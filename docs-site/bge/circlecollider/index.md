---
title: CircleCollider
kind: class
longname: BGE.CircleCollider
description: Collider with the shape of a circle centered at (offset.x, offset.y), with given radius
---

# CircleCollider

**Extends:&#x20;**[`Collider`](/bge#collider)

Collider with the shape of a circle centered at (offset.x, offset.y), with given radius

**Properties**

- `radius` (integer) — Radius of the collider

---

## Constructor

<Signature
  code="new CircleCollider(
	colliderName: string,
	args?: roAssociativeArray,
): CircleCollider"
/>

Create a new CircleCollider

**Parameters**

- `colliderName` (string) — name of this collider
- `args` (roAssociativeArray, optional, default: "{}") — additional properties (e.g {radius: 10})

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

Draws the circle outline around the collider

**Parameters**

- `renderObj` ([Renderer](/bge#renderer))
- `position` (BGE.Math.Vector)
- `color` (integer, optional, default: "\&hFF0000FF")
- `addName` (boolean, optional, default: false)
- `font` (roFont, optional, default: "invalid")

**Returns**

- `void`
