# The Mutiny (PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `examples/visualnovel` - "The Mutiny", a short sci-fi visual novel (20 nodes, 3 endings) built only on `BGE.Story`, with backgrounds, portrait cards, a typewriter text box, choices, a backlog, autosave/Continue and an endings-seen list (closes #294).

**Architecture:** The story is data (`src/story/mutiny.json`). One `StageScene` owns a `BGE.Story.StoryState` and `DialogueRunner` and drives four UI pieces in `gameUi` (backdrop, two portrait cards, text box, choice list) plus a backlog panel. Line objects carry `background`/`left`/`right` keys the scene reads; endings `post` `ending:<id>`. A `TitleScene` offers Continue/New Game. The game registers no story vocabulary of its own - that's the test of the engine core.

**Tech Stack:** BrighterScript, `BGE.Story` (PR 1), `BGE.UI`, Rooibos for the story tests, `sips` for asset resizing (macOS), rokubot for on-device checks.

**Spec:** `specs/2026-10-11-bge-story-and-visual-novel-design.md` (Part 2). Builds on `specs/2026-10-11-bge-story-plan.md` (PR 1), which must be merged or this branch stacked on it.

## Global Constraints

- Branch: `feature/issue-294-visual-novel`, created from `feature/issue-298-bge-story` (stacked) or from `main` once PR 1 merges. Never commit to `main`.
- Game canvas 1280x720; all UI in `gameUi`; every text/widget position title-safe (≥10% in from each edge).
- Backgrounds committed as 1280x720 JPG; portraits as 360x480 PNG cards. No music or sound.
- Registry section `bge-visualnovel`, keys `save` and `endings`. Deep-link params turn saving off.
- `goto`/`call`/`end` are quoted in any BrighterScript AA literal and read with brackets.
- Guard every discrete action with `input.press`. Never compare custom-class instances or `roBitmap`s with `=`.
- No game-specific condition/effect registrations - if the story needs one, stop and raise it (it means the engine core is missing something).
- Every asset's licence and author checked on its OpenGameArt page and credited in `src/images/CREDITS.md` and on the title screen.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Gate: `npm run check`, `npm run validate-examples`, `cd examples/visualnovel && npm test`, then an on-device run.

## Review Focus

1. **A save from an older build of the story** (node renamed or removed) - Continue must start a new story at `start` (keeping nothing broken), not crash or show a blank box. Tested in Task 3.
2. **Pressing OK rapidly through the typewriter and into a choice list** - the press that finishes a line must not also click the first choice. Covered by the one-frame button delay in Task 5; checked on device in Task 7.
3. **Reaching every ending** - each ending must be reachable from `start` with some choices, and the best ending only with all three clues. Tested in Task 2.
4. **A line too long for the text box** - must not overflow the box. Tested in Task 2 (length cap) and handled by wrapping in Task 4.
5. **Opening the backlog while choices are shown** - focus must return to the choices when it closes, and Back in the backlog must not quit to the title. Covered in Task 5; checked on device in Task 7.

---

## File structure

`examples/visualnovel/`:

| Path | Responsibility |
|---|---|
| `src/manifest` | channel config, `multi_controllers=1` |
| `src/story/mutiny.json` | the whole story |
| `src/images/bg/*.jpg`, `src/images/portraits/*.png`, `src/images/CREDITS.md` | art and attribution |
| `src/source/main.bs` | game setup, scenes, deep links |
| `src/source/Story/Characters.bs` | speaker name → portrait id; portrait/background ids → bitmap names |
| `src/source/Story/VnSave.bs` | save data and endings-seen (pure, tested) |
| `src/source/UI/Backdrop.bs` | full-screen background with a fade on change |
| `src/source/UI/PortraitCard.bs` | one framed portrait, lit or dimmed |
| `src/source/UI/TextBox.bs` | name tab + typewriter text |
| `src/source/UI/ChoiceList.bs` | choice buttons |
| `src/source/UI/BacklogPanel.bs` | scrollable history |
| `src/source/Scenes/StageScene.bs` | runs the story |
| `src/source/Scenes/TitleScene.bs` | Continue / New Game / endings seen / credits |
| `tests/Mutiny.spec.bs`, `tests/VnSave.spec.bs`, `bsconfig.test.json` | story and save tests |

---

### Task 1: Scaffold and assets

**Files:** `examples/visualnovel/**` (scaffold), `src/images/bg/centaurBridge.jpg`, `greyanBridge.jpg`, `lab.jpg`, `src/images/portraits/husk.png`, `voss.png`, `castell.png`, `sato.png`, `src/images/CREDITS.md`, `src/manifest`.

- [ ] **Step 1: Branch and scaffold**

```bash
git checkout feature/issue-298-bge-story
git checkout -b feature/issue-294-visual-novel
npm run create-example -- visualnovel "The Mutiny"
cd examples/visualnovel && npm install
```

Delete the scaffold's `MainScene.bs`, `util.bs` (if unused) and `src/sounds/`. In `src/manifest` set `title=The Mutiny` and add `multi_controllers=1` under Channel Options (copy the rpg manifest's options block).

- [ ] **Step 2: Resize the art (from `~/Downloads/visual novel`)**

Backgrounds to 1280x720 JPG:

```bash
sips -s format jpeg -s formatOptions 85 -z 720 1280 "$HOME/Downloads/visual novel/centaurbrige/centaurbridgeRender.png" --out examples/visualnovel/src/images/bg/centaurBridge.jpg
sips -s format jpeg -s formatOptions 85 -z 720 1280 "$HOME/Downloads/visual novel/GreyanBridge/greyan_bridge.png" --out examples/visualnovel/src/images/bg/greyanBridge.jpg
sips -s format jpeg -s formatOptions 85 -z 720 1280 "$HOME/Downloads/visual novel/ancientartefactresearch/render.png" --out examples/visualnovel/src/images/bg/lab.jpg
```

Portraits to 3:4 cards, cropped about the centre then scaled to 360x480 (science-officer.png is square, so it's cropped to 600x800 first; StarPilot to 1413x1884):

```bash
sips -c 2000 1500 "$HOME/Downloads/visual novel/Husk_thumb.png" --out /tmp/husk.png && sips -z 480 360 /tmp/husk.png --out examples/visualnovel/src/images/portraits/husk.png
sips -c 800 600 "$HOME/Downloads/visual novel/science-officer.png" --out /tmp/voss.png && sips -z 480 360 /tmp/voss.png --out examples/visualnovel/src/images/portraits/voss.png
sips -c 667 500 "$HOME/Downloads/visual novel/SecurityOfficer.png" --out /tmp/castell.png && sips -z 480 360 /tmp/castell.png --out examples/visualnovel/src/images/portraits/castell.png
sips -c 1884 1413 "$HOME/Downloads/visual novel/StarPilot.png" --out /tmp/sato.png && sips -z 480 360 /tmp/sato.png --out examples/visualnovel/src/images/portraits/sato.png
```

(Use the session scratchpad instead of `/tmp` if one is configured.) Open each output and check faces aren't cut off; if one is, crop with an offset using `sips --cropOffset`.

- [ ] **Step 3: Credits**

The asset pages (from the user):
- Sato: https://opengameart.org/content/starship-pilot
- Husk: https://opengameart.org/content/the-husk-human-analog-android
- Castell: https://opengameart.org/content/starship-security-officer
- Voss: https://opengameart.org/content/science-officer
- Greyan bridge: https://opengameart.org/content/greyan-space-ship-bridge
- Research lab: https://opengameart.org/content/ancient-artifact-research
- Centaur bridge: no page given - read `~/Downloads/visual novel/centaurbrige/license.txt`, and search OpenGameArt for "centaur bridge" for the page.

Fetch each page and read its author and licence. For each, record title, author, licence and URL in `src/images/CREDITS.md`:

```markdown
# Art credits

| Asset | File | Author | Licence | Source |
|---|---|---|---|---|
| Husk portrait | portraits/husk.png | Justin Nichol | <licence from the page> | <url> |
...
Resized and cropped for this example.
```

If any licence requires something beyond attribution (e.g. share-alike for derivatives), note it there and tell the user before committing.

- [ ] **Step 4: Validate the empty example builds**

Add a placeholder `main.bs` (`sub Main()` creating a `BGE.Game(1280, 720)` and calling `game.play()`), run `npm run validate-examples`. Expected: no errors for `visualnovel`.

- [ ] **Step 5: Commit**

```bash
git add examples/visualnovel .vscode/tasks.json
git commit -m "examples/visualnovel: scaffold, art and credits (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The story and its tests

**Files:**
- Create: `examples/visualnovel/src/story/mutiny.json`, `examples/visualnovel/bsconfig.test.json`, `examples/visualnovel/tests/Mutiny.spec.bs`; add a `test` script to `package.json`.

**Interfaces:**
- Produces (story contract the scene relies on): start node `start`; line object keys `background` (`centaurBridge` | `greyanBridge` | `lab`), `left`/`right` (`husk` | `voss` | `castell` | `sato` | `""`); speakers `Husk`, `Dr. Voss`, `Chief Castell`, `Lt. Sato` (or none); ending posts `ending:stopped`, `ending:mutiny`, `ending:leave`; items `dataCore`, `relayTap`, `navLog`, `accessRecord` with a `name` field.

- [ ] **Step 1: Write `mutiny.json`**

```json
{
  "items": {
    "dataCore": {"max": 1, "name": "Greyan data core"},
    "relayTap": {"max": 1, "name": "Relay tap", "onAcquire": [{"add": "evidence.count", "amount": 1}]},
    "navLog": {"max": 1, "name": "Altered nav log", "onAcquire": [{"add": "evidence.count", "amount": 1}]},
    "accessRecord": {"max": 1, "name": "Command-code trace", "onAcquire": [{"add": "evidence.count", "amount": 1}]}
  },
  "rules": [
    {"event": "storyChanged", "when": [{"hasItem": "relayTap"}, {"hasItem": "navLog"}, {"hasItem": "accessRecord"}, {"notFlag": "evidence.complete"}], "effects": [{"set": "evidence.complete", "value": true}]}
  ],
  "nodes": {
    "start": {
      "lines": [
        {"text": "Survey ship Centaur. Day 212 of a long, quiet survey of the Greyan Drift.", "background": "centaurBridge", "left": "", "right": ""},
        {"speaker": "Lt. Sato", "text": "Captain, we're picking up a signal. Old Greyan encoding, repeating.", "left": "sato"},
        {"speaker": "Chief Castell", "text": "A distress call? Out here? Someone's alive on that derelict.", "right": "castell"}
      ],
      "choices": [
        {"label": "Answer the call.", "effects": [{"set": "answered", "value": true}], "goto": "briefing"},
        {"label": "Log it and hold position.", "effects": [{"add": "trust.sato", "amount": 1}], "goto": "holdPosition"}
      ]
    },
    "holdPosition": {
      "lines": [
        {"speaker": "Chief Castell", "text": "With respect, Captain, regulations say we render aid. The crew will expect it."},
        {"speaker": "Lt. Sato", "text": "And if it's a lure? Greyan ships don't just go quiet."},
        "Castell's jaw tightens. He isn't used to losing an argument."
      ],
      "effects": [{"add": "trust.castell", "amount": -1}],
      "goto": "briefing"
    },
    "briefing": {
      "lines": [
        {"speaker": "Dr. Voss", "text": "The derelict is the Greyan ship Ilsk. Dead for decades, if the hull scans are right.", "left": "voss", "right": "husk"},
        {"speaker": "Husk", "text": "And yet it is transmitting, Captain. Something aboard still has power."},
        {"speaker": "Chief Castell", "text": "Greyan drive tech is worth more than this whole ship. If there's anyone to save, we save them. If there isn't...", "left": "castell", "right": "sato"},
        {"speaker": "Lt. Sato", "text": "If there isn't, we leave it alone."}
      ],
      "choices": [
        {"label": "Castell's right. We go aboard.", "effects": [{"add": "trust.castell", "amount": 1}], "goto": "awayTeam"},
        {"label": "Sato's right. Scan it from here first.", "effects": [{"add": "trust.sato", "amount": 1}], "goto": "scanFirst"}
      ]
    },
    "scanFirst": {
      "lines": [
        {"speaker": "Dr. Voss", "text": "No life signs. Just that signal, over and over.", "left": "voss", "right": "husk"},
        {"speaker": "Husk", "text": "And a data core, Captain. Still warm."},
        "There's no avoiding it. Someone has to go over."
      ],
      "goto": "awayTeam"
    },
    "awayTeam": {
      "lines": [{"text": "The shuttle has room for two.", "left": "sato", "right": "castell"}],
      "choices": [
        {"label": "Take Lt. Sato.", "effects": [{"set": "away.partner", "value": "Sato"}], "goto": "greyanWithSato"},
        {"label": "Take Chief Castell.", "effects": [{"set": "away.partner", "value": "Castell"}, {"add": "trust.castell", "amount": 1}], "goto": "greyanWithCastell"}
      ]
    },
    "greyanWithSato": {
      "lines": [
        {"speaker": "Lt. Sato", "text": "Nobody's home. Look at the dust on everything.", "background": "greyanBridge", "left": "sato", "right": ""},
        {"speaker": "Lt. Sato", "text": "Captain, this console... someone's patched a relay into it. Recently. That's our hardware."},
        "While you pull the data core, Sato pockets a tap from the relay: a log of every message sent through it."
      ],
      "effects": [{"giveItem": "dataCore"}, {"giveItem": "relayTap"}],
      "goto": "lab"
    },
    "greyanWithCastell": {
      "lines": [
        {"speaker": "Chief Castell", "text": "Look at this place. The drive core's fully intact. We'd be rich.", "background": "greyanBridge", "left": "", "right": "castell"},
        "While you pull the data core, Castell wanders over to the comms console. He comes back a little too quickly.",
        {"speaker": "Chief Castell", "text": "Nothing over there. Let's go."}
      ],
      "effects": [{"giveItem": "dataCore"}, {"set": "castell.wandered", "value": true}],
      "goto": "lab"
    },
    "lab": {
      "lines": [
        {"speaker": "Dr. Voss", "text": "The core is Greyan, all right. And that signal isn't a distress call.", "background": "lab", "left": "voss", "right": ""},
        {"speaker": "Dr. Voss", "text": "It's a warning. 'Do not take what sleeps here.' Their drive core is unstable. It killed them."},
        {"speaker": "Dr. Voss", "text": "Captain, I'd like to keep this between us until I'm sure. If the crew panics..."}
      ],
      "choices": [
        {"label": "Agreed. Keep it quiet.", "effects": [{"set": "kept.secret", "value": true}, {"add": "trust.voss", "amount": 1}], "goto": "nightShift"},
        {"label": "No. The crew deserves to know.", "effects": [{"set": "told.crew", "value": true}], "goto": "nightShift"}
      ]
    },
    "nightShift": {
      "lines": [
        {"text": "Ship's night. The bridge lights are dimmed to amber.", "background": "centaurBridge", "left": "husk", "right": ""},
        {"speaker": "Husk", "text": "Captain. I have found something I do not like."}
      ],
      "call": "huskReport",
      "goto": "hub"
    },
    "huskReport": {
      "speaker": "Husk",
      "lines": [
        "Someone altered the navigation log at 0300. Our course now runs to the Ilsk's drive core, and from there to a Free Trader depot.",
        "The change was made with a command code. I cannot see whose."
      ],
      "effects": [{"giveItem": "navLog"}]
    },
    "hub": {
      "lines": [{"text": "Morning. Someone aboard means to take the Centaur. You have time to talk to your crew.", "left": "", "right": ""}],
      "choices": [
        {"label": "Talk to Lt. Sato.", "once": true, "call": "talkSato"},
        {"label": "Talk to Chief Castell.", "once": true, "call": "talkCastell"},
        {"label": "Talk to Dr. Voss.", "once": true, "call": "talkVoss"},
        {"label": "Ask Husk for a status report.", "when": [{"flag": "husk.reports", "lt": 3}], "call": "huskStatus"},
        {"label": "I've heard enough.", "when": [{"visited": "talkSato"}, {"visited": "talkCastell"}, {"visited": "talkVoss"}, {"flag": "husk.reports", "lt": 3}], "goto": "confrontation"},
        {"goto": "confrontation"}
      ]
    },
    "talkSato": [
      {
        "when": [{"flag": "away.partner", "eq": "Sato"}],
        "speaker": "Lt. Sato",
        "lines": [
          {"text": "That relay tap we pulled? I decoded it. Messages to a Free Trader depot, signed with a security cipher.", "left": "sato"},
          "Only one department aboard uses that cipher, Captain."
        ],
        "effects": [{"add": "trust.sato", "amount": 1}]
      },
      {
        "when": [{"flag": "trust.sato", "gte": 2}],
        "speaker": "Lt. Sato",
        "lines": [
          {"text": "You listened to me before, so I'll say it. Castell's been in the comms bay every night this week.", "left": "sato"},
          "I copied his last transmission. Here."
        ],
        "effects": [{"giveItem": "relayTap"}]
      },
      {
        "speaker": "Lt. Sato",
        "lines": [
          {"text": "I told you that signal was a trap. Now someone's playing games with our course.", "left": "sato"},
          "Ask Castell where he was at 0300. I'd love to hear his answer."
        ]
      }
    ],
    "talkCastell": {
      "speaker": "Chief Castell",
      "lines": [
        {"text": "Captain. Rough night?", "right": "castell"},
        "If someone's been at the nav log, my money's on the synthetic. Husk can get into everything."
      ],
      "choices": [
        {"label": "Where were you at 0300?", "goto": "castell0300"},
        {"label": "Thanks, Chief."}
      ]
    },
    "castell0300": {
      "lines": [
        {"speaker": "Chief Castell", "text": "Asleep. Ask anyone."},
        "You do ask. Nobody saw him."
      ]
    },
    "talkVoss": [
      {
        "when": [{"flag": "kept.secret"}],
        "speaker": "Dr. Voss",
        "lines": [
          {"text": "Thank you for keeping quiet. I've confirmed it: take that drive core, and it kills everyone within a light-minute.", "left": "voss"},
          "Whoever changed our course knows that. Or doesn't care."
        ]
      },
      {
        "speaker": "Dr. Voss",
        "lines": [
          {"text": "You told them about the warning. Fine. Then they know, and someone changed our course anyway.", "left": "voss"},
          "That isn't ignorance, Captain. That's greed."
        ]
      }
    ],
    "huskStatus": {
      "select": "random",
      "candidates": [
        {"once": true, "speaker": "Husk", "lines": [{"text": "All systems nominal. Except for the crew, who are not.", "right": "husk"}], "effects": [{"add": "husk.reports", "amount": 1}]},
        {"once": true, "speaker": "Husk", "lines": [{"text": "Engine output steady. Someone keeps checking the shuttle's fuel. It is not me.", "right": "husk"}], "effects": [{"add": "husk.reports", "amount": 1}]},
        {"once": true, "speaker": "Husk", "lines": [{"text": "I have traced the command code used on the nav log. It belongs to the security office.", "right": "husk"}], "effects": [{"add": "husk.reports", "amount": 1}, {"giveItem": "accessRecord"}]}
      ]
    },
    "confrontation": {
      "lines": [
        {"text": "You call the senior staff to the bridge. Every eye is on you.", "left": "husk", "right": "castell"},
        {"speaker": "Chief Castell", "text": "Well, Captain? You say someone's planning a mutiny. Who?"}
      ],
      "choices": [
        {"label": "Chief Castell. You changed our course.", "when": [{"flag": "evidence.complete"}], "showDisabled": true, "goto": "endingStopped"},
        {"label": "Husk. You can get into everything.", "when": [{"hasItem": "navLog"}], "showDisabled": true, "effects": [{"set": "mutiny.accused", "value": "Husk"}], "goto": "endingMutiny"},
        {"label": "Dr. Voss. You hid the warning.", "when": [{"any": [{"flag": "kept.secret"}, {"visited": "talkVoss"}]}], "showDisabled": true, "effects": [{"set": "mutiny.accused", "value": "Dr. Voss"}], "goto": "endingMutiny"},
        {"label": "Stand down. We're leaving.", "goto": "endingLeave"}
      ]
    },
    "endingStopped": {
      "lines": [
        {"speaker": "Chief Castell", "text": "You can't prove a thing."},
        {"speaker": "Lt. Sato", "text": "Relay tap. Nav log. Command-code trace. We can.", "left": "sato"},
        {"speaker": "Husk", "text": "Chief Castell, you are relieved of duty. I will escort you.", "left": "husk"},
        {"text": "With ${evidence.count} pieces of evidence on the table, the brig door closes on Castell.", "left": "", "right": ""},
        {"text": "The Centaur turns away from the Ilsk, and leaves it sleeping.", "background": "greyanBridge"},
        {"speaker": "Dr. Voss", "text": "Let it sleep. Some things should stay lost.", "left": "voss"}
      ],
      "effects": [{"post": "ending:stopped"}],
      "end": true
    },
    "endingMutiny": {
      "lines": [
        {"speaker": "Chief Castell", "text": "${mutiny.accused}? Really?"},
        {"text": "While the crew argues, Castell's people take the shuttle bay. By ship's night, the Centaur is his.", "left": "", "right": "castell"},
        {"speaker": "Chief Castell", "text": "Nothing personal, Captain. That drive core is worth more than all of us."},
        {"text": "Weeks later, a Free Trader depot vanishes in a flash bright enough to see from three systems away.", "background": "greyanBridge", "right": ""}
      ],
      "effects": [{"post": "ending:mutiny"}],
      "end": true
    },
    "endingLeave": {
      "lines": [
        "You order the Centaur away from the Ilsk at full burn.",
        {"speaker": "Lt. Sato", "text": "Course laid in. Whatever's on that ship can stay there.", "left": "sato"},
        {"speaker": "Chief Castell", "text": "...Aye, Captain.", "right": "castell"},
        {"text": "You never learn who changed the course. But some nights you catch Castell watching the stars behind you.", "left": "", "right": ""}
      ],
      "effects": [{"post": "ending:leave"}],
      "end": true
    }
  }
}
```

- [ ] **Step 2: Test config**

`examples/visualnovel/bsconfig.test.json`: copy `examples/story/bsconfig.test.json` (PR 1, Task 8), changing `"story/jokes.json"` to `"story/mutiny.json"` and adding `"source/Story/VnSave.bs"` (Task 3 creates it; add the entry then). `package.json`: add `"test": "bsc --project bsconfig.test.json --create-package=false && node ../../scripts/run-tests-ci.js examples/visualnovel/test-build"`.

- [ ] **Step 3: Write the story tests**

`examples/visualnovel/tests/Mutiny.spec.bs`:

```brighterscript
namespace tests
  @suite("visual novel: The Mutiny")
  class MutinyTests extends rooibos.BaseTestSuite

    private story as BGE.Story.StoryData
    private state as BGE.Story.StoryState
    private runner as BGE.Story.DialogueRunner
    private posts as string[]

    protected override function beforeEach()
      m.story = BGE.Story.loadStory("pkg:/story/mutiny.json")
      m.state = new BGE.Story.StoryState(m.story)
      m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
      ' Husk's reports in a fixed order: always the first least-visited one.
      m.runner.random = function(count as integer) as integer
        return 0
      end function
      m.posts = []
    end function

    ' Applies a step's result the way StageScene does: settle the rules, remember posts.
    private sub take(result as BGE.Story.StoryResult)
      m.posts.append(result.posts)
      settled = m.state.settle()
      m.posts.append(settled.posts)
    end sub

    private sub readToChoice()
      while m.runner.isActive() and not m.runner.isChoosing()
        m.take(m.runner.advance())
      end while
    end sub

    private sub choose(label as string)
      m.readToChoice()
      views = m.runner.choices()
      for i = 0 to views.count() - 1
        if views[i].label = label
          m.assertTrue(views[i].enabled, label + " is disabled")
          m.take(m.runner.choose(i))
          return
        end if
      end for
      m.fail("no choice labelled " + label)
    end sub

    private function isEnabled(label as string) as boolean
      m.readToChoice()
      for each view in m.runner.choices()
        if view.label = label
          return view.enabled
        end if
      end for
      return false
    end function

    private sub readToEnd()
      while m.runner.isActive()
        m.take(m.runner.advance())
      end while
    end sub

    @it("validates with no game vocabulary at all")
    function _()
      m.assertNotInvalid(m.story)
      m.assertEqual([], BGE.Story.validateStory(m.story, m.state))
    end function

    @it("keeps every line short enough for the text box")
    function _()
      for each id in m.story.nodes
        entry = m.story.nodes[id]
        nodes = BGE.Story.getCandidates(entry)
        if nodes = invalid
          nodes = [entry]
        end if
        for each node in nodes
          if node.lines <> invalid
            for each line in node.lines
              text = line
              if type(line) = "roAssociativeArray"
                text = line.text
              end if
              m.assertTrue(Len(text) <= 180, id + ": " + text)
            end for
          end if
        end for
      end for
    end function

    @it("reaches the best ending with all three clues (Sato's route)")
    function _()
      m.take(m.runner.start("start"))
      m.choose("Log it and hold position.")
      m.choose("Sato's right. Scan it from here first.")
      m.choose("Take Lt. Sato.")
      m.choose("Agreed. Keep it quiet.")
      m.choose("Talk to Lt. Sato.")
      m.choose("Talk to Chief Castell.")
      m.choose("Thanks, Chief.")
      m.choose("Talk to Dr. Voss.")
      m.choose("Ask Husk for a status report.")
      m.choose("Ask Husk for a status report.")
      m.choose("Ask Husk for a status report.")
      ' Husk has nothing more to report and everyone's been seen: the fallback moves on.
      m.readToChoice()
      m.assertTrue(m.state.flags.isSet("evidence.complete"))
      m.assertEqual(3, m.state.flags.getInt("evidence.count"))
      m.choose("Chief Castell. You changed our course.")
      m.readToEnd()
      m.assertEqual(["ending:stopped"], m.posts)
    end function

    @it("can't accuse Castell without the relay tap (Castell's route)")
    function _()
      m.take(m.runner.start("start"))
      m.choose("Answer the call.")
      m.choose("Castell's right. We go aboard.")
      m.choose("Take Chief Castell.")
      m.choose("No. The crew deserves to know.")
      m.choose("Talk to Lt. Sato.")
      m.choose("Talk to Chief Castell.")
      m.choose("Where were you at 0300?")
      m.choose("Talk to Dr. Voss.")
      m.choose("I've heard enough.")
      m.assertFalse(m.isEnabled("Chief Castell. You changed our course."))
      m.choose("Husk. You can get into everything.")
      m.readToEnd()
      m.assertEqual(["ending:mutiny"], m.posts)
      m.assertEqual("Husk", m.state.flags.get("mutiny.accused"))
    end function

    @it("can always stand down")
    function _()
      m.take(m.runner.start("start"))
      m.choose("Answer the call.")
      m.choose("Sato's right. Scan it from here first.")
      m.choose("Take Lt. Sato.")
      m.choose("Agreed. Keep it quiet.")
      m.choose("Talk to Lt. Sato.")
      m.choose("Talk to Chief Castell.")
      m.choose("Thanks, Chief.")
      m.choose("Talk to Dr. Voss.")
      m.choose("I've heard enough.")
      m.choose("Stand down. We're leaving.")
      m.readToEnd()
      m.assertEqual(["ending:leave"], m.posts)
    end function

    @it("returns to the hub's remaining choices after each conversation")
    function _()
      m.take(m.runner.start("hub"))
      m.choose("Talk to Lt. Sato.")
      m.readToChoice()
      labels = []
      for each view in m.runner.choices()
        labels.push(view.label)
      end for
      m.assertEqual(["Talk to Chief Castell.", "Talk to Dr. Voss.", "Ask Husk for a status report."], labels)
    end function

  end class
end namespace
```

Route trace (Sato): Log (+1 trust.sato), Sato's right (+1 → 2), partner Sato → dataCore + relayTap on the Greyan bridge, navLog at night, accessRecord with the third report (with `random` returning 0, reports come in candidate order). After the third report every `once` talk is used, the report choice fails `lt 3`, and so does "I've heard enough." - nothing labelled is enabled, so the fallback goes to the confrontation. The Castell route reaches "I've heard enough." with `husk.reports` at 0, so it's enabled there.

- [ ] **Step 4: Run**

Run: `cd examples/visualnovel && npm test`
Expected: PASS. A failing route test prints which label was missing or disabled - fix the story data, not the test, unless the test's route is wrong.

- [ ] **Step 5: Commit**

```bash
git add examples/visualnovel
git commit -m "visualnovel: The Mutiny story and playthrough tests (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Save data and endings seen

**Files:**
- Create: `examples/visualnovel/src/source/Story/VnSave.bs`, `examples/visualnovel/tests/VnSave.spec.bs`

**Interfaces:**
- Produces: `interface VnStage { background as string, left as string, right as string }`; `interface VnSave extends roAssociativeArray { version as integer, state as BGE.Story.StorySaveData, position as BGE.Story.RunnerPosition, backlog as roAssociativeArray[], stage as VnStage }`; `const VN_SAVE_VERSION = 1`, `const VN_SAVE_SECTION = "bge-visualnovel"`; `buildVnSave(state, runner, stage as VnStage) as VnSave` (invalid if the runner has no position); `validateVnSave(data as dynamic) as VnSave` (or invalid); `applyVnSave(save as VnSave, state, runner) as boolean` (false → caller starts over); `backlogToSave(backlog as BGE.Story.StoryLineView[]) as roAssociativeArray[]`, `backlogFromSave(data as dynamic) as BGE.Story.StoryLineView[]`; `addEndingSeen(seen as roAssociativeArray, endingId as string) as roAssociativeArray`; `endingsSeenText(seen as roAssociativeArray) as string`.

- [ ] **Step 1: Write the failing spec**

`examples/visualnovel/tests/VnSave.spec.bs`:

```brighterscript
namespace tests
  @suite("visual novel save data")
  class VnSaveTests extends rooibos.BaseTestSuite

    private story as BGE.Story.StoryData
    private state as BGE.Story.StoryState
    private runner as BGE.Story.DialogueRunner

    protected override function beforeEach()
      m.story = BGE.Story.loadStory("pkg:/story/mutiny.json")
      m.state = new BGE.Story.StoryState(m.story)
      m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
    end function

    @it("round-trips state, position, backlog and stage through JSON")
    function _()
      m.runner.start("start")
      m.runner.advance()
      m.state.flags.set("trust.sato", 2)
      save = buildVnSave(m.state, m.runner, {background: "centaurBridge", left: "sato", right: ""})
      loaded = validateVnSave(ParseJson(FormatJson(save)))
      m.assertNotInvalid(loaded)
      state2 = new BGE.Story.StoryState(m.story)
      runner2 = new BGE.Story.DialogueRunner(state2, m.story)
      m.assertTrue(applyVnSave(loaded, state2, runner2))
      m.assertEqual(2, state2.flags.getInt("trust.sato"))
      m.assertEqual(m.runner.currentLine().text, runner2.currentLine().text)
      m.assertEqual(2, runner2.backlog.count())
      m.assertEqual("sato", loaded.stage.left)
    end function

    @it("rejects junk and other versions")
    function _()
      m.assertInvalid(validateVnSave(invalid))
      m.assertInvalid(validateVnSave("junk"))
      m.assertInvalid(validateVnSave({version: 99}))
      m.assertInvalid(validateVnSave({version: 1, state: {}, position: {}, backlog: [], stage: "x"}))
    end function

    @it("reports a save whose node no longer exists, so the game starts over")
    function _()
      save = {version: 1, state: m.state.toSaveData(), position: {stack: [{key: "removedNode", line: 0, phase: "lines"}]}, backlog: [], stage: {background: "", left: "", right: ""}}
      m.assertFalse(applyVnSave(validateVnSave(save), m.state, m.runner))
      m.assertFalse(m.runner.isActive())
    end function

    @it("records endings seen once each and lists them")
    function _()
      seen = addEndingSeen({}, "leave")
      seen = addEndingSeen(seen, "leave")
      seen = addEndingSeen(seen, "stopped")
      m.assertEqual(2, seen.Count())
      m.assertEqual("Endings found: 2 of 3", endingsSeenText(seen))
      m.assertEqual("", endingsSeenText({}))
    end function

  end class
end namespace
```

- [ ] **Step 2: Run** - `npm test`, expected build failure (`buildVnSave` not found).

- [ ] **Step 3: Implement `VnSave.bs`**

```brighterscript
' examples/visualnovel/src/source/Story/VnSave.bs
import "pkg:/source/story/StoryState.bs"
import "pkg:/source/story/DialogueRunner.bs"

const VN_SAVE_VERSION = 1
const VN_SAVE_SECTION = "bge-visualnovel"
const VN_ENDING_COUNT = 3

' What's on screen: background and portrait ids ("" for none).
interface VnStage
  background as string
  left as string
  right as string
end interface

interface VnSave extends roAssociativeArray
  version as integer
  state as BGE.Story.StorySaveData
  position as BGE.Story.RunnerPosition
  ' {text, speaker, isChoice} per entry
  backlog as roAssociativeArray[]
  stage as VnStage
end interface

' @return {VnSave} or invalid if there's nothing to resume (no conversation, or a one-off node)
function buildVnSave(state as BGE.Story.StoryState, runner as BGE.Story.DialogueRunner, stage as VnStage) as VnSave
  position = runner.getPosition()
  if position = invalid
    return invalid
  end if
  return {
    version: VN_SAVE_VERSION,
    state: state.toSaveData(),
    position: position,
    backlog: backlogToSave(runner.backlog),
    stage: {background: stage.background, left: stage.left, right: stage.right}
  }
end function

' @return {VnSave} the save if it has the right shape and version, else invalid
function validateVnSave(data as dynamic) as VnSave
  if type(data) <> "roAssociativeArray"
    return invalid
  end if
  if BGE.Story.valueKind(data.version) <> "integer"
    return invalid
  end if
  if data.version <> VN_SAVE_VERSION
    return invalid
  end if
  if type(data.state) <> "roAssociativeArray" or type(data.position) <> "roAssociativeArray" or type(data.stage) <> "roAssociativeArray"
    return invalid
  end if
  for each key in ["background", "left", "right"]
    if BGE.Story.valueKind(data.stage[key]) <> "string"
      data.stage[key] = ""
    end if
  end for
  return data
end function

' Loads a save into the state and runner.
'
' @return {boolean} false if the saved position doesn't fit the story any more - start over
function applyVnSave(save as VnSave, state as BGE.Story.StoryState, runner as BGE.Story.DialogueRunner) as boolean
  if save = invalid
    return false
  end if
  state.loadSaveData(save.state)
  if not runner.restore(save.position)
    state.reset()
    return false
  end if
  runner.backlog = backlogFromSave(save.backlog)
  return true
end function

function backlogToSave(backlog as BGE.Story.StoryLineView[]) as roAssociativeArray[]
  entries = [] as roAssociativeArray[]
  for each view in backlog
    entries.push({text: view.text, speaker: view.speaker, isChoice: view.isChoice})
  end for
  return entries
end function

function backlogFromSave(data as dynamic) as BGE.Story.StoryLineView[]
  views = [] as BGE.Story.StoryLineView[]
  if type(data) <> "roArray"
    return views
  end if
  for each entry in data
    if type(entry) = "roAssociativeArray"
      if BGE.Story.valueKind(entry.text) = "string" and BGE.Story.valueKind(entry.speaker) = "string"
        views.push({text: entry.text, speaker: entry.speaker, line: {text: entry.text}, isChoice: BGE.Story.isTrue(entry.isChoice)})
      end if
    end if
  end for
  return views
end function

function addEndingSeen(seen as roAssociativeArray, endingId as string) as roAssociativeArray
  result = {}
  if type(seen) = "roAssociativeArray"
    result.Append(seen)
  end if
  result[endingId] = true
  return result
end function

' @return {string} "Endings found: n of 3", or "" before the first
function endingsSeenText(seen as roAssociativeArray) as string
  if type(seen) <> "roAssociativeArray" or seen.Count() = 0
    return ""
  end if
  return "Endings found: " + seen.Count().toStr() + " of " + VN_ENDING_COUNT.toStr()
end function
```

`position = invalid` is safe (an AA or invalid).

- [ ] **Step 4: Run** - `npm test`, expected PASS. (Add `source/Story/VnSave.bs` to `bsconfig.test.json` first.)

- [ ] **Step 5: Commit**

```bash
git add examples/visualnovel
git commit -m "visualnovel: save data and endings seen (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Stage UI pieces

**Files:**
- Create: `src/source/Story/Characters.bs`, `src/source/UI/Backdrop.bs`, `src/source/UI/PortraitCard.bs`, `src/source/UI/TextBox.bs`, `src/source/UI/ChoiceList.bs`, `src/source/UI/BacklogPanel.bs` (all under `examples/visualnovel/`)

**Interfaces:**
- Produces: `portraitForSpeaker(speaker as string) as string`; `backgroundBitmapName(id as string) as string` (`"bg_" + id`); `portraitBitmapName(id as string) as string` (`"portrait_" + id`); `class Backdrop extends BGE.UI.UiWidget` with `setBackground(id as string)`; `class PortraitCard extends BGE.UI.UiWidget` with `new(game, side as string)`, `setPortrait(id as string)`, `portraitId as string`, `lit as boolean`; `class TextBox extends BGE.UI.UiContainer` with `showLine(speaker as string, text as string)`, `isTyping() as boolean`, `finishTyping()`, `clear()`; `class ChoiceList extends BGE.UI.UiContainer` with `show(views as BGE.Story.ChoiceView[], listener as ChoiceListener)`, `clear()`, `focusFirst()`, `hasButtons() as boolean`; `interface ChoiceListener { sub chooseIndex(index as integer) }`; `class BacklogPanel extends BGE.UI.UiContainer` with `new(game, entries as BGE.Story.StoryLineView[])`, `open(parent)`, `close(parent)`, `scroll(delta as integer)`.

All draw in UI-canvas pixels; the UI canvas is 1280x720 here (same as the game canvas). Title-safe box: x 128..1152, y 72..648.

- [ ] **Step 1: `Characters.bs`**

```brighterscript
' Who's who: speaker names in mutiny.json -> portrait ids, and ids -> bitmap names.

function portraitForSpeaker(speaker as string) as string
  map = {"Husk": "husk", "Dr. Voss": "voss", "Chief Castell": "castell", "Lt. Sato": "sato"}
  if map.DoesExist(speaker)
    return map[speaker]
  end if
  return ""
end function

function backgroundBitmapName(id as string) as string
  return "bg_" + id
end function

function portraitBitmapName(id as string) as string
  return "portrait_" + id
end function

' Every background and portrait id, for loading.
function getBackgroundIds() as string[]
  return ["centaurBridge", "greyanBridge", "lab"]
end function

function getPortraitIds() as string[]
  return ["husk", "voss", "castell", "sato"]
end function
```

- [ ] **Step 2: `Backdrop.bs`**

```brighterscript
import "pkg:/source/engine/ui/UiWidget.bs"
import "../Story/Characters.bs"

' The full-screen background. A change fades through black over FADE_SECONDS.
const BACKDROP_FADE_SECONDS = 0.4

class Backdrop extends BGE.UI.UiWidget

  backgroundId as string = ""
  private pendingId as string = ""
  ' -1 = not fading; otherwise seconds into the fade
  private fadeTime as float = -1

  sub setBackground(id as string)
    if id = m.backgroundId or id = m.pendingId
      return
    end if
    if m.backgroundId = ""
      m.backgroundId = id
      return
    end if
    m.pendingId = id
    m.fadeTime = 0
  end sub

  override sub onUpdate(deltaTime as float)
    if m.fadeTime < 0
      return
    end if
    m.fadeTime += deltaTime
    if m.fadeTime >= BACKDROP_FADE_SECONDS / 2 and m.pendingId <> ""
      m.backgroundId = m.pendingId
      m.pendingId = ""
    end if
    if m.fadeTime >= BACKDROP_FADE_SECONDS
      m.fadeTime = -1
    end if
  end sub

  override sub draw(parent = invalid as BGE.UI.UiWidget)
    w = m.canvas.getWidth()
    h = m.canvas.getHeight()
    m.canvas.renderer.drawRectangle(0, 0, w, h, &h000000FF)
    if m.backgroundId <> ""
      art = m.game.getBitmap(backgroundBitmapName(m.backgroundId))
      if art <> invalid
        m.canvas.renderer.drawScaledObject(0, 0, w / art.GetWidth(), h / art.GetHeight(), art)
      end if
    end if
    if m.fadeTime >= 0
      ' 0 -> 1 -> 0 opacity across the fade
      half = BACKDROP_FADE_SECONDS / 2
      amount = 1 - Abs(m.fadeTime - half) / half
      alpha = Int(amount * 255)
      m.canvas.renderer.drawRectangle(0, 0, w, h, alpha)
    end if
  end sub

end class
```

Check `UiWidget` has an overridable `onUpdate(deltaTime)` (UiContainer forwards it per CLAUDE.md's `processUiInput`); if the base signature differs, match it. `&h00000000 + alpha` = `alpha` is black at that alpha.

- [ ] **Step 3: `PortraitCard.bs`**

```brighterscript
import "pkg:/source/engine/ui/UiWidget.bs"
import "../Story/Characters.bs"

const PORTRAIT_W = 360
const PORTRAIT_H = 480
const PORTRAIT_FRAME_RGBA = &hC8D6E5FF
const PORTRAIT_DIM_RGBA = &h00000099

' A framed portrait on the left or right. The speaker's card is lit; the other is dimmed.
class PortraitCard extends BGE.UI.UiWidget

  portraitId as string = ""
  lit as boolean = true

  ' @param {string} side - "left" or "right"
  sub new(game as BGE.Game, side as string)
    super(game)
    m.customPosition = true
    uiW = game.uiCanvas.getWidth()
    m.customY = 72
    if side = "left"
      m.customX = 128
    else
      m.customX = uiW - 128 - PORTRAIT_W
    end if
    m.width = PORTRAIT_W
    m.height = PORTRAIT_H
  end sub

  sub setPortrait(id as string)
    m.portraitId = id
  end sub

  override sub draw(parent = invalid as BGE.UI.UiWidget)
    if m.portraitId = ""
      return
    end if
    art = m.game.getBitmap(portraitBitmapName(m.portraitId))
    if art = invalid
      return
    end if
    x = m.position.x
    y = m.position.y
    m.canvas.renderer.drawRectangle(x - 4, y - 4, PORTRAIT_W + 8, PORTRAIT_H + 8, PORTRAIT_FRAME_RGBA)
    m.canvas.renderer.drawScaledObject(x, y, PORTRAIT_W / art.GetWidth(), PORTRAIT_H / art.GetHeight(), art)
    if not m.lit
      m.canvas.renderer.drawRectangle(x - 4, y - 4, PORTRAIT_W + 8, PORTRAIT_H + 8, PORTRAIT_DIM_RGBA)
    end if
  end sub

end class
```

The cards sit at y 72-552 and the text box starts at y 488 - the box overlaps the bottom of the portraits, which is the usual VN look. If `m.position` isn't set from `customX/customY` until the parent lays out, use `m.customX`/`m.customY` directly.

- [ ] **Step 4: `TextBox.bs`**

```brighterscript
import "pkg:/source/engine/ui/UiContainer.bs"
import "pkg:/source/engine/ui/Label.bs"
import "pkg:/source/engine/ui/TextWrap.bs"

const TEXTBOX_X = 128.0
const TEXTBOX_Y = 488.0
const TEXTBOX_W = 1024.0
const TEXTBOX_H = 160.0
const TEXTBOX_PADDING = 24.0
const TEXTBOX_RGBA = &h0B1726E6
const TEXTBOX_NAME_RGBA = &h5FE0D0FF
' Characters revealed per second.
const TEXTBOX_TYPE_SPEED = 60.0

' The text box along the bottom: a name tab, then the line typed out. finishTyping() shows it all.
class TextBox extends BGE.UI.UiContainer

  private nameLabel as BGE.UI.Label = invalid
  private bodyLabel as BGE.UI.Label = invalid
  ' The line, wrapped once up front so words don't jump between lines as it types.
  private wrappedText as string = ""
  private shown as float = 0

  sub new(game as BGE.Game)
    super(game)
    m.customPosition = true
    m.customX = TEXTBOX_X
    m.customY = TEXTBOX_Y
    m.width = TEXTBOX_W
    m.height = TEXTBOX_H
    m.showBackground = true
    m.backgroundRGBA = TEXTBOX_RGBA
    m.nameLabel = new BGE.UI.Label(game)
    m.nameLabel.customPosition = true
    m.nameLabel.customX = TEXTBOX_PADDING
    m.nameLabel.customY = 12
    m.nameLabel.drawableText.textColor = TEXTBOX_NAME_RGBA
    m.addChild(m.nameLabel)
    m.bodyLabel = new BGE.UI.Label(game)
    m.bodyLabel.customPosition = true
    m.bodyLabel.customX = TEXTBOX_PADDING
    m.bodyLabel.customY = 52
    m.addChild(m.bodyLabel)
  end sub

  sub showLine(speaker as string, text as string)
    m.nameLabel.setText(speaker)
    font = m.game.defaultTheme.font
    m.wrappedText = BGE.UI.wrapText(text, font, TEXTBOX_W - TEXTBOX_PADDING * 2).join(Chr(10))
    m.shown = 0
    m.bodyLabel.setText("")
  end sub

  sub clear()
    m.nameLabel.setText("")
    m.wrappedText = ""
    m.shown = 0
    m.bodyLabel.setText("")
  end sub

  function isTyping() as boolean
    return Int(m.shown) < Len(m.wrappedText)
  end function

  sub finishTyping()
    m.shown = Len(m.wrappedText)
    m.bodyLabel.setText(m.wrappedText)
  end sub

  override sub onUpdate(deltaTime as float)
    super.onUpdate(deltaTime)
    if not m.isTyping()
      return
    end if
    before = Int(m.shown)
    m.shown += TEXTBOX_TYPE_SPEED * deltaTime
    if Int(m.shown) <> before
      m.bodyLabel.setText(Left(m.wrappedText, Int(m.shown)))
    end if
  end sub

end class
```

Check `UiContainer`'s background fields (`showBackground`/`backgroundRGBA` are what the rpg's `DialogueBox` sets) and that `UiContainer.onUpdate` exists to call `super` on; match whatever the engine names them. Four wrapped lines of the 28px default font fit in 160-52 = 108px? No - 28px font is ~36px per line, so three lines fit. The 180-character cap (Task 2) wraps to at most 3 lines at ~70 chars/line in 976px; if a real line wraps to 4 on device, raise `TEXTBOX_H` to 190 and `TEXTBOX_Y` to 458.

- [ ] **Step 5: `ChoiceList.bs`**

```brighterscript
import "pkg:/source/engine/ui/UiContainer.bs"
import "pkg:/source/engine/ui/Button.bs"
import "pkg:/source/story/StoryTypes.bs"

const CHOICE_W = 720.0
const CHOICE_H = 52.0
const CHOICE_GAP = 10.0
' Bottom of the list sits just above the text box.
const CHOICE_BOTTOM = 470.0

interface ChoiceListener
  sub chooseIndex(index as integer)
end interface

' A choice button. Disabled choices are drawn greyed and can't be focused or clicked.
class ChoiceButton extends BGE.UI.Button

  choiceIndex as integer = 0
  listener as ChoiceListener = invalid

  sub new(game as BGE.Game, choiceIndex as integer, enabled as boolean, listener as ChoiceListener)
    super(game)
    m.choiceIndex = choiceIndex
    m.listener = listener
    m.focusable = enabled
    if not enabled
      m.drawableText.textColor = &h6B7785FF
    end if
    m.onActivate = sub(clicked as BGE.UI.Button)
      pressed = clicked as ChoiceButton
      pressed.listener.chooseIndex(pressed.choiceIndex)
    end sub
  end sub

end class

' The choices, stacked and centred above the text box.
class ChoiceList extends BGE.UI.UiContainer

  private buttons as ChoiceButton[] = []

  sub show(views as BGE.Story.ChoiceView[], listener as ChoiceListener)
    m.clear()
    uiW = m.game.uiCanvas.getWidth()
    top = CHOICE_BOTTOM - views.count() * (CHOICE_H + CHOICE_GAP)
    for i = 0 to views.count() - 1
      button = new ChoiceButton(m.game, i, views[i].enabled, listener)
      button.setLabel(views[i].label)
      button.customPosition = true
      button.customX = (uiW - CHOICE_W) / 2
      button.customY = top + i * (CHOICE_H + CHOICE_GAP)
      button.width = CHOICE_W
      button.height = CHOICE_H
      m.addChild(button)
      m.buttons.push(button)
    end for
    m.focusFirst()
  end sub

  sub focusFirst()
    for each button in m.buttons
      if button.focusable
        m.game.focusManager.focusWidget(button)
        return
      end if
    end for
  end sub

  function hasButtons() as boolean
    return m.buttons.count() > 0
  end function

  sub clear()
    for each button in m.buttons
      m.removeChild(button)
    end for
    m.buttons = []
  end sub

end class
```

`ChoiceList` is created with `customPosition = true`, `customX = 0`, `customY = 0` so its children's custom positions are in canvas pixels (check how `UiContainer` offsets children; if children are relative to the container, that's what you want with the container at 0,0). The `listener` field holding the scene is a reference, not an `=` comparison - fine.

- [ ] **Step 6: `BacklogPanel.bs`**

```brighterscript
import "pkg:/source/engine/ui/UiContainer.bs"
import "pkg:/source/engine/ui/Label.bs"
import "pkg:/source/engine/ui/TextWrap.bs"
import "pkg:/source/story/StoryTypes.bs"

const BACKLOG_ROWS = 12
const BACKLOG_RGBA = &h050B12F0
const BACKLOG_CHOICE_RGBA = &h5FE0D0FF

' The history of past lines, newest at the bottom. Up/Down scroll; the scene closes it.
class BacklogPanel extends BGE.UI.UiContainer

  private rows as string[] = []
  ' index of the first row shown
  private first as integer = 0
  private labels as BGE.UI.Label[] = []

  sub new(game as BGE.Game, entries as BGE.Story.StoryLineView[])
    super(game)
    m.customPosition = true
    m.customX = 0
    m.customY = 0
    m.width = game.uiCanvas.getWidth()
    m.height = game.uiCanvas.getHeight()
    m.showBackground = true
    m.backgroundRGBA = BACKLOG_RGBA
    font = game.defaultTheme.font
    for each entry in entries
      text = entry.text
      if entry.isChoice
        text = "> " + text
      else if entry.speaker <> ""
        text = entry.speaker + ": " + text
      end if
      m.rows.append(BGE.UI.wrapText(text, font, 1024))
    end for
    m.first = m.rows.count() - BACKLOG_ROWS
    if m.first < 0
      m.first = 0
    end if
    lineHeight = font.GetOneLineHeight()
    for i = 0 to BACKLOG_ROWS - 1
      label = new BGE.UI.Label(game)
      label.customPosition = true
      label.customX = 128
      label.customY = 72 + i * lineHeight
      m.addChild(label)
      m.labels.push(label)
    end for
    m.refresh()
  end sub

  sub scroll(delta as integer)
    m.first += delta
    maxFirst = m.rows.count() - BACKLOG_ROWS
    if m.first > maxFirst
      m.first = maxFirst
    end if
    if m.first < 0
      m.first = 0
    end if
    m.refresh()
  end sub

  private sub refresh()
    for i = 0 to BACKLOG_ROWS - 1
      index = m.first + i
      if index < m.rows.count()
        m.labels[i].setText(m.rows[index])
      else
        m.labels[i].setText("")
      end if
    end for
  end sub

end class
```

Twelve rows at ~36px each fill y 72-504 within the title-safe area. Choice rows are prefixed `> ` instead of coloured (keeps the panel simple).

- [ ] **Step 7: Validate** - `npm run validate-examples`; fix any API mismatches against the engine (field names noted in the steps above). Expected: no errors in `visualnovel`.

- [ ] **Step 8: Commit**

```bash
git add examples/visualnovel
git commit -m "visualnovel: backdrop, portrait cards, text box, choices and backlog (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: StageScene

**Files:**
- Create: `examples/visualnovel/src/source/Scenes/StageScene.bs`

**Interfaces:**
- Consumes: Tasks 2-4.
- Produces: scene name `"StageScene"`; `changeScene` args `{continue: true}` (resume the save), `{node: "<id>", flags: [...], items: {...}}` (deep link, saving off), or `{}` (new game). Implements `ChoiceListener.chooseIndex`.

- [ ] **Step 1: Write it**

```brighterscript
import "pkg:/source/engine/GameScene.bs"
import "pkg:/source/utils/registry.bs"
import "pkg:/source/story/StoryState.bs"
import "pkg:/source/story/DialogueRunner.bs"
import "pkg:/source/story/StoryLoader.bs"
import "../Story/Characters.bs"
import "../Story/VnSave.bs"
import "../UI/Backdrop.bs"
import "../UI/PortraitCard.bs"
import "../UI/TextBox.bs"
import "../UI/ChoiceList.bs"
import "../UI/BacklogPanel.bs"

' Plays mutiny.json: lines in the text box, choices above it, portraits and backgrounds from each
' line's background/left/right keys. OK reads on, * or Up opens the backlog, Back returns to the title.
class StageScene extends BGE.GameScene

  savingEnabled as boolean = true
  private story as BGE.Story.StoryData = invalid
  private state as BGE.Story.StoryState = invalid
  private runner as BGE.Story.DialogueRunner = invalid
  private stage as VnStage = invalid
  private backdrop as Backdrop = invalid
  private leftCard as PortraitCard = invalid
  private rightCard as PortraitCard = invalid
  private textBox as TextBox = invalid
  private choiceList as ChoiceList = invalid
  private backlog as BacklogPanel = invalid
  ' Frames to wait before showing choices, so the OK that ended the line can't click one.
  private choicesDelay as integer = -1
  private ended as boolean = false

  sub new(game as BGE.Game)
    super(game)
    m.name = "StageScene"
  end sub

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    for each id in getBackgroundIds()
      loader.loadBitmap(backgroundBitmapName(id), "pkg:/images/bg/" + id + ".jpg")
    end for
    for each id in getPortraitIds()
      loader.loadBitmap(portraitBitmapName(id), "pkg:/images/portraits/" + id + ".png")
    end for
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.story = BGE.Story.loadStory("pkg:/story/mutiny.json")
    m.state = new BGE.Story.StoryState(m.story)
    m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
    m.stage = {background: "", left: "", right: ""}
    m.ended = false
    m.backlog = invalid
    m.buildUi()
    m.savingEnabled = args.node = invalid
    resumed = false
    if args.continue = true
      save = validateVnSave(BGE.registryRead(VN_SAVE_SECTION, "save"))
      resumed = applyVnSave(save, m.state, m.runner)
      if resumed
        m.stage = save.stage
      end if
    end if
    if not resumed
      startNode = "start"
      if args.node <> invalid
        startNode = args.node
        for each flagName in args.flags
          m.state.flags.set(flagName, true)
        end for
        for each itemId in args.items
          m.state.inventory.add(itemId)
        end for
        m.state.settle()
      end if
      m.applyResult(m.runner.start(startNode))
    end if
    m.refresh()
  end sub

  override sub onDestroy()
    m.game.gameUi.clearChildren()
  end sub

  private sub buildUi()
    m.backdrop = new Backdrop(m.game)
    m.game.gameUi.addChild(m.backdrop)
    m.leftCard = new PortraitCard(m.game, "left")
    m.game.gameUi.addChild(m.leftCard)
    m.rightCard = new PortraitCard(m.game, "right")
    m.game.gameUi.addChild(m.rightCard)
    m.textBox = new TextBox(m.game)
    m.game.gameUi.addChild(m.textBox)
    m.choiceList = new ChoiceList(m.game)
    m.choiceList.customPosition = true
    m.game.gameUi.addChild(m.choiceList)
  end sub

  override sub onInput(input as BGE.GameInput)
    if not input.press
      return
    end if
    if m.backlog <> invalid
      if input.isButton("up")
        m.backlog.scroll(-1)
      else if input.isButton("down")
        m.backlog.scroll(1)
      else if input.isButton("back") or input.isButton("ok") or input.isButton("options")
        m.closeBacklog()
      end if
      input.consume()
      return
    end if
    reading = m.runner.isActive() and not m.runner.isChoosing()
    if input.isButton("options") or (reading and input.isButton("up"))
      m.openBacklog()
    else if input.isButton("back")
      m.game.changeSceneWithFade("TitleScene", {})
    else if input.isButton("ok") and m.ended
      m.game.changeSceneWithFade("TitleScene", {})
    else if input.isButton("ok") and reading
      if m.textBox.isTyping()
        m.textBox.finishTyping()
      else
        m.applyResult(m.runner.advance())
        m.refresh()
      end if
    end if
  end sub

  override sub onUpdate(deltaTime as float)
    if m.choicesDelay = 0
      m.choicesDelay = -1
      m.choiceList.show(m.runner.choices(), m)
    else if m.choicesDelay > 0
      m.choicesDelay--
    end if
  end sub

  ' Called by a ChoiceButton.
  sub chooseIndex(index as integer)
    m.choiceList.clear()
    m.applyResult(m.runner.choose(index))
    m.refresh()
  end sub

  ' Settles the rules, records endings and autosaves after every step.
  private sub applyResult(result as BGE.Story.StoryResult)
    posts = [] as string[]
    posts.append(result.posts)
    posts.append(m.state.settle().posts)
    for each eventName in posts
      if Left(eventName, 7) = "ending:"
        seen = BGE.registryRead(VN_SAVE_SECTION, "endings", {})
        BGE.registryWrite(VN_SAVE_SECTION, "endings", addEndingSeen(seen, Mid(eventName, 8)))
      end if
    end for
  end sub

  ' Shows whatever the runner is at now: a line, the choices, or the end.
  private sub refresh()
    if not m.runner.isActive()
      m.ended = true
      m.textBox.showLine("", "The End. Press OK to return to the title.")
      m.leftCard.setPortrait("")
      m.rightCard.setPortrait("")
      if m.savingEnabled
        BGE.registryDelete(VN_SAVE_SECTION, "save")
      end if
      return
    end if
    if m.runner.isChoosing()
      m.choicesDelay = 1
    else
      line = m.runner.currentLine()
      m.updateStage(line)
      m.textBox.showLine(line.speaker, line.text)
    end if
    m.save()
  end sub

  private sub updateStage(line as BGE.Story.StoryLineView)
    for each key in ["background", "left", "right"]
      if BGE.Story.valueKind(line.line[key]) = "string"
        m.stage[key] = line.line[key]
      end if
    end for
    m.backdrop.setBackground(m.stage.background)
    m.leftCard.setPortrait(m.stage.left)
    m.rightCard.setPortrait(m.stage.right)
    speaking = portraitForSpeaker(line.speaker)
    m.leftCard.lit = speaking = "" or speaking = m.stage.left
    m.rightCard.lit = speaking = "" or speaking = m.stage.right
  end sub

  private sub save()
    if not m.savingEnabled
      return
    end if
    data = buildVnSave(m.state, m.runner, m.stage)
    if data <> invalid
      BGE.registryWrite(VN_SAVE_SECTION, "save", data)
    end if
  end sub

  private sub openBacklog()
    m.backlog = new BacklogPanel(m.game, m.runner.backlog)
    m.game.gameUi.addChild(m.backlog)
  end sub

  private sub closeBacklog()
    m.game.gameUi.removeChild(m.backlog)
    m.backlog = invalid
    if m.runner.isChoosing()
      m.choiceList.focusFirst()
    end if
  end sub

end class
```

Check before running:
- `BGE.registryDelete` may not exist - `grep -n "sub registry" src/source/utils/registry.bs`. If not, delete the key the way the rpg's `Story.deleteSave()` does (`roRegistrySection.Delete` + `Flush`), in a small `deleteVnSave()` in `VnSave.bs`.
- `args.continue = true` compares a possibly-invalid value - use `BGE.Story.isTrue(args.continue)`. Likewise `args.node = invalid` is fine (string or invalid), but write `m.savingEnabled = BGE.Story.valueKind(args.node) <> "string"` to be safe.
- `onDestroy` signature and whether scene change already clears `gameUi` - check `GameScene.bs`; the persistent `gameUi` survives scene changes (CLAUDE.md), so the scene must remove what it added. Prefer removing the six widgets individually over `clearChildren()` if the debug UI or anything else lives there.
- Back while the backlog is open must not leave the scene: the backlog branch returns before the Back handler, and `input.consume()` keeps it from anything else.
- While choosing, the FocusManager handles Up/Down/OK on the buttons; the scene's `ok` branch only acts when `reading`.

- [ ] **Step 2: Validate** - `npm run validate-examples`. Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add examples/visualnovel
git commit -m "visualnovel: StageScene runs the story with autosave (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Title scene, main and deep links

**Files:**
- Create: `examples/visualnovel/src/source/Scenes/TitleScene.bs`
- Modify: `examples/visualnovel/src/source/main.bs`

- [ ] **Step 1: `TitleScene.bs`**

```brighterscript
import "pkg:/source/engine/GameScene.bs"
import "pkg:/source/engine/ui/Label.bs"
import "pkg:/source/utils/registry.bs"
import "../Story/VnSave.bs"
import "../UI/Backdrop.bs"
import "../UI/ChoiceList.bs"

' The Mutiny's title: Continue (with a save), New Game, the endings found, and credits. Back exits.
class TitleScene extends BGE.GameScene

  private backdrop as Backdrop = invalid
  private menu as ChoiceList = invalid
  private labels as BGE.UI.Label[] = []
  private actions as string[] = []

  sub new(game as BGE.Game)
    super(game)
    m.name = "TitleScene"
  end sub

  override sub onLoad(loader as BGE.AssetLoader, args as roAssociativeArray)
    loader.loadBitmap(backgroundBitmapName("centaurBridge"), "pkg:/images/bg/centaurBridge.jpg")
  end sub

  override sub onCreate(args as roAssociativeArray)
    m.backdrop = new Backdrop(m.game)
    m.backdrop.setBackground("centaurBridge")
    m.game.gameUi.addChild(m.backdrop)
    m.addLabel("THE MUTINY", 128, 120)
    m.addLabel(endingsSeenText(BGE.registryRead(VN_SAVE_SECTION, "endings", {})), 128, 170)
    m.addLabel("Portraits by Justin Nichol. Full credits in images/CREDITS.md.", 128, 610)
    m.actions = []
    views = [] as BGE.Story.ChoiceView[]
    if validateVnSave(BGE.registryRead(VN_SAVE_SECTION, "save")) <> invalid
      m.actions.push("continue")
      views.push({label: "Continue", enabled: true, choice: {}, index: 0})
    end if
    m.actions.push("newGame")
    views.push({label: "New Game", enabled: true, choice: {}, index: 0})
    m.menu = new ChoiceList(m.game)
    m.menu.customPosition = true
    m.game.gameUi.addChild(m.menu)
    m.menu.show(views, m)
  end sub

  private sub addLabel(text as string, x as float, y as float)
    label = new BGE.UI.Label(m.game)
    label.customPosition = true
    label.customX = x
    label.customY = y
    label.setText(text)
    m.game.gameUi.addChild(label)
    m.labels.push(label)
  end sub

  sub chooseIndex(index as integer)
    if m.actions[index] = "continue"
      m.game.changeSceneWithFade("StageScene", {continue: true})
    else
      m.game.changeSceneWithFade("StageScene", {})
    end if
  end sub

  override sub onInput(input as BGE.GameInput)
    if input.press and LCase(input.button) = "back"
      m.game.End()
    end if
  end sub

  override sub onDestroy()
    m.game.gameUi.removeChild(m.backdrop)
    m.game.gameUi.removeChild(m.menu)
    for each label in m.labels
      m.game.gameUi.removeChild(label)
    end for
    m.labels = []
  end sub

end class
```

Replace the credits line's "Full credits in images/CREDITS.md" with the actual authors once Task 1's research is done (one short line per author if they fit; keep it title-safe). Gamepad B aliases to `back`; checking the raw `input.button` keeps B from quitting (as the rpg's `isQuitButton` does). Also make `StageScene`'s Back check use `LCase(input.button) = "back"` for leaving to the title, and accept `input.isButton("back")` (B too) for closing the backlog. `ChoiceList.show` with `m` as listener needs `TitleScene` to satisfy `ChoiceListener` - it does (`chooseIndex`).

- [ ] **Step 2: `main.bs`**

```brighterscript
import "Scenes/TitleScene.bs"
import "Scenes/StageScene.bs"

' The Mutiny. Deep link to a node for testing (saving off), e.g.
'   rokubot launch dev --param node=confrontation --param items=relayTap,navLog,accessRecord
sub Main(args = {} as roAssociativeArray)
  game = new BGE.Game(1280, 720)
  game.fitCanvasToScreen()
  game.enableControllerInput()
  game.controls.bindAxis("move", "1", 0, "Move")
  ' The left stick steps focus through choices, like the d-pad.
  game.focusManager.analogAxisName = "move"
  game.focusManager.analogListRepeatDelay = 0.3

  title = new TitleScene(game)
  game.defineScene(title)
  stage = new StageScene(game)
  game.defineScene(stage)

  if args.node <> invalid
    game.changeSceneWithFade("StageScene", {node: args.node, flags: splitList(args.flags), items: itemCounts(args.items)})
  else
    game.changeSceneWithFade("TitleScene", {})
  end if
  game.play()
end sub

function splitList(text as dynamic) as string[]
  names = [] as string[]
  if BGE.Story.valueKind(text) <> "string"
    return names
  end if
  for each part in (text as string).Split(",")
    if part.Trim() <> ""
      names.push(part.Trim())
    end if
  end for
  return names
end function

' "a,b" -> {a: 1, b: 1}; StageScene adds one of each
function itemCounts(text as dynamic) as roAssociativeArray
  counts = {}
  for each name in splitList(text)
    counts[name] = 1
  end for
  return counts
end function
```

(`main.bs` needs `import "pkg:/source/story/ValueKinds.bs"` for `valueKind`.) In `StageScene.onCreate`, `for each itemId in args.items` iterates the AA's keys - correct for `itemCounts`.

- [ ] **Step 3: Validate and run the tests**

Run: `npm run validate-examples` and `cd examples/visualnovel && npm test`. Expected: clean, PASS.

- [ ] **Step 4: Commit**

```bash
git add examples/visualnovel
git commit -m "visualnovel: title scene, deep links and controller setup (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: On-device verification, docs and the PR

- [ ] **Step 1: Run it**

Follow the `rokubot-examples` skill (sideload `examples/visualnovel`). Check, with a screenshot each:
1. Title: background, "THE MUTINY", New Game focused (no Continue on a fresh install).
2. New Game: the bridge fades in, the first line types out; OK mid-typing completes it; OK again advances; Sato's card appears on the left lit, Castell's on the right dimmed while Sato speaks, then lit for his line.
3. First choice list: two buttons above the text box, the first focused, and the OK that finished the line did not pick one.
4. `*` opens the backlog showing the lines so far; Up/Down scroll; Back closes it and focus returns to the choices; Back did not quit to the title.
5. Make a choice, press Back to the title: Continue now shows; Continue resumes on the same line with the same portraits and background.
6. `--param node=confrontation --param items=relayTap,navLog,accessRecord`: the Castell accusation is enabled (the rule sets `evidence.complete` on start via `settle()`); `--param node=confrontation` alone shows the three accusations greyed out, with focus on "Stand down".
7. Play one ending through to "The End"; OK returns to the title, which shows "Endings found: 1 of 3".
Check text stays inside the title-safe area and lines don't overflow the box (raise `TEXTBOX_H` per Task 4 if they do). Ask the user to play a full route themselves and report anything off.

- [ ] **Step 2: Docs**

- `docs/story.md` (from PR 1): add a short "A visual novel" section pointing at `examples/visualnovel` - line objects with game keys (`background`/`left`/`right`), the hub pattern, `showDisabled` accusations, endings via `post`, and saving the runner position plus backlog.
- `CLAUDE.md`: add `visualnovel` to the examples list at the top, and an `examples/visualnovel` bullet under Conventions (story in `src/story/mutiny.json`; `StageScene` reads `background`/`left`/`right` line keys; endings post `ending:<id>`; saves in `bge-visualnovel`; deep links `node`/`flags`/`items`; its tests run with `cd examples/visualnovel && npm test` and include route playthroughs to each ending).

- [ ] **Step 3: Full gate** - `npm run check:all` and `cd examples/visualnovel && npm test`. Expected: pass.

- [ ] **Step 4: Commit, push, PR**

```bash
git add docs/story.md CLAUDE.md
git commit -m "Docs: the visual novel example (#294)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -u origin feature/issue-294-visual-novel
```

Open the PR with the `pr-voice` skill (closes #294; base `feature/issue-298-bge-story` if PR 1 isn't merged yet, else `main`), ending with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
