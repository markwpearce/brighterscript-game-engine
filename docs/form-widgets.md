---
title: Form Widgets
group: Guides
order: 22
---

# Form Widgets

`BGE.UI` has a few widgets for entering values: `Checkbox`, `Slider`, `Select`,
`TextInput` and an on-screen `Keyboard`, plus `Label` for text. This guide builds a
settings screen out of them. It covers focus, the three `Select` styles, typing a name with
the keyboard, background images and sounds. The runnable reference is `examples/ui`.

The widgets live in `game.gameUi` and follow the rules in [Menus and Panels](/ui-menus):
add them with `scene.addUi()` and they go away when the scene does.

## The settings screen

This scene puts one of each control on the screen and a Save button at the bottom. Save
reads every value back with `getValue()`, so the controls don't need callbacks:

```brighterscript
class SettingsScene extends BGE.GameScene

  private musicCheckbox as BGE.UI.Checkbox
  private volumeSlider as BGE.UI.Slider
  private difficultySelect as BGE.UI.Select
  private nameInput as BGE.UI.TextInput
  private keyboard as BGE.UI.Keyboard

  sub new(game as BGE.Game)
    super(game)
    m.name = "SettingsScene"
  end sub

  override sub onCreate(args as roAssociativeArray)
    width = m.game.uiCanvas.getWidth()
    height = m.game.uiCanvas.getHeight()

    title = new BGE.UI.Label(m.game)
    title.setText("Settings")
    title.customPosition = true
    title.customX = width * 0.11
    title.customY = height * 0.12
    m.addUi(title)

    m.musicCheckbox = new BGE.UI.Checkbox(m.game)
    m.musicCheckbox.setLabel("Music")
    m.musicCheckbox.checked = true
    m.musicCheckbox.customPosition = true
    m.musicCheckbox.customX = width * 0.11
    m.musicCheckbox.customY = height * 0.25
    m.addUi(m.musicCheckbox)

    volumeLabel = new BGE.UI.Label(m.game)
    volumeLabel.setText("Volume")
    volumeLabel.customPosition = true
    volumeLabel.customX = width * 0.11
    volumeLabel.customY = height * 0.32
    m.addUi(volumeLabel)

    m.volumeSlider = new BGE.UI.Slider(m.game)
    m.volumeSlider.minValue = 0.0
    m.volumeSlider.maxValue = 10.0
    m.volumeSlider.step = 1.0
    m.volumeSlider.setValue(7.0)
    m.volumeSlider.customPosition = true
    m.volumeSlider.customX = width * 0.11
    m.volumeSlider.customY = height * 0.36
    m.volumeSlider.width = width * 0.27
    m.volumeSlider.height = height * 0.04
    m.addUi(m.volumeSlider)

    m.difficultySelect = new BGE.UI.Select(m.game)
    m.difficultySelect.options = ["Easy", "Normal", "Hard"]
    m.difficultySelect.selectedIndex = 1
    m.difficultySelect.customPosition = true
    m.difficultySelect.customX = width * 0.11
    m.difficultySelect.customY = height * 0.45
    m.difficultySelect.width = width * 0.27
    m.difficultySelect.height = height * 0.083
    m.addUi(m.difficultySelect)

    m.nameInput = new BGE.UI.TextInput(m.game)
    m.nameInput.placeholder = "Enter your name"
    m.nameInput.maxLength = 12
    m.nameInput.customPosition = true
    m.nameInput.customX = width * 0.55
    m.nameInput.customY = height * 0.25
    m.nameInput.width = width * 0.34
    m.nameInput.height = height * 0.075
    m.addUi(m.nameInput)

    ' Opened by OK on the name field. It stays out of the scene until then.
    m.keyboard = new BGE.UI.Keyboard(m.game)
    m.keyboard.customPosition = true
    m.keyboard.customX = width * 0.55
    m.keyboard.customY = height * 0.4
    m.keyboard.width = width * 0.34
    m.keyboard.height = height * 0.4
    m.nameInput.keyboard = m.keyboard

    saveButton = new BGE.UI.Button(m.game)
    saveButton.setLabel("Save")
    saveButton.actionId = "save"
    saveButton.listener = m
    saveButton.customPosition = true
    saveButton.customX = width * 0.11
    saveButton.customY = height * 0.8
    saveButton.width = width * 0.2
    saveButton.height = height * 0.083
    m.addUi(saveButton)

    ' Focuses the first control now, rather than after the first press.
    m.game.focusManager.ensureFocusSeeded()
  end sub

  sub onUiAction(actionId as string, button as BGE.UI.Button)
    if actionId = "save"
      music = m.musicCheckbox.getValue() as boolean
      volume = m.volumeSlider.getValue() as float
      difficulty = m.difficultySelect.getValue() as string
      playerName = m.nameInput.getValue() as string
      ' ...store the values somewhere, then leave
      m.game.changeScene("MainScene")
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back") and not input.consumed and not m.keyboard.isShown()
      m.game.changeScene("MainScene")
    end if
  end sub

end class
```

Save is a `Button` with an `actionId` and `listener = m`, so the scene handles it in
`onUiAction()` (see [Menus and Panels](/ui-menus)).
The `onInput()` override is what makes Back leave the screen. It skips the press while the
keyboard is open, because the keyboard uses Back to cancel.

`BGE.UI.Label` is not focusable, so it only draws text. A `Select` has no label of its own,
so put a `Label` above or beside it, as this scene does.

## Focus

Focus moves through the widgets in the order you called `addChild()` (or `addUi()`). With the
default list mode, Up and Down move to the next or previous widget, and Left and Right do the
same unless the focused widget uses them. A focused `Slider`, an inline or horizontal `Select`,
or a `TextInput` takes Left and Right for itself. Focus stays on that widget until you press
Up or Down.

Call `game.focusManager.ensureFocusSeeded()` at the end of `onCreate()`. Without it, nothing
is focused until the player's first press.

Keep the widgets you want to reach in one container, in the order a player should move
through them.

## Checkbox

`BGE.UI.Checkbox` is a box with a label to its right. Its box is 20 by 20 pixels unless you
set `width` and `height`. Its fields and methods:

- `checked` is the current state, `false` by default.
- `setLabel(text)` sets the label.
- `getValue()` returns the state as a `boolean`.
- `onChanged` is called after each toggle with the checkbox as its argument, for example
  `sub(checkbox as BGE.UI.Checkbox)`.

Pressing OK toggles the box.

## Slider

`BGE.UI.Slider` picks a number between `minValue` and `maxValue` (0 to 100 by default). Each
Left or Right press moves it by `step` (1 by default). A held direction keeps stepping while
it's held. The label draws above the bar, so leave room for it. The slider draws
nothing if `width` or `height` is 0.

- `setValue(value)` sets the value and clamps it to the range.
- `increase()` and `decrease()` change it by `step`, or by an amount you pass in.
- `getValue()` returns the value as a `float`.
- `setLabel(text)` sets the label.
- `barColor` and `backgroundColor` override the theme colors.

A slider has no change callback. Read it with `getValue()` when you need it, as the Save
button above does.

## Select

`BGE.UI.Select` picks one value from `options`, an array of values (usually strings).
`selectedIndex` is the current index, and `getValue()` returns the option at that index.
Set `style` to choose how it works. The default is `BGE.UI.SelectStyle.inline`.

- **`inline`** shows the current option in the box. Left and Right cycle through the
  options and wrap around at the ends. Use `next()` and `previous()` to move the selection
  from code.
- **`popup`** shows the current option in the box. OK opens a list of every option below
  the box. Up and Down move the highlight, OK commits it, and Back cancels. Losing focus
  closes the list. Left and Right do nothing while the list is open. The list is not
  scrolled or clipped, so keep the option count small enough to fit on screen.
- **`horizontal`** draws every option side by side in one row, with the current one
  highlighted. Left and Right move to the neighbouring option and stop at the ends, without
  wrapping. Give the widget a wide `width`, since each option gets an equal slot. Labels
  wider than their slot are drawn past it and not clipped.

Every style fires `onChanged` with the select as its argument when the selection changes.
In `popup` style that happens on commit, not while the highlight moves.

```brighterscript
m.difficultySelect.style = BGE.UI.SelectStyle.popup
m.difficultySelect.options = ["Easy", "Normal", "Hard", "Expert"]
```

## TextInput

`BGE.UI.TextInput` is a single line of text with a caret. Its main fields:

- `text` holds the text, and `getValue()` returns it.
- `placeholder` is shown dimmed while the field is empty and unfocused.
- `maxLength` caps the length. `0`, the default, means no cap. Characters past the cap are
  dropped.
- `onChanged` is called after each insert or delete, and `onSubmit` when OK is pressed
  (unless a `keyboard` is set, in which case OK opens the keyboard). Both are called with the
  input as their argument.

Left and Right move the caret, Backspace deletes before it and Enter submits. The field
doesn't clip or scroll, so text wider than the field runs past its right edge. Set
`maxLength` to something that fits.

Characters from the Roku mobile app's keyboard also reach the field, so a player can type
without the on-screen keyboard. The backspace behaviour of the mobile app has not been
checked on a device, so test it before you depend on it.

### On-screen keyboard

`BGE.UI.Keyboard` is a grid of keys for a `roScreen` game, where the Roku's own keyboards
aren't available. Set it on the `TextInput`, as the settings screen does, and OK on the field
opens it. Or open it yourself with `keyboard.show(container, textInput)`. `hide()` closes
it and returns focus to the field.

While the keyboard is open, the remote does this:

| Remote | While the keyboard is open |
| --- | --- |
| D-pad | Move the highlight. It wraps, and Up and Down land on the nearest key. |
| OK | Press the highlighted key. |
| Back | Cancel. The field gets back the text it had when the keyboard opened, and `onCancel` fires. |
| Play, or the Done key | Close the keyboard, fire `onDone`, then the field's `onSubmit`. |
| Replay | Delete. |
| Fast-forward | Type a space. |

The keyboard is one widget, so focus can't leave it while it's open. Set `onDone` and
`onCancel` to a `sub(keyboard as BGE.UI.Keyboard)` if you need to know when it closes.

The layout is chosen by the factory you pass in:

- `BGE.UI.createAlphabeticalKeyboardLayout()` is the default.
- `BGE.UI.createQwertyKeyboardLayout()` is a QWERTY layout.
- `BGE.UI.createCompactKeyboardLayout()` has only A to Z and 0 to 9, which suits
  arcade-style name entry.

Pass one to `new BGE.UI.Keyboard(game, layout)`, or assign `keyboard.layout` later. The
alphabetical and QWERTY layouts have a Shift page and a symbols page. Build your own layout
with `KeyboardPage`s and `KeyboardRow`s, using `createKeyboardCharRow()` for the letters in a
row.

To change the layout while the scene runs, as the `TextInputScene` in `examples/ui` does,
assign `keyboard.layout` and set `keyboard.width` to suit.

## Backgrounds

By default a widget's background is a flat color from the theme. To use an image instead,
set `backgroundImage` on a theme. `BGE.UI.loadBackgroundImage()` loads one from a path and
picks the right type for you:

- A path ending in `.9.png` (any case) loads as a `BGE.UI.NinePatchImage`. Its corners stay
  fixed and its edges and centre stretch, so one small image fits any widget size.
- Any other path loads as a `BGE.UI.ImageBackground`, which stretches the whole image to fill
  the widget.

It returns `invalid` if the file can't be loaded. Load the image once, not every time the
scene opens:

```brighterscript
' in main.bs, once
panelBackground = BGE.UI.loadBackgroundImage("pkg:/images/panel.9.png")
```

Then set it on the theme. Setting it on `game.defaultTheme` covers every widget in the
game. Setting it on one `UiContainer`'s `theme` covers only that container's children. That
is the better choice for a settings panel, because the rest of the game keeps its flat
colors. Set `defaultTheme.backgroundImage` back to `invalid` when you leave a scene that set
it.

```brighterscript
m.game.defaultTheme.backgroundImage = panelBackground
```

`Button`, `Checkbox`, `Slider`, `TextInput` and `Select` all draw the image. The image is the
same whatever the focus or hover state.

To make a `.9.png`, add a one-pixel transparent border. Mark the stretchable part with black
pixels along the top row and the left column. The border is removed when the image loads.
Android's 9-patch convention is the same, so any 9-patch tool will prepare the file. See
[Engine Internals](/engine-internals) for the
details and for loading a 9-patch from a bitmap yourself.

## Sounds

Only `Button` plays sounds. Load the sounds once with `game.loadSound()`, then name them in
the game's defaults:

```brighterscript
m.game.loadSound("uiFocus", "pkg:/sounds/ui_focus.wav")
m.game.loadSound("uiClick", "pkg:/sounds/ui_click.wav")
m.game.uiFocusSoundKey = "uiFocus"
m.game.uiClickSoundKey = "uiClick"
```

Every `Button` then plays `uiFocus` when it gains focus and `uiClick` when it's clicked. A
button can set its own `focusSoundKey` or `clickSoundKey` to override the default. The
defaults are empty, so a game with no keys set plays nothing.

The checkboxes, sliders and selects in this guide don't play sounds. If you want one, call
`m.game.playSound()` yourself in the code that reacts to the change, such as the Save handler
or a poll in `onUpdate()`.

## Examples

`examples/ui` has a demo scene for each of these:

- `Scenes/PopupSelectScene.bs` has all three `Select` styles, and a popup inside a themed
  container.
- `Scenes/TextInputScene.bs` has a `TextInput` with a keyboard and a switch between the
  alphabetical and QWERTY layouts.
- `Scenes/NinePatchScene.bs` shows a 9-patch behind buttons of several sizes.
- `Scenes/ImageBackgroundScene.bs` shows a plain image background.

Keep the controls inside the title-safe area: at least 10% in from every edge of
`game.uiCanvas`. The examples place everything as a fraction of the canvas width and height,
which keeps the layout correct on any screen size.
