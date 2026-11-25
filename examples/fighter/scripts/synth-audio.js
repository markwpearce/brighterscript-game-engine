#!/usr/bin/env node
// Synthesizes the sounds the CC0/OGA packs don't cover (whooshes, jump/land, menu blips,
// the KO sting) and the chiptune music, into src/sounds/ and src/music/.
// Music is written as WAV, then converted to MP3 with ffmpeg (must be on PATH).
//
// Usage (from examples/fighter): node scripts/synth-audio.js
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const RATE = 22050;

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

const midiHz = (n) => 440 * Math.pow(2, (n - 69) / 12);

function pulse(phase, duty) {
  return phase % 1 < duty ? 1 : -1;
}

function triangle(phase) {
  const p = phase % 1;
  return p < 0.5 ? p * 4 - 1 : 3 - p * 4;
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

// ----- Music: a tiny tracker. Notes are [midi or null, length in 8ths]. -----

const N = (name) => {
  const m = /^([A-G])(#?)(\d)$/.exec(name);
  const base = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]];
  return 12 * (Number(m[3]) + 1) + base + (m[2] ? 1 : 0);
};

function parseMelody(text) {
  return text
    .trim()
    .split(/\s+/)
    .map((tok) => {
      const [note, len] = tok.split(':');
      return [note === '-' ? null : N(note), Number(len)];
    });
}

// Chord roots/qualities per bar, for the bass and arpeggio.
const CHORDS = {
  Am: [N('A2'), [0, 3, 7]],
  F: [N('F2'), [0, 4, 7]],
  G: [N('G2'), [0, 4, 7]],
  Em: [N('E2'), [0, 3, 7]],
  E: [N('E2'), [0, 4, 7]],
  Dm: [N('D2'), [0, 3, 7]],
  C: [N('C3'), [0, 4, 7]]
};

function renderSong({ bpm, chords, melody, drums, leadDuty, arp }) {
  const eighth = 60 / bpm / 2;
  const bars = chords.length;
  const out = buffer(bars * 8 * eighth);
  const add = (start, seconds, fn) => {
    const s0 = Math.floor(start * RATE);
    const len = Math.floor(seconds * RATE);
    for (let i = 0; i < len && s0 + i < out.length; i++) out[s0 + i] += fn(i / RATE, i / len);
  };

  // Lead: pulse with a little vibrato and a decay to a sustain.
  let t = 0;
  for (const [note, len] of melody) {
    if (note !== null) {
      const hz = midiHz(note);
      const dur = len * eighth;
      add(t, dur * 0.95, (s, p) => {
        const vib = 1 + 0.004 * Math.sin(2 * Math.PI * 5.5 * s) * Math.min(1, s * 4);
        const env = (0.55 + 0.45 * Math.exp(-s * 8)) * Math.min(1, (1 - p) * 12);
        return pulse(s * hz * vib, leadDuty) * env * 0.16;
      });
    }
    t += len * eighth;
  }

  chords.forEach((name, bar) => {
    const [root, quality] = CHORDS[name];
    const barStart = bar * 8 * eighth;
    // Bass: octave-bouncing eighths on a triangle.
    for (let k = 0; k < 8; k++) {
      const n = root + (k % 2 ? 12 : 0);
      add(barStart + k * eighth, eighth * 0.9, (s, p) => triangle(s * midiHz(n)) * 0.32 * (1 - p * 0.6));
    }
    // Arpeggio: chord tones in sixteenths, quiet.
    if (arp) {
      for (let k = 0; k < 16; k++) {
        const n = root + 24 + quality[k % 3] + (k % 6 >= 3 ? 12 : 0);
        add(barStart + (k * eighth) / 2, (eighth / 2) * 0.8, (s, p) => pulse(s * midiHz(n), 0.125) * 0.045 * (1 - p));
      }
    }
    // Drums: pattern string per bar of 16 sixteenths. k = kick, s = snare, h = hat.
    for (let k = 0; k < 16; k++) {
      const start = barStart + (k * eighth) / 2;
      for (const hit of drums[k] || '') {
        if (hit === 'k') {
          add(start, 0.14, (s, p) => Math.sin(2 * Math.PI * (55 + 90 * (1 - p) * (1 - p)) * s) * (1 - p) * 0.55);
        } else if (hit === 's') {
          add(start, 0.12, (s, p) => (noise() * 0.7 + Math.sin(2 * Math.PI * 190 * s) * 0.3) * Math.pow(1 - p, 2) * 0.32);
        } else if (hit === 'h') {
          add(start, 0.03, (s, p) => noise() * (1 - p) * 0.08);
        }
      }
    }
  });
  return out;
}

function drumPattern(spec) {
  // spec: 16 chars per voice line, combined.
  const out = Array(16).fill('');
  for (const [voice, line] of Object.entries(spec)) {
    [...line].forEach((c, i) => {
      if (c === 'x') out[i] += voice;
    });
  }
  return out;
}

const FIGHT_MELODY = parseMelody(`
  A4:1 A4:1 C5:2 E5:2 D5:1 C5:1
  C5:3 A4:1 F4:2 A4:2
  B4:1 B4:1 D5:2 G5:2 F5:1 E5:1
  E5:6 -:2
  A5:1 G5:1 E5:2 C5:2 E5:1 G5:1
  A5:3 G5:1 F5:2 E5:2
  D5:1 E5:1 F5:1 G5:1 F5:2 D5:2
  E5:2 G#5:2 B5:4
  F5:2 E5:1 D5:1 A4:2 D5:2
  E5:2 D5:1 C5:1 A4:4
  F5:1 F5:1 G5:1 A5:1 G5:2 F5:2
  E5:4 G#4:2 B4:2
  C5:1 D5:1 E5:1 F5:1 A5:2 F5:2
  G5:1 F5:1 E5:1 D5:1 B4:2 D5:2
  C5:2 E5:2 A5:2 G#5:2
  A5:6 -:2
`);

const TITLE_MELODY = parseMelody(`
  E5:4 D5:2 C5:2
  C5:4 A4:4
  B4:4 C5:2 D5:2
  E5:8
  A5:4 G5:2 E5:2
  F5:4 E5:2 C5:2
  D5:2 E5:2 F5:2 D5:2
  E5:8
`);

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

  const music = path.join(ROOT, 'src', 'music');
  const fightDrums = drumPattern({ k: 'x.....x.x.....x.', s: '....x.......x..x', h: 'x.x.x.x.x.x.x.x.' });
  const fight = renderSong({
    bpm: 150,
    chords: ['Am', 'F', 'G', 'Em', 'Am', 'F', 'G', 'E', 'Dm', 'Am', 'Dm', 'E', 'F', 'G', 'Am', 'Am'],
    melody: FIGHT_MELODY,
    drums: fightDrums,
    leadDuty: 0.25,
    arp: true
  });
  const titleDrums = drumPattern({ k: 'x.......x.......', s: '........x.......', h: '..x...x...x...x.' });
  const title = renderSong({
    bpm: 112,
    chords: ['Am', 'F', 'G', 'Em', 'Am', 'F', 'Dm', 'E'],
    melody: TITLE_MELODY,
    drums: titleDrums,
    leadDuty: 0.5,
    arp: true
  });
  const victory = renderSong({
    bpm: 150,
    chords: ['C', 'G', 'C'],
    melody: parseMelody('G4:1 C5:1 E5:1 G5:1 C6:4 B5:1 A5:1 B5:1 G5:1 D6:4 C6:8'),
    drums: drumPattern({ k: 'x...x...x...x...', s: '', h: 'x.x.x.x.x.x.x.x.' }),
    leadDuty: 0.25,
    arp: false
  });
  for (const [name, samples] of Object.entries({ fight, title, victory })) {
    const wav = path.join(music, `${name}.wav`);
    writeWav(wav, samples);
    execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '96k', path.join(music, `${name}.mp3`)]);
    fs.unlinkSync(wav);
  }
}

main();
