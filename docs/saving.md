---
title: Saving
group: Guides
order: 15
---

# Saving

Saves live in the device registry. The engine gives you a few layers; what goes in a save
stays your game's business.

## Registry helpers

`BGE.registryWrite(section, key, value)` writes any JSON-friendly value,
`BGE.registryRead(section, key, default)` reads it back (the default isn't written),
`BGE.registryExists()` and `BGE.registryDelete()` do what they say.

## SaveSlot

`BGE.SaveSlot(section, key, version)` is one versioned save:

```brighterscript
m.slot = new BGE.SaveSlot("my-game", "save", 2)
m.slot.write({scene: "Town", coins: 40})

save = m.slot.read(validateSave) ' invalid if missing, unreadable or rejected
menu.addItem("continue", "Continue", m.slot.exists(validateSave))
m.slot.delete()
```

- `read(validate)` returns the data only if it was written with this `version` (or an older
  one `migrate()` upgrades) and passes `validate`, a `function(data) as dynamic` that returns
  the data (cleaned up if need be) or invalid.
- Subclass and override `migrate(fromVersion, data)` to upgrade old saves. **The default drops
  them**, so override it before you bump `version` or players lose their progress (a dropped
  save logs a warning). An upgraded save is written back, so it's migrated once. Data written
  before you used `SaveSlot` arrives with `fromVersion` set to its own `version` field (0 if it
  has none).
- `write()` returns false if the data can't be saved: something `FormatJson()` can't write
  (a function, an roBitmap...) or a full registry.
- `enabled = false` stops it reading and writing, e.g. while a deep link is testing a level.

## SaveProfile

`BGE.SaveProfile(section)` holds what should outlast any one save or new game: settings,
unlocks, endings found, high scores. Each change is written straight away, so don't call
`set()` every frame.

```brighterscript
m.profile = new BGE.SaveProfile("my-game")
m.profile.set("musicVolume", 70)
m.profile.addToSet("endings", "escape") ' true the first time
if m.profile.recordHighScore("arcade", score)
  ' a new best
end if
best = m.profile.getHighScore("arcade")
```

For an arcade game, `BGE.GameSession.persistHighScore(section)` does this for you at every game
over (see [Game Sessions](/game-session)).
