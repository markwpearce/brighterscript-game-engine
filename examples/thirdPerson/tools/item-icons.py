#!/usr/bin/env python3
"""Draws the placeholder item icons: simple shapes, 64 x 64 each, in one strip.

    python3 tools/item-icons.py src/images/item_icons.png

Needs ImageMagick (`magick`). The order is the `icon` index in src/source/Items.bs: longsword, orc
cleaver, warden's blade, heater shield, tower shield, draught, coin, chieftain's tusk, barrow flask.
"""
import subprocess
import sys

OUTLINE = "#1A1008"

# Each icon: ImageMagick -draw primitives on a transparent 64 x 64
ICONS = [
    # Longsword: a straight steel blade corner to corner, a crossguard and a leather grip
    [("#C8CCD4", "polygon 50,8 56,14 22,48 16,42"), ("#8A6A3A", "polygon 10,36 28,54 24,58 6,40"),
     ("#5A3A1E", "polygon 15,47 17,49 9,57 7,55"), ("#C8A040", "circle 7,57 9,59")],
    # Orc cleaver: a broad, dark slab with a notched edge on a short haft
    [("#6A6460", "polygon 22,8 54,8 54,40 30,40 22,32"), ("#9A948C", "polygon 22,8 54,8 54,12 22,12"),
     ("#3A2A1A", "polygon 34,40 40,40 40,60 34,60"), ("#1A1008", "circle 47,16 49,18")],
    # Warden's blade: slender pale-blue steel, a gold guard
    [("#B8D4F0", "polygon 52,6 56,10 24,42 20,38"), ("#E0B050", "polygon 14,34 30,50 27,53 11,37"),
     ("#2A2A40", "polygon 19,45 21,47 13,55 11,53"), ("#E0B050", "circle 11,55 13,57")],
    # Heater shield: a red field with a pale cross and an iron rim
    [("#8A8A90", "path 'M 10,8 L 54,8 L 54,30 Q 54,50 32,60 Q 10,50 10,30 Z'"),
     ("#8A1C1C", "path 'M 14,12 L 50,12 L 50,30 Q 50,47 32,56 Q 14,47 14,30 Z'"),
     ("#E8E0C8", "polygon 29,14 35,14 35,52 29,52"), ("#E8E0C8", "polygon 16,26 48,26 48,32 16,32")],
    # Tower shield: a tall plank wall with iron bands and a boss
    [("#5A3A20", "roundrectangle 14,4 50,60 4,4"), ("#7A5230", "polygon 18,6 24,6 24,58 18,58"),
     ("#7A5230", "polygon 30,6 36,6 36,58 30,58"), ("#7A5230", "polygon 42,6 46,6 46,58 42,58"),
     ("#8A8A90", "polygon 14,14 50,14 50,18 14,18"), ("#8A8A90", "polygon 14,46 50,46 50,50 14,50"),
     ("#B0B0B8", "circle 32,32 32,38")],
    # Draught: a round glass bottle of red, corked
    [("#6A4A2A", "polygon 28,4 36,4 36,12 28,12"), ("#C0D0D8", "polygon 26,12 38,12 38,22 26,22"),
     ("#C0D0D8", "circle 32,40 32,60"), ("#B01828", "circle 32,42 32,57"), ("#F0A0A0", "circle 26,36 26,39")],
    # Coin: gold with a darker rim
    [("#A07818", "circle 32,32 32,56"), ("#F0C860", "circle 32,32 32,52"), ("#C89830", "polygon 28,20 36,20 36,44 28,44")],
    # Chieftain's tusk: a curved ivory horn
    [("#E8DCB8", "path 'M 12,54 Q 14,20 52,8 Q 30,26 24,56 Z'"), ("#A89070", "polygon 10,52 26,52 26,58 10,58")],
    # Barrow flask: an old clay flask with a gold plus (one more draught)
    [("#8A5A30", "circle 30,38 30,58"), ("#8A5A30", "polygon 26,10 34,10 34,24 26,24"), ("#4A3018", "polygon 25,6 35,6 35,11 25,11"),
     ("#E0B050", "polygon 45,6 51,6 51,26 45,26"), ("#E0B050", "polygon 38,13 58,13 58,19 38,19")],
]


def icon_args(shapes):
    args = ["(", "-size", "64x64", "xc:none", "-stroke", OUTLINE, "-strokewidth", "2"]
    for fill, primitive in shapes:
        args += ["-fill", fill, "-draw", primitive]
    return args + [")"]


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    command = ["magick"]
    for shapes in ICONS:
        command += icon_args(shapes)
    command += ["+append", "-strip", "-depth", "8", sys.argv[1]]
    subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
