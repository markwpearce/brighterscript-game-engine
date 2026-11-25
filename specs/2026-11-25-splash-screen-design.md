# Splash screen (issue #99)

## Why

Every game built on the engine should open with the BrighterScript Game Engine logo: a cannon
fires a ball, with a startup sound. This is credit for the engine (see #696, which looks into
asking for it in the licence) and gives games a polished start. Games often have their own studio
or publisher logos to show too.

Most of #99's loading half already exists (`GameScene.onLoad()`, `AssetLoader`, `LoadingScreen`).
What's missing is the branded splash, a way to chain more logos after it, and hiding the first
scene's loading behind them.

## Goals

- **On by default.** `game.play()` shows the engine splash once per launch, before the first
  scene. A game turns it off with `game.splash.enabled = false`.
- **Loads underneath.** The first scene's `onLoad()` queue runs while the splash plays. The scene's
  `onCreate()` waits until the queue has drained and every card has finished. If loading takes
  longer than the cards, the last card stays up with a thin progress bar, then fades into the scene.
- **A card sequence, engine card first.** Games append their own cards: a ready-made image card,
  or a subclass with its own drawing. The engine card can't be moved or removed, only turned off
  with `enabled`.
- **Skippable by default.** Any key press skips the current card. A card with `skippable = false`
  plays in full. This includes the engine card, so a game can mark it unskippable. Skipping never
  skips loading.
- **Restylable engine card.** Four preset colour schemes from the brand sheet, or set the
  background, cannon and title colours directly. The sound can be turned off. The layout and
  animation stay fixed.
- **No change for code that never calls `play()`.** Unit tests build a `Game` and change scenes
  without running the loop, and they must behave as they do today.

## Non-goals

- A splash for SceneGraph-only apps that never create the engine's `roScreen`. The splash draws
  on the UI canvas, so it works wherever the loading screen does today.
- Showing the splash again on later scene changes. It's a once-per-launch thing.
- Licence wording. That's #696.

## Design

### Startup phase in `Game.Play()`

The decision is made when `Play()` starts, not in `changeScene()`. That's because games call
`changeScene()` in `Main()` before `play()`, and a first scene with nothing to load runs its
`onCreate()` right there.

When `Play()` starts, if `m.splash.enabled` is true and the splash hasn't played yet, the game
sets `splashActive = true` and calls `m.splash.start(m)`. While it's active, each frame of the loop:

1. Collects input as normal. Remote and controller key presses go to `m.splash.onInput(input)`
   and are not passed to `gameUi`, the scene or entities.
2. Calls `m.splash.update(dt)`.
3. Calls `updateSceneLoading()`, so the first scene's queue keeps loading within
   `loadingBudgetMs`.
4. Skips entity updates, the tween manager, collisions and game canvas drawing. This is the same
   hold that loading already puts on the scene and its entities. Persistent entities and `gameUi`
   are held too, because the splash covers the whole screen.
5. Draws the splash on the UI canvas with `m.splash.draw(renderer, loadingProgress, dt)`. Then it
   draws `debugUi` as normal and swaps buffers.
6. At the end of the frame, `applyEndOfFrameSceneWork()` doesn't call `finishSceneLoading()`
   while `splashActive` is true. A scene change requested during the splash stays pending as it
   does during loading.

The splash ends when `m.splash.isFinished()` is true and no scene is loading. Then the game:

- Sets `splashActive = false`, calls `m.splash.onEnd()` and frees the splash bitmaps and sound.
- Runs the held `finishSceneLoading()`, if loading finished during the splash.
- Starts a fade-in from black with `screenFade` (0.3s), using the same path as
  `changeSceneWithFade()`'s second half.
- Marks `dtTimer`, so the scene's first `dt` isn't the length of the splash.

There are two first-scene cases:

- **Still loading when `play()` starts.** `onCreate()` runs after the splash, as described above.
  The splash replaces the loading screen, so `resolveLoadingScreen()`'s screen is never shown for
  this load.
- **Already created in `Main()`** (`onLoad()` queued nothing). The scene simply gets no updates
  until the splash ends. The docs say so: `onCreate()` may run before the splash, but the first
  `onUpdate()` is always after it. A `GameTimer` started in `onCreate()` counts the splash time.

`game.isSplashActive()` lets persistent code check for it. `isTransitioning()` also returns true
while the splash is active.

If no scene was ever changed to before `play()`, the splash still plays, then the loop carries on
as today.

### Classes (`src/source/engine/splash/`)

**`BGE.SplashCard`** is the base class for one card in the sequence.

- `skippable as boolean = true`
- `minSeconds as float = 0`: a skip is ignored until the card has been up this long. This avoids
  a key press left over from launching the channel skipping the first card.
- `fadeSeconds as float = 0.25`: how long the cross-fade into this card takes.
- `elapsed as float`: seconds since the card started. The sequence sets it.
- `sub onStart(game as BGE.Game)`: load assets and play a sound here.
- `sub update(dt as float)`
- `sub draw(renderer as BGE.Renderer, opacity as float)`: draws the full screen.
- `function isFinished() as boolean`
- `sub onEnd(game as BGE.Game)`: free assets here.

**`BGE.EngineSplashCard extends SplashCard`** is the cannon logo.

- Art: the title, the cannon sprite sheet (4x2 frames, 8 frames) and the cannonball. All are
  white-on-transparent, tinted when drawn with the `rgba` argument. The HD set is used when the UI
  canvas is under 1080 high, and FHD otherwise. Frame rects, `body`, `ballSpawn` and
  `suggestedGap` come from the generator's JSON. They're kept as constants in a `.bs` file, not
  parsed at runtime.
- Layout: the cannon body and title are a group, centred on screen. The title is vertically
  centred, and the cannon is placed so `body` sits `suggestedGap` to the left of the title. This
  matches `preview.py`.
- Timeline (from `bge_startup.json`):

  | Time | What happens |
  | --- | --- |
  | 0ms | Sound starts. The cannon shows its idle frame. |
  | 510ms | Windup frame. |
  | 600ms | Fire frame: the boom. |
  | +60ms each | `ball_out` and the smoke frames, using each frame's `duration` from the JSON. |
  | After the settle frame | Back to idle. |
  | About 3.0s | The card is finished. |

  The ball spawns at `ballSpawn` on the `ball_out` frame. It moves along
  (`dirX`, `dirY`) × launch speed, with gravity, until it leaves the screen.
- `useScheme(scheme as BGE.SplashScheme)`. The presets are:

  | Scheme | Background | Cannon | Title |
  | --- | --- | --- | --- |
  | `Purple` (default) | `#421866` | white | white |
  | `Dark` | `#121826` | `#FFAA28` | `#F0F0F5` |
  | `Cream` | `#F5F0E4` | `#421866` | `#1E1E28` |
  | `Teal` | `#0A786E` | `#FFE678` | white |

- `backgroundColor`, `cannonColor` and `titleColor` (packed RGBA) can be set directly.
- `sound as boolean = true`. The sound plays on channel 0 with `game.playSound()`.

**`BGE.ImageSplashCard extends SplashCard`** is a centred image.

- `new(image as string, options as BGE.ImageSplashCardOptions)`. `image` is a loaded bitmap name,
  or a `pkg:/` path, which is loaded in `onStart()` and freed in `onEnd()`.
- Options (an interface with all fields optional):
  - `seconds`: defaults to 2.
  - `backgroundColor`: defaults to black.
  - `scale`: defaults to 1.
  - `sound`: a loaded sound name or a `pkg:/` WAV path.
  - `skippable`.
- It fades in and out over its `fadeSeconds`.

**`BGE.SplashSequence`** is `game.splash`, created in `Game.new()`.

- `enabled as boolean = true`
- `engineCard as BGE.EngineSplashCard`: always plays first. Restyle it here.
- `sub addCard(card as BGE.SplashCard)`
- `start`, `onInput`, `update`, `draw`, `isFinished` and `onEnd` are called by `Game`.
- It moves to the next card when the current one finishes or is skipped, cross-fading over the
  next card's `fadeSeconds`.
- When the last card finishes but the game is still loading, `draw()` keeps drawing that card's
  final frame with a progress bar under it. The bar is placed by
  `DefaultLoadingScreen.getBarRect()` and coloured with the card's foreground colour. It's shown
  only after a further 0.25s, like `showAfterSeconds`, so a load that finishes just after the
  cards doesn't flash a bar.
- A skip key press must be a `press`, not a release. Back skips like any other key and doesn't
  quit.

### Assets

These ship in `src/source/engine/splash/images/` and `src/source/engine/splash/sounds/` and reach
consumers through ROPM, the same way `debug/images/*.png` do:

- `bge_title_{hd,fhd}.webp`, `bge_cannon_{hd,fhd}.webp` and `bge_cannonball_{hd,fhd}.webp`:
  about 33KB in total.
- `bge_startup.wav`: re-encoded from the 529KB stereo 44.1kHz original to mono 22.05kHz 16-bit,
  about 130KB. A Roku channel must be under 4MB zipped, and every game carries this file.

The generator scripts (`make_splash.py`, `make_sound.py`, `preview.py`) go in `tools/splash/`,
with a short README. The title is set in Montserrat (SIL OFL 1.1). The art is rendered from it and
the font itself isn't shipped. The OFL text goes in `tools/splash/` and gets an entry in
`LICENSE-THIRD-PARTY.md`.

## Testing

Rooibos specs, colocated:

- `EngineSplashCard.spec.bs`: frame selection at the cue times, the ball spawn time and position,
  `isFinished()` at about 3s, colours for each scheme, HD vs FHD choice, `sound = false`.
- `SplashSequence.spec.bs`: card order with the engine card first, skip vs `skippable = false`,
  skips ignored before `minSeconds`, release events ignored, cross-fade opacity, the progress bar
  shown only after the cards finish and the extra delay passes.
- `GameSplash.spec.bs`: start the splash with a new test-only `startSplashForTest()` and step it with `runSceneTransitionFrameForTest(dt)` (which gains the splash update and hold), plus
  `fakeDT`. Check that:
  - `onCreate()` waits until both the queue and the splash are finished, in each order;
  - the scene and entities get no `onUpdate()` meanwhile;
  - a scene created in `Main()` gets its first `onUpdate()` only after the splash;
  - `enabled = false` behaves as today;
  - a `changeScene()` during the splash is applied afterwards;
  - code that never calls `play()` is unaffected.

On a device: run an example on the Express and the Ultra. Check that the sound's boom lines up
with the fire frame, that the HD and FHD art are both sharp, and that a first scene with a long
load shows the progress bar.

## Docs and examples

- A new `docs/splash-screen.md` covering the opt-out, schemes, custom cards and the loading
  behaviour. Link it from `docs/loading-assets.md` and `docs/game-engine-overview.md`.
- `examples/loading` gets a studio-logo `ImageSplashCard` after the engine card.
- Every other example now shows the engine splash. The rokubot drive scripts and any example
  tests that screenshot the first scene need to wait about 3s, or press a key to skip.
