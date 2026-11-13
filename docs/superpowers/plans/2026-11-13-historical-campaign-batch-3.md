# Historical Campaign, Batch 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the campaign: the Ebro, night of 25 July 1938 (silence the bank's sentries before
the boats cross, against a clock), and Krasny Bor, the night before 10 February 1943 (cut the
telephone lines and destroy the artillery store), with the closing note the campaign ends on.

**Architecture:** Two more `Objective` kinds on the types batches 1 and 2 made. `SilenceObjective`
owns a clock and a list of sentries; `CutObjective` owns a list of `CutPoint`s, which are
`Interactable`s that take a few seconds of standing still. Both report through the same HUD line,
marker, validator and save as the others. The maps are two more table files. A handful of small
things the two reviews left open are closed first, because this batch leans on them.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, single-threaded web export), GUT
(`ops/test.sh`), Python 3 map tables (`tools/mapgen.py`), Playwright for the built game.

**Spec:** `docs/superpowers/specs/2026-11-12-historical-campaign-design.md` (Delivery, batch 3:
"Mission 4, the Ebro (silence); mission 6, Krasny Bor (cut and destroy)").

## Global Constraints

- Stealth rules do not change. An alarm failing the Ebro is a rule of that mission's objective,
  not of perception: guards see, hear and react exactly as everywhere else.
- No swastikas or other Nazi symbols.
- Every historical sentence shown in the game is in the spec's "Historical notes" table with its
  source first. Before a note goes into `history.gd`, fetch its source page and check each
  sentence; drop or reword what the page does not say, update the table to match, and give no
  date closer than the source does.
- Maps are authored only as tables in `tools/make_<name>_map.py`.
- Navmesh under 2,500 polygons per mission. 30 fps or better in `e2e/perf.spec.js` on every mission.
- Each task: run the test files it names while working, and the whole `ops/test.sh` before its
  last commit; rerun any test file touched by a late change before committing it.
- Work on branch `campaign-batch-3`; merge to `main` and deploy only in Task 9. If `fly auth
  whoami` fails, merge and push, do not deploy, and say so.

## Review Focus

1. **The clock, the briefing and the pause.** The Ebro's clock must not run while the briefing is
   up or the game is paused, and a quick load puts back the time that was left. (Task 2.)
2. **The last sentry and an alarm in the same moment.** A sentry who dies raising the alarm: if he
   was the last, the objective is met and the mission goes on; if he was not, it is lost. An alarm
   after the last sentry is down never fails it. (Task 2.)
3. **A noisy kill.** A sentry shot with the rifle is down, but the shot is heard, the alarm goes
   up and the mission is lost if any sentry was left; a body found before the last sentry is down
   loses it the same way. (Task 2.)
4. **Cutting interrupted.** Moving off, being killed, or a quick load in the middle leaves the
   line whole and the next try starting from nothing; changing who is selected does not interrupt
   it; two specialists at one pole do not cut it twice as fast or twice. (Task 3.)
5. **Krasny Bor in either order.** Store first then lines, or lines first then store: won only
   with both done and both out; the blast going off next to a pole does not cut its line. (Task 3
   for the rule, Task 7 for the map.)

---

### Task 1: Loose ends this batch stands on

**Files:**
- Modify: `tools/mapgen.py`, `src/mission/mission_rules.gd`, `src/main.gd`, `tools/make_soldier.py`
- Test: `tests/mission/test_mission_rules.gd`, `tests/mission/test_night.gd`, `tests/tools/test_mapgen.py` (new, plain `python3 -m unittest`)

**Interfaces:**
- `mapgen.mission(**tables)` raises `ValueError` naming the table and the value for a `SEASON`
  outside `{"summer", "snow"}`, a `LIGHT` outside `{"dawn", "overcast", "dusk", "predawn"}`, a
  `DRESS` outside `{"", "spain_winter", "russia"}`, and for an objective entry missing a field its
  kind needs.
- `MissionRules.CUT_OFF_TEXT` becomes "The squad is cut off from the extraction point"; a mission
  with a span (`Nav/BridgeDeck` or `Nav/BridgeBroken`) keeps today's words through
  `const BRIDGE_CUT_OFF_TEXT`.
- `main.apply_light()` can be called any number of times with the same result: each lamp's energy
  and range as the scene has them are kept in its metadata on the first call and every preset
  works from those.
- `tools/make_soldier.py --palettes-only` imports only Pillow.

- [ ] **Step 1: Write the failing tests.**

```python
# tests/tools/test_mapgen.py
def test_unknown_season_is_refused(self):      # mission(SEASON="winter") raises ValueError containing "SEASON" and "winter"
def test_unknown_light_and_dress_are_refused(self)
def test_known_values_pass(self)               # the defaults, and snow / dusk / russia
def test_a_rescue_without_a_building_is_refused(self)
```

```gdscript
# test_mission_rules.gd
func test_cut_off_without_a_bridge_does_not_speak_of_one() -> void
func test_cut_off_with_the_bridge_down_says_so() -> void
# test_night.gd
func test_lighting_twice_is_lighting_once() -> void:   # dusk applied twice: lamp energy still 2 x the scene's
```

- [ ] **Step 2: Run** `python3 -m unittest discover -s tests/tools -t .` and the two GUT files — expected: fail.
- [ ] **Step 3: Implement.** Add the `unittest` run to `ops/test.sh` after the GUT run.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing, the Python tests included.
- [ ] **Step 5: Commit** `fix: the map tables refuse what they do not know; lighting twice is lighting once`.

---

### Task 2: `SilenceObjective`

**Files:**
- Create: `src/mission/objectives/silence_objective.gd`
- Modify: `src/mission/mission_rules.gd` (`clock_running`), `src/main.gd` (stops the clock while the briefing is up)
- Test: `tests/mission/test_silence.gd`, `tests/fixtures/flat_bank.tscn`, `tests/ui/test_briefing.gd`

**Interfaces:**
- Produces:

```gdscript
# MissionRules
var clock_running := true          # main sets it false while the briefing is up; objectives with a clock obey it

class_name SilenceObjective extends Objective
const TOO_LATE_TEXT := "The boats came in under the sentries' guns"
const ALARM_TEXT := "The alarm was raised before the boats crossed"
@export var sentries: PackedStringArray     # names of guards under the mission's Guards node
@export var seconds := 300.0                # the clock
var time_left: float                        # starts at `seconds`
func sentries_left() -> int
# done: every named sentry is dead. failed, only while not done: time_left <= 0, or any living
# guard of the mission is in ALARM. Within one evaluation, deaths are counted before alarms.
# The clock runs in _physics_process, only while not done, not failed, the mission RUNNING and
# rules.clock_running.
# current_hud_text(): "Silence the sentries: 3 left. Boats in 4:12" (minutes:seconds, rounded up).
# current_marker_name(): "Sentry"; marker_position(): the living named sentry nearest to the
# first living specialist.
# save_state adds "time_left": float; state_ok wants 0 <= time_left <= seconds.
# validate(): at least one name; every name is a guard of the mission; seconds > 0.
```

- [ ] **Step 1: Build the fixture** `tests/fixtures/flat_bank.tscn`: a flat 60 × 60 m mission,
  two spawns, five guards of which `Guard1`..`Guard3` are the sentries on short beats 20 m apart
  and two stand far off, an extraction, `Objectives/Silence` with `seconds = 60`.
- [ ] **Step 2: Write the failing tests** in `tests/mission/test_silence.gd`:

```gdscript
func test_the_fixture_is_a_sound_mission() -> void
func test_all_three_down_and_it_is_met() -> void
func test_two_down_is_not_enough() -> void
func test_the_clock_runs_out_and_the_mission_is_lost_with_its_reason() -> void:
	assert_eq(rules.loss_reason(), SilenceObjective.TOO_LATE_TEXT)
func test_an_alarm_anywhere_loses_it_at_once() -> void:          # a far guard put in ALARM
	assert_eq(rules.loss_reason(), SilenceObjective.ALARM_TEXT)
func test_an_alarm_after_the_last_sentry_is_down_changes_nothing() -> void      # Review Focus 2
func test_the_last_sentry_dying_in_alarm_still_meets_it() -> void               # Review Focus 2
func test_a_sentry_dying_in_alarm_with_others_left_loses_it() -> void           # Review Focus 2
func test_a_rifle_shot_that_kills_a_sentry_brings_the_alarm_and_the_loss() -> void   # Review Focus 3: live guards, real noise
func test_a_body_found_before_the_last_is_down_loses_it() -> void               # Review Focus 3
func test_the_clock_stands_still_while_the_rules_say_so() -> void:              # Review Focus 1
	rules.clock_running = false   # 120 physics frames: time_left unchanged
func test_the_clock_stands_still_while_the_game_is_paused() -> void             # Review Focus 1
func test_the_clock_stops_once_it_is_met_and_once_the_mission_has_ended() -> void
func test_the_words_count_sentries_and_time() -> void:
	assert_eq(objective.current_hud_text(), "Silence the sentries: 3 left. Boats in 1:00")
func test_the_pointer_leads_to_the_nearest_sentry_still_standing() -> void
func test_time_left_round_trips_and_a_load_puts_it_back() -> void               # Review Focus 1
func test_a_save_with_impossible_time_is_refused() -> void       # negative, more than `seconds`, not a number
func test_validator_wants_sentries_that_exist() -> void
# test_briefing.gd
func test_the_clock_waits_for_the_briefing() -> void:            # main with the briefing up: rules.clock_running false; after begin(): true
```

- [ ] **Step 3: Run** `ops/test.sh -gtest=res://tests/mission/test_silence.gd,res://tests/ui/test_briefing.gd` — expected: fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** the same, then `ops/test.sh` — expected: all passing.
- [ ] **Step 6: Commit** `feat: sentries to silence before a clock runs out`.

---

### Task 3: `CutPoint` and `CutObjective`

**Files:**
- Create: `src/mission/cut_point.gd`, `src/mission/objectives/cut_objective.gd`
- Modify: `src/units/unit.gd` (`is_moving()`), `src/terrain/telegraph_pole.gd` (`drop_wire()`, `raise_wire()`),
  `src/ui/briefing.gd` (the `F` line: "Use, take, put down or cut. Carry or drop a body (Dynamiter)")
- Test: `tests/mission/test_cut.gd`, `tests/fixtures/flat_line.tscn`

**Interfaces:**
- Produces:

```gdscript
class_name CutPoint extends Interactable     # prompt "Cutting the line: stand still"
signal was_cut()
const CUT_SECONDS := 4.0
@export var pole: NodePath                   # the TelegraphPole whose wire goes down, from the mission
var cut := false
var progress := 0.0                          # seconds of cutting so far
var cutter: Specialist                       # who is at it; null when nobody is
func interact(user: Specialist) -> void      # starts cutting if nobody is at it; a second specialist is ignored
func set_cut(value: bool) -> void            # for load: wire down or up, usable to match, nobody cutting
# _physics_process: while there is a cutter: if they are dead, out of reach or moving, the
# cutting stops and progress goes back to 0; else progress += delta; at CUT_SECONDS it is cut:
# usable false, the pole's wire down, was_cut emitted.
# A small junction box is drawn on the pole at chest height so the place can be seen.

class_name CutObjective extends Objective
@export var points: Array[NodePath]          # CutPoints, from the mission
func points_left() -> int
# done when every point is cut. Never fails. current_hud_text(): hud_text + ": 2 left".
# marker_position(): the first point not yet cut. Emits its done_text once.
# save_state adds "cut": [bool, ...] in the order of `points`; progress is not saved.
# validate(): at least one point; each exists; a specialist can stand within reach of each.
```

- Cutting makes no noise and can be done standing or lying. A blast does nothing to a line.

- [ ] **Step 1: Build the fixture** `tests/fixtures/flat_line.tscn`: a flat 60 × 60 m mission, a
  line of four telegraph poles, `CutPoint`s at the second and third, three far guards, an
  extraction, `Objectives/Cut` and, after it, `Objectives/Destroy` with its target 30 m away.
- [ ] **Step 2: Write the failing tests** in `tests/mission/test_cut.gd`:

```gdscript
func test_the_fixture_is_a_sound_mission() -> void
func test_f_at_the_pole_and_four_seconds_still_cuts_it() -> void:
	# 3.9 s: not cut; 4.1 s: cut, usable false, the pole's wire hidden
func test_moving_off_stops_it_and_the_next_try_starts_from_nothing() -> void     # Review Focus 4
func test_an_order_to_move_a_step_within_reach_stops_it_too() -> void            # Review Focus 4
func test_the_cutter_killed_leaves_the_line_whole() -> void                      # Review Focus 4
func test_selecting_the_other_specialist_does_not_stop_it() -> void              # Review Focus 4
func test_a_second_specialist_at_the_same_pole_adds_nothing() -> void            # Review Focus 4: still 4 s, cut once, was_cut once
func test_it_can_be_cut_lying_down() -> void
func test_cutting_makes_no_noise() -> void                # NoiseBus hears nothing in those four seconds
func test_both_cut_and_the_objective_is_met_and_says_so_once() -> void
func test_the_words_count_what_is_left() -> void:
	assert_eq(objective.current_hud_text(), "Cut the telephone lines: 2 left")
func test_a_blast_beside_a_pole_does_not_cut_it() -> void                        # Review Focus 5
func test_lines_then_store_wins() -> void                                        # Review Focus 5
func test_store_then_lines_wins() -> void                                        # Review Focus 5
func test_one_without_the_other_is_not_a_win() -> void                           # Review Focus 5
func test_a_load_in_the_middle_of_cutting_leaves_it_whole_and_idle() -> void     # Review Focus 4
func test_cut_lines_stay_cut_through_a_save_and_a_load() -> void
func test_a_load_from_before_puts_a_cut_line_back_up() -> void
func test_a_save_with_the_wrong_number_of_lines_is_refused() -> void
func test_validator_wants_points_that_can_be_stood_at() -> void
```

- [ ] **Step 3: Run** `ops/test.sh -gtest=res://tests/mission/test_cut.gd` — expected: fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** the same, then `ops/test.sh` — expected: all passing.
- [ ] **Step 6: Commit** `feat: telephone lines to cut`.

---

### Task 4: Water on any side, boats that cross, and the hour before dawn

**Files:**
- Create: `src/terrain/boat_crossing.gd`
- Modify: `tools/mapgen.py` (`WATER`, `CROSSING`), `tools/make_carchuna_map.py` (uses `WATER`), `src/main.gd` (`predawn`)
- Test: `tests/terrain/test_boat_crossing.gd`, `tests/mission/test_night.gd`, `tests/mission/test_carchuna.gd`, `tests/tools/test_mapgen.py`

**Interfaces:**
- Produces:

```python
WATER = (side, edge, level)     # side "north" or "south": still water over everything beyond z = edge
                                # replaces SEA = (edge, level), which stays as an alias for ("south", edge, level)
CROSSING = {"after": "Silence", "boats": [((x0, z0), (x1, z1)), ...], "seconds": 25.0}
```

```gdscript
class_name BoatCrossing extends Node3D
## Launches that set out over the water when an objective is met. Display only.
@export var after: NodePath          # the Objective whose completion starts them, from the mission
@export var seconds := 25.0
var crossing := false
func start() -> void                 # each boat goes from its start to its end over `seconds`; idempotent
func arrive() -> void                # puts them at the far end at once, for a load made after they crossed
```

- `light = &"predawn"` goes with `night = true`: the night as it is, with the ambient light up to
  0.8 and the sky `Color(0.05, 0.07, 0.14)`, so snow reads blue rather than black. Without
  `night` it is dawn.
- Carchuna regenerates byte for byte the same apart from nothing: `SEA` still works.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_boat_crossing.gd
func test_the_boats_wait_until_the_objective_is_met() -> void
func test_they_cross_in_the_time_given_and_stop_at_the_far_bank() -> void
func test_starting_twice_is_starting_once() -> void
func test_arrive_puts_them_across_at_once() -> void
func test_they_stop_nothing_and_nobody() -> void           # no CollisionObject3D under it
# test_night.gd
func test_the_hour_before_dawn_is_night_with_more_to_see_by() -> void
func test_predawn_without_night_is_dawn() -> void
# test_carchuna.gd
func test_the_sea_is_still_where_it_was() -> void          # the Sea node's transform, unchanged
```

```python
# test_mapgen.py
def test_water_to_the_north_lies_north(self)
def test_sea_still_means_water_to_the_south(self)
```

- [ ] **Step 2: Run** them — expected: fail.
- [ ] **Step 3: Implement**, regenerate Carchuna, check `git diff --stat scenes/missions/carchuna.tscn` shows nothing.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Commit** `feat: water on either side, boats that cross it, and the hour before dawn`.

---

### Task 5: The Ebro map

**Files:**
- Create: `tools/make_ebro_map.py`; generated `scenes/missions/ebro.tscn`, `resources/missions/ebro_land.tres`
- Modify: `tools/mapgen.py` (objective kind `silence`), `src/mission/missions.gd`, `src/mission/history.gd`,
  the spec's table if a sentence changes, `README.md`
- Test: `tests/mission/test_ebro.gd`, `tests/ui/test_missions.gd`, `tests/mission/test_history.gd`, `tests/mission/test_campaign.gd`

**Interfaces:**
- `mapgen` objective: `{"kind": "silence", "sentries": ["PostWest", "PostMiddle", "PostEast"],
  "seconds": 300, "hud": "Silence the sentries", "marker": "Sentry", "done": "The bank is quiet:
  the boats are crossing"}`; sentry names are names from the `GUARDS` table, written as the
  guards' node names.
- `Missions.LIST` gains, between `carchuna` and `volkhov`: `{ "id": "ebro", "name": "The
  crossing", "place": "The Ebro", "date": "25 July 1938", "path": "res://scenes/missions/ebro.tscn" }`.
- A stored campaign with `carchuna` and `volkhov` won and no `ebro` keeps both wins; the Volkhov
  is shut until the Ebro is won. (Test in `test_campaign.gd`.)
- `History` for `ebro`, subject to the source check (https://en.wikipedia.org/wiki/Battle_of_the_Ebro):

  **before:** "The night of 24 to 25 July 1938. The Army of the Ebro is about to cross the river
  in boats to attack. It is said that men were sent over ahead of the first wave to deal with the
  sentries on the far bank and make lines fast for the boats. Here the two of you are those men."

  **after:** "The first boats crossed shortly after midnight. The battle that followed was the
  longest of the war and lasted into November." (Keep the second sentence only if the source
  gives it.)

**The place** (110 m west–east, 90 m north–south; `NIGHT=True`, summer, eight guards):

- The river along the whole north side (`WATER = ("north", ...)`), a reedy bank below a low bluff.
  The pair's boat lies drawn up in the reeds in the north-west; they start beside it. The
  extraction is the landing in the middle of the bank where the boats come in, marked by a post
  with a line made fast (plain shapes).
- Three sentry posts on the bluff, west, middle and east, about 30 m apart: each a sandbagged pit
  with a lamp, and one sentry on a beat of some 14 m along the bank past cover (reeds, a wall end,
  a stack of crates) where someone can lie hidden a knife's reach from his path.
- Behind them, 20 m inland and behind walls and an olive grove: a farm that is the company's
  post, with a watchtower whose searchlight sweeps the track between the posts; a corporal who
  walks the track from post to post; two men at the farm; a machine-gun pit on the east road
  with its own man; one man asleep-on-his-feet at the farm gate who does not move.
- The clock: 300 seconds. The quiet way has to be possible in under 240.
- `CROSSING`: four launches from beyond the north edge to the landing, starting when the
  objective is met.
- `TEXTS`: title "The crossing"; briefing lines: "Silence the three sentries on the bank before
  the boats set out. The clock is at the top of the screen.", "Not a shot, not a shout: an alarm
  anywhere before the last of them is down and the boats come in under fire.", "Then both of you
  to the landing. Lose either one and the mission fails."

- [ ] **Step 1: Write the failing tests** in `tests/mission/test_ebro.gd`:

```gdscript
func test_validator_passes() -> void
func test_it_is_a_summer_night_with_eight_guards_and_a_searchlight() -> void
func test_the_objective_is_three_sentries_and_five_minutes() -> void:
	assert_eq(silence.sentries.size(), 3); assert_eq(silence.seconds, 300.0)
	# and each name is a living guard of the mission
func test_the_sentries_stand_apart() -> void               # every pair of sentry beats more than 20 m apart
func test_navmesh_is_well_inside_the_path_search_limit() -> void
func test_the_river_cannot_be_walked() -> void
func test_nobody_sees_the_start_in_the_first_twenty_seconds() -> void
func test_each_post_can_be_walked_to_from_the_start_and_from_the_one_before() -> void
func test_boats_wait_on_the_far_side_until_the_bank_is_quiet() -> void
```

  and: `Missions.LIST` ids are `guadarrama, teruel, carchuna, ebro, volkhov`; the history test
  for `ebro` wants "It is said" in the note before.
- [ ] **Step 2: Run** — expected: fail, no scene.
- [ ] **Step 3: Check the notes against the source**, extend `mapgen`, write the tables,
  generate, iterate with `tools/map_preview.gd`.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at it in the game:** the reeds and the boat, each post, the farm, the clock
  line on the HUD, the boats crossing.
- [ ] **Step 6: Commit** `feat: the Ebro, 25 July 1938`.

---

### Task 6: The Ebro can be won unseen in time, and a shot loses it

**Files:**
- Create: `tests/run/ebro_bot.gd`, `tests/run/test_ebro_run.gd`
- Modify: `tools/make_ebro_map.py` if the map needs tuning (tables only)

- [ ] **Step 1: Write the tests.**

```gdscript
func test_stealth_play_wins_inside_the_clock() -> void:
	assert_eq(bot.rules.result, MissionRules.Result.WON, bot.summary())
	assert_lt(bot.silenced_at, 240.0, "all three down with a minute in hand")
	assert_eq(bot.knifed, 3)
	assert_false(bot.alarm_before_quiet, "no guard reached ALARM before the last sentry was down")
	assert_eq(bot.dynamiter.hp, bot.dynamiter.stats.max_hp)
	assert_eq(bot.marksman.hp, bot.marksman.stats.max_hp)
func test_shooting_the_first_sentry_loses_it() -> void:
	assert_eq(bot.rules.result, MissionRules.Result.LOST)
	assert_eq(bot.rules.loss_reason(), SilenceObjective.ALARM_TEXT)
func test_doing_nothing_loses_it_to_the_clock() -> void:
	assert_eq(bot.rules.loss_reason(), SilenceObjective.TOO_LATE_TEXT)
```

- [ ] **Step 2: Run** — expected: fail, no bot.
- [ ] **Step 3: Write the bot** on the pattern of `tests/run/bridge_bot.gd`'s ambush: lie hidden
  beside a sentry's beat, stand as he draws level with his back turned, knife, carry the body
  into the cover if the corporal's round would find it, on to the next. Only a player's orders.
- [ ] **Step 4: Run** `tests/run/test_ebro_run.gd` three times and `ops/test.sh` once — expected:
  the same result each time, all passing.
- [ ] **Step 5: Commit** `test: the Ebro is won with the knife inside the clock, and lost by a shot`.

---

### Task 7: The Krasny Bor map

**Files:**
- Create: `tools/make_krasny_bor_map.py`; generated `scenes/missions/krasny_bor.tscn`, `resources/missions/krasny_bor_land.tres`
- Modify: `tools/mapgen.py` (objective kind `cut`, table `CUT_POINTS`), `src/terrain/settlement_prop.gd` (a field gun),
  `src/mission/missions.gd`, `src/mission/history.gd`, the spec's table if a sentence changes, `README.md`
- Test: `tests/mission/test_krasny_bor.gd`, `tests/ui/test_missions.gd`, `tests/mission/test_history.gd`

**Interfaces:**
- `mapgen`: `CUT_POINTS = [(line, pole), ...]` (indices into `POLE_LINES`), each written as a
  `CutPoint` at that pole; objective `{"kind": "cut", "hud": "Cut the telephone lines", "marker":
  "Line", "done": "The lines are cut"}` takes every cut point. The mission's `OBJECTIVES` are the
  cut and then a destroy with "Destroy the artillery store" / "Store" / "Store destroyed".
- `Missions.LIST` gains, last: `{ "id": "krasny_bor", "name": "The guns", "place": "Krasny Bor",
  "date": "9 February 1943", "path": "res://scenes/missions/krasny_bor.tscn" }`.
- `History` for `krasny_bor`, subject to the source check (https://en.wikipedia.org/wiki/Battle_of_Krasny_Bor):

  **before:** "The night of 9 February 1943, south of Leningrad. The División Azul holds the line
  at Krasny Bor, and the Red Army is about to try to break the siege here. This raid on its guns
  is invented."

  **after:** "At 06:40 on 10 February the Soviet guns opened on Krasny Bor. By the 15th the
  División Azul reported 3,645 killed or wounded and 300 missing, about three quarters of the men
  it had in the battle. The Red Army's losses were heavy too, and the siege was not broken here.
  Spaniards had fought Spaniards outside Leningrad, six years after the Guadarrama." (Keep each
  sentence only as far as the sources checked give it; the last is the campaign's own.)

**The place** (110 m × 90 m; `SEASON="snow"`, `NIGHT=True`, `LIGHT="predawn"`, `SNOWFALL=True`,
`DRESS="russia"`, eight guards, one watchtower with a searchlight):

- The pair start in a shell-torn birch wood along the south edge; the extraction is a hollow in
  the same wood in the south-east.
- North of it, a battery of the División Azul: three field guns in sandbagged pits in a row
  facing south (a `SETTLEMENT` kind `"gun"` made of plain shapes: trail, shield, barrel, two
  wheels), the artillery store (stacked crates under a tarpaulin, the `TARGET_STACK`) in a
  walled yard behind the middle gun, a log command dug-out, a log bunkhouse, and the telephone
  line running on poles from the dug-out west to east across the back of the position and off the
  map: three of its poles are the cut points, well apart.
- Sentries: one walking the gun line, one at the store's gate, one round the dug-out, one on the
  road behind the line of poles, two in the bunkhouse yard, one in the tower, one on the west
  flank. A quiet way has to exist on the belly to each pole and to within the charge's reach of
  the store.
- `TEXTS`: title "The guns"; briefing lines: "Cut the telephone line at its three marked poles
  (F, and stand still for four seconds).", "Blow up the artillery store with the Dynamiter's
  charge. In any order.", "Then both of you back to the wood. Lose either one and the mission fails."

- [ ] **Step 1: Write the failing tests** in `tests/mission/test_krasny_bor.gd`:

```gdscript
func test_validator_passes() -> void
func test_it_is_snow_before_dawn_with_eight_guards_in_blue_and_a_searchlight() -> void
func test_it_asks_for_three_lines_cut_and_the_store_destroyed() -> void
func test_the_cut_points_stand_apart_and_each_on_a_pole_of_the_line() -> void   # > 15 m apart
func test_navmesh_is_well_inside_the_path_search_limit() -> void
func test_nobody_sees_the_start_in_the_first_twenty_seconds() -> void
func test_a_charge_in_the_yard_destroys_the_store_and_one_at_the_guns_does_not() -> void
func test_the_extraction_can_still_be_reached_once_the_store_is_gone() -> void
func test_it_is_the_last_mission_and_winning_it_goes_back_to_the_list() -> void:
	# the end screen's button reads "Back to the missions" and the note ends the campaign
```

  and: `Missions.LIST` ids are `guadarrama, teruel, carchuna, ebro, volkhov, krasny_bor`.
- [ ] **Step 2: Run** — expected: fail, no scene.
- [ ] **Step 3: Check the notes against the source**, extend `mapgen`, write the tables,
  generate, iterate with `tools/map_preview.gd`.
- [ ] **Step 4: Run** `ops/test.sh` — expected: all passing.
- [ ] **Step 5: Look at it in the game:** the wood, the guns, the store, a marked pole, the dug-out.
- [ ] **Step 6: Commit** `feat: Krasny Bor, the night before`.

---

### Task 8: Krasny Bor can be won unseen up to the blast

**Files:**
- Create: `tests/run/krasny_bor_bot.gd`, `tests/run/test_krasny_bor_run.gd`
- Modify: `tools/make_krasny_bor_map.py` if the map needs tuning (tables only)

- [ ] **Step 1: Write the tests.**

```gdscript
func test_stealth_play_wins() -> void:
	assert_eq(bot.rules.result, MissionRules.Result.WON, bot.summary())
	assert_lt(bot.elapsed, KrasnyBorBot.CAP)                        # CAP := 480.0
	assert_eq(bot.lines_cut, 3)
	assert_false(bot.noticed_before_blast, "no guard left its patrol before the store went up")
	assert_eq(bot.dynamiter.hp, bot.dynamiter.stats.max_hp)
	assert_eq(bot.marksman.hp, bot.marksman.stats.max_hp)
func test_walking_up_to_the_guns_is_caught() -> void:
	assert_gt(bot.max_alarm, 0)
```

- [ ] **Step 2: Run** — expected: fail, no bot.
- [ ] **Step 3: Write the bot**: the three poles on the belly, then the store, the charge, and
  out before it goes; the alarm the blast brings is fair, as on the bridge.
- [ ] **Step 4: Run** `tests/run/test_krasny_bor_run.gd` three times and `ops/test.sh` once —
  expected: the same result each time, all passing.
- [ ] **Step 5: Commit** `test: Krasny Bor is won unseen up to the blast`.

---

### Task 9: Final checks and ship

**Files:**
- Modify: `e2e/missions.spec.js`, `e2e/perf.spec.js`, `e2e/briefing.spec.js`, `README.md`,
  `docs/superpowers/specs/2026-11-12-historical-campaign-design.md` (status: all three batches built)

- [ ] **Step 1: Browser tests.** `e2e/perf.spec.js` on the six missions with their guard counts
  (5, 6, 7, 8, 7, 8). `e2e/missions.spec.js`: `?mission=ebro` and `?mission=krasny_bor` load with
  no console errors and report the right id and title.
- [ ] **Step 2: Run** `ops/test.sh`, then `ops/build-web.sh && npx playwright test --trace off` —
  expected: all passing, 30 fps or better on each mission.
- [ ] **Step 3: Look at every new screen once**, driving the real game scene, at 1280×720 and
  1920×1080: the Ebro's briefing, clock line, a sentry down, the boats crossing, win, both
  losses; Krasny Bor's briefing, a line being cut and cut, the store going up, the win with the
  closing note, a loss; and the briefing's list of six fitting its panel.
- [ ] **Step 4: README**: the six missions, the two new objectives and what `F` does at a pole.
- [ ] **Step 5: Commit**, merge `campaign-batch-3` into `main`, push; deploy with
  `ops/deploy-fly.sh` if the Fly login is good, else stop there and say so.
- [ ] **Step 6: Check the live site** if deployed: each of the six missions loads and starts with
  no console errors; a clean profile opens on Guadarrama with the rest locked.
