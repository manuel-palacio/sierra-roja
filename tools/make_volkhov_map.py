#!/usr/bin/env python3
"""The Volkhov mission's map, as tables. Run to rewrite its land and scene:

    python3 tools/make_volkhov_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png res://scenes/missions/volkhov.tscn

Winter 1941-42 on the Volkhov front, at dusk, with snow falling. The frozen river runs north to
south through the middle. The pair start in the birch wood on the west bank; the División Azul
holds a hamlet of log houses on the east bank, and its orders lie on the table in the command
post. Three ways over: straight across the ice in front of the machine-gun post, the causeway at
the north end with a sentry on it, and the south, where the snow has drifted over the ice. The
orders have to come back to the dug-out in the wood.

The quiet way is on the belly, by the south: a figure lying down is seen only within six metres,
and no beat comes that close to the drifts, the back of the hamlet, or the command post's door.
tests/run/volkhov_bot.gd plays it.
"""
from mapgen import ADD, EARTH, ICE, MOUND, PATH, ROAD, SET, mission, write

BOUNDS = (-55, -45, 110, 90)
PLAIN = 1.5
RIVER = 0.6  # the ice, below the banks

# kind, mode, points, width, falloff, height, end_height, surface
FEATURES = [
    # Low rises in the wood and behind the hamlet.
    (MOUND, ADD, [(-32, -8)], 7, 14, 2.6, None, -1),
    (MOUND, ADD, [(44, -34)], 6, 12, 2.2, None, -1),
    (MOUND, ADD, [(-30, 40)], 5, 10, 1.6, None, -1),
    # The hamlet's ground, trodden flat.
    (MOUND, SET, [(28, -2)], 16, 6, PLAIN, None, EARTH),
    # The road east out of it.
    (PATH, SET, [(36, 4), (48, 6), (110, 8)], 1.8, 2.0, PLAIN, None, ROAD),
    # The dug-out in the wood.
    (MOUND, SET, [(-44, -30)], 4, 3, PLAIN, None, EARTH),
    # The river: twelve metres of ice between low banks.
    (PATH, SET, [(-2, -110), (0, -20), (3, 10), (1, 110)], 6.0, 3.0, RIVER, None, ICE),
    # The causeway at the north end: timber and packed snow, level with the banks.
    (PATH, SET, [(-12, -34), (12, -34)], 1.6, 2.4, PLAIN, None, ROAD),
    # Snow drifted over the ice in the south.
    (MOUND, ADD, [(-1, 28)], 1.2, 1.6, 0.7, None, -1),
    (MOUND, ADD, [(4, 33)], 1.4, 1.8, 0.8, None, -1),
    (MOUND, ADD, [(0, 38)], 1.2, 1.6, 0.6, None, -1),
    (MOUND, ADD, [(6, 26)], 1.0, 1.4, 0.6, None, -1),
]

SPECIALIST_SPAWNS = [(-46, 34), (-44, 36.5)]
# name, route points; the guard starts at the first.
GUARDS = [
    ("Post", [(10.5, -6), (10.5, 4)]),
    ("Causeway", [(8, -34), (-5, -34)]),
    ("Street", [(14, 10), (22, 10)]),
    # Up and down the east side of the command post: the house stands between it and the door.
    ("CommandPost", [(37.5, -1), (37.5, -13)]),
    ("Kitchen", [(18, -17), (23, -9.5)]),
    ("EastRoad", [(46, -2), (46, 12)]),
    ("SouthBank", [(12.5, 8), (12.5, 22)]),
]
EXTRACTION = (-44, -30)
WALLS = [
    # The machine-gun post on the bank, looking over the ice.
    ([(10.2, -3.4), (8.4, -3.4), (8.4, 1.4), (10.2, 1.4)], 1.0, "sandbags"),
    # Garden walls at the back of the hamlet, under snow.
    [(24, 20), (33, 21)],
    [(16, 26), (22, 28)],
]
TOWERS = []
CARTS = [(25.0, 6.5, 0.4)]
SETTLEMENT = [
    ("field_kitchen", 21.0, -12.5, 0.6),
    ("well", 33.5, 9.0, 0.0),
    ("truck", 43.0, 2.0, 1.4),
]
# The telephone line east out of the command post.
POLE_LINES = [[(35.5, -8), (43, -11), (50, -13), (57, -15)]]
# name, x, z, rotation (radians), size, roof height, ruin, enterable, storeys, style.
BUILDINGS = [
    ("CommandPost", 30, -6, 0.0, (8, 3, 6), 1.5, False, True, 1, "log"),
    ("Izba1", 18, -22, 0.0, (6, 2.8, 5), 1.4, False, False, 1, "log"),
    ("Izba2", 41, 12, 0.0, (6, 2.8, 5), 1.4, False, False, 1, "log"),
    ("Izba3", 21, 16, 0.0, (7, 2.8, 5), 1.4, False, False, 1, "log"),
]
CRATES = [
    ("CratePost", 12.6, PLAIN, -8.5, 1.4, 1.4),
    ("CrateStreet", 26.0, PLAIN, 1.0, 1.4, 1.4),
]

BIRCH = ["tree:birch"]
SNOW_PINES = ["tree:snow_pine"]
WEST = [(-54, -44), (-10, -44), (-10, 44), (-54, 44)]
EAST = [(13, -44), (54, -44), (54, 44), (13, 44)]
WHOLE = [(-54, -44), (54, -44), (54, 44), (-54, 44)]
# Kept open: the ways over, the way round the back of the hamlet, the doors and the dug-out.
CLEAR = [(-46, 34), (-44, 36.5), (-44, -30), (-40, -26), (-12, 33), (10, 32), (20, 32), (35.5, 31), (35.5, 20), (35.5, 8),
         (28.5, 3), (30, -1.8), (-12, 0), (12, 0), (-14, -34), (14, -34), (-30, 34), (-44, 0), (-44, 20)]
# name, blocking, models, area, count, seed, spacing, scale range, keep clear, blocker size, max slope
SCATTERS = [
    ("WestBirches", True, BIRCH, WEST, 34, 71, 4.5, (0.85, 1.25), 3.0, (0.4, 3.0, 0.4), 30),
    ("WestPines", True, SNOW_PINES, WEST, 20, 72, 6.0, (0.85, 1.2), 3.0, (0.5, 3.0, 0.5), 30),
    ("EastBirches", True, BIRCH, EAST, 16, 73, 6.0, (0.85, 1.2), 3.5, (0.4, 3.0, 0.4), 30),
    ("EastPines", True, SNOW_PINES, EAST, 8, 74, 8.0, (0.85, 1.2), 3.5, (0.5, 3.0, 0.5), 30),
    ("Rocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], WHOLE, 12, 75, 8.0, (2.0, 2.6), 3.5, (1.8, 0.9, 1.8), 28),
    ("Bushes", False, ["tree:bare_bush"], WHOLE, 120, 76, 2.4, (0.7, 1.4), 1.5, None, 34),
    ("Deadwood", False, ["stump_round", "log_stack", "log", "stump_old"], WHOLE, 26, 77, 5.0, (2.6, 3.4), 2.0, None, 30),
]
# Single props: model, x, ground height, z, scale, turn in radians, and the box that makes it solid.
PLACED = [
    ("barrel", 23.2, PLAIN, -13.6, 4.2, 0.0, (1.0, 1.4, 1.0)),
    ("box-large", 36.0, PLAIN, 2.2, 4.4, 0.3, (1.3, 1.1, 2.1)),
    # The dug-out in the wood.
    ("tent", -47.0, PLAIN, -32.5, 5.0, 0.9, (2.5, 1.9, 2.5)),
    ("box-large", -41.0, PLAIN, -33.0, 4.4, 2.0, (1.3, 1.1, 2.1)),
]
# Lamps: x, z, height of the ground there.
LAMPS = [(28.2, -1.6, PLAIN), (22.5, -10.5, PLAIN), (12.0, -1.0, PLAIN)]
# The orders lie on the table in the command post's north-west corner.
OBJECTIVES = [
    {"kind": "steal", "item": (27.3, -8.0), "ground": PLAIN, "label": "Orders",
     "hud": "Take the orders from the command post", "carry": "Bring the orders back across the river",
     "marker": "Command post", "prompt": "You have the orders", "done": "The orders are out"},
]
TEXTS = {
    "title": "The orders",
    "objectives": [
        "Cross the frozen river and take the orders from the command post (F at the table).",
        "Bring them back across the river to the dug-out. F puts them down; whoever holds them cannot carry a body.",
        "Lose either one and the mission fails.",
    ],
}


if __name__ == "__main__":
    write(mission(
        NAME="volkhov", NODE="Volkhov", SEED=41, SEASON="snow", LIGHT="dusk", SNOWFALL=True, DRESS="russia",
        NOISE=0.3, BOUNDS=BOUNDS, PLAIN=PLAIN, FEATURES=FEATURES, SPECIALIST_SPAWNS=SPECIALIST_SPAWNS, GUARDS=GUARDS,
        EXTRACTION=EXTRACTION, WALLS=WALLS, BUILDINGS=BUILDINGS, CRATES=CRATES, SCATTERS=SCATTERS, CLEAR=CLEAR,
        PLACED=PLACED, LAMPS=LAMPS, POLE_LINES=POLE_LINES, TOWERS=TOWERS, CARTS=CARTS, SETTLEMENT=SETTLEMENT,
        OBJECTIVES=OBJECTIVES, TEXTS=TEXTS,
    ))
