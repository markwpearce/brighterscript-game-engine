---
title: Tile Maps
group: Guides
order: 8
---

# Tile Maps

A tile map builds a level out of a grid of same-sized cells: ground, walls,
water, platforms. The engine doesn't have a map format of its own. It gives
you a few helpers that take plain lists of cells, so your map can come from
anywhere: strings written in code, arrays of tile ids, a generated layout, or
data exported from an editor.

The helpers, all in the `BGE.TileMap` namespace unless noted:

| Job | Helper |
| --- | --- |
| Draw thousands of tiles cheaply | `bakeTileMapImages()` |
| Turn solid cells into a few colliders or solids | `mergeTileColliderRuns()` |
| Side-scroller collision (incl. one-way platforms) | `BGE.resolveAabbTileCollision()` |
| Top-down movement against walls | `BGE.SolidWorld` |
| Pick border/corner tiles from neighbours | `getEdgePiece3x3()`, `getNeighbourMask4()`, `getNeighbourMask8()`, `getBlobTileIndex()` |

`examples/platformer` (side-scrolling) and `examples/rpg` (top-down) use all
of these; this guide follows how they do it.

## Grid cells and world positions

Whatever your map data looks like, at some point you'll walk it row by row
and turn each cell into a world position. Two things to keep straight:

- Map rows usually count **down** from the top, but world **+y is up**. So
  row 0 is the highest row in the world.
- Different helpers want different corners. Tile images and rectangle
  colliders take a **top-left** corner; `BGE.SolidWorld` takes a
  **bottom-left** corner.

A pair of small functions keeps that in one place:

```brighterscript
const TILE_SIZE = 32

' Top edge of a cell row, in world space - for TileSpec.worldY and
' addRectangleCollider()'s offset_y.
function cellTopY(numRows as integer, row as integer) as float
  return (numRows - row) * TILE_SIZE
end function

' Bottom edge of a cell row - for BGE.SolidWorld.addSolid().
function cellBottomY(numRows as integer, row as integer) as float
  return (numRows - row - 1) * TILE_SIZE
end function
```

The rest of this guide uses these two names.

### One way to write map data

Both example games write their maps as one string per row, one character per
cell, with a legend in a comment:

```brighterscript
' #  solid    -  one-way platform    .  empty
function getLevelRows() as string[]
  return [
    "........................",
    "..........---...........",
    "........................",
    "########....############"
  ]
end function
```

That's easy to read and edit in code, but it's only a choice: the helpers
below never see the strings. An array of integer tile ids works just as well,
and so does anything you can loop over.

## Drawing the ground

Adding one `Image` per tile would give the renderer one object to sort and
draw per tile, every frame. Instead, describe every tile as a
`BGE.TileMap.TileSpec` and bake them into a few large bitmaps once, when the
level is built:

```brighterscript
override sub onCreate(args as roAssociativeArray)
  rows = args.rows
  numRows = rows.count()
  sheet = m.game.getBitmap("tiles")
  ' One region per tile kind, reused for every tile of that kind
  groundRegion = CreateObject("roRegion", sheet, 0, 0, TILE_SIZE, TILE_SIZE)

  tiles = [] as BGE.TileMap.TileSpec[]
  for r = 0 to numRows - 1
    for c = 0 to rows[r].len() - 1
      if rows[r].mid(c, 1) = "#"
        tiles.push({
          worldX: c * TILE_SIZE,
          worldY: cellTopY(numRows, r),
          region: groundRegion,
          width: TILE_SIZE,
          height: TILE_SIZE
        })
      end if
    end for
  end for

  chunks = BGE.TileMap.bakeTileMapImages(tiles, 512)
  for i = 0 to chunks.count() - 1
    chunk = chunks[i]
    region = CreateObject("roRegion", chunk.bitmap, 0, 0, chunk.bitmap.GetWidth(), chunk.bitmap.GetHeight())
    m.addImage("ground_" + i.toStr(), region, {
      offset: BGE.Math.VectorOps.create(chunk.worldX, chunk.worldY),
      drawMode: BGE.SceneObjectDrawMode.matchCamera
    })
  end for
end sub
```

Each chunk becomes one draw call. A tile can be any size and can be nudged
off the grid (the platformer raises its grass tiles a few pixels so the
player's feet line up with the art); a chunk's bitmap grows to fit.

> **Keep `chunkSize` at 512 or below.** Larger chunks can fail to draw inside
> a running game even though they work in isolation (issue #213).

Baking happens once, in `onCreate()`, so its cost is paid while the level
loads rather than every frame.

## Side-scrolling games

A side-scroller's tiles are real colliders, and the player is pushed back out
of a tile after the engine reports an overlap.

### Colliders for tiles

`mergeTileColliderRuns()` joins neighbouring cells in the same row that have
the same tag, so a 20-tile floor becomes one collider instead of 20. Tag
cells with whatever your game needs to tell apart:

```brighterscript
cells = [] as BGE.TileMap.ColliderCell[]
for r = 0 to numRows - 1
  for c = 0 to rows[r].len() - 1
    ch = rows[r].mid(c, 1)
    if ch = "#"
      cells.push({row: r, col: c, tag: "solid"})
    else if ch = "-"
      cells.push({row: r, col: c, tag: "oneWay"})
    end if
  end for
end for

colliderRuns = BGE.TileMap.mergeTileColliderRuns(cells)
for i = 0 to colliderRuns.count() - 1
  colliderRun = colliderRuns[i]
  width = (colliderRun.endCol - colliderRun.startCol + 1) * TILE_SIZE
  collider = m.addRectangleCollider("tileRun_" + i.toStr(), width, TILE_SIZE, colliderRun.startCol * TILE_SIZE, cellTopY(numRows, colliderRun.row))
  collider.tagsList.add(colliderRun.tag)
end for
```

### Landing, bumping and one-way platforms

In the player, remember where it was before this frame's movement, then let
`BGE.resolveAabbTileCollision()` work out which side it hit:

```brighterscript
override sub onUpdate(dt as float)
  m.positionBeforeMove = BGE.Math.VectorOps.create(m.position.x, m.position.y)
  ' ... gravity, running, jumping: set m.velocity ...
end sub

override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
  if otherEntity.name <> "Level"
    return
  end if
  tile = otherCollider as BGE.RectangleCollider
  isOneWay = tile.tagsList.hasTag("oneWay")
  result = BGE.resolveAabbTileCollision(m.positionBeforeMove, m.position, m.width, m.height, m.velocity, tile, isOneWay)
  m.position.x = result.position.x
  m.position.y = result.position.y
  m.velocity.x = result.velocity.x
  m.velocity.y = result.velocity.y
  if result.side = BGE.TileCollisionSide.top
    m.grounded = true
  end if
end sub
```

The player's position is the bottom-centre of its hitbox. A one-way tile only
stops a player landing on it from above; from below or the side it passes
straight through.

> **Don't rely on `onCollision()` to keep the player grounded.** The
> compositor doesn't always report the same overlap again on the next frame,
> so a player standing still can look like it keeps leaving the ground.
> Assume it's still grounded until it jumps or walks off an edge, and use
> `onCollision()` to detect new landings. See `examples/platformer`'s
> `Player.bs`.

> **Cap `dt` for fast falls.** This approach fixes an overlap after it
> happens, so a very long frame can move the player clean through a thin tile
> before any collision is seen. The platformer limits each update to 1/30s.

## Top-down games

In a top-down game, characters walk around walls rather than landing on
them, and it's simpler to keep them out of walls in the first place.
`BGE.SolidWorld` does that with plain rectangle maths: no colliders, no
`velocity`.

### Walls

Feed the same merged rows into a `SolidWorld`, and fence in the map's edge:

```brighterscript
world = new BGE.SolidWorld()
for each colliderRun in BGE.TileMap.mergeTileColliderRuns(cells)
  width = (colliderRun.endCol - colliderRun.startCol + 1) * TILE_SIZE
  world.addSolid(colliderRun.startCol * TILE_SIZE, cellBottomY(numRows, colliderRun.row), width, TILE_SIZE)
end for
world.addBounds(0, 0, numCols * TILE_SIZE, numRows * TILE_SIZE)
```

Keep one `SolidWorld` per scene and hand it to everything that walks.

### Moving

Each frame, move a box at the character's feet and take its new position from
the result:

```brighterscript
sub moveBy(dx as float, dy as float)
  feet = {x: m.position.x - FEET_W / 2, y: m.position.y, w: FEET_W, h: FEET_H}
  result = m.solidWorld.moveAndSlide(feet, dx, dy)
  m.position.x = result.x + FEET_W / 2
  m.position.y = result.y
end sub
```

`moveAndSlide()` stops flush against walls, slides along them, splits a long
move into short steps so nothing tunnels through, and eases the box around a
corner it only just clips. Pass `{cornerNudge: 0}` for moves that shouldn't
steer, like being knocked back.

Using only the feet lets a character's head overlap a wall drawn above it,
which is what you want with a top-down camera.

Colliders are still useful for things that *trigger* rather than block: a
door, a pickup, an enemy's attack. `examples/rpg` uses `onCollisionEnter()`
on a `feet` collider for doors.

### Drawing in front of and behind things

Under `BGE.Camera2d`, a higher `position.z` draws in front. Set every
character's and prop's `z` from its feet, so whatever is lower on screen
draws in front, and push the ground far behind everything:

```brighterscript
m.position.z = -m.position.y      ' characters and props, every time they move
groundEntity.position.z = -9000   ' the baked ground
```

## Which collision approach?

| | `resolveAabbTileCollision()` | `BGE.SolidWorld` |
| --- | --- | --- |
| Works with | Compositor colliders, in `onCollision()` | Plain rectangles, no colliders |
| When it acts | After an overlap is reported | Before the move happens |
| One-way platforms | Yes | No |
| Stops fast movers tunnelling | No (cap `dt`) | Yes |
| Slides along walls / eases corners | No | Yes |
| Typical game | Side-scrolling, gravity | Top-down, free movement |

## Auto-tiling

A path of cobblestones through grass looks blocky if every cobble cell uses
the same picture. Auto-tiling picks each cell's tile from its neighbours, so
borders and corners come out right without anyone choosing them by hand.

All the auto-tile functions take your grid as an array of rows. Each row is
either a string, one character per cell, or an array of cell values such as
integer tile ids. Two cells are the same surface when their values are
equal.

### A 3x3 edge set

The simplest tile sheet has nine pieces: four corners, four edges and a
centre. `getEdgePiece3x3()` returns which one to use:

```brighterscript
piece = BGE.TileMap.getEdgePiece3x3(rows, r, c)
region = CreateObject("roRegion", sheet, setX + piece.col * TILE_SIZE, setY + piece.row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
```

A 3x3 set has no inner corners or one-cell-wide pieces, so those cells get the
centre piece. Draw paths at least two cells wide, or use a bigger set.

### 16- and 47-tile sets

For more complete sheets, get a neighbour mask, where each matching neighbour
sets one bit:

| | | |
| :-: | :-: | :-: |
| NW 128 | N 1 | NE 2 |
| W 64 | | E 4 |
| SW 32 | S 16 | SE 8 |

- **16 tiles** (sides only): `getNeighbourMask4()` returns 0-15 using N = 1,
  E = 2, S = 4, W = 8, which indexes the set directly.
- **47 tiles** ("blob" sets, with inner corners): `getNeighbourMask8()`
  returns 0-255 with the bits above, and `getBlobTileIndex()` turns that into
  0-46.

```brighterscript
mask = BGE.TileMap.getNeighbourMask8(grid, r, c)
tile = BGE.TileMap.getBlobTileIndex(mask)
' this sheet lays its 47 tiles out 8 per row
region = CreateObject("roRegion", sheet, (tile mod 8) * TILE_SIZE, (tile \ 8) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
```

There are only 47 because a corner only matters when both sides next to it
also match. `reduceBlobMask()` clears the corners that don't, and
`getBlobTileIndex()` numbers the 47 results in ascending order.

> **Your sheet's order may differ.** Blob sheets from different tools lay
> out their 47 tiles differently. If yours doesn't match ascending-mask
> order, build your own lookup from `reduceBlobMask()`'s value to a tile
> position.

### The map's edge

A neighbour outside the map counts as matching, so a path runs cleanly off
the edge. Pass `{outOfBoundsMatches: false}` to draw a border there instead.
A missing cell (past the end of a short row) or an `invalid` cell value also
counts as outside the map.

## Map editors

Editors like [Tiled](https://www.mapeditor.org/) choose border and corner
tiles while you paint, and save the final tile id for every cell, so a map
from one doesn't need runtime auto-tiling: loop over its tile ids and build
`TileSpec`s and `ColliderCell`s the same way as above. The engine doesn't
load Tiled maps yet (issue #196).

Runtime auto-tiling is still useful for maps made in code, or generated by
the game, and for re-tiling the cells around one that changes during play.
