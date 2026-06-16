extends Node2D

var current_screen: Node = null
var _scenario: String = ""
var deepest_floor: int = 0

func _ready() -> void:
	_parse_args()
	if _scenario == "gameplay" or _scenario == "level1":
		_enter_game(1)
	elif _scenario == "level2":
		_enter_game(2)
	elif _scenario == "level3":
		_enter_game(3)
	elif _scenario == "death":
		_enter_game(1, true)
	elif _scenario == "floor_transition":
		_enter_game(2)
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

func _enter_game(floor_num: int = 1, force_death: bool = false) -> void:
	var g = preload("res://scripts/Game.gd").new()
	g.main = self
	g.floor_num = floor_num
	g.force_death = force_death
	_swap(g)

func _enter_death_screen(floor_num: int, turns: int) -> void:
	var d = preload("res://scripts/DeathScreen.gd").new()
	d.main = self
	d.floor_num = floor_num
	d.turns = turns
	if floor_num > deepest_floor:
		deepest_floor = floor_num
	_swap(d)

func _enter_floor_transition(floor_num: int) -> void:
	var ft = preload("res://scripts/FloorTransition.gd").new()
	ft.main = self
	ft.floor_num = floor_num
	if floor_num > deepest_floor:
		deepest_floor = floor_num
	_swap(ft)
