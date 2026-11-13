# thirdPerson: the town

Part of [#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385). It covers the README's "Still needed" items for the town map, a ground texture, and re-rendering the townsfolk.

## Intent

The game gets a starting place. The knight begins in a walled town at night, walks out through its gate to the graveyard, and goes down from there into the crypt. The town is a calm, lived-in hub: no enemies, a few people standing about, pigs in a pen. It should feel like a real place the player can walk around, and it should hold the frame rate the other scenes hold.

## Goals

- A new `TownScene` that becomes the default start scene. The order is **Town ↔ Graveyard ↔ Crypt**.
- A walled town: wall segments and towers all round, with a gate. Inside are timber houses, thatched huts, a central square with the well, fenced fields, a pig pen and a keep.
- **A painted ground layer**: one ground image showing cobbled streets and the square, dirt paths, grass and fields (crop rows or ploughed earth). It's generated from the same layout as the buildings, so streets always meet doors and gates.
- **Townsfolk** standing in idle poses, facing different ways: peasants (male and female), a nobleman, the old man and a priest, rendered from the Flare NPC `.blend` files in the knight's style (16 directions, 12° camera, same scale).
- **Pigs** in the pen. They wander slowly if `Pig.blend` has a walk cycle; otherwise they only idle.
- Night, lit the same way as the graveyard (`Night.addLights`), with fire torches at the gate and round the square. The houses' windows are already painted lit in the atlas.
- Walls, buildings, fences, the well, the keep and the NPCs are solid. The knight can't walk through them.

## Non-goals (for now)

- Talking to NPCs, or any interaction with them. They don't react to the knight.
- Enemies or combat in town. The knight can still swing, block and roll, but nothing is there to fight.
- Going inside any building.
- Day/night cycles, weather, or people walking routes.

## Anti-goals

- **Frame rate drops below the graveyard's.** Per the "conservative perf caps" preference, cut density, draw distance or NPC count before accepting a slower town.
- **Running out of texture memory.** The four combat sheets already take about 27 MB, against 64 MB on HD devices. The town loads the knight and the NPC sheets, not the monster sheets.
- **UI or text outside the title-safe area.**
- **A ground map that doesn't line up with the buildings.**

## Scene flow changes

- `main.bs`: the start scene becomes `TownScene`. The deep links `scene=field` (the combat arena, kept for testing), `scene=graveyard` and `scene=crypt` still work, and `scene=town` is added. `at=<col>,<row>[,<heading>]` works in town as it does in the graveyard.
- `GraveyardScene`: the `E` gap in the fence now leads to `TownScene` (`{from: "graveyard"}`), not the field. Coming back from town (`{from: "town"}`) puts the knight just inside that gap, facing into the graveyard.
- `TownScene`: walking into the gate's passage leads to the graveyard. Arriving from the graveyard puts the knight just inside the gate, facing into town. A fresh start (no `from`) puts him in the square.
- Nothing leads to `FieldScene` any more. The README's scene table gets updated.

## Layout: a text grid in a file both sides read

Like the graveyard, the town is a text grid of 2 m cells. Unlike the graveyard, the grid lives in a **data file**, `src/maps/town.txt`, because two programs need it:

- `TownScene` reads it at runtime (`ReadAsciiFile`) and parses it, like `GraveyardMap.parse`.
- A new tool, `tools/town-ground.py`, reads the same file and paints the ground image from it.

The key goes in a comment block at the top of the file, and the tool and the parser skip comment lines. The kinds needed, roughly (the builder settles the exact characters):

| Kind | Meaning |
| --- | --- |
| `,` | outside the walls (grass, nothing placed) |
| `.` | grass |
| `=` | cobbles (streets and the square) |
| `-` | dirt path |
| `~` | field (crop rows), `:` ploughed field |
| `w` | town wall (runs become `wall_segment`s; corners and marked points become `wall_tower`s) |
| `G` | the gate (one `wall_gate`; its passage is the way out to the graveyard) |
| `t` | a wall tower |
| `H` | a house; `u` a hut; `K` the keep. Each connected group of cells is one building |
| `f` | fence (as in the graveyard), around fields and the pen |
| `W` | the well |
| `P` | a pig's starting spot (inside the pen) |
| `n` | an NPC's spot (which NPC and which way it faces is decided per spot; see below) |
| `l` | a standing torch (post and flame) |
| `@` | the start spot in the square |

**Many buildings of one kind.** `GraveyardMap` assumes each building kind appears once. The town has many houses and huts, so its parser finds **connected groups** of cells (flood fill) rather than one rectangle per kind. Each group's bounding rectangle has to match the model's footprint in whole cells, or the parser should warn. A house's footprint is 6×8 m (3×4 cells), a hut's 4×5 m (2×3 cells, rounded up), the keep's is whatever the new model is. A building's facing (which way its door points) comes from the grid: the door faces the nearest cobble or path cell next to its footprint. The builder decides how that's marked or inferred.

**Walls are on the 2 m grid but the models aren't.** `wall_segment` and `wall_gate` are 8 m (4 cells) long and `wall_tower` is 4 m (2 cells), so wall runs should be multiples of 4 cells between towers. The parser places segments along a run and warns if one doesn't divide evenly.

**Size.** A starting suggestion is about 36×32 cells (72×64 m) inside the walls: big enough for a square, a street or two, eight to ten houses and huts, two fields, a pen and the keep. Too big starts to hurt frame rate and ground texture memory (below), so the builder should go smaller if it measures badly.

## The painted ground

`tools/town-ground.py` (Pillow and numpy, like `make-props.py`) reads `town.txt` and writes `src/sprites/town_ground.webp`. Each cell is painted by its kind: cobbles, packed dirt, grass, crop rows or furrows. Edges between kinds are blended or ragged so it doesn't look like a chessboard, and grass shows under buildings and outside the walls. The painting is procedural, so no third-party credit is needed.

**How it's drawn:** a `DrawablePlane` with `fillMode: staticImage`, centred on the town, scaled so one cell is the right number of texels.

**Resolution and memory.** With the 36×32-cell suggestion, the town is about 2300×2050 world units. At the field's 2 units per texel, that would need about a 1150×1024 image (about 4.7 MB as a bitmap). At 4 units per texel it would need about 576×512 (about 1.2 MB). Coarser texels also let the plane draw farther, since draw distance scales with texel size. The builder picks the scale on the device: start at 4 and only go finer if it looks too blurry up close and the memory and frame rate allow.

**Outside the walls.** The static image ends at its edges. Either the image covers a margin of grass outside the walls, far enough that the 32-40 m draw distance and the fade never show its edge from inside, or a plain `tiledImage` grass plane is added underneath. Two layered planes would roughly double the ground's draw cost, so try the margin first.

**Open question for Mark: torch light on the ground.** At the moment the ground plane only draws the pools of torchlight when it's a repeating tile (`tiledImage`). `SceneObjectPlane.usesLightPools()` checks for that. A painted `staticImage` ground would still get the moonlight's tint, but **no pools of torchlight on the cobbles**. The options are covered at the end.

## New art

### The keep

Add a `keep` model to `make-props.py` in the same style: low-poly, a few dozen triangles, using the shared 256 px atlas. It's a square stone tower, taller and wider than `wall_tower`, with a door and battlements, about 10×14×10 m. It can reuse the stone and tower tiles; if it needs a new tile (a big door, say), take a free slot in the atlas grid. It goes in `src/models/props/` like the rest. The `thirdPerson_props` folder in Downloads is the earlier source of these models, but the repo's `tools/make-props.py` is the one to edit.

### Torches you can see (Mark's request)

Lights in town use the existing `Torch` entity (its flame particles and `PointLight`), but every flame must come **from a visible torch**, not hang in the air. There are two kinds:

- **A standing torch**: a wooden or iron post about 1.8-2 m tall with a cup or brazier on top. These go round the square and along the streets.
- **A wall torch**: a bracket with a short torch on it, fixed to the wall beside the gate passage and on the keep.

Both are small, low-poly `.obj` models added to `make-props.py` using the shared atlas (wood or iron tiles), placed with `PropModel`. The flame's base goes at the model's tip. The builder can use a camera-facing `Prop` sprite instead if a model looks worse or costs more, as long as the flame clearly sits on it. In the map, `l` is a standing torch; wall torches are placed by the scene next to the gate and the keep door. The new `TownTorch` (or an option on `Torch`) adds the model and the flame together, so the two can't drift apart. Optionally, give the graveyard hut's lantern and the crypt's wall torches the same treatment later. That's outside this piece of work.

### Townsfolk and pigs

The sources are in `~/Downloads/bge aaa/flare monsters/Flare Npcs/`: `Peasant/MalePeasant.blend` (four texture variants), `FemalePeasants/*` (peasant, noblewoman, old woman, witch), `Noblemen/*`, `OldMan/*`, `LuxPriest/*` and `Pig/Pig.blend`. Copy the ones that get used into `art/`, unchanged, like the existing sources, and add them to `CREDITS.md` (Flare NPCs, by their authors and under their licence from their OpenGameArt page).

Render them the way the README describes for the knight and monsters: convert with Blender 2.79 (`tools/convert-flare.py`), then render with Blender 5 and `../../tools/render-character.py --config tools/characters.py --packed`. Add a `CHARACTERS` entry for each NPC in `tools/characters.py`:

- **Idle only** (Flare's stance, frames 1-4), plus a walk cycle for the pig if the file has one. The builder checks which actions each `.blend` actually has.
- **Same scale as the knight** (64 px for 2 m). Adults come out a little shorter than him, the old man shorter still, the pig small.
- **Texture variants**: where one `.blend` has several skin PNGs (four male peasants, three noblemen), render two or three variants by swapping the image the material uses. A config key for the texture image may need adding to `render-character.py`, as a generic option.
- **Texture memory.** About six to eight NPC sheets with four idle frames each, 16 directions, should be small next to the combat sheets. Use `--mirror` for anyone who isn't holding something in one hand, which halves their sheet. The builder reports the total.

An NPC entity, `Entities/Townsfolk.bs`, is a `DrawableOrientedSprite` drawn like the knight (`axisAligned`, `isShaded`, `lightWrap` 0.5), playing its idle loop. Each one starts at a random point in the loop, so a crowd doesn't bob in step. It has a round solid body so the knight bumps into it. It isn't a `Fighter` and can't be hit.

**Which NPC goes on which `n` spot**, and its facing, is chosen from a cell-fixed random number (`cellRandom`), like the graveyard's graves and trees. The town looks the same every time, and the people near the square face roughly toward the well. If the builder wants explicit choices, add a small table in the scene keyed by spot.

**Pigs**: a `Pig` entity that idles, and if there's a walk cycle, now and then picks a point inside its pen and ambles there, kept in by the pen's fence solids. Three or four pigs.

## Decided while building

- The town wall is four inward-facing `DrawableWall`s plus tower and gate models, not `wall_segment` models: the knight never sees the outside, and ~30 wall models would cost far more to draw.
- Seven townsfolk sheets (peasant m/f, nobleman, noblewoman, old man, priest) and the pig, 5.7 MB of texture in all.

## Code shape

- `src/maps/town.txt`: the layout.
- `Town/TownMap.bs`: parse, connected groups, wall runs, cell ↔ world, like `GraveyardMap` but its own file. The builder may pull shared helpers out of `GraveyardMap` into one small grid helper if it helps; don't change graveyard behaviour.
- `Scenes/TownScene.bs`: extends `ThirdPersonScene`. It loads the knight's sheet, the NPC sheets, the town ground, the sky, the props atlas and the models. It places everything from the map, sets up `SolidWorld` and `SolidTracker`, and handles the gate exit. It has no enemies, so no `CombatDirector` spawning, but the knight still needs whatever `ThirdPersonScene` expects (HUD, camera rig). In `onDestroy` it frees what only it uses, keeping the shared bitmaps (`nightSky`) as the graveyard does.
- `Entities/Townsfolk.bs`, `Entities/Pig.bs`.
- Reuse `PropModel` (buildings, with camera blockers), `Fence`, `Torch` and `Pillar` as they are.
- Building heights matter for the camera: the walls are 10 m and the keep 14 m. The `PropModel` camera blockers should stop the chase camera ending up inside them; check that it behaves near the walls.

## Verification

- `npm run check` and `npm run check:all` pass.
- **On the device**, which is required (static checks have missed runtime crashes before):
  - Start in town. Walk round the whole of it: through the streets, into the square, round the fields, the pen and the keep. Nothing walks through anything, and the camera doesn't end up inside walls.
  - Take the gate to the graveyard, then come back. The knight arrives at the right spot each way. Go Graveyard → Crypt → Graveyard → Town.
  - The FPS in town (first paused sample, quality pinned) is no worse than the graveyard's at the same quality. Note the texture memory with the NPC sheets loaded.
  - The ground's edge is never visible from inside the walls, and the streets line up with the doors and the gate.
- Docs: the README's scene table, a "Town art" section (the ground tool, the NPC renders, the keep), the render commands for the NPCs, and the "Still needed" list updated.

## Left to the builder

The exact layout and the map's characters; the ground's palette and texel scale; which NPC variants to render; the keep's exact shape; the torch positions; the pig wander behaviour; and how doors' facings are marked. Choices made here that Mark didn't make himself: night, the text-file layout plus the generated ground image, the 36×32-cell size suggestion, no `CombatDirector` enemies, and the NPC selection by cell-fixed random number.

## Torch light on a painted ground (decided: option 3, baked glow; option 1 can follow as an engine issue)

1. **Engine change, in its own PR first:** make light pools work on `staticImage` planes too. Pools are already drawn over the texture after the warp, so the change is probably small, but it's engine code, with tests and a device check. The town would then use it.
2. **Live without torch pools on the town ground.** The torches still light the buildings, the NPCs and the knight, and the moonlight still tints the ground. Only the warm circle of light on the cobbles is missing.
3. **Bake the light into the painted ground.** The tool paints a warm glow round each `l` cell into the image. It costs nothing at runtime and looks right, but it doesn't light the knight's feet differently from anyone else's, and moving a torch means regenerating the image.
