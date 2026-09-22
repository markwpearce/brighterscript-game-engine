# Angle-based sprite selection for pseudo-3D billboards (issue #104)

## Problem

The engine's billboard drawables (`Image`/`AnimatedImage`/`Sprite`) always show the same
texture regardless of viewing angle. Classic Doom/Duke3D-style monster sprites fake full 3D
orientation by pre-rendering N views (e.g. 8 compass directions) of an animation and swapping
between them based on the angle between the camera and the entity's facing — the object never
actually rotates in 3D, but the *image* changes to suggest it did. This is the same trick
`DrawableSphere` uses for shape (always face the camera via `directScaled`), applied here to
texture selection instead.

## Goals

- A new drawable, `DrawableOrientedSprite`, that composes with `Sprite`'s existing named
  animations (walk, idle, etc.) by adding an axis: which of N angle buckets is active,
  recomputed every frame from the camera-to-entity angle.
- Configurable bucket count (`numAngles`, default 8 — the classic Doom count), not hard-coded.
- Configurable vertical/elevation bucketing (`numElevationBands`, default 1 — no vertical
  distinction, fully backward compatible), so a sheet can optionally provide a different sprite
  for "camera looking down on this" / "camera looking up at this" in addition to azimuth.
- Zero changes to `SceneObjectImage`/`SceneObject` — the whole feature lives in the `Drawable`
  layer by reusing `Sprite.addAnimation`/`playAnimation` and `AnimatedImage`'s existing
  time-based frame indexing unmodified.
- Optional mirroring: one angle bucket's art can be declared "the mirror of" another bucket's,
  so a sheet that only draws (say) a right-side profile doesn't also need a left-side profile.
- A runnable demo: a character entity in `examples/terrain`'s `WorldRoom`, built from the
  supplied Helix spritesheet, that visibly swaps facing as the free-fly camera orbits it.

## Non-goals

- Non-linear elevation band boundaries (e.g. a wider "level" band than the extremes) — bands
  are equal-sized slices of the -90°..+90° pitch range. Can be revisited if a real sheet needs
  it; nothing about the design below forecloses it later.
- Any change to `Image`/`AnimatedImage`/`Sprite`/`SceneObjectImage` themselves; this is purely
  additive.
- Resolving the Helix sheet's ambiguous top "idle" block (see Appendix) — the demo uses frame 0
  of each walk-direction row as that direction's idle pose instead.

## Design

### `DrawableOrientedSprite` (`src/source/engine/drawables/DrawableOrientedSprite.bs`)

Extends `BGE.Sprite`. Constructor signature matches `Sprite`'s with two extra params:

```
sub new(owner as GameEntity, spriteSheet as ifDraw2d, cellWidth as integer, cellHeight as integer, numAngles = 8 as integer, numElevationBands = 1 as integer, args = {} as roAssociativeArray)
```

Public API:

```
' Registers one animation per angle bucket under `baseName` (e.g. "walk"), for the single
' elevation band (numElevationBands = 1, the default/common case — no vertical distinction).
' Sugar for addElevationOrientedAnimation(baseName, [angleFrames], frameRate, playMode).
' `angleFrames` must have exactly `numAngles` entries, ordered starting at bucket 0 = the
' entity's front (camera looking directly at the entity's forward side) and proceeding
' clockwise (viewed from above) through the remaining buckets. Each entry is either:
'   - an integer[] of frame indexes (this bucket's own art), or
'   - {mirrorOf: {elevation: E, angle: A}} - reuse another bucket's frames, flipped
'     horizontally, for buckets whose sheet doesn't draw a distinct view (e.g. only a right
'     profile is drawn; the left profile bucket mirrors it).
' Throws a clear error if angleFrames.Count() <> numAngles, or if a mirrorOf target is not a
' real (non-mirrored) bucket registered in this same call.
function addOrientedAnimation(baseName as string, angleFrames as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void

' Registers the full elevation x angle grid under `baseName`. `elevationBands` must have
' exactly `numElevationBands` entries; each entry is itself an `angleFrames` array in the same
' shape addOrientedAnimation takes (numAngles entries, each an integer[] or a mirrorOf tuple).
' Elevation band 0 = steepest "camera below the entity, looking up at it"; band
' numElevationBands - 1 = steepest "camera above the entity, looking down on it"; bands split
' the -90..+90 degree pitch range into equal slices (see Non-goals).
' Validates every band's angleFrames the same way addOrientedAnimation does, plus that every
' mirrorOf tuple's `elevation` is a valid band index.
function addElevationOrientedAnimation(baseName as string, elevationBands as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void

' Selects which base animation is currently playing (analogous to Sprite.playAnimation, but
' picks among the (numElevationBands x numAngles) per-bucket animations registered for this
' baseName). Errors if baseName was never registered via addOrientedAnimation /
' addElevationOrientedAnimation.
sub playOrientedAnimation(baseName as string)
```

Internal state: `orientedAnimations` (baseName -> a `numElevationBands`-length array of
`numAngles`-length arrays, each cell either a real internal animation name or
`{mirrorOf: {elevation, angle}}`), `activeBaseAnimationName`, `currentElevationBand`/
`currentAngleBucket` (both start invalid so the first `update()` always resolves a real
bucket), `baseScaleX` (the scale magnitude to restore/negate — captured once, on construction,
from the drawable's own `scale.x`).

`override sub update()`:

```
override sub update()
  if m.activeBaseAnimationName <> ""
    camera = m.owner.game.canvas.renderer.camera
    elevationBand = m.computeElevationBand(camera)
    angleBucket = m.computeAngleBucket(camera)
    if elevationBand <> m.currentElevationBand or angleBucket <> m.currentAngleBucket
      m.currentElevationBand = elevationBand
      m.currentAngleBucket = angleBucket
      entry = m.resolveBucket(m.activeBaseAnimationName, elevationBand, angleBucket)  ' follows a mirrorOf to its source bucket
      super.playAnimation(entry.animationName)
      m.scale.x = entry.isMirrored ? -m.baseScaleX : m.baseScaleX
    end if
  end if
  super.update()
end sub
```

`computeAngleBucket(camera as BGE.Camera) as integer`:

- If `camera` is not a `Camera3d`, returns `0` unconditionally (a 2D camera has no facing/orbit
  concept, so bucketing is meaningless — documented no-op, not an error).
- Otherwise:
  1. `toCamera = camera.position - m.owner.position`, flattened to the XZ plane.
  2. `angleToCamera = Atan2(toCamera.x, toCamera.z)` (matching the axis/sign convention
     `BGE.Math.getRotationMatrix`/`Camera3d.rotate` already use for yaw — confirmed during
     implementation against a known orbit, not assumed).
  3. `relative = normalizeAngle(angleToCamera - m.owner.rotation.y)` into `[0, 2π)`.
  4. `bucketSize = 2π / numAngles`; `bucket = Floor((relative + bucketSize / 2) / bucketSize) mod numAngles`
     (the `+ bucketSize / 2` centers bucket 0 on "camera exactly at 0°" rather than starting a
     bucket boundary there).

`computeElevationBand(camera as BGE.Camera) as integer`:

- If `camera` is not a `Camera3d`, or `numElevationBands = 1`, returns `0` unconditionally (no
  vertical distinction requested/possible).
- Otherwise:
  1. `deltaY = camera.position.y - m.owner.position.y`; `horizontalDistance = length of toCamera's XZ component` (reusing the same `toCamera` vector `computeAngleBucket` derives).
  2. `pitch = Atan2(deltaY, horizontalDistance)`, in `[-90°, +90°]` — no wraparound, unlike azimuth.
  3. `bandSize = 180° / numElevationBands`; `band = clamp(Floor((pitch + 90°) / bandSize), 0, numElevationBands - 1)`.

This mirrors the constructor+hook customization pattern `DrawableSphere` uses (force behavior
in the `Drawable` subclass's constructor/override, no new `SceneObject` subclass) — here the
"forced behavior" is swapping which registered `Sprite` animation is active, computed from the
camera each `update()`, rather than a forced `drawMode`.

### Why no `SceneObjectImage`/`SceneObject` changes

`Sprite`/`AnimatedImage` already push the resolved frame into the paired `SceneObjectImage` via
`sceneObj.frameNumber` (used for its region-name cache key and dirty-check) every `update()`.
Since `DrawableOrientedSprite` only changes *which* registered `SpriteAnimation` is active before
delegating to the existing `Sprite`/`AnimatedImage` update logic, that existing wiring already
does the right thing unmodified — a bucket change looks exactly like any other animation switch
already supported today.

Mirroring reuses the engine's existing negative-`scale.x`-flips-a-billboard behavior (already
threaded through `SceneObjectBillboard`'s direct/`directScaled` draw path via
`m.drawable.scale.x`), so no new draw-time code is needed for it either. This will be confirmed
against a real `directScaled` billboard during implementation (TDD) since the existing code
paths that reference `drawable.scale.x` were written for scaling, not explicitly documented as
a flip mechanism — if `DrawTransformedObject` doesn't already treat a negative scale as a
horizontal flip on this engine's supported Roku targets, mirroring falls back to requiring
distinct art per bucket (i.e. `mirrorOf` becomes unavailable) and that finding gets folded back
into this spec before the plan is written.

### Error handling

- `addOrientedAnimation`/`addElevationOrientedAnimation`: a wrong `angleFrames.Count()` (or
  wrong `elevationBands.Count()`), or a `mirrorOf` target that doesn't point at a real
  non-mirrored bucket registered in the same call (including an out-of-range `elevation`
  index), are all hard runtime errors with a message naming the offending
  bucket/band/baseName (matching this codebase's existing fail-fast validation style rather
  than silently clamping/ignoring bad input).
- `playOrientedAnimation` with an unregistered `baseName`: hard runtime error, matching the
  above rather than silently doing nothing.
- `computeAngleBucket`/`computeElevationBand` with a non-`Camera3d` camera: not an error —
  always resolves to bucket/band 0.

### Testing

- Rooibos unit tests for the pure angle→bucket and pitch→band math (`computeAngleBucket`/
  `computeElevationBand`'s core calculations, refactored into small pure/testable functions)
  using synthetic camera/entity positions and rotations — no `Game` required for this part.
  Covers `numElevationBands = 1` (always band 0) alongside multi-band cases.
- A `Game`-backed Rooibos test (matching `Sprite.spec.bs`'s existing pattern of a real `Game` +
  `GameEntity` + a small synthetic `ifDraw2D` sheet) covering: `addOrientedAnimation`/
  `addElevationOrientedAnimation` validation errors (bad count, bad `mirrorOf` target/elevation
  index), and that `playOrientedAnimation` combined with a moved/rotated synthetic camera swaps
  which underlying `SpriteAnimation` is active across both axes, including a mirrored bucket
  case (confirms `scale.x` flips sign, not the mirror's exact pixels).
- Manual verification: the `examples/terrain` character (see below), confirmed via
  `rokubot-examples` by orbiting the free-fly camera around it and screenshotting each expected
  facing change — required per this repo's convention that example/runtime behavior isn't
  proven by unit tests or static analysis alone.

### `examples/terrain` integration

- New entity (name TBD at implementation time, e.g. `Guard`) under
  `examples/terrain/src/source/Entities/`, following the `LowWall` convention: extends
  `BGE.GameEntity`, built via a placement-args `onCreate`, added to `WorldRoom` via a new
  `addCharacters()`-style method mirroring `addTrees()`/`addLowWalls()`.
  - Uses `DrawableOrientedSprite` with the Helix sheet (640x1024, 80x64 cells, 8 cols x 16 rows)
    and `numAngles: 8`, `numElevationBands: 1` (default) — the Helix sheet has no distinct
    top-down/bottom-up art, so this demo exercises the azimuth axis only; the elevation axis is
    covered by unit tests instead (see Testing).
  - `addOrientedAnimation("walk", ...)` sourced from the sheet's bottom 8x8 grid (sheet rows
    8-15; row r's 8 frames are its walk cycle for one facing).
  - `addOrientedAnimation("idle", ...)` reuses frame 0 of each of those same 8 rows (single-frame
    "idle" per bucket) rather than the sheet's separate, ambiguous top block (see Appendix) —
    sidesteps having to resolve that block's semantics at all.
  - `drawMode: BGE.SceneObjectDrawMode.directScaled` (matches the existing tree convention for a
    billboard that scales with camera distance) with `banksWithCameraRoll: true` to match.
  - The exact row-to-compass-direction mapping (which of the 8 rows is "front" vs "front-left"
    etc.) and whether any bucket needs `mirrorOf` will be determined empirically by loading the
    sheet in the example and visually comparing against known camera angles (via
    `rokubot-examples`), not guessed up front — the engine feature's design doesn't depend on
    getting this mapping right, only the demo's content does.

## Appendix: Helix spritesheet geometry (for implementation reference)

`helix_full_sheet.png`, 640x1024 RGBA, sliced as an 8-column x 16-row grid of 80x64 cells
(confirmed via direct pixel inspection, not the asset's own documentation):

- Sheet rows 0-7 (pixel y 0-511): a single-frame-per-row block whose semantics are ambiguous —
  sampling showed 3 near-identical "front" frames, 1 right-profile frame, 3 near-identical
  "back" frames, then another right-profile frame that visually matched the first one (not a
  mirrored left profile as might be expected of an 8-direction pack). Likely idle-animation
  breathing frames for only 4 true cardinal-ish views, not 8 evenly-spaced compass directions.
  **Not used** by this design (see Non-goals) — deliberately avoided rather than resolved.
- Sheet rows 8-15 (pixel y 512-1023): an 8-direction x 8-frame walk cycle grid, one direction
  per row, one animation frame per column. This is what the terrain demo uses for both its
  "walk" and (via frame 0) "idle" oriented animations.
