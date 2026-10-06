# examples/rpg — Slice E: Music and sound (design)

Issue: #290. Follows Slice D2 (`specs/2026-10-05-rpg-slice-d2-throne-room-design.md`, #296). This is the last RPG slice.

The RPG has no music, and three of its seven sound effects have no licence on file. Slice E adds a music track per area and replaces the placeholder sounds. It also adds the missing ones: dialogue, shop, potion, doors and gates, saving, goblins and the witch. Every asset is CC0 or CC-BY(-SA) and credited in-game.

## Constraints

- **No music volume.** Roku's `roAudioPlayer` (behind `Game.musicPlay()`) has no volume control, so a real fade or crossfade isn't possible. A track change is a hard cut, placed under `changeSceneWithFade()`'s screen fade. A real crossfade would need a SceneGraph `Audio` node. That is out of scope here, and no issue is filed for it.
- **Sound effects must be WAV.** `roAudioResource` (behind `Game.playSound()`) plays WAV only. brs-engine also hard-codes `format: "wav"` for sound effects. MP3 is used for music only.
- **Music can't be OGG.** `roAudioPlayer` doesn't play it.
- **Keep the package small.**
  - Sound effects: mono, 16-bit PCM, 22.05 kHz, silence trimmed, about 44 KB per second.
  - Music: 96 kbps stereo MP3, about 0.7 MB per minute.

## Engine: track-aware music

`Game.musicPlay(path, loop = false, restart = true)` gains a `restart` parameter. With the default (`true`) it behaves exactly as before, so existing callers don't change. With `restart = false`, it returns `true` and does nothing if `path` is already the current track.

- `Game` keeps the current track's path in a private field. A successful `musicPlay()` sets it, and `musicStop()` clears it. So does the player's end-of-track event for a non-looping track (`roAudioPlayerEvent.isFullResult()`, handled where `Play()` already reads `musicPort`). Without that, a finished one-shot track would still count as "playing".
- `getMusicPath() as string` returns the current track, or `""` when nothing is playing.
- `musicPause()` and `musicResume()` don't change the path.
- Spec: `Game.spec.bs` (or a new `GameMusic.spec.bs`, one suite per file) covers this bookkeeping:
  - setting and clearing the path
  - `restart = false` with the same path
  - `restart = false` with a different path
  - a missing file leaves the path unchanged

  The audio itself can't be checked headlessly.
- The `examples/audio` demo and the `musicPlay` doc comment mention the new parameter.

## Music

| Scene | Track | Author | Licence | Source |
|---|---|---|---|---|
| `TitleScene` | RPG Music (`Main Menu.mp3`) | João Vitor Lisboa | CC-BY-SA 3.0 | https://opengameart.org/content/rpg-music-2 |
| `TownScene` | RPG Market Theme (`1. The Market.wav`) | João Vitor Lisboa | CC-BY 4.0 (CC-BY-SA 4.0 is also offered) | https://opengameart.org/content/rpg-market-theme |
| `SewerScene` | Horror music (`Overture.mp3`) | João Vitor Lisboa | CC0 | https://opengameart.org/content/horror-music |
| `CastleScene`, Guardroom, Storeroom, Barracks, Antechamber, KingsHall | Stealth in the Woods (`Stealth in the Woods.mp3`) | João Vitor Lisboa | CC0 | https://opengameart.org/content/stealth-music |
| `ThroneRoomScene` | Boss Fight (`bosstheme_WO_low.mp3`), cut into a loop and an ending | João Vitor Lisboa | CC0 | https://opengameart.org/content/boss-fight-0 |
| `CreditsScene` | Medieval: Victory Theme (`victory.mp3`) | RandomMind | CC0 | https://opengameart.org/content/medieval-victory-theme |

Output files go in `examples/rpg/src/music/`: `title.mp3`, `town.mp3`, `sewer.mp3`, `castle.mp3`, `boss_loop.mp3`, `boss_end.mp3`, `credits.mp3`.

Behaviour:
- Each scene starts its track in `onCreate` with `musicPlay(track, true, false)`. The scene classes get a `musicTrack` field that `AreaScene` (and `TitleScene`/`CreditsScene`) play. All six keep rooms name `castle.mp3`, so walking between them keeps the track going. Defeat-respawn into the keep also keeps the track.
- A deep link starts the scene's own track like any other scene change.
- The witch's `onDying()` calls `musicPlay(boss_end, false)`, which plays the ending once and then goes quiet. A later scene change starts that scene's track. The witch can die only once per save, so the ending never replays.
- Pausing (dialogue, shop, inventory) leaves the music playing.
- `GoblinShowcaseScene` (a deep-link-only test scene) plays no music.

### The boss loop

Boss Fight is "two songs in one": a fight section, then an ending meant for the boss's death.
- `boss_loop.mp3` is the fight section, trimmed to a bar boundary so it loops cleanly.
- `boss_end.mp3` is the rest, from the cut point to the end.

The cut point is found by ear and recorded in the build script. It's confirmed on a Roku, since MP3 looping can leave a short gap: the encoder adds padding at the start and end. If the gap is noticeable, the loop is encoded from the trimmed source as WAV-to-MP3 with `-write_xing 1`. If that's not enough, that track stays a WAV (fallback; size noted in the PR).

## Sound effects

Sources:
- artisticdude, "RPG Sound Pack", CC0, WAV (https://opengameart.org/content/rpg-sound-pack)
- TinyWorlds, "5 Hit Sounds + Dying", CC0 (https://opengameart.org/content/5-hit-sounds-dying), for the player's death

| Name (`loadSound`) | File | Source | Plays when |
|---|---|---|---|
| `sword` | `sword.wav` | `battle/swing*` | sword swing (replaces placeholder) |
| `enemyHit` | `enemy_hit.wav` | `battle/sword-unsheathe*` | sword hits an enemy, pot or switch (replaces placeholder) |
| `enemyDie` | `enemy_die.wav` | `NPC/gutteral beast/mnstr*` | an enemy dies (replaces placeholder) |
| `ratBite` | `rat_bite.wav` | `NPC/beetle/bite-small*` | a rat touches the player |
| `goblinHurt` / `goblinDie` | `goblin_hurt.wav`, `goblin_die.wav` | `NPC/ogre/ogre*` | goblins and the Goblin King, used instead of `enemyHit`/`enemyDie` |
| `kingRoar` | `king_roar.wav` | `NPC/giant/giant*` | the Goblin King starts a charge |
| `witchCast` | `witch_cast.wav` | `battle/magic1` or `battle/spell` | the witch fires a volley or summons |
| `witchHurt` | `witch_hurt.wav` | `NPC/shade/shade*` | the witch is hit or dies |
| `coin` | `coin.wav` | `inventory/coin` | coin pickup (replaces placeholder) |
| `purchase` | `purchase.wav` | `inventory/coin2` or `coin3` | a shop purchase succeeds |
| `refuse` | `refuse.wav` | `interface/interface*` | a purchase is refused |
| `dialogue` | `dialogue.wav` | `interface/interface*` | a dialogue page turns |
| `save` | `save.wav` | `interface/interface*` | the save indicator shows |
| `potion` | `potion.wav` | `inventory/bottle` + `inventory/bubble`, layered | a potion is drunk |
| `door` | `door.wav` | `world/door` | the player goes through a `Door` |
| `gate` | `gate.wav` | `inventory/metal-ringing` + `inventory/chainmail1`, layered | a `Gate` opens |
| `die` | `die.wav` | TinyWorlds dying sound | player defeated (replaces placeholder) |
| `pain` | `pain.wav` | unchanged (repo owner's own) | player hurt |
| `lowHealth` | `low_health.wav` | unchanged (Damaged Panda, CC-BY 3.0) | low-health warning |

The exact source file for each row (the `*` choices) is picked when building and listened to on a device. Swapping one is a one-line change in the build script's table. Every effect is loaded in `main.bs` as now, and played at a per-sound volume set in one place: a small `SOUND_VOLUMES` table read by an example-local `playSfx(game, name)` helper. That lets the effects be balanced against the music without touching each call site.

## Build script: `examples/rpg/scripts/build-audio.js`

This is plain Node, like `build-castle-walls.js`. It shells out to `ffmpeg`, which is a dev-machine requirement (`brew install ffmpeg`), not a CI one. The built files are committed, and CI never runs the script.

- Usage: `node scripts/build-audio.js <sourceDir>`. `<sourceDir>` holds the unzipped downloads: the RPG Sound Pack folder, the TinyWorlds files, and the music files. The originals never enter the repo.
- A table at the top lists every output file:
  - its source path(s), relative to `<sourceDir>`
  - optional `start`/`end` trims (the boss loop cut lives here)
  - optional layering of several sources, via `amix`
  - a kind, `sfx` or `music`, which picks the encoding settings
- `sfx` files: downmixed to mono, `pcm_s16le`, 22.05 kHz, with leading and trailing silence removed (`silenceremove`) and normalised peaks.
- `music` files: 96 kbps stereo MP3 (`libmp3lame`).
- The script fails clearly if `ffmpeg` is missing or a source file isn't found. It prints each output's size and the total.

## Credits

- `Story/CreditsData.bs` (the in-game credits roll) lists:
  - every music track, as "Music: <title> by João Vitor Lisboa" (or RandomMind), plus its licence
  - the RPG Sound Pack (artisticdude, CC0)
  - TinyWorlds (CC0)
  - Damaged Panda (CC-BY 3.0)
  - the repo owner's `pain.wav`
- `src/sounds/CREDITS.md` is rewritten to match, with no unlicensed entries left. A new `src/music/CREDITS.md` gives each track's URL and licence, noting that RPG Music is CC-BY-SA 3.0.

## Docs

- The CLAUDE.md `examples/rpg` bullet gains a sentence on music (one track per area, `musicPlay(..., restart = false)`, boss ending), the `playSfx` volume table and `build-audio.js`.
- The CLAUDE.md engine notes mention `restart` and `getMusicPath()` where `Game` audio is covered.
- The `rokubot-examples` skill notes that audio can't be checked through rokubot, so the user listens.

## Testing

- `npm run check` (lint, validate, headless tests, including the new music bookkeeping spec) and `cd examples/rpg && npm test`.
- Smoke check through rokubot: sideload, then launch the title, the town, the sewer, a castle room and the throne room via deep links. The point is to catch a crash from a missing file. Rokubot can't hear anything.
- On a real Roku, the user listens for:
  - each scene's track, with no restart when moving between castle rooms
  - the boss loop's seam, and the ending on the witch's death
  - the credits track
  - each new sound effect, and how loud the effects are against the music

## Out of scope

- Music volume, fades and crossfades, which `roAudioPlayer` can't do.
- Gamepad work (#292) and promoting the story layer (#298).
- Audio for the other examples.
