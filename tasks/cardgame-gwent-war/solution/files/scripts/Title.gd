extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.06, 0.04)
const COLOR_PANEL = Color(0.15, 0.12, 0.10)
const COLOR_GOLD = Color(0.82, 0.68, 0.21)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_BANNER_N = Color(0.15, 0.25, 0.55)
const COLOR_BANNER_M = Color(0.45, 0.12, 0.12)

var faction_selected: String = ""
var start_btn: Button = null

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Decorative banners
	var banner_l = ColorRect.new()
	banner_l.color = COLOR_BANNER_N
	banner_l.position = Vector2(40, 80)
	banner_l.size = Vector2(80, 560)
	add_child(banner_l)

	var banner_r = ColorRect.new()
	banner_r.color = COLOR_BANNER_M
	banner_r.position = Vector2(1160, 80)
	banner_r.size = Vector2(80, 560)
	add_child(banner_r)

	# Title
	var title = Label.new()
	title.text = "GWENT WAR"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "A Row-Based Card Battle"
	sub.position = Vector2(0, 150)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_TEXT)
	sub.add_theme_font_size_override("font_size", 24)
	add_child(sub)

	# Faction select label
	var fac_label = Label.new()
	fac_label.text = "Choose Your Faction"
	fac_label.position = Vector2(0, 230)
	fac_label.size = Vector2(1280, 40)
	fac_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fac_label.add_theme_color_override("font_color", COLOR_TEXT)
	fac_label.add_theme_font_size_override("font_size", 28)
	add_child(fac_label)

	# Northern Realms button
	var north_btn = _make_faction_btn("NORTHERN REALMS", Vector2(340, 300), COLOR_BANNER_N)
	north_btn.pressed.connect(_on_select_northern)
	add_child(north_btn)

	# Monsters button
	var mon_btn = _make_faction_btn("MONSTERS", Vector2(700, 300), COLOR_BANNER_M)
	mon_btn.pressed.connect(_on_select_monsters)
	add_child(mon_btn)

	# Faction description
	var desc = Label.new()
	desc.name = "FactionDesc"
	desc.text = ""
	desc.position = Vector2(0, 420)
	desc.size = Vector2(1280, 60)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	desc.add_theme_font_size_override("font_size", 18)
	add_child(desc)

	# Start button
	start_btn = _make_button("START BATTLE", Vector2(490, 520))
	start_btn.disabled = true
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

func _on_select_northern() -> void:
	faction_selected = "northern"
	main.player_faction = "northern"
	start_btn.disabled = false
	var desc = get_node("FactionDesc")
	desc.text = "Northern Realms: Strong heroes and siege units. Ability: Draw a card when winning a round."

func _on_select_monsters() -> void:
	faction_selected = "monsters"
	main.player_faction = "monsters"
	start_btn.disabled = false
	var desc = get_node("FactionDesc")
	desc.text = "Monsters: Swarm the board with numbers. Ability: Keep one random unit on the board between rounds."

func _on_start() -> void:
	main._enter_battle()

func _make_faction_btn(text: String, pos: Vector2, accent: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(240, 80)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	var sb_h = sb.duplicate()
	sb_h.bg_color = accent.lerp(COLOR_PANEL, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 20)
	return b

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	var sb_dis = sb.duplicate()
	sb_dis.bg_color = Color(0.08, 0.07, 0.06)
	sb_dis.border_color = Color(0.3, 0.3, 0.25)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb_dis)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.35, 0.2))
	b.add_theme_font_size_override("font_size", 26)
	return b
