#!/usr/bin/env python3
"""Draws the keep's and chapel's wall dressing (32 px per metre, like the crypt's art).

    python3 tools/interior-art.py src/sprites [preview.png]

Writes keep_door.webp (an arched double door filling the keep's 4 x 5 m doorway, stone above),
chapel_door.webp (a single door, 2 x 6 m), chapel_window.webp (a lancet of stained glass, drawn
unlit), keep_banner.webp and keep_banner_blue.webp (hung banners), as lossless WebP. The stone
round the doors is the crypt wall's (tools/crypt-art.py), so it matches the walls.
With a second path, also writes a preview of all of them side by side.
Needs ImageMagick (`magick`) to write the images.
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

PX = 32
LEAD = (26, 24, 28)
IRON = (46, 46, 52)
GOLD = (206, 164, 66)


def crypt_wall():
    # crypt-art.py draws the wall first from this seed
    return crypt_art.wall(random.Random(1347))


def in_arch(x, y, x0, x1, spring, rise):
    """Inside a pointed arch over x0..x1 whose sides spring at y = spring and rise `rise` px."""
    if x < x0 or x >= x1:
        return False
    if y >= spring:
        return True
    half = (x1 - x0) / 2
    cx = x0 + half
    # two circles meeting at the apex, each centred on the far springing point's side
    radius = (half * half + rise * rise) / (2 * half) if half > 0 else 0
    dx = abs(x + 0.5 - cx)
    centre = cx - (radius - half) if x + 0.5 >= cx else cx + (radius - half)
    return (x + 0.5 - centre) ** 2 + (y + 0.5 - spring) ** 2 <= radius * radius and spring - y <= rise and dx <= half


def door(rng, leaves, wall_m):
    """`leaves` 2 m leaves side by side under one pointed arch, set in wall_m of stone."""
    width = leaves * 2 * PX
    height = int(wall_m * PX)
    img = Image(width, height, (0, 0, 0, 255))
    stone = crypt_wall()
    for y in range(height):
        for x in range(width):
            # the wall texture's damp foot lines up with the floor
            p = stone.get(x, y - height)
            img.put(x, y, tuple(p[:3]))
    x0, x1 = 7, width - 7
    leaf_h = int(3.1 * PX)
    spring = height - leaf_h + (12 if leaves > 1 else 10)
    rise = 26 if leaves > 1 else 18
    # voussoirs: a lighter stone ring round the opening
    for y in range(height):
        for x in range(width):
            if in_arch(x, y, x0 - 5, x1 + 5, spring, rise + 5) and not in_arch(x, y, x0, x1, spring, rise):
                k = rng.uniform(0.92, 1.05)
                img.put(x, y, shade((128, 120, 108), k))
    # joints between the ring's stones, pointing at the arch's middle
    cx = width / 2
    for i in range(1, 9):
        a = math.pi * i / 9
        for r in range(0, 8):
            rx = cx - math.cos(a) * ((x1 - x0) / 2 + r - 1)
            ry = spring - math.sin(a) * (rise + r - 1)
            img.put(int(rx), int(ry), (52, 48, 44))
    # the leaves: vertical planks
    for y in range(height):
        for x in range(width):
            if not in_arch(x, y, x0, x1, spring, rise) or y >= height - 3:
                continue
            plank = (x - x0) // 7
            prng = random.Random(plank * 31 + 7)
            base = prng.choice([(98, 62, 34), (90, 58, 32), (104, 68, 38), (86, 54, 30)])
            k = rng.uniform(0.9, 1.06) * (1.0 + 0.06 * math.sin(y * 0.7 + plank))
            if (x - x0) % 7 == 0:
                img.put(x, y, (40, 26, 16))
            else:
                img.put(x, y, shade(base, k))
    if leaves > 1:
        for y in range(spring - rise, height - 3):
            for x in (int(cx) - 1, int(cx)):
                if in_arch(x, y, x0, x1, spring, rise):
                    img.put(x, y, (28, 18, 12))
    # iron bands with rivets, and strap hinges
    for band_y in (height - 3 - int(leaf_h * 0.25), height - 3 - int(leaf_h * 0.72)):
        for y in range(band_y, band_y + 3):
            for x in range(x0, x1):
                if in_arch(x, y, x0, x1, spring, rise):
                    img.put(x, y, shade(IRON, 1.15 if y == band_y else 0.9))
        for x in range(x0 + 3, x1 - 2, 6):
            img.put(x, band_y + 1, (120, 118, 124))
    # ring pulls by the middle (or the latch side)
    pulls = [int(cx) - 5, int(cx) + 4] if leaves > 1 else [x1 - 9]
    pull_y = height - 3 - int(leaf_h * 0.48)
    for px in pulls:
        for a in range(24):
            t = a / 24 * 2 * math.pi
            img.put(int(px + math.cos(t) * 3), int(pull_y + 3 + math.sin(t) * 3), (150, 140, 110))
        img.rect(px - 1, pull_y - 1, px + 2, pull_y + 1, IRON)
    # worn step
    img.rect(x0 - 4, height - 3, x1 + 4, height, (112, 106, 98))
    return img


def window(rng):
    """40 x 112 (1.25 x 3.5 m): a lancet of leaded glass in a stone surround, transparent outside."""
    width, height = 40, 112
    img = Image(width, height)
    spring, rise = 34, 30
    palette = [(46, 76, 168), (36, 58, 140), (156, 34, 44), (196, 154, 58), (44, 116, 76), (112, 52, 132)]
    for y in range(height):
        for x in range(width):
            if in_arch(x, y, 0, width, spring, rise) and not in_arch(x, y, 4, width - 4, spring, rise - 4):
                img.put(x, y, shade((118, 112, 104), rng.uniform(0.85, 1.05)))
            elif in_arch(x, y, 4, width - 4, spring, rise - 4):
                # diamond quarries
                u = (x - 4 + y) // 7
                v = (x - 4 - y) // 7
                on_lead = (x - 4 + y) % 7 == 0 or (x - 4 - y) % 7 == 0
                col = palette[(u * 3 + v * 5) % len(palette)]
                # a gold-and-red medallion in the middle, a blue border down the sides
                dx, dy = x - width / 2, y - 64
                if dx * dx + dy * dy < 100:
                    col = GOLD if dx * dx + dy * dy < 36 else palette[2]
                    on_lead = abs(math.hypot(dx, dy) - 6) < 0.6 or abs(math.hypot(dx, dy) - 10) < 0.7
                elif x < 8 or x >= width - 8:
                    col = palette[1]
                    on_lead = y % 6 == 0 or x == 7 or x == width - 8
                if on_lead:
                    img.put(x, y, LEAD)
                else:
                    # brighter towards the middle, as if moonlit from outside
                    glow = 0.82 + 0.25 * (1 - abs(x - width / 2) / (width / 2))
                    img.put(x, y, shade(col, glow * rng.uniform(0.92, 1.05)))
    # a mullion and transom bar
    img.rect(width // 2 - 1, spring - rise + 8, width // 2 + 1, height - 4, LEAD)
    img.rect(4, height - 4, width - 4, height, (108, 102, 96))
    return img


def banner(rng, cloth):
    """36 x 88 (1.1 x 2.75 m): a swallow-tailed banner on a rod, gold-edged, a tower on it."""
    width, height = 36, 88
    img = Image(width, height)
    left, right = 3, width - 3
    tail = 12
    for y in range(3, height):
        for x in range(left, right):
            # the swallowtail's notch
            notch = y - (height - tail)
            if notch > 0 and abs(x + 0.5 - width / 2) < notch * (right - left) / (2 * tail):
                continue
            fold = 0.86 + 0.16 * math.sin((x - left) * 0.55)
            edge = x < left + 2 or x >= right - 2 or y < 5 or (notch > -2 and notch > 0 and False)
            col = GOLD if edge else cloth
            img.put(x, y, shade(col, fold * rng.uniform(0.95, 1.04)))
    # gold hem along the tails
    for y in range(height - tail, height):
        notch = y - (height - tail)
        for x in range(left, right):
            inner = abs(x + 0.5 - width / 2) - notch * (right - left) / (2 * tail)
            if 0 <= inner < 1.6 or y >= height - 2 and inner >= 0:
                img.put(x, y, shade(GOLD, 0.95))
    # a tower: body, battlements, a dark gate
    cx = width // 2
    img.rect(cx - 6, 26, cx + 6, 52, shade(GOLD, 1.0))
    for i in range(4):
        img.rect(cx - 8 + i * 4 + (1 if i > 1 else 0), 20, cx - 8 + i * 4 + 3 + (1 if i > 1 else 0), 26, GOLD)
    img.rect(cx - 8, 24, cx + 8, 28, GOLD)
    img.rect(cx - 2, 44, cx + 2, 52, shade(cloth, 0.6))
    img.ellipse(cx, 44, 2, 2, shade(cloth, 0.6))
    img.rect(cx - 1, 32, cx + 1, 37, shade(cloth, 0.6))
    # the rod, with knobs
    img.rect(0, 1, width, 4, (92, 60, 34))
    img.ellipse(1.5, 2.5, 1.6, 1.8, GOLD)
    img.ellipse(width - 1.5, 2.5, 1.6, 1.8, GOLD)
    return img


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    rng = random.Random(1186)
    images = {
        "keep_door": door(rng, 2, 5),
        "chapel_door": door(rng, 1, 6),
        "chapel_window": window(rng),
        "keep_banner": banner(rng, (128, 22, 30)),
        "keep_banner_blue": banner(rng, (30, 44, 112)),
    }
    for name, img in images.items():
        img.write(os.path.join(out, name + ".webp"))
    if len(sys.argv) > 2:
        total = sum(img.width for img in images.values()) + 8 * len(images)
        tallest = max(img.height for img in images.values())
        preview = Image(total, tallest, (40, 0, 40, 255))
        left = 0
        for img in images.values():
            for y in range(img.height):
                for x in range(img.width):
                    p = img.get(x, y)
                    if p[3] > 0:
                        preview.put(left + x, tallest - img.height + y, tuple(p[:3]))
            left += img.width + 8
        preview.write(sys.argv[2])


if __name__ == "__main__":
    main()
