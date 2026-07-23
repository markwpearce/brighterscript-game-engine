---
title: Camera2d
kind: class
longname: BGE.Camera2d
---

# Camera2d

**Extends:&#x20;**[`Camera`](/bge#camera)

**Properties**

- `top` (float)
- `bottom` (float)
- `right` (float)
- `left` (float)
- `near` (float)
- `far` (float)
- `name` (string)

---

## Constructor

<Signature code="new Camera2d(): Camera2d" />

---

## Instance Methods

<MemberHeading id="settarget" depth="3" name="setTarget" sig="setTarget(targetPos: BGE.Math.Vector): void" />

**Parameters**

- `targetPos` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="rotate" depth="3" name="rotate" sig="rotate(rotation: BGE.Math.Vector): void" />

**Parameters**

- `rotation` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="isinview" depth="3" name="isInView" sig="isInView(point: BGE.Math.Vector): boolean" />

**Parameters**

- `point` (BGE.Math.Vector)

**Returns**

- `boolean`

<MemberHeading id="computeworldtocameramatrix" depth="3" name="computeWorldToCameraMatrix" sig="computeWorldToCameraMatrix(): void" />

**Returns**

- `void`

<MemberHeading id="distancefromcamerafront" depth="3" name="distanceFromCameraFront" sig="distanceFromCameraFront(point: BGE.Math.Vector): float" />

**Parameters**

- `point` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading
  id="worldpointtocanvaspoint"
  depth="3"
  name="worldPointToCanvasPoint"
  sig="worldPointToCanvasPoint(
	pWorld: BGE.Math.Vector,
): BGE.Math.Vector"
/>

**Parameters**

- `pWorld` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`
