# Room levels: buildings with heights, learned from DOOM

## Intent

BGE should be able to draw ordinary first- and third-person levels: rooms, stairs and
buildings, including **rooms directly above other rooms**, with BGE's 3D models, sprites and
lights inside them, fast enough on a Roku.

BGE is not becoming a DOOM engine. It won't load WADs or copy DOOM's limits. It borrows the
ideas that make DOOM-family engines (DOOM, Build, Quake's portals) fast on weak hardware:

- **Only touch what's visible.** Walk the level outward from the camera's room through the
  openings on screen, so rooms that can't be seen, and everything in them, cost nothing.
- **Front to back with closing windows.** Each screen column (ray) keeps an open window that
  nearer walls narrow; a closed ray costs nothing more. `BGE.WallsView` (#468, #473) already
  does this for `DrawableWalls`.
- **Two-sided lines.** Where two rooms share an edge, it's an opening; the difference in their
  floor and ceiling heights becomes a step below and a lintel above.

The test bed is a new example, **`examples/firstPerson`**: a small DOOM/Quake-style shooter set
in a building of 2–3 storeys.

## Goals

- Levels built from **rooms**: a floor outline (seen from above) with a floor height and a
  ceiling height, and wall/floor/ceiling textures.
- Rooms sharing an edge whose height ranges overlap are joined there automatically. The opening
  spans the overlap; the rest of the edge is drawn as a step (below) and a lintel (above).
- **Rooms over rooms.** Connectivity comes from shared edges with heights, not plan position, so
  rooms may overlap in plan. A stairwell is a tall room touching the ground-floor hall at
  ground height and the upstairs landing at upstairs height (Build engine style). There are no
  holes in floors or ceilings.
- **Textured floors and ceilings**, benchmarked on device before anything is built on them.
- Models and sprites **belong to a room** and are skipped when their room isn't visited.
  They are drawn correctly against nearer walls (a model half behind a door frame is cut off by
  the frame).
- The level data is **plain data** (arrays/AAs). Building in code is for testing only; the
  format must be something an editor or exporter could produce later.
- Read-only queries for game code: which room a point is in, and that room's floor and ceiling
  heights.
- `examples/firstPerson`: a playable slice, holding **≥30 fps on the Roku Ultra at Medium**
  render quality (about what the crypt demo gets today).

## Non-goals

- Loading DOOM/Quake files, or DOOM gameplay rules in the engine.
- **Movement and collision.** Game code moves things, as today. The engine only offers the
  read-only queries above. The example does its own wall sliding and floor snapping.
- A level editor or file format (later, once this works).
- Sloped floors, ramps, seeing under overhangs/balconies, and wall tops (a room's edge is solid
  from its floor to its ceiling except at an opening).
- Moving geometry (doors, lifts) in v1. Keep the design open to changing a room's floor/ceiling
  height at runtime later; that should not need rebuilding the level.
- Replacing `DrawableWalls`/`DrawableGridWalls`. They stay as they are.

## Anti-goals

These would make the work a failure even if it technically ran:

- Models, sprites or lights not working in room levels, or only working as special cases.
- A DOOM-shaped API (linedefs, sidedefs, sectors as user-facing concepts). Users think in rooms
  and openings.
- Regressing existing demos, especially the crypt and grid-walls demos, in speed or looks.
- Textured floors that blow HD devices' 64MB texture memory or the ~13,000 draws-per-frame queue.

## Constraints

From `CLAUDE.md` and device experience:

- `Camera3d` only. Pitch about 15° up to 35° down (as `WallsView`), roll ignored.
- Roku drops all draws into a bitmap once ~13,000 queue in a frame; keep per-frame draws well
  under that.
- HD devices have 64MB of texture memory; FHD screen-sized bitmaps are ~4.5MB each.
- Never draw into a bitmap after reading from it in the same frame.
- Draw costs aren't predictable from code. Every "this path is faster" claim is measured in
  `rendererTest`.
- Quality/speed trade-offs go in `BGE.RenderQualitySettings` with a value at all five levels,
  checked by `RenderQualityPresets.spec.bs`.
- Colocated Rooibos tests for engine code. Example runtime code must be run on a device.
- One issue and one PR per phase. Docs (`docs/drawables-and-scene-objects.md`, `CLAUDE.md`)
  updated with the code.

## How it works (decided)

### Level data

A level is a list of rooms. Each room has:

- `outline`: a **convex** polygon of `{x, z}` points, listed clockwise seen from above (the same
  winding `createWallSegment` uses for inward-facing walls).
- `floor`, `ceiling`: heights.
- `wallTexture`, `floorTexture`, `ceilingTexture`: names into a textures AA, plus tiling sizes as
  `WallSegmentOptions` has.

A concave space is several convex rooms sharing open edges. That costs nothing, because a shared
edge with matching heights is just an opening. Requiring convex rooms means a room's own walls
never hide each other, so no sorting is needed inside a room.

An edge can be marked **solid** (a wall between two touching rooms), and an opening can be
narrowed to a height range (a window with a sill and lintel). *(Builder check; my call.)*

Joining: at build time, find edges of different rooms that lie on the same line and overlap.
Where their height ranges overlap, that span is an opening to the neighbour; the parts outside
it, and edges with no neighbour, are solid walls.

### Drawing: walking rooms through openings

Each frame:

1. Find the camera's room. If the camera is in no room (an orbit camera pushed into a wall),
   use the room it was last in. *(My call.)*
2. Visit it with the full screen's rays open (the per-ray elevation windows `WallsView` already
   keeps).
3. For each edge of the room facing the camera, over the rays it covers:
   - a solid edge draws a wall strip from floor to ceiling and closes those rays;
   - an opening draws the step below and the lintel above it (if any), narrows the windows to
     the opening, and visits the neighbour with just those rays.
4. Between the room's walls/openings and its floor and ceiling, each ray's leftover window is
   that room's floor (below) and ceiling (above). Record those slices for drawing.
5. A room may be visited more than once through different openings (different rays). Stop on
   rays that are closed.

This replaces the global 2D BSP for room levels; ordering comes from the traversal.
`WallsBsp` stays for `DrawableWalls`.

### Drawing order and objects

The traversal visits rooms nearest first. Drawing goes the other way, **room by room, farthest
first**: a room's floor, ceiling and wall pieces, then the objects in it (painter-sorted among
themselves as today), then the next nearer room. Nearer walls and door frames are drawn after the
objects behind them, so they cut those objects off correctly. Objects in rooms that weren't
visited this frame aren't drawn at all.

Drawables with no room (particles, `drawWorld*` overlays, a projectile between rooms) draw
after the rooms in the existing sorted pass, hidden per ray as `DrawableWalls` hides objects
today. One level drawable per renderer: a room level can't be mixed with `DrawableWalls` or
`DrawableGridWalls`, so their stages and the crypt/grid-walls paths stay untouched. *(My call.)*

Lights are not tied to rooms: they light everything as today, so nothing blinks when a room
leaves view. A lamp lighting through a floor is an accepted v1 limitation. *(My call.)*

An object's room is set by game code or worked out from its position when it moves. Objects that
straddle an opening belong to one room; small glitches there are acceptable, because speed comes
first (as with occlusion, #108).

### Floors and ceilings

Phase 1 is a benchmark (below). The candidates to time:

- **A. Plane per height, sliced.** For each distinct visible floor or ceiling height, draw a
  tiled plane into a screen-sized bitmap (the existing `SceneObjectPlane` warp), then copy a
  vertical slice of it into each strip's floor or ceiling slice. Risk: texture memory with
  several heights in view.
- **B. Row spans.** DOOM's approach: a screen row of floor is at constant depth, so it maps to a
  straight line through the texture. Draw each row span as one rotated, scaled texture-region
  draw, stepping rows by a quality setting (e.g. every 2–4 px). Risk: the draw count.
- **Baseline: flat colour** per slice (one filled rectangle per strip), shaded by distance and
  light.

The winner, possibly per quality level, becomes the floor path. The benchmark scene has walls
and floors together; it passes at **≥40 fps on the Ultra at Medium**, leaving room for objects
in phase 4's 30 fps target. *(My call.)* If neither textured path passes, stop and bring the numbers back before phase 2.

## Phases (one issue and PR each)

1. **Floor benchmark** (`rendererTest`): a throwaway demo drawing textured floor/ceiling slices
   at 3–6 heights through `wallStripWidth` strips, timing A, B and the baseline on the Ultra
   and an HD device.
2. **Room level data + renderer**: the data and joining, the room walk, wall/step/lintel strips,
   floors and ceilings using phase 1's winner, and the room queries, with tests. A
   `rendererTest` demo of a two-storey test building.
3. **Objects in rooms**: drawing room by room with objects, skipping unvisited rooms, with
   tests and a demo with models and sprites behind door frames and upstairs.
4. **`examples/firstPerson`**: a building of 2–3 storeys, first-person movement with wall
   sliding and floor snapping in game code, a weapon, a few enemies (sprites and/or models),
   lights, and a third-person toggle if it's cheap (`BGE.OrbitCamera`). Must hold ≥30 fps on
   the Ultra at Medium.

## Left to the builder

- Class and file names (e.g. `BGE.RoomLevel`, `BGE.DrawableRoomLevel`, `renderer/rooms/`), and
  whether the room walk generalises `WallsView` or is a new view sharing its strip, column and
  light-cache code.
- How floor and ceiling slices are batched, and the quality settings phase 1 adds.
- How the camera's and objects' rooms are found (point-in-convex-polygon, cached last room,
  neighbour checks first).
- Lighting details. Use the existing lights and `isShaded`; a per-room brightness is welcome if
  it's cheap.
- The example's gameplay details: weapon feel, enemy behaviour, art. Keep it a slice, not a
  game.
