extends Node2D

var current_screen: String = ""
var scenario: String = ""
var title_node: Node2D = null
var game_node: Node2D = null
var result_node: Node2D = null

func _ready() -> void:
	_parse_args()
	if scenario == "":
		_switch_screen("title")
	elif scenario == "day1" or scenario == "fight":
		_switch_screen("game")
	else:
		_switch_screen("title")

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]

func _switch_screen(screen_name: String) -> void:
	if title_node:
		title_node.queue_free()
		title_node = null
	if game_node:
		game_node.queue_free()
		game_node = null
	if result_node:
		result_node.queue_free()
		result_node = null
	current_screen = screen_name
	match screen_name:
		"title":
			var s: Node2D = Node2D.new()
			s.set_script(load("res://scripts/Title.gd"))
			add_child(s)
			title_node = s
		"game":
			var s: Node2D = Node2D.new()
			s.set_script(load("res://scripts/Game.gd"))
			s.set_meta("scenario", scenario)
			add_child(s)
			game_node = s
		"result":
			var s: Node2D = Node2D.new()
			s.set_script(load("res://scripts/Result.gd"))
			add_child(s)
			result_node = s
