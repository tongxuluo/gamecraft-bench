extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var floor_num: int = 1
var max_floors: int = 4
var player_hp: int = 10
var player_hp_max: int = 10
var energy: int = 5
var energy_max: int = 10
var resources: int = 0
var seed_deck: Array = []
var season_index: int = 0

const SEASONS = ["Spring", "Summer", "Autumn", "Winter"]

func _ready() -> void:
	_parse_args()
	_init_deck()
	if _scenario == "battle":
		_enter_floor()
	elif _scenario == "shop":
		_enter_shop()
	elif _scenario == "boss":
		floor_num = 5
		_enter_floor()
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

func _init_deck() -> void:
	seed_deck = [
		{"id": "sunflower", "label": "SUN", "color": Color(1.0, 0.85, 0.2), "cost": 2, "atk": 0, "hp": 3, "effect": "energy"},
		{"id": "thornbush", "label": "THN", "color": Color(0.4, 0.7, 0.3), "cost": 3, "atk": 2, "hp": 4, "effect": "damage"},
		{"id": "vinewall", "label": "VNE", "color": Color(0.2, 0.55, 0.2), "cost": 2, "atk": 0, "hp": 8, "effect": "block"},
		{"id": "healbloom", "label": "HLB", "color": Color(0.9, 0.4, 0.7), "cost": 4, "atk": 0, "hp": 3, "effect": "heal"},
		{"id": "sunflower", "label": "SUN", "color": Color(1.0, 0.85, 0.2), "cost": 2, "atk": 0, "hp": 3, "effect": "energy"},
		{"id": "thornbush", "label": "THN", "color": Color(0.4, 0.7, 0.3), "cost": 3, "atk": 2, "hp": 4, "effect": "damage"},
		{"id": "vinewall", "label": "VNE", "color": Color(0.2, 0.55, 0.2), "cost": 2, "atk": 0, "hp": 8, "effect": "block"},
		{"id": "thornbush", "label": "THN", "color": Color(0.4, 0.7, 0.3), "cost": 3, "atk": 2, "hp": 4, "effect": "damage"},
	]

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_floor() -> void:
	var f = preload("res://scripts/Floor.gd").new()
	f.main = self
	_swap(f)

func _enter_shop() -> void:
	var s = preload("res://scripts/Shop.gd").new()
	s.main = self
	_swap(s)

func _enter_result(won: bool) -> void:
	var r = preload("res://scripts/Result.gd").new()
	r.main = self
	r.won = won
	_swap(r)

func get_season() -> String:
	return SEASONS[season_index % 4]

func advance_floor() -> void:
	floor_num += 1
	if floor_num % 3 == 1:
		season_index += 1
	if floor_num > max_floors + 1:
		_enter_result(true)
	else:
		_enter_shop()
