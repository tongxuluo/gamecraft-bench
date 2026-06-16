extends Node2D

var current_screen: Node = null
var _scenario: String = ""

func _ready() -> void:
	_parse_args()
	if _scenario.begins_with("level_"):
		var lvl_id = _scenario.substr(len("level_")).to_int()
		_enter_game(lvl_id)
	elif _scenario == "level_select":
		_enter_level_select()
	elif _scenario == "near_victory":
		_enter_game(1, true)
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

func _enter_level_select() -> void:
	var s = preload("res://scripts/LevelSelect.gd").new()
	s.main = self
	_swap(s)

func _enter_game(level_id: int, near_victory: bool = false) -> void:
	var g = preload("res://scripts/Game.gd").new()
	g.main = self
	g.level_id = level_id
	g.near_victory = near_victory
	_swap(g)

func _enter_result(level_id: int, won: bool, saved_count: int, quota: int) -> void:
	var r = preload("res://scripts/Result.gd").new()
	r.main = self
	r.level_id = level_id
	r.won = won
	r.saved_count = saved_count
	r.quota = quota
	_swap(r)
