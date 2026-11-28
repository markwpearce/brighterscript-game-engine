#!/usr/bin/env python3
"""Draws the channel icons and splash screens: the game's name in the title font, gold on the night sky's blue.

    python3 tools/title-images.py src/images

Needs ImageMagick (`magick`). Writes Channel_Icon_HD.png, Channel_Icon_SD.png, Splash_HD.png and Splash_SD.png.
"""
import os
import subprocess
import sys

TITLE = "Night of the\nBarrow King"
FONT = os.path.join(os.path.dirname(__file__), "..", "src", "fonts", "quill-and-antler-expanded.ttf")
# The night sky's zenith and horizon (tools/night-sky.py), and the menus' gold (MenuTheme.bs)
TOP = "#080E28"
BOTTOM = "#26386A"
GOLD = "#E0B050"

# file, width, height, text height as a fraction of the image's
IMAGES = [
    ("Channel_Icon_HD.png", 336, 210, 0.62),
    ("Channel_Icon_SD.png", 246, 140, 0.62),
    ("Splash_HD.png", 1280, 720, 0.34),
    ("Splash_SD.png", 720, 480, 0.30),
]


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    out_dir = sys.argv[1]
    for name, width, height, fraction in IMAGES:
        text_width = int(width * 0.84)
        text_height = int(height * fraction)
        shadow = max(1, height // 160)
        label = ["(", "-size", f"{text_width}x{text_height}", "-background", "none", "-font", FONT,
                 "-gravity", "center", "-fill", "{fill}", f"label:{TITLE}", ")"]
        shadow_label = [part.replace("{fill}", "#000000B0") for part in label]
        gold_label = [part.replace("{fill}", GOLD) for part in label]
        subprocess.run(
            ["magick", "-size", f"{width}x{height}", f"gradient:{TOP}-{BOTTOM}"]
            + shadow_label + ["-gravity", "center", "-geometry", f"+{shadow}+{shadow}", "-composite"]
            + gold_label + ["-gravity", "center", "-geometry", "+0+0", "-composite"]
            + ["-depth", "8", "-strip", os.path.join(out_dir, name)],
            check=True)
        print("wrote", os.path.join(out_dir, name))


if __name__ == "__main__":
    main()
