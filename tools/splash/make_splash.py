#!/usr/bin/env python3
"""
BrighterScript Game Engine splash asset generator.

Outputs (per resolution):
  bge_title_<res>.webp          white-on-transparent title text (two lines)
  bge_cannon_<res>.webp         white-on-transparent cannon sprite sheet (4x2 grid)
  bge_cannonball_<res>.webp     white-on-transparent cannonball sprite
  bge_cannon_<res>.json         frame rects, durations, body rect, ball spawn info

All art is pure white with alpha, so it can be tinted with blendColor
(SceneGraph Poster) or the rgba argument of roBitmap.DrawObject / DrawScaledObject.

Fonts: Montserrat (SIL Open Font License 1.1).
Requires: Pillow (with WebP), numpy, scipy.
"""
import json, math, os, sys, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt as edt

MONTSERRAT = os.environ.get(
    "MONTSERRAT", "/usr/share/fonts/truetype/google-fonts/ofl/montserrat/Montserrat[wght].ttf")

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)

SS = 4  # supersampling for the cannon art


def font(size, weight):
    f = ImageFont.truetype(MONTSERRAT, size)
    f.set_variation_by_name(weight)
    return f


# --------------------------------------------------------------------------- text
def draw_tracked(draw, xy, text, fnt, tracking):
    x, y = xy
    for i, ch in enumerate(text):
        draw.text((x, y), ch, font=fnt, fill=255)
        if i + 1 < len(text):
            pair = fnt.getlength(ch + text[i + 1]) - fnt.getlength(text[i + 1])
            x += pair + tracking


def tracked_width(text, fnt, tracking):
    w = 0
    for i, ch in enumerate(text):
        if i + 1 < len(text):
            w += fnt.getlength(ch + text[i + 1]) - fnt.getlength(text[i + 1]) + tracking
        else:
            w += fnt.getlength(ch)
    return w


def make_title(size1):
    f1 = font(size1, b"ExtraBold")
    size2 = round(size1 * 0.60)
    f2 = font(size2, b"SemiBold")
    track1 = size1 * 0.015
    track2 = size2 * 0.30

    # cap heights via ink boxes
    cap1 = f1.getbbox("H", anchor="ls")
    cap1_h = -cap1[1]
    gap = cap1_h * 0.42

    W = int(tracked_width("BRIGHTERSCRIPT", f1, track1) + size1)
    Hc = int(size1 * 3)
    img = Image.new("L", (W, Hc), 0)
    d = ImageDraw.Draw(img)
    base1 = size1 * 1.2
    # draw with baseline anchor
    x = size1 * 0.3
    xx = x
    t = "BRIGHTERSCRIPT"
    for i, ch in enumerate(t):
        d.text((xx, base1), ch, font=f1, fill=255, anchor="ls")
        if i + 1 < len(t):
            xx += f1.getlength(ch + t[i + 1]) - f1.getlength(t[i + 1]) + track1
    cap2 = -f2.getbbox("H", anchor="ls")[1]
    base2 = base1 + gap + cap2
    t = "GAME ENGINE"
    xx = x + size1 * 0.02
    for i, ch in enumerate(t):
        d.text((xx, base2), ch, font=f2, fill=255, anchor="ls")
        if i + 1 < len(t):
            xx += f2.getlength(ch + t[i + 1]) - f2.getlength(t[i + 1]) + track2
    bbox = img.getbbox()
    img = img.crop(bbox)
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.putalpha(img)
    return out


# --------------------------------------------------------------------------- cannon geometry (units)
C = np.array([700.0, 720.0])   # wheel centre
R_WHEEL = 265.0
P = np.array([665.0, 430.0])   # barrel pivot (trunnion)
BASE_ANGLE = 30.0
T = 66.0                       # outline stroke
G = 36.0                       # knockout gap between parts


class Canvas:
    def __init__(self, x0, y0, x1, y1, k):
        self.x0, self.y0, self.k = x0, y0, k
        self.w = int(math.ceil((x1 - x0) * k))
        self.h = int(math.ceil((y1 - y0) * k))
        self.alpha = np.zeros((self.h, self.w), np.float32)

    def px(self, p):
        return ((p[0] - self.x0) * self.k, (p[1] - self.y0) * self.k)

    def new_mask(self):
        im = Image.new("L", (self.w, self.h), 0)
        return im, ImageDraw.Draw(im)

    # primitives drawn into a PIL mask
    def circle(self, d, c, r, fill=255):
        x, y = self.px(c)
        rr = r * self.k
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=fill)

    def poly(self, d, pts, fill=255):
        d.polygon([self.px(p) for p in pts], fill=fill)

    def capsule(self, d, a, b, r, fill=255):
        a, b = np.asarray(a), np.asarray(b)
        v = b - a
        L = np.linalg.norm(v)
        n = np.array([-v[1], v[0]]) / L * r
        self.poly(d, [a + n, b + n, b - n, a - n], fill)
        self.circle(d, a, r, fill)
        self.circle(d, b, r, fill)

    # compositing
    def add(self, fill_mask, mode="outline", stroke=T, gap=G, alpha=1.0, solid=None):
        """Knock out a gap around the part, then draw it as an outline (or solid)."""
        fill = np.asarray(fill_mask) > 127
        if not fill.any():
            return
        knock = edt(~fill) <= gap * self.k
        self.alpha[knock] *= (1.0 - alpha)
        if mode == "outline":
            ink = fill & (edt(fill) <= stroke * self.k)
        else:
            ink = fill
        if solid is not None:  # extra solid detail inside (e.g. hub letter)
            ink = ink | (np.asarray(solid) > 127)
        self.alpha[ink] = np.maximum(self.alpha[ink], alpha)

    def cut(self, mask):
        self.alpha[np.asarray(mask) > 127] = 0.0

    def to_image(self, ss):
        a = self.alpha
        h, w = (a.shape[0] // ss) * ss, (a.shape[1] // ss) * ss
        a = a[:h, :w].reshape(h // ss, ss, w // ss, ss).mean(axis=(1, 3))
        a8 = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
        im = Image.new("RGBA", (a8.shape[1], a8.shape[0]), (255, 255, 255, 0))
        im.putalpha(Image.fromarray(a8))
        return im


def dirs(angle_deg):
    t = math.radians(angle_deg)
    d = np.array([math.cos(t), -math.sin(t)])
    n = np.array([math.sin(t), math.cos(t)])
    return d, n


def barrel_frame(recoil, kick):
    d, n = dirs(BASE_ANGLE + kick)
    O = P - recoil * d
    return O, d, n


BALL_R = 82.0


def draw_ball(cv, center, ss_font=None):
    im, dr = cv.new_mask()
    cv.circle(dr, center, BALL_R)
    cv.add(im, mode="solid")
    hi, dh = cv.new_mask()
    cv.circle(dh, center + np.array([-0.34, -0.34]) * BALL_R, 0.2 * BALL_R)
    cv.cut(hi)


def star(center, r_out, r_in, points, rot):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / points
        pts.append(center + r * np.array([math.cos(a), math.sin(a)]))
    return pts


def sparks(cv, origin, d, n, dist, count, alpha, seed, size=1.0):
    rng = random.Random(seed)
    for i in range(count):
        spread = rng.uniform(-0.9, 0.9)
        along = dist * rng.uniform(0.75, 1.25)
        lift = rng.uniform(-40, 40)
        p = origin + along * d + spread * along * 0.55 * (-n) + lift * n
        im, dr = cv.new_mask()
        s = (22 + rng.uniform(0, 14)) * size
        w = 9 * size
        if rng.random() < 0.5:   # plus sign
            cv.capsule(dr, p - [s, 0], p + [s, 0], w)
            cv.capsule(dr, p - [0, s], p + [0, s], w)
        else:                    # dash pointing outward
            dd = (p - origin)
            dd = dd / np.linalg.norm(dd)
            cv.capsule(dr, p - dd * s * 1.2, p + dd * s * 1.2, w)
        cv.add(im, mode="solid", gap=G * 0.6, alpha=alpha)


def smoke(cv, origin, d, n, dist, radius, alpha, stroke):
    c0 = origin + dist * d
    blobs = [(c0, radius), (c0 + 0.75 * radius * (-n) + 0.25 * radius * d, radius * 0.72),
             (c0 + 0.62 * radius * n + 0.35 * radius * d, radius * 0.62),
             (c0 + 0.9 * radius * d - 0.15 * radius * n, radius * 0.66)]
    im, dr = cv.new_mask()
    for c, r in blobs:
        cv.circle(dr, c, r)
    cv.add(im, mode="outline", stroke=stroke, alpha=alpha)


def draw_cannon(cv, recoil=0.0, kick=0.0, body_only=False):
    # trail / carriage (back)
    im, dr = cv.new_mask()
    E = np.array([215.0, 900.0])
    cv.capsule(dr, C, E, 84)
    x0, x1, y0, y1, rc = E[0] - 115, E[0] + 85, E[1] - 70, 985.0, 34
    cv.poly(dr, [(x0 + rc, y0), (x1, y0), (x1, y1), (x0 + rc, y1)])
    cv.poly(dr, [(x0, y0 + rc), (x1, y0 + rc), (x1, y1 - rc), (x0, y1 - rc)])
    cv.circle(dr, (x0 + rc, y0 + rc), rc)
    cv.circle(dr, (x0 + rc, y1 - rc), rc)
    cv.add(im)

    O, d, n = barrel_frame(recoil, kick)
    breech = O - 250 * d
    muzzle = O + 470 * d
    rb, rm = 118.0, 98.0

    # cascabel knob
    im, dr = cv.new_mask()
    cv.capsule(dr, breech, breech - 210 * d, 26)
    cv.circle(dr, breech - 215 * d, 46)
    cv.add(im, mode="solid")

    # barrel body
    im, dr = cv.new_mask()
    cv.poly(dr, [breech + rb * n, muzzle + rm * n, muzzle - rm * n, breech - rb * n])
    cv.circle(dr, breech, rb)
    cv.add(im)

    # muzzle ring
    im, dr = cv.new_mask()
    m0, m1 = O + 440 * d, O + 515 * d
    rr = 130
    cv.poly(dr, [m0 + rr * n, m1 + rr * n, m1 - rr * n, m0 - rr * n])
    cv.add(im)

    # wheel with "B" hub
    im, dr = cv.new_mask()
    cv.circle(dr, C, R_WHEEL)
    hub, dh = cv.new_mask()
    fsize = int(300 * cv.k)
    f = font(fsize, b"ExtraBold")
    x, y = cv.px(C)
    dh.text((x + 6 * cv.k, y), "B", font=f, fill=255, anchor="mm")
    cv.add(im, solid=hub)

    exit_pt = O + 515 * d
    return exit_pt, d, n


FRAMES = [
    # name, recoil, kick, duration(ms)
    ("idle",        0,   0.0, 1000),
    ("windup",      22,  1.5,   90),
    ("fire",        78,  6.0,   60),
    ("ball_out",    64,  5.0,   60),
    ("smoke1",      44,  3.5,   70),
    ("smoke2",      24,  2.0,   80),
    ("smoke3",      10,  0.8,   90),
    ("settle",      0,   0.0,  100),
]


def draw_frame(cv, idx):
    name, rec, kick, _ = FRAMES[idx]
    exit_pt, d, n = draw_cannon(cv, rec, kick)
    ball = None
    if name == "fire":
        im, dr = cv.new_mask()
        cv.poly(dr, star(exit_pt + 150 * d, 250, 135, 9, math.radians(-BASE_ANGLE - kick)))
        cv.add(im, stroke=T * 0.9)
        for i, a in enumerate([-50, -25, 0, 25, 50]):
            rd = np.array([math.cos(math.radians(-BASE_ANGLE - kick + a)),
                           math.sin(math.radians(-BASE_ANGLE - kick + a))])
            im, dr = cv.new_mask()
            L0, L1 = (300, 400) if i % 2 == 0 else (285, 350)
            cv.capsule(dr, exit_pt + 150 * d + rd * L0, exit_pt + 150 * d + rd * L1, 20)
            cv.add(im, mode="solid", gap=G * 0.6)
    elif name == "ball_out":
        im, dr = cv.new_mask()
        cv.poly(dr, star(exit_pt + 40 * d, 150, 92, 7, math.radians(-BASE_ANGLE - kick + 12)))
        cv.add(im, stroke=T * 0.8)
        ball = exit_pt + 300 * d
        draw_ball(cv, ball)
    elif name == "smoke1":
        smoke(cv, exit_pt, d, n, 130, 110, 1.0, T * 0.85)
        sparks(cv, exit_pt, d, n, 420, 5, 1.0, seed=4)
    elif name == "smoke2":
        smoke(cv, exit_pt + np.array([0, -30]), d, n, 190, 130, 0.75, T * 0.7)
        sparks(cv, exit_pt + np.array([0, -20]), d, n, 520, 4, 0.75, seed=5)
    elif name == "smoke3":
        smoke(cv, exit_pt + np.array([0, -70]), d, n, 240, 145, 0.45, T * 0.55)
        sparks(cv, exit_pt + np.array([0, -45]), d, n, 600, 3, 0.45, seed=6)
    elif name == "settle":
        sparks(cv, exit_pt + np.array([0, -70]), d, n, 660, 2, 0.2, seed=7)
    return ball, d


def build(res, title_size):
    title = make_title(title_size)
    H = title.height  # cannon body must match this

    # 1) measure body bbox in units with a probe render
    probe_k = 0.5
    WORLD = (-50, 0, 1900, 1150)   # generous unit-space region (y0 rises if needed below)
    WORLD = (-50, -350, 1900, 1150)
    cv = Canvas(*WORLD, probe_k)
    draw_cannon(cv, 0, 0)
    ys, xs = np.nonzero(cv.alpha > 0.5)
    by0, by1 = ys.min() / probe_k + WORLD[1], (ys.max() + 1) / probe_k + WORLD[1]
    bx0, bx1 = xs.min() / probe_k + WORLD[0], (xs.max() + 1) / probe_k + WORLD[0]
    body_h_units = by1 - by0
    k_final = H / body_h_units            # px per unit at final res
    # refine so the anti-aliased idle body is exactly H px tall
    def body_h(kf):
        cv = Canvas(*WORLD, kf * SS)
        draw_cannon(cv, 0, 0)
        bb = cv.to_image(SS).getchannel("A").getbbox()
        return bb[3] - bb[1]
    lo, hi = k_final * 0.95, k_final * 1.05
    for _ in range(14):
        mid = (lo + hi) / 2
        hh = body_h(mid)
        if hh == H:
            k_final = mid
            break
        if hh > H:
            hi = mid
        else:
            lo = mid
        k_final = mid
    k = k_final * SS

    # 2) render every frame, find union bbox
    rendered = []
    for i in range(len(FRAMES)):
        cv = Canvas(*WORLD, k)
        ball, d = draw_frame(cv, i)
        img = cv.to_image(SS)
        rendered.append((img, ball, d))
    union = None
    for img, _, _ in rendered:
        bb = img.getchannel("A").getbbox()
        union = bb if union is None else (min(union[0], bb[0]), min(union[1], bb[1]),
                                          max(union[2], bb[2]), max(union[3], bb[3]))
    pad = 2
    ux0, uy0, ux1, uy1 = union[0] - pad, union[1] - pad, union[2] + pad, union[3] + pad
    fw, fh = ux1 - ux0, uy1 - uy0

    idle_bb = rendered[0][0].getchannel("A").getbbox()
    body = {"x": idle_bb[0] - ux0, "y": idle_bb[1] - uy0,
            "w": idle_bb[2] - idle_bb[0], "h": idle_bb[3] - idle_bb[1]}

    cols, rows = 4, 2
    sheet = Image.new("RGBA", (fw * cols, fh * rows), (255, 255, 255, 0))
    frames = []
    ball_spawn = None
    for i, (img, ball, d) in enumerate(rendered):
        fr = img.crop((ux0, uy0, ux1, uy1))
        cx, cy = (i % cols) * fw, (i // cols) * fh
        sheet.paste(fr, (cx, cy))
        frames.append({"name": FRAMES[i][0], "index": i,
                       "frame": {"x": cx, "y": cy, "w": fw, "h": fh},
                       "duration": FRAMES[i][3]})
        if ball is not None:
            bx = (ball[0] - WORLD[0]) * k_final - ux0
            by = (ball[1] - WORLD[1]) * k_final - uy0
            ball_spawn = {"frame": i, "x": round(bx, 1), "y": round(by, 1),
                          "dirX": round(float(d[0]), 4), "dirY": round(float(d[1]), 4)}

    # standalone cannonball sprite
    r = BALL_R * k_final
    bcv = Canvas(-BALL_R - 4 / k_final, -BALL_R - 4 / k_final,
                 BALL_R + 4 / k_final, BALL_R + 4 / k_final, k)
    draw_ball(bcv, np.array([0.0, 0.0]))
    ball_img = bcv.to_image(SS)

    title.save(f"{OUT}/bge_title_{res}.webp", lossless=True)
    sheet.save(f"{OUT}/bge_cannon_{res}.webp", lossless=True)
    ball_img.save(f"{OUT}/bge_cannonball_{res}.webp", lossless=True)

    meta = {
        "image": f"bge_cannon_{res}.webp",
        "size": {"w": sheet.width, "h": sheet.height},
        "frameSize": {"w": fw, "h": fh},
        "grid": {"cols": cols, "rows": rows},
        "frames": frames,
        "body": body,
        "bodyNote": "Rect of the idle cannon artwork inside each frame. body.h equals the title image height.",
        "ballSpawn": ball_spawn,
        "ballSpawnNote": "Centre of the cannonball in the ball_out frame (frame-local px) and its launch direction. "
                         "Hide the in-frame ball from the next frame on and spawn bge_cannonball here.",
        "cannonball": {"image": f"bge_cannonball_{res}.webp",
                       "w": ball_img.width, "h": ball_img.height},
        "title": {"image": f"bge_title_{res}.webp", "w": title.width, "h": title.height},
        "suggestedGap": round(H * 0.16),
    }
    with open(f"{OUT}/bge_cannon_{res}.json", "w") as fjs:
        json.dump(meta, fjs, indent=2)
    return title, sheet, ball_img, meta


if __name__ == "__main__":
    results = {}
    for res, size in [("fhd", 112), ("hd", 75)]:
        results[res] = build(res, size)
        t, s, b, m = results[res]
        print(res, "title", t.size, "sheet", s.size, "frame", m["frameSize"], "body", m["body"])
