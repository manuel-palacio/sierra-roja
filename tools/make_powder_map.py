#!/usr/bin/env python3
"""The Teruel mission's map (the depot, once the powder store), as tables. Run to rewrite its land and scene:

    python3 tools/make_powder_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png res://scenes/missions/powder_store.tscn

December 1937, outside Teruel, under snow and a lid of cloud. A walled farm on a plain between
two hills, used as a supply depot. The squad comes up
from the south-west, gets in by the south gate, the east gate or the gap in the west wall, blows
the stack in the yard and leaves by the road east.
"""
from mapgen import ADD, EARTH, MOUND, PATH, ROAD, SET, mission, write

BOUNDS = (-50, -40, 100, 80)
PLAIN = -1.0
HIGH = 2.3  # a wall nobody sees over

FEATURES = [
    (MOUND, ADD, [(30, -28)], 6, 14, 5.0, None, -1),
    (MOUND, ADD, [(-38, -20)], 6, 14, 4.0, None, -1),
    (PATH, ADD, [(-30, 27), (-10, 25), (12, 28)], 3, 6, 1.6, None, -1),
    # The yard, and the camp where the squad is met.
    (MOUND, SET, [(5, 0)], 20, 6, PLAIN, None, EARTH),
    (MOUND, SET, [(44, 12)], 4, 3, PLAIN, None, EARTH),
    # The road in from the west to the south gate, and out of the east gate.
    (PATH, SET, [(-110, 8), (-30, 10), (-8, 19), (5, 19), (5, 13)], 2.0, 2.5, PLAIN, None, ROAD),
    (PATH, SET, [(20, 0), (40, 3), (110, 5)], 2.0, 2.5, PLAIN, None, ROAD),
]

SPECIALIST_SPAWNS = [(-44, 32), (-44, 35)]
GUARDS = [
    ("Yard", [(2.5, 4.5), (11.5, 4.5), (11.5, -3), (2.5, -3)]),
    ("SouthWall", [(-8, 15.5), (17, 15.5)]),
    ("EastWall", [(23.5, -10), (23.5, 9)]),
    ("NorthWall", [(17, -15.5), (-8, -15.5)]),
    ("Road", [(-40, 9.5), (-16, 13)]),
    ("Inside", [(-6, 9), (-6, -1)]),
]
EXTRACTION = (44, 12)
# Just south of the stack: the marker has to be on ground a unit can reach.
TARGET = (6, PLAIN, 1.7)
# x, ground, z, size along x, height, size along z
TARGET_STACK = [
    (5.2, PLAIN, -1.4, 1.6, 1.4, 1.2),
    (6.9, PLAIN, -1.2, 1.4, 1.2, 1.4),
    (6.0, PLAIN, 0.1, 1.8, 1.0, 1.2),
    (6.0, PLAIN + 1.3, -1.3, 1.2, 1.0, 1.0),
]
WALLS = [
    # The farm's wall: south (with the gate), east (with the gate), north, west (with the gap).
    ([(-10, 12), (3, 12)], HIGH), ([(7, 12), (20, 12)], HIGH),
    ([(20, 12), (20, 2)], HIGH), ([(20, -2), (20, -12)], HIGH),
    ([(20, -12), (-10, -12)], HIGH),
    ([(-10, -12), (-10, -9)], HIGH), ([(-10, -6), (-10, 12)], HIGH),
    # Field walls outside, low enough to see over and to lie behind.
    [(-24, 19), (-15, 23)],
    [(12, 21), (23, 20)],
    [(-19, -18), (-13, -23)],
    [(27, -9), (31, 3)],
    # Sandbags by the south gate and inside the east one.
    ([(8.6, 13.0), (8.6, 14.2), (9.8, 14.2)], 1.0, "sandbags"),
    ([(17.6, 3.2), (18.8, 3.2)], 1.0, "sandbags"),
]
# A watchtower in the north-east corner of the yard, and carts in the yard and on the road.
TOWERS = [(17.0, 8.5, 195, 50, 12)]
CARTS = [(-2.5, 8.5, 1.3), (-20.0, 14.5, 0.3)]
# What makes the place look lived in: kind, x, z, turn in radians.
SETTLEMENT = [
    ("truck", 0.5, 23.0, 1.57),
    ("well", -16.5, -4.0, 0.0),
    ("washing_line", -3.0, -2.3, 0.0),
    ("haystack", 16.0, 26.5, 0.0),
    ("haystack", 20.5, 29.5, 0.0),
]
# The telegraph line in along the road from the west.
POLE_LINES = [[(-48, 5.5), (-34, 6.5), (-21, 9.5), (-9, 15.5)]]
BUILDINGS = [
    ("Barracks", -3, -6.5, 0.0, (9, 3, 5), 1.4, False, True),
    ("Shed", 14.5, -7.5, 0.0, (6, 2.8, 5), 1.2, False, True),
    ("Gatehouse", 10.5, 8.6, 0.0, (4, 2.8, 3.4), 1.2, False),
    ("OldBarn", -30, -6, 0.3, (7, 2.4, 6), 0.0, True),
]
CRATES = [
    ("CrateYard1", 0.0, PLAIN, 6.5, 1.4, 1.4),
    ("CrateYard2", 14.5, PLAIN, 2.0, 1.4, 1.4),
    ("CrateYard3", -8.4, PLAIN, 3.0, 1.4, 1.4),
    ("CrateRoad", 9.5, PLAIN, 19.5, 1.4, 1.4),
]

# Winter: pines under snow, and bare birches where the olives stood (the same places: what
# blocks feet and eyes has not moved since this was the powder store).
PINES = ["tree:snow_pine"]
OAKS = ["tree:birch"]
WHOLE_MAP = [(-49, -39), (49, -39), (49, 39), (-49, 39)]
NORTH = [(-49, -39), (49, -39), (49, -16), (-49, -16)]
SOUTH = [(-49, 15), (49, 15), (49, 39), (-49, 39)]
# Kept open: the ways in, the start and the camp.
CLEAR = [(5, 16), (5, 19), (24, 0), (-13, -7.5), (44, 12), (-44, 32), (-44, 35), (30, 2), (-20, 28)]
SCATTERS = [
    ("NorthPines", True, PINES, NORTH, 30, 31, 5.0, (0.85, 1.2), 3.0, (0.5, 3.0, 0.5), 32),
    ("Olives", True, OAKS, SOUTH, 16, 32, 6.5, (0.85, 1.2), 3.5, (0.6, 3.0, 0.6), 25),
    ("TallRocks", True, ["rock_tallA", "rock_tallB"], WHOLE_MAP, 10, 33, 9.0, (2.0, 2.6), 3.5, (1.4, 2.0, 1.4), 28),
    ("FlatRocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], WHOLE_MAP, 16, 34, 7.0, (2.2, 2.8), 3.5, (1.8, 0.9, 1.8), 28),
    ("Bushes", False, ["tree:bare_bush"], WHOLE_MAP, 110, 35, 2.2, (0.7, 1.4), 1.5, None, 34),
    ("Deadwood", False, ["stump_round", "log_stack", "log", "stump_old"], WHOLE_MAP, 18, 40, 5.0, (2.6, 3.4), 2.0, None, 30),
    ("Pebbles", False, ["rock_smallA", "rock_smallB", "rock_smallC", "stone_smallA", "stone_smallB"], WHOLE_MAP, 140, 41, 1.2, (1.5, 2.6), 1.0, None, 40),
]
PLACED = [
    ("barrel", 16.2, PLAIN, -3.6, 4.2, 0.0, (1.0, 1.4, 1.0)),
    ("barrel", 17.4, PLAIN, -3.4, 4.2, 1.0, (1.0, 1.4, 1.0)),
    ("box-large", -8.0, PLAIN, 10.2, 4.4, 0.2, (1.3, 1.1, 2.1)),
    ("box", 12.6, PLAIN, 10.9, 4.4, 0.6, (1.1, 1.1, 1.1)),
    # The camp where the squad is met.
    ("tent", 47.6, PLAIN, 15.0, 5.0, 2.2, (2.5, 1.9, 2.5)),
    ("box-large", 47.4, PLAIN, 9.0, 4.4, 0.9, (1.3, 1.1, 2.1)),
]
LAMPS = [(2.2, 13.6, PLAIN), (21.4, 3.2, PLAIN), (1.5, 0.5, PLAIN), (12.5, -1.5, PLAIN)]
TEXTS = {
    "title": "The depot outside Teruel",
    "target_name": "Depot",
    "objective_text": "Destroy the depot",
    "destroyed_text": "Depot destroyed",
    "objectives": [
        "Blow up the stores stacked in the farm's yard with the Dynamiter's charge.",
        "Get both of them to the camp fire on the road east.",
        "Lose either one and the mission fails.",
    ],
}


if __name__ == "__main__":
    tables = dict(
        NODE="PowderStore", SEASON="snow", LIGHT="overcast", SNOWFALL=True, DRESS="spain_winter", SEED=11, BOUNDS=BOUNDS, PLAIN=PLAIN, FEATURES=FEATURES,
        SPECIALIST_SPAWNS=SPECIALIST_SPAWNS, GUARDS=GUARDS, EXTRACTION=EXTRACTION, TARGET=TARGET,
        TARGET_STACK=TARGET_STACK, WALLS=WALLS, BUILDINGS=BUILDINGS, CRATES=CRATES, SCATTERS=SCATTERS,
        CLEAR=CLEAR, PLACED=PLACED, LAMPS=LAMPS, POLE_LINES=POLE_LINES, TOWERS=TOWERS, CARTS=CARTS,
        SETTLEMENT=SETTLEMENT,
    )
    write(mission(NAME="powder_store", TEXTS=TEXTS, **tables))
