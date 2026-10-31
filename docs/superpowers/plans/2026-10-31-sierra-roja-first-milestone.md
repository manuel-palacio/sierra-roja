# Sierra Roja First Milestone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one playable browser mission in which two guerrilla specialists blow up a railway bridge past three guards and escape.

**Architecture:** A Godot 4 project with low-poly 3D and a fixed isometric camera. Rules (perception, guard states, mission rules) run without any display code, so GUT tests them headlessly. Display code only reads state and listens to signals.

**Tech Stack:** Godot 4.7.2 (Compatibility renderer, single-threaded web export), GDScript, GUT 9.6.1, Playwright, Node 26.

**Spec:** `docs/superpowers/specs/2026-10-31-sierra-roja-design.md`

## Global Constraints

- Desktop browser, mouse and keyboard only. No touch controls and no Mac app.
- No original Commandos maps, art, audio, text or names. Characters are fictional.
- No fascist or Condor Legion symbols in this milestone.
- Every asset in the repo has a redistributable licence and a line in `CREDITS.md`.
- Performance: target 60 fps, minimum 30 fps, with every guard active in the web build.
- Display code never changes game state, except through unit orders.
- Keep every script focused on one job. Use signals upward, method calls downward.

## Review Focus

1. Bridge blows up on the same frame a specialist dies: the mission is lost, because loss takes priority (Task 8).
2. Saving while a charge is ticking or a body is being carried: loading restores the remaining fuse and the carrier (Task 11).
3. The browser tab loses focus: the game pauses and edge-scroll stops (Task 9).
4. The Dynamiter dies while carrying a body: the body drops where they fell and stays discoverable (Task 7).
5. Both specialists reach extraction before the bridge blows: nothing happens until it does, and they must still be there (Task 8).

## Tuning values

The spec leaves these open. All live in `.tres` resources so they can change without code. Height values are metres, speeds are m/s and times are seconds.

| Value | Setting |
|---|---|
| Walk / run / crawl speed | 3 / 6 / 1.2 |
| Vision near range / far range / half-angle | 6 / 14 / 40° |
| Far range after an alarm | 18 |
| Eye height / target height standing / crawling | 1.6 / 1.5 / 0.3 |
| Far-zone time to raise alarm | 1.5 |
| Alarm stand-down after losing sight | 30 |
| Noise radius: run / pistol / rifle / explosion | 8 / 20 / 35 / 80 |
| Knife range / carry-pickup range / plant range | 1.5 / 1.5 / 2 |
| Charge fuse / blast radius | 10 / 8 |
| Rifle shots / pistol shots | 5 / 8 |
| Rifle / pistol range | 40 / 15 |
| Hit points, all units | 100 |
| Damage: rifle / pistol / guard rifle | 100 / 50 / 34 |
| Guard fire interval / range | 1.5 / 14 |

The spec doesn't say guards shoot, but "lose if a specialist dies" needs it. Guards in ALARM fire at any specialist they can see within range. Pause lets the player move the camera only, not give orders.

**Hotkeys:** `1`/`2` select, `C` stand/crawl, `Q` knife, `E` main ability (charge or rifle), `R` pistol, `F` pick up/drop, `Space` pause, `O` quick save, `L` quick load. Browsers reserve F5 and Ctrl+S, so those aren't used.

## File structure

```
project.godot, export_presets.cfg, CREDITS.md, .gitignore, package.json
addons/gut/                 GUT 9.6.1, vendored
src/core/stats.gd           UnitStats resource (speeds, hit points, ammo)
src/core/noise_bus.gd       Autoload NoiseBus, signal noise_emitted(pos, radius)
src/mission/mission.gd      Mission root: lists spawns, routes, objectives, extraction
src/mission/mission_validator.gd
src/mission/mission_rules.gd
src/units/unit.gd           Base CharacterBody3D
src/units/specialist.gd, guard.gd, body.gd
src/abilities/ability.gd, knife.gd, charge.gd, rifle.gd, pistol.gd, carry.gd
src/abilities/planted_charge.gd
src/perception/vision.gd    Pure zone maths
src/perception/perception.gd
src/ai/guard_brain.gd
src/player/player_input.gd, iso_camera.gd
src/ui/hud.gd, vision_overlay.gd, end_screen.gd
src/save/save_game.gd       Autoload SaveGame
scenes/main.tscn, scenes/units/*.tscn, scenes/missions/bridge.tscn
tests/unit/*, tests/mission/*, tests/run/*
web/shell.html              Export shell with the WebGL2 message
e2e/smoke.spec.js, e2e/perf.spec.js
ops/serve.sh, ops/com.sierraroja.serve.plist, ops/build-web.sh
```

**Test command** (`T` below): `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

---

### Task 1: Toolchain and web smoke test

**Files:**
- Create: `project.godot`, `export_presets.cfg`, `.gitignore`, `CREDITS.md`, `addons/gut/`, `scenes/main.tscn`, `web/shell.html`, `ops/build-web.sh`, `package.json`, `e2e/smoke.spec.js`, `tests/unit/test_smoke.gd`

**Interfaces:**
- Produces: command `T`; `ops/build-web.sh` writes `build/web/index.html`.

- [ ] **Step 1: Install Godot.** Run `brew install --cask godot`. Check that `godot --version` starts with `4.7.2`.
- [ ] **Step 2: Install export templates.** Download `Godot_v4.7.2-stable_export_templates.tpz` from the official `godotengine/godot` release, then unpack its `templates/` contents into `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.
- [ ] **Step 3: Create the project.** Set renderer `gl_compatibility`, main scene `scenes/main.tscn`, and a web export preset named `Web` with thread support off and the custom shell `web/shell.html`. Ignore `.godot/`, `build/` and `node_modules/`.
- [ ] **Step 4: Vendor GUT 9.6.1 and add the smoke test.** `test_smoke.gd` contains `assert_true(true)`. Run `godot --headless --path . --import`, then `T`. Expected: 1 passing, exit 0. GUT 9.6.1 hasn't been checked against Godot 4.7.2 yet; if it fails to load, stop and report.
- [ ] **Step 5: Write the failing browser test.** `e2e/smoke.spec.js` serves `build/web/` and asserts no console errors and that a `canvas` is visible. A second test uses `addInitScript` to make `getContext('webgl2')` return null, and asserts the text `This game needs WebGL2`.
- [ ] **Step 6: Implement the shell and build script.** `ops/build-web.sh` runs `godot --headless --path . --export-release "Web" build/web/index.html`. `shell.html` checks WebGL2 before starting the engine.
- [ ] **Step 7: Run it.** Run `ops/build-web.sh && npx playwright test e2e/smoke.spec.js`. Expected: both pass.
- [ ] **Step 8: Commit.** `chore: set up Godot, GUT and web smoke test`

### Task 2: Mission scene and validator

**Files:**
- Create: `src/mission/mission.gd`, `src/mission/mission_validator.gd`, `scenes/missions/bridge.tscn`, `src/player/iso_camera.gd`
- Modify: `scenes/main.tscn`
- Test: `tests/mission/test_validator.gd`, `tests/mission/test_bridge.gd`

**Interfaces:**
- Produces: `class_name Mission extends Node3D` with `specialist_spawns() -> Array[Marker3D]`, `guard_spawns() -> Array[Marker3D]`, `patrol_routes() -> Array[Path3D]`, `bridge_target() -> Marker3D`, `extraction() -> Area3D`, `nav_map() -> RID`, `build_nav() -> void`.
- Produces: `MissionValidator.validate(mission: Mission) -> PackedStringArray` (empty means valid).

Build `bridge.tscn` as greybox CSG: a river gorge, a rail bridge, a guard post, a wall line, cover, and an extraction area on the far side from the start. It needs 2 specialist spawns, 3 guard spawns and 3 routes. The bridge stays reachable only past guard sight lines.

- [ ] **Step 1: Write failing tests.** `test_missing_spawn_reported`, `test_empty_route_reported`, `test_unreachable_objective_reported` build small broken missions and assert the matching error text. `test_bridge_valid` loads `bridge.tscn`, calls `build_nav()`, and asserts an empty result.
- [ ] **Step 2: Run `T`.** Expected: FAIL, `Mission` not defined.
- [ ] **Step 3: Implement.** `build_nav` calls `bake_navigation_mesh(false)` at runtime, since the web build has no threads. Reachable means `NavigationServer3D.map_get_path` ends within 1 m of the target. `main.tscn` loads the mission, validates it, and in debug calls `push_error` then `get_tree().quit(1)` if invalid.
- [ ] **Step 4: Implement `IsoCamera`.** Orthographic, yaw 45°, pitch -35°. Takes `pan(delta: Vector2)` and `zoom_by(step: int)`, with zoom sizes 15 to 40, clamped to the mission bounds.
- [ ] **Step 5: Run `T`.** Expected: all pass, including baking navigation headlessly.
- [ ] **Step 6: Commit.** `feat: add bridge mission and validator`

### Task 3: Units

**Files:**
- Create: `src/core/stats.gd`, `src/units/unit.gd`, `src/units/specialist.gd`, `src/units/body.gd`, `scenes/units/specialist.tscn`, `scenes/units/body.tscn`, `resources/dynamiter.tres`, `resources/marksman.tres`
- Test: `tests/unit/test_unit.gd`

**Interfaces:**
- Consumes: `Mission.nav_map()`.
- Produces: `class_name Unit extends CharacterBody3D` with `enum Stance { STANDING, CRAWLING }`, `stance`, `hp`, `alive: bool`, `move_to(target: Vector3, run := false)`, `stop()`, `set_stance(s: Stance)`, `take_damage(amount: int)`, `save_state() -> Dictionary`, `load_state(d: Dictionary)`, and signals `died(unit)` and `arrived(unit)`.
- Produces: `Specialist extends Unit` with `abilities: Dictionary`. `Body extends Node3D` with `found: bool`, `carried_by: Specialist`.

- [ ] **Step 1: Write failing tests.** `test_walk_speed` moves 3 m/s ±10%. `test_crawl_cannot_run`: a run order while crawling moves at 1.2. `test_unreachable_goes_to_nearest` ends within 1 m of the closest nav point. `test_dead_ignores_orders`. `test_running_emits_noise` emits radius 8 on `NoiseBus`. `test_save_load_roundtrip`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement, including `NoiseBus` as an autoload.** Use `NavigationAgent3D`. Running emits noise every 0.5 s.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Commit.** `feat: add units with movement and stance`

### Task 4: Perception

**Files:**
- Create: `src/perception/vision.gd`, `src/perception/perception.gd`, `resources/guard_vision.tres`
- Test: `tests/unit/test_vision.gd`, `tests/unit/test_perception.gd`

**Interfaces:**
- Consumes: `Unit`, `NoiseBus`.
- Produces: `Vision.zone(eye: Vector3, forward: Vector3, target: Vector3, stance: Unit.Stance, far_range: float) -> Vision.Zone`, where `enum Zone { NONE, FAR, NEAR }`. Pure, with no scene tree. A crawling target in the far zone returns `NONE`.
- Produces: `Perception.sees(guard: Unit, target: Node3D, target_height: float) -> Vision.Zone` adds the line-of-sight ray on the world collision layer. `Perception.polygon(guard: Unit, far_range: float, rays := 24) -> PackedVector3Array` gives the overlay shape, clipped by walls.

- [ ] **Step 1: Write failing tests.** Assert `NEAR` for standing and crawling at 5 m ahead, `FAR` standing at 10 m, `NONE` crawling at 10 m, `NONE` at 15 m, `NONE` at 90° off-axis, `FAR` standing at 16 m with `far_range` 18. Physics tests assert a wall gives `NONE`, a low wall hides a crawler but not a stander, and a target on a platform above the guard's sight line behind an edge gives `NONE`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Use the eye and target heights from the tuning table. Physics tests await `wait_physics_frames(2)`.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Commit.** `feat: add vision zones and line of sight`

### Task 5: Guards and guard AI

**Files:**
- Create: `src/units/guard.gd`, `src/ai/guard_brain.gd`, `scenes/units/guard.tscn`
- Test: `tests/unit/test_guard_brain.gd`

**Interfaces:**
- Consumes: `Perception`, `NoiseBus`, `Unit`, `Body`, `Mission.patrol_routes()`.
- Produces: `class_name GuardBrain extends RefCounted` with `enum State { PATROL, SUSPICIOUS, INVESTIGATE, ALARM }`, `state`, `alerted: bool`, `tick(delta: float, sight: Vision.Zone, target_pos: Vector3, body_seen: bool)`, `hear(pos: Vector3)`, `save_state()`, `load_state(d)`, signals `state_changed(state)`, `alarm_raised(pos)`.
- Produces: `Guard extends Unit` with `brain: GuardBrain`, `current_far_range() -> float` (14, or 18 once `alerted`). It sees all specialists, reports the strongest zone, follows the route, and fires in ALARM.

`GuardBrain` holds decisions only and has no scene access, so it can be tested with no scene tree.

| From | Trigger | To |
|---|---|---|
| any | `NEAR`, or `body_seen`, or `alarm_raised` by another guard | ALARM |
| PATROL | `FAR` | SUSPICIOUS (stop, face target) |
| SUSPICIOUS | `FAR` for 1.5 s in total | ALARM |
| SUSPICIOUS | no sight for 3 s | INVESTIGATE last position |
| PATROL, SUSPICIOUS | `hear(pos)` | INVESTIGATE `pos` |
| INVESTIGATE | arrived, 4 s with no sight | PATROL |
| ALARM | no sight for 30 s | PATROL, `alerted = true` |

- [ ] **Step 1: Write failing tests.** One test per table row, plus `test_alert_persists_after_stand_down`, `test_guards_share_alarm`, `test_noise_outside_radius_ignored`, `test_dead_guard_does_nothing`, `test_stuck_guard_picks_next_waypoint` (no progress for 3 s advances the waypoint), `test_guard_fires_every_1_5s_in_alarm_with_sight`, `test_guard_does_not_fire_without_sight`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Vision checks run every 0.1 s per guard, staggered, not every frame. A body counts once: set `Body.found` when seen.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Add guards to `bridge.tscn` and commit.** `feat: add guard AI state machine`

### Task 6: Performance check

**Files:**
- Create: `e2e/perf.spec.js`, `src/core/perf_probe.gd`

**Interfaces:**
- Produces: `window.sierraPerf() -> {fps: number, frames: number}`, exposed through `JavaScriptBridge` when the URL has `?perf=1`, averaged over the last 10 s.

This is the spec's main technical risk, so it runs before more game is built on top.

- [ ] **Step 1: Write the test.** `e2e/perf.spec.js` loads the build with `?perf=1`, waits 20 s with all guards patrolling, then logs fps and asserts `fps >= 30`. Note in the file that headless Chromium may use software WebGL, so the logged figure is a floor rather than a final answer.
- [ ] **Step 2: Implement the probe and run.** Run `ops/build-web.sh && npx playwright test e2e/perf.spec.js`. Expected: pass, with fps logged.
- [ ] **Step 3: If it fails,** apply the spec's order: simplify the map and lighting, then reduce vision check frequency. If still below 30, stop and report to Manuel.
- [ ] **Step 4: Commit.** `test: add web performance check`

### Task 7: Abilities

**Files:**
- Create: `src/abilities/ability.gd`, `knife.gd`, `charge.gd`, `planted_charge.gd`, `rifle.gd`, `pistol.gd`, `carry.gd`
- Test: `tests/unit/test_abilities.gd`

**Interfaces:**
- Consumes: `Unit`, `Specialist`, `Guard`, `Body`, `NoiseBus`.
- Produces: `class_name Ability extends RefCounted` with `can_use(user: Specialist, target: Variant) -> bool`, `use(user: Specialist, target: Variant) -> void`, `ammo: int` (-1 means unlimited), `save_state()`, `load_state(d)`.
- Produces: `PlantedCharge extends Node3D` with `fuse_left: float`, signal `detonated(pos: Vector3)`. On detonating it deals lethal damage to all units within 8 m, including specialists, and emits noise radius 80.
- Dynamiter: knife, charge, pistol, carry. Marksman: rifle, pistol. A killed guard is replaced by a `Body` at its position.

- [ ] **Step 1: Write failing tests.** `test_knife_kills_in_range_silently` (no noise), `test_knife_out_of_range_refused`, `test_rifle_kills_and_makes_noise_35`, `test_rifle_stops_at_zero_ammo`, `test_rifle_blocked_by_wall`, `test_pistol_two_shots_to_kill_noise_20`, `test_charge_detonates_after_10s`, `test_blast_kills_nearby_specialist`, `test_carry_moves_body_with_carrier`, `test_carrying_forces_walk`, `test_marksman_has_no_carry`, `test_dropped_body_stays_discoverable`, `test_carrier_death_drops_body_where_they_fell`, `test_dead_user_cannot_use_ability`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Carrying forces walking speed; it adds tension and isn't a spec conflict. Ranges and shots come from the tuning table.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Commit.** `feat: add specialist abilities`

### Task 8: Mission rules

**Files:**
- Create: `src/mission/mission_rules.gd`
- Modify: `src/mission/mission.gd`
- Test: `tests/unit/test_mission_rules.gd`

**Interfaces:**
- Consumes: `Unit.died`, `PlantedCharge.detonated`, `GuardBrain.alarm_raised`, `Mission.extraction()`, `Mission.bridge_target()`.
- Produces: `class_name MissionRules extends Node` with `enum Result { RUNNING, WON, LOST }`, `result`, `bridge_destroyed: bool`, `alarm_level: int` (guards in ALARM), signals `result_changed(result)`, `bridge_blown()`, `save_state()`, `load_state(d)`.

The bridge is destroyed when a charge detonates within 8 m of `bridge_target`; the bridge mesh then swaps to a broken version.

- [ ] **Step 1: Write failing tests.** `test_win_needs_bridge_and_both_at_extraction`, `test_extraction_before_bridge_does_not_win`, `test_win_after_bridge_when_already_waiting`, `test_leaving_extraction_clears_presence`, `test_specialist_death_loses`, `test_death_and_bridge_same_frame_is_loss`, `test_charge_far_from_bridge_does_not_count`, `test_result_is_final_after_won_or_lost`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Evaluate results once per frame, checking loss first.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Commit.** `feat: add mission win and loss rules`

### Task 9: Player input

**Files:**
- Create: `src/player/player_input.gd`
- Modify: `src/player/iso_camera.gd`
- Test: `tests/unit/test_player_input.gd`

**Interfaces:**
- Consumes: `Unit` orders, `Ability`, `IsoCamera`.
- Produces: `PlayerInput` with `selected: Specialist`, `select(s: Specialist)`, `armed_ability: StringName`, and signal `selection_changed(s)`, `paused_changed(paused: bool)`.

- [ ] **Step 1: Write failing tests** using synthetic `InputEvent`s and a helper for mouse picking. `test_click_moves_selected`, `test_double_click_runs`, `test_keys_select_1_2`, `test_c_toggles_stance`, `test_armed_ability_targets_next_click`, `test_ability_on_invalid_target_refused`, `test_dead_cannot_be_selected`, `test_space_pauses_and_blocks_orders`, `test_camera_moves_while_paused`, `test_focus_lost_pauses_and_stops_edge_scroll`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Hotkeys come from the tuning section. Double-click window 0.3 s, edge-scroll margin 16 px. Set camera and input `process_mode` to `ALWAYS`. Handle `NOTIFICATION_APPLICATION_FOCUS_OUT` for auto-pause. When the mouse leaves the window, edge-scroll stops.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Commit.** `feat: add player input and camera controls`

### Task 10: HUD and overlays

**Files:**
- Create: `src/ui/hud.gd`, `src/ui/vision_overlay.gd`, `src/ui/end_screen.gd`, `scenes/ui/hud.tscn`
- Test: `tests/unit/test_hud.gd`

**Interfaces:**
- Consumes: `PlayerInput`, `MissionRules`, `Perception.polygon`, `Guard.current_far_range`, `SaveGame` (from Task 11, connected there).
- Produces: `VisionOverlay.show_for(guard: Guard)`, `hide_overlay()`. The HUD reads state only.

Clicking a guard with no ability armed shows their cone: near zone red, far zone yellow. Show one guard at a time. The HUD shows two portraits with health, the ability bar with ammo, the alarm level, a pause indicator and messages. The end screen shows `Mission complete` or `Mission failed` with a Restart button.

- [ ] **Step 1: Write failing tests.** `test_ammo_label_updates`, `test_alarm_label_updates`, `test_end_screen_shows_on_result`, `test_restart_reloads_mission`, `test_overlay_polygon_clipped_by_wall`, `test_overlay_hides_on_guard_death`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Rebuild the overlay mesh at most 10 times a second.
- [ ] **Step 4: Run `T` and the browser smoke test.** Expected: pass. Save a screenshot to `build/e2e/hud.png` and look at it to check the cones draw on the map.
- [ ] **Step 5: Commit.** `feat: add HUD and vision cone overlay`

### Task 11: Quick save and load

**Files:**
- Create: `src/save/save_game.gd`
- Modify: `src/mission/mission.gd`
- Test: `tests/unit/test_save_game.gd`

**Interfaces:**
- Consumes: `save_state()` and `load_state()` on units, brains, abilities, charges and rules.
- Produces: autoload `SaveGame` with `const VERSION := 1`, `quick_save(mission: Mission) -> Error`, `quick_load(mission: Mission) -> Error`, `signal message(text: String)`. Stored as JSON at `user://quicksave.json`, which Godot maps to browser IndexedDB on the web.

- [ ] **Step 1: Write failing tests.** `test_roundtrip_positions_hp_ammo`, `test_roundtrip_guard_state_and_alerted`, `test_roundtrip_active_charge_fuse`, `test_roundtrip_carried_body_keeps_carrier`, `test_roundtrip_dead_guard_stays_body`, `test_load_without_save_shows_message`, `test_corrupt_json_offers_restart`, `test_old_version_offers_restart`, `test_load_after_result_clears_end_screen`.
- [ ] **Step 2: Run `T`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Give every saved object a stable id. Load rebuilds dynamic objects (bodies, charges) from the saved data. A bad save shows `This save can't be loaded. Restart the mission?` and leaves the game state unchanged.
- [ ] **Step 4: Run `T`.** Expected: pass.
- [ ] **Step 5: Add a browser check and commit.** `e2e/smoke.spec.js` presses `O`, moves, presses `L`, reloads the page, presses `L`, and asserts no console errors and the `Game loaded` message. Commit `feat: add quick save and load`.

### Task 12: Scripted winning run

**Files:**
- Create: `tests/run/test_bridge_run.gd`, `tests/run/test_bridge_detected.gd`
- Modify: `scenes/missions/bridge.tscn` if the mission turns out unwinnable

**Interfaces:**
- Consumes: the public orders on `Specialist` and `Ability`, plus `MissionRules`.

- [ ] **Step 1: Write the winning run.** A bot crawls past the guards on a fixed route, knifes one guard, hides the body, plants the charge, retreats, and gets both specialists to extraction. Set `Engine.time_scale` to 4. Assert `result == WON` within a 5-minute game-time cap.
- [ ] **Step 2: Write the detection run.** A bot walks straight at a guard post. Assert the guard reaches ALARM and `result == LOST` within the cap.
- [ ] **Step 3: Run `T`.** Fix real bugs at their cause. If the map is unwinnable, change the map and not the rules.
- [ ] **Step 4: Commit.** `test: prove the bridge mission can be won and lost`

### Task 13: Art, audio and hosting

**Files:**
- Create: `assets/`, `ops/serve.sh`, `ops/com.sierraroja.serve.plist`, `README.md`
- Modify: `scenes/units/*.tscn`, `scenes/missions/bridge.tscn`, `CREDITS.md`

**Interfaces:**
- Consumes: unit scenes and `bridge.tscn`, with no script changes.

- [ ] **Step 1: Add placeholder art.** Use Kenney and Quaternius packs, confirming each is CC0 on its source page when downloading. Keep only the files used, and record them in `CREDITS.md`. Mark uniforms with neutral colours and no symbols. Add placeholder sounds for footsteps, shots, explosion and alarm, also CC0.
- [ ] **Step 2: Add `ops/serve.sh`.** It sets `PATH` and `HOME`, then runs `python3 -m http.server 8003 --bind 100.64.0.1 --directory build/web`. Add a KeepAlive plist modelled on `~/Projects/homeradar` serve. Run the script directly and check `curl -sI http://100.64.0.1:8003/index.html` returns 200.
- [ ] **Step 3: Run the full checks.** Run `T && ops/build-web.sh && npx playwright test`. Expected: all pass. Run the perf check again with final art.
- [ ] **Step 4: Commit and push.** `feat: add placeholder art, sound and hosting`. Push if the GitHub repo exists.
- [ ] **Step 5: Hand over to Manuel.** Give him the `launchctl bootstrap` command to load the agent, since Claude can't on this machine. Then send a `tg-notify` with the URL. He then checks fps on the computer he plays on and decides whether the stealth is fun. That finishes items 7 and 8 of the spec's definition of done, and only he can close them.
