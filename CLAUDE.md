# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

An object-oriented game engine for Roku in [BrighterScript](https://github.com/rokucommunity/brighterscript), distributed via ROPM. All engine source is under `src/source/` in the `BGE` namespace. `examples/` holds sample Roku channels that consume the engine via ROPM and are the main end-to-end check of engine changes; `examples/rendererTest` is a menu of `BGE.Renderer` demos built without `Game`/`GameScene` (see below). Unit tests are colocated Rooibos `*.spec.bs` files.

Deeper material: hand-written guides in `docs/` (e.g. `engine-internals.md`, `drawables-and-scene-objects.md`, `loading-assets.md`, `render-quality.md`, `story.md`, `tile-maps.md`) and design specs in `specs/`. Read the relevant one before changing a subsystem.

## Commands

Run from the repo root.

- `npm run check` — lint, validate, headless tests. The standard quality gate; always run after engine changes.
- `npm run check:all` — `check`, then validate every example.
- `npm run validate` — type-check with and without tests (`bsconfig.build.json`, `bsconfig.test.json`).
- `npm run lint` / `npm run build` / `npm run clean` / `npm run docs` / `npm run docs-server` (serves under the `/brighterscript-game-engine` basePath, as deployed).
- `npm run test:ci` — build and run tests headlessly via `brs-cli` (what CI runs). `npm run test:device` runs them on a device/brs-desktop (`ROKU_HOST`/`ROKU_PASSWORD`).
- Examples: `prepare-examples`, `build-examples` (zips to `examples/<name>/out/`), `validate-examples`, `clean-all` — all fan out via `scripts/examples.js`. `npm run run-example -- <name> [key=value ...]` builds the engine, packages one example, sideloads it and launches it with deep-link params (`scripts/run-example.js`). Otherwise, for one example, `cd examples/<name>` and use its own npm scripts (some, e.g. `rpg`, `visualnovel`, have their own `npm test`, not part of CI).
- Scaffolding: `npm run create-example -- <name> ["Title"]`, `create-entity -- <example> <Entity>`, `create-scene -- <example> <Scene>` (then wire up `defineScene`/`changeScene` by hand).
- `npm run audio -- <sfx|music|silences|info> ...` — `ffmpeg`-based audio tools (`roAudioResource` plays WAV only; `roAudioPlayer` can't play OGG).

All `scripts/*.js` are plain Node so they run on Windows too.

To run/drive an example on a Roku or simulator (sideload, launch, keys, screenshots), use the `rokubot-examples` skill. `examples/rendererTest` demos can be launched directly with `--param demo=<id>`.

### Releasing

Never by hand. Run the **Initialize Release** GitHub workflow (patch/minor/major): it bumps the version, drafts CHANGELOG's `[Unreleased]` section from merged PRs, and opens a `release/x.y.z` PR. Edit the notes there and merge promptly; merging runs **Publish Release** (tag, `npm publish` via OIDC trusted publishing, GitHub release). Publish Release is re-runnable after partial failure.

### Unit tests (Rooibos v6)

- **One `@suite` class per `*.spec.bs` file.** Two in one file corrupts suite metadata (`ERROR RETRIEVING TEST SUITE DATA!!`).
- Rooibos can't stub native components (`roScreen`, `roCompositor`, `CreateObject`). Construct a real `BGE.Game` (works headlessly) for `GameEntity`/`Game`/collider/`Canvas`/`GameScene` tests; `Renderer` only needs a real bitmap.
- **`assertEqual` is type-strict** (`1` ≠ `1.0`). `as dynamic` params and plain field assignments don't coerce; `fix()`/`cint()` return Integer, `abs()` Float. When unsure, run once and read the types from the failure diff.
- Don't name a suite field `scene` (clashes with `rooibos.BaseTestSuite.scene`).
- Don't `assertEqual` whole objects that may hold circular references or native components; compare an id or marker field.
- Needs an `@describe` before the first `@it` (RBS2201).
- Tests cover engine code only. Example apps' runtime code is **not** exercised by `check`/`validate-examples` — an actual on-device/simulator run is required to verify example changes.

### Docs site

`docs-site/` is generated and gitignored; `docs.yml` deploys it to GitHub Pages on every push to `main` (`https://markwpearce.github.io/brighterscript-game-engine/`).

**Every markdown file under `docs/` is published** (`opts.docs`, recursive). Internal design docs/plans go in `specs/`. Guides need frontmatter (`title`, `group: Guides`, `order`). Cross-link with root-relative slugs (`[Engine Internals](/engine-internals)`); literal `opts.menu` links in `jsdoc.json` need the `/brighterscript-game-engine` prefix by hand. No Mermaid — diagrams are SVG/PNG in `docs/images/`.

## Architecture

### Game loop (`engine/Game.bs`)

`Game.Play()` runs one loop per frame:

1. Collect input/ECP/audio/URL events.
2. **UI input first** (`processUiInput`): `gameUi` gets input before entities, so a widget can `input.consume()` and stop it reaching `GameEntity.onInput()`.
3. Update entities (current scene first, then `sortedEntities` in reverse): input callbacks, `onUpdate`, velocity integration; then `tweenManager` ticks (a tween beats velocity on the same field).
4. Collisions via `roCompositor`, calling `onCollision`.
5. Draw game canvas (`onDrawBegin`/`render()`/`onDrawEnd`), then UI canvas, then `debugUi` (update+draw).
6. Swap buffers, periodic GC, then apply any pending scene change (deferred to end of frame).

Callbacks can delete entities or change scene mid-frame, so engine code re-checks `isValidEntity()` after **every** callback — follow this in `Game.bs`. Internal state on `Game` is fenced by `****BEGIN/END - For Internal Use****` comments.

### Entities, scenes, drawables

- `GameEntity` is the base game object (lifecycle hooks `onCreate`/`onUpdate`/`onCollision`/`onInput`/…/`onDestroy`; `position`/`velocity`/`rotation`/`scale`, colliders, drawables, tags).
- `GameScene` is a `GameEntity` representing one game state; methods/fields say "scene" (`changeScene()`, `currentScene`, `Scenes/`). Scenes are reused: the old one gets `onChangeScene()` then `onDestroy()` — remove its `gameUi` widgets there, or focusable buttons keep taking input in the next scene. Non-persistent entities are destroyed on scene change (`onChangeScene()`, no `onDestroy()`).
- **Scene loading** (`engine/loading/`, `docs/loading-assets.md`): `GameScene.onLoad(loader, args)` queues `LoadTask`s; they run within `loadingBudgetMs` per frame behind a `LoadingScreen`, and `onCreate` runs once the queue drains. Held entities get no callbacks meanwhile. Loaders accept http(s) URLs (cached under `cachefs:/bge/`); synchronous `Game` loaders don't. Bitmaps decode via `BGE.TextureLoader` (`roTextureManager`). Tests fake the network by overriding `DownloadTask.createTransfer()`/`createPort()` or `AssetLoader.newDownloadTask()`, and swap in `tests.FakeTextureLoader`.
- `Drawable`s attach to an entity and register a `SceneObject` with the `Renderer`, which does the actual drawing (see `docs/drawables-and-scene-objects.md`). `Drawable.owner` may be `invalid` — use the owner-safe accessors (`getGame()`, `getOwnerPosition()`, …), not `m.owner.*`.
- A drawable that changes shape in place must call `invalidateGeometry()` (movement checking can't see a resize).
- `GameEntity.isOnScreen()` is a signal only; the engine never skips off-screen entities' updates.
- **Two color formats**: `Drawable.color`/`outlineRGBA` take RGB (`0xRRGGBB`, `BGE.ColorsRGB`); `Renderer.draw*` takes RGBA (`0xRRGGBBAA`, `BGE.Colors`). Mixing them gives a wrong color, not an error.
- `GameInput` `x`/`y` are world space: +y is up. Only the final canvas projection flips y.
- `GameInput` fires on both press and release — guard one-shot actions with `input.press and input.isButton(...)`.

### Renderer (`engine/renderer/`)

- One `Renderer` per canvas (game and UI), owning `SceneObject`s, a `Camera2d`/`Camera3d`, a `TriangleCache` and a `ScratchBitmapPool`. Draw modes (`SceneObjectDrawMode`) give billboard/oriented pseudo-3D. Plain `oriented` backface-culls — inward-facing walls need `orientedDrawBackFace`.
- Depth sort is a stable whole-object painter's sort, skipped when nothing changed. Optional overlap clusters (`computeOverlapClusters`) interleave per-face primitives. Static entities (`GameEntity.isStatic`, oriented image/rectangle) go into a classification-only BSP so dynamic objects sort correctly against walls. Occlusion culling (`Drawable.isOccluder`, `Camera3d` only) uses a span map; see `specs/` for the depth-sort, BSP and occlusion designs.
- Culled objects latch (`isCulled()`) until they move; deterministic draw failures latch too.
- `Camera3d.maxDrawDistance` is the base; the effective distance is scaled by render quality, eased over time, and device-capped (simulator 900, FHD 2500, HD 1000) because large plane bitmaps fail to allocate. Objects fade near the far distance; the fade is applied only at final draw, never baked into cached rasters.
- **Render quality** (`engine/quality/`, `docs/render-quality.md`): any constant trading quality for speed belongs in `BGE.RenderQualitySettings` with a value at all five levels in `RenderQualityPresets.bs` (current value at Ultra if already best quality, else Medium), read via `rendererObj.qualitySettings`. `RenderQualityPresets.spec.bs` enforces completeness and monotonicity — extend it. `setQualitySettings()` bumps `qualityVersion` so cached drawings redraw.
- **Lighting** (`renderer/lighting/`, `Game.addLight()`): directional/point/ambient `BGE.Light`s on the game renderer shade `isShaded` drawables; with none, shading is camera-facing as before. `Renderer.updateLighting()` diffs a value signature each frame and bumps `lightingVersion`, which `SceneObject.lightingChangedThisDraw` turns into a relight; a model skips the redraw if no face's shaded color changed, and an impostor absorbs light changes within `modelImpostorMaxAngleDegrees`/`modelImpostorMaxLightChange` of its capture. Planes (`isShaded`) are tinted at the final blit, except a `tiledImage` plane with a ranged point light's pool in view: then all its lighting is drawn into the top-down bitmap (pools blended over a kept lit copy, so a lamp moving alone skips the texture warp), within `planeLightPoolMaxDriftPixels`/`planeLightPoolMaxLightChange`. Pools never switch off with quality, so adaptive quality can't make lights blink.
- `SceneObjectPlane` (ground planes, `fillMode` `color`/`tiledImage`/`staticImage`) and `SceneObjectSkybox` handle camera roll by rendering unrolled then rotating.

Device-confirmed renderer gotchas (headless brs-engine can't see most of these):

- Never pass a negative scale together with a nonzero rotation to a native draw call — real Roku only mirrors at rotation 0.
- `ScratchBitmapPool` bitmaps are not cleared on reuse — clear before drawing into them. They are never reused within a frame (mid-frame reuse breaks warps on device), and scratch regions must start at their bitmap's (0,0).
- Roku silently drops all draws into a bitmap once ~13,000 queue in a frame. Keep loops well under that.
- HD devices have only 64MB of texture memory (`rokubot textures` to inspect); FHD scratch bitmaps are ~4.5MB each.
- `Renderer` enables alpha on its target; without it, transparent corners blit as black.
- Never `Finish()` an `roScreen` the game draws to directly — it presents the frame early and the UI flickers.
- Draw costs vary by >10x between operations and aren't predictable from code. Never assert one path is faster — measure it (`rendererTest` times every demo; see `quad-fill-benchmark`). Keep blocking setup work short or the OS watchdog kills the channel.

`examples/rendererTest`: add a demo by subclassing `RendererTest` under `Tests/` and adding one entry to `DemoList.bs`. Its loop uses `port.GetMessage()` — `wait(0, port)` waits forever. Cache expensive `drawPinnedCorners` loops into a bitmap in `setup()`.

### UI (`engine/ui/`)

Retained-mode widget tree on its own canvas: `Game.gameUi` and `Game.debugUi` (`enableStandardDebugUi()` adds the standard debug windows). `UiContainer.onInput()` broadcasts to all children; focus is global via `Game.focusManager` (`FocusManager`), driven once per input event. The focused widget gets first refusal through `handleInput() as boolean`. `FocusNavigationMode.list` (default) steps through widgets in `addChild()` order; `pointer` uses a virtual cursor, optionally analog (`analogAxisName`). `debugUi` never captures input and is never blocked by another capture. Widgets register for focus as soon as they're added to any focus-enabled container, so build modal panels fresh on show and tear them down on hide (`BGE.UI.MessagePanel` does this). Theme via `Game.defaultTheme` or `UiContainer.theme`.

### Collision (`engine/colliders/`)

- `CircleCollider`/`RectangleCollider` use `roCompositor.CheckMultipleCollisions()`. `onCollisionEnter`/`onCollisionExit` are diffed per frame.
- Edge-to-edge contact is not an overlap: snapping flush stops `onCollision` next frame, so "reset grounded every frame" flickers.
- `SphereCollider3d`/`BoxCollider3d` do true 3D overlap (two compositor planes plus exact maths). `Game.raycast()`/`raycastAll()` return `BGE.RaycastHit`.
- `resolveAabbTileCollision()` (tile platformers) and `BGE.SolidWorld.moveAndSlide()` (top-down) resolve against static geometry.

### Other

- `math/`: `BGE.Math.VectorOps`, `Matrix44`, `CornerPoints`, etc. are used everywhere instead of raw AAs.
- `utils/`: OBJ/STL parsers (`Game.load3dModel`, textured `.obj` with materials), tweens, `MotionChecker`, `TagList`, registry helpers, auto-tiling (`utils/tilemap/AutoTile.bs`), `CountdownTimer` (dt-driven; distinct from wall-clock `GameTimer`).
- `story/`: `BGE.Story` — UI-free dialogue/flags/inventory runner (`docs/story.md`). `goto`/`call`/`end` are reserved words (use brackets / quoted keys); ids can't contain `#` or `/`. If bsc misreads a `StoryData` literal against `Items()`, add `items: {}`.
- Music: `Game.musicPlay(path, loop, restart = true)` — pass `restart = false` to keep a shared track playing across scenes; `roAudioPlayer` can't fade. `Game.changeSceneWithFade()` for transitions.
- `Camera2d.follow()`/`setBounds()` apply in `checkMovement()` after updates — set camera targets in `onUpdate`, not `onDrawBegin`.

## Conventions

- `bslint.json`: no single-line `if` (`inline-if-style: never`).
- **Always `import` files whose symbols you use**, even though `source` scope compiles without it — SceneGraph component scopes aren't ambient and fail with `cannot-find-name`.
- Doc comments (`'` JSDoc with `@param`/`@return`) are for engine consumers; implementation rationale goes in inline comments. Keep inline comments short.
- **Prefer real types** (classes, `interface X extends roAssociativeArray`, native types, typed casts) over `as object`/`as dynamic`. Options bags are interfaces with `optional` fields (iterate `.Keys()`, not the interface). Callback types written as `sub(...)` need an explicit `as void`. bsc has no `invalid` in unions — use `as dynamic`. Cast computed integers to enum types explicitly.
- **`=` between two objects (class instances, `roRegion`, `roBitmap`, …) crashes at runtime** with Type Mismatch; bsc doesn't catch it and casting doesn't help. Compare an id or scalar field.
- **bsc self-reference bug**: a namespace function returning, or a method taking a parameter typed as, a class defined in the same file can corrupt type resolution elsewhere in that file. Put such functions in a separate file, or type the param `as object`.
- `GetRemoteID()` returns names like `"BT:1"`/`"IR:1"`, not numbers; only trust `GetValue(axis)` analog data for `"BT:"` remotes.
- A typed keyboard character arrives as its own press/release events (`GetChar() <> 0`) whose codes collide with buttons; `BGE.getControlEventKind()` routes them to `onECPKeyboard()` only. Backspace/Enter arrive as buttons.
- Package paths are case-insensitive: don't name an example folder `source/story` (it collides with the engine's).
- Keep example UI title-safe (≥10% from canvas edges).
- Keep `brightscript.projects` in `.vscode/settings.json` to ≤10 entries (the language server runs out of heap); always keep the root `bsconfig.json`.
