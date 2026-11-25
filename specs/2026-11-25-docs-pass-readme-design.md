# Docs pass, part 1: README and accuracy (issue #663)

## Why

The README undersells the engine. Its stills (asteroids, 3d cube, snake, platformer, rpg) predate
the 3D work: chase cameras, voxel terrain, textured OBJ models, fighter, visual novel. And the
guides have drifted from the APIs as features landed. #663 asks for both to be fixed.

## Scope

#663 ships as two PRs. This spec is **PR 1**:

- Capture new stills and short motion clips on the Ultra.
- Restructure the README around them.
- Check every guide, the README examples table and the "quick taste" snippet against the code.

**PR 2** (filed as its own issue, linked from #663) adds images to the guides that have none.

## 1. Capture

All capture is on the Ultra. It's shared, so check what dev app is on it before each sideload,
and note at the end what was left on it.

**Stills.** Use the `rokubot-examples` skill. Keep each one 1280×720 jpg, compressed to about
100 KB or less, title-safe, with debug overlays off. Save them to `assets/screenshots/<name>.jpg`.

- New: thirdPerson, flightSim (chase camera), fighter, particles, voxel terrain, textured OBJ car,
  visualnovel, ui.
- Kept: asteroids, platformer, rpg, snake, 3d, terrain. Reshoot any that look stale next to the
  new set.

**Clips.** Record with Carabiner (`start_recording`/`stop_recording`) through the USB HDMI
capture card.

- Make 3 or 4 clips of 4–6 s each: flightSim, thirdPerson and voxel terrain, plus the OBJ model
  if it reads well.
- Convert each with ffmpeg (two-pass palette) to a looping GIF about 640 px wide at 12–15 fps,
  at most about 2 MB. Over budget means lowering the size or frame rate, not dropping the clip.
- Save them to `assets/clips/<name>.gif`.
- Keep the ffmpeg commands in the PR description so the clips can be rebuilt.

## 2. README structure

Top to bottom:

1. Badges (unchanged).
2. Title and a two-sentence pitch: real 2D and 3D games on Roku (chase cameras, voxel terrain,
   textured models, tile maps, visual novels) in object-oriented BrighterScript. Use the whole
   engine or just the renderer.
3. **Hero collage:** one 2×3 jpg (flightSim, voxel terrain, thirdPerson, fighter, platformer,
   OBJ car), each tile labelled with its example name. Built with ffmpeg from the stills
   (`assets/screenshots/hero.jpg`), with the command recorded in the PR so it can be rebuilt.
4. **See it move:** the GIFs side by side, each linking to its example folder.
5. **Features:** a scannable list in groups (3D; 2D and worlds; game systems; Roku integration;
   dev workflow), each item linking to its guide. It covers at least: the 3D renderer and
   cameras (Chase/Follow/Orbit), voxel terrain, impostors/fog/occlusion, textured OBJ models,
   particles, tile maps, pathfinding, story/visual novel, QR-code phone controller, saving,
   HUD/UI widgets, SceneGraph hybrid, splash screen, and simulator support.
6. Quick taste snippet (checked to compile, see §3).
7. Install, usage and docs sections: keep them, and refresh anything stale.
8. **Examples table:** every folder in `examples/`, one line each, with a thumbnail column where a
   still exists.

The current stacked `<figure>` blocks go. Their shots move to the collage or the table.

README links to the docs site use absolute `https://markwpearce.github.io/...` URLs, as they do
now. If the docs build publishes the README, the new images and GIFs must show up there too.

## 3. Accuracy pass

- **Guides.** Check all 19 in `docs/` against `src/source/`. Watch most closely the recent
  changes: `ChaseCamera`/`FollowCamera`/`OrbitCamera`, impostors/fog/occlusion perf work, 0.9.0
  changes, and the splash screen.
  - Fix wrong signatures, renamed APIs and behaviour that's no longer true.
  - Write a missing section for a new feature if it's short. File an issue if it isn't.
  - Run this as about 3 parallel subagents, each taking a group of guides and reporting
    discrepancies with `file:line` plus the source that proves each one. The coordinator applies
    every fix and checks it.
- **Quick taste.** Paste the snippet, with a minimal `MainScene`, into a scratch example and run
  `validate` on it. Delete the scratch example afterwards.
- **Examples table.** Diff it against `ls examples/`.
- **Docs site.** Run `npm run docs` and confirm the images resolve in `docs-site/`.

## Done when

- The README matches §2. Every image and GIF is in the repo and within its size budget.
- Every guide discrepancy is fixed or filed.
- `npm run check:all` passes, and `npm run docs` builds with the images resolving.
- A PR is open, closing nothing (#663 stays open for PR 2), with the screenshots inline.
- A follow-up issue for guide images is filed and linked from #663.
