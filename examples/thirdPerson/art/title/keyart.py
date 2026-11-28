"""Night of the Barrow King - splash, title mockup, logo and Roku icons built
on the painted key art (keyart_source.png). Fonts come from bk_style, e.g.
  BK_TITLE_FONT=fonts/bluu-next/BluuNext-Bold.otf python3 keyart.py"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
from bk_style import TITLE_FONT, SUB_FONT, BODY_FONT, BODY_BOLD_FONT, weather_title, smooth

SRC = Image.open("keyart_source.png").convert("RGB")      # 1376x768
SW, SH = SRC.size

def fit_16x9(im, w, h):
    sw, sh = im.size
    cw = round(sh * w / h)
    x0 = (sw - cw) // 2
    return im.crop((x0, 0, x0 + cw, sh)).resize((w, h), Image.LANCZOS)

def f32(im): return np.asarray(im, np.float32) / 255
def to_img(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))

def tracked(draw, text, font, cx, base, track, fill=255):
    ws = [draw.textlength(c, font=font) for c in text]
    x = cx - (sum(ws) + track * (len(text) - 1)) / 2
    for c, w_ in zip(text, ws):
        draw.text((x, base), c, font=font, fill=fill, anchor="ls"); x += w_ + track
    return sum(ws) + track * (len(text) - 1)

def title(w, h, cx, base_big, big_px, sub_px, track, rules=True, wear=1.0, k=1.0, ss=2):
    """Weathered title lockup. Returns alpha, soft shadow, colour (all w x h)."""
    m = Image.new("L", (w * ss, h * ss), 0); d = ImageDraw.Draw(m)
    m2 = Image.new("L", (w * ss, h * ss), 0); d2 = ImageDraw.Draw(m2)
    big = ImageFont.truetype(TITLE_FONT, int(big_px * ss))
    sub = ImageFont.truetype(SUB_FONT, int(sub_px * ss))
    tw = tracked(d, "BARROW KING", big, cx * ss, base_big * ss, track * ss)
    sb = base_big - big_px * 0.95
    d2.text((cx * ss, sb * ss), "Night of the", font=sub, fill=255, anchor="ms")
    if rules:
        ry = (sb - sub_px * 0.3) * ss
        for sg in (-1, 1):
            x0 = cx * ss + sg * sub_px * 3.4 * ss; x1 = cx * ss + sg * tw / 2
            d2.line([(x0, ry), (x1, ry)], fill=200, width=max(2, int(sub_px / 18 * ss)))
            q = sub_px / 9 * ss
            d2.polygon([(x1, ry - q), (x1 + sg * q * 1.6, ry), (x1, ry + q), (x1 - sg * q * 1.6, ry)], fill=220)
    a = f32(m.resize((w, h), Image.LANCZOS)); a2 = f32(m2.resize((w, h), Image.LANCZOS))
    a, col = weather_title(a, k=k, seed=200, strength=wear)
    b, col2 = weather_title(a2, k=k * 0.5, seed=220, strength=wear * 0.12)
    col = np.where(b[..., None] > a[..., None], col2, col); a = np.maximum(a, b)
    lower = np.clip(a - np.roll(a, -max(1, int(3 * k)), axis=0), 0, 1)
    col = np.clip(col + lower[..., None] * np.array([120, 190, 210]) / 255 * 0.25, 0, 1)
    sh = ndi.gaussian_filter(a, max(1.5, 12 * k))
    return a, sh, col

def comp(bg, a, sh, col, shadow=0.85):
    out = bg * (1 - np.clip(sh * shadow, 0, 1))[..., None]
    return out * (1 - a[..., None]) + col * a[..., None]

def top_scrim(bg, y0, y1, amt):
    yy = np.arange(bg.shape[0], dtype=np.float32)[:, None]
    return bg * (1 - smooth(y1, y0, yy) * amt)[..., None]

# ---------- splash 1920x1080 ----------
W, H = 1920, 1080
bg = f32(fit_16x9(SRC, W, H))
bg = top_scrim(bg, 0, 330, 0.45)          # deepen the sky band so the title reads
a, sh, col = title(W, H, W / 2, 212, 132, 46, 16, k=0.8)
splash = comp(bg, a, sh, col)
to_img(splash).save("splash_fhd.jpg", quality=94)
to_img(splash).resize((1280, 720), Image.LANCZOS).save("splash_hd.jpg", quality=94)
to_img(bg).save("title_backdrop_fhd.jpg", quality=94)

# transparent logo for overlays
alpha = np.clip(np.maximum(a, sh * 0.7), 0, 1)
rgba = np.zeros((H, W, 4), np.float32)
rgba[..., :3] = np.where(alpha[..., None] > 0, col * a[..., None] / np.maximum(alpha[..., None], 1e-4), 0)
rgba[..., 3] = alpha
logo = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
bb = logo.getbbox(); pad = 24
logo.crop((bb[0] - pad, bb[1] - pad, bb[2] + pad, bb[3] + pad)).save("title_logo.png")

# ---------- title screen mockup ----------
mock = to_img(splash).convert("RGBA")
yy = np.arange(H, dtype=np.float32)[:, None]
band = np.zeros((H, W, 4), np.uint8); band[..., 3] = np.broadcast_to(smooth(890, 1010, yy) * 170, (H, W)).astype(np.uint8)
mock = Image.alpha_composite(mock, Image.fromarray(band, "RGBA"))
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0)); od = ImageDraw.Draw(ov)
mf = ImageFont.truetype(BODY_FONT, 44); mfb = ImageFont.truetype(BODY_BOLD_FONT, 44)
items = ["Continue", "New Game", "Options", "Credits"]
y0, gap = 1000, 96
fonts = [mfb if i == 0 else mf for i in range(len(items))]
widths = [od.textlength(it, font=f) for it, f in zip(items, fonts)]
x = W / 2 - (sum(widths) + gap * (len(items) - 1)) / 2
for i, (it, f, w_) in enumerate(zip(items, fonts, widths)):
    sel = i == 0
    od.text((x, y0), it, font=f, fill=(226, 234, 232, 255) if sel else (150, 160, 162, 200), anchor="ls")
    if sel: od.line([(x, y0 + 16), (x + w_, y0 + 16)], fill=(140, 210, 230, 230), width=3)
    x += w_ + gap
Image.alpha_composite(mock, ov).convert("RGB").save("title_screen_mock.png")

# ---------- Roku channel posters (4:3) ----------
POSTER_BOX = (330, 0, 1130, 600)   # in source pixels: knight, king and sky above the crown
for name, (w, h, big, sub, tr, base, wear) in {
        "icon_focus_fhd.png": (540, 405, 58, 24, 7, 100, 0.5),
        "icon_focus_hd.png": (290, 218, 31, 15, 3, 54, 0.25)}.items():
    p = f32(SRC.crop(POSTER_BOX).resize((w, h), Image.LANCZOS))
    p = top_scrim(p, 0, h * 0.3, 0.45)
    a, sh, col = title(w, h, w / 2, base, big, sub, tr, rules=False, wear=wear, k=w / 1920 * 1.2, ss=4)
    to_img(comp(p, a, sh, np.clip(col * 1.1, 0, 1))).save(name, optimize=True)
print("done")
