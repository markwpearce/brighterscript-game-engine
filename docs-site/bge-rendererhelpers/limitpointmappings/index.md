---
title: LimitPointMappings
kind: class
longname: BGE/RendererHelpers.LimitPointMappings
description: These are limits in screen space origin top / / / &gt;right left &lt; / \ / \ / bottom opposite Baseline angle is the average angle from [left-right, top-bottom]
---

# LimitPointMappings

These are limits in screen space origin top /\
/\
/ >right left \< / \ / \ / bottom opposite

Baseline angle is the average angle from \[left-right, top-bottom]

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

---

## Constructor

<Signature
  code="new LimitPointMappings(
	points: dynamic,
	screenSpace?: boolean,
): LimitPointMappings"
/>

**Parameters**

- `points` (dynamic)
- `screenSpace` (boolean, optional, default: true)

---

## Instance Methods

<MemberHeading id="getanglebaselinedifference" depth="3" name="getAngleBaseLineDifference" sig="getAngleBaseLineDifference(other: LimitPoints2d): float" />

**Parameters**

- `other` ([LimitPoints2d](/bge-rendererhelpers#limitpoints2d))

**Returns**

- `float`
