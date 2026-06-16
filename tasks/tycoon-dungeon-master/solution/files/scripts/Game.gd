extends Node2D

signal game_over(stats: Dictionary)

const GRID_COLS: int = 8
const GRID_ROWS: int = 5
const CELL_SIZE: int = 80
const GRID_OFFSET: Vector2 = Vector2(80, 140)

enum RoomType { EMPTY, DUG, TRAP, BARRACKS, HATCHERY, TREASURE }

var grid: Array = []
var gold: int = 200
var food: int = 50
var morale: int = 100
var day: int = 1
var wave: int = 0
var monsters: int = 0
var heroes_defeated: int = 0
var selected_type: int = RoomType.DUG
var wave_timer: float = 0.0
var wave_active: bool = false
var combat_log: Array = []
var game_ended: bool = false

var gold_label: Label = null
var food_label: Label = null
var morale_label: Label = null
var day_label: Label = null
var log_label: Label = null
var cells: Array = []

func _ready() -> void:
	_init_grid()
	_build_ui()
	var sc: String = ""
	if has_meta("scenario"):
		sc = str(get_meta("scenario"))
	if sc == "combat":
		_setup_combat_scenario()
	elif sc == "wave1":
		_setup_wave1_scenario()

func _init_grid() -> void:
	for r in range(GRID_ROWS):
		var row: Array = []
		for c in range(GRID_COLS):
			row.append(RoomType.EMPTY)
		grid.append(row)

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.1)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# HUD
	gold_label = Label.new()
	gold_label.position = Vector2(80, 20)
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
	add_child(gold_label)

	food_label = Label.new()
	food_label.position = Vector2(280, 20)
	food_label.add_theme_font_size_override("font_size", 20)
	food_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.3))
	add_child(food_label)

	morale_label = Label.new()
	morale_label.position = Vector2(480, 20)
	morale_label.add_theme_font_size_override("font_size", 20)
	morale_label.add_theme_color_override("font_color", Color(0.6, 0.6, 1))
	add_child(morale_label)

	day_label = Label.new()
	day_label.position = Vector2(680, 20)
	day_label.add_theme_font_size_override("font_size", 20)
	day_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(day_label)

	_update_hud()
	_draw_grid()
	_build_buttons()

	log_label = Label.new()
	log_label.position = Vector2(760, 140)
	log_label.size = Vector2(480, 400)
	log_label.add_theme_font_size_override("font_size", 16)
	log_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(log_label)

func _draw_grid() -> void:
	for child in cells:
		child.queue_free()
	cells.clear()
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var cell: ColorRect = ColorRect.new()
			cell.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			cell.position = GRID_OFFSET + Vector2(c * CELL_SIZE + 2, r * CELL_SIZE + 2)
			cell.color = _room_color(grid[r][c])
			add_child(cell)
			cells.append(cell)

func _room_color(t: int) -> Color:
	match t:
		RoomType.EMPTY:
			return Color(0.15, 0.12, 0.1)
		RoomType.DUG:
			return Color(0.3, 0.2, 0.15)
		RoomType.TRAP:
			return Color(0.7, 0.2, 0.2)
		RoomType.BARRACKS:
			return Color(0.2, 0.4, 0.7)
		RoomType.HATCHERY:
			return Color(0.2, 0.6, 0.3)
		RoomType.TREASURE:
			return Color(0.8, 0.7, 0.1)
		_:
			return Color(0.1, 0.1, 0.1)

func _build_buttons() -> void:
	var types: Array = ["Dig", "Trap", "Barracks", "Hatchery", "Treasure"]
	var type_vals: Array = [RoomType.DUG, RoomType.TRAP, RoomType.BARRACKS, RoomType.HATCHERY, RoomType.TREASURE]
	for i in range(types.size()):
		var btn: Button = Button.new()
		var label_text: String = types[i]
		btn.text = label_text
		btn.position = Vector2(80 + i * 130, 580)
		btn.custom_minimum_size = Vector2(120, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.25, 0.2, 0.3)
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4
		s.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		var tv: int = type_vals[i]
		btn.pressed.connect(_select_type.bind(tv))
		add_child(btn)

	# Recruit button
	var recruit_btn: Button = Button.new()
	recruit_btn.text = "Recruit Monster (-30g -10f)"
	recruit_btn.position = Vector2(80, 640)
	recruit_btn.custom_minimum_size = Vector2(250, 40)
	recruit_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var rs: StyleBoxFlat = StyleBoxFlat.new()
	rs.bg_color = Color(0.4, 0.15, 0.5)
	rs.corner_radius_top_left = 4
	rs.corner_radius_top_right = 4
	rs.corner_radius_bottom_left = 4
	rs.corner_radius_bottom_right = 4
	recruit_btn.add_theme_stylebox_override("normal", rs)
	recruit_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	recruit_btn.pressed.connect(_recruit_monster)
	add_child(recruit_btn)

	# Send wave button
	var wave_btn: Button = Button.new()
	wave_btn.text = "Send Hero Wave"
	wave_btn.position = Vector2(400, 640)
	wave_btn.custom_minimum_size = Vector2(180, 40)
	wave_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var ws: StyleBoxFlat = StyleBoxFlat.new()
	ws.bg_color = Color(0.1, 0.4, 0.5)
	ws.corner_radius_top_left = 4
	ws.corner_radius_top_right = 4
	ws.corner_radius_bottom_left = 4
	ws.corner_radius_bottom_right = 4
	wave_btn.add_theme_stylebox_override("normal", ws)
	wave_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	wave_btn.pressed.connect(_start_wave)
	add_child(wave_btn)

func _select_type(t: int) -> void:
	selected_type = t

func _recruit_monster() -> void:
	if gold >= 30 and food >= 10:
		gold -= 30
		food -= 10
		monsters += 1
		_add_log("Recruited a monster! Total: " + str(monsters))
		_update_hud()

func _start_wave() -> void:
	if wave_active or game_ended:
		return
	wave += 1
	day += 1
	wave_active = true
	wave_timer = 2.0
	var hero_count: int = wave + 1
	var trap_count: int = _count_rooms(RoomType.TRAP)
	var barracks_count: int = _count_rooms(RoomType.BARRACKS)
	var defense: int = monsters * 2 + trap_count * 3 + barracks_count * 2
	var attack: int = hero_count * 3
	_add_log("--- Wave " + str(wave) + " ---")
	_add_log(str(hero_count) + " heroes attack! (power " + str(attack) + ")")
	_add_log("Your defense: " + str(defense))
	if defense >= attack:
		heroes_defeated += hero_count
		gold += hero_count * 10
		_add_log("Heroes defeated! Loot: " + str(hero_count * 10) + "g")
	else:
		var lost: int = attack - defense
		morale -= lost * 5
		_add_log("Heroes broke through! Morale -" + str(lost * 5))
	_update_hud()
	if morale <= 0:
		_end_game()

func _count_rooms(t: int) -> int:
	var count: int = 0
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if grid[r][c] == t:
				count += 1
	return count

func _process(delta: float) -> void:
	if wave_active:
		wave_timer -= delta
		if wave_timer <= 0:
			wave_active = false

func _input(event: InputEvent) -> void:
	if game_ended:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_grid_click(mb.position)

func _handle_grid_click(pos: Vector2) -> void:
	var local: Vector2 = pos - GRID_OFFSET
	if local.x < 0 or local.y < 0:
		return
	var c: int = int(local.x) / CELL_SIZE
	var r: int = int(local.y) / CELL_SIZE
	if r < 0 or r >= GRID_ROWS or c < 0 or c >= GRID_COLS:
		return
	var cost: int = 10
	if selected_type == RoomType.TRAP:
		cost = 25
	elif selected_type == RoomType.BARRACKS:
		cost = 30
	elif selected_type == RoomType.HATCHERY:
		cost = 20
	elif selected_type == RoomType.TREASURE:
		cost = 40
	if gold < cost:
		_add_log("Not enough gold!")
		return
	if grid[r][c] == RoomType.EMPTY or (grid[r][c] == RoomType.DUG and selected_type != RoomType.DUG):
		gold -= cost
		grid[r][c] = selected_type
		_draw_grid()
		_update_hud()
		_add_log("Built room at (" + str(c) + "," + str(r) + ")")

func _update_hud() -> void:
	gold_label.text = "Gold: " + str(gold)
	food_label.text = "Food: " + str(food)
	morale_label.text = "Morale: " + str(morale)
	day_label.text = "Day: " + str(day) + "  Wave: " + str(wave) + "  Monsters: " + str(monsters)

func _add_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 12:
		combat_log.pop_front()
	var text: String = ""
	for line in combat_log:
		text += line + "\n"
	log_label.text = text

func _end_game() -> void:
	game_ended = true
	var stats: Dictionary = {
		"waves_survived": wave,
		"heroes_defeated": heroes_defeated,
		"gold_remaining": gold,
		"monsters": monsters,
		"rooms_built": _count_rooms(RoomType.TRAP) + _count_rooms(RoomType.BARRACKS) + _count_rooms(RoomType.HATCHERY) + _count_rooms(RoomType.TREASURE)
	}
	emit_signal("game_over", stats)

func _setup_wave1_scenario() -> void:
	grid[0][0] = RoomType.DUG
	grid[0][1] = RoomType.BARRACKS
	grid[1][0] = RoomType.TRAP
	monsters = 2
	_draw_grid()
	_update_hud()
	_add_log("Scenario: wave1 loaded")

func _setup_combat_scenario() -> void:
	for r in range(3):
		for c in range(4):
			grid[r][c] = RoomType.DUG
	grid[0][0] = RoomType.TRAP
	grid[0][1] = RoomType.TRAP
	grid[1][0] = RoomType.BARRACKS
	grid[1][1] = RoomType.BARRACKS
	grid[2][0] = RoomType.HATCHERY
	grid[2][1] = RoomType.TREASURE
	monsters = 5
	gold = 300
	food = 80
	_draw_grid()
	_update_hud()
	_add_log("Scenario: combat loaded")
	_start_wave()
