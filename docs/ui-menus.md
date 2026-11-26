---
title: Menus and Panels
group: Guides
order: 13
---

# Menus and Panels

`BGE.UI` widgets live in `game.gameUi`, drawn on `game.uiCanvas`. This guide covers the
pieces most games need: buttons that report to an owner, menu lists, message panels, and
UI that goes away with its scene.

## Buttons report to a listener

Give a `BGE.UI.Button` an `actionId` and a `listener`. On click the button calls
`listener.onUiAction(actionId, button)`, so one scene or entity can handle all of its buttons
without looking itself up again:

```brighterscript
class TitleScene extends BGE.GameScene
  override sub onCreate(args as roAssociativeArray)
    start = new BGE.UI.Button(m.game)
    start.setLabel("Start")
    start.actionId = "start"
    start.listener = m
    m.addUi(start)
  end sub

  sub onUiAction(actionId as string, button as BGE.UI.Button)
    if actionId = "start"
      m.game.changeScene("LevelScene")
    end if
  end sub
end class
```

`button.value` carries any extra data (a choice index, an item). `onActivate` still works
and runs before the listener. `setDisabled(true)` dims a button and takes it out of focus.

## MenuList

`BGE.UI.MenuList` is a panel with an optional title, a wrapped message and a column of
items. Picking an item calls the listener with the item's id. `open()` builds the panel and
focuses the first enabled item; `close()` removes it.

```brighterscript
menu = new BGE.UI.MenuList(m.game)
menu.title = "Adventure"
menu.listener = m
menu.addItem("continue", "Continue", saveSlot.exists()) ' disabled when there's no save
menu.addItem("new", "New Game")
menu.addItem("credits", "Credits")
menu.centered = true
menu.open() ' no parent: owned by the current scene
```

Leave `width`/`height` at 0 to fit the content, or set them (or call `setSize()`) to fix
them. A fixed height is a minimum: the panel still grows to fit its content. Spacing is set by `panelPadding`, `sectionGap`, `itemHeight`, `itemGap`, `itemWidth`
and `contentAlign`. Subclass to change more: `createButton(item)` returns the button for an
item (use your own `Button` subclass for a different look), and `buildChildren()` lays the
panel out.

While it's open:

- `setItemEnabled(id, enabled)` enables or disables an item and its button.
- `setMessage(text)` replaces the message in place (e.g. "Not enough coins"). The panel
  isn't resized, so keep to the lines it had.
- `focusItem(id)` focuses an item's button (false if it's missing or disabled);
  `focusFirstEnabled()` focuses the first enabled one.
- `getButton(id)` returns an item's button, `isOpen()` says whether the menu is open, and
  `centerIn(container)` re-centers it.

`setTitle()`, `clearItems()`, `addItem()` and `setSize()` take effect the next time the menu
opens. Opening an open menu rebuilds it.

## MessagePanel

`BGE.UI.MessagePanel` is a `MenuList` that centers itself, for pause, win and game-over
screens:

```brighterscript
panel = new BGE.UI.MessagePanel(m.game, 0, 0, [
  new BGE.UI.MessagePanelButton("Retry", invalid, "retry"),
  new BGE.UI.MessagePanelButton("Quit", invalid, "quit")
], "Game Over", "Score: 1200")
panel.listener = m
panel.show(m.game.gameUi)
```

## Theme

Panels take their colors from the theme (`game.defaultTheme`, or a container's `theme`):
`panelBackgroundColor` (or `panelBackgroundImage`, a 9-patch or plain image),
`panelTitleColor` and `panelTextColor`. Buttons use `backgroundColor`,
`hoveredBackgroundColor`, `focusedBorderColor`, `disabledColor` and `font`. Titles use the
"heading" font and messages the "body" font, falling back to "default". Set a panel's
`backgroundRGBA` to override its theme color.

## Pause menus and modals

`game.pushModal()` opens a modal: the game pauses while any modal is open, and nested ones
just count up. `game.popModal()` closes one and ignores the buttons held right then until
they're released, so the OK that picked "Resume" doesn't also jump (or close the modal
underneath); when the last closes the game resumes, unless it was already paused before the
first opened. A `Pause()` or `Resume()` while a modal
is open takes over, and closing the modal leaves it alone. Changing scene resumes the game
and forgets open modals, unless `game.keepPauseOnSceneChange` is set - and even then a pause
that only came from modals ends. `game.isModalOpen()` says whether any modal is open, and
`game.getModalDepth()` how many.

`BGE.PauseMenu` is a ready-made pause entity built on those:

```brighterscript
pause = new BGE.PauseMenu(m.game, {buttons: ["resume", "restart", "title"], titleScene: "TitleScene"})
pause.blockWhen = function(game as BGE.Game) as boolean
  return game.getEntityByName("GameOverPanel") <> invalid
end function
m.game.addEntity(pause)
```

It toggles on the "pause" action when that's bound, else the remote's Play, and Back closes
it. Built-in buttons are `resume`, `restart`, `title` and `quit`; `addButton(id, label)` adds
your own, which go to `listener.onUiAction()` (or override `onAction()`). `style: "text"`
just draws the title instead of a panel. Subclass it to change the look (`createMenu()`,
`drawTextStyle()`).

## UI owned by a scene

`scene.addUi(widget)` adds a widget to `gameUi` for the current visit only. When the game
leaves or resets the scene the widget is removed after `onDestroy()`, and its buttons stop
taking focus. A `MenuList` opened with no parent is added this way. Add a widget to
`game.gameUi` directly to keep it across scenes, e.g. a HUD owned by a persistent entity.

## Form widgets

Checkboxes, sliders, selects, text input and the on-screen keyboard are covered in
[Form Widgets](/form-widgets), with a settings screen built from them.
