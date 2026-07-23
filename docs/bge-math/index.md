---
title: BGE/Math
kind: namespace
longname: BGE/Math
---

# BGE/Math

**Alias:** `BGE.Math`

---

## Static Methods

<MemberHeading
  id="createcornerpoints"
  depth="3"
  name="createCornerPoints"
  sig="createCornerPoints(
	topLeft: Vector,
	topRight: Vector,
	bottomLeft: Vector,
	bottomRight: Vector,
): CornerPoints"
/>

<MemberMeta badges="static" />

**Parameters**

- `topLeft` ([Vector](/bge-math#vector))
- `topRight` ([Vector](/bge-math#vector))
- `bottomLeft` ([Vector](/bge-math#vector))
- `bottomRight` ([Vector](/bge-math#vector))

**Returns**

- [`CornerPoints`](/bge-math#cornerpoints)

<MemberHeading id="isfloatarray44" depth="3" name="isFloatArray44" sig="isFloatArray44(x: dynamic): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `x` (dynamic)

**Returns**

- `boolean`

<MemberHeading id="getfloat44identity" depth="3" name="getFloat44Identity" sig="getFloat44Identity(): dynamic" />

<MemberMeta badges="static" />

**Returns**

- `dynamic`

<MemberHeading id="fillfloat44" depth="3" name="fillFloat44" sig="fillFloat44(dest: dynamic, src: dynamic): void" />

<MemberMeta badges="static" />

**Parameters**

- `dest` (dynamic)
- `src` (dynamic)

**Returns**

- `void`

<MemberHeading id="lookat" depth="3" name="lookAt" sig="lookAt(from: Vector, lookTo: Vector): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `from` ([Vector](/bge-math#vector))
- `lookTo` ([Vector](/bge-math#vector))

**Returns**

- `dynamic`

<MemberHeading
  id="orthographicmatrix"
  depth="3"
  name="orthographicMatrix"
  sig="orthographicMatrix(
	top: float,
	bottom: float,
	left: float,
	right: float,
	far: float,
	near: float,
): dynamic"
/>

<MemberMeta badges="static" />

**Parameters**

- `top` (float)
- `bottom` (float)
- `left` (float)
- `right` (float)
- `far` (float)
- `near` (float)

**Returns**

- `dynamic`

<MemberHeading id="getscalematrix" depth="3" name="getScaleMatrix" sig="getScaleMatrix(scale: Vector): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `scale` ([Vector](/bge-math#vector))

**Returns**

- `dynamic`

<MemberHeading id="getrotationmatrix" depth="3" name="getRotationMatrix" sig="getRotationMatrix(rotation: Vector): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `rotation` ([Vector](/bge-math#vector))

**Returns**

- `dynamic`

<MemberHeading id="gettranslationmatrix" depth="3" name="getTranslationMatrix" sig="getTranslationMatrix(position: Vector): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `position` ([Vector](/bge-math#vector))

**Returns**

- `dynamic`

<MemberHeading
  id="gettransformationmatrix"
  depth="3"
  name="getTransformationMatrix"
  sig="getTransformationMatrix(
	position: Vector,
	rotation: Vector,
	scale: Vector,
): dynamic"
/>

<MemberMeta badges="static" />

**Parameters**

- `position` ([Vector](/bge-math#vector))
- `rotation` ([Vector](/bge-math#vector))
- `scale` ([Vector](/bge-math#vector))

**Returns**

- `dynamic`

<MemberHeading id="createtransform" depth="3" name="createTransform" sig="createTransform(): Transform" />

<MemberMeta badges="static" />

**Returns**

- [`Transform`](/bge-math#transform)

<MemberHeading id="min" depth="3" name="Min" sig="Min(a: float, b: float): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `a` (float)
- `b` (float)

**Returns**

- `dynamic`

<MemberHeading id="max" depth="3" name="Max" sig="Max(a: float, b: float): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `a` (float)
- `b` (float)

**Returns**

- `dynamic`

<MemberHeading id="clamp" depth="3" name="Clamp" sig="Clamp(number: float, minVal: float, maxVal: float): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `number` (float)
- `minVal` (float)
- `maxVal` (float)

**Returns**

- `dynamic`

<MemberHeading id="atan2" depth="3" name="Atan2" sig="Atan2(y: float, x: float): float" />

<MemberMeta badges="static" />

**Parameters**

- `y` (float)
- `x` (float)

**Returns**

- `float`

<MemberHeading id="isintegereven" depth="3" name="IsIntegerEven" sig="IsIntegerEven(number: integer): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `number` (integer)

**Returns**

- `boolean`

<MemberHeading id="isintegerodd" depth="3" name="IsIntegerOdd" sig="IsIntegerOdd(number: integer): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `number` (integer)

**Returns**

- `boolean`

<MemberHeading id="power" depth="3" name="Power" sig="Power(number: float, pow: integer): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `number` (float)
- `pow` (integer)

**Returns**

- `dynamic`

<MemberHeading id="round" depth="3" name="Round" sig="Round(number: float, decimals?: integer): float" />

<MemberMeta badges="static" />

**Parameters**

- `number` (float)
- `decimals` (integer, optional, default: 0)

**Returns**

- `float`

<MemberHeading id="degreestoradians" depth="3" name="DegreesToRadians" sig="DegreesToRadians(degrees: float): float" />

<MemberMeta badges="static" />

**Parameters**

- `degrees` (float)

**Returns**

- `float`

<MemberHeading id="radianstodegrees" depth="3" name="RadiansToDegrees" sig="RadiansToDegrees(radians: float): float" />

<MemberMeta badges="static" />

**Parameters**

- `radians` (float)

**Returns**

- `float`

<MemberHeading id="randominrange" depth="3" name="RandomInRange" sig="RandomInRange(lowestInt: integer, highestInt: integer): integer" />

<MemberMeta badges="static" />

**Parameters**

- `lowestInt` (integer)
- `highestInt` (integer)

**Returns**

- `integer`

<MemberHeading id="constrainangle" depth="3" name="constrainAngle" sig="constrainAngle(angleRad: float): float" />

<MemberMeta badges="static" />

**Parameters**

- `angleRad` (float)

**Returns**

- `float`

<MemberHeading
  id="rotatevectoraroundvector2d"
  depth="3"
  name="RotateVectorAroundVector2d"
  sig="RotateVectorAroundVector2d(
	vector1: Vector,
	vector2: Vector,
	radians: float,
): Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `vector1` ([Vector](/bge-math#vector))
- `vector2` ([Vector](/bge-math#vector))
- `radians` (float)

**Returns**

- [`Vector`](/bge-math#vector)

<MemberHeading id="totaldistance" depth="3" name="TotalDistance" sig="TotalDistance(vector1: Vector, vector2: Vector): float" />

<MemberMeta badges="static" />

**Parameters**

- `vector1` ([Vector](/bge-math#vector))
- `vector2` ([Vector](/bge-math#vector))

**Returns**

- `float`

<MemberHeading id="getangle" depth="3" name="GetAngle" sig="GetAngle(point1: Vector, point2: Vector): float" />

<MemberMeta badges="static" />

**Parameters**

- `point1` ([Vector](/bge-math#vector))
- `point2` ([Vector](/bge-math#vector))

**Returns**

- `float`

<MemberHeading
  id="getanglebetweenvectors"
  depth="3"
  name="GetAngleBetweenVectors"
  sig="GetAngleBetweenVectors(
	center: vector,
	point1: Vector,
	point2: Vector,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `center` (vector)
- `point1` ([Vector](/bge-math#vector))
- `point2` ([Vector](/bge-math#vector))

**Returns**

- `float`

<MemberHeading id="average" depth="3" name="average" sig="average(num1: float, num2: float): float" />

<MemberMeta badges="static" />

**Parameters**

- `num1` (float)
- `num2` (float)

**Returns**

- `float`

<MemberHeading id="arraysum" depth="3" name="arraySum" sig="arraySum(nums: dynamic): float" />

<MemberMeta badges="static" />

**Parameters**

- `nums` (dynamic)

**Returns**

- `float`

<MemberHeading id="arrayaverage" depth="3" name="arrayAverage" sig="arrayAverage(nums: dynamic): float" />

<MemberMeta badges="static" />

**Parameters**

- `nums` (dynamic)

**Returns**

- `float`

<MemberHeading id="arraymin" depth="3" name="arrayMin" sig="arrayMin(nums: dynamic): float" />

<MemberMeta badges="static" />

**Parameters**

- `nums` (dynamic)

**Returns**

- `float`

<MemberHeading id="arraymax" depth="3" name="arrayMax" sig="arrayMax(nums: dynamic): float" />

<MemberMeta badges="static" />

**Parameters**

- `nums` (dynamic)

**Returns**

- `float`

<MemberHeading id="vectorzero" depth="3" name="VectorZero" sig="VectorZero(): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="vectorfromfloatarray" depth="3" name="VectorFromFloatArray" sig="VectorFromFloatArray(array: dynamic): BGE.Math.Vector" />

<MemberMeta badges="static" />

**Parameters**

- `array` (dynamic)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="createscalevector"
  depth="3"
  name="createScaleVector"
  sig="createScaleVector(
	scale_x: float,
	scale_y?: dynamic,
	scale_z?: dynamic,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `scale_x` (float) — horizontal scale
- `scale_y` (dynamic, optional, default: "invalid") — vertical scale, or if invalid, use the horizontal scale as vertical scale
- `scale_z` (dynamic, optional, default: "invalid")

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="distancefromplane"
  depth="3"
  name="distanceFromPlane"
  sig="distanceFromPlane(
	planePoint: BGE.Math.Vector,
	planeNormal: BGE.Math.Vector,
	targetPoint: BGE.Math.Vector,
): float"
/>

<MemberMeta badges="static" />

**Parameters**

- `planePoint` (BGE.Math.Vector)
- `planeNormal` (BGE.Math.Vector)
- `targetPoint` (BGE.Math.Vector)

**Returns**

- `float`

<MemberHeading
  id="midpointbetweenpoints"
  depth="3"
  name="midPointBetweenPoints"
  sig="midPointBetweenPoints(
	a: BGE.Math.Vector,
	b: BGE.Math.Vector,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `a` (BGE.Math.Vector)
- `b` (BGE.Math.Vector)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getbounds" depth="3" name="getBounds" sig="getBounds(points: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `points` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="getboundingcubepoints" depth="3" name="getBoundingCubePoints" sig="getBoundingCubePoints(points: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `points` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="vectorarraysequal" depth="3" name="vectorArraysEqual" sig="vectorArraysEqual(a?: dynamic, b?: dynamic): boolean" />

<MemberMeta badges="static" />

**Parameters**

- `a` (dynamic, optional, default: "\[]")
- `b` (dynamic, optional, default: "\[]")

**Returns**

- `boolean`

<MemberHeading id="vectorarraycopy" depth="3" name="vectorArrayCopy" sig="vectorArrayCopy(a?: dynamic): dynamic" />

<MemberMeta badges="static" />

**Parameters**

- `a` (dynamic, optional, default: "\[]")

**Returns**

- `dynamic`

<MemberHeading
  id="intersectpointpoint"
  depth="3"
  name="intersectPointPoint"
  sig="intersectPointPoint(
	p1: Vector,
	p2: Vector,
	p3: Vector,
	p4: Vector,
	mustBeInSegment?: boolean,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

From https\://paulbourke.net/geometry/pointlineplane/javascript.txt

**Parameters**

- `p1` ([Vector](/bge-math#vector))
- `p2` ([Vector](/bge-math#vector))
- `p3` ([Vector](/bge-math#vector))
- `p4` ([Vector](/bge-math#vector))
- `mustBeInSegment` (boolean, optional, default: false)

**Returns**

- `BGE.Math.Vector`

<MemberHeading
  id="intersectpointangle"
  depth="3"
  name="intersectPointAngle"
  sig="intersectPointAngle(
	p1: BGE.Math.Vector,
	angle1FromXAxis: float,
	p2: BGE.Math.Vector,
	angle2FromXAxis: float,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

**Parameters**

- `p1` (BGE.Math.Vector)
- `angle1FromXAxis` (float)
- `p2` (BGE.Math.Vector)
- `angle2FromXAxis` (float)

**Returns**

- `BGE.Math.Vector`

## Enums

<MemberHeading id="bgemathwindingdirection" depth="3" name="BGE.Math.WindingDirection" sig="BGE.Math.WindingDirection" />

<MemberMeta badges="static,readonly,enum" />

**Properties**

- `clockwise` (default: 0)
- `counterclockwise` (default: 1)

## Other

<MemberHeading id="cornerpoints" depth="3" name="CornerPoints" sig="CornerPoints" />

<MemberMeta badges="static" />

**Properties**

- `topLeft` (dynamic)
- `topRight` (dynamic)
- `bottomLeft` (dynamic)
- `bottomRight` (dynamic)

<MemberHeading id="transform" depth="3" name="Transform" sig="Transform" />

<MemberMeta badges="static" />

**Properties**

- `position` (BGE.Math.Vector)
- `rotation` (BGE.Math.vector)
- `scale` (BGE.Math.Vector)

<MemberHeading id="triangle" depth="3" name="Triangle" sig="Triangle" />

<MemberMeta badges="static" />

**Properties**

- `lengths` (dynamic)
- `angles` (dynamic)
- `anglesToNext` (dynamic)
- `anglesToPrevious` (dynamic)
- `points` (dynamic)
- `longestIndex` (integer)
- `height` (float)
- `winding` ([WindingDirection](/bge-math#bgemathwindingdirection))
- `angleRotatedFromOriginal` (float)

<MemberHeading id="circle" depth="3" name="Circle" sig="Circle" />

<MemberMeta badges="static" />

**Parameters**

- `x` (float, optional, default: 0)
- `y` (float, optional, default: 0)
- `radius` (float, optional, default: 0)

**Properties**

- `x` (float)
- `y` (float)
- `radius` (float)

**Returns**

- `BGE.Math.Circle`

<MemberHeading id="pi" depth="3" name="PI" sig="PI" />

<MemberMeta badges="static,readonly" />

**Default:** `3.14159265358`

<MemberHeading id="halfpi" depth="3" name="HALF_PI" sig="HALF_PI" />

<MemberMeta badges="static,readonly" />

**Default:** `1.57079632679`

<MemberHeading id="rectangle" depth="3" name="Rectangle" sig="Rectangle" />

<MemberMeta badges="static" />

**Parameters**

- `x` (float, optional, default: 0)
- `y` (float, optional, default: 0)
- `width` (float, optional, default: 0)
- `height` (float, optional, default: 0)

**Properties**

- `x` (float)
- `y` (float)
- `width` (float)
- `height` (float)

**Returns**

- `BGE.Math.Rectangle`

<MemberHeading id="vector" depth="3" name="Vector" sig="Vector" />

<MemberMeta badges="static" />

**Properties**

- `x` (float)
- `y` (float)
- `z` (float)
