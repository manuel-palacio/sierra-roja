#!/usr/bin/env python3
"""The bridge mission's map, as tables. Run to rewrite its land and scene:

    python3 tools/make_bridge_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png
"""
from mapgen import ADD, BALLAST, EARTH, MOUND, PATH, ROAD, ROCK, SET, mission, write

BOUNDS = (-55, -40, 110, 80)
PLAIN = -3.0

# kind, mode, points, width, falloff, height, end_height, surface
FEATURES = [
    # Hills and knolls.
    (MOUND, ADD, [(-34, -26)], 8, 14, 5.5, None, -1),
    (MOUND, ADD, [(32, -24)], 5, 13, 5.0, None, -1),
    (MOUND, ADD, [(20, 37)], 5, 10, 2.0, None, -1),
    # Flat yards: the checkpoint and the extraction point. (The farmhouse has the hill's flat top.)
    (MOUND, SET, [(-31, 14)], 9, 4, PLAIN, None, EARTH),
    (MOUND, SET, [(46, 28)], 4, 3, PLAIN, None, EARTH),
    # The rocky ridge that screens the east bank's north corridor from the patrol south of it.
    (PATH, ADD, [(13, 13), (24, 12), (36, 13.5)], 0.4, 2.6, 2.6, None, -1),
    # The road: up from the south to the checkpoint, and on from the crossing to the farm.
    (PATH, SET, [(-28, 100), (-30, 40), (-30, 12)], 2.0, 2.5, PLAIN, None, ROAD),
    # The farm track is only painted on (ADD 0): it follows the hillside as it is.
    (PATH, ADD, [(-30, -11), (-28.5, -16), (-31, -20.5)], 1.6, 0.0, 0.0, None, ROAD),
    # The railway embankment either side of the gorge.
    (PATH, SET, [(-110, 0), (-5, 0)], 2.5, 5.0, 0.0, None, BALLAST),
    (PATH, SET, [(5, 0), (110, 0)], 2.5, 5.0, 0.0, None, BALLAST),
    # The level crossing by the checkpoint.
    (PATH, SET, [(-30, 12), (-30, 2.5)], 2.0, 1.5, PLAIN, 0.0, ROAD),
    (PATH, SET, [(-30, -2.5), (-30, -11)], 2.0, 1.5, 0.0, PLAIN, ROAD),
    (PATH, SET, [(-30, -0.5), (-30, 0.5)], 2.0, 0.01, 0.0, None, ROAD),
    # Footpaths over and onto the embankment: far west, and at each abutment.
    (PATH, SET, [(-54, 9), (-49, 2.4)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    (PATH, SET, [(-49, -2.4), (-54, -9)], 1.6, 1.2, 0.0, PLAIN, EARTH),
    (PATH, SET, [(-14, 8), (-7, 2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    (PATH, SET, [(-19, -8), (-12, -2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    (PATH, SET, [(15, 8), (7, 2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    (PATH, SET, [(15, -8), (7, -2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    (PATH, SET, [(44, 9), (38, 2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    # The gorge, cut last through everything.
    (PATH, SET, [(-6, -110), (-3, -30), (0, -9), (0, 9), (4, 30), (8, 110)], 3.5, 1.5, -12.0, None, ROCK),
]

SPECIALIST_SPAWNS = [(-50, 32), (-50, 35)]
# name, route points; the guard starts at the first.
GUARDS = [
    ("Checkpoint", [(-32, 18), (-32, 10), (-25, 10), (-25, 18)]),
    ("Road", [(-30, 21), (-30, 30)]),
    ("Track", [(-44, 0), (-28, 0)]),
    ("Sentry", [(-12, 0), (4, 0)]),
    ("EastBank", [(14, 17), (14, 30), (28, 30), (28, 17)]),
]
EXTRACTION = (46, 28)
# Dry-stone walls: polylines.
WALLS = [
    [(-33, 22), (-33, 33)],
    [(-27, 24), (-27, 33)],
    [(-24, 26), (-13, 26), (-13, 18)],
    [(18, 23), (25, 23)],
    [(34, 20), (40, 24)],
    [(-9, -12), (-8.5, -21)],
    [(-42, -21), (-42, -31), (-34, -33)],
    # A sandbagged post by the barrier.
    ([(-35.2, 6.8), (-33.4, 6.8), (-33.4, 8.0)], 1.0, "sandbags"),
]
# A watchtower over the checkpoint yard, and a cart left by the field and one at the farm.
TOWERS = [(-39.5, 19.5)]
CARTS = [(-17.5, 30.0, 0.5), (-39.0, -22.5, 2.0)]
# The middle of the river, for the foam along its banks: the gorge's own line.
RIVER_COURSE = [(-6, -110), (-3, -30), (0, -9), (0, 9), (4, 30), (8, 110)]
# Telegraph poles along the north side of the track, either side of the gorge.
POLE_LINES = [
    [(x, -3.4) for x in (-53, -39, -25, -11)],
    [(x, -3.4) for x in (11, 25, 39, 53)],
]
# name, x, z, rotation (radians), size, roof height, ruin
BUILDINGS = [
    ("CheckpointHut", -37.5, 13, 0.0, (5, 2.8, 4), 1.3, False),
    ("Farmhouse", -36, -27, 0.25, (7, 2.6, 6), 0.0, True),
]
# Crates: name, x, y of the ground they stand on, z, size along x, size along z.
# The two beside the track are long and close to the rails: each hides someone lying just west of
# it from a guard walking the rails, all the way until the guard is level with them.
CRATES = [
    ("CrateTrackS", -9.4, 0.0, 1.35, 3.0, 1.5),
    ("CrateTrackN", -9.4, 0.0, -1.75, 3.0, 1.5),
    ("CrateYard1", -27, PLAIN, 14, 1.2, 1.2),
    ("CrateYard2", -34.5, PLAIN, 17.5, 1.2, 1.2),
    ("CrateYard3", -33, PLAIN, 8.5, 1.2, 1.2),
]


# Scattered kit models. Blocking ones go under Nav/ and stop feet and eyes.
PINES = ["tree:pine"]
WHOLE_MAP = [(-54, -39), (54, -39), (54, 39), (-54, 39)]
HILL = [(-54, -39), (-10, -39), (-10, -24), (-20, -17), (-44, -17), (-54, -20)]
NORTH_EAST = [(8, -39), (54, -39), (54, -10), (12, -10)]
SOUTH_WEST = [(-54, 9), (-8, 9), (-6, 39), (-54, 39)]
SOUTH_EAST = [(10, 9), (54, 9), (54, 39), (12, 39)]
# Places the scatters leave open: the trail north of the track and the lying-up spots by the ramps.
CLEAR = [(-53.5, 12.5), (-52, 13.5), (-53.5, -9.5), (-50, -14.5), (-42, -15), (-33, -15), (-26, -13),
         (-20, -10.5), (-21.5, -12), (-15, 10), (-11, 30), (-30, 36), (44.5, 10), (46, 20)]
# name, blocking, models, area, count, seed, spacing, scale range, keep clear, blocker size, max slope
SCATTERS = [
    ("HillPines", True, PINES, HILL, 36, 11, 4.5, (0.85, 1.2), 3.0, (0.5, 3.0, 0.5), 32),
    ("NorthEastPines", True, PINES, NORTH_EAST, 24, 12, 5.0, (0.85, 1.2), 3.0, (0.5, 3.0, 0.5), 32),
    ("SouthWestTrees", True, ["tree:oak"], SOUTH_WEST, 9, 13, 8.0, (0.85, 1.2), 3.5, (0.6, 3.0, 0.6), 25),
    ("SouthEastTrees", True, ["tree:olive"], SOUTH_EAST, 8, 14, 8.0, (0.85, 1.2), 3.5, (0.6, 3.0, 0.6), 25),
    ("TallRocks", True, ["rock_tallA", "rock_tallB"], WHOLE_MAP, 14, 15, 9.0, (2.0, 2.6), 3.5, (1.4, 2.0, 1.4), 28),
    ("FlatRocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], WHOLE_MAP, 20, 16, 7.0, (2.2, 2.8), 3.5, (1.8, 0.9, 1.8), 28),
    ("Bushes", False, ["tree:bush"], WHOLE_MAP, 190, 17, 2.2, (0.7, 1.4), 1.5, None, 34),
    ("Grass", False, ["grass", "grass_large", "grass_leafs", "grass_leafsLarge"], WHOLE_MAP, 1000, 18, 0.7, (2.0, 3.2), 0.9, None, 36),
    ("Wheat", False, ["crops_wheatStageB"], [(-23.2, 18.8), (-14.2, 18.8), (-14.2, 25.2), (-23.2, 25.2)], 260, 25, 0.5, (2.4, 3.2), 0.3, None, 30),
    ("Poppies", False, ["flower_redA", "flower_redB", "flower_redC"], WHOLE_MAP, 190, 21, 0.6, (1.3, 2.0), 1.0, None, 30),
    ("Broom", False, ["flower_yellowA", "flower_yellowB", "flower_yellowC"], WHOLE_MAP, 170, 22, 0.8, (1.3, 2.1), 1.0, None, 34),
    ("Thistles", False, ["flower_purpleA", "flower_purpleB"], WHOLE_MAP, 80, 23, 1.0, (1.3, 2.0), 1.0, None, 34),
    ("Saplings", False, ["tree:sapling"], WHOLE_MAP, 26, 24, 6.0, (0.8, 1.3), 3.0, None, 30),
    ("Deadwood", False, ["stump_round", "log_stack", "log", "stump_old"], WHOLE_MAP, 22, 20, 5.0, (2.6, 3.4), 2.0, None, 30),
    ("Pebbles", False, ["rock_smallA", "rock_smallB", "rock_smallC", "stone_smallA", "stone_smallB"], WHOLE_MAP, 160, 19, 1.2, (1.5, 2.6), 1.0, None, 40),
]
# Single props: model, x, ground height, z, scale, turn in radians, and the size of the box that
# makes it solid (None for something too thin to hide behind). What looks like cover is cover.
PLACED = [
    ("barrel", -34.4, PLAIN, 11.2, 4.2, 0.0, (1.0, 1.4, 1.0)),
    ("barrel", -34.2, PLAIN, 12.4, 4.2, 1.0, (1.0, 1.4, 1.0)),
    ("box-large", -39.0, PLAIN, 16.0, 4.4, 0.3, (1.3, 1.1, 2.1)),
    ("box", -38.2, PLAIN, 17.6, 4.4, 1.2, (1.1, 1.1, 1.1)),
    ("box", -27.9, PLAIN, 15.4, 4.4, 0.5, (1.1, 1.1, 1.1)),
    ("signpost", -27.4, PLAIN, 21.5, 4.0, 1.6, None),
    ("tent", -40.5, PLAIN, 8.5, 5.0, 0.4, (2.5, 1.9, 2.5)),
    # The camp at the extraction point.
    ("tent", 50.2, PLAIN, 30.5, 5.0, 2.4, (2.5, 1.9, 2.5)),
    ("box-large", 49.5, PLAIN, 25.2, 4.4, 0.9, (1.3, 1.1, 2.1)),
    ("barrel", 50.6, PLAIN, 26.6, 4.2, 0.0, (1.0, 1.4, 1.0)),
]
# Lamps: x, z, height of the ground there. Warm pools of light at the checkpoint and the bridge.
LAMPS = [(-28.2, 9.5, PLAIN), (-35, 16, PLAIN), (-26, 17, PLAIN), (-6.3, 2.2, 0.0), (6.3, -2.2, 0.0)]


if __name__ == "__main__":
    write(mission(
        NAME="bridge", NODE="Bridge", BRIDGE=True, BOUNDS=BOUNDS, PLAIN=PLAIN, FEATURES=FEATURES,
        SPECIALIST_SPAWNS=SPECIALIST_SPAWNS, GUARDS=GUARDS, EXTRACTION=EXTRACTION, WALLS=WALLS,
        BUILDINGS=BUILDINGS, CRATES=CRATES, SCATTERS=SCATTERS, CLEAR=CLEAR, PLACED=PLACED, LAMPS=LAMPS, POLE_LINES=POLE_LINES,
        TOWERS=TOWERS, CARTS=CARTS, RIVER_COURSE=RIVER_COURSE,
    ))
