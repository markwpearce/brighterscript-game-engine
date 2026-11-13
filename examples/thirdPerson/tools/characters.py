# The characters tools/render-character.py (at the repo root) renders from the Flare Blender
# sources (see CREDITS.md), converted by convert-flare.py. Pass this file as its --config;
# inbetweens() comes from the script. Keys are described at the top of render-character.py.

# Grey-green skin (renders at about #9AAE93; the lighting brightens it) in place of the source's orange, with dark hair
ORC_COLOURS = {"Material.skin": (0.18, 0.22, 0.146), "Material.hair": (0.06, 0.04, 0.025)}

# The melee's four keys (13-16) with four in-betweens
MONSTER_ATTACK = inbetweens(13, 16, 8)  # noqa: F821 (provided by render-character.py)

CHARACTERS = {
    # steel_armor.blend
    "knight": {
        "animations": [
            ("idle", [1, 2, 3, 4]),
            ("run", [5, 6, 7, 8, 9, 10, 11, 12]),
            ("attack", inbetweens(13, 16, 9)),  # noqa: F821
            ("block", [17, 18]),
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
