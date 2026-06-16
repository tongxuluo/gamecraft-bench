extends Node2D

var current_screen: Node = null
var _scenario: String = ""
var cleared_chambers: Array = []

func _ready() -> void:
	_parse_args()
	if _scenario == "chamber1":
		_enter_game(0)
	elif _scenario == "chamber2":
		_enter_game(1)
	elif _scenario == "chamber3":
		_enter_game(2)
	elif _scenario == "chamber_select":
		_enter_chamber_select()
	elif _scenario == "completion":
		_enter_completion(0)
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

func _enter_chamber_select() -> void:
	var s = preload("res://scripts/ChamberSelect.gd").new()
	s.main = self
	s.cleared = cleared_chambers.duplicate()
	_swap(s)

func _enter_game(chamber_index: int) -> void:
	var g = preload("res://scripts/Game.gd").new()
	g.main = self
	g.chamber_index = chamber_index
	_swap(g)

func _enter_completion(chamber_index: int) -> void:
	var c = preload("res://scripts/Completion.gd").new()
	c.main = self
	c.chamber_index = chamber_index
	if not cleared_chambers.has(chamber_index):
		cleared_chambers.append(chamber_index)
	_swap(c)
