#!/usr/bin/env node
// Synthesizes the sounds the CC0/OGA packs don't cover (whooshes, jump/land, menu blips,
// the KO sting) into src/sounds/.
//
// Usage (from examples/fighter): node scripts/synth-audio.js
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const RATE = 16000;

// Seeded so every run writes identical files.
let seed = 12345;
function rand() {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
}
const noise = () => rand() * 2 - 1;

function writeWav(file, samples) {
  const data = Buffer.alloc(samples.length * 2);
  let peak = 0;
  for (const s of samples) peak = Math.max(peak, Math.abs(s));
  const gain = peak > 0.95 ? 0.95 / peak : 1;
  samples.forEach((s, i) => data.writeInt16LE(Math.round(s * gain * 32767), i * 2));
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVEfmt ', 8);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.concat([header, data]));
  console.log(file);
}

function buffer(seconds) {
  return new Float32Array(Math.ceil(seconds * RATE));
}

// Band-passed noise whose centre frequency sweeps from f0 to f1: a whoosh.
function whoosh(seconds, f0, f1, q, volume) {
  const out = buffer(seconds);
  let low = 0;
  let band = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / out.length;
    const f = f0 + (f1 - f0) * t;
    const k = 2 * Math.sin((Math.PI * f) / RATE);
    low += k * band;
    const high = noise() - low - band / q;
    band += k * high;
    const env = Math.sin(Math.PI * Math.min(1, t * 1.6)) * (1 - t);
    out[i] = band * env * volume;
  }
  return out;
}

// A sine whose pitch drops from f0 to f1, decaying: a thud or boom.
function thud(seconds, f0, f1, volume) {
  const out = buffer(seconds);
  let phase = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / out.length;
    phase += (2 * Math.PI * (f0 + (f1 - f0) * t)) / RATE;
    out[i] = Math.sin(phase) * Math.pow(1 - t, 2) * volume;
  }
  return out;
}

function mix(...parts) {
  const len = Math.max(...parts.map((p) => p.length));
  const out = new Float32Array(len);
  for (const p of parts) p.forEach((s, i) => (out[i] += s));
  return out;
}

const N = (name) => {
  const m = /^([A-G])(#?)(\d)$/.exec(name);
  const base = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]];
  return 12 * (Number(m[3]) + 1) + base + (m[2] ? 1 : 0);
};

const midiHz = (n) => 440 * Math.pow(2, (n - 69) / 12);

function pulse(phase, duty) {
  return phase % 1 < duty ? 1 : -1;
}

function blip(notes, noteSeconds, volume) {
  const out = buffer(notes.length * noteSeconds);
  const per = Math.floor(noteSeconds * RATE);
  notes.forEach((n, k) => {
    const hz = midiHz(n);
    for (let i = 0; i < per; i++) {
      const env = 1 - i / per;
      out[k * per + i] = pulse((i * hz) / RATE, 0.5) * env * volume;
    }
  });
  return out;
}

function main() {
  const sounds = path.join(ROOT, 'src', 'sounds');
  writeWav(path.join(sounds, 'whiffLight.wav'), whoosh(0.13, 2600, 900, 2.2, 1.0));
  writeWav(path.join(sounds, 'whiffHeavy.wav'), whoosh(0.24, 1500, 380, 2.8, 1.0));
  writeWav(path.join(sounds, 'jump.wav'), whoosh(0.16, 500, 1800, 3.0, 0.7));
  writeWav(path.join(sounds, 'land.wav'), mix(thud(0.12, 110, 45, 0.8), whoosh(0.08, 400, 150, 1.0, 0.4)));
  writeWav(path.join(sounds, 'thump.wav'), mix(thud(0.3, 90, 30, 1.0), whoosh(0.2, 600, 120, 1.0, 0.7)));
  writeWav(path.join(sounds, 'fireball.wav'), mix(whoosh(0.45, 300, 2400, 4.0, 0.9), blip([N('A5'), N('E6'), N('A6')], 0.06, 0.25)));
  writeWav(path.join(sounds, 'menuMove.wav'), blip([N('E6')], 0.05, 0.4));
  writeWav(path.join(sounds, 'menuSelect.wav'), blip([N('A5'), N('E6')], 0.07, 0.4));
  writeWav(path.join(sounds, 'koSting.wav'), mix(thud(1.1, 70, 28, 1.0), whoosh(0.5, 3000, 200, 0.8, 0.6)));
}

main();
