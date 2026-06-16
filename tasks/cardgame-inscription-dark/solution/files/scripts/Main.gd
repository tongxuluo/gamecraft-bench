extends Node2D

var current_screen: Node = null
var _scenario: String = ""
var run_state: Dictionary = {"current_node": 0, "deck": [], "scale_player": 0, "scale_opponent": 0}

func _ready() -> void:
	_parse_args()
	if _scenario == "battle1":
		_enter_battle(0)
	elif _scenario == "battle2":
		_enter_battle(1)
	elif _scenario == "event":
		_enter_event()
	elif _scenario == "map":
		_enter_map()
	else:
		_enter_title()

func _parse_args() -> void:
	var args = OS.get_cmdline_user_args()
	var i = 0
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
	_swap(t)

func _enter_map() -> void:
	var m = preload("res://scripts/Map.gd").new()
	m.main = self
	_swap(m)

func _enter_battle(battle_idx: int) -> void:
	var b = preload("res://scripts/Battle.gd").new()
	b.main = self
	b.battle_idx = battle_idx
	_swap(b)

func _enter_event() -> void:
	var e = preload("res://scripts/Event.gd").new()
	e.main = self
	_swap(e)
