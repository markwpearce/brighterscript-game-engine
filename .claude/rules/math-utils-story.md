---
paths:
  - "src/source/math/**"
  - "src/source/utils/**"
  - "src/source/story/**"
---

# Math, utils, story

- `math/`: use `BGE.Math.VectorOps`, `Matrix44`, `CornerPoints`, etc., not raw AAs. Headings (`heading.bs`: `headingForward`, `wrapAngle`, `turnToward`, `flatDistance`, …): heading 0 faces -z (camera/oriented-sprite convention).
- Melee: `BGE.Math.isWithinArc()` (matches `drawWorldArc`), `BGE.TokenPool` (attack tokens by id, with cooldown).
- `utils/`: OBJ/STL parsers (`Game.load3dModel`, textured `.obj` + materials), tweens, `MotionChecker`, `TagList`, registry helpers, auto-tiling (`tilemap/AutoTile.bs`, `docs/tile-maps.md`), `CountdownTimer` (dt-driven, unlike wall-clock `GameTimer`).
- `story/` (`docs/story.md`): `BGE.Story` is a UI-free dialogue/flags/inventory runner. `goto`/`call`/`end` are reserved (use brackets/quoted keys); ids can't contain `#` or `/`. If bsc misreads a `StoryData` literal against `Items()`, add `items: {}`.
