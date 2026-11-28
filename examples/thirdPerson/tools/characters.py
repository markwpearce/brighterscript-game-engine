# The characters tools/render-character.py (at the repo root) renders from the Flare Blender
# sources (see CREDITS.md), converted by convert-flare.py. Pass this file as its --config;
# inbetweens() comes from the script. Keys are described at the top of render-character.py.

# Grey-green skin (renders at about #9AAE93; the lighting brightens it) in place of the source's orange, with dark hair
ORC_COLOURS = {"Material.skin": (0.18, 0.22, 0.146), "Material.hair": (0.06, 0.04, 0.025)}

# The melee: 8 frames drawing back to the top of the swing (13 to 14.5), so even a long wind-up plays
# at 12 fps or more before holding there, then 4 for the strike (to 16)
MONSTER_ATTACK = inbetweens(13, 14.5, 8) + inbetweens(14.5, 16, 5)[1:]  # noqa: F821 (provided by render-character.py)

# The goblins' jab: 8 frames drawing the weapon back (21 to 22), then 4 for the thrust (to 24)
GOBLIN_ATTACK = inbetweens(21, 22, 8) + inbetweens(22, 24, 5)[1:]  # noqa: F821

CHARACTERS = {
    # steel_armor.blend
    "knight": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", inbetweens(13, 16, 9)),  # noqa: F821
            # raising the shield, a hit and the fall, with in-betweens so each plays at 12 fps or more
            ("block", inbetweens(17, 18, 3)),  # noqa: F821
            ("hit", inbetweens(19, 20, 3)),  # noqa: F821
            ("die", inbetweens(21, 24, 7)),  # noqa: F821
            # keyed by tools/knight-moves.py: a roll, a hop back, and a side-step to the right
            ("roll", list(range(41, 49))),
            ("backstep", [49, 50, 51, 52]),
            ("strafe", list(range(53, 61))),
        ],
        "parts": {"MaleHead1": "male_head1.blend", "Longsword": "longsword.blend", "HeavyShield": "shield.blend"},
        "size": 2.6,
    },
    # skeleton_0.blend
    "skeleton": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", MONSTER_ATTACK),
            ("block", [17]),
            ("hit", [19]),
            ("die", [21, 23, 25, 27]),
        ],
        "hide": ["KingdomCrossbow"],
        "size": 3.6,
    },
    # orc_flare_0.blend, layer 2: hand axe, no armour
    "orc": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", MONSTER_ATTACK),
            ("hit", [17]),
            ("die", [19, 21, 23, 24]),
        ],
        "layers": ["1", "2"],
        "colours": ORC_COLOURS,
        "size": 3.6,
    },
    # orc_flare_0.blend, layer 5: armour, shield and a bigger axe
    # Its overhead swing makes its frames big, so it keeps fewer idle and die frames to save texture memory
    "orc-heavy": {
        "animations": [
            ("idle", [1, 3]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", MONSTER_ATTACK),
            ("block", [30]),
            ("hit", [17]),
            ("die", [20, 24]),
        ],
        "layers": ["1", "5"],
        "colours": ORC_COLOURS,
        "size": 3.6,
    },
    # The forest's creatures. goblin.blend and knife_hobgoblin.blend share Flare's goblin rig:
    # stance 1-4, a hop 5-12, run 13-20, a jab 21-24 (drawn back at 22), a throw 25-28, hit 29-30,
    # die 37-40 and a fall dropping the weapon 41-48
    # goblin.blend: spear; its bright green skin darkened
    "goblin": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", list(range(13, 21))),
            ("attack", GOBLIN_ATTACK),
            ("hit", [29]),
            ("die", [37, 38, 39, 40]),
        ],
        "colours": {"Skin": (0.15, 0.26, 0.08)},
        "size": 3.6,
    },
    # knife_hobgoblin.blend: knife; its yellow skin turned a ruddy brown
    "hobgoblin": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", list(range(13, 21))),
            ("attack", GOBLIN_ATTACK),
            ("hit", [29]),
            ("die", [37, 38, 39, 40]),
        ],
        "colours": {"Skin": (0.28, 0.13, 0.06)},
        "size": 3.6,
    },
    # Werewolf.blend: its "Action" has stance 0-8, run 9-16, a rearing swipe 17-20 (reared up at
    # 18), a recoil 21-23 and die 24-28. Unarmed and near enough symmetric to render --mirror
    "werewolf": {
        "animations": [
            ("idle", [0, 2, 4, 6]),
            ("run", list(range(9, 17))),
            ("attack", inbetweens(17, 18, 8) + inbetweens(18, 20, 5)[1:]),  # noqa: F821
            ("hit", [22]),
            ("die", [24, 25, 26, 28]),
        ],
        "rig": "MaleArm",
        # Its pale belly and legs otherwise burn out white
        "colours": {"White Fur": (0.45, 0.43, 0.4)},
        "size": 4.5,
    },
    # Townsfolk, from the Flare NPC sources (art/npcs/), idle only: four frames across each idle loop
    # MalePeasant.blend: the hoe is the short one on layer 12; HumanMale.001 duplicates HumanMale
    "peasant_m": {
        "animations": [("idle", inbetweens(0.39, 16.76, 5)[:4])],  # noqa: F821
        "hide": ["HumanMale.001", "capelli1.001", "Plane.002"],
        "platform": "RenderPlatform.002",
        "lamp": "Lamp.001",
        "shadow": "ShadowPlane.001",
        "size": 2.4,
    },
    # FemalePeasant4.blend: green dress and broom
    "peasant_f": {"animations": [("idle", [0, 1.5, 3, 4.5])], "size": 2.4},
    # NobleWoman1.blend: red dress and fan
    "noblewoman": {"animations": [("idle", [0, 1.5, 3, 4.5])], "size": 2.4},
    # Nobleman.blend: the blue suit on layer 11 (layer 4 is a green one)
    "nobleman": {
        "animations": [("idle", [1, 2.5, 4, 5.5])],
        "hide": ["Plane.003"],
        "size": 2.4,
    },
    "old_man": {"animations": [("idle", [0, 1.25, 2.5, 3.75])], "size": 2.4},
    # LuxPriestNPC.blend turns its camera and lights round the character, so it goes on the turntable
    "priest": {
        "animations": [("idle", [0, 1.5, 3, 4.5])],
        "turntable": ["MaleArm", "HumanMale.001"],
        "hide": ["Sun.001", "Sun.002"],
        "lamp": "Sun",
        "shadow": "ShadowPlane",
        "size": 2.6,
    },
    # Pig.blend keeps each animation in its own action. Its Walk and Run are for another rig (they
    # crumple it); Flare's walk is Armature.001Action, a 10-frame cycle
    "pig": {
        "animations": [
            ("idle", [0, 37.5, 75, 112.5], "Idle"),
            ("walk", inbetweens(0, 10, 9)[:8], "Armature.001Action"),  # noqa: F821
        ],
        "size": 2.4,
    },
}
