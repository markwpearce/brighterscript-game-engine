# Making a culled SceneObject recoverable

Design for [#48](https://github.com/markwpearce/brighterscript-game-engine/issues/48), with the camera half of the scope agreed during brainstorming.

## Problem

`SceneObject.isPotentiallyOnScreen()` short-circuits on `framesSinceDrawn`:

```brightscript
if m.framesSinceDrawn = 0 or m.isFirstFrameSinceEnabled
  return true
end if
if not m.objMovedInRelationToCamera(cameraObj)
  return false
end if
```

Once an object fails to draw a single frame, it is not reconsidered until the object or the camera moves. For a stationary object in front of a stationary camera, one bad frame is permanent.

`framesSinceDrawn` is the wrong signal because it cannot distinguish the three reasons `didDraw` ends up false, only one of which justifies latching:

| Reason | Latch sound? |
| --- | --- |
| `isPotentiallyOnScreen()` returned false — the frustum rejected it | **Yes.** Nothing moved, so re-running the check gives the same answer. This is the optimisation worth keeping. |
| `findCanvasPosition()` returned false | No. Geometry- and resource-dependent; may succeed on retry. |
| `performDraw()` returned false | No. Same. |

The bug is confined to that one gate. Both inner failure paths already self-heal and are merely unreachable:

- `findCanvasPosition()` failing sets `hasValidCanvasPosition = false`, and `SceneObject.bs:250` retries on `not m.hasValidCanvasPosition`.
- `performDraw()` failing leaves `hasValidCanvasPosition` true, so `SceneObject.bs:254` retries it next frame.

`framesSinceDrawn` is read nowhere else — it is incremented, reset, and tested in this gate, and nothing more.

### The same trap, second instance

`Camera.movedLastFrame()` dirty-checks only `position` and `orientation` (`Camera.bs:52`). So a change to the camera's projection that is not movement also leaves a legitimately-culled stationary object culled. Of the candidates:

- **`fieldOfViewDegrees`** (`Camera3d.bs:100`) — affected, and it is a bare public field, so no setter can intercept a write to it.
- **`frameSize`** (`Camera.bs:12`) — affected.
- **The camera's own draw mode** (`Camera3d.toggleWireFrame()`, which flips `currentDrawMode`) — already covered. It flows through `getActualDrawMode()` into the existing `drawModeChanged()` bypass at `SceneObject.bs:249`.

## Approach

Two independent changes, both under `src/source/engine/renderer/`.

### 1. Latch on cull, not on "didn't draw"

In `SceneObject`, delete `framesSinceDrawn` and `resetFrameSinceDrawn()` and replace them with `protected lastFrameWasCulled = false`.

`draw()` captures whether execution entered the draw path at all:

```brightscript
enteredDrawPath = modeChanged or projectionChanged or m.isPotentiallyOnScreen(rendererObj.camera)
if enteredDrawPath
  ' unchanged: findCanvasPosition / performDraw / afterDraw
end if
m.lastFrameWasCulled = not enteredDrawPath
```

`isPotentiallyOnScreen()`'s first test becomes:

```brightscript
if not m.lastFrameWasCulled or m.isFirstFrameSinceEnabled
  return true
end if
```

The initial state is behaviourally identical to today: `framesSinceDrawn = 0` and `lastFrameWasCulled = false` both mean "reconsider me", so nothing changes on the first frame or while an object draws normally.

The optimisation is preserved exactly. An object the frustum genuinely rejected still costs one boolean test per frame until something moves. What changes is that a `findCanvasPosition()` or `performDraw()` failure no longer sets the latch, so the two existing inner retry paths become reachable and the object recovers on the next frame.

`SceneObjectPlane` overrides `isPotentiallyOnScreen()` to return true unconditionally, so it is never latched. No change needed there, and its own `hasAccurateTempBitmap` caching is untouched.

### 2. A camera projection change invalidates the latch

`Camera` gains:

- `projectionVersion as integer`, bumped when the projection changes.
- `bumpProjectionVersion()`, public, so a future setter can declare a change explicitly instead of relying on the dirty check.
- `protected sub checkProjectionChange()`, called from `checkMovement()`, comparing `frameSize` against a stored copy and bumping the version on a difference.

`Camera3d` overrides `checkProjectionChange()` to call `super.` and additionally check `fieldOfViewDegrees`.

`Renderer.setupCameraForFrame()` already calls `camera.checkMovement()` once per frame before `drawScene()` (`Renderer.bs:155`), so the dirty check needs no new plumbing.

Dirty-checking rather than intercepting, because `fieldOfViewDegrees` is a public field that consumers write directly — a setter would be silently bypassed. This is the same philosophy `MotionChecker` already applies to position and orientation.

`SceneObject` keeps `lastProjectionVersion as integer = -1` and a `protected function projectionChanged()`, mirroring the existing `geometryChanged()`/`lastGeometryVersion` pair. It feeds **only** `draw()`:

- the latch bypass in `enteredDrawPath` above, and
- the canvas-position recompute condition at `SceneObject.bs:250`.

It deliberately does **not** feed `update()`'s `forceRecompute`, because FOV and frame size change where a point lands on the canvas, not where the object sits in the world.

`lastProjectionVersion` is assigned at the end of `draw()` alongside `lastGeometryVersion` and `lastDrawMode`.

## Testing

Rooibos specs following `SceneObjectImage.spec.bs`'s black-box pattern: `setupCameraForFrame()` then `drawScene()`, asserting on `getDrawCallsLastFrame()`, with its `drawFrames(count)` helper for settling a stationary object over several frames. A spec must call `setupCameraForFrame()` before `drawScene()`, or a `Camera3d`'s frustum normals are uninitialised and `isInView` fails for reasons unrelated to the test.

**Camera invalidation** — needs no test doubles. Place an object outside a narrow FOV, draw several frames so it settles into the culled-and-latched state, widen `fieldOfViewDegrees`, draw again, assert it draws. This test fails against today's code.

**Failure recovery** — a transient draw failure cannot be induced through the public API, so this needs a minimal test-only `SceneObjectImage` subclass overriding `protected performDraw()` to return false on demand. Draw frames with it failing, stop failing, assert the next frame draws. This test fails against today's code.

**`Camera.spec.bs`** — assert `projectionVersion` bumps after an `fieldOfViewDegrees` write followed by `checkMovement()`, and holds steady across a `checkMovement()` with no projection change.

### One mechanical question for the plan to resolve

Where the failure-recovery helper subclass lives. A second class in the same `.spec.bs` file is untested water given the documented Rooibos metadata-corruption gotcha — that gotcha is specifically about two `@suite` classes, so a plain unannotated helper is probably fine, but not certainly. Try the same-file helper first; if Rooibos misbehaves, fall back to a `*.spec.bs` file containing only the helper and no `@suite`, which keeps it out of production builds for free since `bsconfig.build.json` excludes by that glob.

## Out of scope

- A periodic retry backstop (re-examining a latched object every N frames regardless of cause). Rejected: recovery would be delayed by an arbitrary N, correctly-culled objects would pay for the re-check, and a genuinely broken object would retry forever.
- A three-state `drew`/`culled`/`failed` outcome enum. The third state buys nothing functionally today; the boolean can be widened later if a debug overlay genuinely wants to surface repeated `performDraw` failure.
- `update()` does not include `cameraObj.movedLastFrame()` in `forceRecompute`, which may matter for `directScaled`'s camera-facing quad. Possibly a latent issue, unrelated to this one — worth filing separately rather than folding in here.

## Verification

- `npm run validate` — type-checks with and without tests.
- `npm run lint`.
- `npm run test:ci` — the three specs above must pass, and must be confirmed to fail before the fix lands.
