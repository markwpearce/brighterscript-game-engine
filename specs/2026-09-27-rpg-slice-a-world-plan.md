# examples/rpg Slice A (World) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `examples/rpg`: a *Link to the Past*-style top-down world. The Adventurer sprite walks freely around an auto-tiled town with depth-sorted props, slides along walls, and goes through the castle gate into a castle interior and back.

**Architecture:** Two `GameScene`s (`TownScene`, `CastleScene`) share an `AreaScene` base that builds its area from character-grid map data. Ground is auto-tiled by a pure function and baked once into chunk bitmaps. Collision is plain rectangle maths in a pure `SolidWorld.moveAndSlide()`, not engine colliders; compositor colliders are used only for door triggers. The persistent `Player` and `ScreenFade` survive scene changes. Depth sorting uses `position.z = -feetY` under `Camera2d`.

**Tech Stack:** BrighterScript (bsc 1.0.0-alpha.56), the BGE engine (copied into the example by its bsconfig), Rooibos v6 (`rooibos-roku`) + `brs-cli` for headless pure-logic tests, ImageMagick (one-time sprite-sheet composition), rokubot for on-device smoke checks.

**Spec:** `specs/2026-09-27-rpg-slice-a-world-design.md`

## Global Constraints

- Canvas `new BGE.Game(640, 360)` + `game.fitCanvasToScreen()`. One world unit = one art pixel. Tile size 32.
- World +y is up. Map row 0 is the top. Cell `(r, c)`'s top-left is world `(c * 32, (numRows - r) * 32)`; its bottom edge is `(numRows - r - 1) * 32`.
- No engine changes (`src/source/**` untouched). An engine gap found along the way gets filed as a GitHub issue, not patched.
- Drawables take packed RGB; `Renderer.draw*` takes packed RGBA.
- Never compare two class instances / native components with `=`. Compare names or ids.
- Assign `new X(game)` to a local variable before passing it to `addEntity()`/`defineScene()` (inline `new` as a call argument silently fails).
- A discrete input action must be guarded with `input.press and input.isButton(...)`.
- `bslint.json`: no single-line `if` (`inline-if-style: never`).
- Every file that uses a symbol from another file `import`s that file.
- Terse inline comments (1-3 sentences, the "why"). Public doc comments are for the reader of the example.
- On-device verification via the `rokubot-examples` skill is mandatory for runtime behaviour. Feel (movement, sliding, depth) is judged by Mark in a playtest, not via rokubot.
- Branch: `feature/rpg-slice-a-world` (already created, spec committed). Never push to `main`.

## Review Focus

1. **A path cell with neighbours on both sides differing** (one-cell-wide road, the gate opening) must render a sensible centre piece, not crash or pick a wrong edge. Pinned in Task 2's `@params` tests.
2. **Walking up the 3-wide road into the 1-wide gate opening** must not snag on the gate pillars. The corner nudge must ease the player in. Pinned by Task 3's stacked-rect nudge test and checked in Task 8's smoke run.
3. **A long frame** (the first frame after a scene bake) must not let the player tunnel through a wall. Pinned by Task 3's tunnelling test plus Task 7's `dt` cap.
4. **Arriving at a spawn next to a door** must not bounce straight back through it. Pinned by the Door arming logic in Task 8 and its smoke check.
5. **Leaving the map** must be impossible, even where no solid tile is on the edge (the town's east edge, the south road). Pinned by the bounds solids in Task 6 and Task 3's negative-coordinate test.

---

## File Structure

```
examples/rpg/
  package.json            (scaffolded; add "test" script, clean test-build)
  bsconfig.json           (scaffolded, unchanged)
  bsconfig.test.json      NEW: headless Rooibos build of the pure-logic files only
  tests/                  NEW: *.spec.bs, outside src/ so the normal build never sees them
    AutoTile.spec.bs
    SolidWorld.spec.bs
    Facing.spec.bs
  src/
    manifest, images/     (scaffolded)
    sprites/
      PathAndObjects.png, Castle2.png   (copied from ~/Downloads/rpg)
      adventurer.png                    (composed once from 16 strips)
      CREDITS.md
    source/
      main.bs             bitmaps, input binding, persistent entities, scenes
      Maps/
        AutoTile.bs       pure: autoTilePiece()
        MapData.bs        ground rows, placements, legend helpers
        Atlas.bs          region table + atlasRegion()
      World/
        SolidWorld.bs     pure: SolidWorld class
        TileMapEntity.bs  ground bake + solid tiles + bounds
        Prop.bs           placed atlas object
        Door.bs           trigger zone
        ScreenFade.bs     persistent fade overlay + scene transition
      Entities/
        Facing.bs         pure: facingFor()
        Player.bs
      Scenes/
        AreaScene.bs      shared build/camera/back logic
        TownScene.bs
        CastleScene.bs
scripts/run-tests-ci.js   MODIFY: optional build-dir argument
README.md, docs/game-engine-overview.md, CLAUDE.md, assets/screenshots/rpg.jpg
```

The scaffold's `src/source/Scenes/MainScene.bs` and `src/source/util.bs` are deleted in Task 1 if unused.

---

### Task 1: Scaffold the example, assets, credits, and pure-logic test harness

**Files:**
- Create: `examples/rpg/` via `npm run create-example -- rpg "RPG"` (also registers it in `.vscode/tasks.json`)
- Create: `examples/rpg/src/sprites/{PathAndObjects.png,Castle2.png,adventurer.png,CREDITS.md}`
- Create: `examples/rpg/bsconfig.test.json`, `examples/rpg/tests/Harness.spec.bs` (temporary, removed in Task 2)
- Modify: `examples/rpg/package.json`, `scripts/run-tests-ci.js:20`
- Modify: `examples/rpg/src/source/main.bs` (minimal: load bitmaps, blank scene still from scaffold)

**Interfaces:**
- Produces: bitmaps named `"town"`, `"castle"`, `"adventurer"`. `adventurer.png` is 768×1280: 16 rows of 8 cells of 96×80, rows in this order: 0 idle_down, 1 idle_up, 2 idle_left, 3 idle_right, 4 run_down, 5 run_up, 6 run_left, 7 run_right, 8-11 attack1 down/up/left/right, 12-15 attack2 down/up/left/right.
- Produces: `cd examples/rpg && npm test` runs every `tests/*.spec.bs` headlessly.

- [ ] **Step 1: Scaffold**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
npm run create-example -- rpg "RPG"
ls examples/rpg examples/rpg/src/source examples/rpg/src/source/Scenes
```
Expected: `examples/rpg` exists with `package.json`, `bsconfig.json`, `src/manifest`, `src/source/main.bs`, `src/source/Scenes/MainScene.bs`.

- [ ] **Step 2: Copy the tile sheets and compose the sprite sheet**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg/src/sprites
cp /Users/mpearce/Downloads/rpg/PathAndObjects.png /Users/mpearce/Downloads/rpg/Castle2.png .
S="/Users/mpearce/Downloads/rpg/FREE_Adventurer 2D Pixel Art/Sprites"
magick \
  "$S/IDLE/idle_down.png" "$S/IDLE/idle_up.png" "$S/IDLE/idle_left.png" "$S/IDLE/idle_right.png" \
  "$S/RUN/run_down.png" "$S/RUN/run_up.png" "$S/RUN/run_left.png" "$S/RUN/run_right.png" \
  "$S/ATTACK 1/attack1_down.png" "$S/ATTACK 1/attack1_up.png" "$S/ATTACK 1/attack1_left.png" "$S/ATTACK 1/attack1_right.png" \
  "$S/ATTACK 2/attack2_down.png" "$S/ATTACK 2/attack2_up.png" "$S/ATTACK 2/attack2_left.png" "$S/ATTACK 2/attack2_right.png" \
  -background none -append +repage adventurer.png
magick identify adventurer.png
```
Expected: `adventurer.png PNG 768x1280 ...` with an alpha channel. (If it shows `1280` wide or a single row, the `-append` ordering is wrong. Each input must stay a separate image; do not use `-flatten`.)

- [ ] **Step 3: Write `CREDITS.md`**

`examples/rpg/src/sprites/CREDITS.md`:
```markdown
# Art credits

## PathAndObjects.png
"RPG Tiles: Cobble Stone Paths & Town Objects" by Zabin, Daneeklu, Jetrel, Hyptosis, Redshrike, Bertram.
https://opengameart.org/content/rpg-tiles-cobble-stone-paths-town-objects (see that page for who did what)
License: CC-BY-SA 3.0 (Hyptosis's grass/cliff/water elements: CC-BY 3.0).

## Castle2.png
"Castle Tiles for RPGs" by Zabin, Hyptosis, and Daniel Cook.
https://opengameart.org/content/castle-tiles-for-rpgs
License: CC-BY 3.0.

## adventurer.png
"FREE Adventurer 2D Pixel Art" by Mattz Art — https://xzany.itch.io/
(free edition of https://xzany.itch.io/top-down-adventurer-character).
Combined from the pack's 16 animation strips into one sheet; otherwise unmodified.
License: free for personal and commercial projects; may not be resold or redistributed as a
standalone asset; no NFTs. Included here only as part of this example.
```

- [ ] **Step 4: Let the CI runner take a build directory**

In `scripts/run-tests-ci.js`, replace line 20:
```js
const BUILD_DIR = path.join(ROOT_DIR, 'test-build');
```
with:
```js
// Optional first argument: the test build directory, relative to the repo root (default
// ./test-build) - lets an example with its own bsconfig.test.json reuse this runner.
const BUILD_DIR = path.resolve(ROOT_DIR, process.argv[2] || 'test-build');
```
Also update the header comment's "Assumes `npm run build-tests` has already produced ./test-build." to "Assumes the test build (default ./test-build, or the directory passed as the first argument) already exists."

- [ ] **Step 5: Add the example's test build config**

`examples/rpg/bsconfig.test.json`:
```json
{
    "rootDir": "src",
    "outDir": "test-build",
    "retainStagingDir": true,
    "files": [
        "source/Maps/AutoTile.bs",
        "source/World/SolidWorld.bs",
        "source/Entities/Facing.bs",
        {
            "src": "../tests/**/*.spec.bs",
            "dest": "source/tests"
        },
        {
            "src": "../../../test.manifest",
            "dest": "manifest"
        }
    ],
    "plugins": [
        "rooibos-roku"
    ],
    "rooibos": {
        "isRecordingCodeCoverage": false,
        "testsFilePattern": null,
        "tags": ["!integration", "!deprecated", "!fixme"],
        "showOnlyFailures": true,
        "catchCrashes": true,
        "lineWidth": 70,
        "failFast": false,
        "sendHomeOnFinish": false,
        "reporters": ["mocha"]
    }
}
```
This deliberately does not extend `bsconfig.build.json`: no bslint (avoids the known bslint+rooibos new-file resolution bug), no engine source (the tested files are dependency-free).

In `examples/rpg/package.json`, set the scripts to:
```json
"build": "bsc",
"clean": "rimraf build && rimraf out && rimraf test-build",
"package": "bsc && exampleName=`basename $PWD` && npx roku-deploy zip --dir ./build --out ./out/bge-${exampleName}.zip",
"test": "bsc --project bsconfig.test.json --create-package=false && node ../../scripts/run-tests-ci.js examples/rpg/test-build"
```

- [ ] **Step 6: Create empty pure-logic files and a harness smoke spec**

So the test build has its listed files, create:

`examples/rpg/src/source/Maps/AutoTile.bs`, `examples/rpg/src/source/World/SolidWorld.bs`, `examples/rpg/src/source/Entities/Facing.bs`, each containing only:
```brighterscript
' Filled in by a later task.
```

`examples/rpg/tests/Harness.spec.bs`:
```brighterscript
namespace tests
  @suite("rpg test harness")
  class HarnessTests extends rooibos.BaseTestSuite

    @describe("harness")

    @it("runs")
    function _()
      m.assertTrue(true)
    end function

  end class
end namespace
```

- [ ] **Step 7: Run the harness**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm install && npm test
```
Expected: output ends with a Rooibos PASS result and exit code 0. If `rooibos-roku` can't be resolved, check that `/Users/mpearce/redspace/roku/brighterscript-game-engine/node_modules/rooibos-roku` exists (`npm ci` at the root). Node resolves plugins upward from the example directory.

- [ ] **Step 8: Minimal main.bs that loads the sheets**

Replace `examples/rpg/src/source/main.bs`'s body (keep the scaffold's `MainScene` for now) so it starts:
```brighterscript
sub Main(args = {} as object)
  game = new BGE.Game(640, 360)
  game.fitCanvasToScreen()
  game.loadBitmap("town", "pkg:/sprites/PathAndObjects.png")
  game.loadBitmap("castle", "pkg:/sprites/Castle2.png")
  game.loadBitmap("adventurer", "pkg:/sprites/adventurer.png")

  firstScene = new MainScene(game)
  game.defineScene(firstScene)
  game.changeScene(firstScene.name)
  game.play()
end sub
```

- [ ] **Step 9: Validate the example builds**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npx bsc --validate --create-package=false
cd /Users/mpearce/redspace/roku/brighterscript-game-engine && npm run check
```
Expected: no diagnostics from the example. `npm run check` passes (the `run-tests-ci.js` change must not break the root suite).

- [ ] **Step 10: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add examples/rpg scripts/run-tests-ci.js .vscode/tasks.json
git commit -m "Scaffold examples/rpg with tile/character art and a pure-logic test harness

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Auto-tiling (`autoTilePiece`)

**Files:**
- Modify: `examples/rpg/src/source/Maps/AutoTile.bs`
- Create: `examples/rpg/tests/AutoTile.spec.bs`
- Delete: `examples/rpg/tests/Harness.spec.bs`

**Interfaces:**
- Produces: `function autoTilePiece(rows as string[], r as integer, c as integer) as object` returning `{col as integer, row as integer}`, each 0-2: col 0 = west edge, 2 = east edge, 1 = centre; row 0 = north edge, 2 = south edge, 1 = centre. Plus helpers `autoTileAxisPiece(leadingDiffers as boolean, trailingDiffers as boolean) as integer` and `autoTileDiffers(rows as string[], r as integer, c as integer, surface as string) as boolean`.

- [ ] **Step 1: Write the failing tests**

`examples/rpg/tests/AutoTile.spec.bs`:
```brighterscript
namespace tests
  @suite("autoTilePiece")
  class AutoTileTests extends rooibos.BaseTestSuite

    private block as string[]

    protected override function beforeEach()
      ' A 3x3 cobble block inside grass - every cell maps to a different one of the 9 pieces.
      m.block = [
        ".....",
        ".ccc.",
        ".ccc.",
        ".ccc.",
        "....."
      ]
    end function

    @describe("a 3x3 block")

    @it("picks the matching edge/corner piece for each cell")
    @params(1, 1, 0, 0)
    @params(1, 2, 1, 0)
    @params(1, 3, 2, 0)
    @params(2, 1, 0, 1)
    @params(2, 2, 1, 1)
    @params(2, 3, 2, 1)
    @params(3, 1, 0, 2)
    @params(3, 2, 1, 2)
    @params(3, 3, 2, 2)
    function _(r, c, expectedCol, expectedRow)
      piece = autoTilePiece(m.block, r, c)
      m.assertEqual(expectedCol, piece.col)
      m.assertEqual(expectedRow, piece.row)
    end function

    @describe("fallbacks")

    @it("uses the centre piece for a one-cell-wide run (both sides differ)")
    function _()
      rows = [
        "...",
        ".c.",
        ".c.",
        ".c.",
        "..."
      ]
      piece = autoTilePiece(rows, 2, 1)
      m.assertEqual(1, piece.col)
      m.assertEqual(1, piece.row)
    end function

    @it("uses the centre piece for an inner corner (only a diagonal differs)")
    function _()
      rows = [
        "cc.",
        "ccc",
        "ccc"
      ]
      piece = autoTilePiece(rows, 1, 1)
      m.assertEqual(1, piece.col)
      m.assertEqual(1, piece.row)
    end function

    @it("treats out-of-map neighbours as the same surface")
    function _()
      rows = [
        "cc",
        "cc"
      ]
      piece = autoTilePiece(rows, 0, 0)
      m.assertEqual(1, piece.col)
      m.assertEqual(1, piece.row)
    end function

    @it("treats a different path surface as a differing neighbour")
    function _()
      rows = [
        "cct"
      ]
      piece = autoTilePiece(rows, 0, 1)
      m.assertEqual(2, piece.col)
    end function

  end class
end namespace
```

Delete `examples/rpg/tests/Harness.spec.bs`.

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm test
```
Expected: bsc fails with `cannot-find-name` for `autoTilePiece` (or Rooibos FAIL).

- [ ] **Step 3: Implement**

`examples/rpg/src/source/Maps/AutoTile.bs`:
```brighterscript
' Auto-tiling for path surfaces (cobble, dirt). Each surface's art is a 96x96 set of 3x3
' pieces: corners, edges and a centre, drawn as that surface bordered by grass. This picks
' which piece a cell shows from its four neighbours.
'
' Known limitation: the sheet has no inner-corner pieces, so an inner corner (only a diagonal
' neighbour differs) and a one-cell-wide run both fall back to the centre piece - hard edges.
' Keep paths at least two cells wide in map data.
'
' @param {string[]} rows - the ground layer, one string per map row
' @param {integer} r - row index (0 = top)
' @param {integer} c - column index
' @return {object} {col, row}: 0-2 each, selecting the piece within the 3x3 set
function autoTilePiece(rows as string[], r as integer, c as integer) as object
  surface = rows[r].mid(c, 1)
  westDiffers = autoTileDiffers(rows, r, c - 1, surface)
  eastDiffers = autoTileDiffers(rows, r, c + 1, surface)
  northDiffers = autoTileDiffers(rows, r - 1, c, surface)
  southDiffers = autoTileDiffers(rows, r + 1, c, surface)
  return {
    col: autoTileAxisPiece(westDiffers, eastDiffers),
    row: autoTileAxisPiece(northDiffers, southDiffers)
  }
end function

' 0 = leading edge (west/north), 2 = trailing edge (east/south), 1 = centre.
function autoTileAxisPiece(leadingDiffers as boolean, trailingDiffers as boolean) as integer
  if leadingDiffers and not trailingDiffers
    return 0
  else if trailingDiffers and not leadingDiffers
    return 2
  end if
  return 1
end function

' Out-of-map neighbours count as the same surface, so a path runs cleanly off the map edge.
function autoTileDiffers(rows as string[], r as integer, c as integer, surface as string) as boolean
  if r < 0 or r >= rows.count()
    return false
  end if
  if c < 0 or c >= rows[r].len()
    return false
  end if
  return rows[r].mid(c, 1) <> surface
end function
```

- [ ] **Step 4: Run to verify pass**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm test
```
Expected: PASS, 13 tests (9 parameterised + 4). If an `assertEqual` fails on Integer vs Float, read the types from the diff (see CLAUDE.md's Rooibos notes).

- [ ] **Step 5: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add -A examples/rpg/src/source/Maps/AutoTile.bs examples/rpg/tests
git commit -m "rpg: auto-tile path surfaces from neighbouring cells

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `SolidWorld.moveAndSlide`

**Files:**
- Modify: `examples/rpg/src/source/World/SolidWorld.bs`
- Create: `examples/rpg/tests/SolidWorld.spec.bs`

**Interfaces:**
- Produces: `class SolidWorld` with
  - `sub addSolid(x as float, y as float, w as float, h as float)`: (x, y) = bottom-left, +y up
  - `function getSolidCount() as integer`
  - `function moveAndSlide(box as object, dx as float, dy as float) as object`: `box` = `{x, y, w, h}` (bottom-left). Returns `{x, y, blockedX as boolean, blockedY as boolean}`, the box's new bottom-left corner.
- Constants: `SOLID_BUCKET_SIZE = 128`, `SOLID_MAX_STEP = 4.0`, `SOLID_CORNER_NUDGE = 8.0`.

- [ ] **Step 1: Write the failing tests**

`examples/rpg/tests/SolidWorld.spec.bs`:
```brighterscript
namespace tests
  @suite("SolidWorld.moveAndSlide")
  class SolidWorldTests extends rooibos.BaseTestSuite

    private world as SolidWorld

    protected override function beforeEach()
      m.world = new SolidWorld()
    end function

    ' moveAndSlide sub-steps, so positions are sums of float fractions - compare with tolerance.
    private sub assertClose(expected as float, actual as float, label as string)
      m.assertTrue(Abs(expected - actual) < 0.01, label + ": expected " + expected.toStr() + " but got " + actual.toStr())
    end sub

    private function box(x as float, y as float) as object
      return {x: x, y: y, w: 20.0, h: 12.0}
    end function

    @describe("free movement")

    @it("moves the full distance with no solids")
    function _()
      result = m.world.moveAndSlide(m.box(0, 0), 10, 5)
      m.assertClose(10, result.x, "x")
      m.assertClose(5, result.y, "y")
      m.assertFalse(result.blockedX)
      m.assertFalse(result.blockedY)
    end function

    @describe("blocking and sliding")

    @it("stops flush against a wall")
    function _()
      m.world.addSolid(30, -100, 32, 300)
      result = m.world.moveAndSlide(m.box(0, 0), 20, 0)
      m.assertClose(10, result.x, "x")
      m.assertTrue(result.blockedX)
    end function

    @it("slides along a wall when moving diagonally into it")
    function _()
      m.world.addSolid(30, -100, 32, 300)
      result = m.world.moveAndSlide(m.box(10, 0), 5, 6)
      m.assertClose(10, result.x, "x")
      m.assertClose(6, result.y, "y")
      m.assertTrue(result.blockedX)
      m.assertFalse(result.blockedY)
    end function

    @it("stops in an inside corner")
    function _()
      m.world.addSolid(30, -100, 32, 300)
      m.world.addSolid(-100, 20, 300, 32)
      result = m.world.moveAndSlide(m.box(10, 8), 5, 5)
      m.assertClose(10, result.x, "x")
      m.assertClose(8, result.y, "y")
      m.assertTrue(result.blockedX)
      m.assertTrue(result.blockedY)
    end function

    @it("does not tunnel through a thin solid on a long move")
    function _()
      m.world.addSolid(30, -100, 2, 300)
      result = m.world.moveAndSlide(m.box(0, 0), 60, 0)
      m.assertClose(10, result.x, "x")
    end function

    @describe("corner nudge")

    @it("eases around a corner the box barely clips")
    function _()
      ' Box spans y 0..12; the block starts at y 10, so it overlaps by 2px.
      m.world.addSolid(30, 10, 32, 32)
      result = m.world.moveAndSlide(m.box(0, 0), 20, 0)
      m.assertClose(-2, result.y, "y")
      m.assertTrue(result.x > 10, "x should pass the corner, got " + result.x.toStr())
    end function

    @it("eases around the end of a wall made of stacked rects")
    function _()
      m.world.addSolid(30, 10, 32, 32)
      m.world.addSolid(30, 42, 32, 32)
      m.world.addSolid(30, 74, 32, 32)
      result = m.world.moveAndSlide(m.box(0, 0), 20, 0)
      m.assertClose(-2, result.y, "y")
    end function

    @it("nudges upward past the top of a block")
    function _()
      ' Block spans y -30..2; box spans 0..12, overlapping its top edge by 2px.
      m.world.addSolid(30, -30, 32, 32)
      result = m.world.moveAndSlide(m.box(0, 0), 20, 0)
      m.assertClose(2, result.y, "y")
    end function

    @it("does not nudge when the overlap is deeper than the nudge limit")
    function _()
      m.world.addSolid(30, 2, 32, 32)
      result = m.world.moveAndSlide(m.box(0, 0), 20, 0)
      m.assertClose(0, result.y, "y")
      m.assertClose(10, result.x, "x")
    end function

    @it("does not nudge while moving diagonally")
    function _()
      m.world.addSolid(30, 10, 32, 32)
      result = m.world.moveAndSlide(m.box(0, 0), 20, 0.5)
      m.assertClose(10, result.x, "x")
      m.assertClose(0.5, result.y, "y")
    end function

    @describe("buckets")

    @it("finds a solid spanning many buckets from its far end")
    function _()
      m.world.addSolid(0, 500, 1000, 32)
      result = m.world.moveAndSlide(m.box(900, 480), 0, 20)
      m.assertClose(488, result.y, "y")
      m.assertTrue(result.blockedY)
    end function

    @it("handles solids at negative coordinates (map bounds)")
    function _()
      m.world.addSolid(-64, 0, 64, 100)
      result = m.world.moveAndSlide(m.box(5, 10), -20, 0)
      m.assertClose(0, result.x, "x")
      m.assertTrue(result.blockedX)
    end function

    @it("counts added solids")
    function _()
      m.world.addSolid(0, 0, 10, 10)
      m.world.addSolid(20, 0, 10, 10)
      m.assertEqual(2, m.world.getSolidCount())
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm test
```
Expected: bsc `cannot-find-name` for `SolidWorld`.

- [ ] **Step 3: Implement**

`examples/rpg/src/source/World/SolidWorld.bs`:
```brighterscript
' Axis-aligned solid rectangles for top-down movement, and moveAndSlide() to keep a moving box
' out of them while sliding along walls. Plain rectangle maths, independent of the engine's
' colliders (which only detect overlaps, they don't resolve them).
' Every rectangle is {x, y, w, h}: (x, y) is the bottom-left corner, world +y up.

' Solids are bucketed on a grid this size so a move only tests nearby rectangles.
const SOLID_BUCKET_SIZE = 128
' Longest single sub-step, so a fast move can't skip over a thin solid.
const SOLID_MAX_STEP = 4.0
' How far a box may overlap a blocking corner and still be eased around it.
const SOLID_CORNER_NUDGE = 8.0

class SolidWorld

  private buckets as roAssociativeArray = {}
  private solids as object = []

  ' @param {float} x - bottom-left x
  ' @param {float} y - bottom-left y
  ' @param {float} w
  ' @param {float} h
  sub addSolid(x as float, y as float, w as float, h as float)
    solid = {x: x, y: y, w: w, h: h, id: m.solids.count().toStr()}
    m.solids.push(solid)
    for bx = m.bucketIndex(x) to m.bucketIndex(x + w)
      for by = m.bucketIndex(y) to m.bucketIndex(y + h)
        key = bx.toStr() + "," + by.toStr()
        if m.buckets[key] = invalid
          m.buckets[key] = []
        end if
        m.buckets[key].push(solid)
      end for
    end for
  end sub

  function getSolidCount() as integer
    return m.solids.count()
  end function

  ' Moves box by (dx, dy), stopping flush against solids and sliding along them. When moving
  ' along one axis only, a box that clips a corner by up to SOLID_CORNER_NUDGE is eased around it.
  '
  ' @param {object} box - {x, y, w, h}, bottom-left corner
  ' @param {float} dx
  ' @param {float} dy
  ' @return {object} {x, y, blockedX, blockedY}: the box's new bottom-left corner
  function moveAndSlide(box as object, dx as float, dy as float) as object
    largest = Abs(dx)
    if Abs(dy) > largest
      largest = Abs(dy)
    end if
    steps = Int(largest / SOLID_MAX_STEP) + 1
    stepX = dx / steps
    stepY = dy / steps
    result = {x: box.x, y: box.y, blockedX: false, blockedY: false}
    for i = 1 to steps
      if stepX <> 0
        m.stepAxis(result, box.w, box.h, stepX, true, dy = 0)
      end if
      if stepY <> 0
        m.stepAxis(result, box.w, box.h, stepY, false, dx = 0)
      end if
    end for
    return result
  end function

  private sub stepAxis(result as object, w as float, h as float, delta as float, alongX as boolean, canNudge as boolean)
    nx = result.x
    ny = result.y
    if alongX
      nx += delta
    else
      ny += delta
    end if
    hits = m.overlaps(nx, ny, w, h)
    if hits.count() = 0
      result.x = nx
      result.y = ny
      return
    end if

    ' Snap flush to the nearest blocking edge. The box started clear, so this never moves it backwards.
    if alongX
      result.blockedX = true
      for each hit in hits
        if delta > 0 and hit.x - w < nx
          nx = hit.x - w
        else if delta < 0 and hit.x + hit.w > nx
          nx = hit.x + hit.w
        end if
      end for
      result.x = nx
    else
      result.blockedY = true
      for each hit in hits
        if delta > 0 and hit.y - h < ny
          ny = hit.y - h
        else if delta < 0 and hit.y + hit.h > ny
          ny = hit.y + hit.h
        end if
      end for
      result.y = ny
    end if

    if canNudge
      m.tryNudge(result, w, h, hits, Abs(delta), alongX)
    end if
  end sub

  ' Moves the box perpendicular to travel when it only clips the blockers' combined extent by a
  ' few pixels. Uses the union of all hits so a wall made of stacked tile rects counts as one.
  private sub tryNudge(result as object, w as float, h as float, hits as object, stepLength as float, alongX as boolean)
    ' Perpendicular axis: y when travelling along x, x when travelling along y.
    if alongX
      boxStart = result.y
      boxSize = h
    else
      boxStart = result.x
      boxSize = w
    end if
    blockStart = invalid
    blockEnd = invalid
    for each hit in hits
      if alongX
        hitStart = hit.y
        hitEnd = hit.y + hit.h
      else
        hitStart = hit.x
        hitEnd = hit.x + hit.w
      end if
      if blockStart = invalid or hitStart < blockStart
        blockStart = hitStart
      end if
      if blockEnd = invalid or hitEnd > blockEnd
        blockEnd = hitEnd
      end if
    end for

    shift = 0.0
    overlapAtStart = (boxStart + boxSize) - blockStart
    overlapAtEnd = blockEnd - boxStart
    if overlapAtStart > 0 and overlapAtStart <= SOLID_CORNER_NUDGE
      shift = -m.minFloat(stepLength, overlapAtStart)
    else if overlapAtEnd > 0 and overlapAtEnd <= SOLID_CORNER_NUDGE
      shift = m.minFloat(stepLength, overlapAtEnd)
    end if
    if shift = 0
      return
    end if

    nx = result.x
    ny = result.y
    if alongX
      ny += shift
    else
      nx += shift
    end if
    if m.overlaps(nx, ny, w, h).count() = 0
      result.x = nx
      result.y = ny
    end if
  end sub

  ' Solids strictly overlapping the given box. Touching edges don't count, so a box flush
  ' against a wall is clear.
  private function overlaps(x as float, y as float, w as float, h as float) as object
    found = []
    seen = {}
    for bx = m.bucketIndex(x) to m.bucketIndex(x + w)
      for by = m.bucketIndex(y) to m.bucketIndex(y + h)
        bucket = m.buckets[bx.toStr() + "," + by.toStr()]
        if bucket <> invalid
          for each solid in bucket
            if seen[solid.id] = invalid and x < solid.x + solid.w and x + w > solid.x and y < solid.y + solid.h and y + h > solid.y
              seen[solid.id] = true
              found.push(solid)
            end if
          end for
        end if
      end for
    end for
    return found
  end function

  ' Int() floors, so negative coordinates (map-bounds solids) land in the right bucket.
  private function bucketIndex(value as float) as integer
    return Int(value / SOLID_BUCKET_SIZE)
  end function

  private function minFloat(a as float, b as float) as float
    if a < b
      return a
    end if
    return b
  end function

end class
```

Check the nudge-upward test by hand: the block spans y −30..2 and the box 0..12. `overlapAtStart` = 12 − (−30) = 42 is too deep; `overlapAtEnd` = 2 − 0 = 2 → shift +2 → y = 2. ✓

- [ ] **Step 4: Run to verify pass**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm test
```
Expected: PASS (13 AutoTile + 13 SolidWorld). If a nudge test is off by a sub-step fraction, trace it by hand before changing tolerances. The expected values above assume `steps = Int(20 / 4) + 1 = 6`.

- [ ] **Step 5: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add examples/rpg/src/source/World/SolidWorld.bs examples/rpg/tests/SolidWorld.spec.bs
git commit -m "rpg: SolidWorld.moveAndSlide with wall sliding and corner nudge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Facing

**Files:**
- Modify: `examples/rpg/src/source/Entities/Facing.bs`
- Create: `examples/rpg/tests/Facing.spec.bs`

**Interfaces:**
- Produces: `function facingFor(x as float, y as float, current as string) as string` returning `"up"`, `"down"`, `"left"` or `"right"`. World +y is up.

- [ ] **Step 1: Write the failing tests**

`examples/rpg/tests/Facing.spec.bs`:
```brighterscript
namespace tests
  @suite("facingFor")
  class FacingTests extends rooibos.BaseTestSuite

    @describe("facingFor")

    @it("faces the dominant axis")
    @params(1.0, 0.0, "right")
    @params(-1.0, 0.0, "left")
    @params(0.0, 1.0, "up")
    @params(0.0, -1.0, "down")
    @params(0.9, 0.3, "right")
    @params(-0.2, -0.8, "down")
    function _(x, y, expected)
      m.assertEqual(expected, facingFor(x, y, "down"))
    end function

    @it("keeps the current facing on an exact diagonal")
    function _()
      m.assertEqual("left", facingFor(0.7, 0.7, "left"))
    end function

    @it("keeps the current facing with no input")
    function _()
      m.assertEqual("up", facingFor(0.0, 0.0, "up"))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm test`
Expected: `cannot-find-name` for `facingFor`.

- [ ] **Step 3: Implement**

`examples/rpg/src/source/Entities/Facing.bs`:
```brighterscript
' Which way the player faces for a movement direction (world +y up). On an exact diagonal the
' current facing is kept, so walking diagonally along a wall doesn't flicker between two facings.
'
' @param {float} x
' @param {float} y
' @param {string} current - "up", "down", "left" or "right"
' @return {string}
function facingFor(x as float, y as float, current as string) as string
  if Abs(x) > Abs(y)
    if x > 0
      return "right"
    end if
    return "left"
  else if Abs(y) > Abs(x)
    if y > 0
      return "up"
    end if
    return "down"
  end if
  return current
end function
```

- [ ] **Step 4: Run to verify pass**

Run: `cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npm test`
Expected: PASS (34 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add examples/rpg/src/source/Entities/Facing.bs examples/rpg/tests/Facing.spec.bs
git commit -m "rpg: facing from movement direction

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Atlas and on-device contact-sheet check

**Files:**
- Create: `examples/rpg/src/source/Maps/Atlas.bs`
- Create (throwaway, deleted in Step 6): `examples/rpg/src/source/Scenes/AtlasPreviewScene.bs`
- Modify: `examples/rpg/src/source/main.bs`

**Interfaces:**
- Produces:
  - `function getAtlas() as roAssociativeArray`: name → `{sheet, x, y, w, h, footprint}`. `sheet` is `"town"` or `"castle"`. `footprint` is `{x, y, w, h}` relative to the image's bottom-left (+y up), or `invalid` for decoration.
  - `function atlasRegion(game as BGE.Game, entry as object) as roRegion`
  - `function getSurfaceSet(ch as string) as object`: `{sheet, x, y}` (top-left of a 96×96 3×3 set) for `"c"`, `"w"`, `"t"`, `"d"`, else `invalid`.

- [ ] **Step 1: Write `Atlas.bs`**

```brighterscript
' Named regions in the two tile sheets (sheet keys match main.bs's loadBitmap() names).
' footprint is the solid part of a prop, relative to the image's bottom-left corner (+y up) -
' e.g. a stall's counter but not its awning, so the player can walk behind the awning.
' invalid means decoration only (or standing on tiles that are already solid).
'
' @return {roAssociativeArray}
function getAtlas() as roAssociativeArray
  globals = GetGlobalAA()
  if globals.rpgAtlas = invalid
    globals.rpgAtlas = buildAtlas()
  end if
  return globals.rpgAtlas
end function

function buildAtlas() as roAssociativeArray
  return {
    ' Ground tiles (32x32)
    grass: {sheet: "castle", x: 0, y: 352, w: 32, h: 32, footprint: invalid},
    water: {sheet: "castle", x: 0, y: 384, w: 32, h: 32, footprint: invalid},
    stoneFloor: {sheet: "castle", x: 288, y: 352, w: 32, h: 32, footprint: invalid},
    brick: {sheet: "castle", x: 480, y: 96, w: 32, h: 32, footprint: invalid},

    ' Castle exterior (drawn over '#' tiles, so no footprint)
    wallStrip: {sheet: "castle", x: 32, y: 64, w: 32, h: 128, footprint: invalid},
    castleGate: {sheet: "castle", x: 96, y: 64, w: 96, h: 128, footprint: invalid},
    tower: {sheet: "castle", x: 198, y: 0, w: 58, h: 224, footprint: invalid},

    ' Town props
    stallFront: {sheet: "town", x: 416, y: 352, w: 96, h: 160, footprint: {x: 0, y: 0, w: 96, h: 44}},
    stallProduce: {sheet: "town", x: 400, y: 0, w: 112, h: 96, footprint: {x: 0, y: 0, w: 112, h: 34}},
    crateRow: {sheet: "town", x: 384, y: 224, w: 128, h: 42, footprint: {x: 0, y: 0, w: 128, h: 24}},
    sacksPile: {sheet: "town", x: 288, y: 257, w: 64, h: 63, footprint: {x: 4, y: 0, w: 56, h: 28}},
    plantPot: {sheet: "town", x: 359, y: 291, w: 18, h: 28, footprint: {x: 2, y: 0, w: 14, h: 10}},
    vase: {sheet: "town", x: 388, y: 355, w: 24, h: 38, footprint: {x: 2, y: 0, w: 20, h: 12}},
    firewood: {sheet: "town", x: 130, y: 320, w: 29, h: 32, footprint: {x: 0, y: 0, w: 29, h: 16}},
    grainSack: {sheet: "town", x: 224, y: 327, w: 32, h: 25, footprint: {x: 2, y: 0, w: 28, h: 14}},
    boat: {sheet: "town", x: 1, y: 448, w: 123, h: 63, footprint: invalid},
    dock: {sheet: "town", x: 96, y: 361, w: 96, h: 87, footprint: invalid},
    fountain: {sheet: "castle", x: 290, y: 384, w: 62, h: 64, footprint: {x: 4, y: 0, w: 54, h: 34}},
    well: {sheet: "castle", x: 455, y: 448, w: 52, h: 64, footprint: {x: 4, y: 0, w: 44, h: 30}},
    barrel: {sheet: "castle", x: 292, y: 452, w: 25, h: 27, footprint: {x: 2, y: 0, w: 21, h: 14}},
    crateStack: {sheet: "castle", x: 320, y: 448, w: 30, h: 63, footprint: {x: 0, y: 0, w: 30, h: 20}},
    lampPost: {sheet: "castle", x: 492, y: 353, w: 14, h: 95, footprint: {x: 3, y: 0, w: 8, h: 6}},
    bench: {sheet: "castle", x: 451, y: 320, w: 61, h: 29, footprint: {x: 0, y: 0, w: 61, h: 14}},
    statue: {sheet: "castle", x: 355, y: 426, w: 29, h: 85, footprint: {x: 2, y: 0, w: 25, h: 16}},
    goodsStall: {sheet: "castle", x: 0, y: 288, w: 64, h: 64, footprint: {x: 0, y: 0, w: 64, h: 28}},

    ' Castle interior props
    bannerRed: {sheet: "castle", x: 288, y: 260, w: 29, h: 49, footprint: invalid},
    bannerBlue: {sheet: "castle", x: 320, y: 260, w: 29, h: 49, footprint: invalid},
    oreBins: {sheet: "castle", x: 96, y: 256, w: 64, h: 31, footprint: {x: 0, y: 0, w: 64, h: 18}},
    anvilBig: {sheet: "castle", x: 107, y: 293, w: 53, h: 23, footprint: {x: 4, y: 0, w: 45, h: 12}},
    anvil: {sheet: "castle", x: 164, y: 294, w: 27, h: 24, footprint: {x: 2, y: 0, w: 23, h: 12}},
    weaponRack: {sheet: "castle", x: 128, y: 325, w: 64, h: 59, footprint: {x: 0, y: 0, w: 64, h: 24}},
    dresser: {sheet: "castle", x: 96, y: 323, w: 32, h: 61, footprint: {x: 0, y: 0, w: 32, h: 24}},
    drawers: {sheet: "castle", x: 65, y: 353, w: 30, h: 31, footprint: {x: 0, y: 0, w: 30, h: 18}}
  }
end function

' @param {BGE.Game} game
' @param {object} entry - a getAtlas() entry
' @return {roRegion}
function atlasRegion(game as BGE.Game, entry as object) as roRegion
  return CreateObject("roRegion", game.getBitmap(entry.sheet), entry.x, entry.y, entry.w, entry.h)
end function

' The 3x3 auto-tile set (see AutoTile.bs) for a path character, or invalid.
'
' @param {string} ch
' @return {object} {sheet, x, y}: top-left of the 96x96 set
function getSurfaceSet(ch as string) as object
  sets = {
    c: {sheet: "town", x: 0, y: 0},
    w: {sheet: "town", x: 96, y: 0},
    t: {sheet: "town", x: 192, y: 0},
    d: {sheet: "town", x: 288, y: 0}
  }
  return sets[ch]
end function
```
(Add `import "pkg:/source/engine/Game.bs"` at the top only if validation reports `BGE.Game` unresolved. Match whatever the platformer's files do; they reference `BGE.*` with no engine imports.)

- [ ] **Step 2: Write the throwaway contact-sheet scene**

`examples/rpg/src/source/Scenes/AtlasPreviewScene.bs`:
```brighterscript
import "../Maps/Atlas.bs"

' Throwaway: draws every atlas entry (and each path surface's 9 pieces) labelled, to check
' region coordinates on-device. Deleted once the atlas is verified.
class AtlasPreviewScene extends BGE.GameScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "AtlasPreviewScene"
  end sub

  override sub onDrawEnd(gameRenderer as BGE.Renderer, uiRenderer as BGE.Renderer)
    atlas = getAtlas()
    font = m.game.getFont("default")
    x = 8
    y = 8
    rowHeight = 0
    keys = atlas.Keys()
    keys.Sort()
    for each key in keys
      entry = atlas[key]
      if x + entry.w + 8 > 1280
        x = 8
        y += rowHeight + 24
        rowHeight = 0
      end if
      uiRenderer.drawRectangleOutline(x - 1, y - 1, entry.w + 2, entry.h + 2, &hFF00FFFF)
      uiRenderer.drawObject(x, y, atlasRegion(m.game, entry))
      if entry.footprint <> invalid
        fp = entry.footprint
        uiRenderer.drawRectangleOutline(x + fp.x, y + entry.h - fp.y - fp.h, fp.w, fp.h, &hFF0000FF)
      end if
      uiRenderer.drawText(key, x, y + entry.h + 2, &hFFFFFFFF, font)
      x += entry.w + 16
      if entry.h > rowHeight
        rowHeight = entry.h
      end if
    end for
    for each ch in ["c", "w", "t", "d"]
      surface = getSurfaceSet(ch)
      region = CreateObject("roRegion", m.game.getBitmap(surface.sheet), surface.x, surface.y, 96, 96)
      uiRenderer.drawObject(x, y, region)
      uiRenderer.drawText(ch, x, y + 98, &hFFFFFFFF, font)
      x += 112
    end for
  end sub

end class
```
The UI canvas is screen-sized (1280×720 at 720p), so this draws at 1× on the UI layer. If entries overflow the bottom, scale down with `drawScaledObject` or split across two frames. It's throwaway, so keep it simple.

- [ ] **Step 3: Temporarily start in the preview**

In `main.bs`, replace the `MainScene` lines with:
```brighterscript
  preview = new AtlasPreviewScene(game)
  game.defineScene(preview)
  game.changeScene(preview.name)
```
and delete the scaffold's `src/source/Scenes/MainScene.bs` (and `src/source/util.bs` if nothing uses it).

- [ ] **Step 4: Validate and check on-device**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npx bsc --validate --create-package=false
```
Then follow the `rokubot-examples` skill to sideload `examples/rpg` and screenshot. For each entry, check that:
- the magenta box tightly wraps the intended object, with no neighbouring art bleeding in and nothing cut off;
- the red footprint box sits on the object's base;
- `wallStrip`'s crenellations line up with `castleGate`'s when both are bottom-anchored (they must share the same bottom row of transparent padding, both 128 tall);
- each surface set shows grass-bordered corners/edges and a clean centre.

- [ ] **Step 5: Fix coordinates**

Adjust `buildAtlas()` values until every entry passes. To measure a region:
```bash
magick /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg/src/sprites/Castle2.png -crop 64x96+288+384 +repage -trim -format '%wx%h+%X+%Y\n' info:
```
(prints the tight box inside the crop, as offsets from the crop origin). Re-sideload and re-screenshot until clean. Also confirm `grass`, `water`, `stoneFloor` and `brick` tile seamlessly: temporarily draw each 4×2 times in the preview and look for seams. If one doesn't tile, pick a neighbouring cell that does and note the choice in a comment.

- [ ] **Step 6: Remove the preview and commit the atlas**

Delete `AtlasPreviewScene.bs` and remove its three lines from `main.bs`, leaving `main.bs` as: create the game, load the three bitmaps, `game.play()`. The channel shows a blank screen until Task 6 adds the real scenes, which is fine for an intermediate commit. Note the final contact-sheet screenshot's path in the commit message body for the record.

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npx bsc --validate --create-package=false
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add -A examples/rpg/src
git commit -m "rpg: tile/prop atlas, verified on-device with a contact sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Map data, ground bake, props, and the town (static camera)

**Files:**
- Create: `examples/rpg/src/source/Maps/MapData.bs`
- Create: `examples/rpg/src/source/World/TileMapEntity.bs`, `examples/rpg/src/source/World/Prop.bs`
- Create: `examples/rpg/src/source/Scenes/AreaScene.bs`, `examples/rpg/src/source/Scenes/TownScene.bs`, `examples/rpg/src/source/Scenes/CastleScene.bs`
- Modify: `examples/rpg/src/source/main.bs`

**Interfaces:**
- Consumes: `autoTilePiece` (Task 2), `SolidWorld` (Task 3), `getAtlas`/`atlasRegion`/`getSurfaceSet` (Task 5).
- Produces:
  - `const TILE_SIZE = 32`, `const GROUND_Z = -9000` (in `MapData.bs`)
  - `function getTownRows() as string[]`, `function getCastleRows() as string[]`
  - `function getTownPlacements() as object`, `function getCastlePlacements() as object`: arrays of `{atlasKey, col, row}` | `{type: "door", col, row, w, h, target, spawn}` | `{type: "spawn", id, col, row, facing}`. For props and doors, `row` is the **bottom** cell row. `col` may be fractional.
  - `function isSolidGroundChar(ch as string) as boolean`, `function groundAtlasKey(ch as string) as string`
  - `function cellBottomY(numRows as integer, row as float) as float` = `(numRows - row - 1) * TILE_SIZE`
  - `class TileMapEntity extends BGE.GameEntity`, `onCreate(args)` with `args = {rows as string[], solidWorld as SolidWorld}`
  - `class Prop extends BGE.GameEntity`, `onCreate(args)` with `args = {atlasKey as string, x as float, y as float, solidWorld as SolidWorld}` ((x, y) = image bottom-left)
  - `class AreaScene extends BGE.GameScene` with public `solidWorld as SolidWorld`, `mapWidth as float`, `mapHeight as float`, `spawns as roAssociativeArray` (id → `{x, y, facing}`), overridable `function getRows() as string[]`, `function getPlacements() as object`, and `sub updateCamera()`
  - Scene names `"TownScene"`, `"CastleScene"`

- [ ] **Step 1: Write `MapData.bs`**

```brighterscript
' Map data for the town and the castle interior. The ground layer is one string per row of
' 32px cells (row 0 = top). Legend:
'   .  grass                         c  grey cobble (auto-tiled)
'   w  white cobble (auto-tiled)     t  tan cobble (auto-tiled)
'   d  dirt (auto-tiled)             s  castle stone floor
'   ~  water (solid)                 #  solid, art supplied by a prop over it (castle walls)
'   b  brick wall (solid)            x  solid void, drawn dark
' Auto-tiled paths are written at least two cells wide - see AutoTile.bs for why.
'
' Placements put props, doors and spawn points on the map. A prop's/door's `row` is its
' bottom cell row; `col` may be fractional to centre something between cells.

const TILE_SIZE = 32
' Ground chunks sit behind everything that depth-sorts by feet position.
const GROUND_Z = -9000

function getTownRows() as string[]
  return [
    "################################################",
    "################################################",
    "#######################c########################",
    "#######################c########################",
    "~~~~..................ccc.......................",
    "~~~~..................ccc.......................",
    "~~~~..................ccc........ttttttttt......",
    "~~~~..................ccc........ttttttttt......",
    "~~~~..................ccc........ttttttttt......",
    "~~~~..................ccc........ttttttttt......",
    "~~~~..................ccc........ttttttttt......",
    "~~~~.............ccccccccccccc...ttttttttt......",
    "~~~~.............ccccccccccccc..................",
    "~~~~.............ccccccccccccc..................",
    "~~~~cccccccccccccccccccccccccccccccccccccccc....",
    "~~~~cccccccccccccccccccccccccccccccccccccccc....",
    "~~~~cccccccccccccccccccccccccccccccccccccccc....",
    "~~~~.............ccccccccccccc..................",
    "~~~~.............ccccccccccccc..................",
    "~~~~.............ccccccccccccc..................",
    "~~~~..................ccc.......................",
    "~~~~..................ccc.......................",
    "~~~~..................ccc.......................",
    "~~~~..dddddddddd......ccc.......................",
    "~~~~..dddddddddd......ccc.......................",
    "~~~~..dddddddddd......ccc.......................",
    "~~~~..................ccc.......................",
    "~~~~~~~~~~~~..........ccc.......................",
    "~~~~~~~~~~~~..........ccc.......................",
    "~~~~~~~~~~~~..........ccc.......................",
    "~~~~~~~~~~~~..........ccc.......................",
    "~~~~~~~~~~~~..........ccc......................."
  ]
end function

function getTownPlacements() as object
  p = []
  ' Castle wall along the top, broken by two towers flanking the gate.
  pushWallRun(p, 0, 19, 3)
  pushWallRun(p, 27, 47, 3)
  p.push({atlasKey: "tower", col: 20, row: 3})
  p.push({atlasKey: "tower", col: 25, row: 3})
  p.push({atlasKey: "castleGate", col: 22, row: 3})
  p.push({type: "door", col: 23, row: 3, w: 1, h: 2, target: "CastleScene", spawn: "entrance"})
  p.push({type: "spawn", id: "gate", col: 23.5, row: 5, facing: "down"})
  ' Plaza
  p.push({atlasKey: "fountain", col: 22.5, row: 12})
  p.push({atlasKey: "statue", col: 18, row: 12})
  p.push({atlasKey: "statue", col: 28, row: 12})
  p.push({atlasKey: "lampPost", col: 21, row: 10})
  p.push({atlasKey: "lampPost", col: 25, row: 10})
  p.push({atlasKey: "lampPost", col: 21, row: 21})
  p.push({atlasKey: "lampPost", col: 25, row: 21})
  p.push({atlasKey: "bench", col: 30, row: 19})
  ' Market square (tan cobble, north-east)
  p.push({atlasKey: "stallFront", col: 33, row: 8})
  p.push({atlasKey: "stallFront", col: 36, row: 8})
  p.push({atlasKey: "stallFront", col: 39, row: 8})
  p.push({atlasKey: "plantPot", col: 32, row: 8})
  p.push({atlasKey: "barrel", col: 32, row: 10})
  p.push({atlasKey: "crateStack", col: 42, row: 9})
  p.push({atlasKey: "vase", col: 42, row: 11})
  p.push({atlasKey: "goodsStall", col: 44, row: 13})
  ' West street
  p.push({atlasKey: "stallProduce", col: 7, row: 13})
  p.push({atlasKey: "crateRow", col: 12, row: 13})
  p.push({atlasKey: "sacksPile", col: 5, row: 19})
  p.push({atlasKey: "well", col: 10, row: 20})
  ' Waterfront (south-west)
  p.push({atlasKey: "boat", col: 0, row: 21})
  p.push({atlasKey: "dock", col: 1, row: 25})
  p.push({atlasKey: "boat", col: 5, row: 30})
  p.push({atlasKey: "firewood", col: 16, row: 24})
  p.push({atlasKey: "grainSack", col: 16, row: 25})
  return p
end function

function getCastleRows() as string[]
  return [
    "xxbbbbbbbbbbbbbbbbbbbbxx",
    "xxbbbbbbbbbbbbbbbbbbbbxx",
    "xxbbbbbbbbbbbbbbbbbbbbxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxssssssssssssssssssssxx",
    "xxxxxxxxxxxssxxxxxxxxxxx"
  ]
end function

function getCastlePlacements() as object
  p = []
  p.push({atlasKey: "bannerRed", col: 5, row: 2})
  p.push({atlasKey: "bannerBlue", col: 9, row: 2})
  p.push({atlasKey: "bannerRed", col: 14, row: 2})
  p.push({atlasKey: "bannerBlue", col: 18, row: 2})
  ' Blacksmith corner (west)
  p.push({atlasKey: "oreBins", col: 2, row: 4})
  p.push({atlasKey: "anvilBig", col: 3, row: 7})
  p.push({atlasKey: "anvil", col: 6, row: 7})
  p.push({atlasKey: "weaponRack", col: 2, row: 11})
  ' Hall
  p.push({atlasKey: "statue", col: 9, row: 6})
  p.push({atlasKey: "statue", col: 14, row: 6})
  p.push({atlasKey: "bench", col: 14, row: 11})
  ' Storeroom corner (east)
  p.push({atlasKey: "drawers", col: 18, row: 4})
  p.push({atlasKey: "dresser", col: 20, row: 5})
  p.push({atlasKey: "crateStack", col: 21, row: 12})
  p.push({atlasKey: "barrel", col: 20, row: 13})
  p.push({type: "door", col: 11, row: 15, w: 2, h: 1, target: "TownScene", spawn: "gate"})
  p.push({type: "spawn", id: "entrance", col: 12, row: 13, facing: "up"})
  return p
end function

sub pushWallRun(placements as object, fromCol as integer, toCol as integer, row as integer)
  for c = fromCol to toCol
    placements.push({atlasKey: "wallStrip", col: c, row: row})
  end for
end sub

function isSolidGroundChar(ch as string) as boolean
  return Instr(1, "~#bx", ch) > 0
end function

' Atlas key for a non-auto-tiled ground character ("" for 'x', which TileMapEntity draws itself).
function groundAtlasKey(ch as string) as string
  keys = {".": "grass", "#": "grass", "~": "water", "s": "stoneFloor", "b": "brick"}
  if keys.DoesExist(ch)
    return keys[ch]
  end if
  return ""
end function

' World y of a cell row's bottom edge (world +y up, row 0 at the top).
function cellBottomY(numRows as integer, row as float) as float
  return (numRows - row - 1) * TILE_SIZE
end function
```
Note: the door on the town gate is placed with `row: 3, h: 2` (bottom row 3, covering rows 2-3), matching the "bottom cell row" convention.

- [ ] **Step 2: Write `TileMapEntity.bs`**

```brighterscript
import "pkg:/source/utils/tilemap/TileMapBaking.bs"
import "pkg:/source/utils/tilemap/TileMapColliderMerging.bs"
import "../Maps/Atlas.bs"
import "../Maps/AutoTile.bs"
import "../Maps/MapData.bs"
import "SolidWorld.bs"

' One area's ground: every cell baked once into a few chunk bitmaps (a handful of draw calls
' instead of one per tile), plus the solid tiles and map bounds added to the area's SolidWorld.
class TileMapEntity extends BGE.GameEntity

  private chunkSize = 512.0
  private regionCache = {}

  sub new(game as BGE.Game)
    super(game)
    m.name = "TileMap"
  end sub

  ' @param {roAssociativeArray} args - {rows as string[], solidWorld as SolidWorld}
  override sub onCreate(args as roAssociativeArray)
    rows = args.rows
    solidWorld = args.solidWorld as SolidWorld
    numRows = rows.count()
    numCols = rows[0].len()
    m.position.z = GROUND_Z

    tiles = [] as BGE.TileMap.TileSpec[]
    cells = [] as BGE.TileMap.ColliderCell[]
    for r = 0 to numRows - 1
      for c = 0 to numCols - 1
        ch = rows[r].mid(c, 1)
        tiles.push({worldX: c * TILE_SIZE, worldY: (numRows - r) * TILE_SIZE, region: m.groundRegion(rows, r, c, ch), width: TILE_SIZE, height: TILE_SIZE})
        if isSolidGroundChar(ch)
          cells.push({row: r, col: c, tag: "solid"})
        end if
      end for
    end for

    chunks = BGE.TileMap.bakeTileMapImages(tiles, m.chunkSize)
    for i = 0 to chunks.count() - 1
      chunk = chunks[i]
      chunkRegion = CreateObject("roRegion", chunk.bitmap, 0, 0, chunk.bitmap.GetWidth(), chunk.bitmap.GetHeight())
      m.addImage("groundChunk_" + i.toStr(), chunkRegion, {
        offset: BGE.Math.VectorOps.create(chunk.worldX, chunk.worldY),
        drawMode: BGE.SceneObjectDrawMode.matchCamera
      })
    end for

    for each colliderRun in BGE.TileMap.mergeTileColliderRuns(cells)
      solidWorld.addSolid(colliderRun.startCol * TILE_SIZE, cellBottomY(numRows, colliderRun.row), (colliderRun.endCol - colliderRun.startCol + 1) * TILE_SIZE, TILE_SIZE)
    end for

    ' Map bounds, so nothing walks off an edge that has no solid tile on it.
    mapWidth = numCols * TILE_SIZE
    mapHeight = numRows * TILE_SIZE
    solidWorld.addSolid(-64, -64, mapWidth + 128, 64)
    solidWorld.addSolid(-64, mapHeight, mapWidth + 128, 64)
    solidWorld.addSolid(-64, 0, 64, mapHeight)
    solidWorld.addSolid(mapWidth, 0, 64, mapHeight)
  end sub

  private function groundRegion(rows as string[], r as integer, c as integer, ch as string) as roRegion
    surface = getSurfaceSet(ch)
    key = ch
    piece = invalid
    if surface <> invalid
      piece = autoTilePiece(rows, r, c)
      key = ch + piece.col.toStr() + piece.row.toStr()
    end if
    if m.regionCache[key] = invalid
      if piece <> invalid
        m.regionCache[key] = CreateObject("roRegion", m.game.getBitmap(surface.sheet), surface.x + piece.col * TILE_SIZE, surface.y + piece.row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
      else if ch = "x"
        m.regionCache[key] = m.voidRegion()
      else
        m.regionCache[key] = atlasRegion(m.game, getAtlas()[groundAtlasKey(ch)])
      end if
    end if
    return m.regionCache[key]
  end function

  private function voidRegion() as roRegion
    bitmap = CreateObject("roBitmap", {width: TILE_SIZE, height: TILE_SIZE, AlphaEnable: false})
    bitmap.Clear(&h141018FF)
    bitmap.Finish()
    return CreateObject("roRegion", bitmap, 0, 0, TILE_SIZE, TILE_SIZE)
  end function

end class
```
Note: AA keys are case-insensitive. `regionCache` keys like `"c01"` never collide with another surface, because the surface characters are distinct letters.

- [ ] **Step 3: Write `Prop.bs`**

```brighterscript
import "../Maps/Atlas.bs"
import "SolidWorld.bs"

' A placed atlas object. The entity sits at the image's bottom-left, with z from that y, so
' anything whose feet are lower on screen draws in front of it and anything higher draws behind.
class Prop extends BGE.GameEntity

  sub new(game as BGE.Game)
    super(game)
    m.name = "Prop"
  end sub

  ' @param {roAssociativeArray} args - {atlasKey, x, y (image bottom-left), solidWorld}
  override sub onCreate(args as roAssociativeArray)
    entry = getAtlas()[args.atlasKey]
    m.position.x = args.x
    m.position.y = args.y
    m.position.z = -args.y
    m.addImage("art", atlasRegion(m.game, entry), {
      offset: BGE.Math.VectorOps.create(0, entry.h),
      drawMode: BGE.SceneObjectDrawMode.matchCamera
    })
    if entry.footprint <> invalid
      fp = entry.footprint
      solidWorld = args.solidWorld as SolidWorld
      solidWorld.addSolid(args.x + fp.x, args.y + fp.y, fp.w, fp.h)
    end if
  end sub

end class
```

- [ ] **Step 4: Write `AreaScene.bs`, `TownScene.bs`, `CastleScene.bs`**

`AreaScene.bs` (this task's version: no player/doors yet. Task 7 and Task 8 extend it):
```brighterscript
import "../Maps/MapData.bs"
import "../World/SolidWorld.bs"
import "../World/TileMapEntity.bs"
import "../World/Prop.bs"

' Shared setup for an area: builds the ground and props from map data, keeps the camera inside
' the map, and exits the channel on Back. Subclasses supply getRows()/getPlacements().
class AreaScene extends BGE.GameScene

  solidWorld as SolidWorld = invalid
  mapWidth as float = 0
  mapHeight as float = 0
  ' Spawn id -> {x, y, facing}: player feet position on arrival.
  spawns as roAssociativeArray = {}
  ' World point the camera follows until the player exists (Task 7).
  protected cameraFocus = BGE.Math.VectorOps.create()

  sub new(game as BGE.Game)
    super(game)
  end sub

  function getRows() as string[]
    return []
  end function

  function getPlacements() as object
    return []
  end function

  override sub onCreate(args as roAssociativeArray)
    rows = m.getRows()
    numRows = rows.count()
    m.mapWidth = rows[0].len() * TILE_SIZE
    m.mapHeight = numRows * TILE_SIZE
    m.solidWorld = new SolidWorld()
    m.spawns = {}

    tileMap = new TileMapEntity(m.game)
    m.game.addEntity(tileMap, {rows: rows, solidWorld: m.solidWorld})

    for each item in m.getPlacements()
      if item.atlasKey <> invalid
        prop = new Prop(m.game)
        m.game.addEntity(prop, {atlasKey: item.atlasKey, x: item.col * TILE_SIZE, y: cellBottomY(numRows, item.row), solidWorld: m.solidWorld})
      else if item.type = "spawn"
        ' Feet a little above the cell's bottom edge, so the 12px-tall feet box sits inside the cell.
        m.spawns[item.id] = {x: item.col * TILE_SIZE, y: cellBottomY(numRows, item.row) + 10, facing: item.facing}
      end if
    end for

    m.cameraFocus = BGE.Math.VectorOps.create(m.mapWidth / 2, m.mapHeight / 2)
    m.updateCamera()
  end sub

  override sub onDrawBegin(gameRenderer as BGE.Renderer, uiRenderer as BGE.Renderer)
    m.updateCamera()
  end sub

  ' Centres the camera on cameraFocus, clamped so the view never shows past the map edge; on an
  ' axis where the map is smaller than the view, the map is centred instead.
  sub updateCamera()
    camera = m.game.canvas.renderer.camera
    target = BGE.Math.VectorOps.create(m.clampAxis(m.cameraFocus.x, camera.frameSize.x, m.mapWidth), m.clampAxis(m.cameraFocus.y, camera.frameSize.y, m.mapHeight))
    camera.setTarget(target)
  end sub

  private function clampAxis(focus as float, viewSize as float, mapSize as float) as float
    if mapSize <= viewSize
      return mapSize / 2
    end if
    half = viewSize / 2
    if focus < half
      return half
    else if focus > mapSize - half
      return mapSize - half
    end if
    return focus
  end function

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.End()
    end if
  end sub

end class
```

`TownScene.bs`:
```brighterscript
import "AreaScene.bs"
import "../Maps/MapData.bs"

class TownScene extends AreaScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "TownScene"
  end sub

  override function getRows() as string[]
    return getTownRows()
  end function

  override function getPlacements() as object
    return getTownPlacements()
  end function

end class
```

`CastleScene.bs`:
```brighterscript
import "AreaScene.bs"
import "../Maps/MapData.bs"

class CastleScene extends AreaScene

  sub new(game as BGE.Game)
    super(game)
    m.name = "CastleScene"
  end sub

  override function getRows() as string[]
    return getCastleRows()
  end function

  override function getPlacements() as object
    return getCastlePlacements()
  end function

end class
```

If bsc reports the known subclass transpile crash (`toTypeString`) for these subclasses, give each an explicit fully-qualified constructor as described in memory `project_bsc_subclass_transpile_crash` (the `sub new` above already is one).

- [ ] **Step 5: Wire up `main.bs`**

```brighterscript
sub Main(args = {} as object)
  game = new BGE.Game(640, 360)
  game.fitCanvasToScreen()
  game.loadBitmap("town", "pkg:/sprites/PathAndObjects.png")
  game.loadBitmap("castle", "pkg:/sprites/Castle2.png")
  game.loadBitmap("adventurer", "pkg:/sprites/adventurer.png")

  town = new TownScene(game)
  game.defineScene(town)
  castle = new CastleScene(game)
  game.defineScene(castle)

  startScene = "TownScene"
  ' Deep link (e.g. rokubot launch dev --param scene=CastleScene) for checking one area directly.
  if args.scene <> invalid
    startScene = args.scene
  end if
  game.changeScene(startScene)
  game.play()
end sub
```
Add `import "Scenes/TownScene.bs"` and `import "Scenes/CastleScene.bs"` at the top of `main.bs`.

- [ ] **Step 6: Validate, then check both areas on-device**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npx bsc --validate --create-package=false && npm test
```
Then, via the `rokubot-examples` skill: sideload, launch (town, camera at map centre), screenshot. Then launch with `--param scene=CastleScene` and screenshot. Check:
- the ground is continuous (no chunk seams), and cobble edges blend into grass;
- the wall, towers and gate line up along the top edge (to see the top, temporarily set `cameraFocus` to `{x: 752, y: 900}` in `AreaScene.onCreate` and revert after);
- props sit where the map intends; stalls on the tan square, the fountain in the plaza;
- props lower on screen overlap props above them (depth sort working). If props draw in insertion order instead, depth sorting isn't picking up `z`. Stop, check `Camera2d` near/far against the z range, and scale z (e.g. `-y * 0.5`) per the spec's Risks section.

Note the time from launch to the first frame. Risk: bake cost.

- [ ] **Step 7: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add -A examples/rpg/src
git commit -m "rpg: build the town and castle from map data (baked ground, props, solids)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Player movement, animation, depth, and camera follow

**Files:**
- Create: `examples/rpg/src/source/Entities/Player.bs`
- Modify: `examples/rpg/src/source/Scenes/AreaScene.bs`, `examples/rpg/src/source/main.bs`

**Interfaces:**
- Consumes: `SolidWorld.moveAndSlide` (Task 3), `facingFor` (Task 4), `AreaScene.spawns`/`solidWorld`/`cameraFocus` (Task 6).
- Produces:
  - `class Player extends BGE.GameEntity`, `name = "Player"`, `persistent = true`
  - `sub placeAt(x as float, y as float, facing as string, solidWorld as SolidWorld)`
  - `inputLocked as boolean` (public; Task 8's fade sets and clears it)
  - constants `PLAYER_SPEED = 90.0`, `PLAYER_BOX_W = 20.0`, `PLAYER_BOX_H = 12.0`
  - a `"feet"` `RectangleCollider` covering the feet box (Task 8's doors detect it)

- [ ] **Step 1: Write `Player.bs`**

```brighterscript
import "../World/SolidWorld.bs"
import "Facing.bs"

' Walk speed at full stick deflection, px/sec (about Link to the Past's walking pace).
const PLAYER_SPEED = 90.0
' Collision box at the feet only, so the head can overlap walls and awnings above.
const PLAYER_BOX_W = 20.0
const PLAYER_BOX_H = 12.0

' The player. Its position is the bottom-centre of the feet box. It moves itself through the
' area's SolidWorld rather than via velocity, so the engine's own velocity step never moves it
' without collision.
class Player extends BGE.GameEntity

  solidWorld as SolidWorld = invalid
  facing as string = "down"
  ' Set while a scene transition is fading, so the player can't walk mid-fade.
  inputLocked as boolean = false
  private sprite as BGE.Sprite = invalid

  sub new(game as BGE.Game)
    super(game)
    m.name = "Player"
    m.persistent = true
  end sub

  override sub onCreate(args as roAssociativeArray)
    ' adventurer.png: 16 rows of 8 96x80 cells - see main.bs's composition note for the row order.
    m.sprite = m.addSprite("body", m.game.getBitmap("adventurer"), 96, 80)
    ' Pins the art's feet (48, 58 within each cell) onto the entity's position.
    m.sprite.applyPreTranslation(-48, -58)
    animations = ["idle_down", "idle_up", "idle_left", "idle_right", "run_down", "run_up", "run_left", "run_right"]
    for i = 0 to animations.count() - 1
      frameRate = 8
      if i >= 4
        frameRate = 12
      end if
      m.sprite.addAnimation(animations[i], {startFrame: i * 8, frameCount: 8}, frameRate, BGE.SpritePlayMode.Loop)
    end for
    m.sprite.playAnimation("idle_down")
    m.addRectangleCollider("feet", PLAYER_BOX_W, PLAYER_BOX_H, -PLAYER_BOX_W / 2, PLAYER_BOX_H)
  end sub

  ' Puts the player at an area's spawn point, bound to that area's solids.
  '
  ' @param {float} x - feet x
  ' @param {float} y - feet y
  ' @param {string} facing
  ' @param {SolidWorld} solidWorld
  sub placeAt(x as float, y as float, facing as string, solidWorld as SolidWorld)
    m.position.x = x
    m.position.y = y
    m.position.z = -y
    m.facing = facing
    m.solidWorld = solidWorld
    m.sprite.playAnimation("idle_" + facing)
  end sub

  override sub onUpdate(dt as float)
    if m.solidWorld = invalid
      return
    end if
    ' A long frame (e.g. right after an area is baked) shouldn't turn into one big jump.
    if dt > 0.1
      dt = 0.1
    end if

    moveX = 0.0
    moveY = 0.0
    if not m.inputLocked
      axis = m.game.controls.getAxis("move")
      moveX = axis.x
      moveY = axis.y
    end if
    magnitude = Sqr(moveX * moveX + moveY * moveY)
    if magnitude > 1
      moveX = moveX / magnitude
      moveY = moveY / magnitude
    end if

    if magnitude < 0.05
      m.sprite.playAnimation("idle_" + m.facing)
      return
    end if

    box = {x: m.position.x - PLAYER_BOX_W / 2, y: m.position.y, w: PLAYER_BOX_W, h: PLAYER_BOX_H}
    result = m.solidWorld.moveAndSlide(box, moveX * PLAYER_SPEED * dt, moveY * PLAYER_SPEED * dt)
    m.position.x = result.x + PLAYER_BOX_W / 2
    m.position.y = result.y
    m.position.z = -m.position.y
    m.facing = facingFor(moveX, moveY, m.facing)
    m.sprite.playAnimation("run_" + m.facing)
  end sub

end class
```

- [ ] **Step 2: Bind input and create the player in `main.bs`**

After the `loadBitmap` calls:
```brighterscript
  game.enableControllerInput()
  game.controls.bindAxis("move", "1", 0, "Move")

  ' Created once and persistent - each area positions it on arrival.
  player = new Player(game)
  game.addEntity(player)
```
Add `import "Entities/Player.bs"`.

- [ ] **Step 3: Place the player and follow it in `AreaScene`**

Add `import "../Entities/Player.bs"`. At the end of `AreaScene.onCreate`, replace the `cameraFocus`/`updateCamera()` lines with:
```brighterscript
    spawnId = args.spawn
    if spawnId = invalid or m.spawns[spawnId] = invalid
      spawnId = m.spawns.Keys()[0]
    end if
    spawn = m.spawns[spawnId]
    player = m.game.getEntityByName("Player") as Player
    player.placeAt(spawn.x, spawn.y, spawn.facing, m.solidWorld)
    m.updateCamera()
```
Replace `updateCamera()` so it follows the player:
```brighterscript
  sub updateCamera()
    player = m.game.getEntityByName("Player")
    if player <> invalid
      m.cameraFocus = player.position
    end if
    camera = m.game.canvas.renderer.camera
    target = BGE.Math.VectorOps.create(m.clampAxis(m.cameraFocus.x, camera.frameSize.x, m.mapWidth), m.clampAxis(m.cameraFocus.y, camera.frameSize.y, m.mapHeight))
    camera.setTarget(target)
  end sub
```
(`onDrawBegin` runs after every entity's update, so the camera never trails the player by a frame. If the scene's `onDrawBegin` turns out not to be called, move the `updateCamera()` call to the end of `Player.onUpdate` via `(m.game.currentScene as AreaScene).updateCamera()` and note why.)

In `main.bs`, the initial `changeScene` gets `{spawn: "gate"}` for the town. Leave the deep-link path without args, which falls back to the first spawn.

- [ ] **Step 4: Validate and smoke-test on-device**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npx bsc --validate --create-package=false && npm test
```
Via `rokubot-examples`: sideload, launch. Screenshot the player below the gate, facing down. Press Down briefly and screenshot. Press Left briefly and screenshot. Check:
- **y direction:** pressing Down moves the player down the screen. If it moves up, `getAxis`'s y isn't world +y up. Flip `moveY` and add a comment saying so;
- the sprite's feet sit on the ground point (no floating), and it faces the pressed direction;
- the camera follows and stops at the map edge (hold Left toward the water and screenshot: no area past the map edge visible);
- walking into a stall stops at its counter.

Don't judge feel here. That's Mark's playtest in Task 9.

- [ ] **Step 5: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add -A examples/rpg/src
git commit -m "rpg: player movement with wall sliding, facing animations and camera follow

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Doors, screen fade, and area transitions

**Files:**
- Create: `examples/rpg/src/source/World/ScreenFade.bs`, `examples/rpg/src/source/World/Door.bs`
- Modify: `examples/rpg/src/source/Scenes/AreaScene.bs`, `examples/rpg/src/source/main.bs`

**Interfaces:**
- Consumes: `Player.inputLocked`, the `"feet"` collider, `Player.name = "Player"` (Task 7). Placement `{type: "door", ...}` entries (Task 6).
- Produces:
  - `class ScreenFade extends BGE.GameEntity`, `name = "ScreenFade"`, `persistent = true`: `alpha as float` (0-255, starts 255), `function isActive() as boolean`, `sub transitionTo(sceneName as string, args as roAssociativeArray)`, `sub fadeIn()`, plus tween callbacks `sub onFadedOut()`/`sub onFadedIn()`
  - `class Door extends BGE.GameEntity`, `name = "Door"`: `onCreate(args)` with `args = {x, y, w, h, target, spawn}` in world units, (x, y) = bottom-left

- [ ] **Step 1: Write `ScreenFade.bs`**

```brighterscript
import "../Entities/Player.bs"

const FADE_MS = 300

' A full-screen black overlay for area transitions: fade out, change scene, fade back in. The
' player's input is locked for the whole transition. Persistent, so it survives the scene change
' it triggers.
class ScreenFade extends BGE.GameEntity

  ' 255 = fully black. Starts black, so the first area fades in on launch.
  alpha as float = 255.0
  private active as boolean = false
  private pendingScene as string = ""
  private pendingArgs as roAssociativeArray = {}

  sub new(game as BGE.Game)
    super(game)
    m.name = "ScreenFade"
    m.persistent = true
  end sub

  function isActive() as boolean
    return m.active
  end function

  ' Fades to black, then changes to sceneName with args. Ignored if a transition is already running.
  '
  ' @param {string} sceneName
  ' @param {roAssociativeArray} args - passed to the new scene's onCreate()
  sub transitionTo(sceneName as string, args as roAssociativeArray)
    if m.active
      return
    end if
    m.active = true
    m.setPlayerLocked(true)
    m.pendingScene = sceneName
    m.pendingArgs = args
    m.game.tweenManager.to(m, {alpha: 255.0}, FADE_MS, BGE.Tweens.Easing.LinearTween, {
      owner: m,
      onComplete: sub(targetObj as object)
        fade = targetObj as ScreenFade
        fade.onFadedOut()
      end sub
    })
  end sub

  sub onFadedOut()
    m.game.changeScene(m.pendingScene, m.pendingArgs)
  end sub

  ' Fades from black to clear, then unlocks the player. Called by each area once it's built.
  sub fadeIn()
    m.active = true
    m.setPlayerLocked(true)
    m.game.tweenManager.to(m, {alpha: 0.0}, FADE_MS, BGE.Tweens.Easing.LinearTween, {
      owner: m,
      onComplete: sub(targetObj as object)
        fade = targetObj as ScreenFade
        fade.onFadedIn()
      end sub
    })
  end sub

  sub onFadedIn()
    m.active = false
    m.setPlayerLocked(false)
  end sub

  override sub onDrawEnd(gameRenderer as BGE.Renderer, uiRenderer as BGE.Renderer)
    if m.alpha >= 1
      size = uiRenderer.getCanvasSize()
      ' Packed RGBA with black RGB is just the alpha byte.
      uiRenderer.drawRectangle(0, 0, size.x, size.y, Int(m.alpha))
    end if
  end sub

  private sub setPlayerLocked(locked as boolean)
    player = m.game.getEntityByName("Player") as Player
    if player <> invalid
      player.inputLocked = locked
    end if
  end sub

end class
```

- [ ] **Step 2: Write `Door.bs`**

```brighterscript
import "ScreenFade.bs"

' A trigger zone that starts a transition when the player's feet enter it. It starts disarmed and
' arms once the player isn't overlapping it, so arriving next to (or on) a door never bounces the
' player straight back through it.
class Door extends BGE.GameEntity

  target as string = ""
  spawn as string = ""
  private armed as boolean = false
  ' Starts true so the first update can't arm the door before collisions have been checked once.
  private overlappedLastFrame as boolean = true

  sub new(game as BGE.Game)
    super(game)
    m.name = "Door"
  end sub

  ' @param {roAssociativeArray} args - {x, y (bottom-left), w, h, target (scene name), spawn (spawn id)}
  override sub onCreate(args as roAssociativeArray)
    m.position.x = args.x
    m.position.y = args.y
    m.target = args.target
    m.spawn = args.spawn
    m.addRectangleCollider("zone", args.w, args.h, 0, args.h)
  end sub

  ' Updates run before collisions each frame, so this sees whether last frame had an overlap.
  override sub onUpdate(dt as float)
    if not m.overlappedLastFrame
      m.armed = true
    end if
    m.overlappedLastFrame = false
  end sub

  override sub onCollision(myCollider as BGE.Collider, otherCollider as BGE.Collider, otherEntity as BGE.GameEntity)
    if otherEntity.name <> "Player"
      return
    end if
    m.overlappedLastFrame = true
    if m.armed
      m.armed = false
      fade = m.game.getEntityByName("ScreenFade") as ScreenFade
      fade.transitionTo(m.target, {spawn: m.spawn})
    end if
  end sub

end class
```

- [ ] **Step 3: Create doors and fade in from `AreaScene`, create `ScreenFade` in `main.bs`**

In `AreaScene.bs` add `import "../World/Door.bs"` and `import "../World/ScreenFade.bs"`. In the placements loop, add a branch before the spawn branch:
```brighterscript
      else if item.type = "door"
        door = new Door(m.game)
        m.game.addEntity(door, {x: item.col * TILE_SIZE, y: cellBottomY(numRows, item.row), w: item.w * TILE_SIZE, h: item.h * TILE_SIZE, target: item.target, spawn: item.spawn})
```
At the very end of `onCreate`, after `m.updateCamera()`:
```brighterscript
    fade = m.game.getEntityByName("ScreenFade") as ScreenFade
    fade.fadeIn()
```
In `main.bs`, before creating the player:
```brighterscript
  fade = new ScreenFade(game)
  game.addEntity(fade)
```
and add `import "World/ScreenFade.bs"`.

- [ ] **Step 4: Validate and smoke-test the round trip on-device**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine/examples/rpg && npx bsc --validate --create-package=false && npm test
cd /Users/mpearce/redspace/roku/brighterscript-game-engine && npm run check
```
Via `rokubot-examples`:
1. Launch. Screenshot after about 1s: the town has faded in, the player is below the gate.
2. Hold Up until the player enters the gate (about 1.5s), release, wait 1s, screenshot: the castle interior with the player just inside the south door, facing up. Watch the snag risk: if the player sticks on the gate pillars instead of entering, the corner nudge isn't reaching (check the door placement and the `'#'` cells beside column 23).
3. Hold Down until the player leaves through the south door, release, wait 1s, screenshot: the town with the player below the gate facing down. It must not immediately re-enter the castle.
4. Press Back: the channel exits.

Per memory `feedback_rokubot_held_key_timing`, screenshot before key-up if timing matters, and check for stuck keys across relaunches.

- [ ] **Step 5: Commit**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add -A examples/rpg/src
git commit -m "rpg: doors with fade transitions between the town and the castle

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Docs, follow-up issues, final checks, and playtest hand-off

**Files:**
- Modify: `README.md` (example table after the `platformer` row at line 111; screenshot gallery near line 28), `docs/game-engine-overview.md:19`, `CLAUDE.md` (Commands/examples intro, plus a short `examples/rpg` note)
- Create: `assets/screenshots/rpg.jpg`

- [ ] **Step 1: Screenshot for the README**

Via `rokubot-examples`, take a screenshot of the town with the player in the plaza near the fountain and stalls. Convert it to JPEG at the same size as the other gallery shots (check `magick identify assets/screenshots/platformer.jpg`) and save it as `assets/screenshots/rpg.jpg`.

- [ ] **Step 2: README**

Add a gallery `<figure>` matching the platformer one's markup, with alt text describing the shot and figcaption: `<a href="https://github.com/markwpearce/brighterscript-game-engine/tree/main/examples/rpg">RPG example</a> - a top-down town and castle with auto-tiled paths, depth-sorted props, wall sliding and fade transitions`.

Add a table row after `platformer`:
```markdown
| [`rpg`](examples/rpg) | A *Link to the Past*-style top-down world (work in progress, issue #63): an auto-tiled town built from character-grid map data, free movement that slides along walls, props the player walks in front of and behind, and fade transitions between the town and a castle interior using persistent entities |
```

- [ ] **Step 3: Overview guide**

In `docs/game-engine-overview.md` line 19's sample-channel list, add `` `rpg` `` after `` `platformer` ``. Keep the sentence grammatical and re-wrap the lines if needed.

- [ ] **Step 4: CLAUDE.md**

In the "What this is" paragraph's example list, add `rpg` after `platformer`. Then add a bullet under "Conventions specific to this codebase" (or near the platformer mentions, whichever reads better):
```markdown
- **`examples/rpg` depth and collision** (issue #63): top-down depth sorting is just `position.z = -feetY` on every entity under `Camera2d` (ground chunks at `GROUND_Z = -9000`), so anything lower on screen draws in front with no engine support. Its `SolidWorld.moveAndSlide()` (wall sliding + corner nudge) is deliberately example code, not engine code - it resolves movement against plain rectangles and only uses compositor colliders for door triggers. Its pure-logic files (`AutoTile.bs`, `SolidWorld.bs`, `Facing.bs`) have their own Rooibos suite in `examples/rpg/tests/`, run with `cd examples/rpg && npm test` (not part of `npm run check`/CI).
```

- [ ] **Step 5: Full checks**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine && npm run check && npm run validate-examples
cd examples/rpg && npm test
```
Expected: everything passes. Report actual output if anything fails.

- [ ] **Step 6: File follow-up issues**

Following memory `feedback_work_items_in_github_issues`:
```bash
gh issue create --title "examples/rpg Slice B: action combat (sword, enemies, health, hearts HUD)" --body "Follow-up to #63 Slice A (specs/2026-09-27-rpg-slice-a-world-design.md). Sword swing using the adventurer sheet's attack1/attack2 rows (already in adventurer.png, rows 8-15), enemies with contact damage and knockback, player health, and a hearts HUD. Decide whether enemies need SolidWorld.moveAndSlide - if so, consider promoting it to the engine."
gh issue create --title "examples/rpg Slice C: NPC dialogue, pickups/inventory, quest flag, save/load" --body "Follow-up to #63 Slice A. NPC dialogue in a BGE.UI panel (multi-page, OK to advance - check whether Label needs word wrapping; file an engine issue if so), item pickups and a minimal inventory panel, a quest flag via onGameEvent, save/load of position + inventory via registryRead/registryWrite. Keep UI title-safe."
```
Add any engine gaps found during Tasks 5-8 as their own issues (e.g. Camera2d depth range, if it needed working around). Mention every new issue number in the PR description.

- [ ] **Step 7: Commit docs**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git add README.md docs/game-engine-overview.md CLAUDE.md assets/screenshots/rpg.jpg
git commit -m "Document examples/rpg in README, overview guide and CLAUDE.md

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Hand off for playtest**

Ask Mark to play it (sideload `examples/rpg`) and report on: walking speed and animation rates, sliding along walls, easing into the gate opening, walking behind stall awnings and wall tops, camera clamping at map edges, and fade timing. Adjust `PLAYER_SPEED`, the frame rates, `SOLID_CORNER_NUDGE` and `FADE_MS` per the feedback before opening the PR (the PR itself follows superpowers:finishing-a-development-branch and the `pr-voice` skill).
