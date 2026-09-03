# UI Focus Management, Virtual Cursor, and Theming

Addresses GitHub issue #133 ("UI focus management for interactive widgets"), extended per discussion to include cursor-style pointer input and a shared theme system for `BGE.UI`.

## Problem

`BGE.UI` widgets have no focus concept. Every example needing an interactive menu (`examples/audio`, `examples/tweens`) hand-rolls its own `focusIndex` field and manual directional dispatch. There's also no way for a focused/hovered widget to consume an input event and stop it from also reaching `GameEntity.onInput()` that frame, and no shared way to theme widget colors/fonts — each widget exposes its own ad hoc color fields.

## Goals

- Reusable focus + virtual-cursor navigation for `BGE.UI` widgets, with an explicit per-container focus order as the seed/fallback path.
- Input consumption: a widget that acts on an event stops that event from reaching `GameEntity.onInput()` the same frame.
- A shared, swappable `Theme` object providing default colors/fonts/spacing, overridable per widget instance.
- New interactive widgets: `Button`, `Checkbox`, `Select` (inline cycling), plus retrofitting `Slider` onto focus/theme.
- `examples/audio` migrated off its hand-rolled `focusIndex`.

## Non-goals (this pass)

- Text input (cursor position, ECP keyboard capture) — file as a follow-up issue.
- Expanding-list/popup `Select` — this pass ships inline cycling only (matches `Slider`'s existing interaction style); a full popup list is a future follow-up.
- 9-patch / image-backed widget backgrounds — file as a follow-up issue. The `Theme` field shapes below are chosen so that follow-up can add an image/9-patch background option later without a breaking change (a widget's own `draw()` already isolates its background-fill call from everything else).
- Analog-stick/controller-driven cursor movement — issue #149 (external controllers) isn't built yet. This pass drives the cursor from d-pad press/held only, but keeps per-frame cursor movement expressed as a themeable/settable step so a later analog source can feed it without a design change.
- Spatial (geometry-based) focus navigation — explicit add-order only.

## Architecture

### A. Game-loop reordering for same-frame input consumption

**Current order** (`Game.Play()`): `processEntitiesPreDraw()` (dispatches `onInput` to every `GameEntity`) runs *before* `processAndDrawUI()` (dispatches `onInput` to `gameUi`/`debugUi`). This means a widget consuming an event today can only affect the *next* frame's entity dispatch, not the current one — issue #133 explicitly wants same-frame suppression.

**Change**: reorder `Game.Play()` so UI input processing runs before entity input processing each frame. Concretely, split `processAndDrawUI` (currently update+draw together) so its input-handling portion (`processUiUpdate`'s onInput dispatch) runs ahead of `processEntitiesPreDraw()`, while draw still happens in its existing place in the frame (after entity movement/collision, so UI still draws on top of a fully-updated world). This is a documented behavior change — entities now see input *after* UI has had a chance to consume it, where previously it was the reverse. `CLAUDE.md`'s game-loop section needs updating to match, and `examples/*` need a scan for anything implicitly relying on the old order (none identified so far, but confirm during implementation).

**Consumption mechanism**: reuses the existing `Game.setInputEntity()`/`unsetInputEntity()` primitive (today used for exclusive pause-menu input), rather than inventing new capture machinery:

1. Add `consumed as boolean = false` and a `consume()` setter method to `GameInput`.
2. A widget's `onInput`/pointer-event handler calls `input.consume()` when it acts on the event.
3. After dispatching to its focused/hovered widget, the owning `UiContainer` checks `input.consumed`. If set, it calls `game.setInputEntity(m.id)` (its own entity id) for the remainder of that frame; if nothing is focused/hovered/consuming, it calls `game.unsetInputEntity()`.
4. `processEntityOnInput`'s existing gate (`m.currentInputEntityId = invalid or m.currentInputEntityId = entity.id`) already honors this for every other `GameEntity`, unchanged.

### B. Focus + cursor model

Each `UiContainer` (not `Game`) owns its own cursor and focus state — a future modal dialog gets independent focus from `Game.gameUi`.

**`UiWidget` additions:**
- `focusable as boolean = false` (opt-in; `UiContainer`/`Label` stay `false`).
- `focused as boolean`, `hovered as boolean` (both effectively read-only outward; set by the owning container).
- New lifecycle hooks, empty by default (mirroring `onCreate`/`onDestroy`): `onFocus()`, `onBlur()`, `onMouseOver()`, `onMouseOut()`, `onMouseDown()`, `onMouseUp()`, `onClick()`.
- Hit-testing reuses the widget's existing `position`/`width`/`height` (already maintained by `repositionBasedOnParent`) — no separate bounds concept.

**`UiContainer` additions:**
- `cursorPosition as BGE.Math.Vector` — drawn as a small themed cursor sprite/shape on top of children.
- `cursorStep as float` — per-press/held-frame movement amount (themeable default, settable).
- `focusOrder as UiWidget[]` — built from `focusable` children in `addChild` order. Used to seed the initial focused widget and as the OK-press fallback target when the cursor isn't currently over any widget.
- Per-frame in the (now-earlier, per Section A) UI input pass: Up/Down/Left/Right (press or held) move `cursorPosition` by `cursorStep`; the container hit-tests the new position against its `focusable` children, updating `hovered`/`onMouseOver`/`onMouseOut` and `focused`/`onFocus`/`onBlur` together (hovering a widget focuses it — cursor-primary, not two independent schemes). OK press while a widget is hovered/focused fires `onClick()`. Left/Right while a widget is focused but not being used for cursor movement that frame (e.g. `Slider`/`Select` adjusting) is delegated to the widget's own `onInput` first, consumed if acted on, before falling through to cursor movement.
- Consumption check + `setInputEntity`/`unsetInputEntity()` call as described in Section A, step 3.

### C. Theme system

```
namespace BGE.UI
  class Theme
    backgroundColor as integer = BGE.Colors.<today's Slider/UiContainer defaults>
    foregroundColor as integer
    borderColor as integer
    focusedBorderColor as integer
    hoveredBackgroundColor as integer
    disabledColor as integer
    font as roFont
    fontSize as integer
    defaultPadding as BGE.UI.OffsetSize
    defaultMargin as BGE.UI.OffsetSize
    cursorColor as integer
    cursorSize as float
  end class
end namespace
```

- `Game.defaultTheme as BGE.UI.Theme` — constructed with today's hardcoded widget defaults (e.g. `Slider.barColor`'s current value) so existing consumers see no visual change.
- `UiContainer.theme as BGE.UI.Theme` — defaults to inheriting the parent container's/`Game`'s theme; settable per container for scoped customization.
- Existing per-widget color fields (`Slider.barColor`, etc.) default to `invalid`, meaning "resolve from the nearest theme at add-time"; an explicit assignment still overrides. This is additive — no renames, no breaking change for direct color assignment.
- New widgets (`Button`, `Checkbox`, `Select`) are built theme-first.

### D. New/retrofitted widgets

- **`Button`** — label + background, `focusable = true`. Primary hook is `onClick()`; consumers either subclass to override it or assign an `onActivate` callback field for trivial cases. Visual state (normal/hovered/focused) pulls from `Theme`.
- **`Checkbox`** — label + toggle box, `focusable = true`. `getValue()` returns boolean; `onClick()` flips `checked` and invokes a `changed` callback field. Reuses `Label`'s `DrawableText` pattern for its caption.
- **`Select`** — ordered list of option values, `focusable = true`. Left/Right while focused cycles the current option (mirrors `Slider.increase()`/`decrease()`); `getValue()` returns the selected option. Inline-cycling only, no popup list (non-goal above).
- **`Slider`** retrofit — `focusable = true`, gains `onFocus()`/`onBlur()` (focus-ring visual), Left/Right while focused calls existing `increase()`/`decrease()`, hardcoded colors move onto `Theme` (`barColor`/`backgroundColor` default to `invalid`, same fallback rule as Section C).

## Testing

- Rooibos (`*.spec.bs`, one `@suite` class per file): focus-order seeding/cycling, cursor movement + hit-testing at known widget bounds, `input.consume()` → `setInputEntity`/`unsetInputEntity` gating (construct a real `Game`+`GameEntity`, confirm the entity's `onInput` is skipped the frame a widget consumes), `Theme` fallback resolution (widget field `invalid` pulls container/game theme; explicit override wins), and each new widget's `getValue()`/click/toggle/cycle behavior.
- `examples/audio` retrofit: replace its hand-rolled `focusIndex` with the new focus system. Requires an actual `rokubot` sideload run (per CLAUDE.md, example-level behavior isn't covered by Rooibos).
- New demo surface (exact placement — new example vs. addition to an existing one — decided at plan-writing time) exercising `Button`/`Checkbox`/`Select`/themed `Slider` together with the cursor, as both manual test coverage and living documentation.

## Documentation

- `CLAUDE.md` game-loop section: document the UI-before-entities input reorder (Section A).
- `docs/` guide addition covering focus/cursor/theming for consumers (new or appended to an existing UI-relevant guide — decided at plan-writing time).

## Follow-up issues to file after this spec

- Text input widget (cursor position, ECP keyboard capture).
- 9-patch / image-backed widget backgrounds (`Theme` background as `Drawable`/image instead of flat color only).
- Expanding-list/popup `Select`.
- Analog-stick/controller-driven cursor movement (depends on #149).
