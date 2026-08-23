# Composable terrain planes: far-clip and multi-layer ground

Design toward [#53](https://github.com/markwpearce/brighterscript-game-engine/issues/53) (tile the
plane's texture instead of anchoring a single finite decal) and
[#124](https://github.com/markwpearce/brighterscript-game-engine/issues/124) (a real, engine-wide
draw-distance far-clip, unifying `SceneObjectPlane`'s hardcoded `512`). Deliberately deferred from the
[camera roll and plane horizon design](2026-08-19-camera-roll-and-plane-horizon-design.md), which
called out "plane color fill" and "composable tiled/non-tiled planes" as follow-ups - this is that
follow-up.

## Problem

`DrawablePlane`/`SceneObjectPlane` has exactly one rendering mode today: a texture anchored so its
center pixel sits on the plane's world position, finite, and running out (correctly showing
background) once the camera moves far enough from that anchor. That's the right behavior for a
one-off decal (e.g. `examples/terrain`'s track-map image) but wrong for a texture meant to repeat
(e.g. its checkerboard ground) and offers no way to layer a colored base, a repeating ground texture,
and a specific decal on top of each other - which is what an actual driving/terrain surface needs.

Separately, there is no engine-wide "how far can the camera see" concept (issue #124's own writeup):
`Camera3d.isInView()` checks only the four angled frustum sides, never distance; the only place a
far cutoff exists at all is `SceneObjectPlane.SCENE_OBJECT_PLANE_FAR_DISTANCE = 512`, a private
constant with no relationship to the camera or renderer. A ground plane can stop rendering while an
ordinary billboard placed farther away stays fully visible forever.

## Non-goals

- **#125** (fade near the draw-distance limit) and **#126** (adaptive FPS-based tuning of the draw
  distance) both explicitly depend on this work landing first, and are their own separate designs -
  #126 in particular is a real control loop (hysteresis, sample window, step size) that needs tuning
  against a live scene, not a same-PR add-on. This design only needs `maxDrawDistance` to be a plain,
  live, game-settable field for either of those to build on later.
- **#65** (skybox) and **#66** (distance fog) are separate rendering features, not plane-specific.
- **#119** (diagonal striping on thin oriented `SceneObjectRectangle` billboards) is explicitly
  scoped, in its own issue, as unrelated to plane/terrain rendering - not part of this work.
- Tiling a plane whose normal isn't axis-aligned with world up, or planes at arbitrary angles to each
  other, aren't specifically tested - the design doesn't assume axis-alignment, but the only verified
  configuration is a level ground plane (matching every existing use).

## Approach

### A. `Camera3d.maxDrawDistance` (#124)

Add `maxDrawDistance as float = 1000` to `Camera3d`. Dirty-checked the same way
`fieldOfViewDegrees`/`lastProjectionFieldOfView` already is, via a new `lastMaxDrawDistance` shadow
field feeding the existing recompute-on-change machinery (`checkMovement`/`onCameraMovement`).

`isInView()` gains a distance check alongside its existing four angled-side checks: the forward
distance from the camera along `orientation` (`BGE.Math.VectorOps.dotProduct(point - camera.position,
camera.orientation)`) is rejected if it exceeds `maxDrawDistance`. This is a plain dot-product compare,
not a new `CameraFrustumSide`/normals entry - the existing frustum-side machinery models four angled
half-planes converging behind the camera; a far plane perpendicular to the view axis doesn't need
that machinery, just a distance compare against the existing per-object `negDistanceFromCamera` axis.

`SceneObjectPlane` drops `SCENE_OBJECT_PLANE_FAR_DISTANCE` entirely and reads `camera.maxDrawDistance`
wherever that constant was used: the ray-cast fallback distance in `getPerspectivePointsByCamera`, and
`getPrePerspectiveBmp`'s bitmap sizing.

**This is a real behavior change**, accepted deliberately per discussion: ordinary billboards/models
beyond 1000 world units now cull (previously unbounded), and the plane's rectified bitmap grows from
its current ~512-tall/~1024-wide footprint to ~1000×2000 at a 90° FOV - roughly 4x the pixel/memory
cost of today. Needs on-device verification (frame rate and correctness) on `examples/terrain` and
`examples/3d`, not just `npm run check`/`npm run validate-examples`.

### B. `DrawablePlane` gains three composable fill modes

```
enum PlaneFillMode
  color = "color"
  tiledImage = "tiledImage"
  staticImage = "staticImage"
end enum
```

- **`staticImage`** - today's only mode, formalized under a name: a `roRegion` anchored so its center
  pixel sits on the plane's world position (`BGE.Math.worldPointToTexturePixel`), finite, runs out at
  its own edges. Unchanged behavior - `examples/terrain`'s track-map texture keeps working exactly as
  it does today.
- **`color`** - new. No region at all; reuses the `color`/`alpha` fields every `Drawable` already has.
  Skips the entire texture-warp/slice pipeline (`getPrePerspectiveBmp`/`populatePerspectiveBmp`/
  `drawPerspectiveBmpSlicesToByCamera`) - instead, `performDraw` projects the already-computed
  world-space quad (`m.perspectivePoints.actual`, from `getPerspectivePointsByCamera`) to canvas
  points the same way any other 3D object projects a point, and does one `Renderer.drawPolygon` fill.
  Cheapest of the three modes, and - having no texture bounds - never "runs out": a `color` plane is
  the natural base/backdrop layer under the other two.
- **`tiledImage`** - new. Builds a cached "supertexture" bitmap once (lazily, on first draw): the base
  texture repeated enough times per axis to cover the world-space footprint bounded by
  `camera.maxDrawDistance` (`tilesPerAxis = ceil(2 * maxDrawDistance / tileSize) + 1`), so a single
  anchor point wrapped into the supertexture's own bounds is always far enough from every edge to
  cover the actual required footprint. Per-frame cost is unchanged from today - the exact same single
  `drawRotatedImageWithCenterTo` + scale call, just against the cached bigger bitmap instead of the
  original single tile. The anchor computation (`worldPointToTexturePixel`'s result) is wrapped modulo
  the tile's own width/height before being re-centered into supertexture space; the *relative*
  geometry the warp depends on (rotation angle, `distanceFromTopToBottom`, `footInfo.distanceToPoint`)
  is already translation-invariant, so wrapping only the anchor is correct.
  - Memory cost scales with `(maxDrawDistance / tileSize)²` - a small tile (e.g. a 64×64 grass square)
    against the default 1000-unit draw distance means a moderately large cached bitmap (roughly
    1000×1000 px territory); this is a one-time, lazily-built cost, not per-frame, but is worth
    surfacing in the `DrawablePlane` doc comment so a game author picks a tile size with this in mind.
  - Rebuilt (cache invalidated) only if `maxDrawDistance` changes after the plane was constructed -
    otherwise built once and reused for the plane's lifetime.

`DrawablePlane`'s constructor takes `fillMode` plus either a `region` (image modes) or a `color`
(color mode) - the exact parameter shape (optional args object vs. small named factory functions per
mode) is an implementation detail for the plan, not fixed here.

### C. Composability (stacking multiple planes)

Each `DrawablePlane` remains its own independent `Drawable`/`SceneObject` - nothing new is needed to
stack a `color` base, a `tiledImage` grass layer, and a `staticImage` road decal as three separate
planes (e.g. three `addDrawable` calls on the same entity, or spread across entities). Draw order for
planes that occupy the same world position/depth already falls out of the existing depth-sort
tie-break (`SceneObject.stableSortKey`/`getLastSortIndex`, see issue #59) - insertion order wins ties.
This is called out in the `DrawablePlane` doc comment as the way to control layering (add the base
layer first), rather than introducing a new explicit z-ordering mechanism for planes specifically.

## Testing

- Rooibos coverage: `Camera3d.isInView()`'s new far-distance rejection; the tile-wrap modulo math
  (`worldPointToTexturePixel` anchor wrapping); construction/field defaults for each `PlaneFillMode`.
- Existing `SceneObjectPlane`/`DrawablePlane`-adjacent specs updated for the renamed
  `SCENE_OBJECT_PLANE_FAR_DISTANCE` → `camera.maxDrawDistance` plumbing.
- Mandatory on-device pass via the `rokubot-examples` workflow on `examples/terrain`: all three fill
  modes individually, a stacked composition of at least two layers, and an FPS check with the new
  (larger) default `maxDrawDistance` before this is considered done - static analysis alone has missed
  runtime-only bugs in this codebase before (see the `=`-comparison crash and the entity-registration
  bug, both only caught by an actual sideload).

## Open questions for the implementation plan

- Exact `DrawablePlane` constructor/factory shape for the three modes.
- Whether `examples/terrain` should be updated to demonstrate stacking (e.g. a `color` base under the
  existing checkerboard-as-`tiledImage` and map-as-`staticImage`), given it's the only example
  exercising `DrawablePlane` today.
