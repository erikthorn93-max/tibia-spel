# Bakar om EN karaktärsmodell från assets/_meshy_cache till assets/models3d
# med en pipeline som tål Meshy-källor med många lösa mesh-öar:
#   1. släpp föräldrar + join till ETT mesh-objekt
#   2. svetsa vertex (merge by distance) så öarna hänger ihop
#   3. decimera till budget (edge-collapse beter sig nu sammanhängande)
#   4. texturer till 512px, höjd normaliserad till 1,0 m, fötter på y=0
#
# Kör: blender --background --python tools/rebake_character.py -- <namn> <tris> [weld]
#   ex: blender --background --python tools/rebake_character.py -- middle_aged_man 8000 0.002

import bpy
import os
import sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "_meshy_cache")
DST = os.path.join(ROOT, "assets", "models3d")
TEX_SIZE = 512

argv = sys.argv[sys.argv.index("--") + 1:]
NAME = argv[0]
TARGET = int(argv[1]) if len(argv) > 1 else 8000
WELD = float(argv[2]) if len(argv) > 2 else 0.002


def tri_count():
    total = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            total += len(o.data.loop_triangles)
    return total


def main():
    src = os.path.join(SRC, NAME + ".glb")
    out = os.path.join(DST, NAME + ".glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    before = tri_count()

    # 1) Släpp föräldrar (behåll världstransform) och join:a till ETT objekt.
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        if o.parent is not None:
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Städa: armaturer/tomma noder behövs inte i den statiska exporten.
    for o in list(bpy.data.objects):
        if o is not obj:
            bpy.data.objects.remove(o, do_unlink=True)
    obj.modifiers.clear()

    # 2) Svetsa vertex så decimeringen ser EN sammanhängande yta.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=WELD)
    bpy.ops.object.mode_set(mode="OBJECT")
    welded = tri_count()

    # 3) Decimera till budget.
    ratio = min(1.0, TARGET / max(welded, 1))
    if ratio < 1.0:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier="dec")

    # 4) Texturer ned till 512px.
    for img in bpy.data.images:
        if img.size[0] > TEX_SIZE or img.size[1] > TEX_SIZE:
            img.scale(TEX_SIZE, TEX_SIZE)

    # Normalisera: höjd (Blender-Z → Godot-Y) = 1,0 och fötterna på golvet.
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

    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_image_format="AUTO",
        export_yup=True,
        export_apply=True,
    )
    mb = os.path.getsize(out) / (1024 * 1024)
    print("KLAR %s: %d tris -> svetsad %d -> %d tris, %.1f MB"
          % (NAME, before, welded, tri_count(), mb))


main()
