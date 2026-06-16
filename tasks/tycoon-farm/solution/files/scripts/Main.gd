extends Node2D

const SAVE_PATH := "user://save.json"

var current_screen: Node = null
var save_state: Dictionary = {}
var _scenario: String = ""

func _ready() -> void:
	_parse_args()
	_load_save()
	if _scenario == "farm_default":
		_enter_farm(false)
	elif _scenario == "harvest_ready":
		_enter_farm(true)
	else:
		_enter_title()

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			_scenario = args[i + 1]
			i += 2
			continue
		i += 1

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	t.has_save = save_state.size() > 0
	_swap(t)

func _enter_farm(harvest_ready: bool) -> void:
	var f = preload("res://scripts/Farm.gd").new()
	f.main = self
	f.save_state = save_state
	f.harvest_ready_scenario = harvest_ready
	_swap(f)

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		save_state = parsed

func write_save(state: Dictionary) -> void:
	save_state = state
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(save_state))
	file.close()
