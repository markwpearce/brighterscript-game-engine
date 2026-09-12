# Spike: why do large screen-aligned Images silently fail to render? (issue #211)

## Question

`TileMapBaking.bs`'s doc comment and PR #212 documented a ~192px+ threshold past
which a screen-aligned `Image`/`SceneObjectImage` (`matchCamera` draw mode) could
silently fail to render - on both the BrightScript Simulator and real hardware -
even though the bitmap's own content was provably correct (`GetByteArray`/PNG
roundtrip) and the draw call reported success. This spike investigates *why*,
per three specific questions:

1. Is there a difference between an image loaded from disk vs. one created in memory?
2. Can `roTextureManager` help?
3. Why would there be a hard cap on image size at all?

## What was actually found

### 1. No hardcoded size cap exists anywhere in the rendering stack

Read `brs-engine`'s `IfDraw2D.ts` and `RoBitmap.ts` (the shared TypeScript source
behind both the BrightScript Simulator GUI app, `brs-desktop`, and the headless
`brs-node`/`brs-cli` used by this repo's own CI) in full. Every draw call
(`drawObject`, `drawScaledObject`, `drawTransformedObject`, etc.) reduces to a
plain HTML5 Canvas `ctx.drawImage(...)` call, with no width/height branching,
clamping, or size-based special-casing anywhere in the path. `RoBitmap`'s
constructor doesn't cap dimensions either. So if a size-dependent failure is
real, it is not a documented/intentional limit anywhere in this stack - it would
have to be an emergent timing or resource-exhaustion behavior.

### 2. This exact symptom was already filed upstream, and the maintainer couldn't reproduce it in isolation

[lvcabral/brs-engine#1198](https://github.com/lvcabral/brs-engine/issues/1198)
(filed from this same investigation, during #211/#212's work) reported a large
`roBitmap` rendering blank in the simulator after a rotate+scale draw sequence,
with correct content confirmed by readback. The upstream maintainer tried over
20 combinations - sizes from 512x1024 up to 4000x2000, multiple rotation angles
and scale factors, both `roBitmap` and `roRegion` sources, tint on/off, a
persistent reused scratch bitmap across 60 frames - and could not get a single
blank result. The issue was closed as "some other issue was going on."

This is an important data point: a size-driven, provably-correct-content,
sometimes-blank symptom, tested in isolation by someone with direct access to
the renderer's own internals, does not reproduce on its own.

### 3. The engine *does* have a known asymmetry worth fixing regardless

An `Explore` pass over `src/source/engine/renderer/` found that `Renderer.forceDraw()`
(`Renderer.bs:2290-2299`) - which calls `.Finish()` on a bitmap and, on real
hardware only (`not m.isSimulator`), forces a flush through a dummy `roScreen` -
is called from every path that draws into a scratch/temp bitmap and then reads
it back as a source for a further draw (`makeIntoTriangle`, `scaleTriangleToBeAcuteTriangle`,
`drawPinnedCornersTo`, `drawTriangleFromScratchTo`, and
`SceneObjectBillboard.createTempBitmap` for the oriented draw modes). It is
**never** called from the plain single-blit path (`drawObjectTo`/
`drawScaledObjectTo`/`drawRotatedObjectTo`/`drawTransformedObjectTo`,
`Renderer.bs:1747-1816`) that a `matchCamera`/`directToCamera` `SceneObjectImage`
actually uses - i.e. exactly the path `TileMapBaking`'s baked chunks draw
through every frame. This is a real, pre-existing gap relative to the pattern
the engine already established elsewhere, and was the leading hypothesis
walking into this spike's empirical test.

### 4. Built and ran a dedicated empirical test - and it did not reproduce the failure

Added `examples/rendererTest`'s **"Large Image Render Test (issue #211)"** demo
(`Tests/LargeImageRenderTest.bs`, id `large-image-render`). It:

- draws one selected size (64-640px, interactively controlled via up/down),
  either a solid-color in-memory-created bitmap or an equivalent PNG loaded
  from `pkg:/images/sizetest/` (left/right), directly onto the real `roScreen`
  every single frame - at the same point in the frame (before this app's own
  `SwapBuffers()`) a real game's entity draw pass would run
- reads back a center pixel via `GetByteArray()` immediately after the draw,
  before `SwapBuffers()`, as an automatic pass/fail check
- optionally calls `screenRef.Finish()` right after the draw (OK to toggle) -
  tested with this **off** for the results below, i.e. the worst case per the
  missing-`forceDraw()` hypothesis

Ran this on **both** targets, at the largest documented-bad size range:

| Target | Size | Source | Finish | Frames | Result |
|---|---|---|---|---|---|
| BrightScript Simulator (GUI app) | 576px | memory | off | 119 | 119/119 pass |
| BrightScript Simulator (GUI app) | 576px | disk | off | 116 | 116/116 pass |
| Real Roku hardware | 640px | memory | off | 115 | 115/115 pass |
| Real Roku hardware | 640px | disk | off | 148 | 148/148 pass |

Both the in-app `GetByteArray` check and an actual `rokubot` screenshot of the
physical/simulated screen agreed at every sample: the green square rendered
correctly, at every size tried, on both targets, in-memory or disk-loaded,
with no `Finish()` call at all - zero failures across ~500 sustained frames of
sampling.

## Conclusion

**An isolated large blit, on its own, does not reproduce this failure on either
target.** This matches the upstream maintainer's own experience trying to
reproduce #1198 in isolation. Whatever actually triggered the original
platformer chunk-rendering failures depends on something in the surrounding
per-frame load or state that neither this spike's minimal demo nor upstream's
isolated repro attempts recreate - most likely one or some combination of:

- many simultaneous entities/colliders/other draws sharing the same frame
  (a real platformer level's collision checks, other sprites, UI, etc.)
- sustained GC pressure or pool/allocation churn happening nearby in time
- something specific to the full `GameEntity` → `SceneObjectImage` →
  `Game.Play()` pipeline (dirty-checking, zIndex sort, cull-latching) rather
  than the raw blit call in isolation

Answering the three original questions directly:

1. **Disk vs. memory**: no difference found. Both paths converge to the same
   in-memory canvas before the first draw; the failure (whatever triggers it)
   isn't about how the source bitmap was populated.
2. **`roTextureManager`**: read `RoTextureManager.ts` in full. It is purely a
   caching + optional-async wrapper around loading an `roBitmap` by URI - the
   bitmap it hands back goes through the exact same `ifDraw2D` draw path
   afterward. It cannot help with a render-time completion/race issue; it's
   still worth adopting for background-loading a large baked texture to avoid
   a load-time frame hitch, but that's an unrelated benefit, not a fix for #211.
3. **Why a hard cap**: there isn't a designed one. If the original symptom is
   real (and the code comments describing it, backed by `GetByteArray`/PNG
   round-trip verification, are credible), it's an emergent property of the
   full running game, not a fixed platform ceiling on blit size.

## Recommended next steps

1. **Re-run this same interactive test (or an extended version of it) embedded
   in a real `BGE.Game`/`Room`** with a realistic entity/collider count
   matching `examples/platformer`'s actual level, rather than the bare
   `rendererTest` harness - to test the "requires full game load" hypothesis
   directly. This is the most likely next lead.
2. **Add the missing `.Finish()`/`forceDraw()`-style flush to the plain
   single-blit path** (`Renderer.bs:1747-1816`) defensively regardless of
   whether it's proven necessary here - it's a real, cheap-to-fix asymmetry
   against the pattern the engine already uses everywhere else a bitmap is
   drawn-to-then-relied-upon.
3. **Test under deliberate GC pressure** (e.g. periodic `RunGarbageCollector()`
   calls, or many small allocations churning in the same frame as the large
   blit) alongside this demo's existing size/source/finish matrix - `Game.bs`'s
   own periodic GC and general allocation churn during real gameplay is a
   plausible missing ingredient this spike didn't yet isolate.
4. Keep `LargeImageRenderTest` in `examples/rendererTest` as a reusable
   diagnostic - it's driven entirely by up/down/left/right/OK, so it's cheap to
   extend with a "GC pressure" or "many concurrent draws" toggle for whoever
   picks up step 1 or 3.

## Artifacts from this spike

- `examples/rendererTest/src/source/Tests/LargeImageRenderTest.bs` (new demo)
- `examples/rendererTest/src/source/DemoList.bs` (registers it, id `large-image-render`)
- `examples/rendererTest/src/source/RendererTest.bs` (added a public `screenRef`
  field, set by `main.bs` right after each demo is constructed - lets a demo
  that needs to verify the *actual* screen buffer, not just something drawn
  into an offscreen bitmap via `Renderer`, get at the raw `roScreen`)
- `examples/rendererTest/src/source/main.bs` (sets `activeDemo.screenRef`)
- `examples/rendererTest/src/images/sizetest/size-{64,128,192,256,320,384,448,512,576,640}.png`
  (generated solid-green test images, one per size in the sweep)
