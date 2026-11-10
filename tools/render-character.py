# Renders an animated Blender character into an oriented sprite sheet (BGE.DrawableOrientedSprite)
# for a third-person camera: every frame from every direction on a turntable, from a fixed camera
# angle. Run with Blender 5.x:
#
#   Blender -b <character>.blend --python tools/render-character.py -- \
#     --config <game>/tools/characters.py --character knight --out <somewhere>/knight.webp \
#     [--parts <folder>] [--directions 16] [--height 64] [--packed] [--mirror] [--test]
#
# --config is a Python file defining CHARACTERS, a dict of character name -> settings. It can
# call inbetweens(start, end, count), which this script provides.
#   animations: [(animation, source action frames)]; fractional frames are in-betweens
#   size: the camera's view in Blender units, enough for the widest swing
#   parts (optional): objects from other files (object name -> file in --parts)
#   layers (optional): which of the file's layers ("Collection N") to render, if not all of them
#   hide (optional): objects not to render
#   colours (optional): material -> colour (linear RGB), replacing its RGB node and texture colours
#   platform (optional): the turntable object the character stands on (default "RenderPlatform")
#   lamp (optional): the key light (default "Lamp"; a sun is added if the file has none)
# An object with a material named "ShadowCatcher" catches the ground shadow.
# See examples/thirdPerson/tools/characters.py.
#
# --packed trims every frame to its own pixels and packs them into sheets of at most
# --sheet-size px (knight.webp, knight_1.webp, ...), with knight.json listing each frame's rect and
# offset, for AssetLoader.loadSpriteAtlas() and Game.getSpriteAtlasFrames(). Much less texture
# than the grid.
# --mirror renders only the front-to-back half (9 of 16 directions) for
# DrawableOrientedSprite.mirrorBuckets, which draws the other side flipped.
#
# Cells are row-major, front first then clockwise viewed from above (DrawableOrientedSprite's
# bucket order). Each direction's frames follow on from the last, wrapping at --columns
# (default: one row per direction). Prints the cell size and feet anchor. Rendered frames are
# kept next to the sheet (per character and height, but not colour: clear them after a
# colour change), so a re-run only renders frames it doesn't have.
import argparse
import json
import math
import os
import runpy
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


def inbetweens(start, end, count):
    """count frames evenly spaced from start to end, both included"""
    return [round(start + (end - start) * i / (count - 1), 3) for i in range(count)]


def load_characters(path):
    """The CHARACTERS dict from a --config file"""
    characters = runpy.run_path(path, init_globals={"inbetweens": inbetweens}).get("CHARACTERS")
    if not isinstance(characters, dict) or not characters:
        sys.exit("%s doesn't define a CHARACTERS dict" % path)
    for name, character in characters.items():
        missing = [key for key in ("animations", "size") if key not in character]
        if missing:
            sys.exit("%s: character %s has no %s" % (path, name, ", ".join(missing)))
    return characters


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--config", required=True, help="Python file defining CHARACTERS")
    p.add_argument("--character", required=True)
    p.add_argument("--parts", help="folder with the parts files, for characters that have them")
    p.add_argument("--out", required=True)
    p.add_argument("--directions", type=int, default=16)
    p.add_argument("--columns", type=int, default=0, help="cells per sheet row (default: a row per direction)")
    p.add_argument("--height", type=int, default=64, help="pixels per --reference-height Blender units")
    p.add_argument("--reference-height", type=float, default=1.8, help="Blender units that --height pixels cover (e.g. the hero's height)")
    p.add_argument("--elevation", type=float, default=12, help="camera degrees above horizontal")
    p.add_argument("--samples", type=int, default=24)
    p.add_argument("--test", action="store_true", help="render the first frame of every direction only")
    p.add_argument("--packed", action="store_true", help="trim and pack frames, writing a .json frame list")
    p.add_argument("--mirror", action="store_true", help="render front to back only (directions / 2 + 1), for DrawableOrientedSprite.mirrorBuckets")
    p.add_argument("--sheet-size", type=int, default=2048, help="largest packed sheet width/height")
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


def find_platform(character):
    name = character.get("platform", "RenderPlatform")
    platform = bpy.data.objects.get(name)
    if platform is None:
        sys.exit("No turntable object named %s to stand the character on (set 'platform' in the config)" % name)
    return platform


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

    lamp = bpy.data.objects.get(character.get("lamp", "Lamp"))
    if lamp is None:
        lamp = bpy.data.objects.new("RenderLamp", bpy.data.lights.new("RenderLamp", "SUN"))
        sc.collection.objects.link(lamp)
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
    pixels = int(round(args.height * cam.data.ortho_scale / args.reference_height))
    sc.render.resolution_x = sc.render.resolution_y = pixels
    return sc, cam


def render_frames(sc, cam, args, character, frame_dir, platform):
    frames = [f for _, fs in character["animations"] for f in fs]
    if args.test:
        frames = frames[:1]
    paths = []
    rendered = args.directions // 2 + 1 if args.mirror else args.directions
    for d in range(rendered):
        # The character faces the camera at 0; turning it counter-clockwise puts the camera
        # clockwise round from its front, which is bucket d
        platform.rotation_euler = (0, 0, math.radians(d * 360.0 / args.directions))
        row = []
        for f in frames:
            path = os.path.join(frame_dir, "d%02d_f%07.3f.png" % (d, f))
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


# Sheets are lossy WebP (alpha stays lossless) to keep the channel under Roku's 4 MB limit
def save_webp(pixels, path):
    h, w = pixels.shape[:2]
    img = bpy.data.images.new("sheet", w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(pixels).ravel())
    img.filepath_raw = path
    img.file_format = "WEBP"
    img.save(quality=90)
    bpy.data.images.remove(img)


def opaque_box(alpha):
    ys, xs = np.nonzero(alpha > 0.03)
    if len(ys) == 0:
        return 0, 1, 0, 1
    return ys.min(), ys.max() + 1, xs.min(), xs.max() + 1


def pack(paths, feet, out, columns, animations, packed, sheet_size):
    cells = [load_rgba(p) for row in paths for p in row]
    # Drop the faint edge of the ground shadow, which otherwise pads every cell to the full render
    for cell in cells:
        cell[cell[:, :, 3] < 0.1] = 0
    per_direction = len(paths[0])
    alpha = np.max(np.stack([c[:, :, 3] for c in cells]), axis=0)
    y0, y1, x0, x1 = opaque_box(alpha)
    cw, ch = x1 - x0, y1 - y0
    cells = [cell[y0:y1, x0:x1] for cell in cells]
    fx, fy = feet[0] - x0, feet[1] - y0
    if packed:
        texture = pack_trimmed(cells, cw, ch, out, sheet_size)
        print("PACKED %s cell %dx%d, %d directions x %d frames, anchor (%.3f, %.3f), %.1f MB texture" % (
            out, cw, ch, len(paths), per_direction, fx / cw, fy / ch, texture / 1048576))
    else:
        cols = columns or per_direction
        rows = (len(cells) + cols - 1) // cols
        sheet = np.zeros((rows * ch, cols * cw, 4), dtype=np.float32)
        for i, cell in enumerate(cells):
            r, c = divmod(i, cols)
            sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = cell
        save_webp(sheet, out)
        print("SHEET %s %dx%d cell %dx%d, %d directions x %d frames, %d columns, anchor (%.3f, %.3f), %.1f MB texture" % (
            out, cols * cw, rows * ch, cw, ch, len(paths), per_direction, cols, fx / cw, fy / ch, cols * cw * rows * ch * 4 / 1048576))
    offset = 0
    for name, fs in animations:
        print("ANIM %s frames %d-%d" % (name, offset, offset + len(fs) - 1))
        offset += len(fs)


# Trims each cell to its opaque pixels and shelf-packs them, tallest first, into as many
# sheet_size sheets as it takes. Writes the sheets and a .json frame list next to `out`, in
# frame order. Returns the total texture bytes.
def pack_trimmed(cells, cw, ch, out, sheet_size):
    trimmed = []
    for cell in cells:
        ty0, ty1, tx0, tx1 = opaque_box(cell[:, :, 3])
        trimmed.append((cell[ty0:ty1, tx0:tx1], int(tx0), int(ty0)))
    placed = [None] * len(trimmed)
    sheet, x, y, shelf = 0, 0, 0, 0
    sizes = [[0, 0]]
    for i in sorted(range(len(trimmed)), key=lambda k: -trimmed[k][0].shape[0]):
        h, w = trimmed[i][0].shape[:2]
        if x + w > sheet_size:
            x, y, shelf = 0, y + shelf, 0
        if y + h > sheet_size:
            sheet, x, y, shelf = sheet + 1, 0, 0, 0
            sizes.append([0, 0])
        placed[i] = (sheet, x, y)
        sizes[sheet] = [max(sizes[sheet][0], x + w), max(sizes[sheet][1], y + h)]
        x, shelf = x + w, max(shelf, h)
    base, _ = os.path.splitext(out)
    sheets = [np.zeros((h, w, 4), dtype=np.float32) for w, h in sizes]
    frames = []
    for i, (pixels, ox, oy) in enumerate(trimmed):
        s, px, py = placed[i]
        h, w = pixels.shape[:2]
        sheets[s][py:py + h, px:px + w] = pixels
        frames.append({"sheet": s, "x": px, "y": py, "width": w, "height": h,
                       "offsetX": ox, "offsetY": oy, "sourceWidth": int(cw), "sourceHeight": int(ch)})
    names = []
    for s, pixels in enumerate(sheets):
        path = out if s == 0 else "%s_%d.webp" % (base, s)
        save_webp(pixels, path)
        names.append(os.path.basename(path))
    with open(base + ".json", "w") as f:
        json.dump({"sheets": names, "frames": frames}, f, separators=(",", ":"))
    return sum(w * h * 4 for w, h in sizes)


def main():
    args = parse_args()
    characters = load_characters(args.config)
    if args.character not in characters:
        sys.exit("No character %s in %s (it has %s)" % (args.character, args.config, ", ".join(sorted(characters))))
    character = characters[args.character]
    platform = find_platform(character)
    if character.get("parts"):
        if not args.parts:
            sys.exit("Character %s needs --parts, the folder with its parts files" % args.character)
        add_parts(character["parts"], args.parts, platform)
    choose_objects(character)
    recolour(character)
    sc, cam = setup_scene(args, character)
    out = os.path.abspath(args.out)
    frame_dir = os.path.join(os.path.dirname(out), "%s_%d_frames" % (args.character, args.height))
    os.makedirs(frame_dir, exist_ok=True)
    paths, feet = render_frames(sc, cam, args, character, frame_dir, platform)
    pack(paths, feet, out, args.columns, character["animations"], args.packed, args.sheet_size)


if __name__ == "__main__":
    main()
