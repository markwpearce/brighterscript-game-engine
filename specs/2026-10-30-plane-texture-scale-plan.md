# DrawablePlane texture scale: implementation plan (#389)

> For agentic workers: use superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** `DrawablePlane.scale.x/.y` stretch a plane's texture over world units, and a coarser
plane draws the ground proportionally farther.

**Architecture:** see the spec's "Texture mapping" (texel scale in the mapping, stretch in the
source) and "Draw distance" (per-plane distance from `Camera3d.getPlaneDrawDistanceForTexelScale`).

**Spec:** `specs/2026-10-30-plane-texture-scale-design.md`

## Global constraints

- `scale` (1, 1) must leave mapping, bitmap sizes and draw distance exactly as before.
- `getPlaneDrawDistance()` keeps its value (it limits objects too).
- Never draw into a bitmap after reading it in the same frame.

## Review focus

- A non-square scale with a rotated view: the decal and tiles stay rectangular in the world (stretch is baked into the source).
- Scale < 1: the draw distance doesn't shrink.
- A zero or negative scale: use `Abs`, floored at 0.01.
- A region or scale changed after the first draw: the stretched copy and supertexture rebuild.

---

### Task 1: Camera3d per-texel-scale plane distance

**Files:** `src/source/engine/renderer/cameras/Camera3d.bs`, new `PlaneTextureScale.spec.bs`

- [ ] Tests: `getPlaneDrawDistanceForTexelScale(1)` and `(0.5)` equal `getPlaneDrawDistance()`;
  with `planeDrawDistanceOverride = 100000`, `(4)` is `4 × 900` (the headless cap); with an
  override of 2000, `(4)` is 2000.
- [ ] `function getPlaneDrawDistanceForTexelScale(texelScale as float) as float`: the uncapped
  request (`max(maxDrawDistance × planeDrawDistanceScale, planeDrawDistanceOverride,
  uncapped object reach)`), capped at `deviceCap × max(1, texelScale)`.
  `getPlaneDrawDistance()` returns `getPlaneDrawDistanceForTexelScale(1)`.

### Task 2: Mapping, stretch and per-plane distance

**Files:** `src/source/math/plane.bs`, `SceneObjectPlane.bs`, `PlaneTextureScale.spec.bs`

- [ ] Tests:
  - `worldPointToTexturePixel(p, c, w, h, 4)` divides the offset by 4;
  - a 600×600 `staticImage` at (1.5, 2): `getTextureSize()` is 600×800, and
    `worldPointToTexel(centre + (450, 0, 600))` is (600, 800), `centre − (450, 0, 600)` → (0, 0);
  - a red 64×64 decal at scale (8, 8) shows red at world x = 200 in the top-down bitmap;
  - an 8 px `tiledImage` at scale 4 has under a third of scale 1's `tilesPerAxis`; at (2, 4)
    its logical tile is 8×16;
  - a color plane at scale 4 with a 100000 override reaches a far-edge depth over 900 while
    `camera.getPlaneDrawDistance()` and `getEffectiveMaxDrawDistance()` stay at 900;
  - a scaled tiled plane with a lamp in view draws one pool.
- [ ] `worldPointToTexturePixel(..., worldUnitsPerPixel = 1.0 as float)`.
- [ ] `SceneObjectPlane`: `getTexelScale() as float`, `getTextureStretch() as BGE.Math.Vector`,
  `getTextureSize() as SizeWH` (stretched region size), `worldPointToTexel(p) as Vector`,
  `getWorldDrawDistance(camera as Camera3d) as float`; replace every
  `camera.getPlaneDrawDistance()` in the file with `m.getWorldDrawDistance(camera)`, and size the
  pre-perspective bitmap and supertexture tile count from the texel distance
  (`distance / texelScale`).
- [ ] Stretch tiles in `buildSuperTextureIfNeeded` (logical tile = region × stretch; cache key on
  the logical size); `getStaticSourceRegion()` returns the region, or a cached stretched copy for
  a non-square scale.

### Task 3: Demo and docs

**Files:** `examples/rendererTest/src/source/Tests/PlaneTextureScaleTest.bs`, `DemoList.bs`,
`docs/drawables-and-scene-objects.md`

- [ ] Demo: a scaled tiled ground plus a scaled decal; OK cycles the scale (1, 4, (1.5, 2));
  shows the ground draw distance.
- [ ] Docs: the 600×600 → 900×1200 example and the draw distance note.
- [ ] `npm run check:all`; device + simulator runs (including past 900 world units); PR.
