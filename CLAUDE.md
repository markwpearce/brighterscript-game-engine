# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An object-oriented game engine for Roku, written in [BrighterScript](https://github.com/rokucommunity/brighterscript) (a typed superset of BrightScript that compiles to `.brs`). Distributed via ROPM. All engine source lives under `src/source/` inside the `BGE` namespace; `examples/` contains full sample Roku channels (asteroids, pong, snake, 3d, terrain, canvas, hybrid, pixels, rendererTest) that consume the engine via ROPM and serve as the main way to exercise engine changes end-to-end. There is also a growing Rooibos unit test suite (colocated `*.spec.bs` files) — see [Unit tests](#unit-tests-rooibos) below.

## Commands

Run from the repo root unless noted.

- `npm run build` — clean, then compile the engine with `bsc` (output to `build/`)
- `npm run validate` — type-checks the engine both without tests (`bsconfig.build.json`) and with tests (`bsconfig.test.json`) — always run it after changing engine code.
- `npm run lint` — run `bslint` (rules configured in `bslint.json`)
- `npm run clean` — remove build artifacts (`out/`, `build/`, `test-build/`, `*.tgz`)
- `npm run docs` — regenerate JSDoc HTML docs into `docs/` (config in `jsdoc.json`)
- `npm run build-tests` — compile the Rooibos test suite (`bsconfig.test.json`) to `test-build/`
- `npm run test:ci` — build the tests, then run them headlessly via `brs-cli` (no device/simulator needed) — this is what CI runs
- `npm run test:device` — run the tests against a real device or brs-desktop (`ROKU_HOST`/`ROKU_PASSWORD` env vars), for interactive debugging

Working with the example apps (each example under `examples/<name>` is its own npm project with its own `package.json`/`bsconfig.json`, pulling in the engine via ropm):

- `npm run prepare-examples` — build the engine, then `npm install` in every example directory
- `npm run build-examples` — build the engine, then build every example (`bsc` + zip via `roku-deploy`) — output zips land in `examples/<name>/out/bge-<name>.zip`
- `npm run validate-examples` — validate the engine, then `bsc --validate --create-package=false` in every example
- `npm run clean-all` — clean the engine and every example
- `npm run create-example -- <name> ["Display Title"]` — scaffold a new `examples/<name>` from `scripts/exampleTemplate` (manifest, bsconfig, generated icon/splash images, minimal `MainRoom`), and register it in the root `.vscode/tasks.json` example picker

All of the `*-examples` scripts fan out via `scripts/examples.js`, which iterates every `examples/*/` directory and runs the given command in each (a failure in one example doesn't stop the others, matching the original shell scripts this replaced). To act on a single example, `cd examples/<name>` and run its own npm scripts directly (`npm run build`, `npm run package`) instead. All `scripts/*.js` tooling is plain Node (no shell scripts) so it runs the same on Windows as macOS/Linux.

Beyond the Rooibos unit tests, confidence also comes from manually running an example on a real Roku or the Roku simulator via the VSCode BrightScript extension debug configurations in `.vscode/launch.json` / each example's own `.vscode/launch.json` (requires a `.env` with `ROKU_USERNAME`/`ROKU_PASSWORD`/`ROKU_HOST`, or the `Launch Simulator` config). To drive an example programmatically instead (sideload, launch, press keys, screenshot) — e.g. when asked to run, test, or "play" one — use the `rokubot` devDependency; see the `rokubot-examples` skill (`.claude/skills/rokubot-examples/SKILL.md`) for the workflow, speed tricks, and known per-example gotchas.

### Unit tests (Rooibos)

Tests are [Rooibos](https://github.com/rokucommunity/rooibos) v6 (`rooibos-roku`) suites, colocated next to the code they test as `*.spec.bs` (e.g. `src/source/math/Vector.spec.bs`, `src/source/utils/TagList.spec.bs`) — no separate `tests/` directory. `bsconfig.test.json` (extends `bsconfig.base.json`, loads the `rooibos-roku` plugin) builds them into `test-build/`; `bsconfig.build.json` excludes `*.spec.bs` entirely so none of this ships in a production build. `scripts/run-tests-ci.js` drives `brs-cli` (from the `brs-node` devDependency) headlessly for CI, watching stdout for Rooibos's `[Rooibos Result]: PASS`/`FAIL` line (the mocha reporter configured in `bsconfig.test.json` replaces, not supplements, the default console output) since `brs-cli` never exits on its own.

**Critical gotcha**: a `*.spec.bs` file may only contain **one** `@suite` class. Rooibos v6 (confirmed on `6.0.0-alpha.52`) silently corrupts test-suite metadata when two or more `@suite` classes live in the same file — tests run and report correctly for the classes processed first, then the run crashes with `[Rooibos Error]: ERROR RETRIEVING TEST SUITE DATA!!` while processing a later suite, regardless of which classes/content are involved. One class per file, always.

When testing `GameEntity`/`Game`-level behavior, prefer targeting the pure logic they depend on (e.g. `BGE.isValidEntity`, `MotionChecker`, `ArrayInsert`, `GameTimer`) over constructing a full `BGE.Game` (which creates a real `roScreen`/`roCompositor`) inside a test — that hasn't been proven safe inside Rooibos's own SceneGraph-based test-runner scene.

## Architecture

Everything lives in the `BGE` namespace. `rootDir` is `src`, `outDir` is `build` (see `bsconfig.json`).

### Game loop (`engine/Game.bs`)

`Game` is the top-level engine object (constructed once per app with canvas/UI dimensions). Its `Play()` method runs the single main loop, each frame:

1. **Input/event collection** — reads Roku universal control events, ECP input, audio events, and URL transfer events off message ports.
2. **Update** (`processEntitiesPreDraw`) — for every `GameEntity` (current room processed first, then `sortedEntities` in reverse): dispatch `onInput`/`onECPKeyboard`/`onECPInput`/`onAudioEvent`/`onUrlEvent`/`onUpdate`, then apply velocity to position (`processEntityMovement`).
3. **Collisions** (`processEntitiesCollisions`) — per entity, checks each `Collider` against the `roCompositor`, and calls `onCollision(myCollider, otherCollider, otherEntity)` for every hit.
4. **Draw** (`drawEntities`) — calls `onDrawBegin`/`onDrawEnd` around a `Renderer.drawScene()` pass; the game canvas and UI canvas are rendered separately, then debug overlays.
5. **UI / Debug UI** — `gameUi` and `debugUi` (both `UiContainer` trees) get their own update+draw pass on a separate `uiCanvas`, drawn on top of the game canvas.
6. Swap buffers, run periodic garbage collection (`secondsBetweenGarbageCollection`), then apply a pending room change if `changeRoom()` was called this frame (room changes are deferred to end-of-frame via `roomChangedThisFrame`/`handleRoomChange`).

At every step, entities are re-checked for validity (`isValidEntity`) before each callback, since a callback may `Delete()`/invalidate the entity or trigger a room change mid-frame.

Entities are tracked in `Game.Entities` as `{ <entityName>: { <entityId>: GameEntity } }`, plus a flat `sortedEntities` array (draw/update order = zIndex order via insertion into this array). `Game.Statics`, `Rooms`, `Interfaces`, `Bitmaps`, `Sounds`, `Fonts`, `Models` are the other name-keyed asset/registry tables owned by `Game`.

### Entities, Rooms, Drawables (`engine/GameEntity.bs`, `engine/Room.bs`, `engine/drawables/`)

- `GameEntity` is the base class every game object extends. It exposes empty lifecycle hooks meant to be overridden: `onCreate`, `onUpdate`, `onCollision`, `onDrawBegin`/`onDrawEnd`, `onInput`, `onECPKeyboard`/`onECPInput`, `onAudioEvent`, `onUrlEvent`, `onPause`/`onResume`, `onChangeRoom`, `onGameEvent`, `onDestroy`. It owns `position`/`velocity`/`rotation`/`scale`, a `colliders` map, a `drawables` array, and a `tagsList` (`TagList`) for ad hoc tagging.
- `Room` (in `engine/Room.bs`) is itself just a `GameEntity` subclass — the "current room" is processed like any other entity but always first/last in update and collision passes. Room changes go through `Game.changeRoom()`/`defineRoom()`, and non-persistent entities are destroyed on room change.
- `Drawable` (`engine/drawables/Drawable.bs`) is the base class for visual attachments on a `GameEntity` (`Image`, `Sprite`, `AnimatedImage`, `DrawableRectangle`, `DrawableLine`, `DrawablePolygon`, `DrawableText`, `Model3d`). Each drawable computes its own transformation matrix from offset/rotation/scale and, via `addToScene(renderer)`, registers a `SceneObject` with the `Renderer` — the actual per-frame draw call happens in the renderer, not the drawable.

### Renderer / SceneObjects (`engine/renderer/`)

- `Renderer` (`renderer/Renderer.bs`) wraps an `ifDraw2D` surface (a `Canvas`'s bitmap) and owns the list of `SceneObject`s to draw each frame, plus a `Camera` (`Camera2d` or `Camera3d`, under `renderer/cameras/`), a `TriangleCache` (caches rasterized triangle bitmaps — triangle drawing is otherwise expensive), and a `ScratchBitmapPool` (`ScratchBitmap.bs`) for reusable off-screen bitmaps. There is one `Renderer` for the game canvas and a separate one for the UI canvas (`Game.canvas.renderer` / `Game.uiCanvas.renderer`).
- `SceneObject` subclasses (`sceneObjects/SceneObject*.bs`) represent what actually gets drawn: `SceneObjectImage`, `SceneObjectBillboard`, `SceneObjectLine`, `SceneObjectPolygon`, `SceneObjectText`, `SceneObjectModel`. Each `SceneObjectDrawMode` (`matchCamera`, `directToCamera`, `directScaled`, `oriented`/`orientedDrawBackFace`, `wireFrame`/`wireFrameDrawBackFace`, `solid`/`solidDrawBackFace`) controls how an object reacts to camera rotation/perspective — this is what gives the 2D-renderer-based engine its pseudo-3D/billboard capability (see `examples/3d`, `examples/terrain`).
- `Canvas` (`engine/Canvas.bs`) pairs a bitmap with a `Renderer` and scale/offset, and is the thing `Game` composites to the physical `roScreen` each frame (game canvas and UI canvas are composited independently, letting UI stay crisp regardless of game canvas scaling).

### UI (`engine/ui/`)

`UiContainer`/`UiWidget`/`Label`/`Style`/`Alignment` implement a small retained-mode widget tree, drawn to its own canvas layer above the game world. `Game.gameUi`/`Game.debugUi` are the two top-level containers; debug windows (`engine/debug/`: `DebugWindow`, `FpsDisplay`, `GarbageCollectorDisplay`, `MemoryDisplay`, `InputDisplay`) attach under `debugUi` and are toggled via `Game.debugShowUi()`/`debugDrawColliders()`/etc.

### Collision (`engine/colliders/`)

`Collider` (base), `CircleCollider`, `RectangleCollider` wrap a Roku `roCompositor`/`roSprite` region per entity; collision checks happen through the compositor's `CheckMultipleCollisions()`, not manual AABB math.

### Math / Utils

`math/` has the vector/matrix/transform primitives engine code is built on (`Vector`, `Matrix44`, `Transform`, `CornerPoints`, `Triangle`, plus 2D `circle`/`rectangle` helpers) — `BGE.Math.VectorOps` and `BGE.Math.Matrix44` are used pervasively rather than raw associative arrays. `utils/` has cross-cutting helpers: `quickhull` (convex hull, used for 3D model face computation), `STLParser` (loads `.stl` 3D models, see `Game.load3dModel`), `tweens`, `MotionChecker` (dirty-checking for transforms, avoids recomputing matrices for unmoved objects — see its use in `Drawable.computeTransformationMatrix`), `TagList`, `registry` (Roku registry read/write helpers), `colors`, `strings`.

## Conventions specific to this codebase

- `bslint.json` disables `named-function-style` and `eol-last`, sets `inline-if-style: never` (don't write single-line `if`), and allows implicit type annotations.
- Public API surface is documented with JSDoc-style `'` comments (`@param`, `@return`) directly above class methods — these are pulled into the generated docs (`npm run docs`) via `brighterscript-jsdocs-plugin`; follow this style for any new public engine method.
- Internal-only state on `Game` is fenced with `' ****BEGIN - For Internal Use, Do Not Manually Alter****` / `****END...****` comments — treat that block as engine-private even though BrighterScript doesn't enforce it.
- Because entity callbacks can invalidate/delete the entity (or trigger a room change) mid-callback, engine code re-validates entities with `isValidEntity()`/`m.isValidEntity()` after every single callback invocation — follow this pattern when touching the per-frame processing methods in `Game.bs`.
