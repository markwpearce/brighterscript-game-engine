# Rename `Room` to `Scene` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the engine's `Room` concept to `Scene` (and the renderer's `drawScene`/`addToScene`/`removeFromScene` to `render`/`addToRenderer`/`removeFromRenderer`) across engine, tests, tooling, examples and all documentation, as a clean break.

**Architecture:** A throwaway codemod script (kept in the session scratchpad, never committed) does the mechanical identifier renames and `git mv` file moves, in two modes (`room`, `renderer`) so each concern lands as its own reviewable commit. Everything that needs judgment (doc comments, prose, SVG labels, the hybrid example's name clash, the changelog) is done by hand afterward.

**Tech Stack:** BrighterScript (`bsc` 1.0.0-alpha.55), Rooibos v6 tests run headlessly via `brs-cli`, bslint, Node scaffolding scripts, JSDoc (`clean-jsdoc-theme`) docs site, rokubot for on-device checks.

**Spec:** `specs/2026-09-24-room-to-scene-rename-design.md`

## Global Constraints

- New name is `Scene` everywhere a consumer sees it. The renderer renames are exactly: `Renderer.drawScene()` → `Renderer.render()`, `Drawable.addToScene(renderer)` → `Drawable.addToRenderer(renderer)`, `Drawable.removeFromScene(renderer)` → `Drawable.removeFromRenderer(renderer)`.
- Keep `SceneObject*`, `Renderer.addSceneObject()`/`removeSceneObject()`/`getSceneObjects()` unchanged.
- Clean break: no deprecated aliases, no runtime detection of leftover overrides.
- `examples/hybrid`'s `MainRoom` becomes `GameScene` (not `MainScene`, which is already its SceneGraph component's name).
- Must not change: `headroom` (comment in `Camera3d.bs`), `examples/terrain/src/sprites/SuperMarioKartMapMushroomCup1.png`.
- Do not edit historical records in `specs/` (other than this plan and its spec) or `docs/superpowers/plans/`.
- `examples/scenegraph` is untouched. `rendererTest`'s private `resetScene()`/`timeDrawScene()` in `StaticGeometryBspBenchmark.bs` stay as they are.
- Doc comments are written for the consumer (a game developer using the engine), per CLAUDE.md. Code comments stay terse.
- A `*.spec.bs` file may contain only one `@suite` class (helper classes without `@suite` are fine). A test helper subclass of an engine class needs an explicit constructor with fully-qualified param types (e.g. `sub new(game as BGE.Game)`), or bsc crashes at transpile.
- `assertEqual` is type-strict (Integer vs Float).
- Work on branch `refactor/issue-227-room-to-scene` (already created, spec already committed). Never push to `main`.
- End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Scene-change hook dispatch after the rename.** `Game.handleSceneChange()` looks up `entity.onChangeScene` by name; a missed rename there makes every entity's cleanup silently stop, with no compile error. Expected: every valid entity (persistent or not) gets `onChangeScene(newScene)` before non-persistent ones are destroyed, and the outgoing scene gets it too. Pinned by new tests in Task 1.
2. **`UiContainer` forwarding.** `UiContainer.onChangeScene()` forwards to each child. Expected: a child widget's `onChangeScene` override runs when its container's does. Pinned by a new test in Task 1.
3. **Drawable removal from the renderer.** `GameEntity.removeDrawable()`/`invalidate()` call `removeFromRenderer()`; nothing tests that path today. Expected: after `removeDrawable()`, the renderer's scene-object count drops back. Pinned by a new test in Task 2.
4. **A freshly scaffolded project/scene compiles.** Expected: `create-example` + `create-scene` output validates with `bsc` on the first try. Pinned by a scripted check in Task 3.
5. **Example scene names still resolve at runtime.** `changeScene("X")` takes a string; a renamed class with a stale string (or the hybrid clash) compiles fine but logs "hasn't been defined" and shows nothing. Expected: every example's scene transitions still work. Pinned by the leftover grep plus the on-device smoke run in Task 7.

---

## Codemod script (used by Tasks 1, 2 and 4)

Create this once, before Task 1, in the session scratchpad (not in the repo):
`/private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py`

```python
#!/usr/bin/env python3
"""Throwaway codemod for issue #227. Not committed.

Usage: rename_room.py <mode> <path-prefix> [<path-prefix> ...]
  mode: "room"     - Room -> Scene identifiers/prose + file moves
        "renderer" - drawScene/addToScene/removeFromScene renames
Only git-tracked files under the given prefixes are touched.
"""
import os
import re
import subprocess
import sys

REPO = "/Users/mpearce/redspace/roku/brighterscript-game-engine"
TEXT_EXT = (".bs", ".brs", ".js", ".json", ".xml")
EXCLUDE_PREFIXES = ("specs/", "docs/superpowers/")
KEEP = {"headroom"}

RENDERER_MAP = {
    "drawScene": "render",
    "addToScene": "addToRenderer",
    "removeFromScene": "removeFromRenderer",
    "rendererScene": "renderer",
    "renderScene": "renderer",
}

TOKEN = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")


def rename_room_token(tok, path):
    if tok in KEEP or "Mushroom" in tok:
        return tok
    if path.startswith("examples/hybrid/") and tok.startswith("MainRoom"):
        return "GameScene" + tok[len("MainRoom"):]
    new = tok.replace("Room", "Scene")
    if new.startswith("room"):
        new = "scene" + new[4:]
    new = new.replace("_room", "_scene").replace("-room", "-scene")
    return new


def rewrite(text, mode, path):
    if mode == "renderer":
        return TOKEN.sub(lambda m: RENDERER_MAP.get(m.group(0), m.group(0)), text)
    return TOKEN.sub(lambda m: rename_room_token(m.group(0), path), text)


def tracked(prefixes):
    out = subprocess.run(["git", "ls-files", "--", *prefixes], cwd=REPO,
                         capture_output=True, text=True, check=True).stdout
    return [p for p in out.splitlines() if not p.startswith(EXCLUDE_PREFIXES)]


def main():
    mode, prefixes = sys.argv[1], sys.argv[2:]
    assert mode in ("room", "renderer"), mode
    files = tracked(prefixes)

    changed = 0
    for rel in files:
        if not rel.endswith(TEXT_EXT):
            continue
        full = os.path.join(REPO, rel)
        with open(full, encoding="utf-8") as f:
            old = f.read()
        new = rewrite(old, mode, rel)
        if new != old:
            with open(full, "w", encoding="utf-8") as f:
                f.write(new)
            changed += 1
    print(f"rewrote {changed} files")

    if mode != "room":
        return
    moved = 0
    for rel in files:
        parts = rel.split("/")
        new_parts = [rename_room_token(p, rel) if "oom" in p else p for p in parts]
        # Directory "Rooms" -> "Scenes"; file stems like MainRoom.bs -> MainScene.bs
        new_rel = "/".join(new_parts)
        if new_rel != rel:
            os.makedirs(os.path.dirname(os.path.join(REPO, new_rel)), exist_ok=True)
            subprocess.run(["git", "mv", rel, new_rel], cwd=REPO, check=True)
            moved += 1
    print(f"moved {moved} files")


if __name__ == "__main__":
    main()
```

Notes for whoever runs it:
- Path components go through the same token rule: `Rooms` → `Scenes`, `MainRoom.bs` → `MainScene.bs`, `create-room.js` → `create-scene.js`, `roomTemplate.bs` → `sceneTemplate.bs`, `Room.spec.bs` → `Scene.spec.bs`, and in `examples/hybrid/` only, `MainRoom.bs` → `GameScene.bs`. `SuperMarioKartMapMushroomCup1.png` is skipped by the `Mushroom` guard.
- Prose inside comments and strings is rewritten too ("the current room" → "the current scene"). Every task that runs the script includes a manual read of the diff to fix grammar and wording.

---

### Task 1: Engine `Room` → `Scene`

**Files:**
- Move: `src/source/engine/Room.bs` → `src/source/engine/Scene.bs`
- Move: `src/source/engine/Room.spec.bs` → `src/source/engine/Scene.spec.bs`
- Modify (codemod, then hand review): every tracked file under `src/` containing `Room`/`room` identifiers, chiefly `src/source/engine/Game.bs`, `src/source/engine/GameEntity.bs`, `src/source/engine/interfaces.bs`, `src/source/engine/ui/UiContainer.bs`, plus the spec files `Game.spec.bs`, `GameEntity.spec.bs`, `GameRaycast.spec.bs`, `renderer/Renderer.spec.bs`
- Test: `src/source/engine/Scene.spec.bs`, `src/source/engine/Game.spec.bs`, `src/source/engine/ui/UiContainer.spec.bs`

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 3, 4, 5, 6): `class BGE.Scene extends BGE.GameEntity` with field `persistDrawablesAcrossSceneChange as boolean`; `GameEntity.onChangeScene(newScene as Scene)`; `Game.defineScene(newScene as Scene)`, `Game.changeScene(sceneName as string, args = {} as roAssociativeArray) as boolean`, `Game.resetScene()`, `Game.getScene() as Scene`, `Game.getSceneNames() as string[]`, `Game.isSceneChanging() as boolean`; fields `Game.currentScene as Scene`, `Game.currentSceneArgs`, `Game.Scenes`; `interface BGE.SceneChangeInfo { scene as Scene, args as roAssociativeArray }`.

- [ ] **Step 1: Write the failing tests (new-name API)**

Move the spec file and switch it to the new API by hand first, so it fails against the unrenamed engine:

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git mv src/source/engine/Room.spec.bs src/source/engine/Scene.spec.bs
```

Replace the whole contents of `src/source/engine/Scene.spec.bs` with:

```brighterscript
namespace tests

  ' Scene is just a GameEntity subclass - the "current scene" is processed
  ' like any other entity (see Game.processEntitiesPreDraw), always first/
  ' last in the update and collision passes. This mostly confirms Scene
  ' participates correctly in the same GameEntity/Game machinery already
  ' covered by GameEntity.spec.bs/Game.spec.bs.
  @suite("BGE.Scene")
  class SceneTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
    end function

    @describe("new")

    @it("takes its name from the constructor args, like any GameEntity")
    function _()
      scene = new BGE.Scene(m.game, {name: "MainScene"})
      m.assertEqual("MainScene", scene.name)
    end function

    @it("is valid immediately after creation")
    function _()
      scene = new BGE.Scene(m.game, {name: "MainScene"})
      m.assertTrue(scene.isValid())
    end function

    @describe("defineScene / changeScene / getScene round trip")

    @it("becomes the game's current scene once changed to")
    function _()
      scene = new BGE.Scene(m.game, {name: "MainScene"})
      m.game.defineScene(scene)
      m.game.changeScene("MainScene")

      m.assertEqual(scene.id, m.game.getScene().id)
      m.assertEqual("MainScene", m.game.getScene().name)
    end function

    @it("lists every defined scene in getSceneNames()")
    function _()
      m.game.defineScene(new BGE.Scene(m.game, {name: "SceneA"}))
      m.game.defineScene(new BGE.Scene(m.game, {name: "SceneB"}))

      names = m.game.getSceneNames()
      names.Sort()
      m.assertEqual(2, names.Count())
      m.assertEqual("SceneA", names[0])
      m.assertEqual("SceneB", names[1])
    end function

    @it("returns false and keeps the current scene when changing to an undefined scene")
    function _()
      scene = new BGE.Scene(m.game, {name: "SceneA"})
      m.game.defineScene(scene)
      m.game.changeScene("SceneA")

      m.assertFalse(m.game.changeScene("DoesNotExist"))
      m.assertEqual("SceneA", m.game.getScene().name)
    end function

    ' See #144: a Scene's own directly-added drawables aren't in Game.sortedEntities, so
    ' they're never touched by Game.handleSceneChange()'s automatic non-persistent-entity
    ' cleanup. Scene's default onChangeScene() compensates for that gap directly.
    @describe("onChangeScene - default drawable cleanup (#144)")

    @it("removes this scene's own directly-added drawables by default when changing to a different scene")
    function _()
      sceneA = new BGE.Scene(m.game, {name: "SceneA"})
      sceneB = new BGE.Scene(m.game, {name: "SceneB"})
      m.game.defineScene(sceneA)
      m.game.defineScene(sceneB)

      ' Immediate - currentScene is still invalid at this point.
      m.game.changeScene("SceneA")
      sceneA.addDrawable("rect", new BGE.DrawableRectangle(sceneA, 10, 10))
      m.assertNotInvalid(sceneA.getDrawable("rect"))

      ' A scene change past the first is deferred to end-of-frame unless the game isn't
      ' running - End() forces changeScene to process it immediately for this test.
      m.game.End()
      m.game.changeScene("SceneB")

      m.assertEqual(0, sceneA.drawablesByName.Count())
    end function

    @it("keeps its own drawables across a scene change when persistDrawablesAcrossSceneChange is true")
    function _()
      sceneA = new BGE.Scene(m.game, {name: "SceneA"})
      sceneB = new BGE.Scene(m.game, {name: "SceneB"})
      sceneA.persistDrawablesAcrossSceneChange = true
      m.game.defineScene(sceneA)
      m.game.defineScene(sceneB)

      m.game.changeScene("SceneA")
      sceneA.addDrawable("rect", new BGE.DrawableRectangle(sceneA, 10, 10))

      m.game.End()
      m.game.changeScene("SceneB")

      m.assertNotInvalid(sceneA.getDrawable("rect"))
    end function

    @it("does not remove drawables when 'changing' to the same scene (e.g. Game.resetScene())")
    function _()
      sceneA = new BGE.Scene(m.game, {name: "SceneA"})
      m.game.defineScene(sceneA)

      m.game.changeScene("SceneA")
      sceneA.addDrawable("rect", new BGE.DrawableRectangle(sceneA, 10, 10))

      m.game.End()
      m.game.resetScene()

      m.assertNotInvalid(sceneA.getDrawable("rect"))
    end function

  end class

end namespace
```

Add to `src/source/engine/Game.spec.bs`, inside `class GameTests` (after the last existing `@it` block, before `end class`):

```brighterscript
    @describe("changeScene - onChangeScene dispatch")

    @it("calls onChangeScene on every entity, persistent or not, before destroying non-persistent ones")
    function _()
      sceneA = new BGE.Scene(m.game, {name: "SceneA"})
      sceneB = new BGE.Scene(m.game, {name: "SceneB"})
      m.game.defineScene(sceneA)
      m.game.defineScene(sceneB)
      m.game.changeScene("SceneA")

      transient = new SceneChangeRecordingEntity(m.game, {name: "Transient"})
      keeper = new SceneChangeRecordingEntity(m.game, {name: "Keeper"})
      keeper.persistent = true
      m.game.addEntity(transient)
      m.game.addEntity(keeper)

      m.game.End()
      m.game.changeScene("SceneB")

      m.assertEqual("SceneB", transient.lastNewSceneName)
      m.assertEqual("SceneB", keeper.lastNewSceneName)
      m.assertFalse(transient.isValid())
      m.assertTrue(keeper.isValid())
    end function

    @it("calls onChangeScene on the outgoing scene itself")
    function _()
      outgoing = new SceneChangeRecordingScene(m.game, {name: "Outgoing"})
      incoming = new BGE.Scene(m.game, {name: "Incoming"})
      m.game.defineScene(outgoing)
      m.game.defineScene(incoming)
      m.game.changeScene("Outgoing")

      m.game.End()
      m.game.changeScene("Incoming")

      m.assertEqual("Incoming", outgoing.lastNewSceneName)
      m.assertFalse(m.game.isSceneChanging())
    end function
```

And add these helper classes to `src/source/engine/Game.spec.bs`, after `class GameTests`'s `end class` and alongside the existing helper classes (e.g. after `class InputRecordingEntity ... end class`):

```brighterscript
  ' Records the name of the scene passed to its most recent onChangeScene() call.
  class SceneChangeRecordingEntity extends BGE.GameEntity
    lastNewSceneName as string = ""

    sub new(game as BGE.Game, args = {} as roAssociativeArray)
      super(game, args)
    end sub

    override sub onChangeScene(newScene as BGE.Scene)
      m.lastNewSceneName = newScene.name
    end sub
  end class

  class SceneChangeRecordingScene extends BGE.Scene
    lastNewSceneName as string = ""

    sub new(game as BGE.Game, args = {} as roAssociativeArray)
      super(game, args)
    end sub

    override sub onChangeScene(newScene as BGE.Scene)
      super.onChangeScene(newScene)
      m.lastNewSceneName = newScene.name
    end sub
  end class
```

Add to `src/source/engine/ui/UiContainer.spec.bs`, inside `class UiContainerTests` (before its `end class`):

```brighterscript
    @describe("onChangeScene")

    @it("forwards onChangeScene to every child widget")
    function _()
      child = new SceneChangeRecordingWidget(m.game)
      m.container.addChild(child)
      newScene = new BGE.Scene(m.game, {name: "NextScene"})

      m.container.onChangeScene(newScene)

      m.assertEqual("NextScene", child.lastNewSceneName)
    end function
```

and this helper class after the existing helper classes at the bottom of that file (before the final `end namespace`):

```brighterscript
  class SceneChangeRecordingWidget extends BGE.UI.UiWidget
    lastNewSceneName as string = ""

    sub new(game as BGE.Game)
      super(game)
    end sub

    override sub onChangeScene(newScene as BGE.Scene)
      m.lastNewSceneName = newScene.name
    end sub
  end class
```

If the suite class in `UiContainer.spec.bs` isn't named `UiContainerTests`, add the block inside whatever class carries `@suite("BGE.UI.UiContainer")`.

- [ ] **Step 2: Run validation to verify it fails**

Run: `npm run validate`
Expected: FAIL with `cannot-find-name`/`cannot-find-function` errors for `BGE.Scene`, `defineScene`, `changeScene`, `getSceneNames`, `onChangeScene` in `Scene.spec.bs`, `Game.spec.bs` and `UiContainer.spec.bs`.

- [ ] **Step 3: Run the codemod over the engine**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
python3 /private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py room src/
```

Expected output: `rewrote N files` (about 25) and `moved 1 files` (`Room.bs` → `Scene.bs`; the spec was already moved in Step 1).

Then confirm the must-not-change item survived:

```bash
grep -n "headroom" src/source/engine/renderer/cameras/Camera3d.bs
```

Expected: the `headroom` comment line is still there, unchanged.

- [ ] **Step 4: Rewrite the doc comments by hand**

The codemod leaves grammatical but stale wording. Replace these exactly.

`src/source/engine/Scene.bs`: replace the whole file with:

```brighterscript
import "Game.bs"
import "GameEntity.bs"

namespace BGE

  ' A Scene is a GameEntity that represents one distinct state of your game - a title
  ' screen, a menu, a level. Register scenes with `Game.defineScene()` and switch between
  ' them with `Game.changeScene()`. Only one Scene is current at a time, and it gets the
  ' same per-frame hooks (`onUpdate`, `onInput`, ...) as any other entity.
  '
  ' Changing to a different scene destroys every non-`persistent` entity. The outgoing
  ' scene's own drawables (anything added with `addDrawable()`/`addImage()`/etc. directly
  ' on the scene) are removed too, by this class's default `onChangeScene()`. Nothing is
  ' removed when "changing" to the same scene (e.g. `Game.resetScene()`), since `onCreate()`
  ' runs again immediately and typically re-adds everything.
  '
  ' To keep some or all of a scene's own drawables across a change:
  '  - set `persistDrawablesAcrossSceneChange = true` to keep all of them, or
  '  - override `onChangeScene()` with your own cleanup. An override replaces the default
  '    cleanup unless it calls `super.onChangeScene(newScene)`.
  class Scene extends GameEntity

    ' Whether this scene's own directly-added drawables survive a change to a different
    ' scene, instead of being removed by the default `onChangeScene()`.
    persistDrawablesAcrossSceneChange as boolean = false

    function new(gameEngine as Game, args = {} as roAssociativeArray)
      super(gameEngine, args)
    end function

    ' Removes every drawable this scene added directly to itself when the game changes to
    ' a different scene, unless `persistDrawablesAcrossSceneChange` is true. An override
    ' only keeps this behavior if it calls `super.onChangeScene(newScene)`.
    '
    ' @param {Scene} newScene - The scene being changed to
    override sub onChangeScene(newScene as Scene)
      ' Scenes aren't in Game.sortedEntities, so Game's own non-persistent cleanup never reaches their drawables.
      if m.persistDrawablesAcrossSceneChange or newScene.name = m.name
        return
      end if
      for each drawableName in m.drawablesByName.Keys()
        m.removeDrawable(drawableName)
      end for
    end sub
  end class
end namespace
```

`src/source/engine/GameEntity.bs`: the `onChangeScene` doc comment (formerly "This method is only called when the entity is marked as `persistant`...", which was wrong - `handleSceneChange()` calls it on every entity) becomes:

```brighterscript
    ' Called on every entity when the game changes to a different scene, just before
    ' non-`persistent` entities are destroyed. Override it to save state or clean up.
    '
    ' @param {Scene} newScene - The scene being changed to
    sub onChangeScene(newScene as Scene)
    end sub
```

`src/source/engine/ui/UiContainer.bs`: its override's doc comment becomes:

```brighterscript
    ' Called when the game changes to a different scene. Forwards the call to every child.
    '
    ' @param {Scene} newScene - The scene being changed to
    override sub onChangeScene(newScene as BGE.Scene)
```

`src/source/engine/Game.bs`:
- Field comments near line 128: `' The scene currently in play`, `' The args passed to changeScene() for the current scene`, `' All of the GameEntities by name <entityName> => <entityId> => GameEntity`, `' The scene definitions by name (see defineScene())`.
- `getScene()` doc: `' Gets the scene the game is currently in` / `' @return {Scene}`.
- Section banner: `' --------------------------------Begin Scene Functions----------------------------------------`.
- Replace the `defineScene`/`isSceneChanging`/`changeScene`/`resetScene`/`getSceneNames` doc comments (dropping both stale `' TODO: work on rooms` lines) with:

```brighterscript
    ' Registers a scene so it can later be switched to by name with `changeScene()`.
    '
    ' @param {Scene} newScene - The scene to register; its `name` is the key `changeScene()` uses
    sub defineScene(newScene as Scene)
```

```brighterscript
    ' Whether a scene change was requested this frame and hasn't been applied yet.
    '
    ' @return {boolean}
    function isSceneChanging() as boolean
```

```brighterscript
    ' Changes to the scene registered under the given name, then calls its `onCreate(args)`.
    ' While the game is running, the change is applied at the end of the current frame.
    '
    ' @param {string} sceneName - The name of a scene registered with `defineScene()`
    ' @param {object} [args={}] - Passed to the scene's `onCreate()`
    ' @return {boolean} true if a scene with that name exists
    function changeScene(sceneName as string, args = {} as roAssociativeArray) as boolean
```

```brighterscript
    ' Restarts the current scene by changing to it again with the same args.
    '
    ' @return {void}
    sub resetScene()
```

```brighterscript
    ' The names of every scene registered with `defineScene()`.
    '
    ' @return {string[]}
    function getSceneNames() as string[]
```

- The error log in `changeScene` should read: `m.log("Game.changeScene() - A scene named " + sceneName + " hasn't been defined", BGE.Debug.LogLevel.error)`.

Then read `git diff src/` end to end and fix any other codemod prose that reads badly (e.g. "a Scene/Level" → "a scene").

- [ ] **Step 5: Run the checks to verify they pass**

Run: `npm run check`
Expected: lint clean, validate clean (both configs), Rooibos `[Rooibos Result]: PASS`, including the new tests.

Then confirm nothing named Room is left in the engine:

```bash
git grep -nIi "room" -- src/ | grep -v "headroom"
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add -A src/
git commit -m "Rename Room to Scene in the engine (#227)

BGE.Room -> BGE.Scene, Game.*Room* -> Game.*Scene*, GameEntity.onChangeRoom
-> onChangeScene. Clean break, no aliases. Also fixes onChangeScene's doc
comment, which claimed it only fired for persistent entities.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Renderer `drawScene`/`addToScene`/`removeFromScene` renames

**Files:**
- Modify (codemod, then hand review): `src/source/engine/renderer/Renderer.bs`, `src/source/engine/drawables/Drawable.bs`, the 12 drawables that override `addToScene` (`Image.bs`, `AnimatedImage.bs`, `DrawableRectangle.bs`, `DrawableSkybox.bs`, `DrawablePolygon.bs`, `DrawableLine.bs`, `DrawableCircle.bs`, `Model3d.bs`, `DrawablePlane.bs`, `DrawableParticles.bs`, `DrawableParallaxLayer.bs`, `DrawableText.bs`), `src/source/engine/GameEntity.bs`, `src/source/engine/Game.bs`, and every spec/comment that mentions them
- Test: `src/source/engine/GameEntity.spec.bs`

**Interfaces:**
- Consumes: Task 1's renamed engine (no direct dependency on its names).
- Produces (used by Tasks 4, 5, 6): `Renderer.render()`, `Drawable.addToRenderer(renderer as Renderer) as BGE.SceneObject`, `Drawable.removeFromRenderer(renderer as Renderer)`.

- [ ] **Step 1: Write the failing test**

Add to `src/source/engine/GameEntity.spec.bs`, inside the class carrying `@suite(...)` (before its `end class`):

```brighterscript
    @describe("removeDrawable - renderer cleanup")

    @it("removes the drawable's scene object from the game canvas renderer")
    function _()
      entity = new BGE.GameEntity(m.game, {name: "Holder"})
      m.game.addEntity(entity)
      renderer = m.game.canvas.renderer
      before = renderer.getSceneObjectCount()

      entity.addDrawable("rect", new BGE.DrawableRectangle(entity, 10, 10))
      m.assertEqual(before + 1, renderer.getSceneObjectCount())

      entity.removeDrawable("rect")
      m.assertEqual(before, renderer.getSceneObjectCount())
    end function

    @it("addToRenderer registers a scene object and removeFromRenderer unregisters it")
    function _()
      renderer = m.game.canvas.renderer
      before = renderer.getSceneObjectCount()
      rect = new BGE.DrawableRectangle(invalid, 10, 10)

      m.assertNotInvalid(rect.addToRenderer(renderer))
      m.assertEqual(before + 1, renderer.getSceneObjectCount())

      rect.removeFromRenderer(renderer)
      m.assertEqual(before, renderer.getSceneObjectCount())
    end function
```

`GameEntity.spec.bs`'s `beforeEach` already sets `m.game = new BGE.Game(320, 240)`. `DrawableRectangle` accepts an `invalid` owner (issue #231, see `OwnerlessDrawable.spec.bs`).

- [ ] **Step 2: Run validation to verify it fails**

Run: `npm run validate`
Expected: FAIL with `cannot-find-function` for `addToRenderer` and `removeFromRenderer` in `GameEntity.spec.bs`.

- [ ] **Step 3: Run the codemod**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
python3 /private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py renderer src/
```

Expected: `rewrote N files` (about 40, mostly specs).

- [ ] **Step 4: Rewrite the doc comments by hand**

`src/source/engine/drawables/Drawable.bs`:

```brighterscript
    ' Registers this Drawable with a Renderer, so it gets drawn each frame. The engine
    ' calls this for you when a drawable is added to an entity; call it yourself only for
    ' a standalone drawable. Subclasses override it to create their SceneObject.
    '
    ' @param {Renderer} renderer - The renderer to draw this Drawable with
    ' @return {BGE.SceneObject} The SceneObject that represents this Drawable in the renderer, or invalid if it has none
    function addToRenderer(renderer as Renderer) as BGE.SceneObject
      return invalid
    end function
```

and add a doc comment above `removeFromRenderer`:

```brighterscript
    ' Unregisters every SceneObject this Drawable added to the given Renderer, so it
    ' stops being drawn. The engine calls this for you when a drawable is removed from
    ' an entity or the entity is destroyed.
    '
    ' @param {Renderer} renderer - The renderer to remove this Drawable from
    sub removeFromRenderer(renderer as Renderer)
```

`src/source/engine/renderer/Renderer.bs`: add a doc comment above `sub render()` (it had none):

```brighterscript
    ' Draws one frame: updates every SceneObject, depth-sorts them, and draws them to
    ' this renderer's surface. `Game` calls this for you each frame; call it yourself
    ' only when using a Renderer without a Game.
    sub render()
```

Then read `git diff src/` and fix codemod prose in comments: e.g. "`Renderer.render()` pass" is fine; "the first render() call after registration" is fine; "not just via addToRenderer (issue #69)" is fine. Rephrase anything that now reads oddly, like "addToRenderer / render" describe titles.

- [ ] **Step 5: Run the checks to verify they pass**

Run: `npm run check`
Expected: lint clean, validate clean, `[Rooibos Result]: PASS`.

```bash
git grep -nIwE "drawScene|addToScene|removeFromScene|rendererScene|renderScene" -- src/
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add -A src/
git commit -m "Rename renderer scene methods to render/addToRenderer/removeFromRenderer (#227)

Frees the word \"scene\" for BGE.Scene. SceneObject and the
add/removeSceneObject methods keep their names.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Tooling, templates and ropm consumer fixture

**Files:**
- Move: `scripts/create-room.js` → `scripts/create-scene.js`
- Move: `scripts/templates/roomTemplate.bs` → `scripts/templates/sceneTemplate.bs`
- Move: `scripts/exampleTemplate/src/source/Rooms/MainRoom.bs` → `scripts/exampleTemplate/src/source/Scenes/MainScene.bs`
- Modify: `package.json` (`create-room` script), `scripts/scaffold-class.js`, `scripts/create-example.js`, `scripts/create-entity.js`, `scripts/templates/entityTemplate.bs`, `scripts/exampleTemplate/src/source/main.bs`, `scripts/exampleTemplate/src/source/util.bs`, `scripts/ropmConsumerFixture/src/source/main.bs`

**Interfaces:**
- Consumes: Task 1 (`BGE.Scene`, `defineScene`, `changeScene`, `getSceneNames`), Task 2 (none directly).
- Produces: `npm run create-scene -- <example> <SceneName>` writing `examples/<example>/src/source/Scenes/<SceneName>.bs`; the example template's `goToNextScene(currentScene as BGE.Scene, direction as integer)` helper in `util.bs`.

- [ ] **Step 1: Run the codemod over tooling**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
python3 /private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py room scripts/ package.json
python3 /private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py renderer scripts/
```

Expected: the three files above are moved; `package.json` now has `"create-scene": "node scripts/create-scene.js"`.

- [ ] **Step 2: Fix the scaffolding output by hand**

In `scripts/create-scene.js`, the header and next-steps output must read:

```js
#!/usr/bin/env node
// Scaffolds a new BGE.Scene subclass under examples/<example>/src/source/Scenes
// from scripts/templates/sceneTemplate.bs.
//
// Usage: node scripts/create-scene.js [example] [SceneName]
//   example   - directory name under examples/, e.g. "quickstart"
//               prompted for interactively if omitted
//   SceneName - the class name, e.g. "MainScene" -> Scenes/MainScene.bs
//               prompted for interactively if omitted
```

```js
      console.log('Next steps (typically in main.bs):');
      console.log(`  game.defineScene(new ${className}(game))`);
      console.log(`  game.changeScene("${className}")  # or via this example's getSceneNames(), if it has one`);
```

with `classKind: 'Scene'`, `subDir: path.join('Scenes')`, `templatePath: path.join(__dirname, 'templates', 'sceneTemplate.bs')`.

Check `scripts/create-entity.js`'s hint reads `# add it to a scene, e.g. in a Scene's onCreate(): ...`, `scripts/create-example.js`'s reads `# add entities under src/source/Entities, scenes under src/source/Scenes`, and `scripts/templates/entityTemplate.bs` lists `onChangeScene` among the hooks. Read `git diff scripts/ package.json` for any other stale wording.

- [ ] **Step 3: Verify scaffolded output compiles**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
npm run create-example -- zzscenecheck "Scene Check"
npm run create-scene -- zzscenecheck SecondScene
ls examples/zzscenecheck/src/source/Scenes/
cd examples/zzscenecheck && npm install && npx bsc --validate --create-package=false; cd ../..
```

Expected: `Scenes/` contains `MainScene.bs` and `SecondScene.bs`; `SecondScene.bs` starts with `class SecondScene extends BGE.Scene`; `bsc` reports 0 errors.

Then remove the throwaway example and its tasks.json registration:

```bash
rm -rf examples/zzscenecheck
git checkout -- .vscode/tasks.json
git status --short
```

Expected: `git status` shows only the intended Task 3 changes (no `zzscenecheck`, no `.vscode/tasks.json`).

- [ ] **Step 4: Verify the ropm consumer fixture**

Run: `npm run test:ropm-consumer`
Expected: passes (it builds the engine, packs it and validates `scripts/ropmConsumerFixture` against it, whose `main.bs` now uses `BGE.Scene`/`defineScene`/`changeScene`).

- [ ] **Step 5: Commit**

```bash
git add -A scripts/ package.json
git commit -m "Rename create-room tooling and templates to create-scene (#227)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Examples

**Files:**
- Move: all 53 `examples/*/src/source/Rooms/*.bs` → `examples/*/src/source/Scenes/*.bs` with renamed stems (see spec's examples table); `examples/hybrid/src/source/Rooms/MainRoom.bs` → `examples/hybrid/src/source/Scenes/GameScene.bs`; `examples/terrain`'s `*Placements.bs` move folders but keep their names
- Modify: every example `main.bs`/entity file that references a Room class, `getRoomNames`/`goToNextRoom`, `changeRoom`/`defineRoom`, `drawScene`, `addToScene`, `removeSceneObject`-adjacent comments; on-screen hint text
- Untouched: `examples/scenegraph/**`, and `resetScene`/`timeDrawScene` in `examples/rendererTest/src/source/Tests/StaticGeometryBspBenchmark.bs`

**Interfaces:**
- Consumes: Tasks 1 and 2's engine names.
- Produces: nothing new.

- [ ] **Step 1: Confirm the examples currently fail to validate**

Run: `npm run validate-examples 2>&1 | grep -cE "cannot-find-(name|function)"`
Expected: a large non-zero count (examples still use `BGE.Room`, `changeRoom`, `drawScene`, ...).

- [ ] **Step 2: Run the codemod over every example**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
python3 /private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py room examples/
python3 /private/tmp/claude-502/-Users-mpearce-redspace-roku-brighterscript-game-engine/2908dbff-be7c-4fee-8f60-621e94a4a72f/scratchpad/rename_room.py renderer examples/
```

Expected: `moved 53 files`.

- [ ] **Step 3: Restore the untouched files and check the special cases**

```bash
git checkout HEAD -- examples/scenegraph
git diff --stat HEAD -- examples/scenegraph
grep -n "resetScene\|timeDrawScene" examples/rendererTest/src/source/Tests/StaticGeometryBspBenchmark.bs
grep -rn "GameScene\|MainScene" examples/hybrid/src/source
ls examples/hybrid/src/source/Scenes examples/terrain/src/source/Scenes
git ls-files examples/terrain/src/sprites | grep -i mushroom
```

Expected:
- `git diff --stat` for `examples/scenegraph` is empty.
- `StaticGeometryBspBenchmark.bs` still has its private `resetScene`/`timeDrawScene` (the renderer codemod only matches the exact tokens `drawScene`/`addToScene`/..., so these are untouched; its `renderer.drawScene()` calls are now `renderer.render()`).
- hybrid's source uses `GameScene` for the BGE scene class and `"GameScene"` as its name string; `screen.CreateScene("MainScene")` / the SceneGraph `MainScene` component are unchanged.
- `examples/hybrid/src/source/Scenes/GameScene.bs` exists; terrain's `Scenes/` has `MainScene.bs`, `WorldScene.bs`, `GuardPlacements.bs`, `TreePlacements.bs`, `WallPlacements.bs`.
- `SuperMarioKartMapMushroomCup1.png` is still listed under its original name.

- [ ] **Step 4: Hand-review the example diff**

Read `git diff -M HEAD -- examples/` in full. Fix:
- prose that reads badly after the swap (comments, on-screen hint strings, e.g. "next room" → "next scene");
- any `m.name = "..."` string that doesn't match its class name after the rename (every `changeScene("X")` must name a class's `m.name`);
- stale local names the token rule couldn't reach.

- [ ] **Step 5: Validate every example**

Run: `npm run validate-examples`
Expected: the engine validates and every example reports 0 errors.

```bash
git grep -nIi "room" -- examples/ | grep -vi "mushroom"
git grep -nIwE "drawScene|addToScene|removeFromScene" -- examples/
```

Expected: no output from either.

- [ ] **Step 6: Commit**

```bash
git add -A examples/
git commit -m "Rename Room to Scene across all examples (#227)

Rooms/ -> Scenes/, *Room classes -> *Scene. hybrid's MainRoom becomes
GameScene, since that example already has a SceneGraph MainScene component.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Documentation

**Files:**
- Modify: `README.md`, `docs/game-engine-overview.md`, `docs/engine-internals.md`, `docs/drawables-and-scene-objects.md`, `docs/controller-input.md`, `docs/qr-codes.md`, `docs/scenegraph-shapes.md`, `docs/images/architecture-overview.svg`, `docs/images/game-loop.svg`, `docs/images/collider-vs-camera.svg` (if it mentions a renamed name), `CLAUDE.md`, `.claude/skills/rokubot-examples/SKILL.md`
- Do NOT modify: `specs/**` (other than this plan/spec), `docs/superpowers/plans/**`

**Interfaces:**
- Consumes: every name from Tasks 1-4 (engine API, `npm run create-scene`, example scene class names).
- Produces: nothing code-facing.

This task is prose, rewritten by hand, not with the codemod.

- [ ] **Step 1: List every stale reference**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git grep -nIiE "room|drawScene|addToScene|removeFromScene|create-room" -- README.md docs/ CLAUDE.md .claude/ ':!docs/superpowers' | grep -vi "mushroom\|headroom"
```

Expected: a list of roughly 100 lines across the files above. This is the task's to-do list; the step 5 check is this same command returning nothing.

- [ ] **Step 2: Rewrite the guides and README**

For each hit, rewrite the sentence so it reads naturally with the new names (not a word swap). Code samples must use the real new API: `class MainScene extends BGE.Scene`, `game.defineScene(new MainScene(game))`, `game.changeScene("MainScene")`, `onChangeScene(newScene)`, `renderer.render()`, `drawable.addToRenderer(renderer)`. README command lists use `npm run create-scene -- <example> <SceneName>` and `Scenes/`.

In `docs/game-engine-overview.md`, replace the `Room` row of the core-concepts table with a `Scene` row, and add this note directly below that table:

```markdown
> **Three different "scenes."** `BGE.Scene` is the current state of your game (a title screen, a menu, a level) and is what this guide means by "scene." The renderer's `SceneObject`s are the individual things it draws each frame, one or more per `Drawable`. Roku's SceneGraph `Scene` node is unrelated to both; it only matters if you mix the engine into a SceneGraph app (see [SceneGraph Shapes](/scenegraph-shapes)).
```

- [ ] **Step 3: Update the SVG diagrams**

Edit the `<text>` labels in place (no layout changes):
- `docs/images/architecture-overview.svg`: `every frame, for the current Room then each entity in sortedEntities` → `every frame, for the current Scene then each entity in sortedEntities`; the `Room` box label → `Scene`.
- `docs/images/game-loop.svg`: `apply pending room change` → `apply pending scene change`; `...trigger a room change mid-frame.` → `...trigger a scene change mid-frame.`; `Entity order: current Room first/last, ...` → `Entity order: current Scene first/last, ...`.
- `docs/images/collider-vs-camera.svg`: update any `drawScene`/`Room` label the same way (skip if step 1 listed none for it).

Check each label still fits its box: `Scene` is the same length as `Room` + 1 character, and each changed sentence grows by at most 1 character per replaced word.

- [ ] **Step 4: Update CLAUDE.md and the rokubot skill**

`CLAUDE.md`:
- Commands list: replace the `npm run create-room` bullet with `npm run create-scene -- <example> <SceneName>` — scaffolds `examples/<example>/src/source/Scenes/<SceneName>.bs` from `scripts/templates/sceneTemplate.bs` (a `BGE.Scene` subclass with `onCreate`/`onInput` stubs); still needs a manual `game.defineScene(...)`/`game.changeScene(...)` wired up in `main.bs` (and an entry in that example's `getSceneNames()`, if it has one). Also update `create-entity`'s description and `create-example`'s "minimal `MainRoom`".
- Architecture: rename the "Entities, Rooms, Drawables" heading to "Entities, Scenes, Drawables" and its `engine/Room.bs` path; update the game-loop steps (current scene, `changeScene()`, `sceneChangedThisFrame`/`handleSceneChange`), `Renderer.drawScene()` → `Renderer.render()` everywhere (depth sort, BSP, skybox bullets), `addToScene(renderer)` → `addToRenderer(renderer)`, and example class names (`TieBreakScene`, `ClusterVisualizerScene`, `RectanglesScene`, `CirclesScene`, `WorldScene`, `MainScene`).
- `rendererTest` section: "deliberately built without `BGE.Game`/`Scene`".

`.claude/skills/rokubot-examples/SKILL.md`: rewrite the multi-room navigation advice as multi-scene (`grep -n "changeScene" examples/<name>/src/source/Scenes/*.bs`), and the per-example rows' class names (`ImagesScene`, `TextScene`, `PolygonScene`, `GhostScene`, `MainScene.onCreate`, `getSceneNames()`/`goToNextScene()`, ...).

- [ ] **Step 5: Verify docs are clean and build**

```bash
git grep -nIiE "room|drawScene|addToScene|removeFromScene|create-room" -- README.md docs/ CLAUDE.md .claude/ ':!docs/superpowers' | grep -vi "mushroom\|headroom"
npm run docs
grep -rl "BGE.Room\|Room.html" docs-site | head
ls docs-site | grep -i "scene\.html\|BGE.Scene"
```

Expected: the first grep prints nothing; `npm run docs` exits 0; the second grep prints nothing; the `ls` shows a `BGE.Scene` class page.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/ CLAUDE.md .claude/skills/rokubot-examples/SKILL.md
git commit -m "Update docs, CLAUDE.md and rokubot skill for Room -> Scene (#227)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: CHANGELOG

**Files:**
- Modify: `CHANGELOG.md` (the `[Unreleased]` section)

**Interfaces:**
- Consumes: the public naming map (Tasks 1-3).
- Produces: nothing code-facing.

- [ ] **Step 1: Add the breaking-change entry**

Insert directly under `## [Unreleased]` (above the existing `### Added`):

```markdown
### Changed (breaking)

`Room` is now `Scene` ([#227](https://github.com/markwpearce/brighterscript-game-engine/issues/227)). "Room" never described what it is - the current state of your game, whether that's a title screen, a menu, or a level. The renderer's own "scene" methods were renamed at the same time so the word only means one thing. This is a clean break with no deprecated aliases; the next release is 0.7.0.

| Old | New |
|---|---|
| `BGE.Room` | `BGE.Scene` |
| `Room.persistDrawablesAcrossRoomChange` | `Scene.persistDrawablesAcrossSceneChange` |
| `GameEntity.onChangeRoom(newRoom)` | `GameEntity.onChangeScene(newScene)` |
| `Game.defineRoom()` / `changeRoom()` / `resetRoom()` | `Game.defineScene()` / `changeScene()` / `resetScene()` |
| `Game.getRoom()` / `getRoomNames()` / `isRoomChanging()` | `Game.getScene()` / `getSceneNames()` / `isSceneChanging()` |
| `Game.currentRoom` / `currentRoomArgs` / `Rooms` | `Game.currentScene` / `currentSceneArgs` / `Scenes` |
| `Renderer.drawScene()` | `Renderer.render()` |
| `Drawable.addToScene(renderer)` / `removeFromScene(renderer)` | `Drawable.addToRenderer(renderer)` / `removeFromRenderer(renderer)` |
| `npm run create-room` | `npm run create-scene` (writes to `Scenes/`) |

Most leftover uses of the old names fail to compile. The exception: an `override sub onChangeRoom(...)`, `override function addToScene(...)` or `override sub removeFromScene(...)` in your own classes **still compiles but is never called**. Search your project for those three names and rename them.

`SceneObject` and `Renderer.addSceneObject()`/`removeSceneObject()`/`getSceneObjects()` are unchanged.
```

Also update the existing `examples/platformer` bullet under `### Added` only if it says "room" (it currently doesn't).

- [ ] **Step 2: Verify the only old names in the changelog are in the new table and the historical releases**

```bash
grep -nE "Room|drawScene|addToScene|removeFromScene|create-room" CHANGELOG.md
```

Expected: hits only inside the new "Changed (breaking)" section (table + override warning) and in older release sections (e.g. `0.5.0`'s "minimal `MainRoom`", `0.6.0`'s "room-navigation graph"), which are historical and stay as they are.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "Changelog: Room -> Scene breaking change (#227)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Full verification, on-device smoke run, PR

**Files:**
- None expected. Fix-ups go in whichever file a check points at, amended into a new commit.

**Interfaces:**
- Consumes: everything.
- Produces: the PR.

- [ ] **Step 1: Full quality gate**

Run: `npm run check:all`
Expected: lint clean, validate clean, `[Rooibos Result]: PASS`, every example validates.

Run: `npm run test:ropm-consumer`
Expected: passes.

- [ ] **Step 2: Repo-wide leftover grep**

```bash
cd /Users/mpearce/redspace/roku/brighterscript-game-engine
git grep -nIiE "room|drawScene|addToScene|removeFromScene" -- . ':!specs/' ':!docs/superpowers/' ':!CHANGELOG.md' | grep -vi "mushroom\|headroom"
```

Expected: no output. (`CHANGELOG.md` was checked in Task 6.)

- [ ] **Step 3: Build the examples for sideloading**

Run: `npm run build-examples`
Expected: `examples/<name>/out/bge-<name>.zip` exists for `3d`, `pixels`, `asteroids`, `platformer`, `depthsort`, `hybrid`, `rendererTest`.

- [ ] **Step 4: On-device smoke run**

Invoke the `rokubot-examples` skill and follow its workflow (rokubot reads `.env` itself; never reference `$ROKU_HOST`/`$ROKU_PASSWORD` in commands). For each example below, sideload, launch, screenshot, press the key that changes scene, screenshot again, and confirm the new scene drew (and that the log shows no `Game.changeScene() - A scene named ... hasn't been defined` error):

| Example | Scene change to trigger |
|---|---|
| `3d` | `fwd` from `ImagesScene` → `TextScene`, then `rev` back |
| `pixels` | `fwd` from `PolygonScene` → `RectangleScene` |
| `asteroids` | `select` at `TitleScene` → `MainScene` |
| `platformer` | `select` at `TitleScene` → `MainScene` |
| `depthsort` | whatever key its scene hint says switches `TieBreakScene` ↔ `ClusterVisualizerScene` |
| `hybrid` | launch only - `GameScene` draws inside the SceneGraph `MainScene` |
| `rendererTest` | `rokubot launch dev --param demo=triangles` - the demo draws (exercises `Renderer.render()`) |

Don't play the real-time games; only confirm scenes load and switch. If a screenshot comes back black, check FPS before suspecting a rendering bug.

- [ ] **Step 5: File the follow-up issue**

```bash
gh issue create --label documentation --title "Move docs/superpowers/plans out of the published docs tree" --body "docs/superpowers/plans/ holds three implementation plans (raycasting, static-geometry BSP, oriented sprite billboards). jsdoc.json's opts.docs is ./docs with recurse: true, so every markdown file under docs/ is swept into the public GitHub Pages site. CLAUDE.md says plans belong in specs/. Move them there (git mv, keep history) and check the generated site no longer lists them.

Found while working on #227."
```

- [ ] **Step 6: Push and open the PR**

Invoke the `pr-voice` skill to write the PR description, then:

```bash
git push -u origin refactor/issue-227-room-to-scene:refactor/issue-227-room-to-scene
gh pr create --base main --head refactor/issue-227-room-to-scene --title "Rename Room to Scene (#227)" --body-file <file written via pr-voice>
```

The PR body must mention: closes #227; the clean-break decision; hybrid's `GameScene` exception; which examples were smoke-tested on device; and end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
