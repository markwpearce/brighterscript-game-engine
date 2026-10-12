---
title: Stories and Dialogue
group: Guides
order: 10
---

# Stories and Dialogue

`BGE.Story` is a story layer with no screen of its own. You describe a story as
data (a graph of nodes holding lines, choices and effects), and a
`DialogueRunner` plays it: you ask it what to show, and tell it what the player
did. A `StoryState` holds what the story remembers (flags, items, how often
each node has been visited). Drawing the text, buttons and portraits is up to
your game, so the same story code can sit behind a text box, a visual novel
screen or a talking NPC.

## A first story

A story is a JSON file (or an AA literal in code, which parses to the same
thing). Here is an abridged knock-knock joke from `examples/story`:

```json
{
  "nodes": {
    "start": {
      "speaker": "Husk",
      "lines": ["Captain. May I attempt a joke?"],
      "choices": [
        {"label": "Go on, then.", "goto": "knockKnock"},
        {"label": "Not now, Husk.", "goto": "declined"}
      ]
    },
    "knockKnock": {
      "speaker": "Husk",
      "lines": ["Knock knock."],
      "choices": [{"label": "Who's there?", "goto": "lettuce"}]
    },
    "lettuce": {
      "speaker": "Husk",
      "lines": ["Lettuce.", "Lettuce in, it is cold out here."],
      "goto": "laugh"
    },
    "laugh": {
      "effects": [{"add": "husk.jokes", "amount": 1}],
      "choices": [{"label": "(Laugh)", "goto": "start"}]
    },
    "declined": {"speaker": "Husk", "lines": ["Understood."]}
  }
}
```

And the core of a scene that plays it (the full version, with the buttons, is
[`examples/story`](https://github.com/markwpearce/brighterscript-game-engine/tree/main/examples/story)):

```brighterscript
import "pkg:/source/story/StoryLoader.bs"
import "pkg:/source/story/StoryState.bs"
import "pkg:/source/story/DialogueRunner.bs"

override sub onCreate(args as roAssociativeArray)
  m.story = BGE.Story.loadStory("pkg:/story/jokes.json")
  m.state = new BGE.Story.StoryState(m.story)
  m.runner = new BGE.Story.DialogueRunner(m.state, m.story)
  m.runner.start("start")
  m.show()
end sub

override sub onInput(input as BGE.GameInput)
  if input.press and input.isButton("ok") and not m.runner.isChoosing()
    m.runner.advance()
    m.show()
  end if
end sub

sub show()
  if not m.runner.isActive()
    m.lineLabel.setText("The end.")
  else if m.runner.isChoosing()
    for each view in m.runner.choices()
      ' view.label, view.enabled - make a button, call m.runner.choose(index) when it's pressed
    end for
  else
    line = m.runner.currentLine()
    m.speakerLabel.setText(line.speaker)
    m.lineLabel.setText(line.text)
  end if
end sub
```

That loop is the whole contract. `currentLine()` gives `{text, speaker, line}`
(`text` has `${flags}` filled in, `line` is the raw line if you stored extra
keys on it). `choices()` gives `{label, enabled, choice}` for each button.
`advance()` and `choose(index)` return a `StoryResult` (`{changed, posts,
messages}`) if you want to act on what the story just did.

A button added in the same frame as the OK press that ended the line can pick
up that press as a click, so `examples/story` waits a frame before adding its
choice buttons.

## Nodes

A node has lines to show, then effects, then somewhere to go:

```json
"guardPost": {
  "speaker": "Guard",
  "lines": [
    "Halt.",
    {"text": "Oh, it's you.", "speaker": "Guard (relieved)", "portrait": "guard-smile"}
  ],
  "effects": [{"set": "guard.met", "value": true}],
  "goto": "gateOpens"
}
```

- A line is a string, or an object with `text`, an optional `speaker` and any
  keys you like (`portrait`, `background`...). The engine never reads or strips
  those extra keys; read them from `currentLine().line`.
- `speaker` on the node is the default for its lines.
- Effects run once the player has read the last line, before any choices
  appear. Backing out of a choice list does not undo them, so an effect the
  player should be able to back out of belongs on the choice instead.
- After the effects the node continues with the first of these that applies:
  `choices`, then `call` (play another node, then come back and carry on),
  then `goto` (move on), then `end: true` (finish the whole conversation).
  `end` wins over `goto` if a node has both. A node with none of them has
  run out: the runner returns to whoever called it, or finishes.
- A node with no lines skips straight to that step, so a node can be a pure
  router.
- If a `goto` or `call` names a node that has no passing candidate, the node
  behaves as if it had run out.

`goto`, `call` and `end` are reserved words in BrightScript. In JSON that makes
no difference. In a BrighterScript AA literal write them quoted
(`{"goto": "hub"}`), and read them with brackets (`node["goto"]`).

## Choices

```json
"hub": {
  "lines": ["What now?"],
  "choices": [
    {"label": "Ask about the ship", "once": true, "call": "shipTalk"},
    {"label": "Open the vault", "when": [{"hasItem": "vaultKey"}], "goto": "vault"},
    {"label": "Open the vault (locked)", "when": [{"notItem": "vaultKey"}], "showDisabled": true},
    {"label": "Leave", "goto": "farewell"}
  ]
}
```

- `when` is a list of conditions, all of which must pass. A choice whose
  conditions fail is hidden, or listed with `enabled: false` if it has
  `showDisabled` (draw it greyed and don't let the player pick it).
- `once` hides a choice after it has been taken. It is tracked per choice
  by `id` (or the `label`, if there is no `id`), so give a choice an `id` if two
  choices share a label.
- A choice may have `effects`, then `call` or `goto`. With neither it simply
  means the node has run out.
- `call` from a choice is the **hub pattern**: the called node plays, and
  when it runs out the hub's choices are shown again, re-evaluated (so the
  `once` choice above has gone). A `goto` from a choice does not come back.
- A choice with **no label** is a fallback. It is never shown; it is taken
  automatically when no labelled choice is available. Use it to leave a hub
  once everything has been used up:

```json
{"when": [{"visited": "shipTalk"}], "goto": "confrontation"}
```

Any other key on a choice (`open: "shop"`, say) is yours to read from
`choices()[i].choice` after you call `choose()`.

## Picking a node

A node id can map to one node, or to several candidates:

```json
"bram": [
  {"when": [{"flag": "gate.open"}], "speaker": "Bram", "lines": ["Thanks for your help."]},
  {"speaker": "Bram", "lines": ["The gate is still shut."]}
],
"townsfolk": {
  "select": "random",
  "candidates": [
    {"lines": ["Lovely day."]},
    {"lines": ["Mind the rats."]},
    {"lines": ["Have you seen the market?"], "once": true}
  ]
}
```

- A plain array is `select: "first"`: the first candidate whose `when`
  passes. Put the most specific ones first and an unconditional fallback last.
- `select: "random"` picks among the eligible candidates that have been seen
  the *fewest* times, so a line doesn't repeat until the others have been used.
- A `once` node is skipped after it has been entered once.
- If no candidate is eligible, `start()` leaves `isActive()` false (check it
  before drawing a dialogue box).

Entering a node adds one to its visit count. A candidate also counts under
`<id>#<index>` (`bram#0`), and the group counts as a whole under `bram`.
Conditions read these counts: `{"visited": "bram"}` (entered at least once),
`{"visited": "bram", "gte": 3}` and `{"notVisited": "bram"}`. From code, call
`state.visitCount("bram")`. Because of those keys, node ids can't contain `#`
or `/`.

For a test, make random picks deterministic by setting
`runner.random = function(count as integer) as integer ... end function`.

## Flags and conditions

Flags are a key/value blackboard on the state (`state.flags`) holding strings,
integers, floats and booleans. Conditions test them. All of these go in a
`when` list:

| Condition | Passes when |
|---|---|
| `{flag}` | the flag is set |
| `{flag, eq}` | the flag equals `eq` |
| `{flag, gte}` / `{flag, lt}` | the flag is at least / below the number |
| `{notFlag}` | the flag is not set |
| `{hasItem}` / `{notItem}` | the item is carried / not carried |
| `{visited}` / `{visited, gte}` / `{notVisited}` | the node was entered (at least n times) / never |
| `{any: [conditions]}` | at least one nested condition passes |

From code, `state.evaluate(conditions)` runs a list, so you can use the same
conditions to decide anything else in your game.

Text can show a flag with `${name}`:

```json
"lines": ["That is ${husk.jokes} jokes. I believe I am funny."]
```

A string flag is inserted as is, a number is written as digits, a boolean as
`true` or `false`, and a flag that isn't set as an empty string. If the text
might show a counter before anything has counted, set it to 0 first. A `${`
without a closing `}` is left as written. `state.interpolate(text)` does the
same for text of your own.

## Effects and event rules

Effects change the state. A node's `effects`, a choice's `effects` and a rule's
`effects` all take the same list:

| Effect | Does |
|---|---|
| `{set, value}` | sets a flag |
| `{add, amount}` | adds to a numeric flag (starting from 0) |
| `{giveItem}` / `{takeItem}` | adds / removes one item (`giveItem` runs the item's `onAcquire`) |
| `{post}` | queues a game event name for your game to send on |
| `{message, speaker?}` | queues text for your game to show |

`advance()`, `choose()` and `start()` return a `StoryResult` with `posts` and
`messages`; the runner doesn't send or show them for you:

```brighterscript
result = m.runner.choose(index)
for each name in result.posts
  m.game.postGameEvent(name)
end for
for each message in result.messages
  m.showMessage(message)
end for
```

**Event rules** let the world tell the story something happened. Put them in
the story's `rules`:

```json
"rules": [
  {"event": "enemyKilled", "match": {"enemy": "rat"}, "effects": [{"add": "rats.kills", "amount": 1}]},
  {"event": "storyChanged", "when": [{"flag": "rats.kills", "gte": 4}], "effects": [{"set": "quest.ratsDone", "value": true}]}
]
```

```brighterscript
state.runEvent("enemyKilled", {enemy: "rat"})
state.settle()
```

`runEvent(name, data)` runs every rule for that event whose `match` (each key
must equal the same field of `data`) and `when` pass, in order. `settle()` then
runs the `storyChanged` rules until nothing changes (at most four passes, then
a warning), so a flag one rule sets can trigger another. Call `settle()` after
anything that changed the state: after an `advance()` or `choose()` whose
result has `changed`, and after you change flags or items from code.

## Your own vocabulary

If your game has things the built-ins don't know about, register them on the
state. A handler gets the condition or effect, the state, and a `context` you
chose at registration (BrightScript functions can't capture variables, so this
is how a handler reaches your `Player`). An effect handler returns `true` if
it changed the story state.

```brighterscript
state.registerCondition("coinsGte", function(condition as roAssociativeArray, state as object, player as dynamic) as boolean
  return player.coins >= condition.coinsGte
end function, player)

state.registerEffect("giveCoins", function(effect as roAssociativeArray, state as object, player as dynamic) as boolean
  player.coins += effect.giveCoins
  return effect.giveCoins <> 0
end function, player)
```

```json
{"label": "Buy a drink (5 coins)", "when": [{"coinsGte": 5}], "effects": [{"giveCoins": -5}], "goto": "drink"}
```

A registered key wins over a built-in one with the same name. An unknown key
logs a single `[BGE.Story] warning` and fails the condition (or does nothing,
for an effect). The `examples/rpg` story registers `coinsGte`, `giveCoins`,
`takeCoins`, `heal` and `addMaxHealth` this way.

## Items

Declare the items the story can hand out under `items`. Each has a `max`
(how many can be carried) and optional `onAcquire` effects; add any fields
your own game needs and read them back:

```json
"items": {
  "dataCore": {"max": 1, "name": "Data core", "icon": "core.png"},
  "ration": {"max": 5, "onAcquire": [{"add": "rations.found", "amount": 1}]}
}
```

```brighterscript
state.applyEffects([{giveItem: "ration"}])
print state.inventory.count("ration")
print state.inventory.has("dataCore")
```

`inventory.add()` returns `false` at the maximum, and the `giveItem` effect then
changes nothing. `state.inventory.toAA()` lists what is carried. The extra
fields (`name`, `icon`) stay on the definition in `story.items` for you to read.

## Saving

State and position are saved separately, and both are plain data:

```brighterscript
' Save
BGE.registryWrite("my-game", "save", {
  state: m.state.toSaveData(),
  position: m.runner.getPosition()
})

' Load
saved = BGE.registryRead("my-game", "save", invalid)
if saved <> invalid
  m.state.loadSaveData(saved.state)
  if not m.runner.restore(saved.position)
    m.runner.start("start") ' the story changed since the save; begin again
  end if
end if
```

- `toSaveData()` is `{flags, inventory, visits}`. `loadSaveData()` drops
  anything malformed, so a damaged save gives a fresh state.
- `getPosition()` is `{stack: [{key, line, phase}]}` - where the conversation
  is, including any `call`s still waiting to return. `restore()` returns `false`
  when a node in it no longer exists.
- `runner.backlog` is the list of lines shown so far, oldest first (capped by
  `backlogLimit`, default 100). It isn't part of the position; save it yourself
  if your game shows a history.
- The save has no UI in it, so an autosave on each node is just a call after
  `advance()` or `choose()`.

## Checking a story

A typo in a node id or a condition key only shows up when a player reaches it.
`validateStory` finds them up front: `goto`/`call` targets that don't exist,
condition and effect keys that are neither built in nor registered, groups with
an unknown `select` or no candidates, and nodes with nothing to do. Register
your vocabulary first, then validate in a Rooibos test:

```brighterscript
namespace tests
  @suite("my story")
  class MyStoryTests extends rooibos.BaseTestSuite

    @describe("story data")

    @it("has no errors")
    function _()
      story = BGE.Story.loadStory("pkg:/story/jokes.json")
      state = new BGE.Story.StoryState(story)
      errors = BGE.Story.validateStory(story, state)
      m.assertEmpty(errors)
    end function

  end class
end namespace
```

`loadStory` returns `invalid` (and logs why) if the file can't be read or
parsed. For an AA literal written in code, include an `items: {}` key if it has
no items, or bsc may mistake the literal for `roAssociativeArray`'s `Items()`
method.

To check that each ending can be reached, a spec can drive a
`DialogueRunner` with a fixed list of choices (see
`examples/story/tests/Jokes.spec.bs`). `runner.startNode(node)` plays a
one-off node that isn't in the story, and `runner.cancel()` ends a
conversation at any point.
