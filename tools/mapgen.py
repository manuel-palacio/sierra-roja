"""Writes a mission's land (`resources/missions/<name>_land.tres`) and scene
(`scenes/missions/<name>.tscn`) from tables of numbers.

A mission is authored as a small Python file of tables (see `make_bridge_map.py`,
`make_powder_map.py`) rather than in the Godot editor: metres, x east, z south. A change to the
land, the blockers or the patrols is one edit and one run, and `tools/map_preview.gd` draws the
baked result from above.
"""
import math
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parent.parent
GRASS, EARTH, ROAD, BALLAST, ROCK = range(5)
# What a frozen river is made of in a snow mission: the ballast surface, which winter draws as ice.
ICE = BALLAST
MOUND, PATH = 0, 1
ADD, SET = 0, 1
NATURE = "res://assets/props/nature/"
SURVIVAL = "res://assets/props/survival/"
LAMP_HEIGHT = 3.2
# Scatters drawn in one flat colour, by name.
FLAT_COLOURS = {"Wheat": (0.74, 0.62, 0.32)}
# Props drawn as plain textured shapes instead of kit models.
PLAIN_SHAPES = ("barrel", "box", "box-large")

DEFAULTS = dict(SEED=7, NOISE=0.45, NAV_FLOOR=-6, BRIDGE=False, TARGET=(0, 0, 0), TARGET_STACK=[], WALLS=[], BUILDINGS=[],
                CRATES=[], SCATTERS=[], CLEAR=[], PLACED=[], LAMPS=[], TEXTS={}, POLE_LINES=[], RIVER_COURSE=[], TOWERS=[], CARTS=[], SETTLEMENT=[], NIGHT=False, LAND=None, OBJECTIVES=None, SEASON="summer", SEA=None, EXTRACTION_FIRE=True, EXTRACTION_GROUND=None)


def mission(**tables):
    """The tables of one mission, with defaults for what it leaves out."""
    return SimpleNamespace(**{**DEFAULTS, **tables})


def write(m):
    """Writes a mission's scene, and its land unless it borrows another mission's (LAND)."""
    if not m.LAND:
        m.LAND = m.NAME
        write_land(m)
    write_scene(m)
    print(f"wrote {m.NAME}.tscn on the land of {m.LAND}")


def v2(points):
    return "PackedVector2Array(" + ", ".join(f"{x}, {z}" for x, z in points) + ")"


def write_land(m):
    BOUNDS, PLAIN, FEATURES = m.BOUNDS, m.PLAIN, m.FEATURES
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
            f"base_height = {PLAIN}", f"seed = {m.SEED}", f"noise_amplitude = {m.NOISE}", "noise_period = 28.0",
            "features = Array[ExtResource(\"2_feature\")]([" + ", ".join(f'SubResource("{i}")' for i in ids) + "])", ""]
    (ROOT / f"resources/missions/{m.LAND}_land.tres").write_text("\n".join(out))


def at(x, y, z):
    return f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})"


def objectives(m):
    """What the mission asks for. One that says nothing asks for its TARGET to be destroyed, in the
    words of its TEXTS."""
    if m.OBJECTIVES is not None:
        return m.OBJECTIVES
    return [{"kind": "destroy", "hud": m.TEXTS.get("objective_text", "Destroy the bridge"),
             "marker": m.TEXTS.get("target_name", "Bridge"), "done": m.TEXTS.get("destroyed_text", "Bridge destroyed")}]


def objective_nodes(objective, m):
    """The scene lines of one objective, under Objectives/, and of what it needs on the map."""
    if objective["kind"] == "destroy":
        # The thing to destroy stands at the BridgeTarget marker, whatever it is.
        return ['[node name="Destroy" type="Node" parent="Objectives"]', 'script = ExtResource("15_destroy")',
                f'hud_text = "{objective["hud"]}"', f'marker_name = "{objective["marker"]}"',
                f'done_text = "{objective["done"]}"', 'target = NodePath("BridgeTarget")', ""]
    if objective["kind"] == "rescue":
        # The cell is an enterable building, which has its doorway in the middle of its south wall.
        name, x, z, rot, size = next(b for b in m.BUILDINGS if b[0] == objective["building"])[:5]
        assert rot == 0.0 and len(objective) and size, "a cell's building is not turned"
        ground = objective["ground"]
        door_z = z + size[2] / 2.0
        px, pz = objective["prisoner"]
        return [
            # What shuts the doorway: solid to feet and eyes until the door is opened.
            '[node name="CellDoorBlock" type="CSGBox3D" parent="Nav"]', "use_collision = true",
            at(x, ground + 1.1, door_z - 0.22), "size = Vector3(2.5, 2.4, 0.3)", 'material = SubResource("m_crate")', "",
            '[node name="CellDoor" type="Node3D" parent="."]', at(x, ground, door_z), 'script = ExtResource("17_door")', "",
            '[node name="Prisoner" parent="." instance=ExtResource("18_prisoner")]', at(px, ground, pz), "",
            '[node name="Rescue" type="Node" parent="Objectives"]', 'script = ExtResource("16_rescue")',
            f'hud_text = "{objective["hud"]}"', f'marker_name = "{objective["marker"]}"',
            f'escort_text = "{objective["escort"]}"', 'prisoner = NodePath("Prisoner")', 'door = NodePath("CellDoor")', ""]
    raise ValueError("unknown objective kind: %s" % objective["kind"])


def write_scene(m):
    BOUNDS, PLAIN, GUARDS, EXTRACTION = m.BOUNDS, m.PLAIN, m.GUARDS, m.EXTRACTION
    # In a snow mission everything that stands on the land wears snow.
    snowy = ["snowy = true"] if m.SEASON == "snow" else []
    WALLS, BUILDINGS, CRATES, SCATTERS, CLEAR = m.WALLS, m.BUILDINGS, m.CRATES, m.SCATTERS, m.CLEAR
    PLACED, LAMPS, SPECIALIST_SPAWNS = m.PLACED, m.LAMPS, m.SPECIALIST_SPAWNS
    bx, bz, bw, bd = BOUNDS
    o = ['[gd_scene format=3]', "",
         '[ext_resource type="Script" path="res://src/mission/mission.gd" id="1_mission"]',
         '[ext_resource type="PackedScene" path="res://scenes/units/guard.tscn" id="2_guard"]',
         '[ext_resource type="Script" path="res://src/terrain/terrain.gd" id="3_terrain"]',
         '[ext_resource type="Resource" path="res://resources/missions/' + m.LAND + '_land.tres" id="4_land"]',
         '[ext_resource type="Script" path="res://src/terrain/stone_wall.gd" id="5_wall"]',
         '[ext_resource type="Script" path="res://src/terrain/building.gd" id="6_building"]',
         '[ext_resource type="Script" path="res://src/terrain/prop_scatter.gd" id="7_scatter"]',
         '[ext_resource type="Script" path="res://src/terrain/sleepers.gd" id="8_sleepers"]',
         '[ext_resource type="Shader" path="res://assets/shaders/water.gdshader" id="9_water"]',
         '[ext_resource type="Script" path="res://src/terrain/campfire.gd" id="10_campfire"]',
         '[ext_resource type="Script" path="res://src/terrain/telegraph_pole.gd" id="11_pole"]',
         '[ext_resource type="Script" path="res://src/terrain/watchtower.gd" id="12_tower"]',
         '[ext_resource type="Script" path="res://src/terrain/cart.gd" id="13_cart"]',
         '[ext_resource type="Script" path="res://src/terrain/settlement_prop.gd" id="14_settled"]',
         '[ext_resource type="Script" path="res://src/mission/objectives/destroy_objective.gd" id="15_destroy"]']
    if any(objective["kind"] == "rescue" for objective in objectives(m)):
        o += ['[ext_resource type="Script" path="res://src/mission/objectives/rescue_objective.gd" id="16_rescue"]',
              '[ext_resource type="Script" path="res://src/terrain/cell_door.gd" id="17_door"]',
              '[ext_resource type="PackedScene" path="res://scenes/units/prisoner.tscn" id="18_prisoner"]']
    model_ids = {}
    for scatter in SCATTERS:
        for model in scatter[2]:
            if model.startswith("tree:"):
                continue
            if model not in model_ids:
                model_ids[model] = f"m_{model}"
                o.append(f'[ext_resource type="PackedScene" path="{NATURE}{model}.glb" id="m_{model}"]')
    for texture in ("steel", "planks", "stone_wall"):
        o.append(f'[ext_resource type="Texture2D" path="res://assets/textures/{texture}.jpg" id="t_{texture}"]')
    for texture in ("planks", "stone_wall"):
        o.append(f'[ext_resource type="Texture2D" path="res://assets/textures/{texture}_normal.jpg" id="n_{texture}"]')
    for model in sorted({entry[0] for entry in PLACED} - set(PLAIN_SHAPES)):
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
         f"filter_baking_aabb = AABB({bx - 1}, {m.NAV_FLOOR}, {bz - 1}, {bw + 2}, {24 - m.NAV_FLOOR}, {bd + 2})", ""]
    # name -> (colour or tint, texture or None, texture repeats per metre)
    materials = {"m_steel": ((0.55, 0.57, 0.62), "steel", 0.5), "m_crate": ((0.95, 0.85, 0.72), "planks", 0.8),
                 "m_stone": ((0.9, 0.86, 0.8), "stone_wall", 0.4), "m_rail": ((0.2, 0.2, 0.22), None, 0),
                 "m_pad": ((0.2, 0.7, 0.3), None, 0), "m_post": ((0.12, 0.12, 0.13), None, 0),
                 "m_barrier": ((0.8, 0.2, 0.15), None, 0), "m_drum": ((0.45, 0.55, 0.42), "steel", 0.9)}
    for name, ((r, g, b), texture, tiling) in materials.items():
        o += [f'[sub_resource type="StandardMaterial3D" id="{name}"]', f"albedo_color = Color({r}, {g}, {b}, 1)"]
        if texture:
            o += [f'albedo_texture = ExtResource("t_{texture}")', "uv1_triplanar = true", "uv1_world_triplanar = true",
                  f"uv1_scale = Vector3({tiling}, {tiling}, {tiling})"]
            if texture in ("planks", "stone_wall"):
                o += ["normal_enabled = true", f'normal_texture = ExtResource("n_{texture}")']
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
        if entry[0] == "barrel":
            o += [f'[sub_resource type="CylinderMesh" id="Mesh_prop{i + 1}"]', 'material = SubResource("m_drum")',
                  f"top_radius = {entry[6][0] / 2.0}", f"bottom_radius = {entry[6][0] / 2.0}", f"height = {entry[6][1]}",
                  "radial_segments = 12", "rings = 1", ""]
        elif entry[0] in PLAIN_SHAPES:
            o += [f'[sub_resource type="BoxMesh" id="Mesh_prop{i + 1}"]', 'material = SubResource("m_crate")',
                  "size = Vector3(%s, %s, %s)" % entry[6], ""]
    o += ['[sub_resource type="BoxShape3D" id="Box_extraction"]', "size = Vector3(6, 3, 6)", "",
          '[sub_resource type="ShaderMaterial" id="m_water"]', 'shader = ExtResource("9_water")']
    if m.RIVER_COURSE:
        course = list(m.RIVER_COURSE) + [m.RIVER_COURSE[-1]] * (8 - len(m.RIVER_COURSE))
        o += [f"shader_parameter/course = {v2(course)}", f"shader_parameter/course_points = {len(m.RIVER_COURSE)}"]
    o += ["",
          '[sub_resource type="PlaneMesh" id="Mesh_water"]', 'material = SubResource("m_water")', "size = Vector2(44, 260)", "",
          '[sub_resource type="PlaneMesh" id="Mesh_sea"]', 'material = SubResource("m_water")', "size = Vector2(400, 160)", "",
          '[sub_resource type="StandardMaterial3D" id="m_lamp"]', "shading_mode = 0", "albedo_color = Color(1, 0.86, 0.55, 1)", "",
          '[sub_resource type="SphereMesh" id="Mesh_bulb"]', 'material = SubResource("m_lamp")', "radius = 0.16", "height = 0.32",
          "radial_segments = 8", "rings = 4", "",
          '[sub_resource type="CylinderMesh" id="Mesh_post"]', 'material = SubResource("m_post")', "top_radius = 0.06",
          "bottom_radius = 0.08", f"height = {LAMP_HEIGHT}", "radial_segments = 6", "rings = 1", ""]

    o += [f'[node name="{m.NODE}" type="Node3D"]', 'script = ExtResource("1_mission")',
          "bounds_rect = Rect2(%d, %d, %d, %d)" % BOUNDS]
    if m.SEASON != "summer":
        o.append(f'season = &"{m.SEASON}"')
    if m.NIGHT:
        o.append("night = true")
    if "title" in m.TEXTS:
        o.append(f'title = "{m.TEXTS["title"]}"')
    if "objectives" in m.TEXTS:
        o.append("briefing_lines = PackedStringArray(" + ", ".join('"%s"' % line for line in m.TEXTS["objectives"]) + ")")
    o += ["",
          '[node name="Nav" type="NavigationRegion3D" parent="."]', 'navigation_mesh = SubResource("NavMesh_bridge")', "",
          '[node name="Terrain" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("3_terrain")',
          'spec = ExtResource("4_land")', ""]
    if m.BRIDGE:
        # The deck's top is a hair above the embankment's, which it overlaps at each end.
        o += ['[node name="BridgeDeck" type="CSGBox3D" parent="Nav"]', "use_collision = true", at(0, -0.18, 0),
              "size = Vector3(10.8, 0.4, 3.4)", 'material = SubResource("m_steel")', ""]
    if m.TARGET_STACK:
        # What the charge is for. It is taken away, and the navmesh rebaked, when the target blows.
        o += ['[node name="TargetStack" type="Node3D" parent="Nav"]', ""]
        for i, (x, ground, z, sx, sy, sz) in enumerate(m.TARGET_STACK):
            o += [f'[node name="Stack{i + 1}" type="CSGBox3D" parent="Nav/TargetStack"]', "use_collision = true",
                  at(x, ground + sy / 2.0 - 0.2, z), f"size = Vector3({sx}, {sy}, {sz})", 'material = SubResource("m_crate")', ""]
    for name, x, ground, z, length, depth in CRATES:
        o += [f'[node name="{name}" type="CSGBox3D" parent="Nav"]', "use_collision = true", at(x, ground + 0.4, z),
              f"size = Vector3({length}, 1.6, {depth})", 'material = SubResource("m_crate")', ""]
    for i, wall in enumerate(WALLS):
        # A wall is a polyline, or (polyline, height) for one too high to see over, or
        # (polyline, height, kind) for one of sandbags.
        points, height, kind = (tuple(wall) + (None, None))[:3] if isinstance(wall, tuple) else (wall, None, None)
        o += [f'[node name="Wall{i + 1}" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("5_wall")',
              f"points = {v2(points)}"]
        if height:
            o.append(f"wall_height = {height}")
        if kind:
            o.append(f'kind = &"{kind}"')
        o += snowy + [""]
    for building in BUILDINGS:
        # name, x, z, turn, size, roof height, ruin, then optionally: enterable, storeys, style.
        name, x, z, rot, size, roof, ruin = building[:7]
        enterable = building[7] if len(building) > 7 else False
        storeys = building[8] if len(building) > 8 else 1
        style = building[9] if len(building) > 9 else None
        c, s = math.cos(rot), math.sin(rot)
        o += [f'[node name="{name}" type="StaticBody3D" parent="Nav"]',
              f"transform = Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, {x}, 0, {z})",
              'script = ExtResource("6_building")', "size = Vector3(%s, %s, %s)" % size,
              f"roof_height = {roof}", f"ruin = {'true' if ruin else 'false'}"]
        if enterable:
            o.append("enterable = true")
        if storeys > 1:
            o.append(f"storeys = {storeys}")
        if style:
            o.append(f'style = &"{style}"')
        o += snowy + [""]
    # Trucks, wells, haystacks and washing lines: kind, x, z, turn in radians.
    for i, (kind, x, z, turn) in enumerate(m.SETTLEMENT):
        c, sn = math.cos(turn), math.sin(turn)
        o += [f'[node name="Settled{i + 1}" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("14_settled")',
              f"transform = Transform3D({c:.4f}, 0, {-sn:.4f}, 0, 1, 0, {sn:.4f}, 0, {c:.4f}, {x}, 0, {z})", f'kind = &"{kind}"'] + snowy + [""]

    # Watchtowers (x, z) and carts (x, z, turn in radians): solid, set on the ground by the mission.
    # A tower: x, z, then its searchlight's aim in degrees (0 east, 90 south), swing and reach.
    for i, (x, z, aim, arc, reach) in enumerate(m.TOWERS):
        o += [f'[node name="Watchtower{i + 1}" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("12_tower")', at(x, 0, z),
              f"aim_deg = {float(aim)}", f"arc_deg = {float(arc)}", f"reach = {float(reach)}"] + snowy + [""]
    for i, (x, z, turn) in enumerate(m.CARTS):
        c, sn = math.cos(turn), math.sin(turn)
        o += [f'[node name="Cart{i + 1}" type="StaticBody3D" parent="Nav"]', 'script = ExtResource("13_cart")',
              f"transform = Transform3D({c:.4f}, 0, {-sn:.4f}, 0, 1, 0, {sn:.4f}, 0, {c:.4f}, {x}, 0, {z})"] + snowy + [""]

    def scatter_node(parent, entry):
        name, _, models, area, count, seed, spacing, scale, clear, blocker, slope = entry
        # "tree:<kind>" in place of kit models scatters trees made by TreeBuilder.
        what = (f'tree_kind = &"{models[0][5:]}"' if models[0].startswith("tree:") else
                "models = Array[PackedScene]([" + ", ".join(f'ExtResource("{model_ids[m]}")' for m in models) + "])")
        lines = [f'[node name="{name}" type="Node3D" parent="{parent}"]', 'script = ExtResource("7_scatter")', what,
                 f"area = {v2(area)}", f"count = {count}", f"seed = {seed}", f"min_spacing = {float(spacing)}",
                 f"max_slope_deg = {float(slope)}", "scale_range = Vector2(%s, %s)" % scale, f"keep_clear = {float(clear)}",
                 f"clear_points = {v2(CLEAR)}"]
        if blocker:
            lines.append("blocker_size = Vector3(%s, %s, %s)" % blocker)
        if name in FLAT_COLOURS:
            lines.append("flat_colour = Color(%s, %s, %s, 1)" % FLAT_COLOURS[name])
        return lines + snowy + [""]

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

    o += ['[node name="Scenery" type="Node3D" parent="."]', ""]
    if m.BRIDGE:
        o += ['[node name="River" type="MeshInstance3D" parent="Scenery"]', at(1, -10.4, 0), 'mesh = SubResource("Mesh_water")', ""]
    if m.SEA:
        # Still water over everything south of the shore; the land rises out of it.
        shore, level = m.SEA
        o += ['[node name="Sea" type="MeshInstance3D" parent="Scenery"]', at(0, level, shore + 76), 'mesh = SubResource("Mesh_sea")', ""]
    for entry in SCATTERS:
        if not entry[1]:
            o += scatter_node("Scenery", entry)
    if m.BRIDGE:
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
    for i, (model, x, ground, z, scale, turn, solid) in enumerate(PLACED):
        if model in PLAIN_SHAPES:
            # Boxes and barrels are made here, planked and rusted like everything else built,
            # in the size of the box that makes them solid.
            c, sn = math.cos(turn), math.sin(turn)
            o += [f'[node name="Prop{i + 1}" type="MeshInstance3D" parent="Scenery"]',
                  f"transform = Transform3D({c:.4f}, 0, {-sn:.4f}, 0, 1, 0, {sn:.4f}, 0, {c:.4f}, {x}, {ground + solid[1] / 2.0 - 0.1}, {z})",
                  f'mesh = SubResource("Mesh_prop{i + 1}")', ""]
            continue
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
    if m.BRIDGE:
        for name, z in (("RailA", -0.7), ("RailB", 0.7)):
            o += [f'[node name="{name}" type="CSGBox3D" parent="Scenery"]', at(0, 0.19, z), "size = Vector3(200, 0.14, 0.1)",
                  'material = SubResource("m_rail")', ""]
    # Telegraph poles, each wired to the next of its line.
    for line_index, line in enumerate(m.POLE_LINES):
        for i, (x, z) in enumerate(line):
            o += [f'[node name="Pole{line_index + 1}_{i + 1}" type="Node3D" parent="Scenery"]',
                  'script = ExtResource("11_pole")', at(x, 0, z)]
            if i + 1 < len(line):
                o.append("wire_to = Vector2(%s, %s)" % line[i + 1])
            o.append("")
    ex, ez = EXTRACTION
    extraction_ground = PLAIN if m.EXTRACTION_GROUND is None else m.EXTRACTION_GROUND
    if m.EXTRACTION_FIRE:
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
          at(ex, extraction_ground + 1.5, ez), "", '[node name="Shape" type="CollisionShape3D" parent="Extraction"]',
          'shape = SubResource("Box_extraction")', "",
          '[node name="BridgeTarget" type="Marker3D" parent="."]', at(*m.TARGET), "",
          '[node name="Guards" type="Node3D" parent="."]', "",
          '[node name="Objectives" type="Node" parent="."]', ""]
    for objective in objectives(m):
        o += objective_nodes(objective, m)
    for i in range(len(GUARDS)):
        o += [f'[node name="Guard{i + 1}" parent="Guards" instance=ExtResource("2_guard")]', ""]
    (ROOT / f"scenes/missions/{m.NAME}.tscn").write_text("\n".join(o))


