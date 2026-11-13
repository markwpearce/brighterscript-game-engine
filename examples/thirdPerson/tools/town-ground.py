"""
Paints the town's ground from its layout: cobbles, dirt paths, grass, crops, ploughed earth and
mud, with ragged edges between them and a warm glow baked round each standing torch (a
staticImage ground plane gets no light pools of its own).

  python3 tools/town-ground.py      (needs Pillow and numpy)

Reads src/maps/town.txt, writes src/sprites/town_ground.webp: PX texels per 2 m cell, row 0 the
far (-z) edge, as TownScene's ground plane draws it.
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, "..", "src", "maps", "town.txt")
OUT = os.path.join(HERE, "..", "src", "sprites", "town_ground.webp")
PX = 16  # texels per cell (so 4 world units per texel); TownScene.groundTexelScale must agree

# What each kind of cell is painted as. Buildings, walls and props stand on dirt or grass.
SURFACE = {
    "=": "cobbles", "-": "dirt", "~": "crops", ":": "ploughed", "x": "mud", "P": "mud",
    "w": "dirt", "t": "dirt", "G": "cobbles", "H": "dirt", "u": "dirt", "K": "cobbles",
    "W": "cobbles", "@": "cobbles",
}
# Props on a cell take the surface round them (the most common neighbouring one)
TAKES_NEIGHBOURS = "lnf"


def read_rows():
    with open(MAP) as fh:
        return [line.rstrip("\n") for line in fh if line.strip() and not line.startswith("#")]


def surfaces(rows):
    h, w = len(rows), len(rows[0])
    grid = [[SURFACE.get(k, "grass") for k in row] for row in rows]
    for r in range(h):
        for c in range(w):
            if rows[r][c] in TAKES_NEIGHBOURS:
                near = [grid[rr][cc] for rr in range(r - 1, r + 2) for cc in range(c - 1, c + 2)
                        if 0 <= rr < h and 0 <= cc < w and rows[rr][cc] not in TAKES_NEIGHBOURS]
                grid[r][c] = max(set(near), key=near.count) if near else "grass"
    return grid


def texture(name, w, h, rng):
    """A w x h RGB float image of one surface"""
    y, x = np.mgrid[0:h, 0:w]
    n = rng.normal(0, 1, (h, w))
    if name == "grass":
        base = np.array([62, 84, 44]); img = base + n[..., None] * [6, 8, 5]
        img += (rng.random((h, w)) < 0.05)[..., None] * [18, 20, 6]
    elif name == "dirt":
        img = np.array([104, 84, 60]) + n[..., None] * [7, 6, 5]
    elif name == "mud":
        img = np.array([70, 54, 38]) + n[..., None] * [5, 4, 3]
        img -= (rng.random((h, w)) < 0.06)[..., None] * [18, 14, 8]
    elif name == "ploughed":
        furrow = ((y // 2) % 2 == 0)
        img = np.where(furrow[..., None], [86, 64, 42], [112, 88, 60]) + n[..., None] * 4
    elif name == "crops":
        row = ((y // 2) % 2 == 0)
        img = np.where(row[..., None], [78, 104, 46], [96, 76, 50]) + n[..., None] * [8, 10, 4]
    elif name == "cobbles":
        # 2x2-texel stones (about 25 cm) in offset rows, each its own grey, with dark joints
        stone = rng.normal(0, 1, (h // 2 + 2, w // 2 + 2))
        sy = y // 2; sx = (x + (sy % 2)) // 2
        img = np.array([106, 104, 100]) + stone[sy, sx][..., None] * 10
        joint = ((x + (sy % 2)) % 2 == 0) & (y % 2 == 0)
        img = np.where(joint[..., None], img * 0.7, img)
    return img.astype(np.float32)


def main():
    rows = read_rows()
    grid = surfaces(rows)
    ch, cw = len(rows), len(rows[0])
    h, w = ch * PX, cw * PX
    rng = np.random.default_rng(7)
    layers = {name: texture(name, w, h, rng) for name in set(k for row in grid for k in row)}

    # Each texel takes the surface of the cell under a jittered copy of itself, so the edges
    # between surfaces are ragged rather than straight
    y, x = np.mgrid[0:h, 0:w]
    jx = x + rng.normal(0, PX * 0.18, (h, w)); jy = y + rng.normal(0, PX * 0.18, (h, w))
    col = np.clip((jx // PX).astype(int), 0, cw - 1); row = np.clip((jy // PX).astype(int), 0, ch - 1)
    img = np.zeros((h, w, 3), np.float32)
    for name, layer in layers.items():
        mask = np.array([[grid[r][c] == name for c in range(cw)] for r in range(ch)])[row, col]
        img[mask] = layer[mask]

    # A warm glow round each standing torch, about 4 m across
    for r in range(ch):
        for c in range(cw):
            if rows[r][c] == "l":
                cx, cy = (c + 0.5) * PX, (r + 0.5) * PX
                d = np.hypot(x - cx, y - cy) / (PX * 2.2)
                glow = np.clip(1 - d, 0, 1) ** 2 * 0.55
                img = img * (1 + glow[..., None] * 0.6) + glow[..., None] * np.array([90, 50, 10])

    img = np.clip(img, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(OUT, "WEBP", quality=90)
    print("%s %dx%d (%d cells of %d texels)" % (OUT, w, h, cw * ch, PX))


if __name__ == "__main__":
    main()
