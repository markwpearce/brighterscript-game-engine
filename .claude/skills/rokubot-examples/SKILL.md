---
name: rokubot-examples
description: Drive brighterscript-game-engine example apps on a real or simulated Roku via rokubot (sideload, launch, act/screenshot loop). Use when asked to run, test, demo, or "play" one of the examples/* apps, or to explore what an example does.
---

# Driving BGE examples with rokubot

`rokubot` (npm, `^0.3.0`, installed as a devDependency of this repo) is a CLI for driving any
Roku device over ECP: sideload, launch, press keys, screenshot, stream the debug console. It's
the tool to use whenever a task requires actually running one of `examples/*` rather than just
reading/editing its source.

## Setup

- Device credentials live in `.env` at the repo root as `ROKU_HOST`/`ROKU_PASSWORD` — **do not
  try to read `.env`**, it's blocked by a harness-level guardrail (even a value-free `grep` for
  key names gets denied). Export the two vars yourself for the session instead:
  `export ROKU_HOST=... ROKU_PASSWORD=...` (ask the user for values if not already known in the
  conversation — e.g. brs-desktop, the BrightScript Simulator, is commonly `127.0.0.1` /
  `rokudev`).
- rokubot needs its `dist/` built — `npm install` at the repo root handles this automatically
  now (it has a `prepare` script as of rokubot 0.1.1+). If `node_modules/rokubot/dist` is ever
  missing, `cd node_modules/rokubot && npm install && npm run build`.

## Fast act/screenshot loop

The naive `npx rokubot <cmd>` loop is slow enough (~1s/call, mostly npx resolution overhead) that
a real-time game's state can visibly race ahead of you between calls. Speed it up:

1. **Call the built CLI directly**, skip npx: `node node_modules/rokubot/dist/cli.js <cmd>`
   (~0.3s vs ~1s per call).
2. **Use `--action keydown` / `--action keyup` holds** instead of many discrete `press` calls to
   cover more distance per round trip (e.g. hold `down` for 150-250ms instead of pressing it 3
   times).
3. **Downsample screenshots with the built-in `--scale` flag** — don't shell out to `sips`/
   ImageMagick, `screenshot --scale 0.25` (or `press <key> --screenshot --scale 0.25`) does it
   server-side. Full-res captures are 1280x720; for picking the next action you rarely need more
   than a couple hundred px wide.
4. **`press <key> --screenshot`** combines the action and the follow-up screenshot into one
   rokubot invocation — use it instead of two separate calls whenever you're about to look right
   after acting. `text <string> --screenshot` does the same for typed input.
5. **`press` takes multiple keys in one call**, e.g. `press up up select`, with `--delay` (default
   0.25s) controlling the pause between each and — combined with `--screenshot` — after the last
   one before capturing. Use this for a known sequence instead of N separate invocations.

zsh gotcha: **never name a shell variable `path`** — in zsh it's a special array kept in sync
with `$PATH`, and assigning to it (e.g. `path=$(rbot screenshot ...)`) silently breaks every
subsequent command in the same shell (`command not found` for things that were on PATH a moment
ago). Use `shotpath` or similar instead.

## Figuring out an app's controls — general method

This applies beyond this repo, too: the same rokubot loop drives *any* Roku channel, including
ones you have no source for. Work down this list — each step is cheaper/more reliable than the
next, so don't skip ahead to blind probing if a cheaper signal is available:

1. **Screenshot before touching anything, and read it carefully.** Some apps put their own
   control legend on screen (this repo's `canvas` and `3d` examples do, literally spelling out
   "Move Camera: Arrows | Change Scene: <</>>"). That's free, exact information — always look
   first.
2. **If you have source, grep it — don't trial-and-error.** For BGE apps specifically:
   ```
   grep -rn "onInput\|isButton" examples/<name>/src/source/ | grep -v node_modules
   ```
   This gives you the *engine's internal* button name — as of rokubot 0.3.0 it accepts BGE's own
   names directly as aliases (see below), so this is much less of a trap than it used to be, but
   still worth knowing about for the one name (`"audioguide"`) with no ECP equivalent.
3. **If you don't have source (a real third-party channel, a black-box build), probe
   systematically instead of randomly.** Go through the full ECP key set in a fixed order —
   `select`, `up`, `down`, `left`, `right`, `back`, `play`, `rev`, `fwd`, `instantreplay`, `info`,
   `enter`, `search`, `backspace` (skip `home`, it exits the channel) — sending each with
   `press <key> --screenshot` and diffing against the previous frame. Note three distinct
   outcomes per key, not just "worked/didn't": *visible change*, *silently ignored* (device
   accepted it, nothing in the app responds), and *no-op because it's the wrong key entirely*.
   Try `select` first — most apps gate everything else behind a "press OK to start" / menu
   screen. Try `info` early too, since a debug/overlay toggle on that button is a common
   convention (it is in this engine) and unlocks free diagnostic info (FPS, entity/collider
   counts) for the rest of your exploration.
4. **Don't mistake "invisible but working" for "dead."** A control can be doing something real
   with no visible effect in a screenshot — this repo's `canvas` example pans/scales the game
   canvas correctly, but everything on screen is drawn on a separate UI layer that isn't affected,
   so it *looks* like nothing happened. Similarly, movement systems built on holding a direction
   (velocity set per-frame while held) will show nothing from one `press`/`keypress` tap — retry
   with a `keydown`...`keyup` hold before concluding a direction is unmapped.
5. **When there's a multi-room/multi-scene app, map the whole navigation graph before trusting
   one screenshot.** Grepping a single room's `onInput` (or watching one button press produce "no
   change") isn't enough evidence that a scene-change control is broken — the button might have
   landed you on a room whose default camera/framing just doesn't look different at a glance, or
   the navigation might not be a simple cycle. Grep every room file for `changeRoom(` calls and
   build the actual graph:
   ```
   grep -n "changeRoom" examples/<name>/src/source/Rooms/*.bs
   ```
   This repo's `pixels` example is a good example of why this matters: it looked like it should
   cycle through 4 rooms, but the real graph (before this was fixed) was
   `GhostRoom → RectangleRoom → PolygonRoom → SpriteRoom → PolygonRoom` (looped there) — and since
   the app's actual start room was `PolygonRoom`, `GhostRoom` and `RectangleRoom` were unreachable
   from the running app via any button at all. That would only ever have been found by reading
   every room's `changeRoom` calls, not by pressing buttons and hoping — it's fixed now (see the
   `pixels` row below), but the lesson generalizes to any new multi-room app you're exploring.
6. **Write down what you learn as you go**, even mid-exploration — rokubot's own README describes
   this same screenshot→act→screenshot loop as a way to build up a `SKILL.md` for whatever app
   you're driving (`rokubot skill init` scaffolds one). Future you (or another agent) shouldn't
   have to re-derive the same control scheme from scratch.

### BGE button names vs rokubot/ECP key names

`GameInput.isButton("...")` checks against BGE's own button-name table
(`src/source/utils/utils.bs`, `buttonNameFromCode`) — historically **not** the same string
rokubot expected on the command line (e.g. BGE's `"options"` vs. the real ECP key `info`), which
cost real time earlier: pressing the literal string `"options"` used to send an ECP key of that
name, which the device just silently ignored — indistinguishable from "nothing changed" due to an
unrelated bug.

**As of rokubot 0.3.0 this is fixed both ways:** `press` is now case-insensitive and accepts
common aliases (`ok`, `ff`/`forward`/`fastforward`, `rw`/`rewind`, `options`/`*`, `replay`, plus
several others — run `press --help` for the live list), so BGE's own `isButton(...)` strings now
work directly as rokubot arguments in every case that mattered here. *And* an unrecognized key
now errors immediately with the full valid-key/alias list instead of silently no-op'ing — so a
typo or wrong name is caught right away rather than looking like an app bug. The one BGE name
still without an ECP equivalent is `"audioguide"`.

Bottom line: you can generally just pass BGE's `isButton(...)` string straight to `press` now.
The mapping (canonical rokubot key ← BGE name) for reference: `select`←OK, `instantreplay`←replay,
`rev`←rewind, `fwd`←fastforward, `info`←options, plus the obvious `up`/`down`/`left`/`right`/
`back`/`play`.

## Building & sideloading an example

Use the repo's own fan-out scripts rather than hand-rolling `bsc`/zip calls:

- `npm run build-examples` (repo root) — builds the engine, then runs `npm run package` in every
  `examples/*` dir, producing `examples/<name>/out/bge-<name>.zip`. A failure in one example
  doesn't stop the others.
- Sideload **that zip**, not the loose `examples/<name>/build/` directory — sideloading the
  unpacked `build/` dir has produced stale/inconsistent state in past sessions (missing assets,
  a paddle-position crash) that the proper packaged zip didn't reproduce. If you only need one
  example, `cd examples/<name> && npm run package` builds just that zip.

```
node node_modules/rokubot/dist/cli.js sideload ./examples/<name>/out/bge-<name>.zip --deleteDevChannel --host $ROKU_HOST --password $ROKU_PASSWORD
node node_modules/rokubot/dist/cli.js launch dev --host $ROKU_HOST --password $ROKU_PASSWORD
```

(`--host`/`--password` can be omitted once `ROKU_HOST`/`ROKU_PASSWORD` are exported.)

## Debugging a crash or unresponsive screen

If a screenshot looks frozen/unchanged across several actions, don't assume rokubot is broken —
the app may have crashed into the BrightScript Micro Debugger, which just keeps showing the last
rendered frame. Check directly instead of guessing:

```
node node_modules/rokubot/dist/cli.js debugger-state
```

This tells you paused-at-breakpoint vs. idle/unchanged in one call — no more manually streaming
`console` for a few seconds and grepping for the debugger prompt. `active-app` is still useful
alongside it to confirm which app is in the foreground.

Two crashes seen so far, for reference:
- `asteroids` on brs-desktop (the BrightScript Simulator): background bitmap is a `.jpg`
  (`spacebackground.jpg`) and fails to decode (`loadBitmap()` logs "Bitmap not created"), which
  then null-derefs in `MainRoom.onCreate`. Looked simulator-specific (JPEG decode support), not
  an engine or rokubot bug — untested on real hardware.
- Sideloading the loose `build/` dir (vs the packaged zip) has crashed `pong` on
  `Paddle.brs` reading a bitmap's width before it's loaded — another reason to always sideload
  the packaged zip.

To get out of a paused debugger, `console --send "exit"` (or just `press home` to force-quit the
channel back to Home).

## What each example actually is

| Example | What it is | Controls (BGE name → rokubot key) |
| --- | --- | --- |
| `pong` | Playable 2-paddle pong vs. a same-speed, zero-latency CPU. Ball always spawns dead-center; `MainRoom`/`Ball.bs`/`Computer.bs` are short reads. | `up`/`down` move paddle, `select` (OK) at title screen starts, `back` quits, `info` (options) toggles debug overlay |
| `asteroids` | Ship-vs-asteroids splash + gameplay. Crashes on brs-desktop (see above) — background JPEG fails to load. | untested past splash on simulator |
| `snake` | Real playable snake: red = food, green segments = snake, score counter. Title screen is "Press OK To Play". | `select` starts, `up`/`down`/`left`/`right` steer, `play` pauses (`PauseHandler`), `back` quits, `info` toggles debug |
| `3d` | Multi-room 3D renderer showcase — `ImagesRoom` (start), `TextRoom`, `ModelRoom`, `CubesRoom`, `PolyRoom`, `TreesRoom`, cycled in that fixed order (`getRoomNames()` in `main.bs`) and wrapping around. Self-documents its own controls on screen. Confirmed live: `fwd` does advance rooms — a single press from `ImagesRoom` lands on `TextRoom`, whose default camera framing just doesn't show anything eye-catching, which can look like "nothing happened" if you only check one press. | `select` (OK) = per-entity rotation toggle, `info` (`*`) = change rotation axis, arrows = move/rotate camera, `rev`/`fwd` (`<`/`>`) = prev/next room, `instantreplay` = toggle debug info, `play` = change draw mode/wireframe |
| `pixels` | Multi-room draw-mode/sprite showcase. Room graph was fixed (was previously a broken 2-cycle orphaning 2 of the 4 rooms — see git history) to match `3d`'s pattern: `getRoomNames()`/`goToNextRoom()` in `main.bs`, cycling `PolygonRoom → RectangleRoom → SpriteRoom → GhostRoom → PolygonRoom`, confirmed live in both directions. | From any room: `fwd`/`rev` = next/previous room. `PolygonRoom`: `select` (OK) = regenerate shapes, `info` (options) = cycle `SceneObjectDrawMode` 1-7, `up`/`down` = change shape count. `RectangleRoom`: `select` = regenerate, `info` = recolor, `up`/`down` = change grid size. `SpriteRoom`/`GhostRoom`: `select` = add more sprites/ghosts |
| `canvas` | Demonstrates panning/scaling the whole game **canvas** (offset/scale), not an on-screen entity. On-screen text/rectangle are drawn on the separate UI layer, so the pan/scale effect isn't visible in a screenshot even though it's working — don't mistake that for a bug. | arrows = pan canvas, `info`/`instantreplay` = scale up/down, `play` = re-center |
| `quickstart` | Minimal scaffold-template app: one white square, moves freely. Good smoke-test for "is the toolchain working." | arrows (any direction, free movement via `input.x`/`input.y`) |
| `rendererTest` | Categorized, menu-driven suite of `BGE.Renderer` demos - deliberately **not** built on `BGE.Game`/`Room` (see `CLAUDE.md`'s "Manually exercising the Renderer" note for the architecture and how to add a new demo). Grouped by category on an on-screen menu. | `up`/`down` = select in menu, `select` (OK) = run selected demo / demo-specific action, `back` = return to menu. Can also skip the menu entirely via a launch param: `rokubot launch dev --param demo=<id>` (see `DemoList.bs` for valid ids) |
| `hybrid` | Fixed (was previously broken — stale `getImage` call). Now: SceneGraph side plays a sample video; roScreen/BGE side is a ball-to-target minigame that switches back to SceneGraph on collision. | Ball game: arrows move the ball, reaching the green target switches to video. `back` (either side) toggles/quits |
