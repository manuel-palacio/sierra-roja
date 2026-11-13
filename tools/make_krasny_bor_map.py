#!/usr/bin/env python3
"""The Krasny Bor mission's map, as tables. Run to rewrite its land and scene:

    python3 tools/make_krasny_bor_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png res://scenes/missions/krasny_bor.tscn

The night of 9 February 1943, south of Leningrad, in snow, in the hour before dawn. A battery of
the División Azul: three guns in a row facing south, its artillery store in a walled yard at the
east end, a log dug-out and bunkhouse behind, and the telephone line from the dug-out running
east on poles across the back of the position. The pair start in the shell-torn wood along the
south edge and have to get back to it.

The quiet way is on the belly, round by the west and along behind the line of poles: a figure
lying down is seen only within six metres, and no beat comes that close to it. The store can be
blown from outside its east wall, with the open country beyond to crawl away into.
tests/run/krasny_bor_bot.gd plays it.
"""
from mapgen import ADD, EARTH, MOUND, PATH, ROAD, SET, mission, write

BOUNDS = (-55, -45, 110, 90)
PLAIN = 1.5
HIGH = 2.4

# kind, mode, points, width, falloff, height, end_height, surface
FEATURES = [
    (MOUND, ADD, [(-40, -36)], 6, 12, 2.4, None, -1),
    (MOUND, ADD, [(48, -34)], 5, 11, 2.0, None, -1),
    (MOUND, ADD, [(10, 36)], 5, 10, 1.4, None, -1),
    # The battery's ground, trodden flat, and the store's yard.
    (MOUND, SET, [(-4, 0)], 26, 6, PLAIN, None, EARTH),
    (MOUND, SET, [(34, 2)], 8, 3, PLAIN, None, EARTH),
    # The road behind the position.
    (PATH, SET, [(-110, -39), (-20, -37), (34, -37), (110, -39)], 1.8, 2.5, PLAIN, None, ROAD),
]

SPECIALIST_SPAWNS = [(-44, 38), (-42, 40)]
# name, route points; the guard starts at the first.
GUARDS = [
    ("GunLine", [(-24, 8.5), (14, 8.5)]),
    ("Picket", [(-6, 17), (8, 17)]),
    ("DugOut", [(-24, -17), (-24, -11)]),
    ("Road", [(-20, -37), (34, -37)]),
    ("StoreGate", [(27.0, 0.5), (27.0, 4.5)]),
    ("Yard", [(22, -8), (33, -8)]),
    ("Tower", [(18.6, -1.5), (19.2, -1.5)]),
    ("Bunkhouse", [(40, -12), (40, -6)]),
]
# A hollow in the wood in the south-east.
EXTRACTION = (44, 35)
EXTRACTION_FIRE = False
WALLS = [
    # The store's yard, with its gate in the west wall.
    ([(29, -2), (39, -2)], HIGH), ([(39, -2), (39, 6)], HIGH), ([(39, 6), (29, 6)], HIGH),
    ([(29, 6), (29, 3.8)], HIGH), ([(29, 0.8), (29, -2)], HIGH),
    # A sandbagged pit round the front of each gun.
    ([(-27, 4.5), (-27, 6.6), (-21, 6.6), (-21, 4.5)], 1.0, "sandbags"),
    ([(-9, 4.5), (-9, 6.6), (-3, 6.6), (-3, 4.5)], 1.0, "sandbags"),
    ([(9, 4.5), (9, 6.6), (15, 6.6), (15, 4.5)], 1.0, "sandbags"),
]
# The battery's tower, its light on the ground in front of the guns.
TOWERS = [(17.0, -3.0, 100, 45, 15)]
CARTS = [(-12.0, -6.0, 0.8)]
SETTLEMENT = [
    ("gun", -24.0, 3.0, 3.14),
    ("gun", -6.0, 3.0, 3.14),
    ("gun", 12.0, 3.0, 3.14),
    ("truck", 4.0, -14.0, 1.57),
    ("field_kitchen", 22.0, -17.0, 0.3),
]
# The telephone line from the dug-out east across the back of the position.
POLE_LINES = [[(-30, -22.5), (-18, -24), (-6, -24), (6, -24), (18, -24), (30, -24), (42, -24), (54, -24.5)]]
# Where it can be cut: (line, pole), counted from 0.
CUT_POINTS = [(0, 1), (0, 3), (0, 5)]
# name, x, z, rotation (radians), size, roof height, ruin, enterable, storeys, style.
BUILDINGS = [
    ("DugOut", -30, -14, 0.0, (7, 2.6, 5), 1.0, False, False, 1, "log"),
    ("Bunkhouse", 27, -14, 0.0, (9, 2.8, 5), 1.3, False, False, 1, "log"),
]
CRATES = [
    ("CrateGuns1", -15.0, PLAIN, 1.0, 1.4, 1.4),
    ("CrateGuns2", 3.0, PLAIN, 0.5, 1.4, 1.4),
]
# The store: shells stacked under a tarpaulin in the middle of the yard.
TARGET = (34, PLAIN, 4.0)
TARGET_STACK = [
    (33.2, PLAIN, 1.2, 1.8, 1.3, 1.3),
    (35.0, PLAIN, 1.4, 1.5, 1.2, 1.5),
    (34.2, PLAIN, 2.5, 2.0, 1.0, 0.9),
    (34.0, PLAIN + 1.2, 1.3, 1.4, 0.9, 1.1),
]

BIRCH = ["tree:birch"]
SNOW_PINES = ["tree:snow_pine"]
WOOD = [(-54, 24), (54, 24), (54, 44), (-54, 44)]
BEHIND = [(-54, -44), (54, -44), (54, -41), (-54, -41)]
WHOLE = [(-54, -44), (54, -44), (54, 44), (-54, 44)]
# Kept open: the way round by the west, the line of poles, the way down the east side, the hollow.
CLEAR = [(-44, 38), (-42, 40), (-40, 20), (-40, 0), (-40, -20), (-40, -26.5), (-17.4, -25.2), (6.6, -25.2), (30.6, -25.2),
         (-10, -26.5), (18, -26.5), (-30, -26.5), (36, -26.5), (42, -26.5), (50, -26.5), (50, -12), (50, 2), (46, 2), (40.6, 2), (47, 13), (45, 26), (44, 35), (-20, 38), (10, 39)]
# name, blocking, models, area, count, seed, spacing, scale range, keep clear, blocker size, max slope
SCATTERS = [
    ("WoodBirches", True, BIRCH, WOOD, 40, 91, 4.0, (0.85, 1.25), 3.0, (0.4, 3.0, 0.4), 30),
    ("WoodPines", True, SNOW_PINES, WOOD, 12, 92, 7.0, (0.85, 1.2), 3.0, (0.5, 3.0, 0.5), 30),
    ("BehindBirches", True, BIRCH, BEHIND, 14, 93, 7.0, (0.85, 1.2), 3.5, (0.4, 3.0, 0.4), 30),
    ("Rocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], WOOD, 8, 94, 9.0, (2.0, 2.6), 3.5, (1.8, 0.9, 1.8), 28),
    ("Bushes", False, ["tree:bare_bush"], WHOLE, 110, 95, 2.4, (0.7, 1.4), 1.5, None, 34),
    # Shell-torn: stumps and fallen timber through the wood.
    ("Deadwood", False, ["stump_round", "log_stack", "log", "stump_old"], WOOD, 40, 96, 3.5, (2.6, 3.4), 2.0, None, 30),
]
# Single props: model, x, ground height, z, scale, turn in radians, and the box that makes it solid.
PLACED = [
    ("barrel", -27.5, PLAIN, -9.5, 4.2, 0.0, (1.0, 1.4, 1.0)),
    ("box-large", 20.5, PLAIN, -11.0, 4.4, 0.4, (1.3, 1.1, 2.1)),
    ("box", 31.0, PLAIN, 4.6, 4.4, 0.2, (1.1, 1.1, 1.1)),
    # The hollow in the wood.
    ("tent", 48.0, PLAIN, 38.0, 5.0, 2.2, (2.5, 1.9, 2.5)),
]
# Lamps: x, z, height of the ground there.
LAMPS = [(-26.0, -10.0, PLAIN), (27.6, 2.4, PLAIN), (-6.0, -0.5, PLAIN), (24.0, -10.0, PLAIN)]
OBJECTIVES = [
    {"kind": "cut", "hud": "Cut the telephone lines", "marker": "Line", "done": "The lines are cut"},
    {"kind": "destroy", "hud": "Destroy the artillery store", "marker": "Store", "done": "Store destroyed"},
]
TEXTS = {
    "title": "The guns",
    "objectives": [
        "Cut the telephone line at its three marked poles (F, and stand still for four seconds).",
        "Blow up the artillery store with the Dynamiter's charge. In any order.",
        "Then both of you back to the wood. Lose either one and the mission fails.",
    ],
}


if __name__ == "__main__":
    write(mission(
        NAME="krasny_bor", NODE="KrasnyBor", SEED=43, SEASON="snow", NIGHT=True, LIGHT="predawn", SNOWFALL=True,
        DRESS="russia", NOISE=0.3, BOUNDS=BOUNDS, PLAIN=PLAIN, FEATURES=FEATURES,
        SPECIALIST_SPAWNS=SPECIALIST_SPAWNS, GUARDS=GUARDS, EXTRACTION=EXTRACTION, EXTRACTION_FIRE=EXTRACTION_FIRE,
        TARGET=TARGET, TARGET_STACK=TARGET_STACK, WALLS=WALLS, BUILDINGS=BUILDINGS, CRATES=CRATES, SCATTERS=SCATTERS,
        CLEAR=CLEAR, PLACED=PLACED, LAMPS=LAMPS, POLE_LINES=POLE_LINES, CUT_POINTS=CUT_POINTS, TOWERS=TOWERS,
        CARTS=CARTS, SETTLEMENT=SETTLEMENT, OBJECTIVES=OBJECTIVES, TEXTS=TEXTS,
    ))
