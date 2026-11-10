---
paths:
  - "**/*.spec.bs"
  - "src/source/**/tests/**"
  - "scripts/run-tests-*.js"
  - "bsconfig.test.json"
---

# Rooibos v6 unit tests

- **One `@suite` class per `*.spec.bs`.** Two corrupt suite metadata (`ERROR RETRIEVING TEST SUITE DATA!!`).
- Needs `@describe` before the first `@it` (RBS2201).
- Can't stub native components (`roScreen`, `roCompositor`, `CreateObject`). Use a real `BGE.Game` (works headlessly) for `GameEntity`/`Game`/collider/`Canvas`/`GameScene`; `Renderer` only needs a real bitmap.
- **`assertEqual` is type-strict** (`1` ≠ `1.0`). `as dynamic` params and field assignments don't coerce; `fix()`/`cint()` → Integer, `abs()` → Float. Unsure? Run once, read types from the diff.
- Don't name a suite field `scene` (clashes with `rooibos.BaseTestSuite.scene`).
- Don't `assertEqual` objects that may be circular or hold natives; compare an id/marker.
- Exact times: `freeze()` the `GameTimer` before `addTime()` (`Sprite.advanceAnimationClockForTests()` does), or CI drift breaks it.
- Network fakes: override `DownloadTask.createTransfer()`/`createPort()` or `AssetLoader.newDownloadTask()`; swap in `tests.FakeTextureLoader`.
- Tests cover engine code only; example runtime code needs an on-device/simulator run.
- Iterating on one test: tag it `@only`, full `npm run check` at the end.
