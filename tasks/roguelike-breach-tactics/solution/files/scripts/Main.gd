extends Node2D

var current_screen: Node = null
var _scenario: String = ""

func _ready() -> void:
	_parse_args()
	if _scenario == "battle":
		_enter_battle()
	elif _scenario == "building_save":
		_enter_battle_scenario("building_save")
	elif _scenario == "upgrade":
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

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_battle() -> void:
	var b = preload("res://scripts/Battle.gd").new()
	b.main = self
	b.scenario_id = ""
	_swap(b)

func _enter_battle_scenario(id: String) -> void:
	var b = preload("res://scripts/Battle.gd").new()
	b.main = self
	b.scenario_id = id
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
