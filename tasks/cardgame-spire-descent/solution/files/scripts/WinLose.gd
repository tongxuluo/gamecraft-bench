extends Node2D

var main: Node = null
var won: bool = true

const COLOR_BG = Color(0.05, 0.04, 0.08)
const COLOR_PANEL = Color(0.14, 0.12, 0.18)
const COLOR_ACCENT = Color(0.65, 0.45, 0.20)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_GREEN = Color(0.30, 0.75, 0.40)
const COLOR_RED = Color(0.85, 0.30, 0.30)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	if won:
		_build_win()
	else:
		_build_lose()

func _build_win() -> void:
	# Victory glow
	var glow = ColorRect.new()
	glow.color = COLOR_ACCENT * Color(0.2, 0.2, 0.2)
	glow.position = Vector2(340, 80)
	glow.size = Vector2(600, 300)
	add_child(glow)

	var title = Label.new()
	title.text = "VICTORY!"
	title.position = Vector2(0, 120)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "The Spire has been conquered!"
	subtitle.position = Vector2(0, 210)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_GREEN)
	subtitle.add_theme_font_size_override("font_size", 24)
	add_child(subtitle)

	# Stats
	var stats_panel = ColorRect.new()
	stats_panel.color = COLOR_PANEL
	stats_panel.position = Vector2(390, 280)
	stats_panel.size = Vector2(500, 200)
	add_child(stats_panel)

	var stats_text = Label.new()
	stats_text.text = "Class: %s\nFloors Cleared: %d\nHP Remaining: %d/%d\nDeck Size: %d cards\nGold: %d" % [
		main.player_class, main.current_floor, main.player_hp, main.player_hp_max,
		main.player_deck.size(), main.player_gold
	]
	stats_text.position = Vector2(420, 300)
	stats_text.size = Vector2(440, 160)
	stats_text.add_theme_color_override("font_color", COLOR_TEXT)
	stats_text.add_theme_font_size_override("font_size", 20)
	add_child(stats_text)

	var btn = _make_button("NEW RUN", Vector2(490, 530))
	btn.pressed.connect(func(): main._enter_title())
	add_child(btn)

func _build_lose() -> void:
	var title = Label.new()
	title.text = "DEFEAT"
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_RED)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "You have fallen in the Spire..."
	subtitle.position = Vector2(0, 240)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
	subtitle.add_theme_font_size_override("font_size", 24)
	add_child(subtitle)

	# Stats
	var stats_panel = ColorRect.new()
	stats_panel.color = COLOR_PANEL
	stats_panel.position = Vector2(390, 310)
	stats_panel.size = Vector2(500, 160)
	add_child(stats_panel)

	var stats_text = Label.new()
	stats_text.text = "Class: %s\nFloors Reached: %d\nFights Won: %d\nDeck Size: %d cards" % [
		main.player_class, main.current_floor, main.fights_won, main.player_deck.size()
	]
	stats_text.position = Vector2(420, 330)
	stats_text.size = Vector2(440, 120)
	stats_text.add_theme_color_override("font_color", COLOR_TEXT)
	stats_text.add_theme_font_size_override("font_size", 20)
	add_child(stats_text)

	var btn = _make_button("TRY AGAIN", Vector2(490, 520))
	btn.pressed.connect(func(): main._enter_title())
	add_child(btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 26)
	return b
