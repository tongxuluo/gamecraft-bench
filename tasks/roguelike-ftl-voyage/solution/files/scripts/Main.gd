extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var fuel: int = 14
var scrap: int = 30
var hull: int = 30
var max_hull: int = 30
var sector: int = 1
var crew: Array = []
var systems: Dictionary = {}
var sector_map: Array = []
var current_node: int = 0
var visited_nodes: Array = []

func _ready() -> void:
	_parse_args()
	_init_game_state()
	if _scenario == "combat":
		_enter_combat({"type": "combat", "enemy_name": "Pirate Scout", "enemy_hull": 12, "enemy_weapons": 2})
	elif _scenario == "shop":
		_enter_shop()
	elif _scenario == "map":
		_enter_sector_map()
	elif _scenario == "boss":
		_enter_combat({"type": "boss", "enemy_name": "Rebel Flagship", "enemy_hull": 30, "enemy_weapons": 4})
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

func _init_game_state() -> void:
	crew = [
		{"name": "Captain", "room": "weapons", "hp": 4, "max_hp": 4},
		{"name": "Engineer", "room": "engines", "hp": 4, "max_hp": 4},
		{"name": "Medic", "room": "medbay", "hp": 4, "max_hp": 4},
	]
	systems = {
		"weapons": {"power": 2, "max_power": 3, "damage": 0},
		"shields": {"power": 1, "max_power": 3, "damage": 0},
		"engines": {"power": 1, "max_power": 3, "damage": 0},
		"medbay": {"power": 1, "max_power": 2, "damage": 0},
	}

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_sector_map() -> void:
	_generate_sector_map()
	var s = preload("res://scripts/SectorMap.gd").new()
	s.main = self
	_swap(s)

func _enter_ship_view() -> void:
	var s = preload("res://scripts/ShipView.gd").new()
	s.main = self
	_swap(s)

func _enter_event(event_data: Dictionary) -> void:
	var e = preload("res://scripts/Event.gd").new()
	e.main = self
	e.event_data = event_data
	_swap(e)

func _enter_combat(enemy_data: Dictionary) -> void:
	var c = preload("res://scripts/Combat.gd").new()
	c.main = self
	c.enemy_data = enemy_data
	_swap(c)

func _enter_shop() -> void:
	var s = preload("res://scripts/Shop.gd").new()
	s.main = self
	_swap(s)

func _enter_victory() -> void:
	var v = preload("res://scripts/Victory.gd").new()
	v.main = self
	_swap(v)

func _enter_defeat() -> void:
	var d = preload("res://scripts/Defeat.gd").new()
	d.main = self
	_swap(d)

func _generate_sector_map() -> void:
	if sector_map.size() > 0:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = sector * 42
	sector_map = []
	var node_count = 8
	for i in range(node_count):
		var nx = 120 + i * 140
		var ny = 200 + rng.randi_range(-80, 80)
		var node_type = "empty"
		if i == 0:
			node_type = "start"
		elif i == node_count - 1:
			node_type = "exit"
		else:
			var roll = rng.randi_range(0, 4)
			if roll == 0:
				node_type = "combat"
			elif roll == 1:
				node_type = "shop"
			elif roll == 2:
				node_type = "event"
			elif roll == 3:
				node_type = "combat"
			else:
				node_type = "event"
		sector_map.append({"x": nx, "y": ny, "type": node_type, "connections": []})
	# Connect nodes linearly with some branches
	for i in range(node_count - 1):
		sector_map[i].connections.append(i + 1)
		if i + 2 < node_count and rng.randi_range(0, 2) == 0:
			sector_map[i].connections.append(i + 2)
	current_node = 0
	visited_nodes = [0]

func advance_sector() -> void:
	sector += 1
	sector_map = []
	current_node = 0
	visited_nodes = []
	if sector > 3:
		_enter_combat({"type": "boss", "enemy_name": "Rebel Flagship", "enemy_hull": 30, "enemy_weapons": 4})
	else:
		_enter_sector_map()
