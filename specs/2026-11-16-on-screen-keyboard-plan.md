# On-screen keyboard implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `BGE.UI.Keyboard`, a d-pad driven on-screen keyboard that types into a `BGE.UI.TextInput` (#288).

**Architecture:** `KeyboardLayout` holds pages of rows of keys and the highlighted-key cursor (pure, no drawing). `Keyboard` is one focusable `UiWidget` that consumes d-pad input so focus never leaves it, draws the current page and edits its target `TextInput` through new public edit methods. Spec: `specs/2026-11-16-on-screen-keyboard-design.md`.

**Tech Stack:** BrighterScript, Rooibos v6 (headless brs-cli), rokubot for device checks.

## Global Constraints

- No single-line `if`. Real types (no `as object`/`as dynamic` except where `invalid` must be allowed). `import` every file whose symbols you use.
- Never `=` two objects; compare ids/scalars. No `continue for` after an inner loop.
- `assertEqual` is type-strict (`1` ≠ `1.0`); widths are floats, indices integers.
- One `@suite` per spec file, `@describe` before the first `@it`.
- Button codes for `new BGE.GameInput(code, heldMs)`: back 0, up 2, down 3, left 4, right 5, OK 6, replay 7, rewind 8, fastforward 9, play 13. Add 100 for a release, 1000 for held.
- Run tests: `TEST_SHARDS=engine-ui npm run test:ci` (all `ui/` specs). Full gate: `npm run check`.
- Doc comments are for consumers; rationale in short inline comments.

---

### Task 1: TextInput public edit path and `editing` caret

**Files:**
- Modify: `src/source/engine/ui/TextInput.bs`
- Test: `src/source/engine/ui/TextInput.spec.bs`

**Interfaces:**
- Produces: `TextInput.insertChar(char as integer)`, `TextInput.deleteBeforeCursor()` (now public), `TextInput.submit()`, `TextInput.editing as boolean` (draw the caret while true even when unfocused).

- [ ] **Step 1: failing tests** (add a `@describe("public edit path")` block)

```brightscript
@it("insertChar inserts at the caret without focus")
function _()
  m.input.text = "ac"
  m.input.cursorIndex = 1
  m.input.insertChar(Asc("b"))
  m.assertEqual("abc", m.input.text)
  m.assertEqual(2, m.input.cursorIndex)
end function

@it("insertChar respects maxLength")
function _()
  m.input.maxLength = 2
  m.input.text = "ab"
  m.input.cursorIndex = 2
  m.input.insertChar(Asc("c"))
  m.assertEqual("ab", m.input.text)
end function

@it("deleteBeforeCursor deletes without focus")
function _()
  m.input.text = "abc"
  m.input.cursorIndex = 3
  m.input.deleteBeforeCursor()
  m.assertEqual("ab", m.input.text)
end function

@it("submit fires onSubmit")
function _()
  m.input.onSubmit = sub(input as BGE.UI.TextInput)
    input.lastChangedValue = "submitted"
  end sub
  m.input.submit()
  m.assertEqual("submitted", m.input.lastChangedValue)
end function
```

- [ ] **Step 2:** run, expect `cannot-find-function`/private-access errors.
- [ ] **Step 3: implement.** Add `editing as boolean = false` (doc: "true while an on-screen keyboard types into this; draws the caret even when unfocused"). Extract the insert half of `onECPKeyboard()` into:

```brightscript
' Inserts a character at the caret (dropped once maxLength is reached) and fires onChanged.
'
' @param {integer} char - character code
sub insertChar(char as integer)
  m.cursorIndex = m.clampCursorIndex(m.cursorIndex)
  if m.maxLength > 0 and Len(m.text) >= m.maxLength
    return
  end if
  m.text = Left(m.text, m.cursorIndex) + Chr(char) + Mid(m.text, m.cursorIndex + 1)
  m.cursorIndex++
  m.fireChanged()
end sub

' Fires onSubmit.
sub submit()
  if m.onSubmit <> invalid
    m.onSubmit(m)
  end if
end sub
```

`onECPKeyboard()` keeps its `focused` check, then `deleteBeforeCursor()` for char 8 else `insertChar(char)`. Make `deleteBeforeCursor()` public with a doc comment. `onClick()` calls `m.submit()`. In `draw()`, show the caret when `m.focused or m.editing`.
- [ ] **Step 4:** run, expect PASS.
- [ ] **Step 5:** commit `UI: public TextInput edit path for the on-screen keyboard (#288)`.

### Task 2: KeyboardLayout and built-in layouts

**Files:**
- Create: `src/source/engine/ui/KeyboardLayout.bs`
- Test: `src/source/engine/ui/KeyboardLayout.spec.bs`

**Interfaces:**
- Produces:
  - `enum KeyboardKeyKind`: `char = "char"`, `space = "space"`, `backspace = "backspace"`, `done = "done"`, `page = "page"`.
  - `class KeyboardKey`: `label as string`, `kind as KeyboardKeyKind`, `char as integer` (`char` keys), `width as float` (units), `targetPage as integer` (`page` keys). `sub new(label as string, kind as KeyboardKeyKind, width = 1.0 as float)`.
  - `class KeyboardRow`: `keys as KeyboardKey[]`, `indent as float`.
  - `class KeyboardPage`: `rows as KeyboardRow[]`; `function getWidthUnits() as float` (max of indent + key widths).
  - `class KeyboardLayout`: `pages as KeyboardPage[]`, `pageIndex as integer`, `row as integer`, `column as integer`; `currentPage() as KeyboardPage`, `currentKey() as KeyboardKey`, `move(dx as integer, dy as integer)` (dy +1 = next row down), `setPage(index as integer)`, `setCursor(row as integer, column as integer)`, `keyAt(x as float, y as float) as dynamic` (returns `{row, column}` or `invalid`; x in units, y in rows), `keyLeft(row as integer, column as integer) as float` (left edge in units).
  - `function createAlphabeticalKeyboardLayout() as KeyboardLayout`, `createQwertyKeyboardLayout()`, `createCompactKeyboardLayout()`.
  - Helpers: `function createKeyboardCharRow(chars as string, indent = 0.0 as float) as KeyboardRow`, `createKeyboardPageKey(label as string, targetPage as integer, width as float) as KeyboardKey`.

- [ ] **Step 1: failing tests**

```brightscript
@describe("alphabetical layout")

@it("has lower, upper and symbol pages, 7 units wide")
function _()
  layout = BGE.UI.createAlphabeticalKeyboardLayout()
  m.assertEqual(3, layout.pages.count())
  m.assertEqual(7.0, layout.pages[0].getWidthUnits())
  m.assertEqual("a", layout.currentKey().label)
end function

@describe("move")

@it("wraps left and right within a row")
function _()
  layout = BGE.UI.createAlphabeticalKeyboardLayout()
  layout.move(-1, 0)
  m.assertEqual("g", layout.currentKey().label)
  layout.move(1, 0)
  m.assertEqual("a", layout.currentKey().label)
end function

@it("wraps up from the top row to the special row")
function _()
  layout = BGE.UI.createAlphabeticalKeyboardLayout()
  layout.move(0, -1)
  m.assertEqual(4, layout.row)
  m.assertEqual("Shift", layout.currentKey().label) ' a's centre 0.5 is inside Shift (0-1.5)
end function

@it("lands on the nearest centre in a row of different widths")
function _()
  layout = BGE.UI.createAlphabeticalKeyboardLayout()
  layout.setCursor(3, 3) ' "y", centre 3.5
  layout.move(0, 1) ' special row: Shift 0.75, &123 2.25, Space 4.0, Del 5.5, Done 6.5
  m.assertEqual("Space", layout.currentKey().label)
end function

@it("lands on the nearest centre in an indented QWERTY row")
function _()
  layout = BGE.UI.createQwertyKeyboardLayout()
  layout.setCursor(0, 1) ' "w", centre 1.5
  layout.move(0, 1) ' a (centre 1.0) and s (2.0) tie at 0.5 away; ties go left
  m.assertEqual("a", layout.currentKey().label)
end function

@describe("pages")

@it("setPage keeps the cursor where it exists and clamps otherwise")
function _()
  layout = BGE.UI.createAlphabeticalKeyboardLayout()
  layout.setCursor(1, 2) ' "j"
  layout.setPage(1)
  m.assertEqual("J", layout.currentKey().label)
  layout.setCursor(4, 4) ' Done on the lower page
  layout.setPage(2) ' symbols special row has 4 keys
  m.assertEqual(3, layout.column)
end function

@it("keyAt maps a point to a key")
function _()
  layout = BGE.UI.createAlphabeticalKeyboardLayout()
  hit = layout.keyAt(2.5, 1.5)
  m.assertEqual(1, hit.row)
  m.assertEqual(2, hit.column)
  m.assertInvalid(layout.keyAt(7.5, 0.5))
end function

@describe("compact layout")

@it("is one page of A-Z and 0-9 in rows of 9 plus Del and Done")
function _()
  layout = BGE.UI.createCompactKeyboardLayout()
  m.assertEqual(1, layout.pages.count())
  m.assertEqual(5, layout.pages[0].rows.count())
  m.assertEqual("A", layout.currentKey().label)
  m.assertEqual(Asc("A"), layout.currentKey().char)
end function
```

- [ ] **Step 2:** run, expect errors (missing file/functions).
- [ ] **Step 3: implement** `KeyboardLayout.bs` (imports nothing but math):

```brightscript
namespace BGE.UI

  enum KeyboardKeyKind
    char = "char"
    space = "space"
    backspace = "backspace"
    done = "done"
    page = "page"
  end enum

  ' One key on a BGE.UI.Keyboard.
  class KeyboardKey
    label as string
    kind as BGE.UI.KeyboardKeyKind
    ' Character code typed by a char key.
    char as integer = 0
    ' Width in grid units (a letter is 1).
    width as float = 1.0
    ' Page a page key switches to.
    targetPage as integer = 0

    sub new(label as string, kind as BGE.UI.KeyboardKeyKind, width = 1.0 as float)
      m.label = label
      m.kind = kind
      m.width = width
    end sub
  end class

  ' A row of keys, optionally indented (in grid units).
  class KeyboardRow
    keys as BGE.UI.KeyboardKey[] = []
    indent as float = 0.0
  end class

  ' One page of a keyboard layout.
  class KeyboardPage
    rows as BGE.UI.KeyboardRow[] = []

    ' The widest row, in grid units, including its indent.
    function getWidthUnits() as float
      widest = 0.0
      for each row in m.rows
        rowWidth = row.indent
        for each key in row.keys
          rowWidth += key.width
        end for
        if rowWidth > widest
          widest = rowWidth
        end if
      end for
      return widest
    end function
  end class

  ' Pages of keys plus the highlighted-key cursor for a BGE.UI.Keyboard.
  class KeyboardLayout
    pages as BGE.UI.KeyboardPage[] = []
    pageIndex as integer = 0
    row as integer = 0
    column as integer = 0

    function currentPage() as BGE.UI.KeyboardPage
      return m.pages[m.pageIndex]
    end function

    function currentKey() as BGE.UI.KeyboardKey
      return m.currentPage().rows[m.row].keys[m.column]
    end function

    ' Moves the cursor. Left/Right wrap within the row; Up/Down wrap top to bottom and land on
    ' the key whose centre is nearest the current key's centre.
    '
    ' @param {integer} dx - -1 left, 1 right
    ' @param {integer} dy - -1 up, 1 down
    sub move(dx as integer, dy as integer)
      rows = m.currentPage().rows
      if dx <> 0
        count = rows[m.row].keys.count()
        m.column = ((m.column + dx) mod count + count) mod count
      end if
      if dy <> 0
        centre = m.keyLeft(m.row, m.column) + m.currentKey().width / 2.0
        m.row = ((m.row + dy) mod rows.count() + rows.count()) mod rows.count()
        m.column = m.nearestColumn(m.row, centre)
      end if
    end sub

    ' Switches page, keeping the cursor's row and column where they exist, else clamping.
    sub setPage(index as integer)
      m.pageIndex = index
      m.setCursor(m.row, m.column)
    end sub

    ' Moves the cursor to a row and column, clamped to the current page.
    sub setCursor(row as integer, column as integer)
      rows = m.currentPage().rows
      m.row = cint(BGE.Math.Clamp(row, 0, rows.count() - 1))
      m.column = cint(BGE.Math.Clamp(column, 0, rows[m.row].keys.count() - 1))
    end sub

    ' The key under a point, x in grid units and y in rows.
    '
    ' @return {dynamic} {row, column}, or invalid if no key is there
    function keyAt(x as float, y as float) as dynamic
      rows = m.currentPage().rows
      rowIndex = int(y)
      if y < 0 or rowIndex >= rows.count()
        return invalid
      end if
      left = rows[rowIndex].indent
      for i = 0 to rows[rowIndex].keys.count() - 1
        width = rows[rowIndex].keys[i].width
        if x >= left and x < left + width
          return {row: rowIndex, column: i}
        end if
        left += width
      end for
      return invalid
    end function

    ' Left edge of a key, in grid units.
    function keyLeft(row as integer, column as integer) as float
      keyRow = m.currentPage().rows[row]
      left = keyRow.indent
      for i = 0 to column - 1
        left += keyRow.keys[i].width
      end for
      return left
    end function

    private function nearestColumn(row as integer, centre as float) as integer
      keyRow = m.currentPage().rows[row]
      best = 0
      bestDistance = 1000000.0
      left = keyRow.indent
      for i = 0 to keyRow.keys.count() - 1
        distance = abs(left + keyRow.keys[i].width / 2.0 - centre)
        ' strict < so ties go left
        if distance < bestDistance
          bestDistance = distance
          best = i
        end if
        left += keyRow.keys[i].width
      end for
      return best
    end function
  end class

  ' A row of 1-unit char keys, one per character of `chars`.
  function createKeyboardCharRow(chars as string, indent = 0.0 as float) as BGE.UI.KeyboardRow
    row = new BGE.UI.KeyboardRow()
    row.indent = indent
    for i = 1 to Len(chars)
      key = new BGE.UI.KeyboardKey(Mid(chars, i, 1), BGE.UI.KeyboardKeyKind.char)
      key.char = Asc(Mid(chars, i, 1))
      row.keys.push(key)
    end for
    return row
  end function

  ' A key that switches to another page.
  function createKeyboardPageKey(label as string, targetPage as integer, width as float) as BGE.UI.KeyboardKey
    key = new BGE.UI.KeyboardKey(label, BGE.UI.KeyboardKeyKind.page, width)
    key.targetPage = targetPage
    return key
  end function
```

Then the builders (same file). A private-ish helper builds a page from char rows plus a special row:

```brightscript
  ' Builds a page from rows of characters (with optional indents) and a special row.
  function createKeyboardPage(charRows as string[], indents as float[], specialRow as BGE.UI.KeyboardRow) as BGE.UI.KeyboardPage
    page = new BGE.UI.KeyboardPage()
    for i = 0 to charRows.count() - 1
      page.rows.push(BGE.UI.createKeyboardCharRow(charRows[i], indents[i]))
    end for
    page.rows.push(specialRow)
    return page
  end function

  ' A special row: the given page keys, then Space, Del and Done.
  function createKeyboardSpecialRow(pageKeys as BGE.UI.KeyboardKey[], spaceWidth as float, editKeyWidth as float) as BGE.UI.KeyboardRow
    row = new BGE.UI.KeyboardRow()
    for each key in pageKeys
      row.keys.push(key)
    end for
    space = new BGE.UI.KeyboardKey("Space", BGE.UI.KeyboardKeyKind.space, spaceWidth)
    space.char = 32
    row.keys.push(space)
    row.keys.push(new BGE.UI.KeyboardKey("Del", BGE.UI.KeyboardKeyKind.backspace, editKeyWidth))
    row.keys.push(new BGE.UI.KeyboardKey("Done", BGE.UI.KeyboardKeyKind.done, editKeyWidth))
    return row
  end function

  ' Alphabetical a-z in rows of 7, with an upper case page and a symbols page.
  function createAlphabeticalKeyboardLayout() as BGE.UI.KeyboardLayout
    lower = ["abcdefg", "hijklmn", "opqrstu", "vwxyz.@"]
    upper = []
    for each chars in lower
      upper.push(UCase(chars))
    end for
    symbols = ["1234567", "890-_'""", "!?#&/:;", "()+=*,$"]
    noIndent = [0.0, 0.0, 0.0, 0.0]
    layout = new BGE.UI.KeyboardLayout()
    layout.pages.push(BGE.UI.createKeyboardPage(lower, noIndent, BGE.UI.createKeyboardSpecialRow([BGE.UI.createKeyboardPageKey("Shift", 1, 1.5), BGE.UI.createKeyboardPageKey("&123", 2, 1.5)], 2.0, 1.0)))
    layout.pages.push(BGE.UI.createKeyboardPage(upper, noIndent, BGE.UI.createKeyboardSpecialRow([BGE.UI.createKeyboardPageKey("abc", 0, 1.5), BGE.UI.createKeyboardPageKey("&123", 2, 1.5)], 2.0, 1.0)))
    layout.pages.push(BGE.UI.createKeyboardPage(symbols, noIndent, BGE.UI.createKeyboardSpecialRow([BGE.UI.createKeyboardPageKey("abc", 0, 1.5)], 3.5, 1.0)))
    return layout
  end function

  ' QWERTY, with staggered rows, an upper case page and a symbols page.
  function createQwertyKeyboardLayout() as BGE.UI.KeyboardLayout
    lower = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    upper = []
    for each chars in lower
      upper.push(UCase(chars))
    end for
    letterIndents = [0.0, 0.5, 1.5]
    symbols = ["1234567890", "-_'""!?#&", "/:;()+=", "*,$.@"]
    symbolIndents = [0.0, 1.0, 1.5, 2.5]
    layout = new BGE.UI.KeyboardLayout()
    layout.pages.push(BGE.UI.createKeyboardPage(lower, letterIndents, BGE.UI.createKeyboardSpecialRow([BGE.UI.createKeyboardPageKey("Shift", 1, 2.0), BGE.UI.createKeyboardPageKey("&123", 2, 2.0)], 3.0, 1.5)))
    layout.pages.push(BGE.UI.createKeyboardPage(upper, letterIndents, BGE.UI.createKeyboardSpecialRow([BGE.UI.createKeyboardPageKey("abc", 0, 2.0), BGE.UI.createKeyboardPageKey("&123", 2, 2.0)], 3.0, 1.5)))
    layout.pages.push(BGE.UI.createKeyboardPage(symbols, symbolIndents, BGE.UI.createKeyboardSpecialRow([BGE.UI.createKeyboardPageKey("abc", 0, 2.0)], 5.0, 1.5)))
    return layout
  end function

  ' A-Z and 0-9 in rows of 9, then Del and Done - for short arcade-style entry.
  function createCompactKeyboardLayout() as BGE.UI.KeyboardLayout
    special = new BGE.UI.KeyboardRow()
    special.keys.push(new BGE.UI.KeyboardKey("Del", BGE.UI.KeyboardKeyKind.backspace, 4.5))
    special.keys.push(new BGE.UI.KeyboardKey("Done", BGE.UI.KeyboardKeyKind.done, 4.5))
    layout = new BGE.UI.KeyboardLayout()
    layout.pages.push(BGE.UI.createKeyboardPage(["ABCDEFGHI", "JKLMNOPQR", "STUVWXYZ0", "123456789"], [0.0, 0.0, 0.0, 0.0], special))
    return layout
  end function

end namespace
```

Note the QWERTY tie test: "w" centre 1.5; "a" centre 1.0 and "s" centre 2.0 are equally far, so strict `<` picks "a".
- [ ] **Step 4:** run, expect PASS.
- [ ] **Step 5:** commit `UI: KeyboardLayout with alphabetical, QWERTY and compact layouts (#288)`.

### Task 3: Keyboard widget

**Files:**
- Create: `src/source/engine/ui/Keyboard.bs`
- Test: `src/source/engine/ui/Keyboard.spec.bs`

**Interfaces:**
- Consumes: Task 1's `insertChar`/`deleteBeforeCursor`/`submit`/`editing`; Task 2's layout API; `FocusManager.focusWidget(widget)`, `FocusManager.navigationMode`, `FocusManager.cursorPosition`; `RepeatThrottle.shouldAct(input)`.
- Produces: `class Keyboard extends UiWidget`: `layout as KeyboardLayout`, `target as TextInput`, `onDone`/`onCancel as function or dynamic` (`sub(keyboard as BGE.UI.Keyboard)`), `backgroundRGBA as integer = &h000000C0`, `keyGap as float = 4.0`; `sub new(game as BGE.Game, layout = invalid as dynamic)`; `show(parent as UiContainer, target as TextInput)`; `hide()`; `pressKey(key as KeyboardKey)`; `done()`; `cancel()`; `isShown() as boolean`.

- [ ] **Step 1: failing tests.** `beforeEach`: `m.game = new BGE.Game(320, 240)`, `m.input = new BGE.UI.TextInput(m.game)`, `m.game.gameUi.addChild(m.input)`, `m.keyboard = new BGE.UI.Keyboard(m.game)`, sizes 210x150, `m.keyboard.show(m.game.gameUi, m.input)`. Tests:

```brightscript
@describe("typing")

@it("OK types the highlighted key into the target")
function _()
  m.game.focusManager.update(new BGE.GameInput(6, 0))
  m.assertEqual("a", m.input.text)
end function

@it("d-pad moves the highlight, is consumed and keeps focus")
function _()
  input = new BGE.GameInput(5, 0) ' right
  m.game.focusManager.update(input)
  m.assertEqual("b", m.keyboard.layout.currentKey().label)
  m.assertTrue(input.consumed)
  m.assertTrue(m.keyboard.focused)
end function

@it("Space, Del and page keys")
function _()
  m.keyboard.layout.setCursor(4, 2) ' Space
  m.keyboard.pressKey(m.keyboard.layout.currentKey())
  m.assertEqual(" ", m.input.text)
  m.keyboard.layout.setCursor(4, 3) ' Del
  m.keyboard.pressKey(m.keyboard.layout.currentKey())
  m.assertEqual("", m.input.text)
  m.keyboard.layout.setCursor(4, 0) ' Shift
  m.keyboard.pressKey(m.keyboard.layout.currentKey())
  m.assertEqual(1, m.keyboard.layout.pageIndex)
end function

@it("remote shortcuts: replay deletes, fast-forward types a space")
function _()
  m.input.text = "ab"
  m.input.cursorIndex = 2
  m.game.focusManager.update(new BGE.GameInput(7, 0))
  m.assertEqual("a", m.input.text)
  m.game.focusManager.update(new BGE.GameInput(9, 0))
  m.assertEqual("a ", m.input.text)
end function

@it("forwards mobile-app characters to the target")
function _()
  m.keyboard.onECPKeyboard(Asc("z"))
  m.assertEqual("z", m.input.text)
end function

@it("marks the target as editing while shown")
function _()
  m.assertTrue(m.input.editing)
  m.keyboard.hide()
  m.assertFalse(m.input.editing)
end function

@describe("done and cancel")

@it("Done hides, refocuses the target and fires onDone and onSubmit")
function _()
  m.input.onSubmit = sub(input as BGE.UI.TextInput)
    input.lastChangedValue = "submitted"
  end sub
  m.keyboard.done()
  m.assertFalse(m.keyboard.isShown())
  m.assertTrue(m.input.focused)
  m.assertEqual("submitted", m.input.lastChangedValue)
end function

@it("Play is Done")
function _()
  m.game.focusManager.update(new BGE.GameInput(13, 0))
  m.assertFalse(m.keyboard.isShown())
end function

@it("Back cancels and restores the text")
function _()
  m.input.text = "old"
  m.input.cursorIndex = 3
  m.keyboard.hide()
  m.keyboard.show(m.game.gameUi, m.input)
  m.input.insertChar(Asc("x"))
  m.game.focusManager.update(new BGE.GameInput(0, 0))
  m.assertEqual("old", m.input.text)
  m.assertEqual(3, m.input.cursorIndex)
  m.assertFalse(m.keyboard.isShown())
end function

@it("hide unregisters from focus")
function _()
  before = m.game.focusManager.registeredCount()
  m.keyboard.hide()
  m.assertEqual(before - 1, m.game.focusManager.registeredCount())
end function

@describe("draw")

@it("draws without throwing")
function _()
  m.keyboard.draw(m.game.gameUi)
  m.assertTrue(true)
end function
```

onDone is covered via a `lastDoneCount as integer` test field? No: keep the API lean and check `onDone` by setting `m.keyboard.onDone = sub(keyboard as BGE.UI.Keyboard) : keyboard.target.lastChangedValue = "done" : end sub` in a separate `@it` (write it as a multi-line sub; no single-line `if`).
- [ ] **Step 2:** run, expect missing-class errors.
- [ ] **Step 3: implement** `Keyboard.bs`:

```brightscript
import "../Game.bs"
import "../GameInput.bs"
import "../drawables/DrawableText.bs"
import "../../math/math.bs"
import "KeyboardLayout.bs"
import "Style.bs"
import "TextInput.bs"
import "UiContainer.bs"
import "UiWidget.bs"

namespace BGE.UI

  ' An on-screen keyboard that types into a TextInput with the d-pad and OK, for roScreen games
  ' (Roku's own keyboards are SceneGraph-only). Show it with show(); Back cancels and restores
  ' the text, Done (or Play) submits. Replay deletes, Fast-forward types a space. Characters from
  ' the Roku mobile app still reach the target while it's open.
  class Keyboard extends UiWidget

    layout as BGE.UI.KeyboardLayout
    target as BGE.UI.TextInput = invalid
    ' Called after Done hides the keyboard - sub(keyboard as BGE.UI.Keyboard)
    onDone as function or dynamic
    ' Called after Cancel restores the text and hides the keyboard - sub(keyboard as BGE.UI.Keyboard)
    onCancel as function or dynamic
    ' Panel colour behind the keys.
    backgroundRGBA as integer = &h000000C0
    ' Pixels between keys.
    keyGap as float = 4.0

    private textBeforeShow as string = ""
    private repeatThrottle as BGE.UI.RepeatThrottle = new BGE.UI.RepeatThrottle()
    private labelTexts as roAssociativeArray = {}
    private lastPointerX as float = -1.0
    private lastPointerY as float = -1.0

    ' @param {BGE.Game} game
    ' @param {BGE.UI.KeyboardLayout} [layout] - defaults to createAlphabeticalKeyboardLayout()
    sub new(game as BGE.Game, layout = invalid as dynamic)
      super(game)
      m.focusable = true
      if layout = invalid
        layout = BGE.UI.createAlphabeticalKeyboardLayout()
      end if
      m.layout = layout
    end sub

    ' Adds the keyboard to `parent`, focuses it and starts typing into `target`.
    '
    ' @param {BGE.UI.UiContainer} parent
    ' @param {BGE.UI.TextInput} target
    sub show(parent as BGE.UI.UiContainer, target as BGE.UI.TextInput)
      m.target = target
      m.textBeforeShow = target.text
      target.editing = true
      parent.addChild(m)
      m.game.focusManager.focusWidget(m)
    end sub

    ' Removes the keyboard from its container and refocuses the target.
    sub hide()
      container = m.parentContainer
      if container <> invalid
        (container as BGE.UI.UiContainer).removeChild(m)
      end if
      m.parentContainer = invalid
      if m.target <> invalid
        m.target.editing = false
        m.game.focusManager.focusWidget(m.target)
      end if
    end sub

    function isShown() as boolean
      return m.parentContainer <> invalid
    end function

    ' Hides the keyboard, then fires onDone and the target's onSubmit.
    sub done()
      m.hide()
      if m.onDone <> invalid
        m.onDone(m)
      end if
      if m.target <> invalid
        m.target.submit()
      end if
    end sub

    ' Restores the target's text from when show() was called, hides, then fires onCancel.
    sub cancel()
      if m.target <> invalid
        m.target.text = m.textBeforeShow
        m.target.cursorIndex = Len(m.textBeforeShow)
      end if
      m.hide()
      if m.onCancel <> invalid
        m.onCancel(m)
      end if
    end sub

    ' Acts on a key as if it were pressed.
    '
    ' @param {BGE.UI.KeyboardKey} key
    sub pressKey(key as BGE.UI.KeyboardKey)
      if key.kind = BGE.UI.KeyboardKeyKind.page
        m.layout.setPage(key.targetPage)
      else if key.kind = BGE.UI.KeyboardKeyKind.done
        m.done()
      else if m.target = invalid
        return
      else if key.kind = BGE.UI.KeyboardKeyKind.backspace
        m.target.deleteBeforeCursor()
      else
        m.target.insertChar(key.char)
      end if
    end sub

    override sub onClick()
      m.pressKey(m.layout.currentKey())
    end sub

    override sub onECPKeyboard(char as integer)
      if not m.focused or m.target = invalid
        return
      end if
      if char = 8
        m.target.deleteBeforeCursor()
      else
        m.target.insertChar(char)
      end if
    end sub

    ' D-pad moves the highlight (and never moves focus away), Back cancels, Replay deletes,
    ' Fast-forward types a space, Play is Done.
    override function handleInput(input as BGE.GameInput) as boolean
      if not (input.press or input.held)
        return false
      end if
      if input.isButton("back")
        if input.press
          m.cancel()
        end if
      else if input.isButton("play")
        if input.press
          m.done()
        end if
      else if input.isButton("fastforward")
        if input.press and m.target <> invalid
          m.target.insertChar(32)
        end if
      else if input.isButton("replay")
        if m.repeatThrottle.shouldAct(input) and m.target <> invalid
          m.target.deleteBeforeCursor()
        end if
      else if input.x <> 0 or input.y <> 0
        if m.repeatThrottle.shouldAct(input)
          ' input.y is +1 for up; layout rows count down
          m.layout.move(cint(input.x), -cint(input.y))
        end if
      else
        return false
      end if
      input.consume()
      return true
    end function

    ' Pointer mode: a cursor that moved onto a key highlights it.
    override sub onUpdate(deltaTime as float)
      fm = m.game.focusManager
      if fm.navigationMode <> BGE.UI.FocusNavigationMode.pointer or m.width <= 0 or m.height <= 0
        return
      end if
      p = fm.cursorPosition
      if p.x = m.lastPointerX and p.y = m.lastPointerY
        return
      end if
      m.lastPointerX = p.x
      m.lastPointerY = p.y
      page = m.layout.currentPage()
      hit = m.layout.keyAt((p.x - m.position.x) / (m.width / page.getWidthUnits()), (p.y - m.position.y) / (m.height / page.rows.count()))
      if hit <> invalid
        m.layout.setCursor(hit.row, hit.column)
      end if
    end sub

    override sub draw(parent = invalid as UiWidget)
      if m.width <= 0 or m.height <= 0
        return
      end if
      theme = m.resolveTheme(parent)
      renderer = m.canvas.renderer
      renderer.drawRectangle(m.position.x, m.position.y, m.width, m.height, m.backgroundRGBA)

      page = m.layout.currentPage()
      unitWidth = m.width / page.getWidthUnits()
      rowHeight = m.height / page.rows.count()
      gap = m.keyGap
      for r = 0 to page.rows.count() - 1
        keyRow = page.rows[r]
        left = keyRow.indent
        for c = 0 to keyRow.keys.count() - 1
          key = keyRow.keys[c]
          x = m.position.x + left * unitWidth + gap / 2
          y = m.position.y + r * rowHeight + gap / 2
          w = key.width * unitWidth - gap
          h = rowHeight - gap
          isHighlighted = r = m.layout.row and c = m.layout.column
          m.drawKey(theme, key, x, y, w, h, isHighlighted)
          left += key.width
        end for
      end for
    end sub

    private sub drawKey(theme as BGE.UI.Theme, key as BGE.UI.KeyboardKey, x as float, y as float, w as float, h as float, isHighlighted as boolean)
      renderer = m.canvas.renderer
      color = theme.backgroundColor
      if isHighlighted
        color = theme.hoveredBackgroundColor
        if m.focused
          renderer.drawRectangle(x - 2, y - 2, w + 4, h + 4, theme.focusedBorderColor)
        end if
      end if
      renderer.drawRectangle(x, y, w, h, color)
      text = m.getLabelText(key.label, theme)
      textImage = text.getTextImage()
      if textImage <> invalid
        size = text.getDrawnSize()
        renderer.drawTransformedObject(x + (w - size.width) / 2, y + (h - size.height) / 2, 1.0, 1.0, 0, textImage)
      end if
    end sub

    private function getLabelText(label as string, theme as BGE.UI.Theme) as BGE.DrawableText
      text = m.labelTexts[label]
      if text = invalid
        text = new BGE.DrawableText(m, label)
        if theme.font <> invalid
          text.setFont(theme.font)
        end if
        m.labelTexts[label] = text
      end if
      return text
    end function

  end class

end namespace
```

If `labelTexts` (AA keys are case-insensitive) collides "a"/"A", key it with `label + "|" + Asc(label).ToStr()` instead; the case-sensitivity test is the upper page's labels drawing upper case on device.
- [ ] **Step 4:** run, expect PASS. If `(container as BGE.UI.UiContainer)` trips the bsc self-reference bug, type the local first: `container = m.parentContainer as BGE.UI.UiContainer`.
- [ ] **Step 5:** commit `UI: BGE.UI.Keyboard on-screen keyboard widget (#288)`.

### Task 4: `TextInput.keyboard` opens the keyboard on OK

**Files:**
- Modify: `src/source/engine/ui/TextInput.bs`
- Test: `src/source/engine/ui/TextInput.spec.bs`

**Interfaces:**
- Consumes: `Keyboard.show(parent, target)`, `Keyboard.isShown()`.
- Produces: `TextInput.keyboard as BGE.UI.Keyboard = invalid`.

- [ ] **Step 1: failing tests**

```brightscript
@describe("keyboard")

@it("OK opens the keyboard instead of submitting")
function _()
  m.game.gameUi.addChild(m.input)
  m.input.keyboard = new BGE.UI.Keyboard(m.game)
  m.input.onSubmit = sub(input as BGE.UI.TextInput)
    input.lastChangedValue = "submitted"
  end sub
  m.input.onClick()
  m.assertTrue(m.input.keyboard.isShown())
  m.assertInvalid(m.input.lastChangedValue)
end function
```

- [ ] **Step 2:** run, expect failure.
- [ ] **Step 3: implement.** `import "Keyboard.bs"` in `TextInput.bs`; field with doc "Optional on-screen keyboard: when set, OK opens it (in this input's container) instead of firing onSubmit; its Done fires onSubmit." `onClick()`:

```brightscript
override sub onClick()
  if m.keyboard <> invalid and m.parentContainer <> invalid
    if not m.keyboard.isShown()
      m.keyboard.show(m.parentContainer as BGE.UI.UiContainer, m)
    end if
    return
  end if
  m.submit()
end sub
```

Enter (handleInput) still calls `onClick()`, which is fine: a physical keyboard's Enter opening the on-screen one only happens if the game set `keyboard`.
- [ ] **Step 4:** run, expect PASS. Then `npm run check`.
- [ ] **Step 5:** commit `UI: TextInput.keyboard opens an on-screen keyboard on OK (#288)`.

### Task 5: Demo, docs and device check

**Files:**
- Modify: `examples/ui/src/source/Scenes/TextInputScene.bs`
- Modify: `docs/engine-internals.md` (Text entry section), `.claude/rules/ui.md`

- [ ] **Step 1: demo.** In `TextInputScene.onCreate()`, after the TextInput:

```brightscript
m.keyboard = new BGE.UI.Keyboard(m.game)
m.keyboard.customPosition = true
m.keyboard.customX = width * 0.11
m.keyboard.customY = height * 0.5
m.keyboard.width = width * 0.5
m.keyboard.height = height * 0.38
m.textInput.keyboard = m.keyboard
```

Move the value label/button above `0.5` if they'd overlap (value label to `0.44`). Update the hint: "OK on the box opens the keyboard. Back cancels, Play is Done, Replay deletes. The Roku mobile app's keyboard works too." Scene `onInput` Back: only leave the scene if `not m.keyboard.isShown()` (the keyboard consumes Back, so check whether input was consumed already: `if input.press and input.isButton("back") and not input.consumed`). Add a Select (or button) switching `m.keyboard.layout` between alphabetical and QWERTY so both are on the device.
- [ ] **Step 2: docs.** Add an "On-screen keyboard" subsection after the Text entry section of `docs/engine-internals.md`: what it is, a 6-line example (`keyboard = new BGE.UI.Keyboard(game)`, size/position, `textInput.keyboard = keyboard`), layouts (`createAlphabeticalKeyboardLayout`/`createQwertyKeyboardLayout`/`createCompactKeyboardLayout`, custom pages), controls table. Rule line in `ui.md`: "`BGE.UI.Keyboard` is one focusable widget running its own grid navigation; it types through `TextInput.insertChar()`/`deleteBeforeCursor()`."
- [ ] **Step 3:** `npm run check`, validate examples (`node scripts/examples.js validate`).
- [ ] **Step 4: device.** Package examples/ui, sideload to the Ultra (192.168.41.102) and the Express (192.168.41.118, 720p). Fill the TextInput with only remote presses (`press`), check title-safe placement, upper/symbols pages, QWERTY, Back restores. Pointer mode via the Analog Cursor scene isn't on this scene; check pointer by temporarily setting `m.game.focusManager.navigationMode` in the scene only if time allows. Measure: break in with Ctrl-C, or time `draw()` with a temporary `roTimespan` print around `m.keyboard.draw()` over 100 frames; record ms on both devices. Bake to a bitmap only if > 2 ms.
- [ ] **Step 5:** commit `Examples/docs: on-screen keyboard demo and guide (#288)`; push; open PR (pr-voice) closing #288.
