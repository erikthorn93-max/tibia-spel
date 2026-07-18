# Bygger miljöprops proceduralt: låg-poly-primitiver med platta Principled-
# material (inga texturer) — samma konventioner som stationsbyggaren.
#
# Två grupper:
#  * PROPS (prop_*.glb, världsskala): dörren m.fl. — nya modeller.
#  * SCATTER (legacy-namn, 1 m-normaliserade med fötter på z=0): ersätter
#    Meshy-vegetationen/klippan som scattras i tusental. Perf-diagnosen
#    2026-07-13 visade 9 FPS i staden (RTX 4070 Ti) med Meshy-scattern —
#    utan klippscattern 193 FPS, utan all scatter 634 FPS. Låg-poly-
#    ersättarna (~100 tris/st, opaka material) är en ren asset-swap:
#    samma filnamn, samma normalisering, ingen kodändring.
#
# Kör: blender --background --python tools/build_prop_models.py

import bpy
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(ROOT, "assets", "models3d")

# ── Materialpalett (namn → basfärg, metallic, roughness, emission) ────────────
# Metallic hålls ≤ ~0,4 (1,0 blir svart i Godot utan reflektionsmiljö) och
# emission ≤ ~1,5 (bränns annars ut till vitt) — lärdomarna från stationerna.
PALETTE = {
    "iron":         ((0.13, 0.13, 0.15, 1), 0.4, 0.45, None),
    "wood":         ((0.42, 0.27, 0.13, 1), 0.0, 0.85, None),
    "dark_wood":    ((0.28, 0.17, 0.08, 1), 0.0, 0.9, None),
    "stone":        ((0.45, 0.44, 0.42, 1), 0.0, 0.95, None),
    "dark_stone":   ((0.22, 0.22, 0.23, 1), 0.0, 0.95, None),
    "bark":         ((0.35, 0.24, 0.13, 1), 0.0, 0.95, None),
    "bark_dark":    ((0.24, 0.16, 0.09, 1), 0.0, 0.95, None),
    "pine_green":   ((0.15, 0.34, 0.17, 1), 0.0, 0.95, None),
    "pine_dark":    ((0.10, 0.26, 0.14, 1), 0.0, 0.95, None),
    "pine_dusty":   ((0.29, 0.37, 0.21, 1), 0.0, 0.95, None),
    "moss":         ((0.22, 0.36, 0.16, 1), 0.0, 0.95, None),
    "rock_gray":    ((0.34, 0.33, 0.32, 1), 0.0, 0.95, None),
    "cactus_green": ((0.23, 0.45, 0.21, 1), 0.0, 0.9, None),
    "stem_green":   ((0.20, 0.40, 0.19, 1), 0.0, 0.95, None),
    "petal_yellow": ((0.92, 0.78, 0.25, 1), 0.0, 0.85, None),
    "petal_white":  ((0.90, 0.88, 0.80, 1), 0.0, 0.85, None),
    "fern_green":   ((0.13, 0.35, 0.15, 1), 0.0, 0.95, None),
    # Varmt glödande lampglas — emission väl under utbränningsgränsen ~1,5.
    "lamp_glass":   ((1.00, 0.85, 0.50, 1), 0.0, 0.30, ((1.0, 0.75, 0.35, 1.0), 1.2)),
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


def cone(m, r, h, x=0.0, y=0.0, z=0.0, verts=10, ry=0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r, radius2=0, depth=h, location=(x, y, z + h / 2))
    o = bpy.context.active_object
    o.rotation_euler.y = ry
    o.data.materials.append(mat(m))
    return o


def sphere(m, r, x=0.0, y=0.0, z=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=10, ring_count=6, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.data.materials.append(mat(m))
    return o


def ico(m, r, x=0.0, y=0.0, z=0.0, sx=1.0, sy=1.0, sz=1.0, jitter=0.0, seed=1):
    """Låg-poly-icosfär (subdiv 1, 80 tris) med seedat vertexbrus — klippor."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r,
                                          location=(x, y, z))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    if jitter > 0.0:
        rng = random.Random(seed)
        for v in o.data.vertices:
            v.co.x += rng.uniform(-jitter, jitter)
            v.co.y += rng.uniform(-jitter, jitter)
            v.co.z += rng.uniform(-jitter, jitter)
    o.data.materials.append(mat(m))
    return o


# ── Scatter-vegetationen (ersätter Meshy-modellerna, samma filnamn) ───────────
def build_mossy_rock():
    # rock_gray i stället för stone: scattrade klippfält läste som nästan
    # vita med standardstenen — grånas ned mot terrängpalettens klippton.
    parts = [ico("rock_gray", 0.50, z=0.42, sy=0.85, sz=0.75, jitter=0.06, seed=7)]
    parts.append(ico("moss", 0.34, z=0.72, sy=0.8, sz=0.35, jitter=0.04, seed=11))
    parts.append(ico("dark_stone", 0.22, x=0.45, y=0.15, z=0.18,
                     jitter=0.04, seed=13))
    return parts


def build_pine_tree_tall():
    parts = [cyl("bark", 0.06, 0.30, verts=8)]
    parts.append(cone("pine_green", 0.32, 0.42, z=0.22, verts=9))
    parts.append(cone("pine_green", 0.25, 0.38, z=0.50, verts=9))
    parts.append(cone("pine_dark", 0.17, 0.34, z=0.74, verts=9))
    return parts


def build_fir_tree_short():
    parts = [cyl("bark_dark", 0.07, 0.24, verts=8)]
    parts.append(cone("pine_dark", 0.40, 0.48, z=0.16, verts=9))
    parts.append(cone("pine_dark", 0.29, 0.44, z=0.50, verts=9))
    return parts


def build_pine_stunted():
    parts = [cyl("bark_dark", 0.08, 0.28, verts=8)]
    parts.append(cone("pine_dusty", 0.42, 0.62, z=0.24, verts=9))
    return parts


def build_dead_tree():
    parts = [cyl("bark_dark", 0.07, 0.80, verts=7)]
    parts.append(cone("bark_dark", 0.05, 0.22, z=0.78, verts=7))
    # Kala grenar: tunna cylindrar vinklade ut från stammen.
    for rz_, z_, ry_ in ((0.4, 0.52, 0.9), (2.5, 0.62, 1.1), (4.4, 0.44, 0.8)):
        b = cyl("bark_dark", 0.025, 0.34, z=z_, verts=6, ry=ry_)
        b.rotation_euler.z = rz_
        b.location.x += 0.14 * math.cos(rz_)
        b.location.y += 0.14 * math.sin(rz_)
        parts.append(b)
    return parts


def build_cactus():
    parts = [cyl("cactus_green", 0.12, 0.88, verts=8)]
    # Två armar: vågrätt utskott + lodrät topp, klassisk saguaro.
    for sx_, z_ in ((1, 0.48), (-1, 0.30)):
        parts.append(cyl("cactus_green", 0.065, 0.20, x=sx_ * 0.19, z=z_,
                         verts=7, ry=math.pi / 2))
        parts.append(cyl("cactus_green", 0.065, 0.30, x=sx_ * 0.30, z=z_,
                         verts=7))
    return parts


def build_wildflower():
    parts = []
    for x_, y_, head, tilt in ((0.0, 0.0, "petal_yellow", 0.0),
                               (0.18, 0.10, "petal_white", 0.25),
                               (-0.15, -0.08, "petal_yellow", -0.2)):
        s = cyl("stem_green", 0.018, 0.55, x=x_, y=y_, verts=6)
        s.rotation_euler.x = tilt
        parts.append(s)
        parts.append(sphere(head, 0.09, x=x_ - 0.10 * math.sin(tilt),
                            y=y_ + 0.10 * math.sin(tilt), z=0.60))
    return parts


def build_fern():
    parts = []
    for i in range(6):
        a = i * math.tau / 6.0
        blade = box("fern_green", 0.10, 0.52, 0.025,
                    x=0.20 * math.cos(a + math.pi / 2),
                    y=0.20 * math.sin(a + math.pi / 2), z=0.28)
        blade.rotation_euler = (0.55, 0.0, a)
        parts.append(blade)
    parts.append(cyl("stem_green", 0.03, 0.20, verts=6))
    return parts


def build_lantern():
    """Lyktstolpe i järn med varmt glödande lamphus — ~2,2 m hög.
    Emissivt glas (ingen ljuskälla — perf) som glimmar i skymningen."""
    parts = []
    parts.append(box("dark_stone", 0.22, 0.22, 0.10))              # stenfot
    parts.append(cyl("iron", 0.035, 1.82, z=0.10, verts=8))        # stolpe
    parts.append(box("iron", 0.16, 0.16, 0.05, z=1.90))            # lampfot
    parts.append(box("lamp_glass", 0.13, 0.13, 0.17, z=1.95))      # glashus
    parts.append(cone("iron", 0.15, 0.10, z=2.12, verts=8))        # plåttak
    return parts


def build_barrel():
    """Ektunna med järnband — 0,65 m hög, står vid husväggar."""
    parts = []
    parts.append(cyl("wood", 0.26, 0.62, verts=12))                # stomme
    for z in (0.08, 0.47):
        parts.append(cyl("iron", 0.275, 0.05, z=z, verts=12))      # järnband
    parts.append(cyl("dark_wood", 0.22, 0.03, z=0.62, verts=12))   # lock
    return parts


def build_crate():
    """Trälåda med mörka hörnreglar — 0,5 m kub."""
    parts = []
    parts.append(box("wood", 0.52, 0.52, 0.50))
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            parts.append(box("dark_wood", 0.07, 0.07, 0.52,
                             x=sx_ * 0.24, y=sy_ * 0.24))
    return parts


PROPS = {
    "door": build_door,
    "lantern": build_lantern,
    "barrel": build_barrel,
    "crate": build_crate,
}

## Exporteras under Meshy-modellernas gamla filnamn (ren asset-swap) och
## normaliseras till 1,0 m höjd med fötterna på z=0 — Zone3D/GatherNode3D:s
## h-värden gäller oförändrade.
SCATTER = {
    "mossy_rock": build_mossy_rock,
    "pine_tree_tall": build_pine_tree_tall,
    "fir_tree_short": build_fir_tree_short,
    "pine_stunted": build_pine_stunted,
    "dead_tree": build_dead_tree,
    "cactus": build_cactus,
    "wildflower": build_wildflower,
    "fern": build_fern,
}


def _normalize_height(obj):
    """Skala till exakt 1,0 m hög och flytta fötterna till z=0."""
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    zs = [c[2] for c in obj.bound_box]
    lo, hi = min(zs), max(zs)
    s = 1.0 / (hi - lo)
    obj.scale = (s, s, s)
    obj.location.z = -lo * s
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def _export(name, build, normalize):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    parts = build()
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.shade_flat()
    obj.name = name
    if normalize:
        _normalize_height(obj)
    out = os.path.join(DST, "%s.glb" % name)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
    )
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("KLAR %s: %.0f kB, %d tris" % (name, os.path.getsize(out) / 1024.0, tris))


def main():
    # Valfritt filter efter "--" på kommandoraden: bygg bara angivna modeller
    # (så en ny prop inte tvingar omexport av hela scatter-setet).
    import sys
    only = None
    if "--" in sys.argv:
        picked = sys.argv[sys.argv.index("--") + 1:]
        only = set(picked) if picked else None
    for name, build in PROPS.items():
        if only is not None and name not in only and ("prop_%s" % name) not in only:
            continue
        _export("prop_%s" % name, build, normalize=False)
    for name, build in SCATTER.items():
        if only is not None and name not in only:
            continue
        _export(name, build, normalize=True)


main()
