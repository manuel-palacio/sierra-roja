#!/usr/bin/env python3
"""The Ebro mission's map, as tables. Run to rewrite its land and scene:

    python3 tools/make_ebro_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png res://scenes/missions/ebro.tscn

The night of 24 to 25 July 1938, on the Nationalist bank of the Ebro. The river runs along the
whole north side. The pair have come over ahead of the boats and start beside their own in the
reeds in the north-west. Three sentries walk the top of the bank, west, middle and east, and all
three have to be dead before the boats set out; behind them a track, an olive grove and the farm
that is the company's post, with a searchlight on the track.

The quiet way is the knife. A figure lying down is seen only within six metres, and the foot of
the bank is farther than that from the sentries' beats. Each beat ends beside a stack of crates:
someone lying past the end of the stack is hidden until the sentry is level with him, as at the
bridge. tests/run/ebro_bot.gd plays it.
"""
from mapgen import ADD, EARTH, MOUND, PATH, ROAD, ROCK, SET, mission, write

BOUNDS = (-55, -45, 110, 90)
PLAIN = 2.0
BANK = 1.4  # the foot of the bank, by the water
BEAT = -20.0  # the sentries walk the top of the bank along this line

# kind, mode, points, width, falloff, height, end_height, surface
FEATURES = [
    # Low hills inland.
    (MOUND, ADD, [(-36, 34)], 7, 14, 4.0, None, -1),
    (MOUND, ADD, [(38, 30)], 6, 13, 3.5, None, -1),
    # The farm's yard.
    (MOUND, SET, [(2, 14)], 13, 5, PLAIN, None, EARTH),
    # The track behind the posts, and the road east.
    (PATH, SET, [(-110, -2), (-30, -4), (38, -4), (110, -2)], 1.8, 2.5, PLAIN, None, ROAD),
    # The river, and the foot of the bank along it.
    (PATH, SET, [(-110, -48), (110, -48)], 11, 5, -3.0, None, ROCK),
    (PATH, SET, [(-110, -27.5), (110, -27.5)], 2.2, 3.0, BANK, None, -1),
]

SPECIALIST_SPAWNS = [(-51, -27), (-49.5, -28.5)]
# name, route points; the guard starts at the first. The first three are the sentries.
GUARDS = [
    ("PostWest", [(-33, BEAT), (-19, BEAT)]),
    ("PostMiddle", [(-3, BEAT), (11, BEAT)]),
    ("PostEast", [(27, BEAT), (41, BEAT)]),
    ("Corporal", [(-30, -4), (38, -4)]),
    ("FarmYard", [(5, 9.5), (12, 12)]),
    ("Gate", [(0.0, 5.5), (0.6, 5.5)]),
    ("Grove", [(-30, 10), (-18, 16)]),
    ("MachineGun", [(47, -1), (47, 7)]),
]
# The landing, where the boats come in: the middle of the bank.
EXTRACTION = (4, -27.5)
EXTRACTION_FIRE = False
HIGH = 2.3
WALLS = [
    # The farm's wall, with its gate to the north.
    ([(-8, 6), (-2, 6)], HIGH), ([(2, 6), (14, 6)], HIGH),
    ([(14, 6), (14, 22)], HIGH), ([(14, 22), (-8, 22)], HIGH), ([(-8, 22), (-8, 6)], HIGH),
    # A sandbagged pit at each post, on the landward side of the beat.
    ([(-28.5, -17.6), (-28.5, -16.2), (-25.5, -16.2), (-25.5, -17.6)], 1.0, "sandbags"),
    ([(2.5, -17.6), (2.5, -16.2), (5.5, -16.2), (5.5, -17.6)], 1.0, "sandbags"),
    ([(32.5, -17.6), (32.5, -16.2), (35.5, -16.2), (35.5, -17.6)], 1.0, "sandbags"),
    # The machine-gun pit on the east road.
    ([(44.6, -3.0), (44.6, 1.0), (46.0, 1.0)], 1.0, "sandbags"),
    # Field walls in the grove.
    [(-36, 4), (-24, 5)],
    [(-16, 9), (-12, 18)],
    [(22, 8), (34, 9)],
]
# The farm's tower, its light sweeping the track. x, z, aim in degrees (0 east, 90 south), swing, reach.
TOWERS = [(-5.5, 8.5, -90, 55, 13)]
CARTS = [(-1.0, 9.0, 0.6)]
SETTLEMENT = [
    ("launch", -52.5, -30.0, 1.25),
    ("well", 10.5, 19.0, 0.0),
    ("truck", -4.5, 1.5, 1.57),
    ("haystack", 20.0, 16.0, 0.0),
]
POLE_LINES = [[(-52, -6.5), (-38, -7), (-24, -7), (-10, -7), (4, -7), (18, -7), (32, -7), (46, -6.5)]]
# name, x, z, rotation (radians), size, roof height, ruin, enterable, storeys.
BUILDINGS = [
    ("Farmhouse", 3, 17, 0.0, (9, 5.4, 6), 1.5, False, False, 2),
    ("Barn", -4, 12, 0.0, (5, 3, 5), 1.3, False, False),
]
# The stack of crates at the east end of each sentry's beat, on the river side of it: x, ground, z,
# length, depth. Someone lying just past its east end is hidden from the sentry coming east.
CRATES = [
    ("StackWest", -21.6, PLAIN, BEAT - 1.35, 3.0, 1.5),
    ("StackMiddle", 8.4, PLAIN, BEAT - 1.35, 3.0, 1.5),
    ("StackEast", 38.4, PLAIN, BEAT - 1.35, 3.0, 1.5),
]

OLIVES = ["tree:olive"]
INLAND = [(-54, 2), (54, 2), (54, 44), (-54, 44)]
BANKSIDE = [(-54, -31), (54, -31), (54, -22.5), (-54, -22.5)]
BLUFF = [(-54, -18), (54, -18), (54, -7), (-54, -7)]
# Kept open: the foot of the bank, the lying-up places and the landing.
CLEAR = [(-51, -27), (-49.5, -28.5), (4, -27.5), (-19.3, -21.5), (10.7, -21.5), (40.7, -21.5), (-18, -27.5),
         (12, -27.5), (42, -27.5), (-35, -27.5), (27, -27.5), (0, 5.5)]
# name, blocking, models, area, count, seed, spacing, scale range, keep clear, blocker size, max slope
SCATTERS = [
    ("Olives", True, OLIVES, INLAND, 30, 81, 6.0, (0.85, 1.25), 3.5, (0.6, 3.0, 0.6), 25),
    ("Rocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], INLAND, 10, 82, 8.0, (2.0, 2.6), 3.5, (1.8, 0.9, 1.8), 28),
    # Reeds along the water: nothing to hide behind, only to look at.
    ("Reeds", False, ["tree:bush"], BANKSIDE, 150, 83, 1.2, (0.6, 1.1), 0.0, None, 40),
    ("ReedGrass", False, ["grass_large", "grass_leafsLarge"], BANKSIDE, 320, 84, 0.6, (2.2, 3.4), 0.0, None, 40),
    ("Bushes", False, ["tree:bush"], BLUFF, 40, 85, 2.4, (0.7, 1.3), 1.5, None, 34),
    ("Grass", False, ["grass", "grass_large", "grass_leafs"], INLAND, 420, 86, 0.8, (2.0, 3.2), 0.9, None, 36),
    ("Broom", False, ["flower_yellowA", "flower_yellowB", "flower_yellowC"], INLAND, 110, 87, 0.9, (1.3, 2.1), 1.0, None, 34),
]
# Single props: model, x, ground height, z, scale, turn in radians, and the box that makes it solid.
PLACED = [
    # The post the first line is made fast to, at the landing.
    ("signpost", 6.2, BANK, -28.6, 4.0, 0.4, None),
    ("barrel", -27.0, PLAIN, -15.2, 4.2, 0.0, (1.0, 1.4, 1.0)),
    ("barrel", 4.0, PLAIN, -15.2, 4.2, 0.6, (1.0, 1.4, 1.0)),
    ("box", 34.0, PLAIN, -15.2, 4.4, 0.3, (1.1, 1.1, 1.1)),
    ("box-large", 45.4, PLAIN, 3.2, 4.4, 1.2, (1.3, 1.1, 2.1)),
]
# A lamp at each post and at the farm's gate: x, z, height of the ground there.
LAMPS = [(-27.0, -18.4, PLAIN), (4.0, -18.4, PLAIN), (34.0, -18.4, PLAIN), (-1.4, 4.6, PLAIN)]
WATER = ("north", -31.5, 0.35)
CROSSING = {"after": "Silence", "seconds": 25.0,
            "boats": [((-6, -90), (-3, -33.4)), ((1, -94), (2, -33.4)), ((8, -91), (7, -33.4)), ((15, -96), (12, -33.4))]}
OBJECTIVES = [
    {"kind": "silence", "sentries": ["PostWest", "PostMiddle", "PostEast"], "seconds": 300,
     "hud": "Silence the sentries", "marker": "Sentry", "done": "The bank is quiet: the boats are crossing"},
]
TEXTS = {
    "title": "The crossing",
    "objectives": [
        "Silence the three sentries on the bank before the boats set out. The clock is at the top of the screen.",
        "Not a shot, not a shout: an alarm anywhere before the last of them is down and the boats come in under fire.",
        "Then both of you to the landing. Lose either one and the mission fails.",
    ],
}


if __name__ == "__main__":
    write(mission(
        NAME="ebro", NODE="Ebro", SEED=25, NIGHT=True, NAV_FLOOR=0.6, BOUNDS=BOUNDS, PLAIN=PLAIN,
        FEATURES=FEATURES, SPECIALIST_SPAWNS=SPECIALIST_SPAWNS, GUARDS=GUARDS, EXTRACTION=EXTRACTION,
        EXTRACTION_FIRE=EXTRACTION_FIRE, EXTRACTION_GROUND=BANK, WALLS=WALLS, BUILDINGS=BUILDINGS, CRATES=CRATES,
        SCATTERS=SCATTERS, CLEAR=CLEAR, PLACED=PLACED, LAMPS=LAMPS, POLE_LINES=POLE_LINES, TOWERS=TOWERS,
        CARTS=CARTS, SETTLEMENT=SETTLEMENT, WATER=WATER, CROSSING=CROSSING, OBJECTIVES=OBJECTIVES, TEXTS=TEXTS,
    ))
