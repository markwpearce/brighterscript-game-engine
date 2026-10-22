# Occlusion culling (issue #108) - design

## Intent

When a large, solid piece of static geometry (a building, a wall) is in the foreground, anything fully hidden behind it does not need drawing. The renderer should skip those objects. It should also skip the per-frame work that leads up to drawing them: canvas projection, temp-bitmap rasterization and the draw call itself.

The motivating scene is `examples/terrain` with a static chapel model standing among the trees. Trees behind the chapel are some of the most expensive draws in that scene.

## Goals

- Static geometry the game marks as an occluder hides anything fully behind it.
- Several occluders together can hide one object, for example two walls meeting at a corner, or the faces of one model.
- Game code can ask why an entity wasn't drawn: visible, occluded, or off camera.
- No measurable cost for a renderer with no occluders registered.

## Non-goals

- Moving occluders. Only `isStatic` entities can occlude in this version.
- Multi-material OBJ models. That is #341; the chapel draws with one texture until then.
- Skipping `onUpdate()`, collisions or `SceneObject.update()` for hidden objects. Gameplay keeps running, and the engine still doesn't skip game logic for off-screen entities.
- Occlusion on the UI renderer. `render()` is never called on it.

## Anti-goals (failure even if it "works")

- **Popping.** An object that is partly visible must never be skipped, even for one frame. Every rule below is chosen so that the only failure mode is "drew something that was actually hidden", never the reverse.
- **A frame-time regression** in scenes that don't register occluders, or with `occlusionCullingEnabled = false`.

A scene that does register occluders may lose time on moving frames when little is hidden. That's a trade-off for the game to make, and the PR has to report it honestly; it isn't a failure of the feature. The owner wants to judge this as a general engine feature, not by the terrain example alone.

## Decisions made with the project owner

1. **Static-only, opt-in occluders.** Being static isn't enough, because a static tree billboard must not hide anything. An occluder has to be explicitly marked.
2. **Static 3D models can be occluders**, as well as static quads. The chapel is a `Model3d`.
3. **Conservative.** Skip only when the object is provably fully hidden.
4. **Visibility enum.** It replaces the boolean culled signal, and `GameEntity.isOnScreen()` stays as a convenience wrapper. `Drawable.isOnScreen()` goes away in favour of `Drawable.getVisibility()`.
5. **Algorithm: a screen-space span occlusion map**, chosen after a device benchmark (below). A native-bitmap variant was tried and rejected as both slower and non-conservative.
6. **The band count is a fraction of the renderer's draw height**, not a fixed pixel size, so the cost doesn't depend on canvas resolution.

## Benchmark evidence (spike, real Roku, `rendererTest`)

The spike is the `occlusion-span-benchmark` demo on branch `spike/issue-108-occlusion-grid`, uncommitted.

Test setup:
- Random screen-space quads and triangles as occluders, 300 random boxes as occludees.
- Every "hidden" verdict brute-force checked by sampling the box every 2px.

| Map type | Occluders | Band | Build | Check per object | False hides |
|---|---|---|---|---|---|
| span (optimised) | 8 | 16px | 2.1-2.4 ms | 13 µs | 0 |
| span (optimised) | 32 | 16px | 12.5 ms | 17 µs | 0 |
| span (optimised) | 32 | 8px | 23.8 ms | 23 µs | 0 |
| span (optimised) | 128 | 8px | 92 ms | 20 µs | 0 |
| native bitmap | 32 | 16px | 22.4 ms (2 ms of it readback) | 20 µs | **12** |

Findings:
- **Build cost** is about 20 µs per occluder per band it covers.
- **When it's paid:** only on frames where the camera moved or the set of occluders changed. A still frame reuses the map.
- **Break-even:** an oriented billboard or model costs on the order of 1-2 ms to draw, so the build pays for itself when it hides even a couple of them. The spike numbers leave out projecting the occluders from 3D to screen.

## How it works

### Marking occluders

- `Drawable.isOccluder as boolean = false`, also accepted as an `isOccluder` key in drawable args.
  - It only takes effect when `owner.isStatic` is true.
  - Setting it on a non-static or ownerless drawable logs a warning once and is otherwise ignored.
  - *My call:* drawable-level rather than entity-level, so a static chapel entity can leave a thin decorative drawable such as a cross out of occlusion.
- The game asserts that a flagged drawable is opaque. The engine can't tell whether an `Image`'s texture has transparent pixels, which is why this is opt-in.
- **Registration is separate from BSP eligibility.** Today `Renderer.markStatic()` declines anything that isn't an Image or Rectangle, so a static model ends up with `sceneObj.isStatic = false`.
  - Add a `Renderer` occluder registration, e.g. `markOccluder(sceneObj)`, called alongside `markStatic` wherever that's called today.
  - It covers `SceneObjectImage`, `SceneObjectRectangle` and `SceneObjectModel`.
  - The BSP stays Image/Rectangle-only.
  - A static model still isn't a BSP node; it only joins the occluder list.

### Which occluders count each frame

An occluder contributes this frame only if all of these hold:
- it is enabled;
- `distanceFadeAlpha = 1`;
- `Drawable.alpha = 255`;
- its draw mode isn't `wireFrame*`, and isn't a screen-aligned mode (`matchCamera`, `directToCamera`, `directScaled`);
- the camera is a `Camera3d`.

*My call:* screen-aligned and `Camera2d` occluders are out of scope for v1. `markOccluder` rejects a screen-aligned scene object with a one-time warning, the same way the BSP's eligibility check does, and occlusion is skipped entirely under a `Camera2d`.
- a `Rectangle` is `filled`.

What it contributes:
- **Quads:** only if all 4 corners project. A quad facing away from the camera counts only in a `*DrawBackFace` mode.
- **Models:** their faces, under the same rules - front-facing, or any face in `*DrawBackFace` modes, and all 3 vertices must project.

**Coplanar merge for models:**
- *My call:* when a static model is first registered as an occluder, merge its coplanar, edge-sharing triangles into convex panels.
- Store them in the model's local space, so it's computed once.
- This cuts how many occluders feed the build. The span map would merge adjacent triangles anyway, but fewer, larger polygons are cheaper to build from.
- If a merged panel would be non-convex, keep the triangles separate.

**Cap:**
- `Renderer.maxOccluders`, default 32: if more occluder polygons qualify, only the largest by projected screen area are used.
- *My call* on the default; tune it on the device.

### The span map

Built once per frame, after `updateSceneObjects()` and before the draw passes. It is rebuilt only when the camera moved, an occluder's enabled state, fade or geometry changed, or the canvas size changed. Otherwise last frame's map is kept.

**Structure:**
- The canvas is split into `Renderer.occlusionBandCount` horizontal bands, default 45 (16px at 720p).
- For each band, the map holds a sorted list of merged `[left, right, farthestDepth]` x-ranges.

**Building it:**
- For each occluder polygon, a convex shape in canvas space:
  - find its top and bottom vertices;
  - walk its two edge chains once, recording x at every band boundary inside its y-range.
- A band lying wholly inside the polygon's y-range is covered across `[max(left at top, left at bottom), min(right at top, right at bottom)]`. This is exact for convex shapes.
- Insert that range into the band's list, merging with any range it overlaps or touches.
- A merged range keeps the **largest** depth of the occluders in it. That is conservative: an object must be behind every occluder that was merged in.

**Depth:**
- Use the same measure everywhere: `Camera.distanceFromCameraFront()`.
- An occluder's depth is its farthest projected vertex.

### Testing an object

**Candidates:** every enabled `SceneObject` except:
- planes, skyboxes and parallax layers (drawn under everything);
- registered occluders themselves (*my call:* occluders are always drawn, which keeps the rules simple);
- anything already culled as off camera this frame.

**The test:**
1. Use the object's `getBoundingPoints()`. If **any** point fails to project, the object is not occluded.
   - `DepthSort.getScreenBounds()` drops points that fail to project and so under-reports an object's size; it must not be reused as-is.
2. Take the screen AABB of the projected points, inflated by `occlusionMargin`. *My call:* 2px default, covering rounding and the temp-bitmap drift described below.
3. The object's nearest depth is the minimum over its bounding points.
4. It is hidden if, in every band its AABB touches, one merged range contains `[minX, maxX]` and that range's farthest depth is less than the object's nearest depth.
5. Off-canvas boxes are never "occluded" (they're off camera).

**Re-testing:** an object's verdict is recomputed only when the map was rebuilt or the object itself moved, changed geometry or changed draw mode. Otherwise last frame's verdict stands.

**Interaction with the occluder's own drawing:**
- **Approximate redraws.** While moving, an occluder may draw from a slightly stale or approximately transformed temp bitmap, with up to 16px drift for billboards and 64px for models (`attemptTransformTempBitmap`).
  - *Builder to decide:* either inflate by that threshold, or exclude occluders whose last draw used an approximate transform.
  - The second is preferred if it's cheap to detect, since a 64px margin would hide very little.
- **Coarse fills.** Quick-draw triangle skipping and banding only affect small or mid-size triangles, which aren't big enough to matter as occluders. The builder should confirm this on the device with the debug overlay.
- **Transient draw failures.** If an occluder's own draw fails transiently (scratch-pool or temp-bitmap allocation), the objects it hid that frame leave a one-frame hole.
  - *My call:* accept this, and log it at debug level.
  - Don't restructure the draw order to draw occluders first.

### Pipeline placement

In `Renderer.render()`:
1. `updateSceneObjects()`, as today.
2. **New:** if any occluders are registered, `updateOcclusion()` projects the occluders, (re)builds the span map if needed, and tests candidates.
   - With none registered, this is one boolean check: the same zero-cost fallback as `hasStaticGeometry`.
3. Clusters, depth sort, skybox, planes: unchanged.
   - Occluded objects are excluded from cluster candidacy, as culled ones are today.
4. Main pass (BSP walk or sorted loop): an occluded object is skipped with a `markSkippedOccluded()` bookkeeping call, next to the existing `markSkippedBehindCamera()` gate.
   - That call records what `draw()` would have recorded: mode, geometry, projection and quality versions, `isFirstFrameSinceEnabled`.
   - So an object coming back into view doesn't redraw from stale caches incorrectly, and doesn't read as changed every frame.
   - It does **not** set the frustum cull latch. Occlusion has its own verdict, because the latch can't be woken by an occluder changing.

### Visibility state

```
enum VisibilityState
  unknown    ' never drawn yet, or no scene objects / drawables
  visible    ' drawn last frame
  occluded   ' in front of the camera and in view, but fully hidden by occluders
  offCamera  ' outside the frustum, behind the camera, past the draw distance or faded out,
             ' or a deterministic draw failure (today's cull latch)
end enum
```

- `SceneObject` stores its state, replacing the meaning of `lastFrameWasCulled` for reporting.
  - The internal latch can stay as it is.
  - `isCulled()` becomes `getVisibility() = offCamera`, or is removed if nothing else needs it; the builder decides.
- `Drawable.getVisibility()` and `GameEntity.getVisibility()` report the most visible state among their parts, in the order visible > occluded > offCamera > unknown. An empty drawable or entity reports `unknown`.
- `GameEntity.isOnScreen()` keeps its current meaning and doc: true for `visible` or `unknown`.
- `Drawable.isOnScreen()` is removed.
- Update the specs that cover these (`Drawable.spec.bs`, `GameEntity.spec.bs`) and `getClusterCandidates()`.
- *My call:* "off camera" and "past draw distance" share one state.

### Settings

| Field | Default | Notes |
|---|---|---|
| `Renderer.occlusionCullingEnabled` | `true` | Free when nothing is registered. Lets a game or demo A/B it. |
| `Renderer.occlusionBandCount` | 45 | Bands across the renderer's height. |
| `Renderer.maxOccluders` | 32 | Largest-by-screen-area occluder polygons per frame. |
| `Renderer.occlusionMargin` | 2 | Pixels added around each tested box. |

None of these change what the player sees, so they are **not** `RenderQualitySettings` fields. They trade how much gets hidden against build time.

### Debug

A game debug value, e.g. `draw_occlusion`, that:
- outlines every occluded object's screen AABB in red;
- draws the merged span ranges translucently.

This is how false hides get caught on the device.

## Prerequisites

- **#342** - an oriented `SceneObjectModel` or `SceneObjectPolygon` measures its depth from the world origin. Fix it first; occluder and occludee depths depend on it.
  - Per the project owner, it's fixed as part of this work, as the first task on the same branch, with its own specs. The PR closes both #108 and #342.

## Proving it

- **Rooibos specs** for the span map as pure maths, using screen-space polygons in and verdicts out:
  - an object fully inside one occluder;
  - an object covered only by the union of two touching occluders;
  - a hairline gap between two occluders, which must not hide;
  - an object in front of the occluder;
  - an object straddling a band boundary;
  - an object partly off canvas;
  - any bounding point unprojectable.
- **Specs for the visibility roll-up**, including `GameEntity.isOnScreen()` compatibility.
- **Integration specs with a real `Game`:**
  - a static occluder rectangle hides a rectangle behind it;
  - it doesn't hide one beside it;
  - it stops hiding once disabled.
- **`examples/terrain`:**
  - Add the chapel. Its source files are `/Users/mpearce/Downloads/bge aaa/export/chapel.obj`, `chapel.mtl` and `textures/` (28 triangles, 7 parts). Copy them into `examples/terrain/src/models/`; no credit is needed. Place it as a static entity flagged `isOccluder`, near enough to the trees that several are hidden from the start position.
  - Scale it up to the scene: the OBJ is about 13 units tall and the trees are 180, so roughly 25x.
  - Use one texture via `options.texturePath`; `stone.png` is fine until #341.
  - Load it in `WorldScene.onLoad()`.
- **`rendererTest`:** keep a cleaned-up span-map benchmark as a permanent demo. *My call;* drop the native variant.
- **On the device**, record these numbers in the PR:
  - **No-occluder baseline:** an existing 3D example (e.g. `examples/3d`) before and after the change. Must not regress.
  - **Occlusion-heavy scene:** a new `rendererTest` demo built on `Renderer` alone, with a few large static occluder walls and many expensive oriented objects behind and beside them. Measure with `occlusionCullingEnabled` on and off, camera moving and still. This is where the feature should clearly win.
  - **Terrain with the chapel:** on and off, camera moving and still. Report whatever it shows; a loss on moving frames here doesn't block the feature.
- *My call:* no adaptive auto-off in v1. `occlusionCullingEnabled` is the game's switch. If the numbers show games will need an automatic one, file it as a follow-up issue.

## Docs

- `CLAUDE.md` renderer bullets: pipeline placement, the zero-cost fallback, conservative rules and the enum.
- `docs/drawables-and-scene-objects.md`: a consumer-facing section on `isOccluder` and `getVisibility()`, with a short code example.

## Left to the builder

- The final default values, tuned on the device.
- Whether `isCulled()` survives.
- How to handle approximate-transform occluders (see above).
- Exactly where the chapel sits in terrain.
- File layout. The span map is pure maths, so it should live in its own file under `renderer/`, with a spec next to it.
