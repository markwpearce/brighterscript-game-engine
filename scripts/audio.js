#!/usr/bin/env node
// Roku audio tools (needs ffmpeg on PATH: brew install ffmpeg). Roku's roAudioResource (sound
// effects) plays WAV only and roAudioPlayer (music) can't play OGG, so effects become small mono WAVs
// and music becomes MP3.
//
//   npm run audio -- sfx <in...> <out.wav>         mono 16-bit 22.05 kHz, trimmed, peak -1 dB; several inputs are mixed
//   npm run audio -- music <in> <out.mp3> [--start s] [--end s] [--bitrate 96k]
//   npm run audio -- silences <file> [--noise -35dB] [--min 0.25]   quiet gaps, e.g. to find a loop point
//   npm run audio -- info <files...>                codec, channels, sample rate, duration, size
//
// The same functions are exported for per-example build scripts (see examples/rpg/scripts/build-audio.js).

const fs = require('fs');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

const TRIM_SILENCE = 'silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse';

function ffmpeg(args) {
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });
}

function requireFfmpeg() {
  const res = spawnSync('ffmpeg', ['-version'], { stdio: 'ignore' });
  if (res.error || res.status !== 0) {
    throw new Error('ffmpeg not found - install it (brew install ffmpeg).');
  }
}

// ffmpeg's analysis filters report on stderr.
function analyse(file, filter) {
  return spawnSync('ffmpeg', ['-hide_banner', '-i', file, '-af', filter, '-f', 'null', '-'], { encoding: 'utf8' }).stderr;
}

function inputArgs(inputs, start, end) {
  const args = [];
  for (const file of inputs) {
    if (!fs.existsSync(file)) {
      throw new Error(`Missing source: ${file}`);
    }
    if (start !== undefined) args.push('-ss', String(start));
    if (end !== undefined) args.push('-to', String(end));
    args.push('-i', file);
  }
  return args;
}

function mixFilter(count) {
  return count > 1 ? `amix=inputs=${count}:normalize=0` : '';
}

// @return {number} the peak level in dB, e.g. -3.2
function measurePeak(file) {
  const match = /max_volume: (-?[\d.]+) dB/.exec(analyse(file, 'volumedetect'));
  if (!match) throw new Error(`No peak found for ${file}`);
  return parseFloat(match[1]);
}

// Builds a Roku sound effect: mono 16-bit 22.05 kHz WAV, silence trimmed from both ends, peak at -1 dB.
// @param {string[]} inputs - one file, or several to mix together
// @return {number} the output's size in bytes
function buildSfx(inputs, out, { start, end } = {}) {
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const tmp = out + '.tmp.wav';
  const filter = [mixFilter(inputs.length), TRIM_SILENCE].filter(Boolean).join(',');
  ffmpeg([...inputArgs(inputs, start, end), '-filter_complex', filter, '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', tmp]);
  const gain = -1 - measurePeak(tmp);
  ffmpeg(['-i', tmp, '-af', `volume=${gain.toFixed(2)}dB`, '-c:a', 'pcm_s16le', out]);
  fs.unlinkSync(tmp);
  return fs.statSync(out).size;
}

// Builds a Roku music track: stereo 44.1 kHz MP3.
// @param {string[]} inputs - one file, or several to mix together
// @return {number} the output's size in bytes
function buildMusic(inputs, out, { start, end, bitrate = '96k' } = {}) {
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const mix = mixFilter(inputs.length);
  const filter = mix ? ['-filter_complex', mix] : [];
  ffmpeg([...inputArgs(inputs, start, end), ...filter, '-ac', '2', '-ar', '44100', '-c:a', 'libmp3lame', '-b:a', bitrate, out]);
  return fs.statSync(out).size;
}

// @return {{start: number, end: number, duration: number}[]} quiet gaps in seconds
function findSilences(file, { noise = '-35dB', min = 0.25 } = {}) {
  const log = analyse(file, `silencedetect=noise=${noise}:d=${min}`);
  const gaps = [];
  let start;
  for (const line of log.split('\n')) {
    const s = /silence_start: (-?[\d.]+)/.exec(line);
    const e = /silence_end: ([\d.]+) \| silence_duration: ([\d.]+)/.exec(line);
    if (s) start = parseFloat(s[1]);
    if (e) gaps.push({ start: Math.max(0, start), end: parseFloat(e[1]), duration: parseFloat(e[2]) });
  }
  return gaps;
}

// @return {{codec: string, channels: number, sampleRate: number, duration: number, bytes: number}}
function probe(file) {
  const out = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'stream=codec_name,channels,sample_rate:format=duration', '-of', 'json', file], { encoding: 'utf8' });
  const json = JSON.parse(out);
  const stream = json.streams[0];
  return {
    codec: stream.codec_name,
    channels: stream.channels,
    sampleRate: parseInt(stream.sample_rate, 10),
    duration: parseFloat(json.format.duration),
    bytes: fs.statSync(file).size,
  };
}

function kb(bytes) {
  return `${(bytes / 1024).toFixed(1)} KB`;
}

// Splits CLI args into positionals and --name value options.
function parseArgs(argv) {
  const positional = [];
  const options = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      options[argv[i].slice(2)] = argv[++i];
    } else {
      positional.push(argv[i]);
    }
  }
  return { positional, options };
}

function main() {
  const [command, ...rest] = process.argv.slice(2);
  const { positional, options } = parseArgs(rest);
  const number = (value) => (value === undefined ? undefined : parseFloat(value));
  requireFfmpeg();
  if (command === 'sfx' && positional.length >= 2) {
    const out = positional.pop();
    console.log(`${out} ${kb(buildSfx(positional, out, { start: number(options.start), end: number(options.end) }))}`);
  } else if (command === 'music' && positional.length >= 2) {
    const out = positional.pop();
    console.log(`${out} ${kb(buildMusic(positional, out, { start: number(options.start), end: number(options.end), bitrate: options.bitrate }))}`);
  } else if (command === 'silences' && positional.length === 1) {
    const gaps = findSilences(positional[0], { noise: options.noise, min: number(options.min) });
    for (const gap of gaps) {
      console.log(`${gap.start.toFixed(2)}s - ${gap.end.toFixed(2)}s (${gap.duration.toFixed(2)}s)`);
    }
    if (gaps.length === 0) console.log('No silences found.');
  } else if (command === 'info' && positional.length >= 1) {
    for (const file of positional) {
      const info = probe(file);
      console.log(`${file}: ${info.codec}, ${info.channels === 1 ? 'mono' : `${info.channels} ch`}, ${info.sampleRate} Hz, ${info.duration.toFixed(2)}s, ${kb(info.bytes)}`);
    }
  } else {
    console.error('Usage: npm run audio -- sfx <in...> <out.wav> | music <in> <out.mp3> [--start s] [--end s] [--bitrate 96k] | silences <file> [--noise -35dB] [--min 0.25] | info <files...>');
    process.exit(1);
  }
}

if (require.main === module) {
  try {
    main();
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}

module.exports = { requireFfmpeg, buildSfx, buildMusic, findSilences, measurePeak, probe };
