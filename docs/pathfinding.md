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

`examples/navigation` shows it working: four agents chase a flag through a
maze with doors, re-planning when the doors open or close.

## Building the grid

Build the grid once the world's solids are in, at scene load:

```brighterscript
m.nav = new BGE.NavGrid(m.solidWorld, {cellSize: 16, agentRadius: 10})
```

- `agentRadius` grows every solid by that much before it blocks cells, so a
  path that keeps the agent's centre in open cells keeps its body clear of
  walls. Use the radius of the mover's feet box (or collider).
- `cellSize` trades accuracy for cost. A gap is only found if a whole open
  cell fits through it once the solids have grown. To be sure of that, a gap
  must be at least `2 * agentRadius + 2 * cellSize` wide, or
  `2 * agentRadius + cellSize` when the walls line up with the cell edges. So
  a 40-unit doorway with walls on cell edges takes `agentRadius: 10` with
  10-unit cells, but not `agentRadius: 13` with 20-unit cells.
- By default the grid covers every solid in the world, plus a margin of
  `agentRadius` and one cell so agents can walk round the outside. Points
  outside the grid count as blocked, so if agents walk on open ground beyond
  the outermost solids, pass `minX`, `minY`, `width` and `height` to cover it.

Building tests each solid once and costs one byte per cell. For a big map,
build it in a `LoadTask` (see [Loading Assets](/loading-assets)) so the
loading screen keeps drawing:

```brighterscript
override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
  loader.addStep(function(scene as object) as dynamic
    scene.nav = new BGE.NavGrid(scene.solidWorld, {cellSize: 16, agentRadius: 10})
    return true
  end function, m)
end sub
```

## Following a target

`BGE.NavFollower` does the usual job for you: it steers straight at a target
it can see, and otherwise follows a path round the walls. Make one per agent,
and call `steer()` each frame:

```brighterscript
m.follower = new BGE.NavFollower(m.nav, {plane: BGE.SeparationPlane.xy})

override sub onUpdate(dt as float)
  way = m.follower.steer(m.position, m.player.position, dt)
  if invalid <> way
    ' A wall in the way: `way` is a unit vector along the path
    m.moveBy(way.x * m.speed * dt, way.y * m.speed * dt)
  else if m.follower.canSeeTarget
    ' In sight: up to you. Chase, circle, attack...
    m.moveToward(m.player.position, dt)
  end if
end sub
```

`steer()` returns invalid when the agent can see its target, so the game
decides what to do then. It also returns invalid out of sight when there's
no path left to follow (e.g. the target is walled off and the agent got as
close as it can), with `canSeeTarget` false.

`plane` says which position axes are the grid's x and y: `xz` (the default)
for a 3D game's ground, `xy` for a 2D one. Directions come back on the same
plane. The rest of the options are timings and distances:

```brighterscript
m.follower = new BGE.NavFollower(m.nav, {
  sightInterval: 0.25,   ' seconds between line-of-sight checks
  repathInterval: 0.5,   ' seconds between searches while out of sight
  repathDistance: 20,    ' search early when the target moves this far (default off)
  arriveRadius: 6,       ' a waypoint is reached this close (default half a cell)
  searchBudgetMs: 2,     ' spread searches over frames (default 0: all at once)
  pathWhileVisible: true ' keep a path ready while in sight (default false)
})
```

- `canSee(from, target, dt)` gives the same timed sight check without
  steering, e.g. to wake a guard. It shares `steer()`'s timer, so call one or
  the other each frame.
- `forceRepath()` searches and checks sight again next frame, e.g. after a
  door opened. `repathAfter(seconds)` delays the next search, to spread
  several agents' first searches over frames. `clearPath()` drops the path.
- `path`, `pathIndex`, `lastSearch` and `lastSearchFrames` are there to draw
  or debug what it's doing.
- Sight is the grid's `hasLineOfSight()`. For something else (a raycast, a
  view cone), subclass it and override `checkSight(from, target)`.

`examples/navigation` (`Agent.bs`, on the xy plane) and `examples/thirdPerson`
(`Entities/Enemy.bs`, on the ground) both use it.

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
  cell's centre. The same goes for a point just outside the grid. A start
  further out than `snapRings` fails; a goal that far out is treated as walled
  off (below).
- **Goal walled off**: by default you get a partial path to the open cell
  nearest the goal, so an agent still heads the right way. If the agent is
  already there, the path is just its start. Pass
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

Solids are grown by `agentRadius`, so an agent against a wall often stands in
a blocked cell. An end of the line in a blocked cell is looked at from the
open cell nearest it, up to 2 cells away. Pass a fifth argument to change
that (`0` counts any blocked end as blocked). Points outside the grid aren't
moved.

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
  waypoint = BGE.Math.VectorOps.create(point.x, 0, point.y)
end for
```

## Sizing the grid

The grid costs one byte per cell, so even a 512 × 512 m map at 1 m cells is
256 KB. Searches need more: each one running at once uses three arrays with an
entry per cell, which the grid keeps when it finishes, so the next search
reuses them instead of allocating its own. It keeps up to `maxPooledSearches`
sets (default 4); lower that on a big map, or call `releaseSearchMemory()`
after a burst of searches. Search cost grows too: a search expands roughly the cells between
start and goal, and an unreachable goal expands every reachable cell up to
`maxExpandedCells`. On big maps, use cells as coarse as your narrowest
gaps allow, cap `maxExpandedCells`, and spread searches over frames.
