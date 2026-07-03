# Decimerar Meshy-GLB:erna i assets/_meshy_cache till spelfärdiga modeller i
# assets/models3d: polygonbudget, texturer nedskalade till 512px, höjd
# normaliserad till 1,0 m med fötterna på marken (y=0 i Godot).
#
# Körs headless:
#   blender --background --python tools/decimate_glb.py
#
# Skippar modeller som redan finns i utkatalogen — säkert att köra om.

import bpy
import glob
import os

SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "_meshy_cache")
DST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "models3d")
TEX_SIZE = 512
DEFAULT_TRIS = 3000

# Polygonbudget per modell (karaktärer får mer, vegetation mindre).
TARGETS = {
    "orc": 4000, "zombie": 4000, "skeleton": 4000, "king": 4000,
    "boy": 3500, "toddler": 3500, "middle_aged_man": 3500, "young_woman": 3500,
    "wolf": 3500, "bear": 3500, "rat": 3000, "rat_alt": 3000, "rabbit": 3000,
    "bush": 1500, "fern": 1500, "wildflower": 1500, "cactus": 1500,
    "fir_tree_short": 2000, "pine_stunted": 2000, "pine_tree_tall": 2000,
    "dead_tree": 2000, "mossy_rock": 1200, "treasure_chest": 2000,
    "stone_staircase": 2500, "stone_depot": 3000,
    "glowing_green": 1500, "emerald_sigil": 1500,
}


def tri_count():
    total = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            total += len(o.data.loop_triangles)
    return total


def process(path, out_path):
    name = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)

    before = tri_count()
    target = TARGETS.get(name, DEFAULT_TRIS)
    ratio = min(1.0, target / max(before, 1))
    if ratio < 1.0:
        for o in list(bpy.data.objects):
            if o.type != "MESH":
                continue
            bpy.context.view_layer.objects.active = o
            mod = o.modifiers.new("dec", "DECIMATE")
            mod.ratio = ratio
            bpy.ops.object.modifier_apply(modifier="dec")

    # Texturer: 512px räcker gott för 3/4-kameran och krymper filerna mest.
    for img in bpy.data.images:
        if img.size[0] > TEX_SIZE or img.size[1] > TEX_SIZE:
            img.scale(TEX_SIZE, TEX_SIZE)

    # Normalisera: höjd (Blender-Z → Godot-Y) = 1,0 och fötterna på golvet.
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if meshes:
        zs, xs, ys = [], [], []
        for o in meshes:
            for corner in o.bound_box:
                v = o.matrix_world @ __import__("mathutils").Vector(corner)
                xs.append(v.x)
                ys.append(v.y)
                zs.append(v.z)
        height = max(zs) - min(zs)
        if height > 0.0001:
            s = 1.0 / height
            cx = (max(xs) + min(xs)) / 2.0
            cy = (max(ys) + min(ys)) / 2.0
            zmin = min(zs)
            for o in meshes:
                if o.parent is None:
                    o.location.x = (o.location.x - cx) * s
                    o.location.y = (o.location.y - cy) * s
                    o.location.z = (o.location.z - zmin) * s
                    o.scale = o.scale * s

    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_image_format="AUTO",
        export_yup=True,
        export_apply=True,
    )
    after = tri_count()
    mb = os.path.getsize(out_path) / (1024 * 1024)
    print("KLAR %s: %d -> %d tris, %.1f MB" % (name, before, after, mb))


def main():
    os.makedirs(DST, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SRC, "*.glb"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if name.endswith("_preview"):
            continue
        out_path = os.path.join(DST, name + ".glb")
        if os.path.exists(out_path):
            print("SKIPPAR %s (finns redan)" % name)
            continue
        try:
            process(path, out_path)
        except Exception as e:  # en trasig modell ska inte stoppa resten
            print("FEL %s: %s" % (name, e))


main()
