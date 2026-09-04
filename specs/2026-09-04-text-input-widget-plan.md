# Text Input Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A focusable `BGE.UI.TextInput` widget: cursor-position tracking, ECP-keyboard-driven character entry/backspace, Left/Right cursor movement.

**Architecture:** `TextInput extends UiWidget`, overriding `onECPKeyboard(char)` to insert/delete at `cursorIndex`, and `handleInput()` to move `cursorIndex` on Left/Right (consumed, same pattern as `Select`'s Left/Right cycling). The ECP-keyboard broadcast plumbing (`Game.bs` → `UiContainer.onECPKeyboard` → every child) already exists end-to-end from #133's pass - this widget requires **no `Game.bs`/`UiContainer.bs` changes**, only a new widget class.

**Tech Stack:** BrighterScript, Rooibos, `roFont.GetOneLineWidth()`.

**Spec:** `specs/2026-09-04-ui-followups-design.md` (section 4). Depends on `examples/ui` (scaffolded in `specs/2026-09-04-analog-cursor-plan.md`, Task 1). Run last of the four sibling plans.

## Global Constraints

- One `@suite` class per `*.spec.bs` file.
- `assertEqual` is type-strict.
- `npm run validate` after engine changes; `npm run check` before done.
- New public methods get JSDoc-style `'` doc comments.

---

### Task 1: `TextInput` skeleton — construction, `text`/`cursorIndex` fields, `getValue()`

**Files:**
- Create: `src/source/engine/ui/TextInput.bs`
- Test: `src/source/engine/ui/TextInput.spec.bs`

**Interfaces:**
- Produces: `BGE.UI.TextInput.new(game as BGE.Game)`, fields `text as string = ""`, `cursorIndex as integer = 0`, `maxLength as integer = 0`, `placeholder as string = ""`, `onChanged as function or dynamic`, `onSubmit as function or dynamic`, `override function getValue() as dynamic` (returns `m.text`).

- [ ] **Step 1: Write the failing test**

```brightscript
' src/source/engine/ui/TextInput.spec.bs
import "pkg:/source/engine/ui/TextInput.bs"

namespace tests
  @suite("TextInput")
  class TextInputTest extends BaseTestSuite

    @beforeEach
    sub before()
      m.game = new BGE.Game({width: 400, height: 400}, {width: 400, height: 400})
    end sub

    @it("constructs focusable with empty text")
    function _()
      input = new BGE.UI.TextInput(m.game)
      m.assertEqual(true, input.focusable)
      m.assertEqual("", input.text)
      m.assertEqual(0, input.cursorIndex)
    end function

    @it("getValue returns the current text")
    function _()
      input = new BGE.UI.TextInput(m.game)
      input.text = "hello"
      m.assertEqual("hello", input.getValue())
    end function

  end class
end namespace
```

Check an existing widget spec (`Select.spec.bs` or `Button.spec.bs`) for the exact `@beforeEach`/`BaseTestSuite`/`Game` construction pattern and `import`s this codebase actually uses, and match it exactly rather than guessing constructor args.

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — class doesn't exist.

- [ ] **Step 3: Implement the skeleton**

```brightscript
' src/source/engine/ui/TextInput.bs
import "../drawables/DrawableText.bs"
import "../Game.bs"
import "../GameInput.bs"
import "Style.bs"
import "UiWidget.bs"

namespace BGE.UI

  ' A focusable single-line text entry widget. Characters arrive via
  ' onECPKeyboard() (Roku's mobile-app on-screen keyboard sends individual
  ' characters this way - see Game.bs's existing onECPKeyboard dispatch,
  ' which already reaches every UiContainer child unconditionally, same as
  ' onInput()). Left/Right (while focused) move the caret; OK fires
  ' onSubmit. No on-screen virtual keyboard is drawn by this widget - it
  ' relies entirely on the platform's own text-entry mechanism delivering
  ' onECPKeyboard() characters.
  class TextInput extends UiWidget

    ' Current text content.
    text as string = ""
    ' Caret position, 0..Len(text). Moved by Left/Right while focused, and
    ' advances/retreats as characters are inserted/deleted.
    cursorIndex as integer = 0
    ' Maximum text length, 0 = unlimited. A character typed once text.Len()
    ' already equals maxLength is silently dropped.
    maxLength as integer = 0
    ' Text shown (dimmed) when text is empty and this widget isn't focused.
    placeholder as string = ""

    ' Called after any edit (insert/delete) - function(input as TextInput) as void
    onChanged as function or dynamic
    ' Called on OK-press while focused - function(input as TextInput) as void
    onSubmit as function or dynamic

    drawableText as BGE.DrawableText

    sub new(game as BGE.Game)
      super(game)
      m.focusable = true
      m.drawableText = new BGE.DrawableText(m)
    end sub

    ' Gets the current text content.
    '
    ' @return {dynamic} - the current text (string)
    override function getValue() as dynamic
      return m.text
    end function

  end class

end namespace
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/TextInput.bs src/source/engine/ui/TextInput.spec.bs
git commit -m "feat: add BGE.UI.TextInput skeleton"
```

---

### Task 2: `onECPKeyboard` — insert and backspace

**Files:**
- Modify: `src/source/engine/ui/TextInput.bs`
- Test: `src/source/engine/ui/TextInput.spec.bs`

**Interfaces:**
- Produces: `override sub onECPKeyboard(char as integer)`.

- [ ] **Step 1: Write the failing tests**

```brightscript
@it("onECPKeyboard inserts a printable character at cursorIndex when focused")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.focused = true
  input.text = "ac"
  input.cursorIndex = 1
  input.onECPKeyboard(98) ' 'b'
  m.assertEqual("abc", input.text)
  m.assertEqual(2, input.cursorIndex)
end function

@it("onECPKeyboard does nothing when not focused")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.focused = false
  input.text = "ac"
  input.cursorIndex = 1
  input.onECPKeyboard(98)
  m.assertEqual("ac", input.text)
end function

@it("onECPKeyboard char 8 (backspace) deletes the character before cursorIndex")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.focused = true
  input.text = "abc"
  input.cursorIndex = 2
  input.onECPKeyboard(8)
  m.assertEqual("ac", input.text)
  m.assertEqual(1, input.cursorIndex)
end function

@it("onECPKeyboard backspace at cursorIndex 0 does nothing")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.focused = true
  input.text = "abc"
  input.cursorIndex = 0
  input.onECPKeyboard(8)
  m.assertEqual("abc", input.text)
  m.assertEqual(0, input.cursorIndex)
end function

@it("onECPKeyboard drops a printable character once maxLength is reached")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.focused = true
  input.maxLength = 2
  input.text = "ab"
  input.cursorIndex = 2
  input.onECPKeyboard(99) ' 'c'
  m.assertEqual("ab", input.text)
end function

@it("onECPKeyboard fires onChanged on a successful insert")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.focused = true
  calledWith = invalid
  input.onChanged = sub(t as BGE.UI.TextInput)
    calledWith = t.text
  end sub
  input.onECPKeyboard(97) ' 'a'
  m.assertEqual("a", calledWith)
end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `onECPKeyboard` not overridden (base `GameEntity.onECPKeyboard` is a no-op).

- [ ] **Step 3: Implement**

```brightscript
override sub onECPKeyboard(char as integer)
  if not m.focused
    return
  end if

  if char = 8 ' backspace (ASCII BS)
    if m.cursorIndex > 0
      m.text = Left(m.text, m.cursorIndex - 1) + Mid(m.text, m.cursorIndex + 1)
      m.cursorIndex--
      m.fireChanged()
    end if
    return
  end if

  if m.maxLength > 0 and Len(m.text) >= m.maxLength
    return
  end if

  m.text = Left(m.text, m.cursorIndex) + Chr(char) + Mid(m.text, m.cursorIndex + 1)
  m.cursorIndex++
  m.fireChanged()
end sub

private sub fireChanged()
  if m.onChanged <> invalid
    m.onChanged(m)
  end if
end sub
```

Confirm `Mid(m.text, m.cursorIndex + 1)` (1-indexed `Mid`) returns the correct tail substring for BrighterScript's actual `Mid` semantics before trusting this - check an existing usage of `Mid()` elsewhere in the engine (`grep -rn "Mid(" src/source/`) for the indexing convention this codebase already relies on, and adjust the `+1`/no-`+1` offset to match if it differs from standard BrightScript `Mid(s, startPos As Integer)` (1-based start).

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/TextInput.bs src/source/engine/ui/TextInput.spec.bs
git commit -m "feat: TextInput.onECPKeyboard() inserts/deletes at the caret"
```

---

### Task 3: `handleInput()` — Left/Right move the caret

**Files:**
- Modify: `src/source/engine/ui/TextInput.bs`
- Test: `src/source/engine/ui/TextInput.spec.bs`

**Interfaces:**
- Produces: `override function handleInput(input as BGE.GameInput) as boolean`.
- Consumes: existing `RepeatThrottle` (`Style.bs`) for repeat-while-held, matching `Select`'s convention exactly.

- [ ] **Step 1: Write the failing tests**

```brightscript
@it("right moves cursorIndex forward, clamped to text length, and consumes")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.text = "abc"
  input.cursorIndex = 3
  gameInput = new BGE.GameInput(5, 0) ' right, press
  handled = input.handleInput(gameInput)
  m.assertEqual(true, handled)
  m.assertEqual(true, gameInput.consumed)
  m.assertEqual(3, input.cursorIndex) ' already at end, clamped
end function

@it("left moves cursorIndex backward, clamped to 0")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.text = "abc"
  input.cursorIndex = 0
  gameInput = new BGE.GameInput(4, 0) ' left, press
  input.handleInput(gameInput)
  m.assertEqual(0, input.cursorIndex)
end function

@it("left/right return false and don't consume for other buttons")
function _()
  input = new BGE.UI.TextInput(m.game)
  gameInput = new BGE.GameInput(2, 0) ' up, press
  handled = input.handleInput(gameInput)
  m.assertEqual(false, handled)
  m.assertEqual(false, gameInput.consumed)
end function
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 3: Implement**

```brightscript
protected repeatThrottle as BGE.UI.RepeatThrottle = new BGE.UI.RepeatThrottle()

override function handleInput(input as BGE.GameInput) as boolean
  if not (input.press or input.held)
    return false
  end if
  if not (input.isButton("left") or input.isButton("right"))
    return false
  end if

  if m.repeatThrottle.shouldAct(input)
    if input.isButton("right")
      m.cursorIndex = BGE.Math.Clamp(m.cursorIndex + 1, 0, Len(m.text))
    else
      m.cursorIndex = BGE.Math.Clamp(m.cursorIndex - 1, 0, Len(m.text))
    end if
  end if

  input.consume()
  return true
end function

override sub onClick()
  if m.onSubmit <> invalid
    m.onSubmit(m)
  end if
end sub
```

(Add `protected repeatThrottle` as a class field, not inside a method - place it near `drawableText` in Task 1's skeleton, matching `Select.bs`'s existing field placement.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/TextInput.bs src/source/engine/ui/TextInput.spec.bs
git commit -m "feat: TextInput.handleInput() moves the caret with left/right"
```

---

### Task 4: `draw()` — text, caret, placeholder

**Files:**
- Modify: `src/source/engine/ui/TextInput.bs`
- Test: `src/source/engine/ui/TextInput.spec.bs`

**Interfaces:**
- Consumes: `m.resolveTheme(parent)`, `roFont.GetOneLineWidth(text, maxWidth) as integer` (`m.drawableText.font`), `Renderer.drawRectangle`/`drawTransformedObject` (existing pattern from `Select.draw()`/`Button.draw()`).

- [ ] **Step 1: Write the failing test — draw() doesn't throw in every state**

```brightscript
@it("draw does not throw when empty, focused, or with placeholder")
function _()
  input = new BGE.UI.TextInput(m.game)
  input.width = 120
  input.height = 30
  input.position = BGE.Math.VectorOps.create(0, 0)
  input.placeholder = "Enter name"
  input.draw() ' empty, unfocused - shows placeholder

  input.focused = true
  input.draw() ' empty, focused - shows caret at 0

  input.text = "hello"
  input.cursorIndex = 3
  input.draw() ' populated, focused - shows caret mid-string
end function
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run build-tests && npm run test:ci`
Expected: FAIL — `draw` isn't overridden (base `UiWidget.draw()` is a no-op, so this "fails" only in the sense of not exercising real code; confirm by temporarily asserting a call-count field, same trick as the popup-Select plan's Task 4, if you want a genuine red state here).

- [ ] **Step 3: Implement**

```brightscript
override sub draw(parent = invalid as UiWidget)
  if m.width <= 0 or m.height <= 0
    return
  end if

  theme = m.resolveTheme(parent)

  backgroundColor = theme.backgroundColor
  if m.focused
    m.canvas.renderer.drawRectangle(m.position.x - 2, m.position.y - 2, m.width + 4, m.height + 4, theme.focusedBorderColor)
  end if
  m.canvas.renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, backgroundColor)

  displayText = m.text
  textColor = theme.foregroundColor
  if displayText = "" and not m.focused and m.placeholder <> ""
    displayText = m.placeholder
    textColor = theme.disabledColor
  end if

  textX = m.position.x + 6 ' left-aligned with a small inset, unlike Button/Select's centered text
  textY = m.position.y + (m.height - m.drawableText.font.GetOneLineHeight()) / 2

  if displayText <> ""
    m.drawableText.text = displayText
    m.drawableText.textColor = textColor
    textImage = m.drawableText.getTextImage()
    if textImage <> invalid
      m.canvas.renderer.drawTransformedObject(textX, textY, 1.0, 1.0, 0, textImage)
    end if
  end if

  if m.focused
    caretX = textX + m.drawableText.font.GetOneLineWidth(Left(m.text, m.cursorIndex), 10000)
    m.canvas.renderer.drawRectangle(caretX, textY, 2, m.drawableText.font.GetOneLineHeight(), theme.foregroundColor)
  end if
end sub
```

Check `DrawableText`'s exact field name for its text color first (`grep -n "textColor\|color as integer" src/source/engine/drawables/DrawableText.bs`) - `textColor` above is a guess based on `Select`/`Button`'s convention; confirm and correct if the real field name differs.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run build-tests && npm run test:ci`

- [ ] **Step 5: Validate and commit**

Run: `npm run validate`

```bash
git add src/source/engine/ui/TextInput.bs src/source/engine/ui/TextInput.spec.bs
git commit -m "feat: TextInput.draw() renders text, caret, and placeholder"
```

---

### Task 5: `examples/ui` demo room + on-device verification

**Files:**
- Create: `examples/ui/src/source/Rooms/TextInputRoom.bs`
- Modify: `examples/ui/src/source/main.bs`

- [ ] **Step 1: Scaffold and build**

Run: `npm run create-room -- ui TextInputRoom`

In `onCreate()`: add one `TextInput` (with a placeholder like "Enter your name") plus a `Button` whose `onActivate` reads `textInput.getValue()` and displays it via a `Label`. Add a Back handler.

- [ ] **Step 2: Register in main.bs**

Same pattern as prior rooms.

- [ ] **Step 3: Sideload and verify — this is the critical on-device check for this plan**

Per `rokubot-examples`, and per CLAUDE.md's mandatory-on-device-verification rule (text entry via ECP keyboard is exactly the kind of platform behavior static analysis cannot confirm): sideload, launch, navigate to `TextInputRoom`, focus the `TextInput`. If `rokubot` supports sending ECP keyboard/character input (check the skill's docs for this - it may only support remote-button presses, in which case note in the PR description that character-entry verification requires the actual Roku mobile app's on-screen keyboard and ask the user to test manually, per the `feedback_no_realtime_game_play` convention). At minimum, confirm via `rokubot`: the widget renders (background, caret when focused, placeholder when not), Left/Right visibly move the caret if a starting value is pre-populated in `onCreate()` for test purposes, and the room doesn't crash on focus/blur.

- [ ] **Step 4: Commit**

```bash
git add examples/ui
git commit -m "feat: add TextInputRoom demo to examples/ui"
```

---

### Task 6: Docs + issue close-out

**Files:**
- Modify: `docs/engine-internals.md` or `docs/game-engine-overview.md`

- [ ] **Step 1: Document `TextInput`**

Cover: that it relies on the platform's own ECP-keyboard text entry (no virtual keyboard drawn by the engine), `maxLength`, `placeholder`, `onChanged`/`onSubmit`, and the backspace-is-char-8 detail (flag it explicitly as a documented assumption, since it's inferred from existing `onECPKeyboard` plumbing rather than tested against a real device keyboard in Task 2 - call this out as something to confirm during Task 5's on-device pass, and correct the doc/code together if char 8 turns out wrong on a real device).

- [ ] **Step 2: `npm run docs`**

Run: `npm run docs`

- [ ] **Step 3: Final check**

Run: `npm run check`

- [ ] **Step 4: Commit and open the PR**

```bash
git add docs/
git commit -m "docs: document TextInput widget"
```

Push and open a PR closing #179.
