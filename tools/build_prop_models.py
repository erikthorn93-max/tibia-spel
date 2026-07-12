# Bygger miljöprops (assets/models3d/prop_*.glb) proceduralt: låg-poly-
# primitiver med platta Principled-material (inga texturer) i världsskala
# med fötterna på golvet — samma konventioner som stationsbyggaren.
#
# prop_door: trädörr i stenkarm för husens entrance-rutor (Zone3D:s dörr-
# markör). Dörrbladet spänner X-axeln (vrids av vyn efter väggriktningen),
# höjden hålls under vägghöjden 2,0 m.
#
# Kör: blender --background --python tools/build_prop_models.py

import bpy
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(ROOT, "assets", "models3d")

# ── Materialpalett (namn → basfärg, metallic, roughness, emission) ────────────
# Metallic hålls ≤ ~0,4 (1,0 blir svart i Godot utan reflektionsmiljö) och
# emission ≤ ~1,5 (bränns annars ut till vitt) — lärdomarna från stationerna.
PALETTE = {
    "iron":       ((0.13, 0.13, 0.15, 1), 0.4, 0.45, None),
    "wood":       ((0.42, 0.27, 0.13, 1), 0.0, 0.85, None),
    "dark_wood":  ((0.28, 0.17, 0.08, 1), 0.0, 0.9, None),
    "stone":      ((0.45, 0.44, 0.42, 1), 0.0, 0.95, None),
    "dark_stone": ((0.22, 0.22, 0.23, 1), 0.0, 0.95, None),
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


# ── Propsen ───────────────────────────────────────────────────────────────────
def build_door():
    """Stängd trädörr i stenkarm — spänner X, tunn i Y, 1,66 m hög."""
    parts = []
    # Stenkarm: två poster + överliggare
    for sx_ in (-1, 1):
        parts.append(box("stone", 0.14, 0.18, 1.50, x=sx_ * 0.42))
    parts.append(box("stone", 0.98, 0.18, 0.16, z=1.50))
    # Dörrbladet (mörkt trä) med två ljusare plankband
    parts.append(box("dark_wood", 0.70, 0.08, 1.44, z=0.03))
    for zx_ in (0.38, 1.05):
        parts.append(box("wood", 0.72, 0.10, 0.10, z=zx_))
    # Järnbeslag: gångjärnsband + handtag
    for zh_ in (0.30, 1.18):
        parts.append(box("iron", 0.74, 0.11, 0.04, z=zh_))
    parts.append(cyl("iron", 0.035, 0.05, x=0.24, y=-0.07, z=0.78,
                     verts=8, rx=math.pi / 2))
    return parts


PROPS = {
    "door": build_door,
}


def main():
    for name, build in PROPS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _mats.clear()
        parts = build()
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = "prop_%s" % name
        out = os.path.join(DST, "prop_%s.glb" % name)
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            export_yup=True,
            export_apply=True,
        )
        kb = os.path.getsize(out) / 1024.0
        print("KLAR prop_%s: %.0f kB" % (name, kb))


main()
