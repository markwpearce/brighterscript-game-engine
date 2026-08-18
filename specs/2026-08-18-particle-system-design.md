# Particle system design

Issue: [#86](https://github.com/markwpearce/brighterscript-game-engine/issues/86)

## Summary

A `DrawableParticles` drawable (attached to a `GameEntity` like any other
drawable) that emits and simulates lightweight particles — lines, rectangles,
or images — with randomized velocity, acceleration, lifetime-driven fade and
color interpolation, and a configurable population cap. Each live particle is
backed by one `SceneObjectParticle`, a new minimal `SceneObject` subclass, so
particles draw/cull/depth-sort through the existing `Renderer` pipeline with
no renderer changes.

## Goals / non-goals

Goals (from the issue, full scope):

- Emit particles at a configurable rate, or all at once via `burst(count)`.
- Per-particle lifetime, initial velocity with randomized spread, constant
  acceleration, alpha fade, and start→end color interpolation over lifetime.
- Three shapes: line, rectangle, image.
- `start()`/`stop()`/`burst(count)` control API, attached as a normal
  `Drawable`.
- A configurable max-particle cap so a runaway/misconfigured emitter can't
  grow unbounded.

Non-goals (explicitly out of scope per the issue): 3D/billboard-oriented
particles, camera-facing rotation for line/rectangle shapes, and particle
collision detection.

## Architecture

### Why a new `SceneObjectParticle` rather than reusing existing types

Considered reusing `SceneObjectLine`/`SceneObjectRectangle`/`SceneObjectImage`
directly. Rejected because:

- Every existing `SceneObject` reads its geometry/color/alpha from the single
  `Drawable` it's permanently paired with — that model doesn't fit N
  independent per-particle states under one `DrawableParticles`. Reusing them
  would still require injecting per-particle overrides into three different
  existing classes; no code reuse is actually saved.
- `SceneObjectRectangle` and `SceneObjectImage` both extend
  `SceneObjectBillboard`, which brings oriented-mode projection and
  temp-bitmap caching that rectangle/line particles specifically don't want
  (see below) — pulling that in per-particle at "hundreds of particles" scale
  is the wrong tradeoff.

A single new `SceneObjectParticle` (extending plain `SceneObject`, the same
lightweight base `SceneObjectLine` uses — not `SceneObjectBillboard`) with a
per-shape branch in `performDraw`/`findCanvasPosition` is less code overall
and keeps every particle on the cheapest available draw path.

### Per-shape draw cost, by design

- **Line**: a single straight `Renderer.drawLine()` call between two
  endpoints. No orientation/rotation concept.
- **Rectangle**: a single straight, axis-aligned `Renderer.drawRectangle()`
  fill call. No rotation, no outline (fill-only — keeps it on the single
  cheapest call; outline can be added later if a real use case needs it),
  size may still change over lifetime (`startSize`/`endSize`).
- **Image**: the only shape allowed to rotate/scale, since that's the one
  case where the warp cost is worth paying — reuses the same pinned-corner
  warp path (`drawPinnedCorners`) `SceneObjectImage`'s oriented mode already
  uses.

`DrawableParticles`'s `rotation`/`rotationSpeed` config only applies to the
`"image"` shape; it's ignored for `"line"`/`"rectangle"`.

### Component overview

- **`DrawableParticles`** (`src/source/engine/drawables/DrawableParticles.bs`,
  new `Drawable` subclass) — owns emitter config and the live-particle list.
  Overrides `Drawable.update()` (the existing no-op hook every `Drawable`
  already has, called for every drawable of every valid entity every frame
  via `Game.bs`'s `processEntityPreDraw`, independent of the owning entity's
  own `onUpdate()`/velocity — this is the same hook `AnimatedImage.update()`
  already uses). Like `AnimatedImage`, it self-times elapsed time via its own
  `GameTimer` rather than expecting a `dt` parameter.
- **Particle record** — a plain associative array (not a class, to avoid
  per-particle class overhead at emitter scale): `position`, `velocity`,
  `age`, `lifetime`, `startColor`/`endColor`, `startSize`/`endSize`,
  `sceneObject` (its linked `SceneObjectParticle`).
- **`SceneObjectParticle`** (`src/source/engine/renderer/sceneObjects/`, new
  `SceneObject` subclass) — holds its own per-instance `worldPosition`,
  `color`, `alpha`, `size` (and, for image shape, `rotation`/`scale`), set
  directly by `DrawableParticles.update()` each frame rather than derived
  from the owning Drawable's own offset/rotation/scale. Overrides
  `updateWorldPosition` to a no-op (position already pushed each frame) and
  branches `performDraw`/`findCanvasPosition` by shape as above.

### Config / API surface

`DrawableParticles` constructor `args` (matching the issue's sketch):

- `shape` — `"line"` | `"rectangle"` | `"image"` (+ `image` bitmap when
  `"image"`).
- `spawnRate` — particles/second for continuous emission.
- `lifetime` — seconds, or a `{min, max}` range for randomization.
- `velocity` + `velocitySpread` — base velocity vector plus randomization
  (angle and/or magnitude spread).
- `acceleration` — constant acceleration vector applied every frame (e.g.
  gravity).
- `startColor`/`endColor` — packed RGB, interpolated over `age/lifetime`.
- `startAlpha`/`endAlpha` — fade over lifetime.
- `startSize`/`endSize` — interpolated over lifetime.
- `rotation`/`rotationSpeed` — image shape only.
- `maxParticles` — population cap (see below).

API: `start()` / `stop()` (toggle continuous `spawnRate`-driven emission),
`burst(count)` (spawns `count` particles immediately, independent of
`start()`/`stop()` state).

### Population cap

`maxParticles` is a hard cap enforced at spawn time — once the live-particle
count is at the cap, further spawns (from either continuous emission or
`burst()`) are silently dropped until a slot frees up via natural expiry.
This is a safety valve against a runaway/misconfigured emitter, not a
performance tuning knob by itself; real per-shape draw-call cost at scale
gets measured via the `rendererTest` demo below before deciding on a sensible
default.

### Data flow (per frame)

1. `Game.bs`'s `processEntityPreDraw` calls `drawable.update()` for every
   drawable of every valid entity, including each `DrawableParticles`.
2. `DrawableParticles.update()`: advances its spawn accumulator (emits 0+
   new particles this frame, respecting `maxParticles`), then for every live
   particle: ages it, integrates `velocity += acceleration * dt` and
   `position += velocity * dt`, interpolates alpha/color/size by
   `age / lifetime`, and pushes the results directly onto that particle's
   `SceneObjectParticle`. Particles whose `age >= lifetime` are expired:
   their `SceneObjectParticle` is removed from the renderer
   (`Renderer.removeSceneObject`) and dropped from the particle array.
3. The normal `Renderer.drawScene()` pass (cull / depth-sort / draw) handles
   every live `SceneObjectParticle` exactly like any other scene object — no
   changes to `Renderer` itself.

### Renderer registration

`Drawable`'s existing `sceneObjects` dict / `getSceneObjects()` /
`addSceneObjectToRenderer()` / `removeFromScene()` plumbing already supports
one Drawable registering an arbitrary number of SceneObjects over its
lifetime (confirmed generic, though no existing drawable exercises this
today — every current `addToScene` override registers exactly one). No core
engine changes needed: `DrawableParticles` calls
`m.addSceneObjectToRenderer(...)` once per spawned particle and
`rendererScene.removeSceneObject(...)` once per expired particle.

## Testing

- **Rooibos spec** (`DrawableParticles.spec.bs`): spawn-rate accounting over
  simulated time, lifetime expiry removing particles and their scene
  objects, `maxParticles` cap enforcement (continuous emission and
  `burst()`), `start()`/`stop()` toggling emission, color/alpha/size
  interpolation math at known `age/lifetime` fractions.
- **`rendererTest` demo**: a new category exercising each shape at "hundreds
  of particles" (per the issue's own performance concern), timed
  automatically like every other `rendererTest` demo (fps/frame/update/draw
  ms, draw-call count) — this is what informs whether the default
  `maxParticles` needs tuning, not guesswork.
- **On-device/simulator verification** via the `rokubot-examples` skill is
  mandatory before considering this done, per the repo's standing rule that
  static analysis alone doesn't exercise example/runtime behavior.

## Open questions deferred, not blocking this design

- Rectangle outline support — deferred; fill-only for now.
- Whether `maxParticles` needs a smarter eviction policy (e.g. drop
  oldest instead of drop-newest) — decide after `rendererTest` numbers are
  in; drop-newest (silently skip new spawns at cap) is the starting
  behavior.
