# examples/platformer design

Closes: #62

## Goal

Add `examples/platformer` — a side-scrolling platformer (run, jump, land on
platforms, scrolling level, collectibles, a stompable patrolling enemy, a
goal). This is the example most likely to surface real engine gaps, because
platformers need things the engine doesn't provide out of the box: gravity,
grounded state, and collision *resolution* (the engine's `Collider`/
`onCollision` only reports that two colliders overlapped — no normal,
penetration depth, or contact point).

Per the original issue, collision resolution is built **in the example
first**. Whatever comes out of it that's clearly generic gets filed as
separate engine issues afterward — this spec does not propose engine changes.

## Scope

Full scope in one pass (not split into milestones):

- Player: run, jump (variable height by hold duration), fall, land, grounded
  state, coyote time, jump buffering, squash/stretch animation.
- A level several screens wide, authored as string-array tile data.
- Solid ground/platforms and at least one one-way platform.
- Coins (collectible) and a patrolling enemy (stompable from above, costs a
  life otherwise).
- Scrolling camera following the player, clamped to level bounds.
- A goal that completes the level; a HUD (score, lives) via `gameUi`.
- Sound effects (jump/coin/stomp) via `Game.Sounds`.
- Landing/jump dust and coin/stomp particle bursts via `DrawableParticles`.
- Analog-stick/gamepad movement in addition to the Roku remote d-pad.
- A UI-subsystem menu flow: title/start screen, pause menu, win/game-over
  screens (all `BGE.UI`, not ad hoc `drawText` overlays).

Out of scope (unchanged from the issue): a tilemap file format or editor,
general-purpose physics, multiple levels/save progression, real Mario art.

## Architecture

### Level data (`LevelData.bs`)

The level is one or more string rows (top row = top of level), one character
per tile column. A legend maps characters to meaning:

| Char | Meaning |
|------|---------|
| `#`  | Solid tile (blocks from every side) |
| `-`  | One-way platform (land on top only, pass through from below/side) |
| `o`  | Coin spawn |
| `e`  | Enemy patrol spawn |
| `P`  | Player spawn |
| `G`  | Goal spawn |
| `.`  | Empty |

Tile size is a constant (e.g. 32px) shared by `LevelData` and every entity
that spawns from it, so grid coordinates convert to world positions with one
multiply.

### `Level` (GameEntity, one instance per room)

Built by `MainRoom` from `LevelData`: for each `#`/`-` character, adds one
named rectangle collider (`"tile_<row>_<col>"`) and one matching rectangle
drawable at that grid cell, tagged `"solid"` or `"oneWay"` via the collider's
own `tagsList`. `Level` itself never moves — it exists purely so the static
layout doesn't cost one `GameEntity` (and its per-frame `onUpdate`/`onInput`
dispatch) per tile. `GameEntity.colliders` is already a plain name-keyed map
(`GameEntity.bs:316`), so this needs no engine change.

### `Player` (GameEntity)

Fields: `velocity` (existing), `grounded` (bool), `coyoteTimer`,
`jumpBufferTimer`, `positionBeforeMove` (snapshot, see below).

Per-frame flow:
1. `onControls(controls as BGE.Controller.ControlMap)` (called once per frame,
   before `onUpdate` — see **Input** below): read horizontal move from
   `controls.getAxis("move").x` and jump from `controls.isActionPressed("jump")`/
   `isActionHeld("jump")`. Store the resulting intent on fields the same-frame
   `onUpdate` reads, rather than setting velocity directly here, so the
   physics step stays in one place.
2. `onUpdate(dt)`: snapshot `m.positionBeforeMove = clone(m.position)` *before*
   anything else runs this frame (the engine applies `velocity * dt` to
   position after `onUpdate` returns, so this captures true pre-move state).
   Apply gravity (`velocity.y -= GRAVITY * dt`, clamped to a terminal
   velocity so a single frame's fall never exceeds one tile — the simple
   mitigation for tunneling the issue suggests, no substepping needed).
   Apply the horizontal/jump intent read in `onControls`: run speed, jump (if
   grounded or within coyote time; buffer a jump press briefly if airborne so
   a press just before landing still fires), variable jump height by cutting
   `velocity.y` if the button releases early. Decrement `grounded` unless
   refreshed this frame by `onCollision` (see below) — i.e. `grounded` starts
   each frame assumed false and `onCollision` sets it true when applicable.
3. Engine integrates `position += velocity * dt`.
4. `onCollision(myCollider, otherCollider, otherEntity)`: only acts when
   `otherEntity` is the `Level` (checked via a stable identity, e.g.
   `otherEntity.name = "Level"` — never `=` two entity references, per this
   repo's own `=`-operator gotcha). Compares `positionBeforeMove` against the
   tile collider's world bounds (`otherCollider.offset`/`width`/`height`,
   plus `otherEntity.position`, which is fixed) and `velocity`'s sign to
   infer which side was hit:
   - Falling (`velocity.y <= 0`) and was above the tile last frame → landed
     on top: push position up to rest on the tile, `velocity.y = 0`,
     `grounded = true`, trigger landing squash + dust particles if fall speed
     was above a small threshold.
   - Rising (`velocity.y > 0`) and was below the tile last frame → hit head:
     push down, `velocity.y = 0`.
   - Otherwise (horizontal): push out along X opposite `velocity.x`'s sign,
     `velocity.x = 0`.
   - If `otherCollider` is tagged `"oneWay"`, only the "landed on top" case
     applies — any other case is ignored entirely (no push, no velocity
     change), letting the player pass through from below/the side.

This mirrors `examples/breakout`'s `Ball.onCollision` idiom (naive velocity
flip) but generalizes it to depenetration + side detection, which is the
"hard part" called out in the issue.

### `Coin` (GameEntity)

A small entity with its own circle or rectangle collider. On collision with
the player: increments score (via a shared HUD/score field the `MainRoom`
or player owns), plays a sound, spawns a brief sparkle particle burst at its
position, then destroys itself.

### `Enemy` (GameEntity)

Patrols between two x-bounds at constant velocity, reversing direction at
each bound (or on hitting a `Level` wall collider, reusing the same
`otherEntity`-is-`Level` check as `Player`). On colliding with `Player`:
if the player's `positionBeforeMove.y` was above the enemy's top *and*
`Player.velocity.y <= 0` (a stomp, same "landed on top" test as tile
resolution) → play stomp sound + poof particle burst, destroy the enemy,
give the player a small upward bounce. Otherwise → player loses a life,
resets to the last checkpoint/spawn.

### `Goal` (GameEntity)

A trigger collider (not tagged `"solid"`, so nothing else resolves against
it). On colliding with `Player`: completes the level, which shows the win
screen (see **Menu system** below).

### `MainRoom`

- Parses `LevelData` into a `Level` entity plus spawned `Player`/`Coin`/
  `Enemy`/`Goal` entities from the legend's spawn characters.
- Each frame (or via a lightweight camera-follow entity), computes the
  camera target from the player's position, clamps it to
  `[levelHalfWidth - halfScreenWidth, ...]` (manual min/max — `Camera2d`
  doesn't clamp itself), then calls `camera.setTarget(...)`.
- Owns a `gameUi` HUD (score, lives) and hosts the pause/win/game-over
  overlays (see **Menu system** below).

## Input

Both the Roku remote d-pad and an analog stick/gamepad drive the player
through the same code path — `BGE.Controller.ControlMap`, the engine's
existing unified input layer (confirmed current: `ControlMap.getAxis()`
already has a remote-d-pad fallback built in, so a bound axis "just works"
from the physical remote with no separate d-pad-handling code path needed).

- `main.bs` calls `game.controls.bindAxis("move", "1", 0)` for horizontal
  movement and `game.controls.bindAction("jump", <remote button>, <controller
  button>)` for jump, following `examples/controller`'s existing convention.
- `game.enableControllerInput()` is called so a connected phone/web
  controller (the existing WebSocket controller protocol, `examples/controller`)
  can drive movement/jump too — the same axis/action bindings serve both
  input sources with no extra code.
- `Player` reads both through `onControls()` (see above) rather than raw
  `onInput()`, so it never special-cases which device produced the input.
- Anything not part of moving the player (menu navigation, pause toggle)
  goes through the normal `BGE.UI` focus system / `onInput`, unaffected by
  this axis/action binding.

## Menu system

All menus are `BGE.UI` (`UiContainer`/`Button`/`Label`), using the engine's
default `list`-mode focus navigation (Up/Down/OK) — no ad hoc `drawText`
overlay menus, upgrading past `examples/breakout`'s bare "Paused" text (see
`PauseHandler.bs` there) for this example specifically.

- **`TitleRoom`** (the room `main.bs` starts in): a `UiContainer` with a
  "Start Game" `Button` (and a brief control-hint `Label`). OK/click
  → `game.changeRoom("MainRoom")`.
- **Pause menu**: a persistent, non-pauseable entity (following the existing
  `PauseHandler` pattern from `breakout`/`snake`/`asteroids`) toggles a
  `UiContainer` (Resume / Restart Level / Quit to Title `Button`s) into
  `gameUi` on a pause button press, and calls `game.pause()`/`game.resume()`
  in step with showing/hiding it — `Game.pause()` already freezes entity
  update/movement/collisions while leaving `gameUi` input processing
  running (confirmed: `processUiInput` runs unconditionally every frame,
  independent of `m.paused`), so the pause menu stays interactive while
  gameplay is frozen with no engine change needed.
- **Win / game-over screens**: a `UiContainer` shown on reaching `Goal` or on
  losing the last life, each with a message `Label` and Retry/Quit-to-Title
  `Button`s.

## Squash/stretch

Driven entirely by `Player` state transitions, using `Game.tweenManager.to()`
on `m.scale` (a real `BGE.Math.Vector` field on every `GameEntity`) — no
engine change needed:
- Jump takeoff: tween `scale` to a stretched `{x: 0.8, y: 1.25}` briefly.
- Airborne (apex/fall): ease back toward `{x: 1, y: 1}`.
- Landing: a quick squash `{x: 1.3, y: 0.7}`, tweening back to `{x: 1, y: 1}`.

## Particle effects

Via `DrawableParticles`/`SceneObjectParticle` (existing engine feature, see
`specs/2026-08-18-particle-system-design.md`), each a short-lived one-shot
burst (stationary emitter + `velocitySpreadMagnitude` for a radial puff,
`start()` then `stop()` after one burst):
- Landing dust: on `Player` landing with fall speed above a small threshold.
- Jump dust: on `Player` takeoff.
- Coin sparkle: on `Coin` pickup, at its position, before it's destroyed.
- Stomp poof: on `Enemy` being stomped, replacing it at its position.

## Placeholder art & audio

I can't generate new image/audio files myself, so this example is built
entirely from assets already in the repo (reused across an `examples/`
directory boundary, copied into `examples/platformer/src/`) plus plain
procedural `Drawable` shapes — no new files need to be sourced to start:

- **Background**: `examples/parallax/src/sprites/parallax-mountain-bg.png`
  (dusk sky, CC0-licensed per that example's own `CREDITS.md`) as a single
  static backdrop — not scrolled/layered, to keep scope minimal.
- **Solid ground/platform tiles** (`#`): `examples/terrain/src/sprites/grass.png`
  (a tileable grass texture) drawn per tile cell.
- **One-way platforms** (`-`): a flat-colored `DrawableRectangle` (a distinct
  wood-brown tone), visually distinguishing them from solid tiles without
  needing a new texture.
- **Player**: `examples/pixels/src/sprites/walkingsprite.png`'s first sprite
  row (a 9-frame side-view run cycle, 144x144px/frame) via `AnimatedImage`
  for running; idle/airborne use a single static frame from the same sheet,
  with squash/stretch (scale tweens) carrying the jump/land read instead of
  dedicated jump/idle frames. This asset has no `CREDITS.md` in `examples/pixels`
  but was authored directly in this repo's own history (added by the repo
  owner in 2021) — flagging that provenance rather than assuming it's fine
  to redistribute; **please confirm this is OK to reuse, or supply a
  replacement, before this ships.**
- **Coin**: a filled `DrawableCircle` (gold/yellow).
- **Enemy**: a filled `DrawableRectangle` or `DrawableCircle` (a distinct
  red/orange), simple geometric "creature".
- **Goal**: a `DrawablePolygon` flag shape or a distinct-colored rectangle.
- **Particles**: built-in `ParticleShape.Rectangle`/`.Line` shapes (no image
  needed) for dust/sparkle/poof bursts, matching the shapes already used as
  `DrawableParticles`' non-image defaults.
- **Sound effects**, all reused from existing example sound assets (the same
  generic `.wav`s already shared across most examples):
  - Jump: `examples/pong/src/sounds/hit.wav`
  - Coin pickup: the generic `score.wav` (present in most examples)
  - Enemy stomp (impact): `hit.wav`
  - Player loses a life: the generic `die.wav`

If you'd rather supply dedicated art (tile textures, a proper player sprite
sheet, enemy/coin sprites) or audio, drop the files in and I'll wire them up
in place of the reused/procedural placeholders above — nothing here blocks
starting implementation.

## Testing / verification

- Rooibos coverage is not the primary signal here — per this repo's own
  convention, automated tests don't exercise example entity/room code
  (`feedback_static_analysis_insufficient_for_examples`). `npm run check`/
  `npm run validate-examples` catch compile/type errors only.
- Real verification is an actual sideload/run: use the `rokubot-examples`
  skill for scripted smoke checks (level loads, entities spawn, no crash),
  then a human playtest for feel (jump arc, coyote time, one-way platform
  behavior, squash/stretch timing) — platformer feel can't be judged from
  act→screenshot latency.

## Documentation follow-up

- Add `examples/platformer` to `README.md`'s example table/screenshot
  gallery and `docs/game-engine-overview.md`'s sample-channel list, and
  reference it from that guide's collision section as the first example
  doing real collision *resolution* (not just detection).

## Engine-issue extraction candidates (file after building, not before)

Watch for these while implementing, and file as separate engine issues only
if they turn out genuinely reusable beyond this one example:
- A `gravity`/`acceleration` field on `GameEntity`.
- A generic depenetration/`resolveAgainst()` helper.
- Richer `onCollision` arguments (contact normal, penetration depth).
- A "grounded" convenience on `GameEntity`/`Collider`.
