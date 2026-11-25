#!/usr/bin/env node
// Draws every animation as a strip of its frames (from the built atlases, with the feet
// lined up on a baseline), one PNG per character, into out/animation-previews/. Handy for
// checking frame picks in animations-<set>.json without running the game. Attack strips
// mark where the active (hitbox) frames start and end.
//
// Needs ffmpeg on PATH (canvas can't read WebP).
//
// Usage (from examples/fighter, after npm run build-sprites): node scripts/preview-animations.js [character]
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const { createCanvas, loadImage } = require('canvas');

const ROOT = path.join(__dirname, '..');
const SPRITES = path.join(ROOT, 'src', 'sprites', 'fighters');
const OUT_DIR = path.join(ROOT, 'out', 'animation-previews');
const SLOT_W = 110;
const ROW_H = 150;
const LABEL_W = 110;
const BASELINE = 135;

function expand(list) {
  const frames = [];
  for (const item of list || []) {
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

async function previewCharacter(id, layout) {
  const png = path.join(os.tmpdir(), `fighter-preview-${id}.png`);
  execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', path.join(SPRITES, `${id}-0.webp`), png]);
  const atlas = await loadImage(png);
  fs.rmSync(png);
  const animations = JSON.parse(fs.readFileSync(path.join(SPRITES, `animations-${layout.animationSet}.json`), 'utf8'));
  const slotOf = new Map(layout.frames.map((f, i) => [f, i]));
  const rows = Object.entries(animations).map(([name, anim]) => {
    const startup = expand(anim.startup);
    const active = expand(anim.active);
    const frames = anim.frames ? expand(anim.frames) : [...startup, ...active, ...expand(anim.recovery)];
    return { name, frames, activeFrom: startup.length, activeTo: startup.length + active.length, isAttack: !anim.frames };
  });
  const maxFrames = Math.max(...rows.map((r) => r.frames.length));
  const c = createCanvas(LABEL_W + maxFrames * SLOT_W, rows.length * ROW_H);
  const g = c.getContext('2d');
  g.fillStyle = '#6e7480';
  g.fillRect(0, 0, c.width, c.height);
  rows.forEach((row, r) => {
    const y0 = r * ROW_H;
    g.fillStyle = r % 2 ? '#666c78' : '#727884';
    g.fillRect(0, y0, c.width, ROW_H);
    g.fillStyle = '#fff';
    g.font = 'bold 15px sans-serif';
    g.fillText(row.name, 6, y0 + 20);
    row.frames.forEach((frame, i) => {
      const x0 = LABEL_W + i * SLOT_W;
      if (row.isAttack && i >= row.activeFrom && i < row.activeTo) {
        g.fillStyle = 'rgba(255,80,60,0.35)';
        g.fillRect(x0, y0, SLOT_W, ROW_H);
      }
      const rect = layout.rects[slotOf.get(frame)];
      if (rect) {
        const [sx, sy, w, h, fx, fy] = rect;
        const scale = Math.min(1, (BASELINE - 8) / fy);
        g.drawImage(atlas, sx, sy, w, h, x0 + SLOT_W / 2 - fx * scale, y0 + BASELINE - fy * scale, w * scale, h * scale);
      }
      g.fillStyle = '#ff0';
      g.font = '12px sans-serif';
      g.fillText(String(frame), x0 + 3, y0 + 13);
    });
    g.strokeStyle = 'rgba(0,0,0,0.4)';
    g.beginPath();
    g.moveTo(LABEL_W, y0 + BASELINE + 0.5);
    g.lineTo(c.width, y0 + BASELINE + 0.5);
    g.stroke();
  });
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const file = path.join(OUT_DIR, `${id}.png`);
  fs.writeFileSync(file, c.toBuffer('image/png'));
  console.log(file);
}

async function main() {
  const atlas = JSON.parse(fs.readFileSync(path.join(SPRITES, 'atlas.json'), 'utf8'));
  const only = process.argv[2];
  for (const [id, layout] of Object.entries(atlas.characters)) {
    if (!only || only === id) await previewCharacter(id, layout);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
