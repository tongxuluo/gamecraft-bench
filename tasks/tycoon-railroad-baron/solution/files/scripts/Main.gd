extends Node2D

var current_screen: String = ""
var scenario: String = ""
var screen_node: Node2D = null

func _ready() -> void:
	_parse_args()
	if scenario == "building" or scenario == "running":
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
	if screen_node != null:
		screen_node.queue_free()
		screen_node = null
	current_screen = screen_name
	var script_path: String = "res://scripts/" + screen_name + ".gd"
	var scr: GDScript = load(script_path) as GDScript
	screen_node = Node2D.new()
	screen_node.set_script(scr)
	screen_node.set_meta("main", self)
	add_child(screen_node)
