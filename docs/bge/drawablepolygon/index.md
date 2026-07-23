---
title: DrawablePolygon
kind: class
longname: BGE.DrawablePolygon
---

# DrawablePolygon

**Extends:&#x20;**[`Drawable`](/bge#drawable)

**Properties**

- `points` (dynamic) — the set of points defining a convex polygon

---

## Constructor

<Signature
  code="new DrawablePolygon(
	owner: GameEntity,
	points?: dynamic,
	args?: roAssociativeArray,
): DrawablePolygon"
/>

**Parameters**

- `owner` ([GameEntity](/bge#gameentity))
- `points` (dynamic, optional, default: "\[]")
- `args` (roAssociativeArray, optional, default: "{}")

---

## Instance Methods

<MemberHeading id="addtoscene" depth="3" name="addToScene" sig="addToScene(rendererObj: Renderer): BGE.SceneObject" />

**Parameters**

- `rendererObj` ([Renderer](/bge#renderer))

**Returns**

- [`BGE.SceneObject`](/bge#sceneobject)
