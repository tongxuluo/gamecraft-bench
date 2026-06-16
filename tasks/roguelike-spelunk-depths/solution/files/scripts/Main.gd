extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var floor_num: int = 1
var max_floors: int = 4
var player_hp: int = 4
var player_hp_max: int = 4
var ropes: int = 4
var bombs: int = 4
var gold: int = 0
var shopkeeper_angry: bool = false
var enemies_killed: int = 0

func _ready() -> void:
	_parse_args()
	if _scenario == "cave":
		_enter_cave()
	elif _scenario == "shop":
		_enter_cave_with_shop()
	elif _scenario == "death":
		_enter_death()
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

func _enter_cave() -> void:
	var c = preload("res://scripts/Cave.gd").new()
	c.main = self
	c.has_shop = false
	_swap(c)

func _enter_cave_with_shop() -> void:
	var c = preload("res://scripts/Cave.gd").new()
	c.main = self
	c.has_shop = true
	_swap(c)

func _enter_death() -> void:
	var d = preload("res://scripts/Death.gd").new()
	d.main = self
	_swap(d)

func advance_floor() -> void:
	floor_num += 1
	if floor_num > max_floors:
		_enter_death()  # win condition same screen
	else:
		if floor_num % 2 == 0:
			_enter_cave_with_shop()
		else:
			_enter_cave()

func reset_run() -> void:
	floor_num = 1
	player_hp = 4
	ropes = 4
	bombs = 4
	gold = 0
	shopkeeper_angry = false
	enemies_killed = 0
