# BGE.UI Follow-Ups: Analog Cursor, 9-Patch Backgrounds, Popup Select, Text Input

Addresses GitHub issues #182, #180, #181, #179 — all filed as explicit follow-ups to #133's focus/cursor/theme pass (`specs/2026-08-30-ui-focus-cursor-theme-design.md`), which deliberately scoped them out. Each is independent enough to land as its own PR; this doc is the shared architecture context, split into four separate plans (`specs/2026-09-04-analog-cursor-plan.md`, `specs/2026-09-04-ninepatch-backgrounds-plan.md`, `specs/2026-09-04-select-popup-plan.md`, `specs/2026-09-04-text-input-widget-plan.md`) so each can be executed and merged on its own.

**Execution order:** #182 → #180 → #181 → #179 (smallest/most self-contained first; text input last since it's the biggest scope).

**Demo surface:** a new `examples/ui` example (scaffolded in the first plan, extended by each later plan with its own Room) — dedicated to demonstrating `BGE.UI` widgets, separate from `examples/audio`'s actual audio-player purpose.

## Prior art already in the engine (read before touching any of this)

- `src/source/engine/ui/FocusManager.bs` — global focus/cursor singleton (`Game.focusManager`), `FocusNavigationMode.list`/`.pointer`, `RepeatThrottle` (`Style.bs`) for throttled repeat-while-held input.
- `src/source/engine/ui/UiWidget.bs` — base widget: `focusable`, `focused`, `hovered`, `handleInput(input) as boolean`, `onFocus`/`onBlur`/`onMouseOver`/`onMouseOut`/`onMouseDown`/`onMouseUp`/`onClick`, `resolveTheme(parent)`.
- `src/source/engine/ui/Select.bs` / `Slider.bs` / `Button.bs` — existing focusable widgets; `Select`/`Slider`'s Left/Right-cycling `handleInput()` override is the pattern popup-`Select` and `TextInput` both extend.
- `src/source/engine/ui/Theme.bs` — `BGE.UI.Theme`, resolved per-draw via `UiWidget.resolveTheme(parent)`; `invalid` widget color fields fall back to theme.
- `src/source/engine/controller/ControlMap.bs` — `BGE.Controller.ControlMap.getAxis(name) as BGE.Math.Vector`, `hasBindings()`. `Game.controls` (a `ControlMap`) already exists and is populated whenever `Game.enableControllerInput()` was called (#149, shipped 2026-09-04) — analog cursor movement is *not* blocked on any new controller plumbing.
- `Game.getDeltaTime() as float` — per-frame seconds, needed for continuous (non-throttled) analog movement.
- `Game.processUiInput()` → `processUiUpdate(gameUi, ...)` → `processEntityOnInput(gameUi, ...)`, which already calls `entity.onECPKeyboard(msg.GetChar())` whenever `msg.GetChar() <> 0 and msg.GetChar() = msg.GetInt()` (`Game.bs:811`). `UiContainer` already overrides `onECPKeyboard` to broadcast to every child unconditionally (`UiContainer.bs:199`). **This means the "ECP keyboard capture" plumbing issue #179 worried about already exists end-to-end** — a new `TextInput` widget only needs to override `onECPKeyboard` itself; no `Game.bs`/`UiContainer.bs` changes required. This substantially shrinks #179's scope vs. its original estimate.
- `roFont.GetOneLineWidth(text, maxWidth) as integer` — used by `DrawableText` (`m.width = m.font.GetOneLineWidth(m.text, 10000)`), and is what `TextInput` uses to measure caret x-position from a text prefix.
- `Renderer.drawObjectTo`/`drawScaledObjectTo(draw2d, x, y, scaleX, scaleY, src, rgba)` — `src` is any `ifDraw2d` (a `roRegion` sub-region qualifies), used by 9-patch to blit each of its 9 slices.
- **`=` between two custom-class or native-component instances is a runtime crash** (see CLAUDE.md's BrightScript `=` gotcha) — none of these four designs compare widget/region instances directly; flagged here so plan reviewers don't introduce one.

## 1. Analog-stick cursor movement (#182)

`FocusManager.navigatePointer()` today only reads d-pad `input.x`/`input.y`, throttled by `RepeatThrottle` to one discrete step per tap/hold-tick. Analog input needs continuous, unthrottled movement scaled by an axis magnitude and frame time — a different code path, not a tweak to the existing one.

- `FocusManager` gains `analogAxisName as string = invalid` (opt-in; unset = zero behavior change) and `cursorAnalogSpeed as float = 400.0` (px/sec at full deflection).
- New `FocusManager.updateAnalogCursor(controls as BGE.Controller.ControlMap, dt as float)`, called **every frame** regardless of whether any d-pad event fired this frame (unlike `update()`, which only runs per input event) — continuous analog movement can't wait for a discrete event.
- Zero-cost when unused, matching the `onControls()`/`hasBindings()` convention: no-op unless `navigationMode = pointer` AND `analogAxisName <> invalid` AND `controls.hasBindings()`.
- Called from a new one-line addition to `Game.processUiInput()`, right after `processFocusManagerInput()`.
- Deadzone: reuse whatever `ControlMap.getAxis()` already returns (confirm in Task 1 whether `ControllerRegistry.getStick()` already deadzones; if not, apply a `0.15` deadzone locally in `updateAnalogCursor`, not in `ControlMap`, since that's shared with non-UI axis consumers).

## 2. 9-Patch / image-backed widget backgrounds (#180)

New `BGE.UI.NinePatchImage` class (`src/source/engine/ui/NinePatchImage.bs`), not a `Drawable` subclass — it doesn't participate in the `SceneObject`/depth-sort pipeline at all, it's a plain draw-time helper analogous to `Renderer.getCircleResource()`.

```
class NinePatchImage
  sourceRegion as roRegion
  ' Fixed-size insets (px) from each edge that are NOT stretched.
  left as integer
  top as integer
  right as integer
  bottom as integer
  ' 9 pre-sliced sub-regions, computed once in new() via sourceRegion.GetRegion(x,y,w,h).
  protected corners/edges/center as roRegion (9 fields, or an array of 9)

  sub new(sourceRegion as roRegion, left as integer, top as integer, right as integer, bottom as integer)
  sub draw(renderer as BGE.Renderer, x as float, y as float, width as float, height as float)
end class
```

`draw()` blits the 4 corners unscaled (`drawObjectTo`), the 4 edges scaled along one axis only (`drawScaledObjectTo`), and the center scaled both axes — 9 draw calls total, same cost class as today's flat `drawRectangle` fill plus 8 more (acceptable; not a hot path — widget backgrounds redraw only when a widget's own geometry/state changes, same as today).

- `Theme` gains `backgroundImage as BGE.UI.NinePatchImage = invalid` — `invalid` (the default) means "flat color, exactly today's behavior," so this is purely additive.
- Each of `Button`/`Checkbox`/`Select`/`Slider`'s `draw()` gains one branch: `if theme.backgroundImage <> invalid then theme.backgroundImage.draw(...) else <existing drawRectangle fill>`. The **hovered/focused border-drawing lines stay untouched** — only the background *fill* branches.

### 2a. Loading a 9-patch: Android `.9.png` border-marker convention (not hand-specified insets)

Rather than requiring a game developer to hand-tune four inset numbers per image, `NinePatchImage` is normally constructed via a new loader that reads the insets *from the image itself*, using the same convention Android's `.9.png` format uses — a well-established format with existing authoring tools, so consumers aren't inventing a bespoke asset pipeline:

- The source PNG has a 1px transparent border added around the real artwork. Opaque black pixels (`RGB` near `0x000000`, full alpha) drawn along a contiguous run of the **top** border row mark the horizontal stretch region; a run along the **left** border column marks the vertical stretch region. Everywhere else on that 1px border is transparent.
- New namespaced function `BGE.UI.loadNinePatchImage(path as string) as BGE.UI.NinePatchImage`:
  1. `bitmap = CreateObject("roBitmap", path)` (same construction Roku uses everywhere else, e.g. `Game.loadBitmap`).
  2. Read the top border row via `bitmap.GetByteArray(0, 0, width, 1)` and the left border column via `bitmap.GetByteArray(0, 0, 1, height)` — both return an `roByteArray` of RGBA bytes (`GetByteArray(x, y, width, height) as roByteArray`, confirmed against `brighterscript`'s Roku component type data — 4 bytes/pixel, RGBA order).
  3. Scan each border array for the first/last near-black-and-opaque pixel (threshold, not exact-`0x000000FF`, since PNG export can introduce minor color drift) to find the stretch run's start/end index.
  4. Convert those run boundaries (in full-bitmap coordinates, which include the 1px border) into the *interior* content's own coordinate space (subtract 1) to get `left`/`top` (content before the run) and `right`/`bottom` (content after the run) insets.
  5. Crop the 1px border away — `bitmap.GetRegion(1, 1, width - 2, height - 2)` — and pass that interior region plus the four computed insets to `NinePatchImage.new()`.
- **Non-goal (first pass):** Android's optional bottom/right border also encodes a *content padding* box (where text should sit inside the 9-patch, independent of the stretch region) — this pass parses only the top/left stretch-region border; a bottom/right content-padding border is ignored (safe to have or omit in a source image either way, since only the top row / left column are read). File a follow-up if a consumer needs it.
- **If no black marker pixels are found on an axis** (a plain PNG with no 9-patch border at all, or a border that never got authored on one axis): default that axis's insets to `0` and log a warning via a `print` diagnostic — this makes `loadNinePatchImage` degrade gracefully to "the whole image stretches on that axis" rather than crashing, at the cost of an unstretched-corners bug being silent; a game developer authoring their own `.9.png` assets should notice visually.

## 3. Popup/expanding list style for Select (#181)

`Select` gains `style as BGE.UI.SelectStyle` (`enum { inline = "inline", popup = "popup" }`), default `inline` — zero behavior change for existing consumers.

- **Overlay drawing problem:** `UiWidget.draw()` is called recursively in container add-order; a popup list needs to render *above every other widget*, regardless of z-order/siblings drawn after it. Solution: a new empty-by-default hook `UiWidget.drawOverlay(canvas as BGE.Canvas, theme as BGE.UI.Theme)`, called once per frame by `FocusManager.draw()` (same place the pointer-mode cursor already draws, i.e. after `gameUi.draw()` in `Game.drawUI()`) — `if m.currentlyFocused <> invalid then m.currentlyFocused.drawOverlay(canvas, theme)`. This is a general mechanism (any future overlay widget reuses it), not popup-`Select`-specific plumbing bolted onto `Game`.
- **Input, while `style = popup`:**
  - `onClick()` (fired by `FocusManager.update()` on OK-press, same as today) sets `m.expanded = true` and seeds `m.highlightedIndex = m.selectedIndex`, instead of doing nothing (today's `Select` has no `onClick` override).
  - `handleInput()`: while `m.expanded`, Up/Down (throttled via the existing `RepeatThrottle`) move `highlightedIndex` (clamped, no wrap), OK-press commits (`m.selectedIndex = m.highlightedIndex`, fires `onChanged`, `m.expanded = false`), `back`-press cancels (`m.expanded = false`, no change) — all four consume the event. While *not* expanded, `style = popup` disables the existing Left/Right inline-cycling (popup is the only interaction path once that style is chosen) and falls through to normal focus navigation.
  - Because `handleInput()` consumes and returns `true` for every button while `m.expanded`, `FocusManager.update()`'s "only navigate if not handled" rule already keeps focus from moving away mid-popup — no `FocusManager` changes needed there.
- **Non-goal (explicitly scoped out, call out in the plan):** scrolling/clipping for option lists longer than fit on screen. First pass draws every option unclipped; a long list overflowing the canvas is a known, documented limitation, not a bug — file a follow-up if it matters in practice.

## 4. Text input widget (#179)

New `BGE.UI.TextInput extends UiWidget` (`src/source/engine/ui/TextInput.bs`). As noted above, `onECPKeyboard` broadcast plumbing already exists — this widget is additive only.

```
class TextInput extends UiWidget
  text as string = ""
  cursorIndex as integer = 0
  maxLength as integer = 0 ' 0 = unlimited
  placeholder as string = ""
  onChanged as function or dynamic ' function(widget as TextInput) as void, fires on every edit
  onSubmit as function or dynamic  ' function(widget as TextInput) as void, fires on OK-press
  drawableText as BGE.DrawableText

  override sub onECPKeyboard(char as integer) ' only acts if m.focused
  override function handleInput(input as BGE.GameInput) as boolean ' Left/Right move cursorIndex, consumed
  override sub onClick() ' fires onSubmit
  override sub draw(parent = invalid as UiWidget)
end class
```

- Backspace: Roku's mobile-app on-screen keyboard sends ASCII `8` (BS) through the same `onECPKeyboard` path (confirmed via existing `msg.GetChar()` plumbing) — `onECPKeyboard` special-cases `char = 8` to delete the character before `cursorIndex` instead of inserting it literally. Any other non-empty char inserts at `cursorIndex` (respecting `maxLength`) and advances the cursor.
- Left/Right (while focused, via `handleInput`) move `cursorIndex` within `[0, Len(m.text)]`, consumed the same way `Select`'s Left/Right consumes — so it doesn't also walk focus away.
- Caret x-position: `m.drawableText.font.GetOneLineWidth(Left(m.text, m.cursorIndex), 10000)`, drawn as a 1-2px vertical line via `Renderer.drawRectangle`, only while `m.focused` (blinking is a nice-to-have, not required for the first pass — a static caret while focused is sufficient and avoids adding a timer).
- `placeholder` draws (dimmed via `theme.disabledColor`) only when `m.text = ""` and not focused.

## Testing (all four)

Each plan's tasks are TDD (`*.spec.bs`, one `@suite` class per file, per CLAUDE.md). Construct a real `BGE.Game` in `beforeEach` where focus/input/theme resolution needs to be exercised end-to-end (per CLAUDE.md: Rooibos can't stub native Roku components, and a real `Game` is the established pattern for `GameEntity`/`UI` behavior). Compare scalar identity fields (`id`, a marker field), never whole objects or native components, per the existing `assertEqual` guidance.

## Documentation

Each plan updates:
- `docs/game-engine-overview.md` or `docs/engine-internals.md` (whichever already documents `BGE.UI` — confirmed at plan-writing time per-plan) with the new capability.
- `CLAUDE.md`'s UI section, if the change is architecturally significant (the `drawOverlay()` mechanism and `updateAnalogCursor()`'s per-frame-not-per-event call both qualify; the 9-patch `Theme` field and `TextInput`'s widget-local behavior likely don't need a CLAUDE.md mention, just doc-comments).
- `examples/ui`'s new Room for that feature, verified via an actual `rokubot` sideload run per CLAUDE.md (Rooibos doesn't cover example-level runtime behavior).
