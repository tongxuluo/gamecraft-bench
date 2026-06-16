extends Node2D

var main: Node = null

const COLOR_BG := Color(0.12, 0.18, 0.10)
const COLOR_GOO_GREEN := Color(0.30, 0.85, 0.25)
const COLOR_GOO_GRAY := Color(0.55, 0.58, 0.60)
const COLOR_GOO_PINK := Color(0.90, 0.45, 0.70)
const COLOR_ACCENT := Color(0.40, 0.75, 0.35)

var _anim_blobs: Array = []
var _time: float = 0.0

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Decorative ground
	var ground = ColorRect.new()
	ground.color = Color(0.08, 0.12, 0.06)
	ground.position = Vector2(0, 580)
	ground.size = Vector2(1280, 140)
	add_child(ground)

	# Title
	var title = Label.new()
	title.text = "GOO ARCHITECT"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOO_GREEN)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Build with blobs. Reach the pipe."
	sub.position = Vector2(0, 200)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.65))
	sub.add_theme_font_size_override("font_size", 24)
	add_child(sub)

	# Animated goo blobs on title screen
	_create_anim_blobs()

	# Start button
	var start_btn = _make_button("START", Vector2(490, 420))
	start_btn.pressed.connect(func(): main._enter_level_select())
	add_child(start_btn)

	# Quit button
	var quit_btn = _make_button("QUIT", Vector2(490, 510))
	quit_btn.pressed.connect(func(): get_tree().quit())
	add_child(quit_btn)

func _create_anim_blobs() -> void:
	var positions = [Vector2(200, 500), Vector2(400, 520), Vector2(600, 490),
					 Vector2(800, 530), Vector2(1000, 500)]
	var colors = [COLOR_GOO_GREEN, COLOR_GOO_GRAY, COLOR_GOO_PINK, COLOR_GOO_GREEN, COLOR_GOO_GRAY]
	for i in range(positions.size()):
		var blob = ColorRect.new()
		blob.color = colors[i]
		blob.size = Vector2(40, 40)
		blob.position = positions[i]
		blob.pivot_offset = Vector2(20, 20)
		add_child(blob)
		_anim_blobs.append({"node": blob, "base_y": positions[i].y, "phase": float(i) * 1.2})

func _process(delta: float) -> void:
	_time += delta
	for b in _anim_blobs:
		var node: ColorRect = b["node"]
		node.position.y = b["base_y"] + sin(_time * 2.0 + b["phase"]) * 12.0
		node.scale = Vector2(1.0 + sin(_time * 3.0 + b["phase"]) * 0.1,
							 1.0 - sin(_time * 3.0 + b["phase"]) * 0.1)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 70)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.30, 0.15)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb.duplicate())
	b.add_theme_stylebox_override("pressed", sb.duplicate())
	b.add_theme_color_override("font_color", Color(0.90, 0.95, 0.88))
	b.add_theme_font_size_override("font_size", 32)
	return b
