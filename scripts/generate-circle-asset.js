#!/usr/bin/env node
// Generates the engine's shipped circle fill asset (see DrawableCircle) - a
// transparent-background PNG with an opaque white filled circle, scaled and
// tinted at draw time the same way any other texture-backed drawable is.
//
// pureimage 0.4.20 quirks this works around (confirmed by hand):
//   - PImage.make() defaults every pixel to opaque black, not transparent -
//     every pixel is explicitly reset to fully transparent first.
//   - ctx.fill() after ctx.beginPath()+ctx.arc() alone silently fills
//     nothing - it only works when the path starts with an explicit
//     moveTo() onto the arc's own starting point first.
//
// Can be run standalone: node scripts/generate-circle-asset.js
// or required as a module: generateCircleAsset(outPath)

const path = require('path');
const fs = require('fs');
const PImage = require('pureimage');

const SIZE = 128;
const MARGIN = 2;

async function generateCircleAsset(outPath) {
  const img = PImage.make(SIZE, SIZE);

  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      img.setPixelRGBA(x, y, 0x00000000);
    }
  }

  const ctx = img.getContext('2d');
  ctx.fillStyle = '#ffffff';
  const cx = SIZE / 2;
  const cy = SIZE / 2;
  const r = SIZE / 2 - MARGIN;
  ctx.beginPath();
  ctx.moveTo(cx + r, cy);
  ctx.arc(cx, cy, r, 0, Math.PI * 2, false);
  ctx.closePath();
  ctx.fill();

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  await PImage.encodePNGToStream(img, fs.createWriteStream(outPath));
}

module.exports = { generateCircleAsset };

if (require.main === module) {
  const outPath = path.join(__dirname, '..', 'src', 'source', 'images', 'circle.png');
  generateCircleAsset(outPath)
    .then(() => console.log(`Generated ${outPath}`))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
