#!/usr/bin/env node
// Cuts each character's animation frames out of their source art in art/, trims each one
// to its visible pixels and packs them into one atlas per character and colour palette
// (palette swaps recolour clothes by hue). atlas.json lists every frame's rectangle and
// where the feet are in it, so the game can line the frames up. Also writes a portrait
// atlas for the HUD and select screen. The source sheets are far too big for a Roku
// texture (the Mustermann ones are ~8000x6900). Also writes bodies.webp: a stance frame per
// palette for the select screen.
//
// Sources are either a grid sheet (cols x rows) or an animated GIF (one frame per GIF
// frame, extracted with ffmpeg, which must be on PATH). Each character's frames are named
// in src/sprites/fighters/animations-<set>.json.
//
// Usage (from examples/fighter): node scripts/build-sprites.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { createCanvas, loadImage } = require('canvas');
const { writeWebp } = require('../../../scripts/webp');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'src', 'sprites', 'fighters');
const ATLAS_WIDTH = 2048;
const PADDING = 1;
const PORTRAIT_SIZE = 200;
const PORTRAIT_COLUMNS = 4;
// Full-body stance frames for the select screen, one per palette, in the same order as
// the portraits.
const BODY_W = 160;
const BODY_H = 240;
// Lower than the default q90: the atlases are most of the channel's size (the simulator
// refuses channels over 7 MB), and the fighters are scaled up anyway.
const ATLAS_QUALITY = 75;

// A rule recolours pixels whose HSL (h 0-360, s/l 0-1) falls in `match`: `h` replaces the
// hue, `s` the saturation (or `sMul` scales it) and `lMul` scales the lightness.
const BLAZE_TROUSERS = { h: [18, 50], s: [0.5, 1], l: [0.03, 0.6] };
const BLAZE_BELT = { h: [200, 270], s: [0.35, 1], l: [0, 1] };
const BLAZE_SHIRT = { h: [0, 360], s: [0, 0.06], l: [0.08, 0.75] };
const FROST_TROUSERS = { h: [195, 265], s: [0.3, 1], l: [0, 1] };
const FROST_SHIRT = { h: [0, 360], s: [0, 0.08], l: [0.4, 1] };
const BRUNO_JEANS = { h: [195, 240], s: [0.12, 1], l: [0.1, 0.9] };
const BRUNO_STRIPES = { h: [10, 45], s: [0.45, 1], l: [0.15, 0.8] };
const NOVA_SHIRT = { h: [75, 165], s: [0.2, 1], l: [0.05, 0.9] };

// scale: source pixels to atlas pixels. reference: a fighting-stance frame used to find the
// feet. portrait: a frame facing forward for the portrait.
const CHARACTERS = {
  blaze: {
    source: { sheet: 'Orangeblack.png', cols: 35, rows: 29 },
    set: 'mustermann',
    scale: 0.5,
    reference: 8,
    portrait: 920,
    palettes: [[], [{ match: BLAZE_TROUSERS, h: 275, lMul: 0.85 }, { match: BLAZE_BELT, h: 55 }, { match: BLAZE_SHIRT, lMul: 0.45 }]]
  },
  frost: {
    source: { sheet: 'Blueehite.png', cols: 35, rows: 29 },
    set: 'mustermann',
    scale: 0.5,
    reference: 8,
    portrait: 920,
    palettes: [[], [{ match: FROST_TROUSERS, s: 0.05, lMul: 0.55 }, { match: FROST_SHIRT, h: 0, s: 0.7, lMul: 0.75 }]]
  },
  bruno: {
    source: { sheet: 'RJD-Spritesheet.png', cols: 34, rows: 43 },
    set: 'bruno',
    // A big man: a little taller than the others.
    scale: 0.72,
    reference: 0,
    portrait: 834,
    palettes: [[], [{ match: BRUNO_STRIPES, h: 195, sMul: 1.1 }, { match: BRUNO_JEANS, h: 32, s: 0.35, lMul: 0.9 }]]
  },
  nova: {
    source: { gif: 'human-fighter.gif' },
    set: 'nova',
    scale: 0.52,
    reference: 0,
    portrait: 80,
    palettes: [[], [{ match: NOVA_SHIRT, h: 290, sMul: 1.1 }]]
  }
};

function expand(list) {
  const frames = [];
  for (const item of list) {
    if (typeof item === 'number') {
      frames.push(item);
    } else {
      const [range, step] = item.split('/');
      const [a, b] = range.split('-').map(Number);
      for (let f = a; f <= b; f += Number(step || 1)) frames.push(f);
    }
  }
  return frames;
}

function usedFrames(animations) {
  const set = new Set();
  for (const anim of Object.values(animations)) {
    for (const key of ['frames', 'startup', 'active', 'recovery']) {
      if (anim[key]) expand(anim[key]).forEach((f) => set.add(f));
    }
  }
  return [...set].sort((a, b) => a - b);
}

function rgbToHsl(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = d / (1 - Math.abs(2 * l - 1));
  let h;
  if (max === r) h = ((g - b) / d) % 6;
  else if (max === g) h = (b - r) / d + 2;
  else h = (r - g) / d + 4;
  h *= 60;
  if (h < 0) h += 360;
  return [h, s, l];
}

function hslToRgb(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)];
}

const inRange = (v, [a, b]) => v >= a && v <= b;

function recolor(data, rules) {
  if (rules.length === 0) return;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const [h, s, l] = rgbToHsl(data[i], data[i + 1], data[i + 2]);
    for (const rule of rules) {
      if (inRange(h, rule.match.h) && inRange(s, rule.match.s) && inRange(l, rule.match.l)) {
        const nh = rule.h ?? h;
        const ns = Math.min(1, rule.s ?? s * (rule.sMul ?? 1));
        const nl = Math.min(1, l * (rule.lMul ?? 1));
        [data[i], data[i + 1], data[i + 2]] = hslToRgb(nh, ns, nl);
        break;
      }
    }
  }
}

// Gives frame(n) -> a canvas of source frame n, plus the source cell size.
async function openSource(source) {
  if (source.sheet) {
    const img = await loadImage(path.join(ROOT, 'art', source.sheet));
    const cellW = img.width / source.cols;
    const cellH = img.height / source.rows;
    return {
      cellW,
      cellH,
      frame(n) {
        const c = createCanvas(Math.ceil(cellW), Math.ceil(cellH));
        c.getContext('2d').drawImage(img, (n % source.cols) * cellW, Math.floor(n / source.cols) * cellH, cellW, cellH, 0, 0, cellW, cellH);
        return c;
      }
    };
  }
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fighter-gif-'));
  execFileSync('ffmpeg', ['-v', 'error', '-i', path.join(ROOT, 'art', source.gif), path.join(dir, 'f%04d.png')]);
  const files = fs.readdirSync(dir).sort();
  const images = [];
  for (const f of files) images.push(await loadImage(path.join(dir, f)));
  fs.rmSync(dir, { recursive: true, force: true });
  return {
    cellW: images[0].width,
    cellH: images[0].height,
    frame(n) {
      const c = createCanvas(images[n].width, images[n].height);
      c.getContext('2d').drawImage(images[n], 0, 0);
      return c;
    }
  };
}

// The opaque pixels' bounding box (inclusive) and mean x.
function opaqueBounds(canvas) {
  const { data, width, height } = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
  let top = height;
  let bottom = -1;
  let left = width;
  let right = -1;
  let sumX = 0;
  let count = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] > 8) {
        top = Math.min(top, y);
        bottom = y;
        left = Math.min(left, x);
        right = Math.max(right, x);
        sumX += x;
        count++;
      }
    }
  }
  return { top, bottom, left, right, meanX: count ? sumX / count : width / 2, data, width };
}

// A square around the head: the top opaque row, centred on the opaque pixels just below it.
function headBox(canvas) {
  const b = opaqueBounds(canvas);
  const size = Math.round((b.bottom - b.top) * 0.36);
  let sumX = 0;
  let count = 0;
  for (let y = b.top; y < b.top + size * 0.6; y++) {
    for (let x = 0; x < b.width; x++) {
      if (b.data[(y * b.width + x) * 4 + 3] > 16) {
        sumX += x;
        count++;
      }
    }
  }
  return { x: sumX / count - size / 2, y: b.top - size * 0.12, size };
}

// Scales a source frame into a canvas big enough for it, with the reference feet at
// (feetX, feetY), then trims it to its opaque pixels.
function trimmedFrame(sourceFrame, scale, ref) {
  const w = Math.ceil(sourceFrame.width * scale);
  const h = Math.ceil(sourceFrame.height * scale);
  const c = createCanvas(w, h);
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = true;
  g.drawImage(sourceFrame, 0, 0, w, h);
  const feetX = ref.meanX * scale;
  const feetY = ref.bottom * scale;
  const b = opaqueBounds(c);
  if (b.right < 0) {
    return { canvas: createCanvas(1, 1), anchorX: 0, anchorY: 0 };
  }
  const tw = b.right - b.left + 1 + PADDING * 2;
  const th = b.bottom - b.top + 1 + PADDING * 2;
  const t = createCanvas(tw, th);
  t.getContext('2d').drawImage(c, b.left - PADDING, b.top - PADDING, tw, th, 0, 0, tw, th);
  return { canvas: t, anchorX: feetX - b.left + PADDING, anchorY: feetY - b.top + PADDING };
}

// Shelf packing, tallest first.
function pack(items) {
  const order = items.map((item, i) => i).sort((a, b) => items[b].canvas.height - items[a].canvas.height);
  const rects = new Array(items.length);
  let x = 0;
  let y = 0;
  let shelf = 0;
  for (const i of order) {
    const { width, height } = items[i].canvas;
    if (x + width > ATLAS_WIDTH) {
      x = 0;
      y += shelf;
      shelf = 0;
    }
    rects[i] = { x, y, w: width, h: height };
    x += width;
    shelf = Math.max(shelf, height);
  }
  return { rects, height: y + shelf };
}

async function buildCharacter(key, character, portraits, bodies, portraitIndex) {
  const animations = JSON.parse(fs.readFileSync(path.join(OUT_DIR, `animations-${character.set}.json`), 'utf8'));
  const frames = usedFrames(animations);
  const source = await openSource(character.source);
  const ref = opaqueBounds(source.frame(character.reference));
  const items = frames.map((frame) => trimmedFrame(source.frame(frame), character.scale, ref));
  const { rects, height } = pack(items);
  const atlas = createCanvas(ATLAS_WIDTH, height);
  const g = atlas.getContext('2d');
  items.forEach((item, i) => g.drawImage(item.canvas, rects[i].x, rects[i].y));
  const base = g.getImageData(0, 0, atlas.width, atlas.height);

  const portraitFrame = source.frame(character.portrait);
  const bodyFrame = source.frame(character.reference);
  const bodyScale = (BODY_H * 0.92) / (ref.bottom - ref.top);
  const bg = bodies.getContext('2d');
  const head = headBox(portraitFrame);
  const pg = portraits.getContext('2d');
  for (let p = 0; p < character.palettes.length; p++) {
    const data = new Uint8ClampedArray(base.data);
    recolor(data, character.palettes[p]);
    const outFile = path.join(OUT_DIR, `${key}-${p}.webp`);
    await writeWebp(data, atlas.width, atlas.height, outFile, { quality: ATLAS_QUALITY });
    console.log(`${outFile}: ${frames.length} frames, ${atlas.width}x${atlas.height}`);

    const pc = createCanvas(PORTRAIT_SIZE, PORTRAIT_SIZE);
    const pcg = pc.getContext('2d');
    pcg.drawImage(portraitFrame, head.x, head.y, head.size, head.size, 0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE);
    const pd = pcg.getImageData(0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE);
    recolor(pd.data, character.palettes[p]);
    pcg.putImageData(pd, 0, 0);
    const index = portraitIndex + p;
    pg.drawImage(pc, (index % PORTRAIT_COLUMNS) * PORTRAIT_SIZE, Math.floor(index / PORTRAIT_COLUMNS) * PORTRAIT_SIZE);

    // The stance frame, feet at the bottom centre of its cell.
    const bc = createCanvas(BODY_W, BODY_H);
    const bcg = bc.getContext('2d');
    bcg.drawImage(bodyFrame, BODY_W / 2 - ref.meanX * bodyScale, BODY_H - 4 - ref.bottom * bodyScale, bodyFrame.width * bodyScale, bodyFrame.height * bodyScale);
    const bd = bcg.getImageData(0, 0, BODY_W, BODY_H);
    recolor(bd.data, character.palettes[p]);
    bcg.putImageData(bd, 0, 0);
    bg.drawImage(bc, (index % PORTRAIT_COLUMNS) * BODY_W, Math.floor(index / PORTRAIT_COLUMNS) * BODY_H);
  }
  return {
    animationSet: character.set,
    paletteCount: character.palettes.length,
    portraitIndex,
    frames,
    // Per frame: x, y, w, h in the atlas, then the feet position within that rectangle.
    rects: rects.map((r, i) => [r.x, r.y, r.w, r.h, Math.round(items[i].anchorX), Math.round(items[i].anchorY)])
  };
}

async function main() {
  const total = Object.values(CHARACTERS).reduce((n, c) => n + c.palettes.length, 0);
  const portraits = createCanvas(PORTRAIT_SIZE * PORTRAIT_COLUMNS, PORTRAIT_SIZE * Math.ceil(total / PORTRAIT_COLUMNS));
  const bodies = createCanvas(BODY_W * PORTRAIT_COLUMNS, BODY_H * Math.ceil(total / PORTRAIT_COLUMNS));
  const characters = {};
  let portraitIndex = 0;
  for (const [key, character] of Object.entries(CHARACTERS)) {
    characters[key] = await buildCharacter(key, character, portraits, bodies, portraitIndex);
    portraitIndex += character.palettes.length;
  }
  const pd = portraits.getContext('2d').getImageData(0, 0, portraits.width, portraits.height);
  await writeWebp(pd.data, portraits.width, portraits.height, path.join(OUT_DIR, 'portraits.webp'));
  const bdd = bodies.getContext('2d').getImageData(0, 0, bodies.width, bodies.height);
  await writeWebp(bdd.data, bodies.width, bodies.height, path.join(OUT_DIR, 'bodies.webp'));
  const layout = { portraitSize: PORTRAIT_SIZE, portraitColumns: PORTRAIT_COLUMNS, bodyWidth: BODY_W, bodyHeight: BODY_H, characters };
  fs.writeFileSync(path.join(OUT_DIR, 'atlas.json'), JSON.stringify(layout) + '\n');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
