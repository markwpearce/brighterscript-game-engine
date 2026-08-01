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
| `DrawableRectangle`   | `SceneObjectRectangle`   | A filled and/or outlined rectangle.                                         |
| `DrawablePolygon`     | `SceneObjectPolygon`     | An arbitrary filled or outlined polygon.                                    |
| `DrawableLine`        | `SceneObjectLine`        | A single line segment between two points.                                   |
| `DrawableText`        | `SceneObjectText`        | Text rendered with a `roFont`.                                              |
| `Model3d`             | `SceneObjectModel`       | A triangle-mesh 3D model (loaded via `Game.load3dModel`, see `STLParser`).   |
| `DrawablePlane`       | `SceneObjectPlane`       | A textured ground/floor plane, rendered with a Mode-7-style perspective warp (see below). |
| `DrawableParallaxLayer` | `SceneObjectParallaxLayer` | A scrolling/tiling background (or foreground) layer that moves at a configurable fraction of the camera's movement. |
| _(billboard drawables, e.g. images used with `directToCamera`/`directScaled` draw modes)_ | `SceneObjectBillboard` | Always faces the camera regardless of its own rotation. |

Every `SceneObject` subclass lives under `src/source/engine/renderer/sceneObjects/`. If you're
adding a new visual primitive, the pair goes together: a `Drawable` subclass that computes its own
geometry/transform, and a `SceneObject` subclass whose `addToScene` call the `Drawable` invokes.

## Rectangles

`DrawableRectangle` is the primitive to reach for when you want a solid block of color - a paddle, a
brick, a health bar, a HUD panel. `GameEntity.addRectangle` builds and attaches one in a single call:

```brighterscript
' a 150x20 white paddle, drawn from the entity's position
m.addRectangle("body", 150, 20, {color: BGE.ColorsRGB.White})
```

`color` and `outlineRGBA` are **packed RGB** (`0xRRGGBB`), which is what every `Drawable` takes -
`BGE.ColorsRGB` is the named-color enum in that format, and `alpha` is a separate field. That's a
different format from the packed **RGBA** (`0xRRGGBBAA`) that the `Renderer.draw*` calls and
`BGE.Colors` use, and mixing the two up gives you a plausible-looking wrong color rather than an
error.

A rectangle is anchored at its **top left corner** by default (anchor `(0, 0)`) and extends right
and downwards on screen, the same as an `Image`. Call `setAnchor(x, y)` with normalized 0-1
coordinates to pivot around a different point instead - `setAnchor(0.5, 0.5)` centers it on the
entity's position, `setAnchor(0.5, 1)` plants its bottom edge there (handy for a sprite that should
grow from the ground up rather than from its center). Every `Drawable` with a rectangular
width/height (`Image`, `Sprite`/`AnimatedImage`, `DrawableRectangle`, `DrawableText`) supports this
the same way. Without `setAnchor()`, nothing changes - offsetting the drawable by half its size to
fake a centered anchor still works exactly as before:

```brighterscript
cornerOffset = BGE.Math.VectorOps.create(-width / 2, height / 2)
m.addRectangle("body", width, height, {color: BGE.ColorsRGB.Yellow, offset: cornerOffset})
' a RectangleCollider covers the same area for the same offset, so the two line up
m.addRectangleCollider("body", width, height, cornerOffset.x, cornerOffset.y)
```

To resize one later, call `setSize(width, height)` rather than assigning to `width`/`height`
directly (they're deliberately not public). A resize isn't *movement*, so the renderer's
dirty-checking can't see it - `setSize` calls `Drawable.invalidateGeometry()`, which bumps a
`geometryVersion` the `SceneObject` compares against to know it must recompute projected geometry
even though nothing moved. Any `Drawable` that changes shape in place should do the same.

### Outlines

Setting `outlineRGBA` on **any** billboard drawable - a rectangle, a polygon, an image, text -
strokes an outline around it. There's no separate on/off flag: a color means yes, `invalid` (the
default) means no, and the renderer skips all outline work when there isn't one. `outlineWidth` sets
the thickness in pixels.

```brighterscript
' a lime rectangle with a 2px white border
m.addRectangle("brick", 112, 30, {
  color: BGE.ColorsRGB.Lime,
  outlineRGBA: BGE.ColorsRGB.White,
  outlineWidth: 2
})

' outline only, no fill - needs an outline color, or nothing is drawn at all
m.addRectangle("frame", 200, 100, {filled: false, outlineRGBA: BGE.ColorsRGB.Cyan})
```

The stroke lives on `SceneObjectBillboard`, which draws it over the top of the fill each frame along
the object's canvas corner points. Two consequences worth knowing:

- The outline is stroked in **canvas space**, so it stays a constant width rather than warping with
  perspective in the `oriented` draw modes. For a 1-2px stroke that generally looks better than the
  alternative, but it does mean an outline isn't baked into the cached temp bitmap and is re-stroked
  on every frame - which is why it's opt-in via `outlineRGBA`.
- A `SceneObject` whose shape isn't a single quad has to opt out by returning `invalid` from
  `getOutlineCanvasPoints()`, which is what `SceneObjectModel` does - outlining a triangle mesh means
  the `wireFrame` draw modes, not this. `SceneObjectPolygon` overrides the same hook to stroke along
  its own point list instead of the inherited quad.

In the `wireFrame` draw modes the outline *is* the entire drawing, so it's stroked once by
`drawToCanvas` and skipped by the hook. Those modes fall back to the fill color when no `outlineRGBA`
is set, which is why they look the same as they always did.

### How a rectangle is drawn, and why it's a billboard

`SceneObjectRectangle` extends `SceneObjectBillboard`, so a rectangle orients and foreshortens in 3D
just like an image (see `examples/3d`'s RectanglesRoom, which cycles a ring of panels through every
draw mode). But unlike an image it has no texture to sample - it's one flat color - so it never uses
the inherited **pinned-corners** path: filling the projected quad produces identical pixels for far
less work, and `DrawableRectangle` never has to hold a bitmap of its own. That's how
`SceneObjectPolygon` draws, for the same reason.

It does still cache that fill into a **temp bitmap** in the oriented draw modes, exactly like a
polygon does. Filling a rotated quad means rasterizing two triangles through scratch bitmaps, which
is far too expensive to repeat every frame for something that hasn't moved - skipping the cache here
cost `examples/3d`'s RectanglesRoom about two thirds of its frame rate (22 FPS vs 63) before it was
put back. Whether a `SceneObject` caches a given draw mode is `usesTempBitmap(drawMode)`, which
`SceneObjectRectangle` overrides to also require `filled` - an outline-only rectangle has no fill
worth caching.

In the direct (billboard) draw modes with no rotation - which is the 2D case, since a `Camera2d`
resolves `matchCamera` to `directToCamera` - it takes a shorter path still, going out as a single
`DrawRect` with no triangle rasterization and no bitmap at all. That's the path `examples/breakout`
runs on for its paddle, ball and every brick.

Keeping the billboard base (rather than making a rectangle a 4-point `DrawablePolygon`) is what buys
the rest: backface culling and per-face `isShaded` shading, both of which need the surface normal a
quad has and an arbitrary polygon doesn't; the direct/billboard draw modes, which
`SceneObjectPolygon` ignores entirely; and a frustum check over the 4 already-computed world corners
instead of `SceneObjectPolygon.getPositionsForFrustumCheck`'s scan-every-vertex bounding cube (whose
8 corners collapse to the same 4 points for a flat quad anyway - pure overhead here).

## SceneObjectDrawMode

Every `SceneObject` has a `SceneObjectDrawMode`, controlling how it reacts to the camera's rotation
and perspective:

| Draw mode                             | Behavior                                                               |
| -------------------------------------- | ------------------------------------------------------------------------ |
| `matchCamera`                          | Follows the camera's rotation/perspective like a normal 3D object.      |
| `directToCamera`                       | Always faces the camera (billboard), ignoring its own rotation.         |
| `directScaled`                         | Like `directToCamera`, but sized by camera distance - a Doom-style sprite. |
| `oriented` / `orientedDrawBackFace`    | Respects its own rotation in 3D, optionally drawing back faces.         |
| `wireFrame` / `wireFrameDrawBackFace`  | Outline-only rendering of the triangle mesh.                           |
| `solid` / `solidDrawBackFace`          | Filled triangle rendering.                                             |

This is what gives a fundamentally 2D-raster engine its pseudo-3D/billboard capability (see
`examples/3d`) - `examples/rendererTest` has a runnable demo per mode (`DemoList.bs`).

`matchCamera`, `directToCamera` and `directScaled` are the **screen-aligned** (billboard) modes -
`isScreenAlignedDrawMode()` - and they keep an object square to the screen instead of turning it
in 3D. `directScaled` is the Doom-sprite one: it faces the camera and its on-screen size comes
from how far away it is, *independently of its own rotation*. That independence is the whole
point, and it's why `SceneObjectBillboard` builds the quad from the camera's own right/up axes in
world space and then projects it (`updateCanvasPointsForCameraFacingQuad`), rather than measuring
the object's own projected quad - measuring the latter would fold the object's orientation into
its size, so a sprite turned edge-on would squash. For the same reason a screen-aligned object is
never backface culled: it has no face to turn away.
`BGE.getDrawModeName(drawMode)` gives you a mode's name, for debug overlays or for an example that
lets you cycle through them (`examples/3d`'s BaseRoom displays it on screen).

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
  drew last frame **and nothing has moved since**, it skips straight to drawing; if the frustum
  *culled* it last frame and nothing has moved since, it stays culled without re-checking, which is
  what makes a static off-screen object free. A moving object always re-checks the frustum either
  way. Only a genuine cull latches this way: a draw that was attempted and failed is retried on the
  very next frame, because `findCanvasPosition()` and `performDraw()` are both
  transient-failure-prone and both already recover. A camera *projection* change - its frame size
  or field of view, neither of which counts as camera movement - lifts the latch too, via
  `Camera.projectionVersion`.
- **`findCanvasPosition(rendererObj, drawMode)`** - only re-run when `objMovedInRelationToCamera()`
  is true (the object or camera moved), there's no valid canvas position yet, or the camera's
  projection changed (`Camera.projectionVersion`, same signal as above). This is where a
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

## Parallax layers (`DrawableParallaxLayer`)

`DrawableParallaxLayer` scrolls a bitmap at a configurable per-axis fraction of the
camera's movement (`parallaxFactor`, a `BGE.Math.Vector`): `{1,1}` (the default) behaves
like an ordinary drawable, `{0,0}` pins it to the camera, `0 < factor < 1` gives a
background layer that drifts slower than the world, and `factor > 1` gives a foreground
layer that scrolls faster. `repeatX`/`repeatY` (defaulting to `true`/`false`) tile the
bitmap to cover the viewport along either axis.

Unlike every other billboard drawable, `SceneObjectParallaxLayer` extends `SceneObject`
directly rather than `SceneObjectBillboard` - a parallax layer is always flat 2D and may
draw several tiled copies in a single frame, so it skips the 3D/orientation/temp-bitmap
machinery entirely and just issues one `Renderer.drawObject()`/`drawScaledObject()` call
per visible tile. It also doesn't honor `Drawable`'s anchor (`setAnchor()`), rotation,
color/outline, or `drawMode` fields - `SceneObjectParallaxLayer.performDraw()` ignores all
of them and always draws from a top-left-anchored canvas position.

Attach one to an entity the same way as any other drawable:

```brighterscript
region = CreateObject("roRegion", bmp, 0, 0, bmp.getWidth(), bmp.getHeight())
owner.addDrawable("mountains", new BGE.DrawableParallaxLayer(owner, region, {
  parallaxFactor: BGE.Math.VectorOps.create(0.3, 0.06),
  repeatX: true,
  repeatY: true
}))
```

`examples/parallax` is a small, playable demo with several stacked background/foreground
layers and a camera that follows the player (`examples/parallax/src/source/Rooms/MainRoom.bs`).

`SceneObjectParallaxLayer` overrides three `SceneObject` methods to make this work:
`findCanvasPosition()` does the actual parallax math and tile enumeration - the base
`SceneObject.draw()`'s existing `objMovedInRelationToCamera()` check already re-triggers
it whenever the camera moves (its default implementation already ORs in
`cameraObj.movedLastFrame()`), so no change to the shared `SceneObject`/`Drawable` update
machinery was needed for this part. `isPotentiallyOnScreen()` and
`getPositionsForFrustumCheck()` correct the renderer's frustum-culling check, which
otherwise tests distance from the owning entity's raw (un-shifted) position: a repeating
layer (`repeatX`/`repeatY`) always returns `true` from `isPotentiallyOnScreen()` and is
never culled, since a repeating axis re-tiles to cover the viewport regardless of how far
the raw owning entity has drifted from the camera; a non-repeating layer is instead tested
against its actual parallax-shifted screen position (via `getPositionsForFrustumCheck()`),
not its raw owner position, so it stays correctly visible/hidden even once that raw
position is far outside the frustum.

Draw order relies entirely on the ordinary distance-from-camera sort - give a background
layer's owning entity a suitably negative Z (or positive, for a foreground layer) so it
falls out of `Renderer.drawScene()`'s existing sort with no renderer changes.
