extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var player_hp: int = 50
var player_max_hp: int = 50
var current_fight: int = 0  # 0-based index
var dice_faces: Array = []  # Array of arrays, each die has 6 faces
var equipment_collected: Array = []

func _ready() -> void:
	_parse_args()
	_init_dice()
	if _scenario == "combat":
		current_fight = 0
		_enter_combat()
	elif _scenario == "equipment":
		current_fight = 1
		_enter_equipment()
	elif _scenario == "boss":
		current_fight = 3
		_enter_combat()
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

func _init_dice() -> void:
	# Each die: sword, sword, shield, heart, skull, blank
	dice_faces.clear()
	for d in range(5):
		dice_faces.append(["sword", "sword", "shield", "heart", "skull", "blank"])

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_combat() -> void:
	var c = preload("res://scripts/Combat.gd").new()
	c.main = self
	c.fight_index = current_fight
	_swap(c)

func _enter_equipment() -> void:
	var e = preload("res://scripts/Equipment.gd").new()
	e.main = self
	_swap(e)

func _enter_win() -> void:
	var w = preload("res://scripts/WinLose.gd").new()
	w.main = self
	w.is_win = true
	_swap(w)

func _enter_lose() -> void:
	var w = preload("res://scripts/WinLose.gd").new()
	w.main = self
	w.is_win = false
	_swap(w)

func advance_after_combat(won: bool) -> void:
	if not won:
		_enter_lose()
		return
	current_fight += 1
	if current_fight > 3:
		_enter_win()
	elif current_fight <= 3:
		_enter_equipment()

func advance_after_equipment() -> void:
	_enter_combat()
