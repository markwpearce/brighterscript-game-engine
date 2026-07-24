---
title: BGE/Math/BGE/Math/TriangleOps
kind: namespace
longname: BGE/Math/BGE/Math/TriangleOps
---

# BGE/Math/BGE/Math/TriangleOps

**Alias:** `BGE.Math.BGE.Math.TriangleOps`

---

## Static Methods

<MemberHeading
  id="create"
  depth="3"
  name="create"
  sig="create(
	points: Array.<BGE.Math.Vector>,
	rearrangeToLongestFirst?: boolean,
): BGE.Math.Triangle"
/>

<MemberMeta badges="static" />

Creates a BGE.Math.Triangle object from 3 points

**Parameters**

- `points` (Array.\<BGE.Math.Vector>) — Array of points in counter clockwise winding (i.e. follows right-hand-rule)
- `rearrangeToLongestFirst` (boolean, optional, default: false) — if true, the points in the triangle will be rearranged so that the longest side is between points\[0] and points\[1]

**Returns**

- `BGE.Math.Triangle`

<MemberHeading
  id="setpoints"
  depth="3"
  name="setPoints"
  sig="setPoints(
	tri: BGE.Math.Triangle,
	points: Array.<BGE.Math.Vector>,
	rearrangeToLongestFirst?: boolean,
): void"
/>

<MemberMeta badges="static" />

Sets the points of a BGE.Math.Triangle and calculates all related properties (lengths, angles, longest side, height, etc). The points should be in counter clockwise winding (i.e. follow right-hand-rule)

**Parameters**

- `tri` (BGE.Math.Triangle)
- `points` (Array.\<BGE.Math.Vector>)
- `rearrangeToLongestFirst` (boolean, optional, default: false)

**Returns**

- `void`

<MemberHeading id="getlongestside" depth="3" name="getLongestSide" sig="getLongestSide(tri: BGE.Math.Triangle): float" />

<MemberMeta badges="static" />

Gets the length of the longest side of a triangle

**Parameters**

- `tri` (BGE.Math.Triangle)

**Returns**

- `float`

<MemberHeading id="isobtuse" depth="3" name="isObtuse" sig="isObtuse(tri: BGE.Math.Triangle): boolean" />

<MemberMeta badges="static" />

True if there is any angle greater than 90degrees

**Parameters**

- `tri` (BGE.Math.Triangle)

**Returns**

- `boolean`

<MemberHeading id="isacute" depth="3" name="isAcute" sig="isAcute(tri: BGE.Math.Triangle): boolean" />

<MemberMeta badges="static" />

True if all angles are less than 90degrees

**Parameters**

- `tri` (BGE.Math.Triangle)

**Returns**

- `boolean`

<MemberHeading id="getoriginindex" depth="3" name="getOriginIndex" sig="getOriginIndex(tri: BGE.Math.Triangle): integer" />

<MemberMeta badges="static" />

Gets the index of the origin point (0,0) in the triangle

**Parameters**

- `tri` (BGE.Math.Triangle)

**Returns**

- `integer` — will return -1 if no point is at the origin

<MemberHeading
  id="getheightbytangentindex"
  depth="3"
  name="getHeightByTangentIndex"
  sig="getHeightByTangentIndex(
	tri: BGE.Math.Triangle,
	tangentIndex: integer,
): float"
/>

<MemberMeta badges="static" />

Gets the height of the triangle based on the length of the side at tangentIndex and the angle at tangentIndex

**Parameters**

- `tri` (BGE.Math.Triangle)
- `tangentIndex` (integer)

**Returns**

- `float`

<MemberHeading id="nextindex" depth="3" name="nextIndex" sig="nextIndex(currentIndex: integer): integer" />

<MemberMeta badges="static" />

Gets the next index in the triangle (0,1,2) given a current index

**Parameters**

- `currentIndex` (integer)

**Returns**

- `integer`

<MemberHeading id="previousindex" depth="3" name="previousIndex" sig="previousIndex(currentIndex: integer): integer" />

<MemberMeta badges="static" />

Gets The previous index in the triangle (0,1,2) given a current index

**Parameters**

- `currentIndex` (integer)

**Returns**

- `integer`

<MemberHeading
  id="getmidpointofside"
  depth="3"
  name="getMidpointOfSide"
  sig="getMidpointOfSide(
	tri: BGE.Math.Triangle,
	sideIndex: integer,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

Gets the midpoint of the side starting at th the given index

**Parameters**

- `tri` (BGE.Math.Triangle)
- `sideIndex` (integer)

**Returns**

- `BGE.Math.Vector`

<MemberHeading id="getperpendicularfootofheight" depth="3" name="getPerpendicularFootOfHeight" sig="getPerpendicularFootOfHeight(tri: BGE.Math.Triangle): dynamic" />

<MemberMeta badges="static" />

Gets information related to the the perpendicular foot of the triangle. That is, the point on the largest side that cuts the triangle into 2 right triangles

**Parameters**

- `tri` (BGE.Math.Triangle)

**Returns**

- `dynamic`

<MemberHeading id="tostr" depth="3" name="toStr" sig="toStr(tri: BGE.Math.Triangle): string" />

<MemberMeta badges="static" />

**Parameters**

- `tri` (BGE.Math.Triangle)

**Returns**

- `string`

<MemberHeading
  id="getthirdrighttrianglepoint"
  depth="3"
  name="getThirdRightTrianglePoint"
  sig="getThirdRightTrianglePoint(
	aPoint: BGE.Math.Vector,
	bPoint: BGE.Math.Vector,
	aAngle: float,
): BGE.Math.Vector"
/>

<MemberMeta badges="static" />

Gets third point in triangle

?-----B | / | | / | |a/c | A ----| \<--- this point is grid aligned, point "?" could be anywhere

**Parameters**

- `aPoint` (BGE.Math.Vector)
- `bPoint` (BGE.Math.Vector)
- `aAngle` (float)

**Returns**

- `BGE.Math.Vector`
