# Rename `Room` to `Scene` - Design

Issue: [#227](https://github.com/markwpearce/brighterscript-game-engine/issues/227)

## Goal

"Room" doesn't describe what the concept is. In this engine a Room is the current game state/screen: a title screen, a menu, a demo page, or a level (platformer's single `MainRoom` plays several levels from `LevelData`). Rename it to **`Scene`**, the term consumers already know from Godot/Unity/Phaser, across the engine, tooling, examples and every piece of documentation.

`Scene` currently collides with the renderer's own vocabulary (`Renderer.drawScene()`, `Drawable.addToScene()`), so the three renderer methods where "scene" means "the renderer's draw list" get renamed as well.

## Decisions

- **Name:** `Scene`, not `Level` (wrong for title screens/menus, and awkward next to platformer's `LevelData`) or `Stage`.
- **Renderer:** rename `drawScene()`/`addToScene()`/`removeFromScene()` (see naming map). Keep `SceneObject*` and `Renderer.addSceneObject()`/`removeSceneObject()`/`getSceneObjects()` - ~150 uses, including public `SceneObjectDrawMode` values, and "an object in the renderer's scene" reads fine next to `BGE.Scene`.
- **Migration:** clean break. No deprecated aliases, and no runtime detection of leftover overrides. The project is pre-1.0 with no known public consumers, so the CHANGELOG migration table is the whole migration story. The next release is 0.7.0.
- **Docs are in scope:** README, every guide under `docs/`, the SVG diagrams, CLAUDE.md, the rokubot skill, doc comments, tooling templates. Stale "Room" references left in docs count as unfinished work.
- **Historical records are not rewritten:** dated design docs and plans in `specs/` and `docs/superpowers/plans/` describe what was true at the time. They keep their Room references.

### Known compile-time behavior of the clean break

Confirmed with a scratch `bsc` build:

- Calls to removed methods/fields (`game.changeRoom()`, `m.currentRoom`, `super.onChangeRoom()`) fail with `cannot-find-function`/`cannot-find-name`, so most leftover consumer code breaks loudly.
- An `override sub onChangeRoom(...)` (or `override function addToScene(...)`) whose base method no longer exists **still compiles**, as an orphan method the engine never calls. The CHANGELOG entry calls this out explicitly so a consumer knows to search for these overrides. No runtime check is added (see Decisions).

## Naming map

### Engine (public, breaking)

| Old | New |
|---|---|
| `BGE.Room` (`engine/Room.bs`, `engine/Room.spec.bs`) | `BGE.Scene` (`engine/Scene.bs`, `engine/Scene.spec.bs`) |
| `Room.persistDrawablesAcrossRoomChange` | `Scene.persistDrawablesAcrossSceneChange` |
| `GameEntity.onChangeRoom(newRoom)` | `GameEntity.onChangeScene(newScene)` |
| `Game.defineRoom()` | `Game.defineScene()` |
| `Game.changeRoom()` | `Game.changeScene()` |
| `Game.resetRoom()` | `Game.resetScene()` |
| `Game.getRoom()` | `Game.getScene()` |
| `Game.getRoomNames()` | `Game.getSceneNames()` |
| `Game.isRoomChanging()` | `Game.isSceneChanging()` |
| `Game.currentRoom` | `Game.currentScene` |
| `Game.currentRoomArgs` | `Game.currentSceneArgs` |
| `Game.Rooms` | `Game.Scenes` |
| `Renderer.drawScene()` | `Renderer.render()` |
| `Drawable.addToScene(renderer)` | `Drawable.addToRenderer(renderer)` |
| `Drawable.removeFromScene(renderer)` | `Drawable.removeFromRenderer(renderer)` |

Every override of the renamed methods is renamed too: the 12 `addToScene` overrides across `engine/drawables/`, and `Room`'s own `onChangeRoom` override.

### Engine (internal, renamed for consistency)

| Old | New |
|---|---|
| `Game.roomChangedThisFrame` | `sceneChangedThisFrame` |
| `Game.roomChangeDetails` | `sceneChangeDetails` |
| `Game.handleRoomChange()` | `handleSceneChange()` |
| `interface RoomChangeInfo` (`room` field) | `interface SceneChangeInfo` (`scene` field) |
| params/locals `newRoom`, `thisRoom`, `roomName`, ... | `newScene`, `thisScene`, `sceneName`, ... |
| params `rendererScene`/`renderScene` (e.g. `Drawable.addToScene(rendererScene)`) | `renderer` |

Spec files' local names (`roomA`, `RoomB`, `TestRoom`, `firstRoom`, ...) follow the same pattern.

**Must not change:** `headroom` (comment in `Camera3d.bs`), `examples/terrain/src/sprites/SuperMarioKartMapMushroomCup1.png`.

### Tooling

| Old | New |
|---|---|
| `npm run create-room` (`package.json`) | `npm run create-scene` |
| `scripts/create-room.js` | `scripts/create-scene.js` |
| `scripts/templates/roomTemplate.bs` | `scripts/templates/sceneTemplate.bs` |
| `scripts/exampleTemplate/src/source/Rooms/MainRoom.bs` | `scripts/exampleTemplate/src/source/Scenes/MainScene.bs` |

Also update: `scripts/scaffold-class.js`, `scripts/create-example.js`, `scripts/create-entity.js`, `scripts/templates/entityTemplate.bs`, `scripts/exampleTemplate/src/source/{main,util}.bs`, `scripts/ropmConsumerFixture/src/source/main.bs`. The generated scene template writes into `Scenes/`, and its "next steps" output mentions `game.defineScene(...)`/`game.changeScene(...)`.

### Examples

Every `examples/<name>/src/source/Rooms/` becomes `Scenes/` (53 files, moved with `git mv`), and every `*Room` class becomes `*Scene`, with its `m.name` string and `defineScene()`/`changeScene()` arguments to match:

| Example | Old → new |
|---|---|
| 3d | `AnchorRoom`, `BaseRoom`, `CarRoom`, `CirclesRoom`, `CubesRoom`, `D20Room`, `ImagesRoom`, `ModelRoom`, `PolyRoom`, `RectanglesRoom`, `TextRoom`, `TreesRoom` → `*Scene` |
| asteroids, platformer | `MainRoom`, `TitleRoom` → `MainScene`, `TitleScene` |
| audio, breakout, canvas, collisions3d, controller, http, parallax, pong, quickstart, snake, tweens | `MainRoom` → `MainScene` |
| **hybrid** | `MainRoom` → **`GameScene`** (this example already has a SceneGraph component named `MainScene`, `components/Scenes/Main/MainScene.xml`) |
| depthsort | `ClusterVisualizerRoom`, `TieBreakRoom` → `*Scene` |
| particles | `AnimatedImageParticlesRoom`, `BurstRoom`, `ImageParticlesRoom`, `LineParticlesRoom`, `MovingEmitterRoom`, `RectangleParticlesRoom`, `StressRoom` → `*Scene` |
| pixels | `CircleRoom`, `GhostRoom`, `PolygonRoom`, `RectangleRoom`, `SpriteRoom` → `*Scene` |
| terrain | `MainRoom`, `WorldRoom` → `MainScene`, `WorldScene`; the `GuardPlacements`/`TreePlacements`/`WallPlacements` helper files move folders but keep their names |
| ui | `AnalogCursorRoom`, `ImageBackgroundRoom`, `MainRoom`, `NinePatchRoom`, `PopupSelectRoom`, `TextInputRoom` → `*Scene` |

Example-local helpers get renamed too (`getRoomNames()`/`goToNextRoom()` in 3d/pixels → `getSceneNames()`/`goToNextScene()`, `roomNames` locals, `main_room`-style locals, `currentRoom` params). Also update comments and on-screen hint text that says "room".

`examples/rendererTest` only changes its `renderer.drawScene()` calls to `renderer.render()`. Its private `resetScene()`/`timeDrawScene()` helpers in `StaticGeometryBspBenchmark.bs` are local to that class and stay as they are. `examples/scenegraph` is untouched (it has no BGE Rooms; its `MainScene`/`StressScene` are SceneGraph components).

### Documentation

Rewrite by hand, not find/replace, so prose still reads naturally (e.g. `Room.bs`'s class doc comment: "A Room is just a GameEntity that represents a distinct scene/level" needs rewording, not a word swap).

- `README.md`
- `docs/game-engine-overview.md`, `docs/engine-internals.md`, `docs/drawables-and-scene-objects.md`, `docs/controller-input.md`, `docs/qr-codes.md`, `docs/scenegraph-shapes.md`
- `docs/images/architecture-overview.svg`, `docs/images/game-loop.svg` (text labels)
- `game-engine-overview.md` gains a short note separating the three meanings of "scene": `BGE.Scene` (the current game state/screen), the renderer's `SceneObject`s (what gets drawn each frame), and Roku's SceneGraph `Scene` node (only relevant to hybrid/SceneGraph apps).
- Doc comments on every renamed engine symbol (these feed the generated API docs).
- `CLAUDE.md`: architecture sections (game loop, "Entities, Rooms, Drawables", renderer bullets mentioning `drawScene()`/`addToScene()`, example class names like `TieBreakRoom`), the commands list (`create-room` → `create-scene`).
- `.claude/skills/rokubot-examples/SKILL.md`: navigation-graph advice and per-example rows.
- `CHANGELOG.md`, under `[Unreleased]`: a **"Changed (breaking)"** section with the full public old → new table above, a note that the next release is 0.7.0, and an explicit warning that leftover `override sub onChangeRoom`/`override function addToScene`/`override sub removeFromScene` methods still compile but are never called, so consumers should search for them.

## Execution

A single PR on `refactor/issue-227-room-to-scene`. Engine, tooling, examples and docs change together, because a split would leave `main` with examples that don't build against the engine.

1. **Code, mechanically:** a throwaway script (scratchpad, not committed) applies the naming map as whole-word identifier replacements across `src/`, `scripts/` and `examples/*/src`, plus `git mv` for every file/folder rename so history follows. Then a manual pass over the diff for the cases that need judgment (the must-not-change list, the hybrid `GameScene` exception, string names, comments).
2. **Prose, by hand:** docs, README, CLAUDE.md, skill, doc comments, SVG labels, changelog.

## Verification

All must pass before opening the PR:

- `npm run check:all`: lint, validate (with and without tests), headless Rooibos suite, `validate-examples` for every example.
- `npm run docs` builds cleanly, and the generated site shows `Scene` with no `Room` class page.
- **Leftover grep:** a case-insensitive `room` grep over the repo (excluding `node_modules`, build outputs, `specs/`, `docs/superpowers/plans/`, `headroom`, and the `MushroomCup` asset) returns nothing.
- **On-device smoke run via rokubot** (CLAUDE.md treats this as mandatory for example changes): `3d` and `pixels` (scene cycling via `getSceneNames()`), `asteroids` and `platformer` (title → game transition), `depthsort`, `hybrid`, and `rendererTest` (for `render()`). Screenshot after each scene change. This checks that scenes load and switch, not gameplay.
- CI's `ropm-consumer-check` job passes with the updated consumer fixture.

## Out of scope

- Renaming `SceneObject*` or the other `Renderer` scene-object methods.
- Deprecated aliases or runtime migration warnings.
- Rewriting historical specs/plans.
- The pre-existing leak of `docs/superpowers/plans/` into the published docs site (separate issue).

## Revision (2026-09-24, after implementation)

The engine class is `BGE.GameScene` (file `engine/GameScene.bs`), not `BGE.Scene`, to match the engine's existing `GameEntity`/`GameInput`/`GameTimer` naming and to read unambiguously next to `SceneObject` and SceneGraph's `Scene` node. Everything else that refers to it keeps saying "scene": `Game.defineScene()`/`changeScene()`/`resetScene()`/`getScene()`/`getSceneNames()`/`isSceneChanging()`, `currentScene`/`currentSceneArgs`/`Scenes`, `onChangeScene()`, `persistDrawablesAcrossSceneChange`, `SceneChangeInfo`, `Scenes/` folders, `npm run create-scene`. This was a readability/consistency choice, not a name-conflict fix: the class is namespaced (`BGE_GameScene`), so neither name could collide with consumer code. `examples/hybrid`'s own scene class became `BallGameScene` so it doesn't read as `GameScene extends BGE.GameScene`.
