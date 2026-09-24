# Changelog

All notable changes to this project are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. This project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.7.0] - 2026-09-24

### Changed (breaking)

`BGE.Room` is now `BGE.GameScene` ([#227](https://github.com/markwpearce/brighterscript-game-engine/issues/227)). "Room" never described what it is - the current state of your game, whether that's a title screen, a menu, or a level. The renderer's own "scene" methods were renamed at the same time so the word only means one thing. This is a clean break with no deprecated aliases. The class is `GameScene`, matching `GameEntity`/`GameInput`; the methods, fields and folders that refer to it just say "scene".

| Old | New |
|---|---|
| `BGE.Room` | `BGE.GameScene` |
| `Room.persistDrawablesAcrossRoomChange` | `GameScene.persistDrawablesAcrossSceneChange` |
| `GameEntity.onChangeRoom(newRoom)` | `GameEntity.onChangeScene(newScene)` |
| `Game.defineRoom()` / `changeRoom()` / `resetRoom()` | `Game.defineScene()` / `changeScene()` / `resetScene()` |
| `Game.getRoom()` / `getRoomNames()` / `isRoomChanging()` | `Game.getScene()` / `getSceneNames()` / `isSceneChanging()` |
| `Game.currentRoom` / `currentRoomArgs` / `Rooms` | `Game.currentScene` / `currentSceneArgs` / `Scenes` |
| `Renderer.drawScene()` | `Renderer.render()` |
| `Drawable.addToScene(renderer)` / `removeFromScene(renderer)` | `Drawable.addToRenderer(renderer)` / `removeFromRenderer(renderer)` |
| `npm run create-room` | `npm run create-scene` (writes to `Scenes/`) |

Most leftover uses of the old names fail to compile. The exception: an `override sub onChangeRoom(...)`, `override function addToScene(...)` or `override sub removeFromScene(...)` in your own classes **still compiles but is never called**. Search your project for those three names and rename them.

`SceneObject` and `Renderer.addSceneObject()`/`removeSceneObject()`/`getSceneObjects()` are unchanged.

### Changed

- `Game.Play()` now processes `gameUi` input *before* entity input (it used to run after), so a focused widget can call `GameInput.consume()` to keep an event from also reaching `GameEntity.onInput()` that frame ([#133](https://github.com/markwpearce/brighterscript-game-engine/issues/133)).
- UI focus is now global: one `Game.focusManager` (`BGE.UI.FocusManager`) owns focus across every container, and defaults to list navigation (d-pad steps through widgets in `addChild()` order). Pointer/cursor navigation is opt-in via `focusManager.navigationMode` ([#178](https://github.com/markwpearce/brighterscript-game-engine/issues/178)).
- Remotes, simulator gamepads and browser controllers now share one `playerIndex` pool instead of remotes being hardcoded to `-1` ([#216](https://github.com/markwpearce/brighterscript-game-engine/issues/216)).
- The `DrawTransformedObject` polyfill is gone; the engine uses the native call, which is fixed as of Roku OS 15.3.
- `Camera3d.maxDrawDistance` is now an engine-wide far-clip honored by every `SceneObject`, capped per device tier ([#124](https://github.com/markwpearce/brighterscript-game-engine/issues/124)).
- `DrawableText.alignment` is now shorthand for `anchor.x` (see anchoring below); this also fixes right-aligned text being offset by its height instead of its width.

### Added

**Rendering**
- Configurable `anchor` on every `Drawable` (`setAnchor(x, y)`) ([#50](https://github.com/markwpearce/brighterscript-game-engine/issues/50)).
- `DrawableCircle`/`DrawableSphere` ([#100](https://github.com/markwpearce/brighterscript-game-engine/issues/100)), with a fast rotate+scale fill path in oriented modes ([#105](https://github.com/markwpearce/brighterscript-game-engine/issues/105)); `Renderer.drawCircle()` and `drawRoundedRectangle()` ([#102](https://github.com/markwpearce/brighterscript-game-engine/issues/102)).
- Particle system: `DrawableParticles` ([#86](https://github.com/markwpearce/brighterscript-game-engine/issues/86)).
- Parallax/scrolling background layers: `DrawableParallaxLayer` and `BGE.newFullHeightParallaxLayer()` ([#67](https://github.com/markwpearce/brighterscript-game-engine/issues/67), [#203](https://github.com/markwpearce/brighterscript-game-engine/issues/203)).
- Skybox: `DrawableSkybox`/`SceneObjectSkybox` ([#65](https://github.com/markwpearce/brighterscript-game-engine/issues/65)).
- `DrawablePlane.fillMode` (`color`/`tiledImage`/`staticImage`) for composable ground planes ([#53](https://github.com/markwpearce/brighterscript-game-engine/issues/53)), and `Camera3d.rollDegrees`.
- Textured `.obj` model loading via `Game.load3dModel` ([#89](https://github.com/markwpearce/brighterscript-game-engine/issues/89)).
- `DrawableOrientedSprite`: Doom-style angle-based sprite billboards ([#104](https://github.com/markwpearce/brighterscript-game-engine/issues/104)).
- Smarter depth sorting: sort skipped when nothing moved, stable tie-breaks, and opt-in overlap clusters that interleave model faces ([#59](https://github.com/markwpearce/brighterscript-game-engine/issues/59)).
- Static geometry: `GameEntity.isStatic` marks level geometry that is drawn through a BSP tree, so dynamic objects sort correctly between walls ([#107](https://github.com/markwpearce/brighterscript-game-engine/issues/107)).
- Tilemap baking into chunked images: `BGE.TileMap.bakeTileMapImages()`.
- `GameEntity.isOnScreen()` ([#75](https://github.com/markwpearce/brighterscript-game-engine/issues/75)).
- SceneGraph shape components (`src/components/Shapes`: `Circle`, `Polygon`, `RoundedRectangle`) that render with `BGE.Renderer` ([#61](https://github.com/markwpearce/brighterscript-game-engine/issues/61)).
- `BGE.QrCode`.

**Collision**
- 3D collision: `SphereCollider3d`/`BoxCollider3d` ([#131](https://github.com/markwpearce/brighterscript-game-engine/issues/131)).
- Raycasting: `Game.raycast()`/`raycastAll()` ([#225](https://github.com/markwpearce/brighterscript-game-engine/issues/225)).
- `BGE.resolveAabbTileCollision()` for platformer/top-down tile collision ([#204](https://github.com/markwpearce/brighterscript-game-engine/issues/204)).

**UI**
- New widgets: `Button`, `Checkbox`, `Select` (inline, horizontal and popup styles), `TextInput`, plus `Slider` on the new focus system ([#133](https://github.com/markwpearce/brighterscript-game-engine/issues/133), [#179](https://github.com/markwpearce/brighterscript-game-engine/issues/179), [#181](https://github.com/markwpearce/brighterscript-game-engine/issues/181), [#192](https://github.com/markwpearce/brighterscript-game-engine/issues/192)).
- `BGE.UI.Theme` (`Game.defaultTheme`, per-container override).
- 9-patch / image widget backgrounds ([#180](https://github.com/markwpearce/brighterscript-game-engine/issues/180)) and an analog-stick-driven cursor ([#182](https://github.com/markwpearce/brighterscript-game-engine/issues/182)).
- `BGE.UI.MessagePanel` for pause/game-over screens ([#202](https://github.com/markwpearce/brighterscript-game-engine/issues/202)).
- `Button` can play a `Game.loadSound()` key on focus/click (`Button.focusSoundKey`/`clickSoundKey`), falling back to a game-wide default (`Game.uiFocusSoundKey`/`uiClickSoundKey`) when unset.

**Input**
- External controllers through a browser-based bridge, with QR-code discovery ([#149](https://github.com/markwpearce/brighterscript-game-engine/issues/149), [#168](https://github.com/markwpearce/brighterscript-game-engine/issues/168)).
- Multiple simultaneous remotes and simulator gamepads (analog sticks, including the right stick) ([#216](https://github.com/markwpearce/brighterscript-game-engine/issues/216)).
- `Game.setCombineRemoteInputs()` to let either the remote or a gamepad drive player 0 in single-player games ([#220](https://github.com/markwpearce/brighterscript-game-engine/issues/220)).
- `ControlMap.getActionHeldTimeMs()` ([#171](https://github.com/markwpearce/brighterscript-game-engine/issues/171)); `bindAction()` accepts an array of button names.
- `GameInput.isButton()` accepts common button-name aliases ([#88](https://github.com/markwpearce/brighterscript-game-engine/issues/88)).
- `BGE.FreeFlyCameraController`, a reusable free-fly 3D camera ([#148](https://github.com/markwpearce/brighterscript-game-engine/issues/148)).

**Utilities**
- `BGE.TweenManager` (`Game.tweenManager`): tweens on arbitrary fields ([#60](https://github.com/markwpearce/brighterscript-game-engine/issues/60)).
- `BGE.CountdownTimer` ([#205](https://github.com/markwpearce/brighterscript-game-engine/issues/205)).
- `Game.getEntitiesByTag()` ([#55](https://github.com/markwpearce/brighterscript-game-engine/issues/55)).
- `Game.enableStandardDebugUi()` ([#54](https://github.com/markwpearce/brighterscript-game-engine/issues/54)).
- `npm run check` / `check:all` ([#57](https://github.com/markwpearce/brighterscript-game-engine/issues/57)), and `create-entity` / `create-scene` scaffolding scripts ([#56](https://github.com/markwpearce/brighterscript-game-engine/issues/56)).

**Examples**
- New: `audio`, `collisions3d`, `controller`, `depthsort`, `http`, `parallax`, `particles`, `platformer`, `scenegraph`, `terrain`, `tweens`, `ui`.
- `breakout` and `asteroids` brought up to date with the new UI, input and effects.

### Fixed

- Draws into a renderer's surface could silently fail for large images: `Renderer.render()` now calls `Finish()` on its destination ([#211](https://github.com/markwpearce/brighterscript-game-engine/issues/211)).
- A single failed frame no longer leaves a stationary object invisible for good ([#48](https://github.com/markwpearce/brighterscript-game-engine/issues/48)); deterministic draw rejections now latch instead of retrying every frame ([#73](https://github.com/markwpearce/brighterscript-game-engine/issues/73)).
- Oriented draw modes applied a drawable's scale twice ([#49](https://github.com/markwpearce/brighterscript-game-engine/issues/49)).
- `Camera3d` frustum planes used edge directions as normals, so `isInView` was wrong at any FOV but 90 ([#70](https://github.com/markwpearce/brighterscript-game-engine/issues/70)).
- Seam between `drawPinnedCorners`' two triangles ([#110](https://github.com/markwpearce/brighterscript-game-engine/issues/110)); choppy model rotation ([#128](https://github.com/markwpearce/brighterscript-game-engine/issues/128)); model face draw order ([#112](https://github.com/markwpearce/brighterscript-game-engine/issues/112)).
- Particles drifting into view from an off-screen emitter stayed culled ([#114](https://github.com/markwpearce/brighterscript-game-engine/issues/114)).
- `Drawable.color` tint dropped for scaled, unrotated circles ([#197](https://github.com/markwpearce/brighterscript-game-engine/issues/197)).
- A scene's own drawables weren't cleaned up on scene change ([#144](https://github.com/markwpearce/brighterscript-game-engine/issues/144)).
- Drawables with no owner crashed ([#231](https://github.com/markwpearce/brighterscript-game-engine/issues/231)).
- `GetTweenObjectPercentState()` only worked for decreasing tweens ([#25](https://github.com/markwpearce/brighterscript-game-engine/issues/25)).
- `QuickHull([])` returned `[invalid, invalid]` ([#109](https://github.com/markwpearce/brighterscript-game-engine/issues/109)); `Game.getBitmap()`/`get3dModel()` could crash when returning `invalid` ([#127](https://github.com/markwpearce/brighterscript-game-engine/issues/127)).
- Several `FocusManager` seeding/navigation bugs ([#190](https://github.com/markwpearce/brighterscript-game-engine/issues/190), [#198](https://github.com/markwpearce/brighterscript-game-engine/issues/198)).
- Missing imports between engine files that broke SceneGraph component scopes ([#178](https://github.com/markwpearce/brighterscript-game-engine/issues/178)).
- The example template's `bsconfig.json` broke every example build except `scenegraph` ([#167](https://github.com/markwpearce/brighterscript-game-engine/issues/167)).

## [0.6.0] - 2026-07-24

### Added

- Central logging: `Game.log(message, level)` / `Game.getLogHistory()`, with a `BGE.Debug.LogLevel` enum (`info`/`warning`/`error`). Existing `print`-only warnings across `Game.bs`/`GameEntity.bs`/`Sprite.bs` now route through it, and previously-silent lookups (`getBitmap`, `get3dModel`, `getFont`, `getDrawable`, `getEntityByID`, `getEntityByName`, `getCollider`) now warn on a miss instead of returning `invalid` with no trace.
- `BGE.Debug.LogDisplay`, a new debug window: bottom-center, auto-scrolling to the latest entries, colored white/yellow/red by level. Wired into all examples alongside the existing `FpsDisplay`/`InputDisplay`/`MemoryDisplay`/`GarbageCollectorDisplay`.
- `DrawableText.textColor` field, enabling per-line text coloring (used by `LogDisplay`).
- A Rooibos (v6) unit test suite, colocated as `*.spec.bs` files, runnable headlessly in CI via `brs-cli` or on-device.
- `examples/breakout`.

### Fixed

- **`ropm install` now actually works for consumers.** Publishing raw `.bs` source (rather than the already-compiled `build/` output) produced ~1640 compile errors for any real consumer - see the [README's Installation section](README.md#installation) for the recommended `ropm.noprefix` + `roku_modules` `diagnosticFilters` consumer setup.
- `examples/hybrid`'s broken build (stale `getImage` call) and `examples/pixels`' room-navigation graph (two rooms were unreachable).
- `BGE.Colors`/`BGE.ColorsRGB` changed to enums.

### Changed

- Docs site (`docs-site/`) is now built and deployed via GitHub Actions on every push to `main`, rather than committing generated output.
- Hand-written guides (`docs/`) folded into the same sidebar as the API reference, instead of a bolted-on menu.

## [0.5.0] - 2026-07-16

### Added

- Renderer overhaul: `SceneObject`s for images, billboards, lines, polygons, text, and 3D models, with configurable draw modes (`matchCamera`, `directToCamera`, `oriented`, `wireframe`, `solid`, and back-face variants).
- Billboard shading and wireframe drawing for models and billboards.
- Triangle bitmap caching and other rendering performance improvements.
- `npm run create-example -- <name> ["Title"]` scaffolds a new example (manifest, bsconfig, generated icon/splash images, minimal `MainRoom`).
- `examples/quickstart`, matching the README's sample code.
- `validate`/`lint` required status checks on PRs to `main`; automated docs regeneration.

### Changed

- UI moved to its own dedicated canvas/layer, with `Drawable`s refactored accordingly.
- README rewrite: engine + standalone drawing-library pitch, runnable quick-start code sample, examples table, screenshots.
- Example tooling (`prepare-examples`, `build-examples`, `validate-examples`, `clean-all`, `create-example`) rewritten in plain Node, so it works on Windows without Git Bash/WSL.

[Unreleased]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/1.1...v0.5.0
