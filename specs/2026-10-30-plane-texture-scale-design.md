# DrawablePlane texture scale: design (#389)

## Intent

A ground plane draws one texture pixel per world unit, and nothing else is possible today. That
hurts in two ways:

- **Big layout images can't cover big areas.** `examples/thirdPerson` (#385) uses 32 world units
  per metre and wants a 1024×1024 layout image to cover 512 m × 512 m (16384 units).
- **Ground draw distance is capped in world units.** The device caps (simulator 900, HD 1000,
  FHD 2500) are only 28–78 m at 32 units/m. A coarser texture costs less bitmap per world unit,
  so it should be able to draw farther.

What Mark asked for: "here's a 600x600 plane image, but scale it by 1.5 times in x, and 2 in y
(so that it acts like a 900x1200 image)."

## Goals

- A per-axis texture scale on `DrawablePlane`: a 600×600 image at scale (1.5, 2) covers
  900×1200 world units.
- It applies to `staticImage` (the decal's world size is image size × scale) and `tiledImage`
  (each tile covers its image size × scale; a 64 px tile at scale 4 repeats every 256 units).
- Size the plane's bitmaps in texels, not world units, and apply the device cap to texels, so a
  coarser plane draws the ground proportionally farther.
- A default of (1, 1) leaves every existing plane exactly as it is.

## Non-goals

- **No change to objects.** Trees, characters, props and the draw distance that applies to
  them stay exactly as they are (Mark: "everything else can stay the same"). The camera's
  `getEffectiveMaxDrawDistance()` / `getCurrentDrawDistance()` and the device cap they use are
  untouched.
- No change to `color` fill planes; they have no texture.
- No mipmapping or filtering changes.

## Anti-goals

- Any visible change to a plane that doesn't set a scale.
- A finer texture (scale < 1) shortening the ground's draw distance below what it is today.

## Decided

- **Per-axis scale, not a single number.** (Mark) This replaces the issue's `texelsPerUnit`
  proposal.
- **Use the existing `Drawable.scale` field** (my call). Planes ignore it today, so it's free.
  `scale.x` stretches the image's x axis (world x); `scale.y` stretches the image's y axis,
  which on a ground plane is world z (`BGE.Math.worldPointToTexturePixel` maps texture y to
  world z via `switchYAndZ`). `scale.z` is ignored. The owner entity's scale is **not**
  applied (my call): planes have never followed it, and doing so now could change existing
  scenes.
- **Objects keep their current draw distance and cap.** (Mark)
- **Plane orientation:** texture mapping already assumes a horizontal plane (texture x = world
  x, texture y = world z). The scale applies in that same frame (my call). Tilted planes are no
  more or less supported than today.

## How it works

### Texture mapping

`SceneObjectPlane.getPerspectivePointsByCamera` maps world corners to texture pixels with
`worldPointToTexturePixel(worldPoint, planeCenter, textureWidth, textureHeight)`. With a scale,
the offset from the plane's centre is divided by the scale per axis before adding the
half-texture offset. Everything after that (the warp into the top-down bitmap, the supertexture
wrap, `boundsOverlapRect` for decals) already works in texture pixels and stays as is.

`tiledImage`'s supertexture and `wrapAnchorIntoSuperTexture` work in texture pixels (the wrap
period is the tile size), so they need no change beyond their inputs now being in texels.

### Draw distance

Today every plane uses `Camera3d.getPlaneDrawDistance()`: the requested plane distance
(`maxDrawDistance * planeDrawDistanceScale`, or `planeDrawDistanceOverride`, never less than
the object distance) capped at the device cap.

With a scale, each textured plane works out its own world draw distance:

```
requested = camera's plane distance before the device cap
cap       = device cap × max(1, min(scale.x, scale.y))
distance  = min(requested, cap)
```

So a plane at scale 4 can reach 4× the device cap if the camera asks for that much ground, and
scale ≤ 1 behaves exactly as today. Camera3d gains a way to get the uncapped requested plane
distance and the device cap. The uncapped request can't just skip the final cap in
`getPlaneDrawDistance()`, because its "never shorter than objects" floor reads
`getEffectiveMaxDrawDistance()`, which is capped too. Build it from the uncapped object reach.

One reach for both axes, from the smaller scale (my call). A (1.5, 2) plane spends a few extra
texels along its 2× axis. Per-axis reach isn't worth the extra footprint maths. `getPlaneDrawDistance()` itself keeps its current meaning, since
it also limits how far objects draw (`advanceDrawDistance`) and objects don't change.

The plane uses its own distance everywhere it now reads `getPlaneDrawDistance()`: the far
corners in `getPerspectivePointsByCamera`, the cache keys (`planeDrawDistanceAtLastDraw`,
`prePerspectiveBmpBuiltForMaxDrawDistance`, `superTextureBuiltForMaxDrawDistance`), and the
bitmap sizing below.

`color` planes have no texture, but they use their own `scale` for draw distance in the same
way (my call). A game that wants a coloured base layer to reach as far as a scaled texture gives
it the same scale.

### Bitmap sizing

- **Top-down (pre-perspective) bitmap:** `getPlanePrePerspectiveBmpSize(farDistance, fov,
  budget)` sizes it at 1 px per world unit, then scales down to the pixel budget. Pass the
  distance in texels (`distance / min(scale.x, scale.y)`) so the bitmap is no bigger than
  today's for the same texel reach. Only its aspect and budget matter downstream
  (`computePerspectiveSlices` reads spans from the quad's own corners).
- **Supertexture (`tiledImage`):** `tilesPerAxis` comes from `2 × distance / tileSize`. In
  texels that's `2 × distance / (tileSize × scale)`, so scaled tiles need fewer repeats and lose
  less sharpness to the existing `getMaxSuperTextureDimension()` downscale. Non-square scales
  need tiles-per-axis worked out separately for x and y, or by the smaller scale. The builder
  decides, keeping the existing corner-bleed padding argument valid.

### Light pools and the horizon

Light pools (#377) are placed from the plane's **world** quad into the top-down bitmap
(`getVisibleLightPools`), not from texture pixels, so the scale doesn't affect where they land.
What changes is the top-down bitmap's pixels per world unit: sized in texels, it has about
`1/scale` as many per world unit. The pool drift limit (`planeLightPoolMaxDriftPixels`) stays in
bitmap pixels (my call, on the FPS-first bias). A pool on a scaled plane can then lag a little
more in world units before it redraws, but it redraws no more often than on an unscaled plane.

The horizon is the far edge of the plane's own draw distance, so a scaled plane's horizon moves
out with it. Objects still fade out before it, since their distance is unchanged and at most
the plane's.

## Risks to check on device

- The simulator's 900 cap exists because brs-engine "silently fails to render past ~908"
  (lvcabral/brs-engine#1198). It's not certain whether that limit is in world units or bitmap
  pixels. Check a scaled plane drawn past 900 world units in the simulator, and fall back to
  keeping the simulator cap in world units if it breaks.
- FHD's 2500 cap was found by bitmap allocation failures before the pixel budgets existed. Check
  a scaled plane at e.g. 4 × 2500 on a real FHD device and an HD device.
- Watch for the ~13,000 queued-draw limit in the supertexture build (it should only get
  smaller).

## Testing

- `SceneObjectPlane.spec.bs`:
  - scale (1, 1) gives the same mapped corners and bitmap sizes as before;
  - `staticImage` at (1.5, 2): a 600×600 region covers 900×1200 world units (the mapped corners
    of a known camera view, and `boundsOverlapRect` turning false exactly past the decal's
    scaled edge);
  - `tiledImage` at scale 4: tile wrap period is 4× the tile size in world units, and
    `tilesPerAxis` shrinks accordingly;
  - draw distance: scale 4 reaches up to 4× the device cap when requested, scale 0.5 and 1 don't
    change it, and the camera's object distance is unchanged in all cases;
  - light pool placement for a scaled plane matches an unscaled one for the same light.
- `examples/rendererTest`: a demo with a scaled `tiledImage` ground and a scaled `staticImage`
  decal, showing the draw distance.
- Device runs (above).

## Docs

Extend the plane section of `docs/drawables-and-scene-objects.md` with a short example (the
600×600 → 900×1200 case) and a note on draw distance.

## Follow-up

thirdPerson (once PR #392 is on `main`): use a scaled layout image for the 512 m map and a
detail texture at whatever density looks right.

## Left to the builder

- How the per-plane distance is factored between `Camera3d` and `SceneObjectPlane`.
- Non-square tiles-per-axis in the supertexture (see above).
- The rendererTest demo's look.
