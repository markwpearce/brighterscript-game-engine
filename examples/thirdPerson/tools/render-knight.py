# Renders the Flare hero knight from Clint Bellanger's Blender sources into an oriented
# sprite sheet for the third-person camera. Run with Blender 5.x on the armor file, after
# re-saving the 2.49 sources in Blender 2.79 (newer Blender drops their animation):
#
#   Blender -b <converted>/steel_armor.blend --python tools/render-knight.py -- \
#     --parts <converted> --out src/sprites/knight16.png [--directions 16] [--height 80] [--test]
#
# Cells are row-major with one direction per row, front first then clockwise viewed from
# above (DrawableOrientedSprite's bucket order). Prints the cell size and feet anchor.
import argparse
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

# (animation, source action frames). Fractional frames are in-betweens of the 2.49 keys.
ANIMATIONS = [
    ("idle", [1, 2, 3, 4]),
    ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
    ("attack", [13, 13.5, 14, 14.5, 15, 15.5, 16]),
    ("block", [17, 18]),
]
# Parts from the other files: object name -> file
PARTS = {"MaleHead1": "male_head1.blend", "Longsword": "longsword.blend", "HeavyShield": "shield.blend"}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--parts", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--directions", type=int, default=16)
    p.add_argument("--height", type=int, default=80, help="character height in pixels")
    p.add_argument("--elevation", type=float, default=12, help="camera degrees above horizontal")
    p.add_argument("--samples", type=int, default=24)
    p.add_argument("--test", action="store_true", help="render frame 1 of every direction only")
    return p.parse_args(argv)


# Each part keeps its own copy of the rig (same animation), as in its source file, so
# bone-parented pieces stay in the hand. The copies ride on this file's turntable.
def add_parts(parts_dir, platform):
    scene_objects = bpy.context.scene.collection.objects
    for name, filename in PARTS.items():
        with bpy.data.libraries.load(os.path.join(parts_dir, filename), link=False) as (src, dst):
            dst.objects = [name]
        obj = dst.objects[0]
        scene_objects.link(obj)
        rig = obj.parent if obj.parent_type == "BONE" else next(m.object for m in obj.modifiers if m.type == "ARMATURE")
        if rig.name not in scene_objects:
            scene_objects.link(rig)
        if obj.parent is not None and obj.parent != rig:
            obj.parent = platform
        rig.parent = platform


def setup_scene(args):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = args.samples
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    shadow = bpy.data.objects["ShadowPlane"]
    shadow.is_shadow_catcher = True

    world = sc.world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.6, 0.7, 1)
    bg.inputs["Strength"].default_value = 1.2

    lamp = bpy.data.objects["Lamp"]
    lamp.data.energy = 4.5

    cam = sc.camera
    cam.data.type = "ORTHO"
    # Character is ~1.8 units tall; 2.6 leaves room for sword swings
    cam.data.ortho_scale = 2.6
    target = Vector((0, 0, 0.95))
    el = math.radians(args.elevation)
    cam.location = target + Vector((0, -math.cos(el), math.sin(el))) * 12
    cam.rotation_euler = (math.pi / 2 - el, 0, 0)
    # Light from the camera's upper left, so every direction is lit the same way
    lamp.rotation_euler = (math.radians(50), 0, math.radians(-35))
    pixels = int(round(args.height * cam.data.ortho_scale / 1.8))
    sc.render.resolution_x = sc.render.resolution_y = pixels
    return sc, cam


def render_frames(sc, cam, args, frame_dir):
    platform = bpy.data.objects["RenderPlatform"]
    frames = [f for _, fs in ANIMATIONS for f in fs]
    if args.test:
        frames = frames[:1]
    paths = []
    for d in range(args.directions):
        # The knight faces the camera at 0; turning him counter-clockwise puts the camera
        # clockwise round from his front, which is bucket d
        platform.rotation_euler = (0, 0, math.radians(d * 360.0 / args.directions))
        row = []
        for i, f in enumerate(frames):
            sc.frame_set(int(f), subframe=f - int(f))
            sc.render.filepath = os.path.join(frame_dir, "d%02d_f%02d.png" % (d, i))
            bpy.ops.render.render(write_still=True)
            row.append(sc.render.filepath)
        paths.append(row)
    sc.frame_set(1)
    feet = world_to_camera_view(sc, cam, Vector((0, 0, 0)))
    return paths, (feet.x * sc.render.resolution_x, (1 - feet.y) * sc.render.resolution_y)


def load_rgba(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    # Blender images are bottom-up
    return np.flipud(px.reshape(h, w, 4))


def pack(paths, feet, out):
    cells = [[load_rgba(p) for p in row] for row in paths]
    alpha = np.max(np.stack([c[:, :, 3] for row in cells for c in row]), axis=0)
    ys, xs = np.nonzero(alpha > 0.03)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    cw, ch = x1 - x0, y1 - y0
    rows, cols = len(cells), len(cells[0])
    sheet = np.zeros((rows * ch, cols * cw, 4), dtype=np.float32)
    for r, row in enumerate(cells):
        for c, cell in enumerate(row):
            sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = cell[y0:y1, x0:x1]
    img = bpy.data.images.new("sheet", cols * cw, rows * ch, alpha=True)
    img.pixels.foreach_set(np.flipud(sheet).ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    fx, fy = feet[0] - x0, feet[1] - y0
    print("SHEET %s %dx%d cell %dx%d, %d directions x %d frames, anchor (%.3f, %.3f), %.1f MB texture" % (
        out, cols * cw, rows * ch, cw, ch, rows, cols, fx / cw, fy / ch, cols * cw * rows * ch * 4 / 1048576))
    offset = 0
    for name, fs in ANIMATIONS:
        print("ANIM %s columns %d-%d" % (name, offset, offset + len(fs) - 1))
        offset += len(fs)


def main():
    args = parse_args()
    add_parts(args.parts, bpy.data.objects["RenderPlatform"])
    sc, cam = setup_scene(args)
    frame_dir = os.path.join(os.path.dirname(os.path.abspath(args.out)), "knight_frames")
    os.makedirs(frame_dir, exist_ok=True)
    paths, feet = render_frames(sc, cam, args, frame_dir)
    pack(paths, feet, os.path.abspath(args.out))


main()
