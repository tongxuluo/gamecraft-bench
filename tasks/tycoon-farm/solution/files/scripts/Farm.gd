extends Node2D

var main: Node = null
var save_state: Dictionary = {}
var harvest_ready_scenario: bool = false

const TILE_SIZE := 64
const GRID_W := 8
const GRID_H := 6
const GRID_X := 320
const GRID_Y := 140

const COLOR_GRASS := Color(0.4, 0.7, 0.3)
const COLOR_TILLED := Color(0.45, 0.35, 0.25)
const COLOR_WATERED := Color(0.35, 0.25, 0.18)
const COLOR_FENCE := Color(0.5, 0.4, 0.3)
const COLOR_HOUSE := Color(0.6, 0.55, 0.5)
const COLOR_ROOF := Color(0.7, 0.3, 0.2)
const COLOR_PLAYER := Color(0.9, 0.8, 0.6)
const COLOR_PANEL := Color(0.55, 0.45, 0.35)
const COLOR_TEXT := Color(0.95, 0.95, 0.90)

const CROP_COLORS := [Color(0.8, 0.9, 0.3), Color(1.0, 0.6, 0.2), Color(0.9, 0.3, 0.5)]
const CROP_GROWTH_DAYS := [1, 2, 3]

enum TileState { GRASS, TILLED, WATERED, PLANTED, MATURE }

var tiles: Array = []
var tile_rects: Array = []
var player_pos := Vector2i(3, 3)
var player_rect: ColorRect = null
var day := 1
var gold := 50
var stamina := 10
var max_stamina := 10
var inventory: Array = []
var inventory_capacity := 6
var current_seed_type := 0

var stamina_bar: ColorRect = null
var stamina_label: Label = null
var gold_label: Label = null
var day_label: Label = null
var inventory_slots: Array = []
var error_banner: ColorRect = null
var error_timer := 0.0

var day_end_panel: Control = null
var fade_overlay: ColorRect = null
var fade_state := 0
var fade_timer := 0.0

func _ready() -> void:
	if save_state.size() > 0:
		day = save_state.get("day", 1)
		gold = save_state.get("gold", 50)
		stamina = save_state.get("stamina", max_stamina)
		inventory = save_state.get("inventory", [])
		var saved_tiles = save_state.get("tiles", [])
		if saved_tiles.size() == GRID_W * GRID_H:
			tiles = saved_tiles.duplicate(true)

	if tiles.size() == 0:
		for y in GRID_H:
			for x in GRID_W:
				tiles.append({
					"state": TileState.GRASS,
					"crop_type": 0,
					"days_planted": 0
				})

	if harvest_ready_scenario:
		day = 1
		gold = 50
		stamina = max_stamina
		inventory = []
		for i in tiles.size():
			tiles[i] = {"state": TileState.GRASS, "crop_type": 0, "days_planted": 0}
		var idx = player_pos.y * GRID_W + player_pos.x + 1
		if idx < tiles.size():
			tiles[idx]["state"] = TileState.MATURE
			tiles[idx]["crop_type"] = 0
			tiles[idx]["days_planted"] = CROP_GROWTH_DAYS[0]

	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.5, 0.65, 0.4)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	for i in range(4):
		var fence := ColorRect.new()
		fence.color = COLOR_FENCE
		if i == 0:
			fence.position = Vector2(GRID_X - 10, GRID_Y - 10)
			fence.size = Vector2(GRID_W * TILE_SIZE + 20, 10)
		elif i == 1:
			fence.position = Vector2(GRID_X - 10, GRID_Y + GRID_H * TILE_SIZE)
			fence.size = Vector2(GRID_W * TILE_SIZE + 20, 10)
		elif i == 2:
			fence.position = Vector2(GRID_X - 10, GRID_Y - 10)
			fence.size = Vector2(10, GRID_H * TILE_SIZE + 20)
		else:
			fence.position = Vector2(GRID_X + GRID_W * TILE_SIZE, GRID_Y - 10)
			fence.size = Vector2(10, GRID_H * TILE_SIZE + 20)
		add_child(fence)

	for y in GRID_H:
		for x in GRID_W:
			var tile_rect := ColorRect.new()
			tile_rect.position = Vector2(GRID_X + x * TILE_SIZE, GRID_Y + y * TILE_SIZE)
			tile_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			tile_rect.color = COLOR_GRASS
			add_child(tile_rect)
			tile_rects.append(tile_rect)

	var house := ColorRect.new()
	house.color = COLOR_HOUSE
	house.position = Vector2(GRID_X + GRID_W * TILE_SIZE + 40, GRID_Y + 100)
	house.size = Vector2(120, 100)
	add_child(house)

	var roof := ColorRect.new()
	roof.color = COLOR_ROOF
	roof.position = Vector2(GRID_X + GRID_W * TILE_SIZE + 30, GRID_Y + 80)
	roof.size = Vector2(140, 30)
	add_child(roof)

	player_rect = ColorRect.new()
	player_rect.color = COLOR_PLAYER
	player_rect.size = Vector2(32, 32)
	add_child(player_rect)
	_update_player_visual()

	_build_hud()
	_update_tiles()

func _build_hud() -> void:
	var stamina_panel := PanelContainer.new()
	stamina_panel.position = Vector2(20, 20)
	stamina_panel.size = Vector2(200, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = Color(0.35, 0.25, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	stamina_panel.add_theme_stylebox_override("panel", sb)
	add_child(stamina_panel)

	var stamina_vbox := VBoxContainer.new()
	stamina_panel.add_child(stamina_vbox)

	stamina_label = Label.new()
	stamina_label.text = "Stamina"
	stamina_label.add_theme_color_override("font_color", COLOR_TEXT)
	stamina_label.add_theme_font_size_override("font_size", 18)
	stamina_vbox.add_child(stamina_label)

	stamina_bar = ColorRect.new()
	stamina_bar.color = Color(0.3, 0.8, 0.3)
	stamina_bar.custom_minimum_size = Vector2(180, 20)
	stamina_vbox.add_child(stamina_bar)

	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(1060, 20)
	info_panel.size = Vector2(200, 80)
	info_panel.add_theme_stylebox_override("panel", sb.duplicate())
	add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_panel.add_child(info_vbox)

	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", COLOR_TEXT)
	gold_label.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(gold_label)

	day_label = Label.new()
	day_label.add_theme_color_override("font_color", COLOR_TEXT)
	day_label.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(day_label)

	var inv_panel := PanelContainer.new()
	inv_panel.position = Vector2(440, 640)
	inv_panel.size = Vector2(400, 60)
	inv_panel.add_theme_stylebox_override("panel", sb.duplicate())
	add_child(inv_panel)

	var inv_hbox := HBoxContainer.new()
	inv_hbox.add_theme_constant_override("separation", 8)
	inv_panel.add_child(inv_hbox)

	for i in inventory_capacity:
		var slot := ColorRect.new()
		slot.color = Color(0.3, 0.25, 0.2)
		slot.custom_minimum_size = Vector2(50, 50)
		inv_hbox.add_child(slot)
		inventory_slots.append(slot)

	error_banner = ColorRect.new()
	error_banner.color = Color(0.9, 0.2, 0.2, 0.8)
	error_banner.position = Vector2(440, 350)
	error_banner.size = Vector2(400, 60)
	error_banner.visible = false
	add_child(error_banner)

	var error_label := Label.new()
	error_label.text = "Cannot perform action!"
	error_label.position = Vector2(0, 0)
	error_label.size = Vector2(400, 60)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color.WHITE)
	error_label.add_theme_font_size_override("font_size", 24)
	error_banner.add_child(error_label)

	_update_hud()

func _update_hud() -> void:
	var bar_width = 180.0 * stamina / max_stamina
	stamina_bar.size = Vector2(bar_width, 20)
	gold_label.text = "Gold: %d" % gold
	day_label.text = "Day %d" % day

	for i in inventory_capacity:
		if i < inventory.size():
			var crop_type = inventory[i]
			inventory_slots[i].color = CROP_COLORS[crop_type]
		else:
			inventory_slots[i].color = Color(0.3, 0.25, 0.2)

func _update_tiles() -> void:
	var idx := 0
	for y in GRID_H:
		for x in GRID_W:
			var tile = tiles[idx]
			var tile_node = tile_rects[idx]
			match tile["state"]:
				TileState.GRASS:
					tile_node.color = COLOR_GRASS
				TileState.TILLED:
					tile_node.color = COLOR_TILLED
				TileState.WATERED:
					tile_node.color = COLOR_WATERED
				TileState.PLANTED:
					tile_node.color = COLOR_WATERED
				TileState.MATURE:
					tile_node.color = COLOR_WATERED

			if tile["state"] == TileState.PLANTED:
				var sprout = _find_or_create_sprout(idx)
				sprout.visible = true
				sprout.color = CROP_COLORS[tile["crop_type"]]
				sprout.size = Vector2(16, 16)
			elif tile["state"] == TileState.MATURE:
				var sprout = _find_or_create_sprout(idx)
				sprout.visible = true
				sprout.color = CROP_COLORS[tile["crop_type"]]
				sprout.size = Vector2(40, 40)
			else:
				var sprout = _find_or_create_sprout(idx)
				sprout.visible = false

			idx += 1

func _find_or_create_sprout(tile_idx: int) -> ColorRect:
	var tag = "sprout_%d" % tile_idx
	for child in get_children():
		if child.has_meta("tile_sprout") and child.get_meta("tile_sprout") == tag:
			return child
	var sprout := ColorRect.new()
	sprout.set_meta("tile_sprout", tag)
	var x = tile_idx % GRID_W
	var y = tile_idx / GRID_W
	sprout.position = Vector2(GRID_X + x * TILE_SIZE + 12, GRID_Y + y * TILE_SIZE + 12)
	sprout.visible = false
	add_child(sprout)
	return sprout

func _update_player_visual() -> void:
	player_rect.position = Vector2(
		GRID_X + player_pos.x * TILE_SIZE + 16,
		GRID_Y + player_pos.y * TILE_SIZE + 16
	)

func _process(delta: float) -> void:
	if error_timer > 0:
		error_timer -= delta
		if error_timer <= 0:
			error_banner.visible = false

	if fade_state > 0:
		fade_timer += delta
		if fade_state == 1:
			if fade_timer >= 1.0:
				fade_overlay.modulate.a = 1.0
				fade_state = 2
				fade_timer = 0.0
			else:
				fade_overlay.modulate.a = fade_timer
		elif fade_state == 2:
			if fade_timer >= 0.5:
				_advance_day()
				fade_state = 3
				fade_timer = 0.0
		elif fade_state == 3:
			if fade_timer >= 1.0:
				fade_overlay.visible = false
				fade_state = 0
			else:
				fade_overlay.modulate.a = 1.0 - fade_timer

func _input(event: InputEvent) -> void:
	if day_end_panel != null and day_end_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			day_end_panel.visible = false
			_start_fade()
		return

	if fade_state > 0:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_try_move(0, -1)
			KEY_DOWN:
				_try_move(0, 1)
			KEY_LEFT:
				_try_move(-1, 0)
			KEY_RIGHT:
				_try_move(1, 0)
			KEY_1:
				_action_till()
			KEY_2:
				_action_water()
			KEY_3:
				_action_plant()
			KEY_4:
				_action_harvest()
			KEY_SPACE:
				_action_sleep()

func _try_move(dx: int, dy: int) -> void:
	var new_x = player_pos.x + dx
	var new_y = player_pos.y + dy
	if new_x >= 0 and new_x < GRID_W and new_y >= 0 and new_y < GRID_H:
		player_pos = Vector2i(new_x, new_y)
		_update_player_visual()

func _action_till() -> void:
	if stamina <= 0:
		_show_error()
		return
	var idx = player_pos.y * GRID_W + player_pos.x
	if tiles[idx]["state"] == TileState.GRASS:
		tiles[idx]["state"] = TileState.TILLED
		stamina -= 1
		_update_tiles()
		_update_hud()
	else:
		_show_error()

func _action_water() -> void:
	if stamina <= 0:
		_show_error()
		return
	var idx = player_pos.y * GRID_W + player_pos.x
	if tiles[idx]["state"] == TileState.TILLED or tiles[idx]["state"] == TileState.PLANTED:
		tiles[idx]["state"] = TileState.WATERED if tiles[idx]["state"] == TileState.TILLED else TileState.PLANTED
		stamina -= 1
		_update_tiles()
		_update_hud()
	else:
		_show_error()

func _action_plant() -> void:
	if stamina <= 0:
		_show_error()
		return
	var idx = player_pos.y * GRID_W + player_pos.x
	if tiles[idx]["state"] == TileState.WATERED:
		tiles[idx]["state"] = TileState.PLANTED
		tiles[idx]["crop_type"] = current_seed_type
		tiles[idx]["days_planted"] = 0
		stamina -= 1
		current_seed_type = (current_seed_type + 1) % 3
		_update_tiles()
		_update_hud()
	else:
		_show_error()

func _action_harvest() -> void:
	if stamina <= 0:
		_show_error()
		return
	var idx = player_pos.y * GRID_W + player_pos.x
	if tiles[idx]["state"] == TileState.MATURE:
		if inventory.size() >= inventory_capacity:
			_show_error()
			return
		inventory.append(tiles[idx]["crop_type"])
		tiles[idx]["state"] = TileState.GRASS
		tiles[idx]["crop_type"] = 0
		tiles[idx]["days_planted"] = 0
		stamina -= 1
		_update_tiles()
		_update_hud()
	else:
		_show_error()

func _action_sleep() -> void:
	var house_x = GRID_X + GRID_W * TILE_SIZE + 40
	var house_y = GRID_Y + 100
	var px = GRID_X + player_pos.x * TILE_SIZE + 16
	var py = GRID_Y + player_pos.y * TILE_SIZE + 16
	if abs(px - house_x) < 100 and abs(py - house_y) < 100:
		_show_day_end_panel()

func _show_error() -> void:
	error_banner.visible = true
	error_timer = 0.5

func _show_day_end_panel() -> void:
	var harvested = inventory.size()
	var earned = harvested * 10
	gold += earned

	day_end_panel = PanelContainer.new()
	day_end_panel.position = Vector2(340, 200)
	day_end_panel.size = Vector2(600, 320)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = Color(0.35, 0.25, 0.15)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	day_end_panel.add_theme_stylebox_override("panel", sb)
	add_child(day_end_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	day_end_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Day %d End" % day
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var summary := Label.new()
	summary.text = "Harvested: %d crops\nEarned: %d gold" % [harvested, earned]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_color_override("font_color", COLOR_TEXT)
	summary.add_theme_font_size_override("font_size", 28)
	vbox.add_child(summary)

	var hint := Label.new()
	hint.text = "Press SPACE to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	hint.add_theme_font_size_override("font_size", 20)
	vbox.add_child(hint)

	inventory.clear()
	_update_hud()

func _start_fade() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = Vector2(1280, 720)
	fade_overlay.modulate.a = 0.0
	add_child(fade_overlay)
	fade_state = 1
	fade_timer = 0.0

func _advance_day() -> void:
	day += 1
	stamina = max_stamina

	for tile in tiles:
		if tile["state"] == TileState.PLANTED:
			tile["days_planted"] += 1
			if tile["days_planted"] >= CROP_GROWTH_DAYS[tile["crop_type"]]:
				tile["state"] = TileState.MATURE

	_update_tiles()
	_update_hud()
	_save_game()

func _save_game() -> void:
	var state := {
		"day": day,
		"gold": gold,
		"stamina": stamina,
		"inventory": inventory.duplicate(),
		"tiles": tiles.duplicate(true)
	}
	main.write_save(state)
