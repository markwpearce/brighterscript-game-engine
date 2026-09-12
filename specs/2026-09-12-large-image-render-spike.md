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

Ran this on **both** targets, at the largest documented-bad size range. Note a
correction made mid-spike: the first "real hardware" pass actually re-hit the
same local BrightScript Simulator instance (`.env`'s default `ROKU_HOST` also
resolves to the simulator, confirmed via `rokubot info` reporting
`BrightScript Simulator` with no `--host` override at all) - the results below
are from re-running against an explicit `--host <lan-ip>` pointed at an actual
physical Roku (`rokubot info` there reports the real device's own model/name),
confirmed genuine.

| Target | Size | Source | Finish | Frames | Result |
|---|---|---|---|---|---|
| BrightScript Simulator (GUI app) | 576px | memory | off | 119 | 119/119 pass |
| BrightScript Simulator (GUI app) | 576px | disk | off | 116 | 116/116 pass |
| Real Roku hardware (confirmed via device-model check) | 640px | memory | off | 115 | renders correctly, no flicker over multiple screenshots |
| Real Roku hardware (confirmed via device-model check) | 640px | disk | off | 146+ | renders correctly, no flicker over multiple screenshots |

On the simulator, the in-app `GetByteArray` check and a `rokubot` screenshot
agreed at every sample: the green square rendered correctly at every size
tried, in-memory or disk-loaded, with no `Finish()` call at all - zero
failures across ~500 sustained frames of sampling.

**On real hardware, `roScreen.GetByteArray()` itself doesn't work the same way**
(see "Platform difference found" below) - so verification there relies purely
on repeated real screenshots (multiple captures a couple seconds apart at each
size/source combo, sampling the fixed marker-pixel location via ImageMagick):
consistently correct, no flicker, at every combo tried.

### Also tested: many large images in the same frame, not just one

`examples/platformer`'s level bakes well over 10 chunks - a single isolated
blit per frame might not be representative. Extended the demo with a `count`
dimension (1/4/8/12/16 copies, tiled across the screen, all drawn - and, where
supported, all individually GetByteArray-verified - in the same frame) and
re-ran on the real device:

| Target | Size | Source | Count | Finish | Frames | Result |
|---|---|---|---|---|---|---|
| Real Roku hardware | 320px | memory | 16 | off | 148 | all 6 on-screen copies render correctly, no flicker |
| Real Roku hardware | 320px | disk | 16 | off | 570 | all 6 on-screen copies render correctly across 3 screenshots ~1.5s apart, no flicker |

Still no reproduction - 16 simultaneous 320px blits per frame, sustained for
~9.5 seconds real time on real hardware, rendered correctly throughout.

## Platform difference found: `roScreen.GetByteArray()` on real hardware

While wiring up this test's in-app auto-verification, discovered that
`m.screenRef.GetByteArray(x, y, w, h)` (called on a real `roScreen`, not an
`roBitmap`) **returns `Invalid` on real Roku hardware** instead of an
`roByteArray` - confirmed via a real device crash (`Array operation attempted
on variable not DIM'd`, `pixel[1]` on an `Invalid` value) the first time this
test ran there. The exact same call, on the exact same code path, returns
real pixel data on **both** the BrightScript Simulator GUI app and headless
`brs-cli` (`brs-node`) - i.e. this is a genuine simulator/real-hardware
behavioral difference in the engine, not a bug in this test. `roBitmap.GetByteArray()`
is unaffected on either platform (used throughout this repo's own Rooibos
suite, e.g. `TileMapBaking.spec.bs`) - the difference is specific to calling
it on a live `roScreen`.

The test now detects this (`type(pixel) = "roByteArray"`) and falls back to
relying purely on a real screenshot of an on-screen marker instead of crashing
or silently misreporting.

Filed upstream as [lvcabral/brs-engine#1229](https://github.com/lvcabral/brs-engine/issues/1229).

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
   plausible missing ingredient this spike didn't yet isolate. Multiple
   simultaneous large blits (up to 16/frame) didn't reproduce it either (see
   above), so raw draw-call volume alone isn't the missing ingredient - GC/
   allocation pressure and the full `GameEntity`/`Room`/collision pipeline
   remain the more likely candidates.
4. Keep `LargeImageRenderTest` in `examples/rendererTest` as a reusable
   diagnostic - it's driven entirely by up/down/left/right/rev/fwd/OK, so it's
   cheap to extend with a "GC pressure" toggle for whoever picks up step 1 or 3.
5. ~~File the `roScreen.GetByteArray()` simulator/real-hardware discrepancy
   upstream~~ - done: [lvcabral/brs-engine#1229](https://github.com/lvcabral/brs-engine/issues/1229).

## Artifacts from this spike

- `examples/rendererTest/src/source/Tests/LargeImageRenderTest.bs` (new demo)
- `examples/rendererTest/src/source/DemoList.bs` (registers it, id `large-image-render`)
- `examples/rendererTest/src/source/RendererTest.bs` (added a public `screenRef`
  field, set by `main.bs` right after each demo is constructed - lets a demo
  that needs to verify the *actual* screen buffer, not just something drawn
  into an offscreen bitmap via `Renderer`, get at the raw `roScreen`)
- `examples/rendererTest/src/source/main.bs` (sets `activeDemo.screenRef`;
  `rev`/`fwd` cycle the simultaneous-copy count)
- `examples/rendererTest/src/images/sizetest/size-{64,128,192,256,320,384,448,512,576,640}.png`
  (generated solid-green test images, one per size in the sweep)
