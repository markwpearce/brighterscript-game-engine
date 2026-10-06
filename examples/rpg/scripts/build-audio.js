#!/usr/bin/env node
// Builds examples/rpg's sound effects and music from downloaded sources, using the repo's Roku
// audio tools (scripts/audio.js, needs ffmpeg). The sources stay outside the repo; see
// src/sounds/CREDITS.md and src/music/CREDITS.md.
//
//   node examples/rpg/scripts/build-audio.js <sourceDir>
//
// <sourceDir> holds "RPG Sound Pack/", "5Hit_Sounds/" and "music/" as downloaded.

const path = require('path');
const { requireFfmpeg, buildSfx, buildMusic } = require('../../../scripts/audio');

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
  // Boss Fight is two pieces separated by silence at 84.99-86.82s (npm run audio -- silences):
  // the fight loops, the ending plays once.
  { out: 'music/boss_loop.mp3', from: ['music/bosstheme_WO_low.mp3'], end: 84.99 },
  { out: 'music/boss_end.mp3', from: ['music/bosstheme_WO_low.mp3'], start: 86.82 },
  { out: 'music/credits.mp3', from: ['music/victory.mp3'] },
];

function main() {
  const sourceDir = process.argv[2];
  if (!sourceDir) {
    console.error('Usage: node build-audio.js <sourceDir>');
    process.exit(1);
  }
  requireFfmpeg();
  let total = 0;
  for (const item of OUTPUTS) {
    const inputs = item.from.map((src) => path.join(sourceDir, src));
    const out = path.join(ROOT, item.out);
    const build = item.out.endsWith('.wav') ? buildSfx : buildMusic;
    const size = build(inputs, out, { start: item.start, end: item.end });
    total += size;
    console.log(`${item.out.padEnd(24)} ${(size / 1024).toFixed(1)} KB`);
  }
  console.log(`${'total'.padEnd(24)} ${(total / 1024).toFixed(1)} KB`);
}

try {
  main();
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
