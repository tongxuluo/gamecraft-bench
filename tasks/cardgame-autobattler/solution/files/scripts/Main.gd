extends Node2D

var current_screen: Node = null
var _scenario: String = ""

var round_num: int = 1
var player_hp: int = 100
var player_gold: int = 3
var player_level: int = 1
var board_slots: Array = []  # Array of creature dicts or null, 8 slots (4x2)
var bench_slots: Array = []  # up to 4 bench slots

func _ready() -> void:
	_parse_args()
	board_slots.resize(8)
	bench_slots.resize(4)
	for i in range(8):
		board_slots[i] = null
	for i in range(4):
		bench_slots[i] = null
	if _scenario == "draft_battle":
		round_num = 2
		player_gold = 6
		_enter_shop()
	elif _scenario == "late_game":
		round_num = 7
		player_gold = 12
		player_hp = 35
		player_level = 4
		_setup_late_game_board()
		_enter_shop()
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

func _setup_late_game_board() -> void:
	board_slots[0] = {"name": "Wolf", "tribe": "Beast", "atk": 5, "hp": 8, "max_hp": 8, "cost": 2, "color": Color(0.6, 0.4, 0.2)}
	board_slots[1] = {"name": "Bear", "tribe": "Beast", "atk": 7, "hp": 12, "max_hp": 12, "cost": 3, "color": Color(0.5, 0.3, 0.1)}
	board_slots[2] = {"name": "Raptor", "tribe": "Beast", "atk": 6, "hp": 6, "max_hp": 6, "cost": 2, "color": Color(0.7, 0.5, 0.2)}
	board_slots[4] = {"name": "Golem", "tribe": "Mech", "atk": 3, "hp": 18, "max_hp": 18, "cost": 4, "color": Color(0.5, 0.5, 0.6)}
	board_slots[5] = {"name": "Drake", "tribe": "Dragon", "atk": 9, "hp": 10, "max_hp": 10, "cost": 5, "color": Color(0.8, 0.3, 0.1)}

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_shop() -> void:
	var s = preload("res://scripts/Shop.gd").new()
	s.main = self
	_swap(s)

func _enter_battle() -> void:
	var b = preload("res://scripts/Battle.gd").new()
	b.main = self
	_swap(b)

func _enter_result(won: bool) -> void:
	var r = preload("res://scripts/Result.gd").new()
	r.main = self
	r.won = won
	_swap(r)
