"""
Paints the forest's ground from its layout, like tools/town-ground.py does the town's: the dirt
road with its ruts, the forest floor, leaf litter, mud, dark undergrowth under the dense forest
and the orc camp's trampled earth, with ragged edges between them and a warm glow baked round the
campfire, the camp's torches and the bonfire (a staticImage ground plane gets no light pools).

  python3 tools/forest-ground.py      (needs Pillow and numpy)

Reads src/maps/forest.txt, writes src/sprites/forest_ground.webp: PX texels per 2 m cell, row 0
the far (-z) edge, as ForestScene's ground plane draws it.
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, "..", "src", "maps", "forest.txt")
OUT = os.path.join(HERE, "..", "src", "sprites", "forest_ground.webp")
PX = 16  # texels per cell (so 4 world units per texel); ForestScene.groundTexelScale must agree

SURFACE = {
    "#": "undergrowth", ".": "floor", ",": "leaves", "-": "road", "E": "road", "@": "road",
    "~": "mud", ":": "earth", "p": "earth", "T": "earth", "F": "ash", "B": "ash",
}
# Trees, enemies and props take the surface round them (the most common neighbouring one)
TAKES_NEIGHBOURS = "YghwtcloOC"
# Baked glows: (radius in cells, strength)
GLOWS = {"F": (3.2, 0.75), "l": (2.0, 0.5), "B": (2.6, 0.6)}


def read_rows():
    with open(MAP) as fh:
        # comments start "# " (a row of dense forest starts with "#" too)
        return [line.rstrip("\n") for line in fh if line.strip() and not line.startswith("# ")]


def surfaces(rows):
    h, w = len(rows), len(rows[0])
    grid = [[SURFACE.get(k, "floor") for k in row] for row in rows]
    for r in range(h):
        for c in range(w):
            if rows[r][c] in TAKES_NEIGHBOURS:
                near = [grid[rr][cc] for rr in range(r - 1, r + 2) for cc in range(c - 1, c + 2)
                        if 0 <= rr < h and 0 <= cc < w and rows[rr][cc] not in TAKES_NEIGHBOURS]
                grid[r][c] = max(set(near), key=near.count) if near else "floor"
    return grid


def texture(name, w, h, rng):
    """A w x h RGB float image of one surface"""
    y, x = np.mgrid[0:h, 0:w]
    n = rng.normal(0, 1, (h, w))
    if name == "floor":
        # dark grass, with a few dead leaves in it
        img = np.array([46, 62, 36]) + n[..., None] * [6, 8, 5]
        img = np.where((rng.random((h, w)) < 0.08)[..., None], [92, 64, 34] + n[..., None] * 8, img)
    elif name == "leaves":
        # fallen leaves, browns and rust, 2x2-texel flecks over dark soil
        fleck = rng.random((h // 2 + 1, w // 2 + 1))[y // 2, x // 2]
        img = np.where((fleck < 0.55)[..., None],
                       np.where((fleck < 0.25)[..., None], [118, 70, 32], [92, 66, 36]),
                       [54, 46, 32]) + n[..., None] * [9, 7, 5]
    elif name == "road":
        # packed dirt with two cart ruts along it (whichever way it runs, ruts read as streaks)
        img = np.array([96, 78, 56]) + n[..., None] * [7, 6, 5]
        img -= (rng.random((h, w)) < 0.05)[..., None] * [20, 16, 12]
    elif name == "mud":
        img = np.array([60, 48, 34]) + n[..., None] * [5, 4, 3]
        img += (rng.random((h, w)) < 0.03)[..., None] * [30, 34, 40]   # puddle glints
    elif name == "undergrowth":
        # brambles and fern under the trees: very dark green and brown
        clump = rng.random((h // 3 + 1, w // 3 + 1))[y // 3, x // 3]
        img = np.where((clump < 0.5)[..., None], [26, 40, 24], [40, 34, 24]) + n[..., None] * [5, 6, 4]
    elif name == "earth":
        img = np.array([88, 72, 54]) + n[..., None] * [6, 5, 4]
        img -= ((x + y) % 7 == 0)[..., None] * [10, 8, 6]                # trodden prints
    elif name == "ash":
        img = np.array([58, 54, 50]) + n[..., None] * [8, 8, 8]
    return img.astype(np.float32)


def main():
    rows = read_rows()
    grid = surfaces(rows)
    ch, cw = len(rows), len(rows[0])
    h, w = ch * PX, cw * PX
    rng = np.random.default_rng(13)
    layers = {name: texture(name, w, h, rng) for name in set(k for row in grid for k in row)}

    # Each texel takes the surface of the cell under a jittered copy of itself, so the edges
    # between surfaces are ragged rather than straight
    y, x = np.mgrid[0:h, 0:w]
    jx = x + rng.normal(0, PX * 0.22, (h, w)); jy = y + rng.normal(0, PX * 0.22, (h, w))
    col = np.clip((jx // PX).astype(int), 0, cw - 1); row = np.clip((jy // PX).astype(int), 0, ch - 1)
    img = np.zeros((h, w, 3), np.float32)
    for name, layer in layers.items():
        mask = np.array([[grid[r][c] == name for c in range(cw)] for r in range(ch)])[row, col]
        img[mask] = layer[mask]

    # A dark ring of roots round each tree
    for r in range(ch):
        for c in range(cw):
            if rows[r][c] == "Y":
                d = np.hypot(x - (c + 0.5) * PX, y - (r + 0.5) * PX) / (PX * 0.9)
                img *= 1 - (np.clip(1 - d, 0, 1) * 0.35)[..., None]

    # Warm glows round the fires and torches
    for r in range(ch):
        for c in range(cw):
            if rows[r][c] in GLOWS:
                radius, strength = GLOWS[rows[r][c]]
                d = np.hypot(x - (c + 0.5) * PX, y - (r + 0.5) * PX) / (PX * radius)
                glow = np.clip(1 - d, 0, 1) ** 2 * strength
                img = img * (1 + glow[..., None] * 0.6) + glow[..., None] * np.array([90, 50, 10])

    img = np.clip(img, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(OUT, "WEBP", quality=85)
    print("%s %dx%d (%d cells of %d texels)" % (OUT, w, h, cw * ch, PX))


if __name__ == "__main__":
    main()
