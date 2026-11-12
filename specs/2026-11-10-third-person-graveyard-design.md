# thirdPerson: the graveyard scene

## Intent

The second of the map's scenes (see `2026-11-05-third-person-crypt-design.md`): a fenced
churchyard at night, above the crypt. You arrive through a gap in the fence, pass a gravedigger's
hut, a chapel and rows of graves, and go down into the crypt through the mausoleum's door at the
far end. A few skeletons stand among the graves and wake as you come near.

## Goals

- `GraveyardScene` in `examples/thirdPerson`, started with the deep link `scene=graveyard`.
- Laid out by a text grid (`GraveyardMap`, like `CryptMap`): editing the layout is editing text.
- The props Mark supplied: the mausoleum (`crypt.obj`), the hut, the well, the fence and the three
  gravestones (procedural, `tools/make-props.py`), plus the chapel from `examples/terrain`, and
  the tree sprites (`trees/_04`) with their baked shadows stripped.
- Three skeletons that stand still until the knight is within 10 m (or hits one), then fight as
  they do in the field. Killed ones stay dead until the knight dies; then everything resets.
- The way round: graveyard gate → field, mausoleum door → crypt, crypt exit → graveyard (outside
  the mausoleum door).

## Non-goals

- Town, forest, NPCs. (The NPC sheets are high-angle Flare renders with baked shadows; they need
  re-rendering from their `.blend` files at 12 degrees on a machine with Blender.)
- A way from the field to the graveyard; the field stays the test arena.
- Engine changes.

## Decided

**Grid.** 2 m cells, 24 x 24 (48 m) with the fence on the second ring and trees outside it, so the
yard inside is 40 x 40 m. Kinds:

| Char | Meaning |
| --- | --- |
| `.` | grass |
| `,` | outside the fence (solid, nothing drawn) |
| `f` | fence: runs of `f` along a row or column become one `DrawableWall` each |
| `E` | gap in the fence: walking into it goes to the field |
| `g` | a grave: slab, cross or broken, picked and jittered by a seeded random |
| `T` | a tree (one of five, jittered, 7-9 m tall); solid trunk |
| `p`, `c`, `h` | the chapel, mausoleum and hut: each group of cells is one model, centred on the group, with a solid footprint the size of the model |
| `W` | the well |
| `D` | in front of the mausoleum door: walking into it goes down to the crypt |
| `s` | a cold spirit flame hovering over the graves |
| `S` | a skeleton |
| `@` | where you arrive from the field (and respawn) |

**Rendering.** The chapel, mausoleum, hut and well are textured `DrawableModel`s (impostors, so
they cost little while only the camera moves), loaded from `.obj` in `onLoad()`, scaled by
`World.UNITS_PER_METRE`, with a `BoxCollider3d` on `World.CAMERA_BLOCKER`. Fences are
`DrawableWall`s on static entities, tiled every 3 m with the fence tile cut from the props atlas,
double-sided and not occluders (you can see through them). Graves and trees are shaded
`axisAligned` cut-outs, like `CryptProp`. Ground, sky and moon are the field's (`grass`,
`nightSky`, `Night.addLights`), 40 m draw distance, far half fading.

**Light.** Moon and sky fill, a warm torch on the hut's front, and two or three spirit flames. No
more: each point light relights what it reaches.

**Solid ground.** `CryptWalls` becomes a general `SolidTracker` (takes a `BGE.SolidWorld`), used by
both scenes; `CryptMap` and `GraveyardMap` each build their own `SolidWorld`. The tracker also
tracks the skeletons, and is cleared and refilled when the knight respawns.

**Skeletons.** `Enemy` gains an optional `wakeDistance`: until the player comes that close or it's
hit, it stands idle (`EnemyState.dormant`) and asks for no attack slot.

**Scene changes.** `changeSceneWithFade(name, {from: ...})`: the graveyard reads `from: "crypt"` to
start just south of the mausoleum door facing away from it; the crypt reads `from: "graveyard"` to
start next to its exit, facing into the maze. The crypt's exit now leads to the graveyard.

**Trees.** `tools/trees.js` (Node, `sharp` via `scripts/webp.js`): `node tools/trees.js <dir of
Sprite_0N.png>` clears near-black, half-transparent pixels (the shadow), trims, scales to 320 px
tall and writes `src/sprites/tree_<n>.webp`. The originals aren't committed.

**Props.** `tools/make-props.py` is Mark's generator (needs Pillow + numpy), writing into
`src/models/props/`; its output is committed, so building doesn't need Python.

**Done** when `scene=graveyard` runs on the Ultra (.102) at the 20 fps target with adaptive quality
in its busiest view, and you can walk graveyard → crypt → graveyard → field.

## Left to the builder

- The exact layout, scales, grave and tree jitter.
- Whether models are static occluders; measure.
