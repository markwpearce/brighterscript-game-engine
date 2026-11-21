---
paths:
  - "src/source/engine/drawables/**"
---

# Drawables

Doc: `docs/drawables-and-scene-objects.md`. Drawing itself is the renderer's (see renderer rule).

- A `Drawable` attaches to an entity and registers a `SceneObject` with the `Renderer`. `owner` may be `invalid` — use `getGame()`, `getOwnerPosition()`, …, never `m.owner.*`.
- Changing shape in place → call `invalidateGeometry()` (movement checking can't see a resize).
- **Two color formats**: `Drawable.color`/`outlineRGBA` are RGB (`0xRRGGBB`, `BGE.ColorsRGB`); `Renderer.draw*` is RGBA (`0xRRGGBBAA`, `BGE.Colors`). Mixing gives a wrong color, not an error.
- `Sprite` frames come from `BGE.SpriteFrames` (grid or packed atlas); regions are shared per anchor with pretranslation baked in — never mutate per sprite. `Game.getSpriteFrames()` caches by bitmap name; packed `.json` atlases (`tools/render-character.py --packed`) load via `AssetLoader.loadSpriteAtlas()` → `Game.getSpriteAtlasFrames()`.
- `Drawable.flash(rgb, seconds, blinkSeconds, alpha)` overrides drawn color (rgb -1 keeps it) and scales drawn alpha without writing `color`/`alpha`; `flashAlpha(alpha, seconds, blinkSeconds)` only fades. Read `getDisplayColor()`/`getDisplayAlpha()`, not the fields. `BGE.Impulse.step(dt)` returns knockback displacement for the caller to apply.
- `BGE.ParticlePresets` (blood/sparks `ParticleBurstStyle`s, authored in metres: pass `unitsPerMetre`) and `BGE.ProceduralFrames.flame()` (code-drawn looping flame strip, cached by bitmap name) live beside the particle system.
- `Drawable.isOccluder` enables occlusion culling (`Camera3d` only).
- `BGE.DrawableWall` (freestanding tiled quad, owner must be `isStatic`) and `DrawableWalls`/`DrawableGridWalls`: see `specs/renderer-notes.md`.
