# Grid Walls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raycast (Wolfenstein/Doom-style) wall rendering for grid mazes as an ordinary
`Drawable`/`SceneObject` pair in the BGE renderer, correct with a camera that pitches, hiding
what's behind the walls.

**Architecture:** A text grid (`GridWallsMap`), a hit source that marches one ray through it
(`GridWallsRayCaster`), and a per-frame view (`GridWallsView`) that fans horizontal rays across
the camera's view and keeps their hits as a depth buffer indexed by ray. `SceneObjectGridWalls`
turns hits into leaning texture-column strips and draws them in a fixed renderer stage after the
planes. The renderer asks the view whether each sorted object (and each `drawWorld*` point) is
behind a wall. The depth buffer is in ground-plane terms (bearing and horizontal distance), so
it doesn't depend on pitch.

**Tech Stack:** BrighterScript, Rooibos v6 (headless via brs-engine), rokubot on the Roku Ultra
(192.168.41.102).

**Spec:** `specs/2026-11-05-grid-walls-design.md`

## Global Constraints

- Branch `engine/grid-walls`. No changes under `examples/thirdPerson`.
- A quality/speed constant belongs in `BGE.RenderQualitySettings` with a value at all five
  levels in `RenderQualityPresets.bs`, plus `RenderQualitySettingsOverrides`, and
  `RenderQualityPresets.spec.bs` extended (completeness and monotonicity).
- Strip width at Medium is 4 px. (Later decision, after Task 8b's measured optimisation: 8 px at Medium, presets [16, 8, 8, 4, 4], light interval [8, 4, 4, 2, 2].)
- Drawable colours are RGB; renderer draws take RGBA.
- Never pass a negative scale together with a nonzero rotation to a native draw call.
- Keep draws per frame well under ~13,000.
- Strong types, `import` what you use, concise comments, one `@suite` per spec file,
  `assertEqual` is type-strict, compare custom objects by `id` and never with `=`.
- A namespace function returning (or a method taking) a class defined in the same file trips
  the bsc self-reference bug. Put such code in classes or separate files.
- Camera inside open cells below the wall tops; roll treated as 0. Both are documented rules,
  not checked.
- Pitch range to support: 15° up to 35° down (thirdPerson's values).
- Frame rate and looks are verified on the Ultra, not asserted. Done = the `grid-walls` demo
  holds 20 fps at Medium with no gaps or drift and nothing showing through.
- Quality gate after every task: `npm run check` (redirect output to a file, read the tail).

## Review Focus

1. A ray exactly along a grid line, or a camera exactly on a cell edge or corner. The DDA must
   not divide by zero or loop forever. Test in Task 3.
2. A camera inside a solid cell, outside the grid, or in a map with no closed border. Outside
   counts as solid, so marching ends and nothing crashes. Test in Task 3.
3. An object partly behind the camera, or one whose points won't project. It's never judged
   hidden, and it draws as before. Test in Task 6.
4. The walls drawable disabled, removed or destroyed. Hiding stops that same frame, with no
   stale depth buffer. Test in Task 5.
5. Strip width changed by a quality change mid-run. The ray count and buffers resize, with no
   out-of-range index. Test in Task 4.

---

### Task 1: Quality settings

**Files:**
- Modify: `src/source/engine/quality/RenderQualitySettings.bs` (interface and overrides)
- Modify: `src/source/engine/quality/RenderQualityPresets.bs`
- Test: `src/source/engine/quality/RenderQualityPresets.spec.bs`

**Interfaces:**
- Produces: `RenderQualitySettings.gridWallStripWidth as integer` (screen pixels between
  rays at the horizon) and `RenderQualitySettings.gridWallLightInterval as integer` (strips
  per lighting sample; 1 = every strip). Both are optional in the overrides interface.

- [ ] **Step 1: Write the failing tests** in the presets spec:
  - `@it("puts the measured 4 px grid wall strips at Medium")` asserts
    `medium.gridWallStripWidth = 4`.
  - A monotonicity `@it` asserts, for each adjacent pair of levels,
    `higher.gridWallStripWidth <= lower.gridWallStripWidth` and
    `higher.gridWallLightInterval <= lower.gridWallLightInterval`.
- [ ] **Step 2:** `npm run check`. Expected: FAIL (`gridWallStripWidth` invalid, and the
  completeness test fails once the field exists at only some levels).
- [ ] **Step 3: Add the fields.** Starting values, from basic to ultra:
  - `gridWallStripWidth = [16, 8, 4, 4, 4]`
  - `gridWallLightInterval = [8, 4, 4, 2, 2]`

  Task 8 tunes them on device.
- [ ] **Step 4:** `npm run check`. Expected: PASS.
- [ ] **Step 5: Commit** with the message `Add grid wall quality settings`.

### Task 2: Strip draw benchmark and baseline (device)

This decides how strips are drawn before any engine drawing code exists, and records
before-timings for the regression check in Task 9.

**Files:**
- Create: `examples/rendererTest/src/source/Tests/GridWallStripBenchmark.bs`
- Modify: `examples/rendererTest/src/source/DemoList.bs`. Add id
  `grid-walls-strip-benchmark` in category "Benchmarks".

**Interfaces:**
- Produces: a ledger `Ruling:` line naming the strip draw method used in Task 5. It is one of:
  - `transformed` (`DrawTransformedObject`, one call per strip);
  - `stacked<N>` (upright `DrawScaledObject` pieces, N per strip);
  - `upright` (only if rotation is unaffordable and stacking too; the fallback named in the
    spec).

- [ ] **Step 1: Write the demo.** It builds a 64x128 striped texture bitmap in `setup()`, plus
  one 1 px column `roRegion` per texel column. Each phase is 60 frames of 320 strips across
  1280 px, each strip 360 px tall and 4 px wide, timed with `roTimespan` and printed as
  `PHASE <name>: <ms> ms/frame`. Phases:
  - upright `DrawScaledObject`;
  - `DrawTransformedObject` at 0°;
  - at a lean that grows from 0 at screen centre to 10° at the edges;
  - the same up to 30°;
  - 4 stacked upright pieces offset along a 30° lean.

  OK reruns. `up`/`down` picks a phase to draw live, so the on-screen frame rate shows the
  queued-draw cost.
- [ ] **Step 2:** `npm run validate-examples`. Expected: no diagnostics for rendererTest.
- [ ] **Step 3: Run on the Ultra.** Use `npm run run-example -- rendererTest
  demo=grid-walls-strip-benchmark`, capture the console with rokubot (the
  `rokubot-examples` skill), and read each phase's ms and the live fps per phase.
- [ ] **Step 4: Record a baseline.** Run demos `lighting`, `skybox`,
  `occlusion-scene-benchmark` and `plane-texture-scale` for 20 s each and record their
  on-screen fps/draw ms in the ledger as `Baseline:` lines.
- [ ] **Step 5: Rule and commit.** Ledger the ruling: transformed if the 30° phase holds
  60 fps live, otherwise the cheapest phase that does. Commit with the message `rendererTest:
  grid wall strip draw benchmark`.

### Task 3: Map and ray caster

**Files:**
- Create: `src/source/engine/renderer/gridWalls/GridWallsMap.bs`
- Create: `src/source/engine/renderer/gridWalls/GridWallsRayCaster.bs`
- Test: `src/source/engine/renderer/gridWalls/GridWallsMap.spec.bs`
- Test: `src/source/engine/renderer/gridWalls/GridWallsRayCaster.spec.bs`

**Interfaces:**
- Produces, in `GridWallsMap.bs`:
  - `interface GridWallsMapArgs`: `cellSize as float`, `wallHeight as float`,
    `origin as BGE.Math.Vector` (the -x/-z corner of cell (0,0); `origin.y` is the floor
    height), `solid as roAssociativeArray` (character → texture name), and
    `optional outsideTexture as string`.
  - `interface GridWallsCell`: `col as integer`, `row as integer`.
  - `class BGE.GridWallsMap`:
    - `sub new(rows as string[], args as GridWallsMapArgs)`;
    - fields `colCount`, `rowCount`, `cellSize`, `wallHeight`, `origin`;
    - `isSolid(col, row) as boolean`, true outside the grid;
    - `textureAt(col, row) as string`, `""` when open. Outside the grid it returns
      `outsideTexture`, or the texture of the alphabetically first `solid` key;
    - `cellAt(x as float, z as float) as GridWallsCell`, which uses floor and so can return
      cells outside the grid.

    Row 0 is -z and column 0 is -x. A character not in `solid` is open.
- Produces, in `GridWallsRayCaster.bs`:
  - `interface GridWallsHit`: `distance as float` (horizontal, along the unit ray),
    `x as float`, `z as float`, `u as float` (0..1), `texture as string`,
    `normalX as float`, `normalZ as float` (the face's outward normal, towards the open
    side), `col as integer`, `row as integer` (the solid cell hit).
  - `class BGE.GridWallsRayCaster`: `sub new(map as BGE.GridWallsMap)` and
    `function cast(originX as float, originZ as float, dirX as float, dirZ as float,
    maxDistance as float, hit as GridWallsHit) as boolean`. `dir` is unit length; `hit` is
    filled in place, so nothing is allocated per ray. Returns false (with `hit` untouched)
    when nothing is hit within `maxDistance`.
  - The rule for `u`: seen from the open side facing the wall, it runs 0 at the left edge
    to 1 at the right, where right is `(n.z, -n.x)` for outward normal `n`. No side mirrors.

- [ ] **Step 1: Write the failing tests.**
  - Map, using rows `["###", "#.#", "#A#"]` with `solid: {"#": "stone", "A": "door"}`,
    `cellSize: 6`, `origin` (-9, 0, -9):
    - `colCount = 3` and `rowCount = 3`;
    - `isSolid(1,1) = false`, `isSolid(-1,1) = true`, `isSolid(3,0) = true`;
    - `textureAt(1,2) = "door"` and `textureAt(1,1) = ""`;
    - `textureAt(5,5) = "stone"` (outside, alphabetical default) and `"door"` when
      `outsideTexture: "door"`;
    - `cellAt(0, 0)` = {col 1, row 1} and `cellAt(-9.0, -9.0)` = {col 0, row 0}.
  - Ray caster, on the same map from (0, 0):
    - looking -z (0, -1): `distance = 3.0`, `normalZ = 1.0`, `normalX = 0.0`, `row = 0`,
      `u = 0.5`, `texture "stone"`;
    - looking +z: `texture "door"`;
    - looking +x: `distance = 3.0`, `normalX = -1.0`;
    - from (-1.5, 0) looking -z: `u = 0.25`;
    - `maxDistance` 2 returns false;
    - an exact diagonal (0.7071, 0.7071) from the cell centre hits at distance about 4.243
      (3·√2, within 0.001) and terminates;
    - a ray from a point exactly on the cell edge x = -3 terminates;
    - from (100, 100), outside the grid, it hits at distance 0 (or returns true at once)
      without looping.
- [ ] **Step 2:** `npm run check`. Expected: FAIL (`GridWallsMap` not found).
- [ ] **Step 3: Implement.** Standard grid DDA in cell units, with steps of +1/-1 and
  `deltaDist = Abs(cellSize / dir)`. A zero component uses a huge delta (1e30), not a
  division. The march stops after `colCount + rowCount + 2` cells past leaving the grid, or
  at `maxDistance`.
- [ ] **Step 4:** `npm run check`. Expected: PASS.
- [ ] **Step 5: Commit** with the message `Add GridWallsMap and grid DDA ray caster`.

### Task 4: The per-frame view and depth buffer

**Files:**
- Create: `src/source/engine/renderer/gridWalls/GridWallsView.bs`
- Test: `src/source/engine/renderer/gridWalls/GridWallsView.spec.bs`

**Interfaces:**
- Consumes: `GridWallsMap`, `GridWallsRayCaster`, `GridWallsHit` from Task 3; `Camera3d`
  (`position`, `orientation`, `getLevelRightVector()`, `getFocalLength()`, `frameSize`,
  `getCurrentDrawDistance()`).
- Produces:
  - `interface GridWallsSpan`: `valid as boolean`, `firstRay as integer`,
    `lastRay as integer`, `nearestDistance as float`.
  - `class BGE.GridWallsView`:
    - `sub new(map as BGE.GridWallsMap)`;
    - `function update(camera as BGE.Camera3d, stripWidth as integer) as boolean` casts every
      ray for this frame;
    - fields `rayCount as integer`, `firstTan as float`, `tanStep as float` (ray `i` has
      bearing tangent `firstTan + i * tanStep` relative to the level forward vector),
      `levelForward`, `levelRight`, `cosPitch`;
    - `hasHit(i) as boolean` and `getHit(i) as GridWallsHit` (hits preallocated and reused
      across frames);
    - `function rayDirection(i as integer) as BGE.Math.Vector` (unit, y = 0);
    - `function findSpan(points as BGE.Math.Vector[]) as GridWallsSpan`. It's invalid if any
      point is level with or behind the camera horizontally, or the list is empty;
    - `function isPointHidden(point as BGE.Math.Vector) as boolean`, true when the point's
      ray has a hit nearer than the point's horizontal distance minus 0.001.

  Ray tangents: `tanStep = stripWidth * cosPitch / focal`. The tangent range is the min and
  max horizontal bearing tangent of the four screen-corner view rays, widened by one step on
  each side. `rayCount = Int((max - min) / tanStep) + 1`. The ray march limit is
  `getCurrentDrawDistance() / cosPitch + map.wallHeight`.

- [ ] **Step 1: Write the failing tests.** Use a real `Camera3d` with `frameSize` 1280x720,
  FOV 90, at the centre of the Task 3 map's open cell, at y 1.8.
  - Level camera looking -z with strip width 4: `rayCount` is between 320 and 324,
    `firstTan` is within 0.01 of -1 - tanStep, and the middle ray hits at distance 3.0.
  - Pitched 35° down (orientation (0, -sin35°, -cos35°)): `rayCount` is greater than the
    level count, so the bottom corners are covered.
  - `isPointHidden` is true for (0, 1, -5) (beyond the north wall) and false for (0, 1, -2).
  - `findSpan([(-1,0,-2), (1,0,-2)])` is valid, `firstRay < lastRay` and
    `nearestDistance = 2.0` within 0.001. A span containing a point at z = +1 (behind) is
    invalid.
  - Review Focus 5: `update` with strip width 4 and then 16 gives a smaller `rayCount`,
    and `getHit(rayCount - 1)` works after each.
- [ ] **Step 2:** `npm run check`. Expected: FAIL.
- [ ] **Step 3: Implement.** Bearing tangent of a horizontal offset `d` is
  `dot(d, levelRight) / dot(d, levelForward)`, and its ray index is
  `Int((tan - firstTan) / tanStep + 0.5)`, clamped. Grow the hit arrays when `rayCount`
  grows, and never shrink them.
- [ ] **Step 4:** `npm run check`. Expected: PASS.
- [ ] **Step 5: Commit** with the message `Add GridWallsView: per-frame ray fan and
  ground-plane depth buffer`.

### Task 5: Drawable, scene object and the renderer stage

**Files:**
- Create: `src/source/engine/drawables/DrawableGridWalls.bs`
- Create: `src/source/engine/renderer/sceneObjects/SceneObjectGridWalls.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs`. Add `GridWalls` to
  `SceneObjectType`, and `function drawsInFixedStage() as boolean`, which returns false.
- Modify: `SceneObjectPlane.bs` and `SceneObjectSkybox.bs`, which override
  `drawsInFixedStage()` to return true.
- Modify: `src/source/engine/renderer/Renderer.bs`.
- Test: `src/source/engine/drawables/DrawableGridWalls.spec.bs`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectGridWalls.spec.bs`

**Interfaces:**
- Consumes: Task 4's `GridWallsView`; Task 1's settings; Task 2's draw-method ruling.
- Produces:
  - `class BGE.DrawableGridWalls extends BGE.Drawable`:
    - `sub new(owner as GameEntity, map as BGE.GridWallsMap, textures as roAssociativeArray,
      args = {} as object)`. `textures` maps a texture name to an `roRegion` one cell wide
      and the wall height tall.
    - `sub setTextures(textures as roAssociativeArray)`, which also calls
      `invalidateGeometry()`.
    - `addToRenderer` registers a `SceneObjectGridWalls` via `addSceneObjectToRenderer`.
    - It honours `enabled`, `isShaded`, `color`/`alpha` (as a tint), `lightWrap` and
      `flash()` (through `getDisplayColor()`).
  - `class BGE.SceneObjectGridWalls extends BGE.SceneObject`, type `GridWalls`:
    - `drawsInFixedStage()` returns true. `participatesInOverlapDetection()`,
      `participatesInDistanceFade()` and `isEligibleForStaticBsp()` return false (the walls
      fade per strip themselves).
    - `isPotentiallyOnScreen()` returns true.
    - `view as BGE.GridWallsView`.
    - `raysLastFrame as integer` and `stripsDrawnLastFrame as integer`.
    - `function computeStrip(index as integer, out as GridWallStrip) as boolean`.
    - `sub redrawStrips(rendererObj as Renderer, firstRay as integer, lastRay as integer,
      nearerThan as float)`.
  - `interface GridWallStrip`: `x as float`, `y as float`, `angle as float` (radians),
    `scaleX as float`, `scaleY as float`, `column as roRegion`, `rgba as integer`,
    `distance as float`.
  - On `Renderer`:
    - `function getGridWalls() as dynamic` returns the `SceneObjectGridWalls` drawn this
      frame, or `invalid`. It's reset to `invalid` at the start of every `render()`.
    - Stage `"gridWalls"`, timed with `lapStage`, after `"planes"`. The `profileStages` doc
      comment lists it.
    - `addSceneObject` of a second `GridWalls` logs one warning and that one never draws.

- [ ] **Step 1: Write the failing tests.**
  - `computeStrip` for the middle ray of a level camera facing the north wall: the strip's
    foot and top lie within 1 px of `camera.worldPointToCanvasPoint` of the hit's foot
    (y = floor) and top (y = floor + wallHeight). The same holds pitched 35° down, and there
    `angle <> 0` for an edge ray.
  - Two neighbouring rays on one wall have no gap: strip i's right edge at the foot is at or
    past strip i+1's left edge.
  - `drawsInFixedStage()` is true for plane, skybox and grid walls, and false for an image.
  - A second grid walls object on one renderer logs a warning (spy on `drawable.log`) and
    `getGridWalls()` returns the first one's `id`.
  - With a `Camera2d`, nothing draws, one warning is logged, and `getGridWalls()` is
    invalid.
  - Review Focus 4: after the drawable is disabled, or `removeFromRenderer` is called,
    `getGridWalls()` is invalid on the next `render()`.
  - With `isShaded` and a `PointLight` beside one wall, a strip's `rgba` is brighter than
    one on the far wall. With no lights it falls back to camera-facing shading.
  - A hit beyond the draw distance isn't drawn, and the fade band gives an alpha below 255.
- [ ] **Step 2:** `npm run check`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `findCanvasPosition` calls `view.update(camera, qualitySettings.gridWallStripWidth)`.
  - `performDraw` computes and draws each strip far to near with the Task 2 method, and
    keeps the strips in a reused array for `redrawStrips`.
  - Lighting: `BGE.Lighting.shadeColor` with the renderer's prepared lights, sampled every
    `gridWallLightInterval` strips and interpolated per channel between samples (a
    different wall side starts a new sample). Use the same floor and camera-facing fallback
    `SceneObjectBillboard` uses.
  - Fade: `camera.getDistanceFadeAlpha(hit point at mid-height)` multiplies the alpha.
  - Debug: with `game.getDebugValue("draw_scene_object_normals")`, draw a dot at each 8th
    strip's foot, plus `rays/strips` text near the top left.
  - Renderer:
    - replace the three `type <> Plane and type <> Skybox` checks with
      `not sceneObj.drawsInFixedStage()`;
    - add the `gridWalls` stage loop after the planes;
    - set the active walls when one draws.
- [ ] **Step 4:** `npm run check`. Expected: PASS, and the existing renderer specs are
  unchanged.
- [ ] **Step 5: Commit** with the message `Add DrawableGridWalls / SceneObjectGridWalls and the
  gridWalls render stage`.

### Task 6: Hiding sorted objects behind walls

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs`. Add
  `hiddenByWallsThisFrame as boolean`.
- Test: `src/source/engine/renderer/RendererGridWalls.spec.bs`

**Interfaces:**
- Consumes: `getGridWalls()`, `GridWallsView.findSpan`, `SceneObjectGridWalls.redrawStrips`.
- Produces: `private sub drawSortedObject(sceneObj as SceneObject)`, used by both the plain
  sorted path and `drawStaticAndDynamicSceneObjects()`. Wall-hidden objects count in
  `occludedCount()` and are shown by the occlusion debug overlay.

  Plan decision: a separate per-frame flag, rather than writing `occludedThisFrame`. The span
  map caches `occludedThisFrame` across frames by `occlusionMapVersion`, and writing it would
  corrupt that cache. Both paths still end in `markSkippedOccluded()`, `VisibilityState.occluded`
  and the same count.

  Test points: `getOcclusionTestPoints(camera)` when `canBeOccluded()`, otherwise
  `getBoundingPoints(camera)`. A type whose points don't bound what it draws (particles,
  screen-sized text) is never skipped whole, only redrawn over.

- [ ] **Step 1: Write the failing tests.** Use a real renderer on a bitmap, the Task 3 map,
  and a `Camera3d` facing the north wall.
  - A billboard image at z = -5 (behind the wall): it isn't drawn, its visibility is
    `occluded`, and `occludedCount()` counts it.
  - The same at z = -2 (in front): it's drawn and redraws no strips.
  - A wide image straddling the wall's edge, so part is behind an open corridor and part
    behind the wall: it's drawn, then `redrawStrips` runs with the expected ray range (spy
    via a subclass overriding `redrawStrips`).
  - Review Focus 3: an object with a point behind the camera is drawn normally and never
    hidden.
  - With occlusion culling on and a span-map occluder also present, an object hidden by the
    span map stays hidden, and its `occlusionMapVersion` caching is unaffected by walls.
  - A clustered object (`clusterMemberCount > 1`) behind a wall is skipped. A partly hidden
    one gets its strips redrawn after the cluster pass.
- [ ] **Step 2:** `npm run check`. Expected: FAIL.
- [ ] **Step 3: Implement** `drawSortedObject` in this order:
  1. the span-map verdict;
  2. the wall span: whole-hidden is skipped, partly hidden draws and then calls
     `redrawStrips(first, last, span.nearestDistance)`;
  3. a normal draw.

  Pad the ray range by 1 on each side. Queue cluster redraws and apply them after
  `drawPendingClusterPrimitives()`.
- [ ] **Step 4:** `npm run check`. Expected: PASS.
- [ ] **Step 5: Commit** with the message `Hide sorted objects behind grid walls`.

### Task 7: In-world overlays and the public query

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs` (`drawWorldPolyline`, `drawWorldBar`;
  `drawWorldCircle`/`drawWorldArc` inherit from the polyline)
- Test: `src/source/engine/renderer/RendererWorldDrawing.spec.bs` (extend)

**Interfaces:**
- Produces: `function isBehindGridWalls(point as BGE.Math.Vector) as boolean`, which is false
  when no walls drew this frame. It's documented as "this frame, from the camera".
  - `drawWorldBar` returns false without drawing when its point is behind.
  - `drawWorldPolyline` skips a segment when either end is behind, and counts that as not
    drawn.

- [ ] **Step 1: Write the failing tests.** With the Task 6 setup:
  - a bar at (0, 2, -5) returns false;
  - a bar at (0, 2, -2) returns true;
  - a polyline from (0,0,-2) to (0,0,-5) returns false;
  - with no walls, `isBehindGridWalls` is false everywhere.
- [ ] **Step 2:** `npm run check`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** `npm run check`. Expected: PASS.
- [ ] **Step 5: Commit** with the message `Hide drawWorld overlays behind grid walls`.

### Task 8: The grid-walls demo and device tuning

**Files:**
- Create: `examples/rendererTest/src/source/Tests/GridWallsTest.bs`
- Create: `examples/rendererTest/src/sprites/crypt_wall.png`, copied with `git show
  examples/third-person-crypt:examples/thirdPerson/src/sprites/crypt_wall.png`
- Modify: `examples/rendererTest/src/source/DemoList.bs`. Add id `grid-walls`, category
  "Drawing".
- Possibly modify: `src/source/engine/quality/RenderQualityPresets.bs` with tuned values.

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the demo.**
  - A 9x9 maze, using the crypt layout's rows with `#` solid, 6 m cells and 4 m walls.
  - A tiled `DrawablePlane` floor, `isShaded` walls, an ambient light and a point light.
  - An oriented image on one wall, flush and 0.01 m off it.
  - A billboard pacing in and out behind a corner, with a `drawWorldBar` over it.
  - The camera at 1.8 m. It turns continuously and sweeps its pitch from 15° up to 35° down
    over 8 s.
  - `up`/`down` steps the quality level, and OK pauses the sweep.
  - The usual timing line plus `rays/strips`.
- [ ] **Step 2:** `npm run validate-examples`. Expected: clean.
- [ ] **Step 3: Run on the Ultra** at each quality level (`--param demo=grid-walls`). Record
  the fps per level. Take screenshots at 15° up, level and 35° down, and check for
  wall/floor seams, the wall image drifting off its wall, gaps between strips, and anything
  showing through.
- [ ] **Step 4: Tune** `gridWallStripWidth`/`gridWallLightInterval` if Medium is under 20 fps
  or Ultra has headroom. A value narrower than 4 is allowed only at the top levels, and only
  if measured affordable. Keep the presets spec passing, and ledger every change with its
  numbers.
- [ ] **Step 5: Commit** with the message `rendererTest: grid walls demo`.

### Task 9: Docs and regression

**Files:**
- Modify: `docs/drawables-and-scene-objects.md`. Add a row in "Every Drawable / SceneObject
  pair" and a "Deep dive: `SceneObjectGridWalls` (`DrawableGridWalls`)" section. It's
  how-to first (build a map, add the drawable, textures, lights). It covers these points
  as asides:
  - the camera stays inside below the wall tops;
  - roll is ignored;
  - what gets hidden and what doesn't (UI canvas);
  - `isBehindGridWalls`;
  - collision isn't included.
- Modify: `docs/render-quality.md` (both settings).
- Modify: `CLAUDE.md`. Add one renderer bullet.

- [ ] **Step 1: Write the docs.**
- [ ] **Step 2:** `npm run check:all`. Expected: PASS.
- [ ] **Step 3: Regression on the Ultra.** Rerun Task 2's baseline demos and compare them
  against the `Baseline:` ledger lines. Expect no visible change, with fps within noise.
- [ ] **Step 4: Commit** with the message `Docs: grid walls`.
