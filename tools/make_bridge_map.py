#!/usr/bin/env python3
"""Writes resources/missions/bridge_land.tres and scenes/missions/bridge.tscn from the tables below.

The bridge map is authored here as numbers (metres, x east, z south, rail level y = 0) rather than
in the Godot editor, so a change to the land, the blockers or the patrols is one edit and one run:

    python3 tools/make_bridge_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOUNDS = (-55, -40, 110, 80)
PLAIN = -3.0
GRASS, EARTH, ROAD, BALLAST, ROCK = range(5)
MOUND, PATH = 0, 1
ADD, SET = 0, 1

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
NATURE = "res://assets/props/nature/"
PINES = ["tree_pineTallA", "tree_pineTallB", "tree_pineRoundA", "tree_pineRoundC", "tree_pineTallC", "tree_pineRoundE"]
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
    ("HillPines", True, PINES, HILL, 36, 11, 4.5, (3.2, 4.4), 3.0, (0.5, 3.0, 0.5), 32),
    ("NorthEastPines", True, PINES, NORTH_EAST, 24, 12, 5.0, (3.2, 4.4), 3.0, (0.5, 3.0, 0.5), 32),
    ("SouthWestTrees", True, ["tree_oak_dark", "tree_oak", "tree_detailed"], SOUTH_WEST, 9, 13, 8.0, (3.6, 4.6), 3.5, (0.6, 3.0, 0.6), 25),
    ("SouthEastTrees", True, ["tree_oak_dark", "tree_oak", "tree_detailed"], SOUTH_EAST, 8, 14, 8.0, (3.6, 4.6), 3.5, (0.6, 3.0, 0.6), 25),
    ("TallRocks", True, ["rock_tallA", "rock_tallB"], WHOLE_MAP, 14, 15, 9.0, (2.0, 2.6), 3.5, (1.4, 2.0, 1.4), 28),
    ("FlatRocks", True, ["rock_largeA", "rock_largeB", "rock_largeC"], WHOLE_MAP, 20, 16, 7.0, (2.2, 2.8), 3.5, (1.8, 0.9, 1.8), 28),
    ("Bushes", False, ["plant_bush", "plant_bushLarge", "plant_bushSmall", "plant_bushDetailed"], WHOLE_MAP, 190, 17, 2.2, (2.4, 3.8), 1.5, None, 34),
    ("Grass", False, ["grass", "grass_large", "grass_leafs", "grass_leafsLarge"], WHOLE_MAP, 1000, 18, 0.7, (2.0, 3.2), 0.9, None, 36),
    ("Poppies", False, ["flower_redA", "flower_redB", "flower_redC"], WHOLE_MAP, 300, 21, 0.6, (1.3, 2.0), 1.0, None, 30),
    ("Broom", False, ["flower_yellowA", "flower_yellowB", "flower_yellowC"], WHOLE_MAP, 170, 22, 0.8, (1.3, 2.1), 1.0, None, 34),
    ("Thistles", False, ["flower_purpleA", "flower_purpleB"], WHOLE_MAP, 80, 23, 1.0, (1.3, 2.0), 1.0, None, 34),
    ("Saplings", False, ["tree_thin", "tree_small", "tree_default"], WHOLE_MAP, 26, 24, 6.0, (2.2, 3.0), 3.0, None, 30),
    ("Deadwood", False, ["stump_round", "log_stack", "log", "stump_old"], WHOLE_MAP, 22, 20, 5.0, (2.6, 3.4), 2.0, None, 30),
    ("Pebbles", False, ["rock_smallA", "rock_smallB", "rock_smallC", "stone_smallA", "stone_smallB"], WHOLE_MAP, 160, 19, 1.2, (1.5, 2.6), 1.0, None, 40),
]
# Single props: model, x, ground height, z, scale, turn in radians, and the size of the box that
# makes it solid (None for something too thin to hide behind). What looks like cover is cover.
SURVIVAL = "res://assets/props/survival/"
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
LAMP_HEIGHT = 3.2


def v2(points):
    return "PackedVector2Array(" + ", ".join(f"{x}, {z}" for x, z in points) + ")"


def write_land():
    out = ['[gd_resource type="Resource" script_class="TerrainSpec" format=3]', "",
           '[ext_resource type="Script" path="res://src/terrain/terrain_spec.gd" id="1_spec"]',
           '[ext_resource type="Script" path="res://src/terrain/terrain_feature.gd" id="2_feature"]', ""]
    ids = []
    for i, (kind, mode, points, width, falloff, height, end, surface) in enumerate(FEATURES):
        ids.append(f"f{i}")
        out += [f'[sub_resource type="Resource" id="f{i}"]', 'script = ExtResource("2_feature")',
                f"kind = {kind}", f"mode = {mode}", f"points = {v2(points)}", f"width = {float(width)}",
                f"falloff = {float(falloff)}", f"height = {float(height)}"]
        if end is not None:
            out.append(f"end_height = {float(end)}")
        out += [f"surface = {surface}", ""]
    out += ["[resource]", 'script = ExtResource("1_spec")',
            "bounds = Rect2(%d, %d, %d, %d)" % BOUNDS, "skirt = 45.0", "cell = 1.0",
            f"base_height = {PLAIN}", "seed = 7", "noise_amplitude = 0.45", "noise_period = 28.0",
            "features = Array[ExtResource(\"2_feature\")]([" + ", ".join(f'SubResource("{i}")' for i in ids) + "])", ""]
    (ROOT / "resources/missions/bridge_land.tres").write_text("\n".join(out))


def at(x, y, z):
    return f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})"


def write_scene():
    bx, bz, bw, bd = BOUNDS
    o = ['[gd_scene format=3]', "",
         '[ext_resource type="Script" path="res://src/mission/mission.gd" id="1_mission"]',
         '[ext_resource type="PackedScene" path="res://scenes/units/guard.tscn" id="2_guard"]',
         '[ext_resource type="Script" path="res://src/terrain/terrain.gd" id="3_terrain"]',
         '[ext_resource type="Resource" path="res://resources/missions/bridge_land.tres" id="4_land"]',
         '[ext_resource type="Script" path="res://src/terrain/stone_wall.gd" id="5_wall"]',
         '[ext_resource type="Script" path="res://src/terrain/building.gd" id="6_building"]',
         '[ext_resource type="Script" path="res://src/terrain/prop_scatter.gd" id="7_scatter"]',
         '[ext_resource type="Script" path="res://src/terrain/sleepers.gd" id="8_sleepers"]',
         '[ext_resource type="Shader" path="res://assets/shaders/water.gdshader" id="9_water"]',
         '[ext_resource type="Script" path="res://src/terrain/campfire.gd" id="10_campfire"]']
    model_ids = {}
    for scatter in SCATTERS:
        for model in scatter[2]:
            if model not in model_ids:
                model_ids[model] = f"m_{model}"
                o.append(f'[ext_resource type="PackedScene" path="{NATURE}{model}.glb" id="m_{model}"]')
    for texture in ("steel", "planks", "stone_wall"):
        o.append(f'[ext_resource type="Texture2D" path="res://assets/textures/{texture}.jpg" id="t_{texture}"]')
    for model in sorted({entry[0] for entry in PLACED}):
        model_ids[model] = f"m_{model}"
        o.append(f'[ext_resource type="PackedScene" path="{SURVIVAL}{model}.glb" id="m_{model}"]')
    o += ["",
         '[sub_resource type="NavigationMesh" id="NavMesh_bridge"]', "cell_size = 0.25", "cell_height = 0.25",
         "agent_height = 1.75", "agent_radius = 0.5", "agent_max_climb = 0.25", "agent_max_slope = 35.0",
         # Coarse detail keeps the navmesh far under the path search's 4096-polygon limit (about
         # 1,400 polygons with every prop in; it was 2,800 at twice the detail), and costs a
         # centimetre or two of height, which the unit models make up when they are drawn.
         "detail_sample_distance = 16.0", "detail_sample_max_error = 0.6",
         # The gorge floor is left out: nobody can get there.
         f"filter_baking_aabb = AABB({bx - 1}, -6, {bz - 1}, {bw + 2}, 30, {bd + 2})", ""]
    # name -> (colour or tint, texture or None, texture repeats per metre)
    materials = {"m_steel": ((0.55, 0.57, 0.62), "steel", 0.5), "m_crate": ((0.95, 0.85, 0.72), "planks", 0.8),
                 "m_stone": ((0.9, 0.86, 0.8), "stone_wall", 0.4), "m_rail": ((0.2, 0.2, 0.22), None, 0),
                 "m_pad": ((0.2, 0.7, 0.3), None, 0), "m_post": ((0.12, 0.12, 0.13), None, 0),
                 "m_barrier": ((0.8, 0.2, 0.15), None, 0)}
    for name, ((r, g, b), texture, tiling) in materials.items():
        o += [f'[sub_resource type="StandardMaterial3D" id="{name}"]', f"albedo_color = Color({r}, {g}, {b}, 1)"]
        if texture:
            o += [f'albedo_texture = ExtResource("t_{texture}")', "uv1_triplanar = true", "uv1_world_triplanar = true",
                  f"uv1_scale = Vector3({tiling}, {tiling}, {tiling})"]
        o += ["roughness = 1.0", ""]
    for i, (_, points) in enumerate(GUARDS):
        flat = ", ".join(f"0, 0, 0, 0, 0, 0, {x}, 0.0, {z}" for x, z in points)
        tilts = ", ".join("0" for _ in points)
        o += [f'[sub_resource type="Curve3D" id="Curve_{i + 1}"]', "_data = {",
              f'"points": PackedVector3Array({flat}),', f'"tilts": PackedFloat32Array({tilts})', "}",
              f"point_count = {len(points)}", ""]
    for i, entry in enumerate(PLACED):
        if entry[6]:
            o += [f'[sub_resource type="BoxShape3D" id="Box_prop{i + 1}"]', "size = Vector3(%s, %s, %s)" % entry[6], ""]
    o += ['[sub_resource type="BoxShape3D" id="Box_extraction"]', "size = Vector3(6, 3, 6)", "",
          '[sub_resource type="ShaderMaterial" id="m_water"]', 'shader = ExtResource("9_water")', "",
          '[sub_resource type="PlaneMesh" id="Mesh_water"]', 'material = SubResource("m_water")', "size = Vector2(44, 260)", "",
          '[sub_resource type="StandardMaterial3D" id="m_lamp"]', "shading_mode = 0", "albedo_color = Color(1, 0.86, 0.55, 1)", "",
          '[sub_resource type="SphereMesh" id="Mesh_bulb"]', 'material = SubResource("m_lamp")', "radius = 0.16", "height = 0.32",
          "radial_segments = 8", "rings = 4", "",
          '[sub_resource type="CylinderMesh" id="Mesh_post"]', 'material = SubResource("m_post")', "top_radius = 0.06",
          "bottom_radius = 0.08", f"height = {LAMP_HEIGHT}", "radial_segments = 6", "rings = 1", ""]

    o += ['[node name="Bridge" type="Node3D"]', 'script = ExtResource("1_mission")',
          "bounds_rect = Rect2(%d, %d, %d, %d)" % BOUNDS, "",
          '[node name="Nav" type="NavigationRegion3D" parent="."]', 'navigation_mesh = SubResource("NavMesh_bridge")', "",
          '[node name="Terrain" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("3_terrain")',
          'spec = ExtResource("4_land")', "",
          # The deck's top is a hair above the embankment's, which it overlaps at each end.
          '[node name="BridgeDeck" type="CSGBox3D" parent="Nav"]', "use_collision = true", at(0, -0.18, 0),
          "size = Vector3(10.8, 0.4, 3.4)", 'material = SubResource("m_steel")', ""]
    for name, x, ground, z, length, depth in CRATES:
        o += [f'[node name="{name}" type="CSGBox3D" parent="Nav"]', "use_collision = true", at(x, ground + 0.4, z),
              f"size = Vector3({length}, 1.6, {depth})", 'material = SubResource("m_crate")', ""]
    for i, points in enumerate(WALLS):
        o += [f'[node name="Wall{i + 1}" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("5_wall")',
              f"points = {v2(points)}", ""]
    for name, x, z, rot, size, roof, ruin in BUILDINGS:
        c, s = math.cos(rot), math.sin(rot)
        o += [f'[node name="{name}" type="StaticBody3D" parent="Nav"]',
              f"transform = Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, {x}, 0, {z})",
              'script = ExtResource("6_building")', "size = Vector3(%s, %s, %s)" % size,
              f"roof_height = {roof}", f"ruin = {'true' if ruin else 'false'}", ""]

    def scatter_node(parent, entry):
        name, _, models, area, count, seed, spacing, scale, clear, blocker, slope = entry
        lines = [f'[node name="{name}" type="Node3D" parent="{parent}"]', 'script = ExtResource("7_scatter")',
                 "models = Array[PackedScene]([" + ", ".join(f'ExtResource("{model_ids[m]}")' for m in models) + "])",
                 f"area = {v2(area)}", f"count = {count}", f"seed = {seed}", f"min_spacing = {float(spacing)}",
                 f"max_slope_deg = {float(slope)}", "scale_range = Vector2(%s, %s)" % scale, f"keep_clear = {float(clear)}",
                 f"clear_points = {v2(CLEAR)}"]
        if blocker:
            lines.append("blocker_size = Vector3(%s, %s, %s)" % blocker)
        return lines + [""]

    for entry in SCATTERS:
        if entry[1]:
            o += scatter_node("Nav", entry)

    for i, (model, x, ground, z, scale, turn, solid) in enumerate(PLACED):
        if solid:
            c, sn = math.cos(turn), math.sin(turn)
            o += [f'[node name="PropBlocker{i + 1}" type="StaticBody3D" parent="Nav"]',
                  f"transform = Transform3D({c:.4f}, 0, {-sn:.4f}, 0, 1, 0, {sn:.4f}, 0, {c:.4f}, {x}, {ground + solid[1] / 2.0}, {z})", "",
                  f'[node name="Shape" type="CollisionShape3D" parent="Nav/PropBlocker{i + 1}"]',
                  f'shape = SubResource("Box_prop{i + 1}")', ""]

    o += ['[node name="Scenery" type="Node3D" parent="."]', "",
          '[node name="River" type="MeshInstance3D" parent="Scenery"]', at(1, -10.4, 0), 'mesh = SubResource("Mesh_water")', ""]
    for entry in SCATTERS:
        if not entry[1]:
            o += scatter_node("Scenery", entry)
    # A plate-girder bridge on two stone abutments.
    # (The girders are solid: lying on the deck you are hidden from the side. They are not under
    # Nav/, so the navmesh bake does not see them; the deck's own edge keeps feet on it.)
    for name, z in (("GirderN", -1.75), ("GirderS", 1.75)):
        o += [f'[node name="{name}" type="CSGBox3D" parent="Scenery"]', "use_collision = true", at(0, 0.35, z),
              "size = Vector3(11.2, 1.5, 0.22)",
              'material = SubResource("m_steel")', ""]
    for name, x in (("AbutmentW", -5.75), ("AbutmentE", 5.75)):
        o += [f'[node name="{name}" type="CSGBox3D" parent="Scenery"]', at(x, -6.3, 0), "size = Vector3(1.9, 12, 5.4)",
              'material = SubResource("m_stone")', ""]
    for name, a, b in (("SleepersW", -100.0, -5.4), ("DeckSleepers", -5.0, 5.0), ("SleepersE", 5.4, 100.0)):
        o += [f'[node name="{name}" type="MultiMeshInstance3D" parent="Scenery"]', 'script = ExtResource("8_sleepers")',
              f"from_x = {a}", f"to_x = {b}", ""]
    # The checkpoint's barrier: a striped pole across the road, high enough to walk under.
    o += ['[node name="Barrier" type="CSGBox3D" parent="Scenery"]', at(-30, PLAIN + 1.9, 8.2), "size = Vector3(5.4, 0.14, 0.14)",
          'material = SubResource("m_barrier")', "",
          '[node name="BarrierPost" type="CSGBox3D" parent="Scenery"]', at(-32.8, PLAIN + 0.95, 8.2), "size = Vector3(0.3, 1.9, 0.3)",
          'material = SubResource("m_post")', ""]
    for i, (model, x, ground, z, scale, turn, _solid) in enumerate(PLACED):
        c, sn = math.cos(turn) * scale, math.sin(turn) * scale
        o += [f'[node name="Prop{i + 1}" parent="Scenery" instance=ExtResource("{model_ids[model]}")]',
              f"transform = Transform3D({c:.4f}, 0, {-sn:.4f}, 0, {scale}, 0, {sn:.4f}, 0, {c:.4f}, {x}, {ground}, {z})", ""]
    for i, (x, z, ground) in enumerate(LAMPS):
        top = ground + LAMP_HEIGHT
        o += [f'[node name="Lamp{i + 1}" type="OmniLight3D" parent="Scenery"]', at(x, top, z),
              "light_color = Color(1, 0.72, 0.38, 1)", "light_energy = 1.1", "omni_range = 10.0", "omni_attenuation = 1.3", "",
              f'[node name="Bulb" type="MeshInstance3D" parent="Scenery/Lamp{i + 1}"]', 'mesh = SubResource("Mesh_bulb")', "",
              f'[node name="Post" type="MeshInstance3D" parent="Scenery/Lamp{i + 1}"]', at(0, -LAMP_HEIGHT / 2.0, 0),
              'mesh = SubResource("Mesh_post")', ""]
    for name, z in (("RailA", -0.7), ("RailB", 0.7)):
        o += [f'[node name="{name}" type="CSGBox3D" parent="Scenery"]', at(0, 0.19, z), "size = Vector3(200, 0.14, 0.1)",
              'material = SubResource("m_rail")', ""]
    ex, ez = EXTRACTION
    # The extraction point is a camp: a fire to walk to, a tent and stores beside it.
    o += ['[node name="ExtractionFire" type="Node3D" parent="Scenery"]', 'script = ExtResource("10_campfire")',
          at(ex, PLAIN, ez), ""]

    o += ['[node name="SpecialistSpawns" type="Node3D" parent="."]', ""]
    for i, (x, z) in enumerate(SPECIALIST_SPAWNS):
        o += [f'[node name="Specialist{i + 1}" type="Marker3D" parent="SpecialistSpawns"]', at(x, 0, z), ""]
    o += ['[node name="GuardSpawns" type="Node3D" parent="."]', ""]
    for i, (_, points) in enumerate(GUARDS):
        o += [f'[node name="Guard{i + 1}" type="Marker3D" parent="GuardSpawns"]', at(points[0][0], 0, points[0][1]), ""]
    o += ['[node name="Routes" type="Node3D" parent="."]', ""]
    for i, (name, _) in enumerate(GUARDS):
        o += [f'[node name="Route{i + 1}" type="Path3D" parent="Routes"]', f'curve = SubResource("Curve_{i + 1}")',
              f'editor_description = "{name}"', ""]
    o += ['[node name="Extraction" type="Area3D" parent="."]', "collision_layer = 0", "collision_mask = 2",
          at(ex, PLAIN + 1.5, ez), "", '[node name="Shape" type="CollisionShape3D" parent="Extraction"]',
          'shape = SubResource("Box_extraction")', "",
          '[node name="BridgeTarget" type="Marker3D" parent="."]', at(0, 0, 0), "",
          '[node name="Guards" type="Node3D" parent="."]', ""]
    for i in range(len(GUARDS)):
        o += [f'[node name="Guard{i + 1}" parent="Guards" instance=ExtResource("2_guard")]', ""]
    (ROOT / "scenes/missions/bridge.tscn").write_text("\n".join(o))


if __name__ == "__main__":
    write_land()
    write_scene()
    print("wrote bridge_land.tres and bridge.tscn")
