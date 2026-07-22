---
name: rokubot-examples
description: Drive brighterscript-game-engine example apps on a real or simulated Roku via rokubot (sideload, launch, act/screenshot loop). Use when asked to run, test, demo, or "play" one of the examples/* apps, or to explore what an example does.
---

# Driving BGE examples with rokubot

`rokubot` (npm, `^0.2.0`, installed as a devDependency of this repo) is a CLI for driving any
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
3. **Downsample screenshots before reading them** — full-res captures are 1280x720; for picking
   the next action you rarely need more than a couple hundred px wide. `sips -Z 320 <in> --out
   <out>` (macOS built-in) cuts file size ~10x and is much faster for you to read.
4. **`press <key> --screenshot`** combines the action and the follow-up screenshot into one
   rokubot invocation — use it instead of two separate calls whenever you're about to look right
   after acting.

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
   This is fast and exact, but it gives you the *engine's internal* button name, not necessarily
   the string rokubot/ECP expects — see the translation table below before you conclude a control
   "does nothing."
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
   This repo's `pixels` example is a good example of why this matters: it looks like it should
   cycle through 4 rooms, but the real graph is
   `GhostRoom → RectangleRoom → PolygonRoom → SpriteRoom → PolygonRoom` (loops there) — and since
   the app's actual start room is `PolygonRoom`, **`GhostRoom` and `RectangleRoom` are unreachable
   from the running app via any button at all.** You'd only ever find that by reading every room's
   `changeRoom` calls, not by pressing buttons and hoping.
6. **Write down what you learn as you go**, even mid-exploration — rokubot's own README describes
   this same screenshot→act→screenshot loop as a way to build up a `SKILL.md` for whatever app
   you're driving (`rokubot skill init` scaffolds one). Future you (or another agent) shouldn't
   have to re-derive the same control scheme from scratch.

### BGE button names vs rokubot/ECP key names — they don't match

This is the specific case of step 2 above biting hardest in this repo: `GameInput.isButton("...")`
checks against BGE's own button-name table (`src/source/utils/utils.bs`,
`buttonNameFromCode`), which is **not** the same string rokubot expects on the command line.
Translate using this table:

| BGE `isButton(...)` name | rokubot / ECP key | Roku remote button |
| --- | --- | --- |
| `"back"` | `back` | Back |
| `"up"` / `"down"` / `"left"` / `"right"` | `up` / `down` / `left` / `right` | D-pad |
| `"OK"` | `select` | OK / center button |
| `"replay"` | `instantreplay` | Instant Replay |
| `"rewind"` | `rev` | Rewind |
| `"fastforward"` | `fwd` | Fast Forward |
| `"options"` | `info` | Options (the `*` button) |
| `"play"` | `play` | Play/Pause |
| `"audioguide"` | (no standard ECP key in rokubot) | — |

The `"options"`/`info` mismatch is the one most likely to bite: pressing rokubot's literal string
`"options"` sends an ECP key of that name, which the device just silently ignores (no error,
nothing happens) — it looks identical to "nothing changed" from an unrelated bug. Always map
through this table rather than assuming rokubot's key name matches the BGE source string.

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
check `active-app` and the debug console first; the app may have crashed into the BrightScript
Micro Debugger, which just keeps showing the last rendered frame:

```
node node_modules/rokubot/dist/cli.js active-app
node node_modules/rokubot/dist/cli.js console   # streams; Ctrl+C or `kill` after a few seconds
```

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
| `pixels` | Multi-room draw-mode/sprite showcase. **The room graph is not a simple cycle** — confirmed by grepping every room's `changeRoom` calls: `GhostRoom → RectangleRoom → PolygonRoom → SpriteRoom → PolygonRoom` (loops there). The app starts at `PolygonRoom`, so `GhostRoom` and `RectangleRoom` are never reachable from the running app via any button — only `PolygonRoom`/`SpriteRoom` are actually visitable in practice. | From `PolygonRoom`: `select` (OK) = regenerate/randomize shapes, `info` (options) = cycle `SceneObjectDrawMode` 1-7, `up`/`down` = change shape count, `fwd` (fastforward) = advance to `SpriteRoom`. From `SpriteRoom`: `select` = add more sprites, `fwd` = back to `PolygonRoom` |
| `canvas` | Demonstrates panning/scaling the whole game **canvas** (offset/scale), not an on-screen entity. On-screen text/rectangle are drawn on the separate UI layer, so the pan/scale effect isn't visible in a screenshot even though it's working — don't mistake that for a bug. | arrows = pan canvas, `info`/`instantreplay` = scale up/down, `play` = re-center |
| `quickstart` | Minimal scaffold-template app: one white square, moves freely. Good smoke-test for "is the toolchain working." | arrows (any direction, free movement via `input.x`/`input.y`) |
| `rendererTest` | A scratch app for manually testing one-off renderer changes — not a stable demo of any one feature, and had nothing on screen (blank white canvas) in the state we found it. Check `main.bs` for whatever is currently wired up before relying on it. | varies / check source |
| `hybrid` | **Skip.** Fresh build fails: `Ball.bs:62` calls `getImage`, which doesn't exist on `GameEntity`/`Ball` (looks like a stale API call from an engine rename). Its `out/bge-hybrid.zip` is a stale pre-existing build from Feb; don't rely on it. | — |
| `terrain` | **Can't build at all right now** — the example directory has no `package.json`/`bsconfig.json`/`manifest`, only `src/`, `build/`, and `node_modules/`. Looks like an incomplete/broken scaffold, not something rokubot can sideload as-is. | — |
