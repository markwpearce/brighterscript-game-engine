---
paths:
  - "src/source/engine/renderer/**"
  - "src/source/engine/quality/**"
  - "src/source/engine/drawables/**"
  - "examples/rendererTest/**"
---

# Renderer

Docs: `specs/renderer-notes.md` (lighting, walls, quad columns), `docs/render-quality.md`, `specs/` for depth-sort/BSP/occlusion.

- One `Renderer` per canvas (game, UI): owns `SceneObject`s, a `Camera2d`/`Camera3d`, a `ScratchBitmapPool`. `SceneObjectDrawMode` gives billboard/oriented pseudo-3D; plain `oriented` backface-culls — inward walls need `orientedDrawBackFace`.
- Depth sort: stable whole-object painter's sort, skipped when nothing changed. `computeOverlapClusters` interleaves per-face primitives. Static entities (`isStatic`, oriented image/rectangle) go in a classification-only BSP; everything else is placed in it by its bounds (`BSP.findBoundsLeaf`), so one across a quad's plane but past its edges (a house on a far fence's line) is ordered by the camera's side of that edge. Occlusion culling (`Camera3d`) uses a span map.
- Culled objects and deterministic draw failures latch (`isCulled()`) until they move.
- Draw replay: an Image/Model whose still frame drew one blit repeats it (`SceneObject.draw()`, `Renderer.beginBlitCapture()`) until anything that shapes it changes; an unshaded camera-facing Image also repeats while its pose relative to the camera holds (`getCameraLockedReplayPose()`). A new path that blits from something short-lived (scratch bitmaps) or draws uncounted must call `cancelBlitCapture()`; one that zeroes a region's pretranslation for the call must call `markCapturedBlitWithoutPretranslation()`.
- Hot per-object/per-entity loops inline helper calls (each costs µs on device); the static BSP caches each dynamic object's leaf (`BSP.findLeaf`).
- `Camera3d.maxDrawDistance` is scaled by quality (not with fog on), eased, and device-capped (simulator 900, FHD 2500, HD 1000). Far fade is applied only at final draw, never baked into cached rasters.
- **Render quality**: any quality-for-speed constant goes in `BGE.RenderQualitySettings` with a value at all five levels in `RenderQualityPresets.bs` (current value at Ultra if already best, else Medium), read via `rendererObj.qualitySettings`. Extend `RenderQualityPresets.spec.bs` (completeness, monotonicity). `setQualitySettings()` bumps `qualityVersion`.
- Lighting (`Game.addLight()`): shades `isShaded` drawables; light-only changes relight without re-projecting.
- Fog (`Camera3d.fog`, `BGE.Fog`): `fogBackdrop` stage after the skybox (one rect, its top at the draw distance or the horizon, whichever is lower, down to the ground's edge), `fogSilhouettes` stage after planes (`castsFogSilhouette` drawables: a model as up to 3 height parts, `BGE.FogSilhouettes`; with `Fog.silhouetteHulls` (default) each part is the convex hull of its own projected points, the union filled as rect bands breaking at corners and stepping each edge at most `fogSilhouetteBand` px down and across (on a shared grid; one polygon skips span merging), else as screen boxes; never overlapping; snapped to whole pixels; drawn at `silhouetteOpacityLead` (default 1, thirdPerson 4) x the lost opacity; repeated while nothing moves), and `castsFogSilhouette` walls walk out to `silhouetteReach` and draw far pieces as merged white-column strips tinted the fog colour. `Drawable.fadeDistanceScale` (e.g. 2 for torch flames) fades and culls a drawable as if the draw distance were that much farther, so light sources show through fog. Fog on fixes the draw distance at `maxDrawDistance` across quality levels (`Camera.fixesDrawDistance()`) unless `Fog.followsQuality`, which eases over `qualityTransitionSeconds`.
- Level walls (`renderer/walls/`): segments as texture-column strips walked front to back through a BSP; hide sorted objects behind them. One per renderer, `Camera3d` only, no collision.
- Quad columns (`renderer/quadColumns/`): textured quads/sprites/text/model faces as power-of-two texel columns; still objects draw once into a temp bitmap.
- `SceneObjectPlane` (`fillMode` `color`/`tiledImage`/`staticImage`) and `SceneObjectSkybox` handle roll by rendering unrolled then rotating.
- `drawWorldPolyline/Circle/Arc/Bar` draw world-space debug shapes (`drawWorldBar` takes RGBA).
- Flat fills: `drawPolygonTo()` fills the convex hull (skips QuickHull when the points are already convex in order) and `drawTriangleTo()` a triangle, each as `DrawRect` bands (`drawConvexPolygonAsSpansTo()`) or exact triangles (two `DrawTransformedObject` each), whichever is cheaper by `POLYGON_SPAN_BANDS_PER_TRIANGLE`/`TRIANGLE_SPAN_MAX_BANDS` (rendererTest `polygon-fill-benchmark`, #539). Fog's `hullRects()` fills unions of polygons without overlap, a different job; it's ~2x dearer per rect.

## Device gotchas (headless brs-engine can't see these)
- Never pass negative scale with nonzero rotation to a native draw — Roku only mirrors at rotation 0.
- Roku queues bitmap draws: never draw into a bitmap after reading from it in the same frame. And keep a source bitmap (e.g. a local strip) referenced until its queued draws have run: freed straight after, the copies can come out empty, at random (the ground's supertexture did). `Finish()` on the destination didn't prevent it.
- `ScratchBitmapPool` bitmaps (only the mirrored+rotated blit uses them) aren't cleared on reuse, aren't reused within a frame, and regions must start at (0,0). Never keep anything built from them past the frame.
- ~13,000 queued draws into one bitmap per frame → all further draws silently dropped. Stay well under.
- HD has 64MB texture memory (`rokubot textures`); FHD scratch bitmaps are ~4.5MB each.
- `Renderer` enables alpha on its target, else transparent corners blit black.
- Never `Finish()` an `roScreen` the game draws to directly (early present → flicker).
- Draw costs vary >10x and aren't predictable from code — measure (rendererTest, `quad-fill-benchmark`), never assert. Keep blocking setup short (OS watchdog).
