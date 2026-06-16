extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var day: int = 1
var gold: int = 50
var inventory: Array = []
var shelves: Array = []
var shop_level: int = 1
var max_shelves: int = 4
var security_level: int = 0
var thieves_caught: int = 0
var total_profit: int = 0

const DAY_TARGETS = [0, 80, 120, 180, 260, 350]
const MAX_DAYS = 5

func _ready() -> void:
	_parse_args()
	seed(12345)
	_init_inventory()
	if _scenario == "shop_day":
		_enter_shop()
	elif _scenario == "thief_event":
		day = 2
		gold = 100
		_init_shelves_with_items()
		_enter_thief()
	elif _scenario == "upgrade":
		day = 2
		gold = 150
		_enter_upgrade()
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

func _init_inventory() -> void:
	inventory = [
		{"name": "Iron Sword", "type": "weapon", "base_price": 15, "price": 15},
		{"name": "Health Potion", "type": "potion", "base_price": 8, "price": 8},
		{"name": "Leather Shield", "type": "armor", "base_price": 12, "price": 12},
		{"name": "Fire Scroll", "type": "magic", "base_price": 20, "price": 20},
		{"name": "Bandage", "type": "potion", "base_price": 5, "price": 5},
		{"name": "Steel Dagger", "type": "weapon", "base_price": 10, "price": 10},
	]

func _init_shelves_with_items() -> void:
	shelves = []
	for i in range(min(4, inventory.size())):
		shelves.append(inventory[i].duplicate())

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
	if shelves.size() == 0:
		_init_shelves_with_items()
	var s = preload("res://scripts/Shop.gd").new()
	s.main = self
	_swap(s)

func _enter_thief() -> void:
	var t = preload("res://scripts/Thief.gd").new()
	t.main = self
	_swap(t)

func _enter_upgrade() -> void:
	var u = preload("res://scripts/Upgrade.gd").new()
	u.main = self
	_swap(u)

func _enter_restock() -> void:
	var r = preload("res://scripts/Restock.gd").new()
	r.main = self
	_swap(r)

func _enter_results(won: bool) -> void:
	var r = preload("res://scripts/Results.gd").new()
	r.main = self
	r.won = won
	_swap(r)

func _end_day() -> void:
	day += 1
	if gold <= 0 and inventory.size() == 0:
		_enter_results(false)
	elif day > MAX_DAYS:
		_enter_results(true)
	else:
		_enter_restock()

func _check_bankrupt() -> bool:
	return gold <= 0 and inventory.size() == 0 and shelves.size() == 0
