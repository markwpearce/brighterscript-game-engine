---
title: Drawables and SceneObjects
group: Guides
order: 3
---

# Drawables and SceneObjects

This is a reference for the visual side of BGE: every `Drawable` subclass, the `SceneObject` each
one registers with the `Renderer`, and how the `Renderer` actually turns a scene full of
`SceneObject`s into pixels every frame. Read [Building a Game with BGE](/game-engine-overview) first
if you haven't - this guide assumes you already know how a `Drawable` attaches to a `GameEntity`.

## The pipeline, in one sentence

A `Drawable` doesn't draw itself. `GameEntity.addDrawable(name, drawable)` attaches it, and once per
frame `Drawable.addToScene(rendererObj)` registers a matching `SceneObject` with the `Renderer` -
from then on, the `Renderer` owns drawing it, not the `Drawable`. The `Drawable` still computes its
own transformation matrix from `offset`/`rotation`/`scale` (see `Drawable.computeTransformationMatrix`),
but the actual per-frame draw call, camera-relative positioning, and draw-mode handling all live on
the `SceneObject` side.

## Every Drawable / SceneObject pair

| Drawable             | SceneObject             | What it draws                                                              |
| --------------------- | ------------------------ | --------------------------------------------------------------------------- |
| `Image`               | `SceneObjectImage`       | A single bitmap region - the basic sprite.                                  |
| `Sprite`              | `SceneObjectImage`       | An `Image` subclass that indexes into a sprite sheet by frame number.        |
| `AnimatedImage`       | `SceneObjectImage`       | A `Sprite` that advances its own frame index over time.                     |
| `DrawableRectangle`   | `SceneObjectPolygon`     | A filled or outlined rectangle.                                             |
| `DrawablePolygon`     | `SceneObjectPolygon`     | An arbitrary filled or outlined polygon.                                    |
| `DrawableLine`        | `SceneObjectLine`        | A single line segment between two points.                                   |
| `DrawableText`        | `SceneObjectText`        | Text rendered with a `roFont`.                                              |
| `Model3d`             | `SceneObjectModel`       | A triangle-mesh 3D model (loaded via `Game.load3dModel`, see `STLParser`).   |
| `DrawablePlane`       | `SceneObjectPlane`       | A textured ground/floor plane, rendered with a Mode-7-style perspective warp (see below). |
| _(billboard drawables, e.g. images used with `directToCamera`/`directScaled` draw modes)_ | `SceneObjectBillboard` | Always faces the camera regardless of its own rotation. |

Every `SceneObject` subclass lives under `src/source/engine/renderer/sceneObjects/`. If you're
adding a new visual primitive, the pair goes together: a `Drawable` subclass that computes its own
geometry/transform, and a `SceneObject` subclass whose `addToScene` call the `Drawable` invokes.

## SceneObjectDrawMode

Every `SceneObject` has a `SceneObjectDrawMode`, controlling how it reacts to the camera's rotation
and perspective:

| Draw mode                             | Behavior                                                               |
| -------------------------------------- | ------------------------------------------------------------------------ |
| `matchCamera`                          | Follows the camera's rotation/perspective like a normal 3D object.      |
| `directToCamera`                       | Always faces the camera (billboard), ignoring its own rotation.         |
| `directScaled`                         | Like `directToCamera`, but also compensates scale for camera distance.  |
| `oriented` / `orientedDrawBackFace`    | Respects its own rotation in 3D, optionally drawing back faces.         |
| `wireFrame` / `wireFrameDrawBackFace`  | Outline-only rendering of the triangle mesh.                           |
| `solid` / `solidDrawBackFace`          | Filled triangle rendering.                                             |

This is what gives a fundamentally 2D-raster engine its pseudo-3D/billboard capability (see
`examples/3d`) - `examples/rendererTest` has a runnable demo per mode (`DemoList.bs`).

## How `Renderer.drawScene()` actually draws a frame

`Renderer.drawScene()` (`engine/renderer/Renderer.bs`) runs once per frame, per canvas (there's a
separate `Renderer` for the game canvas and the UI canvas). It does three things, in order:

1. **`updateSceneObjects()`** - recomputes world positions and camera-distance for every registered
   `SceneObject` (see "Per-object update", below).
2. **Sort by depth** - `m.sceneObjects.sortBy("negDistanceFromCamera")`, so farther objects draw
   first and nearer objects draw over them (simple painter's algorithm, no z-buffer).
3. **Draw in two passes**: every `SceneObjectPlane` first, then every other enabled `SceneObject`
   whose `negDistanceFromCamera < 0` (i.e. in front of the camera). Planes are drawn first because
   they're meant to be a ground/floor - drawing them before anything else means normal
   painter's-algorithm depth sorting for everything else (which _does_ sort against the camera
   distance) still looks correct sitting on top of the plane. This is a `TODO` for proper occlusion
   culling in the engine's own comments, not a settled final design.

### Per-object update (`SceneObject.update`/`draw`)

`SceneObject.update(cameraObj)` and `.draw(rendererObj)` are called every frame for every object,
but most of the expensive work is skipped unless something actually changed:

- **`objMovedLastFrame = m.drawable.movedLastFrame(true)`** - `Drawable`/`Camera` use a
  `MotionChecker` (`utils/MotionChecker.bs`) for dirty-checking; if neither the object nor the
  camera moved since last frame, `update()` skips recomputing the transformation matrix and world
  position entirely.
- **`isPotentiallyOnScreen(cameraObj)`** - a cheap frustum check gate in `draw()`. If the object
  hasn't moved relative to the camera and was on-screen last frame, it skips straight to drawing;
  otherwise it checks the camera's frustum before doing any real work.
- **`findCanvasPosition(rendererObj, drawMode)`** - only re-run when `objMovedInRelationToCamera()`
  is true (the object or camera moved) or there's no valid canvas position yet. This is where a
  `SceneObject` subclass computes whatever camera-relative geometry it needs before drawing (e.g.
  `SceneObjectPlane` computes the frustum-to-plane intersection here - see below).
- **`performDraw(rendererObj, drawMode)`** - the actual draw call. Several `SceneObject` subclasses
  (`SceneObjectBillboard`, `SceneObjectPlane`) cache a rendered bitmap and reuse it across frames
  when nothing's moved, rather than re-rasterizing from scratch every frame - drawing that cached
  bitmap is far cheaper than recomputing the object's projected geometry and re-drawing it.

Two supporting pieces worth knowing about if you're touching rendering performance:

- **`TriangleCache`** caches rasterized triangle bitmaps - triangle drawing (`drawBitmapTriangleTo`,
  `drawPinnedCorners`) is comparatively expensive per call, since it checks out and rasterizes
  scratch bitmaps internally. Code that draws the same triangle-heavy shape every frame should
  render once into a cached bitmap and blit that, rather than redoing the full draw at 60fps -
  `examples/rendererTest/CornerPinGridTest.bs` is a worked example of this pattern (and of what
  happens without it: most of a 26-tile grid silently failed to render after the first few tiles).
- **`ScratchBitmapPool`** (`engine/renderer/ScratchBitmap.bs`) hands out reusable off-screen bitmaps
  for exactly this kind of intermediate rendering work, so it doesn't need to allocate a fresh
  `roBitmap` every frame. **Pooled bitmaps are handed out as-is, not cleared** - if you draw into
  one and don't cover its entire area, whatever was left over from its previous, unrelated use will
  still be there. Always `Clear()` a scratch region yourself before drawing into it unless you're
  certain your draw call will fully cover it.

## Deep dive: `SceneObjectPlane` (`DrawablePlane`)

`DrawablePlane`/`SceneObjectPlane` render a textured, (mostly) infinite ground/floor plane -
`examples/terrain` is a small, playable demo of it (drive a camera around above a Mario Kart track
image, or toggle to a checkerboard). It works nothing like the other `SceneObject`s, which each
draw one small object; a plane covers the camera's entire view of the ground, so the implementation
is closer to a classic SNES "Mode 7" renderer than to a sprite draw call.

### The technique

Each frame, `SceneObjectPlane` (in `findCanvasPosition`, via `getPerspectivePointsByCamera`):

1. Casts a ray from each of the camera's four frustum corners (`Camera3d.frustumRays`) and
   intersects each with the plane (`BGE.Math.intersectRayWithPlane`) - this gives the four
   world-space points where the camera's view "hits the ground" at its corners. Corners whose rays
   don't hit the plane at all (pointing above the horizon) are approximated instead by rotating a
   point on the plane at `SCENE_OBJECT_PLANE_FAR_DISTANCE` around the plane's normal by half the
   field of view.
2. Converts those four world points into **texture pixel coordinates** via
   `BGE.Math.worldPointToTexturePixel` (see "Texture anchoring" below).
3. `populatePerspectiveBmp()` un-warps the resulting quad: it rotates/translates the *entire*
   source texture region so the quad's corner lines up correctly, then scales that into a
   rectangular "pre-perspective" bitmap - effectively turning "camera looking at a trapezoid on the
   ground" into "looking straight down at a flat rectangle."
4. `drawPerspectiveBmpSlicesToByCamera()` slices that pre-perspective bitmap into `~50` thin
   horizontal bands (near-to-far) and draws each one scaled to its correct on-screen size - bands
   near the camera are large, bands near the horizon shrink toward a single line, which is what
   produces the perspective effect.

### Texture anchoring

The plane is mathematically infinite (`y=0`, extending forever in `x`/`z`), but its texture is a
single finite bitmap region - there's no tiling (yet; it's a planned follow-up, not implemented).
`BGE.Math.worldPointToTexturePixel(worldPoint, textureCenterWorldPoint, textureWidth, textureHeight)`
anchors the texture's *center* pixel on wherever the plane actually sits in world space
(`textureCenterWorldPoint`, the plane entity's own world position) rather than on world `(0,0)` -
world points equal to the anchor map to the texture's center pixel, and points `n` units away map
`n` pixels away from center (1 world unit = 1 texture pixel, no additional scaling).

Practical implication: driving/looking far enough away from the plane's anchor point runs off the
edge of the texture. That's expected and handled correctly - `SceneObjectPlane.findCanvasPosition`
uses `BGE.Math.boundsOverlapRect` to skip drawing entirely once the camera's view can't possibly
overlap the texture at all (a cheap early-out), and for partial overlaps, the plane correctly shows
real texture on the side that's in-bounds and the renderer's background (transparent/black) on the
side that isn't - it does **not** wrap or repeat the texture to fill the screen.

### Gotchas if you touch this code

- **Scratch bitmaps are pooled and not cleared** (see the `ScratchBitmapPool` note above) - this bit
  particularly hard here, because the visual symptom of *not* clearing looked exactly like the
  texture "wrapping/repeating" the further you got from its valid bounds. It wasn't a sampling-wrap
  bug at all: `populatePerspectiveBmp()`'s scratch region and `prePerspectiveBmp` are reused,
  uncleared pooled bitmaps, and once the camera's view moved mostly or entirely outside the
  texture's valid area, the rotated draw call landed off-canvas and left the *previous, unrelated
  frame's* leftover pixels showing through - which happened to look like the track's own curb
  pattern, because that's literally what it was. Both bitmaps must be `Clear()`-ed before drawing
  into them each frame.
- **Slice seams**: `drawPerspectiveBmpSlicesToByCamera`'s destination position for each slice
  advances by a rounded (`cint`) pixel count, but each slice's own drawn height comes from a
  separate, unrounded scale factor - the two can disagree by a fraction of a pixel, leaving a thin
  black gap between adjacent slices (worst near the bottom of the screen, where slices are
  tallest/nearest the camera). Each slice is drawn a few pixels taller than its exact allotted band
  (`seamPaddingScale`) so neighbors overlap slightly instead of gapping.
- **Camera-orientation coupling**: if you're building a "chase camera" or similar that follows a
  moving point, don't use `camera.setTarget(fixedPoint)` every frame if you want the camera to turn
  the way a driver's/person's head turns - `setTarget` points the camera *at* that fixed point,
  which orbits the camera around it as its own position changes, rather than rotating the camera's
  own view. Set `camera.orientation` directly from your desired look direction instead (see
  `examples/terrain/src/source/Rooms/MainRoom.bs`'s `updateCameraOrientation`).
