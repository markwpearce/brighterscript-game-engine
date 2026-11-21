# Voxel terrain PR 3: shear pitch camera, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Camera3d.pitchMode = "shear"`: the camera projects as a level camera whose image is moved
down by `focal * tan(pitchUp)`, so verticals stay vertical and objects follow a voxel terrain's
horizon-shift exactly.

**Architecture:** Two camera helpers carry the mode: `getViewForward()` (level forward under shear,
else `orientation`) and `getPitchShiftY()` (0 under rotate). The view matrix, level up/right
vectors, frustum, `viewDepth`, fade depth and the two central projections switch to them, which
covers most of the engine. Sites that duplicate the projection inline get the shift individually
(audit: QuadColumnDrawer projection centre, ImpostorFit basis, SceneObjectModel clip path,
particles, plane rows/rays, skybox, WallsView, voxel terrain). `rotate` keeps every existing
code path, so the default can't change.

**Tech Stack:** BrighterScript, Rooibos v6; device checks on 192.168.41.102.

## Global Constraints

- `rotate` (default) output identical to today: shear-only branches, no arithmetic changes on the
  rotate path.
- Pitch clamped to ±60° under shear.
- A pitch or pitchMode change under shear bumps `projectionVersion`.
- Sign: `getPitchShiftY() = focal * tan(pitchUp)`, pitchUp = atan2(o.y, |o.xz|); looking up moves
  the image down (positive y).

### Task 1: camera core
`Camera3d.bs`: `CameraPitchMode` enum, `pitchMode`, `getViewForward()`, `getPitchShiftY()`,
`getPrincipalY()`; view matrix and level vectors from the view forward; projections add the shift;
shear frustum normals/rays built from the four edge directions (inside reference: the screen
centre's ray); `viewDepth`, fade, `isAnyInView` far test and convergence use the view forward;
projection change test includes the shift.
Tests (`Camera3dShearPitch.spec.bs`): shear at pitch 0 equals rotate (projection, rays, normals);
pitched shear projects to the level camera's point plus the shift; verticals project to one x;
points just inside/outside the top and bottom edges agree between `isAnyInView` and projection;
pitch change bumps `projectionVersion`; clamp at 60°.

### Task 2: inline projections
QuadColumnDrawer centre (`Renderer.prepareColumnProjection`), `ImpostorFit.basisFromView`,
SceneObjectModel clip path / `projectCameraPoint`, SceneObjectParticle size, fog silhouette depth.
Tests: a model and a column-drawn quad under shear land where `worldPointToCanvasPoint` says.

### Task 3: plane and skybox
SceneObjectPlane rows/rays/roll centre and SceneObjectSkybox placement under shear.
Tests: the plane's horizon row and a ground point's row match the camera's projection; the skybox
horizon row moves by the shift.

### Task 4: walls
WallsView principal row (`hh`) and forward under shear. Tests: a wall's top and foot rows match
`worldPointToCanvasPoint` under shear.

### Task 5: voxel terrain under shear, demo, device comparison, docs
Terrain uses pitch 0 with horizon = centre + shift under a shear camera. rendererTest demo
`cameraPitch=rotate|shear`; screenshots of horizonShift / exact / shear at 0, 15, 30 degrees;
results section in the design spec; docs (`docs/voxel-terrain.md`, camera docs, rules).
