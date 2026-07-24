---
title: DrawableRectangle
kind: class
longname: BGE.DrawableRectangle
---

# DrawableRectangle

**Extends:&#x20;**[`Drawable`](/bge#drawable)

**Properties**

- `tempCanvas` (ifDraw2d)
- `lastWidth` (float)
- `lastHeight` (float)

---

## Constructor

<Signature
  code="new DrawableRectangle(
	owner: GameEntity,
	width: float,
	height: float,
	args?: roAssociativeArray,
): DrawableRectangle"
/>

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `width` (float)
- `height` (float)
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererObj: Renderer): BGE.SceneObject" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)
