#!/usr/bin/env python3
"""Draws the crypt's textures and props (32 px per metre, like the knight).

    python3 tools/crypt-art.py src/sprites [preview.png]

Writes crypt_wall.png (one 2 x 4 m wall segment, tiles left/right), crypt_floor.png (flagstones,
tiles both ways), crypt_alcove.png (a niche with a seated skeleton, hung on a wall),
crypt_rubble.png, crypt_bones.png and crypt_altar.png (cut-outs, base on the bottom row).
With a second path, also writes a preview of the wall and floor tiled, to check the seams.
Needs ImageMagick (`magick`) to write the PNGs.
"""
import math
import os
import random
import subprocess
import sys
import tempfile

MORTAR = (22, 20, 19)


class Image:
    def __init__(self, width, height, fill=(0, 0, 0, 0)):
        self.width = width
        self.height = height
        self.px = [list(fill) for _ in range(width * height)]

    def get(self, x, y):
        return self.px[(y % self.height) * self.width + (x % self.width)]

    def put(self, x, y, rgb, alpha=255, wrap=False):
        if wrap:
            x %= self.width
            y %= self.height
        elif x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        p = self.px[y * self.width + x]
        if alpha >= 255 or p[3] == 0:
            p[0], p[1], p[2] = rgb
            p[3] = max(p[3], alpha)
        else:
            t = alpha / 255.0
            for i in range(3):
                p[i] = int(p[i] * (1 - t) + rgb[i] * t)
            p[3] = max(p[3], alpha)

    def rect(self, x0, y0, x1, y1, rgb, wrap=False):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.put(x, y, rgb, wrap=wrap)

    def ellipse(self, cx, cy, rx, ry, rgb, alpha=255):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.put(x, y, rgb, alpha)

    def line(self, x0, y0, x1, y1, rgb, width=1.0):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            self.ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width / 2, width / 2, rgb)

    def write(self, path):
        with tempfile.TemporaryDirectory() as tmp:
            pam = os.path.join(tmp, "image.pam")
            with open(pam, "wb") as f:
                f.write(f"P7\nWIDTH {self.width}\nHEIGHT {self.height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n".encode())
                f.write(bytes(v for p in self.px for v in p))
            subprocess.run(["magick", pam, "-strip", "PNG32:" + path], check=True)


def shade(rgb, k):
    return tuple(max(0, min(255, int(c * k))) for c in rgb)


def stone_colour(rng):
    base = rng.choice([(92, 86, 78), (84, 80, 76), (98, 90, 80), (78, 74, 70), (88, 84, 82)])
    return shade(base, rng.uniform(0.8, 1.1))


def fill_stone(img, x0, y0, x1, y1, rgb, rng, wrap):
    """A block with a lit top-left edge, a dark bottom-right edge and grain."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            k = rng.uniform(0.9, 1.08)
            if y == y0 or x == x0:
                k *= 1.18
            elif y == y1 - 1 or x == x1 - 1:
                k *= 0.7
            img.put(x, y, shade(rgb, k), wrap=wrap)


def wall(rng):
    """64 x 128: courses of blocks with a period of 64 px, so segments tile side by side."""
    img = Image(64, 128, (*MORTAR, 255))
    y = 0
    course = 0
    while y < 128:
        h = min(rng.choice([14, 16, 18]), 128 - y)
        offset = (course % 2) * rng.choice([8, 16, 24])
        x = 0
        while x < 64:
            w = min(rng.choice([16, 24, 32]), 64 - x)
            fill_stone(img, offset + x + 1, y + 1, offset + x + w - 1, y + h - 1, stone_colour(rng), rng, True)
            x += w
        y += h
        course += 1
    # Damp and grime near the floor, and a few cracks
    for yy in range(96, 128):
        k = 1 - (yy - 96) / 32 * 0.35
        for xx in range(64):
            p = img.get(xx, yy)
            img.put(xx, yy, (int(p[0] * k * 0.92), int(p[1] * k), int(p[2] * k * 0.9)))
    for _ in range(5):
        x, yy = rng.randrange(64), rng.randrange(128)
        for _ in range(rng.randrange(4, 10)):
            img.put(x, yy, MORTAR, wrap=True)
            x += rng.choice([-1, 0, 1])
            yy += 1
    return img


def floor(rng):
    """128 x 128 (8 m at 16 texels per metre): flagstones in uneven rows, tiling both ways."""
    img = Image(128, 128, (*MORTAR, 255))
    y = 0
    while y < 128:
        h = min(rng.choice([12, 14, 16]), 128 - y)
        if 128 - (y + h) < 10:
            h = 128 - y
        start = rng.randrange(128)
        x = 0
        while x < 128:
            w = rng.choice([10, 13, 16, 18])
            if 128 - (x + w) < 8:
                w = 128 - x
            rgb = shade(stone_colour(rng), 0.85)
            for yy in range(y + 1, y + h - 1):
                for xx in range(x + 1, x + w - 1):
                    k = rng.uniform(0.88, 1.08)
                    if yy == y + 1 or xx == x + 1:
                        k *= 1.12
                    img.put(start + xx, yy, shade(rgb, k), wrap=True)
            x += w
        y += h
    return img


BONE = (196, 186, 160)
BONE_DARK = (120, 112, 96)


def alcove(rng):
    """64 x 80 (2 x 2.5 m): an arched niche with a seated skeleton, framed in stone."""
    img = Image(64, 80)
    # Stone frame then the dark recess, both arched
    for (inset, rgb) in [(0, (70, 66, 62)), (5, (14, 12, 12))]:
        cx, top, half = 32, 10 + inset, 26 - inset
        for y in range(top, 80):
            for x in range(32 - half, 32 + half):
                arch_y = top + half - math.sqrt(max(0, half * half - (x + 0.5 - cx) ** 2))
                if y >= arch_y:
                    img.put(x, y, shade(rgb, rng.uniform(0.9, 1.08)) if inset == 0 else rgb)
    # Seated skeleton: skull, spine, ribs, arms, pelvis, legs drawn up
    img.ellipse(32, 36, 5, 5.5, BONE)
    img.ellipse(30, 36, 1.4, 1.6, (20, 18, 16))
    img.ellipse(34, 36, 1.4, 1.6, (20, 18, 16))
    img.rect(30, 40, 35, 42, BONE_DARK)
    img.line(32, 42, 32, 60, BONE, 2)
    for i in range(5):
        y = 46 + i * 2.5
        img.line(26 + i * 0.6, y, 38 - i * 0.6, y, BONE, 1.2)
    img.line(26, 45, 22, 56, BONE, 1.5)
    img.line(22, 56, 27, 63, BONE, 1.5)
    img.line(38, 45, 42, 56, BONE, 1.5)
    img.line(42, 56, 37, 63, BONE, 1.5)
    img.ellipse(32, 62, 6, 3, BONE)
    img.line(27, 63, 20, 70, BONE, 2)
    img.line(20, 70, 26, 79, BONE, 2)
    img.line(37, 63, 44, 70, BONE, 2)
    img.line(44, 70, 38, 79, BONE, 2)
    return img


def rubble(rng):
    """48 x 16 (1.5 x 0.5 m): a heap of broken blocks."""
    img = Image(48, 16)
    for _ in range(14):
        w, h = rng.randrange(5, 12), rng.randrange(4, 8)
        x = rng.randrange(0, 48 - w)
        mid = 1 - abs(x + w / 2 - 24) / 24
        y = 16 - h - int(rng.uniform(0, 7) * mid)
        fill_stone(img, x, y, x + w, y + h, stone_colour(rng), rng, False)
    return img


def bones(rng):
    """40 x 12 (1.25 x 0.4 m): a scatter of bones and a skull."""
    img = Image(40, 12)
    for _ in range(7):
        x0, y0 = rng.uniform(3, 37), rng.uniform(7, 11)
        a = rng.uniform(-0.5, 0.5)
        length = rng.uniform(6, 12)
        x1, y1 = x0 + math.cos(a) * length, y0 + math.sin(a) * length * 0.3
        img.line(x0, y0, x1, y1, shade(BONE, rng.uniform(0.75, 1)), 1.4)
        img.ellipse(x0, y0, 1.2, 1.2, BONE)
        img.ellipse(x1, y1, 1.2, 1.2, BONE)
    img.ellipse(20, 7, 4, 3.5, BONE)
    img.ellipse(18.5, 7, 1, 1.1, (20, 18, 16))
    img.ellipse(21.5, 7, 1, 1.1, (20, 18, 16))
    return img


def altar(rng):
    """64 x 40 (2 x 1.25 m): a stone altar with a cloth and candles."""
    img = Image(64, 40)
    fill_stone(img, 6, 30, 58, 40, (76, 72, 68), rng, False)
    fill_stone(img, 10, 14, 54, 30, (88, 84, 80), rng, False)
    fill_stone(img, 4, 10, 60, 15, (100, 96, 90), rng, False)
    img.rect(22, 10, 42, 26, (70, 18, 22))
    img.rect(22, 25, 42, 27, (150, 120, 40))
    for x in (10, 16, 48, 54):
        img.rect(x, 3, x + 2, 10, (210, 200, 170))
        img.ellipse(x + 1, 2, 1.2, 1.8, (255, 200, 90))
    return img


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    rng = random.Random(1347)
    images = {
        "crypt_wall": wall(rng),
        "crypt_floor": floor(rng),
        "crypt_alcove": alcove(rng),
        "crypt_rubble": rubble(rng),
        "crypt_bones": bones(rng),
        "crypt_altar": altar(rng),
    }
    for name, img in images.items():
        img.write(os.path.join(out, name + ".png"))
    if len(sys.argv) > 2:
        w, f = images["crypt_wall"], images["crypt_floor"]
        preview = Image(w.width * 3 + 8 + f.width * 2, max(w.height, f.height * 2), (40, 0, 40, 255))
        for y in range(w.height):
            for x in range(w.width * 3):
                preview.put(x, y, tuple(w.get(x, y)[:3]))
        for y in range(f.height * 2):
            for x in range(f.width * 2):
                preview.put(w.width * 3 + 8 + x, y, tuple(f.get(x, y)[:3]))
        preview.write(sys.argv[2])


if __name__ == "__main__":
    main()
