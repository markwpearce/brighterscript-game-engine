---
title: Collider
kind: class
longname: BGE.Collider
description: Colliders are attached to GameEntities and when two colliders intersect, it triggers the onCollision() method in the GameEntity
---

# Collider

Colliders are attached to GameEntities and when two colliders intersect, it triggers the onCollision() method in the GameEntity

**Properties**

- `colliderType` (string) — The type of this collider - should be defined in sub classes (eg. "circle", "rectangle")
- `name` (string) — Name this collider will be identified by
- `enabled` (boolean) — Does this collider trigger onCollision() ?
- `offset` (BGE.Math.Vector) — Offset from the GameEntity it is attached to
- `memberFlags` (integer) — Bitflag for collision detection: this collider is in this group - https\://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifsprite.md#setmemberflagsflags-as-integer-as-void
- `collidableFlags` (integer) — Bitflag for collision detection: this collider will only collider with colliders in this group - https\://developer.roku.com/en-ca/docs/references/brightscript/interfaces/ifsprite.md#setcollidableflagsflags-as-integer-as-void
- `compositorObject` (roSprite) — Used internal to Game - should not be modified manually
- `tagsList` (dynamic) — Colliders can be tagged with any number of tags so they can be easily identified (e.g. "enemy", "wall", etc.)

---

## Constructor

<Signature
  code="new Collider(
	colliderName: string,
	args?: roAssociativeArray,
): Collider"
/>

Creates a new Collider

**Parameters**

- `colliderName` (string) — the name this collider will be identified by
- `args` (roAssociativeArray, optional, default: "{}") — additional properties to be added to this collider

---

## Instance Methods

<MemberHeading
  id="setupcompositor"
  depth="3"
  name="setupCompositor"
  sig="setupCompositor(
	game,
	gameEngine: Game,
	entityName: string,
	entityId: string,
	entityPosition: BGE.Math.Vector,
): void"
/>

Sets up this collider to be associated with a given game and entity

**Parameters**

- `game` — the game this collider is used by
- `gameEngine` ([Game](/bge#game))
- `entityName` (string) — name of the entity that owns this collider
- `entityId` (string) — id of the entity that owns this collider
- `entityPosition` (BGE.Math.Vector) — entity's position

**Returns**

- `void`

<MemberHeading id="refreshcolliderregion" depth="3" name="refreshColliderRegion" sig="refreshColliderRegion(): void" />

Refreshes the collider. Called every frame by the GameEngine. Should be overridden by sub classes if they have specialized collision set ups (e.g. circle, rectangle).

**Returns**

- `void`

<MemberHeading id="adjustcompositorobject" depth="3" name="adjustCompositorObject" sig="adjustCompositorObject(entityPosition: BGE.Math.Vector): void" />

Moves the compositor to the new x,y position - called from Game when the entity it is attached to moves

**Parameters**

- `entityPosition` (BGE.Math.Vector)

**Returns**

- `void`

<MemberHeading
  id="debugdraw"
  depth="3"
  name="debugDraw"
  sig="debugDraw(
	renderObj: BGE.Renderer,
	position: BGE.Math.Vector,
	color?: integer,
	addName?: boolean,
	font?: roFont,
): void"
/>

Helper function to draw an outline around the collider

**Parameters**

- `renderObj` ([BGE.Renderer](/bge#renderer))
- `position` (BGE.Math.Vector)
- `color` (integer, optional, default: "\&hFF0000FF")
- `addName` (boolean, optional, default: false)
- `font` (roFont, optional, default: "invalid")

**Returns**

- `void`
