#!/usr/bin/env python3
"""Draws the night sky panorama for DrawableSkybox (360 degrees wide, 90 high, horizon in the middle).

    python3 tools/night-sky.py src/sprites/night_sky.png

Needs ImageMagick (`magick`) to write the PNG. The moon's position must match Night.MOON_YAW_DEGREES
and Night.MOON_ELEVATION_DEGREES in src/source/Night.bs, so the moonlight comes from the moon.
"""
import math
import os
import random
import subprocess
import sys
import tempfile

WIDTH = 2048
HEIGHT = 512
DEGREES_HIGH = 90.0
PX_PER_DEGREE = HEIGHT / DEGREES_HIGH

MOON_YAW = -30.0
MOON_ELEVATION = 20.0
MOON_RADIUS_DEGREES = 2.2

# Deep saturated blues rather than black, so the scene stays readable
ZENITH = (8, 14, 40)
HORIZON = (38, 58, 104)
# Below the horizon: the far ground, faded into the dark
FOG = (12, 18, 30)
TREES = (8, 12, 26)
MOON = (228, 234, 240)
CLOUD_DARK = (34, 48, 88)
CLOUD_LIT = (120, 138, 180)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def yaw_to_x(yaw):
    # SceneObjectSkybox puts yaw 0 at the middle column, increasing to the right
    return (yaw / 360.0 * WIDTH + WIDTH / 2) % WIDTH


def elevation_to_y(elevation):
    return HEIGHT / 2 - elevation * PX_PER_DEGREE


def tree_line(rng):
    """Height in degrees of a distant pine tree line at every column, wrapping round."""
    heights = [0.0] * WIDTH
    # A rolling base so the forest rises and falls
    phases = [rng.random() * math.tau for _ in range(3)]
    for x in range(WIDTH):
        a = x / WIDTH * math.tau
        heights[x] = 1.0 + 0.4 * math.sin(a * 3 + phases[0]) + 0.3 * math.sin(a * 7 + phases[1]) + 0.2 * math.sin(a * 13 + phases[2])
    # Pointed tops, each standing on the rolling base (not on its neighbours)
    base = list(heights)
    x = 0
    while x < WIDTH:
        width = rng.randint(3, 8)
        tip = rng.uniform(0.6, 2.0)
        for dx in range(-width, width + 1):
            col = (x + dx) % WIDTH
            heights[col] = max(heights[col], base[x % WIDTH] + tip * (1 - abs(dx) / (width + 1)))
        x += rng.randint(3, 9)
    return heights


def make_noise(rng, cells_x, cells_y):
    """Smooth value noise that wraps round horizontally, sampled with u in 0-1 and v in 0-1."""
    grid = [[rng.random() for _ in range(cells_x)] for _ in range(cells_y + 1)]

    def sample(u, v):
        fx = u * cells_x
        fy = v * cells_y
        x0 = int(fx) % cells_x
        y0 = min(int(fy), cells_y - 1)
        tx = fx - int(fx)
        ty = fy - int(fy)
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        x1 = (x0 + 1) % cells_x
        top = grid[y0][x0] + (grid[y0][x1] - grid[y0][x0]) * tx
        bottom = grid[y0 + 1][x0] + (grid[y0 + 1][x1] - grid[y0 + 1][x0]) * tx
        return top + (bottom - top) * ty
    return sample


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rng = random.Random(385)
    pixels = bytearray(WIDTH * HEIGHT * 3)
    moon_x = yaw_to_x(MOON_YAW)
    moon_y = elevation_to_y(MOON_ELEVATION)
    moon_radius = MOON_RADIUS_DEGREES * PX_PER_DEGREE
    trees = tree_line(rng)
    octaves = [(make_noise(rng, 6 * 2 ** o, 2 * 2 ** o), 0.5 ** o) for o in range(4)]

    for y in range(HEIGHT):
        elevation = (HEIGHT / 2 - y) / PX_PER_DEGREE
        if elevation >= 0:
            base = mix(HORIZON, ZENITH, (elevation / 30.0) ** 0.6)
        else:
            base = mix(TREES, FOG, -elevation / 2.0)
        for x in range(WIDTH):
            dx = abs(x - moon_x)
            dx = min(dx, WIDTH - dx)
            distance = math.hypot(dx, y - moon_y)
            glow = 0.35 * math.exp(-distance / (moon_radius * 4)) + 0.12 * math.exp(-distance / (moon_radius * 14))
            color = mix(base, (120, 140, 190), glow)
            if elevation > 1:
                u = x / WIDTH
                v = y / (HEIGHT / 2)
                n = sum(noise(u, v) * weight for noise, weight in octaves) / 1.875
                # Clouds thin out toward the zenith and the horizon haze
                cover = max(0.0, (n - 0.45) / 0.25) * min(1.0, elevation / 6) * max(0.0, 1 - elevation / 45)
                if cover > 0:
                    cloud = mix(CLOUD_DARK, CLOUD_LIT, glow * 2.2 + 0.25 * n)
                    color = mix(color, cloud, min(1.0, cover) * 0.85)
            if 0 <= elevation < trees[x]:
                color = TREES
            i = (y * WIDTH + x) * 3
            pixels[i:i + 3] = bytes(int(c) for c in color)

    # Stars, fainter toward the horizon haze and behind the moon's glow
    for _ in range(1400):
        x = rng.randrange(WIDTH)
        elevation = rng.uniform(2, DEGREES_HIGH / 2)
        y = int(elevation_to_y(elevation))
        if elevation < trees[x] + 0.5:
            continue
        dx = abs(x - moon_x)
        dx = min(dx, WIDTH - dx)
        if math.hypot(dx, y - moon_y) < moon_radius * 6:
            continue
        i = (y * WIDTH + x) * 3
        if sum(pixels[i:i + 3]) > sum(ZENITH) + 90:
            # behind a cloud
            continue
        brightness = rng.random() ** 3 * min(1.0, (elevation - 2) / 12)
        size = 2 if brightness > 0.6 else 1
        for sy in range(size):
            for sx in range(size):
                i = ((y + sy) * WIDTH + (x + sx) % WIDTH) * 3
                current = tuple(pixels[i:i + 3])
                pixels[i:i + 3] = bytes(int(c) for c in mix(current, (210, 220, 255), 0.25 + 0.75 * brightness))

    # The moon: a soft-edged disc with a few darker seas
    seas = [(rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(0.2, 0.4)) for _ in range(5)]
    for y in range(int(moon_y - moon_radius - 2), int(moon_y + moon_radius + 3)):
        for x in range(int(moon_x - moon_radius - 2), int(moon_x + moon_radius + 3)):
            u = (x - moon_x) / moon_radius
            v = (y - moon_y) / moon_radius
            r = math.hypot(u, v)
            if r > 1.1:
                continue
            coverage = max(0.0, min(1.0, (1.1 - r) / 0.2))
            shade = 1.0
            for su, sv, sr in seas:
                if math.hypot(u - su, v - sv) < sr:
                    shade -= 0.12
            i = (y * WIDTH + x % WIDTH) * 3
            current = tuple(pixels[i:i + 3])
            pixels[i:i + 3] = bytes(int(c) for c in mix(current, tuple(c * shade for c in MOON), coverage))

    with tempfile.TemporaryDirectory() as tmp:
        ppm = os.path.join(tmp, "sky.ppm")
        with open(ppm, "wb") as f:
            f.write(f"P6 {WIDTH} {HEIGHT} 255\n".encode())
            f.write(pixels)
        subprocess.run(["magick", ppm, "-strip", sys.argv[1]], check=True)


if __name__ == "__main__":
    main()
