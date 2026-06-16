extends Node2D

var main: Node = null
var player_won: bool = false

const COLOR_BG = Color(0.05, 0.05, 0.05)
const COLOR_WIN = Color(0.2, 0.5, 0.2)
const COLOR_LOSE = Color(0.5, 0.15, 0.15)
const COLOR_GOLD = Color(0.82, 0.68, 0.21)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var banner = ColorRect.new()
	banner.color = COLOR_WIN if player_won else COLOR_LOSE
	banner.position = Vector2(240, 200)
	banner.size = Vector2(800, 200)
	add_child(banner)

	var title = Label.new()
	title.text = "VICTORY!" if player_won else "DEFEAT"
	title.position = Vector2(0, 230)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	var score_text = "Final: " + str(main.round_wins_player) + " - " + str(main.round_wins_ai)
	var score = Label.new()
	score.text = score_text
	score.position = Vector2(0, 320)
	score.size = Vector2(1280, 40)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_color_override("font_color", COLOR_TEXT)
	score.add_theme_font_size_override("font_size", 28)
	add_child(score)

	var retry_btn = _make_button("PLAY AGAIN", Vector2(390, 480))
	retry_btn.pressed.connect(func(): main._enter_title())
	add_child(retry_btn)

	var quit_btn = _make_button("QUIT", Vector2(690, 480))
	quit_btn.pressed.connect(func(): main.get_tree().quit())
	add_child(quit_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.13, 0.11)
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_font_size_override("font_size", 22)
	return b
