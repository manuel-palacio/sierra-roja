# Historical Campaign, Batch 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the game a winter: snow-covered land, winter trees and buildings, overcast and dusk
light, snowfall and winter uniforms; turn the powder store into Teruel, December 1937; and add the
Volkhov raid against the División Azul, with a new objective: steal the orders and carry them out.

**Architecture:** A mission scene declares three things the map tables write: `season` (how the
land and what stands on it are drawn), `light` (the daylight preset) and `dress` (which uniforms
its units wear). `Terrain`, `PropScatter`, `Building`, `main.gd` and `UnitVisual` each read the
one they need; nothing in the rules reads any of them. The steal objective adds a `Carryable`
thing used with `F`, on the `Interactable` and `Objective` types batch 1 made.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, single-threaded web export), GUT
(`ops/test.sh`), Python 3 map tables (`tools/mapgen.py`), Playwright for the built game.

**Spec:** `docs/superpowers/specs/2026-11-12-historical-campaign-design.md` (Delivery, batch 2:
"Winter look and uniforms; mission 2, Teruel; mission 5, Volkhov (steal)").

## Global Constraints

- Stealth rules do not change: snow, light and dress are drawn, never read by perception. No
  snow tracks, no camouflage effect from white smocks.
- No swastikas or other Nazi symbols. The División Azul is told apart by field grey, the German
  helmet shape and the red-yellow-red arm shield.
- Every historical sentence shown in the game is in the spec's "Historical notes" table with its
  source first. Before a note goes into `history.gd`, fetch its source page and check each
  sentence against it; drop or reword what the page does not say, and update the table to match.
- Maps are authored only as tables in `tools/make_<name>_map.py`; generated `.tscn` and
  `_land.tres` files are never edited by hand.
- Navmesh under 2,500 polygons per mission. 30 fps or better in `e2e/perf.spec.js` on every
  mission, snowfall included.
- New art is made in the repo from code or from the CC0 kits already credited; anything new from
  outside goes into `CREDITS.md`.
- Each task: run the test files it names while working, and the whole `ops/test.sh` before its
  last commit. No failing tests and no script errors at any commit.
- Work on branch `campaign-batch-2`; merge to `main` and deploy only in Task 9.

## Review Focus

1. **Quick load with the orders.** Save with them on the table, pick them up, load: back on the
   table and in nobody's hands. Save while carrying, drop them, load: carried again. (Task 6.)
2. **`F` with the orders in hand next to a body.** It puts the orders down; it does not lift the
   body. With empty hands the next press lifts the body. A specialist holding the orders cannot
   lift a body by any route, the HUD's button included. (Task 6.)
3. **The orders lying inside the extraction are not a win.** Only a living specialist carrying
   them there is; and both specialists must be there. (Task 6.)
4. **Old links and old wins.** `?mission=powder_store` opens Teruel, and a browser that stored a
   win as `powder_store` has Teruel won and Carchuna open. (Task 5.)
5. **Dress outside a winter mission, and on the dead.** A unit with no mission above it (tests,
   the unit preview) and every unit in Guadarrama and Carchuna look as they do today; a guard
   killed on the Volkhov leaves a body in field grey, not khaki. (Task 4.)

---

### Task 1: Snow on the land, and ice

**Files:**
- Modify: `src/mission/mission.gd`, `src/terrain/terrain.gd`, `assets/shaders/terrain.gdshader`,
  `tools/mapgen.py`
- Test: `tests/terrain/test_terrain.gd`, `tests/mission/test_mission_terrain.gd`

**Interfaces:**
- Produces:

```gdscript
# Mission
@export var season := &"summer"          # &"summer" or &"snow"
# Terrain
const SNOW := Color(0.90, 0.93, 0.97)
const SNOW_MIST := Color(0.74, 0.78, 0.84)   # what snow-covered land fades into past the map's edge
var season := &"summer"
func set_season(value: StringName) -> void   # sets shader parameters "snow_cover" (0.0 or 1.0) and the mist
```

```python
# mapgen
SEASON = "summer"        # or "snow"; written as the mission's `season`
ICE = BALLAST            # the surface to give a frozen river in a snow mission
```

- `Mission._ready` (or `build_scenery`, before the shade bake) calls `terrain().set_season(season)`.
- Shader, with `snow_cover` at 1: the grass weight draws as snow (`SNOW`, broken up by the grass
  texture's own light and dark at a quarter strength), the earth weight as paler trodden snow
  (`SNOW` darkened 12%), the road weight as grey-brown slush (the road texture at 60% mixed with
  `SNOW` at 40%), the ballast weight as ice (`Color(0.70, 0.80, 0.88)`, smooth, roughness 0.15),
  and rock keeps its texture with snow on faces whose normal points up more than 0.75. With
  `snow_cover` at 0 the output is exactly today's.
- A frozen river is an ordinary flat `PATH SET` feature with surface `ICE`: it is walkable land.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_terrain.gd
func test_summer_is_the_default_and_draws_as_before() -> void:
	assert_eq(terrain.season, &"summer")
	assert_eq(terrain.material().get_shader_parameter("snow_cover"), 0.0)
func test_snow_season_covers_the_land() -> void:
	terrain.set_season(&"snow")
	assert_eq(terrain.material().get_shader_parameter("snow_cover"), 1.0)
	assert_eq(terrain.material().get_shader_parameter("mist"), Terrain.SNOW_MIST)
func test_an_unknown_season_is_summer() -> void:      # set_season(&"monsoon") leaves snow_cover 0.0
# test_mission_terrain.gd
func test_a_mission_hands_its_season_to_its_land() -> void   # a Mission with season = &"snow" and a Terrain child: terrain.season == &"snow" after build_scenery
```

  (`Terrain.material()` returns the shared `ShaderMaterial`; add it if the class has no such
  accessor.)
- [ ] **Step 2: Run** `ops/test.sh -gtest=res://tests/terrain/test_terrain.gd,res://tests/mission/test_mission_terrain.gd` — expected: fail on the missing members.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the same** — expected: pass. Then `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at it.** Temporarily generate the powder store with `SEASON="snow"`, render
  it with `tools/map_preview.gd` and one in-game screenshot, check snow, slush on the road and
  rock faces read right, then put the table back.
- [ ] **Step 6: Commit** `feat: snow on the land`.

---

### Task 2: Winter trees, rocks and buildings

**Files:**
- Modify: `src/terrain/tree_builder.gd`, `src/terrain/prop_scatter.gd`, `src/terrain/building.gd`,
  `src/terrain/stone_wall.gd`, `src/terrain/settlement_prop.gd`, `tools/mapgen.py`
- Test: `tests/terrain/test_tree_builder.gd`, `tests/terrain/test_prop_scatter.gd`, `tests/terrain/test_blockers.gd`

**Interfaces:**
- Produces:

```gdscript
# TreeBuilder.KINDS gains
&"snow_pine"   # the pine's shape; crown tint Color(0.80, 0.86, 0.84), snow on the upper side of each bough
&"birch"       # height 7.0, trunk 0.14 white with dark flecks, a thin bare crown of twigs, no leaves
&"bare_bush"   # the bush's shape as bare brown twigs, half the cards
# PropScatter
@export var snowy := false        # kit rocks, stumps and logs get a white top (PALETTE entries lightened towards Terrain.SNOW by 0.6)
# Building
@export var snowy := false        # roof tinted Color(0.92, 0.94, 0.97), a white cap on the chimney and ridge
@export var style := &"plaster"   # or &"log": walls of dark horizontal logs (planks texture, tint Color(0.50, 0.40, 0.30)), no shutters, a plank door
```

- `mapgen`: with `SEASON == "snow"` every `PropScatter`, `Building`, `StoneWall`,
  `SettlementProp`, `Watchtower` and `Cart` node is written with `snowy = true`; a building entry
  may carry a style as its tenth field. `StoneWall`, `SettlementProp`, `Watchtower` and `Cart`
  take `snowy` as a thin white cap on their top faces (one flat box or tint each; no new models).
- Collision and navmesh are unchanged by any of this: `snowy` and `style` draw, nothing else.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_tree_builder.gd
func test_winter_kinds_build_three_variants_each() -> void:   # for snow_pine, birch, bare_bush: variants(kind).size() == 3 and each has surfaces
func test_a_birch_has_no_leaf_surface() -> void
# test_prop_scatter.gd
func test_snowy_scatter_places_exactly_what_a_plain_one_does() -> void:
	# same seed, area and count with snowy true and false: transforms() are equal
# test_blockers.gd
func test_a_log_house_blocks_like_a_plaster_one() -> void:
	# same size and place, style &"log" and &"plaster": identical collision shapes and navmesh cut
func test_a_snowy_building_blocks_like_a_plain_one() -> void
```

- [ ] **Step 2: Run** the three files — expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the three files, then `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at it** in `tools/map_preview.gd` and one in-game screenshot of a snowy
  farm and a log house.
- [ ] **Step 6: Commit** `feat: winter trees, snow on roofs and log houses`.

---

### Task 3: Overcast and dusk, and falling snow

**Files:**
- Modify: `src/mission/mission.gd`, `src/main.gd`, `tools/mapgen.py`
- Create: `src/terrain/snowfall.gd`
- Test: `tests/mission/test_night.gd` (rename the file's subject to "light"; keep its tests), `tests/terrain/test_snowfall.gd`

**Interfaces:**
- Produces:

```gdscript
# Mission
@export var light := &"dawn"      # &"dawn" (today's day look), &"overcast", &"dusk"; `night` stays as it is and wins over `light`
@export var snowfall := false
# main.gd
func _apply_light() -> void        # replaces the direct call to _fall_night(); night -> _fall_night(), else by `light`

class_name Snowfall extends CPUParticles3D
const MAX_FLAKES := 260
func follow(camera: IsoCamera) -> void   # rides above the camera's focus so flakes fall through the view wherever it looks
```

- Presets (sun colour, sun energy, fill energy, ambient colour, ambient energy, sky/mist colour,
  saturation):
  - `overcast`: `Color(0.86, 0.88, 0.92)`, 0.55, 0.45, `Color(0.72, 0.76, 0.84)`, 0.95,
    `Terrain.SNOW_MIST`, 0.85. Shadows soft and faint (sun `shadow_opacity` 0.35).
  - `dusk`: `Color(1.0, 0.62, 0.38)`, 0.7, 0.2, `Color(0.46, 0.44, 0.62)`, 0.7,
    `Color(0.38, 0.33, 0.42)`, 0.9. The sun is lowered to 14° above the horizon so shadows run long.
    Lamps are turned up 2× (night turns them up 3.2×).
- Snowfall: local-space box emitter 44 × 30 m, 16 m above the focus, flakes 0.05 m white unshaded
  quads, lifetime 6 s, falling 3 m/s with a slight drift; no collision, no shadows. `main.gd`
  adds one when `mission.snowfall` is true.
- `mapgen`: tables `LIGHT` (default `"dawn"`) and `SNOWFALL` (default `False`).

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_night.gd
func test_an_overcast_mission_is_dimmer_and_flatter_than_dawn_and_not_dark() -> void:
	# sun energy < dawn's, ambient energy > dawn's, sky luminance > 0.5
func test_dusk_is_warm_and_low_with_lamps_up() -> void:
	# sun colour redder than blue, sun pitch between 10 and 20 degrees, lamp energy == 2 x the day's
func test_night_wins_over_light() -> void
func test_an_unknown_light_is_dawn() -> void
# test_snowfall.gd
func test_it_never_exceeds_its_cap() -> void:
	assert_lte(snow.amount, Snowfall.MAX_FLAKES)
func test_it_rides_with_the_camera() -> void       # move the camera focus 30 m: the emitter's x and z follow within 0.1
func test_a_mission_without_snowfall_has_none() -> void    # main on Guadarrama: no Snowfall node
```

- [ ] **Step 2: Run** the two files — expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the two files, then `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Commit** `feat: overcast, dusk and falling snow`.

---

### Task 4: Winter dress

**Files:**
- Create: `src/units/dress.gd`
- Modify: `src/units/unit_visual.gd`, `src/units/soldier_gear.gd`, `src/mission/mission.gd`,
  `tools/make_soldier.py`, `tools/unit_preview_run.gd`, `tools/mapgen.py`
- Create (generated): `assets/characters/soldier/uniform-{guard_blue,dynamiter_russia,marksman_russia}.png`
- Test: `tests/unit/test_dress.gd`, `tests/unit/test_unit_visual.gd`

**Interfaces:**
- Produces:

```gdscript
# Mission
@export var dress := &""          # &"" (as today), &"spain_winter", &"russia"

class_name Dress extends RefCounted
## What a unit wears in a mission: its kit and uniform by the kit its scene gives it.
static func kit(dress: StringName, base: StringName) -> StringName          # unknown dress or base: base
static func uniform(dress: StringName, base: StringName, fallback: Texture2D) -> Texture2D

# UnitVisual._ready: finds the nearest Mission above the unit (none: dress &"") and dresses with
# Dress.kit(dress, kit) and Dress.uniform(dress, kit, uniform).
```

| dress | guard | dynamiter | marksman | prisoner |
|---|---|---|---|---|
| `spain_winter` | kit `guard_winter` (guard + a grey blanket cape), same uniform | kit `dynamiter_winter` (+ brown cape), same uniform | kit `marksman_winter` (+ cape), same uniform | unchanged |
| `russia` | kit `guard_blue`, uniform `guard_blue` | kit `dynamiter_russia`, uniform `dynamiter_russia` | kit `marksman_russia`, uniform `marksman_russia` | unchanged |

- Kits, as pieces in `SoldierGear.KITS` (bone-attached boxes and spheres, as the existing kits):
  - A cape: one box over the back and shoulders on `DEF-spine.003`, about 0.46 × 0.62 × 0.10.
  - `guard_blue`: a helmet with the German flare (the guard's dome in field grey
    `Color(0.33, 0.36, 0.32)` plus a lower, wider skirt ring at the back and sides), a greatcoat
    skirt (a box from the belt to the knee on `DEF-hips`), the slung and held rifle as the
    guard's, and on the upper right sleeve the arm shield: three stacked boxes 0.07 wide, red
    `Color(0.72, 0.10, 0.10)`, yellow `Color(0.92, 0.76, 0.12)`, red, 0.09 high in all.
  - `dynamiter_russia`, `marksman_russia`: a fur cap (a squat sphere `Color(0.38, 0.32, 0.26)` with
    ear flaps), the base kit's weapons and satchel, no beret, neckerchief or flat cap.
- Palettes added to `tools/make_soldier.py` (skin, hair, jacket, trousers, boots, belt):
  `guard_blue` `["#d9a987", "#3a2c20", "#5c6558", "#565f52", "#1e1a17", "#2a221c"]`,
  `dynamiter_russia` `["#c89673", "#1c1a1c", "#e6e8ea", "#dfe2e6", "#4a4038", "#8a7a5c"]`,
  `marksman_russia` `["#d4a482", "#4a3423", "#e2e5e8", "#d9dde2", "#3a2f28", "#7a6a50"]`.
  The script gains `--palettes-only`, which writes every `uniform-*.png` without needing the
  source model; use it to write the three new files.
- `mapgen`: table `DRESS` (default `""`), written as the mission's `dress`.
- The HUD portraits stay as they are (summer dress) in this batch.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_dress.gd
func test_no_dress_changes_nothing() -> void:
	for base in [&"guard", &"dynamiter", &"marksman", &"prisoner"]:
		assert_eq(Dress.kit(&"", base), base)
func test_russia_dresses_guards_in_blue_and_the_pair_in_white() -> void:
	assert_eq(Dress.kit(&"russia", &"guard"), &"guard_blue")
	assert_eq(Dress.kit(&"russia", &"dynamiter"), &"dynamiter_russia")
	assert_true(Dress.uniform(&"russia", &"guard", null).resource_path.ends_with("uniform-guard_blue.png"))
func test_every_dressed_kit_exists() -> void          # each Dress.kit result is a key of SoldierGear.KITS
func test_an_unknown_dress_or_kit_falls_back() -> void
func test_the_arm_shield_is_red_yellow_red_and_nothing_else_is_drawn_on_it() -> void:
	# the three topmost pieces of KITS[&"guard_blue"] on the sleeve bone have the three colours in order
# test_unit_visual.gd
func test_a_unit_outside_any_mission_wears_its_own_kit() -> void          # Review Focus 5
func test_a_guard_in_a_russia_mission_wears_blue() -> void
func test_a_body_in_a_russia_mission_wears_blue() -> void                 # Review Focus 5: kill a guard under a Mission with dress &"russia"
func test_a_guard_in_a_mission_without_dress_is_as_today() -> void        # Review Focus 5
```

- [ ] **Step 2: Run** the two files — expected: fail.
- [ ] **Step 3: Implement**, write the palettes with `uv run --with pillow python3 tools/make_soldier.py --palettes-only`.
- [ ] **Step 4: Run** the two files, then `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at them.** Extend `tools/unit_preview_run.gd` to take a dress as an argument,
  render both dresses, and check by eye: the pair read apart from the guards, the shield is
  legible, nothing floats or clips badly when walking, crawling and aiming.
- [ ] **Step 6: Commit** `feat: winter dress, and the División Azul's field grey`.

---

### Task 5: Teruel

**Files:**
- Modify: `tools/make_powder_map.py`, `src/mission/missions.gd`, `src/mission/history.gd`,
  `docs/superpowers/specs/2026-11-12-historical-campaign-design.md` (the table, if a sentence changes),
  `tests/mission/test_powder_store.gd`, `tests/ui/test_missions.gd`, `tests/mission/test_history.gd`,
  `tests/mission/test_campaign.gd`, `e2e/missions.spec.js`
- Regenerate: `scenes/missions/powder_store.tscn`, `resources/missions/powder_store_land.tres`

**Interfaces:**
- `Missions.LIST[1]` becomes `{ "id": "teruel", "name": "The depot", "place": "Teruel", "date":
  "December 1937", "path": "res://scenes/missions/powder_store.tscn" }`; `ALIASES` gains
  `"powder_store": "teruel"` and `"powder_store_night"` now points to `"teruel"`.
- Map tables: `SEASON="snow"`, `LIGHT="overcast"`, `SNOWFALL=True`, `DRESS="spain_winter"`. The
  land, walls, buildings, guards, target and every *blocking* scatter keep their places, counts
  and seeds, so the navmesh and the patrols do not change; pines become `snow_pine`, olives
  become `birch`, bushes `bare_bush`; grass, wheat, poppies, broom and saplings go.
- `TEXTS`: title "The depot outside Teruel"; `target_name` "Depot"; `objective_text` "Destroy
  the depot"; `destroyed_text` "Depot destroyed"; briefing lines: "Blow up the stores stacked in
  the farm's yard with the Dynamiter's charge.", "Get both of them to the camp fire on the road
  east.", "Lose either one and the mission fails."
- `History`, subject to the source check in Global Constraints
  (https://en.wikipedia.org/wiki/Battle_of_Teruel):

  **before:** "December 1937. The Republic attacks Teruel in falling snow, with no bombardment to
  announce it. A blizzard follows, and the cold goes to eighteen below. The raid on this depot is
  invented."

  **after:** "The town fell to the Republic, and was lost again in February 1938."

- [ ] **Step 1: Update the tests first.**

```gdscript
# test_missions.gd
func test_the_powder_store_is_teruel_now() -> void:
	assert_eq(Missions.id_at(1), "teruel")
	assert_eq(Missions.index_of("powder_store"), 1)
	assert_eq(Missions.index_of("powder_store_night"), 1)
# test_campaign.gd
func test_a_win_stored_under_the_old_id_counts() -> void:        # Review Focus 4
	Campaign.load_from("[\"guadarrama\", \"powder_store\"]")
	assert_true(Campaign.is_won("teruel")); assert_true(Campaign.is_open(2))
# test_powder_store.gd
func test_it_is_winter_at_teruel() -> void:
	assert_eq(mission.season, &"snow"); assert_eq(mission.light, &"overcast")
	assert_true(mission.snowfall); assert_eq(mission.dress, &"spain_winter")
	assert_eq(mission.title, "The depot outside Teruel")
	assert_eq(mission.objectives()[0].hud_text, "Destroy the depot")
# test_history.gd
func test_teruel_has_its_notes() -> void              # before() contains "December 1937" and "invented"; after() is not ""
```

  Existing expectations of "The powder store" texts in `test_powder_store.gd`,
  `test_missions.gd` and `e2e/missions.spec.js` change to the new texts; `?mission=powder_store`
  and `?mission=powder_store_night` are expected to show "The depot outside Teruel" and id `teruel`.
- [ ] **Step 2: Run** `ops/test.sh -gtest=res://tests/mission/test_powder_store.gd,res://tests/ui/test_missions.gd,res://tests/mission/test_campaign.gd,res://tests/mission/test_history.gd` — expected: the new tests fail.
- [ ] **Step 3: Check the notes against the source**, then implement and regenerate.
- [ ] **Step 4: Run** the same files — expected: pass, including the existing powder store tests
  that blow the stack and win. Then `ops/test.sh`.
- [ ] **Step 5: Look at it** in the built game: the farm in snow under an overcast sky, snow
  falling, guards and the pair in capes, the briefing with its note.
- [ ] **Step 6: Commit** `feat: Teruel, December 1937`.

---

### Task 6: Something to take: `Carryable` and `StealObjective`

**Files:**
- Create: `src/mission/carryable.gd`, `src/mission/objectives/steal_objective.gd`
- Modify: `src/units/specialist.gd`, `src/abilities/carry.gd`, `src/player/player_input.gd`,
  `src/ui/briefing.gd` (the `F` line: "Use, take or put down what is next to you. Carry or drop a body (Dynamiter)")
- Test: `tests/mission/test_steal.gd`, `tests/fixtures/flat_post.tscn`, `tests/player/test_player_input.gd`, `tests/abilities/test_abilities.gd`

**Interfaces:**
- Consumes: `Interactable`, `Objective`, `MissionRules.is_at_extraction` (batch 1).
- Produces:

```gdscript
class_name Carryable extends Interactable       # prompt set per mission, e.g. "You have the orders"
signal taken(by: Specialist)
signal put_down(at: Vector3)
@export var label := "Orders"                   # what the HUD and marker call it
var carrier: Specialist                         # null while it lies somewhere
func interact(user: Specialist) -> void         # picks it up: refused if user.holding != null or user.carrying != null
func drop() -> void                             # lies down at the carrier's feet; usable again
# while carried: hidden where it lay; a small satchel mesh rides on the carrier's back; usable = false
# the carrier dying drops it where they fell

# Specialist
var holding: Carryable                          # the thing in hand, or null

class_name StealObjective extends Objective
@export var item: NodePath                      # a Carryable, from the mission
@export var carry_text := "Bring it out"        # the HUD line once it is in hand
# done (latched) when a living specialist holding the item is at the extraction.
# never fails. marker_position(): the item while it lies, the extraction while it is carried.
# current_hud_text(): hud_text while it lies anywhere, carry_text while carried.
# save_state adds "carrier": id or "", "pos": [x, y, z]. state_ok checks both, and that the
# carrier is "" or one of the mission's living specialists.
# validate(): the item exists, and a specialist can stand within its reach (the nearest navmesh
# point to it is closer than `reach`, and reachable from the spawn).
```

- `Carry.can_use` is false while `user.holding != null` (refusal text through the existing
  refusal path: "hands full").
- `PlayerInput`: on `F`, in this order: a thing in reach is used (as now); else if the selected
  specialist holds something it is put down; else the carry ability runs.

- [ ] **Step 1: Build the fixture** `tests/fixtures/flat_post.tscn`: a flat 60 × 60 m mission,
  two spawns, three far guards, an open-fronted hut with a `Carryable` on a table inside, an
  extraction 15 m away, `Objectives/Steal`.
- [ ] **Step 2: Write the failing tests.**

```gdscript
# test_steal.gd
func test_the_fixture_is_a_sound_mission() -> void
func test_f_next_to_it_takes_it() -> void:
	assert_eq(item.carrier, dyn); assert_eq(dyn.holding, item); assert_false(item.usable)
func test_it_cannot_be_taken_from_beyond_reach() -> void
func test_the_marksman_can_take_it_too() -> void
func test_f_again_puts_it_down_at_their_feet() -> void
func test_it_can_be_taken_up_again_by_the_other() -> void
func test_the_carrier_can_still_crawl_and_use_the_knife() -> void
func test_the_carrier_cannot_lift_a_body_and_f_puts_the_orders_down_instead() -> void   # Review Focus 2
func test_with_empty_hands_the_next_f_lifts_the_body() -> void                          # Review Focus 2
func test_someone_carrying_a_body_cannot_take_it() -> void
func test_the_carrier_dying_drops_it_where_they_fell() -> void
func test_carried_to_the_extraction_with_both_there_the_mission_is_won() -> void
func test_the_carrier_there_without_the_other_is_not_a_win() -> void                    # Review Focus 3
func test_lying_inside_the_extraction_it_is_not_a_win() -> void                         # Review Focus 3
func test_the_words_and_the_pointer_follow_it() -> void     # hud "Take the orders" / marker at the item; then carry_text / the extraction; then back when dropped
func test_validator_wants_it_within_reach_of_somewhere_to_stand() -> void
func test_state_round_trips_through_json() -> void
func test_load_from_before_it_was_taken_puts_it_back() -> void                          # Review Focus 1
func test_load_from_while_carried_puts_it_back_in_hand() -> void                        # Review Focus 1
func test_a_save_naming_a_dead_or_unknown_carrier_is_refused() -> void
# test_abilities.gd
func test_carry_is_refused_with_something_in_hand() -> void
```

- [ ] **Step 3: Run** `ops/test.sh -gtest=res://tests/mission/test_steal.gd,res://tests/abilities/test_abilities.gd,res://tests/player/test_player_input.gd` — expected: fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** the same, then `ops/test.sh` — expected: all passing.
- [ ] **Step 6: Commit** `feat: something to take and carry out`.

---

### Task 7: The Volkhov map

**Files:**
- Create: `tools/make_volkhov_map.py`; generated `scenes/missions/volkhov.tscn`, `resources/missions/volkhov_land.tres`
- Modify: `tools/mapgen.py` (objective kind `steal`), `src/mission/missions.gd`, `src/mission/history.gd`,
  the spec's table if a sentence changes, `README.md`
- Test: `tests/mission/test_volkhov.gd`, `tests/ui/test_missions.gd`, `tests/mission/test_history.gd`

**Interfaces:**
- `mapgen` objective: `{"kind": "steal", "item": (x, z), "ground": h, "label": "Orders", "hud":
  "Take the orders from the command post", "carry": "Bring the orders back across the river",
  "marker": "Command post", "prompt": "You have the orders", "done": "The orders are out"}`,
  written as an `Item` node (`Carryable`) at the mission's root and `Objectives/Steal`.
- `Missions.LIST` gains, last: `{ "id": "volkhov", "name": "The orders", "place": "Volkhov
  front", "date": "Winter 1941–42", "path": "res://scenes/missions/volkhov.tscn" }`.
- `History` for `volkhov`, subject to the source check
  (https://en.wikipedia.org/wiki/Blue_Division and the list of Spaniards fallen in the Soviet army
  already in the spec's table):

  **before:** "Winter 1941–42. The División Azul, Spanish volunteers serving as the German army's
  250th Infantry Division, holds a stretch of the Volkhov front. Spanish Republicans in exile in
  the Soviet Union served in its guerrilla and sabotage units in this war, and some died fighting
  near Leningrad. This raid is invented: the two of you in Soviet service now, and Spaniards on
  the other side of the snow."

  **after:** "The División Azul stayed on the Volkhov until August 1942, when it was moved to
  the siege lines south of Leningrad."

**The place** (110 m west–east, 90 m north–south; `SEASON="snow"`, `LIGHT="dusk"`,
`SNOWFALL=True`, `DRESS="russia"`, `NODE="Volkhov"`, seven guards):

- The frozen river runs north to south through the middle, about 12 m of flat ice (`ICE`),
  between low banks. Ice is open ground: nothing on it hides anyone.
- West bank: birch and snow-laden pine wood. The pair start in the south-west of it; the
  extraction is a dug-out in the wood in the north-west, with a camp fire.
- East bank: a hamlet of four log houses (`style` `log`) held by the División Azul. The command
  post is the largest, enterable, set back from the river; the orders lie on its table. Around
  it: a sandbagged machine-gun post on the bank looking over the ice, a field kitchen (a
  `SETTLEMENT` prop made of plain shapes: a wheeled boiler with a chimney), stacked firewood, a
  sledge, a telephone line on poles running east out of the map, lamps at the command post and
  the kitchen.
- Three ways over: straight across the ice in front of the post (short, in full view); the
  timber footbridge at the north end, with a sentry on it; and the south, where the river
  narrows between drifted hummocks and fallen trees that give cover to someone lying down.
- Guards: one at the machine-gun post on a short beat along the bank, one on the footbridge, one
  walking the hamlet's street, one round the command post whose beat goes behind the house and
  out of sight of its door, one at the kitchen, one on the east road, one on the bank south of
  the hamlet whose beat stops short of the hummocks.
- A quiet way has to exist as on Carchuna: on the belly, more than six metres from every beat,
  from the start to the command post's door by the southern crossing, with at most one sentry to
  time.
- `TEXTS`: title "The orders"; briefing lines: "Cross the frozen river and take the orders from
  the command post (F at the table).", "Bring them back across the river to the dug-out. F puts
  them down; whoever holds them cannot carry a body.", "Lose either one and the mission fails."

- [ ] **Step 1: Write the failing tests** in `tests/mission/test_volkhov.gd`:

```gdscript
func test_validator_passes() -> void
func test_it_is_a_winter_dusk_with_seven_guards_in_blue() -> void:
	assert_eq(mission.season, &"snow"); assert_eq(mission.light, &"dusk"); assert_false(mission.night)
	assert_eq(mission.dress, &"russia"); assert_eq(mission.guards().size(), 7)
func test_the_objective_is_to_steal_the_orders() -> void:
	assert_true(mission.objectives()[0] is StealObjective); assert_eq(mission.objectives().size(), 1)
func test_navmesh_is_well_inside_the_path_search_limit() -> void      # < 2500 polygons
func test_the_ice_can_be_walked_bank_to_bank() -> void                # a straight nav path across at three places, each < 1.3 x the straight distance
func test_each_way_over_reaches_the_command_post_door() -> void       # ice, footbridge, southern crossing
func test_the_orders_can_be_reached_and_taken() -> void               # a specialist put at the table: Interactable.nearest is the item
func test_nobody_sees_the_start_in_the_first_twenty_seconds() -> void # live guards, alarm stays 0, all on PATROL
func test_no_searchlight_and_no_watchtower_by_dusk() -> void
```

  and the list and history tests: `Missions.LIST.size() == 4`, order `guadarrama, teruel,
  carchuna, volkhov`; `History.before("volkhov")` contains "invented".
- [ ] **Step 2: Run** — expected: fail, no scene.
- [ ] **Step 3: Check the notes against their sources**, extend `mapgen`, write the tables,
  generate, and iterate with `tools/map_preview.gd` until the place reads as described.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at it in the game:** the wood, the ice from both banks, the hamlet, the
  command post looked into, at 1280×720.
- [ ] **Step 6: Commit** `feat: the Volkhov, winter 1941–42`.

---

### Task 8: The Volkhov can be won unseen, and crossing the ice upright is caught

**Files:**
- Create: `tests/run/volkhov_bot.gd`, `tests/run/test_volkhov_run.gd`
- Modify: `tools/make_volkhov_map.py` if the map needs tuning (tables only, never the rules)

- [ ] **Step 1: Write the tests.**

```gdscript
func test_stealth_play_wins() -> void:
	assert_eq(bot.rules.result, MissionRules.Result.WON, bot.summary())
	assert_lt(bot.elapsed, VolkhovBot.CAP)                         # CAP := 420.0 game seconds
	assert_false(bot.noticed, "no guard left its patrol at any time")
	assert_eq(bot.max_alarm, 0)
	assert_eq(bot.dynamiter.hp, bot.dynamiter.stats.max_hp)
	assert_eq(bot.marksman.hp, bot.marksman.stats.max_hp)
	assert_true(bot.orders_taken)
func test_walking_across_the_ice_is_caught() -> void:
	assert_gt(bot.max_alarm, 0)
```

- [ ] **Step 2: Run** — expected: fail, no bot.
- [ ] **Step 3: Write the bot** on the pattern of `tests/run/carchuna_bot.gd`, using only a
  player's orders (`move_to`, `set_stance`, `Interactable.nearest(...).interact(...)`).
- [ ] **Step 4: Run** `tests/run/test_volkhov_run.gd` three times and `ops/test.sh` once —
  expected: the same result each time, all passing.
- [ ] **Step 5: Commit** `test: the Volkhov is won unseen and the open ice is not`.

---

### Task 9: Final checks and ship

**Files:**
- Modify: `e2e/missions.spec.js`, `e2e/perf.spec.js`, `e2e/briefing.spec.js`, `README.md`, `CREDITS.md` if anything came from outside

- [ ] **Step 1: Browser tests.** `e2e/perf.spec.js` runs on the four missions with their guard
  counts (5, 6, 7, 7). `e2e/missions.spec.js`: `?mission=teruel`, `?mission=powder_store` and
  `?mission=volkhov` load with no console errors and report the right id and title. The briefing
  test that expects three missions expects four.
- [ ] **Step 2: Run** `ops/test.sh`, then `ops/build-web.sh && npx playwright test --trace off` —
  expected: all passing, 30 fps or better on each mission.
- [ ] **Step 3: Look at every screen once**, driving the real game scene: Teruel and the Volkhov
  from briefing to win, the orders taken and put down, a loss on each; at 1280×720 and 1920×1080.
- [ ] **Step 4: README**: the mission list, the `season`, `light` and `dress` tables, the steal
  objective and `F`.
- [ ] **Step 5: Commit**, merge `campaign-batch-2` into `main`, push, deploy with `ops/deploy-fly.sh`.
- [ ] **Step 6: Check the live site**: `?mission=volkhov` and `?mission=teruel` load and start
  with no console errors; a clean profile opens on Guadarrama with the rest locked.
