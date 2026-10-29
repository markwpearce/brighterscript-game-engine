# Configurable lighting (#189)

## Goal

Replace the fixed camera-facing `isShaded` brightness with real lights - several, each with a
color and a direction or position - without slowing down scenes that don't use them.

## Decisions

- **Light kinds**: `DirectionalLight` (direction), `PointLight` (position + optional linear
  `range` falloff), `AmbientLight` (constant). All share `color` (RGB), `intensity`, `enabled`.
  Spot lights and shadows are out of scope.
- **Where lights live**: on the `Renderer` (`addLight`/`removeLight`/`clearLights`), with
  `Game.addLight()` etc. forwarding to the game canvas. Per-renderer matches how cameras and
  quality settings already work, keeps the UI canvas unlit, and works in `rendererTest` without a
  `Game`. Lights outlive scene changes; scenes remove their own.
- **Model**: per-surface diffuse (Lambert) sum over all enabled lights, per RGB channel, capped
  at 1 (no overexposure), multiplied into the surface color. Surfaces are lit on the side the
  camera sees, so back-face draw modes light correctly. Shading is per triangle at its centroid
  (models) or quad center (billboards); no per-vertex/Gouraud interpolation, since the renderer
  fills each triangle with one color.
- **`ambientBrightness`**: kept as a per-channel floor, so existing tuning carries over. An
  `AmbientLight` is the colored, scene-wide alternative; set the floor to 0 to let lights decide.
- **No lights = old behavior**: with no enabled light, shading is exactly the old camera-facing
  path, so every existing scene renders and caches as before.
- **How many lights**: no hard cap. Cost is a few vector ops per light per visible surface, only
  on frames that recompute shading. The real cost is the redraw a changing light forces, not the
  maths.

## Change tracking

Lights are plain objects that games mutate directly, so the renderer can't rely on setters.
`Renderer.updateLighting()` (first thing in `render()`) builds a value signature of the enabled
lights; when it changes it re-prepares them (normalized directions, unpacked colors) and bumps
`lightingVersion`. `SceneObject.draw()` sets `lightingChangedThisDraw` for shaded objects whose
last draw saw an older version, which forces a canvas-position recompute and bypasses the cached
raster checks, like a quality change does.

A model then compares each face's new shaded color with last frame's. If none changed (a moving
light that doesn't reach it), the flag is cleared and the cached drawing is just blitted. If some
changed, only those faces redraw; the rest reuse their exact cached raster without counting as
stale.

## Measured (HD Roku, `rendererTest --param demo=lighting`)

- Static directional light: 62 fps / 7 draw calls, the same as no lights.
- Orbiting point light reaching a ~170-visible-face scene: 12-26 fps, about the cost of rotating
  the same models. That's the scene being re-composited, which is inherent to the cached-raster
  design.
