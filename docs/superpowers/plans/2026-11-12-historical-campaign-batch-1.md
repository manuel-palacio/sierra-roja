# Historical Campaign, Batch 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bridge-only rules with a list of objectives, turn the mission row into a
campaign with historical notes, re-frame the bridge as Guadarrama 1937, and add the Fort Carchuna
rescue mission.

**Architecture:** Each mission scene carries an `Objectives/` node of `Objective` children;
`MissionRules` asks them whether they are done or failed and no longer knows what a bridge is. The
HUD, objective marker, validator and save all read from that list. `Missions`, `History` and
`Campaign` are static data and state; the briefing and end screen display them. The rescue adds a
`Prisoner` unit, a `CellDoor` and an `F`-key interaction that later batches reuse.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, single-threaded web export), GUT
for tests (`ops/test.sh`), Python 3 map tables (`tools/mapgen.py`), Playwright for the built game.

**Spec:** `docs/superpowers/specs/2026-11-12-historical-campaign-design.md`

## Global Constraints

- Stealth rules do not change. Game rules do not depend on what is drawn.
- No swastikas or other Nazi symbols anywhere.
- Every historical statement shown in the game appears in the spec's table with its source. The
  note copy in Task 3 is final; do not add facts to it.
- Maps are authored only as tables in `tools/make_<name>_map.py`; never edit a generated `.tscn`
  or `_land.tres` by hand. Regenerate with `python3 tools/make_<name>_map.py`.
- Navmesh must stay well under the 4096-polygon path-search limit (the existing maps sit near 1,400).
- 30 fps or better in `e2e/perf.spec.js` on every mission.
- All existing tests pass or are updated in the same task. `ops/test.sh` must end with no failing
  tests and no script errors before every commit.
- Code comments and identifiers follow the surrounding style: `##` doc comments that say why,
  typed GDScript, `class_name` on every new script.
- Work on branch `campaign-batch-1`; merge to `main` and deploy only in Task 9.

## Review Focus

1. **Quick load across the cell door.** Save before the door is opened, open it, free the
   prisoner, load: the door must be shut again, the navmesh closed, the prisoner back in the cell
   and following nobody. (Test in Task 6.)
2. **A body and the door both in reach of `F`.** The interaction wins over picking up the body,
   and a second press then picks up the body. (Test in Task 5.)
3. **Browser storage that is missing or holds rubbish.** `Campaign` must fall back to "only
   mission 1 open" and must not stop the game. (Test in Task 3.)
4. **A charge in a mission with nothing to destroy.** On Carchuna the Dynamiter still has a
   charge: it must not print "too far from the bridge", and if it kills the prisoner the mission
   fails with the prisoner's own reason. (Tests in Tasks 2 and 6.)
5. **The prisoner at the extraction without the pair.** Not a win until both specialists are
   there too; and both specialists there without him is not a win either. (Test in Task 6.)

---

### Task 1: `Objective` and `DestroyObjective`

**Files:**
- Create: `src/mission/objectives/objective.gd`, `src/mission/objectives/destroy_objective.gd`
- Test: `tests/mission/test_objectives.gd`

**Interfaces:**
- Produces:

```gdscript
class_name Objective extends Node
signal completed()
@export var hud_text := ""      # "Destroy the bridge"
@export var marker_name := ""   # "Bridge"
@export var done_text := ""     # "Bridge destroyed"; "" shows no message
var done := false
var failed := false
func setup(mission: Mission, rules: MissionRules) -> void   # keeps both; hooks signals
func update() -> void                                        # called by rules every evaluation
func marker_position() -> Vector3
func fail_reason() -> String                                 # "" unless failed
func validate(mission: Mission, map: RID, from: Vector3) -> PackedStringArray
func save_state() -> Dictionary                              # base: {"done": bool, "failed": bool}
func load_state(d: Dictionary) -> void
func state_ok(d: Variant) -> bool                            # schema check for its own save_state
func complete() -> void                                      # sets done, emits completed once

class_name DestroyObjective extends Objective
signal charge_too_far()
@export var target: NodePath          # a Marker3D in the mission
@export var blast_range := 8.0
func on_detonated(pos: Vector3) -> void
```

- `DestroyObjective.on_detonated`: if not done and `pos` is within `blast_range` of the target,
  kills every living unit and frees every uncarried body for which `mission.on_span(pos)` is true,
  calls `mission.break_bridge()`, then `complete()`. Outside the range it emits `charge_too_far`.
  (This is the logic now in `MissionRules._on_detonated` and `_drop_whoever_is_on_the_span`; the
  spec's separate `BridgeTarget` class is not needed, because `Mission.break_bridge` already
  serves both the span and a stack of stores.)
- `load_state` on a `DestroyObjective` calls `mission.break_bridge()` or `mission.repair_bridge()`
  to match `done`.
- `validate` reports `"<name>: target is missing"` or `"<name>: target is unreachable from the
  specialist spawn"` (reach test as `MissionValidator._reaches`; make that function public as
  `MissionValidator.reaches`).

- [ ] **Step 1: Write the failing tests** in `tests/mission/test_objectives.gd`, on
  `res://tests/fixtures/flat_bridge.tscn`:

```gdscript
func test_base_objective_completes_once() -> void:
	var o := Objective.new()
	watch_signals(o)
	o.complete(); o.complete()
	assert_true(o.done)
	assert_signal_emit_count(o, "completed", 1)

func test_base_state_round_trips() -> void:
	var o := Objective.new()
	o.complete()
	var p := Objective.new()
	assert_true(p.state_ok(o.save_state()))
	p.load_state(o.save_state())
	assert_true(p.done)
	assert_false(p.state_ok({"done": 1}))

func test_destroy_done_by_a_charge_in_range() -> void:   # objective.on_detonated(target_pos + Vector3(7.9, 0, 0))
	assert_true(objective.done)

func test_destroy_not_done_out_of_range_and_says_so() -> void:   # 8.1 m away
	assert_false(objective.done)
	assert_signal_emitted(objective, "charge_too_far")

func test_destroy_validate_reports_missing_target() -> void:
	objective.target = NodePath("Nowhere")
	assert_eq(objective.validate(mission, mission.nav_map(), Vector3.ZERO).size(), 1)
```

- [ ] **Step 2: Run** `ops/test.sh -gtest=res://tests/mission/test_objectives.gd` — expected: script error, `Objective` not found.
- [ ] **Step 3: Implement both classes** as specified above.
- [ ] **Step 4: Run the same command** — expected: 5 passing.
- [ ] **Step 5: Commit** `feat: objectives a mission can list, starting with destroy`.

---

### Task 2: Rules, mission, HUD, marker, validator and saves read the objective list

**Files:**
- Modify: `src/mission/mission_rules.gd`, `src/mission/mission.gd`, `src/mission/mission_validator.gd`,
  `src/ui/hud.gd`, `src/ui/objective_marker.gd`, `src/ui/briefing.gd`, `src/save/save_schema.gd`,
  `src/save/save_game.gd` (`VERSION := 3`), `tools/mapgen.py`, `tools/map_preview_run.gd`,
  `tests/fixtures/flat_bridge.tscn`, `tests/run/bridge_bot.gd`
- Regenerate: `scenes/missions/*.tscn` via `tools/make_bridge_map.py`, `tools/make_powder_map.py`
- Test: `tests/mission/test_mission_rules.gd`, `tests/mission/test_validator.gd`,
  `tests/unit/test_save_game.gd`, `tests/ui/test_hud.gd`, `tests/ui/test_objective_marker.gd`,
  `tests/mission/test_bridge.gd`, `tests/mission/test_powder_store.gd`, `tests/run/test_bridge_run.gd`

**Interfaces:**
- Consumes: Task 1.
- Produces:

```gdscript
# Mission
func objectives() -> Array[Objective]    # children of the "Objectives" node, in order
@export var title: String                # kept
@export var briefing_lines: PackedStringArray   # renamed from `objectives`
# removed: bridge_target(), target_name, objective_text, destroyed_text

# MissionRules
signal objective_done(objective: Objective)
signal charge_too_far()                  # re-emitted from any DestroyObjective
func objectives_done() -> bool
func current_objective() -> Objective    # first not done; null when all are
func is_at_extraction(unit: Unit) -> bool   # replaces at_extraction(s); any living Unit
const OBJECTIVE_FAILED_FALLBACK := "The objective can no longer be met"
# removed: bridge_destroyed, bridge_blown, BRIDGE_BLAST_RANGE
```

- `MissionRules.evaluate`: lost if a specialist is dead, any objective is `failed`, or the pair is
  cut off; won when `objectives_done()` and every specialist is at the extraction. `update()` is
  called on each objective first. `loss_reason()` returns `DEATH_TEXT`, else the failed
  objective's `fail_reason()` (or the fallback), else `CUT_OFF_TEXT`.
- The cut-off check in `_on_nav_rebaked` runs whenever a navmesh rebake happens with the mission
  running, whatever the objectives are.
- Rules hook every `PlantedCharge` as now and pass `detonated` to each `DestroyObjective`.
- `MissionRules.save_state` → `{"result", "objectives": [each save_state()], "at_extraction": [unit names]}`.
  `SaveSchema._rules_ok` checks the array length equals `mission.objectives().size()` and calls
  each objective's `state_ok`.
- HUD: objective line is `"Objective: " + current_objective().hud_text`, or the existing escape
  text when none is left; on `objective_done` it shows `done_text` if not empty; the
  `charge_too_far` message becomes `"The charge was too far from the target"`.
- `ObjectiveMarker`: points at `current_objective().marker_position()` with `marker_name`, else at
  the extraction.
- `MissionValidator`: `"mission has no objectives"` when the list is empty; otherwise appends each
  objective's `validate(...)`. The `bridge target` checks go.
- `tools/mapgen.py`: new table `OBJECTIVES` (default `None`). `None` writes one destroy objective
  from `TARGET` and `TEXTS` exactly as today's exports describe it, node name `Destroy`, with the
  marker node still named `BridgeTarget`. `TEXTS["objectives"]` is written as `briefing_lines`.
  `tests/fixtures/flat_bridge.tscn` gets the same `Objectives/Destroy` node by hand (it is a
  hand-written fixture, not generated).

- [ ] **Step 1: Update the tests first.** Replace every `rules.bridge_destroyed` with
  `rules.objectives_done()`, `bridge_blown` with `objective_done`, `at_extraction(` with
  `is_at_extraction(`, and add to `tests/mission/test_mission_rules.gd`:

```gdscript
func test_no_objectives_left_and_both_out_wins() -> void
func test_a_failed_objective_loses_with_its_reason() -> void:
	# a stub Objective subclass with failed = true and fail_reason() "The prisoner was killed"
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), "The prisoner was killed")
func test_a_failed_objective_without_a_reason_uses_the_fallback() -> void
func test_two_objectives_need_both() -> void             # one done, both at extraction: still RUNNING
func test_current_objective_is_the_first_not_done() -> void
func test_charge_far_from_every_target_reports_once() -> void
func test_charge_with_no_destroy_objective_reports_nothing() -> void   # Review Focus 4
```

  Add to `tests/mission/test_validator.gd`: `test_mission_without_objectives_is_invalid`. Add to
  `tests/unit/test_save_game.gd`: `test_version_2_save_is_out_of_date` (a dictionary with
  `"version": 2` and `"rules": {"bridge_destroyed": false, ...}` is refused with the existing
  message) and `test_objective_states_round_trip`.
- [ ] **Step 2: Run** `ops/test.sh` — expected: script errors on the removed members.
- [ ] **Step 3: Implement** the changes above, then regenerate the scenes:
  `python3 tools/make_bridge_map.py && python3 tools/make_powder_map.py`.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing, including `test_bridge_run` (the bot
  still wins unseen) and `test_powder_store`.
- [ ] **Step 5: Run the game once** (`ops/build-web.sh && npx playwright test e2e/smoke.spec.js e2e/hud.spec.js --trace off`) — expected: pass.
- [ ] **Step 6: Commit** `refactor: mission rules judge a list of objectives`.

---

### Task 3: `Missions` with dates and aliases, `History`, `Campaign`

**Files:**
- Modify: `src/mission/missions.gd`
- Create: `src/mission/history.gd`, `src/mission/campaign.gd`
- Test: `tests/ui/test_missions.gd` (update), `tests/mission/test_campaign.gd`, `tests/mission/test_history.gd`

**Interfaces:**
- Produces:

```gdscript
# Missions.LIST at the end of this batch. In this task: guadarrama, powder_store, then the two
# night entries as they are (Task 9 removes them). Task 7 inserts carchuna after powder_store.
{ "id": "guadarrama", "name": "The bridge", "place": "Sierra de Guadarrama", "date": "30 May 1937", "path": "res://scenes/missions/bridge.tscn" },
{ "id": "powder_store", "name": "The powder store", "place": "", "date": "", "path": "res://scenes/missions/powder_store.tscn" },
{ "id": "carchuna", "name": "Fort Carchuna", "place": "Granada coast", "date": "23 May 1938", "path": "res://scenes/missions/carchuna.tscn" },
const ALIASES := { "bridge": "guadarrama", "bridge_night": "guadarrama", "powder_store_night": "powder_store" }
static func index_of(id: String) -> int     # resolves aliases; -1 when unknown
static func id_at(index: int) -> String

class_name History extends RefCounted
static func before(id: String) -> String    # "" when the mission has no note
static func after(id: String) -> String
static func sources(id: String) -> PackedStringArray

class_name Campaign extends RefCounted
const STORAGE_KEY := "sierra-roja-campaign"
static func is_open(index: int) -> bool     # index 0 always; else the one before is won
static func is_won(id: String) -> bool
static func mark_won(id: String) -> void    # also writes storage
static func reset() -> void                 # forgets everything, storage included
static func load_from(text: String) -> void # parses stored JSON: an array of ids; anything else = nothing won
```

- Storage: on the web, `localStorage[STORAGE_KEY]` through `JavaScriptBridge.eval`, read once on
  first use, wrapped in `try/catch` on the JavaScript side so a blocked storage yields `""`.
  Elsewhere it is kept in memory only. Unknown ids in the stored array are ignored.
- `History` copy, exact:

  **guadarrama, before:** "30 May 1937. The Republic attacks towards Segovia through the Sierra de
  Guadarrama, to draw Franco's army away from Bilbao. Hemingway set For Whom the Bell Tolls in this
  offensive: a dynamiter sent behind the lines to blow a bridge as the attack begins. The bridge
  here is his, not history's. The Dynamiter and the Marksman are invented too, here and in every
  mission."

  **guadarrama, after:** "The attack reached La Granja and was thrown back within a week. It held
  up the advance on Bilbao by about two weeks."

  **carchuna, before:** "May 1938. 308 Asturian soldiers, taken prisoner when the north fell, are
  held in the fort of Carchuna on the Granada coast, close behind the front. On the 16th four
  officers escaped to the Republican lines and told what they knew. On the 23rd, 35 volunteers,
  five of them from the International Brigades, cross by launch from Castell de Ferro. Here the two
  of you go in ahead of them, and one officer stands for the 308."

  **carchuna, after:** "The raiders took the fort and led the prisoners towards the Republican
  lines in two columns, with an artillery barrage to cover them. Twenty-five chose to stay behind."

  Sources per id are the URLs in the spec's table.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_campaign.gd (before_each: Campaign.reset())
func test_only_the_first_mission_is_open_at_first() -> void:
	assert_true(Campaign.is_open(0)); assert_false(Campaign.is_open(1))
func test_winning_opens_the_next() -> void:
	Campaign.mark_won(Missions.id_at(0))
	assert_true(Campaign.is_open(1)); assert_false(Campaign.is_open(2))
func test_rubbish_in_storage_means_nothing_won() -> void:      # Review Focus 3
	for text in ["", "{", "42", "{\"a\":1}", "[1, null, \"nowhere\"]"]:
		Campaign.load_from(text)
		assert_false(Campaign.is_open(1), text)
func test_stored_wins_are_read_back() -> void:
	Campaign.load_from("[\"guadarrama\"]")
	assert_true(Campaign.is_won("guadarrama"))

# test_missions.gd additions
func test_old_ids_open_the_reframed_missions() -> void:
	assert_eq(Missions.index_of("bridge"), Missions.index_of("guadarrama"))
	assert_eq(Missions.index_of("nowhere"), -1)
	# Task 9 adds the same assertion for bridge_night and powder_store_night.

# test_history.gd
func test_every_note_has_a_source() -> void     # for each id with before() != "": after() != "" and sources().size() >= 1
func test_notes_draw_no_forbidden_claims() -> void:   # guadarrama before() contains "not history's"
```

- [ ] **Step 2: Run** the three test files — expected: fail, classes not found.
- [ ] **Step 3: Implement.** The two night entries stay in `LIST` until Task 9, so only the
  `bridge` alias is added now; the other two aliases are added in Task 9.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Commit** `feat: a campaign that opens mission by mission, with notes from history`.

---

### Task 4: Briefing and end screen show the campaign

**Files:**
- Modify: `src/ui/briefing.gd`, `src/ui/end_screen.gd`, `src/main.gd`, `src/ui/hud.gd` (only where it builds the end screen)
- Test: `tests/ui/test_briefing.gd`, `tests/ui/test_hud.gd`, `e2e/briefing.spec.js`, `e2e/missions.spec.js`

**Interfaces:**
- Consumes: `Missions`, `History`, `Campaign` (Task 3); `Mission.briefing_lines` (Task 2).
- Produces:

```gdscript
# Briefing
var note_label: Label                    # History.before(id); hidden when ""
var mission_buttons: Array[Button]       # text "1  Sierra de Guadarrama, 30 May 1937"; name only when place is ""
func set_mission(mission: Mission, index: int) -> void   # as now, plus note and locks
# a button is disabled when it is the mission shown or when not Campaign.is_open(i)

# EndScreen
var note_label: Label                    # History.after(id) on a win; hidden otherwise
var mission_id := ""
func show_result(result: MissionRules.Result, reason := "") -> void   # unchanged signature
```

- `main.gd`: on `result_changed` to `WON`, `Campaign.mark_won(Missions.id_at(Missions.current))`
  before the end screen shows; `hud.end_screen.mission_id` is set at start. After the last mission
  the next button reads "Back to the missions" and goes to mission 0's briefing.
- The briefing's fixed `SUBTITLE` and `OBJECTIVES` constants go; it shows the mission's own
  `title` and `briefing_lines`.
- Both labels wrap (`autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`) at a width of 640 px so the
  longest note fits a 1280×720 window without covering the Start button.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_briefing.gd
func test_locked_missions_cannot_be_chosen() -> void:      # Campaign.reset(); buttons[1].disabled
func test_won_mission_opens_the_next_button() -> void
func test_note_is_shown_for_a_mission_that_has_one() -> void:
	assert_string_contains(briefing.note_label.text, "30 May 1937")
func test_note_is_hidden_for_a_mission_without_one() -> void   # powder_store
func test_button_names_place_and_date() -> void:
	assert_eq(briefing.mission_buttons[0].text, "1  Sierra de Guadarrama, 30 May 1937")
# test_hud.gd
func test_win_shows_what_really_happened() -> void:
	assert_string_contains(hud.end_screen.note_label.text, "La Granja")
func test_loss_shows_no_note() -> void
```

  In `e2e/briefing.spec.js`: with `?briefing=1` a fresh page shows the Guadarrama note text and
  the second mission button is disabled; after `localStorage.setItem('sierra-roja-campaign',
  '["guadarrama"]')` and a reload it is enabled. With the value `'{'` the page still starts.
- [ ] **Step 2: Run** `ops/test.sh -gdir=res://tests/ui` — expected: the new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `ops/test.sh`, then `ops/build-web.sh && npx playwright test e2e/briefing.spec.js e2e/missions.spec.js --trace off` — expected: pass.
- [ ] **Step 5: Look at it.** Screenshot the briefing and the win screen at 1280×720 and at
  1920×1080 (`deviceScaleFactor: 1`) and check by eye that nothing overlaps or is cut off.
- [ ] **Step 6: Commit** `feat: the briefing lists the campaign and tells each mission's history`.

---

### Task 5: Things to use with `F`, and one group for everyone the guards hunt

**Files:**
- Create: `src/mission/interactable.gd`
- Modify: `src/player/player_input.gd`, `src/units/unit.gd`, `src/units/specialist.gd`,
  `src/units/guard.gd:168`, `src/terrain/searchlight.gd:84`, `src/abilities/planted_charge.gd:52`,
  `src/ui/briefing.gd` (the `F` line of `CONTROLS`: "Use what is next to you; carry or drop a body (Dynamiter)")
- Test: `tests/player/test_player_input.gd`, `tests/perception/test_perception.gd`

**Interfaces:**
- Produces:

```gdscript
class_name Interactable extends Node3D
const GROUP := "interactables"
@export var reach := 1.8
@export var prompt := ""                              # shown by the HUD message line when used
func can_interact(user: Specialist) -> bool           # base: user alive, within reach on the ground plane
func interact(user: Specialist) -> void               # subclasses override
static func nearest(tree: SceneTree, user: Specialist) -> Interactable   # the closest one that can_interact; else null

# Unit
const HUNTED := "hunted"     # everyone a guard reacts to on sight: specialists, and later the prisoner
```

- `PlayerInput`: on `F`, for the selected specialist (either one), `Interactable.nearest` is tried
  first; if it returns something, `interact` is called and nothing else happens. Otherwise the
  existing carry handling runs. With both selected, the Dynamiter is the user.
- `Specialist._ready` adds the unit to `Unit.HUNTED` as well as `Specialist.GROUP`. The three
  listed call sites iterate `Unit.HUNTED` and treat members as `Unit`; nothing else changes.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_player_input.gd
func test_f_uses_the_thing_in_reach() -> void                 # a stub Interactable counts interact() calls
func test_f_ignores_a_thing_out_of_reach() -> void            # 1.9 m away: not used
func test_f_prefers_the_thing_over_a_body_then_takes_the_body() -> void   # Review Focus 2
func test_marksman_can_use_a_thing() -> void
# test_perception.gd
func test_guard_sees_any_hunted_unit() -> void                # a plain Unit added to Unit.HUNTED raises suspicion as a specialist does
```

- [ ] **Step 2: Run** the two files — expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing, the bridge bot run included.
- [ ] **Step 5: Commit** `feat: F uses what is next to you`.

---

### Task 6: `Prisoner`, `CellDoor`, `RescueObjective`

**Files:**
- Create: `src/units/prisoner.gd`, `scenes/units/prisoner.tscn`, `src/terrain/cell_door.gd`,
  `src/mission/objectives/rescue_objective.gd`
- Modify: `src/mission/mission.gd` (`prisoners()`, `rebake_nav_soon()` as the public name of
  `_rebake_next_frame`, save and load), `src/save/save_schema.gd`, `src/mission/mission_rules.gd`
  (extraction membership for any `Unit`), `src/units/soldier_gear.gd` and `tools/make_soldier.py`
  (a `&"prisoner"` kit: bare head, torn grey shirt, no weapon)
- Test: `tests/mission/test_rescue.gd`, `tests/unit/test_save_game.gd`, `tests/fixtures/flat_cell.tscn`

**Interfaces:**
- Consumes: `Objective` (1), rules (2), `Interactable`, `Unit.HUNTED` (5).
- Produces:

```gdscript
class_name Prisoner extends Unit
const GROUP := "prisoners"
const FOLLOW_DISTANCE := 1.5      # where he stands behind the leader
const CATCH_UP := 2.5             # farther than this from the leader, he moves
var leader: Specialist            # null while held
func follow(s: Specialist) -> void
# every physics frame while following: stance = leader.stance; runs when the leader runs;
# if farther than CATCH_UP, move_to a point FOLLOW_DISTANCE behind the leader.
# joins Unit.HUNTED only once he is following; a guard looking into the cell before that ignores him.
# save_state adds "leader": id or ""

class_name CellDoor extends Interactable   # prompt "The cell is open"
signal opened()
var open := false
func interact(user: Specialist) -> void    # opens once: removes its blocker from Nav, asks mission.rebake_nav_soon()
func set_open(value: bool) -> void         # for load; rebakes when it changes
func stand_point() -> Vector3              # 1.2 m outside the door, on the ground

class_name RescueObjective extends Objective
const KILLED_TEXT := "The prisoner was killed"
@export var prisoner: NodePath
@export var door: NodePath
# door.opened -> prisoner.follow(user). update(): failed when the prisoner is dead;
# done when rules.is_at_extraction(prisoner). marker_position(): the door until it is open,
# then the extraction. hud_text is set per mission; after the door opens the HUD reads
# "Bring the prisoner to the extraction point" (property `escort_text`).
# save_state adds "door_open": bool. validate(): prisoner and door exist; door.stand_point()
# is reachable from the spawn; the extraction is reachable from stand_point().
```

- The door's blocker is a `StaticBody3D` on `Unit.LAYER_WORLD` under `Nav/`, as wide as
  `Building.ENTRANCE_WIDTH`, so it blocks sight and is cut from the navmesh like a wall.
- `Mission.save_state` adds `"prisoners": [...]`; `load_state` restores them after the specialists
  and re-attaches leaders by id, then the rules load restores each objective (door included).

- [ ] **Step 1: Build the fixture** `tests/fixtures/flat_cell.tscn`: a flat 40×40 m mission with
  two specialist spawns, three guards far away on short beats, an enterable cell building with a
  `CellDoor` in its doorway, a `Prisoner` inside, an extraction 15 m from the door, and
  `Objectives/Rescue`.
- [ ] **Step 2: Write the failing tests** in `tests/mission/test_rescue.gd`:

```gdscript
func test_prisoner_cannot_be_reached_while_the_door_is_shut() -> void   # no nav path from spawn into the cell
func test_f_at_the_door_opens_it_and_he_follows() -> void:
	assert_true(door.open); assert_eq(prisoner.leader, dynamiter)
func test_door_cannot_be_opened_from_beyond_reach() -> void
func test_he_matches_the_leaders_stance() -> void
func test_he_keeps_up_over_twenty_metres() -> void:      # leader walks 20 m; he ends within CATCH_UP + 0.5
func test_guards_ignore_him_in_the_cell_and_see_him_once_out() -> void
func test_he_reaches_the_extraction_with_both_and_the_mission_is_won() -> void
func test_he_alone_at_the_extraction_is_not_a_win() -> void              # Review Focus 5
func test_both_at_the_extraction_without_him_is_not_a_win() -> void      # Review Focus 5
func test_a_charge_that_kills_him_loses_with_his_reason() -> void:       # Review Focus 4
	assert_eq(rules.loss_reason(), RescueObjective.KILLED_TEXT)
func test_a_charge_far_from_him_says_nothing_about_a_target() -> void    # Review Focus 4
func test_validator_wants_a_door_that_can_be_stood_at() -> void
```

  and in `tests/unit/test_save_game.gd`:

```gdscript
func test_load_from_before_the_door_shuts_it_again() -> void:            # Review Focus 1
	# save; open; walk 5 m; load
	assert_false(door.open); assert_null(prisoner.leader)
	assert_almost_eq(prisoner.global_position, cell_position, Vector3.ONE * 0.1)
	# and after the rebake the cell is unreachable again
func test_load_from_after_keeps_him_following() -> void
```

- [ ] **Step 3: Run** the two files — expected: fail.
- [ ] **Step 4: Implement.** Render the prisoner with `tools/unit_preview.gd` and check by eye
  that he reads apart from guards and specialists.
- [ ] **Step 5: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 6: Commit** `feat: a prisoner to free and bring out`.

---

### Task 7: The Carchuna map

**Files:**
- Create: `tools/make_carchuna_map.py`; generated `scenes/missions/carchuna.tscn`, `resources/missions/carchuna_land.tres`
- Modify: `tools/mapgen.py` (tables `OBJECTIVES`, `SEA`, `PRISONER`), `src/mission/missions.gd` (add the `carchuna` line), `README.md` (mission list, the new table file)
- Test: `tests/mission/test_carchuna.gd`

**Interfaces:**
- Consumes: Tasks 2 and 6.
- Produces, in `mapgen`:

```python
OBJECTIVES = [  # None keeps the single destroy objective
    {"kind": "destroy", "target": (x, y, z), "hud": "...", "marker": "...", "done": "..."},
    {"kind": "rescue", "building": "Cells", "prisoner": (x, z), "hud": "Free the officer",
     "escort": "Bring the officer to the launch", "marker": "Cells"},
]
SEA = (z_shore, level)   # a still water plane over everything south of z_shore; None for no sea
```

  A rescue entry writes a `CellDoor` in the named building's doorway, a `Prisoner` at the given
  point, and `Objectives/Rescue`.

**The place** (west–east 110 m, north–south 90 m, night, `NIGHT=True`, `NODE="Carchuna"`):

- The sea along the south edge; a beach under a low cliff in the south-west where the launch lies
  (a `PLACED` boat shape) and the pair start. The extraction is the launch.
- The fort on a headland in the east: a square of high wall about 30 m a side, gate in the north
  wall, a breach low in the south-west corner above the beach path. Inside: the cells (enterable,
  against the east wall), a barracks, the commandant's house, a yard with a well. A watchtower with
  a searchlight at the north-west corner, sweeping the road and the gate.
- A coast road in from the north-west to the gate, with a sentry box and telegraph line.
- Three ways in: the gate from the road (lit, two guards); the breach from the beach path (one
  crawl-only stretch under the tower's light); round the east side over the rocks to a postern
  (long, one patrol to time).
- Seven guards: two at the gate, one on the road, one walking the yard, one at the cells' door on
  a short beat that turns away, one on the beach path, one on the east rocks.
- Dry coast scatter: agave-like bushes, olives, rocks; no pines, no wheat.
- `TEXTS`: title "Fort Carchuna"; briefing lines: "Get into the fort and open the cells (F at the
  door).", "Bring the officer back to the launch on the beach. He follows whoever freed him and
  does as they do.", "Lose him or either of you and the mission fails."

- [ ] **Step 1: Write the failing tests** in `tests/mission/test_carchuna.gd`:

```gdscript
func test_validator_passes() -> void:
	assert_eq(MissionValidator.validate(mission), PackedStringArray())
func test_it_is_a_night_mission_with_seven_guards_and_a_searchlight() -> void
func test_the_objective_is_a_rescue() -> void:
	assert_true(mission.objectives()[0] is RescueObjective); assert_eq(mission.objectives().size(), 1)
func test_navmesh_is_well_inside_the_path_search_limit() -> void:     # polygon count < 2500
func test_nobody_sees_the_start_or_the_cell_at_the_start() -> void:   # 20 s of play, alarm_level stays 0, no guard leaves patrol
func test_the_sea_cannot_be_walked() -> void                          # a point 5 m south of the shore is off the navmesh
func test_each_way_in_reaches_the_cell_door() -> void                 # nav path from spawn via gate, breach and postern waypoints
```

- [ ] **Step 2: Run** it — expected: fail, no scene.
- [ ] **Step 3: Extend `mapgen`, write the tables, generate**, and iterate with
  `godot --headless --path . -s tools/map_preview.gd -- /tmp/carchuna.png res://scenes/missions/carchuna.tscn`
  until the layout reads as described.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at it in the game.** `ops/build-web.sh`, open `?mission=carchuna`, take
  screenshots of the beach, the breach, the yard and the cells looked into; check by eye for
  floating props, walls through buildings and unreadable darkness.
- [ ] **Step 6: Commit** `feat: Fort Carchuna, May 1938`.

---

### Task 8: Carchuna can be won unseen, and carelessness is caught

**Files:**
- Create: `tests/run/carchuna_bot.gd`, `tests/run/test_carchuna_run.gd`
- Modify: `tests/run/bridge_bot.gd` only to share `FastClock` and the wait helpers (move them to `tests/run/bot_base.gd`); `tools/make_carchuna_map.py` if the map needs tuning

**Interfaces:**
- Consumes: the map (7). The bot uses only what a player has: `move_to`, `set_stance`,
  abilities, and `F` through `Interactable.nearest(...).interact(...)`.

- [ ] **Step 1: Write the tests.**

```gdscript
func test_stealth_play_wins() -> void:
	assert_eq(bot.rules.result, MissionRules.Result.WON, bot.summary())
	assert_lt(bot.elapsed, CarchunaBot.CAP)                       # CAP := 420.0 game seconds
	assert_false(bot.noticed, "no guard left its patrol at any time")
	assert_eq(bot.dynamiter.hp, bot.dynamiter.stats.max_hp)
	assert_eq(bot.marksman.hp, bot.marksman.stats.max_hp)
	assert_true(bot.prisoner.alive)
func test_walking_in_by_the_gate_is_caught() -> void:
	assert_gt(bot.max_alarm, 0)
```

- [ ] **Step 2: Run** — expected: fail, no bot.
- [ ] **Step 3: Write the bot** for the breach route. Where the route cannot be made unseen with
  a player's orders, change the map tables (a guard's beat, a wall, a rock), not the rules, and
  re-run Task 7's tests.
- [ ] **Step 4: Run** `ops/test.sh` three times — expected: all passing each time (the run must
  not be flaky).
- [ ] **Step 5: Commit** `test: Carchuna is won unseen and the gate is not`.

---

### Task 9: Retire the night variants, final checks, ship

**Files:**
- Modify: `src/mission/missions.gd` (drop `bridge_night`, `powder_store_night`; aliases as in Task 3),
  `tools/make_bridge_map.py`, `tools/make_powder_map.py` (drop the night `write`), `tools/map_preview_run.gd`,
  `tests/mission/test_night.gd` (retarget to `carchuna.tscn`), `tests/ui/test_missions.gd`,
  `e2e/missions.spec.js`, `e2e/perf.spec.js`, `README.md`,
  `docs/superpowers/specs/2026-11-12-historical-campaign-design.md` (the `BridgeTarget` sentence, to match Task 1)
- Delete: `scenes/missions/bridge_night.tscn`, `scenes/missions/powder_store_night.tscn`
- Modify: `tools/make_bridge_map.py` `TEXTS["title"]` → "The bridge in the Guadarrama"

- [ ] **Step 1: Update the tests.** `test_missions.gd` asserts that `bridge_night` and
  `powder_store_night` resolve to `guadarrama` and `powder_store`. `test_night.gd` asserts the same things (dark, lamps turned
  up, a searchlight per tower that reacts to a hunted unit) on Carchuna. `e2e/missions.spec.js`:
  `?mission=bridge_night` and `?mission=bridge` both load the Guadarrama title;
  `?mission=carchuna` loads with no console errors. `e2e/perf.spec.js` runs on all three missions.
- [ ] **Step 2: Make the changes**, regenerate the two maps, run `ops/test.sh` — expected: all passing.
- [ ] **Step 3: Run the whole browser suite**
  `ops/build-web.sh && npx playwright test --trace off` — expected: all passing, 30 fps or better
  on each mission.
- [ ] **Step 4: Play Carchuna by hand through the browser tools** from briefing to win screen
  once, and once to a loss by getting the prisoner killed; confirm the notes, the HUD lines, the
  marker and the loss reason read right.
- [ ] **Step 5: Commit** `feat: night belongs to the missions where it was true`, merge
  `campaign-batch-1` into `main`, push, and deploy with `ops/deploy-fly.sh`.
- [ ] **Step 6: Check the live site**: `https://sierra-roja.fly.dev/?mission=carchuna` loads and
  starts; the briefing on a clean profile shows mission 1 open and the others locked.
