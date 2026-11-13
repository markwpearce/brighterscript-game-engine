"""
Low-poly prop generator for examples/thirdPerson.

Outputs (in ./out):
  props_atlas.png   256x320 palette PNG shared by every model (4x5 grid of 64px tiles)
  props.mtl         one material, "props", pointing at the atlas
  *.obj             models: metres, Y-up, origin at the centre of the base, front faces +Z,
                    counter-clockwise winding, flat normals
  grave_*.png       gravestone billboards (RGBA, 32x48)

Change SCALE to export in world units instead (e.g. 32 for World.UNITS_PER_METRE).
Change TILE to 128 for a 512x512 atlas with sharper textures.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw

SCALE = 1.0
TILE = 64
GRID = 4            # tiles across
ROWS = 5            # tiles down; new tiles go on new rows so existing ones keep their place
ATLAS = TILE * GRID
ATLAS_H = TILE * ROWS
INSET = 1.0  # px kept clear at tile edges so bilinear filtering doesn't bleed
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "models", "props")

# ----------------------------------------------------------------------------- textures
T = TILE
def rng(seed): return random.Random(seed)

def noise(img, amt, seed):
    a = np.asarray(img).astype(np.int16)
    r = np.random.default_rng(seed).integers(-amt, amt + 1, a.shape[:2])
    a[..., :3] += r[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), img.mode)

def jitter(c, r, n):
    k = r.randint(-n, n)
    return tuple(max(0, min(255, v + k)) for v in c)

def blocks(w, h, row_h, wmin, wmax, base, mortar, seed, moss=0):
    r = rng(seed)
    im = Image.new("RGBA", (w, h), mortar + (255,))
    d = ImageDraw.Draw(im)
    y = 0
    while y < h:
        x = -r.randint(0, wmax)
        while x < w:
            bw = r.randint(wmin, wmax)
            c = jitter(base, r, 10)
            if moss and y > h - moss * row_h and r.random() < 0.5:
                c = (c[0] - 12, c[1] + 4, c[2] - 14)
            d.rectangle([x + 1, y + 1, x + bw - 1, y + row_h - 1], fill=c + (255,))
            d.line([x + 1, y + 1, x + bw - 1, y + 1], fill=tuple(min(255, v + 14) for v in c) + (255,))
            x += bw
        y += row_h
    return noise(im, 6, seed)

def t_stone():   return blocks(T, T, max(4, T // 12), T // 7, T // 4, (92, 94, 100), (52, 54, 60), 1, moss=2)
def t_flag():
    r = rng(2); im = Image.new("RGBA", (T, T), (60, 60, 64, 255)); d = ImageDraw.Draw(im)
    for gy in range(0, T, T // 4):
        for gx in range(0, T, T // 4):
            ox, oy = r.randint(0, 2), r.randint(0, 2)
            d.rectangle([gx + ox, gy + oy, gx + T // 4 - 2, gy + T // 4 - 2], fill=jitter((84, 84, 88), r, 10) + (255,))
    return noise(im, 7, 2)
def t_tower():
    im = blocks(T, T, max(4, T // 12), T // 6, T // 3, (84, 86, 94), (46, 48, 54), 3, moss=1)
    d = ImageDraw.Draw(im); cx = T // 2
    d.rectangle([cx - T // 32 - 1, T // 6, cx + T // 32, T // 6 + T // 4], fill=(14, 14, 18, 255))      # arrow slit
    d.rectangle([cx - T // 32 - 1, T // 2 + 4, cx + T // 32, T // 2 + 4 + T // 6], fill=(14, 14, 18, 255))
    return im
def t_slate():
    r = rng(4); im = Image.new("RGBA", (T, T), (34, 38, 46, 255)); d = ImageDraw.Draw(im)
    rh = max(3, T // 14)
    for i, y in enumerate(range(0, T, rh)):
        x = -(i % 2) * (T // 16)
        while x < T:
            w = T // 8
            d.rectangle([x + 1, y, x + w - 1, y + rh - 2], fill=jitter((60, 66, 78), r, 9) + (255,))
            x += w
    return noise(im, 5, 4)
def t_thatch():
    r = rng(5); im = Image.new("RGBA", (T, T), (98, 80, 46, 255)); d = ImageDraw.Draw(im)
    for _ in range(T * 6):
        x = r.randint(0, T); y = r.randint(0, T); l = r.randint(T // 10, T // 4)
        d.line([x, y, x + r.randint(-1, 1), y + l], fill=jitter((120, 98, 56), r, 22) + (255,))
    for y in range(T // 5, T, T // 5):
        d.line([0, y, T, y], fill=(70, 56, 32, 255))
    return noise(im, 5, 5)
def plaster(seed, col=(150, 138, 112)):
    return noise(Image.new("RGBA", (T, T), col + (255,)), 9, seed)
def beam(d, box, col=(58, 40, 26)): d.rectangle(box, fill=col + (255,))
def window(d, cx, cy, w, h):
    d.rectangle([cx - w // 2 - 1, cy - h // 2 - 1, cx + w // 2 + 1, cy + h // 2 + 1], fill=(48, 32, 20, 255))
    d.rectangle([cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2], fill=(236, 168, 70, 255))   # warm lit glass
    d.line([cx, cy - h // 2, cx, cy + h // 2], fill=(48, 32, 20, 255))
    d.line([cx - w // 2, cy, cx + w // 2, cy], fill=(48, 32, 20, 255))
def door(d, cx, bottom, w, h, col=(72, 48, 28)):
    d.rectangle([cx - w // 2 - 1, bottom - h - 1, cx + w // 2 + 1, bottom], fill=(36, 24, 14, 255))
    d.rectangle([cx - w // 2, bottom - h, cx + w // 2, bottom], fill=col + (255,))
    for x in range(cx - w // 2 + 3, cx + w // 2, 3): d.line([x, bottom - h, x, bottom], fill=(56, 36, 20, 255))
    d.point([cx + w // 2 - 2, bottom - h // 2], fill=(160, 150, 120, 255))
def t_hutwall(with_door):
    im = plaster(6, (122, 104, 74)); d = ImageDraw.Draw(im); b = max(2, T // 21)
    beam(d, [0, 0, b, T]); beam(d, [T - b - 1, 0, T, T]); beam(d, [0, 0, T, b]); beam(d, [0, T - b - 1, T, T])
    if with_door: door(d, T // 2, T - 1, T // 4, int(T * 0.8))
    else: window(d, T // 2, T // 2 - 2, T // 8, T // 7)
    return im
def t_housefront():  # 6 m x 5.5 m
    im = plaster(7); d = ImageDraw.Draw(im); b = max(2, T // 32)
    for x in (0, T // 3, 2 * T // 3, T - b - 1): beam(d, [x, 0, x + b, T])
    beam(d, [0, T // 2, T, T // 2 + b]); beam(d, [0, 0, T, b]); beam(d, [0, T - b - 1, T, T])
    door(d, T // 2, T - 1, T // 5, int(T * 0.4))
    window(d, T // 6, int(T * 0.72), T // 9, T // 8); window(d, 5 * T // 6, int(T * 0.72), T // 9, T // 8)
    for cx in (T // 6, T // 2, 5 * T // 6): window(d, cx, T // 4, T // 9, T // 8)
    return im
def t_housewall():   # 8 m x 5.5 m
    im = plaster(8); d = ImageDraw.Draw(im); b = max(2, T // 32)
    for x in (0, T // 4, T // 2, 3 * T // 4, T - b - 1): beam(d, [x, 0, x + b, T])
    beam(d, [0, T // 2, T, T // 2 + b]); beam(d, [0, 0, T, b]); beam(d, [0, T - b - 1, T, T])
    for q in range(4):
        x0 = q * T // 4
        d.line([x0, T // 2, x0 + T // 4, T], fill=(58, 40, 26, 255), width=b)
    for cx in (3 * T // 8, 5 * T // 8): window(d, cx, T // 4, T // 10, T // 8)
    return im
def t_gable():       # triangle UV (0,0) (1,0) (0.5,1)
    im = plaster(9); d = ImageDraw.Draw(im); b = max(2, T // 32)
    beam(d, [0, T - b - 1, T, T]); beam(d, [T // 2 - b // 2, 0, T // 2 + b // 2, T])
    d.line([T // 4, T, T // 2, T // 2], fill=(58, 40, 26, 255), width=b)
    d.line([3 * T // 4, T, T // 2, T // 2], fill=(58, 40, 26, 255), width=b)
    window(d, T // 2, int(T * 0.68), T // 8, T // 7)
    return im
def t_cryptside(): return blocks(T, T, max(5, T // 8), T // 4, T // 2, (70, 72, 74), (36, 38, 40), 10, moss=3)
def t_cryptfront():
    im = t_cryptside(); d = ImageDraw.Draw(im); cx = T // 2
    d.rectangle([cx - T // 5 - 2, T // 4 - 2, cx + T // 5 + 2, T], fill=(54, 56, 58, 255))          # door frame
    d.rectangle([cx - T // 5, T // 4 + 4, cx + T // 5, T], fill=(26, 28, 30, 255))                 # iron door
    for x in range(cx - T // 5 + 3, cx + T // 5, max(3, T // 16)):
        d.line([x, T // 4 + 4, x, T], fill=(46, 40, 36, 255))
    d.line([cx - T // 5, T // 2, cx + T // 5, T // 2], fill=(46, 40, 36, 255))
    d.rectangle([cx - 1, T // 16, cx + 1, T // 5], fill=(110, 112, 114, 255))                     # carved cross
    d.rectangle([cx - T // 20, T // 10, cx + T // 20, T // 10 + 2], fill=(110, 112, 114, 255))
    return im
def t_wood():
    r = rng(12); im = Image.new("RGBA", (T, T), (78, 56, 36, 255)); d = ImageDraw.Draw(im)
    for x in range(0, T, T // 8):
        d.rectangle([x, 0, x + T // 8 - 2, T], fill=jitter((92, 66, 42), r, 10) + (255,))
    for _ in range(T): d.point([r.randint(0, T), r.randint(0, T)], fill=(60, 42, 26, 255))
    return noise(im, 5, 12)
def t_wellstone(): return blocks(T, T, max(4, T // 6), T // 6, T // 3, (100, 96, 88), (50, 48, 44), 13, moss=2)
def t_water():
    im = blocks(T, T, max(4, T // 8), T // 6, T // 4, (100, 96, 88), (50, 48, 44), 14)
    d = ImageDraw.Draw(im); m = T // 6
    d.rectangle([m, m, T - m, T - m], fill=(10, 14, 22, 255))
    d.line([m + 4, T // 2, T - m - 8, T // 2 - 2], fill=(40, 52, 70, 255))
    return im
def t_fence():       # alpha cut-out pickets
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im); r = rng(15)
    n = 10; pw = T / n
    for i in range(n):
        x0 = int(i * pw + 1); x1 = int((i + 1) * pw - 1); top = T // 10 + r.randint(0, T // 16)
        c = jitter((88, 66, 44), r, 10) + (255,)
        d.rectangle([x0, top + 2, x1, T - 1], fill=c)
        d.polygon([(x0, top + 2), ((x0 + x1) / 2, top - 1), (x1, top + 2)], fill=c)
    for y in (int(T * 0.35), int(T * 0.75)):
        d.rectangle([0, y, T, y + max(2, T // 20)], fill=(70, 50, 32, 255))
    return im

def t_keepdoor():     # big arched door in a stone wall
    im = blocks(T, T, max(4, T // 12), T // 6, T // 3, (84, 86, 94), (46, 48, 54), 16, moss=1)
    d = ImageDraw.Draw(im); cx, w = T // 2, T // 3
    d.rectangle([cx - w // 2 - 3, T // 3, cx + w // 2 + 3, T], fill=(62, 62, 66, 255))
    d.ellipse([cx - w // 2 - 3, T // 3 - w // 2 - 3, cx + w // 2 + 3, T // 3 + w // 2 + 3], fill=(62, 62, 66, 255))
    d.ellipse([cx - w // 2, T // 3 - w // 2, cx + w // 2, T // 3 + w // 2], fill=(72, 48, 28, 255))
    d.rectangle([cx - w // 2, T // 3, cx + w // 2, T], fill=(72, 48, 28, 255))
    for x in range(cx - w // 2 + 3, cx + w // 2, 3): d.line([x, T // 3 - w // 3, x, T], fill=(56, 36, 20, 255))
    for y in (T // 2, 3 * T // 4): d.line([cx - w // 2, y, cx + w // 2, y], fill=(30, 30, 32, 255), width=2)
    return im
def t_iron():
    r = rng(17); im = Image.new("RGBA", (T, T), (34, 32, 32, 255)); d = ImageDraw.Draw(im)
    for y in range(0, T, T // 8): d.line([0, y, T, y], fill=jitter((50, 46, 44), r, 6) + (255,))
    return noise(im, 6, 17)
def t_merlons():      # alpha cut-out battlements along the top of a wall
    im = blocks(T, T, max(4, T // 8), T // 6, T // 3, (88, 90, 98), (48, 50, 56), 18)
    a = np.asarray(im).copy(); n = 4; w = T // n
    for i in range(n): a[: T // 2, i * w + w // 2: (i + 1) * w, 3] = 0
    return Image.fromarray(a, "RGBA")
def t_banner():       # the keep's red banner
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(T // 4, 0), (3 * T // 4, 0), (3 * T // 4, T - 1), (T // 2, 3 * T // 4), (T // 4, T - 1)], fill=(120, 24, 28, 255))
    d.polygon([(T // 2, T // 6), (T // 2 + 8, T // 3), (T // 2, T // 2), (T // 2 - 8, T // 3)], fill=(200, 170, 70, 255))
    return noise(im, 5, 19)

TILES = [  # name, builder          grid position = index (row-major)
    ("stone", t_stone), ("flag", t_flag), ("tower", t_tower), ("slate", t_slate),
    ("housefront", t_housefront), ("housewall", t_housewall), ("gable", t_gable), ("thatch", t_thatch),
    ("hutdoor", lambda: t_hutwall(True)), ("hutwall", lambda: t_hutwall(False)), ("cryptfront", t_cryptfront), ("cryptside", t_cryptside),
    ("wood", t_wood), ("wellstone", t_wellstone), ("water", t_water), ("fence", t_fence),
    ("keepdoor", t_keepdoor), ("iron", t_iron), ("merlons", t_merlons), ("banner", t_banner),
]
TILE_INDEX = {n: i for i, (n, _) in enumerate(TILES)}

def build_atlas():
    atlas = Image.new("RGBA", (ATLAS, ATLAS_H), (0, 0, 0, 0))
    for i, (_, fn) in enumerate(TILES):
        atlas.paste(fn(), ((i % GRID) * T, (i // GRID) * T))
    return atlas

# ----------------------------------------------------------------------------- graves (billboards)
def grave(kind, seed):
    W, H = 32, 48; im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im); r = rng(seed)
    stone, dark, light = (104, 106, 110, 255), (60, 62, 66, 255), (134, 136, 140, 255)
    if kind == "slab":
        d.rectangle([6, 14, 25, 47], fill=stone); d.ellipse([6, 4, 25, 24], fill=stone)
        d.line([7, 14, 7, 47], fill=light); d.line([25, 14, 25, 47], fill=dark)
        d.line([12, 20, 19, 20], fill=dark); d.line([11, 25, 20, 25], fill=dark); d.line([12, 29, 19, 29], fill=dark)
    elif kind == "cross":
        d.rectangle([13, 4, 18, 47], fill=stone); d.rectangle([5, 13, 26, 18], fill=stone)
        d.line([13, 4, 13, 47], fill=light); d.line([18, 19, 18, 47], fill=dark); d.line([5, 18, 26, 18], fill=dark)
        d.rectangle([10, 42, 21, 47], fill=dark)
    else:  # broken, leaning
        tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0)); t = ImageDraw.Draw(tmp)
        t.polygon([(7, 47), (7, 18), (12, 14), (16, 19), (20, 13), (25, 17), (25, 47)], fill=stone)
        t.line([7, 18, 7, 47], fill=light); t.line([25, 17, 25, 47], fill=dark); t.line([13, 26, 19, 26], fill=dark)
        im = tmp.rotate(-9, resample=Image.NEAREST, center=(16, 47)); d = ImageDraw.Draw(im)
    for y in range(41, 48):  # moss at the base
        for x in range(W):
            if im.getpixel((x, y))[3] and r.random() < 0.45: d.point([x, y], fill=(62, 76, 50, 255))
    return noise(im, 6, seed)

# ----------------------------------------------------------------------------- geometry
class Model:
    def __init__(self, name): self.name, self.v, self.vt, self.vn, self.f = name, [], [], [], []
    def _uv(self, tile, s, t):
        i = TILE_INDEX[tile]; col, row = i % GRID, i // GRID
        px = col * T + INSET + s * (T - 2 * INSET)
        py = row * T + INSET + (1 - t) * (T - 2 * INSET)
        return (px / ATLAS, 1 - py / ATLAS_H)
    def tri(self, a, b, c, tile, ua, ub, uc):
        a, b, c = map(np.array, (a, b, c))
        n = np.cross(b - a, c - a); n = n / np.linalg.norm(n)
        self.vn.append(tuple(n)); ni = len(self.vn)
        idx = []
        for p, uv in ((a, ua), (b, ub), (c, uc)):
            self.v.append(tuple(p * SCALE)); self.vt.append(self._uv(tile, *uv))
            idx.append((len(self.v), len(self.vt), ni))
        self.f.append(idx)
    def quad(self, p0, p1, p2, p3, tile, uv=(0, 0, 1, 1)):
        """p0 bottom-left, p1 bottom-right, p2 top-right, p3 top-left, seen from the front."""
        u0, v0, u1, v1 = uv
        self.tri(p0, p1, p2, tile, (u0, v0), (u1, v0), (u1, v1))
        self.tri(p0, p2, p3, tile, (u0, v0), (u1, v1), (u0, v1))
    def gable(self, p0, p1, apex, tile):
        self.tri(p0, p1, apex, tile, (0, 0), (1, 0), (0.5, 1))
    @property
    def tris(self): return len(self.f)
    def write(self, path):
        with open(path, "w") as fh:
            fh.write(f"# {self.name}: {self.tris} triangles, units={'metres' if SCALE == 1 else SCALE}, Y-up\n")
            fh.write("mtllib props.mtl\no %s\n" % self.name)
            # de-duplicate positions/uvs for a smaller file
            vmap, tmap, vs, ts = {}, {}, [], []
            for p in self.v:
                k = tuple(round(x, 4) for x in p)
                if k not in vmap: vmap[k] = len(vs) + 1; vs.append(k)
            for uv in self.vt:
                k = tuple(round(x, 5) for x in uv)
                if k not in tmap: tmap[k] = len(ts) + 1; ts.append(k)
            for p in vs: fh.write("v %g %g %g\n" % p)
            for uv in ts: fh.write("vt %g %g\n" % uv)
            for n in self.vn: fh.write("vn %.4f %.4f %.4f\n" % n)
            fh.write("usemtl props\ns off\n")
            for face in self.f:
                fh.write("f " + " ".join(
                    f"{vmap[tuple(round(x, 4) for x in self.v[vi - 1])]}/{tmap[tuple(round(x, 5) for x in self.vt[ti - 1])]}/{ni}"
                    for vi, ti, ni in face) + "\n")

def box_walls(m, x0, x1, z0, z1, y0, y1, front, back, left, right):
    """Four outward-facing walls of an axis-aligned box (no top/bottom)."""
    m.quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), *front)   # +Z
    m.quad((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), *back)    # -Z
    m.quad((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), *left)    # -X
    m.quad((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), *right)   # +X

def gabled_building(name, w, d, wall_h, ridge_h, front, back, side, gable, roof):
    """Ridge runs front-to-back (along Z) so both gables face +Z/-Z."""
    m = Model(name); x, z = w / 2, d / 2
    box_walls(m, -x, x, -z, z, 0, wall_h, (front,), (back,), (side,), (side,))
    m.gable((-x, wall_h, z), (x, wall_h, z), (0, ridge_h, z), gable)
    m.gable((x, wall_h, -z), (-x, wall_h, -z), (0, ridge_h, -z), gable)
    m.quad((x, wall_h, z), (x, wall_h, -z), (0, ridge_h, -z), (0, ridge_h, z), roof)    # right slope
    m.quad((-x, wall_h, -z), (-x, wall_h, z), (0, ridge_h, z), (0, ridge_h, -z), roof)  # left slope
    return m

def prism(m, p_bottom, p_top, r, tile, axis="y"):
    """3-sided post/beam between two points (no caps)."""
    a, b = np.array(p_bottom, float), np.array(p_top, float)
    ax = (b - a) / np.linalg.norm(b - a)
    ref = np.array([0, 0, 1.0]) if abs(ax[2]) < 0.9 else np.array([1.0, 0, 0])
    u = np.cross(ax, ref); u /= np.linalg.norm(u); v = np.cross(ax, u)
    offs = [r * (math.cos(k * 2 * math.pi / 3) * u + math.sin(k * 2 * math.pi / 3) * v) for k in range(3)]
    for k in range(3):
        o0, o1 = offs[k], offs[(k + 1) % 3]
        m.quad(a + o0, a + o1, b + o1, b + o0, tile, (k / 3, 0, (k + 1) / 3, 1))

def models():
    out = []
    # --- town wall segment: 8 m long, 6 m tall, 1.5 m thick. Tiles end-to-end along X.
    L, H, Th = 8.0, 6.0, 1.5; x, z = L / 2, Th / 2
    m = Model("wall_segment")
    box_walls(m, -x, x, -z, z, 0, H, ("stone",), ("stone",), ("stone", (0, 0, Th / L, 1)), ("stone", (0, 0, Th / L, 1)))
    m.quad((-x, H, z), (x, H, z), (x, H, -z), (-x, H, -z), "flag")
    out.append(m)

    # --- wall tower: 4 x 4 m, 8 m to the eaves, pyramid roof to 11 m.
    m = Model("wall_tower"); s, h, p = 2.0, 8.0, 11.0
    box_walls(m, -s, s, -s, s, 0, h, ("tower",), ("tower",), ("tower",), ("tower",))
    for a, b in (((-s, h, s), (s, h, s)), ((s, h, s), (s, h, -s)), ((s, h, -s), (-s, h, -s)), ((-s, h, -s), (-s, h, s))):
        m.gable(a, b, (0, p, 0), "slate")
    out.append(m)

    # --- gatehouse wall: same size as a segment with a 3.5 x 4 m passage through it.
    m = Model("wall_gate"); g, gh = 1.75, 4.0
    U = lambda a: (a + x) / L; V = lambda b: b / H
    for zz, sign in ((z, 1), (-z, -1)):
        def q(xa, xb, ya, yb):
            if sign > 0: m.quad((xa, ya, zz), (xb, ya, zz), (xb, yb, zz), (xa, yb, zz), "stone", (U(xa), V(ya), U(xb), V(yb)))
            else:        m.quad((xb, ya, zz), (xa, ya, zz), (xa, yb, zz), (xb, yb, zz), "stone", (1 - U(xb), V(ya), 1 - U(xa), V(yb)))
        q(-x, -g, 0, H); q(g, x, 0, H); q(-g, g, gh, H)
    m.quad((-x, 0, -z), (-x, 0, z), (-x, H, z), (-x, H, -z), "stone", (0, 0, Th / L, 1))
    m.quad((x, 0, z), (x, 0, -z), (x, H, -z), (x, H, z), "stone", (0, 0, Th / L, 1))
    m.quad((-x, H, z), (x, H, z), (x, H, -z), (-x, H, -z), "flag")
    m.quad((-g, 0, z), (-g, 0, -z), (-g, gh, -z), (-g, gh, z), "stone", (0, 0, Th / L, gh / H))   # passage left wall (faces +X)
    m.quad((g, 0, -z), (g, 0, z), (g, gh, z), (g, gh, -z), "stone", (0, 0, Th / L, gh / H))       # passage right wall (faces -X)
    m.quad((-g, gh, -z), (g, gh, -z), (g, gh, z), (-g, gh, z), "flag", (0, 0, 2 * g / L, Th / L))  # passage ceiling (faces down)
    out.append(m)

    out.append(gabled_building("hut", 4.0, 5.0, 2.4, 4.6, "hutdoor", "hutwall", "hutwall", "hutwall", "thatch"))

    m = gabled_building("house", 6.0, 8.0, 5.5, 8.5, "housefront", "housewall", "housewall", "gable", "slate")
    cx, cz, c = 1.7, -1.8, 0.45          # chimney rises out of the right roof slope
    box_walls(m, cx - c, cx + c, cz - c, cz + c, 6.2, 9.6,
              ("stone", (0, 0, .15, .5)), ("stone", (0, 0, .15, .5)), ("stone", (0, 0, .15, .5)), ("stone", (0, 0, .15, .5)))
    out.append(m)

    out.append(gabled_building("crypt", 3.6, 4.5, 2.6, 3.6, "cryptfront", "cryptside", "cryptside", "cryptside", "flag"))

    # --- well: 1.8 m stone box, dark water top, winch frame.
    m = Model("well"); s, h = 0.9, 0.9
    box_walls(m, -s, s, -s, s, 0, h, ("wellstone",), ("wellstone",), ("wellstone",), ("wellstone",))
    m.quad((-s, h, s), (s, h, s), (s, h, -s), (-s, h, -s), "water")
    prism(m, (-0.8, h, 0), (-0.8, 2.3, 0), 0.09, "wood")
    prism(m, (0.8, h, 0), (0.8, 2.3, 0), 0.09, "wood")
    prism(m, (-0.85, 2.15, 0), (0.85, 2.15, 0), 0.07, "wood")
    out.append(m)

    # --- keep: 10 x 10 m stone tower, 13 m to the battlements' foot, door and banner on the front.
    m = Model("keep"); s, h, cols, rows = 5.0, 13.0, 2, 3
    def face(corner, along, tiles):
        # cols x rows quads so the tower tile keeps its size; tiles(col, row) picks each one
        c, a = np.array(corner, float), np.array(along, float)
        for col in range(cols):
            for row in range(rows):
                p0 = c + a * (2 * s * col / cols) + np.array([0, h * row / rows, 0])
                p1 = c + a * (2 * s * (col + 1) / cols) + np.array([0, h * row / rows, 0])
                up = np.array([0, h / rows, 0])
                m.quad(p0, p1, p1 + up, p0 + up, tiles(col, row))
    face((-s, 0, s), (1, 0, 0), lambda c, r: "keepdoor" if (c, r) == (1, 0) else "tower")    # +Z, the door
    face((s, 0, -s), (-1, 0, 0), lambda c, r: "tower")                                      # -Z
    face((-s, 0, -s), (0, 0, 1), lambda c, r: "tower")                                      # -X
    face((s, 0, s), (0, 0, -1), lambda c, r: "tower")                                       # +X
    mh = 1.6
    box_walls(m, -s, s, -s, s, h, h + mh, ("merlons", (0, 0, 1, 1)), ("merlons",), ("merlons",), ("merlons",))
    # banner hung on the front above the door, just proud of the wall
    m.quad((-0.9, 5.0, s + 0.05), (0.9, 5.0, s + 0.05), (0.9, 9.0, s + 0.05), (-0.9, 9.0, s + 0.05), "banner")
    out.append(m)

    # --- wall torch: an iron bracket out of a wall (the wall is z 0, front +Z) holding a short
    # torch whose tip, where the flame sits, is at (0, 2.75, 0.4).
    m = Model("torch_wall")
    prism(m, (0, 2.2, 0.0), (0, 2.35, 0.32), 0.04, "iron")
    prism(m, (0, 2.3, 0.36), (0, 2.75, 0.4), 0.06, "wood")
    out.append(m)

    # --- fence: 3 m x 1.2 m alpha cut-out, both sides.
    m = Model("fence"); fx = 1.5
    m.quad((-fx, 0, 0), (fx, 0, 0), (fx, 1.2, 0), (-fx, 1.2, 0), "fence")
    m.quad((fx, 0, 0), (-fx, 0, 0), (-fx, 1.2, 0), (fx, 1.2, 0), "fence")
    out.append(m)
    return out

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    atlas = build_atlas()
    atlas.quantize(colors=128, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, "props_atlas.png"), optimize=True)
    with open(os.path.join(OUT, "props.mtl"), "w") as fh:
        fh.write("newmtl props\nKa 1 1 1\nKd 1 1 1\nKs 0 0 0\nd 1\nillum 1\nmap_Kd props_atlas.png\n")
    for k, seed in (("slab", 20), ("cross", 21), ("broken", 22)):
        grave(k, seed).quantize(colors=32, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, f"grave_{k}.png"), optimize=True)
    for m in models():
        m.write(os.path.join(OUT, m.name + ".obj"))
        print(f"{m.name:14s} {m.tris:3d} tris")
