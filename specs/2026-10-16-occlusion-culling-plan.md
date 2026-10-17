# Occlusion Culling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Static geometry that a game flags as an occluder hides any object fully behind it, so the renderer skips projecting and drawing that object. Game code can see why an entity wasn't drawn through a `VisibilityState` enum.

**Architecture:**
- Each frame, after `updateSceneObjects()`, the renderer does three things:
  - projects registered occluders to convex canvas-space polygons;
  - builds a per-band "span map" of the x-ranges they fully cover, merged across occluders;
  - tests every other object's projected bounding box against it.
- Hidden objects skip `draw()` through a bookkeeping call, the same pattern as `markSkippedBehindCamera()`.
- With no occluders registered, all of this costs one boolean check.

**Tech Stack:** BrighterScript (bsc 1.0 alpha), Rooibos v6 specs run headlessly via `brs-cli`, Roku device testing via rokubot.

**Spec:** `specs/2026-10-16-occlusion-culling-design.md` (approved). Read it before starting any task.

## Global Constraints

- Only skip an object that is provably fully hidden. Every rule must fail toward drawing (anti-goal: popping).
- Only static entities' drawables, explicitly flagged `isOccluder`, occlude. Ownerless scene objects opt in with `Renderer.markOccluder()`.
- Occluders: `SceneObjectImage`, `SceneObjectRectangle` and `SceneObjectModel`, in oriented modes only (`oriented`, `orientedDrawBackFace`, `solid`, `solidDrawBackFace`), and only under a `Camera3d`.
- No cost with zero occluders, or with `Renderer.occlusionCullingEnabled = false`.
- Defaults:
  - `occlusionBandCount = 45`
  - `maxOccluders = 32`
  - `occlusionMargin = 2`
  - `occlusionCullingEnabled = true`
  - These are not `RenderQualitySettings` fields.
- `VisibilityState` values: `unknown`, `visible`, `occluded`, `offCamera`. Roll-up order: visible > occluded > offCamera > unknown.
- `GameEntity.isOnScreen()` = visibility is `visible` or `unknown`. `Drawable.isOnScreen()` is removed.
- Repo rules (`CLAUDE.md`):
  - one `@suite` per `*.spec.bs`;
  - `assertEqual` is type-strict (int vs float);
  - never `=`-compare objects (compare `id`);
  - `import` every file whose symbols you use;
  - no single-line `if`;
  - strong types (interfaces over bare AAs);
  - consumer-facing doc comments, terse inline comments;
  - don't name a suite field `scene`;
  - put a free function returning/taking its own file's class in a separate file.
- After every engine change run `npm run check` (lint + validate + headless tests). The task's commit only happens when that is green.

## Review Focus

1. **Object straddling the near plane.** An occludee with any bounding point behind the camera, or not projectable, must stay visible. Covered: Task 7 `@it("never occludes an object with a bounding point behind the camera")`.
2. **Hairline gap between two adjacent occluders.** Two quads that nearly touch must not hide an object behind the gap. Covered: Task 2 `@it("does not hide across a gap between two occluders")`.
3. **Occluder disabled, faded or removed while an object is hidden behind it, with nothing else moving.** The object must reappear that same frame, with valid canvas geometry. Covered: Task 7 `@it("shows a hidden object again the frame its occluder is disabled")` and `@it("...after its occluder is removed")`.
4. **Object in front of an occluder but overlapping it on screen.** It must stay visible. Covered: Task 2 `@it("does not hide an object nearer than the occluder")` and Task 7 `@it("does not occlude an object in front of the wall")`.
5. **An occluder drawn approximately while the camera moves** (temp-bitmap stretch or stale per-face raster). Its drawn pixels must match the geometry the map was built from. Covered: Task 6 `@it("never reuses a transformed temp bitmap for a registered occluder")`.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs`, `SceneObjectPolygon.bs` (modify) | #342 depth fix |
| `src/source/engine/renderer/occlusion/OcclusionTypes.bs` (create) | `VisibilityState` enum, `OccluderPolygon` and `OccluderPanel` interfaces |
| `src/source/engine/renderer/occlusion/OcclusionSpanMap.bs` (create) + `.spec.bs` | Pure-maths span map |
| `src/source/engine/renderer/occlusion/OccluderPanels.bs` (create) + `.spec.bs` | Coplanar merge of model triangles into convex panels (namespace `BGE.Occlusion`) |
| `SceneObject.bs`, `SceneObjectBillboard.bs`, `SceneObjectRectangle.bs`, `SceneObjectImage.bs`, `SceneObjectModel.bs` (modify) | Visibility state, occluder polygons, skip bookkeeping |
| `src/source/engine/drawables/Drawable.bs`, `src/source/engine/GameEntity.bs` (modify) | `isOccluder`, `getVisibility()`, `isOnScreen()` wrapper |
| `src/source/engine/renderer/Renderer.bs` (modify) | Registration, `updateOcclusion()`, draw-loop gating, settings, debug overlay |
| `src/source/engine/renderer/RendererOcclusion.spec.bs` (create) | Integration specs with a real `Game` + `Camera3d` |
| `src/source/engine/Game.bs` (modify) | `debugDrawOcclusion()` |
| `examples/rendererTest/...` | Span-map benchmark (replaces the spike) + occlusion scene benchmark |
| `examples/terrain/...` | Chapel occluder + on/off toggle |
| `CLAUDE.md`, `docs/drawables-and-scene-objects.md` | Docs |

---

### Task 1: Fix #342 - oriented Model/Polygon depth measured from the world origin

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs:330-335`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPolygon.bs:88-93`
- Test: `src/source/engine/renderer/sceneObjects/SceneObjectModel.spec.bs`, `SceneObjectPolygon.spec.bs`

**Interfaces:**
- Produces: `getPositionForCameraDistance(oriented)` returns the object's own centre. For a model that is the centre of `modelWorldBounds`; for a polygon, the centre of the AABB of `polygonWorldPoints`.

- [ ] **Step 1: Write the failing tests.** In each spec, add `@it("measures oriented depth from the object's own centre, not the world origin")`:
  - Build a real `Game` with a `Camera3d` at (0, 0, -500) looking at the origin.
  - Make an entity at position (0, 0, 300) with a cube model (or a 4-point polygon), `drawMode: oriented`.
  - `renderer.setupCameraForFrame()`, then `renderer.render()`.
  - Assert `sceneObj.getDepthPosition().z` is within 1 of `300` (`m.assertTrue(abs(... - 300) < 1)`).
- [ ] **Step 2:** `npm run test:ci`. Expected: both new tests FAIL, with z ≈ 0.
- [ ] **Step 3:** Implement both overrides.
  - Model: `BGE.Math.VectorOps.create((min.x+max.x)/2, ...)` from `modelWorldBounds`. Confirm the field shape (`[min, max]` vectors) in `updateWorldPosition()` at line 290.
  - Polygon: min/max over `polygonWorldPoints`.
  - Fall back to `m.worldPosition` when the bounds or points are empty.
- [ ] **Step 4:** `npm run check`. Expected: all green.
- [ ] **Step 5:** Commit: `git commit -m "Measure oriented model/polygon depth from the object, not the origin (#342)"`

---

### Task 2: Span occlusion map (pure maths)

**Files:**
- Create: `src/source/engine/renderer/occlusion/OcclusionTypes.bs`
- Create: `src/source/engine/renderer/occlusion/OcclusionSpanMap.bs`
- Test: `src/source/engine/renderer/occlusion/OcclusionSpanMap.spec.bs`

**Interfaces:**
- Produces, in `OcclusionTypes.bs`, namespace `BGE`:
  - `enum VisibilityState` with string values `unknown`, `visible`, `occluded`, `offCamera`.
  - `interface OccluderPolygon extends roAssociativeArray`:
    - `xs as float[]`, `ys as float[]` - canvas-space convex polygon, either winding, 3+ points;
    - `depth as float` - the farthest vertex's `distanceFromCameraFront`;
    - `area as float` - projected area, used for the `maxOccluders` cap.
  - `interface OccluderPanel extends roAssociativeArray`:
    - `vertices as BGE.Math.Vector[]` - model-local, convex, ordered around the perimeter;
    - `normal as BGE.Math.Vector` - model-local.
- Produces, in `OcclusionSpanMap.bs`, `class OcclusionSpanMap`:
  - `sub new(width as float, height as float, bandCount as integer)`
  - `sub build(polygons as BGE.OccluderPolygon[])`
  - `function isHidden(minX as float, minY as float, maxX as float, maxY as float, nearestDepth as float) as boolean` - the caller has already applied the margin;
  - `function getBandHeight() as float`, `function getBandCount() as integer`;
  - `function getBandSpans(band as integer) as float[]` - flat `[left, right, depth, ...]`, for the debug overlay.

- [ ] **Step 1: Write the failing tests** (`@suite("BGE.OcclusionSpanMap")`). All of them use a 1280x720 map with 45 bands (band height 16.0), unless noted:
  - `@it("hides a box fully inside one nearer quad")` - quad (100,100)-(600,100)-(600,500)-(100,500) at depth 10; box (200,200)-(300,300) with nearest depth 20 → `assertTrue`.
  - `@it("does not hide an object nearer than the occluder")` - same quad and box, nearest depth 5 → `assertFalse`.
  - `@it("hides a box covered only by the union of two touching quads")` - quads x 100-400 and x 400-700, y 100-500, depths 10 and 12; box (350,200)-(450,300) at depth 20 → true. A box at depth 11 → false (a merged range keeps the farthest depth).
  - `@it("does not hide across a gap between two occluders")` - quads x 100-399 and x 401-700; box (350,200)-(450,300) → false.
  - `@it("does not hide a box poking out of the occluder")` - box (550,200)-(650,300) → false.
  - `@it("only counts bands lying wholly inside a triangle")`:
    - triangle (100,100),(700,100),(400,600) at depth 10;
    - box near the apex, (390,560)-(410,590), whose band isn't fully covered → false;
    - box (380,150)-(420,200) → true.
  - `@it("treats a box spanning several bands as hidden only if every band covers it")` - box (200,90)-(300,300) whose top band starts above the quad → false.
  - `@it("never hides a box that extends off the canvas")` - box (-10,200)-(50,300) under a quad covering the whole canvas → false.
  - `@it("hides nothing when built with no polygons")`.
  - `@it("rebuilding replaces the previous frame's spans")` - build once with the quad, then build with `[]` → false.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL (class not defined).
- [ ] **Step 3:** Port the algorithm from the spike: `examples/rendererTest/src/source/Tests/OcclusionSpanBenchmark.bs`, the class `OcclusionSpanMap` and its `chainXs`/`insertSpan` helpers.
  - The band count comes from the constructor; band height = `height / bandCount`.
  - Remove the margin handling from `isHidden` (the caller applies it).
  - Keep the spike's rules:
    - a band contributes only if it lies wholly within the polygon's y range;
    - the covered range is `[max of left x at the band's top and bottom edges, min of right x]`;
    - merged ranges keep the max depth;
    - ranges that touch (`next.left <= cur.right`) merge.
  - Reuse the per-band arrays between builds (`Clear()`).
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Add screen-space span occlusion map (#108)"`

---

### Task 3: Coplanar panels for static model occluders

**Files:**
- Create: `src/source/engine/renderer/occlusion/OccluderPanels.bs`
- Test: `src/source/engine/renderer/occlusion/OccluderPanels.spec.bs`

**Interfaces:**
- Consumes: `BGE.OccluderPanel` (Task 2), `BGE.Model3dFace` (`drawables/Model3d.bs`).
- Produces: `function BGE.Occlusion.buildModelPanels(faces as BGE.Model3dFace[]) as BGE.OccluderPanel[]` in namespace `BGE.Occlusion`.

- [ ] **Step 1: Write the failing tests** (`@suite("BGE.Occlusion.buildModelPanels")`):
  - `@it("merges two coplanar triangles sharing an edge into one 4-vertex panel")`.
  - `@it("keeps triangles on different planes separate")` - two triangles at 90° → 2 panels.
  - `@it("merges a cube's 12 triangles into 6 panels")`.
  - `@it("does not merge when the result would be non-convex")` - three coplanar triangles forming an L shape → more than 1 panel, every panel convex. Check convexity with a helper that tests the cross-product sign along the panel.
  - `@it("ignores degenerate faces")` - zero-area triangle → no panel.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL.
- [ ] **Step 3:** Implement it with greedy merging:
  - group faces by plane (normal dot within 0.999, and the plane distance within 0.01 × model bounding size);
  - within a group, repeatedly merge a panel with a triangle sharing an edge (matching vertex positions within epsilon) when the merged polygon stays convex;
  - drop collinear vertices.
  - Model sizes are tiny (the chapel has 28 faces), so O(n²) is fine. It runs once per registration.
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Merge coplanar model faces into occluder panels (#108)"`

---

### Task 4: Visibility state on SceneObject, Drawable and GameEntity

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` - fields near line 190, `draw()` at 422-465, `markSkippedBehindCamera()` at 392
- Modify: `src/source/engine/drawables/Drawable.bs:375-390`
- Modify: `src/source/engine/GameEntity.bs:125-155`
- Modify: `src/source/engine/renderer/Renderer.bs:505-513` (`getClusterCandidates`)
- Test: `src/source/engine/drawables/Drawable.spec.bs`, `src/source/engine/GameEntity.spec.bs`, `src/source/engine/renderer/sceneObjects/SceneObject.spec.bs` (or the nearest existing SceneObject spec)

**Interfaces:**
- Consumes: `BGE.VisibilityState` (Task 2's `OcclusionTypes.bs`; import it).
- Produces:
  - `SceneObject.getVisibility() as BGE.VisibilityState` - initially `unknown`.
  - `SceneObject.markSkippedOccluded(cameraObj as Camera)` - used by Task 7.
  - `Drawable.getVisibility() as BGE.VisibilityState`.
  - `GameEntity.getVisibility() as BGE.VisibilityState`.
  - `GameEntity.isOnScreen() as boolean` - unchanged semantics.
  - Removes `Drawable.isOnScreen()`.
  - `SceneObject.isCulled()` stays, and still means "latched off camera".

- [ ] **Step 1: Write the failing tests:**
  - `SceneObject`: `@it("is unknown before its first draw")`; `@it("is visible after drawing")`; `@it("is offCamera when frustum-culled")`; `@it("is offCamera when skipped behind the camera")`; `@it("is occluded after markSkippedOccluded and forces a canvas recompute on its next draw")`. For the last one, after `markSkippedOccluded`, assert `hasValidCanvasPosition` is false through a test accessor, or spy `findCanvasPosition` on the next `draw()`.
  - `Drawable`: `@it("reports the most visible state among its scene objects")` - one occluded and one offCamera gives occluded; add a visible one and it gives visible. `@it("is unknown with no scene objects")`.
  - `GameEntity`: `@it("is unknown with no drawables")`; `@it("isOnScreen is true for visible and unknown, false for occluded and offCamera")`.
  - Replace the existing `Drawable.isOnScreen` specs (`Drawable.spec.bs:161-187`) with `getVisibility` equivalents.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL.
- [ ] **Step 3:** Implement:
  - Add `protected visibility as BGE.VisibilityState = BGE.VisibilityState.unknown`.
  - In `draw()`: after setting `lastFrameWasCulled`, set `offCamera` if `lastFrameWasCulled`, else `visible`. A transient failure reports `visible`, matching today's `isOnScreen()`.
  - `markSkippedBehindCamera()` sets `offCamera`.
  - `markSkippedOccluded(cameraObj)`:
    - records `lastDrawMode = getActualDrawMode(cameraObj)` and `lastGeometryVersion`;
    - sets `isFirstFrameSinceEnabled = false`, `lastFrameDidDraw = false`, `hasValidCanvasPosition = false`, `visibility = occluded`;
    - leaves `lastFrameWasCulled = false`;
    - does **not** record projection/quality versions, so a change that happens while hidden is applied on return.
  - `markSkippedWhileDisabled()` leaves visibility unchanged (today's behaviour).
  - Drawable and GameEntity roll-ups use the ranking order from Global Constraints.
  - `getClusterCandidates()` also excludes `occluded`.
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Report visibility as an enum; keep GameEntity.isOnScreen() as a wrapper (#108)"`

---

### Task 5: Occluder registration and settings

**Files:**
- Modify: `src/source/engine/drawables/Drawable.bs` - add `isOccluder as boolean = false` near the other public fields
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs`, `SceneObjectImage.bs`, `SceneObjectRectangle.bs`, `SceneObjectModel.bs`
- Modify: `src/source/engine/renderer/Renderer.bs` - `addSceneObject` (428-438), `removeSceneObject` (474-489), new fields and methods
- Test: `src/source/engine/renderer/RendererOcclusion.spec.bs` (create; `@suite("BGE.Renderer - occlusion")`, setup like `RendererStaticGeometry.spec.bs`)

**Interfaces:**
- Produces on `SceneObject`:
  - `function isEligibleOccluderType() as boolean` - base `false`; Image, Rectangle and Model return `true`;
  - `isOccluder as boolean` - set only by the renderer, like `isStatic`.
- Produces on `Renderer`:
  - `sub markOccluder(sceneObj as SceneObject)`;
  - `function hasOccluders() as boolean`;
  - public fields `occlusionCullingEnabled as boolean = true`, `occlusionBandCount as integer = 45`, `maxOccluders as integer = 32`, `occlusionMargin as float = 2`;
  - private `occluders as roAssociativeArray` (by scene object `id`), `occludersChanged as boolean`.

- [ ] **Step 1: Write the failing tests:**
  - `@it("registers a flagged drawable of a static entity as an occluder")` - `GameEntity(m.game, {name: "wall", isStatic: true})`, `addRectangle("r", 100, 100, {isOccluder: true, drawMode: BGE.SceneObjectDrawMode.orientedDrawBackFace})` → `sceneObj.isOccluder` true and `renderer.hasOccluders()` true.
  - `@it("ignores isOccluder on a non-static entity")` → false / false.
  - `@it("does not register an unflagged static drawable")`.
  - `@it("registers a static model")` - a `DrawableModel` with a cube model.
  - `@it("declines a circle")` - an ineligible type → false.
  - `@it("declines a screen-aligned draw mode")` - `directScaled` → false.
  - `@it("markOccluder works on an ownerless scene object")` - same construction as `RendererStaticGeometry.spec.bs`'s ownerless test.
  - `@it("unregisters on removal")` - remove the drawable → `hasOccluders()` false.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL.
- [ ] **Step 3:** Implement:
  - `addSceneObject`: if `drawable.isOccluder`, then `markOccluder` when the owner is static; otherwise log a warning once through `drawable.log(..., BGE.Debug.LogLevel.warning)`.
  - `markOccluder` declines, with the same style of warning as `markStatic`, when `not isEligibleOccluderType()` or the drawable's `drawMode` is screen-aligned (`isScreenAlignedDrawMode`).
  - For a model, `markOccluder` builds and caches its panels with `BGE.Occlusion.buildModelPanels(drawable.model.faces)` on the `SceneObjectModel` (`occluderPanels as BGE.OccluderPanel[]`).
  - Registration and removal set `occludersChanged = true`.
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Register static drawables flagged isOccluder (#108)"`

---

### Task 6: Occluder polygons per frame, drawn exactly

**Files:**
- Modify: `SceneObject.bs`, `SceneObjectBillboard.bs` (polygon helper; `attemptTransformTempBitmap` at 935), `SceneObjectRectangle.bs`, `SceneObjectModel.bs` (per-face reuse at ~193)
- Test: `src/source/engine/renderer/RendererOcclusion.spec.bs`

**Interfaces:**
- Consumes: `BGE.OccluderPolygon`, `BGE.OccluderPanel`, `isOccluder`.
- Produces: `function SceneObject.appendOccluderPolygons(rendererObj as Renderer, out as BGE.OccluderPolygon[]) as void` - base: no-op. Appends zero or more polygons for this frame.

- [ ] **Step 1: Write the failing tests.** Each uses a wall rectangle 200x200 at z=0, `orientedDrawBackFace`, filled, and a `Camera3d` at (0,0,-500) looking at the origin. Call `updateSceneObjects()` through `render()` first.
  - `@it("contributes one polygon for a solid wall facing the camera")` - 1 polygon, 4 points, depth > 0.
  - `@it("contributes nothing in a wireframe mode")`.
  - `@it("contributes nothing when partly faded")` - set `distanceFadeAlpha` through a far camera, or a test hook.
  - `@it("contributes nothing when drawable alpha is below 255")`.
  - `@it("contributes nothing for an unfilled rectangle")`.
  - `@it("contributes nothing for a plain oriented quad facing away")`.
  - `@it("contributes nothing when a corner is behind the camera")` - camera between the corners.
  - `@it("contributes nothing while disabled")`.
  - `@it("contributes a cube model's front-facing panels only")` - camera looking straight at one face → 1 polygon; at a corner → 3.
  - `@it("never reuses a transformed temp bitmap for a registered occluder")` - move the camera slightly between two renders and spy `attemptTransformTempBitmap` (or assert its result is unused). The model per-face reuse path must skip reuse for occluders too.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL.
- [ ] **Step 3:** Implement:
  - **Shared gate:**
    - `enabled`, `distanceFadeAlpha = 1`, `drawable.alpha = 255`;
    - the mode is not `wireFrame*` and not screen-aligned;
    - `rendererObj.camera` is a `Camera3d` (check the camera's `name = "Camera3d"`, the same check `SceneObjectSkybox` uses).
  - **Billboard:**
    - project its 4 world corners with `camera.worldPointToCanvasPoint`; skip it if any is `invalid`;
    - backface: in a non-`*DrawBackFace` mode, skip when `BGE.Math.CornerPoints` reports the canvas quad mirrored, matching how the draw path culls;
    - depth = the max `distanceFromCameraFront` over its corners;
    - area = shoelace area.
  - **Rectangle:** also requires `filled`.
  - **Model:**
    - transform each cached panel's vertices by `m.transformationMatrix` (`BGE.Math.Matrix44.multVecMatrix`) and project them;
    - skip a panel if any vertex fails to project, or if it's back-facing in a non-`*DrawBackFace` mode (canvas winding);
    - one polygon per panel.
  - **Exact drawing:** when `m.isOccluder`, `attemptTransformTempBitmap` returns its "no reuse" result, and `SceneObjectModel`'s per-face stale reuse is skipped. That keeps drawn pixels matching this frame's geometry.
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Project occluders to canvas polygons and draw them exactly (#108)"`

---

### Task 7: `Renderer.updateOcclusion()` and draw-loop gating

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs` - `render()` (701-815), BSP loop (626-636), sorted loop (787-795)
- Modify: `SceneObject.bs` - occlusion verdict fields
- Test: `src/source/engine/renderer/RendererOcclusion.spec.bs`

**Interfaces:**
- Consumes: `OcclusionSpanMap`, `appendOccluderPolygons`, `markSkippedOccluded`, the settings from Task 5.
- Produces:
  - `private sub Renderer.updateOcclusion()`;
  - `SceneObject.occludedThisFrame as boolean` (read-only by convention), plus `occlusionMapVersion` bookkeeping;
  - `function Renderer.getOcclusionMap() as OcclusionSpanMap` (for the debug overlay and tests; `invalid` until first built);
  - `function Renderer.getOccludedCountLastFrame() as integer`.

- [ ] **Step 1: Write the failing integration tests.** Use a real `Game`, a `Camera3d` at (0,0,-500) looking at the origin, a static occluder wall 300x300 at z=0, and a small 20x20 rectangle "tree" (`orientedDrawBackFace`) at z=200. Render two frames per test.
  - `@it("occludes an object fully behind a wall")` - tree visibility `occluded`, and its `performDraw` isn't called (spy, or compare `getDrawCallsLastFrame()` with the tree disabled).
  - `@it("does not occlude an object beside the wall")` - tree at x=400 → `visible`.
  - `@it("does not occlude an object in front of the wall")` - tree at z=-100 → `visible`.
  - `@it("hides an object behind two touching walls")` - two 150-wide walls side by side, tree at the seam → `occluded`.
  - `@it("never occludes an object with a bounding point behind the camera")` - a long tree rectangle reaching behind the camera → not `occluded`.
  - `@it("shows a hidden object again the frame its occluder is disabled")` - occluded, then `wall.enabled = false` and render → `visible`, drawn.
  - `@it("...after its occluder is removed")` - same, but removing the drawable.
  - `@it("does nothing when occlusionCullingEnabled is false")` → `visible`.
  - `@it("does nothing under a Camera2d")`.
  - `@it("does no occlusion work with no occluders registered")` - `getOcclusionMap()` stays `invalid`.
  - `@it("reuses the map while nothing moves")` - capture a map build counter, render twice with nothing moving → unchanged; move the camera → +1.
  - `@it("keeps only the largest occluders when over maxOccluders")` - `maxOccluders = 1`, one large wall plus a small one in front of the tree; the tree is only behind the small one → `visible`.
  - `@it("hides objects behind a static model occluder")` - a cube model scaled up as the wall.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL.
- [ ] **Step 3:** Implement `updateOcclusion()`, called in `render()` right after `updateSceneObjects()`. When `not occlusionCullingEnabled or not hasOccluders() or the camera isn't a Camera3d`, return early, clearing any `occludedThisFrame` flags left from a previous frame.
  - **Rebuild when** `camera.movedLastFrame()`, `occludersChanged`, the canvas size changed, or any occluder this frame:
    - moved,
    - changed geometry (`geometryChanged()`),
    - flipped enabled (track `wasEnabledLastFrame`),
    - changed `distanceFadeAlpha` from 1 or back.
  - **Build:**
    - collect polygons from every registered occluder;
    - if there are more than `maxOccluders`, `SortBy("area", "r")` and keep the first `maxOccluders`;
    - `spanMap.build(...)`;
    - bump `occlusionMapVersion`; clear `occludersChanged`.
  - **Test candidates:** every enabled scene object that:
    - isn't an occluder;
    - isn't a Plane, Skybox or ParallaxLayer (check `type`);
    - is in front of the camera (`negDistanceFromCamera < 0`).
  - **Re-test a candidate only if** the map version changed, or the object moved, changed geometry or changed draw mode this frame (the same signals as `depthChangedThisFrame`/`geometryChanged()`). Otherwise keep its verdict.
  - **The test:**
    - project every point of `getBoundingPoints(camera)`; any `invalid` means not occluded;
    - inflate the AABB by `occlusionMargin`;
    - nearest = min `distanceFromCameraFront`;
    - `occludedThisFrame = spanMap.isHidden(...)`.
  - **Draw-loop gating:** in both the BSP loop and the plain sorted loop, an object with `occludedThisFrame` calls `markSkippedOccluded(m.camera)` instead of `draw(m)`. Cluster candidacy already excludes it (Task 4), but `getClusterCandidates()` runs before this - make it check `occludedThisFrame` instead of last frame's visibility.
  - **Occlusion and the frustum:** an occluded object never reached its frustum check that frame, so it can't latch off camera. If it leaves the view while hidden, the next `draw()` after it's revealed does the frustum check normally.
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Cull objects hidden behind static occluders (#108)"`

---

### Task 8: Debug overlay

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs` - draw at the end of `render()`, before `Finish()`
- Modify: `src/source/engine/Game.bs:1723` area - add `debugDrawOcclusion(enabled as boolean)` next to `debugDrawColliders`
- Test: `RendererOcclusion.spec.bs`

**Interfaces:**
- Produces: `Renderer.showOcclusionDebug as boolean = false`; `Game.debugDrawOcclusion(enabled as boolean)` sets it on `m.canvas.renderer`.

- [ ] **Step 1: Write the failing test** `@it("draws the occlusion overlay only when enabled")` - compare `getDrawCallsLastFrame()` between `showOcclusionDebug` false and true with one occluded object. The overlay adds draw calls.
- [ ] **Step 2:** `npm run test:ci`. Expected: FAIL.
- [ ] **Step 3:** Implement:
  - each band's merged spans as translucent rectangles (`&h3060C080`);
  - each occluded object's inflated AABB as a red outline (`BGE.Colors.Red`), with 4 `drawLine` calls, from the AABB stored during the test.
- [ ] **Step 4:** `npm run check`. Expected: green.
- [ ] **Step 5:** Commit: `git commit -m "Add occlusion debug overlay (#108)"`

---

### Task 9: rendererTest benchmarks

**Files:**
- Delete the spike: `examples/rendererTest/src/source/Tests/OcclusionSpanBenchmark.bs` (uncommitted).
- Create: `examples/rendererTest/src/source/Tests/OcclusionSpanMapBenchmark.bs` - times the engine's `BGE.OcclusionSpanMap` (k = 8/32/128 random polygons, 45 bands; build ms, query µs, brute-force false-hide check). Keep the spike's watchdog-safe one-config-per-few-frames structure and its visual check.
- Create: `examples/rendererTest/src/source/Tests/OcclusionSceneBenchmark.bs` - the occlusion-heavy scene below.
- Modify: `examples/rendererTest/src/source/DemoList.bs` - ids `occlusion-span-map-benchmark` and `occlusion-scene-benchmark`, category `Benchmarks` (or whatever category the existing benchmarks use).

**Interfaces:**
- Consumes: `Renderer.markOccluder`, `occlusionCullingEnabled`, `getOccludedCountLastFrame()`, `showOcclusionDebug`.

**The scene benchmark:**
- Built like `StaticGeometryBspBenchmark.bs`: a fresh off-screen renderer per phase, frames driven by frame index, timed with `roTimespan`.
- Contents:
  - three large static wall rectangles (`orientedDrawBackFace`, filled), registered with `markStatic` + `markOccluder`;
  - 60 `Image` billboards in `oriented` mode (texture warps are expensive) scattered behind and beside them;
  - a camera orbiting on a path.
- Four phases: occlusion on/off × camera moving/still.
- Report per phase: ms per frame, draw calls per frame, occluded count.
- OK toggles `showOcclusionDebug` on a final live view.

- [ ] **Step 1:** Write both demos and register them. Build: `cd examples/rendererTest && npx bsc --create-package=false`. Expected: 0 errors.
- [ ] **Step 2:** Package and sideload: `npm run package`, then `node node_modules/rokubot/dist/cli.js sideload ./examples/rendererTest/out/bge-rendererTest.zip --deleteDevChannel`, `press home`, `launch dev --param demo=occlusion-scene-benchmark`. Screenshot the results.
  - Expected: false hides 0 in the span benchmark.
  - Expected: the "occlusion on" phases have fewer draw calls than "off".
  - Record the numbers for the PR.
- [ ] **Step 3:** With the overlay on, check visually that no red outline is drawn around an object that is partly visible.
- [ ] **Step 4:** Commit: `git commit -m "Add occlusion benchmarks to rendererTest (#108)"`

---

### Task 10: Chapel occluder in terrain

**Files:**
- Copy `/Users/mpearce/Downloads/bge aaa/export/chapel.obj`, `chapel.mtl` and `textures/*.png` to `examples/terrain/src/models/chapel/`. No credit file.
- Create: `examples/terrain/src/source/Entities/Chapel.bs`
- Modify: `examples/terrain/src/source/Scenes/WorldScene.bs` - `onLoad()` (line 12) and `onCreate()`
- Modify: `examples/terrain/src/source/Entities/TerrainFreeFlyCameraController.bs` (toggle key)

**The Chapel entity:**
- `isStatic = true`.
- `addDrawable("chapel", new BGE.DrawableModel(m, game.getModel("chapel"), {isOccluder: true, drawMode: BGE.SceneObjectDrawMode.solid}))`. Confirm the model accessor name on `Game`, and the right solid mode for a closed mesh.
- Scale about 25x, so the 13-unit model is ~330 tall against 180-tall trees.
- Place it on the ground between the start position and a dense cluster from `TreePlacements.bs`.

**Loading:** in `WorldScene.onLoad()`, `loader.load3dModel("chapel", "pkg:/models/chapel/chapel.obj", {texturePath: "pkg:/models/chapel/textures/stone.png"})` when the model isn't already loaded.

**Toggle:**
- A button not already used by the terrain controller or `BGE.FreeFlyCameraController` toggles `m.game.canvas.renderer.occlusionCullingEnabled`. Grep both for `isButton(` first; `play` is the first choice.
- Show `Occlusion: on/off` in the existing hint text.
- The existing options debug toggle also calls `game.debugDrawOcclusion()`.

- [ ] **Step 1:** Implement, then `cd examples/terrain && npx bsc --create-package=false`. Expected: 0 errors.
- [ ] **Step 2:** Package, sideload and launch on the device.
  - Screenshot: the chapel renders, and trees behind it disappear only when fully hidden. Use the overlay.
  - Then ask the user to fly around and report popping. Real-time play through rokubot is too slow.
- [ ] **Step 3:** Measure FPS with occlusion on and off, camera still and moving (follow `reference_rokubot_fps_sampling`: first paused sample per launch, quality pinned). Record the numbers for the PR, whatever they show.
- [ ] **Step 4:** Commit: `git commit -m "Add an occluding chapel to terrain (#108)"`

---

### Task 11: No-regression check, docs, PR

**Files:**
- Modify: `CLAUDE.md` - a renderer bullet for occlusion:
  - pipeline placement and the zero-cost fallback;
  - the conservative rules;
  - occluders draw exactly;
  - the `VisibilityState` roll-up;
  - `isOnScreen()` is now a wrapper.

  Also update the existing `isOnScreen()`/`isCulled()` mentions.
- Modify: `docs/drawables-and-scene-objects.md` - a consumer section "Occluders and visibility" with a short example: a static entity, `isOccluder: true`, and `getVisibility()`/`isOnScreen()` in game code. Lead with the how-to; put the gotchas (opaque only, oriented modes, `Camera3d`) as asides.
- Modify: the `rendererTest` row in `.claude/skills/rokubot-examples/SKILL.md`, and the terrain row (the new toggle key).

- [ ] **Step 1: Baseline.** Build `examples/3d` from `main` and from this branch, and measure FPS on the device in the same scene. Expected: no regression. Record both.
- [ ] **Step 2:** Write the docs. `npm run docs` builds without errors.
- [ ] **Step 3:** `npm run check:all`. Expected: green.
- [ ] **Step 4:** Commit the docs, push the branch with an explicit refspec (`git push -u origin feature/issue-108-occlusion-culling:feature/issue-108-occlusion-culling`), and open the PR with the `pr-voice` skill.
  - The body has the benchmark tables from Tasks 9-11.
  - It says `Closes #108` and `Closes #342`.
