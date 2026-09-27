# examples/rpg — Slice A: World (design)

Issue: #63. This is the first of three slices of a *Link to the Past*-style action RPG example:

- **Slice A — World (this spec):** auto-tiled tile map from real art, free movement with wall sliding, depth-sorted props, clamped scrolling camera, a door transition between two areas.
- **Slice B — Combat:** sword swing, enemies, health, knockback, hearts HUD. Own spec/PR.
- **Slice C — RPG layer:** NPC dialogue, pickups + inventory, quest flag via `onGameEvent`, save/load via registry. Own spec/PR.

The example is a reference to read, not a game to finish: two small areas, one player character.

## Goals

- Free (non-grid) 8-directional movement that slides along walls and nudges around corners.
- Ground built from the two supplied tile sheets, auto-tiled from readable character-grid map data.
- *Link to the Past*-style depth: the player walks behind the upper part of tall props and in front of their base.
- A camera that follows the player and never shows past the map edge.
- Two areas (town overworld, castle interior) joined by a door, using `changeScene()` + a `persistent` player.

## Non-goals (this slice)

Combat (including the attack animations), NPCs, dialogue, inventory, save/load, quest flags, sound/music, inner-corner auto-tiles, a tilemap file format or editor (Tiled support is #196), any engine changes.

## Assets and licensing

Two 512×512 sheets on a 32px grid, copied into `examples/rpg/src/sprites/`:

- `PathAndObjects.png` — [RPG Tiles: Cobble Stone Paths & Town Objects](https://opengameart.org/content/rpg-tiles-cobble-stone-paths-town-objects). Zabin, Daneeklu, Jetrel, Hyptosis, Redshrike, Bertram. CC-BY-SA 3.0 (Hyptosis's grass/cliff/water elements CC-BY 3.0).
- `Castle2.png` — [Castle Tiles for RPGs](https://opengameart.org/content/castle-tiles-for-rpgs). Zabin, Hyptosis, Daniel Cook. CC-BY 3.0.

Player character: **FREE Adventurer 2D Pixel Art** by Mattz Art ([xzany.itch.io](https://xzany.itch.io/); the free edition of [Adventurer 2D Top-Down](https://xzany.itch.io/top-down-adventurer-character)). Sixteen 768×80 strips — idle, run, attack 1, attack 2, each in four facings (up/down/left/right), 8 frames of 96×80 per strip. The character is ~19×34px inside each cell, feet at about (48, 58) from the cell's top-left in every frame. The strips are combined once (ImageMagick, not at runtime) into a single `examples/rpg/src/sprites/adventurer.png` (768×1280: 16 rows of 8 cells, in a fixed row order documented in `Player.bs`), so it loads as one `BGE.Sprite` sheet. License: free for personal/commercial projects; must not be resold or redistributed as a standalone asset; no NFTs; credit appreciated, not required. It ships only as part of this example, and is credited in `CREDITS.md`. Slice A uses idle and run; the attack rows are included now for Slice B.

`examples/rpg/src/sprites/CREDITS.md` lists authors, licenses, and links for both, following the attribution text each page asks for. Share-alike applies to the art (and edits of it), not to the engine or example code.

The sheets are atlases, not uniform tilesets. `PathAndObjects.png`'s ground comes as 96×96 blocks, each a 3×3 set of corner/edge/centre pieces for a path surface bordered by grass (eight surface styles: grey, white, tan cobble, dirt, and variants), with 96×64 fill-plus-grass-tuft blocks beneath. There are no inner-corner pieces. Objects (stalls, fountain, well, crates, barrels, banners, anvils, castle wall and gate facades, dock, boats) are mixed sizes.

## Scale and coordinates

- `new BGE.Game(640, 360)` + `game.fitCanvasToScreen()`, as `examples/platformer` does: 32px art at 2× on 720p and 3× on 1080p. One world unit = one art pixel; ~20×11 tiles visible.
- Map row 0 is the top. Cell `(r, c)`'s top-left is world `(c * 32, (numRows - r) * 32)` — +y up, the same convention as the platformer's `Level.bs`.

## File layout

```
examples/rpg/                      (npm run create-example -- rpg "RPG")
  src/sprites/  Castle2.png, PathAndObjects.png, adventurer.png, CREDITS.md
  src/source/
    main.bs                        canvas, sheet loading, "move" axis binding, defineScene x2, start in town
    Maps/
      MapData.bs                   town + castle: ground rows and placement lists
      Atlas.bs                     name -> {sheet, x, y, w, h, footprint}
      AutoTile.bs                  pure: pick 1 of 9 edge pieces from N/S/E/W neighbours
    World/
      TileMapEntity.bs             builds one area's ground (baked) and solid rects
      SolidWorld.bs                solid-rect store, grid buckets, moveAndSlide()
      Prop.bs                      placed object: image + footprint solid + z from feet
      Door.bs                      trigger zone -> scene transition
      ScreenFade.bs                persistent full-canvas fade overlay
    Entities/
      Player.bs                    persistent; input, movement, facing, sprite animations
    Scenes/
      TownScene.bs, CastleScene.bs
```

## Map data (`MapData.bs`)

Each area is two parts.

**Ground layer** — an array of strings, one character per 32px cell:

| Char | Meaning | Solid |
|------|---------|-------|
| `.` | grass | no |
| `c` | grey cobble (auto-tiled into grass) | no |
| `w` | white cobble (auto-tiled) | no |
| `t` | tan cobble (auto-tiled) | no |
| `d` | dirt (auto-tiled) | no |
| `s` | castle stone floor | no |
| `~` | water | yes |
| `#` | solid; visual supplied by a prop drawn over it (castle walls) | yes |
| `x` | solid void, drawn dark (interior out-of-bounds) | yes |

Auto-tiled paths are written at least two cells wide (see Auto-tiling).

**Placement list** — an array of AAs:

- `{atlasKey: "stall", col: 12, row: 4}` — a prop.
- `{type: "door", col, row, w, h, target: "castle", spawn: "gate"}` — a transition zone, in cells.
- `{type: "spawn", id: "gate", col, row, facing: "up"}` — an arrival point.

Sizes: town ~48×32 cells (≈2.4 × 2.8 screens, so the camera scrolls on both axes); castle interior ~24×16 cells.

**Town:** market town. Cobble roads auto-tiled into grass, market stalls, fountain, well, crates and barrels, a stretch of water along one edge with a dock and boats. The castle wall facade runs along the top edge with the arched gate (the door to the castle).

**Castle interior:** stone floor, the castle wall facade along the north edge, `x` void on the other edges, banners, a blacksmith corner (anvils, weapon rack), shelves, and a door on the south edge back to the town gate.

## Auto-tiling (`AutoTile.bs`)

A pure function (no engine dependencies): given the ground rows and a cell, return which of the nine pieces of that cell's surface set to draw.

- Column piece: **left** if only the west neighbour differs from this cell's surface, **right** if only the east differs, otherwise **centre**.
- Row piece: **top** if only north differs, **bottom** if only south differs, otherwise **centre**.
- Out-of-map neighbours count as the same surface (no border at map edges).
- Known limitations, documented in the source and in `MapData.bs`: inner corners and one-cell-wide runs fall back to the centre piece (hard edges); water and stone floor are not blended with neighbours (hard tile edges).

Grass cells use a plain grass tile.

## Atlas (`Atlas.bs`)

A table from name to `{sheet, x, y, w, h, footprint}`, where `footprint` is the solid rectangle `{x, y, w, h}` relative to the image's bottom-left (a stall's counter base, the fountain's basin, a wall section's full base; `invalid` = not solid). It covers the eight edge sets (as 3×3 piece groups) and fill tiles, plain grass, water, stone floor, and every prop the two maps use.

Coordinates are measured from the sheets during implementation. A throwaway contact-sheet check draws every atlas entry in a labelled grid and is screenshotted on-device to confirm each region before any map uses it.

## Building an area (`TileMapEntity.bs`)

- Walks the ground layer. Each cell becomes a `BGE.TileMap.TileSpec` using its atlas region (auto-tiled pieces for path surfaces). All tiles are baked once with `BGE.TileMap.bakeTileMapImages()` into 512px chunks and added as `matchCamera` images at z = −9000 (farthest back).
- Solid cells (`~`, `#`, `x`) become `BGE.TileMap.ColliderCell`s, merged with `mergeTileColliderRuns()`, and added to the scene's `SolidWorld` as rectangles.
- Placement-list props become `Prop` entities; doors become `Door` entities; spawns are kept in a lookup by id.
- Exposes the map's world bounds for camera clamping.

## Solid world and movement (`SolidWorld.bs`)

A per-scene store of axis-aligned solid rectangles (merged tile runs plus prop footprints), bucketed in a 128px grid.

`moveAndSlide(box, dx, dy)` — `box` is the mover's collision rectangle:

1. Move by `dx`; for each overlapping solid from the relevant buckets, push `box` back out along x to the solid's edge. Mark x blocked.
2. Same for `dy` along y.
3. **Corner nudge:** if input was along a single axis, that axis was blocked, and the blocking solid's edge overlaps `box` perpendicular to travel by ≤ 8px, move perpendicular toward the free side by up to the same step length.
4. Return the resulting position and which axes were blocked.

It is plain rectangle maths with no engine types beyond `BGE.Math` vectors, so it can be unit tested. It lives in the example rather than the engine. If Slice B's enemies need the same behaviour, that's when to decide whether it moves into the engine (via its own issue).

## Player (`Player.bs`)

- `persistent = true`.
- Reads `game.controls.getAxis("move")` (bound in `main.bs`; this already falls back to the d-pad, so remote and analog stick share one path). Diagonals normalised; analog magnitude scales speed up to ~90 px/s.
- Moves itself via `SolidWorld.moveAndSlide()` in `onUpdate()` and leaves `velocity` at zero, so the engine's post-update velocity integration never moves it without collision.
- Collision box: ~20×12 at the feet, not the whole sprite, so its head can overlap walls/awnings above it.
- A `RectangleCollider` on the feet box, used only for door triggers.
- Facing (up/down/left/right) from the dominant input axis; on an exact diagonal the current facing is kept, so it doesn't flicker along walls.
- Drawn with one `BGE.Sprite` (`addSprite()`, 96×80 cells from `adventurer.png`) with eight named animations: `idle_<facing>` and `run_<facing>`, looping (idle ~8 fps, run ~12 fps; tuned in the playtest). The sprite is offset so the cell's feet point (48, 58) sits on the entity's position, which is the bottom-centre of the collision box. It switches to `run_<facing>` while moving and `idle_<facing>` when stopped, keeping the frame timer when only the facing changes mid-run.
- Input lock flag used during transitions.

## Depth

Every depth-sorted entity sets `position.z = -feetWorldY`: the player each frame it moves, props once (a prop's entity is anchored at its footprint's bottom edge, with its image offset upward). Ground chunks sit at z = −9000. `Camera2d` depth is `camera.z − point.z` with the camera at z = 1000 and far at −10000, so the town's range (world y up to ~1024) fits. Equal depths use the renderer's existing stable tie-break. To verify on the first on-device run.

## Camera

In the active scene's `onDrawBegin()` (runs after every entity's update, before rendering, so no one-frame lag): target the player's position, clamped so the 640×360 frame stays within the map's world bounds; on an axis where the map is smaller than the frame, centre the map instead. Scenes snap the camera on arrival.

## Transitions (`Door.bs`, `ScreenFade.bs`)

1. `Door` owns a `RectangleCollider` trigger zone. On overlap with the player, if the door is armed and no transition is running, it starts one.
2. The player's input locks. `ScreenFade.fadeOut(0.3)` tweens a full-canvas black rectangle's alpha to 1 via `game.tweenManager`.
3. On completion: `game.changeScene(target, {spawn: spawnId})`. The player and `ScreenFade` are `persistent`; the map, props, and doors are destroyed with the old scene.
4. The new scene's `onCreate(args)` builds its area, places the player at the named spawn with its facing, snaps the camera, and calls `ScreenFade.fadeIn(0.3)`. Input unlocks when the fade-in completes.

Re-trigger guard: spawn points sit one cell outside their matching door, and a door starts disarmed if the player is inside it and arms once the player has left its zone.

`main.bs` defines both scenes and starts in the town at the spawn just below the castle gate. Back exits the channel.

## Testing

- **Pure-logic tests** for `AutoTile` (each of the nine pieces, map-edge handling, the one-wide and inner-corner fallbacks) and `moveAndSlide` (slide along a wall, stop at a corner, corner nudge, diagonal into an inside corner, no tunnelling at max speed). The repo's Rooibos build (`bsconfig.test.json`) only covers `src/`. The implementation plan decides how these run for an example. Fallback: a throwaway harness run once, with results reported — no new CI plumbing in this PR.
- `npm run check` and `npm run validate-examples` stay clean.
- **On-device (mandatory):** rokubot smoke — sideload, launch, screenshot town, walk into the gate, screenshot castle, walk back out, screenshot town. Plus the atlas contact-sheet check. Then a hand-off to Mark for a feel playtest (movement, wall sliding, corner nudge, depth behind stalls/walls, camera clamping) — rokubot is not used to judge feel.
- Title-safe area: no UI text in this slice. The rule applies from Slice C.

## Docs and follow-ups

- README example table row + screenshot, and `docs/game-engine-overview.md`'s sample-channel list.
- CLAUDE.md: a short `examples/rpg` note — the z-from-feet depth convention, and that `SolidWorld` is example code by design.
- File GitHub issues for Slice B and Slice C, and for any engine gap found during implementation.

## Risks

- **Atlas measurement errors** — mitigated by the contact-sheet check before building maps.
- **Depth range** — if z values fall outside `Camera2d`'s near/far, scale z (e.g. `-feetWorldY * 0.5`). Verified on the first run.
- **Door trigger via compositor** — the player's feet collider and the door zone must share compatible member/collidable flags. Covered by the transition smoke test.
- **Bake cost** — town ≈ 1,500 cells baked once per scene entry. Measure scene-entry time on real hardware. If noticeable behind the fade, cache the baked chunks across visits (a follow-up, not this slice).
