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
- A runnable demo: a character entity in `examples/terrain`'s `WorldRoom`, built from the
  supplied Helix spritesheet, that visibly swaps facing as the free-fly camera orbits it.

## Non-goals

- Non-linear elevation band boundaries (e.g. a wider "level" band than the extremes) — bands
  are equal-sized slices of the -90°..+90° pitch range. Can be revisited if a real sheet needs
  it; nothing about the design below forecloses it later.
- Any change to `Image`/`AnimatedImage`/`Sprite`/`SceneObjectImage` themselves; this is purely
  additive.
- Mirroring one angle bucket's art to serve as another's. This was originally a goal (a sheet
  that only draws, say, a right-side profile wouldn't also need a left-side profile), gated on
  confirming that a negative `Drawable.scale.x` actually produces a horizontal flip through
  `SceneObjectBillboard`'s `directScaled` blit path. That confirmation never happened during
  implementation, and a final-review code read found it does **not** work as hoped:
  `drawRegionAsRotatedQuad()` derives its blit scale/rotation from `BGE.Math.CornerPoints`
  magnitude helpers (`getAvgWidth()`, `getAvgRotation()`), which discard the sign a negative
  `scale.x` would carry through the quad's world-space corners — the result is a
  180°-rotated-and-mislocated render, not a horizontal mirror. Per this goal's own fallback,
  `mirrorOf` was removed from the public API rather than shipped broken; every angle/elevation
  bucket needs its own real art. A real fix belongs in `SceneObjectBillboard` (out of scope for
  this feature, and not verifiable without on-device testing) — filed as issue #237.

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
' clockwise (viewed from above) through the remaining buckets. Each entry is an integer[] of
' frame indexes - that bucket's own art. Every bucket needs real art; there is no mirroring
' (see Non-goals).
' Logs an error and registers nothing if angleFrames.Count() <> numAngles, or if any entry
' isn't an integer[].
function addOrientedAnimation(baseName as string, angleFrames as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void

' Registers the full elevation x angle grid under `baseName`. `elevationBands` must have
' exactly `numElevationBands` entries; each entry is itself an `angleFrames` array in the same
' shape addOrientedAnimation takes (numAngles entries, each an integer[]).
' Elevation band 0 = steepest "camera below the entity, looking up at it"; band
' numElevationBands - 1 = steepest "camera above the entity, looking down on it"; bands split
' the -90..+90 degree pitch range into equal slices (see Non-goals).
' Validates every band's angleFrames the same way addOrientedAnimation does.
function addElevationOrientedAnimation(baseName as string, elevationBands as object, frameRate as integer, playMode = SpritePlayMode.Loop as SpritePlayMode) as void

' Selects which base animation is currently playing (analogous to Sprite.playAnimation, but
' picks among the (numElevationBands x numAngles) per-bucket animations registered for this
' baseName). Errors if baseName was never registered via addOrientedAnimation /
' addElevationOrientedAnimation.
sub playOrientedAnimation(baseName as string)
```

Internal state: `orientedAnimations` (baseName -> a `numElevationBands`-length array of
`numAngles`-length arrays, each cell a real internal animation name), `activeBaseAnimationName`,
`currentElevationBand`/`currentAngleBucket` (both start invalid so the first `update()` always
resolves a real bucket).

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
      bucket = m.orientedAnimations[m.activeBaseAnimationName][elevationBand][angleBucket]
      m.playAnimation(bucket.animationName)
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

Mirroring was originally planned to reuse the engine's negative-`scale.x`-flips-a-billboard
behavior threaded through `SceneObjectBillboard`'s `directScaled` draw path — see Non-goals for
why that turned out not to work and was dropped rather than shipped broken.

### Error handling

- `addOrientedAnimation`/`addElevationOrientedAnimation`: a wrong `angleFrames.Count()` (or
  wrong `elevationBands.Count()`), or a bucket entry that isn't an `integer[]`, log an error
  (via `m.owner.game.log(..., BGE.Debug.LogLevel.error)`, this codebase's existing convention —
  not a `throw`) naming the offending bucket/band/baseName and register nothing for that call.
- `playOrientedAnimation` with an unregistered `baseName`: same log-and-no-op convention.
- `computeAngleBucket`/`computeElevationBand` with a non-`Camera3d` camera: not an error —
  always resolves to bucket/band 0.

### Testing

- Rooibos unit tests for the pure angle→bucket and pitch→band math (`computeAngleBucket`/
  `computeElevationBand`) using synthetic camera/entity positions and rotations — no `Game`
  required for this part. Covers `numElevationBands = 1` (always band 0) alongside multi-band
  cases.
- A `Game`-backed Rooibos test (matching `Sprite.spec.bs`'s existing pattern of a real `Game` +
  `GameEntity` + a small synthetic `ifDraw2D` sheet) covering: `addOrientedAnimation`/
  `addElevationOrientedAnimation` validation errors (bad count, a non-array bucket entry), a
  `numAngles` other than the default 8, direct multi-band `addElevationOrientedAnimation`
  registration, and that `playOrientedAnimation` combined with a moved/rotated synthetic camera
  swaps which underlying `SpriteAnimation` is active across both axes.
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
  - `addOrientedAnimation("idle", ...)` uses the sheet's top single-frame-per-row block (sheet
    rows 0-7, see Appendix) rather than reusing a walk-cycle frame — each block shares the same
    per-row compass order, so idle bucket N and walk bucket N are just the corresponding row in
    each block.
  - `drawMode: BGE.SceneObjectDrawMode.directScaled` (matches the existing tree convention for a
    billboard that scales with camera distance) with `banksWithCameraRoll: true` to match.
  - The row-to-compass-direction mapping is documented by the asset itself (see Appendix) — no
    `mirrorOf` buckets are needed, since both blocks have real art for all 8 directions.

## Appendix: Helix spritesheet geometry (for implementation reference)

`helix_full_sheet.png`, 640x1024 RGBA, sliced as an 8-column x 16-row grid of 80x64 cells.
Per the asset's own documentation, both row blocks share the same per-block compass order,
starting at the block's first row: SW, S, SE, E, NE, N, NW, W.

- Sheet rows 0-7 (pixel y 0-511): a single-frame-per-row idle-pose block, one direction per row
  (row 0 = SW, row 1 = S, ... row 7 = W).
- Sheet rows 8-15 (pixel y 512-1023): an 8-direction x 8-frame walk cycle grid, one direction per
  row (row 8 = SW, row 9 = S, ... row 15 = W), one animation frame per column.

An earlier direct-pixel-inspection pass judged the top block "ambiguous" (several rows looked
near-identical) and avoided it, reusing walk-frame-0 as a stand-in idle pose instead. That read
was wrong — subtle diagonal-facing idle poses (SW/S/SE, or NW/N/NE) legitimately look very
similar to a quick visual scan, but the block is a real, complete 8-direction idle set matching
the walk block's own row order. The terrain demo now uses it directly.
