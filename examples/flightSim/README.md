# Biplane Flight

A small flight sim over `BGE.DrawableVoxelTerrain` (#655): fly a biplane round an island through a
course of ten rings, in order, against the clock. The chase camera rolls with the plane's bank and
uses shear pitch, so the rings sit exactly on the hills and hide behind them.

Hitting the ground or the sea puts you back at the last ring you passed, 5 seconds down. Finish the
course and it starts again; the best time is kept until you quit.

## Controls

The remote and the phone controller page (`http://<roku ip>:8888`) fly the plane on a Roku. A
real Roku doesn't pass a paired gamepad's sticks to channels, so to fly with a gamepad, connect
it to the phone or computer showing the phone page (its D-pad and left stick drive stick 1). The
gamepad column is for the brs-engine simulator.

| Action | Simulator gamepad | Remote | Phone page |
| --- | --- | --- | --- |
| Bank / pitch | left stick or d-pad | d-pad | stick 1 |
| Faster (hold) | RT, R1, A | OK, FF | A, R1 |
| Slower (hold) | LT, L1 | RW | B, L1 |
| Throttle | right stick up/down | | stick 2 |
| Invert pitch | X | `*` | X |
| Restart course | Y | Instant Replay | Y |
| Quit | | Back | |

Letting go of the stick levels the plane. Pitch is the pilot's way round by default (stick up,
nose down); X / `*` flips it.

Deep links: `quality=<0-4>` pins the render quality level (basic to ultra), otherwise it adapts;
`debug=1` shows the FPS and input panels; `profile=1` logs a `FLIGHT` line of render stage times
every 60 frames; `draw=<units>` sets the draw distance (default 1700).

## Performance

On a Roku Ultra (1080p) at Basic: ~25 fps flying level, ~22 fps in a banked turn, where the
terrain is drawn rolled (~22 ms) and the plane costs ~10-12 ms. The plane moves every frame, so it
can't use an impostor and redraws all its faces; it culls back faces, which halves that. The
rings are impostors (static), which saves ~9 ms with two near rings. Adaptive quality settles
around Medium at the engine's default 20 fps target.

## Art

- `src/models/biplane.obj`, `propeller.obj`: a low-poly biplane (made by Claude), split so the
  propeller can spin. Nose +x, y up. The wings and tail are single-sided but face up and back,
  so the body is drawn culled (`solid`) and only the propeller with `solidDrawBackFace`.
- `src/maps/island.bvox`, `src/sprites/sky.png`: made by `python3 tools/make-art.py` (standard
  library only), which writes the island's heightmap and colour map to `art/` and bakes them with
  `../../tools/voxel-map.py`. Paint over the PNGs and re-bake to change the island:

  ```sh
  python3 ../../tools/voxel-map.py art/island-heights.png art/island-colors.png src/maps/island.bvox --edge flat --flat-height 30 --flat-color 2A5DA8
  ```

  The ring course (`FlightScene.coursePoints`) is in map cells, so check it still clears the hills.
