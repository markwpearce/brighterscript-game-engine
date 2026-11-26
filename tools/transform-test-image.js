#!/usr/bin/env node
// Draws the test image rendererTest's TransformedImageTest rotates and scales: coloured tiles, an
// "UP" arrow and labelled corners, so rotation and flips are easy to read (#696).
//
// Usage: node tools/transform-test-image.js [out]   (default: examples/rendererTest/src/images/transformTest.jpg)

const path = require('path');
const sharp = require('sharp');

const WIDTH = 1200;
const HEIGHT = 675;
const OUT = process.argv[2] || path.join(__dirname, '..', 'examples', 'rendererTest', 'src', 'images', 'transformTest.jpg');
const COLORS = ['#e53935', '#fb8c00', '#fdd835', '#43a047', '#1e88e5', '#8e24aa'];

function tiles() {
  const cols = 3;
  const tileW = 300;
  const tileH = 160;
  const left = (WIDTH - cols * tileW - (cols - 1) * 30) / 2;
  return COLORS.map((color, i) => {
    const x = left + (i % cols) * (tileW + 30);
    const y = 230 + Math.floor(i / cols) * (tileH + 30);
    return `<rect x="${x}" y="${y}" width="${tileW}" height="${tileH}" rx="18" fill="${color}"/>
      <text x="${x + tileW / 2}" y="${y + tileH / 2 + 28}" font-size="80" text-anchor="middle" fill="#fff" font-family="sans-serif" font-weight="bold">${i + 1}</text>`;
  }).join('\n');
}

function corner(label, x, y, anchor) {
  return `<text x="${x}" y="${y}" font-size="44" text-anchor="${anchor}" fill="#fff" font-family="sans-serif" font-weight="bold">${label}</text>`;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="#1b1f3a"/>
  <rect x="8" y="8" width="${WIDTH - 16}" height="${HEIGHT - 16}" fill="none" stroke="#fff" stroke-width="8"/>
  <polygon points="600,40 670,130 625,130 625,200 575,200 575,130 530,130" fill="#fff"/>
  ${corner('TL', 30, 70, 'start')}
  ${corner('TR', WIDTH - 30, 70, 'end')}
  ${corner('BL', 30, HEIGHT - 30, 'start')}
  ${corner('BR', WIDTH - 30, HEIGHT - 30, 'end')}
  ${tiles()}
</svg>`;

sharp(Buffer.from(svg))
  .jpeg({ quality: 85 })
  .toFile(OUT)
  .then((info) => console.log(`Wrote ${path.relative(process.cwd(), OUT)} (${info.size} bytes)`));
