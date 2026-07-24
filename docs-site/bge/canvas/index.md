---
title: Canvas
kind: class
longname: BGE.Canvas
description: Contains a roku roBitmap which all game objects get drawn to.
---

# Canvas

Contains a roku roBitmap which all game objects get drawn to.

**Properties**

- `bitmap` (ifDraw2D) — bitmap GameEntity images get drawn to
- `offset` (BGE.Math.Vector) — Position offset from screen coordinates (z value ignored)
- `scale` (BGE.Math.Vector) — Scale (z value ignored)
- `renderer` ([Renderer](/bge#renderer)) — Renderer for this canvas
- `rendererOptions` ([RendererOptions](/bge#rendereroptions))

---

## Constructor

<Signature
  code="new Canvas(
	gameEngine: Game,
	canvasWidth: integer,
	canvasHeight: integer,
	options?: RendererOptions,
): Canvas"
/>

Creates a Canvas object and bitmap

**Parameters**

- `gameEngine` ([Game](/bge#game))
- `canvasWidth` (integer) — width of canvas
- `canvasHeight` (integer) — height of canvas
- `options` ([RendererOptions](/bge#rendereroptions), optional, default: "{useBitmapPooling: true}")

---

## Instance Methods

<MemberHeading id="setsize" depth="3" name="setSize" sig="setSize(canvasWidth: integer, canvasHeight: integer): void" />

Changes the size of the canvas

**Parameters**

- `canvasWidth` (integer) — width of canvas
- `canvasHeight` (integer) — height of canvas

**Returns**

- `void`

<MemberHeading id="setbitmap" depth="3" name="setBitmap" sig="setBitmap(bitmap: ifDraw2D): void" />

**Parameters**

- `bitmap` (ifDraw2D)

**Returns**

- `void`

<MemberHeading id="clear" depth="3" name="clear" sig="clear(color: integer): void" />

Clears the canvas to the given background color

**Parameters**

- `color` (integer)

**Returns**

- `void`

<MemberHeading id="getoffset" depth="3" name="getOffset" sig="getOffset(): BGE.Math.Vector" />

Gets the offset of the canvas from the screen

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getscale" depth="3" name="getScale" sig="getScale(): BGE.Math.Vector" />

Gets the scale of the canvas

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="setoffset" depth="3" name="setOffset" sig="setOffset(x: float, y: float): void" />

Sets the offset of the canvas. This is as Float to allow incrementing by less than 1 pixel, it is converted to integer internally

**Parameters**

- `x` (float) — x offset
- `y` (float) — y offset

**Returns**

- `void`

<MemberHeading id="setscale" depth="3" name="setScale" sig="setScale(scale_x: float, scale_y?: float): void" />

Sets the scale of the canvas

**Parameters**

- `scale_x` (float) — horizontal scale
- `scale_y` (float, optional, default: "invalid") — vertical scale, or if invalid, use the horizontal scale as vertical scale

**Returns**

- `void`

<MemberHeading id="getwidth" depth="3" name="getWidth" sig="getWidth(): integer" />

Gets the width of the underlying bitmap

**Returns**

- `integer`

<MemberHeading id="getheight" depth="3" name="getHeight" sig="getHeight(): integer" />

Gets the height of the underlying bitmap

**Returns**

- `integer`
