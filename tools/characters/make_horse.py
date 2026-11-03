import sys, math, numpy as np
sys.path.insert(0, '/tmp/mh2')
import mhlib as L
from mhlib import *

# ---- skeleton (metres, +Z forward, Y up, hooves on y = 0)
H = {
    'root': (0, 1.15, 0.0), 'neck': (0, 1.32, 0.82), 'head': (0, 1.7, 1.28), 'tail': (0, 1.3, -0.98),
    'fl_u': (0.17, 1.02, 0.62), 'fl_l': (0.17, 0.6, 0.62), 'fl_h': (0.17, 0.17, 0.62),
    'fr_u': (-0.17, 1.02, 0.62), 'fr_l': (-0.17, 0.6, 0.62), 'fr_h': (-0.17, 0.17, 0.62),
    'hl_u': (0.18, 1.04, -0.68), 'hl_l': (0.18, 0.62, -0.78), 'hl_h': (0.18, 0.17, -0.7),
    'hr_u': (-0.18, 1.04, -0.68), 'hr_l': (-0.18, 0.62, -0.78), 'hr_h': (-0.18, 0.17, -0.7),
}
P = {'root': None, 'neck': 'root', 'head': 'neck', 'tail': 'root'}
for s in ('fl', 'fr', 'hl', 'hr'):
    P[s + '_u'] = 'root'; P[s + '_l'] = s + '_u'; P[s + '_h'] = s + '_l'
BONES = list(H.keys())
COAT = (0.42, 0.25, 0.13)
DARK = (0.08, 0.06, 0.05)
M = Model(BONES, P, H)

def legw(s, ykn, yfet, band=0.07):
    def f(p):
        y = p[1]
        if y > ykn + band: return [(s + '_u', 1.0)]
        if y > ykn - band:
            t = (y - (ykn - band)) / (2 * band); return [(s + '_u', t), (s + '_l', 1 - t)]
        if y > yfet + band: return [(s + '_l', 1.0)]
        if y > yfet - band:
            t = (y - (yfet - band)) / (2 * band); return [(s + '_l', t), (s + '_h', 1 - t)]
        return [(s + '_h', 1.0)]
    return f

# ---- barrel body: rings in XY planes along z
sec = [(-1.04, 1.2, 0.02, 0.02), (-1.0, 1.24, 0.15, 0.17), (-0.85, 1.3, 0.27, 0.3), (-0.6, 1.28, 0.285, 0.34), (-0.2, 1.22, 0.265, 0.36),
       (0.2, 1.2, 0.265, 0.37), (0.55, 1.22, 0.29, 0.38), (0.8, 1.27, 0.27, 0.35), (0.98, 1.34, 0.2, 0.28), (1.06, 1.4, 0.12, 0.2)]
rings = [ring_xy((0, cy, z), rxv, ryv) for z, cy, rxv, ryv in sec]
Vb, Fb = loft(rings, 16, True, False)
def body_w(p):
    if p[2] > 0.82: t = min((p[2] - 0.82) / 0.24, 1.0); return [('neck', t * 0.8), ('root', 1 - t * 0.8)]
    if p[2] < -0.9: return [('root', 0.7), ('tail', 0.3)]
    return [('root', 1.0)]
M.add('body', Vb, Fb, color=COAT, wfn=body_w)

# ---- neck (perpendicular rings along a curved axis)
nk = [((0, 1.36, 0.85), 0.2, 0.3), ((0, 1.5, 1.0), 0.16, 0.25), ((0, 1.65, 1.15), 0.12, 0.2), ((0, 1.74, 1.26), 0.1, 0.17)]
rings = [ring_perp(c, (0, 0.7, 0.55), rxv, ryv) for c, rxv, ryv in nk]
Vn, Fn = loft(rings, 12, False, False)
M.add('body', Vn, Fn, color=COAT, wfn=lambda p: [('neck', 0.75), ('root', 0.25)] if p[2] < 0.95 else [('neck', 1.0)])

# ---- head: skull, muzzle
hd = [((0, 1.8, 1.27), 0.1, 0.12), ((0, 1.7, 1.34), 0.095, 0.14), ((0, 1.58, 1.45), 0.07, 0.15), ((0, 1.5, 1.57), 0.055, 0.09), ((0, 1.46, 1.64), 0.055, 0.05)]
rings = [ring_perp(c, (0, -0.8, 0.6), rxv, ryv) for c, rxv, ryv in hd]
Vh, Fh = loft(rings, 12, True, True)
M.add('body', Vh, Fh, color=COAT, bone='head')
for sg in (-1, 1):
    Ve, Fe = lathe([(0.03, 0.0), (0.001, 0.13)], 6, (sg * 0.07, 1.83, 1.25), 1)
    M.add('body', place(Ve - np.array([sg * 0.07, 1.83, 1.25]), euler(0.1, 0, -sg * 0.18), (sg * 0.07, 1.84, 1.25)), Fe, color=COAT, bone='head')
    Vq, Fq = box((sg * 0.085, 1.7, 1.37), (0.022, 0.03, 0.04)); M.add('iron', Vq, Fq, smooth=False, bone='head')   # eyes
    Vq, Fq = box((sg * 0.03, 1.45, 1.66), (0.02, 0.02, 0.02)); M.add('iron', Vq, Fq, smooth=False, bone='head')   # nostrils

# ---- mane and tail (dark)
for i in range(9):
    t = i / 8.0
    c = np.array((0.0, 1.78 - 0.4 * t, 1.12 - 0.3 * t))
    Vm, Fm = box(c + np.array([0, 0.03, -0.1]), (0.03, 0.12, 0.05), euler(0.3, 0, 0)); M.add('body', Vm, Fm, color=DARK, smooth=False, bone='neck')
Vt, Ft = loft([ring_xz((0, 1.32, -1.0), 0.04, 0.04), ring_xz((0, 1.15, -1.12), 0.07, 0.06), ring_xz((0, 0.85, -1.18), 0.06, 0.05), ring_xz((0, 0.55, -1.12), 0.015, 0.015)], 8, True, True)
M.add('body', Vt, Ft, color=DARK, bone='tail')

# ---- legs
def leg(s, top, ytop, rtop, kn, rk, fet, rf, front):
    x, z = H[s + '_u'][0], H[s + '_u'][2]
    zk = H[s + '_l'][2]; zh = H[s + '_h'][2]
    rings = [ring_xz((x, ytop, z), rtop, rtop * 1.25), ring_xz((x, 0.8, (z + zk) / 2), rtop * 0.72, rtop * 0.95), ring_xz((x, kn, zk), rk, rk * 1.15),
             ring_xz((x, 0.4, (zk + zh) / 2), rk * 0.68, rk * 0.72), ring_xz((x, fet, zh), rf, rf), ring_xz((x, 0.1, zh), rf * 1.1, rf * 1.2)]
    Vv, Ff = loft(rings, 10, False, False)
    M.add('body', Vv, Ff, color=COAT, wfn=legw(s, kn, fet))
    # hoof
    Vv, Ff = lathe([(rf * 1.2, 0.1), (rf * 1.35, 0.0), (0.001, 0.0)], 10, (x, 0.0, zh), 1)
    M.add('iron', Vv + np.array([0, 0.0, 0]), Ff, color=(0.6, 0.6, 0.6), bone=s + '_h')
    Vv, Ff = lathe([(rf * 1.2, 0.1), (rf * 1.2, 0.13)], 10, (x, 0.0, zh), 1)
for s in ('fl', 'fr'): leg(s, None, 1.12, 0.12, 0.6, 0.062, 0.2, 0.052, True)
for s in ('hl', 'hr'): leg(s, None, 1.14, 0.14, 0.62, 0.065, 0.2, 0.052, False)

# ---- tack: blanket (team cloth), saddle (leather), stirrups, bridle
Vv, Ff = loft([ring_xy((0, 1.36 + 0.0 * zz, zz), 0.33, 0.27) for zz in (-0.36, 0.38)], 14, True, True)
M.add('cloth', Vv, Ff, color=(0.78, 0.12, 0.12), bone='root')
Vv, Ff = loft([ring_xy((0, 1.44, zz), 0.15 - 0.0 * abs(zz), 0.06) for zz in (-0.3, 0.3)], 10, True, True)
M.add('leather', Vv, Ff, bone='root')
Vv, Ff = box((0, 1.52, -0.3), (0.3, 0.12, 0.05), euler(-0.3, 0, 0)); M.add('leather', Vv, Ff, smooth=False, bone='root')
Vv, Ff = box((0, 1.5, 0.28), (0.12, 0.1, 0.06), euler(0.3, 0, 0)); M.add('leather', Vv, Ff, smooth=False, bone='root')
for sg in (-1, 1):
    Vv, Ff = box((sg * 0.34, 1.05, 0.02), (0.015, 0.4, 0.03)); M.add('leather', Vv, Ff, smooth=False, bone='root')
    Vv, Ff = box((sg * 0.34, 0.84, 0.02), (0.1, 0.012, 0.1)); M.add('steel', Vv, Ff, smooth=False, bone='root')
# girth strap
Vv, Ff = loft([ring_xy((0, 1.2, 0.18), 0.285, 0.375), ring_xy((0, 1.2, 0.24), 0.285, 0.375)], 16, False, False)
M.add('leather', Vv, Ff, wfn=lambda p: [('root', 1.0)])
# bridle: noseband + browband + cheek
Vv, Ff = loft([ring_perp((0, 1.52, 1.58), (0, -0.8, 0.6), 0.062, 0.1), ring_perp((0, 1.515, 1.585), (0, -0.8, 0.6), 0.062, 0.1)], 12, False, False)
M.add('leather', Vv, Ff, bone='head')
Vv, Ff = loft([ring_perp((0, 1.7, 1.36), (0, -0.8, 0.6), 0.098, 0.145), ring_perp((0, 1.712, 1.35), (0, -0.8, 0.6), 0.098, 0.145)], 12, False, False)
M.add('leather', Vv, Ff, bone='head')

# ---- animation
def gait(t, kind):
    Pz = {}; ph = {'walk': dict(fl=0.0, hr=0.25, fr=0.5, hl=0.75), 'run': dict(fl=0.0, fr=0.08, hl=0.45, hr=0.52)}[kind]
    amp = 0.45 if kind == 'walk' else 0.85
    for s in ('fl', 'fr', 'hl', 'hr'):
        a = 2 * math.pi * (t + ph[s]); sg = 1.0
        Pz[s + '_u'] = (-math.sin(a) * amp * (1 if s[0] == 'f' else -0.85), 0, 0)
        lift = max(0.0, math.cos(a))
        Pz[s + '_l'] = ((lift * 1.0 + 0.05) * (1 if s[0] == 'f' else -1.0), 0, 0)
        Pz[s + '_h'] = (-lift * 0.25 * (1 if s[0] == 'f' else -1.0), 0, 0)
    a = 2 * math.pi * t
    Pz['root'] = (math.sin(a * (2 if kind == 'run' else 1)) * (0.06 if kind == 'run' else 0.01), 0, math.sin(a) * 0.015)
    Pz['neck'] = (-0.04 + math.sin(a * (2 if kind == 'run' else 1) + 1.0) * 0.06, 0, 0)
    Pz['head'] = (math.sin(a * 2 + 2) * 0.05, 0, 0)
    Pz['tail'] = (0.2 + math.sin(a * 2) * 0.15, math.sin(a) * 0.15, 0)
    return Pz, [0, (abs(math.sin(a * 2)) * (0.06 if kind == 'run' else 0.015)), 0]
def idle(t):
    a = 2 * math.pi * t
    Pz = {'root': (math.sin(a) * 0.006, 0, 0), 'neck': (math.sin(a + 1) * 0.03 - 0.02, 0, 0), 'head': (math.sin(a * 2) * 0.03, 0, 0),
          'tail': (0.15 + math.sin(a) * 0.06, math.sin(a * 2) * 0.1, 0), 'fl_u': (-0.0, 0, 0)}
    return Pz, [0, 0.004 * math.sin(a), 0]

CLIPS = [('idle', 3.0, idle, True), ('walk', 1.2, lambda t: gait(t, 'walk'), True), ('run', 0.6, lambda t: gait(t, 'run'), True)]

if __name__ == '__main__':
    out = sys.argv[1]
    n = M.write(f'{out}/horse.glb', CLIPS)
    print('horse', n // 1024, 'KB')
