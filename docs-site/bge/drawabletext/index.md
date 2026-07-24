---
title: DrawableText
kind: class
longname: BGE.DrawableText
description: Class to draw text
---

# DrawableText

**Extends:&#x20;**[`Drawable`](/bge#drawable)

Class to draw text

**Properties**

- `text` (string) — The text to write on the screen
- `font` (roFont) — The Font object to use ( get this from the font registry)
- `alignment` (BGE.UI.HorizAlignment) — The Horizontal alignment for the text
- `lastTextValue` (string)
- `tempCanvas` (roBitmap)
- `tempRegion` (roRegion)

---

## Constructor

<Signature
  code="new DrawableText(
	owner: GameEntity,
	text?: string,
	font?: roFont,
	args?: roAssociativeArray,
): DrawableText"
/>

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `text` (string, optional, default: "\\"\\"")
- `font` (roFont, optional, default: "invalid")
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererObj: Renderer): BGE.SceneObject" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)

<MemberHeading id="gettextimage" depth="3" name="getTextImage" sig="getTextImage(): roRegion" />

**Returns**

- `roRegion`

<MemberHeading id="getworldposition" depth="3" name="getWorldPosition" sig="getWorldPosition(): BGE.Math.Vector" />

**Returns**

- `BGE.Math.Vector`
