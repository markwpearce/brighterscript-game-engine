---
title: Game Sessions
group: Guides
order: 17
---

# Game sessions

`BGE.GameSession` keeps an arcade game's score, lives and state: ready, playing, paused,
over or levelComplete. It's an entity you add if you want it. Your game keeps its own rules
and screens, and calls the session when its own events happen.

```brighterscript
session = new BGE.GameSession(game, {lives: 3, prompts: true, startButton: "ok"})
session.persistHighScore("my-game")
game.addEntity(session)

' When something scores:
session.addScore(10)

' When the player's hit:
if session.loseLife()
  ' that was the last life: the session is over and the high score is saved
end if

' Gate gameplay on the state:
if session.isPlaying()
  ' spawn enemies...
end if
```

## State

`start()` moves from ready (or over, as a new game with a fresh score and lives) to
playing. From levelComplete it keeps the score and lives, so the next level carries them on.
`pause()`/`resume()`, `gameOver()`, `completeLevel()` and `reset()` (back to ready)
do the rest; `setState()` moves anywhere, e.g. back to ready after a lost ball. `isPlaying()`
and `hasEnded()` (over or levelComplete) cover the usual checks.

`pause()` only changes the session's state. Pausing the game itself stays with
`BGE.PauseMenu` or `game.pushModal()`.

Each change posts a game event, `sessionStateChanged` by default, with
`{state, previousState}`:

```brighterscript
override sub onGameEvent(eventName as string, data as roAssociativeArray)
  if eventName = "sessionStateChanged" and data.state = BGE.GameSessionState.over
    m.addExplosion(m.player)
  end if
end sub
```

Set `stateEventName` to rename it, or to `""` to post nothing.

## Score and lives

`addScore(points)` and `loseLife(count)` are ignored once the game's over or the level's
complete, so a stray hit after the end doesn't count. Lives are optional: leave `lives` at 0
and `loseLife()` does nothing, so you end the game with `gameOver()` instead. Set `score` or
`lives` directly to carry them into the next level, e.g. from scene args.

## Prompts and input

Both are off unless you turn them on:

- `prompts: true` shows a centered `BGE.UI.Label` in the current scene's UI: "Press OK To
  Play" while ready, "Game Over!" and "Press OK To Play" once it's over. Change the text with
  `readyPrompt`, `overPrompt`, `pausedPrompt` and `levelCompletePrompt`, restyle
  `promptLabel`, or override `getPromptText(state)`.
- `startButton: "ok"` (a remote button) or `startAction: "fire"` (a `ControlMap` action)
  calls `start()` from ready or over.

Leave them off and draw your own screens. Read `session.state`, or use the hooks below.

## High score

`persistHighScore(section, table = "highScore")` reads the best score into `highScore` and
saves a new best at every game over. It keeps it in a `BGE.SaveProfile` (see
[Saving](/saving)), so it shares that profile with your other settings. Call
`recordHighScore()` to save at other times, e.g. at the end of a level.

## Subclassing

Override `onStateChanged(previousState, newState)`, `onGameOver()` or `onLevelComplete()`.
A HUD entity can be the session itself:

```brighterscript
class GameStateManager extends BGE.GameSession

  sub new(game as BGE.Game)
    super(game, {lives: 3})
    m.name = "GameStateManager"
  end sub

  override sub onGameOver()
    m.showEndPanel("Game Over - Score: " + m.score.toStr())
  end sub

end class
```

If you override `onCreate()` or `onUpdate()`, call `super`: the session puts its prompt in the
scene's UI there.

The snake, pong, asteroids, breakout and platformer examples each use a session in their own
way.
