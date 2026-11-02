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
}
