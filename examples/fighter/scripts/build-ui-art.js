#!/usr/bin/env node
// Draws the fighter's UI art: announcement words, the logo, HUD pieces, hit sparks,
// projectiles, the stage floor, and the channel splash/icons. Everything is at canvas
// resolution (640x360) except the splash and icons. Pieces are packed into
// src/sprites/ui/ui.webp with their rectangles in ui.json.
//
// Usage (from examples/fighter): node scripts/build-ui-art.js
const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage, FontFace, fonts } = require('canvas');
const { writeWebp } = require('../../../scripts/webp');

const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'src', 'sprites', 'ui');
const FONT = 'Viper Command';
fonts.add(new FontFace(FONT, fs.readFileSync(path.join(ROOT, 'src', 'fonts', 'ViperCommand-3l74X.otf'))));

// Seeded so every run draws identical art.
let seed = 4242;
function rand() {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
}

// ---------- Words ----------

const FIRE = [
  [0, '#fffbe0'],
  [0.35, '#ffd23a'],
  [0.7, '#ff7a12'],
  [1, '#c3200c']
];
const STEEL = [
  [0, '#ffffff'],
  [0.45, '#b8c8dc'],
  [0.55, '#5d7391'],
  [1, '#d6e2f0']
];
const ICE = [
  [0, '#ffffff'],
  [0.4, '#9ff0ff'],
  [1, '#1a6fd0']
];
const GOLD = [
  [0, '#fffbe0'],
  [0.5, '#ffd84a'],
  [1, '#b06d00']
];

// Big outlined, gradient-filled text with a hard drop shadow.
function word(text, size, stops, opts = {}) {
  const outline = opts.outline ?? Math.max(3, Math.round(size / 11));
  const shadow = opts.shadow ?? Math.max(3, Math.round(size / 14));
  const probe = createCanvas(10, 10).getContext('2d');
  probe.font = `${size}px "${FONT}"`;
  const m = probe.measureText(text);
  const w = Math.ceil(m.width + outline * 2 + shadow + 4);
  const ascent = Math.ceil(m.actualBoundingBoxAscent);
  const descent = Math.ceil(m.actualBoundingBoxDescent);
  const h = ascent + descent + outline * 2 + shadow + 4;
  const c = createCanvas(w, h);
  const g = c.getContext('2d');
  g.font = probe.font;
  g.textBaseline = 'alphabetic';
  g.lineJoin = 'round';
  const x = outline + 2;
  const y = outline + 2 + ascent;
  g.fillStyle = opts.shadowColor ?? '#1a0b2e';
  g.strokeStyle = g.fillStyle;
  g.lineWidth = outline * 2;
  g.strokeText(text, x + shadow, y + shadow);
  g.fillText(text, x + shadow, y + shadow);
  g.strokeStyle = opts.outlineColor ?? '#2a0d06';
  g.strokeText(text, x, y);
  const grad = g.createLinearGradient(0, y - ascent, 0, y + descent);
  stops.forEach(([o, col]) => grad.addColorStop(o, col));
  g.fillStyle = grad;
  g.fillText(text, x, y);
  // A thin highlight along the top half.
  g.save();
  g.globalCompositeOperation = 'source-atop';
  g.fillStyle = 'rgba(255,255,255,0.18)';
  g.fillRect(0, 0, w, y - ascent * 0.55);
  g.restore();
  return c;
}

// ---------- HUD ----------

// HUD pieces and words are drawn on the UI canvas, which is screen-sized (1280x720), so
// they're drawn at twice the 640x360 game canvas scale.
const UI_SCALE = 2;

function hiRes(w, h) {
  const c = createCanvas(w * UI_SCALE, h * UI_SCALE);
  const g = c.getContext('2d');
  g.scale(UI_SCALE, UI_SCALE);
  return { c, g };
}

function barFrame() {
  // 232x22 (before UI_SCALE): the bar window is 220x12 at (6,5).
  const { c, g } = hiRes(232, 22);
  const grad = g.createLinearGradient(0, 0, 0, 22);
  grad.addColorStop(0, '#f4f4f8');
  grad.addColorStop(0.5, '#8a93a8');
  grad.addColorStop(1, '#3a4054');
  g.fillStyle = grad;
  g.beginPath();
  g.moveTo(0, 0);
  g.lineTo(232, 0);
  g.lineTo(224, 22);
  g.lineTo(8, 22);
  g.closePath();
  g.fill();
  g.strokeStyle = '#11131c';
  g.lineWidth = 1;
  g.stroke();
  g.clearRect(6, 5, 220, 12);
  g.globalCompositeOperation = 'destination-out';
  g.fillRect(6, 5, 220, 12);
  g.globalCompositeOperation = 'source-over';
  g.strokeStyle = '#11131c';
  g.strokeRect(5.5, 4.5, 221, 13);
  return c;
}

function koBadge() {
  const { c, g } = hiRes(40, 26);
  g.fillStyle = '#11131c';
  g.beginPath();
  g.moveTo(6, 0);
  g.lineTo(34, 0);
  g.lineTo(40, 13);
  g.lineTo(34, 26);
  g.lineTo(6, 26);
  g.lineTo(0, 13);
  g.closePath();
  g.fill();
  const grad = g.createLinearGradient(0, 2, 0, 24);
  grad.addColorStop(0, '#ff6a4a');
  grad.addColorStop(1, '#9a0c0c');
  g.fillStyle = grad;
  g.beginPath();
  g.moveTo(7, 2);
  g.lineTo(33, 2);
  g.lineTo(38, 13);
  g.lineTo(33, 24);
  g.lineTo(7, 24);
  g.lineTo(2, 13);
  g.closePath();
  g.fill();
  const text = word('KO', 17 * UI_SCALE, GOLD, { outline: 2 * UI_SCALE, shadow: UI_SCALE });
  g.drawImage(text, (40 - text.width / UI_SCALE) / 2 + 1, (26 - text.height / UI_SCALE) / 2 + 1, text.width / UI_SCALE, text.height / UI_SCALE);
  return c;
}

function roundMark(won) {
  const { c, g } = hiRes(14, 14);
  g.fillStyle = '#11131c';
  g.beginPath();
  g.arc(7, 7, 7, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = won ? '#ffd23a' : '#3a4054';
  g.beginPath();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 ? 2.6 : 5.6;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    g.lineTo(7 + Math.cos(a) * r, 7 + Math.sin(a) * r);
  }
  g.closePath();
  g.fill();
  return c;
}

function portraitFrame() {
  const { c, g } = hiRes(44, 44);
  g.fillStyle = '#11131c';
  g.fillRect(0, 0, 44, 44);
  const grad = g.createLinearGradient(0, 0, 44, 44);
  grad.addColorStop(0, '#f4f4f8');
  grad.addColorStop(1, '#3a4054');
  g.fillStyle = grad;
  g.fillRect(1, 1, 42, 42);
  g.clearRect(3, 3, 38, 38);
  return c;
}

function timerBox() {
  const { c, g } = hiRes(48, 34);
  g.fillStyle = '#11131c';
  g.fillRect(0, 0, 48, 34);
  const grad = g.createLinearGradient(0, 0, 0, 34);
  grad.addColorStop(0, '#2c3250');
  grad.addColorStop(1, '#0c0e18');
  g.fillStyle = grad;
  g.fillRect(2, 2, 44, 30);
  return c;
}

// ---------- Effects ----------

function starburst(size, frame, frames, inner, outer, rays) {
  const c = createCanvas(size, size);
  const g = c.getContext('2d');
  const t = frame / (frames - 1);
  const cx = size / 2;
  const radius = (size / 2) * (0.45 + 0.55 * Math.sqrt(t));
  g.globalAlpha = 1 - t * 0.75;
  const grad = g.createRadialGradient(cx, cx, 0, cx, cx, radius);
  grad.addColorStop(0, '#ffffff');
  grad.addColorStop(0.35, inner);
  grad.addColorStop(1, outer);
  g.fillStyle = grad;
  g.beginPath();
  for (let i = 0; i < rays * 2; i++) {
    const jitter = 0.75 + rand() * 0.5;
    const r = i % 2 ? radius * 0.32 * (1 - t * 0.5) : radius * jitter;
    const a = (i * Math.PI) / rays + frame * 0.3;
    g.lineTo(cx + Math.cos(a) * r, cx + Math.sin(a) * r);
  }
  g.closePath();
  g.fill();
  if (t > 0.3) {
    // Hollow out the middle as it fades: a ring of sparks.
    g.globalCompositeOperation = 'destination-out';
    g.beginPath();
    g.arc(cx, cx, radius * (t - 0.2) * 0.8, 0, Math.PI * 2);
    g.fill();
  }
  return c;
}

function projectile(frame, core, mid, edge) {
  const w = 60;
  const h = 36;
  const c = createCanvas(w, h);
  const g = c.getContext('2d');
  // Flickering tail streaks, then the orb at the front (facing right).
  for (let i = 0; i < 9; i++) {
    const y = h / 2 + (rand() - 0.5) * h * 0.55;
    const len = 18 + rand() * 22;
    const grad = g.createLinearGradient(w - 22 - len, 0, w - 18, 0);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, mid);
    g.strokeStyle = grad;
    g.lineWidth = 2 + rand() * 3;
    g.lineCap = 'round';
    g.beginPath();
    g.moveTo(w - 22 - len, y);
    g.lineTo(w - 18, h / 2 + (y - h / 2) * 0.4);
    g.stroke();
  }
  const r = 13 + (frame % 2) * 1.5;
  const grad = g.createRadialGradient(w - 18, h / 2, 1, w - 18, h / 2, r);
  grad.addColorStop(0, '#ffffff');
  grad.addColorStop(0.3, core);
  grad.addColorStop(0.75, mid);
  grad.addColorStop(1, edge);
  g.fillStyle = grad;
  g.beginPath();
  g.arc(w - 18, h / 2, r, 0, Math.PI * 2);
  g.fill();
  return c;
}

function floorTile() {
  // 256x64, tiles horizontally. Top is the back of the floor.
  const w = 256;
  const h = 64;
  const c = createCanvas(w, h);
  const g = c.getContext('2d');
  const grad = g.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, '#3b4a3d');
  grad.addColorStop(0.15, '#2c372d');
  grad.addColorStop(1, '#141a15');
  g.fillStyle = grad;
  g.fillRect(0, 0, w, h);
  // Rows of plates get taller toward the front.
  const rows = [0, 5, 12, 21, 33, 47, 64];
  for (let r = 0; r < rows.length - 1; r++) {
    g.fillStyle = 'rgba(0,0,0,0.55)';
    g.fillRect(0, rows[r], w, 1);
    g.fillStyle = 'rgba(160,200,150,0.12)';
    g.fillRect(0, rows[r] + 1, w, 1);
    const plateW = 32 + r * 16;
    const offset = r % 2 ? plateW / 2 : 0;
    for (let x = -offset; x < w; x += plateW) {
      g.fillStyle = 'rgba(0,0,0,0.45)';
      g.fillRect(Math.round(x), rows[r], 1, rows[r + 1] - rows[r]);
      // Rivets.
      if (r >= 2) {
        g.fillStyle = 'rgba(170,200,160,0.35)';
        g.fillRect(Math.round(x) + 3, rows[r] + 3, 1, 1);
        g.fillRect(Math.round(x) + plateW - 4, rows[r] + 3, 1, 1);
      }
    }
  }
  // Grime speckle.
  for (let i = 0; i < 420; i++) {
    const y = Math.floor(rand() * h);
    g.fillStyle = rand() < 0.5 ? `rgba(0,0,0,${0.15 + rand() * 0.25})` : `rgba(140,170,120,${0.05 + rand() * 0.1})`;
    g.fillRect(Math.floor(rand() * w), y, 1 + Math.floor((rand() * y) / 16), 1);
  }
  // Lit front lip at the back edge, where the fighters stand.
  g.fillStyle = '#6f8a62';
  g.fillRect(0, 0, w, 1);
  return c;
}

function shadowBlob() {
  const c = createCanvas(64, 12);
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(32, 6, 1, 32, 6, 32);
  grad.addColorStop(0, 'rgba(0,0,0,0.75)');
  grad.addColorStop(0.6, 'rgba(0,0,0,0.45)');
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = grad;
  g.save();
  g.scale(1, 12 / 64);
  g.beginPath();
  g.arc(32, 32, 32, 0, Math.PI * 2);
  g.fill();
  g.restore();
  return c;
}

// ---------- Logo, splash, icons ----------

function logo(scale = 1) {
  const iron = word('IRONYARD', Math.round(84 * scale), STEEL, { outlineColor: '#0d1324', shadowColor: '#000000' });
  const brawl = word('BRAWL', Math.round(64 * scale), FIRE, { shadowColor: '#000000' });
  const w = Math.max(iron.width, brawl.width);
  const overlap = Math.round(22 * scale);
  const c = createCanvas(w, iron.height + brawl.height - overlap);
  const g = c.getContext('2d');
  g.drawImage(iron, (w - iron.width) / 2, 0);
  // BRAWL in front, stamped over IRONYARD's lower edge, off to the right.
  g.drawImage(brawl, (w - brawl.width) / 2 + Math.round(70 * scale), iron.height - overlap);
  return c;
}

async function stageBackdrop(width, height) {
  const c = createCanvas(width, height);
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = false;
  const layers = ['skill-desc_0003_bg.png', 'skill-desc_0002_far-buildings.png', 'skill-desc_0001_buildings.png', 'skill-desc_0000_foreground.png'];
  const scale = height / 160;
  for (const [i, file] of layers.entries()) {
    const img = await loadImage(path.join(ROOT, 'src', 'sprites', 'stage', file));
    const drawW = img.width * scale;
    const drawH = img.height * scale;
    const offset = [0, -40, -120, -260][i] * scale;
    for (let x = offset; x < width; x += drawW) {
      g.drawImage(img, x, height - drawH, drawW, drawH);
    }
  }
  // Darken toward the bottom so the fighters and logo stand out.
  const shade = g.createLinearGradient(0, 0, 0, height);
  shade.addColorStop(0, 'rgba(5,10,20,0.15)');
  shade.addColorStop(1, 'rgba(5,10,20,0.75)');
  g.fillStyle = shade;
  g.fillRect(0, 0, width, height);
  return c;
}

// A full-size frame from a character sheet (cut out of the 35x29 grid).
async function sheetFrame(file, frame) {
  const img = await loadImage(path.join(ROOT, 'art', file));
  const cw = img.width / 35;
  const ch = img.height / 29;
  const c = createCanvas(Math.ceil(cw), Math.ceil(ch));
  c.getContext('2d').drawImage(img, (frame % 35) * cw, Math.floor(frame / 35) * ch, cw, ch, 0, 0, cw, ch);
  return c;
}

async function splash(width, height) {
  const c = await stageBackdrop(width, height);
  const g = c.getContext('2d');
  const unit = height / 720;
  const blaze = await sheetFrame('Orangeblack.png', 49);
  const frost = await sheetFrame('Blueehite.png', 181);
  const size = 470 * unit;
  const feetY = height - size * 0.93;
  g.drawImage(blaze, width / 2 - size * 1.05, feetY, size, size);
  g.save();
  g.translate(width / 2 + size * 1.05, 0);
  g.scale(-1, 1);
  g.drawImage(frost, 0, feetY, size, size);
  g.restore();
  const l = logo(1.75 * unit);
  g.drawImage(l, (width - l.width) / 2, height * 0.06);
  return c;
}

async function icon(width, height) {
  const c = await stageBackdrop(width, height);
  const g = c.getContext('2d');
  const fit = logo(1);
  const l = logo(Math.min((width * 0.9) / fit.width, (height * 0.8) / fit.height));
  g.drawImage(l, (width - l.width) / 2, (height - l.height) / 2);
  return c;
}

// ---------- Packing ----------

function pack(pieces) {
  // Shelf packing into a 1024-wide sheet.
  const sheetW = 1024;
  let x = 0;
  let y = 0;
  let shelf = 0;
  const rects = {};
  const sorted = Object.entries(pieces).sort((a, b) => b[1].height - a[1].height);
  for (const [name, canvas] of sorted) {
    if (x + canvas.width > sheetW) {
      x = 0;
      y += shelf + 2;
      shelf = 0;
    }
    rects[name] = { x, y, w: canvas.width, h: canvas.height };
    x += canvas.width + 2;
    shelf = Math.max(shelf, canvas.height);
  }
  const sheet = createCanvas(sheetW, y + shelf);
  const g = sheet.getContext('2d');
  for (const [name, canvas] of sorted) g.drawImage(canvas, rects[name].x, rects[name].y);
  return { sheet, rects };
}

async function main() {
  const pieces = {
    logo: logo(UI_SCALE),
    round1: word('ROUND 1', 88, FIRE),
    round2: word('ROUND 2', 88, FIRE),
    round3: word('ROUND 3', 88, FIRE),
    round4: word('ROUND 4', 88, FIRE),
    round5: word('ROUND 5', 88, FIRE),
    finalRound: word('FINAL ROUND', 88, FIRE),
    fight: word('FIGHT!', 144, FIRE),
    ko: word('K.O.', 192, FIRE),
    time: word('TIME', 144, STEEL, { outlineColor: '#0d1324' }),
    perfect: word('PERFECT', 112, GOLD),
    draw: word('DRAW', 144, STEEL, { outlineColor: '#0d1324' }),
    youWin: word('YOU WIN', 120, GOLD),
    youLose: word('YOU LOSE', 120, STEEL, { outlineColor: '#0d1324' }),
    p1Wins: word('P1 WINS', 120, GOLD),
    p2Wins: word('P2 WINS', 120, GOLD),
    cpuWins: word('CPU WINS', 120, GOLD),
    paused: word('PAUSED', 96, STEEL, { outlineColor: '#0d1324' }),
    vs: word('VS', 128, FIRE),
    chooseFighter: word('CHOOSE YOUR FIGHTER', 60, GOLD),
    nameBlaze: word('BLAZE', 60, FIRE),
    nameFrost: word('FROST', 60, ICE, { outlineColor: '#06213f' }),
    barFrame: barFrame(),
    koBadge: koBadge(),
    markWon: roundMark(true),
    markEmpty: roundMark(false),
    portraitFrame: portraitFrame(),
    timerBox: timerBox(),
    floor: floorTile(),
    shadow: shadowBlob()
  };
  for (let f = 0; f < 5; f++) {
    pieces[`spark${f}`] = starburst(52, f, 5, '#fff066', 'rgba(255,90,20,0)', 8);
    pieces[`block${f}`] = starburst(44, f, 5, '#c8f0ff', 'rgba(40,120,255,0)', 6);
  }
  for (let f = 0; f < 4; f++) {
    pieces[`fire${f}`] = projectile(f, '#fff2a0', '#ff9a1a', 'rgba(220,40,0,0)');
    pieces[`ice${f}`] = projectile(f, '#e6ffff', '#56d8ff', 'rgba(20,80,255,0)');
  }
  const { sheet, rects } = pack(pieces);
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const data = sheet.getContext('2d').getImageData(0, 0, sheet.width, sheet.height).data;
  await writeWebp(data, sheet.width, sheet.height, path.join(OUT_DIR, 'ui.webp'));
  fs.writeFileSync(path.join(OUT_DIR, 'ui.json'), JSON.stringify(rects) + '\n');
  console.log(`ui.webp ${sheet.width}x${sheet.height}, ${Object.keys(rects).length} pieces`);

  const images = path.join(ROOT, 'src', 'images');
  const jpg = (canvas, file) => fs.writeFileSync(path.join(images, file), canvas.toBuffer('image/jpeg', { quality: 0.9 }));
  jpg(await splash(1280, 720), 'Splash_HD.jpg');
  jpg(await splash(720, 480), 'Splash_SD.jpg');
  jpg(await icon(336, 210), 'Channel_Icon_HD.jpg');
  jpg(await icon(246, 140), 'Channel_Icon_SD.jpg');
  // The title screen's backdrop, at canvas size.
  const title = await stageBackdrop(640, 360);
  fs.writeFileSync(path.join(images, 'title_bg.jpg'), title.toBuffer('image/jpeg', { quality: 0.9 }));
  for (const old of ['Splash_HD.png', 'Splash_SD.png', 'Channel_Icon_HD.png', 'Channel_Icon_SD.png']) {
    fs.rmSync(path.join(images, old), { force: true });
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
