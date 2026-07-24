---
title: SpriteAnimation
kind: class
longname: BGE.SpriteAnimation
description: CReate a new SpriteAnimation
---

# SpriteAnimation

CReate a new SpriteAnimation

**Properties**

- `name` (string) — Name of the animation
- `frameRate` (integer) — Frames per second the animation should play at
- `frameList` (dynamic) — Array of the regions of the each cell of this animation
- `playMode` ([SpritePlayMode](/bge#spriteplaymode)) — Play mode for the sprite: loop, forward, reverse, pingpong

---

## Constructor

<Signature
  code="new SpriteAnimation(
	name: string,
	frameList: dynamic,
	frameRate: integer,
	playMode?: SpritePlayMode,
): SpriteAnimation"
/>

**Parameters**

- `name` (string) — Name of the animation
- `frameList` (dynamic) — Wither an array of cell indexes, or an object {startFrame, frameCount}
- `frameRate` (integer) — Frames per second the animation should play at
- `playMode` ([SpritePlayMode](/bge#spriteplaymode), optional, default: "SpritePlayMode.Loop") — Play mode for the sprite: loop, forward, reverse, pingpong
