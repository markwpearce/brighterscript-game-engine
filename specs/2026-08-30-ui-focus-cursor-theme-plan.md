# UI Focus Management, Virtual Cursor, and Theming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `BGE.UI` a reusable focus + virtual-cursor navigation system with same-frame input consumption, a shared `Theme` for colors/fonts, and three new interactive widgets (`Button`, `Checkbox`, `Select`), replacing `examples/audio`'s hand-rolled focus state.

**Architecture:** A `UiContainer` owns its own cursor position and focus state; d-pad input moves the cursor, hit-tests it against `focusable` children (hover drives focus, cursor-primary), and dispatches `onFocus`/`onBlur`/`onMouseOver`/`onMouseOut`/`onClick`. A widget that acts on an event calls `input.consume()`; the container then calls the existing `Game.setInputEntity()` primitive (extended to take effect the same frame) so regular `GameEntity.onInput()` is skipped for the rest of that frame. `Game.Play()` is reordered so UI input runs before entity input, making same-frame consumption possible at all. Colors/fonts default to a shared `BGE.UI.Theme`, with per-widget fields as an override.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 (`rooibos-roku`) for unit tests, `brs-cli` for headless CI test runs.

**Spec:** `specs/2026-08-30-ui-focus-cursor-theme-design.md`

## Global Constraints

- One `@suite` class per `*.spec.bs` file (Rooibos v6 silently corrupts multi-suite files — see CLAUDE.md).
- `assertEqual` is type-strict — match `Float` literals (`0.0`) against fields typed `as float`, `Integer` literals against `as integer`/untyped-dynamic-from-integer-literal fields. When unsure, run the test once and read the actual/expected types from the failure diff.
- Never compare two custom-class instances (or two native `roRegion`/`roBitmap`, etc.) with `=` — runtime `Type Mismatch` crash, not caught by `bsc`/lint. Compare a stable id/scalar field instead.
- New/changed public engine methods get JSDoc-style `'` comments (`@param`, `@return`) directly above them.
- `bslint.json`: no single-line `if`, `named-function-style` and `eol-last` disabled.
- Every task must leave `npm run validate` and `npm run test:ci` passing before moving to the next task.
- The `Game.Play()` reorder (Task 3) is a documented behavior change (UI input now runs before entity input) — `CLAUDE.md`'s game-loop section must be updated (Task 13) in the same work, not deferred.

---

## Task 1: `GameInput` gains a consume flag

**Files:**
- Modify: `src/source/engine/GameInput.bs`
- Test: `src/source/engine/GameInput.spec.bs`

**Interfaces:**
- Produces: `GameInput.consumed as boolean` (defaults `false`), `GameInput.consume() as void` (sets `consumed = true`).

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/GameInput.spec.bs`, inside the existing `GameInputTests` suite (after the last `@describe` block):

```brightscript
    @describe("consume")

    @it("defaults to not consumed")
    function _()
      input = new BGE.GameInput(2, 0)
      m.assertFalse(input.consumed)
    end function

    @it("consume() marks the input as consumed")
    function _()
      input = new BGE.GameInput(2, 0)
      input.consume()
      m.assertTrue(input.consumed)
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `consumed` and `consume` are not members of `GameInput`.

- [ ] **Step 3: Add the field and method to `GameInput`**

In `src/source/engine/GameInput.bs`, add alongside the other per-frame state fields (near `playerIndex`):

```brightscript
    ' Set by a UiWidget/UiContainer that acted on this event - once set, the
    ' owning UiContainer stops this event from also reaching GameEntity.onInput()
    ' for the rest of this frame (see Game.setInputEntity()).
    consumed as boolean = false
```

And add a method (after `isDirectionalArrow()`):

```brightscript
    ' Marks this input as handled by a UI widget, so it won't also reach
    ' regular GameEntity.onInput() callbacks this frame.
    '
    ' @return {void}
    sub consume()
      m.consumed = true
    end sub
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/GameInput.bs src/source/engine/GameInput.spec.bs
git commit -m "feat(ui): add GameInput.consume() for same-frame input capture"
```

---

## Task 2: `Game.setInputEntity`/`unsetInputEntity` take effect the same frame

**Context:** `Game.Play()` snapshots `m.currentInputEntityId = m.inputEntityId` once at the top of each frame; `dispatchOnInput()` (the shared per-entity dispatch helper) reads `m.currentInputEntityId`, not `m.inputEntityId`. Today, calling `setInputEntity()`/`unsetInputEntity()` mid-frame only changes `m.inputEntityId`, so the effect doesn't apply until the *next* frame's snapshot. Task 3's reorder needs a UI container's mid-frame `setInputEntity()` call to gate *this same frame's* remaining entity dispatch, so both fields must update together.

**Files:**
- Modify: `src/source/engine/Game.bs:2058-2071` (the `setInputEntity`/`unsetInputEntity` methods)
- Test: `src/source/engine/Game.spec.bs`

**Interfaces:**
- Produces: `Game.setInputEntity(entity as GameEntity)` and `Game.unsetInputEntity()` now update both `m.inputEntityId` (persists across frames until unset) and `m.currentInputEntityId` (read by `dispatchOnInput` for the rest of the current frame) in the same call.

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/Game.spec.bs`'s `GameTests` suite (near the other behavioral tests):

```brightscript
    @describe("setInputEntity")

    @it("takes effect the same frame it's called, not just the next one")
    function _()
      capturingEntity = new InputCapturingEntity(m.game)
      capturingEntity.onCreate({})
      otherEntity = new InputRecordingEntity(m.game)
      otherEntity.onCreate({})

      ' Simulate what Game.Play() does at the top of a frame, then dispatch
      ' input to both entities in registration order - mirrors
      ' processEntitiesPreDraw calling processEntityOnInput per entity.
      m.game.dispatchOnInputForTest(capturingEntity, new BGE.GameInput(6, 0)) ' OK, press
      m.game.dispatchOnInputForTest(otherEntity, new BGE.GameInput(6, 0))

      m.assertFalse(otherEntity.receivedInput)
    end function

    @it("unsetInputEntity() also takes effect the same frame")
    function _()
      capturingEntity = new InputCapturingEntity(m.game)
      capturingEntity.onCreate({})
      otherEntity = new InputRecordingEntity(m.game)
      otherEntity.onCreate({})

      m.game.setInputEntity(capturingEntity)
      m.game.unsetInputEntity()
      m.game.dispatchOnInputForTest(otherEntity, new BGE.GameInput(6, 0))

      m.assertTrue(otherEntity.receivedInput)
    end function
```

Add the two small helper entities at the bottom of the file, alongside the existing `ControlsCountingEntity` (same pattern - see `project_bsc_subclass_transpile_crash` memory: use an explicit fully-qualified constructor call):

```brightscript
  class InputCapturingEntity extends BGE.GameEntity
    sub new(game as BGE.Game)
      super(game)
    end sub

    override sub onInput(input as BGE.GameInput)
      m.game.setInputEntity(m)
    end sub
  end class

  class InputRecordingEntity extends BGE.GameEntity
    receivedInput as boolean = false

    sub new(game as BGE.Game)
      super(game)
    end sub

    override sub onInput(input as BGE.GameInput)
      m.receivedInput = true
    end sub
  end class
```

This test also needs a tiny test-only seam into `Game`'s private dispatch, since `dispatchOnInput` is `private`. Add a public passthrough for tests only where indicated in Step 3.

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `dispatchOnInputForTest` doesn't exist yet, and/or `otherEntity.receivedInput` is `false` when it should be `true` (or vice versa) because `currentInputEntityId` isn't updated mid-frame.

- [ ] **Step 3: Fix `setInputEntity`/`unsetInputEntity` and add the test seam**

In `src/source/engine/Game.bs`, replace:

```brightscript
    sub setInputEntity(entity as GameEntity)
      m.inputEntityId = entity.id
    end sub
```

```brightscript
    sub unsetInputEntity()
      m.inputEntityId = invalid
    end sub
```

with:

```brightscript
    ' Set only one entity to receive onInput() calls
    ' Useful for when a menu/pause screen should handle all input
    ' Takes effect immediately (this frame's remaining dispatch), not just next frame.
    '
    ' @param {GameEntity} entity
    ' @return {void}
    sub setInputEntity(entity as GameEntity)
      m.inputEntityId = entity.id
      m.currentInputEntityId = entity.id
    end sub


    ' Unset that only one entity will receive onInputCalls()
    ' Takes effect immediately (this frame's remaining dispatch), not just next frame.
    '
    ' @return {void}
    sub unsetInputEntity()
      m.inputEntityId = invalid
      m.currentInputEntityId = invalid
    end sub
```

Then add a thin public test-only wrapper around the private `dispatchOnInput`, right after `dispatchOnInput`'s own definition:

```brightscript
    ' Test-only passthrough to the private dispatchOnInput(), so specs can
    ' exercise the same currentInputEntityId gating Game.Play() relies on
    ' without needing a full Play() loop iteration.
    '
    ' @param {GameEntity} entity
    ' @param {GameInput} input
    ' @return {boolean} true if the entity is still valid
    function dispatchOnInputForTest(entity as GameEntity, input as GameInput) as boolean
      return m.dispatchOnInput(entity, input)
    end function
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`
Expected: clean (no type errors)

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/Game.spec.bs
git commit -m "fix(ui): make setInputEntity/unsetInputEntity take effect same-frame"
```

---

## Task 3: Reorder `Game.Play()` so UI input runs before entity input

**Context:** Today `Game.Play()` calls `processEntitiesPreDraw()` then, later in the frame, `processAndDrawUI()` (which does `gameUi`'s input handling *and* drawing together via `processUiUpdate`). For a `gameUi` widget's `input.consume()` (Task 1) + `setInputEntity()` (Task 2) to gate *this frame's* entity dispatch, `gameUi`'s input handling must run before `processEntitiesPreDraw()`. Drawing must stay where it is (after entity movement/collision), so split `processAndDrawUI` into an input phase and a draw phase.

**Files:**
- Modify: `src/source/engine/Game.bs` (`Play()` around line 373-393, and `processAndDrawUI`/`processUiUpdate` around line 1061-1096)
- Test: `src/source/engine/Game.spec.bs`

**Interfaces:**
- Produces: `Game.processUiInput(universalControlEvents, musicMsg, ecpMsg, urlMsg)` (private, new) — runs `gameUi`'s `onInput`/`onAudioEvent`/`onECPInput`/`onUrlEvent`/`onUpdate` dispatch only.
- Produces: `Game.drawUI()` (private, renamed from the draw half of `processAndDrawUI`) — just the `uiCanvas` render/draw call, no input dispatch.
- Consumes: `Game.setInputEntity`/`unsetInputEntity` from Task 2, `GameInput.consumed` from Task 1 are not directly used here — this task only reorders *when* `gameUi`'s existing `onInput` dispatch runs; the consumption wiring itself is Task 7 (`UiContainer`).

- [ ] **Step 1: Write the failing test**

This behavior is easiest to prove end-to-end once `UiContainer` actually consumes input (Task 7). For this task, add a narrower regression test that locks in *ordering* using the same `Game.setInputEntity` mechanism, proving a `gameUi`-triggered capture affects entities processed in the same `Play()`-shaped sequence. Add to `Game.spec.bs`:

```brightscript
    @describe("UI input runs before entity input")

    @it("gameUi's onInput can capture input before entities are dispatched this frame")
    function _()
      capturingWidget = new BGE.UI.UiWidget(m.game)
      m.game.gameUi.addChild(capturingWidget)
      otherEntity = new InputRecordingEntity(m.game)
      otherEntity.onCreate({})

      ' processUiInput must run before dispatching to otherEntity for this
      ' to work - mirrors the fixed Play() order.
      capturingWidget.game.setInputEntity(m.game.gameUi)
      m.game.dispatchOnInputForTest(otherEntity, new BGE.GameInput(6, 0))

      m.assertFalse(otherEntity.receivedInput)

      m.game.unsetInputEntity()
    end function
```

(This reuses `InputRecordingEntity` from Task 2 — no new helper class needed.)

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS already, actually — this test only exercises the gating primitive from Task 2, which already works. That's expected: this step is a smoke test that the primitive Task 3 relies on is solid. Confirm it passes before continuing (if it fails, Task 2 isn't complete).

- [ ] **Step 3: Split `processAndDrawUI` into input and draw phases**

In `src/source/engine/Game.bs`, replace:

```brightscript
    private sub processAndDrawUI(universalControlEvents as roUniversalControlEvent[], musicMsg as roAudioPlayerEvent, ecpMsg as roInputEvent, urlMsg as roUrlEvent)
      m.processUiUpdate(m.gameUi, universalControlEvents, musicMsg, ecpMsg, urlMsg)

      m.uiCanvas.renderer.setupCameraForFrame()
      if m.isValidEntity(m.gameUi) and invalid <> m.gameUi.draw
        m.adjustEntityCompositorObjectPostCollision(m.gameUi)

        m.gameUi.draw()
      end if
    end sub
```

with:

```brightscript
    ' Runs gameUi's input/update dispatch. Called BEFORE processEntitiesPreDraw()
    ' each frame (see Play()) so a UiWidget that consumes an input event
    ' (GameInput.consume() + Game.setInputEntity()) can stop that event from
    ' also reaching GameEntity.onInput() for regular entities the same frame.
    '
    ' @param {roUniversalControlEvent[]} universalControlEvents - array of control events since last frame
    ' @param musicMsg - audio player event in last frame
    ' @param ecpMsg  - input event in last frame
    ' @param urlMsg - url event in last frame
    private sub processUiInput(universalControlEvents as roUniversalControlEvent[], musicMsg as roAudioPlayerEvent, ecpMsg as roInputEvent, urlMsg as roUrlEvent)
      m.processUiUpdate(m.gameUi, universalControlEvents, musicMsg, ecpMsg, urlMsg)
    end sub

    ' Draws gameUi to the UI canvas. Called after entity movement/collision/draw
    ' each frame (see Play()), same position in the frame as before this reorder -
    ' only the input dispatch above moved, not drawing.
    '
    ' @return {void}
    private sub drawUI()
      m.uiCanvas.renderer.setupCameraForFrame()
      if m.isValidEntity(m.gameUi) and invalid <> m.gameUi.draw
        m.adjustEntityCompositorObjectPostCollision(m.gameUi)

        m.gameUi.draw()
      end if
    end sub
```

- [ ] **Step 4: Update `Play()`'s call sites**

In `src/source/engine/Game.bs`'s `Play()`, move the UI input call ahead of entity processing. Replace:

```brightscript
        ' ----------------------Handle entity interactions (collisions, etc)--------------------
        m.processEntitiesPreDraw(universalControlEvents, controllerInputs, musicMsg, ecpMsg, urlMsg)
```

with:

```brightscript
        ' ----------------------Process UI input first, so a widget that consumes-------------
        ' ----------------------an event (GameInput.consume()) can capture input before-------
        ' ----------------------regular entities are dispatched this same frame---------------
        m.processUiInput(universalControlEvents, musicMsg, ecpMsg, urlMsg)

        ' ----------------------Handle entity interactions (collisions, etc)--------------------
        m.processEntitiesPreDraw(universalControlEvents, controllerInputs, musicMsg, ecpMsg, urlMsg)
```

Then replace the later call:

```brightscript
        ' ---------------------- Handle all UI updates and draws -------------------------
        m.processAndDrawUI(universalControlEvents, musicMsg, ecpMsg, urlMsg)
```

with:

```brightscript
        ' ---------------------- Draw UI (input already processed earlier this frame) -----
        m.drawUI()
```

- [ ] **Step 5: Run full validation**

Run: `npm run validate && npm run build-tests && npm run test:ci`
Expected: clean, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/Game.spec.bs
git commit -m "refactor(ui): process gameUi input before entities, enabling same-frame capture"
```

---

## Task 4: `UiWidget` gains focus/hover state, lifecycle hooks, and hit-testing

**Files:**
- Modify: `src/source/engine/ui/UiWidget.bs`
- Test: `src/source/engine/ui/UiWidget.spec.bs`

**Interfaces:**
- Produces: `UiWidget.focusable as boolean` (default `false`), `UiWidget.focused as boolean`, `UiWidget.hovered as boolean`.
- Produces: empty overridable hooks `onFocus()`, `onBlur()`, `onMouseOver()`, `onMouseOut()`, `onMouseDown()`, `onMouseUp()`, `onClick()`.
- Produces: `UiWidget.containsPoint(point as BGE.Math.Vector) as boolean` — true if `point` is within `[position.x, position.x+width) x [position.y, position.y+height)`. Uses the widget's *current* `position`/`width`/`height` (already kept current by `repositionBasedOnParent`, called every draw pass), so callers must hit-test after that frame's reposition has run.
- Produces: `UiWidget.isContainer() as boolean` (returns `false`) — lets a widget resolve its effective `Theme` from its parent without an unsafe `=` comparison between custom-class instances (see CLAUDE.md's `=`-operator gotcha) or brittle duck-typing. `UiContainer` overrides this to `true` in Task 6.
- Consumes: `BGE.Math.Vector` (existing).

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/ui/UiWidget.spec.bs`'s existing suite:

```brightscript
    @describe("defaults")

    @it("is not focusable, focused, or hovered by default")
    function _()
      widget = new BGE.UI.UiWidget(m.game)
      m.assertFalse(widget.focusable)
      m.assertFalse(widget.focused)
      m.assertFalse(widget.hovered)
    end function

    @describe("containsPoint")

    @it("is true for a point inside the widget's bounds")
    function _()
      m.child.position = BGE.Math.VectorOps.create(10, 20, 0)
      m.child.width = 20
      m.child.height = 10

      m.assertTrue(m.child.containsPoint(BGE.Math.VectorOps.create(15, 25, 0)))
    end function

    @it("is true exactly on the top-left corner")
    function _()
      m.child.position = BGE.Math.VectorOps.create(10, 20, 0)
      m.child.width = 20
      m.child.height = 10

      m.assertTrue(m.child.containsPoint(BGE.Math.VectorOps.create(10, 20, 0)))
    end function

    @it("is false exactly on the bottom-right edge (exclusive)")
    function _()
      m.child.position = BGE.Math.VectorOps.create(10, 20, 0)
      m.child.width = 20
      m.child.height = 10

      m.assertFalse(m.child.containsPoint(BGE.Math.VectorOps.create(30, 30, 0)))
    end function

    @it("is false for a point outside the widget's bounds")
    function _()
      m.child.position = BGE.Math.VectorOps.create(10, 20, 0)
      m.child.width = 20
      m.child.height = 10

      m.assertFalse(m.child.containsPoint(BGE.Math.VectorOps.create(0, 0, 0)))
    end function

    @describe("isContainer")

    @it("is false for a plain UiWidget")
    function _()
      m.assertFalse(m.child.isContainer())
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `focusable`/`focused`/`hovered`/`containsPoint` don't exist yet.

- [ ] **Step 3: Add the fields, hooks, and hit-test method**

In `src/source/engine/ui/UiWidget.bs`, add fields near `width`/`height`:

```brightscript
    ' Can this widget receive focus/hover from its owning UiContainer's cursor?
    focusable as boolean = false
    ' Does this widget currently have focus? Set by the owning UiContainer - do not set directly.
    focused as boolean = false
    ' Is the owning UiContainer's cursor currently over this widget? Set by the owning UiContainer.
    hovered as boolean = false
```

Add the lifecycle hooks after `draw()`:

```brightscript
    ' Called when this widget gains focus (via the owning UiContainer's cursor
    ' or focus-order seeding). Override to show a focus-ring, etc.
    '
    sub onFocus()
    end sub

    ' Called when this widget loses focus.
    '
    sub onBlur()
    end sub

    ' Called when the owning UiContainer's cursor moves onto this widget.
    '
    sub onMouseOver()
    end sub

    ' Called when the owning UiContainer's cursor moves off this widget.
    '
    sub onMouseOut()
    end sub

    ' Called when OK is pressed while the cursor is over this widget (or this
    ' widget is focused via cursor-primary hover).
    '
    sub onMouseDown()
    end sub

    ' Called when OK is released while the cursor is over this widget.
    '
    sub onMouseUp()
    end sub

    ' Called when OK is pressed and released while the cursor is over this
    ' widget (or this widget is focused). The common "activate" hook - most
    ' widgets (Button, Checkbox, Select) only need to override this one.
    '
    sub onClick()
    end sub
```

Add the hit-test method after `getWorldPosition`:

```brightscript
    ' Is the given point (in the same coordinate space as m.position - UI
    ' canvas space) within this widget's current bounds? Bounds are
    ' half-open: the top-left corner counts, the bottom-right edge doesn't.
    '
    ' @param {BGE.Math.Vector} point
    ' @return {boolean}
    function containsPoint(point as BGE.Math.Vector) as boolean
      return point.x >= m.position.x and point.x < m.position.x + m.width and point.y >= m.position.y and point.y < m.position.y + m.height
    end function
```

Add the `isContainer()` hook after `containsPoint`:

```brightscript
    ' Is this widget a UiContainer? Overridden to true in UiContainer.
    '
    ' @return {boolean}
    function isContainer() as boolean
      return false
    end function
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/ui/UiWidget.bs src/source/engine/ui/UiWidget.spec.bs
git commit -m "feat(ui): add focus/hover state, lifecycle hooks, and hit-testing to UiWidget"
```

---

## Task 5: `BGE.UI.Theme` and `Game.defaultTheme`

**Files:**
- Create: `src/source/engine/ui/Theme.bs`
- Create: `src/source/engine/ui/Theme.spec.bs`
- Modify: `src/source/engine/Game.bs` (add `defaultTheme` field, constructed in `new()`)
- Test: `src/source/engine/Game.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.Theme` class with fields `backgroundColor`, `foregroundColor`, `borderColor`, `focusedBorderColor`, `hoveredBackgroundColor`, `disabledColor` (all `as integer`, packed RGBA per `BGE.Colors`), `font as roFont`, `fontSize as integer`, `defaultPadding as BGE.UI.OffsetSize`, `defaultMargin as BGE.UI.OffsetSize`, `cursorColor as integer`, `cursorSize as float`.
- Produces: `Game.defaultTheme as BGE.UI.Theme`, constructed in `Game.new()` after `m.fonts["default"]` is set (Theme's default font needs it).
- Consumes: `BGE.Colors` enum, `BGE.UI.OffsetSize` (existing), `m.fonts["default"]` (existing, set at `Game.bs:241`).

- [ ] **Step 1: Write the failing test for `Theme`'s defaults**

Create `src/source/engine/ui/Theme.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.UI.Theme")
  class ThemeTests extends rooibos.BaseTestSuite

    @describe("defaults")

    @it("has sensible default colors matching today's hardcoded widget values")
    function _()
      theme = new BGE.UI.Theme()
      m.assertEqual(BGE.Colors.Gray, theme.backgroundColor)
      m.assertEqual(BGE.Colors.White, theme.foregroundColor)
      m.assertEqual(BGE.Colors.White, theme.borderColor)
      m.assertEqual(BGE.Colors.White, theme.cursorColor)
    end function

    @it("has a default cursorSize and fontSize")
    function _()
      theme = new BGE.UI.Theme()
      m.assertEqual(8.0, theme.cursorSize)
      m.assertEqual(28, theme.fontSize)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.UI.Theme` doesn't exist.

- [ ] **Step 3: Create `Theme.bs`**

Create `src/source/engine/ui/Theme.bs`:

```brightscript
namespace BGE.UI

  ' Default colors/fonts/spacing for BGE.UI widgets. Game.defaultTheme is the
  ' engine-wide default (matching today's previously-hardcoded widget colors,
  ' so existing consumers see no visual change); a UiContainer.theme overrides
  ' it for that container's subtree, and any per-widget color/font field left
  ' `invalid` resolves from the nearest theme up the tree at add-time.
  class Theme

    backgroundColor as integer = BGE.Colors.Gray
    foregroundColor as integer = BGE.Colors.White
    borderColor as integer = BGE.Colors.White
    focusedBorderColor as integer = BGE.Colors.White
    hoveredBackgroundColor as integer = BGE.Colors.Gray
    disabledColor as integer = BGE.Colors.Gray

    font as roFont
    fontSize as integer = 28

    defaultPadding as OffsetSize
    defaultMargin as OffsetSize

    cursorColor as integer = BGE.Colors.White
    cursorSize as float = 8.0

    sub new()
      m.defaultPadding = new OffsetSize()
      m.defaultMargin = new OffsetSize()
    end sub

  end class

end namespace
```

- [ ] **Step 4: Run the `Theme` defaults test**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Write the failing test for `Game.defaultTheme`**

Add to `src/source/engine/Game.spec.bs`'s `GameTests` suite:

```brightscript
    @describe("defaultTheme")

    @it("constructs a default Theme using the game's default font")
    function _()
      m.assertNotInvalid(m.game.defaultTheme)
      m.assertNotInvalid(m.game.defaultTheme.font)
    end function
```

- [ ] **Step 6: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `Game.defaultTheme` doesn't exist.

- [ ] **Step 7: Add `defaultTheme` to `Game`**

In `src/source/engine/Game.bs`, add the field declaration near `gameUi`/`debugUi` (around line 116-119):

```brightscript
    defaultTheme as BGE.UI.Theme
```

In `Game.new()`, right after the line that sets `m.fonts["default"] = m.fontRegistry.GetDefaultFont(28, false, false)` (line 241), add:

```brightscript
      m.defaultTheme = new BGE.UI.Theme()
      m.defaultTheme.font = m.fonts["default"]
```

- [ ] **Step 8: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 9: Run full validation**

Run: `npm run validate`

- [ ] **Step 10: Commit**

```bash
git add src/source/engine/ui/Theme.bs src/source/engine/ui/Theme.spec.bs src/source/engine/Game.bs src/source/engine/Game.spec.bs
git commit -m "feat(ui): add BGE.UI.Theme and Game.defaultTheme"
```

---

## Task 6: `UiContainer` resolves an effective theme and tracks focus order

**Files:**
- Modify: `src/source/engine/ui/UiContainer.bs`
- Test: create `src/source/engine/ui/UiContainer.spec.bs`

**Interfaces:**
- Produces: `UiContainer.theme as BGE.UI.Theme or dynamic` (default `invalid` — meaning "inherit").
- Produces: `UiContainer.effectiveTheme() as BGE.UI.Theme` — returns `m.theme` if set, else `m.game.defaultTheme`.
- Produces: `UiContainer.focusOrder as UiWidget[]` — rebuilt whenever a focusable child is added/removed, in `addChild` call order.
- Consumes: `BGE.UI.Theme`, `Game.defaultTheme` (Task 5); `UiWidget.focusable` (Task 4).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/ui/UiContainer.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.UI.UiContainer")
  class UiContainerTests extends rooibos.BaseTestSuite

    game as BGE.Game
    container as BGE.UI.UiContainer

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.container = new BGE.UI.UiContainer(m.game)
    end function

    @describe("effectiveTheme")

    @it("falls back to the game's defaultTheme when no theme is set")
    function _()
      m.container.effectiveTheme().cursorSize = 12345.0
      m.assertEqual(12345.0, m.game.defaultTheme.cursorSize)
    end function

    @it("uses its own theme when one is set")
    function _()
      customTheme = new BGE.UI.Theme()
      customTheme.cursorSize = 99.0
      m.container.theme = customTheme

      m.assertEqual(99.0, m.container.effectiveTheme().cursorSize)
    end function

    @describe("focusOrder")

    @it("starts empty")
    function _()
      m.assertEqual(0, m.container.focusOrder.count())
    end function

    @it("adds a focusable child to focusOrder, in addChild order")
    function _()
      first = new BGE.UI.UiWidget(m.game)
      first.focusable = true
      second = new BGE.UI.UiWidget(m.game)
      second.focusable = true

      m.container.addChild(first)
      m.container.addChild(second)

      m.assertEqual(2, m.container.focusOrder.count())
      m.assertEqual(first.id, m.container.focusOrder[0].id)
      m.assertEqual(second.id, m.container.focusOrder[1].id)
    end function

    @it("does not add a non-focusable child to focusOrder")
    function _()
      notFocusable = new BGE.UI.UiWidget(m.game)

      m.container.addChild(notFocusable)

      m.assertEqual(0, m.container.focusOrder.count())
    end function

    @it("removes a child from focusOrder when removed from the container")
    function _()
      widget = new BGE.UI.UiWidget(m.game)
      widget.focusable = true
      m.container.addChild(widget)

      m.container.removeChild(widget)

      m.assertEqual(0, m.container.focusOrder.count())
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `theme`, `effectiveTheme`, `focusOrder` don't exist on `UiContainer`.

- [ ] **Step 3: Add the fields and methods to `UiContainer`**

In `src/source/engine/ui/UiContainer.bs`, add fields near `backgroundRGBA`:

```brightscript
    ' This container's own theme override. When invalid, effectiveTheme()
    ' falls back to m.game.defaultTheme.
    theme as BGE.UI.Theme

    ' Focusable children, in the order they were added via addChild() -
    ' used to seed initial focus and as the OK-press fallback target when
    ' the cursor isn't over any widget. Rebuilt by addChild()/removeChild().
    focusOrder as UiWidget[] = []
```

Add the theme resolution method (near `getValue`):

```brightscript
    ' The theme this container's widgets should pull colors/fonts from:
    ' this container's own m.theme if set, else the game's defaultTheme.
    '
    ' @return {BGE.UI.Theme}
    function effectiveTheme() as BGE.UI.Theme
      if m.theme <> invalid
        return m.theme
      end if
      return m.game.defaultTheme
    end function

    override function isContainer() as boolean
      return true
    end function
```

Update `addChild` and `removeChild` to maintain `focusOrder`:

```brightscript
    sub addChild(element as UiWidget)
      if element <> invalid
        m.children.push(element)
        if element.focusable
          m.focusOrder.push(element)
        end if
      end if
    end sub
```

```brightscript
    sub removeChild(element as UiWidget)
      indexToRemove = -1
      if invalid = element
        return
      end if

      for i = 0 to m.children.count() - 1
        if m.children[i].id = element.id
          indexToRemove = i
          exit for
        end if
      end for
      if indexToRemove >= 0 and invalid <> m.children[indexToRemove]
        m.children[indexToRemove].onDestroy()
        m.children.delete(indexToRemove)
      end if

      for i = m.focusOrder.count() - 1 to 0 step -1
        if m.focusOrder[i].id = element.id
          m.focusOrder.delete(i)
        end if
      end for
    end sub
```

Also update `clearChildren` to reset `focusOrder`:

```brightscript
    sub clearChildren()
      for each element in m.children
        element.onDestroy()
      end for
      m.children.clear()
      m.focusOrder.clear()
    end sub
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/ui/UiContainer.bs src/source/engine/ui/UiContainer.spec.bs
git commit -m "feat(ui): UiContainer tracks focusOrder and resolves an effective Theme"
```

---

## Task 7: `UiContainer` cursor movement, hit-testing, and focus/hover dispatch

**Context:** This is the core of the feature. `UiContainer.onInput()` currently just forwards every input to every child unconditionally. It becomes: move the cursor on directional input, hit-test the new cursor position against `focusOrder`, update `hovered`/`focused` + fire the matching lifecycle hooks, dispatch OK-press to the hovered/focused widget's `onClick()`, and — if a widget's own `onInput` (still called for widgets that want raw input, e.g. `Slider` adjusting via Left/Right while focused) sets `input.consumed` — call `game.setInputEntity(m.id)` for the rest of the frame.

**Files:**
- Modify: `src/source/engine/ui/UiContainer.bs`
- Test: `src/source/engine/ui/UiContainer.spec.bs`

**Interfaces:**
- Produces: `UiContainer.cursorPosition as BGE.Math.Vector` (starts at `focusOrder[0]`'s center if non-empty, else the container's own top-left).
- Produces: `UiContainer.cursorStep as float = 16.0` (pixels moved per press/held-frame).
- Consumes: `GameInput.x`/`.y`/`.press`/`.held`/`.isButton`/`.consume()`/`.consumed` (existing + Task 1); `UiWidget.containsPoint`/`focused`/`hovered`/`onFocus`/`onBlur`/`onMouseOver`/`onMouseOut`/`onClick`/`onInput` (Task 4, existing); `Game.setInputEntity`/`unsetInputEntity` (existing, Task 2 fix).

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/ui/UiContainer.spec.bs`:

```brightscript
    @describe("cursor movement and hover")

    @it("moving the cursor onto a focusable widget hovers and focuses it")
    function _()
      widget = new BGE.UI.UiWidget(m.game)
      widget.focusable = true
      widget.customPosition = true
      widget.customX = 0
      widget.customY = 0
      widget.width = 100
      widget.height = 100
      widget.repositionBasedOnParent(m.container)
      m.container.addChild(widget)
      m.container.cursorPosition = BGE.Math.VectorOps.create(50, 50, 0)

      m.container.onInput(new BGE.GameInput(6, 0)) ' OK press - triggers a hit-test pass

      m.assertTrue(widget.hovered)
      m.assertTrue(widget.focused)
    end function

    @it("moving the cursor off a widget blurs and unhovers it")
    function _()
      widget = new BGE.UI.UiWidget(m.game)
      widget.focusable = true
      widget.customPosition = true
      widget.customX = 0
      widget.customY = 0
      widget.width = 10
      widget.height = 10
      widget.repositionBasedOnParent(m.container)
      m.container.addChild(widget)
      m.container.cursorPosition = BGE.Math.VectorOps.create(5, 5, 0)
      m.container.onInput(new BGE.GameInput(6, 0))
      m.assertTrue(widget.focused)

      m.container.cursorPosition = BGE.Math.VectorOps.create(999, 999, 0)
      m.container.onInput(new BGE.GameInput(6, 0))

      m.assertFalse(widget.hovered)
      m.assertFalse(widget.focused)
    end function

    @it("right/held-right moves the cursor right by cursorStep")
    function _()
      startX = m.container.cursorPosition.x
      m.container.onInput(new BGE.GameInput(5, 0)) ' right, press

      m.assertEqual(startX + m.container.cursorStep, m.container.cursorPosition.x)
    end function

    @describe("click/consume")

    @it("OK press while hovering a widget fires onClick")
    function _()
      widget = new ClickCountingWidget(m.game)
      widget.focusable = true
      widget.customPosition = true
      widget.customX = 0
      widget.customY = 0
      widget.width = 10
      widget.height = 10
      widget.repositionBasedOnParent(m.container)
      m.container.addChild(widget)
      m.container.cursorPosition = BGE.Math.VectorOps.create(5, 5, 0)

      m.container.onInput(new BGE.GameInput(6, 0)) ' OK press

      m.assertEqual(1, widget.clickCount)
    end function

    @it("a widget's onInput can consume an event, capturing input for the rest of the frame")
    function _()
      widget = new ConsumingWidget(m.game)
      widget.focusable = true
      widget.customPosition = true
      widget.customX = 0
      widget.customY = 0
      widget.width = 10
      widget.height = 10
      widget.repositionBasedOnParent(m.container)
      m.container.addChild(widget)
      m.container.cursorPosition = BGE.Math.VectorOps.create(5, 5, 0)
      m.container.onInput(new BGE.GameInput(6, 0)) ' OK press - focuses/hovers widget

      otherEntity = new InputRecordingEntityForUiContainerTests(m.game)
      otherEntity.onCreate({})

      ' Left, with the widget focused - ConsumingWidget.onInput consumes it.
      m.container.onInput(new BGE.GameInput(4, 0))
      m.game.dispatchOnInputForTest(otherEntity, new BGE.GameInput(4, 0))

      m.assertFalse(otherEntity.receivedInput)

      m.game.unsetInputEntity()
    end function
```

Add three small helper classes at the bottom of the file:

```brightscript
  class ClickCountingWidget extends BGE.UI.UiWidget
    clickCount as integer = 0

    sub new(game as BGE.Game)
      super(game)
    end sub

    override sub onClick()
      m.clickCount++
    end sub
  end class

  class ConsumingWidget extends BGE.UI.UiWidget
    sub new(game as BGE.Game)
      super(game)
    end sub

    override sub onInput(input as BGE.GameInput)
      if input.isButton("left")
        input.consume()
      end if
    end sub
  end class

  class InputRecordingEntityForUiContainerTests extends BGE.GameEntity
    receivedInput as boolean = false

    sub new(game as BGE.Game)
      super(game)
    end sub

    override sub onInput(input as BGE.GameInput)
      m.receivedInput = true
    end sub
  end class
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `cursorPosition`/`cursorStep` don't exist, and `onInput` doesn't do hit-testing/consumption yet.

- [ ] **Step 3: Implement cursor/focus/consumption in `UiContainer`**

In `src/source/engine/ui/UiContainer.bs`, add fields near `focusOrder`:

```brightscript
    ' Virtual cursor position, in this container's own UI-canvas coordinate
    ' space (same space as m.position). Moved by directional input; hit-tested
    ' against focusOrder each frame to drive hover/focus (cursor-primary -
    ' hovering a widget focuses it, there's no separate keyboard-only scheme).
    cursorPosition as BGE.Math.Vector = BGE.Math.VectorZero()
    ' Pixels the cursor moves per press/held-frame of directional input.
    cursorStep as float = 16.0

    protected currentlyFocused as BGE.UI.UiWidget
```

Replace `UiContainer.onInput` entirely:

```brightscript
    ' Method to process input per frame.
    ' Moves the cursor on directional input, hit-tests it against focusable
    ' children to drive hover/focus, dispatches OK to the hovered/focused
    ' widget's onClick(), and forwards raw input to the focused widget's own
    ' onInput() (e.g. Slider adjusting via Left/Right). If anything along the
    ' way calls input.consume(), this container captures all input for the
    ' rest of this frame via Game.setInputEntity() - see GameInput.consume().
    '
    ' @param {BGE.GameInput} input - GameInput object for the last frame
    override sub onInput(input as BGE.GameInput)
      if input.press or input.held
        m.cursorPosition.x += input.x * m.cursorStep
        m.cursorPosition.y -= input.y * m.cursorStep ' input.y is world-space (+up); cursor space is screen-space (+down)
      end if

      m.updateHoverAndFocus()

      if m.currentlyFocused <> invalid
        if input.press and input.isButton("ok")
          m.currentlyFocused.onMouseDown()
          m.currentlyFocused.onClick()
          input.consume()
        else if input.release and input.isButton("ok")
          m.currentlyFocused.onMouseUp()
        else if m.currentlyFocused.onInput <> invalid
          m.currentlyFocused.onInput(input)
        end if
      end if

      if input.consumed
        m.game.setInputEntity(m)
      else
        m.game.unsetInputEntity()
      end if
    end sub

    ' Hit-tests m.cursorPosition against focusOrder, updating hovered/focused
    ' state and firing onMouseOver/onMouseOut/onFocus/onBlur for whatever
    ' changed. At most one widget is hovered/focused at a time.
    '
    private sub updateHoverAndFocus()
      hit = invalid as BGE.UI.UiWidget
      for each widget in m.focusOrder
        if widget.containsPoint(m.cursorPosition)
          hit = widget
          exit for
        end if
      end for

      if m.currentlyFocused <> invalid and (hit = invalid or hit.id <> m.currentlyFocused.id)
        m.currentlyFocused.hovered = false
        m.currentlyFocused.focused = false
        m.currentlyFocused.onMouseOut()
        m.currentlyFocused.onBlur()
        m.currentlyFocused = invalid
      end if

      if hit <> invalid and m.currentlyFocused = invalid
        hit.hovered = true
        hit.focused = true
        hit.onMouseOver()
        hit.onFocus()
        m.currentlyFocused = hit
      end if
    end sub
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/ui/UiContainer.bs src/source/engine/ui/UiContainer.spec.bs
git commit -m "feat(ui): UiContainer drives cursor movement, hover/focus, and input consumption"
```

---

## Task 8: `UiContainer` seeds initial focus and draws the cursor

**Files:**
- Modify: `src/source/engine/ui/UiContainer.bs`
- Test: `src/source/engine/ui/UiContainer.spec.bs`

**Interfaces:**
- Produces: cursor seeded at the center of `focusOrder[0]` the first time a container with at least one focusable child processes input (not at construction time, since `addChild` may run before the widget's position is finalized by the first `draw()`/`repositionBasedOnParent`).
- Produces: `UiContainer.draw()` also draws a small themed cursor marker (using `effectiveTheme().cursorColor`/`cursorSize`) on top of children, only when `focusOrder.count() > 0`.

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/ui/UiContainer.spec.bs`:

```brightscript
    @describe("initial focus seeding")

    @it("seeds the cursor onto the first focusable widget's center on first input")
    function _()
      widget = new BGE.UI.UiWidget(m.game)
      widget.focusable = true
      widget.customPosition = true
      widget.customX = 40
      widget.customY = 60
      widget.width = 20
      widget.height = 10
      widget.repositionBasedOnParent(m.container)
      m.container.addChild(widget)

      m.container.onInput(new BGE.GameInput(1000, 0)) ' an inert held-code with x=0,y=0, doesn't move the cursor

      m.assertTrue(widget.focused)
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — with no seeding, `cursorPosition` starts at `(0,0)` and never overlaps the widget at `(40,60)`-`(60,70)`.

- [ ] **Step 3: Add seeding logic**

In `src/source/engine/ui/UiContainer.bs`, add a field to track whether seeding has happened:

```brightscript
    protected hasSeededFocus as boolean = false
```

At the top of `onInput` (before the cursor-movement block), add:

```brightscript
      if not m.hasSeededFocus and m.focusOrder.count() > 0
        seed = m.focusOrder[0]
        m.cursorPosition = BGE.Math.VectorOps.create(seed.position.x + seed.width / 2, seed.position.y + seed.height / 2, 0)
        m.hasSeededFocus = true
      end if
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Write the failing test for cursor drawing**

Add to `src/source/engine/ui/UiContainer.spec.bs`:

```brightscript
    @describe("cursor drawing")

    @it("does not crash drawing with no focusable children")
    function _()
      m.container.draw()
      ' No assertion beyond "doesn't throw" - draw() has no return value to
      ' check, and this container has no canvas/screen backing in this test,
      ' so this only proves the guard for an empty focusOrder is safe.
      m.assertTrue(true)
    end function
```

- [ ] **Step 6: Run test to verify it fails or passes**

Run: `npm run build-tests && npm run test:ci`
Expected: this should already PASS against the current `draw()` (it doesn't touch cursor drawing yet) — confirms a safe baseline before Step 7 adds real drawing.

- [ ] **Step 7: Add cursor drawing to `UiContainer.draw()`**

In `src/source/engine/ui/UiContainer.bs`, at the end of `draw()` (after the `for each child in m.children` loop, still inside the `sub`), add:

```brightscript
      if m.focusOrder.count() > 0
        theme = m.effectiveTheme()
        m.canvas.renderer.drawRectangle(m.cursorPosition.x - theme.cursorSize / 2, m.cursorPosition.y - theme.cursorSize / 2, theme.cursorSize, theme.cursorSize, theme.cursorColor)
      end if
```

- [ ] **Step 8: Run test to verify it still passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS (the "no crash" test from Step 5 still needs a real canvas/renderer, since `UiWidget.new()` already calls `m.setCanvas(game.uiCanvas)` — confirm this resolves via the real `Game`'s `uiCanvas`, no extra setup needed).

- [ ] **Step 9: Run full validation**

Run: `npm run validate`

- [ ] **Step 10: Commit**

```bash
git add src/source/engine/ui/UiContainer.bs src/source/engine/ui/UiContainer.spec.bs
git commit -m "feat(ui): UiContainer seeds initial focus and draws a themed cursor"
```

---

## Task 9: Retrofit `Slider` onto focus and `Theme`

**Files:**
- Modify: `src/source/engine/ui/Slider.bs`
- Test: `src/source/engine/ui/Slider.spec.bs`

**Interfaces:**
- Produces: `Slider.focusable = true` by default; `barColor`/`backgroundColor` default to `invalid` (was `BGE.Colors.White`/`BGE.Colors.Gray`), resolving from `effectiveTheme()` when `invalid`; `Slider.onInput()` calls `increase()`/`decrease()` on Left/Right press and `input.consume()`.
- Consumes: `UiWidget.focusable`/`onFocus`/`onBlur` (Task 4), `UiContainer.effectiveTheme()` (Task 6) — a `Slider` needs its parent container to resolve its theme, so it resolves lazily in `draw()` (parent is known there via `repositionBasedOnParent`'s caller) rather than at construction time (before it's added to any container).

- [ ] **Step 1: Write the failing tests**

Add to `src/source/engine/ui/Slider.spec.bs`:

```brightscript
    @describe("focus")

    @it("is focusable by default")
    function _()
      m.assertTrue(m.slider.focusable)
    end function

    @describe("onInput")

    @it("left press decreases the value and consumes the input")
    function _()
      m.slider.step = 5
      m.slider.setValue(10)
      input = new BGE.GameInput(4, 0) ' left, press

      m.slider.onInput(input)

      m.assertEqual(5.0, m.slider.getValue())
      m.assertTrue(input.consumed)
    end function

    @it("right press increases the value and consumes the input")
    function _()
      m.slider.step = 5
      m.slider.setValue(10)
      input = new BGE.GameInput(5, 0) ' right, press

      m.slider.onInput(input)

      m.assertEqual(15.0, m.slider.getValue())
      m.assertTrue(input.consumed)
    end function

    @it("does not consume input it doesn't handle")
    function _()
      input = new BGE.GameInput(2, 0) ' up, press

      m.slider.onInput(input)

      m.assertFalse(input.consumed)
    end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `Slider.focusable` is `false` (inherited default), `onInput` doesn't exist on `Slider` yet.

- [ ] **Step 3: Retrofit `Slider`**

In `src/source/engine/ui/Slider.bs`, replace the constructor and color field defaults:

```brightscript
    barColor as integer
    backgroundColor as integer
```

(removing the old `= BGE.Colors.White`/`= BGE.Colors.Gray` defaults - both now default to `invalid` via the field's own type, since no initializer is given. Note: `as integer` with no default actually initializes to `0`, not `invalid`, in BrighterScript — use `as dynamic` instead so `invalid` is a real, distinguishable "unset" sentinel:)

```brightscript
    barColor as dynamic
    backgroundColor as dynamic
```

Update `sub new`:

```brightscript
    sub new(game as BGE.Game)
      super(game)
      m.focusable = true
      m.drawableText = new BGE.DrawableText(m)
    end sub
```

Add an `onInput` override (after `decrease`):

```brightscript
    ' Left/Right (while this slider is focused) adjust the value by step and
    ' consume the event, so it doesn't also reach GameEntity.onInput() -
    ' see GameInput.consume().
    '
    ' @param {BGE.GameInput} input
    override sub onInput(input as BGE.GameInput)
      if not input.press
        return
      end if
      if input.isButton("left")
        m.decrease()
        input.consume()
      else if input.isButton("right")
        m.increase()
        input.consume()
      end if
    end sub
```

Update `draw()` to resolve theme colors when `barColor`/`backgroundColor` are `invalid`, and draw a focus ring when focused. Replace:

```brightscript
    override sub draw(parent = invalid as UiWidget)
      if m.width <= 0 or m.height <= 0
        return
      end if

      percent = (m.value - m.minValue) / (m.maxValue - m.minValue)
      fillWidth = m.width * percent

      m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, m.backgroundColor)
      if fillWidth > 0
        m.canvas.renderer.drawRectangle(m.position.x, m.position.y, fillWidth, m.height, m.barColor)
      end if

      if invalid <> m.drawableText and m.drawableText.text <> ""
        textImage = m.drawableText.getTextImage()
        if textImage <> invalid
          m.canvas.renderer.drawTransformedObject(m.position.x, m.position.y - m.drawableText.getDrawnSize().height, 1.0, 1.0, 0, textImage)
        end if
      end if
    end sub
```

with:

```brightscript
    override sub draw(parent = invalid as UiWidget)
      if m.width <= 0 or m.height <= 0
        return
      end if

      theme = m.game.defaultTheme
      if parent <> invalid and parent.isContainer()
        theme = (parent as BGE.UI.UiContainer).effectiveTheme()
      end if
      resolvedBackgroundColor = m.backgroundColor
      if resolvedBackgroundColor = invalid
        resolvedBackgroundColor = theme.backgroundColor
      end if
      resolvedBarColor = m.barColor
      if resolvedBarColor = invalid
        resolvedBarColor = theme.foregroundColor
      end if

      percent = (m.value - m.minValue) / (m.maxValue - m.minValue)
      fillWidth = m.width * percent

      m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, resolvedBackgroundColor)
      if fillWidth > 0
        m.canvas.renderer.drawRectangle(m.position.x, m.position.y, fillWidth, m.height, resolvedBarColor)
      end if

      if m.focused
        m.canvas.renderer.drawRectangle(m.position.x - 2, m.position.y - 2, m.width + 4, m.height + 4, theme.focusedBorderColor)
        m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, resolvedBackgroundColor)
        if fillWidth > 0
          m.canvas.renderer.drawRectangle(m.position.x, m.position.y, fillWidth, m.height, resolvedBarColor)
        end if
      end if

      if invalid <> m.drawableText and m.drawableText.text <> ""
        textImage = m.drawableText.getTextImage()
        if textImage <> invalid
          m.canvas.renderer.drawTransformedObject(m.position.x, m.position.y - m.drawableText.getDrawnSize().height, 1.0, 1.0, 0, textImage)
        end if
      end if
    end sub
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS. If any existing `Slider.spec.bs` test asserted the old hardcoded `barColor`/`backgroundColor` defaults, update those assertions to expect `invalid` instead (check the current `@describe("defaults")` block).

- [ ] **Step 5: Run full validation**

Run: `npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/ui/Slider.bs src/source/engine/ui/Slider.spec.bs
git commit -m "feat(ui): retrofit Slider onto focus, input consumption, and Theme"
```

---

## Task 10: `Button` widget

**Files:**
- Create: `src/source/engine/ui/Button.bs`
- Create: `src/source/engine/ui/Button.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.Button extends UiWidget`, `focusable = true`, `setLabel(text as string)`, `onActivate as function or invalid` (settable callback field, called from `onClick()`), themed background/label/focus-ring rendering matching `Slider`'s theme-resolution pattern from Task 9.
- Consumes: `UiWidget.isContainer()` (Task 9's note), `Theme` (Task 5), `BGE.DrawableText` (existing, same pattern as `Label`/`Slider`).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/ui/Button.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.UI.Button")
  class ButtonTests extends rooibos.BaseTestSuite

    game as BGE.Game
    button as BGE.UI.Button

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.button = new BGE.UI.Button(m.game)
    end function

    @describe("defaults")

    @it("is focusable by default")
    function _()
      m.assertTrue(m.button.focusable)
    end function

    @describe("onClick")

    @it("calls onActivate when set")
    function _()
      m.button.activateCallCount = 0
      m.button.onActivate = sub(button as BGE.UI.Button)
        button.activateCallCount++
      end sub

      m.button.onClick()

      m.assertEqual(1, m.button.activateCallCount)
    end function

    @it("does nothing if onActivate isn't set")
    function _()
      m.button.onClick() ' should not throw
      m.assertTrue(true)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.UI.Button` doesn't exist.

- [ ] **Step 3: Create `Button.bs`**

Create `src/source/engine/ui/Button.bs`:

```brightscript
namespace BGE.UI

  ' A focusable, clickable button: a label over a themed background.
  ' Set onActivate to a function(button as Button) to handle clicks, or
  ' subclass and override onClick() directly.
  class Button extends UiWidget

    drawableText as BGE.DrawableText
    activateCallCount as integer = 0

    ' Called from onClick() when set - function(button as Button) as void
    onActivate as function or dynamic

    sub new(game as BGE.Game)
      super(game)
      m.focusable = true
      m.drawableText = new BGE.DrawableText(m)
    end sub

    ' Sets this button's label text.
    '
    ' @param {string} text
    ' @return {void}
    sub setLabel(text as string)
      m.drawableText.text = text
    end sub

    override sub onClick()
      if m.onActivate <> invalid
        m.onActivate(m)
      end if
    end sub

    override sub draw(parent = invalid as UiWidget)
      if m.width <= 0 or m.height <= 0
        return
      end if

      theme = m.game.defaultTheme
      if parent <> invalid and parent.isContainer()
        theme = (parent as UiContainer).effectiveTheme()
      end if

      backgroundColor = theme.backgroundColor
      if m.hovered or m.focused
        backgroundColor = theme.hoveredBackgroundColor
      end if

      m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, backgroundColor)
      if m.focused
        m.canvas.renderer.drawRectangle(m.position.x - 2, m.position.y - 2, m.width + 4, m.height + 4, theme.focusedBorderColor)
        m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, backgroundColor)
      end if

      if invalid <> m.drawableText and m.drawableText.text <> ""
        textImage = m.drawableText.getTextImage()
        if textImage <> invalid
          textSize = m.drawableText.getDrawnSize()
          textX = m.position.x + (m.width - textSize.width) / 2
          textY = m.position.y + (m.height - textSize.height) / 2
          m.canvas.renderer.drawTransformedObject(textX, textY, 1.0, 1.0, 0, textImage)
        end if
      end if
    end sub

  end class

end namespace
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 6: Run full validation**

Run: `npm run validate`

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/ui/Button.bs src/source/engine/ui/Button.spec.bs
git commit -m "feat(ui): add Button widget"
```

---

## Task 11: `Checkbox` widget

**Files:**
- Create: `src/source/engine/ui/Checkbox.bs`
- Create: `src/source/engine/ui/Checkbox.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.Checkbox extends UiWidget`, `focusable = true`, `checked as boolean`, `getValue() as boolean`, `setLabel(text as string)`, `onChanged as function or invalid` (called with `(checkbox as Checkbox)` after `checked` flips).
- Consumes: same theme-resolution pattern as `Button`/`Slider`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/ui/Checkbox.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.UI.Checkbox")
  class CheckboxTests extends rooibos.BaseTestSuite

    game as BGE.Game
    checkbox as BGE.UI.Checkbox

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.checkbox = new BGE.UI.Checkbox(m.game)
    end function

    @describe("defaults")

    @it("is focusable and unchecked by default")
    function _()
      m.assertTrue(m.checkbox.focusable)
      m.assertFalse(m.checkbox.checked)
      m.assertFalse(m.checkbox.getValue())
    end function

    @describe("onClick")

    @it("toggles checked from false to true")
    function _()
      m.checkbox.onClick()
      m.assertTrue(m.checkbox.getValue())
    end function

    @it("toggles checked from true to false")
    function _()
      m.checkbox.checked = true
      m.checkbox.onClick()
      m.assertFalse(m.checkbox.getValue())
    end function

    @it("calls onChanged with the new value")
    function _()
      m.checkbox.lastChangedValue = invalid
      m.checkbox.onChanged = sub(checkbox as BGE.UI.Checkbox)
        checkbox.lastChangedValue = checkbox.getValue()
      end sub

      m.checkbox.onClick()

      m.assertTrue(m.checkbox.lastChangedValue)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.UI.Checkbox` doesn't exist.

- [ ] **Step 3: Create `Checkbox.bs`**

Create `src/source/engine/ui/Checkbox.bs`:

```brightscript
namespace BGE.UI

  ' A focusable checkbox: a small toggle box plus a label.
  ' Set onChanged to a function(checkbox as Checkbox) to react to toggles.
  class Checkbox extends UiWidget

    checked as boolean = false
    drawableText as BGE.DrawableText
    lastChangedValue as dynamic

    ' Called from onClick() after checked flips - function(checkbox as Checkbox) as void
    onChanged as function or dynamic

    sub new(game as BGE.Game)
      super(game)
      m.focusable = true
      m.drawableText = new BGE.DrawableText(m)
    end sub

    ' Sets this checkbox's label text.
    '
    ' @param {string} text
    ' @return {void}
    sub setLabel(text as string)
      m.drawableText.text = text
    end sub

    ' Gets this checkbox's current value.
    '
    ' @return {boolean}
    override function getValue() as boolean
      return m.checked
    end function

    override sub onClick()
      m.checked = not m.checked
      if m.onChanged <> invalid
        m.onChanged(m)
      end if
    end sub

    override sub draw(parent = invalid as UiWidget)
      boxSize = m.height
      if boxSize <= 0
        boxSize = 20
      end if

      theme = m.game.defaultTheme
      if parent <> invalid and parent.isContainer()
        theme = (parent as UiContainer).effectiveTheme()
      end if

      boxColor = theme.backgroundColor
      if m.hovered or m.focused
        boxColor = theme.hoveredBackgroundColor
      end if

      m.canvas.renderer.drawRectangle(m.position.x, m.position.y, boxSize, boxSize, boxColor)
      if m.checked
        inset = boxSize * 0.25
        m.canvas.renderer.drawRectangle(m.position.x + inset, m.position.y + inset, boxSize - inset * 2, boxSize - inset * 2, theme.foregroundColor)
      end if
      if m.focused
        m.canvas.renderer.drawRectangle(m.position.x - 2, m.position.y - 2, boxSize + 4, boxSize + 4, theme.focusedBorderColor)
        m.canvas.renderer.drawRectangle(m.position.x, m.position.y, boxSize, boxSize, boxColor)
        if m.checked
          inset = boxSize * 0.25
          m.canvas.renderer.drawRectangle(m.position.x + inset, m.position.y + inset, boxSize - inset * 2, boxSize - inset * 2, theme.foregroundColor)
        end if
      end if

      if invalid <> m.drawableText and m.drawableText.text <> ""
        textImage = m.drawableText.getTextImage()
        if textImage <> invalid
          textY = m.position.y + (boxSize - m.drawableText.getDrawnSize().height) / 2
          m.canvas.renderer.drawTransformedObject(m.position.x + boxSize + 8, textY, 1.0, 1.0, 0, textImage)
        end if
      end if
    end sub

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/ui/Checkbox.bs src/source/engine/ui/Checkbox.spec.bs
git commit -m "feat(ui): add Checkbox widget"
```

---

## Task 12: `Select` widget (inline cycling)

**Files:**
- Create: `src/source/engine/ui/Select.bs`
- Create: `src/source/engine/ui/Select.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.Select extends UiWidget`, `focusable = true`, `options as dynamic[]`, `selectedIndex as integer`, `getValue() as dynamic` (returns `options[selectedIndex]`), `next()`/`previous()` (cycle with wraparound), `onInput()` calling `next()`/`previous()` on Right/Left press + `input.consume()`, `onChanged as function or invalid`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/ui/Select.spec.bs`:

```brightscript
namespace tests

  @suite("BGE.UI.Select")
  class SelectTests extends rooibos.BaseTestSuite

    game as BGE.Game
    select as BGE.UI.Select

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.select = new BGE.UI.Select(m.game)
      m.select.options = ["Easy", "Medium", "Hard"]
    end function

    @describe("defaults")

    @it("is focusable and starts at index 0")
    function _()
      m.assertTrue(m.select.focusable)
      m.assertEqual(0, m.select.selectedIndex)
      m.assertEqual("Easy", m.select.getValue())
    end function

    @describe("next/previous")

    @it("next advances to the next option")
    function _()
      m.select.next()
      m.assertEqual("Medium", m.select.getValue())
    end function

    @it("next wraps around from the last option to the first")
    function _()
      m.select.selectedIndex = 2
      m.select.next()
      m.assertEqual("Easy", m.select.getValue())
    end function

    @it("previous wraps around from the first option to the last")
    function _()
      m.select.previous()
      m.assertEqual("Hard", m.select.getValue())
    end function

    @describe("onInput")

    @it("right press advances and consumes the input")
    function _()
      input = new BGE.GameInput(5, 0) ' right, press
      m.select.onInput(input)
      m.assertEqual("Medium", m.select.getValue())
      m.assertTrue(input.consumed)
    end function

    @it("left press goes back and consumes the input")
    function _()
      m.select.selectedIndex = 1
      input = new BGE.GameInput(4, 0) ' left, press
      m.select.onInput(input)
      m.assertEqual("Easy", m.select.getValue())
      m.assertTrue(input.consumed)
    end function

    @it("does not consume input it doesn't handle")
    function _()
      input = new BGE.GameInput(2, 0) ' up, press
      m.select.onInput(input)
      m.assertFalse(input.consumed)
    end function

  end class

end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `BGE.UI.Select` doesn't exist.

- [ ] **Step 3: Create `Select.bs`**

Create `src/source/engine/ui/Select.bs`:

```brightscript
namespace BGE.UI

  ' A focusable, inline-cycling option picker: Left/Right (while focused)
  ' step through m.options with wraparound. For a full expanding/popup list,
  ' see the follow-up issue filed alongside this widget - this is the
  ' compact style, matching Slider's existing interaction pattern.
  class Select extends UiWidget

    options as dynamic[] = []
    selectedIndex as integer = 0
    drawableText as BGE.DrawableText

    ' Called after selectedIndex changes - function(select as Select) as void
    onChanged as function or dynamic

    sub new(game as BGE.Game)
      super(game)
      m.focusable = true
      m.drawableText = new BGE.DrawableText(m)
    end sub

    ' Gets the currently selected option's value.
    '
    ' @return {dynamic}
    override function getValue() as dynamic
      if m.options.count() = 0
        return invalid
      end if
      return m.options[m.selectedIndex]
    end function

    ' Advances to the next option, wrapping to the first after the last.
    '
    ' @return {void}
    sub next()
      if m.options.count() = 0
        return
      end if
      m.selectedIndex = (m.selectedIndex + 1) mod m.options.count()
      if m.onChanged <> invalid
        m.onChanged(m)
      end if
    end sub

    ' Goes back to the previous option, wrapping to the last after the first.
    '
    ' @return {void}
    sub previous()
      if m.options.count() = 0
        return
      end if
      m.selectedIndex = (m.selectedIndex - 1 + m.options.count()) mod m.options.count()
      if m.onChanged <> invalid
        m.onChanged(m)
      end if
    end sub

    override sub onInput(input as BGE.GameInput)
      if not input.press
        return
      end if
      if input.isButton("right")
        m.next()
        input.consume()
      else if input.isButton("left")
        m.previous()
        input.consume()
      end if
    end sub

    override sub draw(parent = invalid as UiWidget)
      if m.width <= 0 or m.height <= 0
        return
      end if

      theme = m.game.defaultTheme
      if parent <> invalid and parent.isContainer()
        theme = (parent as UiContainer).effectiveTheme()
      end if

      backgroundColor = theme.backgroundColor
      if m.hovered or m.focused
        backgroundColor = theme.hoveredBackgroundColor
      end if

      m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, backgroundColor)
      if m.focused
        m.canvas.renderer.drawRectangle(m.position.x - 2, m.position.y - 2, m.width + 4, m.height + 4, theme.focusedBorderColor)
        m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, backgroundColor)
      end if

      value = m.getValue()
      if value <> invalid
        m.drawableText.text = value.ToStr()
        textImage = m.drawableText.getTextImage()
        if textImage <> invalid
          textSize = m.drawableText.getDrawnSize()
          textX = m.position.x + (m.width - textSize.width) / 2
          textY = m.position.y + (m.height - textSize.height) / 2
          m.canvas.renderer.drawTransformedObject(textX, textY, 1.0, 1.0, 0, textImage)
        end if
      end if
    end sub

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS

- [ ] **Step 5: Run full validation**

Run: `npm run validate`

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/ui/Select.bs src/source/engine/ui/Select.spec.bs
git commit -m "feat(ui): add Select widget (inline cycling)"
```

---

## Task 13: Update `CLAUDE.md` for the game-loop reorder and new UI system

**Files:**
- Modify: `/Users/mpearce/redspace/roku/brighterscript-game-engine/CLAUDE.md`

- [ ] **Step 1: Update the game loop section**

In the "Game loop (`engine/Game.bs`)" section, update step 2 ("Update (`processEntitiesPreDraw`)...") to note the new ordering. Find the numbered list and add a note after item 1 ("Input/event collection..."), or inline into item 2, along these lines:

```markdown
1. **Input/event collection** — reads Roku universal control events, ECP input, audio events, and URL transfer events off message ports.
2. **UI input** (`processUiInput`) — `gameUi`'s `onInput`/`onAudioEvent`/`onECPInput`/`onUrlEvent`/`onUpdate` dispatch runs here, *before* regular entities get their turn — this lets a focused/hovered `BGE.UI` widget call `input.consume()` (see `GameInput.consume()`) and capture all input for the rest of the frame via the existing `Game.setInputEntity()`, stopping that same event from also reaching `GameEntity.onInput()`. This ordering is deliberate and was changed for issue #133 — UI used to process after entities.
3. **Update** (`processEntitiesPreDraw`) — for every `GameEntity` (current room processed first, then `sortedEntities` in reverse): dispatch `onInput`/`onECPKeyboard`/`onECPInput`/`onAudioEvent`/`onUrlEvent`/`onUpdate`, then apply velocity to position (`processEntityMovement`)...
```

(Renumber the remaining list items accordingly, keeping the rest of that section's content unchanged.)

- [ ] **Step 2: Add a `BGE.UI` focus/cursor/theme summary**

In the "UI (`engine/ui/`)" section, expand the existing paragraph to mention the new system, e.g.:

```markdown
`UiContainer`/`UiWidget`/`Label`/`Style`/`Alignment` implement a small retained-mode widget tree, drawn to its own canvas layer above the game world. Each `UiContainer` owns its own focus/cursor state (issue #133): `UiWidget.focusable` opt-in widgets (`Slider`, `Button`, `Checkbox`, `Select`) are hit-tested against the container's `cursorPosition` (moved by directional input, `cursorStep` pixels per press/held-frame) — hovering a widget focuses it (cursor-primary; `focusOrder`, built from `addChild` order, only seeds the initial focus and serves as an OK-press fallback), firing `onMouseOver`/`onMouseOut`/`onFocus`/`onBlur`/`onClick`. A widget's `onInput` (or the container's own dispatch) can call `input.consume()` (`GameInput.consume()`) to capture all input for the rest of that frame via `Game.setInputEntity()`, keeping it from also reaching `GameEntity.onInput()`. Colors/fonts default to `Game.defaultTheme` (a `BGE.UI.Theme`) or a `UiContainer.theme` override; any per-widget color field left unset resolves from there. `Game.gameUi`/`Game.debugUi` are the two top-level containers; debug windows (`engine/debug/`: ...) attach under `debugUi` [keep existing sentence about debug windows here].
```

Adjust wording to flow with whatever the existing paragraph already says about debug windows (read the current text before editing so nothing is duplicated or contradicted).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document UI focus/cursor/theme system and game-loop input reorder"
```

---

## Task 14: Retrofit `examples/audio` onto the new focus system

**Files:**
- Modify: `examples/audio/src/source/Rooms/MainRoom.bs`

**Context:** Replaces the hand-rolled `focusIndex`/manual Up-Down-cycling/manual Left-Right-routing described in issue #133's own "Context" section, proving the new system actually replaces that pattern. This file isn't covered by Rooibos (per CLAUDE.md, examples' own code isn't exercised by the automated suite) — an actual `rokubot` sideload run is required before this task is considered verified.

**Important consequence of the new architecture to design around:** `UiContainer.onInput()` (Task 7) unconditionally consumes OK-while-focused and calls the focused widget's `onClick()` — neither `Select` nor `Slider` exposes an activate callback field (only `Button`/`Checkbox` do), so OK presses on them would otherwise be silently swallowed (`UiWidget.onClick()` is an empty stub) and never reach `MainRoom.onInput()` at all. This example needs OK to trigger `playFocused()` regardless of which widget is focused, so it subclasses both to route their `onClick()` back to the room. This also means the old `input.isButton("ok") and not m.rowSelect.focused and not m.volumeSlider.focused` idea doesn't work — OK is never seen by the room's own `onInput` while a widget is focused; it must be wired through the subclasses' `onClick()` instead.

- [ ] **Step 1: Rewrite `MainRoom.bs` to use `BGE.UI.Select` for the row picker and rely on `Slider`'s own focus handling**

Replace the whole file:

```brightscript
' Demonstrates the two distinct sound paths the engine exposes, and onAudioEvent():
'   Sound Effect - Game.Sounds / playSound() (roAudioResource) - one-shot, has a per-play volume
'   Music        - Game.musicPlay()/musicPause()/musicResume()/musicStop() (roAudioPlayer) - can
'                  loop, but roAudioPlayer has no volume control on the Roku platform at all -
'                  so unlike the sound effect, volume isn't adjustable here.
'
' Up/Down: move the cursor between the row picker and the volume slider
' Left/Right: change row (picker) or adjust volume (slider)
' OK: play (music toggles play/pause; sound effect fires the one-shot)
' Options (*): toggle music looping   Rewind: stop music
class MainRoom extends BGE.Room

  sfxVolume = 100
  loopMusic = true

  ' "stopped", "playing" or "paused" - Game itself doesn't track music playback state,
  ' so this room does, to know which of musicPlay/musicPause/musicResume to call next.
  musicState = "stopped"

  infoLabel as BGE.UI.Label
  statusLabel as BGE.UI.Label
  rowSelect as AudioRowSelect
  volumeSlider as AudioVolumeSlider

  sub new(game as BGE.Game)
    super(game)
    m.name = "MainRoom"
    m.infoLabel = new BGE.UI.Label(m.game)
    m.statusLabel = new BGE.UI.Label(m.game)
    m.rowSelect = new AudioRowSelect(m.game)
    m.volumeSlider = new AudioVolumeSlider(m.game)
  end sub

  override sub onCreate(args as roAssociativeArray)
    width = m.game.canvas.getWidth()
    height = m.game.canvas.getHeight()

    m.infoLabel.customPosition = true
    m.infoLabel.customX = width * 0.1
    m.infoLabel.customY = height * 0.1
    m.game.gameUi.addChild(m.infoLabel)

    m.rowSelect.customPosition = true
    m.rowSelect.customX = width * 0.1
    m.rowSelect.customY = height * 0.3
    m.rowSelect.width = width * 0.3
    m.rowSelect.height = 24
    m.rowSelect.options = ["Music", "Sound Effect"]
    m.rowSelect.room = m
    m.rowSelect.onChanged = sub(select as BGE.UI.Select)
      (select as AudioRowSelect).room.updateLabels()
    end sub
    m.game.gameUi.addChild(m.rowSelect)

    m.volumeSlider.customPosition = true
    m.volumeSlider.customX = width * 0.1
    m.volumeSlider.customY = height * 0.4
    m.volumeSlider.width = width * 0.3
    m.volumeSlider.height = 24
    m.volumeSlider.step = 10
    m.volumeSlider.setValue(m.sfxVolume)
    m.volumeSlider.room = m
    m.game.gameUi.addChild(m.volumeSlider)

    m.statusLabel.customPosition = true
    m.statusLabel.customX = width * 0.1
    m.statusLabel.customY = height * 0.55
    m.statusLabel.setText("Last audio event: (none yet)")
    m.game.gameUi.addChild(m.statusLabel)

    m.updateLabels()
  end sub

  override sub onChangeRoom(newRoom as BGE.Room)
    m.game.gameUi.removeChild(m.infoLabel)
    m.game.gameUi.removeChild(m.rowSelect)
    m.game.gameUi.removeChild(m.volumeSlider)
    m.game.gameUi.removeChild(m.statusLabel)
  end sub

  ' OK/Left/Right on the row picker and slider are handled by BGE.UI's own
  ' focus/cursor system (Select.onInput/Slider.onInput adjust; UiContainer
  ' routes OK-while-focused to onClick(), which AudioRowSelect/AudioVolumeSlider
  ' route back to playFocused() below) - this room's own onInput only sees
  ' whatever those widgets don't consume: Up/Down (cursor movement, never
  ' consumed) and Options/Rewind/Back (neither widget's onInput touches them).
  override sub onInput(input as BGE.GameInput)
    if not input.press
      return
    end if

    if input.isButton("options")
      if m.rowSelect.getValue() = "Music"
        m.loopMusic = not m.loopMusic
        m.updateLabels()
      end if
    else if input.isButton("rewind")
      if m.rowSelect.getValue() = "Music"
        m.game.musicStop()
        m.musicState = "stopped"
        m.updateLabels()
      end if
    else if input.isButton("back")
      m.game.End()
    end if
  end sub

  ' Reacts to roAudioPlayerEvent - fired for the music track (Game.Sounds/playSound
  ' one-shots don't generate onAudioEvent callbacks, only the music player does).
  override sub onAudioEvent(msg as roAudioPlayerEvent)
    eventName = "unknown"
    if msg.isFullResult()
      eventName = "finished"
    else if msg.isPartialResult()
      eventName = "interrupted"
    else if msg.isPaused()
      eventName = "paused"
    else if msg.isResumed()
      eventName = "resumed"
    else if msg.isRequestFailed()
      eventName = "failed"
    else if msg.isRequestSucceeded()
      eventName = "succeeded"
    else if msg.isListItemSelected()
      eventName = "started"
    else if msg.isStatusMessage()
      eventName = "status"
    end if

    m.statusLabel.setText(`Last audio event: "${eventName}"`)
    if msg.isFullResult() and not m.loopMusic
      m.musicState = "stopped"
      m.updateLabels()
    end if
  end sub

  ' Public - called from AudioRowSelect/AudioVolumeSlider's onClick() override,
  ' since UiContainer routes OK-while-focused to the focused widget's onClick(),
  ' not to this room's own onInput() (see the class doc comment above).
  sub playFocused()
    if m.rowSelect.getValue() = "Music"
      if m.musicState = "stopped"
        m.game.musicPlay("pkg:/sounds/ambient.mp3", m.loopMusic)
        m.musicState = "playing"
      else if m.musicState = "playing"
        m.game.musicPause()
        m.musicState = "paused"
      else
        m.game.musicResume()
        m.musicState = "playing"
      end if
    else
      m.game.playSound("bell", cint(m.sfxVolume))
    end if
    m.updateLabels()
  end sub

  ' Public - called from AudioRowSelect.onChanged (row cycling) as well as
  ' this room's own onInput() and onAudioEvent().
  sub updateLabels()
    m.sfxVolume = m.volumeSlider.getValue()
    if m.rowSelect.getValue() = "Sound Effect"
      m.volumeSlider.setLabel(`Sound Effect Volume: ${cint(m.volumeSlider.getValue())}`)
    else
      m.volumeSlider.setLabel("(roAudioPlayer has no volume control - only the sound effect's does)")
    end if
    m.infoLabel.setText("Audio Example" + Chr(10) +
      "Up/Down: move cursor   Left/Right: change row / adjust volume   OK: play/pause" + Chr(10) +
      "Options: toggle music loop   Rewind: stop music   Back: quit" + Chr(10) +
      `Row: ${m.rowSelect.getValue()}   Music: ${m.musicState} (loop ${m.loopMusic})`)
  end sub

end class

' Routes OK-press-while-focused (UiContainer's onClick() dispatch) back to
' the owning room's playFocused() - Select has no built-in activate callback
' the way Button/Checkbox do, so this example subclasses it instead.
class AudioRowSelect extends BGE.UI.Select
  room as MainRoom

  sub new(game as BGE.Game)
    super(game)
  end sub

  override sub onClick()
    m.room.playFocused()
  end sub
end class

' Same reasoning as AudioRowSelect - Slider has no built-in activate callback.
class AudioVolumeSlider extends BGE.UI.Slider
  room as MainRoom

  sub new(game as BGE.Game)
    super(game)
  end sub

  override sub onClick()
    m.room.playFocused()
  end sub
end class
```

- [ ] **Step 2: Sideload and verify manually via `rokubot`**

Follow the `rokubot-examples` skill to sideload `examples/audio`, then:
1. Launch the example and confirm the cursor starts on the row picker.
2. Press Left/Right on the row picker — confirm it cycles "Music"/"Sound Effect" and the info label updates live.
3. Press Up/Down to move the cursor to the volume slider — confirm it focuses (visual ring) and Left/Right adjusts it and updates the label.
4. Press OK on each row — confirm music/sound playback still works as before (via `AudioRowSelect`/`AudioVolumeSlider.onClick()` → `playFocused()`).
5. Confirm Options/Rewind/Back still work as documented.

- [ ] **Step 3: Run example validation**

Run: `cd examples/audio && npm run build && cd ../.. `
Expected: builds cleanly.

- [ ] **Step 4: Commit**

```bash
git add examples/audio/src/source/Rooms/MainRoom.bs
git commit -m "refactor(examples/audio): use BGE.UI focus/cursor system instead of hand-rolled focusIndex"
```

---

## Task 15: File follow-up issues

- [ ] **Step 1: File the four follow-up issues identified in the spec's "Non-goals" section**

```bash
gh issue create --title "Text input widget for BGE.UI (cursor position, ECP keyboard capture)" --body "Follow-up to #133 / specs/2026-08-30-ui-focus-cursor-theme-design.md. Needs real keyboard capture and cursor-position tracking - substantially different plumbing than the other focusable widgets (Button/Checkbox/Select/Slider), which is why it was scoped out of that pass."

gh issue create --title "9-patch / image-backed widget backgrounds for BGE.UI" --body "Follow-up to #133 / specs/2026-08-30-ui-focus-cursor-theme-design.md. Theme.backgroundColor/borderColor are flat-color only today; add a 9-patch or general image background option (e.g. Theme.background as a Drawable/NinePatchImage) without breaking the existing flat-color API."

gh issue create --title "Expanding/popup list style for BGE.UI.Select" --body "Follow-up to #133 / specs/2026-08-30-ui-focus-cursor-theme-design.md. BGE.UI.Select currently only supports inline cycling (Left/Right steps through options, matching Slider's interaction style). A full expanding/popup list is a natural follow-up for menus with many options."

gh issue create --title "Analog-stick/controller-driven virtual cursor movement for BGE.UI" --body "Follow-up to #133 / specs/2026-08-30-ui-focus-cursor-theme-design.md. UiContainer.cursorPosition is currently driven by d-pad press/held only. Once #149 (external controller support) lands, feed continuous analog input into the same cursorPosition field for finer-grained cursor movement."
```

- [ ] **Step 2: No commit needed** (this task only files GitHub issues, no repo changes)

---

## Final Verification

- [ ] Run the full local quality gate: `npm run check` (lint + validate + headless tests)
- [ ] Run `npm run check:all` to also validate every example project
- [ ] Confirm `examples/audio` was manually verified via `rokubot` (Task 14, Step 2)
- [ ] Review the diff for the game-loop reorder (Task 3) once more against `CLAUDE.md`'s updated description (Task 13) to confirm they match exactly
