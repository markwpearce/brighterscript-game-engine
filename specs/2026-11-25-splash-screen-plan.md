# Splash Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every game opens with the engine's cannon splash (on by default, opt-out), with the
first scene loading underneath and room for game-supplied cards after it. Issue #99, design in
`specs/2026-11-25-splash-screen-design.md`.

**Architecture:** `BGE.SplashSequence` (`game.splash`) runs `BGE.SplashCard`s, engine card first.
`Game.Play()` starts it before its first frame. While it's active the loop only does input, the
splash, scene loading and drawing the splash; `onCreate()` of a loading first scene is held until
the splash ends, then the scene fades in from black.

**Tech Stack:** BrighterScript (bsc 1.0 alpha), Rooibos v6 headless (brs-cli), roScreen/roBitmap,
roAudioResource.

## Global Constraints

- Follow CLAUDE.md: no single-line `if`, `import` every file whose symbols you use, real types
  (interfaces for options bags, `as void` for sub callback types), no `=` between objects, no
  `continue for` after an inner loop.
- One `@suite` class per spec file, `@describe` before the first `@it`, `assertEqual` is
  type-strict.
- Engine card always first; `game.splash.enabled = true` by default.
- Skippable by default; `skippable = false` makes a card (engine card included) play in full.
  Skips are `press` events only. Skipping never skips loading.
- Code that never calls `play()` behaves exactly as today.
- Assets ship under `src/source/engine/splash/` and are referenced as
  `pkg:/source/engine/splash/...` (ROPM rewrites it for consumers).
- `npm run check` must pass at the end of every task that touches engine code.

## File structure

| File | Responsibility |
| --- | --- |
| `src/source/engine/splash/SplashCard.bs` | Base card: timing, skip rules, fade, hooks |
| `src/source/engine/splash/ImageSplashCard.bs` | Centred image card + options interface |
| `src/source/engine/splash/EngineSplashArt.bs` | HD/FHD layout constants, timeline, schemes, pure helpers |
| `src/source/engine/splash/EngineSplashCard.bs` | The cannon card: loads art/sound, animates, draws |
| `src/source/engine/splash/SplashSequence.bs` | Card order, cross-fades, loading hold + bar, outro |
| `src/source/engine/splash/images/*.webp`, `sounds/bge_startup.wav` | Art and sound |
| `src/source/engine/Game.bs` | `splash`, `isSplashActive()`, `unloadSound()`, Play() splash branch, hold, test hooks |
| `tools/splash/` | Generator scripts, README, Montserrat OFL |
| `docs/splash-screen.md` | Guide |

---

### Task 1: Assets and tools

**Files:** create `src/source/engine/splash/images/bge_{title,cannon,cannonball}_{hd,fhd}.webp`,
`src/source/engine/splash/sounds/bge_startup.wav`, `tools/splash/{make_splash.py,make_sound.py,preview.py,preview_av.py,Montserrat-OFL.txt,README.md}`;
modify `LICENSE-THIRD-PARTY.md`.

- [ ] Copy the six webp files and the scripts from the issue #99 attachment (`files 2.zip` →
  `bge_splash.zip`) into place.
- [ ] Convert the WAV to mono 22.05kHz 16-bit with Python's `audioop` (no ffmpeg here):

```python
import wave, audioop, sys
src, dst = sys.argv[1], sys.argv[2]
with wave.open(src) as w:
    p = w.getparams(); data = w.readframes(p.nframes)
mono = audioop.tomono(data, p.sampwidth, 0.5, 0.5)
out, _ = audioop.ratecv(mono, p.sampwidth, 1, p.framerate, 22050, None)
with wave.open(dst, 'wb') as o:
    o.setnchannels(1); o.setsampwidth(p.sampwidth); o.setframerate(22050); o.writeframes(out)
```

- [ ] `tools/splash/README.md`: what each script makes, its deps (Pillow, numpy, scipy,
  Montserrat), and the downmix step above.
- [ ] Add a Montserrat entry to `LICENSE-THIRD-PARTY.md` (art rendered from it; font not shipped;
  OFL text in `tools/splash/Montserrat-OFL.txt`).
- [ ] Commit: `Splash: engine logo art, startup sound and generator scripts`.

### Task 2: `SplashCard` and `ImageSplashCard`

**Interfaces — produces:**

```brighterscript
namespace BGE
  class SplashCard
    skippable as boolean = true
    minSeconds as float = 0.25
    fadeSeconds as float = 0.25
    elapsed as float = 0
    skipped as boolean = false
    sub onStart(game as BGE.Game)
    sub update(dt as float)            ' base: elapsed += dt
    function trySkip() as boolean      ' true (and skipped = true) if skippable and elapsed >= minSeconds
    function isFinished() as boolean   ' base: skipped
    ' The card's background colour, for the loading bar and fades
    function getBackgroundColor() as integer
    ' A colour that reads on the background, for the loading bar
    function getForegroundColor() as integer
    sub draw(renderer as BGE.Renderer, opacity as float)
    sub onEnd(game as BGE.Game)
  end class

  interface ImageSplashCardOptions
    optional seconds as float
    optional backgroundColor as integer
    optional foregroundColor as integer
    optional scale as float
    optional sound as string
    optional skippable as boolean
  end interface

  class ImageSplashCard extends SplashCard
    sub new(image as string, options = {} as BGE.ImageSplashCardOptions)
  end class
end namespace
```

`ImageSplashCard`: `image`/`sound` starting with `pkg:/` are loaded in `onStart()` under
`"bge.splash.image." + id` names and unloaded in `onEnd()`; otherwise they're names of
already-loaded assets and left alone. `isFinished()` is `skipped or elapsed >= seconds`. `draw()`
fills the background then draws the bitmap centred and scaled, with alpha `opacity` multiplied by
its own fade in/out over `fadeSeconds` at each end. Colours with an alpha byte are combined with
`BGE.Colors`' helpers (check `utils/colors.bs` for an alpha-multiply helper; add
`BGE.Colors.withAlpha(rgba, alpha as float) as integer` there if none exists, with a spec).

- [ ] Write `SplashCard.spec.bs` (in `src/source/engine/splash/`): `trySkip` ignored before
  `minSeconds`, ignored when `skippable = false`, accepted afterwards and `isFinished()`;
  `update` advances `elapsed`. `ImageSplashCard`: finishes at `seconds`, options override
  defaults, fade alpha is 0 at start, 1 mid-card, 0 at the end (expose
  `function getFadeAlpha() as float`), `onStart` with a missing `pkg:/` path logs and still
  finishes on time.
- [ ] Run `TEST_SHARDS=engine npm run test:ci`; expect failures (classes missing).
- [ ] Implement both classes. Run again; pass.
- [ ] `npm run check`; commit `Splash: SplashCard and ImageSplashCard`.

### Task 3: `EngineSplashCard`

**Interfaces — produces:**

```brighterscript
namespace BGE
  enum SplashScheme
    Purple = "purple"
    Dark = "dark"
    Cream = "cream"
    Teal = "teal"
  end enum

  ' EngineSplashArt.bs
  namespace EngineSplashArt
    function getLayout(fhd as boolean) as BGE.EngineSplashLayout   ' frame/body/ball/title sizes from the generator JSON
    function getFrameIndexAt(ms as float) as integer               ' timeline below
    function getBallSpawnMs() as float                              ' 720
    function getDurationMs() as float                               ' 3000
  end namespace

  class EngineSplashCard extends SplashCard
    backgroundColor as integer
    cannonColor as integer
    titleColor as integer
    sound as boolean = true
    sub useScheme(scheme as BGE.SplashScheme)
    ' Where the ball is (canvas px) at the card's elapsed time, or invalid before it spawns
    function getBallPosition() as BGE.Math.Vector
    function getFrameIndex() as integer
  end class
end namespace
```

Layout constants (from the generator JSON, `EngineSplashLayout` is an `interface ... extends
roAssociativeArray` with integer/float fields):

| | HD | FHD |
| --- | --- | --- |
| frame | 207x160 | 304x235 |
| body x,y,w,h | 2,49,128,109 | 2,71,188,162 |
| ball spawn x,y | 141.2,42.0 | 207.5,60.8 |
| ball size | 27 | 36 |
| title | 707x109 | 1055x162 |
| gap | 17 | 26 |
| ref height | 720 | 1080 |

Sheet is 4 columns x 2 rows; frame `i` is at `(i mod 4) * fw, (i \ 4) * fh`. Ball direction
`(0.8192, -0.5736)` in image space (+y down).

Timeline (ms): idle 0–510, windup 510, fire 600, ball_out 660, smoke1 720, smoke2 790,
smoke3 870, settle 960, idle from 1060. Sound at 0. Ball spawns at 720 (when the in-frame ball
goes away), at the spawn point, speed 3800 px/s and gravity 9600 px/s² at FHD scale (from
`preview_av.py`), times the art scale. Card finishes at 3000ms or on skip.

Art choice: `fhd = uiHeight >= 1000`; scale `= uiHeight / refHeight` (so a 320x240 test canvas
still lays out). Group centred: `groupW = body.w + gap + title.w` (scaled), title vertically
centred, cannon frame drawn at `(gx - body.x, ty - body.y)`, title at `gx + body.w + gap`.
Tinting with `drawScaledObject(..., rgba)` where `rgba` is the colour with its alpha multiplied
by `opacity`. Bitmaps loaded with `game.loadBitmap()` under `bge.splash.title`,
`bge.splash.cannon`, `bge.splash.ball`; sound with `game.loadSound("bge.splash.startup", ...)`;
all unloaded in `onEnd()`. Regions for the 8 frames made once in `onStart()`.

Schemes: Purple `&h421866FF`/white/white, Dark `&h121826FF`/`&hFFAA28FF`/`&hF0F0F5FF`,
Cream `&hF5F0E4FF`/`&h421866FF`/`&h1E1E28FF`, Teal `&h0A786EFF`/`&hFFE678FF`/white. Foreground
colour for the bar = `titleColor`.

- [ ] Write `EngineSplashCard.spec.bs`: frame index at 0, 509, 510, 600, 659, 660, 720, 960,
  1059, 1060, 2999; ball invalid before 720 and moving up-right just after; `isFinished()` false
  at 2.9s, true at 3.0s; each scheme's three colours; HD layout picked for a 720-high game, FHD
  for 1080; `sound = false` doesn't load the sound (`game.Sounds` has no
  `bge.splash.startup` after `onStart`).
- [ ] Run engine shard; expect failures. Implement `EngineSplashArt.bs` then
  `EngineSplashCard.bs`. Run; pass. `npm run check`. Commit
  `Splash: the engine's cannon card`.

### Task 4: `SplashSequence`

**Interfaces — produces:**

```brighterscript
class SplashSequence
  enabled as boolean = true
  engineCard as BGE.EngineSplashCard
  ' Delay before the loading bar shows once the cards are done
  barDelaySeconds as float = 0.25
  outroSeconds as float = 0.25
  sub addCard(card as BGE.SplashCard)
  function getCards() as BGE.SplashCard[]     ' engine card first
  sub start(game as BGE.Game)                 ' onStart of the first card
  sub onInput(input as BGE.GameInput)         ' press -> current card trySkip()
  sub update(dt as float, loading as boolean)
  sub draw(renderer as BGE.Renderer, progress as float)
  function isFinished() as boolean
  function hasPlayed() as boolean
  sub finish(game as BGE.Game)                ' onEnd for any card not yet ended
  function getCurrentIndex() as integer
  function isShowingLoadingBar() as boolean
end class
```

States: `cards` → (`waiting` while `loading`, last card's final frame + bar after
`barDelaySeconds`) → `outro` (fade the last card to black over `outroSeconds`) → `done`. Moving
to the next card calls `onEnd` on the old one and `onStart` on the new one, then cross-fades:
for the new card's first `fadeSeconds`, draw the old card at `1 - t` over... (simpler and cheap:
draw the new card with opacity `t` over the old card's background colour). The bar uses
`BGE.DefaultLoadingScreen`'s `getBarRect()` geometry (instantiate one and call it; it has no
state that matters) and the last card's foreground colour, drawn only when `progress < 1`.

- [ ] Write `SplashSequence.spec.bs` using a `TestSplashCard extends SplashCard` (finishes after
  `seconds`, counts `onStart`/`onEnd`): engine card first then added cards in order; skip moves
  on; `skippable = false` doesn't; release inputs ignored; while loading after the last card it
  stays in `waiting`, shows the bar only after `barDelaySeconds`; finished after `outroSeconds`
  once loading stops; every card gets exactly one `onStart`/`onEnd`; `finish()` ends the current
  card early. Build it with `seq.engineCard.sound = false` and a 320x240 game.
- [ ] Run; fail. Implement. Run; pass. `npm run check`. Commit `Splash: SplashSequence`.

### Task 5: Game integration

**Files:** modify `src/source/engine/Game.bs`; create `src/source/engine/GameSplash.spec.bs`.

**Interfaces — produces:** `game.splash as BGE.SplashSequence`, `game.isSplashActive() as boolean`,
`game.unloadSound(name as string)`, test hooks `startSplashForTest()` and
`runSplashFrameForTest(dt as float, inputs as BGE.GameInput[])`.

Changes:

1. Import `splash/SplashSequence.bs`; `splash = new BGE.SplashSequence()` in `new()`;
   private `splashActive as boolean = false`.
2. `unloadSound(soundName)`: `m.Sounds.Delete(soundName)`.
3. `private sub startSplashIfNeeded()`: if `m.splash.enabled and not m.splash.hasPlayed()`,
   `m.splashActive = true`, `m.splash.start(m)`. Called at the top of `Play()` after
   `m.running = true`. `startSplashForTest()` calls it.
4. In the loop, after the controls/ControlMap block, `if m.splashActive` → `m.runSplashFrame(universalControlEvents, controllerInputs)` and then the normal swap path; `else` the existing UI input, entity, draw block. `runSplashFrame`:
   - for each universal event and controller input, convert with `m.gameInputForRemoteMsg(msg)` and call `m.splash.onInput(input)`
   - `m.updateSceneLoading()`, `m.assets.update(m.assetsBudgetMs)`
   - `m.splash.update(m.dt, m.sceneLoading)`
   - clear both canvases, draw the game canvas to the screen as today (cleared, so black),
     `m.uiCanvas.renderer.setupCameraForFrame()`, `m.splash.draw(m.uiCanvas.renderer, progress)`
     where progress is `m.getLoadingProgress()`
   - then the existing debug UI, ui canvas blit and `SwapBuffers` run unchanged.
   - if `m.splash.isFinished()`, call `m.endSplash()`.
5. `applyEndOfFrameSceneWork()`: `if m.sceneLoading and m.sceneLoadFinished and not m.splashActive` for `finishSceneLoading()`. A pending scene change during the splash: also skip `handleSceneChange()` while `splashActive`.
6. `endSplash()`: `m.splashActive = false`, `m.splash.finish(m)`, `m.screenFade.opacity = 1.0`.
   If `m.sceneLoading and m.sceneLoadFinished`: `m.fadeTransitionPhase = "out"`,
   `m.fadeTransitionSeconds = 0.3`, `m.finishSceneLoading()` (which starts the "in" fade). Else
   if no load: `m.fadeTransitionPhase = "in"`, `m.screenFade.fadeTo(0, 0.3)`. Then apply any
   pending `sceneChangedThisFrame` via `handleSceneChange()`, and `m.dtTimer.Mark()`.
   (Loading can't still be running here: the sequence only finishes when `loading` is false.)
7. `isTransitioning()` also returns true while `splashActive`; add `isSplashActive()`.
8. `isLoadingScreenShown()` false during the splash: in `updateSceneLoading()`, don't show the
   loading screen while `splashActive`.

- [ ] Write `GameSplash.spec.bs` (game 320x240, `game.splash.engineCard.sound = false`, real
  card timing stepped with dt 0.1, so the engine card takes 30 frames):
  - never calling play: `changeScene` still creates synchronously, `isSplashActive()` false
  - `enabled = false`: `startSplashForTest()` does nothing
  - loading scene: `onCreate` not called while the splash runs even after the loader is done;
    called on the frame the splash ends; fade-in starts (`screenFade.opacity` 1 → decreasing)
  - loading longer than the splash: splash finishes only after loading ends
  - scene created before play: no `onUpdate` while active (use `runSplashFrameForTest` then
    `processEntitiesPreDrawForTest` only after it ends)
  - `changeScene` during the splash applies after it
  - a press skips; `skippable = false` ignores it
- [ ] Run; fail. Implement. Run; pass. `npm run check`. Commit
  `Splash: show it before the first scene, loading underneath`.

### Task 6: Docs and examples

- [ ] `docs/splash-screen.md` (frontmatter `title: Splash Screen`, `group: Guides`, next free
  `order`): opt-out, schemes/colours/sound, `ImageSplashCard`, custom cards, skippable, loading
  behaviour, the first-scene `onCreate()` note, asset size. Link from `docs/loading-assets.md`
  (Loading screens section) and `docs/game-engine-overview.md`.
- [ ] `examples/loading`: add a studio card (`ImageSplashCard` with one of its own images) in
  `main.bs`.
- [ ] Find example tests / rokubot scripts that screenshot or drive the first scene
  (`grep -rn "rokubot\|screenshot" examples/*/package.json examples/*/test* scripts`) and add a
  wait or a skip key press where needed.
- [ ] Add the change to `CHANGELOG.md` under Unreleased if that file has such a section.
- [ ] `npm run check:all`. Commit `Splash: docs and example`.

### Task 7: Device check and PR

- [ ] Sideload `examples/loading` (rokubot-examples skill) on the Express (.118) and the Ultra
  (.102): screenshot the splash mid-animation, confirm the art is sharp, sound plays, skip works,
  scene fades in.
- [ ] Open the PR (pr-voice skill), `Closes #99`.
