# Docs pass, part 1 (README + accuracy) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A README that shows off the engine with fresh device stills, a hero collage and motion GIFs, and guides that match the current APIs (issue #663, PR 1).

**Architecture:** This is docs-only work on the branch `docs/663-docs-pass`. Assets are captured on the Ultra: stills with rokubot, clips with Carabiner through the USB HDMI capture card. They're processed with ffmpeg into compressed jpgs and GIFs under `assets/`. The README is rewritten around them. A parallel guide audit fixes stale API docs.

**Tech Stack:** rokubot (`node node_modules/rokubot/dist/cli.js`), Carabiner MCP (`start_recording`/`stop_recording`, `send_key`, `launch_app`), ffmpeg (Homebrew), `npm run docs`, `npm run check:all`.

Design: `specs/2026-11-25-docs-pass-readme-design.md`.

## Global Constraints

- Stills: 1280×720 jpg, about 100 KB or less each, title-safe, debug overlays off, in `assets/screenshots/<name>.jpg`.
- GIFs: 3–4 clips of 4–6 s, about 640 px wide, 12–15 fps, looping, two-pass palette, about 2 MB or less each, in `assets/clips/<name>.gif`. Over budget means shrink, not drop.
- Hero: one 2×3 collage `assets/screenshots/hero.jpg` (flightSim, voxel terrain, thirdPerson, fighter, platformer, OBJ car), with tiles labelled by example name.
- The Ultra is shared: check the current dev app before each sideload, and record what's left on it at the end.
- Never write device IPs, hostnames or credentials in commits, the PR or issues. Call devices "the Ultra".
- Don't read `.env`. rokubot reads it itself.
- No single-line `if` in any BrightScript (scratch example included).
- README links to the docs site stay absolute `https://markwpearce.github.io/brighterscript-game-engine/...`.
- #663 stays open (PR 1 says "Part of #663", not "Closes").

---

### Task 1: Guide accuracy audit

**Files:**
- Modify: whichever `docs/*.md` have discrepancies (all 19 guides are in scope).

**Interfaces:**
- Produces: corrected guides, plus a list of "too big to fix here" gaps for Task 7 to file.

- [ ] **Step 1: Dispatch 3 audit subagents in parallel** (`general-purpose`), one per group:
  - A: `game-engine-overview.md`, `engine-internals.md`, `drawables-and-scene-objects.md`, `launch-params.md`, `splash-screen.md`, `game-session.md`
  - B: `third-person-cameras.md`, `render-quality.md`, `voxel-terrain.md`, `scenegraph-shapes.md`, `loading-assets.md`, `saving.md`
  - C: `tile-maps.md`, `pathfinding.md`, `story.md`, `hud-widgets.md`, `ui-menus.md`, `controller-input.md`, `qr-codes.md`

  Brief for each:
  > Audit these guides in `/Users/mpearce/development/personal/brighterscript-game-engine/docs/` against the engine source in `src/source/` (namespace `BGE`): <list>. Check every class, method and field name, signature, default value, option-bag key and described behaviour. Check recent changes most closely: `ChaseCamera`/`FollowCamera`/`OrbitCamera`, `camera.zoom`/`zoomTo`, impostors/fog/occlusion, the splash screen, and the 0.9.0 changes (`git log --oneline v0.9.0~1..` if that tag exists, otherwise `git log --oneline -150`). Also read `.claude/rules/*.md` for the relevant subsystems. **Do not edit files.** Return a list: `docs/<file>:<line>`, what the guide says, what the code does, and the proof (`src/source/<file>:<line>`). Separately, list features that have no coverage in these guides at all. Report only discrepancies you have confirmed in the source.

- [ ] **Step 2: Apply each finding.** Open the cited source line, confirm it, then edit the guide. Write a short missing section (about 30 lines or less) inline when a feature isn't covered. Anything bigger goes on the Task 7 "file as issue" list.

- [ ] **Step 3: Check that links and frontmatter still hold**

  Run: `npm run docs 2>&1 | tail -20`
  Expected: the build completes with no new warnings about broken links. Every guide keeps `title`/`group: Guides`/`order`.

- [ ] **Step 4: Commit**

  ```bash
  git add docs/
  git commit -m "Docs: bring guides up to date with current APIs (#663)

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

### Task 2: Quick-taste snippet compiles, and the examples inventory

**Files:**
- Create then delete: `examples/zz-snippet-check/` (scratch, never committed)
- Produces: `out/examples-inventory.md` (git-ignored), with one line per example for Task 6

- [ ] **Step 1: Scaffold a scratch example**

  Run: `npm run create-example -- zz-snippet-check "Snippet Check"`

- [ ] **Step 2: Replace its source** with the README's three code blocks verbatim: `main()` in `src/source/main.bs`, `MainScene` in `src/source/MainScene.bs`, `Player` in `src/source/Player.bs`. Add `import` lines where a file uses another's symbols (CLAUDE.md requires this). Add a `pkg:/sprites/player.png` (copy any small png from another example).

- [ ] **Step 3: Validate**

  Run: `node scripts/examples.js validate zz-snippet-check` (if `examples.js` doesn't take a name filter, `cd examples/zz-snippet-check && npx bsc --project bsconfig.json --create-package false`)
  Expected: 0 errors. If it fails, fix the README snippet, not the scratch copy, and re-copy until it passes. Also compare with `examples/quickstart`, which the README says holds this exact code, and keep them in sync.

- [ ] **Step 4: Delete the scratch example**

  Run: `rm -rf examples/zz-snippet-check && git status --short examples/`
  Expected: nothing under `examples/` beyond what was there before (the untracked `examples/flightSim/package-lock.json`).

- [ ] **Step 5: Build the examples inventory.** For each folder in `ls examples/`, read its `README.md` (if any) and `src/source/main.bs` header comment. Write `out/examples-inventory.md` with `name | one-line "what it shows" | best still (if any)`. There are 29 folders today; check the count matches `ls examples | wc -l`.

- [ ] **Step 6: Commit** (only if Step 3 changed the README snippet or quickstart)

  ```bash
  git add README.md examples/quickstart
  git commit -m "README: keep the quick-taste snippet compiling (#663)

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

### Task 3: Capture stills on the Ultra

**Files:**
- Create: `assets/screenshots/{thirdPerson,flightSim,fighter,particles,voxelTerrain,objCar,visualnovel,ui}.jpg`
- Maybe replace: `assets/screenshots/{asteroids,platformer,rpg,snake,3d,terrain}.jpg`

- [ ] **Step 1: Install ffmpeg** (also needed by Tasks 4–5): `brew install ffmpeg && ffmpeg -version | head -1`

- [ ] **Step 2: Note what's on the Ultra:** `node node_modules/rokubot/dist/cli.js` with the skill's "what's running" command (see `.claude/skills/rokubot-examples/SKILL.md`). Record it in `out/shepherd-prs.md`-style notes at `out/docs-pass-notes.md`. Per memory, rokubot sideload and screenshot need the sandbox off and `NO_PROXY='*'`.

- [ ] **Step 3: For each example**, follow the rokubot-examples skill:
  1. Build and sideload: `npm run run-example -- <folder> splash=0` (`splash=0` skips the engine splash).
  2. Drive it to a strong frame:
     - flightSim: chase camera over the island, banking past a ring.
     - thirdPerson: character in the world with props and fog.
     - voxelTerrain: a different flightSim angle (low, looking across terrain), or the rendererTest voxel demo (`rendererTest demo=<voxel demo>`; grep `examples/rendererTest/src` for demo names).
     - objCar: the textured car OBJ (grep `examples/3d/src` and `examples/loading/src` for `.obj` to find which example and scene shows it).
     - fighter: mid-exchange, with the HUD.
     - particles: a dense effect.
     - visualnovel: a dialogue box over a background with a character.
     - ui: a menu with focus visible.
  3. Grab it full-res: `node node_modules/rokubot/dist/cli.js screenshot` (prints a path).
  4. Compress: `ffmpeg -y -i <shot> -q:v 4 assets/screenshots/<name>.jpg`, then `ls -l` it. If it's over about 100 KB, retry with `-q:v 6`.
  5. Look at the result (Read the jpg). Check it's title-safe, has no debug overlay, and doesn't have the black-frame capture glitch (retake if black).

- [ ] **Step 4: Review the 6 existing stills** against the new set. Reshoot any that look dated (the 3d cube is the likely one) the same way.

- [ ] **Step 5: Commit**

  ```bash
  git add assets/screenshots/
  git commit -m "Screenshots: fresh device captures of the 3D and newer examples (#663)

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

### Task 4: Record motion clips → GIFs

**Files:**
- Create: `assets/clips/{flightSim,thirdPerson,voxelTerrain}.gif` (+ `objModel.gif` if it reads well)

- [ ] **Step 1: Pick the capture card.** `mcp__carabiner__list_capture_devices` → `mcp__carabiner__select_capture_device` with the "USB3 Video" deviceId. `mcp__carabiner__take_screenshot` to confirm it shows the Ultra's output.

- [ ] **Step 2: For each clip:** sideload the example (`npm run run-example -- <folder> splash=0`). Get into position. Call `start_recording`, drive about 6 s with `send_key` or rokubot keydown/keyup holds (flightSim: gentle bank; thirdPerson: walk and turn the camera; voxel: slow fly-over), then `stop_recording`. Note the file path it returns.

- [ ] **Step 3: Convert** (trim to the best 4–6 s with `-ss`/`-t`):

  ```bash
  ffmpeg -y -ss <start> -t 5 -i <rec> -vf "fps=12,scale=640:-1:flags=lanczos,palettegen=stats_mode=diff" /tmp/pal.png
  ffmpeg -y -ss <start> -t 5 -i <rec> -i /tmp/pal.png -lavfi "fps=12,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" -loop 0 assets/clips/<name>.gif
  ls -l assets/clips/<name>.gif
  ```

  Over about 2 MB: drop to `scale=560`, then `fps=10`, then `-t 4`. Keep the exact commands used for the PR description.

- [ ] **Step 4: Check each GIF loops cleanly** (look at the first and last frames with `ffmpeg -i x.gif -vf "select=eq(n\,0)" -vframes 1 /tmp/f0.png` and Read it).

- [ ] **Step 5: Commit**

  ```bash
  git add assets/clips/
  git commit -m "Clips: device-recorded GIFs of the 3D examples (#663)

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

### Task 5: Hero collage

**Files:**
- Create: `assets/screenshots/hero.jpg`

- [ ] **Step 1: Build a labelled 2×3 grid** (each tile 640×360, 1920×720 total):

  ```bash
  F=/System/Library/Fonts/Supplemental/Arial\ Bold.ttf
  label() { echo "scale=640:360,drawtext=fontfile='$F':text='$1':x=16:y=h-th-16:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=8"; }
  ffmpeg -y \
    -i assets/screenshots/flightSim.jpg -i assets/screenshots/voxelTerrain.jpg -i assets/screenshots/thirdPerson.jpg \
    -i assets/screenshots/fighter.jpg -i assets/screenshots/platformer.jpg -i assets/screenshots/objCar.jpg \
    -filter_complex "[0]$(label flightSim)[a];[1]$(label 'voxel terrain')[b];[2]$(label thirdPerson)[c];[3]$(label fighter)[d];[4]$(label platformer)[e];[5]$(label 'OBJ models')[f];[a][b][c][d][e][f]xstack=inputs=6:layout=0_0|w0_0|w0+w1_0|0_h0|w0_h0|w0+w1_h0" \
    -q:v 5 assets/screenshots/hero.jpg
  ls -l assets/screenshots/hero.jpg
  ```

  If ffmpeg was built without `drawtext`, drop the labels from the image and put captions in the README under the hero instead.

- [ ] **Step 2: Read hero.jpg.** Check the labels are legible and the size is about 250 KB or less (raise `-q:v` if not).

- [ ] **Step 3: Commit** `assets/screenshots/hero.jpg`, with the message "README: hero collage (#663)" and the attribution line.

### Task 6: Rewrite the README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: stills (Task 3), GIFs (Task 4), `hero.jpg` (Task 5), `out/examples-inventory.md` (Task 2), and guide slugs from `docs/*.md` filenames (site URL `https://markwpearce.github.io/brighterscript-game-engine/<slug>` — confirm the URL pattern against the built `docs-site/` file names).

- [ ] **Step 1: Restructure top to bottom**, per spec §2:
  1. Badges (unchanged).
  2. `# BrighterScript Game Engine` + a two-sentence pitch: real 2D and 3D games on Roku (chase cameras, voxel terrain, textured models, tile maps, visual novels) in object-oriented BrighterScript; use the whole engine or just the renderer.
  3. `<img src="assets/screenshots/hero.jpg" alt="…">`, with alt text describing all six tiles.
  4. `## See it move`: one HTML row of the GIFs (`<a href="examples/<x>"><img src="assets/clips/<x>.gif" width="32%" alt="…"></a>`).
  5. `## Features`, grouped under **3D**, **2D and worlds**, **Game systems**, **Roku integration**, **Dev workflow**. One bullet per capability, each linking to its guide. It must cover the 3D renderer and Chase/Follow/Orbit cameras, voxel terrain, impostors/fog/occlusion, textured OBJ models, particles, tile maps, pathfinding, story/visual novel, QR-code phone controller, saving, HUD/UI widgets, SceneGraph hybrid, splash screen, and simulator support. Fold in the current "Why" bullets (OO lifecycle, renderer standalone, debug tooling, simulator); don't lose their content.
  6. `## A quick taste`: keep (as checked in Task 2).
  7. `## Examples`: a table with every folder from the inventory, columns `Example | What it shows | ` and a thumbnail `<img src="assets/screenshots/<x>.jpg" width="160">` where a still exists. Keep the `create-example` note.
  8. Cloning/Running, Installation, Known limitation, Documentation, Acknowledgements: keep, and refresh anything stale (e.g. the "work in progress, issue #63/#295" notes: check whether those issues are closed with `gh issue view 63 --json state`).
- [ ] **Step 2: Remove the old stacked `<figure>` blocks.**
- [ ] **Step 3: Check every relative link resolves:**

  ```bash
  grep -oE '(src|href)="[^"#h][^"]*"|\]\([^)#h][^)]*\)' README.md | sed -E 's/^(src|href)="//; s/"$//; s/^\]\(//; s/\)$//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING $p"; done
  ```

  Expected: no output.
- [ ] **Step 4: Commit** `README.md` with the message "README: hero, motion clips, feature map and full examples table (#663)" and the attribution line.

### Task 7: Site build, checks, follow-ups, PR

- [ ] **Step 1: Docs build.** Run `npm run docs`, then `ls docs-site/_assets | grep -E 'hero|gif|thirdPerson|flightSim'`. Expected: the new assets are copied. If the GIFs aren't, look at how `brighterscript-jsdocs-plugin` handles README images and fix it there (or note it in the PR if it's an upstream limit).
- [ ] **Step 2: Run `npm run check:all`.** Expected: it passes. Paste the tail of the output into the notes.
- [ ] **Step 3: File the follow-ups.** Check `gh issue list --search "<keywords>"` for each first to avoid duplicates.
  - "Docs pass part 2: images in the guides" (body: the guide list from #663's "Guides" section, minus anything PR 1 covered), label `documentation`.
  - One issue per too-big gap from Task 1.
  - Comment on #663 linking them.
- [ ] **Step 4: Push and open the PR:** `git push -u origin docs/663-docs-pass`, then `gh pr create --base main`. Write the body with the pr-voice skill: "Part of #663", a summary, inline hero + GIF previews, the ffmpeg commands, the guide fixes list, the device used ("the Ultra"), and what's left on it. End with the Claude Code attribution line.
- [ ] **Step 5: Record what's on the Ultra** in the PR description.
