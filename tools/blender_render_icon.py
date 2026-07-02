# blender_render_icon — headless rendering av en .glb till kvadratisk PNG-ikon.
# Anropas av generate-asset.js:
#   blender --background --python tools/blender_render_icon.py -- \
#     --glb <modell.glb> --out <ikon.png> --size 32
#
# Fast 3/4-vy (45° azimut, 30° elevation), ortografisk kamera, transparent
# bakgrund. Renderar i supersample (size×16) och skalar ner till size×size.
# Efterbehandling (outline/kontrast) görs av tools/postprocess_sprite.js.
import argparse
import math
import sys

import bpy
from mathutils import Vector

SUPERSAMPLE = 16  # render i size*16 → nedskalning ger mjuka men täta ikoner


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--size", type=int, default=32)
    return p.parse_args(argv)


def set_render_engine(scene):
    # Motornamnet varierar mellan Blender-versioner (EEVEE/EEVEE_NEXT).
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = engine
            return engine
        except TypeError:
            continue
    raise RuntimeError("ingen känd rendermotor tillgänglig")


def scene_bounds(objs):
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for ob in objs:
        for corner in ob.bound_box:
            wc = ob.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, wc))
            hi = Vector(map(max, hi, wc))
    return lo, hi


def main():
    args = parse_args()

    # Tom scen utan default-kub/-lampa/-kamera.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    bpy.ops.import_scene.gltf(filepath=args.glb)
    meshes = [ob for ob in scene.objects if ob.type == "MESH"]
    if not meshes:
        print("✖ inga mesh-objekt i GLB:n", file=sys.stderr)
        sys.exit(1)

    lo, hi = scene_bounds(meshes)
    center = (lo + hi) / 2
    dims = hi - lo
    max_dim = max(dims.x, dims.y, dims.z, 1e-6)

    # Kamera: fast 3/4-vy — 45° runt Z, 30° upp, ortografisk.
    azim, elev = math.radians(45.0), math.radians(30.0)
    direction = Vector((
        math.cos(elev) * math.sin(azim),
        -math.cos(elev) * math.cos(azim),
        math.sin(elev),
    ))
    cam_data = bpy.data.cameras.new("icon_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max_dim * 1.15   # liten marginal runt modellen
    cam_data.clip_end = max_dim * 100
    cam = bpy.data.objects.new("icon_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = center + direction * max_dim * 3
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Ljus: sol snett från kamerahållet + jämnt världsljus så texturer läses bra.
    sun_data = bpy.data.lights.new("icon_sun", type="SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("icon_sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(70))

    world = bpy.data.worlds.new("icon_world")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
        bg.inputs[1].default_value = 0.7

    engine = set_render_engine(scene)
    render_size = args.size * SUPERSAMPLE
    scene.render.resolution_x = render_size
    scene.render.resolution_y = render_size
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = args.out

    print(f"▶ renderar {render_size}×{render_size} med {engine} ...")
    bpy.ops.render.render(write_still=True)

    # Skala ner till slutstorleken.
    img = bpy.data.images.load(args.out)
    img.scale(args.size, args.size)
    img.save()
    print(f"✔ {args.out} ({args.size}×{args.size})")


if __name__ == "__main__":
    main()
