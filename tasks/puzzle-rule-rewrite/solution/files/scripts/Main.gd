extends Node2D

var current_screen: Node = null
var _scenario: String = ""

func _ready() -> void:
	_parse_args()
	match _scenario:
		"level1":
			_enter_game(0)
		"level2":
			_enter_game(1)
		"level3":
			_enter_game(2)
		"level4":
			_enter_game(3)
		"level5":
			_enter_game(4)
		"level_select":
			_enter_level_select()
		_:
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

func _enter_level_select() -> void:
	var s = preload("res://scripts/LevelSelect.gd").new()
	s.main = self
	_swap(s)

func _enter_game(level_index: int) -> void:
	var g = preload("res://scripts/Game.gd").new()
	g.main = self
	g.level_index = level_index
	_swap(g)

func _enter_win_screen(level_index: int) -> void:
	var w = preload("res://scripts/WinScreen.gd").new()
	w.main = self
	w.level_index = level_index
	_swap(w)
