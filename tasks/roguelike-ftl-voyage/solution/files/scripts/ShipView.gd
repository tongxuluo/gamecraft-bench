extends Node2D

var main: Node = null

const COLOR_BG = Color(0.05, 0.06, 0.09)
const COLOR_ROOM = Color(0.15, 0.18, 0.22)
const COLOR_ROOM_BORDER = Color(0.4, 0.5, 0.6)
const COLOR_CREW = Color(0.2, 0.8, 0.3)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_HULL = Color(0.3, 0.35, 0.4)
const COLOR_ACCENT = Color(0.3, 0.6, 0.9)

var room_rects: Dictionary = {}
var crew_nodes: Array = []
var dragging_crew: int = -1
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Ship hull outline
	var hull_rect = ColorRect.new()
	hull_rect.color = COLOR_HULL
	hull_rect.size = Vector2(600, 300)
	hull_rect.position = Vector2(340, 180)
	add_child(hull_rect)

	# Rooms
	_add_room("weapons", Vector2(380, 220), Vector2(120, 100), "WEAPONS")
	_add_room("shields", Vector2(540, 220), Vector2(120, 100), "SHIELDS")
	_add_room("engines", Vector2(700, 220), Vector2(120, 100), "ENGINES")
	_add_room("medbay", Vector2(540, 350), Vector2(120, 100), "MEDBAY")

	# Crew dots
	for i in range(main.crew.size()):
		var c = main.crew[i]
		var crew_dot = ColorRect.new()
		crew_dot.color = COLOR_CREW
		crew_dot.size = Vector2(20, 20)
		var room_pos = _get_room_center(c.room)
		crew_dot.position = room_pos + Vector2(i * 25 - 20, 30)
		add_child(crew_dot)
		crew_nodes.append(crew_dot)

		# Crew name label
		var name_lbl = Label.new()
		name_lbl.text = c.name
		name_lbl.position = crew_dot.position + Vector2(-10, -18)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		add_child(name_lbl)

	# HUD
	_draw_hud()

	# Back to map button
	var back_btn = _make_button("SECTOR MAP", Vector2(1080, 650))
	back_btn.pressed.connect(func(): main._enter_sector_map())
	add_child(back_btn)

	# Instructions
	var instr = Label.new()
	instr.text = "Drag crew (green dots) between rooms to assign them."
	instr.position = Vector2(340, 520)
	instr.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	instr.add_theme_font_size_override("font_size", 16)
	add_child(instr)

func _add_room(room_id: String, pos: Vector2, sz: Vector2, label_text: String) -> void:
	var room = ColorRect.new()
	room.color = COLOR_ROOM
	room.size = sz
	room.position = pos
	add_child(room)

	# Border
	var border_top = ColorRect.new()
	border_top.color = COLOR_ROOM_BORDER
	border_top.size = Vector2(sz.x, 2)
	border_top.position = pos
	add_child(border_top)

	var border_bot = ColorRect.new()
	border_bot.color = COLOR_ROOM_BORDER
	border_bot.size = Vector2(sz.x, 2)
	border_bot.position = pos + Vector2(0, sz.y - 2)
	add_child(border_bot)

	var border_left = ColorRect.new()
	border_left.color = COLOR_ROOM_BORDER
	border_left.size = Vector2(2, sz.y)
	border_left.position = pos
	add_child(border_left)

	var border_right = ColorRect.new()
	border_right.color = COLOR_ROOM_BORDER
	border_right.size = Vector2(2, sz.y)
	border_right.position = pos + Vector2(sz.x - 2, 0)
	add_child(border_right)

	# Room label
	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = pos + Vector2(10, 5)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(lbl)

	# Power indicator
	var sys = main.systems[room_id]
	var pwr_lbl = Label.new()
	pwr_lbl.text = "PWR: " + str(sys.power) + "/" + str(sys.max_power)
	pwr_lbl.position = pos + Vector2(10, 75)
	pwr_lbl.add_theme_font_size_override("font_size", 12)
	pwr_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	add_child(pwr_lbl)

	room_rects[room_id] = Rect2(pos, sz)

func _get_room_center(room_id: String) -> Vector2:
	var positions = {
		"weapons": Vector2(420, 250),
		"shields": Vector2(580, 250),
		"engines": Vector2(740, 250),
		"medbay": Vector2(580, 380),
	}
	if positions.has(room_id):
		return positions[room_id]
	return Vector2(500, 300)

func _draw_hud() -> void:
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.08, 0.09, 0.12)
	hud_bg.size = Vector2(1280, 50)
	add_child(hud_bg)

	var fuel_lbl = Label.new()
	fuel_lbl.text = "FUEL: " + str(main.fuel)
	fuel_lbl.position = Vector2(20, 12)
	fuel_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	fuel_lbl.add_theme_font_size_override("font_size", 20)
	add_child(fuel_lbl)

	var scrap_lbl = Label.new()
	scrap_lbl.text = "SCRAP: " + str(main.scrap)
	scrap_lbl.position = Vector2(200, 12)
	scrap_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	scrap_lbl.add_theme_font_size_override("font_size", 20)
	add_child(scrap_lbl)

	var hull_lbl = Label.new()
	hull_lbl.text = "HULL: " + str(main.hull) + "/" + str(main.max_hull)
	hull_lbl.position = Vector2(400, 12)
	hull_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3))
	hull_lbl.add_theme_font_size_override("font_size", 20)
	add_child(hull_lbl)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(160, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.18, 0.25)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 18)
	return b

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking on a crew dot
				for i in range(crew_nodes.size()):
					var dot = crew_nodes[i]
					var rect = Rect2(dot.position, dot.size)
					if rect.has_point(event.position):
						dragging_crew = i
						drag_offset = dot.position - event.position
						break
			else:
				if dragging_crew >= 0:
					# Drop crew into room
					for room_id in room_rects:
						if room_rects[room_id].has_point(event.position):
							main.crew[dragging_crew].room = room_id
							break
					# Snap back to room position
					var c = main.crew[dragging_crew]
					var room_pos = _get_room_center(c.room)
					crew_nodes[dragging_crew].position = room_pos + Vector2(dragging_crew * 25 - 20, 30)
					dragging_crew = -1
	elif event is InputEventMouseMotion:
		if dragging_crew >= 0:
			crew_nodes[dragging_crew].position = event.position + drag_offset
