#!/usr/bin/env node
// Draws the top-down race track that examples/terrain lays on its ground plane.
// Replaces a ripped Super Mario Kart map (#696).
//
// Usage: node tools/race-track.js [out]   (default: examples/terrain/src/sprites/raceTrack.png)

const path = require('path');
const sharp = require('sharp');

const SIZE = 1024;
const OUT = process.argv[2] || path.join(__dirname, '..', 'examples', 'terrain', 'src', 'sprites', 'raceTrack.png');

// Centre line of the circuit, as a closed loop of cubic beziers
const TRACK = [
  'M 200 820',
  'C 120 820 110 700 140 600',
  'C 180 470 120 360 170 250',
  'C 220 140 360 130 430 200',
  'C 500 270 520 380 610 380',
  'C 700 380 700 180 800 160',
  'C 900 140 930 260 900 360',
  'C 860 500 760 520 760 620',
  'C 760 720 900 730 880 840',
  'C 860 930 700 920 600 880',
  'C 480 830 360 820 200 820 Z'
].join(' ');

function svg() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}">
  <defs>
    <pattern id="dirt" width="8" height="8" patternUnits="userSpaceOnUse">
      <rect width="8" height="8" fill="#8a7650"/>
      <rect x="1" y="2" width="2" height="2" fill="#7c6a46"/>
      <rect x="5" y="5" width="2" height="2" fill="#9a865e"/>
    </pattern>
    <pattern id="checker" width="20" height="20" patternUnits="userSpaceOnUse">
      <rect width="20" height="20" fill="#fff"/>
      <rect width="10" height="10" fill="#111"/>
      <rect x="10" y="10" width="10" height="10" fill="#111"/>
    </pattern>
  </defs>
  <rect width="${SIZE}" height="${SIZE}" fill="url(#dirt)"/>
  <!-- grass verges outside the circuit and in its infield -->
  <path d="M 0 0 H 1024 V 90 H 0 Z M 0 960 H 1024 V 1024 H 0 Z" fill="#3f8f2f"/>
  <ellipse cx="300" cy="520" rx="90" ry="200" fill="#3f8f2f"/>
  <ellipse cx="820" cy="250" rx="45" ry="60" fill="#3f8f2f"/>
  <circle cx="620" cy="700" r="80" fill="#3f8f2f"/>
  <!-- kerbs: red/white dashes under the asphalt edge -->
  <path d="${TRACK}" fill="none" stroke="#fff" stroke-width="132" stroke-linejoin="round"/>
  <path d="${TRACK}" fill="none" stroke="#c62828" stroke-width="132" stroke-dasharray="18 18" stroke-linejoin="round"/>
  <path d="${TRACK}" fill="none" stroke="#5a5a5e" stroke-width="116" stroke-linejoin="round"/>
  <path d="${TRACK}" fill="none" stroke="#e8e8e8" stroke-width="3" stroke-dasharray="30 26"/>
  <!-- start/finish line -->
  <rect x="290" y="762" width="20" height="116" fill="url(#checker)"/>
</svg>`;
}

sharp(Buffer.from(svg()))
  .png({ palette: true, colors: 64 })
  .toFile(OUT)
  .then((info) => console.log(`Wrote ${path.relative(process.cwd(), OUT)} (${info.size} bytes)`));
