# A Real Place Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the bridge mission on real terrain with three routes and five guards, give it night
lighting and props, and add the on-screen help needed to read it.

**Architecture:** A deterministic `TerrainGenerator` turns a `TerrainSpec` resource into a
`HeightField`; a `Terrain` node draws it and gives it collision, and the navmesh is baked from the
same triangles, so sight, picking and movement agree with what is drawn. Everything else is display
code that reads game state and never writes it.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, single-threaded web export), GUT
9.6.1, Playwright. Kenney CC0 model kits for props.

**Spec:** `docs/superpowers/specs/2026-11-09-a-real-place-design.md`

## Global Constraints

- Stealth rules do not change: no new mechanics, no tuning changes in `resources/*.tres`.
- Game rules never depend on display nodes. Display code reads units and never writes them.
- Renderer stays Compatibility; the web export stays single-threaded with no extensions.
- Only CC0 assets enter the repo; each is recorded in `CREDITS.md` with source and licence.
- No machine-specific details (host names, addresses, home paths) in tracked files.
- 30 fps or better in `e2e/perf.spec.js` with all five guards active.
- `ops/test.sh` passes at the end of every task.
- Work on `main`; push after each slice.

## Decisions the spec left to the plan

- **Collision** is a `ConcavePolygonShape3D` built from the drawn triangles, not a
  `HeightMapShape3D`, so the navmesh source, sight rays and the mesh are the same faces.
- **No sky.** The camera is orthographic and always looks down, so no ray ever reaches a sky. The
  terrain skirt reaches 45 m past the bounds and fog darkens it. The spec is amended to say so.
- **Buildings and dry-stone walls are generated meshes** (whitewashed box, tiled pitched roof; chains
  of stone blocks). No CC0 kit has Spanish rural buildings. Trees, rocks, scrub, fences, crates,
  barrels and track pieces come from Kenney kits (Nature Kit, Survival Kit, Train Kit).
- **Unit height** comes from the navmesh point under the unit every physics frame; `UnitVisual`
  shifts the model onto the drawn ground. The first milestone followed the next path corner, which
  is wrong between corners on a slope.
- **Sentry:** a two-point route along the bridge deck. No new guard code.
- **Bridge break** keeps the full rebake. If the rebake takes over 250 ms in the browser build,
  Task 6 moves the deck into its own navigation region that is switched off instead.
- **Probe and perf URLs skip the briefing** (`?probe=1`, `?perf=1`), so the existing browser specs
  keep their timing.

## Review Focus

1. **A click on ground no unit can stand on** (gorge wall, steep rock, water): the unit walks to the
   nearest reachable point and does not freeze or jitter. Test in Task 4.
2. **A save from the first milestone:** loading it shows the out-of-date message and offers a
   restart; nothing moves. Test in Task 6.
3. **A unit ordered across the bridge as it blows:** after the rebake it stops at the bank and does
   not walk on air. Test in Task 6.
4. **Camera rotated, pointer at a screen edge:** the view scrolls toward that edge in all four
   orientations, and a click still picks the ground under the pointer. Test in Task 13.
5. **A guard standing behind a tree or wall from the camera:** the click still selects it when its
   silhouette is what the pointer is on. Test in Task 12.

## File Structure

| File | Responsibility |
|---|---|
| `src/terrain/height_field.gd` | Grid of heights and surface tags; sampling |
| `src/terrain/terrain_feature.gd`, `terrain_spec.gd` | Authored description of a landscape (resources) |
| `src/terrain/terrain_generator.gd` | `TerrainSpec` -> `HeightField` |
| `src/terrain/terrain.gd` | Node: chunked mesh, vertex colours, collision, faces for the bake |
| `src/terrain/prop_scatter.gd` | Seeded placement of kit models as MultiMeshes, with optional blockers |
| `src/terrain/stone_wall.gd`, `building.gd` | Generated wall and building meshes with box colliders |
| `resources/missions/bridge_land.tres` | The bridge mission's `TerrainSpec` |
| `tools/map_preview.gd` | Headless top-down PNG of heights, navmesh, routes and props, for map design |
| `src/ui/guard_marker.gd`, `order_marker.gd`, `briefing.gd` | Display only |
| `assets/shaders/water.gdshader` | River |
| `assets/props/` | Kit models actually used, with licence files |

---

## Slice 1: terrain and the new map

### Task 1: HeightField

**Files:** Create `src/terrain/height_field.gd`, `tests/terrain/test_height_field.gd`.

**Interfaces — produces:**

```gdscript
class_name HeightField extends RefCounted
enum Surface { GRASS, EARTH, ROAD, BALLAST, ROCK }
func _init(origin: Vector2, cell: float, cols: int, rows: int)  # cols x rows vertices
var origin: Vector2; var cell: float; var cols: int; var rows: int
func rect() -> Rect2
func get_h(col: int, row: int) -> float      # clamped to the grid
func set_h(col: int, row: int, h: float) -> void
func get_surface(col: int, row: int) -> Surface
func set_surface(col: int, row: int, s: Surface) -> void
func vertex(col: int, row: int) -> Vector3
func height_at(x: float, z: float) -> float  # same triangle split as the mesh; clamped outside
func slope_deg_at(x: float, z: float) -> float
```

Each quad splits along the diagonal from `(col, row)` to `(col+1, row+1)`; `height_at` interpolates
inside the triangle the point falls in, so it equals the drawn surface exactly.

- [ ] Tests: a flat field returns its height everywhere and slope 0; a field rising 1 m per metre in
  x returns `height_at(2.5, z) == 2.5` and slope 45 within 0.01; a point outside the rect returns the
  edge height; `height_at` at a quad's centre equals the mean of the two diagonal corners.
- [ ] Run, see them fail, implement, see them pass, commit.

### Task 2: TerrainSpec and TerrainGenerator

**Files:** Create `src/terrain/terrain_feature.gd`, `src/terrain/terrain_spec.gd`,
`src/terrain/terrain_generator.gd`, `tests/terrain/test_terrain_generator.gd`.

**Interfaces — produces:**

```gdscript
class_name TerrainFeature extends Resource
enum Kind { MOUND, PATH }      # MOUND: radial, around points[0]. PATH: along the polyline.
enum Mode { ADD, SET }         # ADD: raise or lower by height. SET: blend toward absolute height.
@export var kind: Kind; @export var mode: Mode
@export var points: PackedVector2Array
@export var width: float       # full-strength radius (MOUND) or half-width (PATH)
@export var falloff: float     # metres over which strength eases from 1 to 0 (smoothstep)
@export var height: float
@export var end_height: float  # PATH + SET only: height at the last point; NAN means same as height
@export var surface := -1      # HeightField.Surface inside the full-strength zone, or -1 to leave

class_name TerrainSpec extends Resource
@export var bounds: Rect2      # playable area
@export var skirt := 45.0      # metres of land beyond the bounds on every side
@export var cell := 1.0
@export var base_height := 0.0
@export var seed := 1
@export var noise_amplitude := 0.0   # metres; applied before features, so SET features stay exact
@export var noise_period := 24.0
@export var features: Array[TerrainFeature]

class_name TerrainGenerator extends RefCounted
static func build(spec: TerrainSpec) -> HeightField
```

Features apply in order. Noise is `FastNoiseLite` (simplex) with the spec's seed. A PATH + SET
feature with `end_height` interpolates the target height by distance along the polyline (a ramp).

- [ ] Tests: same spec twice gives identical heights; different seed differs; a SET PATH leaves
  every vertex within `width` of the line at exactly `height` despite noise; an ADD MOUND of 5 m is
  5 m above base at its centre and 0 beyond `width + falloff`; a ramp PATH is at `height` at its
  start and `end_height` at its end; `surface` tags only the full-strength zone.
- [ ] Run, fail, implement, pass, commit.

### Task 3: Terrain node

**Files:** Create `src/terrain/terrain.gd`, `tests/terrain/test_terrain.gd`.

**Interfaces — consumes** `TerrainGenerator.build`. **Produces:**

```gdscript
class_name Terrain extends StaticBody3D   # collision_layer = Unit.LAYER_WORLD
const CHUNK := 32                         # quads per chunk side; one MeshInstance3D per chunk
const ROCK_SLOPE_DEG := 38.0              # steeper than this is drawn as rock
const COLLISION_MARGIN := 6.0             # collision covers the bounds plus this
@export var spec: TerrainSpec
var field: HeightField                    # set in _ready (or by build())
func build() -> void                      # idempotent; _ready calls it
func faces(area: Rect2) -> PackedVector3Array   # triangles inside area, for the navmesh bake
func height_at(x: float, z: float) -> float
```

Flat shading (per-face normals), colour in `COLOR` per vertex with a `StandardMaterial3D` that has
`vertex_color_use_as_albedo`. Colour by surface tag, rock above `ROCK_SLOPE_DEG`, with a small
seeded per-face brightness jitter so the faces read as low-poly. Chunks exist so that the eight-light
limit per mesh applies per chunk and so that off-screen land is culled.

- [ ] Tests: after `build()` a downward ray on the world layer hits within 0.01 m of
  `field.height_at` at ten seeded points inside the bounds; a `Perception.line_clear` between two
  points 1.6 m above ground on opposite sides of a 5 m mound is false and is true on flat ground;
  `faces(bounds)` is non-empty and every vertex lies inside the bounds grown by one cell; chunks
  number `ceil(cols/CHUNK) * ceil(rows/CHUNK)`.
- [ ] Run, fail, implement, pass, commit.

### Task 4: Mission and units on terrain

**Files:** Modify `src/mission/mission.gd`, `src/units/unit.gd`, `src/units/unit_visual.gd`,
`src/mission/mission_validator.gd`; tests in `tests/mission/test_mission_terrain.gd`,
`tests/unit/test_unit.gd`, `tests/mission/test_validator.gd`.

**Interfaces — produces:**

```gdscript
# Mission
func terrain() -> Terrain                       # the Terrain under Nav/, or null
func ground_height(x: float, z: float) -> float # terrain height, or 0.0 with no terrain
# Unit
func ground_y() -> float                        # navmesh height under the unit
# MissionValidator
const GROUND_TOLERANCE := 1.0
```

- `_collect_faces` also takes `Terrain.faces(bounds_rect.grow(2))` and, for every `StaticBody3D`
  under `Nav/` other than the terrain, the twelve triangles of each `BoxShape3D` and the faces of
  each `ConcavePolygonShape3D`. CSG handling stays for the bridge deck.
- The navmesh resource in the mission scene sets `agent_max_slope = 35`, `cell_height = 0.125`,
  `detail_sample_distance = 3`, `detail_sample_max_error = 0.15`, and `filter_baking_aabb` to the
  bounds. `NAV_BAKE_LIFT_CELLS` is re-measured against a flat terrain test and corrected.
- `Unit._physics_process` sets `global_position.y` from
  `NavigationServer3D.map_get_closest_point(map, global_position).y` moved at
  `VERTICAL_SNAP_SPEED`, moving or not.
- `UnitVisual` offsets the model's y by the drawn ground (a downward ray on the world layer from
  1 m above the unit) minus the unit's y, clamped to 0.5 m.
- Validator: every specialist spawn, guard spawn, route point, the bridge target and the extraction
  must be within `GROUND_TOLERANCE` of the navmesh on the ground plane; errors name the node.

- [ ] Tests: a mission built in code with a sloped `Terrain` bakes a navmesh whose closest point at
  three places is within 0.2 m of `ground_height`; a unit walking 10 m up a 20 degree slope stays
  within 0.25 m of the ground all the way and arrives; a slope of 45 degrees gets no navmesh; a
  `BoxShape3D` blocker under `Nav/` leaves a hole the path goes round; **Review Focus 1:** a move
  order onto the 45 degree face ends with the unit stopped on walkable ground within 2 s of
  arriving at the nearest point, velocity zero; the validator names a guard spawn placed on the
  45 degree face and a route point off the map.
- [ ] Existing tests that assume `y == 0` on a CSG floor keep passing unchanged (CSG path intact).
- [ ] Run, fail, implement, pass, commit.

### Task 5: The new map

**Files:** Create `tools/map_preview.gd`, `resources/missions/bridge_land.tres`,
`src/terrain/stone_wall.gd`, `src/terrain/building.gd`, `tests/terrain/test_blockers.gd`. Rewrite
`scenes/missions/bridge.tscn`, `tests/mission/test_bridge.gd`. Modify `src/mission/mission.gd`
(bridge constants), `src/mission/mission_validator.gd` (nothing but what Task 4 added).

**Interfaces — produces:**

```gdscript
class_name StoneWall extends StaticBody3D   # under Nav/, world layer
@export var points: PackedVector2Array      # polyline on the ground plane
@export var wall_height := 1.0              # hides a crawler, not a stander
@export var thickness := 0.6
func build(ground: Callable) -> void        # ground.call(x, z) -> float; Mission calls it before the bake

class_name Building extends StaticBody3D    # under Nav/, world layer
@export var size := Vector3(5, 3, 4)        # footprint x, wall height, footprint z
@export var roof_height := 1.4              # 0 for a roofless ruin
@export var ruin := false                   # broken wall tops, no roof
func build(ground: Callable) -> void
```

`tools/map_preview.gd` runs with `godot --headless --path . -s tools/map_preview.gd -- out.png`:
loads the mission, bakes, and writes a top-down image (height shading, unwalkable in grey, navmesh
edges, routes, spawns, blockers, 10 m grid with coordinates). It is a design aid and is excluded
from the export.

Map, in metres, x east, z south. Bounds `Rect2(-55, -40, 110, 80)`. Rail level is y = 0.

| Element | Where |
|---|---|
| Gorge | Along x = 0, 10 m wide at the top, 9 m deep, rock walls; river plane at y = -8 |
| Railway embankment | Along z = 0 from x = -55 to x = -5 and x = 5 to x = 55, top 5 m wide at y = 0, ballast |
| West plain | y from -3 (south-west) to -2.5; base ground for the checkpoint and the start |
| Hill | North-west, centre (-28, -24), 7 m above the plain, pines; ruined farmhouse on a pad at (-34, -22) |
| Road | From (-55, 22) north-east to the checkpoint at (-18, 8), then a ramp up onto the embankment at (-12, 0) |
| Checkpoint | Hut at (-20, 12), barrier, lamp posts, crates and barrels |
| Gorge path | From the start along the south plain to a ledge under the embankment's south face, then a ramp up to the abutment at (-6, 2) |
| Hill path | From the start north over the hill's shoulder, down to the embankment at (-10, -2) |
| East bank | Plain at y = -2 with scrub and rocks; extraction pad at (44, 26) |
| Start | Specialists at (-50, 30) and (-50, 33) |

Guards: `Guard1` and `Guard2` patrol the checkpoint and the road loop; `Guard3` walks the track
between x = -45 and x = -10; `Guard4` is the sentry pacing the deck between x = -5 and x = 5;
`Guard5` loops the east bank between the bridge end and the extraction. Exact route points are
tuned with the preview tool and the bot in Task 6.

Mission constants: `BANK_EDGE_X` stays 5.0; `bounds_rect` becomes the new bounds.

- [ ] `test_blockers.gd`: a `StoneWall` 1 m high between a guard and a specialist 3 m apart hides
  the crawler and not the stander (as the crate test did); a `Building` blocks both; both produce
  box shapes on the world layer and no navmesh inside their footprint.
- [ ] Rewrite `test_bridge.gd` for the new map: validator passes; 2 specialist spawns, 5 guard
  spawns, 5 routes, 5 guards at their spawns; extraction over 60 m from the start and across the
  gorge; guards walk at 3 m/s once nav is built; a walking unit stays within 0.25 m of
  `ground_height`; the navmesh has no point with |x| < 4 except on the deck (|z| < 2); a path from
  the start to the bridge target exists by each of the three routes (path through a named waypoint
  on each stays under 1.3 times the straight-line sum); the embankment hides a crawler at its
  south foot from a guard on the track above; the broken-bridge test as before.
- [ ] Build the land spec and scene, iterating with the preview tool until the tests pass.
- [ ] Commit.

### Task 6: Bot, saves, browser specs, slice build

**Files:** Rewrite `tests/run/bridge_bot.gd`, `tests/run/test_bridge_run.gd`,
`tests/run/test_bridge_detected.gd`. Modify `src/save/save_game.gd` (version + 1),
`tests/unit/test_save_game.gd`, `e2e/*.spec.js` where they assume the old map,
`export_presets.cfg` (exclude `tools/*`).

- [ ] Bot: `play()` wins by the gorge path without any guard reaching ALARM, knifing the sentry and
  hiding the body is allowed; `walk_upright()` takes the road. Assertions as now: WON, bridge
  destroyed, under the cap (raise `CAP` to 420 s if the larger map needs it), no alarm seen; the
  road walk and a walk at the checkpoint hut are both LOST with an alarm.
- [ ] **Review Focus 2:** a save dictionary with the previous version number is refused by
  `SaveGame` with the out-of-date message and the restart offer, and no unit moves.
- [ ] **Review Focus 3:** a specialist ordered from the west abutment to the east bank, with the
  bridge broken while it is on the approach, ends stopped at |x| >= `BANK_EDGE_X` on the west side
  with y within 0.25 m of the ground.
- [ ] Measure the rebake in the web build (log `Time.get_ticks_msec()` around `rebake_nav` once);
  apply the decision above.
- [ ] `ops/test.sh`, `ops/build-web.sh`, `npx playwright test --trace off`; look at a screenshot.
- [ ] Commit and push.

---

## Slice 2: the look

### Task 7: Light, fog, water

**Files:** Modify `scenes/main.tscn`, `scenes/missions/bridge.tscn`; create
`assets/shaders/water.gdshader`.

- Moon: directional, cool, energy about 0.9, shadows on, `directional_shadow_max_distance = 160`,
  soft. A second directional fill from the opposite side, energy about 0.2, no shadows.
- Environment: background a dark blue-black, ambient cool and low, depth fog on, tuned so the skirt
  fades out before its edge at every zoom. Tonemap filmic.
- Water: a plane in the gorge with a spatial shader, two scrolling noise layers for colour and a
  moon glint; unshaded cost, no screen reads (Compatibility).
- Lamps: `OmniLight3D` at the checkpoint (3) and the farmhouse (1), warm, range 10 to 13, each with
  a post and an unshaded bulb.

- [ ] Build, screenshot at three camera positions, adjust by eye until units, cover and ground
  read clearly. `e2e/perf.spec.js` still passes. Commit.

### Task 8: Props

**Files:** Create `assets/props/**` (only models used), `src/terrain/prop_scatter.gd`,
`tests/terrain/test_prop_scatter.gd`. Modify `scenes/missions/bridge.tscn`, `CREDITS.md`.

**Interfaces — produces:**

```gdscript
class_name PropScatter extends Node3D
@export var models: Array[PackedScene]      # one MultiMesh per mesh found in each model
@export var area: PackedVector2Array        # polygon on the ground plane
@export var count := 50
@export var seed := 1
@export var min_spacing := 2.0
@export var max_slope_deg := 30.0
@export var scale_range := Vector2(0.8, 1.3)
@export var keep_clear := 2.5               # metres from ROAD/BALLAST surfaces, spawns, route points
@export var blocker_size := Vector3.ZERO    # non-zero: each instance gets a BoxShape3D this size under Nav/
func build(mission: Mission) -> void        # called by Mission before the bake
func transforms() -> Array[Transform3D]
```

- [ ] Tests: same seed gives the same transforms; every instance lies inside the polygon, on a slope
  under the limit, at least `keep_clear` from a road vertex and from every route point, and at
  least `min_spacing` from each other; with `blocker_size` set, the navmesh has a hole at an
  instance and a sight ray through its trunk is blocked.
- [ ] Download the three Kenney kits into a scratch directory outside the repo, copy only the
  models used and each kit's licence file, record them in `CREDITS.md`.
- [ ] Place: pines on the hill (blocking trunks), scrub and grass tufts on the plains (no
  collision), rocks along the gorge rim and scattered as cover (blocking), sleepers and rails along
  the track, truss sides on the bridge (visual only, hidden with the span when it breaks), fences
  and the barrier at the checkpoint, crates and barrels.
- [ ] Re-run the bot tests; move any prop that breaks the winning route. Screenshot, perf, commit.

### Task 9: Uniforms and the prone pose

**Files:** Modify `assets/characters/Textures/*` (new variants beside the originals),
`src/units/unit_visual.gd`, unit scenes, `tests/unit/test_unit_visual.gd` (create).

- Guards in pale khaki, the Dynamiter in blue overalls with a red neckerchief, the Marksman in
  brown with a beret-dark head: made by recolouring the Kenney textures (kept CC0, noted in
  `CREDITS.md`).
- Crawling: the model lies face down along the unit's heading instead of being squashed, with the
  walk animation at reduced speed while moving and paused while still.

- [ ] Tests: crawling sets the model's up axis within 10 degrees of horizontal and leaves the
  unit's collision shape and position untouched; standing restores the rest basis exactly.
- [ ] Screenshot, commit, push slice 2.

---

## Slice 3: readability

### Task 10: Vision cones on the ground

**Files:** Modify `src/perception/perception.gd`, `src/ui/vision_overlay.gd`,
`tests/perception/test_perception.gd`, `tests/ui/test_hud.gd` where it reads the polygons.

**Interfaces — produces:**

```gdscript
# Perception
## Ground points a guard can see, as rows of samples along each ray. visible[i][j] is true when a
## target of target_height standing at samples[i][j] has a clear line from the guard's eye.
static func ground_samples(guard: Unit, range_m: float, rays: int, step: float,
		target_height: float, ground: Callable, tuning: GuardVision = null) -> Dictionary
		# { "points": Array[PackedVector3Array], "visible": Array[PackedByteArray] }
```

The overlay draws a quad between neighbouring samples when all four corners are visible: near zone
(red) tested at the crawling target height, far zone (yellow) at the standing height, each lifted
`LIFT` above the sampled ground. `Perception.polygon` stays for its existing callers and tests.

- [ ] Tests: on flat ground every sample is visible and lies at ground height; behind a 1 m wall
  the near-zone samples are hidden and far-zone samples (standing height) beyond 2 m from the wall
  are visible; at the foot of the embankment under a guard on the track, near samples are hidden.
- [ ] Implement, check the web build's frame rate with a cone shown, commit.

### Task 11: Guard, order and selection markers

**Files:** Create `src/ui/guard_marker.gd`, `src/ui/order_marker.gd`,
`tests/ui/test_markers.gd`. Modify `scenes/units/guard.tscn`, `scenes/units/specialist.tscn`,
`scenes/units/marksman.tscn`, `src/player/player_input.gd`, `src/main.gd`.

**Interfaces — produces:**

```gdscript
# PlayerInput
signal move_ordered(pos: Vector3, run: bool)
# GuardMarker extends Label3D (child of Guard): "" on PATROL, "?" on SUSPICIOUS and INVESTIGATE
#   (yellow), "!" on ALARM (red); billboard, no depth test, fixed size on screen.
# OrderMarker extends Node3D: show_at(pos: Vector3, run: bool); a ring that shrinks and fades in
#   0.6 s (two rings for a run order).
```

Selection ring: brighter, pulsing slowly, drawn only under the selected specialist; the other keeps
a dim ring.

- [ ] Tests: marker text and colour for each brain state, and it clears after a load back to
  PATROL; `move_ordered` fires once per accepted ground click with the picked position and not for
  a refused order or an armed-ability click; the order marker frees its rings after 0.6 s.
- [ ] Commit.

### Task 12: Silhouettes

**Files:** Modify `src/units/unit_visual.gd`, `src/player/picker.gd`,
`tests/player/test_player_input.gd`, `tests/unit/test_unit_visual.gd`.

- `UnitVisual` gives every mesh of the model a `next_pass` material: unshaded, flat colour (guards
  warm red-orange, specialists pale blue), drawn only where the unit is behind something (inverted
  depth test).
- **Review Focus 5:** `Picker.pick` casts the units layer first and returns a unit hit when the
  pointer is on a unit's capsule, whatever world geometry lies in front; otherwise it returns the
  world hit as before.

- [ ] Tests: every `MeshInstance3D` under a unit's model has the silhouette pass; with a wall box
  between camera and guard, `Picker.pick` at the guard's screen position returns the guard; with
  the pointer beside the guard it returns the wall.
- [ ] Screenshot a guard behind the hut and a specialist behind a pine. Commit.

### Task 13: Camera rotation

**Files:** Modify `src/player/iso_camera.gd`, `src/player/player_input.gd`,
`tests/player/test_iso_camera.gd`, `tests/player/test_player_input.gd`, `README.md`.

**Interfaces — produces:**

```gdscript
# IsoCamera
const ROTATE_TIME := 0.25
var quarter := 0                         # 0..3; yaw = YAW_DEG + 90 * quarter
func rotate_by(step: int) -> void        # +1 turns the view clockwise; eased over ROTATE_TIME
```

`Z` turns one way, `X` the other, also while paused.

- [ ] Tests: after `rotate_by(1)` and `ROTATE_TIME` the yaw is 135 and the focus is unchanged;
  four turns return the original transform; **Review Focus 4:** in each quarter a pointer at the
  right screen edge moves the focus along the camera's own right vector projected on the ground,
  and `Picker.pick` at the screen centre returns a point within 0.5 m of the focus on flat ground;
  `Z`/`X` call `rotate_by`.
- [ ] Commit, build, browser specs, push slice 3.

---

## Slice 4: a proper start

### Task 14: Briefing and objective line

**Files:** Create `src/ui/briefing.gd`, `tests/ui/test_briefing.gd`, `e2e/briefing.spec.js`.
Modify `src/main.gd`, `src/ui/hud.gd`, `tests/ui/test_hud.gd`, `README.md`, `CREDITS.md` if needed.

**Interfaces — produces:**

```gdscript
class_name Briefing extends CanvasLayer
signal started()
static func wanted() -> bool   # false with ?probe=1 or ?perf=1, and in headless test runs
# Hud
var objective_label: Label     # "Destroy the bridge" until rules.bridge_destroyed, then
                               # "Reach the extraction point"; hidden once the mission has ended
```

Copy: title "Sierra Roja", subtitle "The bridge at night", the two objectives, the controls table
from the README (including `Z` / `X`), and a "Start" button. The tree is paused and orders are off
until Start; `Enter` and `Space` also start. The camera can be scrolled behind it.

- [ ] Tests: the briefing pauses the tree and `started` unpauses it; Space on the briefing starts
  and does not also toggle the game's pause; the objective text follows `bridge_destroyed` and a
  load back to before the blast; `e2e/briefing.spec.js` sees the canvas, clicks, and the game runs
  with no console errors.
- [ ] Full run: `ops/test.sh`, `ops/build-web.sh`, `npx playwright test --trace off`, screenshots
  of the briefing and three views of the map. Update the README controls. Commit and push.
