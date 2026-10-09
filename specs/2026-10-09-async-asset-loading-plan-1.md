# Async Asset Loading, PR 1: Loading Stage + Local Tasks - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a loading stage to every scene change, plus a general time-budgeted task loader (`BGE.AssetLoader`) with built-in local asset loads, step-by-step model parsing, and an overridable loading screen.

**Architecture:** `BGE.LoadTask` is the unit of work (`step(budgetMs)` / `getProgress()`); `BGE.AssetLoader` runs tasks round-robin within a per-frame millisecond budget. `Game.handleSceneChange()` is split into teardown -> `onLoad(loader, args)` -> (frames of loading) -> `onCreate(args)`; a scene that queues nothing gets `onCreate` in the same call, exactly as today. A `BGE.LoadingScreen` is drawn on the UI canvas above the fade overlay while loading.

**Tech Stack:** BrighterScript (`bsc`), Rooibos v6 (`rooibos-roku`) headless via `brs-cli`, `rokubot` for on-device runs.

**Spec:** `specs/2026-10-09-async-asset-loading-design.md` (this plan covers its "Delivery" item 1; downloads/caching are plan 2, roTextureManager is plan 3).

## Global Constraints

- All engine code is in the `BGE` namespace under `src/source/`; new loading code goes in `src/source/engine/loading/`.
- Every file that uses another file's class/interface/enum/function must `import` that file (SceneGraph scopes aren't ambient).
- A `*.spec.bs` file contains exactly **one** `@suite` class (Rooibos v6 corrupts metadata otherwise). Helper classes without `@suite` may sit below it.
- A test class in `namespace tests` that subclasses a `BGE` class needs an explicit constructor calling `super(...)` with fully-qualified types (bsc transpile crash otherwise).
- `assertEqual` is type-strict (`1` vs `1.0` fail); compare scalars, never whole objects with back-references.
- Never compare two objects with `=` (runtime Type Mismatch); compare an `id`/`name` field.
- Never write `foo(new X(...))` - assign `new X(...)` to a local first, then pass it.
- No single-line `if` (`bslint` `inline-if-style: never`).
- An instance method parameter or field typed as **its own class** corrupts bsc symbol resolution - use `as object`/`roArray` there (this is the only allowed use of `as object`).
- Doc comments (`'` above public members, `@param`/`@return`) are for game developers; inline comments are terse "why" only.
- `GameInput`-style discrete actions are guarded by `input.press`.
- Example UI stays >= 10% in from every canvas edge (title safe).
- `npm run check` (lint + validate + headless tests) must pass at the end of every task; `npm run check:all` at the end of the plan.
- Zero behaviour change for a scene that doesn't override `onLoad`: `onCreate` runs in the same `handleSceneChange()` call as today.

## Review Focus

- A custom task or step function that throws: the loader marks it failed, logs it, and the scene still opens (test in Task 1).
- A task whose `getProgress()` goes backwards or above 1: the overall bar never moves backwards or past 1 (test in Task 1).
- `changeScene()` called from inside `onLoad` (with tasks queued), whether or not the game loop is running: the loading scene still gets its `onCreate` once, then the requested scene runs; no recursion into a half-started load (test in Task 5).
- Entities a scene adds during `onLoad`: they don't get `onUpdate`/`onInput`/collisions before the scene's `onCreate` (test in Task 5).
- `resetScene()` on a scene with an `onLoad`: the loading stage runs again with the same args; persistent entities survive (test in Task 5).

---

### Task 1: `LoadTask`, `StepTask` and `AssetLoader`

**Files:**
- Create: `src/source/engine/loading/LoadTask.bs`
- Create: `src/source/engine/loading/StepTask.bs`
- Create: `src/source/engine/loading/AssetLoader.bs`
- Test: `src/source/engine/loading/AssetLoader.spec.bs`

**Interfaces:**
- Consumes: `BGE.GameTimer` (`src/source/engine/GameTimer.bs`: `mark()`, `totalMilliseconds() as integer`, `addTime(ms)`), `BGE.Game.log(message, level)`.
- Produces:
  - `class BGE.LoadTask` - fields `name as string`, `weight as float = 1.0`, `error as dynamic = invalid`, `done as boolean = false`, `dependsOn as roArray`, `waitingForNextFrame as boolean = false`, `progressHighWater as float = 0.0`; methods `step(budgetMs as integer) as boolean`, `getProgress() as float`, `after(other as object) as object` (adds a dependency, returns `m`).
  - `class BGE.StepTask extends BGE.LoadTask` - `new(stepFunction as function, context as dynamic)`.
  - `class BGE.AssetLoader` - `new(game as BGE.Game)`, `timer as BGE.GameTimer`, `onComplete as function or dynamic`, `addTask(task as BGE.LoadTask) as BGE.LoadTask`, `addStep(stepFunction as function, context = invalid as dynamic, weight = 1.0 as float) as BGE.LoadTask`, `update(budgetMs as integer)`, `hasTasks() as boolean`, `isDone() as boolean`, `getProgress() as float`, `getErrors() as string[]`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/loading/AssetLoader.spec.bs`:

```brighterscript
import "pkg:/source/engine/loading/AssetLoader.bs"

namespace tests

  @suite("BGE.AssetLoader")
  class AssetLoaderTests extends rooibos.BaseTestSuite

    game as BGE.Game
    loader as BGE.AssetLoader

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.loader = new BGE.AssetLoader(m.game)
    end function

    @describe("progress and completion")

    @it("is done with progress 1 when it has no tasks")
    function _()
      m.assertFalse(m.loader.hasTasks())
      m.assertTrue(m.loader.isDone())
      m.assertEqual(1.0, m.loader.getProgress())
    end function

    @it("runs many fast tasks in one update")
    function _()
      for i = 1 to 20
        task = new FakeLoadTask(1, 0)
        m.loader.addTask(task)
      end for
      m.loader.update(1000)
      m.assertTrue(m.loader.isDone())
      m.assertEqual(1.0, m.loader.getProgress())
    end function

    @it("stops stepping once the budget is used")
    function _()
      slow = new FakeLoadTask(10, 5)
      slow.loaderTimer = m.loader.timer
      m.loader.addTask(slow)
      m.loader.update(12)
      ' each step costs 5ms of the 12ms budget: steps at 0ms, 5ms and 10ms
      m.assertEqual(3, slow.stepCount)
      m.assertFalse(m.loader.isDone())
    end function

    @it("weights progress by task weight")
    function _()
      light = new FakeLoadTask(1, 0)
      heavy = new FakeLoadTask(100, 0)
      heavy.weight = 3.0
      heavy.waitingForNextFrameAfterStep = true
      m.loader.addTask(light)
      m.loader.addTask(heavy)
      m.loader.update(1000)
      ' light done (1 * 1) + heavy at 1/100 (3 * 0.01) over total weight 4
      m.assertTrue(Abs(m.loader.getProgress() - (1.03 / 4.0)) < 0.0001)
    end function

    @it("never reports a task's progress going backwards or past 1")
    function _()
      task = new FakeLoadTask(5, 0)
      task.waitingForNextFrameAfterStep = true
      m.loader.addTask(task)
      task.fakeProgress = 0.6
      m.loader.update(1000)
      m.assertTrue(Abs(m.loader.getProgress() - 0.6) < 0.0001)
      task.fakeProgress = 0.2
      m.loader.update(1000)
      m.assertTrue(Abs(m.loader.getProgress() - 0.6) < 0.0001)
      task.fakeProgress = 7.0
      m.loader.update(1000)
      m.assertTrue(m.loader.getProgress() <= 1.0)
    end function

    @it("calls onComplete exactly once")
    function _()
      task = new FakeLoadTask(1, 0)
      m.loader.addTask(task)
      ' a dynamic alias, since completeCount isn't a declared AssetLoader field
      loaderAA = m.loader as dynamic
      loaderAA.completeCount = 0
      m.loader.onComplete = sub(loader as object)
        loader.completeCount = loader.completeCount + 1
      end sub
      m.loader.update(1000)
      m.loader.update(1000)
      m.assertEqual(1, loaderAA.completeCount)
    end function

    @it("starts a fresh batch when a task is added after the queue drained")
    function _()
      first = new FakeLoadTask(1, 0)
      first.failWith = "first failed"
      m.loader.addTask(first)
      m.loader.update(1000)
      m.assertEqual(1, m.loader.getErrors().count())
      second = new FakeLoadTask(2, 0)
      second.waitingForNextFrameAfterStep = true
      m.loader.addTask(second)
      m.assertEqual(0, m.loader.getErrors().count())
      m.assertTrue(m.loader.getProgress() < 1.0)
    end function

    @describe("dependencies")

    @it("does not start a task until its dependencies are done")
    function _()
      first = new FakeLoadTask(3, 0)
      first.waitingForNextFrameAfterStep = true
      second = new FakeLoadTask(1, 0)
      second.after(first)
      m.loader.addTask(first)
      m.loader.addTask(second)
      m.loader.update(1000)
      m.assertEqual(0, second.stepCount)
      m.loader.update(1000)
      m.loader.update(1000)
      m.loader.update(1000)
      m.assertEqual(1, second.stepCount)
      m.assertTrue(m.loader.isDone())
    end function

    @it("fails a task whose dependency failed, without running it")
    function _()
      first = new FakeLoadTask(1, 0)
      first.failWith = "boom"
      second = new FakeLoadTask(1, 0)
      second.after(first)
      m.loader.addTask(first)
      m.loader.addTask(second)
      m.loader.update(1000)
      m.assertTrue(m.loader.isDone())
      m.assertEqual(0, second.stepCount)
      m.assertEqual(2, m.loader.getErrors().count())
    end function

    @describe("failures")

    @it("treats a task that throws as failed and done")
    function _()
      task = new FakeLoadTask(1, 0)
      task.throwOnStep = true
      m.loader.addTask(task)
      m.loader.update(1000)
      m.assertTrue(m.loader.isDone())
      m.assertEqual(1, m.loader.getErrors().count())
      m.assertNotInvalid(task.error)
    end function

    @describe("addStep")

    @it("calls a step function with its context until it returns true")
    function _()
      context = {calls: 0}
      m.loader.addStep(function(ctx as object) as dynamic
        ctx.calls = ctx.calls + 1
        return ctx.calls >= 3
      end function, context)
      m.loader.update(1000)
      m.assertEqual(3, context.calls)
      m.assertTrue(m.loader.isDone())
    end function

    @it("uses a numeric return as progress, done at 1")
    function _()
      context = {calls: 0}
      m.loader.addStep(function(ctx as object) as dynamic
        ctx.calls = ctx.calls + 1
        return ctx.calls / 4.0
      end function, context)
      m.loader.update(1000)
      m.assertEqual(4, context.calls)
      m.assertTrue(m.loader.isDone())
    end function

    @it("fails a step function that throws")
    function _()
      m.loader.addStep(function(ctx as object) as dynamic
        return ctx.missing.field
      end function, {})
      m.loader.update(1000)
      m.assertTrue(m.loader.isDone())
      m.assertEqual(1, m.loader.getErrors().count())
    end function

  end class

  ' Finishes after `stepsToFinish` steps, advancing the loader's clock by `msPerStep` per step.
  class FakeLoadTask extends BGE.LoadTask
    stepsToFinish as integer
    msPerStep as integer
    stepCount as integer = 0
    fakeProgress as dynamic = invalid
    failWith as dynamic = invalid
    throwOnStep as boolean = false
    waitingForNextFrameAfterStep as boolean = false
    loaderTimer as dynamic = invalid

    sub new(stepsToFinish as integer, msPerStep as integer)
      super()
      m.stepsToFinish = stepsToFinish
      m.msPerStep = msPerStep
    end sub

    override function step(budgetMs as integer) as boolean
      if m.throwOnStep
        throw "fake task threw"
      end if
      m.stepCount++
      if m.loaderTimer <> invalid
        m.loaderTimer.addTime(m.msPerStep)
      end if
      if m.failWith <> invalid
        m.error = m.failWith
        return true
      end if
      m.waitingForNextFrame = m.waitingForNextFrameAfterStep
      return m.stepCount >= m.stepsToFinish
    end function

    override function getProgress() as float
      if m.fakeProgress <> invalid
        return m.fakeProgress
      end if
      return m.stepCount / m.stepsToFinish
    end function
  end class

end namespace
```

Note: the `onComplete` test counts on the loader itself (through a `dynamic` alias) because a BrightScript anonymous sub can't close over test locals; the loader passes itself to `onComplete`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - `cannot-find-name` for `BGE.AssetLoader` / `BGE.LoadTask`.

- [ ] **Step 3: Implement `LoadTask`**

Create `src/source/engine/loading/LoadTask.bs`:

```brighterscript
namespace BGE

  ' One unit of work for a `BGE.AssetLoader`: loading an asset, parsing part of a model, building
  ' part of a level. The loader calls `step()` repeatedly (several times a frame if it's fast,
  ' once a frame if it's slow) until it returns true.
  '
  ' Extend this class for your own work, or use `AssetLoader.addStep()` for a plain function.
  class LoadTask

    ' Shown in log messages
    name as string = "task"
    ' This task's share of the loader's overall progress, relative to the other tasks
    weight as float = 1.0
    ' Set to a message string if the task failed. A failed task counts as done.
    error as dynamic = invalid
    ' Set by the loader once step() has returned true
    done as boolean = false
    ' Tasks that must finish before this one starts - see after()
    dependsOn as roArray
    ' Set true in step() when there's nothing more to do until next frame (e.g. waiting on a
    ' download), so the loader doesn't keep calling it this frame. Cleared every frame.
    waitingForNextFrame as boolean = false
    ' Highest progress reported so far, kept by the loader so the bar never goes backwards
    progressHighWater as float = 0.0

    sub new()
      m.dependsOn = []
    end sub

    ' Does some of this task's work.
    '
    ' @param {integer} budgetMs - roughly how many milliseconds this call may take
    ' @return {boolean} true once the task is finished (or has failed - set `error`)
    function step(budgetMs as integer) as boolean
      return true
    end function

    ' How far through its work this task is.
    '
    ' @return {float} 0 to 1
    function getProgress() as float
      return 0.0
    end function

    ' Makes this task wait until another task has finished. If the other task fails, this one
    ' fails too without running.
    '
    ' @param {BGE.LoadTask} other
    ' @return {BGE.LoadTask} this task, so calls can be chained
    function after(other as object) as object
      m.dependsOn.push(other)
      return m
    end function

  end class

end namespace
```

(`after()`/`dependsOn` use `object`/`roArray` because a method parameter typed as its own class corrupts bsc symbol resolution - see Global Constraints.)

- [ ] **Step 4: Implement `StepTask`**

Create `src/source/engine/loading/StepTask.bs`:

```brighterscript
import "LoadTask.bs"

namespace BGE

  ' A LoadTask that calls a plain function once per step - see `AssetLoader.addStep()`.
  class StepTask extends LoadTask

    private stepFunction as function
    private context as dynamic
    private progress as float = 0.0

    sub new(stepFunction as function, context as dynamic)
      super()
      m.name = "step"
      m.stepFunction = stepFunction
      m.context = context
    end sub

    override function step(budgetMs as integer) as boolean
      ' called through a local: a detached function value has no reliable `m`
      stepFn = m.stepFunction
      result = stepFn(m.context)
      resultType = LCase(type(result))
      if resultType = "boolean" or resultType = "roboolean"
        return result
      end if
      if resultType = "float" or resultType = "rofloat" or resultType = "double" or resultType = "rodouble" or resultType = "integer" or resultType = "roint" or resultType = "rointeger"
        m.progress = result
        return result >= 1.0
      end if
      return false
    end function

    override function getProgress() as float
      return m.progress
    end function

  end class

end namespace
```

- [ ] **Step 5: Implement `AssetLoader`**

Create `src/source/engine/loading/AssetLoader.bs`:

```brighterscript
import "../Game.bs"
import "../GameTimer.bs"
import "../../math/math.bs"
import "LoadTask.bs"
import "StepTask.bs"

namespace BGE

  ' Runs LoadTasks a little at a time, within a per-frame time budget, so long loads don't freeze
  ' the game. A scene gets one in `GameScene.onLoad()`; `game.assets` is one you can use at any
  ' time for background loading.
  '
  ' Once every queued task has finished, `onComplete(loader)` is called. Adding a task after
  ' that starts a new batch: progress and errors start again from scratch.
  class AssetLoader

    ' Called once when the queue drains: sub(loader as BGE.AssetLoader)
    onComplete as function or dynamic = invalid
    ' Measures each update()'s budget
    timer as BGE.GameTimer

    private game as BGE.Game
    private tasks as roArray
    private errors as string[]
    private completeFired as boolean = true

    sub new(game as BGE.Game)
      m.game = game
      m.timer = new BGE.GameTimer()
      m.tasks = []
      m.errors = []
    end sub

    ' Queues a task.
    '
    ' @param {BGE.LoadTask} task
    ' @return {BGE.LoadTask} the same task
    function addTask(task as BGE.LoadTask) as BGE.LoadTask
      if m.completeFired
        m.tasks = []
        m.errors = []
        m.completeFired = false
      end if
      m.tasks.push(task)
      return task
    end function

    ' Queues a function to be called once per step until it's done. It's passed `context` and
    ' returns true when done, or a number from 0 to 1 for its progress (done at 1). Anything else
    ' means "not done yet".
    '
    ' @param {function} stepFunction - function(context) as dynamic
    ' @param {dynamic} [context=invalid] - passed to every call
    ' @param {float} [weight=1.0] - its share of overall progress
    ' @return {BGE.LoadTask} the queued task
    function addStep(stepFunction as function, context = invalid as dynamic, weight = 1.0 as float) as BGE.LoadTask
      task = new BGE.StepTask(stepFunction, context)
      task.weight = weight
      return m.addTask(task)
    end function

    ' Whether any tasks are queued in the current batch.
    '
    ' @return {boolean}
    function hasTasks() as boolean
      return m.tasks.count() > 0
    end function

    ' Whether every queued task has finished (true when nothing is queued).
    '
    ' @return {boolean}
    function isDone() as boolean
      for each task in m.tasks
        if not task.done
          return false
        end if
      end for
      return true
    end function

    ' Overall progress of the current batch, weighted by each task's `weight`.
    '
    ' @return {float} 0 to 1 (1 when nothing is queued)
    function getProgress() as float
      totalWeight = 0.0
      weighted = 0.0
      for each task in m.tasks
        totalWeight += task.weight
        if task.done
          weighted += task.weight
        else
          weighted += task.weight * task.progressHighWater
        end if
      end for
      if totalWeight <= 0
        return 1.0
      end if
      return weighted / totalWeight
    end function

    ' Error messages from tasks in the current batch that failed.
    '
    ' @return {string[]}
    function getErrors() as string[]
      return m.errors
    end function

    ' Runs task steps until every task is done or `budgetMs` has been used. Called by Game.
    '
    ' @param {integer} budgetMs
    sub update(budgetMs as integer)
      if m.tasks.count() = 0
        return
      end if
      m.timer.mark()
      for each task in m.tasks
        task.waitingForNextFrame = false
      end for

      outOfTime = false
      ranAny = true
      while ranAny and not outOfTime
        ranAny = false
        for each task in m.tasks
          if not task.done and not task.waitingForNextFrame and m.dependenciesReady(task)
            remaining = budgetMs - m.timer.totalMilliseconds()
            if remaining <= 0 and ranAny
              outOfTime = true
              exit for
            end if
            m.runStep(task, remaining)
            ranAny = true
          end if
        end for
        if m.timer.totalMilliseconds() >= budgetMs
          outOfTime = true
        end if
      end while

      if not m.completeFired and m.isDone()
        m.completeFired = true
        if m.onComplete <> invalid
          onCompleteFn = m.onComplete
          onCompleteFn(m)
        end if
      end if
    end sub

    ' True when every dependency is done. A failed dependency fails this task.
    private function dependenciesReady(task as BGE.LoadTask) as boolean
      for each dependency in task.dependsOn
        if not dependency.done
          return false
        end if
        if dependency.error <> invalid
          m.finishTask(task, "dependency " + dependency.name + " failed")
          return false
        end if
      end for
      return true
    end function

    private sub runStep(task as BGE.LoadTask, budgetMs as integer)
      finished = false
      try
        finished = task.step(budgetMs)
      catch e
        task.error = task.name + " threw: " + e.message
        finished = true
      end try
      if finished
        m.finishTask(task, task.error)
      else
        progress = BGE.Math.Clamp(task.getProgress(), 0, 1)
        if progress > task.progressHighWater
          task.progressHighWater = progress
        end if
      end if
    end sub

    private sub finishTask(task as BGE.LoadTask, errorMessage as dynamic)
      task.done = true
      task.progressHighWater = 1.0
      if errorMessage <> invalid
        task.error = errorMessage
        m.errors.push(errorMessage)
        m.game.log("BGE.AssetLoader - " + errorMessage, BGE.Debug.LogLevel.error)
      end if
    end sub

  end class

end namespace
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm run check`
Expected: lint and validate clean; `[Rooibos Result]: PASS`, including the 13 new `BGE.AssetLoader` tests. If the `"uses a numeric return as progress"` test fails on the float/integer division type, read the failure diff and fix the comparison rather than the loader (see the `assertEqual` note in Global Constraints).

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/loading/
git commit -m "Add LoadTask, StepTask and AssetLoader (#301)"
```

---

### Task 2: Step-by-step model parsing

**Files:**
- Create: `src/source/utils/parsers/OBJParseTask.bs`
- Create: `src/source/utils/parsers/STLParseTask.bs`
- Modify: `src/source/utils/parsers/OBJParser.bs` (`parseOBJContent` becomes a wrapper)
- Modify: `src/source/utils/parsers/STLParser.bs` (`parseSTLAsciiFile`/`parseSTLBinaryFile` become wrappers)
- Test: `src/source/utils/parsers/OBJParseTask.spec.bs`, `src/source/utils/parsers/STLParseTask.spec.bs`

**Interfaces:**
- Consumes: `BGE.LoadTask` (Task 1); existing `BGE.Parsers.resolveOBJFaceVertices`, `resolveOBJFaceTexCoords`, `appendOBJFace`, `resolveOBJTexturePath` (OBJParser.bs); `BGE.Model3d`, `BGE.Model3dFaceOps.create`, `BGE.Math.VectorOps.create`, `BGE.Math.VectorFromFloatArray`, `BGE.stringToFloat`, `BGE.bytesToInteger`, `BGE.bytesToFloat`.
- Produces:
  - `class BGE.Parsers.OBJParseTask extends BGE.LoadTask` - `new(content as string, baseDir = "" as string)`, `model as BGE.Model3d` (set once done).
  - `class BGE.Parsers.STLAsciiParseTask extends BGE.LoadTask` - `new(content as string)`, `model`.
  - `class BGE.Parsers.STLBinaryParseTask extends BGE.LoadTask` - `new(fileBytes as roByteArray)`, `model`.
  - Each `step(budgetMs)` parses until `budgetMs` elapses (checked every 16 lines/triangles), and `getProgress()` is lines-or-triangles done / total.

- [ ] **Step 1: Write the failing tests**

Create `src/source/utils/parsers/OBJParseTask.spec.bs`:

```brighterscript
import "pkg:/source/utils/parsers/OBJParseTask.bs"

namespace tests

  @suite("BGE.Parsers.OBJParseTask")
  class OBJParseTaskTests extends rooibos.BaseTestSuite

    @it("produces the same model in many small steps as in one go")
    function _()
      content = m.makeGridObj(20)
      oneShot = BGE.Parsers.parseOBJContent(content)

      task = new BGE.Parsers.OBJParseTask(content)
      steps = 0
      while not task.step(0)
        steps++
      end while
      m.assertTrue(steps > 1)
      m.assertEqual(oneShot.faces.count(), task.model.faces.count())
      m.assertEqual(oneShot.name, task.model.name)
      lastIndex = oneShot.faces.count() - 1
      m.assertEqual(oneShot.faces[lastIndex].vertices[2].x, task.model.faces[lastIndex].vertices[2].x)
      m.assertEqual(oneShot.faces[lastIndex].vertices[2].y, task.model.faces[lastIndex].vertices[2].y)
    end function

    @it("reports progress that rises from 0 to 1 and never falls")
    function _()
      task = new BGE.Parsers.OBJParseTask(m.makeGridObj(20))
      m.assertEqual(0.0, task.getProgress())
      last = 0.0
      while not task.step(0)
        progress = task.getProgress()
        m.assertTrue(progress >= last)
        m.assertTrue(progress < 1.0)
        last = progress
      end while
      m.assertEqual(1.0, task.getProgress())
    end function

    @it("finishes immediately for empty content")
    function _()
      task = new BGE.Parsers.OBJParseTask("")
      m.assertTrue(task.step(0))
      m.assertEqual(0, task.model.faces.count())
    end function

    ' An n x n grid of quads: (n+1)^2 vertices and n^2 quad faces (2 triangles each).
    private function makeGridObj(n as integer) as string
      lines = ["o grid"]
      for y = 0 to n
        for x = 0 to n
          lines.push("v " + x.toStr() + " " + y.toStr() + " 0")
        end for
      end for
      for y = 0 to n - 1
        for x = 0 to n - 1
          a = y * (n + 1) + x + 1
          b = a + 1
          c = a + n + 2
          d = a + n + 1
          lines.push("f " + a.toStr() + " " + b.toStr() + " " + c.toStr() + " " + d.toStr())
        end for
      end for
      return lines.join(chr(10))
    end function

  end class

end namespace
```

Create `src/source/utils/parsers/STLParseTask.spec.bs`:

```brighterscript
import "pkg:/source/utils/parsers/STLParseTask.bs"

namespace tests

  @suite("BGE.Parsers.STLParseTask")
  class STLParseTaskTests extends rooibos.BaseTestSuite

    @it("ascii: produces the same model in many small steps as in one go")
    function _()
      content = m.makeAsciiStl(40)
      oneShot = BGE.Parsers.parseSTLAsciiFile(content)

      task = new BGE.Parsers.STLAsciiParseTask(content)
      steps = 0
      while not task.step(0)
        steps++
        m.assertTrue(task.getProgress() < 1.0)
      end while
      m.assertTrue(steps > 1)
      m.assertEqual(40, task.model.faces.count())
      m.assertEqual(oneShot.faces.count(), task.model.faces.count())
      m.assertEqual(oneShot.name, task.model.name)
      m.assertEqual(oneShot.faces[39].vertices[1].x, task.model.faces[39].vertices[1].x)
      m.assertEqual(1.0, task.getProgress())
    end function

    @it("binary: produces the same model in many small steps as in one go")
    function _()
      bytes = m.makeBinaryStl(40)
      oneShot = BGE.Parsers.parseSTLBinaryFile(bytes)

      task = new BGE.Parsers.STLBinaryParseTask(bytes)
      steps = 0
      while not task.step(0)
        steps++
      end while
      m.assertTrue(steps > 1)
      m.assertEqual(40, task.model.faces.count())
      m.assertEqual(oneShot.faces[39].vertices[2].z, task.model.faces[39].vertices[2].z)
      m.assertEqual(1.0, task.getProgress())
    end function

    @it("binary: an array too short for a header gives an empty model")
    function _()
      task = new BGE.Parsers.STLBinaryParseTask(CreateObject("roByteArray"))
      m.assertTrue(task.step(0))
      m.assertEqual(0, task.model.faces.count())
    end function

    private function makeAsciiStl(faceCount as integer) as string
      lines = ["solid test"]
      for i = 0 to faceCount - 1
        x = i.toStr()
        lines.push("facet normal 0 0 1")
        lines.push("outer loop")
        lines.push("vertex " + x + " 0 0")
        lines.push("vertex " + x + " 1 0")
        lines.push("vertex " + x + " 0 1")
        lines.push("endloop")
        lines.push("endfacet")
      end for
      lines.push("endsolid test")
      return lines.join(chr(10))
    end function

    ' 80-byte header, uint32 face count, then 50 bytes per face (normal + 3 vertices as
    ' little-endian float32, then a 2-byte attribute count). Every float is 0.0 except
    ' vertex 2's z, which is the face index (written as a float32).
    private function makeBinaryStl(faceCount as integer) as object
      bytes = CreateObject("roByteArray")
      for i = 1 to 80
        bytes.push(0)
      end for
      bytes.push(faceCount and &hFF)
      bytes.push((faceCount >> 8) and &hFF)
      bytes.push(0)
      bytes.push(0)
      for faceIndex = 0 to faceCount - 1
        for floatIndex = 0 to 11
          if floatIndex = 11
            m.pushFloat32(bytes, faceIndex)
          else
            m.pushFloat32(bytes, 0)
          end if
        end for
        bytes.push(0)
        bytes.push(0)
      end for
      return bytes
    end function

    ' Little-endian IEEE-754 float32 for a small non-negative integer value.
    private sub pushFloat32(bytes as object, value as integer)
      if value = 0
        bytes.push(0)
        bytes.push(0)
        bytes.push(0)
        bytes.push(0)
        return
      end if
      exponent = 0
      while (1 << (exponent + 1)) <= value
        exponent++
      end while
      mantissa = (value - (1 << exponent)) << (23 - exponent)
      bits = ((exponent + 127) << 23) or mantissa
      bytes.push(bits and &hFF)
      bytes.push((bits >> 8) and &hFF)
      bytes.push((bits >> 16) and &hFF)
      bytes.push((bits >> 24) and &hFF)
    end sub

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - `cannot-find-name` for `BGE.Parsers.OBJParseTask` / `STLAsciiParseTask` / `STLBinaryParseTask`.

- [ ] **Step 3: Implement `OBJParseTask` and make `parseOBJContent` wrap it**

Create `src/source/utils/parsers/OBJParseTask.bs`:

```brighterscript
import "../../engine/drawables/Model3d.bs"
import "../../engine/loading/LoadTask.bs"
import "../../math/vector.bs"
import "../../roku_modules/rodash/rodash.d.bs"
import "../strings.bs"
import "OBJParser.bs"

namespace BGE.Parsers

  ' Parses Wavefront .obj content a slice at a time - see `BGE.AssetLoader.load3dModel()`.
  ' `model` is set once `step()` returns true. Same results as `parseOBJContent()`, which runs
  ' one of these to completion.
  class OBJParseTask extends BGE.LoadTask

    ' The parsed model, once done
    model as BGE.Model3d = invalid

    private lines as roArray
    private lineIndex as integer = 0
    private baseDir as string
    private vertices as BGE.Math.Vector[]
    private texCoords as BGE.Math.Vector[]
    private faces as BGE.Model3dFace[]
    private modelName as string = "OBJModel"
    private hasName as boolean = false
    private mtllibName as string = ""
    private sliceTimer as roTimespan

    sub new(content as string, baseDir = "" as string)
      super()
      m.name = "parse .obj"
      m.lines = content.Split(chr(10))
      m.baseDir = baseDir
      m.vertices = []
      m.texCoords = []
      m.faces = []
      m.sliceTimer = CreateObject("roTimespan")
    end sub

    override function step(budgetMs as integer) as boolean
      m.sliceTimer.Mark()
      lineCount = m.lines.count()
      while m.lineIndex < lineCount
        m.parseLine(m.lines[m.lineIndex])
        m.lineIndex++
        if (m.lineIndex mod 16) = 0 and m.sliceTimer.TotalMilliseconds() >= budgetMs and m.lineIndex < lineCount
          return false
        end if
      end while
      m.model = new BGE.Model3d(m.faces)
      m.model.name = m.modelName
      if m.baseDir <> "" and m.mtllibName <> ""
        m.model.texturePath = BGE.Parsers.resolveOBJTexturePath(m.baseDir, m.mtllibName)
      end if
      return true
    end function

    override function getProgress() as float
      lineCount = m.lines.count()
      if lineCount = 0 or m.model <> invalid
        return 1.0
      end if
      return m.lineIndex / lineCount
    end function

    private sub parseLine(rawLine as string)
      tokens = rodash.compact(rawLine.Trim().Split(" "))
      if tokens.count() = 0
        return
      end if
      keyword = tokens[0]
      if keyword = "v" and tokens.count() >= 4
        m.vertices.push(BGE.Math.VectorOps.create(BGE.stringToFloat(tokens[1]), BGE.stringToFloat(tokens[2]), BGE.stringToFloat(tokens[3])))
      else if keyword = "vt" and tokens.count() >= 3
        m.texCoords.push(BGE.Math.VectorOps.create(BGE.stringToFloat(tokens[1]), BGE.stringToFloat(tokens[2]), 0))
      else if (keyword = "o" or keyword = "g") and tokens.count() >= 2 and not m.hasName
        m.modelName = tokens[1]
        m.hasName = true
      else if keyword = "mtllib" and tokens.count() >= 2 and m.mtllibName = ""
        m.mtllibName = tokens[1]
      else if keyword = "f" and tokens.count() >= 4
        BGE.Parsers.appendOBJFace(m.faces, BGE.Parsers.resolveOBJFaceVertices(tokens, m.vertices), BGE.Parsers.resolveOBJFaceTexCoords(tokens, m.texCoords))
      end if
    end sub

  end class

end namespace
```

In `src/source/utils/parsers/OBJParser.bs`, replace the body of `parseOBJContent` (everything from `lines = content.Split(chr(10))` through `return model`) with:

```brighterscript
    task = new BGE.Parsers.OBJParseTask(content, baseDir)
    while not task.step(&h7FFFFFFF)
    end while
    return task.model
```

and add `import "OBJParseTask.bs"` to the top of `OBJParser.bs`. Leave its doc comment unchanged. (`OBJParseTask.bs` imports `OBJParser.bs` for the helper functions; an import cycle between two files is fine in bsc.)

- [ ] **Step 4: Implement the STL parse tasks and make the wrappers use them**

Create `src/source/utils/parsers/STLParseTask.bs`:

```brighterscript
import "../../engine/drawables/Model3d.bs"
import "../../engine/loading/LoadTask.bs"
import "../../math/vector.bs"
import "../../roku_modules/rodash/rodash.d.bs"
import "../strings.bs"
import "../utils.bs"

namespace BGE.Parsers

  ' Parses ASCII .stl content a slice at a time. `model` is set once `step()` returns true
  ' (invalid if the content couldn't be parsed). Same results as `parseSTLAsciiFile()`.
  class STLAsciiParseTask extends BGE.LoadTask

    ' The parsed model, once done
    model as BGE.Model3d = invalid

    private lines as roArray
    private lineIndex as integer = 0
    private depth as integer = 0
    private solidName as string = ""
    private vertexes as BGE.Math.Vector[]
    private normal as BGE.Math.Vector = invalid
    private faces as BGE.Model3dFace[]
    private stopped as boolean = false
    private sliceTimer as roTimespan
    private solidRegex as roRegex
    private facetRegex as roRegex
    private outerLoopRegex as roRegex
    private vertexRegex as roRegex
    private endLoopRegex as roRegex
    private endFacetRegex as roRegex
    private endSolidRegex as roRegex

    sub new(content as string)
      super()
      m.name = "parse .stl"
      m.lines = content.Split(chr(10))
      m.vertexes = []
      m.faces = []
      m.sliceTimer = CreateObject("roTimespan")
      m.solidRegex = CreateObject("roRegex", "solid\s+(.*)", "")
      m.facetRegex = CreateObject("roRegex", "facet normal\s+(.*)", "")
      m.outerLoopRegex = CreateObject("roRegex", "outer loop", "")
      m.vertexRegex = CreateObject("roRegex", "vertex\s+(.*)", "")
      m.endLoopRegex = CreateObject("roRegex", "endloop", "")
      m.endFacetRegex = CreateObject("roRegex", "endfacet", "")
      m.endSolidRegex = CreateObject("roRegex", "endsolid", "")
    end sub

    override function step(budgetMs as integer) as boolean
      m.sliceTimer.Mark()
      lineCount = m.lines.count()
      try
        while m.lineIndex < lineCount and not m.stopped
          m.parseLine(m.lines[m.lineIndex])
          m.lineIndex++
          if (m.lineIndex mod 16) = 0 and m.sliceTimer.TotalMilliseconds() >= budgetMs and m.lineIndex < lineCount and not m.stopped
            return false
          end if
        end while
      catch e
        m.error = "could not parse .stl: " + e.message
        return true
      end try
      m.model = new BGE.Model3d(m.faces)
      m.model.name = m.solidName
      return true
    end function

    override function getProgress() as float
      lineCount = m.lines.count()
      if lineCount = 0 or m.model <> invalid
        return 1.0
      end if
      return m.lineIndex / lineCount
    end function

    private sub parseLine(line as string)
      if m.depth = 0
        if m.solidRegex.isMatch(line)
          m.solidName = m.solidRegex.match(line)[1]
          m.depth++
        else
          print `Unable to read line ${m.lineIndex}, depth ${m.depth}: ${line}`
          m.stopped = true
        end if
      else if m.depth = 1
        if m.facetRegex.isMatch(line)
          normalStr = m.facetRegex.match(line)[1] as string
          m.normal = BGE.Math.VectorFromFloatArray(rodash.map(normalStr.Split(" "), BGE.stringToFloat))
          m.depth++
        else if m.endSolidRegex.isMatch(line)
          m.stopped = true
        else
          print `Unable to read line ${m.lineIndex}, depth ${m.depth}: ${line}`
        end if
      else if m.depth = 2
        if m.outerLoopRegex.isMatch(line)
          m.vertexes = []
          m.depth++
        else if m.endFacetRegex.IsMatch(line)
          m.faces.push(BGE.Model3dFaceOps.create(m.vertexes, m.normal))
          m.depth--
        else
          print `Unable to read line ${m.lineIndex}, depth ${m.depth}: ${line}`
        end if
      else if m.depth = 3
        if m.vertexRegex.isMatch(line) and m.vertexes.Count() < 3
          vertexStr = m.vertexRegex.match(line)[1] as string
          vertex = BGE.Math.VectorFromFloatArray(rodash.map(vertexStr.Split(" "), BGE.stringToFloat))
          if not rodash.isInvalid(vertex)
            m.vertexes.Push(vertex)
          end if
        else if m.endLoopRegex.IsMatch(line)
          m.depth--
        else
          print `Unable to read line ${m.lineIndex}, depth ${m.depth}: ${line}`
        end if
      end if
    end sub

  end class

  ' Parses binary .stl bytes a slice of triangles at a time. Same results as
  ' `parseSTLBinaryFile()`.
  class STLBinaryParseTask extends BGE.LoadTask

    ' The parsed model, once done
    model as BGE.Model3d = invalid

    private fileBytes as roByteArray
    private faceCount as integer = 0
    private faceIndex as integer = 0
    private byteIndex as integer = 84
    private faces as BGE.Model3dFace[]
    private sliceTimer as roTimespan

    sub new(fileBytes as roByteArray)
      super()
      m.name = "parse .stl"
      m.fileBytes = fileBytes
      m.faces = []
      m.sliceTimer = CreateObject("roTimespan")
      ' 80-byte title + 4-byte triangle count + 50 bytes per triangle
      if fileBytes.Count() > 120
        m.faceCount = BGE.bytesToInteger(fileBytes, 80)
      end if
    end sub

    override function step(budgetMs as integer) as boolean
      m.sliceTimer.Mark()
      while m.faceIndex < m.faceCount
        m.parseFace()
        m.faceIndex++
        if (m.faceIndex mod 16) = 0 and m.sliceTimer.TotalMilliseconds() >= budgetMs and m.faceIndex < m.faceCount
          return false
        end if
      end while
      m.model = new BGE.Model3d(m.faces)
      m.model.name = "BinarySTL"
      return true
    end function

    override function getProgress() as float
      if m.faceCount = 0 or m.model <> invalid
        return 1.0
      end if
      return m.faceIndex / m.faceCount
    end function

    private sub parseFace()
      try
        normal = m.readVector()
        v0 = m.readVector()
        v1 = m.readVector()
        v2 = m.readVector()
        m.byteIndex += 2 ' attribute byte count
        m.faces.Push(BGE.Model3dFaceOps.create([v0, v1, v2], normal))
      catch error
        print `Unable to process face ${m.faceIndex}: ${rodash.toString(error)}`
      end try
    end sub

    private function readVector() as BGE.Math.Vector
      x = BGE.bytesToFloat(m.fileBytes, m.byteIndex)
      y = BGE.bytesToFloat(m.fileBytes, m.byteIndex + 4)
      z = BGE.bytesToFloat(m.fileBytes, m.byteIndex + 8)
      m.byteIndex += 12
      return BGE.Math.VectorOps.create(x, y, z)
    end function

  end class

end namespace
```

In `src/source/utils/parsers/STLParser.bs`: add `import "STLParseTask.bs"` at the top; replace the whole body of `parseSTLAsciiFile` with:

```brighterscript
    task = new BGE.Parsers.STLAsciiParseTask(content)
    while not task.step(&h7FFFFFFF)
    end while
    return task.model
```

and the whole body of `parseSTLBinaryFile` with:

```brighterscript
    task = new BGE.Parsers.STLBinaryParseTask(fileBytes)
    while not task.step(&h7FFFFFFF)
    end while
    return task.model
```

A face whose read throws (only possible past the end of a truncated file) is still logged and skipped, as before.

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS - the new suites plus every existing `OBJParser`/`STLParser` test unchanged (they now run through the tasks, which is the regression check that one parser replaced two).

- [ ] **Step 6: Commit**

```bash
git add src/source/utils/parsers/
git commit -m "Parse .obj/.stl a slice at a time with parse tasks (#301)"
```

---

### Task 3: Built-in loads on `AssetLoader`

**Files:**
- Create: `src/source/engine/loading/AssetLoadTasks.bs`
- Modify: `src/source/engine/loading/AssetLoader.bs` (add `loadBitmap`/`loadSound`/`load3dModel`/`registerFont`)
- Modify: `src/source/engine/Game.bs:2356-2380` (`load3dModel` uses a new `addLoadedModel`)
- Test: `src/source/engine/loading/AssetLoadTasks.spec.bs`

**Interfaces:**
- Consumes: `BGE.AssetLoader.addTask` (Task 1); `OBJParseTask`/`STLAsciiParseTask`/`STLBinaryParseTask` (Task 2); `Game.loadBitmap(name, path) as boolean`, `Game.loadSound(name, path)`, `Game.registerFont(path) as boolean`, `Game.get3dModel(name)`.
- Produces:
  - `Game.addLoadedModel(modelName as string, model as BGE.Model3d, options = {} as BGE.Model3dLoadOptions, loadTexture = true as boolean) as boolean` - stores a parsed model and (if `loadTexture`) resolves/loads its texture, exactly as `load3dModel` did after parsing.
  - `AssetLoader.loadBitmap(name as string, path as string) as BGE.LoadTask`
  - `AssetLoader.loadSound(name as string, path as string) as BGE.LoadTask`
  - `AssetLoader.load3dModel(name as string, path as string, options = {} as BGE.Model3dLoadOptions) as BGE.LoadTask`
  - `AssetLoader.registerFont(path as string) as BGE.LoadTask`
  - classes `BGE.BitmapLoadTask`, `BGE.SoundLoadTask`, `BGE.FontLoadTask`, `BGE.ModelLoadTask` (all `extends BGE.LoadTask`).

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/loading/AssetLoadTasks.spec.bs`:

```brighterscript
import "pkg:/source/engine/loading/AssetLoader.bs"

namespace tests

  @suite("BGE.AssetLoader built-in loads")
  class AssetLoadTasksTests extends rooibos.BaseTestSuite

    game as BGE.Game
    loader as BGE.AssetLoader

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.loader = new BGE.AssetLoader(m.game)
    end function

    @it("loads a bitmap into the game's bitmaps")
    function _()
      bitmap = CreateObject("roBitmap", {width: 4, height: 2, AlphaEnable: true})
      bitmap.GetPng(0, 0, 4, 2).WriteFile("tmp:/bge_loader_test.png")
      m.loader.loadBitmap("loaded", "tmp:/bge_loader_test.png")
      m.runUntilDone()
      m.assertEqual(0, m.loader.getErrors().count())
      m.assertEqual(4, m.game.getBitmap("loaded").GetWidth())
    end function

    @it("fails a bitmap load for a missing file")
    function _()
      task = m.loader.loadBitmap("missing", "tmp:/no_such_file.png")
      m.runUntilDone()
      m.assertEqual(1, m.loader.getErrors().count())
      m.assertNotInvalid(task.error)
    end function

    @it("fails a sound load for a missing file")
    function _()
      m.loader.loadSound("missing", "tmp:/no_such_file.wav")
      m.runUntilDone()
      m.assertEqual(1, m.loader.getErrors().count())
    end function

    @it("fails a font registration for a missing file")
    function _()
      m.loader.registerFont("tmp:/no_such_font.ttf")
      m.runUntilDone()
      m.assertEqual(1, m.loader.getErrors().count())
    end function

    @it("loads an .obj model over several updates")
    function _()
      lines = ["o tri"]
      for i = 0 to 299
        lines.push("v " + i.toStr() + " 0 0")
        lines.push("v " + i.toStr() + " 1 0")
        lines.push("v " + i.toStr() + " 0 1")
        base = i * 3
        lines.push("f " + (base + 1).toStr() + " " + (base + 2).toStr() + " " + (base + 3).toStr())
      end for
      WriteAsciiFile("tmp:/bge_loader_test.obj", lines.join(chr(10)))

      m.loader.load3dModel("tris", "tmp:/bge_loader_test.obj")
      m.loader.update(0)
      m.assertFalse(m.loader.isDone())
      m.runUntilDone()
      m.assertEqual(0, m.loader.getErrors().count())
      m.assertEqual(300, m.game.get3dModel("tris").faces.count())
      m.assertEqual("tri", m.game.get3dModel("tris").name)
    end function

    @it("loads an ascii .stl model")
    function _()
      stl = "solid cube" + chr(10) + "facet normal 0 0 1" + chr(10) + "outer loop" + chr(10)
      stl += "vertex 0 0 0" + chr(10) + "vertex 1 0 0" + chr(10) + "vertex 0 1 0" + chr(10)
      stl += "endloop" + chr(10) + "endfacet" + chr(10) + "endsolid cube"
      WriteAsciiFile("tmp:/bge_loader_test.stl", stl)
      m.loader.load3dModel("cube", "tmp:/bge_loader_test.stl")
      m.runUntilDone()
      m.assertEqual(1, m.game.get3dModel("cube").faces.count())
    end function

    @it("fails a model load for an unsupported extension")
    function _()
      WriteAsciiFile("tmp:/bge_loader_test.fbx", "nope")
      m.loader.load3dModel("nope", "tmp:/bge_loader_test.fbx")
      m.runUntilDone()
      m.assertEqual(1, m.loader.getErrors().count())
    end function

    @it("fails a model load for a missing file")
    function _()
      m.loader.load3dModel("nope", "tmp:/no_such_model.obj")
      m.runUntilDone()
      m.assertEqual(1, m.loader.getErrors().count())
    end function

    private sub runUntilDone()
      for i = 1 to 1000
        if m.loader.isDone()
          return
        end if
        m.loader.update(0)
      end for
    end sub

  end class

end namespace
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - `AssetLoader` has no member `loadBitmap`/`loadSound`/`load3dModel`/`registerFont`.

- [ ] **Step 3: Add `Game.addLoadedModel` and use it in `load3dModel`**

In `src/source/engine/Game.bs`, replace `load3dModel` (currently lines 2356-2380) with:

```brighterscript
    function load3dModel(modelName as string, modelPath as string, options = {} as BGE.Model3dLoadOptions) as boolean
      if m.filesystem.Exists(modelPath)
        path_object = CreateObject("roPath", modelPath)
        parts = path_object.Split()
        extensionLower = lcase(parts.extension)
        if extensionLower = ".stl"
          return m.addLoadedModel(modelName, BGE.Parsers.parseSTLFile(modelPath), options, false)
        else if extensionLower = ".obj"
          model = BGE.Parsers.parseOBJFile(modelPath)
          if model = invalid
            m.log("Game.load3dModel() - Model " + modelPath + " could not be parsed", BGE.Debug.LogLevel.error)
            return false
          end if
          return m.addLoadedModel(modelName, model, options, true)
        else
          m.log("Game.load3dModel() - Model " + modelPath + " not loaded, file must be of type .stl or .obj", BGE.Debug.LogLevel.error)
          return false
        end if
      else
        m.log("Game.load3dModel() - Model not created, invalid path provided", BGE.Debug.LogLevel.error)
        return false
      end if
    end function

    ' Adds an already-parsed 3d model under a name, as if it had been loaded with
    ' `load3dModel()`, loading its texture (.obj models) the same way.
    '
    ' @param {string} modelName - the name this model will be referenced by later
    ' @param {BGE.Model3d} model - the parsed model
    ' @param {BGE.Model3dLoadOptions} [options={}] - optional load options (texturePath)
    ' @param {boolean} [loadTexture=true] - false for formats without textures (.stl)
    ' @return {boolean} true if the model was added
    function addLoadedModel(modelName as string, model as BGE.Model3d, options = {} as BGE.Model3dLoadOptions, loadTexture = true as boolean) as boolean
      if model = invalid
        return false
      end if
      m.models[modelName] = model
      if loadTexture
        m.loadModelTexture(model, options)
      end if
      return true
    end function
```

(STL keeps today's behaviour: stored, no texture step. The old STL branch stored `parseSTLFile`'s result even when it was `invalid` and returned true; it now returns false for an unparseable STL, which is the documented meaning of the return value.)

- [ ] **Step 4: Implement the built-in tasks**

Create `src/source/engine/loading/AssetLoadTasks.bs`:

```brighterscript
import "../Game.bs"
import "../drawables/Model3d.bs"
import "../../utils/parsers/OBJParseTask.bs"
import "../../utils/parsers/STLParseTask.bs"
import "LoadTask.bs"

namespace BGE

  ' Loads one bitmap with Game.loadBitmap(). One native decode, so a single step.
  class BitmapLoadTask extends LoadTask

    private game as BGE.Game
    private bitmapName as string
    private path as string

    sub new(game as BGE.Game, bitmapName as string, path as string)
      super()
      m.name = "bitmap " + path
      m.game = game
      m.bitmapName = bitmapName
      m.path = path
    end sub

    override function step(budgetMs as integer) as boolean
      if not m.game.loadBitmap(m.bitmapName, m.path)
        m.error = "could not load bitmap " + m.path
      end if
      return true
    end function

  end class

  ' Loads one sound with Game.loadSound().
  class SoundLoadTask extends LoadTask

    private game as BGE.Game
    private soundName as string
    private path as string

    sub new(game as BGE.Game, soundName as string, path as string)
      super()
      m.name = "sound " + path
      m.game = game
      m.soundName = soundName
      m.path = path
    end sub

    override function step(budgetMs as integer) as boolean
      if not CreateObject("roFileSystem").Exists(m.path)
        m.error = "sound file not found: " + m.path
        return true
      end if
      m.game.loadSound(m.soundName, m.path)
      return true
    end function

  end class

  ' Registers one font file with Game.registerFont().
  class FontLoadTask extends LoadTask

    private game as BGE.Game
    private path as string

    sub new(game as BGE.Game, path as string)
      super()
      m.name = "font " + path
      m.game = game
      m.path = path
    end sub

    override function step(budgetMs as integer) as boolean
      if not m.game.registerFont(m.path)
        m.error = "could not register font " + m.path
      end if
      return true
    end function

  end class

  ' Loads a .obj or .stl model a slice at a time: reads the file, parses it over as many steps
  ' as it needs, then adds it to the game (loading an .obj's texture).
  class ModelLoadTask extends LoadTask

    private game as BGE.Game
    private modelName as string
    private path as string
    private options as BGE.Model3dLoadOptions
    private parseTask as dynamic = invalid
    private isObj as boolean = false

    sub new(game as BGE.Game, modelName as string, path as string, options as BGE.Model3dLoadOptions)
      super()
      m.name = "model " + path
      m.game = game
      m.modelName = modelName
      m.path = path
      m.options = options
    end sub

    override function step(budgetMs as integer) as boolean
      if m.parseTask = invalid
        return m.startParse()
      end if
      if not m.parseTask.step(budgetMs)
        return false
      end if
      if m.parseTask.error <> invalid
        m.error = m.parseTask.error + " (" + m.path + ")"
        return true
      end if
      if not m.game.addLoadedModel(m.modelName, m.parseTask.model, m.options, m.isObj)
        m.error = "could not parse model " + m.path
      end if
      return true
    end function

    override function getProgress() as float
      if m.parseTask = invalid
        return 0.0
      end if
      return m.parseTask.getProgress() * 0.95
    end function

    ' Reads the file and creates the parse task. Returns true only if that failed.
    private function startParse() as boolean
      if not CreateObject("roFileSystem").Exists(m.path)
        m.error = "model file not found: " + m.path
        return true
      end if
      parts = CreateObject("roPath", m.path).Split()
      extensionLower = LCase(parts.extension)
      if extensionLower = ".obj"
        m.isObj = true
        content = ReadAsciiFile(m.path)
        objTask = new BGE.Parsers.OBJParseTask(content, parts.parent)
        m.parseTask = objTask
      else if extensionLower = ".stl"
        content = ReadAsciiFile(m.path)
        if LCase(content.Left(5)) = "solid"
          asciiTask = new BGE.Parsers.STLAsciiParseTask(content)
          m.parseTask = asciiTask
        else
          bytes = CreateObject("roByteArray")
          if not bytes.ReadFile(m.path)
            m.error = "could not read model " + m.path
            return true
          end if
          binaryTask = new BGE.Parsers.STLBinaryParseTask(bytes)
          m.parseTask = binaryTask
        end if
      else
        m.error = "model " + m.path + " must be .stl or .obj"
        return true
      end if
      return false
    end function

  end class

end namespace
```

- [ ] **Step 5: Add the helpers to `AssetLoader`**

In `src/source/engine/loading/AssetLoader.bs`, add `import "AssetLoadTasks.bs"` after the other imports and add these methods after `addStep`:

```brighterscript
    ' Queues loading a bitmap from a local path, as `game.loadBitmap()` would.
    '
    ' @param {string} bitmapName - the name to get it by later (`game.getBitmap()`)
    ' @param {string} path - local file path
    ' @return {BGE.LoadTask} the queued task
    function loadBitmap(bitmapName as string, path as string) as BGE.LoadTask
      task = new BGE.BitmapLoadTask(m.game, bitmapName, path)
      return m.addTask(task)
    end function

    ' Queues loading a sound from a local path, as `game.loadSound()` would.
    '
    ' @param {string} soundName - the name to play it by later (`game.playSound()`)
    ' @param {string} path - local file path
    ' @return {BGE.LoadTask} the queued task
    function loadSound(soundName as string, path as string) as BGE.LoadTask
      task = new BGE.SoundLoadTask(m.game, soundName, path)
      return m.addTask(task)
    end function

    ' Queues loading a .obj or .stl model, parsed a slice at a time so a big model doesn't
    ' freeze the screen. Set the returned task's `weight` higher than other tasks' for a big
    ' model, so the progress bar reflects how long it takes.
    '
    ' @param {string} modelName - the name to get it by later (`game.get3dModel()`)
    ' @param {string} path - local file path
    ' @param {BGE.Model3dLoadOptions} [options={}] - same options as `game.load3dModel()`
    ' @return {BGE.LoadTask} the queued task
    function load3dModel(modelName as string, path as string, options = {} as BGE.Model3dLoadOptions) as BGE.LoadTask
      task = new BGE.ModelLoadTask(m.game, modelName, path, options)
      return m.addTask(task)
    end function

    ' Queues registering a font file, as `game.registerFont()` would.
    '
    ' @param {string} path - local .ttf/.otf path
    ' @return {BGE.LoadTask} the queued task
    function registerFont(path as string) as BGE.LoadTask
      task = new BGE.FontLoadTask(m.game, path)
      return m.addTask(task)
    end function
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS (new suite plus existing `Game` model tests).

- [ ] **Step 7: Commit**

```bash
git add src/source/engine/loading/ src/source/engine/Game.bs
git commit -m "Add built-in bitmap/sound/font/model loads to AssetLoader (#301)"
```

---

### Task 4: `LoadingScreen` and the default

**Files:**
- Create: `src/source/engine/loading/LoadingScreen.bs`
- Test: `src/source/engine/loading/LoadingScreen.spec.bs`

**Interfaces:**
- Consumes: `BGE.Renderer` (`getCanvasSize() as BGE.Math.Vector`, `drawRectangle(x, y, w, h, rgba) as boolean`, `drawText(text, x, y, color, font, horizAlign, vertAlign) as boolean`), `BGE.Colors` (packed RGBA).
- Produces:
  - `class BGE.LoadingScreen` - `showAfterSeconds as float = 0.25`, `onShow()`, `onHide()`, `draw(renderer as BGE.Renderer, progress as float, dt as float)`.
  - `class BGE.DefaultLoadingScreen extends BGE.LoadingScreen` - `new(font = invalid as roFont)`, `backgroundColor`, `barColor`, `barBackgroundColor` (packed RGBA), `label as string = "Loading"`, `font as roFont`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/loading/LoadingScreen.spec.bs`:

```brighterscript
import "pkg:/source/engine/loading/LoadingScreen.bs"

namespace tests

  @suite("BGE.LoadingScreen")
  class LoadingScreenTests extends rooibos.BaseTestSuite

    @it("the base screen waits 0.25s before showing")
    function _()
      screen = new BGE.LoadingScreen()
      m.assertEqual(0.25, screen.showAfterSeconds)
    end function

    @it("the default screen draws at progress 0, 0.5 and 1 without error")
    function _()
      bitmap = CreateObject("roBitmap", {width: 320, height: 180, AlphaEnable: true})
      renderer = new BGE.Renderer(bitmap)
      renderer.resetDrawCallCounter()
      screen = new BGE.DefaultLoadingScreen()
      screen.draw(renderer, 0.0, 0.016)
      screen.draw(renderer, 0.5, 0.016)
      screen.draw(renderer, 1.0, 0.016)
      ' background + bar background each time, plus the fill at 0.5 and 1 (no label without a font)
      m.assertEqual(8, renderer.getDrawCallsLastFrame())
    end function

    @it("the default screen keeps its bar inside the title-safe area")
    function _()
      screen = new BGE.DefaultLoadingScreen()
      rect = screen.getBarRect(1280, 720)
      m.assertTrue(rect.x >= 128)
      m.assertTrue(rect.x + rect.width <= 1152)
      m.assertTrue(rect.y >= 72)
      m.assertTrue(rect.y + rect.height <= 648)
    end function

  end class

end namespace
```

Pixel reads aren't reliable headless, so the draw test counts draw calls (`Renderer.getDrawCallsLastFrame()` counts every `drawRectangle` since `resetDrawCallCounter()`). A zero-width bar at progress 0 is the case most likely to misbehave, so it's skipped rather than drawn.

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - `cannot-find-name` for `BGE.LoadingScreen`.

- [ ] **Step 3: Implement**

Create `src/source/engine/loading/LoadingScreen.bs`:

```brighterscript
import "../renderer/Renderer.bs"
import "../../utils/colors.bs"

namespace BGE

  ' Drawn over the game while a scene is loading (see `GameScene.onLoad()`). Extend it and
  ' override `draw()` for your own loading screen, then return it from
  ' `GameScene.getLoadingScreen()` or set it as `game.loadingScreen`.
  '
  ' It's drawn on the UI canvas, above the game UI and the fade overlay, below the debug UI.
  class LoadingScreen

    ' Loads that finish sooner than this never show the screen, so fast loads don't flash
    showAfterSeconds as float = 0.25

    ' Called when the screen first appears.
    sub onShow()
    end sub

    ' Called when loading finishes, just before the new scene's `onCreate()`.
    sub onHide()
    end sub

    ' Draws one frame of the loading screen.
    '
    ' @param {BGE.Renderer} renderer - the UI canvas renderer
    ' @param {float} progress - overall load progress, 0 to 1
    ' @param {float} dt - seconds since the last frame, for animation
    sub draw(renderer as BGE.Renderer, progress as float, dt as float)
    end sub

  end class

  ' The engine's default loading screen: black, with a progress bar and a label.
  class DefaultLoadingScreen extends LoadingScreen

    ' Packed RGBA
    backgroundColor as integer = BGE.Colors.Black
    ' Packed RGBA
    barColor as integer = BGE.Colors.White
    ' Packed RGBA
    barBackgroundColor as integer = BGE.Colors.Gray
    ' Text above the bar ("" for none)
    label as string = "Loading"
    ' Font for the label (no label is drawn without one)
    font as roFont = invalid

    sub new(font = invalid as roFont)
      super()
      m.font = font
    end sub

    override sub draw(renderer as BGE.Renderer, progress as float, dt as float)
      size = renderer.getCanvasSize()
      renderer.drawRectangle(0, 0, size.x, size.y, m.backgroundColor)
      bar = m.getBarRect(size.x, size.y)
      renderer.drawRectangle(bar.x, bar.y, bar.width, bar.height, m.barBackgroundColor)
      filled = bar.width * BGE.Math.Clamp(progress, 0, 1)
      if filled >= 1
        renderer.drawRectangle(bar.x, bar.y, filled, bar.height, m.barColor)
      end if
      if m.font <> invalid and m.label <> ""
        renderer.drawText(m.label, Int(size.x / 2), Int(bar.y - 12), m.barColor, m.font, "center", "bottom")
      end if
    end sub

    ' Where the progress bar goes on a canvas of the given size.
    '
    ' @param {float} canvasWidth
    ' @param {float} canvasHeight
    ' @return {object} {x, y, width, height}
    function getBarRect(canvasWidth as float, canvasHeight as float) as object
      width = canvasWidth * 0.4
      height = canvasHeight * 0.02
      if height < 6
        height = 6
      end if
      return {x: (canvasWidth - width) / 2, y: canvasHeight * 0.55, width: width, height: height}
    end function

  end class

end namespace
```

Add `import "../../math/math.bs"` for `BGE.Math.Clamp`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/source/engine/loading/LoadingScreen.bs src/source/engine/loading/LoadingScreen.spec.bs
git commit -m "Add LoadingScreen and DefaultLoadingScreen (#301)"
```

---

### Task 5: The loading stage in scene changes, and `game.assets`

**Files:**
- Modify: `src/source/engine/GameScene.bs` (add `onLoad`, `getLoadingScreen`)
- Modify: `src/source/engine/Game.bs` (fields, `handleSceneChange` split, loading per frame, skip rules, `drawUI`, `isTransitioning`, new public API, test helpers, `assets`)
- Test: `src/source/engine/GameSceneLoading.spec.bs`

**Interfaces:**
- Consumes: `BGE.AssetLoader` (Tasks 1/3), `BGE.LoadingScreen`/`BGE.DefaultLoadingScreen` (Task 4).
- Produces (public on `Game`): `assets as BGE.AssetLoader`, `loadingScreen as BGE.LoadingScreen = invalid`, `loadingBudgetMs as integer = 12`, `assetsBudgetMs as integer = 4`, `isLoading() as boolean`, `getLoadingProgress() as float`, `getSceneLoader() as BGE.AssetLoader`, `isLoadingScreenShown() as boolean`, test helpers `runSceneTransitionFrameForTest(dt as float)` and `processEntitiesPreDrawForTest()`.
- Produces (on `GameScene`): `sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)`, `function getLoadingScreen() as BGE.LoadingScreen`.

- [ ] **Step 1: Write the failing tests**

Create `src/source/engine/GameSceneLoading.spec.bs`:

```brighterscript
import "pkg:/source/engine/Game.bs"
import "pkg:/source/engine/loading/AssetLoader.bs"

namespace tests

  @suite("BGE.Game scene loading stage")
  class GameSceneLoadingTests extends rooibos.BaseTestSuite

    game as BGE.Game

    protected override function beforeEach()
      m.game = new BGE.Game(320, 240)
      m.game.defineScene(new BGE.GameScene(m.game, {name: "Plain"}))
      loading = new LoadingTestScene(m.game, "Loading", 3)
      m.game.defineScene(loading)
    end function

    @describe("a scene without onLoad work")

    @it("gets onCreate in the same call, with no loading stage")
    function _()
      m.game.changeScene("Plain")
      m.assertEqual("Plain", m.game.currentScene.name)
      m.assertFalse(m.game.isLoading())
      m.assertEqual(1.0, m.game.getLoadingProgress())
    end function

    @describe("a scene with onLoad work")

    @it("runs onLoad, loads over frames, then calls onCreate once")
    function _()
      m.game.changeScene("Loading")
      scene = m.game.currentScene
      m.assertEqual(1, scene.loadCalls)
      m.assertEqual(0, scene.createCalls)
      m.assertTrue(m.game.isLoading())
      m.assertTrue(m.game.isTransitioning())

      m.game.runSceneTransitionFrameForTest(0.016)
      m.assertTrue(m.game.getLoadingProgress() > 0)
      m.assertEqual(0, scene.createCalls)

      m.runFrames(5)
      m.assertFalse(m.game.isLoading())
      m.assertEqual(1, scene.createCalls)
      m.assertEqual("ok", scene.createdWithArg)
    end function

    @it("destroys the old scene's entities before onLoad runs")
    function _()
      m.game.changeScene("Plain")
      entity = new BGE.GameEntity(m.game, {name: "Old"})
      m.game.addEntity(entity)
      m.game.changeScene("Loading")
      m.assertEqual(0, m.game.currentScene.oldEntitiesSeenInLoad)
    end function

    @it("doesn't run the loading scene or entities added in onLoad until onCreate")
    function _()
      m.game.changeScene("Loading")
      scene = m.game.currentScene
      m.game.processEntitiesPreDrawForTest()
      m.assertEqual(0, scene.updateCalls)
      m.assertEqual(0, scene.addedEntity.updateCalls)
      m.runFrames(6)
      m.game.processEntitiesPreDrawForTest()
      m.assertEqual(1, scene.updateCalls)
      m.assertEqual(1, scene.addedEntity.updateCalls)
    end function

    @it("keeps updating persistent entities while loading")
    function _()
      keeper = new CountingEntity(m.game, "Keeper")
      keeper.persistent = true
      m.game.addEntity(keeper)
      m.game.changeScene("Loading")
      m.game.processEntitiesPreDrawForTest()
      m.assertEqual(1, keeper.updateCalls)
    end function

    @it("records errors on the scene loader for onCreate to check")
    function _()
      scene = m.game.Scenes["Loading"]
      scene.failOneTask = true
      m.game.changeScene("Loading")
      m.runFrames(6)
      m.assertEqual(1, m.game.getSceneLoader().getErrors().count())
      m.assertEqual(1, scene.createCalls)
    end function

    @it("runs the loading stage again on resetScene")
    function _()
      m.game.changeScene("Loading")
      m.runFrames(6)
      m.game.resetScene()
      m.runFrames(6)
      scene = m.game.currentScene
      m.assertEqual(2, scene.loadCalls)
      m.assertEqual(2, scene.createCalls)
    end function

    @describe("scene changes requested while loading")

    @it("defers a changeScene made during loading until loading ends")
    function _()
      m.game.changeScene("Loading")
      loadingScene = m.game.currentScene
      m.game.changeScene("Plain")
      m.assertEqual("Loading", m.game.currentScene.name)
      m.runFrames(6)
      m.assertEqual(1, loadingScene.createCalls)
      m.assertEqual("Plain", m.game.currentScene.name)
    end function

    @it("handles changeScene called from inside onLoad")
    function _()
      scene = m.game.Scenes["Loading"]
      scene.changeToInLoad = "Plain"
      m.game.changeScene("Loading")
      m.runFrames(6)
      m.assertEqual(1, scene.loadCalls)
      m.assertEqual(1, scene.createCalls)
      m.assertEqual("Plain", m.game.currentScene.name)
    end function

    @describe("loading screen")

    @it("only shows once loading has run for showAfterSeconds")
    function _()
      m.game.Scenes["Loading"].taskSteps = 100
      m.game.changeScene("Loading")
      m.game.runSceneTransitionFrameForTest(0.1)
      m.assertFalse(m.game.isLoadingScreenShown())
      m.game.runSceneTransitionFrameForTest(0.2)
      m.assertTrue(m.game.isLoadingScreenShown())
    end function

    @it("uses the scene's loading screen over the game's")
    function _()
      gameScreen = new CountingLoadingScreen()
      gameScreen.tag = "game"
      m.game.loadingScreen = gameScreen
      sceneScreen = new CountingLoadingScreen()
      sceneScreen.tag = "scene"
      sceneScreen.showAfterSeconds = 0
      scene = m.game.Scenes["Loading"]
      scene.screen = sceneScreen
      m.game.changeScene("Loading")
      m.game.runSceneTransitionFrameForTest(0.016)
      m.assertEqual(1, sceneScreen.showCalls)
      m.assertEqual(0, gameScreen.showCalls)
      m.runFrames(6)
      m.assertEqual(1, sceneScreen.hideCalls)
    end function

    @describe("with changeSceneWithFade")

    @it("fades out, loads, creates, then fades in")
    function _()
      m.game.changeScene("Plain")
      m.game.changeSceneWithFade("Loading", {}, 0.05)
      m.runFrames(4)
      m.assertEqual("Loading", m.game.currentScene.name)
      m.assertTrue(m.game.isLoading())
      m.assertEqual(1.0, m.game.screenFade.opacity)
      m.runFrames(6)
      m.assertFalse(m.game.isLoading())
      m.assertEqual(1, m.game.currentScene.createCalls)
      m.runFrames(10)
      m.assertEqual(0.0, m.game.screenFade.opacity)
      m.assertFalse(m.game.isTransitioning())
    end function

    @describe("game.assets")

    @it("is ticked every frame for background loads")
    function _()
      context = {calls: 0}
      m.game.assets.addStep(function(ctx as object) as dynamic
        ctx.calls = ctx.calls + 1
        return ctx.calls >= 2
      end function, context)
      m.game.runSceneTransitionFrameForTest(0.016)
      m.assertEqual(2, context.calls)
      m.assertTrue(m.game.assets.isDone())
    end function

    private sub runFrames(count as integer)
      for i = 1 to count
        m.game.runSceneTransitionFrameForTest(0.016)
      end for
    end sub

  end class

  ' Queues one task that takes `taskSteps` frames (one step per frame), and records calls.
  class LoadingTestScene extends BGE.GameScene
    loadCalls as integer = 0
    createCalls as integer = 0
    updateCalls as integer = 0
    taskSteps as integer = 3
    failOneTask as boolean = false
    changeToInLoad as string = ""
    createdWithArg as string = ""
    oldEntitiesSeenInLoad as integer = -1
    addedEntity as dynamic = invalid
    screen as dynamic = invalid

    sub new(game as BGE.Game, name as string, taskSteps as integer)
      super(game, {name: name})
      m.taskSteps = taskSteps
    end sub

    override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
      m.loadCalls++
      m.oldEntitiesSeenInLoad = m.game.getAllEntities("Old").count()
      entity = new CountingEntity(m.game, "AddedInLoad")
      m.game.addEntity(entity)
      m.addedEntity = entity
      ' one step per frame: the step function asks to wait for the next frame each call
      context = {remaining: m.taskSteps}
      task = loader.addStep(function(ctx as object) as dynamic
        ctx.remaining = ctx.remaining - 1
        ctx.task.waitingForNextFrame = true
        return ctx.remaining <= 0
      end function, context)
      context.task = task
      if m.failOneTask
        loader.addStep(function(ctx as object) as dynamic
          return ctx.missing.field
        end function, {})
      end if
      if m.changeToInLoad <> ""
        m.game.changeScene(m.changeToInLoad)
      end if
    end sub

    override sub onCreate(args as roAssociativeArray)
      m.createCalls++
      m.createdWithArg = "ok"
    end sub

    override sub onUpdate(dt as float)
      m.updateCalls++
    end sub

    override function getLoadingScreen() as BGE.LoadingScreen
      return m.screen
    end function
  end class

  class CountingEntity extends BGE.GameEntity
    updateCalls as integer = 0

    sub new(game as BGE.Game, name as string)
      super(game, {name: name})
    end sub

    override sub onUpdate(dt as float)
      m.updateCalls++
    end sub
  end class

  class CountingLoadingScreen extends BGE.LoadingScreen
    tag as string = ""
    showCalls as integer = 0
    hideCalls as integer = 0

    sub new()
      super()
    end sub

    override sub onShow()
      m.showCalls++
    end sub

    override sub onHide()
      m.hideCalls++
    end sub
  end class

end namespace
```

The loader clears `waitingForNextFrame` at the start of every `update()`, so a step function that sets it on each call runs once per frame - the documented way to do that (Task 7's guide).

- [ ] **Step 2: Run tests to verify they fail**

Run: `npm run validate`
Expected: FAIL - `GameScene` has no `onLoad`/`getLoadingScreen`; `Game` has no `runSceneTransitionFrameForTest`/`isLoading`/etc.

- [ ] **Step 3: Add the hooks to `GameScene`**

In `src/source/engine/GameScene.bs`, add imports `import "loading/AssetLoader.bs"` and `import "loading/LoadingScreen.bs"`, then add after `persistDrawablesAcrossSceneChange`'s constructor:

```brighterscript
    ' Called when this scene is changed to, before `onCreate()`. Queue anything that takes time
    ' on `loader` - asset loads (`loader.loadBitmap()`, `loader.load3dModel()`, ...), your own
    ' `BGE.LoadTask`s, or a function called once per step (`loader.addStep()`). The engine runs
    ' them a little each frame, showing a loading screen, then calls `onCreate(args)`.
    ' Queue nothing (the default) and `onCreate()` runs straight away.
    '
    ' The previous scene's entities are already gone. This scene doesn't get `onUpdate()`,
    ' `onInput()` etc. until `onCreate()` has run - nor do entities added during `onLoad()`.
    '
    ' @param {BGE.AssetLoader} loader - queue this scene's loading work here
    ' @param {object} args - the args passed to `changeScene()`
    sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    end sub

    ' The loading screen to show while this scene loads. Return `invalid` (the default) to use
    ' `game.loadingScreen`, or the engine's default if that isn't set.
    '
    ' @return {BGE.LoadingScreen}
    function getLoadingScreen() as BGE.LoadingScreen
      return invalid
    end function
```

- [ ] **Step 4: Add the loading stage to `Game`**

All edits in `src/source/engine/Game.bs`. Add `import "loading/AssetLoader.bs"` and `import "loading/LoadingScreen.bs"` to the imports.

(a) Public fields, next to `defaultTheme` (line ~187):

```brighterscript
    ' Background loader you can use at any time, e.g. to fetch the next level's assets while
    ' this one plays. Ticked once per frame within `assetsBudgetMs`.
    assets as BGE.AssetLoader
    ' Milliseconds per frame `assets` may spend on its tasks
    assetsBudgetMs as integer = 4
    ' Milliseconds per frame a scene's loading stage may spend on its tasks
    loadingBudgetMs as integer = 12
    ' Loading screen for scenes that don't provide one (`GameScene.getLoadingScreen()`).
    ' `invalid` uses the engine's default.
    loadingScreen as BGE.LoadingScreen = invalid
```

(b) Internal fields, inside the `****BEGIN - For Internal Use...` block:

```brighterscript
    private sceneLoader as BGE.AssetLoader = invalid
    private sceneLoading as boolean = false
    private sceneLoadingSeconds as float = 0.0
    private activeLoadingScreen as BGE.LoadingScreen = invalid
    private loadingScreenShown as boolean = false
    private defaultLoadingScreen as BGE.DefaultLoadingScreen = invalid
```

(c) In the constructor, after `m.defaultTheme.font = m.fonts["default"]` (line ~327):

```brighterscript
      m.assets = new BGE.AssetLoader(m)
```

(d) In `Play()`, right after the `m.processEntitiesPreDraw(...)` call (line ~492):

```brighterscript
        m.updateSceneLoading()
        m.assets.update(m.assetsBudgetMs)
```

(e) Replace `handleSceneChange()` (lines ~2217-2259) with:

```brighterscript
    private sub handleSceneChange()
      ' a change requested while a scene loads waits for that load to finish
      if m.sceneLoading
        return
      end if
      if m.sceneChangedThisFrame and m.sceneChangeDetails <> invalid and m.sceneChangeDetails.scene <> invalid
        thisScene = m.sceneChangeDetails.scene
        args = {}
        if m.sceneChangeDetails.args <> invalid
          args = m.sceneChangeDetails.args
        end if

        for i = 0 to m.sortedEntities.Count() - 1
          entity = m.sortedEntities[i]
          if m.isValidEntity(entity) and entity.onChangeScene <> invalid
            entity.onChangeScene(thisScene)
          end if
        end for
        ' gameUi/debugUi are never registered via addEntity(), so notify them directly.
        m.gameUi.onChangeScene(thisScene)
        m.debugUi.onChangeScene(thisScene)
        for i = 0 to m.sortedEntities.Count() - 1
          entity = m.sortedEntities[i]
          ' currentScene is still invalid on the very first scene change.
          if m.isValidEntity(entity) and not entity.persistent and (m.currentScene = invalid or entity.name <> m.currentScene.name)
            m.destroyEntity(entity, false)
          end if
        end for

        if m.isValidEntity(m.currentScene) and m.currentScene.onChangeScene <> invalid
          m.currentScene.onChangeScene(thisScene)
        end if

        m.currentScene = thisScene
        m.currentSceneArgs = args
        m.sceneChangedThisFrame = false
        m.startSceneLoading()
      end if
      ' changeScene() from onLoad/onCreate while the loop isn't running has nothing else to apply it
      if not m.running and m.sceneChangedThisFrame and not m.sceneLoading
        m.handleSceneChange()
      end if
    end sub

    private sub startSceneLoading()
      m.sceneLoader = new BGE.AssetLoader(m)
      ' set before onLoad so a changeScene() inside it is deferred, not applied mid-setup
      m.sceneLoading = true
      m.currentScene.onLoad(m.sceneLoader, m.currentSceneArgs)
      if not m.sceneLoader.hasTasks()
        m.finishSceneLoading()
        return
      end if
      m.sceneLoadingSeconds = 0.0
      m.loadingScreenShown = false
      m.activeLoadingScreen = m.resolveLoadingScreen()
    end sub

    private sub updateSceneLoading()
      if not m.sceneLoading
        return
      end if
      m.sceneLoader.update(m.loadingBudgetMs)
      m.sceneLoadingSeconds += m.dt
      if m.sceneLoader.isDone()
        m.finishSceneLoading()
        return
      end if
      if not m.loadingScreenShown and m.sceneLoadingSeconds >= m.activeLoadingScreen.showAfterSeconds
        m.loadingScreenShown = true
        m.activeLoadingScreen.onShow()
      end if
    end sub

    private sub finishSceneLoading()
      if m.loadingScreenShown
        m.activeLoadingScreen.onHide()
      end if
      m.loadingScreenShown = false
      m.activeLoadingScreen = invalid
      m.sceneLoading = false
      m.currentScene.onCreate(m.currentSceneArgs)
      m.renderQuality.notifySceneChanged()
      if m.fadeTransitionPhase = "out"
        m.fadeTransitionPhase = "in"
        m.screenFade.fadeTo(0, m.fadeTransitionSeconds)
      end if
      m.lastGarbageCollection = runGarbageCollector()
      m.garbageCollectionTimer.mark()
    end sub

    private function resolveLoadingScreen() as BGE.LoadingScreen
      sceneScreen = m.currentScene.getLoadingScreen()
      if sceneScreen <> invalid
        return sceneScreen
      end if
      if m.loadingScreen <> invalid
        return m.loadingScreen
      end if
      if m.defaultLoadingScreen = invalid
        m.defaultLoadingScreen = new BGE.DefaultLoadingScreen(m.defaultTheme.font)
        m.defaultLoadingScreen.barColor = m.defaultTheme.foregroundColor
        m.defaultLoadingScreen.barBackgroundColor = m.defaultTheme.backgroundColor
      end if
      return m.defaultLoadingScreen
    end function
```

Note the fade-in moved from `handleSceneChange` into `finishSceneLoading`; for a scene with no `onLoad` work this runs in the same call, so the fade order is unchanged.

(f) Public API, next to `isTransitioning()`:

```brighterscript
    ' Whether a scene is in its loading stage (after `changeScene()`, before its `onCreate()`).
    '
    ' @return {boolean}
    function isLoading() as boolean
      return m.sceneLoading
    end function

    ' The current scene's loading progress, 0 to 1 (1 when not loading).
    '
    ' @return {float}
    function getLoadingProgress() as float
      if m.sceneLoading
        return m.sceneLoader.getProgress()
      end if
      return 1.0
    end function

    ' The loader from the current scene's loading stage, e.g. to check
    ' `getSceneLoader().getErrors()` in `onCreate()`. Kept until the next scene change.
    '
    ' @return {BGE.AssetLoader}
    function getSceneLoader() as BGE.AssetLoader
      return m.sceneLoader
    end function

    ' Whether the loading screen is currently showing.
    '
    ' @return {boolean}
    function isLoadingScreenShown() as boolean
      return m.loadingScreenShown
    end function
```

and change `isTransitioning()`'s body to:

```brighterscript
      return m.fadeTransitionPhase <> "" or m.sceneLoading
```

Update its doc comment to: `' Whether a changeSceneWithFade() transition or a scene's loading stage is running.`

(g) Skip the loading scene and non-persistent entities while loading. Add this helper next to `isValidEntity`:

```brighterscript
    ' While a scene loads, only persistent entities run - not the loading scene itself, and not
    ' entities it added in onLoad().
    private function isHeldForLoading(entity as GameEntity, isScene as boolean) as boolean
      return m.sceneLoading and (isScene or not entity.persistent)
    end function
```

In `processEntitiesPreDraw` change the skip condition (line ~734) from
`if not m.isValidEntity(entity) or not entity.enabled or (startedPaused and entity.pauseable)`
to
`if not m.isValidEntity(entity) or not entity.enabled or (startedPaused and entity.pauseable) or m.isHeldForLoading(entity, i = m.sortedEntities.Count())`.

In `processEntitiesCollisions` (line ~803) change
`if not m.isValidEntity(entity) or not entity.enabled or (startedPaused and entity.pauseable) or entity.colliders.count() = 0`
to
`if not m.isValidEntity(entity) or not entity.enabled or (startedPaused and entity.pauseable) or entity.colliders.count() = 0 or m.isHeldForLoading(entity, i = m.sortedEntities.Count())`.

In `drawEntities`, change both `if invalid <> m.currentScene` guards to `if invalid <> m.currentScene and not m.sceneLoading`, and the two `for each entity in m.sortedEntities` bodies to:

```brighterscript
      for each entity in m.sortedEntities
        if not m.isHeldForLoading(entity, false)
          m.processEntityPreDraw(entity)
        end if
      end for
```

(and the same with `processEntityPostDraw`).

(h) In `drawUI()`, after `m.screenFade.draw(m.uiCanvas.renderer)`:

```brighterscript
      if m.loadingScreenShown
        m.activeLoadingScreen.draw(m.uiCanvas.renderer, m.sceneLoader.getProgress(), m.dt)
      end if
```

(i) Test helpers, next to `updateFadeTransitionForTest`:

```brighterscript
    ' Test-only: one frame of scene transition work with a given dt - fade, loading stage,
    ' background assets, then any scene change requested this frame, as Play() does.
    '
    ' @param {float} dt
    sub runSceneTransitionFrameForTest(dt as float)
      m.dt = dt
      m.updateFadeTransition()
      m.updateSceneLoading()
      m.assets.update(m.assetsBudgetMs)
      if m.sceneChangedThisFrame
        m.handleSceneChange()
      end if
    end sub

    ' Test-only: one update pass over the scene and entities with no input.
    sub processEntitiesPreDrawForTest()
      m.processEntitiesPreDraw([] as roUniversalControlEvent[], [] as GameInput[], [] as GameInput[], invalid, invalid, invalid)
    end sub
```

Make the existing `updateFadeTransitionForTest(dt)` call `m.runSceneTransitionFrameForTest(dt)` as its whole body, so the fade specs exercise the same path.

- [ ] **Step 5: Run tests to verify they pass**

Run: `npm run check`
Expected: PASS - the new suite, plus every existing `Game`, `GameFadeTransition`, `GameScene` and `GameEntity` test unchanged (they cover the no-`onLoad` path, which must behave exactly as before).

- [ ] **Step 6: Commit**

```bash
git add src/source/engine/Game.bs src/source/engine/GameScene.bs src/source/engine/GameSceneLoading.spec.bs
git commit -m "Add a loading stage to scene changes, and game.assets (#301)"
```

---

### Task 6: `examples/loading` (local assets + custom loading screen)

**Files:**
- Create (scaffold): `examples/loading/` via `npm run create-example -- loading "Asset Loading"`
- Create: `examples/loading/src/source/Scenes/MenuScene.bs`, `LocalAssetsScene.bs`, `CustomScreenScene.bs`
- Create: `examples/loading/src/source/UI/TimedLoadingScreen.bs`, `UI/DotsLoadingScreen.bs`
- Create: `examples/loading/src/models/` (copy `examples/3d/src/models/*.stl`, `car.obj`, `d20.obj`, `d20.mtl`, `d20_atlas.png`)
- Modify: `examples/loading/src/source/main.bs`

**Interfaces:**
- Consumes: `GameScene.onLoad(loader, args)`, `GameScene.getLoadingScreen()`, `AssetLoader.load3dModel/addStep`, `LoadTask.weight`/`waitingForNextFrame`, `BGE.DefaultLoadingScreen`, `game.getSceneLoader().getErrors()`, `BGE.UI.Button`/`BGE.UI.Label` (as used in `examples/ui/src/source/Scenes/MainScene.bs`).
- Produces: a runnable example; deep link `--param scene=LocalAssetsScene|CustomScreenScene`.

- [ ] **Step 1: Scaffold and copy assets**

```bash
npm run create-example -- loading "Asset Loading"
mkdir -p examples/loading/src/models
cp examples/3d/src/models/*.stl examples/3d/src/models/car.obj examples/3d/src/models/d20.obj examples/3d/src/models/d20.mtl examples/3d/src/models/d20_atlas.png examples/loading/src/models/
```

Read the generated `examples/loading/src/source/main.bs` and `Scenes/MainScene.bs`, then delete `MainScene.bs` (replaced by `MenuScene`).

- [ ] **Step 2: `main.bs`**

```brighterscript
sub Main(args as dynamic)
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()

  menu = new MenuScene(game)
  game.defineScene(menu)
  local = new LocalAssetsScene(game)
  game.defineScene(local)
  custom = new CustomScreenScene(game)
  game.defineScene(custom)

  startScene = menu.name
  if args <> invalid and args.scene <> invalid and game.Scenes[args.scene] <> invalid
    startScene = args.scene
  end if
  game.changeScene(startScene)

  game.enableStandardDebugUi({memory: false, garbageCollector: false, log: false})
  game.play()
end sub
```

- [ ] **Step 3: `MenuScene.bs`**

Model it on `examples/ui/src/source/Scenes/MainScene.bs` (a hint `Label` plus a vertical stack of `BGE.UI.Button`s whose `onActivate` calls `button.game.changeScene(...)`, and `m.game.gameUi.clearChildren()` at the top of `onCreate`). Two buttons: "Large local assets" -> `LocalAssetsScene`, "Custom loading screen" -> `CustomScreenScene`. Hint text: `"Each scene loads its assets in onLoad() before it opens."` Positions at `width * 0.11` / `height * 0.14 + n * height * 0.1`. `onInput`: nothing (Back on the menu exits via the engine's default).

- [ ] **Step 4: `TimedLoadingScreen.bs` and `LocalAssetsScene.bs`**

`examples/loading/src/source/UI/TimedLoadingScreen.bs`:

```brighterscript
' The default loading screen plus a frame-time readout, to show the game loop keeps running
' (and how smoothly) while assets load.
class TimedLoadingScreen extends BGE.DefaultLoadingScreen

  private worstFrameMs as float = 0.0
  private lastFrameMs as float = 0.0

  sub new(font as roFont)
    super(font)
    m.showAfterSeconds = 0
  end sub

  override sub onShow()
    m.worstFrameMs = 0.0
  end sub

  override sub draw(renderer as BGE.Renderer, progress as float, dt as float)
    super.draw(renderer, progress, dt)
    m.lastFrameMs = dt * 1000
    if m.lastFrameMs > m.worstFrameMs
      m.worstFrameMs = m.lastFrameMs
    end if
    if m.font <> invalid
      size = renderer.getCanvasSize()
      text = `frame ${Int(m.lastFrameMs)}ms  worst ${Int(m.worstFrameMs)}ms  ${Int(progress * 100)}%`
      renderer.drawText(text, Int(size.x / 2), Int(size.y * 0.65), m.barColor, m.font, "center", "top")
    end if
  end sub

end class
```

`examples/loading/src/source/Scenes/LocalAssetsScene.bs`:

```brighterscript
' Loads every model in pkg:/models/ through onLoad(), parsed a slice at a time, then lists what
' loaded and how long the whole load took.
class LocalAssetsScene extends BGE.GameScene

  private loadTimer as roTimespan
  private loadSeconds as float = 0.0
  private modelNames as string[]

  sub new(game as BGE.Game)
    super(game)
    m.name = "LocalAssetsScene"
  end sub

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    m.loadTimer = CreateObject("roTimespan")
    m.modelNames = []
    files = CreateObject("roFileSystem").GetDirectoryListing("pkg:/models/")
    for each fileName in files
      lowerName = LCase(fileName)
      if lowerName.EndsWith(".stl") or lowerName.EndsWith(".obj")
        task = loader.load3dModel(fileName, "pkg:/models/" + fileName)
        ' bigger files take longer - weight the bar by size
        stat = CreateObject("roFileSystem").Stat("pkg:/models/" + fileName)
        if stat <> invalid and stat.size <> invalid
          task.weight = stat.size / 1000.0 + 1
        end if
        m.modelNames.push(fileName)
      end if
    end for
  end sub

  override function getLoadingScreen() as BGE.LoadingScreen
    screen = new TimedLoadingScreen(m.game.getFont("debugUI"))
    return screen
  end function

  override sub onCreate(args as roAssociativeArray)
    m.loadSeconds = m.loadTimer.TotalMilliseconds() / 1000.0
    m.game.gameUi.clearChildren()
    width = m.game.canvas.getWidth()
    height = m.game.canvas.getHeight()
    lines = [`Loaded ${m.modelNames.count()} models in ${m.loadSeconds}s - Back for the menu`]
    for each modelName in m.modelNames
      model = m.game.Models[modelName]
      if model <> invalid
        lines.push(`${modelName}: ${model.faces.count()} faces`)
      end if
    end for
    for each errorMessage in m.game.getSceneLoader().getErrors()
      lines.push("ERROR " + errorMessage)
    end for
    for i = 0 to lines.count() - 1
      label = new BGE.UI.Label(m.game)
      label.setText(lines[i])
      label.customPosition = true
      label.customX = width * 0.11
      label.customY = height * 0.11 + i * height * 0.05
      m.game.gameUi.addChild(label)
    end for
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.changeScene("MenuScene")
    end if
  end sub

end class
```

(`Game.Models` is a public field; reading it directly avoids `get3dModel()`'s warning for a model that failed to load.)

- [ ] **Step 5: `DotsLoadingScreen.bs` and `CustomScreenScene.bs`**

`examples/loading/src/source/UI/DotsLoadingScreen.bs`:

```brighterscript
' A strip along the bottom of the screen with animated dots and a thin bar - partial, so the
' level building above it stays visible.
class DotsLoadingScreen extends BGE.LoadingScreen

  font as roFont
  private elapsed as float = 0.0

  sub new(font as roFont)
    super()
    m.font = font
    m.showAfterSeconds = 0
  end sub

  override sub draw(renderer as BGE.Renderer, progress as float, dt as float)
    m.elapsed += dt
    size = renderer.getCanvasSize()
    stripY = size.y * 0.8
    renderer.drawRectangle(size.x * 0.1, stripY, size.x * 0.8, size.y * 0.1, &h000000C0)
    dots = Left("...", Int(m.elapsed * 3) mod 4)
    renderer.drawText("Building level" + dots, Int(size.x * 0.12), Int(stripY + size.y * 0.02), BGE.Colors.Yellow, m.font, "left", "top")
    renderer.drawRectangle(size.x * 0.12, stripY + size.y * 0.075, size.x * 0.76 * progress, 4, BGE.Colors.Yellow)
  end sub

end class
```

`examples/loading/src/source/Scenes/CustomScreenScene.bs`:

```brighterscript
' Builds a grid of tiles a row at a time with loader.addStep(), under a custom loading screen
' that only covers the bottom of the screen, so you can watch the level fill in.
class CustomScreenScene extends BGE.GameScene

  rowsBuilt as integer = 0
  private rows as integer = 36
  private columns as integer = 64

  sub new(game as BGE.Game)
    super(game)
    m.name = "CustomScreenScene"
  end sub

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    m.rowsBuilt = 0
    context = {scene: m}
    task = loader.addStep(buildTileRowStep, context)
    context.task = task
  end sub

  override function getLoadingScreen() as BGE.LoadingScreen
    screen = new DotsLoadingScreen(m.game.getFont("debugUI"))
    return screen
  end function

  ' Builds one row of tiles. Returns progress, 1 when every row is built.
  function buildNextRow() as float
    width = m.game.canvas.getWidth()
    height = m.game.canvas.getHeight()
    tileWidth = width * 0.8 / m.columns
    tileHeight = height * 0.65 / m.rows
    y = m.rowsBuilt
    for x = 0 to m.columns - 1
      tile = new BGE.DrawableRectangle(m, tileWidth - 1, tileHeight - 1, {color: BGE.getRandomColorRGB()})
      ' world space is y-up and a rectangle hangs down from its offset, so row 0 is the top row
      tile.offset.x = width * 0.1 + x * tileWidth
      tile.offset.y = height * 0.9 - y * tileHeight
      m.addDrawable("tile_" + x.toStr() + "_" + y.toStr(), tile)
    end for
    m.rowsBuilt++
    return m.rowsBuilt / m.rows
  end function

  override sub onCreate(args as roAssociativeArray)
    m.game.gameUi.clearChildren()
    label = new BGE.UI.Label(m.game)
    label.setText(`Built ${m.rowsBuilt * m.columns} tiles - Back for the menu`)
    label.customPosition = true
    label.customX = m.game.canvas.getWidth() * 0.11
    label.customY = m.game.canvas.getHeight() * 0.8
    m.game.gameUi.addChild(label)
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and input.isButton("back")
      m.game.changeScene("MenuScene")
    end if
  end sub

end class

' addStep() callback: one row per frame, so the level visibly builds.
function buildTileRowStep(context as object) as dynamic
  context.task.waitingForNextFrame = true
  return context.scene.buildNextRow()
end function
```

`DrawableRectangle`'s constructor is `new(owner, width, height, args)`; positions follow `examples/breakout`'s bricks (world y-up, a rectangle extends down from its top edge). If the first device screenshot shows the grid upside down or offset, fix the `offset.y` formula there. The scene's drawables are removed by `GameScene.onChangeScene()` when leaving, so re-entering rebuilds cleanly.

- [ ] **Step 6: Build, validate, run on a device**

```bash
cd examples/loading && npm install && npm run package && cd ../..
npm run validate-examples
node node_modules/rokubot/dist/cli.js sideload ./examples/loading/out/bge-loading.zip --deleteDevChannel
```

Then via rokubot (see the `rokubot-examples` skill): screenshot the menu, `press select` on "Large local assets", screenshot during loading (the bar and the frame-time line should be visible and the bar part way), then after - the model list with no ERROR lines. Back, Down, `press select` on "Custom loading screen": screenshots should show the bottom strip and a part-built grid, then the full grid and the label. Check `debugger-state` after each. Record the worst frame time from the local-assets screen in the PR description.

- [ ] **Step 7: Commit**

```bash
git add examples/loading .vscode/tasks.json
git commit -m "Add examples/loading: local assets and a custom loading screen (#301)"
```

---

### Task 7: Docs and final check

**Files:**
- Create: `docs/loading-assets.md`
- Modify: `CLAUDE.md` (Architecture: new bullet under "Entities, Scenes, Drawables"; Commands/examples table untouched)
- Modify: `.claude/skills/rokubot-examples/SKILL.md` (add a `loading` row to the examples table)

- [ ] **Step 1: Write the guide**

`docs/loading-assets.md`, frontmatter:

```markdown
---
title: Loading Assets
group: Guides
order: 4
---
```

(Check the `order` values of the other guides in `docs/` and pick the next free one.) Sections, each led by a short code example:
1. **Loading in `onLoad`** - a scene overriding `onLoad(loader, args)` with `loader.loadBitmap`/`load3dModel`, then using the assets in `onCreate`. One paragraph on what happens: old scene gone, loading screen after 0.25s, `onCreate` when done; a scene with no `onLoad` work opens immediately as before.
2. **Your own work** - `loader.addStep(fn, context)` building a level a row at a time (returning a 0-1 progress), and setting `context.task.waitingForNextFrame = true` for one step per frame; then a `BGE.LoadTask` subclass with `step(budgetMs)`/`getProgress()`, `weight`, and `after()`.
3. **Errors** - `game.getSceneLoader().getErrors()` in `onCreate`.
4. **Loading screens** - `getLoadingScreen()` on a scene, `game.loadingScreen`, extending `BGE.LoadingScreen` (`draw(renderer, progress, dt)`, `showAfterSeconds`), and `BGE.DefaultLoadingScreen`'s colours/label.
5. **Background loading** - `game.assets` with `onComplete`, `assetsBudgetMs`.
6. Aside (not a section of its own): one native call can't be split - reading a huge file, one big image decode, one sound - so that frame still hitches; models are parsed a slice at a time.

Link to the engine overview guide with `[Game Engine Overview](/game-engine-overview)`.

- [ ] **Step 2: CLAUDE.md and the rokubot skill**

CLAUDE.md, new bullet after the `GameScene` bullet:

```markdown
- **Scene loading stage** (`engine/loading/`, issue #301, spec `specs/2026-10-09-async-asset-loading-design.md`): `handleSceneChange()` tears down the old scene, sets `currentScene`, then calls `GameScene.onLoad(loader, args)`; if the `BGE.AssetLoader` has tasks, `Game.updateSceneLoading()` runs them each frame within `loadingBudgetMs` and draws a `BGE.LoadingScreen` (scene's `getLoadingScreen()`, else `game.loadingScreen`, else `DefaultLoadingScreen`) above the fade overlay after `showAfterSeconds`, then `finishSceneLoading()` calls `onCreate` and starts the fade-in. No tasks = `onCreate` in the same call, as before. While loading, the scene and non-persistent entities get no per-frame callbacks (`isHeldForLoading()`), and a `changeScene()` waits until loading ends. `LoadTask.step(budgetMs)`/`getProgress()` is the unit of work; `.obj`/`.stl` parse a slice at a time via `BGE.Parsers.OBJParseTask`/`STLAsciiParseTask`/`STLBinaryParseTask`, which `parseOBJContent`/`parseSTL*File` now wrap. `game.assets` is a second loader ticked every frame within `assetsBudgetMs`. See `examples/loading`.
```

Skill table row:

```markdown
| `loading` | Asset-loading demo: a menu of scenes that each load in `GameScene.onLoad()`. "Large local assets" parses every model in `pkg:/models/` under a loading screen with a frame-time readout, then lists faces per model; "Custom loading screen" builds a 64x36 tile grid a row per frame under a strip-style loading screen. `--param scene=LocalAssetsScene|CustomScreenScene` skips the menu. | `up`/`down` + `select` in the menu, `back` returns to the menu |
```

- [ ] **Step 3: Full check**

Run: `npm run check:all`
Expected: lint/validate/tests PASS, every example validates.

Run: `npm run docs`
Expected: builds; `docs-site/` contains a "Loading Assets" page under Guides.

- [ ] **Step 4: Commit**

```bash
git add docs/loading-assets.md CLAUDE.md .claude/skills/rokubot-examples/SKILL.md
git commit -m "Document the scene loading stage and AssetLoader (#301)"
```
