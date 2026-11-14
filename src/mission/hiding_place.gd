class_name HidingPlace
extends Interactable
## Somewhere to put a body, or yourself, out of sight: a haystack, the back of a truck. F next to
## it, carrying a body, leaves the body inside, where no guard finds it. F with empty arms hides
## the specialist, who is then seen by nobody and can do nothing until F, or an order to move,
## brings them out. It holds one of each. Nobody gets in while a guard is suspicious or alarmed.
##
## It keeps no state of its own: who and what is inside is read from where they are, so a save
## needs only the hidden flags of the specialists and the bodies.

const HINT_RANGE := 5.0
const HINT_HEIGHT := 3.0
const HIDE_TEXT := "F: hide"
const LEAVE_TEXT := "F: come out"
const HIDDEN_TEXT := "Hidden. F, or a move, to come out"
const BODY_HIDDEN_TEXT := "The body is hidden"
const BODY_FULL_TEXT := "There is a body in there already"
const FULL_TEXT := "There is no room in there"
const WATCHED_TEXT := "Not while they are looking"

var _hint: Label3D


func _init() -> void:
	reach = 2.7


func _ready() -> void:
	super()
	_hint = Label3D.new()
	_hint.font = UiStyle.FONT
	_hint.font_size = 64
	_hint.pixel_size = 0.012
	_hint.outline_size = 16
	_hint.modulate = UiStyle.BRASS_BRIGHT
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = true
	_hint.shaded = false
	_hint.position = Vector3(0, HINT_HEIGHT, 0)
	_hint.visible = false
	add_child(_hint)


func _process(_delta: float) -> void:
	var near := false
	for node in get_tree().get_nodes_in_group(Specialist.GROUP):
		var s := node as Specialist
		if s.alive and _flat(s.global_position) <= HINT_RANGE:
			near = true
	_hint.visible = near
	if near:
		_hint.text = tr(LEAVE_TEXT if occupant() != null else HIDE_TEXT)


## The specialist hidden here, or null.
func occupant() -> Specialist:
	for node in get_tree().get_nodes_in_group(Specialist.GROUP):
		var s := node as Specialist
		if s.alive and s.hidden and _flat(s.global_position) <= reach + 0.5:
			return s
	return null


## The body hidden here, or null.
func body() -> Body:
	for node in get_tree().get_nodes_in_group(Body.GROUP):
		var b := node as Body
		if b.hidden and _flat(b.global_position) <= 1.0:
			return b
	return null


func interact(user: Specialist) -> void:
	if user.hidden:
		user.hidden = false
		prompt = ""
	elif user.carrying != null:
		if body() != null:
			prompt = BODY_FULL_TEXT
			return
		var carried := user.carrying
		user.drop_body()
		carried.global_position = global_position
		carried.hidden = true
		prompt = BODY_HIDDEN_TEXT
	elif occupant() != null:
		prompt = FULL_TEXT
	elif _watched():
		prompt = WATCHED_TEXT
	else:
		user.hidden = true
		prompt = HIDDEN_TEXT


## A guard has noticed something: it is too late to get in unseen.
func _watched() -> bool:
	for node in get_tree().get_nodes_in_group(Guard.GROUP):
		var guard := node as Guard
		if guard.alive and guard.brain != null \
				and guard.brain.state in [GuardBrain.State.SUSPICIOUS, GuardBrain.State.ALARM]:
			return true
	return false


func _flat(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
