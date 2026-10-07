# examples/rpg Slice E: Music and Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `examples/rpg` a music track per area and a full set of licensed, small sound effects, with a track-aware `Game.musicPlay()` in the engine.

**Architecture:**
- **Engine:** `Game` remembers the current music path. `musicPlay(path, loop, restart = false)` skips a track that's already playing.
- **Assets:** a Node script turns downloaded sources into committed assets with ffmpeg: mono 16-bit 22.05 kHz WAV effects and 96 kbps MP3 music.
- **Example:** two pure, unit-tested tables, `musicTrackFor(sceneName)` and `soundVolume(name)`, drive the scenes and a `playSfx(game, name)` helper.

**Tech Stack:** BrighterScript, Rooibos v6, Node (`child_process` + ffmpeg 7.x at `/opt/homebrew/bin/ffmpeg`), Roku `roAudioPlayer` / `roAudioResource`.

**Spec:** `specs/2026-10-06-rpg-slice-e-audio-design.md`

## Global Constraints

- Sound effects: WAV only (`roAudioResource`), mono, `pcm_s16le`, 22.05 kHz, leading and trailing silence trimmed.
- Music: MP3 only (`roAudioPlayer`, no OGG), 96 kbps stereo (`libmp3lame -b:a 96k`).
- Source downloads live in `/Users/mpearce/Downloads/rpg/` and never enter the repo:
  - `RPG Sound Pack/` (artisticdude, CC0)
  - `5Hit_Sounds/mp3/die1.mp3` (TinyWorlds, CC0)
  - `music/`:
    - `Main Menu.mp3`
    - `1. The Market.wav`
    - `Overture.mp3`
    - `Stealth in the Woods.mp3`
    - `bosstheme_WO_low.mp3`
    - `victory.mp3`
- Boss Fight split: a silence runs from 84.99 s to 86.82 s.
  - `boss_loop.mp3` = 0 to 84.99 s
  - `boss_end.mp3` = 86.82 s to the end
- The default `restart = true` keeps `musicPlay()`'s existing behaviour for every other example.
- Every non-CC0 asset is credited in-game (`Story/CreditsData.bs`) and in a `CREDITS.md`, with "João Vitor Lisboa" named for all six of his tracks.
- Branch: `feature/issue-290-rpg-slice-e-audio` (already created; the spec is committed). Never push to `main`.
- Every new or changed `.bs` file `import`s the files whose symbols it uses (CLAUDE.md conventions).
- Code comments stay terse (1–3 lines, the "why" only).

## Review Focus

1. **A finished one-shot track still counts as playing.**
   - Failure: a `restart = false` call for a track that has already ended would be skipped, leaving silence.
   - Expected: the path is cleared on the end-of-track event (and on a failed play). Task 1 unit-tests `onMusicEvent()` with a fake event.
2. **A missing music file.**
   - Expected: `musicPlay` logs, returns `false` and leaves the remembered path unchanged, so a later call with the right file still plays. Task 1 test.
3. **A deep link straight into a castle room, or the throne room, plays that room's track,** not silence. Task 3's `musicTrackFor` tests cover every scene name.
4. **Every loaded sound name has a volume and a file,** so a typo in `playSfx("gaet")` is caught. Task 4 test: `getSoundFiles()` and `soundVolume()` agree, and `soundVolume()` of an unknown name returns 0, so a typo is silent rather than a crash; `playSfx` logs it.
5. **The credits list every shipped audio file.** Task 5 extends `tests/Credits.spec.bs` to check the music and sound-pack credits.

---

## File structure

| File | Responsibility |
|---|---|
| `src/source/engine/Game.bs` (modify) | `musicPath`/`musicLoops` state, `musicPlay(..., restart)`, `getMusicPath()`, `onMusicEvent()` |
| `src/source/engine/GameMusic.spec.bs` (create) | music bookkeeping suite (one `@suite` per file) |
| `examples/rpg/scripts/build-audio.js` (create) | ffmpeg conversion table, writes `src/sounds/*.wav` and `src/music/*.mp3` |
| `examples/rpg/src/music/*.mp3` + `CREDITS.md` (create) | built music + licences |
| `examples/rpg/src/sounds/*.wav` + `CREDITS.md` (rewrite) | built effects + licences |
| `examples/rpg/src/source/Audio/MusicTracks.bs` (create) | pure `musicTrackFor(sceneName) as string` + track path consts |
| `examples/rpg/src/source/Audio/SoundEffects.bs` (create) | pure `getSoundFiles()`, `soundVolume(name)` |
| `examples/rpg/src/source/Audio/PlayAudio.bs` (create) | `playSfx(game, name)`, `playSceneMusic(game, sceneName)`, `loadSoundEffects(game)` (engine-dependent, untested) |
| `examples/rpg/tests/Audio.spec.bs` (create) | tests for the two pure files |
| scenes, entities, UI (modify) | call `playSceneMusic` / `playSfx` |

---

### Task 1: Engine, track-aware music

**Files:**
- Modify: `src/source/engine/Game.bs` (private fields near line 117, `Play()` near line 413, `musicPlay`/`musicStop` near line 2546)
- Create: `src/source/engine/GameMusic.spec.bs`

**Interfaces:**
- Produces:
  - `Game.musicPlay(path as string, loop = false as boolean, restart = true as boolean) as boolean`
  - `Game.getMusicPath() as string`
  - `Game.onMusicEvent(msg as object)`, public so it can be tested. Its doc comment says the engine calls it, and games don't.

- [ ] **Step 1: Write the failing spec** `src/source/engine/GameMusic.spec.bs`:

```brighterscript
namespace tests

  ' Music bookkeeping only - real playback can't be heard headlessly. pkg:/manifest stands in
  ' for a music file because musicPlay() only checks that the path exists.
  @suite("BGE.Game music")
  class GameMusicTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @describe("musicPlay / getMusicPath")

    @it("is empty before any music plays")
    function _()
      m.assertEqual("", m.game.getMusicPath())
    end function

    @it("remembers the path it started")
    function _()
      m.assertTrue(m.game.musicPlay("pkg:/manifest", true))
      m.assertEqual("pkg:/manifest", m.game.getMusicPath())
    end function

    @it("leaves the path alone when the file is missing")
    function _()
      m.game.musicPlay("pkg:/manifest", true)
      m.assertFalse(m.game.musicPlay("pkg:/no/such.mp3", true))
      m.assertEqual("pkg:/manifest", m.game.getMusicPath())
    end function

    @it("returns true without restarting when restart is false and the track is current")
    function _()
      m.game.musicPlay("pkg:/manifest", true)
      m.assertTrue(m.game.musicPlay("pkg:/manifest", true, false))
      m.assertEqual("pkg:/manifest", m.game.getMusicPath())
    end function

    @it("still fails for a missing file when restart is false")
    function _()
      m.assertFalse(m.game.musicPlay("pkg:/no/such.mp3", true, false))
      m.assertEqual("", m.game.getMusicPath())
    end function

    @it("musicStop clears the path")
    function _()
      m.game.musicPlay("pkg:/manifest", true)
      m.game.musicStop()
      m.assertEqual("", m.game.getMusicPath())
    end function

    @describe("onMusicEvent")

    @it("clears the path when a one-shot track finishes")
    function _()
      m.game.musicPlay("pkg:/manifest", false)
      m.game.onMusicEvent({isFullResult: function() as boolean
          return true
        end function, isRequestFailed: function() as boolean
          return false
        end function})
      m.assertEqual("", m.game.getMusicPath())
    end function

    @it("clears the path when playback fails")
    function _()
      m.game.musicPlay("pkg:/manifest", true)
      m.game.onMusicEvent({isFullResult: function() as boolean
          return false
        end function, isRequestFailed: function() as boolean
          return true
        end function})
      m.assertEqual("", m.game.getMusicPath())
    end function

    @it("keeps the path for any other event")
    function _()
      m.game.musicPlay("pkg:/manifest", true)
      m.game.onMusicEvent({isFullResult: function() as boolean
          return false
        end function, isRequestFailed: function() as boolean
          return false
        end function})
      m.assertEqual("pkg:/manifest", m.game.getMusicPath())
    end function

  end class
end namespace
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `npm run validate`
Expected: validation errors, because `getMusicPath`/`onMusicEvent` don't exist and `musicPlay` takes too many arguments.

- [ ] **Step 3: Implement it in `Game.bs`**

Add after `private musicPort ...` (line ~118):

```brighterscript
    private musicPath as string = ""
```

In `Play()`, directly after `musicMsg = m.musicPort.GetMessage() as roAudioPlayerEvent`:

```brighterscript
        if "roAudioPlayerEvent" = type(musicMsg)
          m.onMusicEvent(musicMsg)
        end if
```

Replace `musicPlay` and `musicStop` and add the two new methods:

```brighterscript
    ' Plays an audio file at the given path
    ' This is designed for music, where only one file can play at a time.
    '
    ' @param {string} path - the path of the music file
    ' @param {boolean} [loop=false]
    ' @param {boolean} [restart=true] - false leaves the music alone if this path is already playing, so scenes sharing a track don't restart it
    ' @return {boolean} - true if started (or already playing, when restart is false)
    function musicPlay(path as string, loop = false as boolean, restart = true as boolean) as boolean
      if not restart and path <> "" and path = m.musicPath
        return true
      end if
      if m.filesystem.Exists(path)
        m.audioPlayer.stop()
        m.audioPlayer.ClearContent()
        song = {}
        song.url = path
        m.audioPlayer.AddContent(song)
        m.audioPlayer.SetLoop(loop)
        m.audioPlayer.play()
        m.musicPath = path
        return true
      else
        m.log("Game.musicPlay() - No file exists at path: " + path, BGE.Debug.LogLevel.error)
        return false
      end if
    end function

    ' The path of the music playing now, or "" when none is
    '
    ' @return {string}
    function getMusicPath() as string
      return m.musicPath
    end function

    ' Called by the game loop with each music player event; games don't need to call it
    '
    ' @param {object} msg - an roAudioPlayerEvent
    sub onMusicEvent(msg as object)
      if msg.isFullResult() or msg.isRequestFailed()
        m.musicPath = ""
      end if
    end sub

    ' Stops the currently playing music file
    '
    ' @return {void}
    sub musicStop()
      m.audioPlayer.stop()
      m.musicPath = ""
    end sub
```

A looping track never sends `isFullResult`, so it keeps its path. The `path <> ""` guard stops `musicPlay("", ..., false)` from returning `true` when nothing is playing.

- [ ] **Step 4: Run the checks and confirm they pass**

Run: `npm run check`
Expected: lint clean, validate clean, `[Rooibos Result]: PASS`, with the 9 new tests passing.

If `brs-cli` can't `AddContent`/`play` headlessly, the "remembers the path" tests fail with a runtime error. In that case, read the failure. Don't stub around it; report it as a blocker.

- [ ] **Step 5: Mention `restart` in the audio demo comment**

In `examples/audio/src/source/Scenes/MainScene.bs` line 3, change the Music line to read `Music - Game.musicPlay(path, loop, restart)/musicPause()/musicResume()/musicStop()/getMusicPath() (roAudioPlayer)`, keeping the rest of the line.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/GameMusic.spec.bs examples/audio/src/source/Scenes/MainScene.bs
git commit -m "engine: track-aware musicPlay (restart flag, getMusicPath) (#290)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `build-audio.js` and the built assets

**Files:**
- Create: `examples/rpg/scripts/build-audio.js`
- Create: `examples/rpg/src/music/{title,town,sewer,castle,boss_loop,boss_end,credits}.mp3`, `examples/rpg/src/music/CREDITS.md`
- Rewrite: `examples/rpg/src/sounds/*.wav` (all but `pain.wav` and `low_health.wav`), `examples/rpg/src/sounds/CREDITS.md`

**Interfaces:**
- Produces these files, which Task 4's `getSoundFiles()` must list exactly:
  - `sword` `enemy_hit` `enemy_die` `rat_bite` `goblin_hurt` `goblin_die` `king_roar` `witch_cast` `witch_hurt` `coin` `purchase` `refuse` `dialogue` `save` `potion` `door` `gate` `die`, each with `.wav`
  - plus the existing `pain.wav` and `low_health.wav`
- Task 3's track constants: `pkg:/music/<name>.mp3`.

- [ ] **Step 1: Write the script**

```js
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
  { out: 'sounds/sword.wav', from: [`${PACK}/battle/swing2.wav`] },
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
    ffmpeg([...inputs, '-af', mix + SFX_FILTER, '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', tmp]);
    const gain = -1 - measurePeak(tmp);
    ffmpeg(['-i', tmp, '-af', `volume=${gain.toFixed(2)}dB`, '-c:a', 'pcm_s16le', out]);
    fs.unlinkSync(tmp);
  } else {
    const filter = mix ? ['-af', mix.slice(0, -1)] : [];
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
```

- [ ] **Step 2: Run it**

Run: `node examples/rpg/scripts/build-audio.js /Users/mpearce/Downloads/rpg`
Expected: 25 lines plus a total.
- Each effect under about 60 KB. `die.wav` may be larger; if any effect is over 100 KB, add an `end:` trim to its row and rerun.
- Music roughly 0.4–1.8 MB per track.
- Total under 8 MB.

- [ ] **Step 3: Verify the formats**

Run: `cd examples/rpg/src && for f in sounds/*.wav music/*.mp3; do echo "$f $(ffprobe -v error -show_entries stream=codec_name,channels,sample_rate -of csv=p=0 "$f")"; done`
Expected:
- every new `sounds/*.wav` reads `pcm_s16le,22050,1`. `pain.wav` and `low_health.wav` stay 44100 and are unchanged.
- every `music/*.mp3` reads `mp3,44100,2`.

- [ ] **Step 4: Write `examples/rpg/src/music/CREDITS.md`**

```markdown
# Music credits

Built from the originals by `scripts/build-audio.js` (re-encoded as 96 kbps MP3; the boss track is split in two).

| File | Track | Author | Licence | Source |
|---|---|---|---|---|
| `title.mp3` | RPG Music | João Vitor Lisboa | [CC-BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) | https://opengameart.org/content/rpg-music-2 |
| `town.mp3` | RPG Market Theme | João Vitor Lisboa | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/rpg-market-theme |
| `sewer.mp3` | Horror music | João Vitor Lisboa | CC0 | https://opengameart.org/content/horror-music |
| `castle.mp3` | Stealth in the Woods | João Vitor Lisboa | CC0 | https://opengameart.org/content/stealth-music |
| `boss_loop.mp3`, `boss_end.mp3` | Boss Fight (split at its mid-track silence) | João Vitor Lisboa | CC0 | https://opengameart.org/content/boss-fight-0 |
| `credits.mp3` | Medieval: Victory Theme | RandomMind | CC0 | https://opengameart.org/content/medieval-victory-theme |
```

- [ ] **Step 5: Rewrite `examples/rpg/src/sounds/CREDITS.md`**

```markdown
# Audio credits

Built by `scripts/build-audio.js` (mono, 16-bit, 22.05 kHz, silence trimmed, peak-normalised) unless noted.

- `sword`, `enemy_hit`, `enemy_die`, `rat_bite`, `goblin_hurt`, `goblin_die`, `king_roar`, `witch_cast`,
  `witch_hurt`, `coin`, `purchase`, `refuse`, `dialogue`, `save`, `potion`, `door`, `gate` (`.wav`) —
  from ["RPG Sound Pack"](https://opengameart.org/content/rpg-sound-pack) by artisticdude, CC0.
  `potion` and `gate` each mix two of its sounds; `scripts/build-audio.js` lists the exact source files.
- `die.wav` — `die1` from ["5 Hit Sounds + Dying"](https://opengameart.org/content/5-hit-sounds-dying) by TinyWorlds, CC0.
- `pain.wav` — made by the repo owner for this example. Not rebuilt.
- `low_health.wav` — `Blip_Select.wav` from
  ["100+ Game Sound Effects (wav/ogg/m4a)"](https://opengameart.org/content/100-plus-game-sound-effects-wavoggm4a)
  by Damaged Panda, licensed [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/). Unmodified, not rebuilt.
```

- [ ] **Step 6: Listen to a few files locally** (optional sanity check): `afplay examples/rpg/src/sounds/gate.wav`. Swapping a source is a one-row change. Picking the final sounds by ear is the user's call during playtesting.

- [ ] **Step 7: Commit**

```bash
git add examples/rpg/scripts/build-audio.js examples/rpg/src/music examples/rpg/src/sounds
git commit -m "rpg: build-audio.js, licensed sound effects and music (#290)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Music per scene

**Files:**
- Create: `examples/rpg/src/source/Audio/MusicTracks.bs`, `examples/rpg/src/source/Audio/PlayAudio.bs` (music half; Task 4 adds the sound-effect half)
- Create: `examples/rpg/tests/Audio.spec.bs`
- Modify: `examples/rpg/bsconfig.test.json` (add `source/Audio/MusicTracks.bs`)
- Modify: `examples/rpg/src/source/Scenes/AreaScene.bs`, `TitleScene.bs`, `CreditsScene.bs`, `examples/rpg/src/source/Entities/Witch.bs`

**Interfaces:**
- Consumes: `Game.musicPlay(path, loop, restart)`, `Game.musicStop()` (Task 1); `pkg:/music/*.mp3` (Task 2).
- Produces:
  - `musicTrackFor(sceneName as string) as string`
  - consts `MUSIC_BOSS_END`
  - `playSceneMusic(game as BGE.Game, sceneName as string)`

- [ ] **Step 1: Write the failing tests** `examples/rpg/tests/Audio.spec.bs`:

```brighterscript
namespace tests
  @suite("audio")
  class AudioTests extends rooibos.BaseTestSuite

    @describe("musicTrackFor")

    @it("gives every keep room the same track, so moving between them doesn't restart it")
    function _()
      castle = musicTrackFor("CastleScene")
      for each name in ["GuardroomScene", "StoreroomScene", "BarracksScene", "AntechamberScene", "KingsHallScene"]
        m.assertEqual(castle, musicTrackFor(name), name)
      end for
    end function

    @it("has a track for every playable scene")
    function _()
      m.assertEqual("pkg:/music/title.mp3", musicTrackFor("TitleScene"))
      m.assertEqual("pkg:/music/town.mp3", musicTrackFor("TownScene"))
      m.assertEqual("pkg:/music/sewer.mp3", musicTrackFor("SewerScene"))
      m.assertEqual("pkg:/music/castle.mp3", musicTrackFor("CastleScene"))
      m.assertEqual("pkg:/music/boss_loop.mp3", musicTrackFor("ThroneRoomScene"))
      m.assertEqual("pkg:/music/credits.mp3", musicTrackFor("CreditsScene"))
    end function

    @it("is silent for the showcase and unknown scenes")
    function _()
      m.assertEqual("", musicTrackFor("GoblinShowcaseScene"))
      m.assertEqual("", musicTrackFor("NoSuchScene"))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile error, because `musicTrackFor` isn't found.

- [ ] **Step 3: Write `Audio/MusicTracks.bs`**

```brighterscript
' examples/rpg/src/source/Audio/MusicTracks.bs
' Which music each scene plays. Pure, so it's unit-tested (tests/Audio.spec.bs).

const MUSIC_BOSS_END = "pkg:/music/boss_end.mp3"

' @param {string} sceneName - a scene's name, e.g. "TownScene"
' @return {string} the track's path, or "" for no music
function musicTrackFor(sceneName as string) as string
  tracks = {
    TitleScene: "pkg:/music/title.mp3",
    TownScene: "pkg:/music/town.mp3",
    SewerScene: "pkg:/music/sewer.mp3",
    CastleScene: "pkg:/music/castle.mp3",
    GuardroomScene: "pkg:/music/castle.mp3",
    StoreroomScene: "pkg:/music/castle.mp3",
    BarracksScene: "pkg:/music/castle.mp3",
    AntechamberScene: "pkg:/music/castle.mp3",
    KingsHallScene: "pkg:/music/castle.mp3",
    ThroneRoomScene: "pkg:/music/boss_loop.mp3",
    CreditsScene: "pkg:/music/credits.mp3"
  }
  if tracks.DoesExist(sceneName)
    return tracks[sceneName]
  end if
  return ""
end function
```

Add `"source/Audio/MusicTracks.bs",` to `examples/rpg/bsconfig.test.json`'s `files`, after `"source/UI/InputRoles.bs",`.

- [ ] **Step 4: Write `Audio/PlayAudio.bs`** (the music part):

```brighterscript
' examples/rpg/src/source/Audio/PlayAudio.bs
import "MusicTracks.bs"

' Starts the scene's track, leaving it running if the last scene played the same one.
sub playSceneMusic(game as BGE.Game, sceneName as string)
  track = musicTrackFor(sceneName)
  if track = ""
    game.musicStop()
  else
    game.musicPlay(track, true, false)
  end if
end sub
```

- [ ] **Step 5: Wire up the scenes**
- `AreaScene.bs`: add `import "../Audio/PlayAudio.bs"`, and make `playSceneMusic(m.game, m.name)` the first line of `onCreate`.
- `TitleScene.bs` and `CreditsScene.bs`: add the same import and the same first line in `onCreate`.

`GoblinShowcaseScene` inherits it and gets `""`, so it stops the music.

- [ ] **Step 6: The boss ending.** In `Entities/Witch.bs`, add `import "../Audio/MusicTracks.bs"` and append to `onDying()`:

```brighterscript
    ' The ending of the boss track plays once over her death.
    m.game.musicPlay(MUSIC_BOSS_END, false)
```

- [ ] **Step 7: Run the checks and confirm they pass**

Run: `cd examples/rpg && npm test && npx bsc --create-package=false`
Expected: `[Rooibos Result]: PASS` with the 3 new tests passing; `bsc` reports 0 errors.

- [ ] **Step 8: Commit**

```bash
git add examples/rpg/src/source/Audio examples/rpg/tests/Audio.spec.bs examples/rpg/bsconfig.test.json examples/rpg/src/source/Scenes examples/rpg/src/source/Entities/Witch.bs
git commit -m "rpg: a music track per area, boss ending on the witch's death (#290)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Sound effects

**Files:**
- Create: `examples/rpg/src/source/Audio/SoundEffects.bs`
- Modify: `examples/rpg/src/source/Audio/PlayAudio.bs`, `examples/rpg/tests/Audio.spec.bs`, `examples/rpg/bsconfig.test.json`
- Modify:
  - `examples/rpg/src/source/main.bs` (lines 65–71)
  - `Entities/Enemy.bs`, `Goblin.bs`, `GoblinKing.bs`, `Witch.bs`, `Rat.bs`, `Player.bs`, `Coin.bs`
  - `World/Pot.bs`, `FloorSwitch.bs`, `Pickup.bs`, `Door.bs`, `Gate.bs`
  - `UI/ShopPanel.bs`, `InventoryPanel.bs`, `DialogueBox.bs`, `SaveIndicator.bs`
  - `Story/Story.bs`

**Interfaces:**
- Consumes: the `sounds/*.wav` files from Task 2.
- Produces:
  - `interface SoundFile { name as string, file as string }`
  - `getSoundFiles() as SoundFile[]`
  - `soundVolume(name as string) as integer`
  - `loadSoundEffects(game as BGE.Game)`
  - `playSfx(game as BGE.Game, name as string)`
  - protected `Enemy` fields `hitSound`, `dieSound` and `attackSound`, all `as string`

- [ ] **Step 1: Add the failing tests** to `tests/Audio.spec.bs`, inside the class before `end class`:

```brighterscript
    @describe("sound effects")

    @it("gives every loaded sound a volume between 1 and 100")
    function _()
      for each sound in getSoundFiles()
        volume = soundVolume(sound.name)
        m.assertTrue(volume >= 1 and volume <= 100, sound.name)
      end for
    end function

    @it("loads every sound the game plays from its own file")
    function _()
      names = {}
      for each sound in getSoundFiles()
        m.assertFalse(names.DoesExist(sound.name), "duplicate " + sound.name)
        names[sound.name] = true
        m.assertEqual("pkg:/sounds/", Left(sound.file, 12), sound.file)
      end for
      for each name in ["sword", "enemyHit", "enemyDie", "ratBite", "goblinHurt", "goblinDie", "kingRoar", "witchCast", "witchHurt", "coin", "purchase", "refuse", "dialogue", "save", "potion", "door", "gate", "die", "pain", "lowHealth"]
        m.assertTrue(names.DoesExist(name), name + " is not loaded")
      end for
    end function

    @it("has no volume for an unknown sound")
    function _()
      m.assertEqual(0, soundVolume("noSuchSound"))
    end function
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd examples/rpg && npm test`
Expected: a compile error, because `getSoundFiles` isn't found.

- [ ] **Step 3: Write `Audio/SoundEffects.bs`**

```brighterscript
' examples/rpg/src/source/Audio/SoundEffects.bs
' Every sound effect and how loud it plays, in one place so effects can be balanced against the music.

interface SoundFile
  name as string
  file as string
end interface

' @return {SoundFile[]}
function getSoundFiles() as SoundFile[]
  return [
    {name: "sword", file: "pkg:/sounds/sword.wav"},
    {name: "enemyHit", file: "pkg:/sounds/enemy_hit.wav"},
    {name: "enemyDie", file: "pkg:/sounds/enemy_die.wav"},
    {name: "ratBite", file: "pkg:/sounds/rat_bite.wav"},
    {name: "goblinHurt", file: "pkg:/sounds/goblin_hurt.wav"},
    {name: "goblinDie", file: "pkg:/sounds/goblin_die.wav"},
    {name: "kingRoar", file: "pkg:/sounds/king_roar.wav"},
    {name: "witchCast", file: "pkg:/sounds/witch_cast.wav"},
    {name: "witchHurt", file: "pkg:/sounds/witch_hurt.wav"},
    {name: "coin", file: "pkg:/sounds/coin.wav"},
    {name: "purchase", file: "pkg:/sounds/purchase.wav"},
    {name: "refuse", file: "pkg:/sounds/refuse.wav"},
    {name: "dialogue", file: "pkg:/sounds/dialogue.wav"},
    {name: "save", file: "pkg:/sounds/save.wav"},
    {name: "potion", file: "pkg:/sounds/potion.wav"},
    {name: "door", file: "pkg:/sounds/door.wav"},
    {name: "gate", file: "pkg:/sounds/gate.wav"},
    {name: "die", file: "pkg:/sounds/die.wav"},
    {name: "pain", file: "pkg:/sounds/pain.wav"},
    {name: "lowHealth", file: "pkg:/sounds/low_health.wav"}
  ] as SoundFile[]
end function

' @param {string} name - a name from getSoundFiles()
' @return {integer} 1-100, or 0 for an unknown name
function soundVolume(name as string) as integer
  volumes = {
    sword: 70, enemyHit: 80, enemyDie: 80, ratBite: 70, goblinHurt: 80, goblinDie: 85,
    kingRoar: 90, witchCast: 75, witchHurt: 85, coin: 60, purchase: 70, refuse: 70,
    dialogue: 40, save: 50, potion: 80, door: 70, gate: 80, die: 90, pain: 90, lowHealth: 60
  }
  if volumes.DoesExist(name)
    return volumes[name]
  end if
  return 0
end function
```

Add `"source/Audio/SoundEffects.bs",` to `bsconfig.test.json` next to `MusicTracks.bs`.

- [ ] **Step 4: Add to `Audio/PlayAudio.bs`**

```brighterscript
import "SoundEffects.bs"

sub loadSoundEffects(game as BGE.Game)
  for each sound in getSoundFiles()
    game.loadSound(sound.name, sound.file)
  end for
end sub

' Plays a sound effect at its volume from soundVolume().
sub playSfx(game as BGE.Game, name as string)
  volume = soundVolume(name)
  if volume = 0
    print "[rpg] unknown sound effect: "; name
    return
  end if
  game.playSound(name, volume)
end sub
```

The `import "SoundEffects.bs"` goes at the top of the file, next to `import "MusicTracks.bs"`.

- [ ] **Step 5: Update `main.bs`.** Replace the seven `game.loadSound(...)` lines (65–71) with `loadSoundEffects(game)`, and add `import "Audio/PlayAudio.bs"` with the other imports.

- [ ] **Step 6: Replace every existing call.** Each file gets `import "../Audio/PlayAudio.bs"`.

| File:line (approx.) | Was | Becomes |
|---|---|---|
| `Entities/Player.bs:303` | `m.game.playSound("sword")` | `playSfx(m.game, "sword")` |
| `Entities/Player.bs:358` | `"pain"` | `playSfx(m.game, "pain")` |
| `Entities/Player.bs:368` | `"die"` | `playSfx(m.game, "die")` |
| `Entities/Player.bs:396` | `"lowHealth"` | `playSfx(m.game, "lowHealth")` |
| `Entities/Coin.bs:37`, `World/Pickup.bs:79` | `"coin"` | `playSfx(m.game, "coin")` |
| `World/Pot.bs:46`, `World/FloorSwitch.bs:52`, `Entities/Witch.bs:134` (shield clink) | `"enemyHit"` | `playSfx(m.game, "enemyHit")` |
| `Entities/GoblinKing.bs:172` (wall stun) | `"enemyHit"` | `playSfx(m.game, "enemyHit")` |
| `Story/Story.bs:279` (`buy`) | `"coin"` | `playSfx(m.game, "purchase")` |
| `UI/InventoryPanel.bs:55` (drink) | `"coin"` | `playSfx(m.game, "potion")` |

- [ ] **Step 7: Per-enemy sounds in `Entities/Enemy.bs`.** Add these fields after the existing protected fields:

```brighterscript
  ' Sound effect names (see Audio/SoundEffects.bs); attackSound plays when this enemy hurts the player.
  protected hitSound as string = "enemyHit"
  protected dieSound as string = "enemyDie"
  protected attackSound as string = ""
```

Then:
- In `hurt()`, change `m.game.playSound("enemyHit")` to `playSfx(m.game, m.hitSound)`.
- In `die()`, change `m.game.playSound("enemyDie")` to `playSfx(m.game, m.dieSound)`.
- In `recoil()`, after the `isDying` guard, add:

```brighterscript
    if m.attackSound <> ""
      playSfx(m.game, m.attackSound)
    end if
```

Set the fields in each subclass's `onCreate`, after `super.onCreate(args)`:
- `Rat.bs`: `m.attackSound = "ratBite"`
- `Goblin.bs` (so `GoblinKing` inherits it): `m.hitSound = "goblinHurt"` and `m.dieSound = "goblinDie"`
- `Witch.bs`: `m.hitSound = "witchHurt"` and `m.dieSound = "witchHurt"`

`GoblinKing` extends `Goblin`, so it inherits the goblin sounds.

- [ ] **Step 8: The new trigger points.** Each file needs `import "../Audio/PlayAudio.bs"`.
- `GoblinKing.bs` `startTell()`: append `playSfx(m.game, "kingRoar")`.
- `Witch.bs` `castFan()`: after `m.castLock.start(WITCH_CAST_SECONDS)`, add `playSfx(m.game, "witchCast")`. In `summonWave()`, put the same sound at the top of the existing `if not spawned` check (line ~310), as an `if spawned` / `playSfx(m.game, "witchCast")` / `end if` block placed before it.
- `World/Door.bs` `onCollisionEnter`: before `changeSceneWithFade`, add `playSfx(m.game, "door")`.
- `World/Gate.bs` `open()`: after `m.isOpening = true`, add `playSfx(m.game, "gate")`.
- `UI/ShopPanel.bs` `onAction`: in the `else` branch, before `m.setMessage(result.reason)`, add `playSfx(m.game, "refuse")`.
- `UI/InventoryPanel.bs`: in the drink `else` branch, before `m.setMessage`, add `playSfx(m.game, "refuse")`.
- `UI/DialogueBox.bs` `showPage()`: first lines:

```brighterscript
    if index > 0
      playSfx(m.game, "dialogue")
    end if
```
- `UI/SaveIndicator.bs` `onGameEvent`: inside the `storySaved` branch, add `playSfx(m.game, "save")`. Every `UiWidget` has `m.game`.

- [ ] **Step 9: Check that no raw calls remain**

Run: `grep -rn "playSound(" examples/rpg/src/source`
Expected: one match only, inside `Audio/PlayAudio.bs`.

- [ ] **Step 10: Run the tests and validation**

Run: `cd examples/rpg && npm test && npx bsc --create-package=false`, then `cd ../.. && npm run lint`
Expected: PASS (3 new tests), 0 bsc errors, lint clean.

- [ ] **Step 11: Commit**

```bash
git add examples/rpg
git commit -m "rpg: sound effects for dialogue, shop, potion, doors, gates, saving, goblins and the witch (#290)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Credits, docs, smoke test

**Files:**
- Modify: `examples/rpg/src/source/Story/CreditsData.bs`, `examples/rpg/tests/Credits.spec.bs`
- Modify: `CLAUDE.md` (`examples/rpg` bullet; the `Game` audio mention), `.claude/skills/rokubot-examples/SKILL.md`

- [ ] **Step 1: Write the failing credits test.** Add this to `tests/Credits.spec.bs` before `@it("uses only known styles")`:

```brighterscript
    @it("credits the music and sound effects")
    function _()
      text = ""
      for each line in getCreditLines()
        text += line.text + Chr(10)
      end for
      for each name in ["Jo" + Chr(227) + "o Vitor Lisboa", "RPG Market Theme", "Stealth in the Woods", "Boss Fight", "Horror music", "RPG Music", "Medieval: Victory Theme", "RandomMind", "artisticdude", "TinyWorlds", "Damaged Panda"]
        m.assertTrue(Instr(1, text, name) > 0, name + " is missing from the credits")
      end for
    end function
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd examples/rpg && npm test`
Expected: FAIL on "João Vitor Lisboa is missing from the credits".

- [ ] **Step 3: Add the credits.** In `CreditsData.bs`, before the `Font` title line, add:

```brighterscript
  lines.push({text: "", style: "body"})
  lines.push({text: "Music", style: "title"})
  addCredit(lines, "Title", """RPG Music"" by Jo" + Chr(227) + "o Vitor Lisboa. CC-BY-SA 3.0")
  addCredit(lines, "Town", """RPG Market Theme"" by Jo" + Chr(227) + "o Vitor Lisboa. CC-BY 4.0")
  addCredit(lines, "Sewer", """Horror music"" by Jo" + Chr(227) + "o Vitor Lisboa. CC0")
  addCredit(lines, "Castle", """Stealth in the Woods"" by Jo" + Chr(227) + "o Vitor Lisboa. CC0")
  addCredit(lines, "Throne room", """Boss Fight"" by Jo" + Chr(227) + "o Vitor Lisboa. CC0")
  addCredit(lines, "Credits", """Medieval: Victory Theme"" by RandomMind. CC0")
  lines.push({text: "Sound", style: "title"})
  addCredit(lines, "Sound effects", """RPG Sound Pack"" by artisticdude. CC0")
  addCredit(lines, "die.wav", """5 Hit Sounds + Dying"" by TinyWorlds. CC0")
  addCredit(lines, "low_health.wav", """100+ Game Sound Effects"" by Damaged Panda. CC-BY 3.0")
```

This matches the existing `Chr(246)` style for non-ASCII.

The `Font` section's existing `lines.push({text: "", style: "body"})` already comes before `Font`. Check the layout so there's exactly one blank line between sections (`addCredit` adds a trailing blank).

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `cd examples/rpg && npm test`
Expected: PASS.

- [ ] **Step 5: Update the docs**
- In `CLAUDE.md`'s `examples/rpg` bullet, append before "The story layer deliberately stays…":

  > **Audio** (issue #290, `specs/2026-10-06-rpg-slice-e-audio-design.md`): `Audio/MusicTracks.bs`'s `musicTrackFor(sceneName)` picks each scene's track, started by `playSceneMusic()` with `musicPlay(track, true, false)` so the six keep rooms share one unbroken track. The witch's death swaps in the boss track's one-shot ending. Effects go through `playSfx(game, name)` at a volume from `Audio/SoundEffects.bs`'s `soundVolume()`. Every effect and track is built by `examples/rpg/scripts/build-audio.js <downloadsDir>` with ffmpeg: mono 16-bit 22.05 kHz WAV, since `roAudioResource` plays WAV only, and 96 kbps MP3 music. Sources and licences are in `src/sounds/CREDITS.md` and `src/music/CREDITS.md`.
- Add a CLAUDE.md engine note near the `ScreenFade` bullet:

  > - **`Game.musicPlay(path, loop, restart = true)`/`getMusicPath()`**: `restart = false` leaves an already-playing track alone (scenes sharing a track don't restart it). The path clears on `musicStop()` or when a one-shot track ends. `roAudioPlayer` has no volume control, so music can't fade. Time a change under `changeSceneWithFade()` instead.
- `.claude/skills/rokubot-examples/SKILL.md`, in the RPG section: add "rokubot can't hear audio. For music and sound changes, smoke-test that each scene loads without a crash, then ask the user to listen."

- [ ] **Step 6: Run the full quality gate**

Run: `npm run check && npm run validate-examples && (cd examples/rpg && npm test)`
Expected: all PASS / 0 errors.

- [ ] **Step 7: On-device smoke test** (rokubot-examples skill). Sideload `examples/rpg`, then launch each of these and screenshot it:
  - `--param scene=TownScene`
  - `--param scene=SewerScene`
  - `--param scene=CastleScene`
  - `--param scene=ThroneRoomScene`
  - `--param scene=CreditsScene`
  - plain launch (title)

  Expected: every scene renders, and no crash or `musicPlay() - No file exists` error appears in the debug console.

- [ ] **Step 8: Commit**

```bash
git add examples/rpg CLAUDE.md .claude/skills/rokubot-examples/SKILL.md
git commit -m "rpg: credit the music and sound; docs for Slice E audio (#290)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: Hand over for listening.** Ask the user to play on a Roku and report on:
  - each scene's track, and that it doesn't restart between castle rooms
  - the boss loop seam, and the ending playing on the witch's death
  - the credits track
  - each new effect, and the effects' loudness against the music

Tune by editing `soundVolume()` or a source row in `build-audio.js` and rerunning it.
