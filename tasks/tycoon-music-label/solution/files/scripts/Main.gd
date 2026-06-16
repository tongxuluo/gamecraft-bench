extends Node2D

var current_screen: Node2D = null
var scenario: String = ""
var gold: int = 0
var reputation: int = 0
var albums_released: Array = []
var roster_size: int = 0

func _ready() -> void:
	_parse_args()
	if scenario == "":
		_show_screen("Title")
	elif scenario == "scouting":
		_show_screen("Game")
	elif scenario == "release":
		_show_screen("Game")
	else:
		_show_screen("Title")

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in range(args.size()):
		var arg: String = args[i]
		if arg == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]

func _show_screen(screen_name: String) -> void:
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null
	var screen: Node2D = Node2D.new()
	var script_path: String = "res://scripts/" + screen_name + ".gd"
	var scr: GDScript = load(script_path) as GDScript
	screen.set_script(scr)
	screen.name = screen_name
	add_child(screen)
	current_screen = screen

func change_screen(screen_name: String) -> void:
	call_deferred("_show_screen", screen_name)
