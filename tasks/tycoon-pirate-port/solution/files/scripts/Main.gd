extends Node2D

var current_screen: String = ""
var scenario: String = ""
var result_data: Dictionary = {}

func _ready() -> void:
	_parse_args()
	if scenario != "":
		_switch_screen("Game")
	else:
		_switch_screen("Title")

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]

func _switch_screen(screen_name: String) -> void:
	for child in get_children():
		child.queue_free()
	current_screen = screen_name
	var node: Node2D = Node2D.new()
	node.name = screen_name
	var script_path: String = "res://scripts/" + screen_name + ".gd"
	var scr: Script = load(script_path) as Script
	node.set_script(scr)
	add_child(node)
