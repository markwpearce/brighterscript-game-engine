# Popup/Expanding Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an expanding/popup list interaction style to `BGE.UI.Select`, alongside its existing inline Left/Right-cycling style, without changing default behavior for any existing consumer.

**Architecture:** `Select.style` (new `BGE.UI.SelectStyle` enum, default `inline`) switches its `onClick()`/`handleInput()` behavior; a new general-purpose `UiWidget.drawOverlay()` hook (empty by default, called once per frame by `FocusManager.draw()` for whichever widget is currently focused) lets the popup list render above every other widget regardless of container z-order, without any `Select`-specific code in `Game.bs`.

**Tech Stack:** BrighterScript, Rooibos.

**Spec:** `specs/2026-09-04-ui-followups-design.md` (section 3). Depends on `examples/ui` (scaffolded in `specs/2026-09-04-analog-cursor-plan.md`, Task 1) and, if run before that plan lands, scaffold it here instead.

## Global Constraints

- One `@suite` class per `*.spec.bs` file.
- `assertEqual` is type-strict.
- Guard every discrete/one-shot input check with `input.press` (CLAUDE.md's press/release double-fire gotcha) - this matters a lot here since popup-Select's OK/back handling is exactly this kind of one-shot action.
- `npm run validate` after engine changes; `npm run check` before done.

---

### Task 1: `UiWidget.drawOverlay()` hook + `FocusManager` wiring

**Files:**
- Modify: `src/source/engine/ui/UiWidget.bs`
- Modify: `src/source/engine/ui/FocusManager.bs` (its existing `draw()` method)
- Test: `src/source/engine/ui/FocusManager.spec.bs`

**Interfaces:**
- Produces: `UiWidget.drawOverlay(canvas as BGE.Canvas, theme as BGE.UI.Theme) as void` (empty base implementation) - consumed by Task 3's popup `Select`, and reusable by any future overlay widget.
- Consumes: `FocusManager.currentlyFocused` (already exists, currently `protected` - confirm whether `draw()` (same class) already has access; it does, no visibility change needed).

- [ ] **Step 1: Write the failing test — drawOverlay is called for the focused widget**

```brightscript
' FocusManager.spec.bs - add to the existing suite. Uses a tiny test double
' widget subclass to record whether drawOverlay() was invoked, since
' UiWidget's own drawOverlay() is a no-op by design.
@it("draw() calls drawOverlay() on the currently focused widget")
function _()
  container = m.game.gameUi
  probe = new tests.OverlayProbeWidget(m.game)
  probe.focusable = true
  container.addChild(probe)

  m.game.focusManager.update(new BGE.GameInput(2, 0)) ' seeds focus in list mode
  m.game.focusManager.draw(m.game.uiCanvas, m.game.defaultTheme)

  m.assertEqual(true, probe.overlayDrawn)
end function
```

Add a small test-double class in the same spec file (BrighterScript allows a plain non-`@suite` helper class in a spec file - confirm this against the existing test suite conventions; if the codebase's Rooibos setup disallows non-suite classes in a `*.spec.bs` file, put `OverlayProbeWidget` in a separate non-spec test-helper `.bs` file instead, e.g. `src/source/engine/ui/testHelpers/OverlayProbeWidget.bs`, and import it):

```brightscript
namespace tests
  class OverlayProbeWidget extends BGE.UI.UiWidget
    overlayDrawn as boolean = false
    override sub drawOverlay(canvas as BGE.Canvas, theme as BGE.UI.Theme)
      m.overlayDrawn = true
    end sub
  end class
end namespace
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `drawOverlay` isn't called anywhere yet (or doesn't exist as an overridable method, depending on how BrighterScript treats the override before the base declares it - confirm the actual error).

- [ ] **Step 3: Add the hook to UiWidget and wire FocusManager.draw()**

In `src/source/engine/ui/UiWidget.bs`, near `onFocus`/`onBlur`:

```brightscript
' Called once per frame, for whichever widget currently has focus, by
' BGE.UI.FocusManager.draw() - AFTER the whole gameUi tree has drawn, so
' this always renders above every other widget regardless of container
' z-order/nesting. Override to draw content that must float above
' everything else, e.g. Select's popup option list (see BGE.UI.Select).
' Empty by default - most widgets don't need this.
'
' @param {BGE.Canvas} canvas
' @param {BGE.UI.Theme} theme
' @return {void}
sub drawOverlay(canvas as BGE.Canvas, theme as BGE.UI.Theme)
end sub
```

In `src/source/engine/ui/FocusManager.bs`'s existing `draw()`:

```brightscript
sub draw(canvas as BGE.Canvas, theme as BGE.UI.Theme)
  if m.currentlyFocused <> invalid and m.currentlyFocused.isValid()
    m.currentlyFocused.drawOverlay(canvas, theme)
  end if
  if m.navigationMode <> BGE.UI.FocusNavigationMode.pointer or m.focusOrder.count() = 0
    return
  end if
  canvas.renderer.drawRectangle(m.cursorPosition.x - theme.cursorSize / 2, m.cursorPosition.y - theme.cursorSize / 2, theme.cursorSize, theme.cursorSize, theme.cursorColor)
end sub
```

(`drawOverlay` fires in both `list` and `pointer` navigation modes - it's independent of the cursor-drawing branch below it, which stays pointer-mode-only exactly as before.)

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/UiWidget.bs src/source/engine/ui/FocusManager.bs src/source/engine/ui/FocusManager.spec.bs
git commit -m "feat: add UiWidget.drawOverlay(), called for the focused widget each frame"
```

---

### Task 2: `Select.style` field + popup expand/collapse state (no drawing yet)

**Files:**
- Modify: `src/source/engine/ui/Select.bs`
- Test: `src/source/engine/ui/Select.spec.bs`

**Interfaces:**
- Produces: `enum BGE.UI.SelectStyle { inline = "inline", popup = "popup" }`, `Select.style as BGE.UI.SelectStyle = BGE.UI.SelectStyle.inline`, `Select.expanded as boolean = false`, `Select.highlightedIndex as integer = 0`.
- Consumes: existing `Select.selectedIndex`, `.options`, `.onChanged`, `RepeatThrottle` (`Style.bs`).

- [ ] **Step 1: Write the failing test — onClick() expands only in popup style**

```brightscript
' Select.spec.bs - add to the existing suite
@it("onClick does nothing in inline style (default)")
function _()
  select = new BGE.UI.Select(m.game)
  select.onClick()
  m.assertEqual(false, select.expanded)
end function

@it("onClick expands in popup style and seeds highlightedIndex from selectedIndex")
function _()
  select = new BGE.UI.Select(m.game)
  select.style = BGE.UI.SelectStyle.popup
  select.options = ["a", "b", "c"]
  select.selectedIndex = 2
  select.onClick()
  m.assertEqual(true, select.expanded)
  m.assertEqual(2, select.highlightedIndex)
end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `style`/`expanded`/`highlightedIndex` don't exist.

- [ ] **Step 3: Implement**

At the top of `Select.bs` (or a shared enum location if `Style.bs` is where other `BGE.UI` enums live - check `grep -n "^  enum" src/source/engine/ui/*.bs` first and match that file's convention):

```brightscript
' Select's interaction style. inline (default): Left/Right cycle the
' current option in place, matching Slider's interaction pattern. popup:
' OK expands a list of every option; Up/Down move a highlight, OK commits,
' back cancels. See Select.style.
enum SelectStyle
  inline = "inline"
  popup = "popup"
end enum
```

In `Select` class:

```brightscript
' Which interaction style this Select uses - see BGE.UI.SelectStyle.
' Defaults to inline (Left/Right cycling), matching this widget's original
' (and only) behavior - popup is opt-in, not a breaking change.
style as BGE.UI.SelectStyle = BGE.UI.SelectStyle.inline

' popup style only: is the option list currently expanded?
expanded as boolean = false
' popup style only: index within m.options currently highlighted while expanded.
highlightedIndex as integer = 0
```

```brightscript
override sub onClick()
  if m.style <> BGE.UI.SelectStyle.popup
    return
  end if
  m.highlightedIndex = m.selectedIndex
  m.expanded = true
end sub
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

```bash
git add src/source/engine/ui/Select.bs src/source/engine/ui/Select.spec.bs
git commit -m "feat: Select.style + popup expand/collapse state"
```

---

### Task 3: Popup input handling — Up/Down highlight, OK commits, back cancels

**Files:**
- Modify: `src/source/engine/ui/Select.bs`
- Test: `src/source/engine/ui/Select.spec.bs`

**Interfaces:**
- Consumes: existing `RepeatThrottle.shouldAct(input)`, `BGE.Math.Clamp` (used elsewhere in `FocusManager.navigateList` - `import "../../math/math.bs"` if not already imported).
- Produces: extended `Select.handleInput(input as BGE.GameInput) as boolean` covering the popup-expanded case.

- [ ] **Step 1: Write the failing tests**

```brightscript
@it("popup style: down moves highlightedIndex while expanded, without changing selectedIndex")
function _()
  select = new BGE.UI.Select(m.game)
  select.style = BGE.UI.SelectStyle.popup
  select.options = ["a", "b", "c"]
  select.expanded = true
  select.highlightedIndex = 0

  select.handleInput(new BGE.GameInput(3, 0)) ' down, press

  m.assertEqual(1, select.highlightedIndex)
  m.assertEqual(0, select.selectedIndex)
end function

@it("popup style: OK commits highlightedIndex to selectedIndex and collapses")
function _()
  select = new BGE.UI.Select(m.game)
  select.style = BGE.UI.SelectStyle.popup
  select.options = ["a", "b", "c"]
  select.expanded = true
  select.highlightedIndex = 2
  changedCalledWith = invalid
  select.onChanged = sub(s as BGE.UI.Select)
    changedCalledWith = s.selectedIndex
  end sub

  handled = select.handleInput(new BGE.GameInput(6, 0)) ' OK, press

  m.assertEqual(true, handled)
  m.assertEqual(2, select.selectedIndex)
  m.assertEqual(false, select.expanded)
  m.assertEqual(2, changedCalledWith)
end function

@it("popup style: back cancels without changing selectedIndex")
function _()
  select = new BGE.UI.Select(m.game)
  select.style = BGE.UI.SelectStyle.popup
  select.options = ["a", "b", "c"]
  select.selectedIndex = 0
  select.expanded = true
  select.highlightedIndex = 2

  handled = select.handleInput(new BGE.GameInput(0, 0)) ' back, press

  m.assertEqual(true, handled)
  m.assertEqual(0, select.selectedIndex)
  m.assertEqual(false, select.expanded)
end function

@it("popup style: left/right do nothing while collapsed (inline cycling disabled)")
function _()
  select = new BGE.UI.Select(m.game)
  select.style = BGE.UI.SelectStyle.popup
  select.options = ["a", "b", "c"]
  select.selectedIndex = 0

  handled = select.handleInput(new BGE.GameInput(5, 0)) ' right, press

  m.assertEqual(false, handled)
  m.assertEqual(0, select.selectedIndex)
end function
```

Confirm the exact button codes (0=back, 2=up, 3=down, 4=left, 5=right, 6=OK) against `GameInput`'s doc comment table before running - copy them from `GameInput.bs`'s own `@example` block rather than retyping from memory.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 3: Implement**

Replace `Select.handleInput` with a version that branches on `m.style`/`m.expanded` first, falling through to the existing inline-cycling body only for `style = inline`:

```brightscript
override function handleInput(input as BGE.GameInput) as boolean
  if not (input.press or input.held or input.release)
    return false
  end if

  if m.style = BGE.UI.SelectStyle.popup
    return m.handlePopupInput(input)
  end if

  if not (input.press or input.held)
    return false
  end if
  if not (input.isButton("left") or input.isButton("right"))
    return false
  end if

  if m.repeatThrottle.shouldAct(input)
    if input.isButton("right")
      m.next()
    else
      m.previous()
    end if
  end if

  input.consume()
  return true
end function

' popup style only: called from handleInput() while m.expanded. Up/Down move
' the highlight (throttled like the inline style's own Left/Right), OK
' commits highlightedIndex to selectedIndex (firing onChanged) and
' collapses, back cancels and collapses without changing selectedIndex.
' Returns false (unhandled) once not expanded, so FocusManager falls back
' to normal focus navigation for this Select.
'
' @param {BGE.GameInput} input
' @return {boolean}
private function handlePopupInput(input as BGE.GameInput) as boolean
  if not m.expanded
    return false
  end if

  if input.press and input.isButton("back")
    m.expanded = false
    input.consume()
    return true
  end if

  if input.press and input.isButton("ok")
    m.selectedIndex = m.highlightedIndex
    m.expanded = false
    if m.onChanged <> invalid
      m.onChanged(m)
    end if
    input.consume()
    return true
  end if

  if (input.press or input.held) and (input.isButton("up") or input.isButton("down"))
    if m.repeatThrottle.shouldAct(input) and m.options.count() > 0
      if input.isButton("down")
        m.highlightedIndex = BGE.Math.Clamp(m.highlightedIndex + 1, 0, m.options.count() - 1)
      else
        m.highlightedIndex = BGE.Math.Clamp(m.highlightedIndex - 1, 0, m.options.count() - 1)
      end if
    end if
    input.consume()
    return true
  end if

  return false
end function
```

Note: `FocusManager.update()` already special-cases OK-press to call `onMouseDown()`/`onClick()` directly and never forwards OK to `handleInput()` at all (see `FocusManager.bs`'s `update()`) - so the OK-commit branch above is actually unreachable through the normal `FocusManager` path once `m.expanded` is already `true` from a *previous* OK press, since `FocusManager` doesn't re-check `handleInput` for OK. Before writing this test as passing, re-read `FocusManager.update()`'s exact branching (`if input.press and input.isButton("ok") ... else if input.release ... else handled = m.currentlyFocused.handleInput(input)`) and resolve this: OK-commit must be handled in `Select.onClick()` on the *second* OK press instead (toggle: first click while `not expanded` expands; second click while `expanded` commits `highlightedIndex` and collapses). Adjust `onClick()` accordingly:

```brightscript
override sub onClick()
  if m.style <> BGE.UI.SelectStyle.popup
    return
  end if
  if m.expanded
    m.selectedIndex = m.highlightedIndex
    m.expanded = false
    if m.onChanged <> invalid
      m.onChanged(m)
    end if
  else
    m.highlightedIndex = m.selectedIndex
    m.expanded = true
  end if
end sub
```

...and remove the OK-handling branch from `handlePopupInput` entirely (dead code per the analysis above) - update Task 3's Step 1 test for "OK commits" to call `select.onClick()` a second time instead of `handleInput()` with an OK `GameInput`, and re-verify against `FocusManager.spec.bs`'s existing OK-press test pattern for the exact call shape expected. **This is exactly the kind of design-vs-actual-code mismatch this plan's steps are meant to catch before merge - treat the correction above as authoritative over the earlier draft in this same task**, and update the design doc's section 3 with a one-line correction note once this is confirmed working end-to-end.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`
Expected: PASS once the OK-handling correction above is applied.

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/Select.bs src/source/engine/ui/Select.spec.bs specs/2026-09-04-ui-followups-design.md
git commit -m "feat: popup Select input handling (up/down highlight, OK expand/commit, back cancel)"
```

---

### Task 4: Popup drawing via `drawOverlay()`

**Files:**
- Modify: `src/source/engine/ui/Select.bs` (`draw()` and new `drawOverlay()`)
- Test: `src/source/engine/ui/Select.spec.bs`

**Interfaces:**
- Consumes: `UiWidget.drawOverlay()` (Task 1), `m.resolveTheme(parent)`, `BGE.DrawableText` (existing pattern from `draw()`).

- [ ] **Step 1: Write the failing test — drawOverlay() is a no-op unless expanded**

```brightscript
@it("drawOverlay does not throw when collapsed or not popup style")
function _()
  select = new BGE.UI.Select(m.game)
  select.width = 80
  select.height = 30
  select.position = BGE.Math.VectorOps.create(0, 0)
  select.drawOverlay(m.game.uiCanvas, m.game.defaultTheme) ' must not throw, style=inline
  select.style = BGE.UI.SelectStyle.popup
  select.drawOverlay(m.game.uiCanvas, m.game.defaultTheme) ' must not throw, not expanded
end function

@it("drawOverlay draws one row per option when expanded")
function _()
  select = new BGE.UI.Select(m.game)
  select.style = BGE.UI.SelectStyle.popup
  select.options = ["a", "b", "c"]
  select.width = 80
  select.height = 30
  select.position = BGE.Math.VectorOps.create(0, 0)
  select.expanded = true
  select.drawOverlay(m.game.uiCanvas, m.game.defaultTheme) ' must not throw
end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `drawOverlay` not overridden yet (base no-op "passes" trivially, so confirm the second test would actually exercise new code by checking coverage manually, or add an assertion on a row-count field, e.g. a `getLastDrawnRowCount()` test accessor incremented in `drawOverlay()`, to make the red/green distinction real).

- [ ] **Step 3: Implement**

```brightscript
override sub drawOverlay(canvas as BGE.Canvas, theme as BGE.UI.Theme)
  if m.style <> BGE.UI.SelectStyle.popup or not m.expanded
    return
  end if

  rowHeight = m.height
  for i = 0 to m.options.count() - 1
    rowY = m.position.y + m.height + i * rowHeight
    bg = theme.backgroundColor
    if i = m.highlightedIndex
      bg = theme.hoveredBackgroundColor
    end if
    canvas.renderer.drawRectangle(m.position.x, rowY, m.width, rowHeight, bg)

    m.drawableText.text = m.options[i].ToStr()
    textImage = m.drawableText.getTextImage()
    if textImage <> invalid
      textSize = m.drawableText.getDrawnSize()
      textX = m.position.x + (m.width - textSize.width) / 2
      textY = rowY + (rowHeight - textSize.height) / 2
      canvas.renderer.drawTransformedObject(textX, textY, 1.0, 1.0, 0, textImage)
    end if
  end for
  canvas.renderer.drawRectangleOutline(m.position.x, m.position.y + m.height, m.width, rowHeight * m.options.count(), theme.focusedBorderColor)
end sub
```

Note the explicit non-goal from the design doc: this draws every option unclipped, so a list overflowing the canvas bottom is a known limitation, not a bug - do not add scrolling/clipping here.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/Select.bs src/source/engine/ui/Select.spec.bs
git commit -m "feat: Select popup list draws via drawOverlay()"
```

---

### Task 5: `examples/ui` demo room + on-device verification

**Files:**
- Create: `examples/ui/src/source/Rooms/PopupSelectRoom.bs`
- Modify: `examples/ui/src/source/main.bs`

- [ ] **Step 1: Scaffold and build**

Run: `npm run create-room -- ui PopupSelectRoom`

In `onCreate()`: add one inline-style `Select` and one popup-style `Select` (5+ options each, e.g. difficulty levels or colors) side by side, with labels distinguishing them, plus a Back handler.

- [ ] **Step 2: Register in main.bs**

Same pattern as prior rooms.

- [ ] **Step 3: Sideload and verify**

Per `rokubot-examples`: sideload, launch, navigate to `PopupSelectRoom`. Drive the popup Select: OK to expand, Up/Down to move highlight, OK to commit, and separately OK-then-back to confirm cancel leaves the original selection. Screenshot each state (collapsed, expanded, after commit).

- [ ] **Step 4: Commit**

```bash
git add examples/ui
git commit -m "feat: add PopupSelectRoom demo to examples/ui"
```

---

### Task 6: Docs + issue close-out

**Files:**
- Modify: `docs/engine-internals.md` or `docs/game-engine-overview.md`

- [ ] **Step 1: Document `Select.style`, `drawOverlay()`, and the popup interaction model**
- [ ] **Step 2: `npm run docs`**

Run: `npm run docs`

- [ ] **Step 3: Final check**

Run: `npm run check`

- [ ] **Step 4: Commit and open the PR**

```bash
git add docs/
git commit -m "docs: document popup Select and UiWidget.drawOverlay()"
```

Push and open a PR closing #181.
