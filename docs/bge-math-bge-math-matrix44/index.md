---
title: BGE/Math/BGE/Math/Matrix44
kind: namespace
longname: BGE/Math/BGE/Math/Matrix44
---

# BGE/Math/BGE/Math/Matrix44

**Alias:** `BGE.Math.BGE.Math.Matrix44`

---

## Static Methods

<MemberHeading id="create" depth="3" name="create" sig="create(values?: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `values` (dynamic, optional, default: "invalid")

**Returns**

- `dynamic`

<MemberHeading id="copy" depth="3" name="copy" sig="copy(mat: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `mat` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="setfrom" depth="3" name="setFrom" sig="setFrom(mat: dynamic, b: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `mat` (dynamic)
- `b` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="equals" depth="3" name="equals" sig="equals(mat: dynamic, b: dynamic): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `mat` (dynamic)
- `b` (dynamic)

**Returns**

- `boolean`

<MemberHeading id="multiply" depth="3" name="multiply" sig="multiply(mat: dynamic, operand: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `mat` (dynamic)
- `operand` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="transposed" depth="3" name="transposed" sig="transposed(mat: dynamic): dynamic" />

<MemberMeta badges="static" />

Returns the transposed version of this Matrix

**Parameters**

- `mat` (dynamic)

**Returns**

- `dynamic`

<MemberHeading
  id="multvecmatrix"
  depth="3"
  name="multVecMatrix"
  sig="multVecMatrix(
	srcVect: BGE.Math.Vector,
	mat: dynamic,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

The coordinate w more often than not equals 1, but it can be different than 1 especially when the matrix is projective matrix (perspective projection matrix).

**Parameters**

- `srcVect` (BGE.Math.Vector)
- `mat` (dynamic)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="multdirmatrix"
  depth="3"
  name="multDirMatrix"
  sig="multDirMatrix(
	srcVect: BGE.Math.Vector,
	mat: dynamic,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

This method needs to be used for vector-matrix multiplication. Look at the differences with the previous method (to compute a point-matrix multiplication). We don't use the coefficients in the matrix that account for translation (x\[3]\[0], x\[3]\[1], x\[3]\[2]) and we don't compute w.

**Parameters**

- `srcVect` (BGE.Math.Vector)
- `mat` (dynamic)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="inverse" depth="3" name="inverse" sig="inverse(mat: dynamic): dynamic" />

<MemberMeta badges="static" />

Compute the inverse of the matrix using the Gauss-Jordan (or reduced row) elimination method. We didn't explain in the lesson on Geometry how the inverse of matrix can be found. Don't worry at this point if you don't understand how this works. But we will need to be able to compute the inverse of matrices in the first lessons of the "Foundation of 3D Rendering" section, which is why we've added this code. For now, you can just use it and rely on it for doing what it's supposed to do. If you want to learn how this works though, check the lesson on called Matrix Inverse in the "Mathematics and Physics of Computer Graphics" section.

**Parameters**

- `mat` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="invert" depth="3" name="invert" sig="invert(mat: dynamic): void" />

<MemberMeta badges="static" />

Set current matrix to its inverse

**Parameters**

- `mat` (dynamic)

**Returns**

- `void`

<MemberHeading id="tostr" depth="3" name="toStr" sig="toStr(mat: dynamic): string" />

<MemberMeta badges="static" />

**Parameters**

- `mat` (dynamic)

**Returns**

- `string`
