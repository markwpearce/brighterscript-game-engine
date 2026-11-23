# Changelog

All notable changes to this project are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. This project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.9.0] - 2026-11-22

### Changed (breaking)

**Scene lifecycle**
- `GameScene.onDestroy()` now runs on the scene you leave (and on `resetScene()`), after `onChangeScene(newScene)`. Scenes are reused, so `onLoad()`/`onCreate()` run again on re-entry ([#327](https://github.com/markwpearce/brighterscript-game-engine/issues/327)). Cleanup that you worked around by doing it in `onChangeScene()` can move to `onDestroy()`; cleanup you wrote in `onDestroy()` that never ran will now run.
- Changing to the scene you're already in is a full leave and re-enter, and the scene's own drawables are removed so `onCreate()` can re-add them. `resetScene()` (and `BGE.PauseMenu` Restart) now clears a scene's drawables ([#616](https://github.com/markwpearce/brighterscript-game-engine/pull/616)). Set `persistDrawablesAcrossSceneChange` to keep them.
- `changeScene()` called from `onCreate()` now applies at the end of the next frame (it used to be dropped) ([#319](https://github.com/markwpearce/brighterscript-game-engine/pull/319)).
- A scene that defines its own `addUi()`/`removeUi()` now clashes with `GameScene`'s new methods: rename yours or switch to the engine ones ([#593](https://github.com/markwpearce/brighterscript-game-engine/pull/593)).
- Changing scene resumes the game and forgets open modals, unless `game.keepPauseOnSceneChange` is set ([#594](https://github.com/markwpearce/brighterscript-game-engine/pull/594)).

**Rendering**
- Removed the corner-pin / triangle-warp path: `useImpostorPin`, the `modelImpostorPin*` quality settings, `ImpostorFit.fitPinnedCorners()`, `Renderer.drawPinnedCorners()`, `drawBitmapTriangle()`, `TriangleCache`, per-face rasters, `DrawableModel.maxStaleFrames`/`maxFaceDriftDistance` and the `drawFlatQuadsAsColumns`/`drawModelFacesAsColumns` switches. Oriented images, sprites, text, rects and model faces now always draw as texture columns. Delete any use of these ([#458](https://github.com/markwpearce/brighterscript-game-engine/pull/458), [#454](https://github.com/markwpearce/brighterscript-game-engine/issues/454)).
- Grid walls are now level walls ([#473](https://github.com/markwpearce/brighterscript-game-engine/pull/473), [#472](https://github.com/markwpearce/brighterscript-game-engine/issues/472)): `DrawableGridWalls` is a `DrawableWalls` built from `map.toSegments()`, and the raycaster classes (`SceneObjectGridWalls`, `GridWallsView`, `WallsHidingView`) are gone. Migrate:

  | Old | New |
  |---|---|
  | `gridWallStripWidth` | `wallStripWidth` |
  | `gridWallLightInterval` | removed |
  | `gridWalls` profiler stage | `walls` |
  | `Renderer.getGridWalls()` | `Renderer.getWalls()` |
  | `Renderer.isBehindGridWalls()` | `Renderer.isBehindWalls()` |
  | `BGE.GridWallsSpan` | `BGE.WallsSpan` |
  | `WallsView.segmentsInView` / `segmentsVisited` | `partsInView` / `partsVisited` |
  | `DrawableGridWalls.invalidateGeometry()` after a map change | `setMap()` rebuilds |

- `RenderQualitySettings.modelImpostorMaxZoom` is now `modelImpostorMaxSizeChange` and limits shrinking as well as growth (3, 2, 1.4, 1.25, 1.15 from Basic to Ultra) ([#486](https://github.com/markwpearce/brighterscript-game-engine/pull/486)).
- The ground plane now reaches the highest quality level's distance at every level and its far edge is the far-clip depth, so objects no longer float past the ground edge. The plane's top-down bitmap is capped (`PLANE_PRE_PERSPECTIVE_MAX_PIXELS`), so the ground is slightly softer on FHD hardware ([#307](https://github.com/markwpearce/brighterscript-game-engine/issues/307)).
- `DrawablePlane` now uses `Drawable.scale` as texels-per-world-unit (`scale.x` along x, `scale.y` along z). `(1, 1)` is unchanged, but a plane with another scale set will now be stretched ([#395](https://github.com/markwpearce/brighterscript-game-engine/pull/395)).
- Fixed the inverted back-face test for 3D models: outward-wound OBJ/STL faces used to draw only their back faces, so models you flipped to compensate will now look inside out. Oriented models and polygons also take their depth from their own centre ([#108](https://github.com/markwpearce/brighterscript-game-engine/issues/108), [#342](https://github.com/markwpearce/brighterscript-game-engine/issues/342)).
- `isShaded` billboards and sprites (`axisAligned`, `directScaled`...) are now lit by `Light`s as camera-facing cut-outs; set `Drawable.lightWrap` to keep back-lit figures from going black ([#442](https://github.com/markwpearce/brighterscript-game-engine/pull/442)).
- Objects now fade out over the last 15% of the draw distance, and a draw distance change eases over 0.75s. Set `Camera3d.drawDistanceFadeFraction = 0` to turn the fade off ([#125](https://github.com/markwpearce/brighterscript-game-engine/issues/125)).
- Frustum culling on a `Camera3d` is tighter: objects that report their real extent are culled as soon as they leave the side of the screen ([#508](https://github.com/markwpearce/brighterscript-game-engine/issues/508)).
- `DrawablePlane.lightPoolOpacity` now defaults to 0.4, and a static plane bakes its light pools into a lit copy of its texture (`bakesLightPools = false` opts out a decal with transparent areas) ([#528](https://github.com/markwpearce/brighterscript-game-engine/issues/528)).
- A render target is no longer `Finish()`ed when it's an `roScreen` (on a 720p device the game canvas is the screen, and the UI flickered).
- On HD devices the scratch pool starts with two 512x512 bitmaps and the draw distance cap is 1000 (was 30) ([#151](https://github.com/markwpearce/brighterscript-game-engine/issues/151)).

**Input, UI and misc**
- Remote button 11 is now `backspace` (it was mislabelled `audioguide`) and 15 is `enter`; `Game` no longer drops button 11 ([#286](https://github.com/markwpearce/brighterscript-game-engine/issues/286)).
- `BGE.Colors.Pink` is real pink (`FFC0CB`); it was a different colour. Debug draws that used it now use `Magenta` ([#331](https://github.com/markwpearce/brighterscript-game-engine/issues/331)).
- `BGE.UI.Theme.hoveredBackgroundColor` defaults to `BGE.Colors.Teal` (was silver) so focused buttons are readable ([#328](https://github.com/markwpearce/brighterscript-game-engine/issues/328)).
- `BGE.UI.Label` with `customPosition` now anchors on `customX` for `horizAlign` `"center"`/`"right"`, like `Renderer.drawText()`. Remove any `GetOneLineWidth` offsets you added to compensate ([#628](https://github.com/markwpearce/brighterscript-game-engine/issues/628)).
- `MessagePanel` is now a `BGE.UI.MenuList`: it focuses its first button on show, takes colours from the theme and its parent is optional ([#593](https://github.com/markwpearce/brighterscript-game-engine/pull/593)).
- `BGE.registryRead()` no longer writes its default as a side effect ([#596](https://github.com/markwpearce/brighterscript-game-engine/pull/596)).
- `Game.loadBitmap()`'s first argument is now `BGE.LoadBitmapSource` (`string or roBitmap or BGE.EmptyBitmapOptions`) ([#370](https://github.com/markwpearce/brighterscript-game-engine/issues/370)).
- `Game.load3dModel()` returns `false` for an unparseable `.stl` instead of storing `invalid` and returning `true`, and the synchronous `game.load*` functions refuse URLs with an error pointing at `AssetLoader` ([#319](https://github.com/markwpearce/brighterscript-game-engine/pull/319), [#322](https://github.com/markwpearce/brighterscript-game-engine/pull/322)).
- `DialogueRunner.choicesFollow()` is true only when one of the node's choices can be taken ([#294](https://github.com/markwpearce/brighterscript-game-engine/issues/294)). In `BGE.Story`, a page's effects run when its last line is read (before choices).
- `game.postGameEvent()` and quality changes skip the loading scene and the entities it holds ([#318](https://github.com/markwpearce/brighterscript-game-engine/issues/318)).

### Changed

**Rendering**
- Draw-quality knobs and the `Renderer` stage list gained many new settings (`quadColumnsPerTexel`, `quadMinPixelsPerColumn`, `quadMaxAffineErrorPixels`, `wallStripWidth`, `wallLodDistanceFraction`, `fogSilhouetteBand`, `voxelColumns`, `animationLodDistanceScale`, and the impostor limits). See the [Render Quality guide](https://markwpearce.github.io/brighterscript-game-engine/render-quality).
- Model impostors (`DrawableModel.useImpostor`, on by default) keep drawing a model's last full rendering while the camera moves, then fall back to vertical strips turned to follow the camera, then a full redraw. Near or very deep models skip the single blit, and strips back off after a failed fit. `DrawableModel.applyImpostorOptions()` takes short option names ([#350](https://github.com/markwpearce/brighterscript-game-engine/pull/350), [#557](https://github.com/markwpearce/brighterscript-game-engine/pull/557), [#599](https://github.com/markwpearce/brighterscript-game-engine/pull/599), [#583](https://github.com/markwpearce/brighterscript-game-engine/pull/583), [#584](https://github.com/markwpearce/brighterscript-game-engine/pull/584), [#604](https://github.com/markwpearce/brighterscript-game-engine/pull/604), [#360](https://github.com/markwpearce/brighterscript-game-engine/issues/360), [#359](https://github.com/markwpearce/brighterscript-game-engine/issues/359), [#556](https://github.com/markwpearce/brighterscript-game-engine/issues/556)).
- Moving models are much faster (shared vertices, inline projection), and faces cut at the near plane instead of being dropped ([#486](https://github.com/markwpearce/brighterscript-game-engine/pull/486), [#583](https://github.com/markwpearce/brighterscript-game-engine/pull/583)).
- Billboards, images and models repeat last frame's blit when nothing that shapes it changed, and camera-locked unshaded billboards keep their replay while the camera moves ([#511](https://github.com/markwpearce/brighterscript-game-engine/pull/511), [#515](https://github.com/markwpearce/brighterscript-game-engine/issues/515), [#439](https://github.com/markwpearce/brighterscript-game-engine/issues/439)).
- Still-scene and per-frame costs are down: static entities skip their own collision checks, entity/scene-object update loops are inlined, bounding spheres speed up fade and frustum checks, and off-screen models are skipped before projecting ([#494](https://github.com/markwpearce/brighterscript-game-engine/issues/494), [#499](https://github.com/markwpearce/brighterscript-game-engine/issues/499), [#495](https://github.com/markwpearce/brighterscript-game-engine/issues/495), [#505](https://github.com/markwpearce/brighterscript-game-engine/issues/505), [#654](https://github.com/markwpearce/brighterscript-game-engine/issues/654)).
- Small triangles are always filled with 1px `DrawRect` bands, which are gap-free and no slower than the two-call fill up to 16px on the shorter side. New `Renderer.drawTriangleAsSpansTo()`, `drawTriangleExactTo()` and `getLossyTriangleFillCount()`.
- `RenderQualitySettings.triangleQuickDrawThreshold` is removed - the band budget is now a measured constant (`BGE.TRIANGLE_SPAN_MAX_BANDS`), and `triangleQuickDrawStep` is the band size while moving. `getTriangleQuickDrawParams()` returns `{skipSize, maxBands, step}`.
- Triangle and polygon fills use `DrawRect` spans when cheaper than exact triangles (up to 3x faster, and no seams in circles) ([#539](https://github.com/markwpearce/brighterscript-game-engine/issues/539)).
- Adaptive quality: repeated hitches step quality down (`hitchFrameMultiple`/`hitchesToStepDown`/`hitchWindowSeconds`), it drops before the first moving frame when the camera starts moving (capped by `AdaptiveQualityOptions.cameraMoveMaxStepDown`, default 2), a still camera steps up by the measured headroom, and probe backoff is shorter ([#352](https://github.com/markwpearce/brighterscript-game-engine/issues/352), [#519](https://github.com/markwpearce/brighterscript-game-engine/issues/519), [#557](https://github.com/markwpearce/brighterscript-game-engine/pull/557), [#606](https://github.com/markwpearce/brighterscript-game-engine/pull/606)).
- Textures are decoded through `roTextureManager` when loaded via `AssetLoader` (see **Loading** below), and big images in examples are now WebP ([#323](https://github.com/markwpearce/brighterscript-game-engine/pull/323), [#483](https://github.com/markwpearce/brighterscript-game-engine/issues/483)).
- Static BSP: a static model that straddles a quad's plane is placed by its bounds, fixing a far fence drawing over a near house; only a note per object type is logged when a type can't go in the static BSP ([#600](https://github.com/markwpearce/brighterscript-game-engine/pull/600), [#518](https://github.com/markwpearce/brighterscript-game-engine/issues/518)).
- Occluders now work with near models (panels cut at the near plane) and fogged models, and an impostor model occluder shrinks its claim only by its fit error ([#602](https://github.com/markwpearce/brighterscript-game-engine/pull/602), [#359](https://github.com/markwpearce/brighterscript-game-engine/issues/359)).
- Strips of wall textures wider than a texel column draw from a mip level to stop shimmer; `DrawableWalls.mipmapped = false` turns it off ([#543](https://github.com/markwpearce/brighterscript-game-engine/issues/543)).
- `Sprite`/`DrawableOrientedSprite` `frameRate` is a `float` (a rate of 0 or less is rejected with a warning), and `playAnimation()`/`playOrientedAnimation()` take `restart = true` to restart the animation already playing ([#408](https://github.com/markwpearce/brighterscript-game-engine/pull/408), [#396](https://github.com/markwpearce/brighterscript-game-engine/issues/396)).
- `DrawableParticles` bounds are the box around the live particles and particles can be hidden by walls ([#463](https://github.com/markwpearce/brighterscript-game-engine/issues/463)).
- Sorted objects are skipped behind level walls only when a wall is nearer ([#513](https://github.com/markwpearce/brighterscript-game-engine/pull/513)).

**Input and UI**
- Each held remote button is tracked separately (it used to be one per remote), so holding Right on a gamepad keeps repeating after you tap A ([#382](https://github.com/markwpearce/brighterscript-game-engine/issues/382)).
- The popup `Select` list draws with its focused widget's own theme, and rows use `theme.backgroundImage` when set (a 2px focus outline marks the highlighted row) ([#193](https://github.com/markwpearce/brighterscript-game-engine/issues/193)).
- On device, `.9.png` files are copied to `tmp:/` under a plain `.png` name so nine-patch images load ([#551](https://github.com/markwpearce/brighterscript-game-engine/issues/551)).

**Collision and scenes**
- `BoxCollider3d.yaw` turns a box about y (the broad phase uses the axis-aligned box around it) ([#641](https://github.com/markwpearce/brighterscript-game-engine/issues/641)).
- `Camera3d.fog` backdrop never reaches above the horizon, and fog fixes the draw distance across quality levels (`Fog.followsQuality` opts back in) ([#529](https://github.com/markwpearce/brighterscript-game-engine/issues/529), [#533](https://github.com/markwpearce/brighterscript-game-engine/issues/533)).
- `game.maxDeltaTime` (0/off by default) caps dt for `onUpdate`, velocity, tweens and `getDeltaTime()` ([#578](https://github.com/markwpearce/brighterscript-game-engine/issues/578)).

### Added

**Rendering**
- Occlusion culling: mark static drawables `isOccluder` to hide what's behind them. `isOnScreen()` is backed by a `BGE.VisibilityState` enum, and `Renderer.occluderDrawPolicy` is `fastShrink` (default), `exact` or `fastExactClaim` ([#108](https://github.com/markwpearce/brighterscript-game-engine/issues/108)).
- Lighting: `BGE.DirectionalLight`, `PointLight` (optional linear `range`) and `AmbientLight`, added with `Game.addLight()`/`removeLight()`/`clearLights()` or on a `Renderer`. No lights keeps the old camera-facing shading. Ranged point lights draw soft pools on ground planes. Entities and scenes own lights via `GameEntity.addLight()`/`removeLight()`/`removeLights()`/`getLights()`, freed with them ([#189](https://github.com/markwpearce/brighterscript-game-engine/issues/189), [#377](https://github.com/markwpearce/brighterscript-game-engine/issues/377), [#575](https://github.com/markwpearce/brighterscript-game-engine/issues/575)).
- Engine fog: `Camera3d.fog` (`BGE.Fog`) with a backdrop band, `Drawable.castsFogSilhouette` (models keep blocking the sky past the draw distance as fog-coloured boxes, outlined by their own points via `fogSilhouetteBand`, `silhouetteReach`, `Fog.silhouetteOpacityLead`), and level walls drawn as fog strips past the draw distance. `Drawable.fadesWithDistance = false` and `Drawable.fadeDistanceScale` keep light emitters visible further ([#520](https://github.com/markwpearce/brighterscript-game-engine/issues/520), [#525](https://github.com/markwpearce/brighterscript-game-engine/issues/525), [#530](https://github.com/markwpearce/brighterscript-game-engine/issues/530), [#495](https://github.com/markwpearce/brighterscript-game-engine/issues/495)).
- `SceneObjectDrawMode.axisAligned`: an upright billboard that foreshortens with camera pitch, with `Drawable.axisAlignedFullHeightPitch` ([#391](https://github.com/markwpearce/brighterscript-game-engine/issues/391)).
- Level walls: `BGE.DrawableWalls` takes wall segments (own foot/top height, `BGE.createWallSegment()`) walked front to back by `BGE.WallsBsp`; `DrawableGridWalls` and `GridWallsMap.toSegments()` build mazes from them. `BGE.DrawableWall` is a freestanding wall with `tileWidth`/`tileHeight` texture tiling. Walls hide sorted objects and particles behind them, and each ray's window is trimmed to the canvas ([#445](https://github.com/markwpearce/brighterscript-game-engine/pull/445), [#467](https://github.com/markwpearce/brighterscript-game-engine/issues/467), [#468](https://github.com/markwpearce/brighterscript-game-engine/issues/468), [#472](https://github.com/markwpearce/brighterscript-game-engine/issues/472)).
- Voxel terrain: `BGE.VoxelMap`/`BGE.VoxelMaps` (`.bvox` files, baked with `tools/voxel-map.py`), `BGE.VoxelMapGenerator`, and `BGE.DrawableVoxelTerrain` with `pitchMode` `horizonShift` or `exact`, hiding sorted objects behind hills and taking fog from `Camera3d.fog`. See the [Voxel Terrain guide](https://markwpearce.github.io/brighterscript-game-engine/voxel-terrain) ([#637](https://github.com/markwpearce/brighterscript-game-engine/issues/637)).
- `Camera3d.pitchMode = "shear"` keeps the view level and moves the image by the pitch, so verticals stay vertical ([#637](https://github.com/markwpearce/brighterscript-game-engine/issues/637)).
- `camera.zoom` now works on `Camera2d` and `Camera3d`, with `camera.zoomTo(target, seconds, easing)` to ease it ([#588](https://github.com/markwpearce/brighterscript-game-engine/issues/588)).
- `Camera.sortsByGroundDistance` sorts whole objects by distance across the ground instead of depth along the view, for tilted chase cameras ([#564](https://github.com/markwpearce/brighterscript-game-engine/issues/564)).
- Textured quads draw as perspective-correct texture columns (`BGE.QuadColumnDrawer`, `Renderer.drawTexturedQuadTo()`), with tiling, mip levels for walls and near-plane clipping. Model faces draw as strips cut to their UV triangle (`BGE.TriangleColumnCuts`, `Renderer.drawTriangleColumnsTo()`) ([#448](https://github.com/markwpearce/brighterscript-game-engine/issues/448), [#449](https://github.com/markwpearce/brighterscript-game-engine/issues/449), [#450](https://github.com/markwpearce/brighterscript-game-engine/issues/450), [#451](https://github.com/markwpearce/brighterscript-game-engine/issues/451)).
- `DrawablePolygon.concave` (and `concave`/`fillRule` on the SceneGraph `Polygon`) fills a concave outline with `BGE.ScanlinePolygonFill` (`BGE.PolygonFillRule.nonZero`/`evenOdd`) ([#547](https://github.com/markwpearce/brighterscript-game-engine/issues/547)).
- `DrawableParticles.sizeInWorldUnits` (also on `ParticleBurstStyle`) sizes particles in world units so they shrink with distance and match across resolutions ([#491](https://github.com/markwpearce/brighterscript-game-engine/issues/491)).
- `Camera3d.projectPointsWithDepth()` takes `markBehind`, so an emitter around the player keeps the fast path ([#506](https://github.com/markwpearce/brighterscript-game-engine/issues/506)).
- `Drawable.flash(color, seconds, blinkSeconds, alpha)` overrides the drawn colour or alpha without touching `color`/`alpha`, plus `flashAlpha()` and `getDisplayAlpha()` ([#426](https://github.com/markwpearce/brighterscript-game-engine/pull/426), [#629](https://github.com/markwpearce/brighterscript-game-engine/issues/629)).
- `DrawableOrientedSprite.lodDistance` with `setLodAnimation()` plays a stand-in animation past a distance (`isLodFar()`), scaled by `RenderQualitySettings.animationLodDistanceScale` ([#580](https://github.com/markwpearce/brighterscript-game-engine/issues/580), [#618](https://github.com/markwpearce/brighterscript-game-engine/issues/618)).
- `Renderer.drawWorldPolyline()`, `drawWorldCircle()`, `drawWorldArc()` and `drawWorldBar()` draw in world space (skipped behind the camera); `SphereCollider3d` draws a ground ring and `BoxCollider3d` its 12 edges in the collider debug draw ([#404](https://github.com/markwpearce/brighterscript-game-engine/issues/404), [#406](https://github.com/markwpearce/brighterscript-game-engine/issues/406), [#422](https://github.com/markwpearce/brighterscript-game-engine/issues/422)).
- `BGE.Model3dOps.boxFaces(center, size, rgba, {omit})` builds an axis-aligned box mesh ([#580](https://github.com/markwpearce/brighterscript-game-engine/issues/580)).
- Multiple materials per `.obj` model: `usemtl`, every `newmtl` (`map_Kd` + `Kd`), UVs outside 0..1 repeat, and `map_Kd` resolves against the `.mtl` ([#341](https://github.com/markwpearce/brighterscript-game-engine/issues/341), [#321](https://github.com/markwpearce/brighterscript-game-engine/issues/321)).
- Named colours: `BGE.Colors`/`ColorsRGB` have all 148 CSS colours ([#331](https://github.com/markwpearce/brighterscript-game-engine/issues/331)).
- `Game.getColliders(flags)` and `Game.getCollidersInBox()`, and `Collider.getWorldBounds()` ([#494](https://github.com/markwpearce/brighterscript-game-engine/issues/494), [#505](https://github.com/markwpearce/brighterscript-game-engine/issues/505)).

**Sprites**
- `BGE.SpriteFrames`: sheets plus a rect per frame (uniform grid or packed, trimmed frames), shared by every sprite using it; `Game.getSpriteFrames(bitmapNames, cellWidth, cellHeight, frameRects?)` caches by bitmap name. `Sprite`/`DrawableOrientedSprite` also take an array of sheet bitmaps ([#386](https://github.com/markwpearce/brighterscript-game-engine/issues/386), [#397](https://github.com/markwpearce/brighterscript-game-engine/issues/397), [#401](https://github.com/markwpearce/brighterscript-game-engine/issues/401)).
- `DrawableOrientedSprite.mirrorBuckets` draws the back half of the directions as flipped copies of the front half ([#402](https://github.com/markwpearce/brighterscript-game-engine/issues/402)).
- `DrawableOrientedSprite.addOrientedAnimationColumns()` and `framesForColumns()` for per-direction frame columns; `BGE.frameRateFor(frameCount, seconds, minFrameRate)` and `BGE.frameRateForStride()` ([#399](https://github.com/markwpearce/brighterscript-game-engine/issues/399), [#400](https://github.com/markwpearce/brighterscript-game-engine/issues/400), [#618](https://github.com/markwpearce/brighterscript-game-engine/issues/618)).
- `Game.loadSpriteAtlas()`/`getSpriteAtlas()`/`unloadSpriteAtlas()`/`getSpriteAtlasFrames()` and `loader.loadSpriteAtlas(name, pathOrUrl)` load a packed atlas `.json` and its sheets ([#417](https://github.com/markwpearce/brighterscript-game-engine/issues/417)).

**Loading**
- Scene loading stage: `GameScene.onLoad(loader, args)` runs before `onCreate()` under a loading screen (`BGE.LoadingScreen`/`DefaultLoadingScreen`, overridable per scene or game). `BGE.AssetLoader`/`BGE.LoadTask` load bitmaps, sounds, fonts and models over several frames, with `addStep(fn, context, weight, oncePerFrame)`, dependencies and weighted progress; `game.assets` is one for background loading. See the [Loading Assets guide](https://markwpearce.github.io/brighterscript-game-engine/loading-assets) ([#301](https://github.com/markwpearce/brighterscript-game-engine/issues/301), [#318](https://github.com/markwpearce/brighterscript-game-engine/issues/318)).
- Load from URLs: loads and the new `AssetLoader.download()` take http(s) URLs, cached in `cachefs:/bge/` (`refresh`/`cache: false`, `clearCache()`), with retries, shared in-flight downloads and extension detection. `BitmapLoadOptions` resizes bitmaps while loading and decodes through `BGE.TextureLoader` ([#301](https://github.com/markwpearce/brighterscript-game-engine/issues/301), [#321](https://github.com/markwpearce/brighterscript-game-engine/issues/321)).
- `loader.loadTiledMap(name, pathOrUrl)`, `game.getTiledMap()` and `game.unloadTiledMap()` ([#493](https://github.com/markwpearce/brighterscript-game-engine/issues/493)).
- `GameScene.loadSceneBitmap()`/`loadSceneModel()`/`loadSceneSpriteAtlas()`/`loadSceneTiledMap()` load assets the scene owns and frees after the next scene's `onLoad()` (`shared` leaves them alone) ([#575](https://github.com/markwpearce/brighterscript-game-engine/issues/575)).
- `Game.loadBitmap()` accepts an `roBitmap`, `Game.getBitmap(name, false)` skips the missing-bitmap warning, and `Game.hasBitmap(name)` ([#370](https://github.com/markwpearce/brighterscript-game-engine/issues/370), [#542](https://github.com/markwpearce/brighterscript-game-engine/issues/542)).
- `BGE.Tiled.parseMapFile()` loads Tiled JSON maps (embedded or `.tsj` tilesets, tile/object/image/group layers); `layerToTileSpecs()`/`layerToColliderCells()` feed the existing tile map functions, and `TileSpec` gets `flipH`/`flipV`. See the [Tile Maps guide](https://markwpearce.github.io/brighterscript-game-engine/tile-maps) ([#196](https://github.com/markwpearce/brighterscript-game-engine/issues/196)).

**Cameras and movement**
- `BGE.OrbitCamera` (orbit/tilt, `recenter()`, min height, `lockOn()`/`releaseLock()`, `lockDeadZone`, `lockEase`) and `BGE.Math.cameraRelativeMove()`; see the [Third-Person Cameras guide](https://markwpearce.github.io/brighterscript-game-engine/third-person-cameras) ([#418](https://github.com/markwpearce/brighterscript-game-engine/issues/418), [#568](https://github.com/markwpearce/brighterscript-game-engine/issues/568)).
- `BGE.CameraBoom` keeps a chase camera in front of colliders, and `BGE.GridWallsCameraBoom` does the same on a grid map ([#390](https://github.com/markwpearce/brighterscript-game-engine/issues/390), [#577](https://github.com/markwpearce/brighterscript-game-engine/issues/577)).
- `BGE.Math` heading helpers (`headingForward`, `headingRight`, `headingOf`, `wrapAngle`, `turnToward`, `flatDistance`, `flatDirection`, `rotationForward()`/`rotationFacing()`, `directionFromYawPitch`, `isWithinArc`), `bounceInRect`, `clampToRect`, `wrapInRect`, `randomFloat`, `randomSign` and `hash2` ([#404](https://github.com/markwpearce/brighterscript-game-engine/issues/404), [#420](https://github.com/markwpearce/brighterscript-game-engine/issues/420), [#578](https://github.com/markwpearce/brighterscript-game-engine/issues/578), [#631](https://github.com/markwpearce/brighterscript-game-engine/issues/631)).
- `BGE.separateCircles(bodies, plane)` pushes overlapping circles apart, and `GameScene.onPostUpdate(dt)` runs after every entity's update, before collisions ([#405](https://github.com/markwpearce/brighterscript-game-engine/issues/405)).
- `BGE.SolidWorld.track(entity, radius)`/`untrack()`/`resolveTracked()` replay tracked bodies through `moveAndSlide()`; `GameScene.trackedSolidWorld` resolves them automatically; `SolidWorld.getSolidsInArea()` ([#578](https://github.com/markwpearce/brighterscript-game-engine/issues/578)).
- `BGE.NavGrid` grid A* over a `SolidWorld` (8-way, smoothed, `step(budgetMs)` to spread a search over frames, `rebuildArea()` for doors) and `BGE.NavFollower` to steer along a path. `NavGrid.hasLineOfSight()` now looks from the nearest open cell. See the [Pathfinding guide](https://markwpearce.github.io/brighterscript-game-engine/pathfinding) ([#434](https://github.com/markwpearce/brighterscript-game-engine/issues/434), [#577](https://github.com/markwpearce/brighterscript-game-engine/issues/577)).
- `BGE.CharGrid` and `BGE.GridSides` parse text-grid maps into cells, groups, runs and a `SolidWorld` ([#577](https://github.com/markwpearce/brighterscript-game-engine/issues/577)).

**Gameplay building blocks**
- `BGE.Impulse` (`start()`, `startTimed()`, `step(dt)`), `BGE.RegenPool`, `BGE.Health`, `BGE.StateClock`, `BGE.TokenPool`, `BGE.Targeting` (`pickInView`/`nextByBearing`), `BGE.ParticlePresets`, `BGE.ParticleBurstPool` with `DrawableParticles.burstCone()`, `BGE.RespawnTimer` and `BGE.Interactables` ([#419](https://github.com/markwpearce/brighterscript-game-engine/issues/419), [#424](https://github.com/markwpearce/brighterscript-game-engine/issues/424), [#403](https://github.com/markwpearce/brighterscript-game-engine/issues/403), [#576](https://github.com/markwpearce/brighterscript-game-engine/issues/576), [#579](https://github.com/markwpearce/brighterscript-game-engine/issues/579), [#573](https://github.com/markwpearce/brighterscript-game-engine/issues/573)).
- `BGE.GameSession`: score, lives, ready/playing/paused/over/levelComplete states, prompts, start input and `persistHighScore(section)`. See the [Game Session guide](https://markwpearce.github.io/brighterscript-game-engine/game-session) ([#576](https://github.com/markwpearce/brighterscript-game-engine/issues/576)).
- `BGE.SceneExits` (`RectExitArea`, `CircleExitArea`, `GridCellsExitArea`), `BGE.SpawnPoints` and `BGE.SceneCycler`, `BGE.nextDrawMode()`/`setEntityDrawMode()`/`cycleDrawMode()`; `getSceneNames()` is in definition order ([#575](https://github.com/markwpearce/brighterscript-game-engine/issues/575)).
- `GameTimer.freeze()` for deterministic tests ([#415](https://github.com/markwpearce/brighterscript-game-engine/issues/415)).

**Story**
- `BGE.Story`: `StoryState` (flags, inventory, visit counts, event rules, `registerCondition`/`registerEffect`), `DialogueRunner` (lines, choices, `goto`/`call`/`end`, `once`, random candidate groups, backlog, save/restore), `loadStory` (JSON) and `validateStory`. See the [Story guide](https://markwpearce.github.io/brighterscript-game-engine/story) ([#298](https://github.com/markwpearce/brighterscript-game-engine/issues/298)).
- `BGE.Story.StorySession` (the entity that owns the state and runner), `BGE.Story.DialogueView` (column, row or list choices), and `BGE.Story.applyDebugState()` ([#573](https://github.com/markwpearce/brighterscript-game-engine/issues/573), [#294](https://github.com/markwpearce/brighterscript-game-engine/issues/294)).

**UI**
- `BGE.UI.Keyboard` on-screen keyboard (alphabetical, QWERTY and arcade layouts): set `textInput.keyboard`. `TextInput` gained `insertChar()`/`deleteBeforeCursor()`/`submit()` ([#288](https://github.com/markwpearce/brighterscript-game-engine/issues/288)).
- `Button.actionId`/`value`/`listener`, `setDisabled()`, `setFont()`; `BGE.UI.MenuList`; `GameScene.addUi()`/`removeUi()` (widgets removed after `onDestroy()`); `BGE.UI.TextButton`; `UiWidget.getTheme()` returns a widget's own theme. See the [Menus guide](https://markwpearce.github.io/brighterscript-game-engine/ui-menus) ([#569](https://github.com/markwpearce/brighterscript-game-engine/issues/569)).
- `BGE.PauseMenu`, `game.pushModal()`/`popModal()`/`isModalOpen()`, `game.suppressInputUntilRelease()`, and `ControlMap.blockUntilReleased()`/`isActionBlocked()`/`matchesAction()` ([#570](https://github.com/markwpearce/brighterscript-game-engine/issues/570)).
- `BGE.UI.Meter`, `Banner`, `CreditsView` and `ControllerQrWidget`, plus `ControlMap.describeBindings()` and `Game.getFontOr()`. See the [HUD Widgets guide](https://markwpearce.github.io/brighterscript-game-engine/hud-widgets) ([#571](https://github.com/markwpearce/brighterscript-game-engine/issues/571)).
- `ControlMap.getPlayerStick()`, and an input debug window that draws a remote or gamepad per player (`InputDisplay.mode` or `enableStandardDebugUi({inputDisplayMode: "text"})` for text) ([#229](https://github.com/markwpearce/brighterscript-game-engine/issues/229)).

**Saving and launching**
- `BGE.registryDelete()`/`registryExists()`, `BGE.SaveSlot(section, key, version)` (versioned, `migrate()`), `BGE.SaveProfile(section)` (settings, endings, `recordHighScore()`/`getHighScore()`). See the [Saving guide](https://markwpearce.github.io/brighterscript-game-engine/saving) ([#572](https://github.com/markwpearce/brighterscript-game-engine/issues/572)).
- `BGE.LaunchParams(args)` typed reader, `sceneName()` checks and `game.applyLaunchQuality(params)`. See the [Launch Params guide](https://markwpearce.github.io/brighterscript-game-engine/launch-params) ([#574](https://github.com/markwpearce/brighterscript-game-engine/issues/574)).

**Debug and tooling**
- `Game.isDebugDrawingColliders()`/`toggleDebugDrawColliders()` and getters for occlusion, safe zones and entity details ([#369](https://github.com/markwpearce/brighterscript-game-engine/issues/369)).
- `game.enableDebugToggle({button, action, levels, startLevel, enabled})` steps through debug overlay levels ([#581](https://github.com/markwpearce/brighterscript-game-engine/issues/581)).
- `BGE.Debug.PerfStats` and `game.debugPrintPerfStats(enabled, interval, options)`; `Renderer.profileStages` with `getStageMsLastFrame()` ([#581](https://github.com/markwpearce/brighterscript-game-engine/issues/581), [#349](https://github.com/markwpearce/brighterscript-game-engine/pull/349)).
- `npm run run-example -- <example> [key=value ...]` builds, sideloads and launches an example with deep-link params ([#379](https://github.com/markwpearce/brighterscript-game-engine/pull/379)).

**Examples**
- New `visualnovel` ("The Mutiny"): a short sci-fi visual novel built on `BGE.Story` ([#294](https://github.com/markwpearce/brighterscript-game-engine/issues/294)).
- New `story`: knock-knock jokes, text only ([#298](https://github.com/markwpearce/brighterscript-game-engine/issues/298)).
- New `loading`: local and remote assets, failure scenes and a clear-cache button ([#301](https://github.com/markwpearce/brighterscript-game-engine/issues/301)).
- New `fighter`: a rough 2-player fight on a parallax stage with frame data, blocking and best of 3 ([#295](https://github.com/markwpearce/brighterscript-game-engine/issues/295)).
- New `thirdPerson`: a souls-like third-person game with a night field, a walled town, a graveyard, a three-level crypt, a keep and a chapel, enemies and bosses, lock-on, stamina, dialogue and engine fog ([#385](https://github.com/markwpearce/brighterscript-game-engine/issues/385)).
- New `navigation`: four agents chase a flag through a maze with doors using `BGE.NavGrid` ([#434](https://github.com/markwpearce/brighterscript-game-engine/issues/434)).
- New `flightSim`: fly a biplane through 10 rings over voxel terrain, against the clock ([#655](https://github.com/markwpearce/brighterscript-game-engine/issues/655)).
- `terrain`: occluding chapel, loading in `onLoad()`, runs on HD-tier devices ([#151](https://github.com/markwpearce/brighterscript-game-engine/issues/151), [#320](https://github.com/markwpearce/brighterscript-game-engine/issues/320), [#108](https://github.com/markwpearce/brighterscript-game-engine/issues/108)).
- `platformer`: level 1 is a Tiled map, score and lives carry to the next level, and `Camera2d.follow()`/`setBounds()` ([#196](https://github.com/markwpearce/brighterscript-game-engine/issues/196), [#621](https://github.com/markwpearce/brighterscript-game-engine/issues/621), [#582](https://github.com/markwpearce/brighterscript-game-engine/issues/582)).
- `3d`: car is a 9-material model and impostor deep links.
- `rendererTest`: scrolling menu and many benchmark and demo scenes (lighting, fog, grid/segment walls, voxel terrain, columns, polygon fills, impostor strips) ([#380](https://github.com/markwpearce/brighterscript-game-engine/pull/380)).
- All examples: gameUi widgets are laid out from `game.uiCanvas`, pause handlers use `BGE.PauseMenu`, and high scores use `BGE.SaveProfile` ([#191](https://github.com/markwpearce/brighterscript-game-engine/issues/191), [#594](https://github.com/markwpearce/brighterscript-game-engine/pull/594), [#596](https://github.com/markwpearce/brighterscript-game-engine/pull/596)).
- Large PNGs are now WebP ([#483](https://github.com/markwpearce/brighterscript-game-engine/issues/483)).

### Fixed

**Rendering**
- A `Renderer` now turns on alpha blending on the surface it draws to. On a surface created with `alphaEnable: false`, every oriented object's transparent corners were drawn as black over whatever was behind them ([#332](https://github.com/markwpearce/brighterscript-game-engine/issues/332)).
- Moving flat-colored triangles (oriented `DrawableRectangle`s, `DrawablePolygon`s, untextured model faces) no longer stripe: the fast fill is now `DrawRect` bands instead of fanned lines, and a rectangle or polygon drawn with it is redrawn exactly once it stops moving ([#119](https://github.com/markwpearce/brighterscript-game-engine/issues/119)).
- Dotted seams in the exact triangle fill ([#339](https://github.com/markwpearce/brighterscript-game-engine/issues/339)), and a mirrored pinned quad warping ([#269](https://github.com/markwpearce/brighterscript-game-engine/issues/269)).
- The tiled ground plane not drawing at High/Ultra (a Roku silently drops a bitmap's draws past ~13,000 queued) ([#252](https://github.com/markwpearce/brighterscript-game-engine/issues/252), [#136](https://github.com/markwpearce/brighterscript-game-engine/issues/136)), jagged ground plane slices toward the screen sides ([#313](https://github.com/markwpearce/brighterscript-game-engine/issues/313)), and a static decal being cropped at the quad's far corner.
- Missing model triangles and texture-memory exhaustion on a real Roku: scratch bitmaps aren't reused within a frame, big triangles warp at most 640px (`Renderer.maxTriangleWarpSize`), and model face images only hold their on-canvas part ([#345](https://github.com/markwpearce/brighterscript-game-engine/issues/345)).
- Ground and tiled model textures coming out with empty rows at random, and walls and oriented images that run past the camera vanishing ([#490](https://github.com/markwpearce/brighterscript-game-engine/pull/490)).
- Objects behind the camera were recomputed every frame (`SceneObject.markSkippedBehindCamera()`) ([#308](https://github.com/markwpearce/brighterscript-game-engine/issues/308)); `isFirstFrameSinceEnabled` never fired after a re-enable.
- Scene object ids are unique across renderers, and `Drawable.removeFromRenderer()` only removes that renderer's scene objects ([#343](https://github.com/markwpearce/brighterscript-game-engine/issues/343)).
- `colorBrightness()` and `colorOpacity()` dropped alpha, so shaded translucent drawables drew opaque ([#375](https://github.com/markwpearce/brighterscript-game-engine/issues/375)).
- Billboards and sprites drew unshaded on their first frame ([#566](https://github.com/markwpearce/brighterscript-game-engine/issues/566)).
- East/west wall facing: `rotation.y` faces `(-sin r, cos r)`, which was backwards for things on east/west walls ([#631](https://github.com/markwpearce/brighterscript-game-engine/issues/631)).
- Crash drawing a polygon triangle more than the clip margin off the canvas in oriented modes ([#615](https://github.com/markwpearce/brighterscript-game-engine/issues/615)).
- A model's bounding box no longer grows its canvas for a face dropped behind the camera, and a failed draw latches as culled only when the bounds are off the canvas ([#344](https://github.com/markwpearce/brighterscript-game-engine/issues/344)).
- Fog fixes: no snapping to fog on redraw, nothing drawn past the draw distance, and walls past it ([#529](https://github.com/markwpearce/brighterscript-game-engine/issues/529), [#533](https://github.com/markwpearce/brighterscript-game-engine/issues/533)).

**Scenes, input and UI**
- `onDestroy()` never ran on a scene you left ([#327](https://github.com/markwpearce/brighterscript-game-engine/issues/327)).
- `Sprite` `PingPong` held frame 0 on its return half ([#387](https://github.com/markwpearce/brighterscript-game-engine/issues/387)).
- Holding a gamepad direction stopped repeating after tapping another button ([#382](https://github.com/markwpearce/brighterscript-game-engine/issues/382)), and a gamepad couldn't pick dialogue choices (`DialogueView.advanceAction`).
- `BGE.UI.Label` `horizAlign` ignored `customX` ([#628](https://github.com/markwpearce/brighterscript-game-engine/issues/628)), and the focused `Button` text was hard to read ([#328](https://github.com/markwpearce/brighterscript-game-engine/issues/328)).
- Keyboard Backspace/Enter in `TextInput` ([#286](https://github.com/markwpearce/brighterscript-game-engine/issues/286)).
- `.9.png` nine-patch images never loaded on a device ([#551](https://github.com/markwpearce/brighterscript-game-engine/issues/551)).
- `Game.getBitmap()` of a missing bitmap logging a warning in get-or-create code ([#542](https://github.com/markwpearce/brighterscript-game-engine/issues/542)).
- Stale `>512` tile chunk warnings: chunks bigger than 512 draw fine, it just wastes texture memory ([#213](https://github.com/markwpearce/brighterscript-game-engine/issues/213)).

## [0.8.0] - 2026-10-08

### Changed

- Render quality levels are now always on: `Renderer` reads every draw-quality knob from a `BGE.RenderQualitySettings` preset, seeded from the device model (fallback Medium). **Games that never call the new API will look slightly different on non-Medium devices** (draw distance, plane slices, fast-draw tolerances) ([#251](https://github.com/markwpearce/brighterscript-game-engine/issues/251), [#126](https://github.com/markwpearce/brighterscript-game-engine/issues/126)).
- `DrawablePlane` always draws to the authored `Camera3d.maxDrawDistance` (device-capped), regardless of quality level, so the horizon never moves.
- `Camera2d` now culls an object by the bounding box of its corners, so an image bigger than the view is no longer culled when all four corners are off screen ([#258](https://github.com/markwpearce/brighterscript-game-engine/issues/258)).
- `Camera2d.worldPointToCanvasPoint()` rounds to the nearest pixel instead of truncating, and the view snaps to whole pixels, so adjacent images no longer gap by 1px ([#255](https://github.com/markwpearce/brighterscript-game-engine/issues/255), [#261](https://github.com/markwpearce/brighterscript-game-engine/issues/261)).
- `Game.loadBitmap()` now accepts `.webp` (Roku OS 9.4+), `.jpeg`, `.bmp` and `.gif`, and returns `false` (and logs) when the bitmap can't be decoded instead of storing `invalid`. SVG isn't supported and animated GIFs only show frame 1 ([#259](https://github.com/markwpearce/brighterscript-game-engine/pull/259), [#266](https://github.com/markwpearce/brighterscript-game-engine/pull/266)).
- `gameUi` and `debugUi` now receive `onChangeScene()` when the scene changes ([#245](https://github.com/markwpearce/brighterscript-game-engine/issues/245)).
- Controller-page input now reaches `gameUi.onInput`.

### Added

**Rendering**
- Adaptive render quality: five `BGE.RenderQualityLevel` presets (Basic to Ultra), `Game.enableAdaptiveQuality()` to hold a target frame rate (default 20fps), `Game.setQualityLevel()` to pin a level, `Game.renderQuality.overridePreset()` to retune a level, and an `onQualityChanged(level)` callback on entities, the scene and UI. See the [Render Quality guide](https://markwpearce.github.io/brighterscript-game-engine/render-quality) ([#251](https://github.com/markwpearce/brighterscript-game-engine/issues/251), [#126](https://github.com/markwpearce/brighterscript-game-engine/issues/126)).
- `Camera2d.follow(entity)` and `Camera2d.setBounds(x, y, w, h)`, applied before drawing so the camera no longer runs a frame behind ([#260](https://github.com/markwpearce/brighterscript-game-engine/pull/260)).

**Scenes**
- `Game.changeSceneWithFade()` / `Game.isTransitioning()` with a `BGE.ScreenFade` overlay ([#260](https://github.com/markwpearce/brighterscript-game-engine/pull/260)).

**Collision**
- `GameEntity.onCollisionEnter()` / `onCollisionExit()` ([#260](https://github.com/markwpearce/brighterscript-game-engine/pull/260)).
- `BGE.SolidWorld`: top-down static-rectangle collision with `moveAndSlide()` (`maxStep`/`cornerNudge` options), `addSolid()` (returns an id), `removeSolid(id)`, `addBounds()`, `isAreaFree()` and `getSolids()` (typed `BGE.SolidWorldSolid[]`) ([#256](https://github.com/markwpearce/brighterscript-game-engine/issues/256)).

**UI**
- `BGE.UI.Label.wrapWidth` and `BGE.UI.wrapText()` for word wrapping; `DrawableText` sizes multi-line text by its widest line ([#257](https://github.com/markwpearce/brighterscript-game-engine/issues/257)).

**Audio**
- `Game.musicPlay(path, loop, restart = true)` (`restart = false` leaves an already-playing track alone) and `Game.getMusicPath()` ([#290](https://github.com/markwpearce/brighterscript-game-engine/issues/290)).
- `npm run audio -- sfx|music|silences|info`: ffmpeg tools for Roku-safe sound effects (mono 22kHz WAV) and music (96kbps MP3) ([#290](https://github.com/markwpearce/brighterscript-game-engine/issues/290)).

**Utilities**
- Auto-tiling in `BGE.TileMap`: `getNeighbourMask4()`, `getNeighbourMask8()`, `reduceBlobMask()`, `getBlobTileIndex()` (47-tile blob sets) and `getEdgePiece3x3()`, taking rows of strings or arrays of tile ids, with an `outOfBoundsMatches` option ([#272](https://github.com/markwpearce/brighterscript-game-engine/issues/272)).
- Releases are automated: an Initialize Release workflow opens a `release/x.y.z` PR, and merging it tags, publishes to npm (trusted publishing) and creates the GitHub release ([#248](https://github.com/markwpearce/brighterscript-game-engine/issues/248)).

**Docs**
- New [Tile Maps guide](https://markwpearce.github.io/brighterscript-game-engine/tile-maps) ([#278](https://github.com/markwpearce/brighterscript-game-engine/issues/278)) and [Render Quality guide](https://markwpearce.github.io/brighterscript-game-engine/render-quality).
- `RectangleCollider` docs now say `offset.y` is the top edge (world +y up), and that edge-to-edge colliders don't collide while `onCollision` fires every frame for a persistent overlap ([#280](https://github.com/markwpearce/brighterscript-game-engine/issues/280), [#200](https://github.com/markwpearce/brighterscript-game-engine/issues/200)).

**Examples**
- New `rpg` ("Broadsword"): a top-down adventure with sword combat, enemies, a data-driven story/dialogue/shop/save layer, a six-room dungeon, a witch boss, credits and music ([#63](https://github.com/markwpearce/brighterscript-game-engine/issues/63), [#256](https://github.com/markwpearce/brighterscript-game-engine/issues/256), [#257](https://github.com/markwpearce/brighterscript-game-engine/issues/257), [#289](https://github.com/markwpearce/brighterscript-game-engine/issues/289), [#296](https://github.com/markwpearce/brighterscript-game-engine/issues/296), [#290](https://github.com/markwpearce/brighterscript-game-engine/issues/290)).
- `platformer`: level 7 boss fight (Venus fly trap) ([#265](https://github.com/markwpearce/brighterscript-game-engine/pull/265)).
- `rendererTest`: `quality-levels` and `negative-scale` demos; `terrain` turns on adaptive quality.

### Fixed

- `Game.handleSceneChange()` crashed when entities existed before the first `changeScene()` ([#244](https://github.com/markwpearce/brighterscript-game-engine/issues/244)).
- `Game.destroyAllEntities()` skipped every other entity ([#263](https://github.com/markwpearce/brighterscript-game-engine/issues/263)).
- Moving a drawable by its own `offset`/`rotation`/`scale` didn't redraw while its entity stood still ([#264](https://github.com/markwpearce/brighterscript-game-engine/issues/264)).
- `directScaled` billboards now mirror correctly for a negative scale on real hardware, which only mirrors `DrawTransformedObject` at rotation 0 ([#237](https://github.com/markwpearce/brighterscript-game-engine/issues/237)).
- `DrawableCircle`'s anchor was ignored in the plain 2D draw modes ([#273](https://github.com/markwpearce/brighterscript-game-engine/issues/273)).
- Typed keyboard characters leaked into button input (a character's release looked like a button, e.g. `"d"` as Back); they now reach only `onECPKeyboard()` ([#194](https://github.com/markwpearce/brighterscript-game-engine/issues/194)).
- `FocusManager.focusWidget()` now clears a held stick direction.

## [0.7.0] - 2026-09-24

### Changed (breaking)

`BGE.Room` is now `BGE.GameScene` ([#227](https://github.com/markwpearce/brighterscript-game-engine/issues/227)). "Room" never described what it is - the current state of your game, whether that's a title screen, a menu, or a level. The renderer's own "scene" methods were renamed at the same time so the word only means one thing. This is a clean break with no deprecated aliases. The class is `GameScene`, matching `GameEntity`/`GameInput`; the methods, fields and folders that refer to it just say "scene".

| Old | New |
|---|---|
| `BGE.Room` | `BGE.GameScene` |
| `Room.persistDrawablesAcrossRoomChange` | `GameScene.persistDrawablesAcrossSceneChange` |
| `GameEntity.onChangeRoom(newRoom)` | `GameEntity.onChangeScene(newScene)` |
| `Game.defineRoom()` / `changeRoom()` / `resetRoom()` | `Game.defineScene()` / `changeScene()` / `resetScene()` |
| `Game.getRoom()` / `getRoomNames()` / `isRoomChanging()` | `Game.getScene()` / `getSceneNames()` / `isSceneChanging()` |
| `Game.currentRoom` / `currentRoomArgs` / `Rooms` | `Game.currentScene` / `currentSceneArgs` / `Scenes` |
| `Renderer.drawScene()` | `Renderer.render()` |
| `Drawable.addToScene(renderer)` / `removeFromScene(renderer)` | `Drawable.addToRenderer(renderer)` / `removeFromRenderer(renderer)` |
| `npm run create-room` | `npm run create-scene` (writes to `Scenes/`) |

Most leftover uses of the old names fail to compile. The exception: an `override sub onChangeRoom(...)`, `override function addToScene(...)` or `override sub removeFromScene(...)` in your own classes **still compiles but is never called**. Search your project for those three names and rename them.

`SceneObject` and `Renderer.addSceneObject()`/`removeSceneObject()`/`getSceneObjects()` are unchanged.

### Changed

- `Game.Play()` now processes `gameUi` input *before* entity input (it used to run after), so a focused widget can call `GameInput.consume()` to keep an event from also reaching `GameEntity.onInput()` that frame ([#133](https://github.com/markwpearce/brighterscript-game-engine/issues/133)).
- UI focus is now global: one `Game.focusManager` (`BGE.UI.FocusManager`) owns focus across every container, and defaults to list navigation (d-pad steps through widgets in `addChild()` order). Pointer/cursor navigation is opt-in via `focusManager.navigationMode` ([#178](https://github.com/markwpearce/brighterscript-game-engine/issues/178)).
- Remotes, simulator gamepads and browser controllers now share one `playerIndex` pool instead of remotes being hardcoded to `-1` ([#216](https://github.com/markwpearce/brighterscript-game-engine/issues/216)).
- The `DrawTransformedObject` polyfill is gone; the engine uses the native call, which is fixed as of Roku OS 15.3.
- `Camera3d.maxDrawDistance` is now an engine-wide far-clip honored by every `SceneObject`, capped per device tier ([#124](https://github.com/markwpearce/brighterscript-game-engine/issues/124)).
- `DrawableText.alignment` is now shorthand for `anchor.x` (see anchoring below); this also fixes right-aligned text being offset by its height instead of its width.

### Added

**Rendering**
- Configurable `anchor` on every `Drawable` (`setAnchor(x, y)`) ([#50](https://github.com/markwpearce/brighterscript-game-engine/issues/50)).
- `DrawableCircle`/`DrawableSphere` ([#100](https://github.com/markwpearce/brighterscript-game-engine/issues/100)), with a fast rotate+scale fill path in oriented modes ([#105](https://github.com/markwpearce/brighterscript-game-engine/issues/105)); `Renderer.drawCircle()` and `drawRoundedRectangle()` ([#102](https://github.com/markwpearce/brighterscript-game-engine/issues/102)).
- Particle system: `DrawableParticles` ([#86](https://github.com/markwpearce/brighterscript-game-engine/issues/86)).
- Parallax/scrolling background layers: `DrawableParallaxLayer` and `BGE.newFullHeightParallaxLayer()` ([#67](https://github.com/markwpearce/brighterscript-game-engine/issues/67), [#203](https://github.com/markwpearce/brighterscript-game-engine/issues/203)).
- Skybox: `DrawableSkybox`/`SceneObjectSkybox` ([#65](https://github.com/markwpearce/brighterscript-game-engine/issues/65)).
- `DrawablePlane.fillMode` (`color`/`tiledImage`/`staticImage`) for composable ground planes ([#53](https://github.com/markwpearce/brighterscript-game-engine/issues/53)), and `Camera3d.rollDegrees`.
- Textured `.obj` model loading via `Game.load3dModel` ([#89](https://github.com/markwpearce/brighterscript-game-engine/issues/89)).
- `DrawableOrientedSprite`: Doom-style angle-based sprite billboards ([#104](https://github.com/markwpearce/brighterscript-game-engine/issues/104)).
- Smarter depth sorting: sort skipped when nothing moved, stable tie-breaks, and opt-in overlap clusters that interleave model faces ([#59](https://github.com/markwpearce/brighterscript-game-engine/issues/59)).
- Static geometry: `GameEntity.isStatic` marks level geometry that is drawn through a BSP tree, so dynamic objects sort correctly between walls ([#107](https://github.com/markwpearce/brighterscript-game-engine/issues/107)).
- Tilemap baking into chunked images: `BGE.TileMap.bakeTileMapImages()`.
- `GameEntity.isOnScreen()` ([#75](https://github.com/markwpearce/brighterscript-game-engine/issues/75)).
- SceneGraph shape components (`src/components/Shapes`: `Circle`, `Polygon`, `RoundedRectangle`) that render with `BGE.Renderer` ([#61](https://github.com/markwpearce/brighterscript-game-engine/issues/61)).
- `BGE.QrCode`.

**Collision**
- 3D collision: `SphereCollider3d`/`BoxCollider3d` ([#131](https://github.com/markwpearce/brighterscript-game-engine/issues/131)).
- Raycasting: `Game.raycast()`/`raycastAll()` ([#225](https://github.com/markwpearce/brighterscript-game-engine/issues/225)).
- `BGE.resolveAabbTileCollision()` for platformer/top-down tile collision ([#204](https://github.com/markwpearce/brighterscript-game-engine/issues/204)).

**UI**
- New widgets: `Button`, `Checkbox`, `Select` (inline, horizontal and popup styles), `TextInput`, plus `Slider` on the new focus system ([#133](https://github.com/markwpearce/brighterscript-game-engine/issues/133), [#179](https://github.com/markwpearce/brighterscript-game-engine/issues/179), [#181](https://github.com/markwpearce/brighterscript-game-engine/issues/181), [#192](https://github.com/markwpearce/brighterscript-game-engine/issues/192)).
- `BGE.UI.Theme` (`Game.defaultTheme`, per-container override).
- 9-patch / image widget backgrounds ([#180](https://github.com/markwpearce/brighterscript-game-engine/issues/180)) and an analog-stick-driven cursor ([#182](https://github.com/markwpearce/brighterscript-game-engine/issues/182)).
- `BGE.UI.MessagePanel` for pause/game-over screens ([#202](https://github.com/markwpearce/brighterscript-game-engine/issues/202)).
- `Button` can play a `Game.loadSound()` key on focus/click (`Button.focusSoundKey`/`clickSoundKey`), falling back to a game-wide default (`Game.uiFocusSoundKey`/`uiClickSoundKey`) when unset.

**Input**
- External controllers through a browser-based bridge, with QR-code discovery ([#149](https://github.com/markwpearce/brighterscript-game-engine/issues/149), [#168](https://github.com/markwpearce/brighterscript-game-engine/issues/168)).
- Multiple simultaneous remotes and simulator gamepads (analog sticks, including the right stick) ([#216](https://github.com/markwpearce/brighterscript-game-engine/issues/216)).
- `Game.setCombineRemoteInputs()` to let either the remote or a gamepad drive player 0 in single-player games ([#220](https://github.com/markwpearce/brighterscript-game-engine/issues/220)).
- `ControlMap.getActionHeldTimeMs()` ([#171](https://github.com/markwpearce/brighterscript-game-engine/issues/171)); `bindAction()` accepts an array of button names.
- `GameInput.isButton()` accepts common button-name aliases ([#88](https://github.com/markwpearce/brighterscript-game-engine/issues/88)).
- `BGE.FreeFlyCameraController`, a reusable free-fly 3D camera ([#148](https://github.com/markwpearce/brighterscript-game-engine/issues/148)).

**Utilities**
- `BGE.TweenManager` (`Game.tweenManager`): tweens on arbitrary fields ([#60](https://github.com/markwpearce/brighterscript-game-engine/issues/60)).
- `BGE.CountdownTimer` ([#205](https://github.com/markwpearce/brighterscript-game-engine/issues/205)).
- `Game.getEntitiesByTag()` ([#55](https://github.com/markwpearce/brighterscript-game-engine/issues/55)).
- `Game.enableStandardDebugUi()` ([#54](https://github.com/markwpearce/brighterscript-game-engine/issues/54)).
- `npm run check` / `check:all` ([#57](https://github.com/markwpearce/brighterscript-game-engine/issues/57)), and `create-entity` / `create-scene` scaffolding scripts ([#56](https://github.com/markwpearce/brighterscript-game-engine/issues/56)).

**Examples**
- New: `audio`, `collisions3d`, `controller`, `depthsort`, `http`, `parallax`, `particles`, `platformer`, `scenegraph`, `terrain`, `tweens`, `ui`.
- `breakout` and `asteroids` brought up to date with the new UI, input and effects.

### Fixed

- Draws into a renderer's surface could silently fail for large images: `Renderer.render()` now calls `Finish()` on its destination ([#211](https://github.com/markwpearce/brighterscript-game-engine/issues/211)).
- A single failed frame no longer leaves a stationary object invisible for good ([#48](https://github.com/markwpearce/brighterscript-game-engine/issues/48)); deterministic draw rejections now latch instead of retrying every frame ([#73](https://github.com/markwpearce/brighterscript-game-engine/issues/73)).
- Oriented draw modes applied a drawable's scale twice ([#49](https://github.com/markwpearce/brighterscript-game-engine/issues/49)).
- `Camera3d` frustum planes used edge directions as normals, so `isInView` was wrong at any FOV but 90 ([#70](https://github.com/markwpearce/brighterscript-game-engine/issues/70)).
- Seam between `drawPinnedCorners`' two triangles ([#110](https://github.com/markwpearce/brighterscript-game-engine/issues/110)); choppy model rotation ([#128](https://github.com/markwpearce/brighterscript-game-engine/issues/128)); model face draw order ([#112](https://github.com/markwpearce/brighterscript-game-engine/issues/112)).
- Particles drifting into view from an off-screen emitter stayed culled ([#114](https://github.com/markwpearce/brighterscript-game-engine/issues/114)).
- `Drawable.color` tint dropped for scaled, unrotated circles ([#197](https://github.com/markwpearce/brighterscript-game-engine/issues/197)).
- A scene's own drawables weren't cleaned up on scene change ([#144](https://github.com/markwpearce/brighterscript-game-engine/issues/144)).
- Drawables with no owner crashed ([#231](https://github.com/markwpearce/brighterscript-game-engine/issues/231)).
- `GetTweenObjectPercentState()` only worked for decreasing tweens ([#25](https://github.com/markwpearce/brighterscript-game-engine/issues/25)).
- `QuickHull([])` returned `[invalid, invalid]` ([#109](https://github.com/markwpearce/brighterscript-game-engine/issues/109)); `Game.getBitmap()`/`get3dModel()` could crash when returning `invalid` ([#127](https://github.com/markwpearce/brighterscript-game-engine/issues/127)).
- Several `FocusManager` seeding/navigation bugs ([#190](https://github.com/markwpearce/brighterscript-game-engine/issues/190), [#198](https://github.com/markwpearce/brighterscript-game-engine/issues/198)).
- Missing imports between engine files that broke SceneGraph component scopes ([#178](https://github.com/markwpearce/brighterscript-game-engine/issues/178)).
- The example template's `bsconfig.json` broke every example build except `scenegraph` ([#167](https://github.com/markwpearce/brighterscript-game-engine/issues/167)).

## [0.6.0] - 2026-07-24

### Added

- Central logging: `Game.log(message, level)` / `Game.getLogHistory()`, with a `BGE.Debug.LogLevel` enum (`info`/`warning`/`error`). Existing `print`-only warnings across `Game.bs`/`GameEntity.bs`/`Sprite.bs` now route through it, and previously-silent lookups (`getBitmap`, `get3dModel`, `getFont`, `getDrawable`, `getEntityByID`, `getEntityByName`, `getCollider`) now warn on a miss instead of returning `invalid` with no trace.
- `BGE.Debug.LogDisplay`, a new debug window: bottom-center, auto-scrolling to the latest entries, colored white/yellow/red by level. Wired into all examples alongside the existing `FpsDisplay`/`InputDisplay`/`MemoryDisplay`/`GarbageCollectorDisplay`.
- `DrawableText.textColor` field, enabling per-line text coloring (used by `LogDisplay`).
- A Rooibos (v6) unit test suite, colocated as `*.spec.bs` files, runnable headlessly in CI via `brs-cli` or on-device.
- `examples/breakout`.

### Fixed

- **`ropm install` now actually works for consumers.** Publishing raw `.bs` source (rather than the already-compiled `build/` output) produced ~1640 compile errors for any real consumer - see the [README's Installation section](README.md#installation) for the recommended `ropm.noprefix` + `roku_modules` `diagnosticFilters` consumer setup.
- `examples/hybrid`'s broken build (stale `getImage` call) and `examples/pixels`' room-navigation graph (two rooms were unreachable).
- `BGE.Colors`/`BGE.ColorsRGB` changed to enums.

### Changed

- Docs site (`docs-site/`) is now built and deployed via GitHub Actions on every push to `main`, rather than committing generated output.
- Hand-written guides (`docs/`) folded into the same sidebar as the API reference, instead of a bolted-on menu.

## [0.5.0] - 2026-07-16

### Added

- Renderer overhaul: `SceneObject`s for images, billboards, lines, polygons, text, and 3D models, with configurable draw modes (`matchCamera`, `directToCamera`, `oriented`, `wireframe`, `solid`, and back-face variants).
- Billboard shading and wireframe drawing for models and billboards.
- Triangle bitmap caching and other rendering performance improvements.
- `npm run create-example -- <name> ["Title"]` scaffolds a new example (manifest, bsconfig, generated icon/splash images, minimal `MainRoom`).
- `examples/quickstart`, matching the README's sample code.
- `validate`/`lint` required status checks on PRs to `main`; automated docs regeneration.

### Changed

- UI moved to its own dedicated canvas/layer, with `Drawable`s refactored accordingly.
- README rewrite: engine + standalone drawing-library pitch, runnable quick-start code sample, examples table, screenshots.
- Example tooling (`prepare-examples`, `build-examples`, `validate-examples`, `clean-all`, `create-example`) rewritten in plain Node, so it works on Windows without Git Bash/WSL.

[Unreleased]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/markwpearce/brighterscript-game-engine/compare/1.1...v0.5.0
