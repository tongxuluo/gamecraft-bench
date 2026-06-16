extends Node2D

var main: Node = null

const COLOR_BG := Color(0.92, 0.94, 0.96)
const COLOR_PANEL := Color(0.98, 0.98, 0.99)
const COLOR_ACCENT_BLUE := Color(0.15, 0.45, 0.95)
const COLOR_ACCENT_ORANGE := Color(0.95, 0.55, 0.10)
const COLOR_DARK := Color(0.12, 0.14, 0.18)
const COLOR_GRID := Color(0.85, 0.87, 0.90)

func _ready() -> void:
	# Background - clean lab white
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Grid pattern overlay
	_draw_grid()

	# Central panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(290, 120)
	panel.size = Vector2(700, 480)
	add_child(panel)

	# Panel border
	var border = ColorRect.new()
	border.color = COLOR_DARK
	border.position = Vector2(288, 118)
	border.size = Vector2(704, 484)
	border.z_index = -1
	add_child(border)

	# Portal imagery - blue oval
	var portal_blue = _make_portal_visual(Vector2(420, 260), COLOR_ACCENT_BLUE, 40.0)
	add_child(portal_blue)

	# Portal imagery - orange oval
	var portal_orange = _make_portal_visual(Vector2(860, 260), COLOR_ACCENT_ORANGE, 40.0)
	add_child(portal_orange)

	# Connection line between portals
	var conn = ColorRect.new()
	conn.color = Color(0.5, 0.5, 0.6, 0.3)
	conn.position = Vector2(460, 258)
	conn.size = Vector2(360, 4)
	add_child(conn)

	# Title text
	var title = Label.new()
	title.text = "PORTAL LAB"
	title.position = Vector2(0, 140)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_DARK)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Aperture Testing Initiative"
	subtitle.position = Vector2(0, 210)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48))
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	# Start button
	var start_btn = _make_button("BEGIN TESTING", Vector2(490, 420))
	start_btn.pressed.connect(func(): main._enter_chamber_select())
	add_child(start_btn)

	# Chamber select button
	var select_btn = _make_button("SELECT CHAMBER", Vector2(490, 500))
	select_btn.pressed.connect(func(): main._enter_chamber_select())
	add_child(select_btn)

func _draw_grid() -> void:
	for x_i in range(0, 26):
		var line = ColorRect.new()
		line.color = COLOR_GRID
		line.position = Vector2(x_i * 50, 0)
		line.size = Vector2(1, 720)
		add_child(line)
	for y_i in range(0, 15):
		var line = ColorRect.new()
		line.color = COLOR_GRID
		line.position = Vector2(0, y_i * 50)
		line.size = Vector2(1280, 1)
		add_child(line)

func _make_portal_visual(pos: Vector2, color: Color, radius: float) -> Node2D:
	var container = Node2D.new()
	container.position = pos
	# Outer glow
	var outer = ColorRect.new()
	outer.color = Color(color.r, color.g, color.b, 0.3)
	outer.position = Vector2(-radius - 8, -radius - 8)
	outer.size = Vector2((radius + 8) * 2, (radius + 8) * 2)
	container.add_child(outer)
	# Inner ring
	var inner = ColorRect.new()
	inner.color = color
	inner.position = Vector2(-radius, -radius)
	inner.size = Vector2(radius * 2, radius * 2)
	container.add_child(inner)
	# Center dark
	var center = ColorRect.new()
	center.color = Color(0.05, 0.05, 0.1)
	center.position = Vector2(-radius + 8, -radius + 8)
	center.size = Vector2((radius - 8) * 2, (radius - 8) * 2)
	container.add_child(center)
	return container

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_DARK
	sb.border_color = COLOR_ACCENT_BLUE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	b.add_theme_font_size_override("font_size", 24)
	return b
