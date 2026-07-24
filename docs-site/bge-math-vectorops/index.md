---
title: BGE/Math/VectorOps
kind: namespace
longname: BGE/Math/VectorOps
---

# BGE/Math/VectorOps

**Alias:** `BGE.Math.VectorOps`

---

## Static Methods

<MemberHeading id="create" depth="3" name="create" sig="create(x?: float, y?: float, z?: dynamic): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `x` (float, optional, default: "0.0")
- `y` (float, optional, default: "0.0")
- `z` (dynamic, optional, default: "0.0")

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="setfrom" depth="3" name="setFrom" sig="setFrom(a: BGE.Math.Vector, b: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `b` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="add" depth="3" name="add" sig="add(a: BGE.Math.Vector, b: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `b` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="equals" depth="3" name="equals" sig="equals(a: BGE.Math.Vector, b: BGE.Math.Vector): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `b` (BGE.Math.Vector)

**Returns**

- `boolean`

<MemberHeading id="plusequals" depth="3" name="plusEquals" sig="plusEquals(a: BGE.Math.Vector, v: BGE.Math.Vector): void" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading
  id="subtract"
  depth="3"
  name="subtract"
  sig="subtract(
	a: BGE.Math.Vector,
	v: BGE.Math.Vector,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="minusequals" depth="3" name="minusEquals" sig="minusEquals(a: BGE.Math.Vector, v: BGE.Math.Vector): void" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="negative" depth="3" name="negative" sig="negative(a: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="flipx" depth="3" name="flipX" sig="flipX(a: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="flipy" depth="3" name="flipY" sig="flipY(a: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="scale" depth="3" name="scale" sig="scale(v: BGE.Math.Vector, r: float): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)
- `r` (float)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="scaleequals" depth="3" name="scaleEquals" sig="scaleEquals(v: BGE.Math.Vector, r: float): void" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)
- `r` (float)

**Returns**

- `void`

<MemberHeading
  id="multiply"
  depth="3"
  name="multiply"
  sig="multiply(
	a: BGE.Math.Vector,
	v: BGE.Math.Vector,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="multequals" depth="3" name="multEquals" sig="multEquals(a: BGE.Math.Vector, v: BGE.Math.Vector): void" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="dotproduct" depth="3" name="dotProduct" sig="dotProduct(a: BGE.Math.Vector, v: BGE.Math.Vector): float" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading id="divide" depth="3" name="divide" sig="divide(a: BGE.Math.Vector, r: float): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `r` (float)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="copy" depth="3" name="copy" sig="copy(v: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

Makes a copy of this vector

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="crossproduct"
  depth="3"
  name="crossProduct"
  sig="crossProduct(
	a: BGE.Math.Vector,
	v: BGE.Math.Vector,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="norm" depth="3" name="norm" sig="norm(v: BGE.Math.Vector): float" />

<MemberMeta badges="static" />

Gets the square of the length of a vector

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading id="length" depth="3" name="length" sig="length(v: BGE.Math.Vector): float" />

<MemberMeta badges="static" />

Gets the length of a vector

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading id="manhattanlength" depth="3" name="manhattanLength" sig="manhattanLength(v: BGE.Math.Vector): float" />

<MemberMeta badges="static" />

Gets the manhattan length of a vector

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading id="normalize" depth="3" name="normalize" sig="normalize(v: BGE.Math.Vector): void" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading id="getnormalizedcopy" depth="3" name="getNormalizedCopy" sig="getNormalizedCopy(v: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="nearestint" depth="3" name="nearestInt" sig="nearestInt(v: BGE.Math.Vector): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="tostr" depth="3" name="toStr" sig="toStr(v: BGE.Math.Vector): string" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `string`

<MemberHeading id="toarray" depth="3" name="toArray" sig="toArray(v: BGE.Math.Vector): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `dynamic`

<MemberHeading id="isparallel" depth="3" name="isParallel" sig="isParallel(a: BGE.Math.Vector, v: BGE.Math.Vector): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `boolean`

<MemberHeading id="iszero" depth="3" name="isZero" sig="isZero(v: BGE.Math.Vector): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `v` (BGE.Math.Vector)

**Returns**

- `boolean`

<MemberHeading
  id="minbound"
  depth="3"
  name="minBound"
  sig="minBound(
	a: BGE.Math.Vector,
	v: BGE.Math.Vector,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="maxbound"
  depth="3"
  name="maxBound"
  sig="maxBound(
	a: BGE.Math.Vector,
	v: BGE.Math.Vector,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `v` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`
