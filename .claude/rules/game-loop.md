---
paths:
  - "src/source/engine/*.bs"
  - "src/source/engine/loading/**"
  - "src/source/engine/debug/**"
  - "src/source/engine/controller/**"
  - "src/source/engine/controllers/**"
  - "src/source/utils/controlEvents.bs"
---

# Game loop, entities, scenes, loading

Docs: `docs/engine-internals.md`, `docs/loading-assets.md`.

## `Game.Play()` per frame
1. Collect input/ECP/audio/URL events.
2. **UI input first** (`processUiInput`): a widget can `input.consume()` before `GameEntity.onInput()`.
3. Update entities (current scene first, then `sortedEntities` in reverse): input callbacks, `onUpdate`, velocity; then `tweenManager` (a tween beats velocity on the same field); then the scene's `onPostUpdate` (after-everyone-moved work, e.g. `BGE.separateCircles()`, follow cameras).
4. Collisions via `roCompositor` → `onCollision`.
5. Draw game canvas (`onDrawBegin`/`render()`/`onDrawEnd`), UI canvas, then `debugUi` (update+draw).
6. Swap buffers, periodic GC, apply any pending scene change.

Callbacks can delete entities or change scene mid-frame: re-check `isValidEntity()` after **every** callback in `Game.bs`. Internal `Game` state is fenced by `****BEGIN/END - For Internal Use****`.

## Entities and scenes
- `GameEntity`: hooks `onCreate`/`onUpdate`/`onCollision`/`onInput`/…/`onDestroy`; `position`/`velocity`/`rotation`/`scale`, colliders, drawables, tags. `isOnScreen()` is a signal only — off-screen entities still update.
- `GameScene` is a `GameEntity` for one game state. Scenes are reused: old one gets `onChangeScene()` then `onDestroy()` — remove its `gameUi` widgets there or buttons keep taking input. Non-persistent entities get `onChangeScene()` and are destroyed (no `onDestroy()`).
- Hit flashes (`Drawable.flash`) tick in `Game` before `onUpdate`, only while `GameEntity.hasActiveFlash`.
- Music: `Game.musicPlay(path, loop, restart = true)`; `restart = false` keeps a shared track across scenes. `roAudioPlayer` can't fade. `Game.changeSceneWithFade()` for transitions.

## Loading (`engine/loading/`)
`GameScene.onLoad(loader, args)` queues `LoadTask`s, run within `loadingBudgetMs` per frame behind a `LoadingScreen`; `onCreate` runs once the queue drains. Held entities get no callbacks meanwhile. Loaders accept http(s) URLs (cached under `cachefs:/bge/`); synchronous `Game` loaders don't. Bitmaps decode via `BGE.TextureLoader` (`roTextureManager`).

## Input (`GameInput`)
- `x`/`y` are world space, +y up (only the final canvas projection flips y).
- Fires on press **and** release — guard one-shots with `input.press and input.isButton(...)`.
- `GetRemoteID()` returns `"BT:1"`/`"IR:1"`; only trust `GetValue(axis)` analog data for `"BT:"`.
- Typed keyboard chars arrive as their own events (`GetChar() <> 0`) whose codes collide with buttons; `BGE.getControlEventKind()` routes them to `onECPKeyboard()` only. Backspace/Enter arrive as buttons.
