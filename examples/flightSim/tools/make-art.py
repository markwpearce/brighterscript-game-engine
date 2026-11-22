#!/usr/bin/env python3
# Makes the flight sim's island map and sky. Python 3 standard library only.
#
#   python3 tools/make-art.py      (from examples/flightSim)
#
# Writes art/island-heights.png and art/island-colors.png (edit these in a paint program and
# re-bake with ../../tools/voxel-map.py if you like), bakes them into src/maps/island.bvox, and
# writes src/sprites/sky.png, a tileable sky panorama.

import importlib.util
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SIZE = 512
SEED = 655
SEA = 30
SEA_RGB = 0x2A5DA8

spec = importlib.util.spec_from_file_location("voxel_map", os.path.join(ROOT, "..", "..", "tools", "voxel-map.py"))
voxel_map = importlib.util.module_from_spec(spec)
spec.loader.exec_module(voxel_map)


def lattice(seed, period):
    rng = random.Random(seed)
    return [[rng.random() for _ in range(period)] for _ in range(period)]


def value_noise(grid, period, u, v):
    """Smooth value noise, u and v in lattice cells; repeats every `period` cells."""
    x0 = int(math.floor(u))
    y0 = int(math.floor(v))
    fx = u - x0
    fy = v - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x0 %= period
    y0 %= period
    x1 = (x0 + 1) % period
    y1 = (y0 + 1) % period
    a = grid[y0][x0] + (grid[y0][x1] - grid[y0][x0]) * fx
    b = grid[y1][x0] + (grid[y1][x1] - grid[y1][x0]) * fx
    return a + (b - a) * fy


def fbm(octaves, x, y, base_period):
    """0-1 fractal noise at x, y in 0-1, tiling at 1."""
    total = 0.0
    amplitude = 1.0
    norm = 0.0
    for i, grid in enumerate(octaves):
        period = base_period << i
        total += value_noise(grid, period, x * period, y * period) * amplitude
        norm += amplitude
        amplitude *= 0.5
    return total / norm


def smoothstep(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)


def make_island():
    octaves = [lattice(SEED + i, 4 << i) for i in range(7)]
    shape = [lattice(SEED + 100 + i, 3 << i) for i in range(3)]
    heights = [[0] * SIZE for _ in range(SIZE)]
    depth = [[0.0] * SIZE for _ in range(SIZE)]
    for z in range(SIZE):
        for x in range(SIZE):
            u = x / SIZE
            v = z / SIZE
            dx = u - 0.5
            dz = v - 0.5
            r = math.sqrt(dx * dx + dz * dz) * 2
            # a wobbly coastline
            r += (fbm(shape, u, v, 3) - 0.5) * 0.45
            land = 1 - smoothstep(0.45, 0.9, r)
            n = fbm(octaves, u, v, 4)
            n2 = smoothstep(0.32, 0.78, n)
            ridge = 1 - abs(2 * n2 - 1)
            e = land * (16 + 215 * (n2 ** 1.6) + 30 * ridge) - 12
            if e <= 0:
                heights[z][x] = SEA
                depth[z][x] = -e
            else:
                heights[z][x] = min(255, SEA + int(e))
    return heights, depth


BANDS = [
    # top (height above sea), rgb
    (3, 0xD8C890),     # sand
    (40, 0x5E9E3C),    # grass
    (95, 0x2F6A2C),   # forest
    (190, 0x7A6E62),   # rock
    (999, 0xF2F2F4),   # snow
]


def shade(rgb, factor):
    r = min(255, int(((rgb >> 16) & 255) * factor))
    g = min(255, int(((rgb >> 8) & 255) * factor))
    b = min(255, int((rgb & 255) * factor))
    return (r, g, b)


def color_island(heights, depth):
    rng = random.Random(SEED)
    factors = [0.62, 0.8, 1.0, 1.15]
    rows = []
    for z in range(SIZE):
        row = []
        for x in range(SIZE):
            h = heights[z][x]
            if h <= SEA and depth[z][x] > 0:
                d = depth[z][x]
                if d < 4:
                    row.append(shade(0x4C8CC0, 1.0))
                elif d < 10:
                    row.append(shade(0x3A74B4, 1.0))
                else:
                    row.append((SEA_RGB >> 16, (SEA_RGB >> 8) & 255, SEA_RGB & 255))
                continue
            above = h - SEA
            # lit from the north-west
            slope = h - heights[max(0, z - 1)][max(0, x - 1)]
            level = 2 + max(-2, min(1, round(slope / 3)))
            if rng.random() < 0.18:
                level = max(0, min(3, level + rng.choice((-1, 1))))
            rgb = BANDS[-1][1]
            for top, band_rgb in BANDS:
                # ragged band edges
                if above < top + rng.randint(-3, 3):
                    rgb = band_rgb
                    break
            row.append(shade(rgb, factors[level]))
        rows.append(row)
    return rows


def make_sky(width=1024, height=256):
    # 120 degrees of pitch, the horizon in the middle: the top row is 60 degrees up
    zenith = (0x3D, 0x7C, 0xC4)
    horizon = (0xB4, 0xD8, 0xF0)
    below = (0xA8, 0xC8, 0xE0)
    clouds = [lattice(SEED + 200 + i, 8 << i) for i in range(5)]
    rows = []
    for y in range(height):
        up = (height / 2 - y) / (height / 2)  # 1 at the top, 0 at the horizon
        row = []
        for x in range(width):
            if up < 0:
                base = below
            else:
                t = up ** 0.6
                base = tuple(int(horizon[i] + (zenith[i] - horizon[i]) * t) for i in range(3))
            c = 0.0
            if 0.02 < up < 0.7:
                # flattened towards the horizon, so they read as a layer seen from below
                n = fbm(clouds, x / width, (up ** 0.7) * 0.6, 8)
                c = smoothstep(0.52, 0.7, n) * smoothstep(0.02, 0.12, up) * (1 - smoothstep(0.45, 0.7, up))
            row.append(tuple(int(base[i] + (250 - base[i]) * c) for i in range(3)))
        rows.append(row)
    return rows


def main():
    art = os.path.join(ROOT, "art")
    maps = os.path.join(ROOT, "src", "maps")
    os.makedirs(art, exist_ok=True)
    os.makedirs(maps, exist_ok=True)
    heights, depth = make_island()
    heights_png = os.path.join(art, "island-heights.png")
    colors_png = os.path.join(art, "island-colors.png")
    voxel_map.write_png(heights_png, [[(h, h, h) for h in row] for row in heights])
    voxel_map.write_png(colors_png, color_island(heights, depth))
    import subprocess
    import sys
    subprocess.run([sys.executable, os.path.join(ROOT, "..", "..", "tools", "voxel-map.py"), heights_png, colors_png,
                    os.path.join(maps, "island.bvox"), "--edge", "flat", "--flat-height", str(SEA),
                    "--flat-color", f"{SEA_RGB:06X}"], check=True)
    voxel_map.write_png(os.path.join(ROOT, "src", "sprites", "sky.png"), make_sky())
    print("wrote art/island-*.png, src/maps/island.bvox, src/sprites/sky.png")


if __name__ == "__main__":
    main()
