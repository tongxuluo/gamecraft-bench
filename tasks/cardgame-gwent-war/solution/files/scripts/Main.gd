extends Node2D

var current_screen: Node = null
var _scenario: String = ""
var player_faction: String = "northern"
var round_wins_player: int = 0
var round_wins_ai: int = 0

func _ready() -> void:
	_parse_args()
	if _scenario == "battle":
		player_faction = "northern"
		_enter_battle()
	elif _scenario == "battle_pass":
		player_faction = "northern"
		_enter_battle_pass()
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
	round_wins_player = 0
	round_wins_ai = 0
	var b = preload("res://scripts/Battle.gd").new()
	b.main = self
	b.seed_value = 42
	_swap(b)

func _enter_battle_pass() -> void:
	round_wins_player = 0
	round_wins_ai = 0
	var b = preload("res://scripts/Battle.gd").new()
	b.main = self
	b.seed_value = 99
	b.force_pass_scenario = true
	_swap(b)

func _enter_round_result(player_won: bool) -> void:
	if player_won:
		round_wins_player += 1
	else:
		round_wins_ai += 1
	if round_wins_player >= 2 or round_wins_ai >= 2:
		_enter_match_result()
	else:
		var b = preload("res://scripts/Battle.gd").new()
		b.main = self
		b.seed_value = 42 + round_wins_player + round_wins_ai
		_swap(b)

func _enter_match_result() -> void:
	var r = preload("res://scripts/MatchResult.gd").new()
	r.main = self
	r.player_won = round_wins_player >= 2
	_swap(r)
