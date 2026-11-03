#!/usr/bin/env python3
# Builds skinned, animated humanoid .glb characters from the MakeHuman base mesh + default rig (CC0).
import json, struct, math, sys, numpy as np
D = '/home/claude/eab71334-web/makehuman/makehuman/data/'
SC = 0.1  # decimetres -> metres

# ---------- mesh
V = []; faces = []; grp = None
for l in open(D + '3dobjs/base.obj'):
    if l.startswith('v '):
        V.append([float(x) for x in l.split()[1:4]])
    elif l.startswith('g '):
        grp = l.split()[1]
    elif l.startswith('f ') and grp == 'body':
        idx = [int(t.split('/')[0]) - 1 for t in l.split()[1:]]
        for i in range(1, len(idx) - 1):
            faces.append([idx[0], idx[i], idx[i + 1]])
V = np.array(V) * SC
ymin = V[:, 1].min()
V[:, 1] -= ymin
faces = np.array(faces)

# ---------- skeleton
sk = json.load(open(D + 'rigs/default.mhskel'))
bones = sk['bones']; joints = sk['joints']
CORE = ['root', 'spine05', 'spine03', 'spine01', 'neck01', 'head', 'clavicle.L', 'clavicle.R', 'upperarm01.L', 'upperarm01.R',
        'lowerarm01.L', 'lowerarm01.R', 'wrist.L', 'wrist.R', 'upperleg01.L', 'upperleg01.R', 'lowerleg01.L', 'lowerleg01.R', 'foot.L', 'foot.R']
def core_of(b):
    while b is not None and b not in CORE:
        b = bones[b]['parent']
    return b or 'root'
def jpos(name):
    idx = joints[name]
    return V[idx].mean(axis=0)
head_pos = {b: jpos(bones[b]['head']) for b in CORE}
core_parent = {}
for b in CORE:
    p = bones[b]['parent']
    core_parent[b] = None if b == 'root' else core_of(p)
ORDER = CORE  # parents precede children? ensure
seen = set()
order = []
def add(b):
    if b in seen: return
    if core_parent[b]: add(core_parent[b])
    seen.add(b); order.append(b)
for b in CORE: add(b)
bidx = {b: i for i, b in enumerate(order)}

# weights
W = json.load(open(D + 'rigs/default_weights.mhw'))['weights']
infl = [dict() for _ in range(len(V))]
for b, lst in W.items():
    c = core_of(b)
    for vi, w in lst:
        if vi < len(V):
            infl[vi][c] = infl[vi].get(c, 0) + w
# ---- decimate by vertex clustering (mobile friendly)
CELL = float(__import__('os').environ.get('CELL', '0.024'))
used0 = np.unique(faces)
key = {}
cid = -np.ones(len(V), dtype=np.int64)
for i in used0:
    k = tuple((V[i] / CELL).astype(int) if False else np.floor(V[i] / CELL).astype(int))
    # separate left/right at the centre line so the legs/arms never merge
    k = k + (1 if V[i][0] > 0 else 0,)
    if k not in key: key[k] = len(key)
    cid[i] = key[k]
nc = len(key)
V2 = np.zeros((nc, 3)); cnt = np.zeros(nc); infl2 = [dict() for _ in range(nc)]
for i in used0:
    c = cid[i]; V2[c] += V[i]; cnt[c] += 1
    for b, w in infl[i].items(): infl2[c][b] = infl2[c].get(b, 0) + w
V2 /= cnt[:, None]
f2 = cid[faces]
keep = (f2[:, 0] != f2[:, 1]) & (f2[:, 1] != f2[:, 2]) & (f2[:, 0] != f2[:, 2])
f2 = f2[keep]
V = V2; infl = infl2; faces = f2
J = np.zeros((len(V), 4), dtype=np.uint16); WT = np.zeros((len(V), 4), dtype=np.float32)
dom = ['root'] * len(V)
for i, d in enumerate(infl):
    if not d: d = {'root': 1.0}
    top = sorted(d.items(), key=lambda kv: -kv[1])[:4]
    s = sum(w for _, w in top)
    dom[i] = top[0][0]
    for k, (b, w) in enumerate(top):
        J[i, k] = bidx[b]; WT[i, k] = w / s

# ---------- palettes / painting
PAL = {
 'sword':   dict(tunic=(.45, .47, .52), arms=(.62, .64, .68), pants=(.22, .18, .15), boots=(.12, .09, .07), helm=(.66, .68, .74), belt=(.25, .15, .08), skin=(.86, .66, .52)),
 'archer':  dict(tunic=(.2, .42, .2), arms=(.2, .42, .2), pants=(.35, .27, .16), boots=(.25, .16, .08), helm=(.15, .3, .15), belt=(.25, .15, .08), skin=(.84, .64, .5)),
 'cav':     dict(tunic=(.5, .5, .55), arms=(.6, .62, .66), pants=(.2, .2, .24), boots=(.1, .08, .07), helm=(.6, .62, .68), belt=(.3, .2, .1), skin=(.86, .66, .52)),
 'hero':    dict(tunic=(.55, .08, .08), arms=(.75, .6, .2), pants=(.12, .1, .12), boots=(.1, .07, .05), helm=(.85, .68, .2), belt=(.8, .65, .2), skin=(.88, .68, .54)),
 'villager':dict(tunic=(.62, .5, .32), arms=(.62, .5, .32), pants=(.36, .28, .18), boots=(.3, .2, .12), helm=(.55, .4, .2), belt=(.4, .25, .12), skin=(.84, .64, .5)),
}
def paint(kind):
    p = PAL[kind]
    col = np.zeros((len(V), 4), dtype=np.float32); col[:, 3] = 1
    hy = head_pos['head'][1]; ank = head_pos['foot.L'][1]; wy = head_pos['root'][1]
    for i in range(len(V)):
        d = dom[i]; y = V[i, 1]; c = p['skin']
        if d in ('head', 'neck01'):
            c = p['skin']
            if d == 'head' and y > hy + (0.11 if kind in ('sword', 'cav', 'hero', 'archer') else 0.15):
                c = p['helm']
            if kind == 'villager' and d == 'head' and y > hy + 0.14:
                c = (.3, .2, .1)
        elif d in ('spine05', 'spine03', 'spine01', 'clavicle.L', 'clavicle.R'):
            c = p['tunic']
            if abs(y - wy - 0.02) < 0.05: c = p['belt']
        elif d.startswith('upperarm'):
            c = p['arms']
        elif d.startswith('lowerarm'):
            c = p['arms'] if kind in ('sword', 'cav', 'hero') else p['tunic']
        elif d.startswith('wrist'):
            c = (.3, .2, .12) if kind != 'villager' else p['skin']
        elif d == 'root':
            c = p['pants']
            if abs(y - wy) < 0.05: c = p['belt']
        elif d.startswith('upperleg') or d.startswith('lowerleg'):
            c = p['pants']
            if y < ank + 0.45: c = p['boots']
        elif d.startswith('foot'):
            c = p['boots']
        col[i, :3] = c
    return col

# ---------- extra rigid parts (weapons, shield, crown, eyes), each bound to one bone
def box(c, s, col, bone):
    cx, cy, cz = c; sx, sy, sz = [v / 2 for v in s]
    vs = []
    for dx in (-1, 1):
        for dy in (-1, 1):
            for dz in (-1, 1):
                vs.append([cx + dx * sx, cy + dy * sy, cz + dz * sz])
    fs = [[0,1,3],[0,3,2],[4,6,7],[4,7,5],[0,4,5],[0,5,1],[2,3,7],[2,7,6],[0,2,6],[0,6,4],[1,5,7],[1,7,3]]
    return np.array(vs), np.array(fs), col, bone

def extras(kind):
    parts = []
    hw = head_pos['wrist.R']; lw = head_pos['wrist.L']; hd = head_pos['head']
    # eyes
    for sx in (-1, 1):
        parts.append(box((hd[0] + sx * 0.035, hd[1] + 0.085, hd[2] + 0.115), (0.022, 0.014, 0.01), (.05, .05, .06), 'head'))
    if kind in ('sword', 'cav', 'hero'):
        L = 0.95 if kind != 'hero' else 1.15
        # sword, hand on the grip, blade forward-down (follows the forearm)
        L = 0.75 if kind != 'hero' else 0.9
        p0 = hw + np.array([0, 0.0, 0.04])
        parts.append(box(p0 + [0, 0.0, 0], (0.03, 0.2, 0.03), (.25, .15, .08), 'wrist.R'))
        parts.append(box(p0 + [0, 0.11, 0], (0.2, 0.035, 0.04), (.7, .6, .25), 'wrist.R'))
        parts.append(box(p0 + [0, 0.12 + L / 2, 0], (0.07, L, 0.016), (.82, .84, .9) if kind != 'hero' else (.95, .9, .6), 'wrist.R'))
        parts.append(box(p0 + [0, 0.12 + L + 0.03, 0], (0.03, 0.07, 0.012), (.82, .84, .9), 'wrist.R'))
        # shield on the left forearm
        sp = head_pos['lowerarm01.L'] * 0.55 + head_pos['wrist.L'] * 0.45 + np.array([0.04, 0, 0.08])
        parts.append(box(sp, (0.04, 0.5, 0.42), (.5, .1, .1) if kind != 'hero' else (.8, .62, .15), 'lowerarm01.L'))
        parts.append(box(sp + [0.025, 0, 0], (0.02, 0.5, 0.08), (.7, .7, .72), 'lowerarm01.L'))
        parts.append(box(sp + [0.025, 0, 0], (0.02, 0.08, 0.42), (.7, .7, .72), 'lowerarm01.L'))
    if kind == 'archer':
        bp = lw + np.array([0, 0, 0.05])
        parts.append(box(bp, (0.035, 1.0, 0.035), (.35, .22, .1), 'wrist.L'))
        parts.append(box(bp + [0, 0.5, -0.07], (0.035, 0.12, 0.035), (.35, .22, .1), 'wrist.L'))
        parts.append(box(bp + [0, -0.5, -0.07], (0.035, 0.12, 0.035), (.35, .22, .1), 'wrist.L'))
        parts.append(box(bp + [0, 0, -0.12], (0.008, 1.0, 0.008), (.9, .9, .8), 'wrist.L'))
        # quiver on the back
        sp = head_pos['spine01'] + np.array([0.0, -0.1, -0.15])
        parts.append(box(sp, (0.14, 0.5, 0.12), (.3, .18, .08), 'spine01'))
        for k in range(3):
            parts.append(box(sp + [-0.03 + k * 0.03, 0.3, 0], (0.015, 0.12, 0.015), (.9, .85, .7), 'spine01'))
    if kind == 'hero':
        for k in range(5):
            a = k * 2 * math.pi / 5
            parts.append(box((hd[0] + math.sin(a) * 0.1, hd[1] + 0.27, hd[2] + 0.02 + math.cos(a) * 0.1), (0.04, 0.09, 0.04), (.95, .8, .25), 'head'))
        parts.append(box((hd[0], hd[1] + 0.23, hd[2] + 0.02), (0.22, 0.04, 0.22), (.95, .8, .25), 'head'))
        # cape
        sp = head_pos['spine01'] + np.array([0, -0.45, -0.17])
        parts.append(box(sp, (0.5, 0.95, 0.03), (.5, .05, .05), 'spine01'))
    if kind in ('sword', 'cav'):
        parts.append(box((hd[0], hd[1] + 0.2, hd[2] + 0.02), (0.02, 0.05, 0.2), (.55, .1, .1), 'head'))  # helmet crest
    return parts

# ---------- animation
def qE(x=0, y=0, z=0):
    def q(ax, a):
        s = math.sin(a / 2); c = math.cos(a / 2)
        return [(s if ax == 0 else 0), (s if ax == 1 else 0), (s if ax == 2 else 0), c]
    def mul(a, b):
        ax, ay, az, aw = a; bx, by, bz, bw = b
        return [aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx, aw*bz+ax*by-ay*bx+az*bw, aw*bw-ax*bx-ay*by-az*bz]
    r = q(2, z); r = mul(r, q(1, y)); r = mul(r, q(0, x))
    return r

ARM = 1.2   # A-pose: arm angle down from T
def base_pose():
    P = {b: [0, 0, 0] for b in order}
    P['upperarm01.L'] = [0, 0, -ARM]; P['upperarm01.R'] = [0, 0, ARM]
    return P

def clip_idle(t, kind):
    P = base_pose(); s = math.sin(t * math.pi)
    P['spine03'][0] = 0.02 * s; P['head'][0] = -0.02 * s
    P['upperarm01.L'][0] = 0.0; P['lowerarm01.L'][0] = -0.25 + 0.03 * s; P['lowerarm01.R'][0] = (-0.9 if kind in ('sword','cav','hero') else -0.25) + 0.03 * s
    P['upperleg01.L'][0] = -0.02; P['upperleg01.R'][0] = -0.02
    return P, [0, 0.004 * s, 0]

def gait(t, kind, amp, knee, bob, lean, cyc=1.0):
    P = base_pose(); a = t * 2 * math.pi
    for sd, sgn in (('L', 1), ('R', -1)):
        ph = a + (0 if sd == 'L' else math.pi)
        P['upperleg01.' + sd][0] = -math.sin(ph) * amp
        P['lowerleg01.' + sd][0] = max(0.0, -math.cos(ph)) * knee + 0.08
        P['foot.' + sd][0] = math.sin(ph) * 0.15
        P['upperarm01.' + sd][0] = math.sin(ph) * amp * 0.9 * (1 if sd == 'R' else 1)
        P['lowerarm01.' + sd][0] = -0.35 - 0.5 * max(0, math.sin(ph)) * (1.0 if amp > 0.8 else 0.4)
    P['spine03'][1] = math.sin(a) * 0.16; P['spine03'][0] = lean
    P['root'][1] = -math.sin(a) * 0.1
    P['head'][1] = -math.sin(a) * 0.1; P['head'][0] = -lean * 0.6
    P['spine05'][2] = math.sin(a) * 0.03
    return P, [0, abs(math.sin(a)) * bob - 0.015, 0]

def clip_walk(t, kind): return gait(t, kind, 0.6, 0.9, 0.025, 0.04)
def clip_run(t, kind): return gait(t, kind, 1.0, 1.7, 0.05, 0.28)

def clip_attack(t, kind):
    P = base_pose()
    P['lowerleg01.R'][0] = 0.2; P['upperleg01.R'][0] = 0.3; P['upperleg01.L'][0] = -0.5; P['lowerleg01.L'][0] = 0.4
    ease = lambda x: x * x * (3 - 2 * x)
    if kind == 'archer':
        d = ease(min(t / 0.55, 1.0)) if t < 0.55 else 1.0 - ease((t - 0.55) / 0.45) * 1.0
        P['upperarm01.L'][2] = -ARM * 0.1; P['upperarm01.L'][1] = 1.45; P['lowerarm01.L'][0] = -0.05
        P['upperarm01.R'][1] = -1.0; P['upperarm01.R'][2] = ARM * 0.3; P['lowerarm01.R'][1] = -1.6 * d - 0.3 + 0.0
        P['lowerarm01.R'][0] = -0.2
        P['spine03'][1] = 0.45 * d; P['head'][1] = -0.35 * d
        return P, [0, 0, -0.04 * (1 - d)]
    if t < 0.3:
        k = ease(t / 0.3)   # wind-up: sword raised behind the shoulder
        up = k
    elif t < 0.5:
        up = 1.0 - ease((t - 0.3) / 0.2) * 1.0 * 1.0  # chop down
        up = 1.0 - (1.0 - 0.0) * ease((t - 0.3) / 0.2)
    else:
        up = -0.15 * (1 - ease((t - 0.5) / 0.5))
    P['upperarm01.R'][2] = ARM - up * 1.6       # raise up to the side
    P['upperarm01.R'][0] = -up * 1.6 + (1 - up) * 0.5   # swing forward
    P['lowerarm01.R'][0] = -0.4 - 0.9 * up
    P['spine03'][1] = -0.5 * up + 0.3 * (1 - up) * (1 if t > 0.3 else 0)
    P['spine03'][0] = 0.25 * (1 - up) * (1 if 0.3 < t < 0.7 else 0)
    P['head'][0] = -0.1
    P['upperarm01.L'][0] = -0.6; P['lowerarm01.L'][0] = -1.1; P['upperarm01.L'][2] = -ARM * 0.4   # shield up
    return P, [0, -0.06 * (1 - up) * (1 if t > 0.3 else 0), 0.12 * (1 - up) * (1 if t > 0.3 else 0)]

def clip_die(t, kind):
    P = base_pose(); e = t * t * (3 - 2 * t)
    P['root'][0] = -1.5 * e; P['spine03'][0] = -0.2 * e; P['head'][0] = 0.3 * e
    P['upperarm01.L'][0] = 0.8 * e; P['upperarm01.R'][0] = 0.8 * e
    P['upperleg01.L'][0] = -0.3 * e; P['upperleg01.R'][0] = 0.2 * e
    P['lowerleg01.L'][0] = 0.6 * e
    return P, [0, -0.78 * e + 0.0, -0.3 * e]

def clip_ride(t, kind):
    P = base_pose(); s = math.sin(t * 2 * math.pi)
    for sd in 'LR':
        P['upperleg01.' + sd][0] = -1.25; P['lowerleg01.' + sd][0] = 1.35
        P['upperleg01.' + sd][2] = 0.35 if sd == 'L' else -0.35
        P['upperarm01.' + sd][0] = -0.6; P['lowerarm01.' + sd][0] = -0.8
    P['spine03'][0] = 0.1 + s * 0.04
    return P, [0, -0.28 + abs(s) * 0.02, 0]

CLIPS = [('idle', 2.0, clip_idle, True), ('walk', 1.0, clip_walk, True), ('run', 0.6, clip_run, True),
         ('attack', 0.8, clip_attack, False), ('die', 1.2, clip_die, False), ('ride', 1.0, clip_ride, True)]

# ---------- GLB writer
def build(kind, out):
    col = paint(kind)
    pos = [V]; cols = [col]; jts = [J]; wts = [WT]; tris = [faces]; off = len(V)
    for vs, fs, c, b in extras(kind):
        n = len(vs)
        pos.append(vs); cc = np.zeros((n, 4), dtype=np.float32); cc[:, :3] = c; cc[:, 3] = 1; cols.append(cc)
        j = np.zeros((n, 4), dtype=np.uint16); j[:, 0] = bidx[b]; jts.append(j)
        w = np.zeros((n, 4), dtype=np.float32); w[:, 0] = 1; wts.append(w)
        tris.append(fs + off); off += n
    P = np.vstack(pos).astype(np.float32); C = np.vstack(cols).astype(np.float32)
    Jn = np.vstack(jts).astype(np.uint16); Wn = np.vstack(wts).astype(np.float32); T = np.vstack(tris).astype(np.uint32)
    # flat normals are cheap; smooth ones by accumulation
    N = np.zeros_like(P)
    f = T
    fn = np.cross(P[f[:, 1]] - P[f[:, 0]], P[f[:, 2]] - P[f[:, 0]])
    for k in range(3): np.add.at(N, f[:, k], fn)
    ln = np.linalg.norm(N, axis=1, keepdims=True); ln[ln == 0] = 1; N = (N / ln).astype(np.float32)
    # compact unused vertices
    used = np.unique(T); remap = -np.ones(len(P), dtype=np.int64); remap[used] = np.arange(len(used))
    P, N, C, Jn, Wn = P[used], N[used], C[used], Jn[used], Wn[used]; T = remap[T].astype(np.uint32)

    blob = bytearray(); views = []; acc = []
    def put(arr, target=None, comp=None, typ=None, mm=False):
        while len(blob) % 4: blob.append(0)
        views.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': arr.nbytes, **({'target': target} if target else {})})
        blob.extend(arr.tobytes())
        a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': typ}
        if mm: a['min'] = arr.min(axis=0).tolist(); a['max'] = arr.max(axis=0).tolist()
        acc.append(a); return len(acc) - 1
    aP = put(P, 34962, 5126, 'VEC3', True); aN = put(N, 34962, 5126, 'VEC3'); aC = put(C, 34962, 5126, 'VEC4')
    aJ = put(Jn, 34962, 5123, 'VEC4'); aW = put(Wn, 34962, 5126, 'VEC4')
    aI = put(T.reshape(-1), 34963, 5125, 'SCALAR')
    # inverse bind matrices (column-major)
    ib = []
    for b in order:
        h = head_pos[b]; m = np.eye(4, dtype=np.float32); m[:3, 3] = -h; ib.append(m.T.reshape(-1))
    aIB = put(np.array(ib, dtype=np.float32).reshape(len(order), 16), None, 5126, 'MAT4')
    # nodes: 0 = armature root container, 1.. bones, last = mesh
    nodes = []
    for b in order:
        hp = head_pos[b]; par = core_parent[b]
        t = (hp - head_pos[par]) if par else hp
        nodes.append({'name': b, 'translation': [float(x) for x in t]})
    for b in order:
        ch = [bidx[c] for c in order if core_parent[c] == b]
        if ch: nodes[bidx[b]]['children'] = ch
    mesh_node = len(nodes)
    nodes.append({'name': 'Body', 'mesh': 0, 'skin': 0})
    arm = len(nodes)
    nodes.append({'name': 'Armature', 'children': [bidx['root'], mesh_node]})
    skin = {'joints': list(range(len(order))), 'inverseBindMatrices': aIB, 'skeleton': bidx['root']}
    anims = []
    for name, dur, fn_, loop in CLIPS:
        n = int(dur * 30) + 1
        times = np.array([i * dur / (n - 1) for i in range(n)], dtype=np.float32)
        tA = put(times, None, 5126, 'SCALAR', True)
        samplers = []; channels = []
        rots = {b: [] for b in order}; rpos = []
        for i in range(n):
            ph = i / (n - 1)
            Pz, rp = fn_(ph, kind)
            for b in order:
                rots[b].append(qE(*Pz[b]))
            rpos.append(rp)
        for b in order:
            arr = np.array(rots[b], dtype=np.float32)
            if np.abs(arr - np.array([0, 0, 0, 1])).max() < 1e-6: continue
            a = put(arr, None, 5126, 'VEC4')
            samplers.append({'input': tA, 'output': a, 'interpolation': 'LINEAR'})
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': bidx[b], 'path': 'rotation'}})
        rp = np.array(rpos, dtype=np.float32) + head_pos['root'][None, :]
        a = put(rp.astype(np.float32), None, 5126, 'VEC3')
        samplers.append({'input': tA, 'output': a, 'interpolation': 'LINEAR'})
        channels.append({'sampler': len(samplers) - 1, 'target': {'node': bidx['root'], 'path': 'translation'}})
        anims.append({'name': name, 'samplers': samplers, 'channels': channels})
    gltf = {'asset': {'version': '2.0', 'generator': 'saleel mh-gen (MakeHuman CC0 base mesh + rig)'},
            'scene': 0, 'scenes': [{'nodes': [arm]}], 'nodes': nodes, 'skins': [skin],
            'meshes': [{'primitives': [{'attributes': {'POSITION': aP, 'NORMAL': aN, 'COLOR_0': aC, 'JOINTS_0': aJ, 'WEIGHTS_0': aW}, 'indices': aI, 'material': 0}]}],
            'materials': [{'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0.0, 'roughnessFactor': 0.85}, 'doubleSided': False}],
            'accessors': acc, 'bufferViews': views, 'buffers': [{'byteLength': len(blob)}], 'animations': anims}
    js = json.dumps(gltf, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    while len(blob) % 4: blob.append(0)
    glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob)
    open(out, 'wb').write(glb)
    print(kind, len(P), 'verts', len(order), 'bones', len(glb) // 1024, 'KB')

if __name__ == '__main__':
    outd = sys.argv[1]
    for k in sys.argv[2:] or ['sword', 'archer', 'cav', 'hero', 'villager']:
        build(k, f'{outd}/{k}.glb')
