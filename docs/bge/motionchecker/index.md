---
title: MotionChecker
kind: class
longname: BGE.MotionChecker
---

# MotionChecker

**Properties**

- `previousTransform` (dynamic)
- `movedLastFrame` (boolean)

---

## Constructor

<Signature code="new MotionChecker(): MotionChecker" />

---

## Instance Methods

<MemberHeading
  id="check"
  depth="3"
  name="check"
  sig="check(
	position?: BGE.Math.Vector,
	rotation?: BGE.Math.Vector,
	scale?: BGE.Math.Vector,
): boolean"
/>

Is the current transform as given different from the previous?

**Parameters**

- `position` (BGE.Math.Vector, optional, default: "invalid")
- `rotation` (BGE.Math.Vector, optional, default: "invalid")
- `scale` (BGE.Math.Vector, optional, default: "invalid")

**Returns**

- `boolean` — True if different from previous

<MemberHeading id="resetmovedflag" depth="3" name="resetMovedFlag" sig="resetMovedFlag(): void" />

**Returns**

- `void`

<MemberHeading
  id="settransform"
  depth="3"
  name="setTransform"
  sig="setTransform(
	position: BGE.Math.Vector,
	rotation: BGE.Math.Vector,
	scale?: BGE.Math.Vector,
): void"
/>

**Parameters**

- `position` (BGE.Math.Vector)
- `rotation` (BGE.Math.Vector)
- `scale` (BGE.Math.Vector, optional, default: "invalid")

**Returns**

- `void`

<MemberHeading
  id="getpositiondifference"
  depth="3"
  name="getPositionDifference"
  sig="getPositionDifference(
	currentPosition: BGE.Math.Vector,
): BGE.Math.Vector"
/>

**Parameters**

- `currentPosition` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="getrotationdifference"
  depth="3"
  name="getRotationDifference"
  sig="getRotationDifference(
	currentRotation: BGE.Math.Vector,
): BGE.Math.Vector"
/>

**Parameters**

- `currentRotation` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`
