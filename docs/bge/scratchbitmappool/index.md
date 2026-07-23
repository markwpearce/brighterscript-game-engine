---
title: ScratchBitmapPool
kind: class
longname: BGE.ScratchBitmapPool
---

# ScratchBitmapPool

---

## Constructor

<Signature
  code="new ScratchBitmapPool(
	doPooling?: boolean,
	initialCount?: integer,
): ScratchBitmapPool"
/>

**Parameters**

- `doPooling` (boolean, optional, default: true)
- `initialCount` (integer, optional, default: 10)

---

## Instance Methods

<MemberHeading
  id="getregion"
  depth="3"
  name="getRegion"
  sig="getRegion(
	askedForWidth: float,
	askedForHeight: float,
	onTopRight?: boolean,
): BGE.ScratchRegion"
/>

**Parameters**

- `askedForWidth` (float)
- `askedForHeight` (float)
- `onTopRight` (boolean, optional, default: false)

**Returns**

- [`BGE.ScratchRegion`](/bge#scratchregion)

<MemberHeading id="returnregion" depth="3" name="returnRegion" sig="returnRegion(usedRegion: ScratchRegion): void" />

**Parameters**

- `usedRegion` ([ScratchRegion](/bge#scratchregion))

**Returns**

- `void`

<MemberHeading id="returnregions" depth="3" name="returnRegions" sig="returnRegions(usedRegions: dynamic): void" />

**Parameters**

- `usedRegions` (dynamic)

**Returns**

- `void`

<MemberHeading id="stageregionsforreturn" depth="3" name="stageRegionsForReturn" sig="stageRegionsForReturn(usedRegions: dynamic): void" />

**Parameters**

- `usedRegions` (dynamic)

**Returns**

- `void`

<MemberHeading id="returnstagedregions" depth="3" name="returnStagedRegions" sig="returnStagedRegions(): void" />

**Returns**

- `void`

<MemberHeading id="clearpool" depth="3" name="clearPool" sig="clearPool(): void" />

**Returns**

- `void`

<MemberHeading id="tostr" depth="3" name="toStr" sig="toStr(): string" />

**Returns**

- `string`
