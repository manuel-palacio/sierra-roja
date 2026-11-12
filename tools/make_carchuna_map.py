#!/usr/bin/env python3
"""The Fort Carchuna mission's map, as tables. Run to rewrite its land and scene:

    python3 tools/make_carchuna_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png res://scenes/missions/carchuna.tscn

The Granada coast on the night of 23 May 1938. The sea is along the south. The pair land from a
launch on the beach in the south-west; the fort stands on the flat ground in the east, its gate
to the north on the coast road. Three ways in: the gate, the breach in the west wall above the
beach path, and the postern in the east wall, round by the rocks. The officer is in the cells
against the east wall; he has to be brought back to the launch.

The quiet way is on the belly, by the breach: a figure lying down is seen only within six metres,
and no beat comes that close to the shore path, the foot of the south wall inside, or the corner
east of the cells. The one sentry to time is the one in the lane west of the cells: while it is up
the lane the cells themselves hide the door from it. tests/run/carchuna_bot.gd plays it.
"""
from mapgen import ADD, EARTH, MOUND, PATH, ROAD, ROCK, SET, mission, write

BOUNDS = (-55, -45, 110, 90)
PLAIN = 2.5
BEACH = 1.0
HIGH = 2.6  # the fort's wall: nobody sees over it

# kind, mode, points, width, falloff, height, end_height, surface
FEATURES = [
    # Low hills inland, north of the road.
    (MOUND, ADD, [(-30, -40)], 7, 14, 4.5, None, -1),
    (MOUND, ADD, [(40, -40)], 6, 12, 3.5, None, -1),
    # A rocky spur between the beach and the fort, which the beach path goes round.
    (MOUND, ADD, [(-18, 12)], 3, 7, 3.0, None, ROCK),
    # The fort's ground, levelled.
    (MOUND, SET, [(23, 5)], 21, 6, PLAIN, None, EARTH),
    # The coast road in from the north-west to the gate.
    (PATH, SET, [(-110, -30), (-25, -27), (8, -22), (23, -15), (23, -10)], 2.0, 2.5, PLAIN, None, ROAD),
    # The sea, and the beach the launch is drawn up on.
    (PATH, SET, [(-110, 46), (110, 46)], 9, 5, -3.0, None, ROCK),
    (MOUND, SET, [(-40, 27)], 7, 5, BEACH, None, EARTH),
    # The path from the beach along the shore, under the south wall.
    (PATH, SET, [(-34, 26), (-12, 25), (6, 25), (44, 25)], 1.6, 3.0, PLAIN - 0.5, None, EARTH),
]

SPECIALIST_SPAWNS = [(-42, 25), (-40, 27.5)]
# name, route points; the guard starts at the first.
GUARDS = [
    ("Gate", [(20, -13), (27, -13)]),
    ("Road", [(-6, -25), (12, -21)]),
    ("GateInside", [(23, -6), (23, 0)]),
    ("Yard", [(11.5, 2), (22, 2), (22, 8), (11.5, 8)]),
    # The lane between the yard wall and the cells: from its south end the door is in view.
    ("Lane", [(28, 10), (28, -1.5)]),
    ("AboveBeach", [(-14, 19), (-4, 18)]),
    ("EastRocks", [(43, 12), (43, -6)]),
]
# The launch: where they came ashore, and where they have to get back to.
EXTRACTION = (-37, 28)
EXTRACTION_FIRE = False
WALLS = [
    # North, with the gate.
    ([(8, -10), (21, -10)], HIGH), ([(25, -10), (38, -10)], HIGH),
    # East, with the postern.
    ([(38, -10), (38, -1)], HIGH), ([(38, 2), (38, 20)], HIGH),
    # South.
    ([(38, 20), (8, 20)], HIGH),
    # West, with the breach low down near the corner.
    ([(8, 20), (8, 17.2)], HIGH), ([(8, 14), (8, -10)], HIGH),
    # The wall that shuts the cells' court off from the yard.
    ([(26, -2), (26, 12)], HIGH),
    # Sandbags inside the gate and at the breach.
    ([(19.5, -7.5), (21, -7.5)], 1.0, "sandbags"),
    ([(10.5, 12.6), (12.4, 12.6)], 1.0, "sandbags"),
    # Field walls outside: by the road, and above the beach.
    [(-2, -18), (8, -15)],
    [(-30, 19), (-22, 21)],
    [(-6, 20.5), (2, 21)],
]
# A tower in the north-west corner sweeping the road, and one in the south-west over the breach.
# x, z, the searchlight's aim in degrees (0 east, 90 south), its swing and its reach.
TOWERS = [(10.5, -7.5, 250, 60, 17), (10.6, 11.0, 150, 50, 13)]
CARTS = [(17.0, 5.0, 1.2)]
SETTLEMENT = [
    ("launch", -37.5, 30.2, 0.35),
    ("well", 17.0, 13.5, 0.0),
    ("truck", 29.0, -13.5, 1.57),
    ("washing_line", 20.5, 16.0, 0.0),
]
POLE_LINES = [[(-50, -32.5), (-36, -31), (-22, -30), (-8, -27.5), (6, -24.5), (17, -18.5)]]
# name, x, z, rotation (radians), size, roof height, ruin, then optionally: enterable, storeys.
BUILDINGS = [
    ("Cells", 33.5, 6, 0.0, (7, 3, 5), 1.2, False, True),
    ("Barracks", 14.5, -4, 0.0, (9, 3, 5), 1.4, False, False),
    ("Commandant", 31.5, -5, 0.0, (6, 5.4, 5), 1.4, False, False, 2),
    ("SentryBox", 27.2, -12.4, 0.0, (1.6, 2.4, 1.6), 0.6, False, False),
]
CRATES = [
    ("CrateYard1", 24.3, PLAIN, 10.5, 1.4, 1.4),
    ("CrateYard2", 21.5, PLAIN, 12.5, 1.4, 1.4),
]

OLIVES = ["tree:olive"]
INLAND = [(-54, -44), (54, -44), (54, -15), (2, -15), (2, 18), (-54, 18)]
EAST = [(41, -13), (54, -13), (54, 22), (41, 22)]
SHORE = [(-28, 22), (52, 22), (52, 29), (-28, 29)]
# Kept open: the three ways in, the landing and the lying-up places on the way.
CLEAR = [(-42, 25), (-40, 27.5), (-37, 28), (-24, 25.5), (-12, 25), (0, 25), (6, 20), (6, 15.5), (23, -13),
         (23, -18), (40, 0.5), (43, 0.5), (43, 20), (40, 24), (20, 24), (-18, 20), (5.5, 22), (-20, 27.5), (-6, 27.5)]
# name, blocking, models, area, count, seed, spacing, scale range, keep clear, blocker size, max slope
SCATTERS = [
    ("Olives", True, OLIVES, INLAND, 26, 51, 6.0, (0.85, 1.25), 3.5, (0.6, 3.0, 0.6), 25),
    ("EastOlives", True, OLIVES, EAST, 4, 52, 6.0, (0.85, 1.2), 3.5, (0.6, 3.0, 0.6), 25),
    ("TallRocks", True, ["rock_tallA", "rock_tallB"], INLAND, 10, 53, 9.0, (2.0, 2.6), 3.5, (1.4, 2.0, 1.4), 28),
    ("ShoreRocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], SHORE, 9, 54, 7.0, (2.2, 2.8), 3.0, (1.8, 0.9, 1.8), 28),
    ("EastRocks", True, ["rock_largeA", "rock_largeB", "rock_tallA"], EAST, 6, 55, 5.0, (2.0, 2.6), 3.0, (1.6, 1.2, 1.6), 28),
    ("Bushes", False, ["tree:bush"], INLAND, 150, 56, 2.2, (0.7, 1.4), 1.5, None, 34),
    ("Grass", False, ["grass", "grass_large", "grass_leafs", "grass_leafsLarge"], INLAND, 500, 57, 0.8, (2.0, 3.2), 0.9, None, 36),
    ("Broom", False, ["flower_yellowA", "flower_yellowB", "flower_yellowC"], INLAND, 120, 58, 0.8, (1.3, 2.1), 1.0, None, 34),
    ("Pebbles", False, ["rock_smallA", "rock_smallB", "rock_smallC", "stone_smallA", "stone_smallB"], SHORE, 110, 59, 1.0, (1.5, 2.6), 1.0, None, 40),
    ("Deadwood", False, ["stump_round", "log", "stump_old"], INLAND, 12, 60, 6.0, (2.6, 3.4), 2.0, None, 30),
]
# Single props: model, x, ground height, z, scale, turn in radians, and the box that makes it solid.
PLACED = [
    ("barrel", 24.6, PLAIN, 12.0, 4.2, 0.0, (1.0, 1.4, 1.0)),
    ("barrel", 31.0, PLAIN, 14.5, 4.2, 1.0, (1.0, 1.4, 1.0)),
    ("box-large", 16.5, PLAIN, 5.0, 4.4, 0.2, (1.3, 1.1, 2.1)),
    ("box", -34.5, BEACH, 25.6, 4.4, 0.6, (1.1, 1.1, 1.1)),
]
# Lamps: x, z, height of the ground there.
LAMPS = [(26.2, -11.2, PLAIN), (19.0, 10.0, PLAIN), (29.4, 11.4, PLAIN), (19.5, -2.0, PLAIN)]
SEA = (33, 0.35)
OBJECTIVES = [
    {"kind": "rescue", "building": "Cells", "prisoner": (33.5, 5.5), "ground": PLAIN, "hud": "Free the officer",
     "escort": "Bring the officer to the launch", "marker": "Cells"},
]
TEXTS = {
    "title": "Fort Carchuna",
    "objectives": [
        "Get into the fort and open the cells (F at the door).",
        "Bring the officer back to the launch on the beach. He follows whoever freed him and does as they do.",
        "Lose him or either of you and the mission fails.",
    ],
}


if __name__ == "__main__":
    write(mission(
        NAME="carchuna", NODE="Carchuna", SEED=23, NIGHT=True, NAV_FLOOR=0.6, BOUNDS=BOUNDS, PLAIN=PLAIN,
        FEATURES=FEATURES, SPECIALIST_SPAWNS=SPECIALIST_SPAWNS, GUARDS=GUARDS, EXTRACTION=EXTRACTION,
        EXTRACTION_FIRE=EXTRACTION_FIRE, EXTRACTION_GROUND=BEACH, WALLS=WALLS, BUILDINGS=BUILDINGS, CRATES=CRATES,
        SCATTERS=SCATTERS, CLEAR=CLEAR, PLACED=PLACED, LAMPS=LAMPS, POLE_LINES=POLE_LINES, TOWERS=TOWERS,
        CARTS=CARTS, SETTLEMENT=SETTLEMENT, SEA=SEA, OBJECTIVES=OBJECTIVES, TEXTS=TEXTS,
    ))
