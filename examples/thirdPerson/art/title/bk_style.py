"""Shared look for Night of the Barrow King art: fonts, weathered lettering,
and the aged-plate treatment. Point BK_TITLE_FONT / BK_SUB_FONT at the
real fonts (Cardo is only a stand-in), e.g.
  BK_TITLE_FONT=fonts/BluuNext-Bold.otf \
  BK_SUB_FONT=fonts/EBGaramond-Italic.ttf \
  BK_BODY_FONT=fonts/EBGaramond-Regular.ttf \
  BK_BODY_BOLD_FONT=fonts/EBGaramond-SemiBold.ttf python3 gen.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

_CARDO = "/usr/share/fonts/truetype/google-fonts/ofl/cardo/"
_BLUU = next((p for p in ("BluuNext-Bold.otf", "fonts/bluu-next/BluuNext-Bold.otf") if os.path.exists(p)), None)
TITLE_FONT = os.environ.get("BK_TITLE_FONT", _BLUU or _CARDO + "Cardo-Bold.ttf")
SUB_FONT = os.environ.get("BK_SUB_FONT", _CARDO + "Cardo-Italic.ttf")          # EB Garamond Italic
BODY_FONT = os.environ.get("BK_BODY_FONT", _CARDO + "Cardo-Regular.ttf")       # EB Garamond Regular
BODY_BOLD_FONT = os.environ.get("BK_BODY_BOLD_FONT", _CARDO + "Cardo-Bold.ttf")  # EB Garamond SemiBold


def fbm(h, w, octaves=6, base=4, persistence=0.55, seed=None):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        gh = base * 2**o * h // max(h, w) + 2
        gw = base * 2**o * w // max(h, w) + 2
        g = r.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += amp * np.asarray(im, np.float32) / 255; tot += amp; amp *= persistence
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)


def _blur(a, r):
    if r <= 0: return a
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im, np.float32) / 255


def weather_title(a, k=1.0, seed=200, light=(0.55, -0.83), strength=1.0):
    """a: glyph coverage 0..1 (H x W). k: scale of the damage (1 = 1080p title).
    strength: how much material is eaten away (use less for thin strokes).
    Returns (alpha, rgb) for carved, eroded, grimy stone lettering."""
    h, w = a.shape
    f = lambda o, b, s: fbm(h, w, o, max(2, int(b / max(k, 0.2))), seed=seed + s)
    # ragged, crumbled edges
    ab = _blur(a, 1.6 * k)
    n = f(5, 140, 1)
    al = smooth(0.40, 0.62, ab + (n - 0.5) * 0.55 * strength)
    # bites taken out of the edges
    edge = smooth(0.05, 0.4, ab) * smooth(0.98, 0.7, ab)
    al *= 1 - smooth(0.62, 0.72, f(4, 70, 2)) * edge * strength
    # pitting through the faces
    al *= 1 - smooth(0.80, 0.88, f(3, 260, 3)) * 0.95 * strength
    al = np.clip(al, 0, 1)

    # carved bevel, lit from the moon (upper right)
    ht = _blur(al, 2.2 * k)
    gy, gx = np.gradient(ht)
    shade = (gx * light[0] + gy * light[1]) * (8 / max(k, 0.8))
    # stone colour: worn bone, mottled, darker and grimier toward the base
    yy = np.linspace(0, 1, h)[:, None]
    lo, hi = np.nonzero(a.max(1) > 0.1)[0][[0, -1]] if (a.max(1) > 0.1).any() else (0, h)
    t = np.clip((np.arange(h)[:, None] - lo) / max(1, hi - lo), 0, 1)
    bone = np.array([176, 166, 140]) / 255
    grime = np.array([92, 84, 66]) / 255
    col = bone * (1 - t[..., None] * 0.55) + grime * (t[..., None] * 0.55)
    mott = f(5, 40, 4)
    col = col * (0.7 + 0.36 * mott[..., None])
    # lichen and rust blooms
    lich = smooth(0.66, 0.8, f(5, 30, 5))
    col = col * (1 - lich[..., None] * 0.6) + np.array([74, 84, 58]) / 255 * lich[..., None] * 0.6
    rust = smooth(0.7, 0.85, f(5, 55, 6)) * t
    col = col * (1 - rust[..., None] * 0.5) + np.array([96, 58, 34]) / 255 * rust[..., None] * 0.5
    # hairline cracks
    rid = 1 - np.abs(2 * f(5, 18, 7) - 1)
    crack = smooth(0.955, 0.99, rid)
    col *= (1 - crack * 0.75)[..., None]
    # grime settles in the pits and edges
    cav = np.clip(ht - _blur(al, 5 * k), -1, 0) * -3
    col *= (1 - np.clip(cav, 0, 0.6))[..., None]
    col = col + shade[..., None] * np.array([1.0, 0.98, 0.9])
    return al, np.clip(col, 0, 1)


def weather_plate(img, seed=300, scratches=True):
    """Aged, damp, damaged-plate finish over a full frame (H x W x 3, 0..1)."""
    h, w, _ = img.shape
    r = np.random.default_rng(seed)
    lum = (img * np.array([0.3, 0.59, 0.11])).sum(-1, keepdims=True)
    img = img * 0.62 + lum * 0.38                    # drain the colour
    tint = np.array([0.92, 1.0, 0.96])                # cold, sickly green-grey
    img = img * tint
    img = np.clip((img - 0.006) * 1.1, 0, 1) ** 1.04  # crush the blacks
    # water stains and mottling
    st = fbm(h, w, 6, 3, seed=seed + 1)
    img *= (0.86 + 0.22 * st)[..., None]
    ring = smooth(0.44, 0.5, st) * smooth(0.56, 0.5, st)
    img *= (1 - ring * 0.1)[..., None]
    # irregular burnt edges
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = np.hypot((xx - w / 2) / (w * 0.58), (yy - h * 0.47) / (h * 0.6))
    v = v + (fbm(h, w, 5, 5, seed=seed + 2) - 0.5) * 0.35
    img *= (1 - smooth(0.7, 1.25, v) * 0.85)[..., None]
    if scratches:
        S = 2
        sc = Image.new("L", (w * S, h * S), 0); d = ImageDraw.Draw(sc)
        dk = Image.new("L", (w * S, h * S), 0); dd = ImageDraw.Draw(dk)
        for _ in range(int(26 * w / 1920)):
            x = r.uniform(0, w) * S; y0 = r.uniform(-0.2, 0.7) * h * S
            ln = r.uniform(0.1, 0.8) * h * S; drift = r.normal(0, 12) * S
            pts = [(x + drift * (i / 8) ** 2 + r.normal(0, 1.2), y0 + ln * i / 8) for i in range(9)]
            (d if r.random() < 0.6 else dd).line(pts, fill=int(r.uniform(40, 120)), width=1)
        for _ in range(int(900 * w / 1920)):
            x, y = r.uniform(0, w) * S, r.uniform(0, h) * S; s = r.uniform(0.6, 2.6) * S
            (d if r.random() < 0.5 else dd).ellipse([x - s, y - s, x + s, y + s], fill=int(r.uniform(30, 140)))
        for _ in range(0):  # hair fibres (off: read as lightning)
            x, y = r.uniform(0, w) * S, r.uniform(0, h) * S
            pts = [(x, y)]
            for i in range(30):
                x += r.normal(2, 3) * S; y += r.normal(0, 3) * S; pts.append((x, y))
            dd.line(pts, fill=90, width=1)
        lt = np.asarray(sc.resize((w, h), Image.LANCZOS), np.float32) / 255
        dkn = np.asarray(dk.resize((w, h), Image.LANCZOS), np.float32) / 255
        img = img + lt[..., None] * np.array([0.55, 0.56, 0.52]) * 0.5
        img = img * (1 - dkn[..., None] * 0.7)
    # luminance-weighted grain
    g = r.normal(0, 1, (h, w, 1)) * (0.012 + 0.03 * np.sqrt(np.clip(img.mean(-1, keepdims=True), 0, 1)))
    return np.clip(img + g, 0, 1)
