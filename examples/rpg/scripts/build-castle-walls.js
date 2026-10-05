#!/usr/bin/env node
// Builds examples/rpg/src/sprites/castleWalls.png from Castle2.png: the keep's side/south wall
// tiles and its rotated, squashed doorway arches (open and barred). Pre-rendered so the device
// never rotates anything at runtime. Regions must match the castleWalls entries in Maps/Atlas.bs.
//
//   node examples/rpg/scripts/build-castle-walls.js

const fs = require('fs');
const path = require('path');
const PImage = require('pureimage');

const SPRITES = path.join(__dirname, '..', 'src', 'sprites');
const TILE = 32;
// Wall-top cap and its inner rim, sampled to sit with Castle2's brown brick.
const CAP = 0x3b302fff;
const RIM = 0x7d6a5eff;
const CAP_DEPTH = 11;
const RIM_DEPTH = 2;

const BRICK = { x: 32, y: 128, w: 32, h: 32 };
const ARCH_OPEN = { x: 424, y: 112, w: 84, h: 82 };
const ARCH_BARS = { x: 326, y: 112, w: 84, h: 82 };

function crop(src, r) {
  const out = PImage.make(r.w, r.h);
  for (let y = 0; y < r.h; y++) {
    for (let x = 0; x < r.w; x++) {
      out.setPixelRGBA(x, y, src.getPixelRGBA(r.x + x, r.y + y));
    }
  }
  return out;
}

// quarterTurns: 1 = 90 clockwise (top ends up on the right), -1 = 90 anticlockwise, 2 = 180.
function rotate(src, quarterTurns) {
  const turns = ((quarterTurns % 4) + 4) % 4;
  const w = turns % 2 ? src.height : src.width;
  const h = turns % 2 ? src.width : src.height;
  const out = PImage.make(w, h);
  for (let y = 0; y < src.height; y++) {
    for (let x = 0; x < src.width; x++) {
      let dx = x, dy = y;
      if (turns === 1) { dx = src.height - 1 - y; dy = x; }
      else if (turns === 2) { dx = src.width - 1 - x; dy = src.height - 1 - y; }
      else if (turns === 3) { dx = y; dy = src.width - 1 - x; }
      out.setPixelRGBA(dx, dy, src.getPixelRGBA(x, y));
    }
  }
  return out;
}

// Nearest-neighbour resize, so pixel art stays crisp.
function resize(src, w, h) {
  const out = PImage.make(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      out.setPixelRGBA(x, y, src.getPixelRGBA(Math.floor(x * src.width / w), Math.floor(y * src.height / h)));
    }
  }
  return out;
}

function blit(dest, src, dx, dy) {
  for (let y = 0; y < src.height; y++) {
    for (let x = 0; x < src.width; x++) {
      dest.setPixelRGBA(dx + x, dy + y, src.getPixelRGBA(x, y));
    }
  }
}

function fill(dest, x, y, w, h, rgba) {
  for (let j = 0; j < h; j++) {
    for (let i = 0; i < w; i++) {
      dest.setPixelRGBA(x + i, y + j, rgba);
    }
  }
}

// A wall tile seen from above: brick face toward the room, dark cap with a light rim outside.
// `outward` is the side the cap is on: "w", "e" or "s".
function wallTile(brick, outward) {
  const tile = PImage.make(TILE, TILE);
  const faceDepth = TILE - CAP_DEPTH - RIM_DEPTH;
  if (outward === 's') {
    blit(tile, resize(rotate(brick, 2), TILE, faceDepth), 0, 0);
    fill(tile, 0, faceDepth, TILE, RIM_DEPTH, RIM);
    fill(tile, 0, faceDepth + RIM_DEPTH, TILE, CAP_DEPTH, CAP);
  } else {
    const face = resize(rotate(brick, outward === 'w' ? -1 : 1), faceDepth, TILE);
    const capX = outward === 'w' ? 0 : TILE - CAP_DEPTH;
    const rimX = outward === 'w' ? CAP_DEPTH : TILE - CAP_DEPTH - RIM_DEPTH;
    const faceX = outward === 'w' ? CAP_DEPTH + RIM_DEPTH : 0;
    fill(tile, capX, 0, CAP_DEPTH, TILE, CAP);
    fill(tile, rimX, 0, RIM_DEPTH, TILE, RIM);
    blit(tile, face, faceX, 0);
  }
  return tile;
}

// An arch turned so its curve points out of the room, squashed to one tile of wall depth.
function sideArch(arch, outward) {
  if (outward === 's') {
    return resize(rotate(arch, 2), arch.width, TILE);
  }
  const turned = rotate(arch, outward === 'w' ? -1 : 1);
  return resize(turned, TILE, turned.height);
}

async function main() {
  const castle = await PImage.decodePNGFromStream(fs.createReadStream(path.join(SPRITES, 'Castle2.png')));
  const brick = crop(castle, BRICK);
  const open = crop(castle, ARCH_OPEN);
  const bars = crop(castle, ARCH_BARS);

  // Layout (keep in step with Atlas.bs):
  //   y 0:   wallW, wallE, wallS, wallCorner (32x32 each)
  //   y 32:  archOpenW, archBarsW, archOpenE, archBarsE (32x84 each)
  //   y 116: archOpenS, archBarsS (84x32 each)
  const sheet = PImage.make(168, 148);
  fill(sheet, 0, 0, 168, 148, 0x00000000);
  blit(sheet, wallTile(brick, 'w'), 0, 0);
  blit(sheet, wallTile(brick, 'e'), 32, 0);
  blit(sheet, wallTile(brick, 's'), 64, 0);
  fill(sheet, 96, 0, TILE, TILE, CAP);
  blit(sheet, sideArch(open, 'w'), 0, 32);
  blit(sheet, sideArch(bars, 'w'), 32, 32);
  blit(sheet, sideArch(open, 'e'), 64, 32);
  blit(sheet, sideArch(bars, 'e'), 96, 32);
  blit(sheet, sideArch(open, 's'), 0, 116);
  blit(sheet, sideArch(bars, 's'), 84, 116);

  const outPath = path.join(SPRITES, 'castleWalls.png');
  await PImage.encodePNGToStream(sheet, fs.createWriteStream(outPath));
  console.log('wrote ' + outPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
