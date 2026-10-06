#!/usr/bin/env node
// Builds examples/rpg/src/sprites/witch.png from lpcfemalechainpreview.png, "LPC Combat Armor for
// women" (https://opengameart.org/content/lpc-combat-armor-for-women): the sheet draws a 1px
// semi-transparent frame round every 64x64 cell, which shows as faint boxes round the sprite, so
// those border pixels are cleared. No lossless PNG optimiser (oxipng, pngcrush, optipng, zopflipng)
// was available when this was written, so the output is not further compressed.
//
//   node examples/rpg/scripts/build-witch.js <path to lpcfemalechainpreview.png>

const fs = require('fs');
const path = require('path');
const PImage = require('pureimage');

const CELL = 64;
const FRAME_ALPHA = 76;

async function main() {
  const input = process.argv[2];
  if (!input) {
    console.error('usage: node build-witch.js <path to lpcfemalechainpreview.png>');
    process.exit(1);
  }
  const sheet = await PImage.decodePNGFromStream(fs.createReadStream(input));
  let cleared = 0;
  for (let y = 0; y < sheet.height; y++) {
    for (let x = 0; x < sheet.width; x++) {
      const ex = x % CELL;
      const ey = y % CELL;
      if (ex !== 0 && ex !== CELL - 1 && ey !== 0 && ey !== CELL - 1) {
        continue;
      }
      const i = (y * sheet.width + x) * 4;
      const d = sheet.data;
      const grey = d[i] === d[i + 1] && d[i] === d[i + 2] && (d[i] === 0 || d[i] === 255);
      if (d[i + 3] === FRAME_ALPHA && grey) {
        d[i + 3] = 0;
        cleared++;
      }
    }
  }
  const outPath = path.join(__dirname, '..', 'src', 'sprites', 'witch.png');
  await PImage.encodePNGToStream(sheet, fs.createWriteStream(outPath));
  console.log(`cleared ${cleared} frame pixels -> ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
