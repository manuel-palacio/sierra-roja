class_name Objective
extends Node
## One thing a mission asks for. A mission lists its objectives as the children of its Objectives
## node, in the order the player is told about them; MissionRules asks each whether it is done or
## can no longer be done. What it takes to meet one is the subclass's business.

## The objective has just been met.
signal completed()

## What the HUD says while this is the objective to go for: "Destroy the bridge".
@export var hud_text := ""
## What the pointer calls the place: "Bridge".
@export var marker_name := ""
## Said once when it is met: "Bridge destroyed". "" says nothing.
@export var done_text := ""

var done := false
var failed := false

var _mission: Mission
var _rules: MissionRules


func setup(mission: Mission, rules: MissionRules) -> void:
	_mission = mission
	_rules = rules


## Called by the rules on every evaluation, for objectives that are met by where things are.
func update() -> void:
	pass


## Where the pointer should lead while this is the objective to go for.
func marker_position() -> Vector3:
	return Vector3.ZERO


## Why it can no longer be met, for the player; "" unless it has failed.
func fail_reason() -> String:
	return ""


## What is wrong with this objective as the mission is built; empty when nothing is.
## `from` is where the squad starts.
func validate(_mission_checked: Mission, _map: RID, _from: Vector3) -> PackedStringArray:
	return PackedStringArray()


func complete() -> void:
	if done:
		return
	done = true
	completed.emit()


func save_state() -> Dictionary:
	return { "done": done, "failed": failed }


func load_state(d: Dictionary) -> void:
	done = bool(d["done"])
	failed = bool(d["failed"])


## Whether a saved state is one load_state can take.
func state_ok(d: Variant) -> bool:
	return d is Dictionary and d.get("done") is bool and d.get("failed") is bool
