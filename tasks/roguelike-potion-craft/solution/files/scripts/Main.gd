extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var gold: int = 0
var reputation: int = 5
var max_reputation: int = 5
var current_floor: int = 1
var inventory: Array = []
var potions: Array = []
var discovered_recipes: Array = []
var customers_served: int = 0

func _ready() -> void:
	_parse_args()
	if _scenario == "map_gather":
		_enter_map()
	elif _scenario == "brew_sell":
		inventory = ["Moonpetal", "Redcap", "Crystalwort"]
		discovered_recipes = [{"name": "Healing Potion", "ingredients": ["Moonpetal", "Redcap"], "color": Color(0.8, 0.2, 0.3)}]
		_enter_brew()
	elif _scenario == "customer":
		potions = ["Healing Potion", "Fire Resist Potion"]
		gold = 10
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
	var m = preload("res://scripts/MapScreen.gd").new()
	m.main = self
	_swap(m)

func _enter_brew() -> void:
	var b = preload("res://scripts/BrewScreen.gd").new()
	b.main = self
	_swap(b)

func _enter_shop() -> void:
	var s = preload("res://scripts/ShopScreen.gd").new()
	s.main = self
	_swap(s)

func _enter_floor_complete() -> void:
	if current_floor >= 3:
		_enter_victory()
	else:
		current_floor += 1
		_enter_map()

func _enter_victory() -> void:
	var v = preload("res://scripts/Victory.gd").new()
	v.main = self
	_swap(v)

func _enter_game_over() -> void:
	var g = preload("res://scripts/GameOver.gd").new()
	g.main = self
	_swap(g)

func reset_run() -> void:
	gold = 0
	reputation = 5
	current_floor = 1
	inventory = []
	potions = []
	discovered_recipes = []
	customers_served = 0
