# Building a Game with BrighterScript Game Engine

This guide is for developers building a game *with* BGE - it walks through the pieces you'll
actually touch (`Game`, `Room`, `GameEntity`, `Drawable`, `Collider`) and the handful of
conventions that aren't obvious from the API reference alone. For a deeper look at how the engine
implements these pieces internally, see [Engine Internals](/tutorials/engine-internals).

## What you're building on top of

BGE is an object-oriented 2D-first game engine for Roku channels, written in
[BrighterScript](https://github.com/rokucommunity/brighterscript) and distributed via
[ROPM](https://ropm.dev). Everything lives under the `BGE` namespace. The `examples/` folder in
the repo has full sample channels (`pong`, `breakout`, `asteroids`, `snake`, `3d`, `canvas`,
`pixels`, `quickstart`, `hybrid`) that are the fastest way to see any of this in action -
`quickstart` in particular is a minimal scaffold worth copying as a starting point for a new game.

## Architecture at a glance

![Architecture overview: Game owns the current Room and sortedEntities; each entity's drawables feed a Renderer/Canvas pipeline that ends at roScreen, its colliders feed a roCompositor/onCollision pipeline, and a separate UiContainer tree draws to its own UI canvas](images/architecture-overview.svg)

| Piece | What it is |
| --- | --- |
| `Game` | The top-level engine object - one per app. Owns the main loop (`Play()`), the current `Room`, every other `GameEntity`, both canvases, and the asset registries (`Bitmaps`, `Sounds`, `Fonts`, `Models`, `Rooms`, `Interfaces`, `Statics`). |
| `Room` | A `GameEntity` subclass that represents "the current scene." Only one is active at a time; switching rooms via `Game.changeRoom()` destroys non-`persistent` entities. |
| `GameEntity` | The base class for anything in your game world - a player, an enemy, a bullet. Exposes lifecycle hooks (`onCreate`, `onUpdate`, `onCollision`, `onDrawBegin`/`onDrawEnd`, `onInput`, …) meant to be overridden, plus `position`/`velocity`/`rotation`/`scale`. |
| `Drawable` | **The recommended way to put anything on screen.** A visual attachment on a `GameEntity` - `Image`, `Sprite`, `AnimatedImage`, `DrawableRectangle`, `DrawableLine`, `DrawablePolygon`, `DrawableText`, `Model3d`. Registers a `SceneObject` with the `Renderer`; the actual draw call happens in the `Renderer`, not the `Drawable`, and moves/rotates/scales with the entity automatically. |
| `Collider` | A `CircleCollider` or `RectangleCollider` attached to a `GameEntity`, wrapping a `roCompositor`/`roSprite` region. Collision checks run through the compositor, not manual math. |
| `Renderer` | Wraps an `ifDraw2D` surface (a `Canvas`'s bitmap). Owns the scene's `SceneObject`s and a `Camera`. There's one for the game canvas and a separate one for the UI canvas. |
| `Canvas` | Pairs a bitmap with a `Renderer` and scale/offset. `Game` composites the game canvas and UI canvas to the physical `roScreen` independently each frame, so UI can stay crisp regardless of game-canvas scaling. |
| `UiContainer` / `UiWidget` | A small retained-mode widget tree (`Label`, `Style`, `Alignment`) drawn to its own canvas layer above the game world. `Game.gameUi` and `Game.debugUi` are the two top-level containers. |

**Always draw through a `Drawable` (`addImage`/`addSprite`/`addAnimatedImage`/etc. on your
`GameEntity`), not by calling `Renderer.Draw*()` yourself.** This is the one strong opinion this
guide has: `examples/asteroids` is worth reading end to end as a reference for doing this
consistently - every entity (`Player`, `Rock`, `Bullet`) is built entirely from `addImage()` +
`addCircleCollider()` in `onCreate`, with no direct `Renderer` calls anywhere in gameplay code.
Beyond being less code, it's what keeps a `Drawable`'s visual position and its `Collider`'s
collision position guaranteed to agree - see
[why that guarantee exists](/tutorials/engine-internals#colliders-never-go-through-the-camera) for
the mechanism, and what goes wrong when code draws directly instead.

## The game loop

`Game.Play()` runs one main loop. Every frame goes through six steps, always in this order:

![Game loop: 1 Input/Events, 2 Update, 3 Collisions, 4 Draw, 5 UI/Debug UI, 6 Swap and Housekeeping, cycling back to step 1](images/game-loop.svg)

A few things fall out of this that matter in practice:

- **Entity order**: the current `Room` is always processed first and last; everything else
  (`sortedEntities`) runs in `zIndex` (insertion) order in between.
- **Callbacks can invalidate their own entity.** A callback might call `Delete()` on itself, or
  trigger a room change. That's why the engine re-checks `isValidEntity()` before every single
  callback - if you write code that processes many entities in a loop (rare for game code, common
  for engine-level tooling), follow the same pattern.
- **Room changes are deferred to end-of-frame.** Calling `Game.changeRoom()` mid-frame doesn't
  swap the room immediately - it's applied after the draw/swap step, once the current frame is
  fully done with the old room.

## Two conventions that trip people up

These are the sharpest gotchas a new BGE developer hits - both were the source of real bugs found
while building the `breakout` and `snake` examples.

### `velocity` is in units/second

```
' A player that moves at 300 units/second horizontally when a direction is held
override sub onInput(input as BGE.GameInput)
  m.velocity.x = input.x * 300
end sub
```

`GameEntity.velocity` is added to `position` every frame, scaled by real elapsed time - it is
**units per second**, not "units per frame." ("Units," not "pixels," because `position`/`velocity`
may live in a scaled coordinate space rather than raw screen pixels.) If you're used to a
60fps-frame-based convention from another engine, a velocity in the *hundreds* is normal here,
not a bug - a paddle that used to read `speed = 12` (implicitly "12px per 60fps-frame") should now
read `speed = 720` (`12 * 60`, the equivalent in units/second).

### `RectangleCollider`'s offset is measured from the *bottom* edge, not the top-left

![Two examples of offset_x/offset_y: a top-left-anchored draw needs offset_y = height; a centered draw needs offset_y = height / 2, since RectangleCollider's top-left is always offset.y minus height](images/collider-offset.svg)

`addRectangleCollider(name, width, height, offset_x, offset_y)` places the rectangle's **top-left**
corner at `(offset_x, offset_y - height)` - so `offset_y` itself is the *bottom* edge, one full
`height` below the top-left. The offset you need depends entirely on how the entity is actually
drawn:

- **Top-left-anchored** (you draw at `position` and grow down/right from there, like a `Paddle` or
  a `Brick`): use `offset_y = height`, so the bottom edge lands at `position.y + height` and the
  computed top-left lands exactly at `position.y` - matching the draw.
- **Centered** (you draw with a pre-translated region so the image is centered on `position`, like
  a `Ball`): use `offset_y = height / 2`, so the box is centered on `position` too.

Getting this backwards doesn't crash anything - it just silently shifts the collider by up to a
full cell relative to what's drawn, which shows up as "the collision only registers when the
sprites don't look like they're touching" (or vice versa). Turning on collider debugging
(`Game.debugDrawColliders(true)`) is the fastest way to check:

![Asteroids with debug colliders and entity details visible: magenta dots marking each entity's position, circle collider outlines around the ship and rocks, and cyan entity name labels reading "Player" and "Rock"](images/asteroids-debug-colliders.jpg)

Compare that to the same scene with debug drawing off:

![Asteroids mid-game: a red rocket ship near a gray rock, on a starfield background](images/asteroids-gameplay.jpg)

## Debugging tools worth knowing early

- `Game.debugDrawColliders(true)` / `Game.debugDrawEntityDetails(true)` / `Game.debugShowUi(true)`
  - toggle these from an `onInput` handler (most examples bind them to the `options` remote
    button) to get the collider-outline view above, plus per-entity name/position labels.
- `Game.getDebugUI().addChild(new BGE.Debug.FpsDisplay(game))` and
  `BGE.Debug.InputDisplay`/`MemoryDisplay`/`GarbageCollectorDisplay` are ready-made debug widgets -
  every example wires up at least the FPS display in `main.bs`.
- `examples/rendererTest` is a menu-driven suite of `Renderer` demos built *without* `Game`/`Room`
  at all - useful for trying out a specific rendering capability (draw modes, triangle warping,
  camera projection) in isolation before wiring it into a real game.

## Where to go next

- Skim `examples/quickstart` for the smallest possible working game.
- Read `examples/asteroids` as the reference for building entities entirely out of
  `Drawable`s/`Collider`s, with no direct `Renderer` calls in gameplay code.
- Read `examples/breakout` or `examples/pong` for a complete, small, real game with comments
  explaining the collider-offset and velocity choices made for each entity.
- See [Engine Internals](/tutorials/engine-internals) for how the renderer, camera, and collision
  system fit together under the hood - useful once you're debugging something that doesn't behave
  like the docs above suggest it should.
