"""Renders the "How to hold sticks" illustrations in Blender.

Run headless, one scene per call:
  blender -b --factory-startup -P tool/grip_renders/grip3d.py -- <scene> <out.png> [quick]

Units: 1 Blender unit = 1 cm. Hands are built from metaballs (one metaball
family per finger so neighbouring fingers never melt into each other), the
stick is a lathe-turned 5A profile, lighting is a soft three-light studio.
"""

import math
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SCENE = ARGV[0] if ARGV else 'test'
OUT = ARGV[1] if len(ARGV) > 1 else '//out.png'
QUICK = 'quick' in ARGV


# ---------------------------------------------------------------- helpers

def lin(h, a=1.0):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (c[0], c[1], c[2], a)


def V(*a):
    return Vector(a)


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def principled(name, color, rough=0.5, **kw):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(color)
    b.inputs['Roughness'].default_value = rough
    for k, v in kw.items():
        b.inputs[k].default_value = v
    return m


def stiff(s, t=0.6):
    """Visible radius of a lone metaball element as a fraction of `radius`."""
    return math.sqrt(1 - (t / s) ** (1 / 3))


# ---------------------------------------------------------------- materials

def materials():
    M = {}
    skin = principled('skin', '#E9B48F', 0.46,
                      **{'Subsurface Weight': 0.35,
                         'Subsurface Scale': 0.35,
                         'Specular IOR Level': 0.38,
                         'Coat Weight': 0.08,
                         'Coat Roughness': 0.4})
    skin.node_tree.nodes['Principled BSDF'].inputs['Subsurface Radius'].default_value = (1.0, 0.42, 0.26)
    M['skin'] = skin
    M['nail'] = principled('nail', '#EDBBA2', 0.26,
                           **{'Coat Weight': 0.6, 'Coat Roughness': 0.12,
                              'Subsurface Weight': 0.2, 'Subsurface Scale': 0.1})

    # Hickory: long streaky grain along the stick's local X axis.
    w = bpy.data.materials.new('wood')
    w.use_nodes = True
    nt = w.node_tree
    b = nt.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = 0.34
    b.inputs['Coat Weight'].default_value = 0.45
    b.inputs['Coat Roughness'].default_value = 0.18
    tc = nt.nodes.new('ShaderNodeTexCoord')
    mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (0.06, 3.2, 3.2)
    nz = nt.nodes.new('ShaderNodeTexNoise')
    nz.inputs['Scale'].default_value = 3.0
    nz.inputs['Detail'].default_value = 9.0
    nz.inputs['Roughness'].default_value = 0.62
    nz.inputs['Distortion'].default_value = 0.6
    cr = nt.nodes.new('ShaderNodeValToRGB')
    cr.color_ramp.elements[0].position = 0.36
    cr.color_ramp.elements[0].color = lin('#C4874F')
    cr.color_ramp.elements[1].position = 0.66
    cr.color_ramp.elements[1].color = lin('#EDC592')
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    nt.links.new(mp.outputs['Vector'], nz.inputs['Vector'])
    nt.links.new(nz.outputs['Fac'], cr.inputs['Fac'])
    nt.links.new(cr.outputs['Color'], b.inputs['Base Color'])
    M['wood'] = w

    M['coral'] = principled('coral', '#E8542A', 0.32, **{'Coat Weight': 0.3})
    M['coral_matte'] = principled('coral_matte', '#E8542A', 0.6)
    M['pad_top'] = principled('pad_top', '#3A3B42', 0.78, **{'Sheen Weight': 0.25})
    M['pad_base'] = principled('pad_base', '#232429', 0.55)
    M['sleeve'] = principled('sleeve', '#3E4656', 0.88,
                             **{'Sheen Weight': 0.6, 'Sheen Roughness': 0.4})
    M['backdrop'] = principled('backdrop', '#FCE9DA', 0.95)
    M['muted'] = principled('muted', '#B39683', 0.7)
    return M


def ghost(mat, alpha):
    """A copy of `mat` that renders at `alpha` opacity."""
    g = mat.copy()
    g.name = mat.name + '_ghost'
    b = g.node_tree.nodes['Principled BSDF']
    b.inputs['Alpha'].default_value = alpha
    return g


# ---------------------------------------------------------------- stick

STICK_L = 40.6
STICK_R = 0.72


def stick_profile():
    R = STICK_R
    p = [(0.0, 0.0), (0.0, 0.46), (0.05, 0.60), (0.14, 0.68), (0.30, R)]
    p.append((24.0, R))
    for i in range(1, 15):
        t = i / 14
        p.append((24.0 + t * (38.3 - 24.0), R - (R - 0.29) * t ** 1.5))
    p.append((38.55, 0.275))
    cx, a, bb = 39.55, 1.05, 0.43
    th0 = math.pi - math.asin(0.285 / bb)
    for i in range(16):
        th = th0 * (1 - i / 15)
        p.append((cx + a * math.cos(th), bb * math.sin(th)))
    p[-1] = (cx + a, 0.0)
    return p


def make_stick(M, name='Stick', mat=None):
    prof = stick_profile()
    seg = 48
    verts, faces, rings = [], [], []
    for x, r in prof:
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append((x, 0, 0))
        else:
            ring = []
            for k in range(seg):
                a = 2 * math.pi * k / seg
                ring.append(len(verts))
                verts.append((x, r * math.cos(a), r * math.sin(a)))
            rings.append(ring)
    flat = []
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        if len(A) == 1:
            for k in range(seg):
                faces.append((A[0], B[(k + 1) % seg], B[k]))
                flat.append(i == 0)
        elif len(B) == 1:
            for k in range(seg):
                faces.append((A[k], A[(k + 1) % seg], B[0]))
                flat.append(False)
        else:
            for k in range(seg):
                faces.append((A[k], A[(k + 1) % seg], B[(k + 1) % seg], B[k]))
                flat.append(False)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    for poly, f in zip(me.polygons, flat):
        poly.use_smooth = not f
    me.materials.append(mat or M['wood'])
    return link(bpy.data.objects.new(name, me))


def place_along(ob, start, direction, roll=0.0):
    """Orients `ob` so its local +X runs from `start` along `direction`."""
    d = Vector(direction).normalized()
    q = d.to_track_quat('X', 'Z')
    q = q @ Quaternion((1, 0, 0), roll)
    ob.matrix_basis = Matrix.Translation(Vector(start)) @ q.to_matrix().to_4x4()


# ---------------------------------------------------------------- metaballs

class Family:
    """One metaball object == one blending family."""

    def __init__(self, name, parent, mat, stiffness, res=0.07):
        mb = bpy.data.metaballs.new(name)
        mb.resolution = res
        mb.render_resolution = res
        mb.threshold = 0.6
        self.ob = link(bpy.data.objects.new(name, mb))
        self.ob.parent = parent
        mb.materials.append(mat)
        self.mb = mb
        self.s = stiffness
        self.k = stiff(stiffness)

    def capsule(self, p0, p1, r):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        e = self.mb.elements.new(type='CAPSULE')
        e.co = (p0 + p1) / 2
        e.radius = r / self.k
        e.size_x = max(d.length / 2, 1e-3)
        e.rotation = d.to_track_quat('X', 'Z') if d.length > 1e-6 else Quaternion()
        e.stiffness = self.s
        return e

    def ball(self, p, r):
        e = self.mb.elements.new(type='BALL')
        e.co = Vector(p)
        e.radius = r / self.k
        e.stiffness = self.s
        return e

    def ellipsoid(self, p, semi, rot=Quaternion()):
        e = self.mb.elements.new(type='ELLIPSOID')
        e.co = Vector(p)
        e.radius = 1 / self.k
        e.size_x, e.size_y, e.size_z = semi
        e.rotation = rot
        e.stiffness = self.s
        return e

    def box(self, p, half, rounding, rot=Quaternion()):
        e = self.mb.elements.new(type='CUBE')
        e.co = Vector(p)
        e.radius = rounding / self.k
        e.size_x, e.size_y, e.size_z = [max(h - rounding, 1e-3) for h in half]
        e.rotation = rot
        e.stiffness = self.s
        return e


# ---------------------------------------------------------------- hand

# Hand frame (right hand): origin at the wrist, +X toward the fingers,
# +Y toward the thumb, +Z out of the back of the hand (dorsal).
FINGERS = {
    'Idx': dict(mcp=V(8.15, 2.75, 0.05), base=V(4.2, 2.35, -0.05),
                L=(3.9, 2.3, 1.9), R=(0.86, 0.79, 0.72), spread=5),
    'Mid': dict(mcp=V(8.55, 0.92, 0.12), base=V(4.2, 0.85, -0.05),
                L=(4.4, 2.8, 2.0), R=(0.90, 0.82, 0.74), spread=0),
    'Rng': dict(mcp=V(8.25, -0.92, 0.05), base=V(4.2, -0.85, -0.05),
                L=(4.1, 2.6, 2.0), R=(0.85, 0.78, 0.71), spread=-4),
    'Pnk': dict(mcp=V(7.55, -2.62, -0.15), base=V(4.2, -2.35, -0.1),
                L=(3.25, 1.95, 1.75), R=(0.76, 0.69, 0.63), spread=-9),
}
THUMB = dict(cmc=V(1.9, 2.55, -1.05), L=(4.4, 3.1, 2.6), R=(1.12, 1.0, 0.93))


def finger_joints(name, a1, a2, a3, spread_extra=0.0):
    f = FINGERS[name]
    sp = math.radians(f['spread'] + spread_extra)
    d0 = V(math.cos(sp), math.sin(sp), 0)
    z = V(0, 0, 1)
    pts = [f['mcp'].copy()]
    frames = []
    th = 0.0
    for L, a in zip(f['L'], (a1, a2, a3)):
        th += math.radians(a)
        d = d0 * math.cos(th) - z * math.sin(th)
        n = d0 * math.sin(th) + z * math.cos(th)
        pts.append(pts[-1] + d * L)
        frames.append((d, n))
    return pts, frames


def thumb_joints(yaw, pitch, roll, a_mcp, a_ip):
    """Thumb metacarpal direction from yaw (toward +Y) and pitch (toward -Z);
    `roll` spins the nail around the metacarpal; flexion curls toward the pad."""
    y, p = math.radians(yaw), math.radians(pitch)
    d = V(math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), -math.sin(p))
    ref = V(0, 0, 1) if abs(d.z) < 0.95 else V(1, 0, 0)
    n = (ref - d * ref.dot(d)).normalized()
    n = Quaternion(d, math.radians(roll)) @ n
    pts = [THUMB['cmc'].copy()]
    frames = []
    for L, a in zip(THUMB['L'], (0.0, a_mcp, a_ip)):
        ang = math.radians(a)
        d, n = (d * math.cos(ang) - n * math.sin(ang),
                n * math.cos(ang) + d * math.sin(ang))
        pts.append(pts[-1] + d * L)
        frames.append((d.copy(), n.copy()))
    return pts, frames


def nail(M, parent, p_dip, p_tip, frame, r, length, name):
    d, n = frame
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(M['nail'])
    for poly in ob.data.polygons:
        poly.use_smooth = True
    side = n.cross(d).normalized()
    center = p_dip + (p_tip - p_dip) * 0.64 + n * (r * 0.9)
    rot = Matrix((d, side, n)).transposed()
    ob.matrix_basis = (Matrix.Translation(center) @ rot.to_4x4()
                       @ Matrix.Diagonal((length / 2, r * 0.5, r * 0.2, 1)))
    ob.parent = parent
    return ob


def make_hand(M, name, pose, mirror=False, sleeve=True):
    """pose: dict finger -> (a1, a2, a3[, spread_extra]), 'thumb' -> kwargs."""
    root = link(bpy.data.objects.new(name, None))
    pre = name
    tp, tf = thumb_joints(**pose['thumb'])

    palm = Family(pre + 'Palm', root, M['skin'], 2.6, 0.08)
    # Metacarpals fanning from the wrist to each knuckle: this is what gives
    # the back of the hand its taper and its faint lengthwise ridges.
    wrist_y = {'Idx': 1.25, 'Mid': 0.42, 'Rng': -0.42, 'Pnk': -1.2}
    rad = {'Idx': 1.02, 'Mid': 1.02, 'Rng': 0.98, 'Pnk': 0.95}
    for fname, f in FINGERS.items():
        mcp = f['mcp']
        palm.capsule(V(0.9, wrist_y[fname], -0.25), V(mcp.x - 0.3, mcp.y, mcp.z - 0.15),
                     rad[fname])
    # Palmar pads.
    palm.ellipsoid(V(3.4, -2.05, -0.95), (2.9, 1.0, 0.95),
                   Quaternion((0, 0, 1), math.radians(-4)))      # hypothenar
    palm.ellipsoid(V(6.2, 0.2, -0.95), (2.0, 2.9, 0.75))         # mid-palm pad
    # Thenar mass wrapped around the thumb metacarpal.
    meta = tp[1] - tp[0]
    q = meta.to_track_quat('X', 'Z')
    palm.ellipsoid(tp[0] + meta * 0.42 + V(0, -0.35, 0.1), (2.7, 1.45, 1.3), q)
    # Web between thumb and index.
    palm.capsule(V(6.6, 2.75, -0.35), tp[1] + (tp[2] - tp[1]) * 0.15, 0.62)
    # Wrist and forearm.
    for i, x in enumerate([-0.6, -2.8, -5.0, -7.2, -9.4, -11.6, -13.8, -16.0]):
        g = min(i, 6) / 6
        palm.ellipsoid(V(x, -0.05, -0.3),
                       (2.2, 2.2 + 0.5 * g, 1.55 + 0.45 * g))

    for fname in FINGERS:
        a = pose[fname]
        pts, frames = finger_joints(fname, *a)
        f = FINGERS[fname]
        fam = Family(pre + fname, root, M['skin'], 9.0, 0.05)
        fam.capsule(pts[0] - frames[0][0] * 0.9 - V(0, 0, 0.15), pts[0], f['R'][0] * 1.02)
        for k in range(3):
            fam.capsule(pts[k], pts[k + 1], f['R'][k])
        nail(M, root, pts[2], pts[3], frames[2], f['R'][2], f['L'][2] * 0.62,
             pre + fname + 'Nail')

    th = Family(pre + 'Thumb', root, M['skin'], 9.0, 0.05)
    th.capsule(tp[0] + (tp[1] - tp[0]) * 0.45, tp[1], THUMB['R'][0])
    for k in (1, 2):
        th.capsule(tp[k], tp[k + 1], THUMB['R'][k])
    nail(M, root, tp[2], tp[3], tf[2], THUMB['R'][2], THUMB['L'][2] * 0.72,
         pre + 'ThumbNail')

    if sleeve:
        make_sleeve(M, root, pre)
    if mirror:
        root.scale = (1, -1, 1)
    return root, dict(thumb=(tp, tf))


def make_sleeve(M, root, pre):
    """A knit cuff over the forearm, ending a few cm short of the wrist."""
    seg, rings = 40, []
    verts, faces = [], []
    xs = [-3.2 - i * 0.55 for i in range(30)]
    for j, x in enumerate(xs):
        rib = 0.06 * math.cos(j * math.pi) if j < 8 else 0.0
        flare = 0.35 * max(0.0, 1 - j / 3)
        ry, rz = 3.3 + flare + rib + 0.02 * j, 2.75 + flare + rib + 0.02 * j
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            ring.append(len(verts))
            verts.append((x, ry * math.cos(a), -0.2 + rz * math.sin(a)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        for k in range(seg):
            faces.append((A[k], B[k], B[(k + 1) % seg], A[(k + 1) % seg]))
    me = bpy.data.meshes.new(pre + 'Sleeve')
    me.from_pydata(verts, [], faces)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(M['sleeve'])
    ob = link(bpy.data.objects.new(pre + 'Sleeve', me))
    sol = ob.modifiers.new('solid', 'SOLIDIFY')
    sol.thickness = 0.35
    ob.parent = root


# ---------------------------------------------------------------- grip solver

def line_dist(q, a, u):
    w = q - a
    return (w - u * w.dot(u)).length


def seg_dist(p0, p1, a, u, n=8):
    return min(line_dist(p0 + (p1 - p0) * (i / n), a, u) for i in range(n + 1))


def palm_inside(q, r):
    """How far point q (a fingertip of radius r) sinks into the palm slab."""
    if -0.5 < q.x < 8.6 and -3.6 < q.y < 3.6:
        return max(0.0, (q.z + r) - (-1.75))
    return 0.0


def solve_finger(fname, a, u, rs, contact=(1, 2), spread_extra=0.0,
                 gap=0.05, looseness=1e-5, ranges=((0, 96), (0, 112), (0, 96))):
    f = FINGERS[fname]
    best = (1e18, None)
    for a1 in range(ranges[0][0], ranges[0][1], 4):
        for a2 in range(ranges[1][0], ranges[1][1], 4):
            for a3 in range(ranges[2][0], ranges[2][1], 4):
                pts, _ = finger_joints(fname, a1, a2, a3, spread_extra)
                E = looseness * (a1 * a1 + a2 * a2 + a3 * a3)
                for k in range(3):
                    d = seg_dist(pts[k], pts[k + 1], a, u)
                    lim = rs + f['R'][k]
                    if d < lim:
                        E += 500 * (lim - d + 0.05) ** 2
                    if k in contact:
                        E += (d - lim - gap) ** 2
                E += 200 * palm_inside(pts[3], f['R'][2]) ** 2
                E += 200 * palm_inside(pts[2], f['R'][1]) ** 2
                if E < best[0]:
                    best = (E, (a1, a2, a3, spread_extra))
    return best[1]


def solve_thumb(target, u, a, rs, avoid=(), seed=1, iters=40000):
    """Search for a thumb pose whose distal pad rests on the stick at
    `target`, lying roughly along the stick direction `u`. `avoid` is a list
    of (p0, p1, r) capsules (the index finger) the thumb must not enter."""
    import random
    rnd = random.Random(seed)
    lo = dict(yaw=-15, pitch=-10, roll=-160, a_mcp=-10, a_ip=-15)
    hi = dict(yaw=75, pitch=80, roll=60, a_mcp=70, a_ip=70)

    def energy(c):
        tp, tf = thumb_joints(**c)
        d3, n3 = tf[2]
        pad = tp[2] + (tp[3] - tp[2]) * 0.55 - n3 * THUMB['R'][2]
        E = 3 * (pad - target).length ** 2
        E += 2 * (1 - d3.dot(u))
        w = pad - a
        toward = -(w - u * w.dot(u)).normalized()
        E += 3 * (1 - (-n3).dot(toward))
        E += 0.4 * max(0.0, -c['a_ip']) ** 2 / 100
        for k in range(3):
            dd = seg_dist(tp[k], tp[k + 1], a, u)
            lim = rs + THUMB['R'][k]
            if dd < lim:
                E += 500 * (lim - dd + 0.05) ** 2
            for (q0, q1, r) in avoid:
                for t in range(9):
                    pt = tp[k] + (tp[k + 1] - tp[k]) * (t / 8)
                    dv = seg_dist(q0, q1, pt, (q1 - q0).normalized(), n=1) if False else None
                    # distance from pt to capsule segment q0-q1
                    qd = q1 - q0
                    tt = max(0.0, min(1.0, (pt - q0).dot(qd) / qd.length_squared))
                    dist = (q0 + qd * tt - pt).length
                    lim2 = r + THUMB['R'][k]
                    if dist < lim2:
                        E += 200 * (lim2 - dist + 0.05) ** 2
        return E

    best = (1e18, None)
    for it in range(iters // 2):
        c = {k: rnd.uniform(lo[k], hi[k]) for k in lo}
        e = energy(c)
        if e < best[0]:
            best = (e, c)
    for sigma in (6, 3, 1.5, 0.7):
        for it in range(iters // 8):
            c = {k: min(hi[k], max(lo[k], best[1][k] + rnd.gauss(0, sigma)))
                 for k in lo}
            e = energy(c)
            if e < best[0]:
                best = (e, c)
    return best[1], best[0]


def grip_line(angle=52.0, fulcrum=V(9.25, 2.9, -2.95)):
    u = V(math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0)
    return fulcrum, u


def grip_pose(wrap=True, angle=52.0, fulcrum=V(9.25, 2.9, -2.95)):
    F, u = grip_line(angle, fulcrum)
    rs = STICK_R
    pose = {}
    pose['Idx'] = solve_finger('Idx', F, u, rs, contact=(1, 2),
                               spread_extra=-5)
    for fname in ('Mid', 'Rng', 'Pnk'):
        if wrap:
            pose[fname] = solve_finger(fname, F, u, rs, contact=(1, 2),
                                       spread_extra=-FINGERS[fname]['spread'] * 0.7,
                                       gap=0.12)
        else:
            pose[fname] = RELAXED[fname]
    side = V(0, 0, 1).cross(u).normalized()        # horizontal, toward the wrist
    up = (side + V(0, 0, 1)).normalized()
    target = F + u * 0.6 + up * (rs + THUMB['R'][2]) * 0.98
    ipts, _ = finger_joints('Idx', *pose['Idx'])
    avoid = [(ipts[k], ipts[k + 1], FINGERS['Idx']['R'][k]) for k in range(3)]
    avoid.append((FINGERS['Idx']['mcp'] - V(1.2, 0, 0.15), FINGERS['Idx']['mcp'], 0.9))
    th, err = solve_thumb(target, u, F, rs, avoid=avoid)
    pose['thumb'] = th
    print('POSE', {k: (tuple(round(x) for x in v) if isinstance(v, tuple)
                       else {kk: round(vv) for kk, vv in v.items()})
                   for k, v in pose.items()}, 'thumb err', round(err, 3))
    butt = F - u * (STICK_L / 3)
    return pose, butt, u


# ---------------------------------------------------------------- set

def studio(key_dir=(-0.45, -0.55, -0.7), key=4.2, fill=0.85, rim=2.0,
           rim_dir=(0.3, 0.9, -0.35)):
    sc = bpy.context.scene
    w = bpy.data.worlds.new('w')
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = lin('#FFF1E6')
    bg.inputs['Strength'].default_value = fill
    sc.world = w

    def sun(name, d, strength, angle):
        s = bpy.data.lights.new(name, 'SUN')
        s.energy = strength
        s.angle = math.radians(angle)
        o = link(bpy.data.objects.new(name, s))
        o.rotation_euler = Vector(d).to_track_quat('-Z', 'Y').to_euler()
        return o
    sun('key', key_dir, key, 22)
    sun('rim', rim_dir, rim, 8)


def cyc(M, floor_z=0.0, depth_y=60, radius=40, width=500, turn=0.0):
    """Seamless studio sweep: floor up to +Y, curving into a wall."""
    prof = [(-400, floor_z), (depth_y, floor_z)]
    for i in range(1, 17):
        a = math.pi / 2 * i / 16
        prof.append((depth_y + radius * math.sin(a),
                     floor_z + radius * (1 - math.cos(a))))
    prof.append((depth_y + radius, floor_z + 400))
    verts, faces = [], []
    for y, z in prof:
        verts += [(-width / 2, y, z), (width / 2, y, z)]
    for i in range(len(prof) - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    me = bpy.data.meshes.new('cyc')
    me.from_pydata(verts, [], faces)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(M['backdrop'])
    ob = link(bpy.data.objects.new('cyc', me))
    ob.rotation_euler = (0, 0, math.radians(turn))
    return ob


def camera(loc, target, lens=50, roll=0.0):
    c = bpy.data.cameras.new('cam')
    c.lens = lens
    o = link(bpy.data.objects.new('cam', c))
    o.location = loc
    d = Vector(target) - Vector(loc)
    q = d.to_track_quat('-Z', 'Y') @ Quaternion((0, 0, 1), math.radians(roll))
    o.rotation_euler = q.to_euler()
    bpy.context.scene.camera = o
    return o


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 20 if QUICK else 192
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 880
    sc.render.resolution_percentage = 50 if QUICK else 100
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = 'AgX - Base Contrast'
    except Exception:
        pass
    # The installed NVIDIA driver is too old for Blender 5.2's CUDA kernels,
    # so render on the CPU.
    sc.cycles.device = 'CPU'
    sc.render.threads_mode = 'AUTO'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = OUT


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- scenes

RELAXED = {
    'Idx': (12, 18, 10), 'Mid': (14, 22, 12), 'Rng': (16, 25, 14),
    'Pnk': (18, 28, 15),
    'thumb': dict(yaw=24, pitch=38, roll=-60, a_mcp=14, a_ip=12),
}


def scene_test(M):
    cyc(M, floor_z=-4)
    root, _ = make_hand(M, 'R', RELAXED)
    root.location = (0, 0, 2)
    studio()
    view = ARGV[2] if len(ARGV) > 2 and ARGV[2] != 'quick' else 'side'
    if view == 'top':
        camera((5, 18, 30), (5, 0, 0), lens=50)
    else:
        camera((6, -30, 22), (4, 0, 0), lens=50)


def scene_grip(M):
    cyc(M, floor_z=-9)
    wrap = 'pinch' not in ARGV
    pose, butt, u = grip_pose(wrap=wrap)
    root, _ = make_hand(M, 'R', pose)
    st = make_stick(M)
    st.parent = root
    place_along(st, butt, u)
    ring = add_ring(M, root, butt + u * (STICK_L / 3), u)
    studio()
    view = ARGV[2] if len(ARGV) > 2 else 'a'
    cams = {
        'a': ((2, 26, 10), (7, 3, -2), 55),       # thumb side
        'b': ((22, -14, 6), (7, 0, -2), 55),      # knuckle / front side
        'c': ((6, 0, -30), (7, 1, -2), 55),       # from below
        'd': ((-8, -4, 22), (7, 1, -2), 50),      # from above/behind
    }
    loc, tgt, lens = cams[view]
    camera(loc, tgt, lens)


def add_ring(M, parent, center, u):
    bpy.ops.mesh.primitive_torus_add(major_radius=STICK_R + 0.05,
                                     minor_radius=0.13,
                                     major_segments=64, minor_segments=16)
    t = bpy.context.active_object
    t.data.materials.append(M['coral'])
    for pl in t.data.polygons:
        pl.use_smooth = True
    q = Vector(u).to_track_quat('Z', 'Y')
    t.matrix_basis = Matrix.Translation(center) @ q.to_matrix().to_4x4()
    t.parent = parent
    return t


# ---------------------------------------------------------------- props

def rounded_cylinder(name, radius, depth, z, mat, bevel):
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=radius,
                                        depth=depth, location=(0, 0, z))
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    b = ob.modifiers.new('bevel', 'BEVEL')
    b.width = bevel
    b.segments = 5
    b.limit_method = 'ANGLE'
    b.harden_normals = True
    return ob


PAD_TOP = 2.7


def make_pad(M, loc=V(0, 0, 0)):
    root = link(bpy.data.objects.new('pad', None))
    for p in (rounded_cylinder('padBase', 15.2, 1.9, 0.95, M['pad_base'], 0.45),
              rounded_cylinder('padRim', 15.26, 0.36, 1.05, M['coral_matte'], 0.1),
              rounded_cylinder('padTop', 13.2, 0.8, 2.3, M['pad_top'], 0.3)):
        p.parent = root
    root.location = loc
    return root


def place_hand(root, F_hand, u_hand, F_world, w_dir, up=V(0, 0, 1), mirror=False):
    """Moves a hand root so the hand-space fulcrum and stick direction land
    on the world fulcrum and direction, with the back of the hand toward
    `up`. A mirrored (left) hand is flipped across its own XZ plane first."""
    S = Matrix.Diagonal((1, -1 if mirror else 1, 1, 1))
    Fh = (S @ F_hand.to_4d()).to_3d()
    e1 = (S.to_3x3() @ u_hand).normalized()
    e3 = (V(0, 0, 1) - e1 * e1.z).normalized()
    e2 = e3.cross(e1)
    f1 = Vector(w_dir).normalized()
    f3 = (Vector(up) - f1 * Vector(up).dot(f1)).normalized()
    f2 = f3.cross(f1)
    R = Matrix((f1, f2, f3)).transposed() @ Matrix((e1, e2, e3))
    t = Vector(F_world) - R @ Fh
    root.matrix_basis = Matrix.Translation(t) @ R.to_4x4() @ S


def gripping_hand(M, name, pose, butt, u, ring=False):
    root, _ = make_hand(M, name, pose)
    st = make_stick(M, name + 'Stick')
    st.parent = root
    place_along(st, butt, u)
    if ring:
        add_ring(M, root, butt + u * (STICK_L / 3), u)
    return root


def arrow(M, pts, radius=0.22, head=1.1):
    """A coral tube through `pts`, ending in a cone at the last point."""
    cu = bpy.data.curves.new('arrow', 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    sp = cu.splines.new('POLY')
    body = pts[:-1]
    sp.points.add(len(body) - 1)
    for k, q in enumerate(body):
        sp.points[k].co = (q.x, q.y, q.z, 1)
    cu.materials.append(M['coral'])
    link(bpy.data.objects.new('arrow', cu))
    tip, prev = pts[-1], pts[-2]
    d = (tip - prev).normalized()
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=radius * 2.8,
                                    radius2=0, depth=head)
    cone = bpy.context.active_object
    cone.data.materials.append(M['coral'])
    cone.matrix_basis = (Matrix.Translation(prev + d * head / 2)
                         @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4())


def slab(M, x0, x1, y, mat, h=0.08, w=0.6, z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    b = bpy.context.active_object
    b.scale = (x1 - x0, w, h)
    b.location = ((x0 + x1) / 2, y, z + h / 2)
    b.data.materials.append(mat)
    bv = b.modifiers.new('bv', 'BEVEL')
    bv.width = min(h, w) * 0.45
    bv.segments = 3
    return b


# ---------------------------------------------------------------- final scenes

def view_arg(default):
    rest = [a for a in ARGV[2:] if a not in ('quick', 'pinch')]
    return rest[0] if rest else default


def scene_1(M):
    """A lone stick lying on the floor, the fulcrum ringed at one third, a
    floor ruler split into thirds underneath."""
    cyc(M, floor_z=0, depth_y=30)
    L = STICK_L
    x0 = -L / 2
    third = x0 + L / 3
    st = make_stick(M)
    place_along(st, V(x0, 0, STICK_R), V(1, 0, 0))
    add_ring(M, None, V(third, 0, STICK_R), V(1, 0, 0))
    y = -3.4
    slab(M, x0, third - 0.15, y, M['coral_matte'])
    slab(M, third + 0.15, x0 + 2 * L / 3 - 0.15, y, M['muted'])
    slab(M, x0 + 2 * L / 3 + 0.15, x0 + L, y, M['muted'])
    for x, mat in ((x0, M['coral_matte']), (third, M['coral_matte']),
                   (x0 + 2 * L / 3, M['muted']), (x0 + L, M['muted'])):
        slab(M, x - 0.2, x + 0.2, y, mat, h=0.12, w=1.8)
    studio(key_dir=(-0.35, 0.45, -0.8), key=4.0, rim_dir=(0.2, -0.9, -0.4), rim=1.2)
    camera((0.5, -40, 18), (0.5, 3.5, -1.0), lens=31)


def scene_2(M):
    """Close-up of the pinch: thumb pad and index finger on the fulcrum,
    the back fingers still open."""
    cyc(M, floor_z=-9)
    pose, butt, u = grip_pose(wrap=False)
    gripping_hand(M, 'R', pose, butt, u, ring=True)
    studio()
    cams = {
        'a': ((14, 20, 12), (8.5, 3, -2), 50),
        'b': ((6, 22, 2), (8.5, 3, -2.5), 50),
        'c': ((22, 12, 9), (8.5, 2.5, -2), 50),
    }
    loc, tgt, lens = cams[view_arg('a')]
    camera(loc, tgt, lens)


def scene_3(M):
    """The whole hand: back fingers resting around the stick."""
    cyc(M, floor_z=-9)
    pose, butt, u = grip_pose(wrap=True)
    gripping_hand(M, 'R', pose, butt, u)
    studio()
    cams = {
        'a': ((22, -14, 6), (6, 0, -2), 50),
        'b': ((24, -6, 14), (6, 0.5, -2), 48),
    }
    loc, tgt, lens = cams[view_arg('a')]
    camera(loc, tgt, lens)


def scene_4(M):
    """Player's view: both hands palms-down, the sticks a V over the pad."""
    cyc(M, floor_z=0, depth_y=60)
    make_pad(M)
    pose, butt, u = grip_pose(wrap=True)
    F, _ = grip_line()
    for side in (1, -1):
        root = gripping_hand(M, 'R' if side > 0 else 'L', pose, butt, u)
        tip = V(side * 1.3, 2.0, PAD_TOP + 1.8)
        w = V(-side * 0.72, 0.70, -0.12).normalized()
        place_hand(root, F, u, tip - w * (STICK_L * 2 / 3), w, mirror=side < 0)
    studio(key_dir=(-0.3, 0.5, -0.8), key=4.2, rim_dir=(0.4, -0.8, -0.45), rim=1.6)
    loc, tgt, lens = {'a': ((0, -52, 42), (0, -13, 4), 38),
                      'b': ((0, -46, 48), (0, -9, 4), 24)}[view_arg('a')]
    camera(loc, tgt, lens)


def scene_5(M):
    """Side view of a stroke: the tip on the pad and a ghost of the stick
    rebounding around the fulcrum."""
    cyc(M, floor_z=0, depth_y=25, turn=90 if view_arg('b') == 'b' else -90)
    make_pad(M, V(0, 6, 0))
    pose, butt, u = grip_pose(wrap=True)
    F, _ = grip_line()
    root = gripping_hand(M, 'R', pose, butt, u)
    down = math.radians(-8)
    w = V(0, math.cos(down), math.sin(down))
    tip = V(0, 4.0, PAD_TOP + 0.45)
    Fw = tip - w * (STICK_L * 2 / 3)
    place_hand(root, F, u, Fw, w)

    up = math.radians(26)
    wg = V(0, math.cos(down + up), math.sin(down + up))
    g = make_stick(M, 'ghost', ghost(M['wood'], 0.3))
    place_along(g, Fw - wg * (STICK_L / 3), wg)
    Rr = STICK_L * 2 / 3 + 1.6
    pts = []
    for k in range(29):
        a = down + math.radians(3) + (up - math.radians(6)) * k / 28
        pts.append(Fw + V(0, math.cos(a), math.sin(a)) * Rr + V(-2.5, 0, 0))
    arrow(M, pts, radius=0.26, head=1.6)
    studio(key_dir=(0.5, 0.35, -0.8), key=4.2, rim_dir=(-0.3, -0.8, -0.5), rim=1.6)
    side = view_arg('b')
    if side == 'a':
        camera((-50, -11, 15), (0, -11, 8), 40)
    else:
        camera((54, -8, 15), (0, -8, 7), 30)


SCENES = {'test': scene_test, 'grip': scene_grip, '1': scene_1, '2': scene_2,
          '3': scene_3, '4': scene_4, '5': scene_5}


def main():
    reset()
    M = materials()
    SCENES[SCENE](M)
    setup_render()
    bpy.ops.render.render(write_still=True)


main()
