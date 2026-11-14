class_name PlayerInput
extends Node
## Turns mouse and keyboard into orders for the selected specialist, and drives the camera zoom
## and the pause. Rules live in Unit and Ability; this only decides which order a click or key is.
##
## Hotkeys: 1/2 select (again: centre the camera on them), 3 select both, C stance, Q knife, E main ability (charge, else rifle), R pistol,
## F pick up / drop, T stone, Space pause, Escape or right click disarm, O quick save, L quick load,
## Z / X turn the camera a quarter turn.

signal selection_changed(s: Specialist)
signal paused_changed(paused: bool)
signal armed_changed(id: StringName)
## A guard was clicked with nothing armed (the vision cone is shown by whoever listens).
signal guard_clicked(guard: Guard)
signal order_refused(reason: String)
## Something next to a specialist was used with F, and has this to say about it.
signal used(text: String)
## A move order was given: where on the ground, and whether to run. Display hooks listen.
signal move_ordered(pos: Vector3, run: bool)

## Specialist -> the thing they have just put down, until they are ordered to move or lift a
## body: F then lifts a body in reach before it takes that thing up again.
var _just_put_down: Dictionary = {}

const DOUBLE_CLICK_SEC := 0.3
const DOUBLE_CLICK_SLOP := 12.0
const SAVE_REFUSED_TEXT := "Can't save after the mission has ended"
const NO_WAY_TEXT := "Can't get there"
## A click this far (on the ground plane) from anywhere a unit can stand is refused, instead of
## sending the unit to the nearest such place, which may be a long walk round.
const OFF_GROUND_SLACK := 1.5

enum Mode {
	GUARD,  ## Arms; the next click must hit a guard.
	SPOT,   ## Acts at the user's feet if usable, else arms and takes a ground click.
	CARRY,  ## Acts on key press: drops the carried body or lifts the nearest one in range.
}

## Ability id -> how its key behaves.
const MODES := {
	&"knife": Mode.GUARD,
	&"pistol": Mode.GUARD,
	&"rifle": Mode.GUARD,
	&"charge": Mode.SPOT,
	&"carry": Mode.CARRY,
	&"stone": Mode.SPOT,
}
## Key -> ability ids, first one the selected specialist has wins.
const ABILITY_KEYS := {
	KEY_Q: [&"knife"],
	KEY_E: [&"charge", &"rifle"],
	KEY_R: [&"pistol"],
	KEY_F: [&"carry"],
	KEY_T: [&"stone"],
}
const SELECT_KEYS := { KEY_1: 0, KEY_2: 1 }
const SELECT_BOTH_KEY := KEY_3
## How far apart two specialists ordered to the same spot end up.
const SIDE_BY_SIDE := 1.4
## Key -> quarter turns of the camera.
const ROTATE_KEYS := { KEY_Z: -1, KEY_X: 1 }

## The specialist abilities belong to; with both selected, the one selected first.
var selected: Specialist
## Move and stance orders go to every living specialist, not only `selected`.
var both_selected := false
var armed_ability := &""
## Set by main from MissionRules.result_changed; false after a win or loss.
var orders_enabled := true
## Screen position -> { "collider", "position" } (see Picker). Replaceable for tests.
var picker := Callable()
## Seconds; replaceable for tests.
var clock := func() -> float: return Time.get_ticks_msec() / 1000.0

var _mission: Mission
var _camera: IsoCamera
var _specialists: Array[Specialist] = []
var _last_click_time := -INF
var _last_click_pos := Vector2.ZERO


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	move_ordered.connect(func(_pos: Vector3, _run: bool) -> void: _just_put_down.clear())


func setup(cam: IsoCamera, specialists: Array[Specialist]) -> void:
	_camera = cam
	_specialists = specialists
	for s in specialists:
		s.died.connect(_on_specialist_died)
	if not picker.is_valid():
		picker = func(pos: Vector2) -> Dictionary: return Picker.pick(_camera, pos)
	if not specialists.is_empty():
		select(specialists[0])


## The mission O and L save and load.
func bind_mission(mission: Mission) -> void:
	_mission = mission
	mission.state_loaded.connect(_on_state_loaded)


## Everyone a move or stance order goes to now.
func selected_units() -> Array[Specialist]:
	var out: Array[Specialist] = []
	if selected == null:
		return out
	out.append(selected)
	if both_selected:
		for s in _specialists:
			if s != selected and s.alive:
				out.append(s)
	return out


## Puts every living specialist under the same move and stance orders.
func select_both() -> void:
	if selected == null or both_selected:
		return
	both_selected = true
	selection_changed.emit(selected)


func select(s: Specialist) -> void:
	if s != null and not s.alive:
		return
	if s == selected and not both_selected:
		return
	both_selected = false
	selected = s
	_set_armed(&"")
	selection_changed.emit(s)


func is_paused() -> bool:
	return get_tree().paused


func set_paused(value: bool) -> void:
	if get_tree().paused == value:
		return
	get_tree().paused = value
	paused_changed.emit(value)


func _unhandled_input(event: InputEvent) -> void:
	handle_event(event)


## Public so tests can drive it with synthetic events.
func handle_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)
	elif event is InputEventMouseButton and event.pressed:
		_on_mouse_button(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# Focus in never unpauses: the player decides when to resume.
		set_paused(true)


func _on_key(event: InputEventKey) -> void:
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return
	var key := event.keycode
	if key == KEY_SPACE:
		set_paused(not is_paused())
	elif key == KEY_ESCAPE:
		_set_armed(&"")
	elif ROTATE_KEYS.has(key):
		# Looking round is always allowed: paused, and after the mission has ended.
		_camera.rotate_by(ROTATE_KEYS[key])
	elif key == KEY_O:
		# Saving works paused, but not after a result: that would overwrite the only save with the
		# ended mission. Loading works any time, so a lost mission can go back to that save.
		if _mission != null:
			if orders_enabled:
				SaveGame.quick_save(_mission)
			else:
				_refuse(SAVE_REFUSED_TEXT)
	elif key == KEY_L:
		if _mission != null:
			SaveGame.quick_load(_mission)
	elif SELECT_KEYS.has(key) and is_paused() and SELECT_KEYS[key] < _specialists.size() \
			and _specialists[SELECT_KEYS[key]] == selected:
		# Finding the selected specialist is looking, not ordering: allowed while paused.
		_camera.centre_on(selected.global_position)
	elif SELECT_KEYS.has(key):
		if _can_order():
			var index: int = SELECT_KEYS[key]
			if index < _specialists.size():
				if _specialists[index] == selected and not both_selected:
					_camera.centre_on(selected.global_position)
				else:
					select(_specialists[index])
	elif key == SELECT_BOTH_KEY:
		if _can_order():
			select_both()
	elif key == KEY_C:
		if _can_order():
			var stance := Unit.Stance.CRAWLING if selected.stance == Unit.Stance.STANDING \
					else Unit.Stance.STANDING
			for unit in selected_units():
				unit.set_stance(stance)
	elif key == KEY_F and (_use_what_is_near() or _put_down()):
		pass
	elif ABILITY_KEYS.has(key):
		_press_ability(ABILITY_KEYS[key])


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom_by(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom_by(-1)
		MOUSE_BUTTON_RIGHT:
			_set_armed(&"")
		MOUSE_BUTTON_LEFT:
			if _can_order():
				_on_left_click(event.position)


func _on_left_click(pos: Vector2) -> void:
	var hit: Dictionary = picker.call(pos)
	if armed_ability != &"":
		_use_armed(hit)
		return
	var collider: Object = hit.get("collider")
	if collider is Specialist:
		select(collider)
	elif collider is Guard:
		guard_clicked.emit(collider)
	elif hit.has("position"):
		_move_selected(hit["position"], pos)


func _move_selected(target: Vector3, screen_pos: Vector2) -> void:
	if not _can_stand_near(target):
		_refuse(NO_WAY_TEXT)
		return
	var now: float = clock.call()
	var double := now - _last_click_time <= DOUBLE_CLICK_SEC \
			and screen_pos.distance_to(_last_click_pos) <= DOUBLE_CLICK_SLOP
	_last_click_time = -INF if double else now
	_last_click_pos = screen_pos
	var units := selected_units()
	# The others stop beside the first, across the way it is going.
	var way := target - selected.global_position
	var across := Vector3(-way.z, 0.0, way.x).normalized() if Vector2(way.x, way.z).length() > 0.1 else Vector3.RIGHT
	for i in units.size():
		units[i].move_to(target + across * SIDE_BY_SIDE * i, double)
	move_ordered.emit(target, double)


func _can_stand_near(target: Vector3) -> bool:
	if _mission == null:
		return true
	var map := _mission.nav_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return true
	var nearest := NavigationServer3D.map_get_closest_point(map, target)
	return Vector2(nearest.x - target.x, nearest.z - target.z).length() <= OFF_GROUND_SLACK


## F, first of all, uses a thing in reach of whoever is selected: with both, the nearer of them.
## True when something was used, and the key has then done its work.
func _use_what_is_near() -> bool:
	if not _can_order():
		return false
	var user: Specialist = null
	var thing: Interactable = null
	for unit in selected_units():
		var near := Interactable.nearest(get_tree(), unit)
		if near != null and near == _just_put_down.get(unit) and _body_in_reach(unit):
			# Put down a moment ago to free the hands for the body lying here: the body is next.
			continue
		if near != null and (thing == null or near.global_position.distance_to(unit.global_position)
				< thing.global_position.distance_to(user.global_position)):
			user = unit
			thing = near
	if thing == null:
		return false
	thing.interact(user)
	if thing.prompt != "":
		used.emit(thing.prompt)
	return true


## F, next: a selected specialist with something in hand puts it down. True when one did.
func _put_down() -> bool:
	if not _can_order():
		return false
	for unit in selected_units():
		if unit.holding != null:
			_just_put_down[unit] = unit.holding
			unit.holding.drop()
			return true
	return false


## Whether this specialist could lift a body from where they stand.
func _body_in_reach(unit: Specialist) -> bool:
	if not unit.has_ability("carry"):
		return false
	var carry: Ability = unit.abilities["carry"]
	for node in get_tree().get_nodes_in_group(Body.GROUP):
		if carry.can_use(unit, node):
			return true
	return false


## What pressing the ability's key does; the HUD's ability buttons call this.
func arm_ability(id: StringName) -> void:
	_press_ability([id])


func _press_ability(ids: Array) -> void:
	if not _can_order():
		return
	var id := &""
	for candidate in ids:
		if selected.has_ability(candidate):
			id = candidate
			break
	if id == &"" and both_selected:
		# With both selected the key goes to whoever has something on it.
		for unit in selected_units():
			for candidate in ids:
				if id == &"" and unit.has_ability(candidate):
					id = candidate
					select(unit)
	if both_selected and id != &"":
		select(selected)
	if id == &"":
		_refuse("no ability on this key")
		return
	var ability: Ability = selected.abilities[String(id)]
	if ability.ammo == 0:
		_refuse("out of ammo")
		return
	if not ability.ready_to_use():
		_refuse("not ready yet")
		return
	match MODES[id]:
		Mode.GUARD:
			_set_armed(&"" if armed_ability == id else id)
		Mode.SPOT:
			if ability.can_use(selected, null):
				ability.use(selected, null)
				_set_armed(&"")
			else:
				_set_armed(id)
		Mode.CARRY:
			# The HUD's button does all that the F key does.
			if not (_use_what_is_near() or _put_down()):
				_press_carry(ability)


func _press_carry(ability: Ability) -> void:
	if selected.carrying != null:
		ability.use(selected, null)
		return
	var nearest: Body
	var best := INF
	for node in get_tree().get_nodes_in_group(Body.GROUP):
		var body := node as Body
		var d := selected.global_position.distance_to(body.global_position)
		if body.carried_by == null and d < best:
			best = d
			nearest = body
	if nearest != null and ability.can_use(selected, nearest):
		ability.use(selected, nearest)
		_just_put_down.erase(selected)
	else:
		_refuse("no body in reach")


func _use_armed(hit: Dictionary) -> void:
	var ability: Ability = selected.abilities[String(armed_ability)]
	var target: Variant = null
	match MODES[armed_ability]:
		Mode.GUARD:
			target = hit.get("collider")
		Mode.SPOT:
			target = hit.get("position")
	if target != null and ability.can_use(selected, target):
		ability.use(selected, target)
		_set_armed(&"")
	else:
		_refuse("invalid target")


func _can_order() -> bool:
	if not orders_enabled or is_paused():
		return false
	return selected != null and selected.alive


func _set_armed(id: StringName) -> void:
	if armed_ability != id:
		armed_ability = id
		armed_changed.emit(id)


func _refuse(reason: String) -> void:
	order_refused.emit(reason)


## Keeps the selection if its specialist lives in the loaded state, else picks a living one.
func _on_state_loaded() -> void:
	_set_armed(&"")
	both_selected = false
	if selected != null and selected.alive:
		return
	selected = null
	for s in _specialists:
		if s.alive:
			select(s)
			return
	selection_changed.emit(null)


func _on_specialist_died(unit: Unit) -> void:
	both_selected = false
	if unit != selected:
		selection_changed.emit(selected)
		return
	selected = null
	for s in _specialists:
		if s.alive:
			select(s)
			return
	_set_armed(&"")
	selection_changed.emit(null)
