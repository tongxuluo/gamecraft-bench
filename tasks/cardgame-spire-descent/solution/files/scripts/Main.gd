extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Run state
var player_class: String = ""
var player_hp: int = 50
var player_hp_max: int = 50
var player_gold: int = 50
var player_deck: Array = []
var player_relics: Array = []
var current_floor: int = 0
var fights_won: int = 0
var map_seed: int = 0

# PLACEHOLDER_MAIN_CONTINUE

func _ready() -> void:
	_parse_args()
	if _scenario == "combat":
		_setup_warrior()
		current_floor = 1
		fights_won = 1
		_enter_combat(false)
	elif _scenario == "draft":
		_setup_warrior()
		fights_won = 1
		_enter_draft()
	elif _scenario == "map":
		_setup_warrior()
		_enter_map()
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

func _enter_class_select() -> void:
	var s = preload("res://scripts/ClassSelect.gd").new()
	s.main = self
	_swap(s)

func _enter_map() -> void:
	var m = preload("res://scripts/Map.gd").new()
	m.main = self
	_swap(m)

func _enter_combat(is_boss: bool) -> void:
	var c = preload("res://scripts/Combat.gd").new()
	c.main = self
	c.is_boss = is_boss
	_swap(c)

func _enter_draft() -> void:
	var d = preload("res://scripts/Draft.gd").new()
	d.main = self
	_swap(d)

func _enter_rest() -> void:
	var heal = int(player_hp_max * 0.3)
	player_hp = min(player_hp + heal, player_hp_max)
	_enter_map()

func _enter_win() -> void:
	var w = preload("res://scripts/WinLose.gd").new()
	w.main = self
	w.won = true
	_swap(w)

func _enter_lose() -> void:
	var w = preload("res://scripts/WinLose.gd").new()
	w.main = self
	w.won = false
	_swap(w)

func _setup_warrior() -> void:
	player_class = "Warrior"
	player_hp = 80
	player_hp_max = 80
	player_deck = [
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Bash", "cost": 2, "type": "attack", "value": 10},
	]
	player_relics = ["Burning Blood"]
	map_seed = 42

func _setup_rogue() -> void:
	player_class = "Rogue"
	player_hp = 70
	player_hp_max = 70
	player_deck = [
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Shiv", "cost": 0, "type": "attack", "value": 4},
		{"name": "Shiv", "cost": 0, "type": "attack", "value": 4},
	]
	player_relics = ["Ring of the Snake"]
	map_seed = 77

func _setup_mage() -> void:
	player_class = "Mage"
	player_hp = 60
	player_hp_max = 60
	player_deck = [
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Strike", "cost": 1, "type": "attack", "value": 6},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Defend", "cost": 1, "type": "skill", "value": 5},
		{"name": "Zap", "cost": 1, "type": "attack", "value": 8},
		{"name": "Frost", "cost": 1, "type": "skill", "value": 8},
	]
	player_relics = ["Cracked Orb"]
	map_seed = 99

func start_run(cls: String) -> void:
	if cls == "Warrior":
		_setup_warrior()
	elif cls == "Rogue":
		_setup_rogue()
	else:
		_setup_mage()
	current_floor = 0
	fights_won = 0
	player_gold = 50
	_enter_map()
