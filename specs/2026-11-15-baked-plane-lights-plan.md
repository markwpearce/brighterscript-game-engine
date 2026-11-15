# Baked staticImage Plane Lights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shaded `staticImage` planes show each ranged point light as a pool baked into a lit copy of their texture, so the thirdPerson town ground looks like the tiled scenes' grounds.

**Architecture:** The working spike on branch `feature/bake-static-lights-528` already does this behind a `DrawablePlane.staticLightMode` string. Turn the "baked" mode into the only behaviour for shaded `staticImage` planes, delete the "pools" and "uniform" static modes and the example's `groundLights` param, add tests, and update the docs.

**Tech Stack:** BrighterScript, Rooibos (headless brs-engine), Roku `ifDraw2D`.

**Spec:** `specs/2026-11-15-baked-plane-lights-design.md`

## Global Constraints

- `lightPoolOpacity` default is 0.4 (already changed on the branch, with the docs line).
- `tiledImage` planes behave exactly as on `main`.
- No single-line `if`; real types (no `as object`/`as dynamic`); never `=` between two objects.
- A baked bitmap is allocated fresh on each rebuild, never redrawn after being read (Roku queues draws).
- `npm run check` passes after every task.

## Review Focus

- A plane that is `isShaded` but the renderer has no lights: draws its texture untinted, no bake (`getLightBakeCount()` stays 0). Test in Task 1.
- An unshaded `staticImage` plane with lights: no bake, tinted as today (-1). Test in Task 1.
- A lamp whose pool lies wholly outside the texture: no placement, so nothing is drawn. Test in Task 1.
- A light that changes every frame rebakes every frame. Accepted; noted in the docs (Task 2), not tested.
- A non-square `scale` (stretched source): pools still land at `worldPointToTexel()`, sized by `getTexelScale()`. Covered by the placement test using scale 2 on both axes; a non-square case is left to review.

---

### Task 1: Baked lighting as the staticImage behaviour, with tests

**Files:**
- Modify: `src/source/engine/drawables/DrawablePlane.bs` (remove `staticLightMode`; doc comment on `lightPoolOpacity` now says "on an `isShaded` plane" rather than "tiledImage")
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs`
- Test: `src/source/engine/renderer/RendererLighting.spec.bs` (the `planes` describe)

**Interfaces:**
- Produces, on `SceneObjectPlane`:
  - `private function drawsPoolsPerFrame() as boolean`: `isShaded and fillMode = tiledImage`
  - `private function bakesLights() as boolean`: `isShaded and fillMode = staticImage`
  - `usesLightPools()` stays `drawsPoolsPerFrame() or bakesLights()`
  - `function getBakedLightPools(rendererObj as BGE.Renderer, width as float, height as float) as PlaneLightPoolPlacement[]`: pools in texel space for a `width` x `height` texture, those overlapping it only (public for tests)
  - `function getLightBakeCount() as integer`: how many times the lit texture has been built (public for tests/telemetry)
  - `function getBakedLightPoolCount() as integer`: pools in the current lit texture (public for tests/telemetry)
- Removes: `populateWithPools()` and the static branch that called it; every `SPIKE (#528)` comment is replaced by a normal one.

- [ ] **Step 1: Write the failing tests** in the `planes` describe, using a helper `drawDecalWithLamp(lampPosition as BGE.Math.Vector) as BGE.SceneObjectPlane` modelled on `drawTiledPlaneWithLamp()`: 64x64 region, `fillMode: staticImage`, `isShaded: true`, `scale: m.v(2, 2, 1)`, same camera, lamp `new BGE.PointLight(lampPosition, 50)`.
  - Change the existing "leave ranged point lights out of a tiled plane's tint" test: the decal half now asserts `&h000000FF` too, and the test is renamed "leave ranged point lights out of a shaded plane's tint, to draw them as pools".
  - `@it("bake a lamp's pool into a static decal's texture, in texels")`: lamp at `m.v(20, 30, -10)` (height 30, range 50 → radius 40 world = 20 texels; centre texel (42, 27)). `pools = sceneObj.getBakedLightPools(m.renderer, 64, 64)`; assert count 1, `x` 22, `y` 7, `width` 40, `height` 40.
  - `@it("leave a pool off a static decal's texture when it doesn't reach it")`: lamp at `m.v(5000, 30, 0)`; `getBakedLightPools(m.renderer, 64, 64).count()` is 0.
  - `@it("bake a static decal's lights once, not every frame")`: `drawDecalWithLamp(m.v(0, 30, -80))`, then `drawStillFrame()`, then move the camera (`camera.position.x = 1`, `checkMovement()`, `update`, `draw`); `getLightBakeCount()` is 1 and `getBakedLightPoolCount()` is 1.
  - `@it("rebake a static decal when a light changes")`: after the above, `m.lamp.position = m.v(10, 30, -80)`, `updateLighting()`, `draw`; `getLightBakeCount()` is 2.
  - `@it("blit a baked static decal untinted")`: add an `AmbientLight(White, 0.5)` before `drawDecalWithLamp`; `getLightTintRGBA()` is not -1, `getCompositeTintRGBA()` is -1.
  - `@it("leave an unshaded or unlit static decal unbaked")`: unshaded decal with a lamp → `getLightBakeCount()` 0 and `getCompositeTintRGBA()` -1; shaded decal with no lights → `getLightBakeCount()` 0.

- [ ] **Step 2: Run to verify they fail**

Run: tag the new tests `@only` while iterating, then `npm run test` (or `npm run check`).
Expected: FAIL, `getBakedLightPools`/`getLightBakeCount` not found.

- [ ] **Step 3: Implement in `SceneObjectPlane.bs`**

Split the spike's `getBakedSourceRegion()` so placement is `getBakedLightPools()` (the spike's loop: `worldPointToTexel(pool.center)`, `radius = pool.radius / getTexelScale()`, skip `getLightPoolRGBA() = 0` and pools outside `width` x `height`; return `PlaneLightPoolPlacement`s with `rgba` set). `getBakedSourceRegion()` draws the tinted source, then each placement's gradient, increments the bake count and records the pool count. No bake when `not rendererObj.hasLights()`: return the source region unchanged and leave `hasBakedLighting` false.

- [ ] **Step 4: Run to verify they pass**

Run: `npm run check` (remove `@only` first).
Expected: lint/validate clean, all shards pass.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/drawables/DrawablePlane.bs src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs src/source/engine/renderer/RendererLighting.spec.bs
git commit -m "Planes: bake light pools into a static decal's texture (#528)"
```

### Task 2: Example cleanup and docs

**Files:**
- Modify: `examples/thirdPerson/src/source/Scenes/TownScene.bs` (remove the `groundLights` block)
- Modify: `examples/thirdPerson/src/source/main.bs` (remove `"groundLights"` from the passed-through keys)
- Modify: `docs/drawables-and-scene-objects.md` (the "Ground planes take lights too" paragraph)
- Modify: `specs/renderer-notes.md` (the Lighting paragraph's plane sentence)

**Interfaces:** consumes Task 1's behaviour only.

- [ ] **Step 1: Docs.** Replace the paragraph's last sentences: a `staticImage` plane bakes its pools and the rest of its lighting into a lit copy of its texture (one extra bitmap the texture's size), rebuilt only when the lights change, so a light that changes every frame rebuilds it every frame; `color` planes and point lights with no `range` still measure the light under the camera. In `renderer-notes.md`, add that shaded `staticImage` planes bake (`getBakedSourceRegion()`, keyed by `lightingVersion`) and blit untinted.
- [ ] **Step 2: Remove the example param**, then `npm run check:all`.
Expected: every example validates.
- [ ] **Step 3: Commit**

```bash
git add examples/thirdPerson docs/drawables-and-scene-objects.md specs/renderer-notes.md specs/2026-11-15-baked-plane-lights-*.md
git commit -m "thirdPerson: the town ground takes torch pools; docs (#528)"
```

### Task 3: On-device check and PR

- [ ] **Step 1:** `npm run run-example -- thirdPerson at=17,27,0`, break into the debugger, screenshot: torch pools by the south road torches, moonlit cobbles beyond. Repeat at `at=17,8,0` (keep torches) and `scene=graveyard` (tiled, unchanged look at 0.4 opacity).
- [ ] **Step 2:** push the branch and open a PR closing #528 (pr-voice skill), with the fps table from the design doc.
