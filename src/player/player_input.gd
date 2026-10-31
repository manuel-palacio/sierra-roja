class_name PlayerInput
extends Node
## Turns mouse and keyboard into orders for the selected specialist, and drives the camera zoom
## and the pause. Rules live in Unit and Ability; this only decides which order a click or key is.
##
## Hotkeys: 1/2 select, C stance, Q knife, E main ability (charge, else rifle), R pistol,
## F pick up / drop, Space pause, Escape or right click disarm. O and L belong to save/load.

signal selection_changed(s: Specialist)
signal paused_changed(paused: bool)
signal armed_changed(id: StringName)
## A guard was clicked with nothing armed (the vision cone is shown by whoever listens).
signal guard_clicked(guard: Guard)
signal order_refused(reason: String)

const DOUBLE_CLICK_SEC := 0.3
const DOUBLE_CLICK_SLOP := 12.0

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
}
## Key -> ability ids, first one the selected specialist has wins.
const ABILITY_KEYS := {
	KEY_Q: [&"knife"],
	KEY_E: [&"charge", &"rifle"],
	KEY_R: [&"pistol"],
	KEY_F: [&"carry"],
}
const SELECT_KEYS := { KEY_1: 0, KEY_2: 1 }

var selected: Specialist
var armed_ability := &""
## Set by main from MissionRules.result_changed; false after a win or loss.
var orders_enabled := true
## Screen position -> { "collider", "position" } (see Picker). Replaceable for tests.
var picker := Callable()
## Seconds; replaceable for tests.
var clock := func() -> float: return Time.get_ticks_msec() / 1000.0

var _camera: IsoCamera
var _specialists: Array[Specialist] = []
var _last_click_time := -INF
var _last_click_pos := Vector2.ZERO


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(cam: IsoCamera, specialists: Array[Specialist]) -> void:
	_camera = cam
	_specialists = specialists
	for s in specialists:
		s.died.connect(_on_specialist_died)
	if not picker.is_valid():
		picker = func(pos: Vector2) -> Dictionary: return Picker.pick(_camera, pos)
	if not specialists.is_empty():
		select(specialists[0])


func select(s: Specialist) -> void:
	if s != null and not s.alive:
		return
	if s == selected:
		return
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
	elif SELECT_KEYS.has(key):
		if _can_order():
			var index: int = SELECT_KEYS[key]
			if index < _specialists.size():
				select(_specialists[index])
	elif key == KEY_C:
		if _can_order():
			selected.set_stance(Unit.Stance.CRAWLING if selected.stance == Unit.Stance.STANDING
					else Unit.Stance.STANDING)
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
	var now: float = clock.call()
	var double := now - _last_click_time <= DOUBLE_CLICK_SEC \
			and screen_pos.distance_to(_last_click_pos) <= DOUBLE_CLICK_SLOP
	_last_click_time = -INF if double else now
	_last_click_pos = screen_pos
	selected.move_to(target, double)


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
	if id == &"":
		_refuse("no ability on this key")
		return
	var ability: Ability = selected.abilities[String(id)]
	if ability.ammo == 0:
		_refuse("out of ammo")
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


func _on_specialist_died(unit: Unit) -> void:
	if unit != selected:
		return
	selected = null
	for s in _specialists:
		if s.alive:
			select(s)
			return
	_set_armed(&"")
	selection_changed.emit(null)
