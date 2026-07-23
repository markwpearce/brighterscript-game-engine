---
title: BGE/QuickHull
kind: namespace
longname: BGE/QuickHull
---

# BGE/QuickHull

**Alias:** `BGE.QuickHull`

---

## Static Methods

<MemberHeading
  id="gettrianglesfrompoints"
  depth="3"
  name="getTrianglesFromPoints"
  sig="getTrianglesFromPoints(
	pointsArray?: dynamic,
	hull?: boolean,
): dynamic"
/>

<MemberMeta badges="static" />

Gets a series of triangles for the convex space defined by an array of {x,y} points

**Parameters**

- `pointsArray` (dynamic, optional, default: "\[]") — array of {x,y} objects
- `hull` (boolean, optional, default: true) — perform a quick hull operation

**Returns**

- `dynamic` — array of triangles, each is array of 3 {x,y} points

<MemberHeading id="quickhull" depth="3" name="QuickHull" sig="QuickHull(pointsArray?: dynamic): dynamic" />

<MemberMeta badges="static" />

Implementation of the QuickHull algorithm for finding convex hull of a set of points Modified from: https\://github.com/claytongulick/quickhull Original author Clay Gulick

**Parameters**

- `pointsArray` (dynamic, optional, default: "\[]") — array of {x,y} objects

**Returns**

- `dynamic` — the minimal set of points for a convex hull

<MemberHeading
  id="getminmaxpoints"
  depth="3"
  name="getMinMaxPoints"
  sig="getMinMaxPoints(
	pointsArray?: Array.<BGE.Math.Vector>,
	vertical?: boolean,
): dynamic"
/>

<MemberMeta badges="static" />

Gets the min and max points in the set along the X axis modified from https:'github.com/claytongulick/quickhull

**Parameters**

- `pointsArray` (Array.\<BGE.Math.Vector>, optional, default: "\[]") — An array of {x,y} objects
- `vertical` (boolean, optional, default: false)

**Returns**

- `dynamic` — array \[ {x,y}, {x,y} ]

<MemberHeading
  id="getmaxwidthandhorizontaloffset"
  depth="3"
  name="getMaxWidthAndHorizontalOffset"
  sig="getMaxWidthAndHorizontalOffset(
	pointsArray?: Array.<BGE.Math.Vector>,
): dynamic"
/>

<MemberMeta badges="static" />

Gets the total width from first point to last point horizontally, and the offset of the first point

**Parameters**

- `pointsArray` (Array.\<BGE.Math.Vector>, optional, default: "\[]") — array of {x,y} objects

**Returns**

- `dynamic`

<MemberHeading id="getmaxheightandverticaloffset" depth="3" name="getMaxHeightAndVerticalOffset" sig="getMaxHeightAndVerticalOffset(pointsArray?: dynamic): dynamic" />

<MemberMeta badges="static" />

Gets the total height from first point to last point vertically, and the offset of the first point

**Parameters**

- `pointsArray` (dynamic, optional, default: "\[]") — array of {x,y} objects

**Returns**

- `dynamic` — object with {height as float, offset as float}

<MemberHeading
  id="distancefromline"
  depth="3"
  name="distanceFromLine"
  sig="distanceFromLine(
	point: BGE.Math.Vector,
	line: Array.<BGE.Math.Vector>,
): float"
/>

<MemberMeta badges="static" />

Calculates the distance of a point from a line modified from https:'github.com/claytongulick/quickhull return {float}

**Parameters**

- `point` (BGE.Math.Vector) — Array \[x,y]
- `line` (Array.\<BGE.Math.Vector>) — Array of two points \[ \[x1,y1], \[x2,y2] ]

**Returns**

- `float`

<MemberHeading id="distalpoints" depth="3" name="distalPoints" sig="distalPoints(line: dynamic, points: dynamic): dynamic" />

<MemberMeta badges="static" />

Determines the set of points that lay outside the line (positive), and the most distal point Returns: {points: \[ \[x1, y1], ... ], max: \[x,y] ]

**Parameters**

- `line` (dynamic)
- `points` (dynamic)

**Returns**

- `dynamic`

<MemberHeading id="addsegments" depth="3" name="addSegments" sig="addSegments(hull: dynamic, line: dynamic, points: dynamic): void" />

<MemberMeta badges="static" />

Recursively adds hull segments

**Parameters**

- `hull` (dynamic)
- `line` (dynamic)
- `points` (dynamic)

**Returns**

- `void`
