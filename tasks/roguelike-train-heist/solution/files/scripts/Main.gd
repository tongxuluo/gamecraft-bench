extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var hp: int = 100
var max_hp: int = 100
var gold: int = 0
var inventory: Array = []  # max 3 items
var current_car: int = 0  # 0 = caboose, 7 = engine
var guard_car: int = -2  # guards start 2 cars behind
var turn: int = 0
var car_types: Array = []  # generated per run

func _ready() -> void:
	_parse_args()
	if _scenario == "train_moving":
		_setup_run()
		current_car = 2
		guard_car = 0
		turn = 3
		_enter_train_view()
	elif _scenario == "combat":
		_setup_run()
		current_car = 3
		car_types[3] = "combat"
		guard_car = 1
		turn = 4
		_enter_encounter()
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

func _setup_run() -> void:
	hp = 100
	max_hp = 100
	gold = 0
	inventory = []
	current_car = 0
	guard_car = -2
	turn = 0
	# Generate 8 cars: caboose, 6 random encounters, engine
	car_types = ["start", "combat", "treasure", "shop", "trap", "combat", "treasure", "engine"]

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_train_view() -> void:
	var t = preload("res://scripts/TrainView.gd").new()
	t.main = self
	_swap(t)

func _enter_encounter() -> void:
	var car_type = car_types[current_car]
	if car_type == "engine":
		_enter_win()
		return
	var e = preload("res://scripts/Encounter.gd").new()
	e.main = self
	e.car_type = car_type
	_swap(e)

func _enter_win() -> void:
	var w = preload("res://scripts/WinScreen.gd").new()
	w.main = self
	_swap(w)

func _enter_gameover(reason: String) -> void:
	var g = preload("res://scripts/GameOver.gd").new()
	g.main = self
	g.reason = reason
	_swap(g)

func advance_turn() -> void:
	turn += 1
	guard_car += 1
	if guard_car >= current_car:
		_enter_gameover("Guards caught you!")

func move_forward() -> void:
	current_car += 1
	if current_car >= 7:
		_enter_win()
		return
	turn += 1
	guard_car += 1
	if guard_car >= current_car:
		_enter_gameover("Guards caught you!")
	else:
		_enter_encounter()
