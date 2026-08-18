# Particle system design

Issue: [#86](https://github.com/markwpearce/brighterscript-game-engine/issues/86)

## Summary

A `DrawableParticles` drawable (attached to a `GameEntity` like any other
drawable) that emits and simulates lightweight particles — lines, rectangles,
or images — with randomized velocity, acceleration, lifetime-driven fade and
color interpolation, and a configurable population cap. The whole emitter is
backed by exactly **one** `SceneObjectParticle` (a new, minimal `SceneObject`
subclass) which draws every live particle itself in a tight loop — not one
`SceneObject` per particle — specifically to keep spawn/expire cheap at scale
(see [Why one `SceneObjectParticle` per emitter, not per particle](#why-one-sceneobjectparticle-per-emitter-not-per-particle)
below). The explicit priority for this feature is maximum particle count at
the highest achievable FPS, not per-particle fidelity — every design choice
below is made in that direction.

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

### Why one `SceneObjectParticle` per emitter, not per particle

Initially considered one `SceneObjectParticle` instance per live particle
(analogous to every existing `Drawable`/`SceneObject` pair being 1:1).
Rejected once its concrete cost became clear: `Renderer.addSceneObject()` and
`removeSceneObject()` both set `needsDepthSort = true`
(`Renderer.bs:269-302`). Depth-sort's entire performance win (issue #59) is
*skipping* the per-frame sort when nothing that affects order changed. An
emitter spawning and expiring particles every frame — the normal case for any
continuous emission — would set that flag every single frame for as long as
it's active, permanently defeating the skip-optimization for the *whole*
renderer, not just this emitter's own objects. At the scale this feature is
explicitly meant to support ("as many particles as possible, highest FPS
possible"), that's the wrong tradeoff.

Instead: **`DrawableParticles.addToScene()` registers exactly one
`SceneObjectParticle` for the entire emitter**, exactly like every other
drawable — zero `addSceneObject`/`removeSceneObject` churn as particles
spawn and expire. That one `SceneObjectParticle` overrides `performDraw` to
loop over the emitter's own live-particle array and issue one direct draw
call per particle itself (`drawLine`/`drawRectangle`/`drawRegion`),
computing each particle's own canvas position inline via
`worldPointToCanvasPoint`.

Consequences, accepted deliberately given the stated priority:

- Particles from one emitter draw as a single atomic unit relative to
  *other* scene objects in the renderer's depth sort — the same
  whole-object-granularity tradeoff `SceneObjectModel` already makes for its
  per-face list. This emitter doesn't get its own entry in the renderer's
  cull-latch/depth-sort bookkeeping per particle.
- Particles within the same emitter draw in spawn order, not depth-sorted
  against each other — acceptable because inter-particle depth correctness
  was never a goal (see non-goals: no 3D/camera-oriented particle
  rendering).
- Per-particle off-canvas skipping is a cheap inline bounds check inside the
  draw loop, not the full per-object frustum-cull machinery every normal
  `SceneObject` gets — correctly scoped, since these aren't independent
  scene objects anymore.

This also means `SceneObjectParticle` itself is a much smaller class than a
1:1 design would need: it holds no per-instance color/alpha/size fields at
all — it just reads straight from its owning `DrawableParticles`'s particle
array at draw time.

### Why not reuse `SceneObjectLine`/`SceneObjectRectangle`/`SceneObjectImage` directly

Considered this too. Rejected because every existing `SceneObject` reads its
geometry/color/alpha from the single `Drawable` it's permanently paired
with — that model doesn't fit one object drawing N independent particle
states in a loop, and `SceneObjectRectangle`/`SceneObjectImage` both extend
`SceneObjectBillboard`, which brings oriented-mode projection and
temp-bitmap caching this feature doesn't want anywhere near a per-particle
draw loop (see per-shape draw cost below). A single new `SceneObjectParticle`
(extending plain `SceneObject`, the same lightweight base `SceneObjectLine`
uses — not `SceneObjectBillboard`) with a per-shape branch inside its one
draw loop is less code overall and keeps every particle on the cheapest
available draw path.

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
  new `Drawable` subclass) — owns emitter config and the live-particle
  array, and captures the `Renderer` passed to `addToScene()` (the base
  `Drawable` doesn't persist this itself — confirmed by reading every field
  and every `addToScene` override — so `DrawableParticles` stores it in its
  own field; in normal usage this is always `GameEntity.addDrawable`'s
  `m.game.canvas.renderer`, called exactly once per drawable). Overrides
  `Drawable.update()` (the existing no-op hook every `Drawable` already has,
  called for every drawable of every valid entity every frame via
  `Game.bs`'s `processEntityPreDraw`, independent of the owning entity's own
  `onUpdate()`/velocity — this is the same hook `AnimatedImage.update()`
  already uses) to run the simulation: spawn accumulator, per-particle
  physics/fade/color integration, expiry. Like `AnimatedImage`, it
  self-times elapsed time via its own `GameTimer` rather than expecting a
  `dt` parameter.
- **Particle record** — a plain associative array (not a class, to avoid
  per-particle class overhead at emitter scale): `position`, `velocity`,
  `age`, `lifetime`, `startColor`/`endColor`, `startSize`/`endSize`,
  `rotation` (image shape only). No `sceneObject` field — there isn't one
  per particle any more.
- **`SceneObjectParticle`** (`src/source/engine/renderer/sceneObjects/`, new
  `SceneObject` subclass, one instance per emitter) — holds no per-particle
  state of its own; `performDraw` iterates its owning `DrawableParticles`'s
  live-particle array directly and draws each one, branching by shape as
  below.

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
   new particle *records* into its own array this frame, respecting
   `maxParticles` — no renderer/scene-object interaction at spawn time at
   all), then for every live particle: ages it, integrates
   `velocity += acceleration * dt` and `position += velocity * dt`,
   interpolates alpha/color/size by `age / lifetime`. Particles whose
   `age >= lifetime` are simply dropped from the array — no
   `Renderer.removeSceneObject` call, since there's no per-particle scene
   object to remove.
3. The normal `Renderer.drawScene()` pass reaches this emitter's single
   `SceneObjectParticle` exactly like any other scene object (one cull
   check, one depth-sort entry); its `performDraw` then loops the
   `DrawableParticles`'s current particle array and issues one direct draw
   call per particle.

### Renderer registration

Unlike the per-particle design this replaced, registration here is the
*normal* single-`SceneObject`-per-`Drawable` case every other drawable
already uses — `DrawableParticles.addToScene()` calls
`m.addSceneObjectToRenderer(...)` exactly once, at attach time, and stores
the given `Renderer` in its own field for `performDraw`'s projection calls.
No core engine changes needed, and no per-particle `Renderer` calls of any
kind.

## Testing

- **Rooibos spec** (`DrawableParticles.spec.bs`): spawn-rate accounting over
  simulated time, lifetime expiry dropping particles from the array,
  `maxParticles` cap enforcement (continuous emission and `burst()`),
  `start()`/`stop()` toggling emission, color/alpha/size interpolation math
  at known `age/lifetime` fractions. Separately, a
  `SceneObjectParticle.spec.bs` covers the single scene object's draw loop
  against a real `Renderer`/`roBitmap` (the `SceneObjectCircle.spec.bs`
  isolation pattern), asserting draw-call counts scale with live particle
  count.
- **New `examples/particles` example** (scaffolded via
  `npm run create-example`), rather than a `rendererTest` demo:
  `DrawableParticles` is a `Drawable` on a `GameEntity`, and `rendererTest`
  is deliberately built without `BGE.Game`/`Room`/`GameEntity` at all — this
  feature can't be exercised there without either standing up an
  entity/room shim just for it or loosening a rule that's out of scope for
  this PR. A dedicated example is the standard way this repo demonstrates a
  new capability end-to-end, and it's where the mandatory on-device
  verification (below) already has to happen anyway. Rooms: one per shape
  (line/rectangle/image), one contrasting continuous emission vs.
  `burst()`, and a "stress" room spawning near `maxParticles` to get real
  fps/draw-call numbers on-device — this is what informs whether the
  default `maxParticles` needs tuning, not guesswork.
- **On-device/simulator verification** via the `rokubot-examples` skill is
  mandatory before considering this done, per the repo's standing rule that
  static analysis alone doesn't exercise example/runtime behavior.

## Open questions deferred, not blocking this design

- Rectangle outline support — deferred; fill-only for now.
- Whether `maxParticles` needs a smarter eviction policy (e.g. drop
  oldest instead of drop-newest) — decide after `rendererTest` numbers are
  in; drop-newest (silently skip new spawns at cap) is the starting
  behavior.
