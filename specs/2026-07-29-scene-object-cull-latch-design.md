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

In `SceneObject`, delete `framesSinceDrawn` and `resetFrameSinceDrawn()` and replace them with two booleans: `protected lastFrameWasCulled = false` and `protected lastFrameDidDraw = false`.

Two flags rather than one, because there are **three** outcomes a frame can have and the old single counter collapsed them into two. An object can have drawn, been culled by the frustum, or entered the draw path and failed. Only the middle one may latch; the third must retry; and — this is the part that needs a flag of its own — the third is also the state the frustum check has to be *reachable* from.

`draw()` records both:

```brightscript
didDraw = false
enteredDrawPath = modeChanged or projectionChanged or m.isPotentiallyOnScreen(rendererObj.camera)
if enteredDrawPath
  ' unchanged: findCanvasPosition / performDraw / afterDraw, setting didDraw
end if
m.lastFrameWasCulled = not enteredDrawPath
m.lastFrameDidDraw = didDraw
```

and `isPotentiallyOnScreen()` becomes:

```brightscript
if m.isFirstFrameSinceEnabled
  return true
end if
if not m.objMovedInRelationToCamera(cameraObj) and not m.geometryChanged()
  if m.lastFrameWasCulled
    return false
  end if
  if m.lastFrameDidDraw
    return true
  end if
end if
' Either something changed, or last frame neither drew nor culled - it entered the draw
' path and failed. Run the real frustum check: it is what puts the object into the culled
' state in the first place, and what lets a failed object discover it is still on screen.
' (frustum loop unchanged, its result returned)
```

**Why the frustum check must be the base case.** The obvious formulation — short-circuit on `not m.lastFrameWasCulled`, set `lastFrameWasCulled = not enteredDrawPath` — is circular and silently disables culling altogether. `lastFrameWasCulled` would then only ever be set by `isPotentiallyOnScreen()` returning false, which it could only do if the flag were already set; starting at `false`, it can never become `true`, and the frustum loop is dead code. This was in an earlier draft of this document and was caught in review of the first implementation.

The trap is that the old code's cull state was **not** bootstrapped by the frustum check at all — `framesSinceDrawn++` on any non-draw was what put an object into it, and the frustum check merely re-evaluated an already-latched object once something moved. Removing that increment therefore removed the only entry into the culled state. Anything replacing it has to supply a new one.

Behaviour, traced:

| Case | Frames |
| --- | --- |
| Static object on screen | Frame 1 draws (first-frame-since-enabled). Frame 2 onward: nothing moved, `lastFrameDidDraw` → one boolean, draws. Unchanged from today. |
| Static object off screen | Frame 1 enters and fails. Frame 2: neither flag set, so the frustum check runs, rejects it, and latches. Frame 3 onward: one boolean. One extra frustum check versus today; culling preserved. |
| Transient failure, on screen | Frame 1 fails. Frame 2: frustum check runs, says in-view, the draw is retried and recovers. **This is the bug fixed.** |
| Recovery after a genuine cull | Unchanged: whatever moves lifts the latch, as today. |

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

**Amended during planning.** A version bump alone is not sufficient: on a projection change the
camera's own derived state is stale too, so `isInView` would answer from the old projection and
the un-latched object would simply be culled again. `Camera3d.frustumNormals` is rebuilt only when
the *orientation* changes (`Camera3d.bs:127`); `frustumRays` and `frustrumConvergence` only on
movement; and `Camera2d`'s `top`/`bottom`/`left`/`right` inside `computeWorldToCameraMatrix()`,
which the renderer calls only when the camera moved. So `checkProjectionChange()` also invokes an
`onProjectionChange()` hook — rebuilding the projection matrix on the base class, and the full
frustum on `Camera3d` via an extracted `recomputeFrustum(recomputeNormals)`.

## Testing

Rooibos specs following `SceneObjectImage.spec.bs`'s black-box pattern, with its
`drawFrames(count)` helper for settling a stationary object over several frames. A spec must call
`setupCameraForFrame()` before `drawScene()`, or a `Camera3d`'s frustum normals are uninitialised
and `isInView` fails for reasons unrelated to the test.

Assertions are on a test double's *draw-attempt count*, not on the renderer's draw-call count.
`FailingSceneObjectImage` (`SceneObjectTestDoubles.spec.bs`) overrides `performDraw()` to fake a
failure on demand and counts its own invocations. Attempts are what distinguish the three states
this design turns on — drew, culled, attempted-and-failed — where a draw-call count distinguishes
only two.

**Failure recovery** — with the double failing, an on-screen object must attempt the draw every
frame (3 attempts in 3 frames). If a failure latched, it would attempt once.

**Cull latching** — the other half of the contract. An object outside the frustum must attempt
once, latch, and stop attempting (1 attempt in 3 frames). Without this assertion the optimisation
can be removed entirely while every recovery test still passes — which is exactly what happened in
the first implementation of this design.

**Projection-change recovery** — a culled, latched object must be reconsidered after
`Camera.bumpProjectionVersion()`, and must then re-latch rather than re-enter the draw path every
frame.

**`Camera.spec.bs` / `Camera3d.spec.bs`** — `projectionVersion` bumps on a frame-size or
field-of-view change and holds steady otherwise; a field-of-view change rebuilds `frustumRays`.

Nothing here keys off the angular relationship between `fieldOfViewDegrees` and `isInView`, and
that is deliberate. `CameraFrustumNormals.setNormals` uses each frustum plane's boundary edge
direction as its normal, which is a correct angular test only at the default 90°; measurement
showed the relationship is in fact inverted, a wider field of view accepting *less*. That is issue
#70 — pre-existing and out of scope here. A test written against today's behaviour would break the
moment #70 is fixed.

### Where the test doubles live

In `SceneObjectTestDoubles.spec.bs`, which contains no `@suite`. The alternative of a second class
inside an existing spec file was skipped: it costs nothing to avoid, and the documented Rooibos
failure mode is a silent metadata corruption that surfaces as a crash in an unrelated suite.

Two brighterscript `1.0.0-alpha.52` bugs shape that file, both commented in it:

- A subclass of a `BGE` class declared in another namespace crashes at transpile — the synthesized
  implicit constructor carries the parent's parameter types over unqualified, so they don't
  resolve. Worked around with an explicit fully-qualified constructor. Filed upstream as
  [rokucommunity/brighterscript#1767](https://github.com/rokucommunity/brighterscript/issues/1767).
- `super.<protectedMethod>()` across namespaces is rejected as a member-access violation even from
  a genuine subclass. Worked around by not delegating to `super` at all — the double fakes its
  return value outright.

## Out of scope

- A periodic retry backstop (re-examining a latched object every N frames regardless of cause). Rejected: recovery would be delayed by an arbitrary N, correctly-culled objects would pay for the re-check, and a genuinely broken object would retry forever.
- A three-state `drew`/`culled`/`failed` outcome enum. The third state buys nothing functionally today; the boolean can be widened later if a debug overlay genuinely wants to surface repeated `performDraw` failure.
- `update()` does not include `cameraObj.movedLastFrame()` in `forceRecompute`, which may matter for `directScaled`'s camera-facing quad. Possibly a latent issue, unrelated to this one — worth filing separately rather than folding in here.
- Fixing `CameraFrustumNormals.setNormals`, which uses frustum edge directions as plane normals —
  wrong at any field of view but the default 90°, and inverted. Found while writing these tests,
  filed as #70.
- Fixing the `drawable` field redeclaration on every `SceneObject` subclass, which transpiles to
  `m.drawable = invalid` after the base constructor sets it. Masked on every engine path by
  `Drawable.addSceneObjectToRenderer()`, but it bites anything constructing a scene object
  directly — including the test double here. Filed as #69.

## Verification

- `npm run validate` — type-checks with and without tests.
- `npm run lint`.
- `npm run test:ci` — the three specs above must pass, and must be confirmed to fail before the fix lands.
