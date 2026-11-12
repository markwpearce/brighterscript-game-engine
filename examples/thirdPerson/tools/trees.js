// Prepares the graveyard's tree billboards from isometric tree sprites (Sprite_01.png ...) with a
// shadow baked in: clears the shadow, trims to the tree and scales it down.
//
//   node tools/trees.js <folder of Sprite_0N.png> [out folder, default src/sprites]
//
// Writes tree_<n>.webp, base on the bottom row. The shadow is near-black and at most half opaque,
// while the tree is coloured and nearly opaque, so a threshold separates them.

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { readRgba, writeWebp } = require('../../../scripts/webp.js');

const HEIGHT = 320;
const SHADOW_MAX_RGB = 40;
const SHADOW_MAX_ALPHA = 140;

async function prepare(inPath, outPath) {
  const { data, width, height } = await readRgba(inPath);
  let minX = width, minY = height, maxX = -1, maxY = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3];
      if (a > 0 && a <= SHADOW_MAX_ALPHA && r <= SHADOW_MAX_RGB && g <= SHADOW_MAX_RGB && b <= SHADOW_MAX_RGB) {
        data[i + 3] = 0;
      }
      if (data[i + 3] > 24) {
        minX = Math.min(minX, x); maxX = Math.max(maxX, x);
        minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      }
    }
  }
  const w = maxX - minX + 1;
  const h = maxY - minY + 1;
  const outW = Math.round(w * HEIGHT / h);
  const { data: scaled, info } = await sharp(data, { raw: { width, height, channels: 4 } })
    .extract({ left: minX, top: minY, width: w, height: h })
    .resize(outW, HEIGHT, { kernel: 'lanczos3' })
    .raw()
    .toBuffer({ resolveWithObject: true });
  await writeWebp(scaled, info.width, info.height, outPath);
  console.log(`${path.basename(outPath)}: ${info.width}x${info.height}`);
}

async function main() {
  const [inDir, outDir = path.join(__dirname, '..', 'src', 'sprites')] = process.argv.slice(2);
  if (!inDir) {
    console.error('usage: node tools/trees.js <folder of Sprite_0N.png> [out folder]');
    process.exit(1);
  }
  const files = fs.readdirSync(inDir).filter((f) => /^Sprite_\d+\.png$/i.test(f)).sort();
  for (let n = 0; n < files.length; n++) {
    await prepare(path.join(inDir, files[n]), path.join(outDir, `tree_${n + 1}.webp`));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
