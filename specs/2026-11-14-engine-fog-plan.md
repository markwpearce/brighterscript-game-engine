# Engine Fog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fog as a `Camera3d` feature: a fog-coloured backdrop behind everything, and opted-in models and level walls that keep blocking the sky in fog colour past the draw distance.

**Architecture:** `BGE.Fog` settings hang off `Camera3d.fog`. `Renderer.render()` gains two stages: the backdrop after the skybox, and screen-box silhouettes for casters after the planes. `SceneObjectWalls` walks out to `silhouetteReach` × the draw distance and draws far pieces as white columns tinted the fog colour.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 headless tests, rokubot for device runs.

**Spec:** `specs/2026-11-14-engine-fog-design.md`

## Global Constraints

- `Fog.color` is RGB (`0xRRGGBB`); draw calls take RGBA: `(color << 8) + alpha`.
- Defaults: `enabled false`, `color &h808080`, `backdropHeight 0`, `silhouetteReach 2.0`, `silhouetteStartAlpha 0.5`.
- Fog disabled (or a `Camera2d`): both new stages return after one field read; no allocations, no draw calls.
- Stage names `fogBackdrop` and `fogSilhouettes` (Renderer.profileStages).
- Frame order: skybox → fog backdrop → planes → fog silhouettes → walls → sorted objects.
- The backdrop fills only from its top down to the ground's far edge + 4 px, never to the frame bottom.
- No fade or fog baked into cached rasters; no `as object`/`as dynamic` where a real type exists; no single-line `if`; `import` what you use.
- Performance bar: ideally within ~0.5 fps of no fog at the same draw distance; a 2-5% drop is OK if it looks better.
- Run `npm run check` after each engine task; it must pass.

## Review Focus

- Camera looking straight up/down (flat forward degenerate): backdrop and silhouettes draw nothing, and there's no crash. Test in Task 2.
- A caster straddling the camera plane (some bounding points behind): its box comes from the points in front only, with no garbage rect. Test in Task 3.
- `Fog.color` changed while the camera is still: the cached boxes redraw in the new colour next frame. Test in Task 3.
- Fog turned on mid-run for walls whose walk is cached with the camera still: the walls walk again out to the reach. Test in Task 4.
- `drawDistanceFadeFraction = 0`: a caster past the draw distance gets a solid box, and one inside gets none. Test in Task 3.

---

### Task 1: Fog settings and the caster flag

**Files:**
- Create: `src/source/engine/renderer/Fog.bs`
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs` (add `fog` field, import)
- Modify: `src/source/engine/drawables/Drawable.bs` (add `castsFogSilhouette`, next to `isOccluder`)
- Test: `src/source/engine/renderer/Fog.spec.bs`

**Interfaces:**
- Produces: `class BGE.Fog` with `enabled as boolean`, `color as integer`, `backdropHeight as float`, `silhouetteReach as float`, `silhouetteStartAlpha as float` (defaults above, JSDoc per the spec); `Camera3d.fog as BGE.Fog = new BGE.Fog()`; `Drawable.castsFogSilhouette as boolean = false`.

- [ ] **Step 1: Write failing tests** `@suite("BGE.Fog")`, `@describe("defaults")`:
  - `"is off with no backdrop and a 2x reach"`: `f = new BGE.Fog()`; `assertFalse(f.enabled)`, `assertEqual(&h808080, f.color)`, `assertEqual(0.0, f.backdropHeight)`, `assertEqual(2.0, f.silhouetteReach)`, `assertEqual(0.5, f.silhouetteStartAlpha)`.
  - `"is on every Camera3d"`: `assertNotInvalid((new BGE.Camera3d()).fog)` and `assertFalse(cam.fog.enabled)`.
  - `"is off on every drawable"`: a `BGE.DrawableRectangle(invalid, ...)` has `castsFogSilhouette = false`.
- [ ] **Step 2:** `npm run check` → the new tests fail (unknown type).
- [ ] **Step 3:** Add the class and fields.
- [ ] **Step 4:** `npm run check` → PASS.
- [ ] **Step 5:** Commit `Fog settings on Camera3d, castsFogSilhouette (#520)`.

### Task 2: The fog backdrop

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs` (`render()` after the skybox stage; new private `drawFogBackdrop()`)
- Test: `src/source/engine/renderer/RendererFog.spec.bs` (new suite `BGE.Renderer - fog`)

**Interfaces:**
- Consumes: `Camera3d.fog`, `Camera3d.getCurrentDrawDistance()`, `getPlaneDrawDistance()`, `worldPointToCanvasPoint()`.
- Produces: stage `fogBackdrop`; test helpers in the suite: `pixelAt(x, y) as integer` (RGBA from `bitmap.GetByteArray(x, y, 1, 1)`), `newCamera()` (eye 50 up, level, looking -z, fov 90, draw distance 1000, fade 0.15, transition 0), `renderFrames(n)`.

- [ ] **Step 1: Write failing tests** (1280×720 alpha bitmap target cleared to `&h000000FF` each frame; no skybox, so "sky" is that black):
  - `"draws nothing when fog is off"`: render 2 frames, `assertEqual(0, renderer.drawCallsLastFrame)` (empty scene); `pixelAt(640, 300)` black.
  - `"fills from the fog's top down to where the ground ends"`: `fog.enabled = true`, `color = &h1C2842`, `backdropHeight = 200`; render; the pixel just above the horizon (`640, 355`) is `&h1C2842FF`, a pixel well above the backdrop's projected top (`640, 100`) is black, and the bottom row (`640, 715`) is black (not filled to the frame bottom).
  - `"draws nothing looking straight down"`: orientation `(0, -1, 0)` → no draw call, no crash.
- [ ] **Step 2:** `npm run check` → FAIL.
- [ ] **Step 3:** Implement `private sub drawFogBackdrop()` as the spec's Backdrop section: flattened forward, `top` at `currentDrawDistance` and y = `backdropHeight`, `foot` at `getPlaneDrawDistance()` and y = 0, one `m.draw2d.DrawRect` clamped to the frame, `m.drawCallsLastFrame++`. Call it in `render()` straight after the skybox stage, then `lap = m.lapStage("fogBackdrop", lap)`. Return early when `m.camera.name <> "Camera3d"` or not `fog.enabled` or `backdropHeight <= 0`.
- [ ] **Step 4:** `npm run check` → PASS.
- [ ] **Step 5:** Commit `Fog backdrop (#520)`.

### Task 3: Silhouettes for casters

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs` (caster list, flag sync in `updateSceneObjects()`, `drawFogSilhouettes()` after the planes stage)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (`fogCasterFlagSeen as boolean = false`, beside `occluderFlagSeen`)
- Test: `src/source/engine/renderer/RendererFog.spec.bs`

**Interfaces:**
- Consumes: Task 1 fields; `SceneObject.distanceFadeAlpha`, `negDistanceFromCamera`, `depthChangedThisFrame`, `getBoundingPoints(camera)`; `Camera3d.projectPointsWithDepth(points, out, true)` (behind points get depth `BGE.PROJECTED_BEHIND_CAMERA_DEPTH`).
- Produces: stage `fogSilhouettes`; `Renderer.fogSilhouettesProjectedLastFrame as integer` (casters projected last frame; 0 when the cache replayed), read by tests; `Renderer.fogSilhouettesDrawnLastFrame as integer`.

- [ ] **Step 1: Write failing tests** (casters are `BGE.DrawableRectangle`s on a static entity standing on the ground, 100 wide × 300 tall, `drawMode` oriented, facing the camera; fog on, backdrop 0, reach 2):
  - `"leaves fog colour where a caster past the draw distance stands"`: caster at z = -1500 → its projected centre pixel is the fog colour; `fogSilhouettesDrawnLastFrame = 1`.
  - `"leaves the sky for a drawable that doesn't cast"`: the same without the flag → black, drawn 0.
  - `"draws nothing for a caster past the reach or behind the camera"`: z = -2500 and z = +500 → drawn 0.
  - `"draws no box while the caster is still mostly opaque"`: z = -500 (inside the draw distance, alpha 1) → drawn 0.
  - `"fades the box in as the caster fades out"`: a caster whose `distanceFadeAlpha` is 0.25 (place it in the fade band) → box drawn with alpha `&h80` (1 - 0.25 / 0.5 = 0.5 → `int(0.5 * 255)`): check via the pixel blending over black, or expose the last rgba drawn; pick one and assert it.
  - `"draws a solid box with fading off"`: `drawDistanceFadeFraction = 0`, caster at -1500 → fog colour; at -500 → drawn 0.
  - `"boxes only the points in front of the camera"`: a caster spanning z = +50..-1500 (a long rectangle rotated along z, flag on, past the draw distance by its depth point): no crash, and the box stays within the frame.
  - `"repeats the boxes while the camera is still"`: frame 1 `fogSilhouettesProjectedLastFrame = 1`, frame 2 `= 0` and drawn still 1; move the camera 5 units → projected 1 again.
  - `"redraws the boxes in a new fog colour with the camera still"`: change `fog.color` after frame 2 → frame 3's pixel is the new colour.
  - `"notices a caster flag set after adding"`: add without the flag, render, set `castsFogSilhouette = true`, render → drawn 1.
- [ ] **Step 2:** `npm run check` → FAIL.
- [ ] **Step 3:** Implement:
  - In `updateSceneObjects()`, beside the `isOccluder` sync: `if drawable.castsFogSilhouette <> sceneObj.fogCasterFlagSeen` → update the flag and mark the caster list dirty. Rebuild the list (`private fogCasters as SceneObject[]`) lazily in `drawFogSilhouettes()` when dirty; adding/removing a scene object also marks it dirty.
  - `private sub drawFogSilhouettes()` per the spec's Silhouettes section: alpha `a` = `distanceFadeAlpha`, or with `drawDistanceFadeFraction <= 0` 0 past the draw distance and 1 inside; draw when `a < silhouetteStartAlpha` and `0 < depth < far * silhouetteReach`; box from the points with depth ≠ `PROJECTED_BEHIND_CAMERA_DEPTH`; alpha byte `int((1 - a / silhouetteStartAlpha) * 255)`; skip boxes off the frame or with alpha byte 0.
  - Cache: keep rects as a flat `float[]` (x, y, w, h) plus an `integer[]` of rgba; replay them when none of these changed since the last frame: camera `motionChecker.movedLastFrame`, `farDistanceChangedThisFrame()`, frame size, any `Fog` field (keep the last values), the caster list, any caster's `depthChangedThisFrame`.
- [ ] **Step 4:** `npm run check` → PASS.
- [ ] **Step 5:** Commit `Fog silhouettes for drawables that cast them (#520)`.

### Task 4: Level walls past the draw distance

**Files:**
- Modify: `src/source/engine/renderer/walls/WallsView.bs` (`update()` takes an optional far limit)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectWalls.bs` (far walk, fog strips, crossfade, walk key)
- Test: `src/source/engine/renderer/RendererWalls.spec.bs` (new `@describe("fog")` in the existing suite)

**Interfaces:**
- Consumes: Task 1 fields (the walls drawable's `castsFogSilhouette`), `camera.fog`.
- Produces: `WallsView.update(camera as BGE.Camera3d, stripWidth as integer, farDistance = 0 as float) as boolean`, where 0 means `camera.getCurrentDrawDistance()`; `SceneObjectWalls.fogStripsDrawnLastFrame as integer`.

- [ ] **Step 1: Write failing tests** (the suite's `across(z, top)` walls; fog on, colour `&h1C2842`, reach 2; the camera draw distance 1000, fade 0.15; the walls drawable `castsFogSilhouette = true`):
  - `"draws a wall past the draw distance in fog colour"`: `across(-1500, 300)` → a pixel on the wall's projected middle is `&h1C2842FF`; above its top it's black; `fogStripsDrawnLastFrame > 0`.
  - `"draws nothing past the draw distance without the flag"`: same wall, flag off → black there, `stripsDrawnLastFrame = 0`.
  - `"crossfades a wall late in the fade band"`: a wall at the depth where its fade alpha is ~0.25 → both a fog strip and the textured strip are drawn on a ray (`fogStripsDrawnLastFrame > 0` and `stripsDrawnLastFrame > fogStripsDrawnLastFrame`).
  - `"walks again when fog is turned on with the camera still"`: render 2 frames with fog off (wall at -1500 not drawn), turn fog on, render 1 → fog strips drawn.
  - `"still hides objects behind near walls"`: the existing hide test still passes with fog on (no change to `rayCloseDepth` semantics within the draw distance).
- [ ] **Step 2:** `npm run check` → FAIL.
- [ ] **Step 3:** Implement per the spec's walls section:
  - `WallsView.update()` passes `farDistance` (or the draw distance when 0) to `cullParts()`.
  - `SceneObjectWalls`: `private function getWalkFar(camera) as float` (draw distance × reach when the camera's fog is enabled, the reach > 0 and `drawable.castsFogSilhouette`, else the draw distance). Store it in the walk key (`keyFar`) and compare it in `viewMatches()`/`walkSettingsMatch()` in place of `getCurrentDrawDistance()`.
  - A white column: one `roBitmap` 1×64 cleared `&hFFFFFFFF`, one `roRegion` with pre-translation `(0, -64)` like `DrawableWalls.buildColumns()`; scale y = `pieceLength / 64`.
  - In `shadePieces()`, per piece also compute `fogRgba` (0 = none): past the draw distance → `(color << 8) + &hFF` and the textured column is dropped; past where the fade alpha drops below `silhouetteStartAlpha` → fog rgba at the crossfade alpha, textured kept. Fog changes invalidate the shade cache like a tint change.
  - In `drawPieces()` and `redrawStrips()` (which only redraws near pieces, so never fog-only ones), draw the fog strip first, then the textured one.
- [ ] **Step 4:** `npm run check` → PASS.
- [ ] **Step 5:** Commit `Level walls stay in fog colour past the draw distance (#520)`.

### Task 5: rendererTest fog demo and benchmark

**Files:**
- Create: `examples/rendererTest/src/source/Tests/FogTest.bs` (`demo=fog`, category Drawing)
- Create: `examples/rendererTest/src/source/Tests/FogBenchmark.bs` (`demo=fog-benchmark`, category Benchmarks)
- Modify: `examples/rendererTest/src/source/DemoList.bs`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1:** `FogTest`: a skybox, a coloured ground plane, a row of 12 tall rectangles at 0.5× to 2× the draw distance (alternate ones cast), and a ring of level walls (castsFogSilhouette) of radius 1.5× the draw distance. `select` cycles fog off / backdrop / backdrop + silhouettes (shown on screen, title-safe); `up`/`down` step the draw distance by 250; `left`/`right` turn the camera.
- [ ] **Step 2:** `FogBenchmark`, after `WallsBenchmark`'s phase pattern: phases for mode (off / backdrop / full) × draw distance (500 / 1000) × casters (10 / 50 / 200), each with `warmupFrames 5`, `timedFrames 60`, still then orbiting; print `FOG mode=<m> draw=<d> casters=<n> motion=<still|orbit> ms=<avg> calls=<avg>`, then a live view.
- [ ] **Step 3:** `npm run check:all` → PASS. Run both on the device (`npm run run-example -- rendererTest demo=fog`, then `demo=fog-benchmark`). Screenshot each mode; capture the `FOG` lines.
- [ ] **Step 4:** Commit `rendererTest: fog demo and benchmark (#520)`.

### Task 6: Docs, device check, engine PR

**Files:**
- Modify: the `docs/` guide that explains `Camera3d` draw distance and fade (find it with `grep -rln drawDistanceFadeFraction docs/`): add a "Fog" section, how-to first with a code example (backdrop, a caster, walls), costs as an aside.
- Modify: `.claude/rules/renderer.md`: one line on fog (stages, casters, walls).
- Modify: `specs/renderer-notes.md` if it covers the walls stage order.

- [ ] **Step 1:** Write the docs.
- [ ] **Step 2:** `npm run check:all` → PASS.
- [ ] **Step 3:** Device: the town on this branch with a temporary local deep link isn't part of this PR. Measure via the rendererTest benchmark only; the town measurement belongs to the town PR.
- [ ] **Step 4:** Open the PR (base `main`, title `Engine fog: backdrop, silhouettes, walls past the draw distance`, body in Mark's voice via the `pr-voice` skill, references #520 without closing it; the town PR closes it).

### Follow-up PR (not this plan's engine PR): the town switches

Branch from the engine PR's branch: `TownScene` uses `camera.fog` (colour from the current fog style, backdrop height tuned), buildings and the keep and the town wall cast silhouettes, `fog=bands` keeps the old bands, `draw=<metres>` deep link, draw distance picked from `perf=phases` at the square, gate (`at=17,29,0`) and orbit (`orbit=0.4`) at 44/30/22 m, screenshots for sign-off. Closes #520.
