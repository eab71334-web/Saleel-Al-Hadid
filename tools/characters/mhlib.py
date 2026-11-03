# Mini procedural modelling + PBR texture + glTF toolkit (numpy only) for the Saleel game.
import json, struct, math, numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image

# ======================================================== textures (tileable, 256px)
S = 256
def _noise(seed, sigma, aniso=(1, 1)):
    r = np.random.RandomState(seed)
    a = r.rand(S, S)
    a = gaussian_filter(a, (sigma * aniso[0], sigma * aniso[1]), mode='wrap')
    a -= a.min(); a /= (a.max() + 1e-9)
    return a
def _fbm(seed, base=3, octs=4, aniso=(1, 1)):
    t = 0; amp = 1.0; tot = 0
    for o in range(octs):
        t = t + amp * _noise(seed + o * 7, max(0.6, S / (base * 2 ** o) / 6), aniso); tot += amp; amp *= 0.5
    return t / tot
def _normal(h, k=1.2):
    gx = np.roll(h, -1, 1) - np.roll(h, 1, 1); gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    n = np.dstack([-gx * k * S / 64, gy * k * S / 64, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5
def _scratches(seed, n=60, length=60):
    r = np.random.RandomState(seed); im = Image.new('L', (S, S), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x, y = r.randint(0, S), r.randint(0, S); a = r.rand() * math.pi; l = r.randint(10, length)
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                d.line([(x + ox, y + oy), (x + ox + math.cos(a) * l, y + oy + math.sin(a) * l)], fill=int(60 + r.rand() * 195), width=1)
    return np.asarray(im, dtype=np.float32) / 255.0

def make_textures(outdir):
    import os; os.makedirs(outdir, exist_ok=True)
    def save(name, base, rough, metal, normal):
        Image.fromarray((np.clip(base * (1.35 if metal.mean() > 0.3 else 1.0), 0, 1) * 255).astype(np.uint8)).save(f'{outdir}/{name}_c.png', optimize=True)
        mr = np.dstack([np.zeros_like(rough), np.clip(rough * 0.9 + 0.1, 0, 1), np.clip(metal * 0.45, 0, 1)])
        Image.fromarray((mr * 255).astype(np.uint8)).save(f'{outdir}/{name}_mr.png', optimize=True)
        Image.fromarray((np.clip(normal, 0, 1) * 255).astype(np.uint8)).save(f'{outdir}/{name}_n.png', optimize=True)
    # --- steel: brushed, scratched, rust speckle
    br = _fbm(1, 6, 3, (0.15, 4.0)); sc = _scratches(2); low = _fbm(3, 2, 3); fine = _fbm(4, 24, 2)
    rust = np.clip((low - 0.62) * 5, 0, 1) * np.clip((fine - 0.35) * 3, 0, 1)
    v = 0.56 + 0.16 * br + 0.18 * sc - 0.05 * fine
    base = np.dstack([v, v * 1.01, v * 1.05])
    rc = np.array([0.45, 0.22, 0.1])
    base = base * (1 - rust[..., None]) + rc * (0.7 + 0.5 * fine[..., None]) * rust[..., None]
    save('steel', base, 0.34 + 0.25 * br + 0.45 * rust - 0.1 * sc, (1 - rust) * 0.95 + 0.05, _normal(br * 0.5 + sc * 0.4 + fine * 0.15))
    # --- dark iron: hammered
    h = _fbm(11, 9, 3); sc = _scratches(12, 40, 40); low = _fbm(13, 2, 3)
    rust = np.clip((low - 0.6) * 4, 0, 1)
    v = 0.2 + 0.1 * h + 0.1 * sc
    base = np.dstack([v, v, v * 1.05]) * (1 - rust[..., None]) + np.array([0.35, 0.18, 0.09]) * rust[..., None] * (0.6 + h[..., None])
    save('iron', base, 0.5 + 0.35 * h + 0.3 * rust, (1 - rust) * 0.9 + 0.05, _normal(h * 0.8 + sc * 0.2, 4))
    # --- old wood: grain with cracks
    yy, xx = np.mgrid[0:S, 0:S] / S
    warp = _fbm(21, 3, 3)
    g = np.sin((xx * 22 + warp * 6.0) * math.pi * 2) * 0.5 + 0.5
    g2 = _fbm(22, 10, 3, (6.0, 0.3))
    crack = np.clip((g2 - 0.8) * 8, 0, 1)
    v = 0.5 + 0.28 * g + 0.2 * g2 - 0.5 * crack
    base = np.dstack([v * 0.62, v * 0.42, v * 0.24]) * (0.9 + 0.2 * _fbm(23, 2, 2)[..., None])
    save('wood', base, 0.82 + 0.1 * g2, np.zeros_like(g), _normal(g * 0.5 + g2 * 0.4 - crack * 0.5, 3))
    # --- leather
    h = _fbm(31, 18, 3); wr = _fbm(32, 4, 3, (1.0, 3.0))
    v = 0.45 + 0.25 * h + 0.15 * wr
    base = np.dstack([v * 0.7, v * 0.45, v * 0.28])
    save('leather', base, 0.62 + 0.25 * h, np.zeros_like(h), _normal(h * 0.7 + wr * 0.3, 3))
    # --- brass / gold (tinted by vertex colour)
    h = _fbm(41, 8, 3); sc = _scratches(42, 50, 50); sm = _fbm(43, 3, 3)
    v = 0.75 + 0.15 * sm + 0.1 * sc
    base = np.dstack([v, v * 0.82, v * 0.45])
    save('gold', base, 0.25 + 0.3 * sm, np.ones_like(h) * 0.97, _normal(h * 0.3 + sc * 0.3, 2))
    # --- woven cloth (white, tinted by vertex colour)
    yy, xx = np.mgrid[0:S, 0:S]
    wv = (np.sin(xx * math.pi / 2) * np.sin(yy * math.pi / 2)) * 0.5 + 0.5
    n = _fbm(51, 10, 3)
    v = 0.82 + 0.1 * wv + 0.08 * n
    save('cloth', np.dstack([v, v, v]), 0.9 + 0.0 * wv, np.zeros_like(wv), _normal(n * 0.1, 0.5))
MATS = {'steel': dict(), 'iron': dict(), 'wood': dict(), 'leather': dict(), 'gold': dict(), 'cloth': dict(), 'body': None}

# ======================================================== geometry helpers
def rotm(ax, a):
    c, s = math.cos(a), math.sin(a)
    if ax == 0: return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if ax == 1: return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def euler(x=0, y=0, z=0): return rotm(2, z) @ rotm(1, y) @ rotm(0, x)

def loft(rings, nseg=12, cap0=True, cap1=True):
    """rings: list of (centre, axis_u, axis_v) 3-vectors; returns V, F (smooth, consistent winding outward when rings go bottom->top)"""
    V = []; F = []
    for c, u, v in rings:
        c = np.array(c, float); u = np.array(u, float); v = np.array(v, float)
        for k in range(nseg):
            a = 2 * math.pi * k / nseg
            V.append(c + u * math.cos(a) + v * math.sin(a))
    n = len(rings)
    for i in range(n - 1):
        for k in range(nseg):
            a = i * nseg + k; b = i * nseg + (k + 1) % nseg
            c_ = (i + 1) * nseg + k; d = (i + 1) * nseg + (k + 1) % nseg
            F += [[a, b, c_], [b, d, c_]]
    V = np.array(V)
    if cap0:
        V = np.vstack([V, np.array(rings[0][0], float)]); ci = len(V) - 1
        for k in range(nseg): F.append([ci, (k + 1) % nseg, k])
    if cap1:
        V = np.vstack([V, np.array(rings[-1][0], float)]); ci = len(V) - 1
        base = (n - 1) * nseg
        for k in range(nseg): F.append([ci, base + k, base + (k + 1) % nseg])
    return V, np.array(F)

def rx(c, rxx, rzz, ax='xz'): pass

def ring_xz(c, rxx, rzz): return (c, (rxx, 0, 0), (0, 0, rzz))
def ring_xy(c, rxx, ryy): return (c, (rxx, 0, 0), (0, ryy, 0))
def ring_perp(c, d, rxx, ryy):
    d = np.array(d, float); d /= np.linalg.norm(d)
    side = np.array([1.0, 0, 0]); up = np.cross(d, side); up /= np.linalg.norm(up)
    return (c, side * rxx, up * ryy)

def lathe(profile, nseg=16, centre=(0, 0, 0), axis=1):
    """profile: list of (radius, height) bottom->top. axis 0/1/2 = x/y/z"""
    rings = []
    for r, h in profile:
        if axis == 1: rings.append(ring_xz((centre[0], centre[1] + h, centre[2]), r, r))
        elif axis == 2: rings.append(ring_xy((centre[0], centre[1], centre[2] + h), r, r))
        else: rings.append((((centre[0] + h), centre[1], centre[2]), (0, r, 0), (0, 0, r)))
    return loft(rings, nseg, profile[0][0] > 1e-6, profile[-1][0] > 1e-6)

def box(c, size, rot=None):
    sx, sy, sz = [s / 2 for s in size]
    V = np.array([[x * sx, y * sy, z * sz] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float)
    F = np.array([[0,1,3],[0,3,2],[4,6,7],[4,7,5],[0,4,5],[0,5,1],[2,3,7],[2,7,6],[0,2,6],[0,6,4],[1,5,7],[1,7,3]])
    if rot is not None: V = V @ rot.T
    return V + np.array(c, float), F

def extrude(poly, thick, z0=0.0):
    """convex 2D polygon (x,y) extruded along z"""
    n = len(poly); V = []
    for z in (z0 - thick / 2, z0 + thick / 2):
        for x, y in poly: V.append([x, y, z])
    F = []
    for i in range(n):
        j = (i + 1) % n
        F += [[i, j, n + i], [j, n + j, n + i]]
    for i in range(1, n - 1):
        F += [[0, i + 1, i], [n, n + i, n + i + 1]]
    return np.array(V, float), np.array(F)

def place(V, rot=None, pos=(0, 0, 0)):
    V = np.array(V, float)
    if rot is not None: V = V @ rot.T
    return V + np.array(pos, float)

# ======================================================== model container
class Model:
    def __init__(self, bones, parents, heads):
        self.bones = bones; self.parents = parents; self.heads = heads
        self.bidx = {b: i for i, b in enumerate(bones)}
        self.prims = {}   # material -> dict of lists
    def add(self, mat, V, F, color=(1, 1, 1), bone='root', smooth=True, wfn=None, uvscale=1.6, colfn=None):
        V = np.array(V, float); F = np.array(F)
        P = self.prims.setdefault(mat, dict(pos=[], nrm=[], uv=[], col=[], j=[], w=[], idx=[], n=0))
        if smooth:
            N = np.zeros_like(V)
            fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
            for k in range(3): np.add.at(N, F[:, k], fn)
            ln = np.linalg.norm(N, axis=1, keepdims=True); ln[ln == 0] = 1; N /= ln
            VV, FF, NN = V, F, N
        else:
            fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
            ln = np.linalg.norm(fn, axis=1, keepdims=True); ln[ln == 0] = 1; fn /= ln
            VV = V[F.reshape(-1)]; NN = np.repeat(fn, 3, axis=0); FF = np.arange(len(VV)).reshape(-1, 3)
        # triplanar-style projection on the dominant normal axis
        a = np.abs(NN); dom = a.argmax(1)
        uv = np.zeros((len(VV), 2))
        for ax, (i, j) in enumerate([(2, 1), (0, 2), (0, 1)]):
            m = dom == ax; uv[m, 0] = VV[m, i]; uv[m, 1] = VV[m, j]
        uv *= uvscale
        n = len(VV)
        J = np.zeros((n, 4), np.uint16); W = np.zeros((n, 4), np.float32)
        if wfn is None:
            J[:, 0] = self.bidx[bone]; W[:, 0] = 1
        else:
            for i in range(n):
                lst = wfn(VV[i])
                for k, (b, w) in enumerate(lst[:4]): J[i, k] = self.bidx[b]; W[i, k] = w
        C = np.ones((n, 4), np.float32)
        if colfn is None: C[:, :3] = color
        else:
            for i in range(n): C[i, :3] = colfn(VV[i])
        P['pos'].append(VV); P['nrm'].append(NN); P['uv'].append(uv); P['col'].append(C); P['j'].append(J); P['w'].append(W)
        P['idx'].append(FF + P['n']); P['n'] += n

    def write(self, path, clips, texdir='tex'):
        blob = bytearray(); views = []; acc = []
        def put(arr, target=None, comp=5126, typ='SCALAR', mm=False):
            while len(blob) % 4: blob.append(0)
            views.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': arr.nbytes, **({'target': target} if target else {})})
            blob.extend(arr.tobytes())
            a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': typ}
            if mm: a['min'] = arr.min(axis=0).tolist(); a['max'] = arr.max(axis=0).tolist()
            acc.append(a); return len(acc) - 1
        images = []; textures = []; materials = []; prims = []
        def tex(name):
            images.append({'uri': f'{texdir}/{name}.png'}); textures.append({'source': len(images) - 1, 'sampler': 0}); return len(textures) - 1
        for mname, P in self.prims.items():
            pos = np.vstack(P['pos']).astype(np.float32); nrm = np.vstack(P['nrm']).astype(np.float32)
            uv = np.vstack(P['uv']).astype(np.float32); col = np.vstack(P['col']).astype(np.float32)
            J = np.vstack(P['j']); W = np.vstack(P['w']); idx = np.vstack(P['idx']).reshape(-1).astype(np.uint32)
            att = {'POSITION': put(pos, 34962, 5126, 'VEC3', True), 'NORMAL': put(nrm, 34962, 5126, 'VEC3'),
                   'TEXCOORD_0': put(uv, 34962, 5126, 'VEC2'), 'COLOR_0': put(col, 34962, 5126, 'VEC4'),
                   'JOINTS_0': put(J, 34962, 5123, 'VEC4'), 'WEIGHTS_0': put(W, 34962, 5126, 'VEC4')}
            mat = {'name': mname, 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0.0, 'roughnessFactor': 0.85}}
            if mname != 'body':
                mat['pbrMetallicRoughness'] = {'baseColorFactor': [1, 1, 1, 1], 'baseColorTexture': {'index': tex(mname + '_c')},
                    'metallicRoughnessTexture': {'index': tex(mname + '_mr')}, 'metallicFactor': 1.0, 'roughnessFactor': 1.0}
                mat['normalTexture'] = {'index': tex(mname + '_n')}
            materials.append(mat)
            prims.append({'attributes': att, 'indices': put(idx, 34963, 5125, 'SCALAR'), 'material': len(materials) - 1})
        bones = self.bones; bidx = self.bidx
        ib = []
        for b in bones:
            m = np.eye(4, dtype=np.float32); m[:3, 3] = -np.array(self.heads[b]); ib.append(m.T.reshape(-1))
        aIB = put(np.array(ib, np.float32).reshape(len(bones), 16), None, 5126, 'MAT4')
        nodes = []
        for b in bones:
            p = self.parents[b]
            t = (np.array(self.heads[b]) - np.array(self.heads[p])) if p else np.array(self.heads[b])
            nodes.append({'name': b, 'translation': [float(x) for x in t]})
        for b in bones:
            ch = [bidx[c] for c in bones if self.parents[c] == b]
            if ch: nodes[bidx[b]]['children'] = ch
        mesh_node = len(nodes); nodes.append({'name': 'Body', 'mesh': 0, 'skin': 0})
        arm = len(nodes); nodes.append({'name': 'Armature', 'children': [bidx[bones[0]], mesh_node]})
        anims = []
        for name, dur, fn_, loop in clips:
            n = int(dur * 30) + 1
            times = np.array([i * dur / (n - 1) for i in range(n)], np.float32)
            tA = put(times, None, 5126, 'SCALAR', True)
            rots = {b: [] for b in bones}; rpos = []
            for i in range(n):
                Pz, rp = fn_(i / (n - 1))
                for b in bones: rots[b].append(quat(*Pz.get(b, (0, 0, 0))))
                rpos.append(rp)
            samplers = []; channels = []
            for b in bones:
                arr = np.array(rots[b], np.float32)
                if np.abs(arr - np.array([0, 0, 0, 1])).max() < 1e-6: continue
                samplers.append({'input': tA, 'output': put(arr, None, 5126, 'VEC4'), 'interpolation': 'LINEAR'})
                channels.append({'sampler': len(samplers) - 1, 'target': {'node': bidx[b], 'path': 'rotation'}})
            rp = (np.array(rpos, np.float32) + np.array(self.heads[bones[0]], np.float32)[None, :]).astype(np.float32)
            samplers.append({'input': tA, 'output': put(rp, None, 5126, 'VEC3'), 'interpolation': 'LINEAR'})
            channels.append({'sampler': len(samplers) - 1, 'target': {'node': bidx[bones[0]], 'path': 'translation'}})
            anims.append({'name': name, 'samplers': samplers, 'channels': channels})
        g = {'asset': {'version': '2.0', 'generator': 'saleel procedural gear/horse generator'}, 'scene': 0, 'scenes': [{'nodes': [arm]}], 'nodes': nodes,
             'skins': [{'joints': list(range(len(bones))), 'inverseBindMatrices': aIB, 'skeleton': 0}], 'meshes': [{'primitives': prims}],
             'materials': materials, 'textures': textures, 'images': images, 'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}],
             'accessors': acc, 'bufferViews': views, 'buffers': [{'byteLength': len(blob)}], 'animations': anims}
        js = json.dumps(g, separators=(',', ':')).encode()
        while len(js) % 4: js += b' '
        while len(blob) % 4: blob.append(0)
        glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob)
        open(path, 'wb').write(glb); return len(glb)

def quat(x=0, y=0, z=0):
    def q(ax, a):
        s = math.sin(a / 2); c = math.cos(a / 2); return [(s if ax == 0 else 0), (s if ax == 1 else 0), (s if ax == 2 else 0), c]
    def mul(a, b):
        ax, ay, az, aw = a; bx, by, bz, bw = b
        return [aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx, aw*bz+ax*by-ay*bx+az*bw, aw*bw-ax*bx-ay*by-az*bz]
    r = q(2, z); r = mul(r, q(1, y)); r = mul(r, q(0, x)); return r
