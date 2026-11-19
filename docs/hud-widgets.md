---
title: HUD and Info Widgets
group: Guides
order: 14
---

# HUD and Info Widgets

Screen-space widgets for `game.gameUi`. Each works with defaults and has fields for its
colors, fonts and timing. Each can also be drawn by hand from a draw hook (`drawAt()`/
`drawOn()`, with `update(dt)` each frame) if you'd rather not put it in the widget tree.

## Meter

`BGE.UI.Meter` is a bar on a backing, for health, stamina or a boss:

```brighterscript
health = new BGE.UI.Meter(m.game)
health.customPosition = true
health.customX = 128
health.customY = 72
health.width = 380
health.height = 14
health.lagEnabled = true ' lost health lingers, then drains
m.addUi(health)

' each frame
health.setValue(player.health, player.maxHealth)
```

- `lagEnabled`: a drop leaves the lost part in `lagColor` for `lagHoldSeconds`, then it
  drains at `lagDrainPerSecond`. `resetValue()` jumps without it.
- `refuse()` blinks the fill (e.g. not enough stamina); `blinkWhenEmpty` blinks an empty bar.
- `setLayer(key, fraction, color)` adds fills under the main one.
- `label` draws text above the bar, like a boss's name.

## Banner

`BGE.UI.Banner` fades a line of text in and out on a dark band across the screen:

```brighterscript
m.banner = new BGE.UI.Banner(m.game)
m.addUi(m.banner)
m.banner.show("Boss defeated", 3)
```

## CreditsView

`BGE.UI.CreditsView` shows entries of `{text, style}` (`"title"`, `"heading"`, `"body"` or
your own in `styleColors`/`styleFonts`), wrapped to fit, scrolling up or (`mode = "static"`)
laid out from the top. It fills the title-safe area by default.

```brighterscript
m.credits = new BGE.UI.CreditsView(m.game, [
  {text: "My Game", style: "title"},
  {text: ""},
  {text: "Code", style: "heading"},
  {text: "Me"}
])
m.addUi(m.credits)
' hold Down to speed up, OK to skip
m.credits.setFast(true)
if m.credits.isFinished() ...
```

## ControllerQrWidget

`BGE.UI.ControllerQrWidget` shows a [QR code](/qr-codes) for the phone/browser
[controller](/controller-input) page, with a caption and the URL under it. The URL comes
from `game.getControllerConnectionInfo()` unless you pass one.

```brighterscript
m.game.enableControllerInput()
qr = new BGE.UI.ControllerQrWidget(m.game, "", 240)
qr.caption = "Scan to use your phone as a controller"
qr.layout()
m.addUi(qr)
```

## Controls legend

`game.controls.describeBindings()` lists every bound action with its label and buttons, in
`bindAction()` order, so a controls screen doesn't have to be written by hand:

```brighterscript
for each binding in m.game.controls.describeBindings(true)
  lines.push(binding.text) ' "Attack: OK / A"
end for
```

Each entry also has `label` and `buttons` (display names, e.g. `["OK", "A"]`) to format your
own way.
