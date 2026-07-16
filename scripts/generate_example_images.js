#!/usr/bin/env node
// Generates simple placeholder icon/splash images (dark background + wrapped
// bold title text), the same look as examples/rendererTest, using pureimage -
// a pure-JS canvas implementation, so no ImageMagick/native deps are needed.
//
// Usage: node scripts/generate_example_images.js "<title>" "<imagesDir>"

const path = require('path');
const fs = require('fs');
const PImage = require('pureimage');

const BACKGROUND = '#333333';
const FOREGROUND = '#ffffff';
const FONT_PATH = path.join(__dirname, 'assets', 'fonts', 'WorkSans-Bold.ttf');
const FONT_NAME = 'WorkSans-Bold';

const SIZES = [
  { file: 'Channel_Icon_HD.png', width: 336, height: 210 },
  { file: 'Channel_Icon_SD.png', width: 246, height: 140 },
  { file: 'Splash_HD.png', width: 1280, height: 720 },
  { file: 'Splash_SD.png', width: 720, height: 480 }
];

function wrapLines(ctx, text, maxWidth) {
  const words = text.split(/\s+/).filter(Boolean);
  const lines = [];
  let line = '';
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (ctx.measureText(candidate).width > maxWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) {
    lines.push(line);
  }
  return lines;
}

function fontSizeForImage(width, height) {
  return Math.max(12, Math.round(Math.min(width, height) * 0.14));
}

async function generateImage(title, width, height, outPath) {
  const img = PImage.make(width, height);
  const ctx = img.getContext('2d');

  ctx.fillStyle = BACKGROUND;
  ctx.fillRect(0, 0, width, height);

  const padding = Math.round(width * 0.08);
  const maxTextWidth = width - padding * 2;

  let fontSize = fontSizeForImage(width, height);
  ctx.font = `${fontSize}pt '${FONT_NAME}'`;
  let lines = wrapLines(ctx, title, maxTextWidth);

  // Shrink the font until the wrapped text fits vertically too.
  while (lines.length * fontSize * 1.3 > height - padding * 2 && fontSize > 10) {
    fontSize -= 2;
    ctx.font = `${fontSize}pt '${FONT_NAME}'`;
    lines = wrapLines(ctx, title, maxTextWidth);
  }

  ctx.fillStyle = FOREGROUND;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  const lineHeight = fontSize * 1.3;
  const blockHeight = lines.length * lineHeight;
  let y = height / 2 - blockHeight / 2 + lineHeight / 2;

  for (const line of lines) {
    ctx.fillText(line, width / 2, y);
    y += lineHeight;
  }

  await PImage.encodePNGToStream(img, fs.createWriteStream(outPath));
}

async function main() {
  const title = process.argv[2];
  const imagesDir = process.argv[3];

  if (!title || !imagesDir) {
    console.error('Usage: node scripts/generate_example_images.js "<title>" "<imagesDir>"');
    process.exit(1);
  }

  const font = PImage.registerFont(FONT_PATH, FONT_NAME);
  await font.load();

  for (const size of SIZES) {
    const outPath = path.join(imagesDir, size.file);
    await generateImage(title, size.width, size.height, outPath);
  }

  console.log(`Generated icon/splash images in ${imagesDir} from title "${title}"`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
