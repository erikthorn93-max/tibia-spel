# Bygger stationsmodellerna (assets/models3d/station_*.glb) proceduralt:
# låg-poly-primitiver med platta Principled-material (inga texturer) i
# världsskala med fötterna på golvet — samma konventioner som karaktärs-
# ombakningen (Blender Z-upp exporteras med export_yup till Godot Y-upp).
#
# Kör: blender --background --python tools/build_station_models.py

import bpy
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(ROOT, "assets", "models3d")

# ── Materialpalett (namn → basfärg, metallic, roughness, emission) ────────────
PALETTE = {
    "iron":        ((0.13, 0.13, 0.15, 1), 0.9, 0.45, None),
    "dark_iron":   ((0.08, 0.08, 0.09, 1), 0.8, 0.6, None),
    "wood":        ((0.42, 0.27, 0.13, 1), 0.0, 0.85, None),
    "dark_wood":   ((0.28, 0.17, 0.08, 1), 0.0, 0.9, None),
    "stone":       ((0.45, 0.44, 0.42, 1), 0.0, 0.95, None),
    "dark_stone":  ((0.22, 0.22, 0.23, 1), 0.0, 0.95, None),
    "marble":      ((0.85, 0.83, 0.78, 1), 0.0, 0.4, None),
    # Metaller hålls halvmetalliska: metallic 1,0 blir svart i Godot utan
    # reflektionsmiljö (ingen reflection probe i zonerna).
    "gold":        ((0.85, 0.65, 0.2, 1), 0.4, 0.4, None),
    # Emission > ~1,5 bränns ut till vitt — håll styrkan låg så kulören syns.
    "ember":       ((0.9, 0.3, 0.05, 1), 0.0, 0.8, ((1.0, 0.35, 0.05, 1), 1.5)),
    "flame":       ((1.0, 0.8, 0.3, 1), 0.0, 0.8, ((1.0, 0.75, 0.25, 1), 2.0)),
    "rune_glow":   ((0.55, 0.3, 0.9, 1), 0.0, 0.7, ((0.6, 0.3, 1.0, 1), 1.2)),
    "green_glass": ((0.2, 0.65, 0.35, 1), 0.0, 0.25, None),
    "purple_glass": ((0.5, 0.25, 0.65, 1), 0.0, 0.25, None),
    "candle":      ((0.92, 0.89, 0.8, 1), 0.0, 0.7, None),
}

_mats = {}


def mat(name):
    if name in _mats:
        return _mats[name]
    base, metallic, rough, emit = PALETTE[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emit is not None:
        color, strength = emit
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = strength
    _mats[name] = m
    return m


# ── Primitiver: location är centrum; z mäts från golvet (z=0) ─────────────────
def box(m, sx, sy, sz, x=0.0, y=0.0, z=0.0, rz=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.rotation_euler.z = rz
    o.data.materials.append(mat(m))
    return o


def cyl(m, r, h, x=0.0, y=0.0, z=0.0, verts=10, rx=0.0, ry=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=r, depth=h, location=(x, y, z + h / 2))
    o = bpy.context.active_object
    o.rotation_euler.x = rx
    o.rotation_euler.y = ry
    o.data.materials.append(mat(m))
    return o


def cone(m, r, h, x=0.0, y=0.0, z=0.0, verts=10, ry=0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r, radius2=0, depth=h, location=(x, y, z + h / 2))
    o = bpy.context.active_object
    o.rotation_euler.y = ry
    o.data.materials.append(mat(m))
    return o


def sphere(m, r, x=0.0, y=0.0, z=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.data.materials.append(mat(m))
    return o


def table(top_mat, leg_mat, w=0.9, d=0.6, h=0.75, top_t=0.06, leg_t=0.08):
    """Bordsskiva + fyra ben — grundstomme för borden."""
    parts = [box(top_mat, w, d, top_t, z=h - top_t)]
    lx = w / 2 - leg_t / 2 - 0.02
    ly = d / 2 - leg_t / 2 - 0.02
    for sx_, sy_ in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        parts.append(box(leg_mat, leg_t, leg_t, h - top_t, x=sx_ * lx, y=sy_ * ly))
    return parts


# ── Stationerna ───────────────────────────────────────────────────────────────
def build_anvil():
    parts = [cyl("dark_wood", 0.26, 0.28, verts=12)]           # stubbe
    parts.append(box("dark_iron", 0.30, 0.26, 0.10, z=0.28))   # fot
    parts.append(box("dark_iron", 0.18, 0.18, 0.14, z=0.38))   # midja
    parts.append(box("iron", 0.62, 0.24, 0.14, z=0.52))        # banslag
    parts.append(cone("iron", 0.09, 0.26, x=0.42, z=0.55,      # horn
                      ry=math.pi / 2))
    return parts


def build_stove():
    parts = [box("stone", 0.85, 0.75, 0.55)]                     # härden
    parts.append(box("dark_stone", 0.45, 0.10, 0.28, y=-0.36, z=0.10))  # mynning
    parts.append(box("ember", 0.33, 0.06, 0.16, y=-0.44, z=0.14))       # glöd
    pot = sphere("dark_iron", 0.22, z=0.72)                      # grytan
    pot.scale = (1.0, 1.0, 0.75)
    parts.append(pot)
    parts.append(cyl("dark_iron", 0.16, 0.05, z=0.83, verts=12))  # lock/rand
    return parts


def build_alchemy_table():
    parts = table("wood", "dark_wood")
    parts.append(cyl("green_glass", 0.07, 0.16, x=-0.22, y=0.05, z=0.75))
    parts.append(cone("purple_glass", 0.08, 0.20, x=0.10, y=-0.10, z=0.75))
    parts.append(sphere("green_glass", 0.06, x=0.28, y=0.12, z=0.81))
    parts.append(box("dark_wood", 0.16, 0.12, 0.05, x=0.28, y=0.12, z=0.75))
    return parts


def build_rune_altar():
    parts = [box("dark_stone", 0.80, 0.60, 0.14)]                # sockel
    parts.append(box("stone", 0.55, 0.42, 0.50, z=0.14))         # pelare
    parts.append(box("dark_stone", 0.72, 0.54, 0.10, z=0.64))    # topplatta
    parts.append(box("rune_glow", 0.30, 0.22, 0.03, z=0.74))     # runan
    return parts


def build_crafting_bench():
    parts = table("wood", "dark_wood", w=1.0, d=0.55, h=0.70)
    parts.append(box("dark_wood", 0.26, 0.26, 0.22, x=0.30, y=0.02, z=0.70))  # låda
    parts.append(cyl("iron", 0.035, 0.22, x=-0.25, y=-0.05, z=0.70,          # hammare
                     ry=math.pi / 2))
    parts.append(box("iron", 0.10, 0.07, 0.07, x=-0.36, y=-0.05, z=0.67))
    return parts


def build_prayer_altar():
    parts = [box("marble", 0.90, 0.55, 0.16)]                    # trappsteg
    parts.append(box("marble", 0.70, 0.45, 0.55, z=0.16))        # altarblock
    parts.append(box("gold", 0.78, 0.50, 0.06, z=0.71))          # guldskiva
    for sx_ in (-1, 1):
        parts.append(cyl("candle", 0.035, 0.16, x=sx_ * 0.28, z=0.77, verts=8))
        parts.append(cone("flame", 0.025, 0.07, x=sx_ * 0.28, z=0.93, verts=8))
    return parts


def build_workbench():
    parts = table("dark_wood", "dark_wood", w=1.05, d=0.60, h=0.80,
                  top_t=0.08, leg_t=0.11)
    parts.append(box("iron", 0.18, 0.14, 0.16, x=0.36, y=0.0, z=0.80))   # skruvstäd
    parts.append(cyl("iron", 0.025, 0.24, x=0.36, y=0.0, z=0.86,         # spak
                     rx=math.pi / 2))
    parts.append(box("wood", 0.30, 0.20, 0.06, x=-0.28, y=0.05, z=0.80))  # bräda
    return parts


STATIONS = {
    "anvil": build_anvil,
    "stove": build_stove,
    "alchemy_table": build_alchemy_table,
    "rune_altar": build_rune_altar,
    "crafting_bench": build_crafting_bench,
    "prayer_altar": build_prayer_altar,
    "workbench": build_workbench,
}


def main():
    for name, build in STATIONS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _mats.clear()
        parts = build()
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = "station_%s" % name
        out = os.path.join(DST, "station_%s.glb" % name)
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            export_yup=True,
            export_apply=True,
        )
        kb = os.path.getsize(out) / 1024.0
        print("KLAR station_%s: %.0f kB" % (name, kb))


main()
