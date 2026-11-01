# Renders a character from the Flare Blender sources (see CREDITS.md) into an oriented sprite
# sheet for the third-person camera. Run with Blender 5.x, after re-saving the 2.49 sources in
# Blender 2.79 (newer Blender drops their animation):
#
#   Blender -b <converted>/steel_armor.blend --python tools/render-character.py -- \
#     --character knight --parts <converted> --out src/sprites/knight.png [--directions 16] [--height 64] [--test]
#
# Cells are row-major, front first then clockwise viewed from above (DrawableOrientedSprite's
# bucket order). Each direction's frames follow on from the last, wrapping at --columns
# (default: one row per direction). Prints the cell size and feet anchor. Rendered frames are
# kept next to the sheet (per character and height, but not colour: clear them after a
# colour change), so a re-run only renders frames it doesn't have.
import argparse
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

# animations: (animation, source action frames); fractional frames are in-betweens of the 2.49 keys
# parts: objects from other files (object name -> file)
# layers: which of the file's layers (now "Collection N") to render, if not all of them
# hide: objects not to render
# colours: material -> colour (linear RGB), replacing the base and texture colours convert-flare.py made
# size: the camera's view in Blender units, enough for the widest swing
# A darker, sickly green than the source's orange, with dark hair
ORC_COLOURS = {"Material.skin": (0.2, 0.25, 0.12), "Material.hair": (0.06, 0.04, 0.025)}

CHARACTERS = {
    "knight": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", [13, 13.5, 14, 14.5, 15, 15.5, 16]),
            ("block", [17, 18]),
        ],
        "parts": {"MaleHead1": "male_head1.blend", "Longsword": "longsword.blend", "HeavyShield": "shield.blend"},
        "size": 2.6,
    },
    # skeleton_0.blend
    "skeleton": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", [13, 13.6, 14.2, 14.8, 15.4, 16]),
            ("block", [17]),
            ("hit", [19]),
            ("die", [21, 23, 25, 27]),
        ],
        "hide": ["KingdomCrossbow"],
        "size": 3.6,
    },
    # orc_flare_0.blend, layer 2: hand axe, no armour
    "orc": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", [13, 13.6, 14.2, 14.8, 15.4, 16]),
            ("hit", [17]),
            ("die", [19, 21, 23, 24]),
        ],
        "layers": ["1", "2"],
        "colours": ORC_COLOURS,
        "size": 3.6,
    },
    # orc_flare_0.blend, layer 5: armour, shield and a bigger axe
    # Its overhead swing makes the cells tall, so fewer frames keep the sheet within 2048 px
    "orc-heavy": {
        "animations": [
            ("idle", [1, 3]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", [13, 13.6, 14.2, 14.8, 15.4, 16]),
            ("block", [30]),
            ("hit", [17]),
            ("die", [20, 24]),
        ],
        "layers": ["1", "5"],
        "colours": ORC_COLOURS,
        "size": 3.6,
    },
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", required=True, choices=sorted(CHARACTERS))
    p.add_argument("--parts", help="folder with the converted parts files, for characters that have them")
    p.add_argument("--out", required=True)
    p.add_argument("--directions", type=int, default=16)
    p.add_argument("--columns", type=int, default=0, help="cells per sheet row (default: a row per direction)")
    p.add_argument("--height", type=int, default=64, help="pixels per 1.8 Blender units (the knight's height)")
    p.add_argument("--elevation", type=float, default=12, help="camera degrees above horizontal")
    p.add_argument("--samples", type=int, default=24)
    p.add_argument("--test", action="store_true", help="render the first frame of every direction only")
    return p.parse_args(argv)


# Each part keeps its own copy of the rig (same animation), as in its source file, so
# bone-parented pieces stay in the hand. The copies ride on this file's turntable.
def add_parts(parts, parts_dir, platform):
    scene_objects = bpy.context.scene.collection.objects
    for name, filename in parts.items():
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


def choose_objects(character):
    layers = character.get("layers")
    if layers:
        for collection in bpy.data.collections:
            if collection.name.startswith("Collection "):
                collection.hide_render = collection.name.split()[-1] not in layers
    for name in character.get("hide", []):
        bpy.data.objects[name].hide_render = True


def recolour(character):
    for name, colour in character.get("colours", {}).items():
        for node in bpy.data.materials[name].node_tree.nodes:
            if node.type == "RGB":
                node.outputs["Color"].default_value = tuple(colour) + (1,)
            elif node.type in ("MIX", "MIX_RGB"):
                # Each texture's colour, mixed in over the base
                for socket in node.inputs:
                    if socket.type == "RGBA" and socket.name in ("B", "Color2") and not socket.is_linked:
                        socket.default_value = tuple(colour) + (1,)


def setup_scene(args, character):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = args.samples
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    # The ground: a separate plane in some files, the turntable itself in others
    for obj in bpy.data.objects:
        if any(slot.material and slot.material.name == "ShadowCatcher" for slot in obj.material_slots):
            obj.is_shadow_catcher = True

    world = sc.world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.55, 0.6, 0.7, 1)
    bg.inputs["Strength"].default_value = 1.2

    lamp = bpy.data.objects["Lamp"]
    lamp.data.energy = 4.5

    cam = sc.camera
    # Some files fly the camera round; ours stays put while the turntable turns
    cam.animation_data_clear()
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = character["size"]
    target = Vector((0, 0, 0.95))
    el = math.radians(args.elevation)
    cam.location = target + Vector((0, -math.cos(el), math.sin(el))) * 12
    cam.rotation_euler = (math.pi / 2 - el, 0, 0)
    # Light from the camera's upper left, so every direction is lit the same way
    lamp.rotation_euler = (math.radians(50), 0, math.radians(-35))
    pixels = int(round(args.height * cam.data.ortho_scale / 1.8))
    sc.render.resolution_x = sc.render.resolution_y = pixels
    return sc, cam


def render_frames(sc, cam, args, character, frame_dir):
    platform = bpy.data.objects["RenderPlatform"]
    frames = [f for _, fs in character["animations"] for f in fs]
    if args.test:
        frames = frames[:1]
    paths = []
    for d in range(args.directions):
        # The character faces the camera at 0; turning it counter-clockwise puts the camera
        # clockwise round from its front, which is bucket d
        platform.rotation_euler = (0, 0, math.radians(d * 360.0 / args.directions))
        row = []
        for f in frames:
            path = os.path.join(frame_dir, "d%02d_f%05.1f.png" % (d, f))
            if not os.path.exists(path):
                sc.frame_set(int(f), subframe=f - int(f))
                sc.render.filepath = path
                bpy.ops.render.render(write_still=True)
            row.append(path)
        paths.append(row)
    platform.rotation_euler = (0, 0, 0)
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


def pack(paths, feet, out, columns, animations):
    cells = [load_rgba(p) for row in paths for p in row]
    # Drop the faint edge of the ground shadow, which otherwise pads every cell to the full render
    for cell in cells:
        cell[cell[:, :, 3] < 0.1] = 0
    per_direction = len(paths[0])
    alpha = np.max(np.stack([c[:, :, 3] for c in cells]), axis=0)
    ys, xs = np.nonzero(alpha > 0.03)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    cw, ch = x1 - x0, y1 - y0
    cols = columns or per_direction
    rows = (len(cells) + cols - 1) // cols
    sheet = np.zeros((rows * ch, cols * cw, 4), dtype=np.float32)
    for i, cell in enumerate(cells):
        r, c = divmod(i, cols)
        sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = cell[y0:y1, x0:x1]
    img = bpy.data.images.new("sheet", cols * cw, rows * ch, alpha=True)
    img.pixels.foreach_set(np.flipud(sheet).ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    fx, fy = feet[0] - x0, feet[1] - y0
    print("SHEET %s %dx%d cell %dx%d, %d directions x %d frames, %d columns, anchor (%.3f, %.3f), %.1f MB texture" % (
        out, cols * cw, rows * ch, cw, ch, len(paths), per_direction, cols, fx / cw, fy / ch, cols * cw * rows * ch * 4 / 1048576))
    offset = 0
    for name, fs in animations:
        print("ANIM %s frames %d-%d" % (name, offset, offset + len(fs) - 1))
        offset += len(fs)


def main():
    args = parse_args()
    character = CHARACTERS[args.character]
    if character.get("parts"):
        add_parts(character["parts"], args.parts, bpy.data.objects["RenderPlatform"])
    choose_objects(character)
    recolour(character)
    sc, cam = setup_scene(args, character)
    out = os.path.abspath(args.out)
    frame_dir = os.path.join(os.path.dirname(out), "%s_%d_frames" % (args.character, args.height))
    os.makedirs(frame_dir, exist_ok=True)
    paths, feet = render_frames(sc, cam, args, character, frame_dir)
    pack(paths, feet, out, args.columns, character["animations"])


main()
