extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var gold: int = 10
var rent: int = 15
var round_num: int = 1
var spins_this_cycle: int = 0
var symbol_pool: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_parse_args()
	_init_symbol_pool()
	if _scenario == "spin_round":
		rng.seed = 42
		_enter_game()
	elif _scenario == "shop":
		rng.seed = 99
		gold = 25
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

func _init_symbol_pool() -> void:
	# Start with basic symbols
	symbol_pool = ["cherry", "cherry", "coin", "coin", "gem", "gem", "cat", "milk", "ore"]

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_game() -> void:
	var g = preload("res://scripts/SlotGrid.gd").new()
	g.main = self
	_swap(g)

func _enter_shop() -> void:
	var s = preload("res://scripts/Shop.gd").new()
	s.main = self
	_swap(s)

func _enter_game_over() -> void:
	var go = preload("res://scripts/GameOver.gd").new()
	go.main = self
	_swap(go)
