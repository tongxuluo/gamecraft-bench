extends Node2D

var current_screen: Node = null
var _scenario: String = ""
var current_level: int = 0

func _ready() -> void:
	_parse_args()
	if _scenario == "level1":
		_enter_game(0)
	elif _scenario == "level2":
		_enter_game(1)
	elif _scenario == "level3":
		_enter_game(2)
	elif _scenario == "routing":
		_enter_game(0)
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

func _enter_game(level_idx: int) -> void:
	current_level = level_idx
	var g = preload("res://scripts/Game.gd").new()
	g.main = self
	g.level_index = level_idx
	_swap(g)

func _enter_next_level() -> void:
	current_level += 1
	if current_level >= 3:
		_enter_title()
	else:
		_enter_game(current_level)
