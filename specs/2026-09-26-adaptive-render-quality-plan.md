# Adaptive Render Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Device-seeded render quality levels (Basic…Ultra) that bundle every draw-quality knob, plus an opt-in controller that moves the level to hold a target FPS.

**Architecture:** A `RenderQualitySettings` record (one field per knob) lives on `BGE.Renderer` and is read wherever a quality constant is read today. `Game` owns a `RenderQualityManager` that seeds a level from the device, applies that level's (optionally overridden) preset to the game canvas renderer, optionally runs a pure `QualityController` fed with `Game.dt`, and broadcasts `onQualityChanged(level)`. Draw distance is a multiplier on the game's own `Camera3d.maxDrawDistance`, applied through a new `getEffectiveMaxDrawDistance()`.

**Tech Stack:** BrighterScript (bsc), Rooibos v6 (`rooibos-roku`) run headlessly via `brs-cli`, bslint, rokubot for on-device checks.

**Spec:** `specs/2026-09-26-adaptive-render-quality-design.md`

## Global Constraints

- All engine code lives in the `BGE` namespace under `src/source/`. New files go in `src/source/engine/quality/`.
- Every file that references a symbol from another file must `import` it (CLAUDE.md conventions) - including a new file referenced from an existing one.
- A `*.spec.bs` file holds exactly **one** `@suite` class.
- `assertEqual` is type-strict (Integer vs Float). Presets store float knobs as float literals (`0.4`, `1.0`) and integer knobs as integer literals; tests compare with the same literal type.
- Don't name a suite field `scene`. Don't `assertEqual` whole objects. Never compare two class instances / native components with `=`.
- Don't construct an object inline as a call argument that references `m` (`x.add(new Foo(m))`) - assign to a local first.
- bslint: no single-line `if` (`inline-if-style: never`).
- Doc comments are written for game developers using the engine; implementation rationale goes in short inline comments (1-3 sentences, the "why" only).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push to `main`; work on `feature/adaptive-render-quality`.
- Quality gate after every task: `npm run check` (lint + validate + headless tests) from the repo root must pass.
- Levels are integer enum values: `basic = 0`, `low = 1`, `medium = 2`, `high = 3`, `ultra = 4`. APIs that do arithmetic on levels take/return `as integer`.
- Preset values (verbatim from the spec; **bold** = today's value):

| Field | Basic | Low | Medium | High | Ultra |
|---|---|---|---|---|---|
| `drawDistanceScale` | 0.4 | 0.6 | **1.0** | 1.5 | 2.0 |
| `drawDistanceOverride` | 0.0 | 0.0 | **0.0** | 0.0 | 0.0 |
| `planeSliceCount` | 20 | 28 | 36 | 44 | **50** |
| `triangleSkipSize` | 8.0 | 6.0 | **4.0** | 3.0 | 2.0 |
| `triangleQuickDrawThreshold` | 128.0 | 96.0 | **64.0** | 48.0 | 32.0 |
| `triangleQuickDrawStep` | 4 | 3 | **2** | 2 | 1 |
| `fastDrawParallelogramTolerance` | 0.10 | 0.08 | 0.06 | 0.045 | **0.03** |
| `fastDrawPerpendicularityTolerance` | 0.15 | 0.13 | 0.10 | 0.075 | **0.05** |

- Device draw-distance caps are unchanged: 900 simulator, 2500 FHD, 30 SD/HD - applied last, always win.
- Simulator triangle adjustment: `threshold = min(preset, 32)`, `step = max(preset, 4)`.
- Controller defaults: `targetFps 30`, `minLevel basic`, `maxLevel ultra`, `windowSeconds 2.0`, `outlierFrameSeconds 0.25`, `settleSeconds 0.5`, `stepDownBelowFraction 0.9`, `stepUpHeadroomFraction 1.25`, `stepUpSustainSeconds 5.0`, `maxMeasurableFps 60`, `stepDownCooldownSeconds 2.0`, `probeFailWindowSeconds 4.0`, `probeBackoffSeconds 30`.

## Review Focus

1. **A game that already sets `camera.maxDrawDistance` above the device cap** (e.g. `examples/terrain`) should still render within the cap - reading the field back now returns the set value, but every culling/plane path must use `getEffectiveMaxDrawDistance()`. Pinned in Task 3 by a test that sets 5000 and asserts a point at 950 is culled.
2. **A camera assigned directly (`renderer.camera = cam` or `Game.setCamera(cam)`) after quality was applied** should still get the level's draw-distance scale. Pinned in Task 4 by a test that swaps the camera after `setQualitySettings` and checks the effective distance after `setupCameraForFrame()`.
3. **Overriding the preset of the level currently active** should take effect immediately, not only on the next level change. Pinned in Task 6.
4. **A single huge frame (GC, asset load) or the rebuild hitch right after a level change** must never cause a step down. Pinned in Task 5 (outlier + settle tests).
5. **`setQualityLevel()` while adaptive tuning is on** must pin the level (turn auto off), not be undone by the controller a few seconds later. Pinned in Task 6.

---

### Task 1: Quality levels, settings record and presets

**Files:**
- Create: `src/source/engine/quality/RenderQualityLevel.bs`
- Create: `src/source/engine/quality/RenderQualitySettings.bs`
- Create: `src/source/engine/quality/RenderQualityPresets.bs`
- Create: `src/source/engine/quality/RenderQualityPresets.spec.bs`
- Modify: `src/source/engine/renderer/Renderer.bs` (toolchain probe only, see Step 1)

**Interfaces:**
- Produces:
  - `enum BGE.RenderQualityLevel` (`basic = 0` … `ultra = 4`)
  - `function BGE.getRenderQualityLevelName(level as integer) as string` → `"Basic"`, `"Low"`, `"Medium"`, `"High"`, `"Ultra"`
  - `function BGE.clampRenderQualityLevel(level as integer) as integer` → clamped to `[0, 4]`
  - `interface BGE.RenderQualitySettings` with the eight fields in Global Constraints
  - `function BGE.getRenderQualityPreset(level as integer) as BGE.RenderQualitySettings` → a **fresh** AA on each call (callers may mutate it)
  - `function BGE.mergeRenderQualitySettings(base as BGE.RenderQualitySettings, overrides as roAssociativeArray) as BGE.RenderQualitySettings` → a new AA: a copy of `base` with each key in `overrides` that also exists in `base` replaced

- [ ] **Step 1: Toolchain probe (old file → new file resolution)**

Your notes record a bslint bug where an existing file could not resolve a symbol from a brand-new file (`project_bslint_rooibos_new_file_bug`); the later convention of always adding an explicit `import` may be what fixes it. Verify before building on it. Create `src/source/engine/quality/RenderQualityLevel.bs`:

```brighterscript
namespace BGE

  ' Render quality levels, from cheapest to best-looking. See `Game.renderQuality`,
  ' `Game.setQualityLevel()` and `Game.enableAdaptiveQuality()`.
  enum RenderQualityLevel
    basic = 0
    low = 1
    medium = 2
    high = 3
    ultra = 4
  end enum

  ' Display name for a quality level, e.g. "High".
  '
  ' @param {integer} level - a `BGE.RenderQualityLevel` value
  ' @return {string}
  function getRenderQualityLevelName(level as integer) as string
    names = ["Basic", "Low", "Medium", "High", "Ultra"]
    return names[clampRenderQualityLevel(level)]
  end function

  ' Clamps any integer into the valid `BGE.RenderQualityLevel` range.
  '
  ' @param {integer} level
  ' @return {integer}
  function clampRenderQualityLevel(level as integer) as integer
    if level < RenderQualityLevel.basic
      return RenderQualityLevel.basic
    end if
    if level > RenderQualityLevel.ultra
      return RenderQualityLevel.ultra
    end if
    return level
  end function

end namespace
```

Temporarily add to `Renderer.bs`: `import "../quality/RenderQualityLevel.bs"` at the top and, inside `class Renderer`, `private probeLevel as integer = BGE.RenderQualityLevel.medium`.

Run: `npm run validate`
Expected: passes. **If it fails with `cannot-find-name`**, stop and report to the user: the fallback is to put `RenderQualityLevel`, `RenderQualitySettings` and the preset functions inside `Renderer.bs` itself (same-file placement), and to have `RenderQualityManager`/`QualityController` (new files) call into existing files only, never the reverse. Every later task depends on this answer.

Once it passes, remove the `probeLevel` field (keep the import - Task 4 needs it).

- [ ] **Step 2: Write the failing preset tests**

Create `src/source/engine/quality/RenderQualityPresets.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.RenderQualityPresets")
  class RenderQualityPresetsTests extends rooibos.BaseTestSuite

    @describe("completeness")

    @it("defines every Medium field at every level")
    function _()
      mediumKeys = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.medium).Keys()
      for level = BGE.RenderQualityLevel.basic to BGE.RenderQualityLevel.ultra
        preset = BGE.getRenderQualityPreset(level)
        for each key in mediumKeys
          m.assertTrue(preset.DoesExist(key), `level ${level} is missing ${key}`)
        end for
        m.assertEqual(mediumKeys.Count(), preset.Keys().Count())
      end for
    end function

    @describe("legacy values")

    @it("puts today's values at Medium for draw distance and triangle knobs")
    function _()
      medium = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.medium)
      m.assertEqual(1.0, medium.drawDistanceScale)
      m.assertEqual(0.0, medium.drawDistanceOverride)
      m.assertEqual(4.0, medium.triangleSkipSize)
      m.assertEqual(64.0, medium.triangleQuickDrawThreshold)
      m.assertEqual(2, medium.triangleQuickDrawStep)
    end function

    @it("puts today's values at Ultra for plane slices and fast-draw tolerances")
    function _()
      ultra = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.ultra)
      m.assertEqual(50, ultra.planeSliceCount)
      m.assertEqual(0.03, ultra.fastDrawParallelogramTolerance)
      m.assertEqual(0.05, ultra.fastDrawPerpendicularityTolerance)
    end function

    @describe("monotonic")

    @it("raises quality from Basic to Ultra for every knob")
    function _()
      for level = BGE.RenderQualityLevel.basic to BGE.RenderQualityLevel.high
        lower = BGE.getRenderQualityPreset(level)
        higher = BGE.getRenderQualityPreset(level + 1)
        ' higher is better/more expensive
        m.assertTrue(higher.drawDistanceScale >= lower.drawDistanceScale)
        m.assertTrue(higher.planeSliceCount >= lower.planeSliceCount)
        ' lower is better/more expensive
        m.assertTrue(higher.triangleSkipSize <= lower.triangleSkipSize)
        m.assertTrue(higher.triangleQuickDrawThreshold <= lower.triangleQuickDrawThreshold)
        m.assertTrue(higher.triangleQuickDrawStep <= lower.triangleQuickDrawStep)
        m.assertTrue(higher.fastDrawParallelogramTolerance <= lower.fastDrawParallelogramTolerance)
        m.assertTrue(higher.fastDrawPerpendicularityTolerance <= lower.fastDrawPerpendicularityTolerance)
      end for
    end function

    @describe("getRenderQualityPreset")

    @it("returns a fresh copy each call")
    function _()
      first = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.high)
      first.planeSliceCount = 999
      m.assertEqual(44, BGE.getRenderQualityPreset(BGE.RenderQualityLevel.high).planeSliceCount)
    end function

    @it("clamps an out-of-range level")
    function _()
      m.assertEqual(50, BGE.getRenderQualityPreset(99).planeSliceCount)
      m.assertEqual(20, BGE.getRenderQualityPreset(-3).planeSliceCount)
    end function

    @describe("mergeRenderQualitySettings")

    @it("replaces only the named fields")
    function _()
      base = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.low)
      merged = BGE.mergeRenderQualitySettings(base, {planeSliceCount: 80})
      m.assertEqual(80, merged.planeSliceCount)
      m.assertEqual(0.6, merged.drawDistanceScale)
      m.assertEqual(28, base.planeSliceCount)
    end function

    @it("ignores unknown keys")
    function _()
      base = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.low)
      merged = BGE.mergeRenderQualitySettings(base, {notAKnob: 1})
      m.assertFalse(merged.DoesExist("notAKnob"))
    end function

    @describe("level names")

    @it("names every level")
    function _()
      m.assertEqual("Basic", BGE.getRenderQualityLevelName(BGE.RenderQualityLevel.basic))
      m.assertEqual("Ultra", BGE.getRenderQualityLevelName(BGE.RenderQualityLevel.ultra))
    end function

  end class

end namespace
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `npm run test:ci`
Expected: build/validation FAIL - `getRenderQualityPreset` not found.

- [ ] **Step 4: Implement the settings interface and presets**

Create `src/source/engine/quality/RenderQualitySettings.bs`:

```brighterscript
namespace BGE

  ' Every draw-quality value a `BGE.Renderer` uses. Each `BGE.RenderQualityLevel` has
  ' a preset (see `BGE.getRenderQualityPreset()`); override individual fields per
  ' level with `game.renderQuality.overridePreset()`.
  '
  ' Adding a new quality setting: add the field here, give it a value at every level
  ' in RenderQualityPresets.bs, and read it via `renderer.qualitySettings`.
  interface RenderQualitySettings
    ' Multiplier on `Camera3d.maxDrawDistance`
    drawDistanceScale as float
    ' Absolute draw distance for this level; 0 or less means "use drawDistanceScale"
    drawDistanceOverride as float
    ' Horizontal slices used to draw a `DrawablePlane` in perspective
    planeSliceCount as integer
    ' Triangles smaller than this many pixels on both axes are skipped
    triangleSkipSize as float
    ' Triangles smaller than this on either axis are drawn with the cheaper line-fill
    triangleQuickDrawThreshold as float
    ' Pixel step between lines in the cheap line-fill (1 = solid)
    triangleQuickDrawStep as integer
    ' How far from a true parallelogram a billboard's quad may be and still use the
    ' cheap single-call fast draw
    fastDrawParallelogramTolerance as float
    ' How far from perpendicular a billboard's quad edges may be and still use the
    ' cheap single-call fast draw
    fastDrawPerpendicularityTolerance as float
  end interface

end namespace
```

Create `src/source/engine/quality/RenderQualityPresets.bs`:

```brighterscript
import "RenderQualityLevel.bs"
import "RenderQualitySettings.bs"

namespace BGE

  ' The engine's built-in settings for a quality level, as a new copy each call.
  '
  ' @param {integer} level - a `BGE.RenderQualityLevel` value (clamped)
  ' @return {BGE.RenderQualitySettings}
  function getRenderQualityPreset(level as integer) as RenderQualitySettings
    level = clampRenderQualityLevel(level)
    ' One column per level: basic, low, medium, high, ultra. Today's pre-feature
    ' value is at medium for two-way knobs, at ultra for knobs already at best quality.
    drawDistanceScale = [0.4, 0.6, 1.0, 1.5, 2.0]
    planeSliceCount = [20, 28, 36, 44, 50]
    triangleSkipSize = [8.0, 6.0, 4.0, 3.0, 2.0]
    triangleQuickDrawThreshold = [128.0, 96.0, 64.0, 48.0, 32.0]
    triangleQuickDrawStep = [4, 3, 2, 2, 1]
    fastDrawParallelogramTolerance = [0.10, 0.08, 0.06, 0.045, 0.03]
    fastDrawPerpendicularityTolerance = [0.15, 0.13, 0.10, 0.075, 0.05]
    return {
      drawDistanceScale: drawDistanceScale[level]
      drawDistanceOverride: 0.0
      planeSliceCount: planeSliceCount[level]
      triangleSkipSize: triangleSkipSize[level]
      triangleQuickDrawThreshold: triangleQuickDrawThreshold[level]
      triangleQuickDrawStep: triangleQuickDrawStep[level]
      fastDrawParallelogramTolerance: fastDrawParallelogramTolerance[level]
      fastDrawPerpendicularityTolerance: fastDrawPerpendicularityTolerance[level]
    }
  end function

  ' Copies `base`, replacing each field named in `overrides`. Keys that aren't
  ' quality settings are ignored.
  '
  ' @param {BGE.RenderQualitySettings} base
  ' @param {roAssociativeArray} overrides - e.g. {planeSliceCount: 80}
  ' @return {BGE.RenderQualitySettings}
  function mergeRenderQualitySettings(base as RenderQualitySettings, overrides as roAssociativeArray) as RenderQualitySettings
    merged = {}
    for each key in base
      merged[key] = base[key]
    end for
    if invalid <> overrides
      for each key in overrides
        if merged.DoesExist(key)
          merged[key] = overrides[key]
        end if
      end for
    end if
    return merged
  end function

end namespace
```

If a float literal like `0.03` compares unequal in the legacy-value test because of float precision, compare with the same literal stored the same way (both sides are float literals, so they should match); if it still fails, read the Rooibos diff before changing anything.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npm run check`
Expected: lint, validate and all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/quality src/source/engine/renderer/Renderer.bs
git commit -m "Add render quality levels and presets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Device seeding

**Files:**
- Create: `src/source/engine/quality/DeviceQualitySeed.bs`
- Create: `src/source/engine/quality/DeviceQualitySeed.spec.bs`

**Interfaces:**
- Consumes: `BGE.RenderQualityLevel` (Task 1)
- Produces:
  - `function BGE.seedRenderQualityLevel(model as string, graphicsPlatform as string, uiResolutionName as string, isSimulator as boolean) as integer` (pure)
  - `function BGE.seedRenderQualityLevelForDevice() as integer` (reads `roDeviceInfo`)
  - `function BGE.getRenderQualityModelPrefix(model as string) as string`

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/quality/DeviceQualitySeed.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.seedRenderQualityLevel")
  class DeviceQualitySeedTests extends rooibos.BaseTestSuite

    @describe("getRenderQualityModelPrefix")

    @it("strips the variant/country suffix")
    function _()
      m.assertEqual("4850", BGE.getRenderQualityModelPrefix("4850X"))
      m.assertEqual("3941", BGE.getRenderQualityModelPrefix("3941X2"))
      m.assertEqual("4802", BGE.getRenderQualityModelPrefix("4802CA"))
      m.assertEqual("C000", BGE.getRenderQualityModelPrefix("C000GB"))
      m.assertEqual("T100", BGE.getRenderQualityModelPrefix("T100X"))
      m.assertEqual("K8P", BGE.getRenderQualityModelPrefix("K8PXX"))
    end function

    @describe("special cases")

    @it("seeds the simulator at Medium")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.medium, BGE.seedRenderQualityLevel("4850X", "opengl", "FHD", true))
    end function

    @it("seeds a device without a GPU at Basic, even if the model is unknown")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.basic, BGE.seedRenderQualityLevel("9999X", "directfb", "FHD", false))
    end function

    @describe("known models")

    @it("uses the table")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.ultra, BGE.seedRenderQualityLevel("4850X", "opengl", "FHD", false))
      m.assertEqual(BGE.RenderQualityLevel.high, BGE.seedRenderQualityLevel("3941X2", "opengl", "FHD", false))
      m.assertEqual(BGE.RenderQualityLevel.medium, BGE.seedRenderQualityLevel("4640X", "opengl", "FHD", false))
      m.assertEqual(BGE.RenderQualityLevel.low, BGE.seedRenderQualityLevel("3930X", "opengl", "HD", false))
      m.assertEqual(BGE.RenderQualityLevel.basic, BGE.seedRenderQualityLevel("4200X", "opengl", "HD", false))
      m.assertEqual(BGE.RenderQualityLevel.ultra, BGE.seedRenderQualityLevel("M000X", "opengl", "FHD", false))
    end function

    @describe("inference for unknown models")

    @it("uses the nearest known player at or below it in the same family")
    function _()
      ' 4860 -> nearest known 4xxx at or below is 4850 (ultra)
      m.assertEqual(BGE.RenderQualityLevel.ultra, BGE.seedRenderQualityLevel("4860X", "opengl", "FHD", false))
      ' 3945 -> 3942 (high)
      m.assertEqual(BGE.RenderQualityLevel.high, BGE.seedRenderQualityLevel("3945X", "opengl", "FHD", false))
    end function

    @it("uses the nearest known TV code at or before it alphabetically")
    function _()
      ' N000 -> M000 (ultra)
      m.assertEqual(BGE.RenderQualityLevel.ultra, BGE.seedRenderQualityLevel("N000X", "opengl", "FHD", false))
      ' B000 -> A000 (high)
      m.assertEqual(BGE.RenderQualityLevel.high, BGE.seedRenderQualityLevel("B000X", "opengl", "FHD", false))
    end function

    @it("caps a 720p or SD device at Low")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.low, BGE.seedRenderQualityLevel("4850X", "opengl", "HD", false))
      m.assertEqual(BGE.RenderQualityLevel.low, BGE.seedRenderQualityLevel("4860X", "opengl", "SD", false))
    end function

    @it("falls back to Medium when nothing matches")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.medium, BGE.seedRenderQualityLevel("", "opengl", "FHD", false))
      m.assertEqual(BGE.RenderQualityLevel.medium, BGE.seedRenderQualityLevel("1000X", "opengl", "FHD", false))
      m.assertEqual(BGE.RenderQualityLevel.medium, BGE.seedRenderQualityLevel("zzz", "opengl", "FHD", false))
    end function

    @describe("seedRenderQualityLevelForDevice")

    @it("seeds Medium under brs-cli (reports as the simulator)")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.medium, BGE.seedRenderQualityLevelForDevice())
    end function

  end class

end namespace
```

- [ ] **Step 2: Run to verify failure**

Run: `npm run test:ci`
Expected: FAIL - `seedRenderQualityLevel` not found.

- [ ] **Step 3: Implement**

Create `src/source/engine/quality/DeviceQualitySeed.bs`:

```brighterscript
import "RenderQualityLevel.bs"

namespace BGE

  ' The model-code prefix used to look a device up: everything up to the first
  ' "X" after the leading 3-4 characters (e.g. "3941X2" -> "3941", "C000GB" -> "C000",
  ' "K8PXX" -> "K8P"), or the first four characters when there is no "X".
  '
  ' @param {string} model - `roDeviceInfo.GetModel()`
  ' @return {string}
  function getRenderQualityModelPrefix(model as string) as string
    if invalid = model or Len(model) = 0
      return ""
    end if
    upper = UCase(model)
    ' Search from index 3 so a TV code's own letter (e.g. "X000") isn't mistaken for
    ' the suffix separator.
    xPos = Instr(4, upper, "X")
    if xPos > 0
      return Left(upper, xPos - 1)
    end if
    return Left(upper, 4)
  end function

  ' Starting quality level for a device. Pure - `seedRenderQualityLevelForDevice()`
  ' calls this with the real device's values.
  '
  ' @param {string} model - `roDeviceInfo.GetModel()`, e.g. "4850X"
  ' @param {string} graphicsPlatform - `roDeviceInfo.GetGraphicsPlatform()`, "opengl" or "directfb"
  ' @param {string} uiResolutionName - `roDeviceInfo.GetUIResolution().name`: "SD", "HD" or "FHD"
  ' @param {boolean} isSimulator - whether this is the BrightScript simulator
  ' @return {integer} a `BGE.RenderQualityLevel` value
  function seedRenderQualityLevel(model as string, graphicsPlatform as string, uiResolutionName as string, isSimulator as boolean) as integer
    if isSimulator
      return RenderQualityLevel.medium
    end if
    if "directfb" = LCase(graphicsPlatform)
      return RenderQualityLevel.basic
    end if

    level = lookUpRenderQualityModel(getRenderQualityModelPrefix(model))
    if level < 0
      level = RenderQualityLevel.medium
    end if

    if ("HD" = uiResolutionName or "SD" = uiResolutionName) and level > RenderQualityLevel.low
      level = RenderQualityLevel.low
    end if
    return level
  end function

  ' Reads this device's model, graphics platform and resolution and returns its
  ' starting quality level. `Game` calls this for you.
  '
  ' @return {integer} a `BGE.RenderQualityLevel` value
  function seedRenderQualityLevelForDevice() as integer
    device = CreateObject("roDeviceInfo")
    return seedRenderQualityLevel(device.GetModel(), device.GetGraphicsPlatform(), device.GetUIResolution().name, device.HasFeature("simulation_engine"))
  end function

  ' Known model prefixes -> level, from developer.roku.com/dev/docs/hardware
  ' ("Current" and "Updatable" models). Add or correct entries as real benchmark
  ' data comes in.
  '
  ' @return {roAssociativeArray}
  function getRenderQualityModelTable() as roAssociativeArray
    basic = RenderQualityLevel.basic
    low = RenderQualityLevel.low
    medium = RenderQualityLevel.medium
    high = RenderQualityLevel.high
    ultra = RenderQualityLevel.ultra
    return {
      ' Streaming players (numeric codes)
      "3600": basic, "3700": basic, "3710": basic, "4200": basic, "4210": basic, "4230": basic
      "3800": low, "3840": low, "3900": low, "3910": low, "3930": low, "3931": low, "3960": low
      "3810": medium, "3811": medium, "3920": medium, "3921": medium, "4620": medium, "4630": medium, "4640": medium, "4660": medium, "4662": medium, "9100": medium, "9102": medium
      "3820": high, "3821": high, "3830": high, "3940": high, "3941": high, "3942": high, "4670": high, "9104": high
      "4800": ultra, "4850": ultra
      ' Roku TVs (letter codes)
      "5000": basic
      "8000": low, "D000": low, "H000": low, "K000": low, "K8P": low, "T100": low
      "7000": medium, "C000": medium, "G000": medium, "L000": medium, "P000": medium
      "6000": high, "A000": high
      "J000": ultra, "M000": ultra
    }
  end function

  ' Table lookup with inference for unknown codes; -1 when nothing fits.
  function lookUpRenderQualityModel(prefix as string) as integer
    if Len(prefix) = 0
      return -1
    end if
    table = getRenderQualityModelTable()
    if table.DoesExist(prefix)
      return table[prefix]
    end if

    isNumericPlayer = isRenderQualityNumericCode(prefix)
    isTvCode = isRenderQualityTvCode(prefix)
    bestKey = ""
    for each key in table
      ' AA iteration may not preserve key case
      ukey = UCase(key)
      if isNumericPlayer and isRenderQualityNumericCode(ukey)
        ' same family (first digit), numerically at or below, nearest wins
        if Left(ukey, 1) = Left(prefix, 1) and Val(ukey) <= Val(prefix)
          if bestKey = "" or Val(ukey) > Val(bestKey)
            bestKey = ukey
          end if
        end if
      else if isTvCode and isRenderQualityTvCode(ukey)
        ' TV letter codes: nearest code at or before this one alphabetically
        if ukey <= prefix
          if bestKey = "" or ukey > bestKey
            bestKey = ukey
          end if
        end if
      end if
    end for
    if bestKey = ""
      return -1
    end if
    return table[bestKey]
  end function

  ' "4850", "3941": four digits
  function isRenderQualityNumericCode(code as string) as boolean
    if Len(code) <> 4
      return false
    end if
    for i = 1 to 4
      if Instr(1, "0123456789", Mid(code, i, 1)) = 0
        return false
      end if
    end for
    return true
  end function

  ' "M000", "K8P": a letter followed by a digit
  function isRenderQualityTvCode(code as string) as boolean
    if Len(code) < 3
      return false
    end if
    return Instr(1, "0123456789", Left(code, 1)) = 0 and Instr(1, "0123456789", Mid(code, 2, 1)) > 0
  end function

end namespace
```

Note: `table` keys like `"5000"`/`"6000"`/`"7000"`/`"8000"` are TV models with numeric codes. They're in the numeric-player family search too (families 5-8), which is fine: an unknown `8100` would inherit `8000` (low). `"1000X"` has no family entry and `"zzz"` is neither a numeric nor a TV code, so both return -1 → Medium. Roku AA keys are case-insensitive; the prefix is upper-cased, so that's harmless.

- [ ] **Step 4: Run to verify pass**

Run: `npm run check`
Expected: PASS. If a lookup test fails, print `getRenderQualityModelPrefix(...)` for that input first - the prefix rule is the most likely culprit.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/quality/DeviceQualitySeed.bs src/source/engine/quality/DeviceQualitySeed.spec.bs
git commit -m "Seed render quality level from device model

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Effective draw distance on the camera

**Files:**
- Modify: `src/source/engine/renderer/cameras/Camera.bs` (new fields)
- Modify: `src/source/engine/renderer/cameras/Camera3d.bs:107-127` (field docs), `:218` (`isInView`), `:599-633` (cap + dirty check)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs:140-143, 191, 348, 377, 391, 451`
- Modify: `src/source/engine/renderer/cameras/Camera3d.spec.bs:268-295`

**Interfaces:**
- Produces:
  - `Camera.drawDistanceScale as float = 1.0`, `Camera.drawDistanceOverride as float = 0.0` (base class, ignored by `Camera2d`)
  - `function Camera3d.getEffectiveMaxDrawDistance() as float`

- [ ] **Step 1: Write the failing tests**

In `Camera3d.spec.bs`, replace the whole `@describe("maxDrawDistance device cap")` block (lines 268-295) with:

```brighterscript
    @describe("effective draw distance")

    ' brs-cli reports as the simulator, so the device cap here is 900.
    @it("equals maxDrawDistance at the default scale")
    function _()
      m.camera.maxDrawDistance = 500
      m.assertEqual(500.0, m.camera.getEffectiveMaxDrawDistance())
    end function

    @it("applies drawDistanceScale")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceScale = 0.4
      m.assertEqual(200.0, m.camera.getEffectiveMaxDrawDistance())
    end function

    @it("uses drawDistanceOverride when it is positive")
    function _()
      m.camera.maxDrawDistance = 500
      m.camera.drawDistanceScale = 2.0
      m.camera.drawDistanceOverride = 123
      m.assertEqual(123.0, m.camera.getEffectiveMaxDrawDistance())
    end function

    @it("clamps the result to the device cap")
    function _()
      m.camera.maxDrawDistance = 800
      m.camera.drawDistanceScale = 2.0
      m.assertEqual(900.0, m.camera.getEffectiveMaxDrawDistance())
    end function

    @it("no longer rewrites maxDrawDistance itself")
    function _()
      m.camera.maxDrawDistance = 5000
      m.camera.checkMovement()
      ' plain field assignment may keep the Integer type - compare by value
      m.assertTrue(m.camera.maxDrawDistance = 5000)
    end function

    @it("still culls beyond the device cap when maxDrawDistance is set above it")
    function _()
      m.camera.position = BGE.Math.VectorOps.create(0, 0, 0)
      m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, -1))
      m.camera.maxDrawDistance = 5000
      m.camera.checkMovement()
      m.assertTrue(m.camera.isInView(BGE.Math.VectorOps.create(0, 0, -850)))
      m.assertFalse(m.camera.isInView(BGE.Math.VectorOps.create(0, 0, -950)))
    end function

    @it("bumps projectionVersion when drawDistanceScale changes")
    function _()
      m.camera.checkMovement()
      before = m.camera.projectionVersion
      m.camera.drawDistanceScale = 0.5
      m.camera.checkMovement()
      m.assertNotEqual(before, m.camera.projectionVersion)
    end function
```

(Check how the existing `bumps projectionVersion when maxDrawDistance changes` test at line ~131 reads the version and copy its exact accessor if it isn't a `projectionVersion` field. Check the existing `isInView with maxDrawDistance` tests at ~107 for how they set the camera up and match that too.)

- [ ] **Step 2: Run to verify failure**

Run: `npm run test:ci`
Expected: FAIL - `getEffectiveMaxDrawDistance`/`drawDistanceScale` don't exist.

- [ ] **Step 3: Implement**

In `Camera.bs`, inside `class Camera` next to the other public fields:

```brighterscript
    ' Multiplier on a 3D camera's maxDrawDistance, set from the renderer's quality
    ' settings every frame - see `BGE.RenderQualitySettings`. Ignored by Camera2d.
    drawDistanceScale as float = 1.0

    ' Absolute draw distance from the renderer's quality settings; 0 or less means
    ' "use drawDistanceScale". Ignored by Camera2d.
    drawDistanceOverride as float = 0.0
```

In `Camera3d.bs`:

1. Replace the `maxDrawDistance` doc comment (lines 107-113) with:

```brighterscript
    ' How far (world units) in front of the camera your game wants to draw. The
    ' distance actually used is `getEffectiveMaxDrawDistance()`: this value scaled by
    ' the current render quality level and capped per device.
    maxDrawDistance as float = 1000
```

2. Rename `lastMaxDrawDistance` to `lastEffectiveMaxDrawDistance` (initial value `-1`) and update its comment to "Last effective draw distance seen by projectionChangedThisFrame()".

3. Add after `getMaxDrawDistanceDeviceCap()`:

```brighterscript
    ' The draw distance the renderer actually uses: `drawDistanceOverride` if set,
    ' otherwise `maxDrawDistance * drawDistanceScale`, then capped for this device.
    '
    ' @return {float}
    function getEffectiveMaxDrawDistance() as float
      distance = m.maxDrawDistance * m.drawDistanceScale
      if m.drawDistanceOverride > 0
        distance = m.drawDistanceOverride * 1.0
      end if
      deviceCap = m.getMaxDrawDistanceDeviceCap()
      if distance > deviceCap
        distance = deviceCap * 1.0
      end if
      return distance
    end function
```

4. In `projectionChangedThisFrame()`, replace the clamp + dirty-check block (the lines from `' Clamp before the dirty-check` through the `lastMaxDrawDistance` check) with:

```brighterscript
      effective = m.getEffectiveMaxDrawDistance()
      if m.lastEffectiveMaxDrawDistance <> effective
        m.lastEffectiveMaxDrawDistance = effective
        changed = true
      end if
```

5. In `isInView` (line 218): `return forwardDistance <= m.getEffectiveMaxDrawDistance()`.

6. Update `getMaxDrawDistanceDeviceCap()`'s doc comment wording from "maxDrawDistance" being clamped to "the effective draw distance", keeping the hardware findings as they are.

In `SceneObjectPlane.bs`, replace every read of `camera.maxDrawDistance` / `(camera as Camera3d).maxDrawDistance` (lines 140, 191, 348, 377, 391, 451) with `.getEffectiveMaxDrawDistance()` on the same camera expression. Leave the `...BuiltForMaxDrawDistance` field names alone (they now cache the effective value, which is what they're compared against).

Also check the rest of the engine: `grep -rn "\.maxDrawDistance" src/source --include=*.bs | grep -v spec.bs` must show only the `Camera3d` field declaration and `getEffectiveMaxDrawDistance()`'s own read. Fix any other reader the same way.

- [ ] **Step 4: Run to verify pass**

Run: `npm run check`
Expected: PASS, including the existing `SceneObjectPlane.spec.bs` and `SceneObjectImage.spec.bs` tests (effective == set value at scale 1.0 below the cap, so they're unaffected).

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/renderer
git commit -m "Apply draw-distance scale and device cap via getEffectiveMaxDrawDistance

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Renderer reads quality settings

**Files:**
- Modify: `src/source/engine/renderer/Renderer.bs:23-26` (constants), `:119` (fields), `:576-583` (`setupCameraForFrame`), `:2060-2078` (`drawQuickTriangleTo`)
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectPlane.bs:30, 157`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectBillboard.bs:61, 144, 181`
- Create: `src/source/engine/renderer/RendererQuality.spec.bs`
- Modify: `src/source/engine/renderer/sceneObjects/SceneObjectCircle.spec.bs` (tolerance test)

**Interfaces:**
- Consumes: `BGE.getRenderQualityPreset`, `BGE.RenderQualitySettings` (Task 1); `Camera.drawDistanceScale/drawDistanceOverride`, `Camera3d.getEffectiveMaxDrawDistance()` (Task 3)
- Produces:
  - `Renderer.qualitySettings as BGE.RenderQualitySettings` (defaults to Medium)
  - `sub Renderer.setQualitySettings(settings as BGE.RenderQualitySettings)`
  - `function Renderer.getTriangleQuickDrawParams() as object` → `{skipSize as float, threshold as float, step as integer}` (after the simulator adjustment)

- [ ] **Step 1: Write the failing renderer tests**

Create `src/source/engine/renderer/RendererQuality.spec.bs`:

```brighterscript
namespace tests

  ' brs-cli reports as the simulator, so the simulator triangle adjustment
  ' (threshold <= 32, step >= 4) is always in effect here.
  @suite("BGE.Renderer quality settings")
  class RendererQualityTests extends rooibos.BaseTestSuite

    renderer as BGE.Renderer

    protected override function beforeEach()
      m.renderer = new BGE.Renderer(CreateObject("roBitmap", {width: 320, height: 240, alphaEnable: true}))
    end function

    @it("defaults to the Medium preset")
    function _()
      m.assertEqual(36, m.renderer.qualitySettings.planeSliceCount)
      m.assertEqual(1.0, m.renderer.qualitySettings.drawDistanceScale)
    end function

    @it("applies the simulator adjustment on top of the preset")
    function _()
      m.renderer.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.medium))
      params = m.renderer.getTriangleQuickDrawParams()
      m.assertEqual(4.0, params.skipSize)
      m.assertEqual(32.0, params.threshold)
      m.assertEqual(4, params.step)
    end function

    @it("reads the skip size from the settings")
    function _()
      m.renderer.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.basic))
      m.assertEqual(8.0, m.renderer.getTriangleQuickDrawParams().skipSize)
    end function

    @it("pushes the draw-distance scale onto the camera each frame")
    function _()
      cam = new BGE.Camera3d()
      cam.maxDrawDistance = 500
      m.renderer.camera = cam
      m.renderer.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.basic))
      m.renderer.setupCameraForFrame()
      m.assertEqual(200.0, cam.getEffectiveMaxDrawDistance())
    end function

    @it("applies the scale to a camera swapped in after the settings were set")
    function _()
      m.renderer.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.low))
      cam = new BGE.Camera3d()
      cam.maxDrawDistance = 500
      m.renderer.camera = cam
      m.renderer.setupCameraForFrame()
      m.assertEqual(300.0, cam.getEffectiveMaxDrawDistance())
    end function

    @it("pushes the draw-distance override")
    function _()
      cam = new BGE.Camera3d()
      m.renderer.camera = cam
      settings = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.medium)
      settings.drawDistanceOverride = 75
      m.renderer.setQualitySettings(settings)
      m.renderer.setupCameraForFrame()
      m.assertEqual(75.0, cam.getEffectiveMaxDrawDistance())
    end function

  end class

end namespace
```

In `SceneObjectCircle.spec.bs`, add after the "falls back to the exact drawPinnedCorners path" test (reuse the suite's existing `m.entity3d`, `m.renderer3d`, `m.drawOnce3d()`):

```brighterscript
    @it("takes the fast path for a slight tilt at Basic but not at Ultra")
    function _()
      ' A slight tilt about x: skewed enough to fail Ultra's tight tolerances (today's
      ' values), within Basic's looser ones.
      m.entity3d.position = BGE.Math.VectorOps.create(0, 0, 700)
      args = {drawMode: BGE.SceneObjectDrawMode.orientedDrawBackFace, rotation: BGE.Math.VectorOps.create(0.15, 0, 0)}

      m.renderer3d.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.ultra))
      ultraCircle = new BGE.DrawableCircle(m.entity3d, 60, args)
      m.assertFalse(m.drawOnce3d(ultraCircle).usedTransformedFastDraw())

      m.renderer3d.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.basic))
      basicCircle = new BGE.DrawableCircle(m.entity3d, 60, args)
      m.assertTrue(m.drawOnce3d(basicCircle).usedTransformedFastDraw())
    end function
```

The tilt angle `0.15` is a starting point. If the test fails for the wrong reason (both true or both false), print `m.drawOnce3d(...)`'s canvas points and adjust the angle until the quad's skew sits between 0.03 and 0.10 - don't change the tolerances. Check `drawOnce3d` removes/isolates each drawable; if it doesn't, remove `ultraCircle`'s scene object before drawing the second.

- [ ] **Step 2: Run to verify failure**

Run: `npm run test:ci`
Expected: FAIL - `qualitySettings`/`setQualitySettings` don't exist.

- [ ] **Step 3: Implement in Renderer**

In `Renderer.bs`:

1. Add `import "../quality/RenderQualityPresets.bs"` and `import "../quality/RenderQualitySettings.bs"` (the `RenderQualityLevel.bs` import from Task 1 stays).
2. Delete the constants `TriangleDrawThreshold`, `TriangleQuickDrawThreshold`, `TriangleQuickDrawThresholdForSimulator` (lines 24-26). `grep -rn "TriangleDrawThreshold\|TriangleQuickDrawThreshold" src examples` first - update any other reference to use `getTriangleQuickDrawParams()`.
3. Add fields after `private isSimulator as boolean = false`:

```brighterscript
    ' The draw-quality values this renderer uses. `Game` sets these from the current
    ' render quality level; a Renderer used without a Game starts at Medium.
    qualitySettings as BGE.RenderQualitySettings = BGE.getRenderQualityPreset(BGE.RenderQualityLevel.medium)
```

If bsc rejects a function call as a field initializer, declare `qualitySettings as BGE.RenderQualitySettings` and assign it as the first line of `sub new(...)`.

4. Add public methods near `setCamera`:

```brighterscript
    ' Replaces this renderer's draw-quality values. Takes effect from the next draw.
    '
    ' @param {BGE.RenderQualitySettings} settings - e.g. `BGE.getRenderQualityPreset(BGE.RenderQualityLevel.high)`
    sub setQualitySettings(settings as BGE.RenderQualitySettings)
      m.qualitySettings = settings
    end sub

    ' The triangle line-fill parameters in effect, after the simulator adjustment.
    '
    ' @return {object} {skipSize, threshold, step}
    function getTriangleQuickDrawParams() as object
      threshold = m.qualitySettings.triangleQuickDrawThreshold
      step = m.qualitySettings.triangleQuickDrawStep
      if m.isSimulator
        ' line drawing is comparatively slow on the simulator
        threshold = BGE.Math.Min(threshold, 32.0)
        step = BGE.Math.Max(step, 4)
      end if
      return {skipSize: m.qualitySettings.triangleSkipSize, threshold: threshold, step: step}
    end function
```

Check `BGE.Math.Min`/`Max` return types: if `Max(step, 4)` returns a Float, wrap it in `cint(...)` so `step` stays an Integer (the test asserts Integer `4`).

5. In `setupCameraForFrame()`, as the first two lines:

```brighterscript
      ' pushed every frame so a camera assigned directly (renderer.camera = cam) picks them up
      m.camera.drawDistanceScale = m.qualitySettings.drawDistanceScale
      m.camera.drawDistanceOverride = m.qualitySettings.drawDistanceOverride
```

6. Rewrite `drawQuickTriangleTo`'s threshold section:

```brighterscript
      params = m.getTriangleQuickDrawParams()
      triangleSize = BGE.Math.VectorOps.subtract(bounds[1], bounds[0])
      if triangleSize.x < params.skipSize and triangleSize.y < params.skipSize
        return true
      end if

      if (triangleSize.x < params.threshold) or (triangleSize.y < params.threshold)
        return m.drawTriangleAsRaysTo(canvasDrawTo, points, x, y, rgba, {levelOffset: 0, levelOfDetail: params.step})
      end if
      return false
```

- [ ] **Step 4: Implement in SceneObjectPlane and SceneObjectBillboard**

`SceneObjectPlane.bs`: delete `const SCENE_OBJECT_PLANE_SLICE_COUNT = 50` (line 30) and at line 157 pass `rendererObj.qualitySettings.planeSliceCount` instead. `grep -rn SCENE_OBJECT_PLANE_SLICE_COUNT src` must return nothing afterwards.

`SceneObjectBillboard.bs`:

1. Add a field near `usedTransformedFastDrawLastFrame`:

```brighterscript
    ' Fast-draw tolerances from the renderer drawing this object, captured at draw time
    ' because canUseTransformedFastDraw() has no renderer parameter.
    private fastDrawParallelogramTolerance as float = 0.03
    private fastDrawPerpendicularityTolerance as float = 0.05
```

2. Add a private helper and call it as the first line of both `performDraw(rendererObj, drawMode)` (line 61) and `isRedrawToCanvasRequired(rendererObj, drawMode)` (line 144 - convert its single `return` into `m.captureFastDrawTolerances(rendererObj)` then `return ...`):

```brighterscript
    private sub captureFastDrawTolerances(rendererObj as BGE.Renderer)
      m.fastDrawParallelogramTolerance = rendererObj.qualitySettings.fastDrawParallelogramTolerance
      m.fastDrawPerpendicularityTolerance = rendererObj.qualitySettings.fastDrawPerpendicularityTolerance
    end sub
```

3. `canUseTransformedFastDraw()` (line 181):

```brighterscript
      return m.canvasPoints.isApproximatelyRotatedRectangle(m.fastDrawParallelogramTolerance, m.fastDrawPerpendicularityTolerance)
```

Check whether any subclass overrides `performDraw` or `isRedrawToCanvasRequired` without calling `super` (`grep -n "override function performDraw\|override function isRedrawToCanvasRequired" src/source/engine/renderer/sceneObjects/*.bs`); add the same capture call there if so.

- [ ] **Step 5: Run to verify pass**

Run: `npm run check`
Expected: PASS - including every existing `SceneObjectPlane`/`Triangle`/`SceneObjectCircle` spec.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/renderer
git commit -m "Read draw-quality knobs from Renderer.qualitySettings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Adaptive quality controller

**Files:**
- Create: `src/source/engine/quality/QualityController.bs`
- Create: `src/source/engine/quality/QualityController.spec.bs`

**Interfaces:**
- Consumes: `BGE.RenderQualityLevel` (Task 1)
- Produces:
  - `interface BGE.AdaptiveQualityOptions` (all fields optional; names and defaults in Global Constraints)
  - `class BGE.QualityController`: `sub new(options = {} as roAssociativeArray)`, `function update(dt as float, currentLevel as integer) as integer`, `sub notifyLevelChanged()`, `sub notifySceneChanged()`, public fields `targetFps`, `minLevel`, `maxLevel`

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/quality/QualityController.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.QualityController")
  class QualityControllerTests extends rooibos.BaseTestSuite

    ' Feeds `seconds` worth of frames at `fps` and returns the level after each change,
    ' calling notifyLevelChanged() like RenderQualityManager does.
    private function run(controller as BGE.QualityController, level as integer, fps as float, seconds as float) as integer
      dt = 1.0 / fps
      frames = cint(seconds * fps)
      for i = 1 to frames
        newLevel = controller.update(dt, level)
        if newLevel <> level
          level = newLevel
          controller.notifyLevelChanged()
        end if
      end for
      return level
    end function

    @describe("stepping down")

    @it("steps down when well below target")
    function _()
      c = new BGE.QualityController()
      m.assertEqual(BGE.RenderQualityLevel.medium, m.run(c, BGE.RenderQualityLevel.high, 20, 1.5))
    end function

    @it("waits the cooldown before stepping down again")
    function _()
      c = new BGE.QualityController()
      ' first step at 1.0s (half window); the average is low again by 2.5s (0.5s settle +
      ' 1.0s half window) but the 2s cooldown blocks a second step until 3.0s
      m.assertEqual(BGE.RenderQualityLevel.high, m.run(c, BGE.RenderQualityLevel.ultra, 20, 2.8))
    end function

    @it("never goes below minLevel")
    function _()
      c = new BGE.QualityController({minLevel: BGE.RenderQualityLevel.low})
      m.assertEqual(BGE.RenderQualityLevel.low, m.run(c, BGE.RenderQualityLevel.medium, 10, 30))
    end function

    @describe("dead zone")

    @it("holds when at target")
    function _()
      c = new BGE.QualityController()
      m.assertEqual(BGE.RenderQualityLevel.medium, m.run(c, BGE.RenderQualityLevel.medium, 30, 20))
    end function

    @describe("stepping up")

    @it("steps up only after sustained headroom")
    function _()
      c = new BGE.QualityController()
      m.assertEqual(BGE.RenderQualityLevel.medium, m.run(c, BGE.RenderQualityLevel.medium, 60, 4))
      m.assertEqual(BGE.RenderQualityLevel.high, m.run(c, BGE.RenderQualityLevel.medium, 60, 3))
    end function

    @it("never goes above maxLevel")
    function _()
      c = new BGE.QualityController({maxLevel: BGE.RenderQualityLevel.high})
      m.assertEqual(BGE.RenderQualityLevel.high, m.run(c, BGE.RenderQualityLevel.medium, 60, 60))
    end function

    @it("probes up at a 60fps target when holding 60fps")
    function _()
      c = new BGE.QualityController({targetFps: 60})
      m.assertEqual(BGE.RenderQualityLevel.high, m.run(c, BGE.RenderQualityLevel.medium, 60, 7))
    end function

    @describe("ignored frames")

    @it("ignores a single huge frame")
    function _()
      c = new BGE.QualityController()
      level = m.run(c, BGE.RenderQualityLevel.medium, 30, 3)
      level = c.update(1.5, level)
      level = m.run(c, level, 30, 1)
      m.assertEqual(BGE.RenderQualityLevel.medium, level)
    end function

    @it("ignores slow frames during the settle period after a scene change")
    function _()
      c = new BGE.QualityController()
      level = m.run(c, BGE.RenderQualityLevel.medium, 30, 3)
      c.notifySceneChanged()
      ' 0.4s of 10fps inside the 0.5s settle, then back to target
      level = m.run(c, level, 10, 0.4)
      level = m.run(c, level, 30, 2)
      m.assertEqual(BGE.RenderQualityLevel.medium, level)
    end function

    @describe("probe backoff")

    @it("doesn't retry a level that just failed")
    function _()
      c = new BGE.QualityController()
      ' headroom -> probe medium->high
      level = m.run(c, BGE.RenderQualityLevel.medium, 60, 7)
      m.assertEqual(BGE.RenderQualityLevel.high, level)
      ' high is too slow -> back to medium within the fail window (the 2s window still
      ' holds some 60fps frames, so the average crosses 27fps ~1.7s in)
      level = m.run(c, level, 20, 2.0)
      m.assertEqual(BGE.RenderQualityLevel.medium, level)
      ' plenty of headroom again, but high is in a 30s backoff
      level = m.run(c, level, 60, 15)
      m.assertEqual(BGE.RenderQualityLevel.medium, level)
      ' after the backoff it probes again
      level = m.run(c, level, 60, 25)
      m.assertEqual(BGE.RenderQualityLevel.high, level)
    end function

  end class

end namespace
```

If Rooibos rejects a `private function` helper in a suite, make it a plain (public) function without `@it`.

- [ ] **Step 2: Run to verify failure**

Run: `npm run test:ci`
Expected: FAIL - `BGE.QualityController` not found.

- [ ] **Step 3: Implement**

Create `src/source/engine/quality/QualityController.bs`:

```brighterscript
import "RenderQualityLevel.bs"

namespace BGE

  ' Options for `Game.enableAdaptiveQuality()`. Every field is optional.
  interface AdaptiveQualityOptions
    ' Frame rate to hold (default 30)
    targetFps as float
    ' Lowest level the controller may choose (default basic)
    minLevel as integer
    ' Highest level the controller may choose (default ultra)
    maxLevel as integer
    ' Seconds of frames averaged (default 2.0)
    windowSeconds as float
    ' Frames longer than this are ignored, e.g. garbage collection (default 0.25)
    outlierFrameSeconds as float
    ' Seconds ignored after a level or scene change (default 0.5)
    settleSeconds as float
    ' Step down when average fps < targetFps * this (default 0.9)
    stepDownBelowFraction as float
    ' Step up when average fps >= targetFps * this... (default 1.25)
    stepUpHeadroomFraction as float
    ' ...for this many seconds (default 5.0)
    stepUpSustainSeconds as float
    ' Display refresh ceiling for the step-up threshold (default 60)
    maxMeasurableFps as float
    ' Minimum seconds between two downward steps (default 2.0)
    stepDownCooldownSeconds as float
    ' A step down this soon after a step up marks that level as failed (default 4.0)
    probeFailWindowSeconds as float
    ' Seconds a failed level isn't retried; doubles on each repeat failure (default 30)
    probeBackoffSeconds as float
  end interface

  ' Chooses a render quality level from measured frame times. `Game` runs one for
  ' you after `enableAdaptiveQuality()`; you don't normally create one yourself.
  class QualityController

    targetFps as float = 30
    minLevel as integer = RenderQualityLevel.basic
    maxLevel as integer = RenderQualityLevel.ultra
    windowSeconds as float = 2.0
    outlierFrameSeconds as float = 0.25
    settleSeconds as float = 0.5
    stepDownBelowFraction as float = 0.9
    stepUpHeadroomFraction as float = 1.25
    stepUpSustainSeconds as float = 5.0
    maxMeasurableFps as float = 60
    stepDownCooldownSeconds as float = 2.0
    probeFailWindowSeconds as float = 4.0
    probeBackoffSeconds as float = 30

    private samples as float[] = []
    private sampleTime as float = 0
    private settleRemaining as float = 0
    private headroomTime as float = 0
    private clock as float = 0
    private timeSinceStepDown as float = 1000
    private timeSinceStepUp as float = 1000
    private lastProbeLevel as integer = -1
    ' level (as string) -> clock time it may be retried / its current backoff length
    private backoffUntil as roAssociativeArray = {}
    private backoffLength as roAssociativeArray = {}

    ' @param {BGE.AdaptiveQualityOptions} [options={}] - any subset of the options
    sub new(options = {} as roAssociativeArray)
      for each key in options
        if m.DoesExist(key) and "samples" <> key
          m[key] = options[key]
        end if
      end for
    end sub

    ' Feed one frame's duration; returns the level to use (currentLevel if no change).
    '
    ' @param {float} dt - full frame time in seconds, including the buffer swap
    ' @param {integer} currentLevel - the level currently applied
    ' @return {integer}
    function update(dt as float, currentLevel as integer) as integer
      m.clock += dt
      m.timeSinceStepDown += dt
      m.timeSinceStepUp += dt

      if m.settleRemaining > 0
        m.settleRemaining -= dt
        return currentLevel
      end if
      if dt > m.outlierFrameSeconds or dt <= 0
        return currentLevel
      end if

      m.samples.push(dt)
      m.sampleTime += dt
      while m.sampleTime > m.windowSeconds and m.samples.count() > 1
        m.sampleTime -= m.samples.shift()
      end while
      ' need at least half a window before trusting the average
      if m.sampleTime < m.windowSeconds * 0.5
        return currentLevel
      end if

      avgFps = m.samples.count() / m.sampleTime
      upThreshold = BGE.Math.Min(m.targetFps * m.stepUpHeadroomFraction, m.maxMeasurableFps * 0.97)

      if avgFps < m.targetFps * m.stepDownBelowFraction
        m.headroomTime = 0
        if currentLevel > m.minLevel and m.timeSinceStepDown >= m.stepDownCooldownSeconds
          if currentLevel = m.lastProbeLevel and m.timeSinceStepUp <= m.probeFailWindowSeconds
            m.markProbeFailed(currentLevel)
          end if
          m.timeSinceStepDown = 0
          return currentLevel - 1
        end if
      else if avgFps >= upThreshold
        m.headroomTime += dt
        if m.headroomTime >= m.stepUpSustainSeconds and currentLevel < m.maxLevel and not m.isInBackoff(currentLevel + 1)
          m.headroomTime = 0
          m.timeSinceStepUp = 0
          m.lastProbeLevel = currentLevel + 1
          return currentLevel + 1
        end if
      else
        m.headroomTime = 0
      end if
      return currentLevel
    end function

    ' Call after a new level has been applied: clears the average and waits out the
    ' settle period so one-off rebuild costs don't count against the new level.
    sub notifyLevelChanged()
      m.resetWindow()
    end sub

    ' Call after a scene change, for the same reason as notifyLevelChanged().
    sub notifySceneChanged()
      m.resetWindow()
    end sub

    private sub resetWindow()
      m.samples = []
      m.sampleTime = 0
      m.headroomTime = 0
      m.settleRemaining = m.settleSeconds
    end sub

    private function isInBackoff(level as integer) as boolean
      key = level.toStr()
      return m.backoffUntil.DoesExist(key) and m.clock < m.backoffUntil[key]
    end function

    private sub markProbeFailed(level as integer)
      key = level.toStr()
      length = m.probeBackoffSeconds
      if m.backoffLength.DoesExist(key)
        length = m.backoffLength[key] * 2
      end if
      m.backoffLength[key] = length
      m.backoffUntil[key] = m.clock + length
    end sub

  end class

end namespace
```

Add `import "../../math/math.bs"` if `BGE.Math.Min` isn't otherwise visible (check the path from `engine/quality/` to `src/source/math/math.bs`: it's `../../math/math.bs`).

- [ ] **Step 4: Run to verify pass**

Run: `npm run check`
Expected: PASS. If a timing test is off by one step, work it through by hand against the constants before changing either the test or the code - the tests encode the spec's timings (2s window, half-window warm-up, 0.5s settle, 2s cooldown, 5s sustain, 4s fail window, 30s backoff), so fix whichever side actually disagrees with them.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/quality/QualityController.bs src/source/engine/quality/QualityController.spec.bs
git commit -m "Add adaptive render quality controller

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: RenderQualityManager and Game integration

**Files:**
- Create: `src/source/engine/quality/RenderQualityManager.bs`
- Create: `src/source/engine/quality/RenderQualityManager.spec.bs`
- Create: `src/source/engine/GameQuality.spec.bs`
- Modify: `src/source/engine/Game.bs` (imports; field; constructor ~line 189; `Play()` after `onSwapBuffers` ~line 498; `handleSceneChange()` after `onCreate` ~line 2048; new public methods next to `postGameEvent` ~line 2458)
- Modify: `src/source/engine/GameEntity.bs` (hook next to `onGameEvent`, ~line 317)
- Modify: `src/source/engine/debug/FpsDisplay.bs`

**Interfaces:**
- Consumes: Tasks 1, 2, 4, 5.
- Produces:
  - `class BGE.RenderQualityManager`: `sub new(renderer as BGE.Renderer, initialLevel as integer)`, `function getLevel() as integer`, `function setLevel(level as integer) as boolean` (true if it changed), `sub overridePreset(level as integer, overrides as roAssociativeArray)`, `function getSettings(level as integer) as BGE.RenderQualitySettings`, `sub enableAdaptive(options = {} as roAssociativeArray)`, `sub disableAdaptive()`, `function isAdaptive() as boolean`, `function update(dt as float) as boolean` (true if the level changed), `sub notifySceneChanged()`
  - `Game.renderQuality as BGE.RenderQualityManager`
  - `sub Game.setQualityLevel(level as integer)`, `sub Game.enableAdaptiveQuality(options = {} as roAssociativeArray)`, `sub Game.disableAdaptiveQuality()`
  - `sub GameEntity.onQualityChanged(level as integer)`

- [ ] **Step 1: Write the failing manager tests**

Create `src/source/engine/quality/RenderQualityManager.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.RenderQualityManager")
  class RenderQualityManagerTests extends rooibos.BaseTestSuite

    renderer as BGE.Renderer
    manager as BGE.RenderQualityManager

    protected override function beforeEach()
      m.renderer = new BGE.Renderer(CreateObject("roBitmap", {width: 64, height: 64, alphaEnable: true}))
      m.manager = new BGE.RenderQualityManager(m.renderer, BGE.RenderQualityLevel.high)
    end function

    @it("applies the initial level's preset to the renderer")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.high, m.manager.getLevel())
      m.assertEqual(44, m.renderer.qualitySettings.planeSliceCount)
    end function

    @it("setLevel applies the new preset and reports a change")
    function _()
      m.assertTrue(m.manager.setLevel(BGE.RenderQualityLevel.basic))
      m.assertEqual(20, m.renderer.qualitySettings.planeSliceCount)
      m.assertFalse(m.manager.setLevel(BGE.RenderQualityLevel.basic))
    end function

    @it("setLevel clamps out-of-range levels")
    function _()
      m.manager.setLevel(42)
      m.assertEqual(BGE.RenderQualityLevel.ultra, m.manager.getLevel())
    end function

    @it("overridePreset changes only that level's named fields")
    function _()
      m.manager.overridePreset(BGE.RenderQualityLevel.low, {planeSliceCount: 99})
      m.assertEqual(99, m.manager.getSettings(BGE.RenderQualityLevel.low).planeSliceCount)
      m.assertEqual(0.6, m.manager.getSettings(BGE.RenderQualityLevel.low).drawDistanceScale)
      m.assertEqual(36, m.manager.getSettings(BGE.RenderQualityLevel.medium).planeSliceCount)
    end function

    @it("overridePreset on the active level takes effect immediately")
    function _()
      m.manager.overridePreset(BGE.RenderQualityLevel.high, {planeSliceCount: 60})
      m.assertEqual(60, m.renderer.qualitySettings.planeSliceCount)
    end function

    @it("overrides accumulate across calls")
    function _()
      m.manager.overridePreset(BGE.RenderQualityLevel.low, {planeSliceCount: 99})
      m.manager.overridePreset(BGE.RenderQualityLevel.low, {drawDistanceScale: 0.5})
      settings = m.manager.getSettings(BGE.RenderQualityLevel.low)
      m.assertEqual(99, settings.planeSliceCount)
      m.assertEqual(0.5, settings.drawDistanceScale)
    end function

    @it("update does nothing unless adaptive is enabled")
    function _()
      for i = 1 to 90
        m.assertFalse(m.manager.update(0.1))
      end for
      m.assertEqual(BGE.RenderQualityLevel.high, m.manager.getLevel())
    end function

    @it("update moves the level when adaptive is enabled")
    function _()
      m.manager.enableAdaptive()
      m.assertTrue(m.manager.isAdaptive())
      changed = false
      ' 0.5s settle + 1.0s half window at 20fps, with margin for float accumulation
      for i = 1 to 40
        if m.manager.update(0.05)
          changed = true
        end if
      end for
      m.assertTrue(changed)
      m.assertEqual(BGE.RenderQualityLevel.medium, m.manager.getLevel())
      m.assertEqual(36, m.renderer.qualitySettings.planeSliceCount)
    end function

    @it("disableAdaptive stops the controller")
    function _()
      m.manager.enableAdaptive()
      m.manager.disableAdaptive()
      m.assertFalse(m.manager.isAdaptive())
      for i = 1 to 60
        m.manager.update(0.05)
      end for
      m.assertEqual(BGE.RenderQualityLevel.high, m.manager.getLevel())
    end function

  end class

end namespace
```

- [ ] **Step 2: Write the failing Game tests**

Create `src/source/engine/GameQuality.spec.bs`:

```brighterscript
namespace tests

  @suite("BGE.Game render quality")
  class GameQualityTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @it("seeds the level from the device (Medium under brs-cli)")
    function _()
      m.assertEqual(BGE.RenderQualityLevel.medium, m.game.renderQuality.getLevel())
      m.assertEqual(36, m.game.canvas.renderer.qualitySettings.planeSliceCount)
    end function

    @it("setQualityLevel applies the level to the game canvas only")
    function _()
      uiSlicesBefore = m.game.uiCanvas.renderer.qualitySettings.planeSliceCount
      m.game.setQualityLevel(BGE.RenderQualityLevel.ultra)
      m.assertEqual(50, m.game.canvas.renderer.qualitySettings.planeSliceCount)
      m.assertEqual(uiSlicesBefore, m.game.uiCanvas.renderer.qualitySettings.planeSliceCount)
    end function

    @it("setQualityLevel turns adaptive tuning off")
    function _()
      m.game.enableAdaptiveQuality()
      m.game.setQualityLevel(BGE.RenderQualityLevel.low)
      m.assertFalse(m.game.renderQuality.isAdaptive())
      m.assertEqual(BGE.RenderQualityLevel.low, m.game.renderQuality.getLevel())
    end function

    @it("notifies entities of a level change")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "Listener"})
      m.game.addEntity(entity)
      listener = entity as dynamic
      listener.seenLevel = -1
      listener.onQualityChanged = sub(level as integer)
        m.seenLevel = level
      end sub
      m.game.setQualityLevel(BGE.RenderQualityLevel.high)
      m.assertEqual(BGE.RenderQualityLevel.high, listener.seenLevel)
    end function

    @it("doesn't notify when the level is unchanged")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "Listener"})
      m.game.addEntity(entity)
      listener = entity as dynamic
      listener.calls = 0
      listener.onQualityChanged = sub(level as integer)
        m.calls = m.calls + 1
      end sub
      m.game.setQualityLevel(BGE.RenderQualityLevel.medium)
      m.assertEqual(0, listener.calls)
    end function

  end class

end namespace
```

If bsc rejects assigning a function literal to a field on a `dynamic`, fall back to a tiny subclass defined in the spec file with an explicit fully-qualified constructor (see memory `project_bsc_subclass_transpile_crash`):

```brighterscript
  class QualityListenerEntity extends BGE.GameEntity
    seenLevel as integer = -1
    calls as integer = 0
    sub new(game as BGE.Game)
      super(game, {name: "Listener"})
    end sub
    override sub onQualityChanged(level as integer)
      m.seenLevel = level
      m.calls = m.calls + 1
    end sub
  end class
```

- [ ] **Step 3: Run to verify failure**

Run: `npm run test:ci`
Expected: FAIL - `RenderQualityManager`/`renderQuality` not found.

- [ ] **Step 4: Implement the manager**

Create `src/source/engine/quality/RenderQualityManager.bs`:

```brighterscript
import "../renderer/Renderer.bs"
import "QualityController.bs"
import "RenderQualityLevel.bs"
import "RenderQualityPresets.bs"
import "RenderQualitySettings.bs"

namespace BGE

  ' Owns the game's current render quality level. Reach it through
  ' `game.renderQuality`; most games only need `Game.setQualityLevel()` or
  ' `Game.enableAdaptiveQuality()`.
  class RenderQualityManager

    private renderer as BGE.Renderer
    private level as integer = RenderQualityLevel.medium
    ' level (as string) -> roAssociativeArray of overridden fields
    private overrides as roAssociativeArray = {}
    private controller as BGE.QualityController = invalid

    ' @param {BGE.Renderer} renderer - the renderer to apply settings to (the game canvas)
    ' @param {integer} initialLevel - a `BGE.RenderQualityLevel` value
    sub new(renderer as BGE.Renderer, initialLevel as integer)
      m.renderer = renderer
      m.level = clampRenderQualityLevel(initialLevel)
      m.applyCurrentLevel()
    end sub

    ' @return {integer} the current `BGE.RenderQualityLevel`
    function getLevel() as integer
      return m.level
    end function

    ' Switches to a level (clamped). Does not change whether adaptive tuning is on -
    ' use `Game.setQualityLevel()` to pin a level.
    '
    ' @param {integer} level - a `BGE.RenderQualityLevel` value
    ' @return {boolean} true if the level changed
    function setLevel(level as integer) as boolean
      level = clampRenderQualityLevel(level)
      if level = m.level
        return false
      end if
      m.level = level
      m.applyCurrentLevel()
      if invalid <> m.controller
        m.controller.notifyLevelChanged()
      end if
      return true
    end function

    ' Replaces individual settings for one level, keeping the engine defaults for
    ' everything else. Repeated calls accumulate.
    '
    ' @param {integer} level - a `BGE.RenderQualityLevel` value
    ' @param {roAssociativeArray} fields - e.g. {planeSliceCount: 80, drawDistanceScale: 1.2}
    sub overridePreset(level as integer, fields as roAssociativeArray)
      key = clampRenderQualityLevel(level).toStr()
      existing = m.overrides[key]
      if invalid = existing
        existing = {}
      end if
      for each field in fields
        existing[field] = fields[field]
      end for
      m.overrides[key] = existing
      if clampRenderQualityLevel(level) = m.level
        m.applyCurrentLevel()
      end if
    end sub

    ' The settings a level uses: the engine preset plus any overrides.
    '
    ' @param {integer} level - a `BGE.RenderQualityLevel` value
    ' @return {BGE.RenderQualitySettings}
    function getSettings(level as integer) as BGE.RenderQualitySettings
      level = clampRenderQualityLevel(level)
      return mergeRenderQualitySettings(getRenderQualityPreset(level), m.overrides[level.toStr()])
    end function

    ' Starts adjusting the level automatically to hold a frame rate.
    '
    ' @param {BGE.AdaptiveQualityOptions} [options={}]
    sub enableAdaptive(options = {} as roAssociativeArray)
      controller = new BGE.QualityController(options)
      m.controller = controller
      m.controller.notifyLevelChanged()
    end sub

    sub disableAdaptive()
      m.controller = invalid
    end sub

    ' @return {boolean} whether the level is being adjusted automatically
    function isAdaptive() as boolean
      return invalid <> m.controller
    end function

    ' `Game` calls this once per frame with the full frame time.
    '
    ' @param {float} dt
    ' @return {boolean} true if the level changed this frame
    function update(dt as float) as boolean
      if invalid = m.controller
        return false
      end if
      return m.setLevel(m.controller.update(dt, m.level))
    end function

    ' `Game` calls this after a scene change.
    sub notifySceneChanged()
      if invalid <> m.controller
        m.controller.notifySceneChanged()
      end if
    end sub

    private sub applyCurrentLevel()
      m.renderer.setQualitySettings(m.getSettings(m.level))
    end sub

  end class

end namespace
```

`mergeRenderQualitySettings` already treats `invalid` overrides as "none".

- [ ] **Step 5: Integrate into Game, GameEntity and FpsDisplay**

`GameEntity.bs`, right after `onGameEvent` (line ~318):

```brighterscript
    ' Called when the game's render quality level changes (see `Game.setQualityLevel()`
    ' and `Game.enableAdaptiveQuality()`). Override it to scale your own content with
    ' quality, e.g. particle counts or effects.
    '
    ' @param {integer} level - the new `BGE.RenderQualityLevel`
    sub onQualityChanged(level as integer)
    end sub
```

`Game.bs`:

1. Add imports (alphabetical within the existing list): `import "quality/DeviceQualitySeed.bs"`, `import "quality/QualityController.bs"`, `import "quality/RenderQualityLevel.bs"`, `import "quality/RenderQualityManager.bs"`.
2. Public field near `currentScene` (line ~129):

```brighterscript
    ' The game's render quality level and presets - see `setQualityLevel()`,
    ' `enableAdaptiveQuality()` and `BGE.RenderQualityManager.overridePreset()`.
    renderQuality as BGE.RenderQualityManager
```

3. In `sub new`, right after `m.canvas.renderer.dummyScreen = m.dummyScreen`:

```brighterscript
      renderQuality = new BGE.RenderQualityManager(m.canvas.renderer, BGE.seedRenderQualityLevelForDevice())
      m.renderQuality = renderQuality
```

4. In `Play()`, right after `m.uiCanvas.renderer.onSwapBuffers()`:

```brighterscript
        if m.renderQuality.update(m.dt)
          m.dispatchQualityChanged()
        end if
```

5. In `handleSceneChange()`, right after `m.currentScene.onCreate(args)`:

```brighterscript
        m.renderQuality.notifySceneChanged()
```

6. Next to `postGameEvent`:

```brighterscript
    ' Pins the render quality level and turns off adaptive tuning.
    '
    ' @param {integer} level - a `BGE.RenderQualityLevel` value
    sub setQualityLevel(level as integer)
      m.renderQuality.disableAdaptive()
      if m.renderQuality.setLevel(level)
        m.dispatchQualityChanged()
      end if
    end sub

    ' Adjusts the render quality level automatically to hold a target frame rate,
    ' starting from the current level.
    '
    ' @param {BGE.AdaptiveQualityOptions} [options={}] - e.g. {targetFps: 30, minLevel: BGE.RenderQualityLevel.low}
    sub enableAdaptiveQuality(options = {} as roAssociativeArray)
      m.renderQuality.enableAdaptive(options)
    end sub

    ' Stops adaptive tuning, keeping the current level.
    sub disableAdaptiveQuality()
      m.renderQuality.disableAdaptive()
    end sub

    private sub dispatchQualityChanged()
      level = m.renderQuality.getLevel()
      for i = 0 to m.sortedEntities.Count() - 1
        entity = m.sortedEntities[i]
        if m.isValidEntity(entity) and entity.onQualityChanged <> invalid
          entity.onQualityChanged(level)
        end if
      end for
      if m.isValidEntity(m.currentScene)
        m.currentScene.onQualityChanged(level)
      end if
      if invalid <> m.gameUi
        m.gameUi.onQualityChanged(level)
      end if
    end sub
```

`FpsDisplay.bs`: add `import "../quality/RenderQualityLevel.bs"`, and replace `m.fpsLabel.setText(\`FPS: ${m.fps}\`)` with:

```brighterscript
      quality = m.game.renderQuality
      mode = ""
      if quality.isAdaptive()
        mode = " (auto)"
      end if
      m.fpsLabel.setText(`FPS: ${m.fps} | Q: ${BGE.getRenderQualityLevelName(quality.getLevel())}${mode}`)
```

- [ ] **Step 6: Run to verify pass**

Run: `npm run check`
Expected: PASS - including all existing `Game.spec.bs`/`GameEntity.spec.bs`/debug-UI specs.

Then run `npm run check:all` (validates every example) - an example that overrides a `GameEntity` method named `onQualityChanged` or uses `renderQuality` would clash; fix any hit.

- [ ] **Step 7: Commit**

```bash
git add src/source/engine
git commit -m "Seed and manage render quality in Game, with adaptive tuning and onQualityChanged

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `quality-levels` rendererTest demo

**Files:**
- Create: `examples/rendererTest/src/source/Tests/QualityLevelsTest.bs`
- Modify: `examples/rendererTest/src/source/DemoList.bs`

**Interfaces:**
- Consumes: `Renderer.setQualitySettings`, `BGE.getRenderQualityPreset`, `BGE.getRenderQualityLevelName` (Tasks 1, 4)

- [ ] **Step 1: Write the demo**

Model it on `StaticGeometryBspBenchmark.bs` (owner stub, `Camera3d`, `setupCameraForFrame()` + `owner.updateTransformationMatrix()` + `render()` per frame, remove scene objects in `teardown`). Create `examples/rendererTest/src/source/Tests/QualityLevelsTest.bs`:

```brighterscript
' Cycles the render quality level (OK) over a mixed 3D scene so each level's cost
' shows in the frame timing line. The tool for tuning the presets on real hardware.
class QualityLevelsTest extends RendererTest

  private level as integer = BGE.RenderQualityLevel.medium
  private ownerGameStub as object
  private owner as BGE.GameEntity
  private camera as BGE.Camera3d
  private spin as float = 0

  sub new()
    super("Quality Levels (OK: next level)")
  end sub

  override sub setup(renderer as BGE.Renderer)
    m.ownerGameStub = new BenchmarkGameStub()
    m.owner = new BGE.GameEntity((m.ownerGameStub as dynamic), {name: "QualityOwner"})

    m.camera = new BGE.Camera3d()
    m.camera.position = BGE.Math.VectorOps.create(0, 60, 400)
    m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, 0))
    m.camera.maxDrawDistance = 1000
    renderer.camera = m.camera

    ' tiled ground plane (plane slices + draw distance)
    tile = CreateObject("roBitmap", {width: 64, height: 64, alphaEnable: false})
    tile.Clear(&h336633FF)
    tile.DrawRect(0, 0, 32, 32, &h449944FF)
    tile.DrawRect(32, 32, 32, 32, &h449944FF)
    tileRegion = CreateObject("roRegion", tile, 0, 0, 64, 64)
    plane = new BGE.DrawablePlane(m.owner, tileRegion, {normal: {x: 0, y: 1, z: 0}, point: {x: 0, y: -40, z: 0}}, {fillMode: BGE.PlaneFillMode.tiledImage})
    plane.addToRenderer(renderer)

    ' tilted circles and filled rectangles (fast-draw tolerances + triangle fills)
    for i = 0 to 11
      angle = (2 * BGE.Math.PI) * (i / 12)
      offset = BGE.Math.VectorOps.create(cos(angle) * 150, 0, sin(angle) * 150)
      circle = new BGE.DrawableCircle(m.owner, 20, {drawMode: BGE.SceneObjectDrawMode.solid, rotation: BGE.Math.VectorOps.create(0.1 * i, 0, 0)})
      circle.offset = offset
      circle.addToRenderer(renderer)
      rect = new BGE.DrawableRectangle(m.owner, 30, 30, {drawMode: BGE.SceneObjectDrawMode.solid, color: BGE.ColorsRGB.Red, rotation: BGE.Math.VectorOps.create(0, angle, 0.3)})
      rect.offset = BGE.Math.VectorOps.create(offset.x, 50, offset.z)
      rect.addToRenderer(renderer)
    end for

    renderer.setQualitySettings(BGE.getRenderQualityPreset(m.level))
  end sub

  override sub update(dt as float)
    m.spin += dt * 0.3
    m.camera.position = BGE.Math.VectorOps.create(sin(m.spin) * 400, 60, cos(m.spin) * 400)
    m.camera.setTarget(BGE.Math.VectorOps.create(0, 0, 0))
  end sub

  override sub draw(renderer as BGE.Renderer)
    renderer.setupCameraForFrame()
    m.owner.updateTransformationMatrix()
    renderer.render()
    renderer.drawText(`Level: ${BGE.getRenderQualityLevelName(m.level)}  draw distance: ${cint(m.camera.getEffectiveMaxDrawDistance())}`, 20, 80, BGE.Colors.White)
  end sub

  override sub onInput(buttonName as string)
    if buttonName = "OK"
      m.level = (m.level + 1) mod 5
    end if
  end sub

  override sub teardown(renderer as BGE.Renderer)
    for each sceneObj in renderer.getSceneObjectsCopy()
      renderer.removeSceneObject(sceneObj)
    end for
    renderer.setQualitySettings(BGE.getRenderQualityPreset(BGE.RenderQualityLevel.medium))
  end sub

end class
```

Also apply the new level in `onInput` - the renderer isn't passed there, so store it: add `private rendererRef as BGE.Renderer`, set `m.rendererRef = renderer` in `setup`, and in `onInput` after changing `m.level` call `m.rendererRef.setQualitySettings(BGE.getRenderQualityPreset(m.level))`.

Check before relying on them: `BenchmarkGameStub` is visible from this file (it's defined in `StaticGeometryBspBenchmark.bs`; if it's not global, copy the class into this file under a new name); the exact `onInput` signature in `RendererTest.bs`; that `rendererTest`'s own `main.bs` draws the title at the top so y=80 is clear.

- [ ] **Step 2: Register it**

In `DemoList.bs`, add after the `circle-fast-draw-benchmark` entry:

```brighterscript
    {
      id: "quality-levels",
      category: "Drawing",
      name: "Quality Levels",
      create: function() as RendererTest
        return new QualityLevelsTest()
      end function
    },
```

- [ ] **Step 3: Validate and run it**

Run: `npm run validate-examples`
Expected: `rendererTest` validates cleanly.

Then, per the `rokubot-examples` skill: build and sideload `rendererTest`, `rokubot launch dev --param demo=quality-levels`, screenshot, press OK four times with a screenshot after each. Expected: the level label steps Medium → High → Ultra → Basic → Low, the plane and shapes draw at every level, no crash. Record the fps/draw-ms line for each level (simulator and, if the user has one connected, a real device) in the PR description - that's the first real data for tuning the presets.

- [ ] **Step 4: Commit**

```bash
git add examples/rendererTest
git commit -m "Add quality-levels rendererTest demo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Terrain opt-in, docs and on-device check

**Files:**
- Modify: `examples/terrain/src/source/main.bs` (or wherever the `Game` is constructed - `grep -n "new BGE.Game" examples/terrain/src/source/*.bs`)
- Modify: `CLAUDE.md`
- Create: `docs/render-quality.md`

- [ ] **Step 1: Opt terrain in**

Right after terrain's `game = new BGE.Game(...)` (and after any `enableStandardDebugUi` call):

```brighterscript
  ' Hold 30fps by moving the render quality level automatically
  game.enableAdaptiveQuality({targetFps: 30})
```

Run: `npm run validate-examples` - Expected: PASS.

- [ ] **Step 2: On-device check**

Per the `rokubot-examples` skill: sideload `examples/terrain`, launch, turn on the debug overlay (terrain's hold-to-toggle), screenshot every ~10s for a minute while idle. Expected: the FPS line shows `Q: <level> (auto)`, the level settles and stops changing (no oscillation), no crash, the ground draws. Then fly forward for a few seconds and check the level doesn't flip-flop. Don't try to "play" in real time - if a check needs sustained input, ask the user to do it and report what they see.

- [ ] **Step 3: Write the guide**

Create `docs/render-quality.md` (how-to first, gotchas folded in as asides):

````markdown
---
title: Render Quality
group: Guides
order: 5
---

# Render Quality

The engine draws at one of five quality levels - Basic, Low, Medium, High and Ultra.
Each level is a bundle of draw-quality settings: how far the camera draws, how many
slices a ground plane uses, how small triangles are drawn, and when billboards can
use a cheaper draw call.

## Default: chosen for the device

You don't need to do anything. When your `Game` is created, the engine picks a
starting level from the Roku model it's running on - a Roku Ultra starts at Ultra,
a Roku Express at Low, the simulator at Medium. A model the engine doesn't know is
guessed from its model number, falling back to Medium.

## Hold a frame rate automatically

```brighterscript
game = new BGE.Game(1280, 720)
game.enableAdaptiveQuality({targetFps: 30})
```

The level drops quickly if the frame rate falls below the target and rises slowly
when there's headroom. Keep it within a range with `minLevel`/`maxLevel`:

```brighterscript
game.enableAdaptiveQuality({targetFps: 30, minLevel: BGE.RenderQualityLevel.low, maxLevel: BGE.RenderQualityLevel.high})
```

The debug FPS display (`game.enableStandardDebugUi()`) shows the current level.

## Pick a level yourself

```brighterscript
game.setQualityLevel(BGE.RenderQualityLevel.high)
```

This also turns adaptive tuning off - handy for testing, or for a settings menu.

## Draw distance

A level scales your camera's `maxDrawDistance` rather than replacing it: Basic
draws 0.4x as far, Medium exactly what you set, Ultra 2x. Set `maxDrawDistance` to
what suits your game at Medium. The distance actually used is
`camera.getEffectiveMaxDrawDistance()`, which is also capped per device to avoid
running out of memory.

## Change what a level does

```brighterscript
' this game's world is small - never draw further than 300 at High
game.renderQuality.overridePreset(BGE.RenderQualityLevel.high, {drawDistanceOverride: 300})
' smoother ground at Medium
game.renderQuality.overridePreset(BGE.RenderQualityLevel.medium, {planeSliceCount: 50})
```

Fields you don't name keep the engine's values. See `BGE.RenderQualitySettings`
for every field.

## Scale your own content

Every entity and scene gets `onQualityChanged(level)` when the level changes:

```brighterscript
override sub onQualityChanged(level as integer)
  m.sparks.maxParticles = [20, 40, 80, 120, 200][level]
end sub
```
````

Check the `order` against the other guides in `docs/` (`grep -n "^order" docs/*.md`) and pick the next free number.

- [ ] **Step 4: Update CLAUDE.md**

1. Add an architecture bullet under "Renderer / SceneObjects" (before the "Manually exercising the Renderer" heading):

```markdown
- **Render quality** (`engine/quality/`, issues #251/#126): every draw-quality knob (draw-distance scale/override, plane slice count, triangle skip/quick-draw thresholds and step, billboard fast-draw tolerances) is a field of `BGE.RenderQualitySettings`, read from `Renderer.qualitySettings` at draw time. Five `BGE.RenderQualityLevel` presets (`RenderQualityPresets.bs`) bundle them - today's pre-feature value sits at Ultra for knobs that were already at best quality (plane slices, fast-draw tolerances) and at Medium for two-way knobs. `Game` owns a `RenderQualityManager` (`game.renderQuality`) seeded from the device via `BGE.seedRenderQualityLevelForDevice()` (a model-prefix table from Roku's hardware spec page, with family/TV-letter inference for unknown models, no-GPU → Basic, 720p capped at Low, fallback Medium - the simulator seeds Medium), applied to the game canvas renderer only. `game.enableAdaptiveQuality()` runs a pure `QualityController` fed with `Game.dt` after the swap (drops fast below 90% of target, rises only after sustained headroom, settle period after level/scene changes, outlier frames ignored, failed up-probes back off). Level changes call `onQualityChanged(level)` on entities, the scene and `gameUi`. A `Renderer` used without a `Game` stays at Medium. See `specs/2026-09-26-adaptive-render-quality-design.md`.
```

2. In the `Camera3d.maxDrawDistance` bullet, replace "Reading `maxDrawDistance` back after setting it higher than the device cap returns the capped value, not what was set." with: "`maxDrawDistance` is the game-authored base value and is never rewritten; the distance actually used everywhere is `Camera3d.getEffectiveMaxDrawDistance()` - base × the quality level's `drawDistanceScale` (or its `drawDistanceOverride`), then the device cap." Update "the shared far-clip every `SceneObject.isInView` check now honors" to refer to the effective distance.

3. Add to "Conventions specific to this codebase":

```markdown
- **A constant that trades visual quality for speed belongs in `BGE.RenderQualitySettings`, not a `const`.** Add the field to the interface, give it a value at all five levels in `engine/quality/RenderQualityPresets.bs` (today's value at Ultra if it's already the best quality, otherwise at Medium), and read it via `rendererObj.qualitySettings`. `RenderQualityPresets.spec.bs` fails if any level is missing a field or a knob isn't monotonic from Basic to Ultra - extend its monotonic check with the new field's direction.
```

4. Remove the stale references to `TriangleDrawThreshold`/`TriangleQuickDrawThreshold` constants if CLAUDE.md mentions them anywhere (`grep -n "TriangleDrawThreshold\|SCENE_OBJECT_PLANE_SLICE_COUNT" CLAUDE.md docs/*.md`).

- [ ] **Step 5: Final gate**

Run: `npm run check:all` and `npm run docs`
Expected: both succeed; `docs-site/` contains a Render Quality guide under Guides.

- [ ] **Step 6: Commit**

```bash
git add examples/terrain CLAUDE.md docs/render-quality.md
git commit -m "Opt terrain into adaptive quality; document render quality

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
