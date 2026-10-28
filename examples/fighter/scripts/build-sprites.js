#!/usr/bin/env node
// Cuts the frames named in src/sprites/fighters/animations.json out of each 997-frame
// Mustermann sheet in art/ and packs them, at half size, into one small atlas per fighter.
// The full sheets are ~8000x6900 - far too big for a Roku texture.
//
// Usage (from examples/fighter): node scripts/build-sprites.js
const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage } = require('canvas');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'src', 'sprites', 'fighters');
const SHEETS = { p1: 'Orangeblack.png', p2: 'Blueehite.png' };
const SHEET_COLS = 35;
const SHEET_ROWS = 29;
const SCALE = 0.5;
// Atlas cell, and where the feet sit in it, in atlas pixels.
const CELL_W = 136;
const CELL_H = 124;
const FEET_X = 68;
const FEET_Y = 118;
const ATLAS_COLS = 24;
// The neutral stance frame used to find each sheet's feet position.
const REFERENCE_FRAME = 3;

function expand(list) {
  const frames = [];
  for (const item of list) {
    if (typeof item === 'number') {
      frames.push(item);
    } else {
      const [a, b] = item.split('-').map(Number);
      for (let f = a; f <= b; f++) frames.push(f);
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

// Bottom-most opaque row and the opaque pixels' mean x, within one sheet cell.
function findFeet(img, cellW, cellH, frame) {
  const c = createCanvas(Math.ceil(cellW), Math.ceil(cellH));
  const g = c.getContext('2d');
  g.drawImage(img, (frame % SHEET_COLS) * cellW, Math.floor(frame / SHEET_COLS) * cellH, cellW, cellH, 0, 0, cellW, cellH);
  const { data, width, height } = g.getImageData(0, 0, c.width, c.height);
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

async function buildSheet(key, file, frames) {
  const img = await loadImage(path.join(ROOT, 'art', file));
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
  const outFile = path.join(OUT_DIR, `${key}.png`);
  fs.writeFileSync(outFile, atlas.toBuffer('image/png'));
  console.log(`${outFile}: ${frames.length} frames, ${atlas.width}x${atlas.height}`);
}

async function main() {
  const animations = JSON.parse(fs.readFileSync(path.join(OUT_DIR, 'animations.json'), 'utf8'));
  const frames = usedFrames(animations);
  for (const [key, file] of Object.entries(SHEETS)) {
    await buildSheet(key, file, frames);
  }
  const layout = { cellWidth: CELL_W, cellHeight: CELL_H, columns: ATLAS_COLS, feetX: FEET_X, feetY: FEET_Y, frames };
  fs.writeFileSync(path.join(OUT_DIR, 'atlas.json'), JSON.stringify(layout) + '\n');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
