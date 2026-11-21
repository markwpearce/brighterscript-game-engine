#!/usr/bin/env python3
# Bakes a heightmap PNG and a colour PNG into a .bvox file for BGE.VoxelMaps.fromFile()
# (voxel terrain, BGE.DrawableVoxelTerrain). Python 3 standard library only.
#
#   python3 tools/voxel-map.py heights.png colors.png out.bvox \
#     [--edge wrap|flat] [--flat-height N] [--flat-color RRGGBB]
#
# heights.png: grayscale (or RGB, its red channel is used), 8 or 16 bits; black is height 0,
#   white 255. colors.png: the same size, any colour type. Up to 256 distinct colours are kept
#   exactly (palette in order of first appearance, row by row); more are reduced to 256 by
#   median cut. Alpha is ignored.
# Size: square, a power of 2 from 64 to 1024.
# --edge flat: past the map's edges is a floor at --flat-height in --flat-color (added to the
#   palette if it isn't in it). The default, wrap, repeats the map, so it should tile.
#
# Mip levels are baked in, with the same rules as BGE.VoxelMaps.fromArrays(): heights are the
# 2x2 average rounded down; colours the most common of each 2x2, a tie going to the first of
# the tied ones in the order (x, z), (x + 1, z), (x, z + 1), (x + 1, z + 1). Keep the two in step.
#
# --write-test-pngs DIR writes the 64x64 ramp/checker pair used to make the engine's test fixture
# (src/source/engine/voxel/VoxelMapTool.spec.bvox).

import argparse
import struct
import sys
import zlib

MAX_LEVELS = 6


def fail(message):
    sys.exit(f"voxel-map: {message}")


# --- PNG ---------------------------------------------------------------------------------------

def read_png(path):
    """Returns (width, height, rows), rows as lists of (r, g, b) tuples, 8 bits per channel."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as error:
        fail(f"can't read {path}: {error.strerror}")
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path} isn't a PNG")
    pos = 8
    idat = b""
    palette = []
    width = height = depth = color_type = None
    interlace = 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"PLTE":
            palette = [tuple(chunk[i:i + 3]) for i in range(0, len(chunk), 3)]
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    if interlace:
        fail(f"{path} is interlaced; save it without interlacing")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if channels is None or depth not in ((8, 16) if color_type != 3 else (8,)):
        fail(f"{path}: unsupported PNG (colour type {color_type}, {depth} bits)")
    bpp = channels * depth // 8
    stride = width * bpp
    raw = zlib.decompress(idat)
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(height):
        filt = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if filt == 1:
                line[i] = (line[i] + a) & 255
            elif filt == 2:
                line[i] = (line[i] + b) & 255
            elif filt == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif filt == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        prev = line
        step = depth // 8
        row = []
        for x in range(width):
            px = [line[x * bpp + k * step] for k in range(channels)]
            if color_type == 3:
                row.append(palette[px[0]])
            elif color_type in (0, 4):
                row.append((px[0], px[0], px[0]))
            else:
                row.append((px[0], px[1], px[2]))
        rows.append(row)
    return width, height, rows


def write_png(path, rows):
    """Writes 8-bit RGB rows of (r, g, b) tuples."""
    height = len(rows)
    width = len(rows[0])
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


# --- colours -----------------------------------------------------------------------------------

def median_cut(colors, count):
    """Up to `count` representative colours for a list of (r, g, b)."""
    boxes = [list(colors)]
    while len(boxes) < count:
        boxes.sort(key=lambda box: max(max(c[k] for c in box) - min(c[k] for c in box) for k in range(3)) if len(box) > 1 else -1)
        box = boxes.pop()
        if len(box) < 2:
            boxes.append(box)
            break
        axis = max(range(3), key=lambda k: max(c[k] for c in box) - min(c[k] for c in box))
        box.sort(key=lambda c: c[axis])
        half = len(box) // 2
        boxes += [box[:half], box[half:]]
    return [tuple(sum(c[k] for c in box) // len(box) for k in range(3)) for box in boxes if box]


def palette_indexes(rows):
    """(palette as 0xRRGGBB ints, indexes row by row)."""
    order = {}
    for row in rows:
        for px in row:
            if px not in order:
                order[px] = len(order)
    if len(order) <= 256:
        palette = list(order)
        lookup = order
    else:
        palette = median_cut(list(order), 256)
        lookup = {}
        for px in order:
            lookup[px] = min(range(len(palette)), key=lambda i: sum((px[k] - palette[i][k]) ** 2 for k in range(3)))
    indexes = [lookup[px] for row in rows for px in row]
    return [(r << 16) | (g << 8) | b for r, g, b in palette], indexes


# --- mips (same rules as BGE.VoxelMaps.averageHeights / mostCommonColors) ----------------------

def average_heights(heights, shift):
    size = 1 << shift
    half = size >> 1
    out = []
    for z in range(half):
        r0 = (z * 2) * size
        r1 = r0 + size
        for x in range(half):
            x2 = x * 2
            out.append((heights[r0 + x2] + heights[r0 + x2 + 1] + heights[r1 + x2] + heights[r1 + x2 + 1]) // 4)
    return out


def most_common_colors(colors, shift):
    size = 1 << shift
    half = size >> 1
    out = []
    for z in range(half):
        r0 = (z * 2) * size
        r1 = r0 + size
        for x in range(half):
            x2 = x * 2
            four = [colors[r0 + x2], colors[r0 + x2 + 1], colors[r1 + x2], colors[r1 + x2 + 1]]
            # max() keeps the first of equal counts, in that order
            out.append(max(four, key=four.count))
    return out


# --- .bvox -------------------------------------------------------------------------------------

def bvox_bytes(heights, colors, palette, shift, edge_flat, flat_height, flat_color):
    level_count = min(MAX_LEVELS, shift - 2)
    height_levels = [heights]
    color_levels = [colors]
    for level in range(1, level_count):
        height_levels.append(average_heights(height_levels[-1], shift - level + 1))
        color_levels.append(most_common_colors(color_levels[-1], shift - level + 1))
    out = bytearray(b"BGEV")
    out += bytes([1, shift, level_count, 1 if edge_flat else 0, flat_height, flat_color, len(palette) & 255])
    for rgb in palette:
        out += bytes([(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255])
    for h, c in zip(height_levels, color_levels):
        out += bytes(h)
        out += bytes(c)
    return bytes(out)


def write_test_pngs(folder):
    import os
    os.makedirs(folder, exist_ok=True)
    # height x * 4; colours a checker of 8-cell squares in red, green, blue
    write_png(os.path.join(folder, "heights.png"), [[(x * 4,) * 3 for x in range(64)] for _ in range(64)])
    checker = [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
    write_png(os.path.join(folder, "colors.png"), [[checker[((x >> 3) + (z >> 3)) % 3] for x in range(64)] for z in range(64)])


def main():
    parser = argparse.ArgumentParser(description="Bake heightmap + colour PNGs into a .bvox voxel terrain map")
    parser.add_argument("heights", nargs="?")
    parser.add_argument("colors", nargs="?")
    parser.add_argument("out", nargs="?")
    parser.add_argument("--edge", choices=["wrap", "flat"], default="wrap")
    parser.add_argument("--flat-height", type=int, default=0)
    parser.add_argument("--flat-color", default="2A5DA8", help="RRGGBB")
    parser.add_argument("--write-test-pngs", metavar="DIR")
    args = parser.parse_args()

    if args.write_test_pngs:
        write_test_pngs(args.write_test_pngs)
        return
    if not (args.heights and args.colors and args.out):
        parser.error("heights, colors and out are required")

    hw, hh, height_rows = read_png(args.heights)
    cw, ch, color_rows = read_png(args.colors)
    if hw != hh:
        fail(f"the heightmap is {hw}x{hh}; it must be square")
    if (cw, ch) != (hw, hh):
        fail(f"the colour map is {cw}x{ch}, the heightmap {hw}x{hh}; they must match")
    shift = hw.bit_length() - 1
    if (1 << shift) != hw or shift < 6 or shift > 10:
        fail(f"size {hw} isn't a power of 2 from 64 to 1024")
    if not 0 <= args.flat_height <= 255:
        fail("--flat-height must be 0-255")

    heights = [px[0] for row in height_rows for px in row]
    palette, colors = palette_indexes(color_rows)
    flat_color = 0
    if args.edge == "flat":
        rgb = int(args.flat_color, 16)
        if rgb not in palette:
            if len(palette) >= 256:
                fail("the colour map has 256 colours, so --flat-color must be one of them")
            palette.append(rgb)
        flat_color = palette.index(rgb)

    data = bvox_bytes(heights, colors, palette, shift, args.edge == "flat", args.flat_height, flat_color)
    with open(args.out, "wb") as f:
        f.write(data)
    print(f"{args.out}: {hw}x{hw}, {len(palette)} colours, {len(data)} bytes")


if __name__ == "__main__":
    main()
