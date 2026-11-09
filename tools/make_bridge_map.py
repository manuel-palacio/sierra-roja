#!/usr/bin/env python3
"""Writes resources/missions/bridge_land.tres and scenes/missions/bridge.tscn from the tables below.

The bridge map is authored here as numbers (metres, x east, z south, rail level y = 0) rather than
in the Godot editor, so a change to the land, the blockers or the patrols is one edit and one run:

    python3 tools/make_bridge_map.py && godot --headless --path . -s tools/map_preview.gd -- /tmp/map.png
"""
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
    (MOUND, ADD, [(-30, -24)], 9, 16, 6.0, None, -1),
    (MOUND, ADD, [(32, -24)], 5, 13, 5.0, None, -1),
    (MOUND, ADD, [(20, 37)], 5, 10, 2.0, None, -1),
    # Flat yards: the checkpoint and the extraction point. (The farmhouse has the hill's flat top.)
    (MOUND, SET, [(-31, 14)], 9, 4, PLAIN, None, EARTH),
    (MOUND, SET, [(46, 28)], 4, 3, PLAIN, None, EARTH),
    # The rocky ridge that screens the east bank's north corridor from the patrol south of it.
    (PATH, ADD, [(13, 13), (24, 12), (36, 13.5)], 0.4, 2.6, 2.6, None, -1),
    # The road: up from the south to the checkpoint, and on from the crossing to the farm.
    (PATH, SET, [(-28, 100), (-30, 40), (-30, 12)], 2.0, 2.5, PLAIN, None, ROAD),
    (PATH, SET, [(-30, -11), (-20, -12), (-19, -17), (-24, -19)], 1.6, 2.0, PLAIN, 3.0, ROAD),
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
    (PATH, SET, [(-14, -8), (-7, -2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    (PATH, SET, [(15, 8), (7, 2.3)], 1.6, 1.2, PLAIN, 0.0, EARTH),
    # The gorge, cut last through everything.
    (PATH, SET, [(-6, -110), (-3, -30), (0, -9), (0, 9), (4, 30), (8, 110)], 3.5, 1.5, -12.0, None, ROCK),
]

SPECIALIST_SPAWNS = [(-50, 32), (-50, 35)]
# name, route points; the guard starts at the first.
GUARDS = [
    ("Checkpoint", [(-32, 18), (-32, 10), (-25, 10), (-25, 18)]),
    ("Road", [(-30, 21), (-30, 30)]),
    ("Track", [(-44, 0), (-26, 0)]),
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
    [(-24, -9), (-17, -9.5)],
    [(-38, -18), (-39, -28), (-31, -31)],
]
# name, x, z, rotation (radians), size, roof height, ruin
BUILDINGS = [
    ("CheckpointHut", -37.5, 13, 0.0, (5, 2.8, 4), 1.3, False),
    ("Farmhouse", -31, -25, 0.25, (7, 2.6, 6), 0.0, True),
]
# Crates: name, x, y of the ground they stand on, z.
CRATES = [
    ("CrateTrackS", -9, 0.0, 1.7),
    ("CrateTrackN", -9, 0.0, -1.7),
    ("CrateYard1", -27, PLAIN, 14),
    ("CrateYard2", -34.5, PLAIN, 17.5),
    ("CrateYard3", -33, PLAIN, 8.5),
]


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
         '[ext_resource type="Script" path="res://src/terrain/building.gd" id="6_building"]', "",
         '[sub_resource type="NavigationMesh" id="NavMesh_bridge"]', "cell_size = 0.25", "cell_height = 0.25",
         "agent_height = 1.75", "agent_radius = 0.5", "agent_max_climb = 0.25", "agent_max_slope = 35.0",
         # Coarse detail keeps the navmesh under the path search's 4096-polygon limit.
         "detail_sample_distance = 8.0", "detail_sample_max_error = 0.3",
         # The gorge floor is left out: nobody can get there.
         f"filter_baking_aabb = AABB({bx - 1}, -6, {bz - 1}, {bw + 2}, 30, {bd + 2})", ""]
    materials = {"m_steel": (0.30, 0.32, 0.35), "m_crate": (0.45, 0.30, 0.16), "m_water": (0.12, 0.30, 0.45),
                 "m_rail": (0.15, 0.15, 0.17), "m_pad": (0.2, 0.7, 0.3)}
    for name, (r, g, b) in materials.items():
        o += [f'[sub_resource type="StandardMaterial3D" id="{name}"]', f"albedo_color = Color({r}, {g}, {b}, 1)", ""]
    for i, (_, points) in enumerate(GUARDS):
        flat = ", ".join(f"0, 0, 0, 0, 0, 0, {x}, 0.0, {z}" for x, z in points)
        tilts = ", ".join("0" for _ in points)
        o += [f'[sub_resource type="Curve3D" id="Curve_{i + 1}"]', "_data = {",
              f'"points": PackedVector3Array({flat}),', f'"tilts": PackedFloat32Array({tilts})', "}",
              f"point_count = {len(points)}", ""]
    o += ['[sub_resource type="BoxShape3D" id="Box_extraction"]', "size = Vector3(6, 3, 6)", ""]

    o += ['[node name="Bridge" type="Node3D"]', 'script = ExtResource("1_mission")',
          "bounds_rect = Rect2(%d, %d, %d, %d)" % BOUNDS, "",
          '[node name="Nav" type="NavigationRegion3D" parent="."]', 'navigation_mesh = SubResource("NavMesh_bridge")', "",
          '[node name="Terrain" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("3_terrain")',
          'spec = ExtResource("4_land")', "",
          # The deck's top is a hair above the embankment's, which it overlaps at each end.
          '[node name="BridgeDeck" type="CSGBox3D" parent="Nav"]', "use_collision = true", at(0, -0.18, 0),
          "size = Vector3(10.8, 0.4, 3.4)", 'material = SubResource("m_steel")', ""]
    for name, x, ground, z in CRATES:
        o += [f'[node name="{name}" type="CSGBox3D" parent="Nav"]', "use_collision = true", at(x, ground + 0.4, z),
              "size = Vector3(1.2, 1.6, 1.2)", 'material = SubResource("m_crate")', ""]
    for i, points in enumerate(WALLS):
        o += [f'[node name="Wall{i + 1}" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("5_wall")',
              f"points = {v2(points)}", ""]
    import math
    for name, x, z, rot, size, roof, ruin in BUILDINGS:
        c, s = math.cos(rot), math.sin(rot)
        o += [f'[node name="{name}" type="StaticBody3D" parent="Nav"]',
              f"transform = Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, {x}, 0, {z})",
              'script = ExtResource("6_building")', "size = Vector3(%s, %s, %s)" % size,
              f"roof_height = {roof}", f"ruin = {'true' if ruin else 'false'}", ""]

    o += ['[node name="Scenery" type="Node3D" parent="."]', "",
          '[node name="River" type="CSGBox3D" parent="Scenery"]', at(1, -11.0, 0), "size = Vector3(40, 1, 200)",
          'material = SubResource("m_water")', ""]
    for name, z in (("GirderN", -1.6), ("GirderS", 1.6)):
        o += [f'[node name="{name}" type="CSGBox3D" parent="Scenery"]', at(0, 1.0, z), "size = Vector3(10.8, 2, 0.2)",
              'material = SubResource("m_steel")', ""]
    for name, z in (("RailA", -0.7), ("RailB", 0.7)):
        o += [f'[node name="{name}" type="CSGBox3D" parent="Scenery"]', at(0, 0.08, z), "size = Vector3(200, 0.16, 0.12)",
              'material = SubResource("m_rail")', ""]
    ex, ez = EXTRACTION
    o += ['[node name="ExtractionPad" type="CSGBox3D" parent="Scenery"]', at(ex, PLAIN + 0.03, ez),
          "size = Vector3(6, 0.06, 6)", 'material = SubResource("m_pad")', ""]

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
