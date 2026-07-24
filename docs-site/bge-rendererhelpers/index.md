---
title: BGE/RendererHelpers
kind: namespace
longname: BGE/RendererHelpers
---

# BGE/RendererHelpers

**Alias:** `BGE.RendererHelpers`

---

## Static Methods

<MemberHeading
  id="createtrianglebitmap"
  depth="3"
  name="createTriangleBitmap"
  sig="createTriangleBitmap(
	bitmap: ifDraw2d,
	points: dynamic,
): TriangleBitmap"
/>

<MemberMeta badges="static" />

**Parameters**

- `bitmap` (ifDraw2d)
- `points` (dynamic)

**Returns**

- [`TriangleBitmap`](/bge-rendererhelpers#trianglebitmap)

<MemberHeading id="createregionwithid" depth="3" name="createRegionWithId" sig="createRegionWithId(region: roRegion, id?: string): RegionWithId" />

<MemberMeta badges="static" />

**Parameters**

- `region` (roRegion)
- `id` (string, optional, default: "\\"\\"")

**Returns**

- [`RegionWithId`](/bge-rendererhelpers#regionwithid)

## Other

<MemberHeading id="trianglebitmap" depth="3" name="TriangleBitmap" sig="TriangleBitmap" />

<MemberMeta badges="static" />

**Properties**

- `bitmap` (ifDraw2d)
- `triangle` (BGE.Math.Triangle)
- `scratchRegion` ([BGE.ScratchRegion](/bge#scratchregion))
- `scale` (BGE.Math.Vector)

<MemberHeading id="regionwithid" depth="3" name="RegionWithId" sig="RegionWithId" />

<MemberMeta badges="static" />

**Properties**

- `region` (roRegion)
- `id` (string)

<MemberHeading id="limitpointmappings" depth="3" name="LimitPointMappings" sig="LimitPointMappings" />

<MemberMeta badges="static" />

These are limits in screen space origin top /\
/\
/ >right left \< / \ / \ / bottom opposite

Baseline angle is the average angle from \[left-right, top-bottom]

**Parameters**

- `points` (dynamic)
- `screenSpace` (boolean, optional, default: true)

**Properties**

- `totalPointCount` (integer)
- `leftIndex` (integer)
- `rightIndex` (integer)
- `topIndex` (integer)
- `bottomIndex` (integer)
- `left` (BGE.Math.Vector)
- `right` (BGE.Math.Vector)
- `top` (BGE.Math.Vector)
- `bottom` (BGE.Math.Vector)
- `origin` (BGE.Math.Vector)
- `opposite` (BGE.Math.Vector)
- `baselineAngle` (float)
- `width` (float)
- `height` (float)

**Returns**

- `BGE.RendererHelpers.LimitPointMappings`

<MemberHeading id="limitpoints2d" depth="3" name="LimitPoints2d" sig="LimitPoints2d" />

<MemberMeta badges="static" />

**Properties**

- `left` (BGE.Math.Vector)
- `right` (BGE.Math.Vector)
- `top` (BGE.Math.Vector)
- `bottom` (BGE.Math.Vector)
