extends Node2D

var current_screen: Node2D = null
var scenario: String = ""

func _ready() -> void:
	_parse_args()
	if scenario == "building" or scenario == "open":
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
	if current_screen:
		current_screen.queue_free()
		current_screen = null
	var scr: Node2D = Node2D.new()
	var script_path: String = "res://scripts/" + screen_name + ".gd"
	var scr_script: GDScript = load(script_path) as GDScript
	scr.set_script(scr_script)
	scr.set_meta("main", self)
	scr.set_meta("scenario", scenario)
	add_child(scr)
	current_screen = scr

func go_to(screen_name: String) -> void:
	call_deferred("_switch_screen", screen_name)
