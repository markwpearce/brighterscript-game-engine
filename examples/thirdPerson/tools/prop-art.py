#!/usr/bin/env python3
"""Draws the textures for box furniture (32 px per metre, like the crypt's art).

    python3 tools/prop-art.py src/sprites [preview.png]

Writes prop_wood.webp (planks, the grain running left/right) and prop_stone.webp (dressed
blocks), each 64 x 64 (2 x 2 m) and tiling both ways, as lossless WebP. With a second path,
also writes a preview of each tiled 2 x 2. Needs ImageMagick (`magick`) to write the images.
"""
import importlib.util
import math
import os
import random
import sys

_spec = importlib.util.spec_from_file_location("crypt_art", os.path.join(os.path.dirname(__file__), "crypt-art.py"))
crypt_art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(crypt_art)
Image = crypt_art.Image
shade = crypt_art.shade

SIZE = 64


def wood(rng):
    """Planks 8 px (0.25 m) wide with wavy grain, butt joints and the odd knot."""
    img = Image(SIZE, SIZE, (0, 0, 0, 255))
    bases = [(112, 74, 44), (104, 68, 40), (118, 80, 48), (98, 64, 38)]
    for plank in range(SIZE // 8):
        base = shade(rng.choice(bases), rng.uniform(0.9, 1.08))
        phase = rng.uniform(0, math.tau)
        joint = rng.randrange(SIZE)
        for y in range(plank * 8, plank * 8 + 8):
            for x in range(SIZE):
                # grain: stripes along x that wander a little, a whole number of waves per tile
                g = math.sin((y * 2.1) + 1.3 * math.sin(x * math.tau / SIZE * 2 + phase))
                k = 1 + 0.09 * g + rng.uniform(-0.04, 0.04)
                if y == plank * 8:
                    k *= 0.55
                elif y == plank * 8 + 1:
                    k *= 1.12
                if x == joint:
                    k *= 0.6
                img.put(x, y, shade(base, k))
        if rng.random() < 0.5:
            kx, ky = rng.randrange(SIZE), plank * 8 + rng.randrange(2, 6)
            for dy in range(-1, 2):
                for dx in range(-2, 3):
                    if dx * dx / 4 + dy * dy <= 1.2:
                        img.put(kx + dx, ky + dy, shade(base, 0.6), wrap=True)
    return img


def stone(rng):
    """Courses of dressed blocks, smaller than the crypt wall's, with a period of 64 px."""
    img = Image(SIZE, SIZE, (*crypt_art.MORTAR, 255))
    y = 0
    course = 0
    while y < SIZE:
        h = min(rng.choice([10, 12]), SIZE - y)
        if SIZE - (y + h) < 8:
            h = SIZE - y
        offset = (course % 2) * 8
        x = 0
        while x < SIZE:
            w = min(rng.choice([16, 16, 24]), SIZE - x)
            crypt_art.fill_stone(img, offset + x + 1, y + 1, offset + x + w - 1, y + h - 1, crypt_art.stone_colour(rng), rng, True)
            x += w
        y += h
        course += 1
    return img


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    rng = random.Random(2711)
    images = {"prop_wood": wood(rng), "prop_stone": stone(rng)}
    for name, img in images.items():
        img.write(os.path.join(out, name + ".webp"))
    if len(sys.argv) > 2:
        preview = Image(SIZE * 4 + 8, SIZE * 2, (40, 0, 40, 255))
        for i, img in enumerate(images.values()):
            for y in range(SIZE * 2):
                for x in range(SIZE * 2):
                    preview.put(i * (SIZE * 2 + 8) + x, y, tuple(img.get(x, y)[:3]))
        preview.write(sys.argv[2])


if __name__ == "__main__":
    main()
