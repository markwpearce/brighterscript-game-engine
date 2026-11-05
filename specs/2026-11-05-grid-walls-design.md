# Grid walls: raycast wall rendering for grid mazes

## Intent

`examples/thirdPerson`'s crypt is a stone maze on a grid. Drawing its walls as warped quads
(oriented images or textured models) is the expensive path on Roku: every quad costs about
3 ms on a Roku Ultra, so 2 m segments ran at 2-5 fps, and one quad per straight run reaches
20 fps only because long quads, warped as two affine triangles, smear and swim up close
(measurements in `specs/2026-11-05-third-person-crypt-design.md`'s branch history).

The `rendererTest` demo `raycast-walls-benchmark` (branch `examples/third-person-crypt`)
measured the Wolfenstein/Doom alternative on the same Ultra: one grid ray per screen strip,
one `DrawScaledObject` of a one-texel-wide texture column per strip, tinted for light.
At 4 px strips (320 rays) a frame took about 12 ms (5 ms casting, 6 ms drawing) and held
62 fps; 1 px strips facing a wall up close dropped to 20 fps. Cost depends on screen width and
wall coverage, not on how many walls there are, and walls are perspective-correct.

This adds that as an engine feature, so any scene built on a grid (the crypt, later a
dungeon) gets fast, correct walls inside the normal 3D renderer: with the floor plane, the
lights, sprites and models, and the chase camera.

## Goals

- `BGE.GridWalls` drawn by the game renderer with `Camera3d`: walls on the edges between
  solid and open cells of a grid, textured, lit by the renderer's lights.
- Walls line up with the floor plane, and with oriented images and models placed on or by
  them, at any camera heading and with the camera tilted up or down (Mark: "I do want this to
  work with a camera that can tilt up/down"). The range is thirdPerson's (Mark: "use the
  thirdPerson values"): its `OrbitCamera` rests about 8.5 degrees down (1.8 m up, looking at
  1.2 m from 4 m away) and tilts by `minTilt`..`maxTilt`, -0.4..0.4 by default and up to 0.45
  in the crypt, so the camera pitches from about 15 degrees up to about 35 degrees down.
- Sprites, billboards, particles and models behind a wall are hidden by it, partly or wholly.
  So are in-world overlays games draw on the game canvas (`Renderer.drawWorldBar`,
  `drawWorldCircle`, `drawWorldArc`, `drawWorldPolyline`, e.g. an enemy's health bar). Screen
  UI on the UI canvas (the player's HUD) always shows over everything (Mark's decision).
- Cost scales with strip width, which is a render-quality setting, so adaptive quality can
  trade wall resolution for frame rate.
- Done is measured in `rendererTest` on the Ultra. The crypt switches over later, as separate
  work (Mark's decision: engine change first, thirdPerson later).

## Non-goals

- A camera outside the maze or above the wall tops (looking down on walls), and walls not on
  a grid. For now the camera stays inside open cells, below the wall tops; document that as
  the rule and don't check it every frame (Mark's decision). But Mark may later want this
  style for a camera above the walls or for things that aren't on a grid, so see the
  constraint on structure below.

- Different wall heights per cell, sloped floors, ceilings, floors other than a
  `DrawablePlane`, doors that open, transparent or cut-out walls (windows, bars, fences).
- Camera roll (`Camera3d.rollDegrees`). Walls are drawn as if roll were 0; document it.
- Making the existing occlusion culling (`isOccluder`) use the wall depth buffer. Possible
  later; not needed for the frame rate.
- Collision. Games keep using `SolidWorld` / their own grid for movement and camera booms.

## Anti-goals

- A visible seam or gap between the walls' feet and the floor plane as the camera turns.
- Characters showing through walls (an enemy round a corner drawn over the wall in front).
- Walls that flicker, pop or blink as lights or quality change.
- A per-frame cost that grows with the number of walls in the level.

## Constraints

- Everything in `CLAUDE.md`: render-quality rules (a quality/speed constant belongs in
  `BGE.RenderQualitySettings` with all five levels, and `RenderQualityPresets.spec.bs` is
  extended), the draw-queue limit (~13,000 draws per bitmap per frame), strong types, one
  Rooibos suite per file, `import` what you use, `isValidEntity` rules in `Game.bs`.
- Two colour formats: drawable colours are RGB, renderer draws RGBA.
- Headless brs-engine can't show draw costs or most device behaviour: frame rate and looks
  are measured on the Ultra (192.168.41.102) with `rendererTest` and the crypt.
- Engine work goes in its own branch and PR (`engine/grid-walls`); no thirdPerson changes.
- **Keep the pieces separable for later uses.** Finding what each strip shows (today: the
  first grid wall a ray hits) is its own unit, apart from drawing strips, lighting them and
  the depth buffer. A later hit source (wall segments not on a grid, or several hits per ray
  for a camera above the walls) should slot in without rewriting the drawing and hiding.

## Decided

**Shape of the API (my call, in the style of `DrawablePlane`).**
- `BGE.GridWallsMap`: the grid. Columns x rows of cells, each solid or open, a cell size and
  wall height in world units, and the world position of cell (0, 0)'s corner. Built from rows
  of characters with a legend (which characters are solid, and which wall texture each solid
  character uses), so a game's map stays a text grid like `CryptMap.layout()`. Row 0 is -z,
  column 0 is -x, as in `CryptMap`. Outside the grid counts as solid.
- `BGE.DrawableGridWalls(owner, map, textures, args)`: a drawable an entity adds, like
  `DrawablePlane`. `textures` maps a texture name to an `roRegion` whose width spans one cell
  and whose height spans the wall height. `isShaded` works as for other drawables.
- `BGE.SceneObjectGridWalls`: its scene object; a new `SceneObjectType` the renderer draws in
  its own stage, after planes and before the sorted objects (stage name `gridWalls` in
  `profileStages`). At most one per renderer is supported; a second logs a warning and is
  ignored.

**Drawing.** Each frame, cast rays from the camera through the grid (DDA) in horizontal
directions spread across the camera's view, one per strip. For each hit, project the wall's
foot and top at the hit point with the real `Camera3d` projection, and draw that texture
column as a strip from the projected foot to the projected top. With the camera tilted, a
vertical world line leans on screen (toward a vanishing point above or below the screen), by
hundreds of pixels at the screen's edge for a steep tilt, so the strips must lean with it to
stay matched to the floor and to oriented props on the walls: draw each strip rotated to the
foot-to-top angle (e.g. `DrawTransformedObject` with a positive scale), not upright. Measure
rotated strips against upright ones on the Ultra; if rotation is too slow, a fallback (e.g.
upright strips cut into a few stacked pieces, each at its own x) is the builder's call, with
the measurements. Choose ray directions so strips are evenly spaced across the screen where
the walls are; draw strips far to near, each wide enough to meet its neighbours so no gaps
open.
Walls past the camera's effective draw distance aren't drawn, and walls fade toward the
background with distance the same way other objects do (`drawDistanceFadeFraction`).

**Light.** With `isShaded`, each strip's tint comes from `BGE.Lighting.shadeColor` at its
hit point with the wall's normal, so torchlight falls off along walls. To keep it cheap,
light is computed every few strips and interpolated (how many is a quality setting, or the
builder's call if measuring shows it doesn't matter). Lighting changes follow the renderer's
existing `lightingVersion` rules; nothing is cached across frames that would make lights blink.

**In-world overlays.** The `Renderer.drawWorld*` helpers check the depth buffer at their
world point(s) and skip what's behind a wall (a bar or label at one point is hidden whole;
lines and arcs may be hidden per piece or whole, builder's call). A public query ("is this
world point behind a wall from the camera this frame?") is exposed for games' own in-world
drawing. Drawing on the UI canvas is never affected.

**Hiding things behind walls.** The pass leaves a per-strip depth buffer (distance along the
camera's forward axis to the wall at each strip). Before an object in the sorted pass draws,
its screen bounds and nearest depth are compared with the buffer over its x span: if the
wall is nearer across the whole span, it's skipped (counted like occluded objects); if the wall
is nearer over part of it, it draws, then the wall strips nearer than it within its span are
drawn again over it. Objects in front of every wall in their span are untouched.

**Quality.** A new `RenderQualitySettings` value for strip width in pixels at each of the
five levels (Medium 4, the measured sweet spot; wider at lower levels, narrower is allowed at
the top only if measured affordable), plus the lighting interval if it's a setting.

**Proof.**
- Rooibos tests for the grid parsing, the ray march (hit cell, side, distance and texture u
  at known rays), strip placement against `Camera3d.worldPointToCanvasPoint`, the depth-buffer
  hide/redraw decision, and the quality presets.
- A `rendererTest` demo with a small maze, the floor plane, an oriented image on a wall, a
  billboard walking behind a wall with a `drawWorldBar` over it, and the camera turning and
  pitching across the whole range (15 degrees up to 35 degrees down), timed like the other demos, run on the Ultra at each quality level.
  Done when it holds 20 fps at Medium with walls meeting the floor and the wall image without
  visible gaps or drift, and nothing behind a wall showing.
- A guide in `docs/` (frontmatter, how-to first, gotchas as asides) and a `CLAUDE.md` note.

## Left to the builder

- Internal structure: how DDA results, buffers and per-strip data are stored and reused.
- Exactly how far apart strips are in angle (uniform in screen x at the horizon is fine).
- How partial redraw picks strips, as long as the result is correct and measured cheap.
- Whether the floor fade and wall fade share code.
- Texture u direction per wall side, as long as textures aren't mirrored on any side.
