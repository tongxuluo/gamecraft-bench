extends Control

var main: Node = null

func _ready() -> void:
	# Full screen background - dark sunset sky
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.08, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Train silhouette (dark rectangle near bottom)
	var train_sil = ColorRect.new()
	train_sil.color = Color(0.05, 0.05, 0.08)
	train_sil.position = Vector2(100, 420)
	train_sil.size = Vector2(1080, 80)
	add_child(train_sil)

	# Smoke stack
	var smoke = ColorRect.new()
	smoke.color = Color(0.05, 0.05, 0.08)
	smoke.position = Vector2(1050, 370)
	smoke.size = Vector2(30, 50)
	add_child(smoke)

	# Wheels
	for i in range(8):
		var wheel = ColorRect.new()
		wheel.color = Color(0.3, 0.3, 0.3)
		wheel.position = Vector2(150 + i * 130, 500)
		wheel.size = Vector2(40, 40)
		add_child(wheel)

	# Sunset gradient strip
	var sunset = ColorRect.new()
	sunset.color = Color(0.8, 0.3, 0.1, 0.6)
	sunset.position = Vector2(0, 350)
	sunset.size = Vector2(1280, 70)
	add_child(sunset)

	# Title label
	var title = Label.new()
	title.text = "TRAIN HEIST"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.position = Vector2(420, 120)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "A Roguelike Adventure"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	sub.position = Vector2(490, 200)
	add_child(sub)

	# Start button
	var btn = Button.new()
	btn.text = "  START HEIST  "
	btn.position = Vector2(530, 560)
	btn.custom_minimum_size = Vector2(220, 50)
	btn.pressed.connect(_on_start)
	add_child(btn)

func _on_start() -> void:
	main._setup_run()
	main._enter_train_view()
