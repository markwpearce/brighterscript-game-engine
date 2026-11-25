#!/usr/bin/env node
// Cuts the frames named in src/sprites/fighters/animations.json out of each 997-frame
// Mustermann sheet in art/ and packs them, at half size, into one atlas per character and
// colour palette (palette swaps recolour the trousers/belt/shirt by hue). Also writes a
// portrait atlas for the HUD and select screen. The full sheets are ~8000x6900 - far too
// big for a Roku texture.
//
// Usage (from examples/fighter): node scripts/build-sprites.js
const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage } = require('canvas');
const { writeWebp } = require('../../../scripts/webp');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'src', 'sprites', 'fighters');
const SHEET_COLS = 35;
const SHEET_ROWS = 29;
const SCALE = 0.5;
// Atlas cell, and where the feet sit in it, in atlas pixels.
const CELL_W = 136;
const CELL_H = 124;
const FEET_X = 68;
const FEET_Y = 118;
const ATLAS_COLS = 24;
// A fighting-stance frame (mid idle loop) used to find each sheet's feet position.
const REFERENCE_FRAME = 8;
const PORTRAIT_SIZE = 200;
const PORTRAIT_FRAME = 920;

// A rule recolours pixels whose HSL (h 0-360, s/l 0-1) falls in `match`: `h` replaces the
// hue, `s` the saturation (or `sMul` scales it) and `lMul` scales the lightness.
const BLAZE_TROUSERS = { h: [18, 50], s: [0.5, 1], l: [0.03, 0.6] };
const BLAZE_BELT = { h: [200, 270], s: [0.35, 1], l: [0, 1] };
const BLAZE_SHIRT = { h: [0, 360], s: [0, 0.06], l: [0.08, 0.75] };
const FROST_TROUSERS = { h: [195, 265], s: [0.3, 1], l: [0, 1] };
const FROST_SHIRT = { h: [0, 360], s: [0, 0.08], l: [0.4, 1] };

const CHARACTERS = {
  blaze: {
    sheet: 'Orangeblack.png',
    palettes: [
      [],
      [{ match: BLAZE_TROUSERS, h: 352 }, { match: BLAZE_BELT, h: 48, sMul: 0.9 }],
      [{ match: BLAZE_TROUSERS, h: 150, sMul: 0.8 }, { match: BLAZE_BELT, h: 0 }],
      [{ match: BLAZE_TROUSERS, h: 275, lMul: 0.85 }, { match: BLAZE_BELT, h: 55 }, { match: BLAZE_SHIRT, lMul: 0.45 }]
    ]
  },
  frost: {
    sheet: 'Blueehite.png',
    palettes: [
      [],
      [{ match: FROST_TROUSERS, h: 8 }, { match: FROST_SHIRT, h: 45, s: 0.55, lMul: 0.92 }],
      [{ match: FROST_TROUSERS, h: 105, lMul: 0.85 }, { match: FROST_SHIRT, s: 0, lMul: 0.3 }],
      [{ match: FROST_TROUSERS, s: 0.05, lMul: 0.55 }, { match: FROST_SHIRT, h: 0, s: 0.7, lMul: 0.75 }]
    ]
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

function cellCanvas(img, cellW, cellH, frame) {
  const c = createCanvas(Math.ceil(cellW), Math.ceil(cellH));
  const g = c.getContext('2d');
  g.drawImage(img, (frame % SHEET_COLS) * cellW, Math.floor(frame / SHEET_COLS) * cellH, cellW, cellH, 0, 0, cellW, cellH);
  return c;
}

// Bottom-most opaque row and the opaque pixels' mean x, within one sheet cell.
function findFeet(img, cellW, cellH, frame) {
  const c = cellCanvas(img, cellW, cellH, frame);
  const { data, width, height } = c.getContext('2d').getImageData(0, 0, c.width, c.height);
  let bottom = 0;
  let sumX = 0;
  let count = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] > 16) {
        bottom = y;
        sumX += x;
        count++;
      }
    }
  }
  return { x: sumX / count, y: bottom };
}

// A square around the head: the top opaque row, centred on the opaque pixels just below it.
function headBox(img, cellW, cellH, frame) {
  const c = cellCanvas(img, cellW, cellH, frame);
  const { data, width, height } = c.getContext('2d').getImageData(0, 0, c.width, c.height);
  const opaque = (x, y) => data[(y * width + x) * 4 + 3] > 16;
  let top = 0;
  while (top < height && ![...Array(width).keys()].some((x) => opaque(x, top))) top++;
  const size = Math.round(cellW * 0.24);
  let sumX = 0;
  let count = 0;
  for (let y = top; y < top + size * 0.6; y++) {
    for (let x = 0; x < width; x++) {
      if (opaque(x, y)) {
        sumX += x;
        count++;
      }
    }
  }
  const cx = sumX / count;
  return { x: cx - size / 2, y: top - size * 0.12, size };
}

async function buildCharacter(key, character, frames, portraits, portraitIndex) {
  const img = await loadImage(path.join(ROOT, 'art', character.sheet));
  const cellW = img.width / SHEET_COLS;
  const cellH = img.height / SHEET_ROWS;
  const feet = findFeet(img, cellW, cellH, REFERENCE_FRAME);
  const rows = Math.ceil(frames.length / ATLAS_COLS);
  const atlas = createCanvas(CELL_W * ATLAS_COLS, CELL_H * rows);
  const g = atlas.getContext('2d');
  g.imageSmoothingEnabled = true;
  frames.forEach((frame, i) => {
    const dx = (i % ATLAS_COLS) * CELL_W;
    const dy = Math.floor(i / ATLAS_COLS) * CELL_H;
    g.save();
    g.beginPath();
    g.rect(dx, dy, CELL_W, CELL_H);
    g.clip();
    // Place the sheet cell so its feet land on (FEET_X, FEET_Y).
    const ox = dx + FEET_X - feet.x * SCALE;
    const oy = dy + FEET_Y - feet.y * SCALE;
    g.drawImage(img, (frame % SHEET_COLS) * cellW, Math.floor(frame / SHEET_COLS) * cellH, cellW, cellH, ox, oy, cellW * SCALE, cellH * SCALE);
    g.restore();
  });
  const base = g.getImageData(0, 0, atlas.width, atlas.height);

  const head = headBox(img, cellW, cellH, PORTRAIT_FRAME);
  const pg = portraits.getContext('2d');
  for (let p = 0; p < character.palettes.length; p++) {
    const data = new Uint8ClampedArray(base.data);
    recolor(data, character.palettes[p]);
    const outFile = path.join(OUT_DIR, `${key}-${p}.webp`);
    await writeWebp(data, atlas.width, atlas.height, outFile);
    console.log(`${outFile}: ${frames.length} frames, ${atlas.width}x${atlas.height}`);

    const pc = createCanvas(PORTRAIT_SIZE, PORTRAIT_SIZE);
    const pcg = pc.getContext('2d');
    const sx = (PORTRAIT_FRAME % SHEET_COLS) * cellW + head.x;
    const sy = Math.floor(PORTRAIT_FRAME / SHEET_COLS) * cellH + head.y;
    pcg.drawImage(img, sx, sy, head.size, head.size, 0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE);
    const pd = pcg.getImageData(0, 0, PORTRAIT_SIZE, PORTRAIT_SIZE);
    recolor(pd.data, character.palettes[p]);
    pcg.putImageData(pd, 0, 0);
    const index = portraitIndex + p;
    pg.drawImage(pc, (index % 4) * PORTRAIT_SIZE, Math.floor(index / 4) * PORTRAIT_SIZE);
  }
  return character.palettes.length;
}

async function main() {
  const animations = JSON.parse(fs.readFileSync(path.join(OUT_DIR, 'animations.json'), 'utf8'));
  const frames = usedFrames(animations);
  const total = Object.values(CHARACTERS).reduce((n, c) => n + c.palettes.length, 0);
  const portraits = createCanvas(PORTRAIT_SIZE * 4, PORTRAIT_SIZE * Math.ceil(total / 4));
  const palettes = {};
  let portraitIndex = 0;
  for (const [key, character] of Object.entries(CHARACTERS)) {
    palettes[key] = { count: await buildCharacter(key, character, frames, portraits, portraitIndex), portraitIndex };
    portraitIndex += palettes[key].count;
  }
  const pd = portraits.getContext('2d').getImageData(0, 0, portraits.width, portraits.height);
  await writeWebp(pd.data, portraits.width, portraits.height, path.join(OUT_DIR, 'portraits.webp'));
  for (const old of ['p1.webp', 'p2.webp']) {
    fs.rmSync(path.join(OUT_DIR, old), { force: true });
  }
  const layout = {
    cellWidth: CELL_W,
    cellHeight: CELL_H,
    columns: ATLAS_COLS,
    feetX: FEET_X,
    feetY: FEET_Y,
    portraitSize: PORTRAIT_SIZE,
    portraitColumns: 4,
    palettes,
    frames
  };
  fs.writeFileSync(path.join(OUT_DIR, 'atlas.json'), JSON.stringify(layout) + '\n');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
