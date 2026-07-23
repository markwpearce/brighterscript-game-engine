# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An object-oriented game engine for Roku, written in [BrighterScript](https://github.com/rokucommunity/brighterscript) (a typed superset of BrightScript that compiles to `.brs`). Distributed via ROPM. All engine source lives under `src/source/` inside the `BGE` namespace; `examples/` contains full sample Roku channels (asteroids, pong, snake, 3d, canvas, hybrid, pixels, quickstart) that consume the engine via ROPM and serve as the main way to exercise engine changes end-to-end, plus `rendererTest` — a categorized, menu-driven suite of `BGE.Renderer` demos, deliberately built without `BGE.Game`/`Room` (see its own note under [Architecture](#architecture) below). There is also a growing Rooibos unit test suite (colocated `*.spec.bs` files) — see [Unit tests](#unit-tests-rooibos) below.

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

Constructing a real `BGE.Game` (which creates a real `roScreen`/`roCompositor`) inside a test works fine, including headlessly under `brs-cli` — confirmed via `Game.spec.bs`/`GameEntity.spec.bs`, which do this in `beforeEach`. Rooibos's own `stub()`/`mock()` can't fake native Roku components (`roScreen`, `roCompositor`, etc. — they only intercept methods on plain BrighterScript class/associative-array targets, and `CreateObject` itself can't be intercepted), so a real `Game` is the only way to exercise `GameEntity`/`Game` behavior; prefer it over duplicating engine logic by hand in a test. The same goes for `Renderer` (just needs a real bitmap, no `Game` required — see `Renderer.spec.bs`), colliders (needs a real `Game`/`GameEntity` for `setupCompositor`), and `Canvas`/`Room` (both need a real `Game`).

**`assertEqual` is type-strict** — `1` (Integer) and `1.0` (Float) fail against each other even though BrightScript would treat them as equal in most expressions. This bit almost every new spec file in this test suite. The type an assertion needs to match depends on how the value got there, not just its declared field type:
- A function param typed `as float`/`as integer` coerces the argument at the call boundary; a param typed `as dynamic` (common for optional/defaulted params) does not, so it carries through as whatever literal type was passed in.
- A class field typed `as float` does **not** get coerced on a later plain assignment (`m.x = 1` inside a method) — only `BGE.Math.VectorOps.create()`-style helpers that explicitly do `x * 1.0` reliably produce a `Float`.
- Some builtins matter too: `fix()`/`cint()` return `Integer`, `abs()` returns `Float`.
- When unsure, run the test once and read the actual/expected types out of the failure diff rather than guessing — Rooibos's assertion failure output prints the type of both sides.

**Avoid comparing whole objects with `assertEqual`** when they might embed circular references (e.g. a `GameEntity`/`Room` holding a `game` back-reference that itself holds the entity) or native Roku components (`roBitmap`, `roRegion`) — deep-equality comparison isn't guaranteed to handle either safely. Compare a distinguishing scalar field instead (an `id`, or a field you mutate specifically to mark identity, e.g. `renderer.frameCount = 12345` then assert the same value comes back through the code path under test).

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
- `onInput(input as GameInput)` (`engine/GameInput.bs`) reports directional `x`/`y` in **world space** (standard math convention, +y is up) — pressing "up" gives `y: 1`, "down" gives `y: -1`. Only the renderer's final world-to-canvas/raster projection (see `Camera2d.worldPointToCanvasPoint`) flips y to screen/pixel space (+y down). Every example that does `velocity.y = input.y * speed` relies on this.
- `Room` (in `engine/Room.bs`) is itself just a `GameEntity` subclass — the "current room" is processed like any other entity but always first/last in update and collision passes. Room changes go through `Game.changeRoom()`/`defineRoom()`, and non-persistent entities are destroyed on room change.
- `Drawable` (`engine/drawables/Drawable.bs`) is the base class for visual attachments on a `GameEntity` (`Image`, `Sprite`, `AnimatedImage`, `DrawableRectangle`, `DrawableLine`, `DrawablePolygon`, `DrawableText`, `Model3d`). Each drawable computes its own transformation matrix from offset/rotation/scale and, via `addToScene(renderer)`, registers a `SceneObject` with the `Renderer` — the actual per-frame draw call happens in the renderer, not the drawable.

### Renderer / SceneObjects (`engine/renderer/`)

- `Renderer` (`renderer/Renderer.bs`) wraps an `ifDraw2D` surface (a `Canvas`'s bitmap) and owns the list of `SceneObject`s to draw each frame, plus a `Camera` (`Camera2d` or `Camera3d`, under `renderer/cameras/`), a `TriangleCache` (caches rasterized triangle bitmaps — triangle drawing is otherwise expensive), and a `ScratchBitmapPool` (`ScratchBitmap.bs`) for reusable off-screen bitmaps. There is one `Renderer` for the game canvas and a separate one for the UI canvas (`Game.canvas.renderer` / `Game.uiCanvas.renderer`).
- `SceneObject` subclasses (`sceneObjects/SceneObject*.bs`) represent what actually gets drawn: `SceneObjectImage`, `SceneObjectBillboard`, `SceneObjectLine`, `SceneObjectPolygon`, `SceneObjectText`, `SceneObjectModel`. Each `SceneObjectDrawMode` (`matchCamera`, `directToCamera`, `directScaled`, `oriented`/`orientedDrawBackFace`, `wireFrame`/`wireFrameDrawBackFace`, `solid`/`solidDrawBackFace`) controls how an object reacts to camera rotation/perspective — this is what gives the 2D-renderer-based engine its pseudo-3D/billboard capability (see `examples/3d`).

#### Manually exercising the Renderer (`examples/rendererTest`)

`rendererTest` is the place to try out or demonstrate a `Renderer`/`ifDraw2D` capability directly — deliberately **not** built on `BGE.Game`/`Room`/`GameEntity`, since the point is to exercise `Renderer` (and, if needed, raw `roScreen`/`roBitmap`/`roRegion` calls) in isolation, the same way a consumer might before ever touching the rest of the engine. `main.bs` owns a raw `roScreen` + message port and a `BGE.Renderer` built directly from it (`new BGE.Renderer(screen)`, no `Game` involved), and runs an on-screen menu grouped by category (Up/Down to select, OK to run, Back to return to the menu).

**To add a new demo**: create a class under `examples/rendererTest/src/source/Tests/` extending `RendererTest` (`RendererTest.bs` — override `setup(renderer)` for one-time setup, `update(dt)`/`draw(renderer)` for the per-frame work, `onInput(buttonName)` for anything beyond Back, which `main.bs` already handles), then add one entry to the array in `DemoList.bs` (`{id, category, name, create: function() as RendererTest ... }`). That's the only file that needs editing — the menu picks it up automatically, grouped under `category`.

Two gotchas hit while building this, worth knowing before touching this file:
- The main loop must read input via `port.GetMessage()` (non-blocking), **not** `wait(0, port)` — in BrightScript, a `wait()` timeout of `0` means "wait forever" (no timeout), not "don't wait"; using it here froze the whole app on the splash screen until the first button press.
- `Renderer.drawPinnedCorners()`/`drawBitmapTriangleTo()` are relatively expensive per call (they check out/rasterize scratch bitmaps internally) — a demo that draws many of them in a loop should render once into a cached bitmap (in `setup()`) and blit that each frame, rather than redoing the full loop every frame at 60fps. `CornerPinGridTest.bs` does this; doing it the naive way caused most of a 26-tile grid to silently fail to render after the first few tiles.

A demo can also be launched directly, skipping the menu, via a `demo` deep-link param matching a `DemoList` entry's `id` — e.g. `rokubot launch dev --param demo=triangles` (see the `rokubot-examples` skill for the general `rokubot` workflow). Handy for scripted checks of one demo at a time instead of navigating the menu by hand.
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
