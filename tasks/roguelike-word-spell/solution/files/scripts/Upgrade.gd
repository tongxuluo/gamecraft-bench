extends Node2D

var main: Node = null
var options: Array = []

func _ready() -> void:
	_generate_options()
	_build_ui()

func _generate_options() -> void:
	var rare = ["Q", "Z", "X", "J", "K", "V", "W"]
	var common = ["E", "A", "I", "O", "U", "T", "N", "S", "R"]
	options.clear()
	# Option 1: add a rare letter
	var r_idx = main.fight_index % rare.size()
	options.append({"type": "add", "letter": rare[r_idx], "desc": "Add rare '" + rare[r_idx] + "' to pool (bonus damage!)"})
	# Option 2: add a vowel
	var v_idx = main.fight_index % 5
	options.append({"type": "add", "letter": common[v_idx], "desc": "Add '" + common[v_idx] + "' to pool"})
	# Option 3: heal
	options.append({"type": "heal", "letter": "", "desc": "Heal 20 HP"})

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.14)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "VICTORY! Choose a Reward"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(380, 60)
	add_child(title)

	var pool_lbl = Label.new()
	pool_lbl.text = "Letter Pool: " + ", ".join(main.letter_pool)
	pool_lbl.add_theme_font_size_override("font_size", 16)
	pool_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	pool_lbl.position = Vector2(100, 130)
	add_child(pool_lbl)

	for i in range(options.size()):
		var btn = Button.new()
		btn.text = options[i]["desc"]
		btn.position = Vector2(340, 220 + i * 120)
		btn.custom_minimum_size = Vector2(600, 80)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(Callable(self, "_on_choice").bind(i))
		add_child(btn)

func _on_choice(idx: int) -> void:
	var opt = options[idx]
	if opt["type"] == "add":
		main.letter_pool.append(opt["letter"])
	elif opt["type"] == "heal":
		main.player_hp = min(main.player_hp + 20, main.player_max_hp)
	main._enter_combat()
