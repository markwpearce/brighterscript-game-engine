# Adaptive render quality - design

Issues: #251 (adaptive render settings), #126 (adaptive draw distance), #125 (fade near the draw-distance limit - **out of scope**, stays a separate issue; could later become a quality setting).

## Goal

Let the engine pick draw-quality values (draw distance, plane slice count, triangle thresholds, billboard fast-draw tolerances, ...) per device, and optionally adapt them at runtime to hold a target FPS - raising visual quality when there's headroom, lowering it when there isn't.

## Decisions (from brainstorming)

- **One dial**: a quality level `BGE.RenderQualityLevel` = `basic | low | medium | high | ultra`. Each level is a preset bundle of settings. Automatic tuning moves the level; nothing tunes individual knobs independently.
- **Device-seeded by default**: every `Game` starts at a level chosen from the device (model table + inference). No opt-in needed for seeding.
- **Adaptive tuning is opt-in**: `game.enableAdaptiveQuality(options)`. Without it the seeded level never changes.
- **Games can customize**: per-field overrides of any level's preset, plus an `onQualityChanged(level)` hook on entities/scenes for game-owned knobs (particle counts, effects, enemy density).
- **Where today's value sits depends on the knob.** For a knob whose current value is already the best visual quality (plane slice count, fast-draw tolerances), today's value is **Ultra** and the lower levels step down gradually from it. For a knob that can go either way (draw distance, triangle thresholds), today's value is **Medium**. So Medium is no longer identical to the pre-feature engine: devices seeded below Ultra draw fewer plane slices and take the fast-draw path more often.
- **Draw distance is a multiplier** on the game's own `Camera3d.maxDrawDistance`, because sensible draw distance is game-specific.
- **`computeOverlapClusters` is not a quality setting** - its value depends on scene content (interpenetrating models), not device power. It stays the game's explicit choice.
- **Extensible**: any future constant that trades visual quality for speed goes into `RenderQualitySettings`, enforced by a completeness test.

## Settings and presets

`BGE.RenderQualitySettings` (interface, `engine/quality/RenderQualityPresets.bs`):

| Field | Replaces | Basic | Low | **Medium** | High | Ultra |
|---|---|---|---|---|---|---|
| `drawDistanceScale` | - (new) | 0.4 | 0.6 | **1.0** | 1.25 | 1.5 |
| `drawDistanceOverride` | - (new, optional absolute distance; `<= 0` = unset, use the scale) | 0 | 0 | **0** | 0 | 0 |
| `planeSliceCount` | `SCENE_OBJECT_PLANE_SLICE_COUNT` (50) | 20 | 28 | 36 | 44 | **50** |
| `triangleSkipSize` | `TriangleDrawThreshold` (4) | 8 | 6 | **4** | 3 | 2 |
| `triangleQuickDrawThreshold` | `TriangleQuickDrawThreshold` (64) | 128 | 96 | **64** | 48 | 32 |
| `triangleQuickDrawStep` | `levelOfDetail = 2` in `drawQuickTriangleTo` | 4 | 3 | **2** | 2 | 1 |
| `fastDrawParallelogramTolerance` | `isApproximatelyRotatedRectangle` default 0.03 | 0.10 | 0.08 | 0.06 | 0.045 | **0.03** |
| `fastDrawPerpendicularityTolerance` | `isApproximatelyRotatedRectangle` default 0.05 | 0.15 | 0.13 | 0.10 | 0.075 | **0.05** |

Bold marks today's value for each knob. Every other value is **initial guesses, not measurements**. Per-operation Roku draw costs are not predictable from code; the presets must be tuned on real hardware with the `quality-levels` rendererTest demo (below) before this ships.

**Simulator adjustment** stays separate from presets: today's simulator branch (`TriangleQuickDrawThresholdForSimulator = 32`, `levelOfDetail = 4`) encodes the simulator's cost model (line drawing is slow there), not a quality choice. On the simulator, the renderer applies `min(preset threshold, 32)` and `max(preset step, 4)`, so the simulator's triangle drawing at Medium is exactly as today.

### Adding a new quality setting

1. Add the field to `RenderQualitySettings`.
2. Give it a value in all five presets in `RenderQualityPresets.bs`. The current hard-coded value goes at **Ultra** if it's already the best visual quality, with lower levels stepping down gradually from it; otherwise it goes at **Medium**, with lower levels trading quality for speed and higher levels the reverse.
3. Replace the constant's read with `rendererObj.qualitySettings.<field>` (or the camera equivalent).
4. The preset-completeness spec fails CI if any level is missing the field.

CLAUDE.md gains a conventions bullet stating this rule.

## Draw distance

- `Camera3d.maxDrawDistance` becomes the **game-authored base value** and is no longer clamped in place.
- New `drawDistanceScale` (default 1.0) and `drawDistanceOverride` (default 0 = unset) fields on the base `Camera` (ignored by `Camera2d`), pushed onto the renderer's camera every frame in `Renderer.setupCameraForFrame()` - so a camera assigned directly (`renderer.camera = cam`, `Game.setCamera()`) still picks them up.
- New `Camera3d.getEffectiveMaxDrawDistance()`: `drawDistanceOverride` if `> 0`, else `maxDrawDistance * drawDistanceScale`, then clamped to the existing device cap (`getMaxDrawDistanceDeviceCap()`: 900 simulator / 2500 FHD / 30 SD-HD). The cap always wins.
- **Planes keep a constant draw distance** (user feedback after on-device testing): `SceneObjectPlane` uses `Camera3d.getPlaneDrawDistance()` - `maxDrawDistance` capped per device, ignoring the level's scale/override - so the horizon never moves with the level and a level change never rebuilds plane bitmaps. Everything else uses the effective distance.
- Every other current reader of `maxDrawDistance` switches to the effective value: `Camera3d.isInView`'s far-clip check (`Camera3d.bs:218`), `projectionChangedThisFrame()`'s dirty check, and `SceneObjectPlane` (pre-perspective bitmap sizing, far distance, supertexture sizing/rebuild checks).
- **Behavior change**: reading `maxDrawDistance` back after setting it above the device cap now returns what was set (previously the capped value). Existing specs/docs asserting the old read-back behavior are updated.
- A level change that changes the effective distance triggers `SceneObjectPlane`'s existing bitmap/supertexture rebuilds. That one-off cost is expected; the controller's settle period ignores it. Each rebuild releases the old bitmap before allocating the new one, and a failed allocation logs a warning and skips that plane for the frame (retried next frame) instead of crashing. High/Ultra scales are kept at 1.25/1.5 because the pre-perspective bitmap grows with the square of the distance - Ultra at 2.0 crashed `examples/terrain` (two textured planes) on a real Roku Ultra.

## Device seeding

`engine/quality/DeviceQualitySeed.bs`: `BGE.seedRenderQualityLevel(model, graphicsPlatform, uiResolutionName, isSimulator) as RenderQualityLevel` - a pure function (unit-testable with fake inputs), plus a thin wrapper that reads `roDeviceInfo` (`GetModel()`, `GetGraphicsPlatform()`, `GetUIResolution().name`, `HasFeature("simulation_engine")`).

Resolution order:

1. Simulator → **medium**.
2. `graphicsPlatform = "directfb"` (no GPU) → **basic**.
3. Known model (matched on the model-code prefix before the country/variant suffix, e.g. `4850X`, `3941X2`, `C000GB` → `C000`) → table level.
4. Unknown model, inferred from Roku's naming conventions:
   - **Numeric streaming players** (`NNNN`): the first digit is the family (3 = Express/Stick, 4 = Premiere/Ultra, 9 = soundbar/streambar), and a higher number within a family is newer. Use the level of the nearest known model **at or below** it in the same family.
   - **Roku TVs** (`L000`/`L100` letter codes): later letters are newer. Use the nearest known TV code at or before it alphabetically.
5. Clamp: a 720p (`HD`) or `SD` UI resolution caps the result at **low**.
6. Nothing matched → **medium**.

Initial table (from developer.roku.com/dev/docs/hardware, current and updatable models):

| Level | Models |
|---|---|
| basic | 3700, 3710, 5000 (MIPS, no GPU); 4200, 4210, 4230 (A9); 3600 (A7) |
| low | 3800, 3840, 3900, 3910, 3930, 3931, 3960; TVs 8000, D000, H000, K000, T100, K8P |
| medium | 4620, 4630, 4640, 4660, 4662, 3810, 3811, 3920, 3921, 9100, 9102; TVs 7000, C000, G000, L000, P000 |
| high | 3820, 3821, 3830, 3940, 3941, 3942, 9104, 4670; TVs 6000, A000 |
| ultra | 4800, 4850; TVs J000, M000 |

The table only picks the starting level; when adaptive tuning is on, the controller decides from there. Benchmark-driven table generation (#251's CSV proposal) is a later follow-up.

## Runtime ownership

- `BGE.Renderer` gains `qualitySettings as RenderQualitySettings`, defaulting to the Medium preset, and `setQualitySettings(settings)`, whose draw-distance fields reach the camera through `setupCameraForFrame()` (above). A standalone `Renderer` (no `Game`, e.g. `rendererTest`) is not device-seeded; it uses Medium unless the caller sets something else.
- `BGE.RenderQualityManager` (`engine/quality/RenderQualityManager.bs`), owned by `Game` as `game.renderQuality`:
  - `getLevel()`, `setLevel(level)` (applies immediately - settings are only read at draw time, so a mid-frame change from an input handler just takes effect for that frame's draw)
  - `overridePreset(level, partialSettings)` - shallow per-field merge onto that level's engine preset; fields not named keep engine defaults, so a setting added later still gets its default under an existing override.
  - `getSettings(level)` - the merged settings for a level.
  - Applies settings to the **game canvas renderer only** (`game.canvas.renderer`); the UI canvas is untouched.
  - On a level change, calls `onQualityChanged(level)` on the current scene and every valid entity (same dispatch shape as `postGameEvent`, re-validating entities after each call).
- `Game` API:
  - `game.setQualityLevel(level)` - pins a level and disables adaptive tuning.
  - `game.enableAdaptiveQuality(options = {})` / `game.disableAdaptiveQuality()`. Enabling first moves the current level into `minLevel`..`maxLevel` (dispatching `onQualityChanged` if that changes it).
  - Seeding happens in the `Game` constructor.
- `GameEntity.onQualityChanged(level as BGE.RenderQualityLevel)` - empty overridable hook.
- `FpsDisplay` appends the level, e.g. `FPS: 30 | Q: High (auto)`.

## Adaptive controller

`BGE.QualityController` (`engine/quality/QualityController.bs`) - a plain class with no `Game` or Roku-component dependency: `update(dt) as RenderQualityLevel` returns the level it wants, and `notifyLevelChanged()` / `notifySceneChanged()` start the settle period. That makes it testable with synthetic `dt` sequences.

`Game` ticks it once per frame, after `SwapBuffers` and before a pending scene change is applied. A requested level change is applied through the manager there, at the frame boundary.

Options (`BGE.AdaptiveQualityOptions`, all optional):

| Option | Default | Meaning |
|---|---|---|
| `targetFps` | 20 | Frame-time budget = 1 / targetFps |
| `minLevel` / `maxLevel` | basic / ultra | Bounds the controller never leaves |
| `windowSeconds` | 2.0 | Rolling average window of full frame time (`Game.dt`, includes swap) |
| `outlierFrameSeconds` | 0.25 | Frames longer than this are excluded (GC, loading, stalls) |
| `settleSeconds` | 0.5 | Samples ignored after a level change or scene change |
| `stepDownBelowFraction` | 0.9 | Step down when average FPS < targetFps × this |
| `stepUpHeadroomFraction` | 1.25 | Step up when average FPS ≥ targetFps × this ... |
| `stepUpSustainSeconds` | 2.0 | ... sustained this long |
| `maxMeasurableFps` | 60 | Display refresh ceiling; the step-up threshold is `min(targetFps × stepUpHeadroomFraction, maxMeasurableFps × 0.97)`, so at a 60 fps target a sustained at-target frame rate still probes up |
| `stepDownCooldownSeconds` | 2.0 | Minimum time between consecutive downward steps |
| `probeFailWindowSeconds` | 4.0 | A step-down this soon after a step-up (counting only time after the settle period) marks that level as failed |
| `probeBackoffSeconds` | 30 | Initial time a failed level is not retried; doubles per repeated failure |

Behavior:

- **Down fast**: the window average is below the step-down threshold (and the cooldown has passed) → one level down.
- **Up slow**: the average stays at or above the headroom threshold for `stepUpSustainSeconds` → probe one level up, unless that level is in backoff.
- **Dead zone**: between the thresholds, nothing changes.
- **Probe backoff**: a failed up-probe blocks that level for the backoff time. This matters at a 60 fps target, where vsync hides headroom and probing is the only signal.
- The window resets on every level change and scene change.

All thresholds are options with these defaults, so they can be tuned on hardware without code changes.

## Testing

Rooibos specs (one `@suite` per file):

- Preset completeness: every level defines every field Medium defines; each legacy constant appears at its documented level (Ultra for plane slices and fast-draw tolerances, Medium for everything else); each knob changes monotonically from Basic to Ultra.
- `overridePreset`: per-field merge, other levels untouched, and unnamed fields keep defaults.
- Device seeding: known models, suffix stripping, family and TV-letter inference, the no-GPU / 720p clamps, simulator, and the Medium fallback.
- Controller with synthetic `dt` sequences: steps down, steps up only after sustain, dead zone, cooldown, settle, outlier exclusion, min/max bounds, probe backoff and its doubling.
- Renderer/camera: `setQualitySettings` reaches the triangle thresholds, the fast-draw tolerances and the plane slice count; `getEffectiveMaxDrawDistance` applies scale, override and cap; the simulator adjustment.
- Game: seeding happens at construction, `setQualityLevel` disables auto, `onQualityChanged` reaches the scene and entities.

Manual / on-device:

- New `rendererTest` demo `quality-levels`: a mixed scene (plane, billboards, circles, triangles). OK cycles the level; the existing timing readout shows the cost per level. This is the preset-tuning tool.
- `examples/terrain` with `enableAdaptiveQuality()` on a real device via rokubot: confirm the level converges without oscillating, and the plane rebuild hitch on level change is absorbed by the settle period.

## Docs

- CLAUDE.md: an architecture bullet for render quality, the conventions bullet for adding settings, and an update to the `maxDrawDistance` read-back note.
- `docs/`: a short guide section on quality levels and adaptive tuning (how-to first, per the docs style preference).

## Out of scope

- #125 fade band near the draw distance.
- Benchmark-CSV-generated device table (#251 follow-up).
- Particle counts, circle outline segments and other per-drawable values - these belong to games via `onQualityChanged`.
- UI canvas quality.
