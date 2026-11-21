---
title: Voxel Terrain
group: Guides
order: 18
---

# Voxel Terrain

`BGE.DrawableVoxelTerrain` draws hills from a heightmap, the way NovaLogic's Comanche (1992) did:
for each screen column, a ray steps over the map from near to far, and wherever the ground rises
into view it draws a vertical strip. There are no polygons, so it's cheap enough for real hills on a
Roku, at the cost of a blocky, low-resolution look (quality sets how many columns). Flat ground is
better done with a [`DrawablePlane`](/drawables-and-scene-objects).

It needs a `Camera3d`, and a renderer draws one terrain at most.

## Maps

A `BGE.VoxelMap` is a square grid, 64 to 1024 cells along each side (a power of 2), with a height
(0-255) and a colour for every cell. Colours are indexes into a palette of up to 256 RGB colours.
The map also keeps smaller copies of itself (mip levels) for drawing far terrain without flicker.

Past its edges a map either repeats (`edgeMode: "wrap"`, so it should tile) or is a flat floor of
one height and colour (`edgeMode: "flat"`, e.g. sea round an island).

### Baking a map from images

Paint a grayscale heightmap (black is 0, white 255) and a colour map the same size in any
paint program, then bake them into a `.bvox` file:

```sh
python3 tools/voxel-map.py heights.png colors.png island.bvox --edge flat --flat-height 60 --flat-color 2A5DA8
```

The colour map can have any number of colours: more than 256 are reduced to 256. The tool needs only
Python 3. Load the file in your game:

```brighterscript
map = BGE.VoxelMaps.fromFile("pkg:/maps/island.bvox")
```

Loading is quick (a 256 map takes ~2 ms on a Roku Ultra), so do it whenever you need it.

### Other ways to make one

- `BGE.VoxelMaps.fromArrays(size, heights, colors, palette, options)` from integer arrays you've
  built in code.
- `BGE.VoxelMapGenerator` makes random tileable maps: diamond-square heights coloured by height
  bands (water, sand, grass, forest, rock, snow by default) and shaded by slope. It's slow (~1.3 s
  for 256x256 on a Roku Ultra, long enough to trip the watchdog on slower devices), so generate a
  map once and keep it: `map.saveToFile("tmp:/world.bvox")`.

## Adding the terrain

```brighterscript
terrain = new BGE.DrawableVoxelTerrain(entity, map, {
  cellSize: 4,        ' world units per map cell
  heightScale: 1.5,   ' world units per height unit
  fade: {color: &h8EC5F0, start: 0.5}
})
entity.addDrawable("terrain", terrain)
```

The entity's position (plus the drawable's `offset`) is map cell (0, 0). Map x and z are world x
and z, and a height of 255 is `255 * heightScale` above the entity.

To stand something on the terrain, `terrain.heightAt(worldX, worldZ)` gives the ground's world y
there, blended between cells.

`setMap(map)` swaps the map. Call it too after changing a map's heights or colours in place, or
the terrain keeps drawing what it had.

## What draws over what

The terrain draws after the ground planes and before [level walls](/drawables-and-scene-objects)
(walls always draw over it). Everything sorted by depth (sprites, models) is tested against the
hills: one wholly behind a hill isn't drawn, and one partly behind it is drawn and then the
nearer hillside is drawn back over it. This is exact to a screen column.

Nothing is drawn above the terrain, so put a skybox or a backdrop behind it.

## Fog and fading

With `Camera3d.fog` on, far terrain fades into the fog colour. With it off, set `fade` to fade it
into another colour (usually the sky's) from `start` (a fraction of the draw distance) to the far
end. Without either, the terrain just stops at the draw distance.

## Roll and pitch

Roll works at any angle: the terrain is drawn level into a square bitmap as wide as the screen's
diagonal, then turned onto the screen. That bitmap is kept while rolled: ~8.6 MB at 1280x720, ~19 MB
at 1920x1080, which counts against the device's texture memory.

Pitch is harder: the terrain's columns stay upright, so it can't truly look up or down. `pitchMode`
picks how it copes:

- `horizonShift` (default): the horizon moves up or down. This is cheap, but only right near
  level. Past about 15 degrees up or down, objects float above or sink into the ground.
- `exact`: every step is projected with the pitched camera, so objects sit on the ground at any
  pitch. It costs about a third more. Objects near the screen edges drift sideways a little at
  steep pitches, since the columns can't lean.

## Quality and cost

The cost is almost exactly columns x depth steps, about 4 µs each on a Roku Ultra. Quality sets
both (`voxelColumns`, `voxelBandSteps`, see [Render Quality](/render-quality)); the draw distance
sets how many steps there are. While the camera is still, the terrain draws the same strips again
without marching.

Flying and turning over a 256 map, terrain only, on a Roku Ultra at 1280x720:

| Level  | Columns | `horizonShift` | `exact` | `horizonShift`, rolled |
| ------ | ------- | -------------- | ------- | ---------------------- |
| Basic  | 50      | 48 fps         | 38 fps  | 39 fps                 |
| Low    | 64      | 39 fps         | 31 fps  |                        |
| Medium | 80      | 30 fps         | 23 fps  | 24 fps                 |
| High   | 100     | 24 fps         | 18 fps  |                        |
| Ultra  | 100     | 21 fps         | 16 fps  | 17 fps                 |

Objects cost the same as anywhere else, plus a little for the hill test (~5 ms for ~40 in view).
The rendererTest app's **Voxel Terrain** demo (`demo=voxel-terrain`) shows all of this, and with
`sweep=1` it prints these numbers for your own device.
