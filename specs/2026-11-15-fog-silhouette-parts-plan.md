# Fog silhouette parts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `castsFogSilhouette` model's fog silhouette follows its outline as a few boxes (tower above nave) instead of one screen box (#525).

**Architecture:** Pure functions in a new `BGE.FogSilhouettes` namespace split a model's faces into model-space height parts and merge screen boxes into non-overlapping rects. `SceneObject.getFogSilhouetteParts()` hands the renderer world-space corners per part (base: one part, its bounding points); `SceneObjectModel` overrides it. `Renderer.workOutFogBoxes()` projects every part and pushes the merged rects.

**Tech Stack:** BrighterScript, Rooibos v6, roDraw2d.

**Spec:** `specs/2026-11-15-fog-silhouette-parts-design.md`

## Global Constraints

- Real types, no `as object`/`as dynamic` except the bsc self-reference workaround; `import` every file whose symbols are used.
- No single-line `if`. Terse inline comments; doc comments for consumers.
- Parts are model space, computed once per `drawable.geometryVersion`; never per frame.
- Overlapping boxes of one caster must never be drawn twice over the same pixel (no darker seams in the fade band).
- Casters that aren't models behave exactly as today (one box, same counts in `fogSilhouettesDrawnLastFrame`).
- `npm run check` passes at every commit.

## Review Focus

- A model with no faces: no parts, no box, no crash.
- A flat model (every face at one height): one part, no divide by zero.
- `invalidateGeometry()` on a caster model: parts worked out again, not stale.
- Any part's corner behind the eye: the whole caster draws no box (today's rule, now over every part).
- Scaled/offset model (PropModel scales by `UNITS_PER_METRE` and offsets z): parts follow `transformationMatrix`.

---

### Task 1: `BGE.FogSilhouettes` pure functions

**Files:**
- Create: `src/source/engine/renderer/FogSilhouettes.bs`
- Test: `src/source/engine/renderer/FogSilhouettes.spec.bs` (one `@suite`, a `boxFaces(lo, hi)` helper building 12 triangles via `BGE.Model3dFaceOps.create`)

**Interfaces:**
- Produces: `BGE.FogSilhouettes.modelParts(faces as BGE.Model3dFace[]) as float[]` — flat `[loX, loY, loZ, hiX, hiY, hiZ]` per part, bottom part first, model space.
- Produces: `BGE.FogSilhouettes.mergeRects(boxes as float[], out as float[])` — `boxes` flat `[x0, y0, x1, y1]` per box (already clamped, x1 > x0, y1 > y0); appends flat `[x, y, w, h]` per rect to `out` (doesn't clear it). Rects cover exactly the union and don't overlap.
- Constants in the namespace: `SLICES = 8`, `SHRINK = 0.5`, `MAX_PARTS = 3`.

`modelParts` algorithm (the tests pin the outputs):
1. Model y range `y0..y1`; if no faces return `[]`; if `y1 = y0` return one part of the whole bounds.
2. Uniform slices of `(y1 - y0) / SLICES`. A face counts in slice `s` when `fy1 > sLo and fy0 < sHi`; a flat face (`fy0 = fy1`) counts only in the slice holding it (top slice inclusive). A slice's footprint is the x/z extent of its faces' whole vertices (not clipped to the slice, so a gable roof doesn't taper into extra parts).
3. Walk slices bottom up, skipping empty ones. Start a new part when a slice's footprint area is under `SHRINK` times the previous non-empty slice's area (and that area > 0) and fewer than `MAX_PARTS` parts exist; otherwise union it into the current part.
4. At each split, the boundary height is the highest `fy1` among faces whose top lies inside the last slice of the lower part (falls back to the slice edge). The lower part's top and the upper part's bottom are that height.

`mergeRects`: one box → push as is. Otherwise sort the distinct y edges; per band between edges, collect the x-spans of boxes covering it, sort by x0, merge touching/overlapping spans; when a band's spans equal the previous band's, extend those rects' heights instead of pushing new ones.

- [ ] **Step 1: Write failing tests** in `FogSilhouettes.spec.bs`:
  - `@it("keeps a plain box as one part")` — `boxFaces({0,0,0},{10,10,10})` → `[0.0,0.0,0.0,10.0,10.0,10.0]`.
  - `@it("splits a tower above a nave into two parts at the nave's top")` — nave `{0,0,0}..{20,6,40}` + tower `{0,0,0}..{6,20,6}` → `[0,0,0,20,6,40, 0,6,0,6,20,6]` (floats).
  - `@it("caps the parts")` — 5 stacked boxes each half the width of the one below, heights 4 each → 3 parts, the last reaching y 20.
  - `@it("keeps a gabled house as one part")` — box `{0,0,0}..{10,6,10}` + two roof triangles from the eaves (y 6, x 0 and 10) to a ridge (y 9, x 5) → 1 part, top 9.
  - `@it("returns no parts for no faces")` and `@it("returns one part for a flat model")`.
  - `@it("passes one box through")`, `@it("cuts a tower above a nave into two rects that don't overlap")` (boxes `[300,125,340,400]`, `[200,300,500,400]` → `[300,125,40,175, 200,300,300,100]`), `@it("merges side by side boxes in a band")`, `@it("keeps apart boxes that don't touch")`.
- [ ] **Step 2:** `npm run test:ci` (or tag `@only`) — fails, namespace missing.
- [ ] **Step 3:** Implement the two functions in `FogSilhouettes.bs` (import `../drawables/Model3d.bs`).
- [ ] **Step 4:** Tests pass.
- [ ] **Step 5:** Commit `Fog: work out a model's silhouette parts and merge screen boxes (#525)`.

### Task 2: Parts per caster, drawn by the renderer

**Files:**
- Modify: `src/source/engine/renderer/sceneObjects/SceneObject.bs` (new method near `getBoundingPointsThisFrame`)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectModel.bs` (override + caches)
- Modify: `src/source/engine/renderer/Renderer.bs` `workOutFogBoxes()` (~line 1368)
- Test: `src/source/engine/renderer/RendererFog.spec.bs`

**Interfaces:**
- Consumes: Task 1's `modelParts`, `mergeRects`.
- Produces: `SceneObject.getFogSilhouetteParts(cameraObj as Camera) as BGE.Math.Vector[][]` — base returns `[m.getBoundingPointsThisFrame(cameraObj)]`. (If bsc rejects `Vector[][]`, use `roArray`.) `SceneObjectModel` returns 8 world corners per part (`BGE.Math.getBoundingCubePoints` of the part's lo/hi, each through `Matrix44.multVecMatrix(v, m.transformationMatrix)`), cached by `geometryVersion` (parts) and `transformVersion` (corners). Don't modify the returned arrays.

`workOutFogBoxes()`: per due caster, project each part's points as now; if any point is behind the eye, the caster draws nothing; clamp each part's box to the frame and collect the valid ones into a reused `float[]`; then `mergeRects` into `fogBoxes`, pushing one `base + alphaByte` per rect appended. `fogSilhouettesProjectedLastFrame` still counts casters.

- [ ] **Step 1: Write failing tests** in `RendererFog.spec.bs` with a helper `newChapel(z as float) as BGE.SceneObject` (DrawableModel of nave `{-200,0,-200}..{200,200,200}` + tower `{-50,0,-50}..{50,600,50}`, entity at `(0, 0, z)`, `castsFogSilhouette: true`):
  - `@it("draws a tower-on-nave model as two rects past the draw distance")` — at -1500: `fogSilhouettesDrawnLastFrame` = 2; `pixelAt(640, 250)` is fog; `pixelAt(720, 250)` (beside the tower, above the nave) is `&h000000FF`.
  - `@it("gives every rect of a fading model the same alpha")` — in the fade band (about -950): 2 rects, both entries of `getFogSilhouetteRgbas()` equal, with an alpha byte between 1 and 254.
  - `@it("works the parts out again after invalidateGeometry")` — replace the model's faces with one plain box, `invalidateGeometry()`, render → 1 rect.
  - `@it("follows a scaled and offset model")` — scale 2, offset z +100: the tower's rect is twice as wide as unscaled (±1 px).
  - Existing silhouette tests keep passing unchanged.
- [ ] **Step 2:** Run — the new ones fail (1 rect).
- [ ] **Step 3:** Implement the method, override and renderer change.
- [ ] **Step 4:** `npm run check` passes.
- [ ] **Step 5:** Commit `Fog: draw a model's silhouette as its parts (#525)`.

### Task 3: Docs and on-device check

**Files:**
- Modify: `src/source/engine/renderer/Fog.bs` doc comment ("a model as a few boxes following its height").
- Modify: `docs/drawables-and-scene-objects.md` ~line 520 (Silhouettes bullet), `.claude/rules/renderer.md` Fog line, `specs/renderer-notes.md` if it mentions fog boxes.

- [ ] **Step 1:** Update the docs.
- [ ] **Step 2:** `npm run check:all` passes.
- [ ] **Step 3:** Sideload thirdPerson (`rokubot-examples` skill), stand where the graveyard chapel is in the fade band and past the draw distance; screenshot: no rectangle beside the tower. Ask the user to compare town FPS against main (don't play real-time via rokubot).
- [ ] **Step 4:** Commit `Docs: fog silhouettes follow a model's height parts (#525)`.
