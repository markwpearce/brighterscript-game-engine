---
title: QR Codes
group: Guides
order: 7
---

# QR Codes

`BGE.QrCode` encodes and draws QR codes directly on a plain `roScreen` channel
- no SceneGraph, no image asset. Handy anywhere you'd otherwise show a URL for
a player to type in by hand, like [connecting a controller](/controller-input).

```brighterscript
BGE.QrCode.draw(renderer, x, y, "https://example.com", 200)
```

![A QR code drawn next to the controller connection URL text](images/qr-code-controller-connect.jpg)

`renderer` is any `BGE.Renderer` (game canvas or UI canvas); `x`/`y` are the
top-left corner and `width` the rendered size in pixels (square). It draws
black-on-white by default - pass `darkRgba`/`lightRgba` (packed RGBA) for a
different look:

```brighterscript
BGE.QrCode.draw(renderer, x, y, code, width, BGE.Colors.White, BGE.Colors.Black)
```

## Drawing one every frame

A `GameEntity`/`Room`'s `onDrawEnd(gameRenderer, uiRenderer)` hook runs once
per frame after the normal scene draw - the natural place to draw a QR code
alongside the rest of your UI. The UI renderer stays crisp regardless of game
canvas scaling, so it's usually the right target for something like this:

```brighterscript
override sub onDrawEnd(gameRenderer as BGE.Renderer, uiRenderer as BGE.Renderer)
  BGE.QrCode.draw(uiRenderer, 20, 20, m.game.getControllerConnectionInfo(), 150)
end sub
```

## Encoding without drawing

`BGE.QrCode.qrEncodeText(text, ecl)` returns a `BGE.QrCode.QrCode` you can
inspect module-by-module - useful if you want to draw it some other way (a
`Model3d` texture, a custom shape, etc.) instead of `draw()`'s plain filled
squares:

```brighterscript
qr = BGE.QrCode.qrEncodeText("hello", BGE.QrCode.EccLevel.medium)
isDark = qr.getModule(x, y) ' x, y in [0, qr.size)
```

`ecl` is a `BGE.QrCode.EccLevel` (`low`/`medium`/`quartile`/`high`) - a higher
level survives more damage/obstruction before becoming unreadable, at the
cost of a denser (sometimes larger) code for the same text.

See `examples/controller`'s `MainRoom` for a runnable example (drawing the
controller connection URL as a QR code instead of - or alongside - plain
text).
