---
paths:
  - "src/source/engine/ui/**"
---

# UI (`BGE.UI`)

- Retained-mode widget tree on its own canvas: `Game.gameUi` and `Game.debugUi` (`enableStandardDebugUi()` adds the standard debug windows).
- `UiContainer.onInput()` broadcasts to children. Focus is global via `Game.focusManager`, driven once per input event; the focused widget gets first refusal through `handleInput() as boolean`.
- `FocusNavigationMode.list` (default) steps in `addChild()` order; `pointer` uses a virtual cursor, optionally analog (`analogAxisName`).
- `debugUi` never captures input and is never blocked by another capture.
- Widgets register for focus when added to any focus-enabled container: build modal panels fresh on show, tear down on hide (`BGE.UI.MessagePanel` does).
- Theme via `Game.defaultTheme` or `UiContainer.theme`.
