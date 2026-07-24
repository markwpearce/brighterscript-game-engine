---
title: CornerPoints
kind: class
longname: BGE/Math.CornerPoints
---

# CornerPoints

**Properties**

- `topLeft` (dynamic)
- `topRight` (dynamic)
- `bottomLeft` (dynamic)
- `bottomRight` (dynamic)

---

## Constructor

<Signature code="new CornerPoints(): CornerPoints" />

---

## Instance Methods

<MemberHeading id="toarray" depth="3" name="toArray" sig="toArray(): dynamic" />

Returns the points in the order of topLeft, topRight, bottomLeft, bottomRight

**Returns**

- `dynamic`

<MemberHeading id="toclockwiseoutlinearray" depth="3" name="toClockwiseOutlineArray" sig="toClockwiseOutlineArray(): dynamic" />

Returns the points in the order of topLeft, topRight, bottomRight, bottomLeft

**Returns**

- `dynamic`

<MemberHeading id="setpointbyindex" depth="3" name="setPointByIndex" sig="setPointByIndex(index: integer, newValue: Vector): void" />

**Parameters**

- `index` (integer)
- `newValue` ([Vector](/bge-math#vector))

**Returns**

- `void`

<MemberHeading id="getnormal" depth="3" name="getNormal" sig="getNormal(): Vector" />

**Returns**

- [`Vector`](/bge-math#vector)

<MemberHeading id="getavgwidth" depth="3" name="getAvgWidth" sig="getAvgWidth(): float" />

**Returns**

- `float`

<MemberHeading id="getmaxwidth" depth="3" name="getMaxWidth" sig="getMaxWidth(): float" />

**Returns**

- `float`

<MemberHeading id="getavgheight" depth="3" name="getAvgHeight" sig="getAvgHeight(): float" />

**Returns**

- `float`

<MemberHeading id="getmaxheight" depth="3" name="getMaxHeight" sig="getMaxHeight(): float" />

**Returns**

- `float`

<MemberHeading id="getavgrotation" depth="3" name="getAvgRotation" sig="getAvgRotation(): float" />

**Returns**

- `float`

<MemberHeading
  id="getrotationoftopleftbottomrightdiagonal"
  depth="3"
  name="getRotationOfTopLeftBottomRightDiagonal"
  sig="getRotationOfTopLeftBottomRightDiagonal(
	originalDiagonal?: Vector,
): float"
/>

**Parameters**

- `originalDiagonal` ([Vector](/bge-math#vector), optional, default: "BGE.Math.VectorOps.create(1, 0, 0)")

**Returns**

- `float`

<MemberHeading
  id="getrotationoftoprightbottomleftdiagonal"
  depth="3"
  name="getRotationOfTopRightBottomLeftDiagonal"
  sig="getRotationOfTopRightBottomLeftDiagonal(
	originalDiagonal?: Vector,
): float"
/>

**Parameters**

- `originalDiagonal` ([Vector](/bge-math#vector), optional, default: "BGE.Math.VectorOps.create(1, 0, 0)")

**Returns**

- `float`

<MemberHeading id="computesidelengths" depth="3" name="computeSideLengths" sig="computeSideLengths(): dynamic" />

**Returns**

- `dynamic`

<MemberHeading id="computediagonallengths" depth="3" name="computeDiagonalLengths" sig="computeDiagonalLengths(): dynamic" />

**Returns**

- `dynamic`

<MemberHeading id="getcenter" depth="3" name="getCenter" sig="getCenter(): Vector" />

**Returns**

- [`Vector`](/bge-math#vector)

<MemberHeading id="getbounds" depth="3" name="getBounds" sig="getBounds(): dynamic" />

**Returns**

- `dynamic`

<MemberHeading id="copy" depth="3" name="copy" sig="copy(): CornerPoints" />

**Returns**

- [`CornerPoints`](/bge-math#cornerpoints)

<MemberHeading id="subtract" depth="3" name="subtract" sig="subtract(vect: Vector): CornerPoints" />

**Parameters**

- `vect` ([Vector](/bge-math#vector))

**Returns**

- [`CornerPoints`](/bge-math#cornerpoints)

<MemberHeading id="add" depth="3" name="add" sig="add(vect: Vector): CornerPoints" />

**Parameters**

- `vect` ([Vector](/bge-math#vector))

**Returns**

- [`CornerPoints`](/bge-math#cornerpoints)

<MemberHeading id="tostr" depth="3" name="toStr" sig="toStr(): string" />

**Returns**

- `string`
