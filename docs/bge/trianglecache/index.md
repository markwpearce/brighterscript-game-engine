---
title: TriangleCache
kind: class
longname: BGE.TriangleCache
---

# TriangleCache

---

## Constructor

<Signature code="new TriangleCache(cacheKeepSeconds?: integer): TriangleCache" />

**Parameters**

- `cacheKeepSeconds` (integer, optional, default: 60)

---

## Instance Methods

<MemberHeading
  id="gettriangle"
  depth="3"
  name="getTriangle"
  sig="getTriangle(
	id: string,
	points: dynamic,
): BGE.RendererHelpers.TriangleBitmap"
/>

**Parameters**

- `id` (string)
- `points` (dynamic)

**Returns**

- `BGE.RendererHelpers.TriangleBitmap`

<MemberHeading
  id="addtriangle"
  depth="3"
  name="addTriangle"
  sig="addTriangle(
	id: string,
	points: dynamic,
	triangleBmp: BGE.RendererHelpers.TriangleBitmap,
): void"
/>

**Parameters**

- `id` (string)
- `points` (dynamic)
- `triangleBmp` (BGE.RendererHelpers.TriangleBitmap)

**Returns**

- `void`

<MemberHeading id="cleancache" depth="3" name="cleanCache" sig="cleanCache(): void" />

**Returns**

- `void`
