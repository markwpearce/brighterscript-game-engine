---
title: Pathfinding
group: Guides
order: 12
---

# Pathfinding

`BGE.NavGrid` finds paths around the solids in a `BGE.SolidWorld` (see
[Tile Maps](/tile-maps) for building one). It splits the world into a coarse
grid of open and blocked cells, runs A* across it, and smooths the result into
a short list of waypoints.

## Building the grid

Build the grid once the world's solids are in, at scene load:

```brighterscript
m.nav = new BGE.NavGrid(m.solidWorld, {cellSize: 16, agentRadius: 10})
```

- `agentRadius` grows every solid by that much before it blocks cells, so a
  path that keeps the agent's centre in open cells keeps its body clear of
  walls. Use the radius of the mover's feet box (or collider).
- `cellSize` trades accuracy for cost. A gap is only found if a whole open
  cell fits through it once the solids have grown, so keep cells about the
  agent's diameter or smaller.
- By default the grid covers every solid in the world. Pass `minX`, `minY`,
  `width` and `height` to cover a different area.

Building tests each solid once and costs one byte per cell. For a big map,
build it in a `LoadTask` (see [Loading Assets](/loading-assets)) so the
loading screen keeps drawing:

```brighterscript
override sub onLoad(loader as BGE.AssetLoader, args as object)
  loader.addStep(function(scene as object) as dynamic
    scene.nav = new BGE.NavGrid(scene.solidWorld, {cellSize: 16, agentRadius: 10})
    return true
  end function, m)
end sub
```

## Finding a path

`findPath()` returns the waypoints from the start to the goal, or `[]` if
there's no way there. `path[0]` is the start and the last point is the goal:

```brighterscript
path = m.nav.findPath(m.position.x, m.position.y, target.x, target.y)
if path.count() > 1
  m.waypoints = path
  m.nextWaypoint = 1
end if
```

Then steer towards `m.waypoints[m.nextWaypoint]` each frame (moving with
`SolidWorld.moveAndSlide()`), and step to the next waypoint once you're close.

Moves are 8-way, and never cut diagonally past a blocked cell's corner. The
path is then smoothed: any waypoint the agent can skip, because the straight
line past it only crosses open cells, is dropped. Pass `{smooth: false}` to
get every cell centre instead.

### When the goal can't be reached

- **Start or goal inside a solid**: it moves to the nearest open cell (up to
  `snapRings` cells away, default 8), and the path starts or ends at that
  cell's centre.
- **Goal walled off**: by default you get a partial path to the open cell
  nearest the goal, so an agent still heads the right way. Pass
  `{allowPartial: false}` to get `[]` instead.
- **Long searches**: a search gives up after `maxExpandedCells` cells
  (default 20000) and returns a partial path. An unreachable goal floods every
  cell the agent can reach before it gives up, so this is what bounds the
  cost.

## Spreading a search over frames

`findPath()` runs the whole search at once. That's fine on a small grid, but a
long search on a big one can drop frames, or trip the watchdog. Start a search
instead and give it a few milliseconds each frame:

```brighterscript
override sub onUpdate(dt as float)
  if m.search = invalid and m.repathTimer <= 0
    m.search = m.nav.startSearch(m.position.x, m.position.y, m.player.position.x, m.player.position.y)
    m.repathTimer = 0.3
  end if
  m.repathTimer -= dt

  if m.search <> invalid and m.search.step(2)
    if m.search.status <> BGE.NavPathStatus.failed
      m.waypoints = m.search.path
      m.nextWaypoint = 1
    end if
    m.search = invalid
  end if
end sub
```

`step(budgetMs)` returns true once the search has finished. Then `status` is
`found`, `partial` or `failed`, and `path` holds the waypoints. `cancel()`
stops a search you no longer need. Several searches can run at once.

Re-path a few times a second, not every frame. And when the agent can see its
target, skip the path and steer straight at it:

```brighterscript
if m.nav.hasLineOfSight(m.position.x, m.position.y, target.x, target.y)
  ' steer directly
end if
```

## When the world changes

When a solid is added or removed (a door opens), rebuild just that area:

```brighterscript
m.solidWorld.removeSolid(m.doorSolidId)
m.nav.rebuildArea(door.x, door.y, door.w, door.h)
```

Searches already running keep using the grid as it is, so restart them.

You can also block cells by hand, on top of the solids: a hazard agents
shouldn't walk through, or cells read from a map layout image.
`rebuild()` and `rebuildArea()` keep these:

```brighterscript
m.nav.setCellBlocked(m.nav.colAt(lava.x), m.nav.rowAt(lava.y), true)
```

## 3D ground planes

A `NavGrid` works in its `SolidWorld`'s 2D coordinates. For a top-down game
those are world x/y. For a 3D game on the x/z ground plane, add solids with
world z as the `SolidWorld`'s y, and read each waypoint's `y` as z:

```brighterscript
m.solidWorld.addSolid(pillar.x - 2, pillar.z - 2, 4, 4)
path = m.nav.findPath(m.position.x, m.position.z, target.x, target.z)
for each point in path
  waypoint = BGE.Math.create(point.x, 0, point.y)
end for
```

## Sizing the grid

The grid costs one byte per cell, so even a 512 × 512 m map at 1 m cells is
256 KB. Search cost is what grows: a search expands roughly the cells between
start and goal, and an unreachable goal expands every reachable cell up to
`maxExpandedCells`. On big maps, use cells as coarse as your narrowest
gaps allow, cap `maxExpandedCells`, and spread searches over frames.
