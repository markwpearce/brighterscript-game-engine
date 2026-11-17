# On-screen keyboard (#288)

## Problem

Roku's keyboards (`KeyboardDialog`, `DynamicKeyboard`, `MiniKeyboard`) are SceneGraph-only. In an
`roScreen` game the only way to type into a `BGE.UI.TextInput` is the Roku mobile app's keyboard
over ECP, so a high-score name, a save-slot name or a search box can't be filled in with the
remote.

## Approach

`BGE.UI.Keyboard` is **one** focusable widget that runs its own grid navigation in
`handleInput()`. A `Button` per key registered with `FocusManager` doesn't work: list mode steps
focus in `addChild()` order, so Up/Down would be meaningless, and focus would walk out of the
keyboard. Because the keyboard reports every d-pad event as handled, `FocusManager.update()` never
moves focus while it's open, in either navigation mode.

Two units:

- `KeyboardLayout`: pages of rows of keys plus the highlighted-key cursor. No drawing, no
  `Game`, so it's tested on its own.
- `Keyboard`: the widget. Owns a layout, draws it, maps input to layout moves and key presses,
  and edits a target `TextInput`.

## KeyboardLayout (`ui/KeyboardLayout.bs`)

A key is `{label, kind, char, width}`. `kind` is a `KeyboardKeyKind` enum: `char`, `shift`,
`symbols`, `space`, `backspace`, `done`. `width` is in grid units (letters are 1). A row has an
optional `indent` in units (QWERTY's staggered rows).

Built-in layouts, from `BGE.UI.createAlphabeticalKeyboardLayout()`,
`BGE.UI.createQwertyKeyboardLayout()` and `BGE.UI.createCompactKeyboardLayout()`. A game can also
build its own pages.

**Alphabetical** (default). Three pages, 7 units wide:

| page | rows |
| --- | --- |
| lower | `a b c d e f g` / `h i j k l m n` / `o p q r s t u` / `v w x y z . @` |
| upper | the lower page, uppercased |
| symbols | `1 2 3 4 5 6 7` / `8 9 0 - _ ' "` / `! ? # & / : ;` / `( ) + = * , $` |

Every page ends with the special row `Shift (1.5) · &123 (1.5) · Space (2) · Del (1) · Done (1)`.
On the upper page Shift reads `abc`; on the symbols page `&123` reads `abc` and Shift is absent
(its width goes to Space).

**QWERTY**. Same three pages, 10 units wide: `q w e r t y u i o p` / `a s d f g h j k l`
(indent 0.5) / `z x c v b n m` (indent 1.5) / special row
`Shift (2) · &123 (2) · Space (3) · Del (1.5) · Done (1.5)`. Upper page uppercased; symbols page
`1 2 3 4 5 6 7 8 9 0` / `- _ ' " ! ? # &` (indent 1) / `/ : ; ( ) + =` (indent 1.5), then
`* , $ . @` ahead of the special row.

**Compact** (arcade name entry). One page: `A`–`Z` then `0`–`9` in rows of 9, then
`Del (4.5) · Done (4.5)`.

Navigation (`move(dx, dy)`):

- Left/Right step within the row and wrap at its ends.
- Up/Down move to the previous/next row, wrapping top and bottom, and land on the key whose
  horizontal centre is nearest the current key's centre (ties go left). Rows of different
  lengths stay predictable.
- `setPage(index)` keeps the cursor on the same row/column where it exists, else clamps.
- Shift toggles lower/upper (caps lock, not one-shot). `&123`/`abc` toggles symbols/lower.

`keyAt(x, y)` maps a point in layout units to a key, for pointer hover.

## Keyboard (`ui/Keyboard.bs`)

Fields: `layout` (default alphabetical), `target as TextInput`, `onDone`/`onCancel`
(`function(keyboard as Keyboard) as void`), plus the usual widget position/size. Key rects are
the widget's bounds divided by the page's row count and each row's units, with a small gap.

- `show(parent, target)`: remembers the target and its current text (for Cancel), adds itself
  to `parent`, and focuses itself (`FocusManager.focusWidget()`).
- `hide(parent)`: removes itself and refocuses the target. Same build-on-show, tear-down-on-hide
  rule as `MessagePanel`, so it doesn't stay focusable while hidden.

Input while focused (`handleInput()`):

| input | action |
| --- | --- |
| d-pad (press, and held via `RepeatThrottle`) | `layout.move()`; always consumed |
| OK (`onClick()`, from `FocusManager`) | press the highlighted key |
| Back | cancel |
| Replay | backspace |
| Fast-forward | space |
| Play | done |

The shortcuts are the issue's suggestion; Roku's own keyboard docs weren't reachable to confirm
them against SceneGraph.

Pressing a key:

- `char`/`space`: `target.insertChar()`
- `backspace`: `target.deleteBeforeCursor()`
- `shift`/`symbols`: switch page
- `done`: hide, call `onDone`, then the target's `onSubmit`

Cancel restores the remembered text (cursor at the end), hides, then calls `onCancel`.

`onECPKeyboard(char)` forwards to the target, so mobile-app typing still works while the
keyboard has focus.

Pointer mode: the d-pad behaves as in list mode. When the cursor (`FocusManager.cursorPosition`)
is over a key, that key is highlighted, so an analog stick can point straight at keys.

Drawing: one themed background (`drawThemedBackground`), then each key as a rectangle in
`theme.backgroundColor`, the highlighted key in `hoveredBackgroundColor` with a
`focusedBorderColor` border, and its label centred. Label `DrawableText`s are cached per label
string, as `Select` does for options.

Performance: a page is about 33 keys, so about 66 native draws a frame. Measure frame cost on the
Ultra and the 720p Express. Only bake the grid into a cached bitmap if the keyboard costs more
than ~2 ms a frame.

## TextInput changes

- New public `insertChar(char as integer)` and public `deleteBeforeCursor()`: the edit path
  `onECPKeyboard()` already uses (respecting `maxLength`, firing `onChanged`), without the
  `focused` check. `onECPKeyboard()` keeps its check and calls them.
- New optional `keyboard as BGE.UI.Keyboard` field. When set, OK on the TextInput opens it
  (`keyboard.show(parentContainer, m)`) instead of firing `onSubmit`; Done fires `onSubmit`.

## Testing

Rooibos:

- `KeyboardLayout`: row wrap, column wrap, nearest-centre Up/Down across rows of different
  lengths, page switching keeps or clamps the cursor, `keyAt()`, compact layout shape.
- `Keyboard`: char/space/backspace edit the target; `maxLength` respected; Done hides and calls
  `onDone` and `onSubmit`; Cancel and Back restore the text and call `onCancel`; shortcuts; d-pad
  is consumed and focus stays; ECP characters are forwarded; `hide()` unregisters from focus.
- `TextInput`: `insertChar()`/`deleteBeforeCursor()` work unfocused; OK with `keyboard` set opens
  it instead of submitting.

Device: examples/ui's Text Input scene gets a keyboard (OK on the TextInput opens it). Check it
on the Ultra (1080p) and the Express (720p): title-safe at both, filled in with only the remote,
in list and pointer mode, and the measured draw cost.

## Docs

`docs/engine-internals.md`'s `TextInput` section gets a short "On-screen keyboard" note; the `ui.md` rule gets one
line.
