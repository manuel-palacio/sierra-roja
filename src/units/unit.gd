class_name Unit
extends CharacterBody3D
## A mobile character: moves along the navmesh, has a stance, hit points and a noise footprint.
## Rules only; the scene supplies placeholder visuals.

signal died(unit: Unit)
signal arrived(unit: Unit)

enum Stance { STANDING, CRAWLING }

const LAYER_WORLD := 1
const LAYER_UNITS := 2
const NOISE_INTERVAL := 0.5
const VERTICAL_SNAP_SPEED := 10.0

@export var stats: Stats
## When false, run orders are carried out as walking (e.g. while carrying a body).
var can_run := true
var stance: Stance = Stance.STANDING
var hp := 100
var alive := true

var _moving := false
var _running := false
var _noise_timer := 0.0
var _agent: NavigationAgent3D
## The map given with set_nav_map; the unit's height comes from it.
var _nav_map := RID()


func _ready() -> void:
	# Layer 1 is the world; units sit on layer 2 and collide with the world only, so sight
	# rays and nav-bake collision never see them.
	collision_layer = LAYER_UNITS
	collision_mask = LAYER_WORLD
	if stats == null:
		stats = Stats.new()
	hp = stats.max_hp
	_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _agent == null:
		_agent = NavigationAgent3D.new()
		_agent.name = "NavigationAgent3D"
		add_child(_agent)
	_agent.path_desired_distance = 0.3
	_agent.target_desired_distance = 0.3
	_agent.radius = 0.5
	_agent.avoidance_enabled = false


func set_nav_map(map: RID) -> void:
	_nav_map = map
	_agent.set_navigation_map(map)


## Height of the navmesh under the unit, which is where it stands. Its own height when it has been
## given no map, or the map has nothing baked yet.
func ground_y() -> float:
	if not _nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(_nav_map) == 0:
		return global_position.y
	return NavigationServer3D.map_get_closest_point(_nav_map, global_position).y


func move_to(target: Vector3, run := false) -> void:
	if not alive:
		return
	_running = run and can_run and stance == Stance.STANDING
	_moving = true
	_noise_timer = 0.0
	_agent.target_position = target


func stop() -> void:
	_moving = false
	_running = false
	velocity = Vector3.ZERO


func set_stance(s: Stance) -> void:
	stance = s
	if s == Stance.CRAWLING:
		_running = false


func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = maxi(hp - amount, 0)
	if hp == 0:
		alive = false
		stop()
		died.emit(self)


func current_speed() -> float:
	if stance == Stance.CRAWLING:
		return stats.crawl_speed
	return stats.run_speed if _running else stats.walk_speed


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# Height follows the navmesh surface under the unit, on a slope too; speed is measured on the
	# ground plane.
	global_position.y = move_toward(global_position.y, ground_y(), VERTICAL_SNAP_SPEED * delta)
	if not _moving:
		return
	if _agent.is_navigation_finished():
		stop()
		arrived.emit(self)
		return
	var next := _agent.get_next_path_position()
	var flat := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if flat.length() > 0.001:
		var dir := flat.normalized()
		velocity = dir * minf(current_speed(), flat.length() / delta)
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.3)
		# The navmesh keeps units clear of everything solid, so they are moved along it directly:
		# sliding a body over sloping ground fights the height taken from the navmesh.
		global_position += velocity * delta
	if _running and stats.run_noise_radius > 0.0:
		_noise_timer -= delta
		if _noise_timer <= 0.0:
			_noise_timer = NOISE_INTERVAL
			NoiseBus.emit_noise(global_position, stats.run_noise_radius)


## JSON-safe snapshot (no Vector3 or enums) so the save system can write it directly.
func save_state() -> Dictionary:
	var target := _agent.target_position
	return {
		"id": String(name),
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot": rotation.y,
		"stance": int(stance),
		"hp": hp,
		"alive": alive,
		"moving": _moving,
		"running": _running,
		"target": [target.x, target.y, target.z],
		"noise_timer": _noise_timer,
	}


func load_state(d: Dictionary) -> void:
	var p: Array = d["pos"]
	global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(d["rot"])
	stance = int(d["stance"]) as Stance
	hp = int(d["hp"])
	alive = bool(d["alive"])
	stop()
	if bool(d["moving"]):
		var t: Array = d["target"]
		move_to(Vector3(t[0], t[1], t[2]))
		_running = bool(d["running"])
	_noise_timer = float(d["noise_timer"])
