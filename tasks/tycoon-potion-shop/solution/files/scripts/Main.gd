extends Node2D

var current_screen: Node2D = null
var scenario: String = ""

func _ready() -> void:
	_parse_args()
	if scenario == "":
		_show_title()
	elif scenario == "brewing":
		_show_game()
	elif scenario == "customers":
		_show_game()
	else:
		_show_title()

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]

func _show_title() -> void:
	_clear()
	var title_script: Script = load("res://scripts/Title.gd")
	var node: Node2D = Node2D.new()
	node.set_script(title_script)
	add_child(node)
	current_screen = node
	node.connect("begin_pressed", Callable(self, "_on_begin"))

func _show_game() -> void:
	_clear()
	var game_script: Script = load("res://scripts/Game.gd")
	var node: Node2D = Node2D.new()
	node.set_script(game_script)
	node.scenario = scenario
	add_child(node)
	current_screen = node
	node.connect("game_ended", Callable(self, "_on_game_ended"))

func _show_result(stats: Dictionary) -> void:
	_clear()
	var result_script: Script = load("res://scripts/Result.gd")
	var node: Node2D = Node2D.new()
	node.set_script(result_script)
	node.stats = stats
	add_child(node)
	current_screen = node

func _clear() -> void:
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null

func _on_begin() -> void:
	_show_game()

func _on_game_ended(stats: Dictionary) -> void:
	_show_result(stats)
