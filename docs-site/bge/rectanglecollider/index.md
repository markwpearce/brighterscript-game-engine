---
title: RectangleCollider
kind: class
longname: BGE.RectangleCollider
description: Collider with the shape of a rectangle with bottom left at (offset.x, offset.y) - i.e. top left is at (offset.x, offset.y - height) - with given width and height
---

# RectangleCollider

**Extends:&#x20;**[`Collider`](/bge#collider)

Collider with the shape of a rectangle with bottom left at (offset.x, offset.y) - i.e. top left is at (offset.x, offset.y - height) - with given width and height

**Properties**

- `width` (float)
- `height` (float)

---

## Constructor

<Signature
  code="new RectangleCollider(
	colliderName: string,
	args?: roAssociativeArray,
): RectangleCollider"
/>

Create a new RectangleCollider

**Parameters**

- `colliderName` (string) — name of this collider
- `args` (roAssociativeArray, optional, default: "{}") — additional properties (e.g {width: 10, height: 20})

---

## Instance Methods

<MemberHeading id="refreshcolliderregion" depth="3" name="refreshColliderRegion" sig="refreshColliderRegion(): void" />

Refreshes the collider

**Returns**

- `void`

<MemberHeading
  id="debugdraw"
  depth="3"
  name="debugDraw"
  sig="debugDraw(
	renderObj: Renderer,
	position: BGE.Math.Vector,
	color?: integer,
	addName?: boolean,
	font?: roFont,
): void"
/>

Draws the rectangle outline around the collider

**Parameters**

- `renderObj` ([Renderer](/bge#renderer))
- `position` (BGE.Math.Vector)
- `color` (integer, optional, default: "\&hFF0000FF")
- `addName` (boolean, optional, default: false)
- `font` (roFont, optional, default: "invalid")

**Returns**

- `void`
