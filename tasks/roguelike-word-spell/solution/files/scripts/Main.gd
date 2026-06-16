extends Node2D

var current_screen: Node = null
var _scenario: String = ""
var fight_index: int = 0
var player_hp: int = 100
var player_max_hp: int = 100
var letter_pool: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_parse_args()
	_init_letter_pool()
	if _scenario == "combat":
		fight_index = 0
		_enter_combat()
	elif _scenario == "upgrade":
		fight_index = 1
		_enter_upgrade()
	elif _scenario == "boss":
		fight_index = 3
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

func _init_letter_pool() -> void:
	rng.seed = 42
	var vowels = ["A", "E", "I", "O", "U"]
	var common = ["T", "N", "S", "R", "L", "D", "H"]
	var uncommon = ["C", "M", "P", "G", "B", "F", "W", "Y", "K", "V"]
	# Build starting pool of 20 tiles
	letter_pool.clear()
	for v in vowels:
		letter_pool.append(v)
		letter_pool.append(v)
	# 10 vowels + 10 consonants
	for c in common:
		letter_pool.append(c)
	for i in range(3):
		letter_pool.append(uncommon[i])

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
	var b = preload("res://scripts/Combat.gd").new()
	b.main = self
	b.fight_index = fight_index
	_swap(b)

func _enter_upgrade() -> void:
	var u = preload("res://scripts/Upgrade.gd").new()
	u.main = self
	_swap(u)

func _enter_result(won: bool) -> void:
	var r = preload("res://scripts/Result.gd").new()
	r.main = self
	r.won = won
	_swap(r)

func advance_after_combat() -> void:
	fight_index += 1
	if fight_index >= 4:
		_enter_result(true)
	else:
		_enter_upgrade()

func on_player_died() -> void:
	_enter_result(false)
