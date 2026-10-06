#!/usr/bin/env node
// Builds examples/rpg's sound effects (mono 16-bit 22.05 kHz WAV, which roAudioResource needs) and
// music (96 kbps MP3; roAudioPlayer can't play OGG) from downloaded sources with ffmpeg.
// The sources stay outside the repo; see src/sounds/CREDITS.md and src/music/CREDITS.md.
//
//   node examples/rpg/scripts/build-audio.js <sourceDir>
//
// <sourceDir> holds "RPG Sound Pack/", "5Hit_Sounds/" and "music/" as downloaded.

const fs = require('fs');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..', 'src');
const PACK = 'RPG Sound Pack';

// from: one source, or several mixed together. start/end trim (seconds) before anything else.
const OUTPUTS = [
  { out: 'sounds/sword.wav', from: [`${PACK}/battle/swing.wav`] },
  { out: 'sounds/enemy_hit.wav', from: [`${PACK}/battle/sword-unsheathe2.wav`] },
  { out: 'sounds/enemy_die.wav', from: [`${PACK}/NPC/gutteral beast/mnstr7.wav`] },
  { out: 'sounds/rat_bite.wav', from: [`${PACK}/NPC/beetle/bite-small.wav`] },
  { out: 'sounds/goblin_hurt.wav', from: [`${PACK}/NPC/ogre/ogre2.wav`] },
  { out: 'sounds/goblin_die.wav', from: [`${PACK}/NPC/ogre/ogre5.wav`] },
  { out: 'sounds/king_roar.wav', from: [`${PACK}/NPC/giant/giant3.wav`] },
  { out: 'sounds/witch_cast.wav', from: [`${PACK}/battle/magic1.wav`] },
  { out: 'sounds/witch_hurt.wav', from: [`${PACK}/NPC/shade/shade5.wav`] },
  { out: 'sounds/coin.wav', from: [`${PACK}/inventory/coin.wav`] },
  { out: 'sounds/purchase.wav', from: [`${PACK}/inventory/coin2.wav`] },
  { out: 'sounds/refuse.wav', from: [`${PACK}/interface/interface6.wav`] },
  { out: 'sounds/dialogue.wav', from: [`${PACK}/interface/interface1.wav`] },
  { out: 'sounds/save.wav', from: [`${PACK}/interface/interface3.wav`] },
  { out: 'sounds/potion.wav', from: [`${PACK}/inventory/bottle.wav`, `${PACK}/inventory/bubble.wav`] },
  { out: 'sounds/door.wav', from: [`${PACK}/world/door.wav`] },
  { out: 'sounds/gate.wav', from: [`${PACK}/inventory/metal-ringing.wav`, `${PACK}/inventory/chainmail1.wav`] },
  { out: 'sounds/die.wav', from: ['5Hit_Sounds/mp3/die1.mp3'] },
  { out: 'music/title.mp3', from: ['music/Main Menu.mp3'] },
  { out: 'music/town.mp3', from: ['music/1. The Market.wav'] },
  { out: 'music/sewer.mp3', from: ['music/Overture.mp3'] },
  { out: 'music/castle.mp3', from: ['music/Stealth in the Woods.mp3'] },
  // Boss Fight is two pieces separated by silence at 84.99-86.82s: the fight loops, the ending plays once.
  { out: 'music/boss_loop.mp3', from: ['music/bosstheme_WO_low.mp3'], end: 84.99 },
  { out: 'music/boss_end.mp3', from: ['music/bosstheme_WO_low.mp3'], start: 86.82 },
  { out: 'music/credits.mp3', from: ['music/victory.mp3'] },
];

const SFX_FILTER = 'silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse';

function ffmpeg(args) {
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });
}

// Peak in dB (e.g. -3.2), so effects can be normalised to -1 dB in a second pass.
// volumedetect reports on stderr.
function measurePeak(file) {
  const res = spawnSync('ffmpeg', ['-hide_banner', '-i', file, '-af', 'volumedetect', '-f', 'null', '-'], { encoding: 'utf8' });
  const match = /max_volume: (-?[\d.]+) dB/.exec(res.stderr);
  if (!match) throw new Error(`No peak found for ${file}`);
  return parseFloat(match[1]);
}

function build(sourceDir, item) {
  const inputs = [];
  for (const src of item.from) {
    const full = path.join(sourceDir, src);
    if (!fs.existsSync(full)) {
      throw new Error(`Missing source: ${full}`);
    }
    if (item.start !== undefined) inputs.push('-ss', String(item.start));
    if (item.end !== undefined) inputs.push('-to', String(item.end));
    inputs.push('-i', full);
  }
  const out = path.join(ROOT, item.out);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const mix = item.from.length > 1 ? `amix=inputs=${item.from.length}:normalize=0,` : '';
  if (item.out.endsWith('.wav')) {
    const tmp = out + '.tmp.wav';
    ffmpeg([...inputs, '-filter_complex', mix + SFX_FILTER, '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', tmp]);
    const gain = -1 - measurePeak(tmp);
    ffmpeg(['-i', tmp, '-af', `volume=${gain.toFixed(2)}dB`, '-c:a', 'pcm_s16le', out]);
    fs.unlinkSync(tmp);
  } else {
    const filter = mix ? ['-filter_complex', mix.slice(0, -1)] : [];
    ffmpeg([...inputs, ...filter, '-ac', '2', '-ar', '44100', '-c:a', 'libmp3lame', '-b:a', '96k', out]);
  }
  return fs.statSync(out).size;
}

function main() {
  const sourceDir = process.argv[2];
  if (!sourceDir) {
    console.error('Usage: node build-audio.js <sourceDir>');
    process.exit(1);
  }
  try {
    execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
  } catch (e) {
    console.error('ffmpeg not found - install it (brew install ffmpeg).');
    process.exit(1);
  }
  let total = 0;
  for (const item of OUTPUTS) {
    const size = build(sourceDir, item);
    total += size;
    console.log(`${item.out.padEnd(24)} ${(size / 1024).toFixed(1)} KB`);
  }
  console.log(`${'total'.padEnd(24)} ${(total / 1024).toFixed(1)} KB`);
}

main();
