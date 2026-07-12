# Bygger kreatursmodellerna (assets/models3d/creature_*.glb) proceduralt:
# fem arketyper (spindel/orm/fågel/padda/krabba) i färgvarianter — låg-poly-
# primitiver med platta Principled-material, samma konventioner som
# stationsbyggaren. Varje modell normaliseras till 1,0 m höjd med fötterna
# på z=0 och nosen mot Blender -Y (= glTF/Godot +Z, Monster3D vrider PI).
#
# Kör: blender --background --python tools/build_creature_models.py

import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(ROOT, "assets", "models3d")

_mats = {}


def mat(name, color, rough=0.8, metallic=0.0, emit=None):
    """Material per (variant, roll) — skapas en gång per export."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emit is not None:
        # Emission > ~1,5 bränns ut till vitt i Godot — håll styrkan låg.
        ec, es = emit
        bsdf.inputs["Emission Color"].default_value = ec
        bsdf.inputs["Emission Strength"].default_value = es
    _mats[name] = m
    return m


def sphere(m, r, x=0.0, y=0.0, z=0.0, sx=1.0, sy=1.0, sz=1.0, rx=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.rotation_euler.x = rx
    o.data.materials.append(m)
    return o


def cone(m, r, h, x=0.0, y=0.0, z=0.0, rx=0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=8, radius1=r, radius2=0, depth=h, location=(x, y, z))
    o = bpy.context.active_object
    o.rotation_euler.x = rx
    o.data.materials.append(m)
    return o


def cyl(m, r, h, x=0.0, y=0.0, z=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=r, depth=h, location=(x, y, z + h / 2))
    o = bpy.context.active_object
    o.data.materials.append(m)
    return o


def cyl_between(m, p1, p2, r):
    """Cylinder mellan två punkter — ben och antenner."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=r, depth=d.length, location=(p1 + p2) / 2)
    o = bpy.context.active_object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m)
    return o


# ── Arketyper (pal = roll → material) ─────────────────────────────────────────
def build_spider(pal):
    body, leg, eye = pal["body"], pal["accent"], pal["eye"]
    parts = [sphere(body, 0.32, y=0.20, z=0.42, sy=1.25, sz=0.95)]   # bakkropp
    parts.append(sphere(body, 0.20, y=-0.18, z=0.36))                # framkropp
    for sx_ in (-1, 1):
        parts.append(sphere(eye, 0.045, x=sx_ * 0.07, y=-0.36, z=0.40))
    for side in (-1, 1):
        for i in range(4):
            yb = -0.16 + i * 0.12
            hip = (side * 0.14, yb, 0.38)
            knee = (side * 0.44, yb - 0.02, 0.58)
            foot = (side * 0.64, yb + 0.04, 0.0)
            parts.append(cyl_between(leg, hip, knee, 0.030))
            parts.append(cyl_between(leg, knee, foot, 0.024))
    return parts


def build_snake(pal):
    """Hoprullad vilande orm (Tibia-posen): platt spiral, rest hals framtill."""
    body, head_m, eye = pal["body"], pal["accent"], pal["eye"]
    parts = []
    n = 34   # tätt längs spiralbanan så kroppen blir EN, inte ett pärlband
    for i in range(n):
        t = i / float(n - 1)
        theta = t * 2.2 * math.tau          # 2,2 varv utifrån och in
        rad = 0.42 - 0.26 * t
        r = 0.085 - 0.025 * t               # svansen smalnar inåt
        parts.append(sphere(body, r, x=rad * math.sin(theta),
                            y=-rad * math.cos(theta), z=r))
    for k in range(1, 5):                   # halsen reser sig ur yttervarvet
        parts.append(sphere(body, 0.075, y=-0.40 - 0.012 * k,
                            z=0.06 + 0.095 * k))
    parts.append(sphere(head_m, 0.115, y=-0.46, z=0.52, sy=1.3, sz=0.85))
    for sx_ in (-1, 1):
        parts.append(sphere(eye, 0.033, x=sx_ * 0.052, y=-0.55, z=0.55))
    return parts


def build_bird(pal):
    body, wing, beak, eye = pal["body"], pal["accent"], pal["beak"], pal["eye"]
    parts = [sphere(body, 0.28, z=0.52, sx=0.85, sy=1.15, sz=0.9, rx=0.25)]
    parts.append(sphere(body, 0.16, y=-0.24, z=0.80))                # huvud
    parts.append(cone(beak, 0.05, 0.16, y=-0.44, z=0.79, rx=-math.pi / 2))
    for sx_ in (-1, 1):
        parts.append(sphere(wing, 0.20, x=sx_ * 0.26, z=0.56,       # vingar
                            sx=0.35, sy=1.15, sz=0.75, rx=0.25))
        parts.append(sphere(eye, 0.035, x=sx_ * 0.08, y=-0.36, z=0.84))
        parts.append(cyl(pal["beak"], 0.020, 0.26, x=sx_ * 0.08, y=0.02))
    parts.append(sphere(wing, 0.12, y=0.30, z=0.62, sx=0.6, sy=1.3, sz=0.4,
                        rx=-0.5))                                    # stjärt
    return parts


def build_toad(pal):
    body, belly, eye = pal["body"], pal["accent"], pal["eye"]
    parts = [sphere(body, 0.36, z=0.30, sx=1.2, sy=1.15, sz=0.80)]
    parts.append(sphere(belly, 0.30, y=-0.04, z=0.20, sx=1.1, sy=1.0, sz=0.6))
    for sx_ in (-1, 1):
        parts.append(sphere(body, 0.10, x=sx_ * 0.16, y=-0.26, z=0.56))  # ögonbulor
        parts.append(sphere(eye, 0.05, x=sx_ * 0.16, y=-0.31, z=0.58))
        parts.append(sphere(body, 0.13, x=sx_ * 0.34, y=0.16, z=0.14,    # baklår
                            sy=1.3, sz=0.9))
        parts.append(cyl_between(body, (sx_ * 0.26, -0.24, 0.24),        # framben
                                 (sx_ * 0.30, -0.30, 0.0), 0.045))
    return parts


def build_crab(pal):
    shell, claw, eye = pal["body"], pal["accent"], pal["eye"]
    parts = [sphere(shell, 0.34, z=0.26, sx=1.35, sy=1.0, sz=0.60)]
    for sx_ in (-1, 1):
        parts.append(sphere(claw, 0.14, x=sx_ * 0.40, y=-0.30, z=0.20,   # klor
                            sx=1.25, sy=1.0, sz=0.8))
        parts.append(cone(claw, 0.055, 0.14, x=sx_ * 0.40, y=-0.44, z=0.22,
                          rx=-math.pi / 2))
        for i in range(3):
            yb = -0.10 + i * 0.16
            parts.append(cyl_between(shell, (sx_ * 0.38, yb, 0.22),
                                     (sx_ * 0.62, yb + 0.04, 0.0), 0.028))
        parts.append(cyl_between(shell, (sx_ * 0.10, -0.30, 0.38),       # ögonskaft
                                 (sx_ * 0.12, -0.36, 0.50), 0.022))
        parts.append(sphere(eye, 0.045, x=sx_ * 0.12, y=-0.37, z=0.52))
    return parts


# ── Varianter: arketyp + palett per roll ──────────────────────────────────────
BLACK_EYE = ((0.03, 0.03, 0.04, 1), 0.4)

VARIANTS = {
    "spider_brown": (build_spider, {
        "body": ((0.35, 0.22, 0.10, 1), 0.85), "accent": ((0.22, 0.13, 0.06, 1), 0.85),
        "eye": BLACK_EYE}),
    "spider_dark": (build_spider, {
        "body": ((0.13, 0.11, 0.16, 1), 0.8), "accent": ((0.08, 0.07, 0.11, 1), 0.8),
        "eye": ((0.7, 0.1, 0.1, 1), 0.5, 0.0, ((0.9, 0.15, 0.1, 1), 1.0))}),
    "spider_green": (build_spider, {
        "body": ((0.20, 0.40, 0.14, 1), 0.85), "accent": ((0.13, 0.27, 0.09, 1), 0.85),
        "eye": BLACK_EYE}),
    "snake_green": (build_snake, {
        "body": ((0.16, 0.45, 0.18, 1), 0.7), "accent": ((0.11, 0.32, 0.12, 1), 0.7),
        "eye": ((0.85, 0.75, 0.2, 1), 0.4)}),
    "snake_sand": (build_snake, {
        "body": ((0.65, 0.55, 0.30, 1), 0.85), "accent": ((0.50, 0.40, 0.20, 1), 0.85),
        "eye": BLACK_EYE}),
    "snake_blue": (build_snake, {
        "body": ((0.18, 0.35, 0.55, 1), 0.6), "accent": ((0.12, 0.24, 0.40, 1), 0.6),
        "eye": ((0.85, 0.75, 0.2, 1), 0.4)}),
    "snake_dark": (build_snake, {
        "body": ((0.10, 0.10, 0.13, 1), 0.7), "accent": ((0.06, 0.06, 0.09, 1), 0.7),
        "eye": ((0.7, 0.1, 0.1, 1), 0.5, 0.0, ((0.9, 0.15, 0.1, 1), 1.0))}),
    "snake_ember": (build_snake, {
        "body": ((0.9, 0.30, 0.05, 1), 0.8, 0.0, ((1.0, 0.30, 0.05, 1), 0.7)),
        "accent": ((0.5, 0.12, 0.03, 1), 0.8),
        "eye": ((1.0, 0.8, 0.2, 1), 0.5, 0.0, ((1.0, 0.8, 0.2, 1), 1.2))}),
    "bird_dark": (build_bird, {
        "body": ((0.10, 0.10, 0.13, 1), 0.8), "accent": ((0.06, 0.06, 0.09, 1), 0.8),
        "beak": ((0.55, 0.42, 0.15, 1), 0.6), "eye": ((0.8, 0.7, 0.2, 1), 0.4)}),
    "bird_white": (build_bird, {
        "body": ((0.88, 0.90, 0.94, 1), 0.85), "accent": ((0.72, 0.76, 0.84, 1), 0.85),
        "beak": ((0.55, 0.45, 0.2, 1), 0.6), "eye": BLACK_EYE}),
    "bird_brown": (build_bird, {
        "body": ((0.40, 0.28, 0.14, 1), 0.85), "accent": ((0.27, 0.18, 0.09, 1), 0.85),
        "beak": ((0.5, 0.4, 0.15, 1), 0.6), "eye": BLACK_EYE}),
    "toad_green": (build_toad, {
        "body": ((0.25, 0.45, 0.15, 1), 0.75), "accent": ((0.62, 0.66, 0.42, 1), 0.75),
        "eye": ((0.85, 0.65, 0.1, 1), 0.4)}),
    "crab_red": (build_crab, {
        "body": ((0.62, 0.20, 0.10, 1), 0.7), "accent": ((0.74, 0.28, 0.12, 1), 0.7),
        "eye": BLACK_EYE}),
    "crab_dark": (build_crab, {
        "body": ((0.20, 0.18, 0.24, 1), 0.7), "accent": ((0.28, 0.25, 0.32, 1), 0.7),
        "eye": ((0.7, 0.1, 0.1, 1), 0.5, 0.0, ((0.9, 0.15, 0.1, 1), 1.0))}),
}


def resolve_palette(name, spec):
    """Roll → material; spec-värden är (color, rough[, metallic[, emit]])."""
    out = {}
    for role, v in spec.items():
        color, rough = v[0], v[1]
        metallic = v[2] if len(v) > 2 else 0.0
        emit = v[3] if len(v) > 3 else None
        out[role] = mat("%s_%s" % (name, role), color, rough, metallic, emit)
    return out


def normalize(obj):
    """Höjd (Blender-Z) = 1,0, fötter på z=0, centrerad i x/y — som ombakningen."""
    xs, ys, zs = [], [], []
    for corner in obj.bound_box:
        v = obj.matrix_world @ Vector(corner)
        xs.append(v.x)
        ys.append(v.y)
        zs.append(v.z)
    height = max(zs) - min(zs)
    if height > 0.0001:
        s = 1.0 / height
        obj.location.x = (obj.location.x - (max(xs) + min(xs)) / 2.0) * s
        obj.location.y = (obj.location.y - (max(ys) + min(ys)) / 2.0) * s
        obj.location.z = (obj.location.z - min(zs)) * s
        obj.scale = obj.scale * s


def main():
    for name, (build, spec) in VARIANTS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _mats.clear()
        parts = build(resolve_palette(name, spec))
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = "creature_%s" % name
        normalize(obj)
        out = os.path.join(DST, "creature_%s.glb" % name)
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            export_yup=True,
            export_apply=True,
        )
        kb = os.path.getsize(out) / 1024.0
        print("KLAR creature_%s: %.0f kB" % (name, kb))


main()
