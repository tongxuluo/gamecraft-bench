extends Node2D

var current_screen: Node2D = null
var scenario: String = ""

func _ready() -> void:
	_parse_args()
	if scenario == "":
		_show_title()
	elif scenario == "wave1":
		_show_game()
	elif scenario == "combat":
		_show_game_combat()
	else:
		_show_title()

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]

func _clear() -> void:
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null

func _show_title() -> void:
	_clear()
	var title_script: GDScript = load("res://scripts/Title.gd")
	var screen: Node2D = Node2D.new()
	screen.set_script(title_script)
	add_child(screen)
	current_screen = screen
	screen.connect("begin_pressed", Callable(self, "_on_begin"))

func _on_begin() -> void:
	_show_game()

func _show_game() -> void:
	_clear()
	var game_script: GDScript = load("res://scripts/Game.gd")
	var screen: Node2D = Node2D.new()
	screen.set_script(game_script)
	screen.set_meta("scenario", scenario)
	add_child(screen)
	current_screen = screen
	screen.connect("game_over", Callable(self, "_on_game_over"))

func _show_game_combat() -> void:
	_clear()
	var game_script: GDScript = load("res://scripts/Game.gd")
	var screen: Node2D = Node2D.new()
	screen.set_script(game_script)
	screen.set_meta("scenario", "combat")
	add_child(screen)
	current_screen = screen
	screen.connect("game_over", Callable(self, "_on_game_over"))

func _on_game_over(stats: Dictionary) -> void:
	_clear()
	var result_script: GDScript = load("res://scripts/Result.gd")
	var screen: Node2D = Node2D.new()
	screen.set_script(result_script)
	screen.set_meta("stats", stats)
	add_child(screen)
	current_screen = screen
