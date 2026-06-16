extends Node2D

var main: Node = null
var scenario_id: String = ""

# Grid: 5x5, cell 100px, centered
const COLS = 5
const ROWS = 5
const CELL = 100
const ORIGIN = Vector2(290, 110)

const COLOR_BG = Color(0.05, 0.06, 0.08)
const COLOR_TILE_A = Color(0.14, 0.16, 0.19)
const COLOR_TILE_B = Color(0.17, 0.19, 0.22)
const COLOR_BUILDING = Color(0.25, 0.50, 0.75)
const COLOR_BUILDING_DMG = Color(0.70, 0.35, 0.20)
const COLOR_MECH_PUNCH = Color(0.30, 0.65, 0.90)
const COLOR_MECH_ARTILLERY = Color(0.85, 0.60, 0.25)
const COLOR_MECH_SHIELD = Color(0.40, 0.80, 0.50)
const COLOR_ENEMY = Color(0.80, 0.25, 0.25)
const COLOR_INTENT = Color(1.0, 0.40, 0.40, 0.8)
const COLOR_ACCENT = Color(0.30, 0.65, 0.90)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)
const COLOR_TEXT = Color(0.90, 0.93, 0.96)
const COLOR_SELECT = Color(0.90, 0.85, 0.30, 0.6)

const MAX_TURNS = 4

# State
var turn = 0
var phase = "player"  # player, enemy_execute, game_over
var selected_mech = -1
var mechs = []  # [{cell, type, hp, max_hp, has_moved, has_acted}]
var enemies = []  # [{cell, hp, intent_dir, intent_type}]
var buildings = []  # [{cell, hp, max_hp}]

# Visual nodes
var grid_tiles = []
var mech_sprites = []
var enemy_sprites = []
var building_sprites = []
var intent_arrows = []
var select_highlight: ColorRect = null
var info_label: Label = null
var turn_label: Label = null
var phase_label: Label = null
var end_turn_btn: Button = null
var status_label: Label = null

func _ready() -> void:
	_build_bg()
	_init_state()
	_build_grid()
	_build_buildings()
	_build_mechs()
	_spawn_enemies_for_turn()
	_build_hud()
	_refresh_all()

func _build_bg() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

func _init_state() -> void:
	# Buildings at fixed positions
	if scenario_id == "building_save":
		buildings = [
			{"cell": Vector2i(1, 1), "hp": 1, "max_hp": 3},
			{"cell": Vector2i(3, 1), "hp": 3, "max_hp": 3},
			{"cell": Vector2i(2, 3), "hp": 2, "max_hp": 3},
			{"cell": Vector2i(4, 4), "hp": 3, "max_hp": 3},
		]
		turn = 2
	else:
		buildings = [
			{"cell": Vector2i(1, 1), "hp": 3, "max_hp": 3},
			{"cell": Vector2i(3, 1), "hp": 3, "max_hp": 3},
			{"cell": Vector2i(2, 3), "hp": 3, "max_hp": 3},
			{"cell": Vector2i(4, 4), "hp": 3, "max_hp": 3},
		]
	# Mechs: punch (melee push), artillery (ranged), shield (protect adjacent)
	mechs = [
		{"cell": Vector2i(0, 2), "type": "punch", "hp": 4, "max_hp": 4, "has_moved": false, "has_acted": false},
		{"cell": Vector2i(2, 4), "type": "artillery", "hp": 3, "max_hp": 3, "has_moved": false, "has_acted": false},
		{"cell": Vector2i(4, 2), "type": "shield", "hp": 5, "max_hp": 5, "has_moved": false, "has_acted": false},
	]

func _build_grid() -> void:
	for r in range(ROWS):
		for c in range(COLS):
			var tile = ColorRect.new()
			tile.color = COLOR_TILE_A if (c + r) % 2 == 0 else COLOR_TILE_B
			tile.position = ORIGIN + Vector2(c * CELL, r * CELL)
			tile.size = Vector2(CELL, CELL)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tile)
			grid_tiles.append(tile)
			# Grid border
			var border = ColorRect.new()
			border.color = Color(0.25, 0.28, 0.32)
			border.position = tile.position
			border.size = Vector2(CELL, 2)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(border)
			var border_l = ColorRect.new()
			border_l.color = Color(0.25, 0.28, 0.32)
			border_l.position = tile.position
			border_l.size = Vector2(2, CELL)
			border_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(border_l)
	# Selection highlight
	select_highlight = ColorRect.new()
	select_highlight.color = COLOR_SELECT
	select_highlight.size = Vector2(CELL, CELL)
	select_highlight.visible = false
	select_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(select_highlight)

func _build_buildings() -> void:
	for b in buildings:
		var sprite = ColorRect.new()
		sprite.size = Vector2(CELL - 20, CELL - 20)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		var lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(CELL - 20, 20)
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		building_sprites.append({"rect": sprite, "label": lbl})

func _build_mechs() -> void:
	for m in mechs:
		var sprite = ColorRect.new()
		sprite.size = Vector2(CELL - 16, CELL - 16)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		var lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(CELL - 16, 20)
		lbl.add_theme_color_override("font_color", Color(0, 0, 0))
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		var hp_lbl = Label.new()
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.size = Vector2(CELL, 16)
		hp_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
		hp_lbl.add_theme_font_size_override("font_size", 12)
		hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hp_lbl)
		mech_sprites.append({"rect": sprite, "label": lbl, "hp_label": hp_lbl})

func _spawn_enemies_for_turn() -> void:
	enemies.clear()
	# Clear old enemy sprites
	for es in enemy_sprites:
		if is_instance_valid(es.rect):
			es.rect.queue_free()
		if is_instance_valid(es.label):
			es.label.queue_free()
	enemy_sprites.clear()
	for ia in intent_arrows:
		if is_instance_valid(ia):
			ia.queue_free()
	intent_arrows.clear()

	var spawn_count = 2 + turn
	if spawn_count > 5:
		spawn_count = 5
	var occupied = _get_occupied_cells()
	var rng = RandomNumberGenerator.new()
	rng.seed = turn * 1000 + 42
	for i in range(spawn_count):
		var cell = Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4))
		var attempts = 0
		while occupied.has(cell) and attempts < 20:
			cell = Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4))
			attempts += 1
		if occupied.has(cell):
			continue
		occupied.append(cell)
		# Determine intent: attack a random adjacent direction
		var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
		var intent_dir = dirs[rng.randi_range(0, 3)]
		enemies.append({"cell": cell, "hp": 2, "intent_dir": intent_dir, "intent_type": "attack"})
		# Create visual
		var sprite = ColorRect.new()
		sprite.size = Vector2(CELL - 24, CELL - 24)
		sprite.color = COLOR_ENEMY
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		var lbl = Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(CELL - 24, 20)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		enemy_sprites.append({"rect": sprite, "label": lbl})
	_build_intent_arrows()

func _build_intent_arrows() -> void:
	for ia in intent_arrows:
		if is_instance_valid(ia):
			ia.queue_free()
	intent_arrows.clear()
	for e in enemies:
		var arrow = Label.new()
		var dir = e.intent_dir
		if dir == Vector2i(0, -1):
			arrow.text = "^"
		elif dir == Vector2i(0, 1):
			arrow.text = "v"
		elif dir == Vector2i(-1, 0):
			arrow.text = "<"
		else:
			arrow.text = ">"
		var target_cell = e.cell + dir
		var pos = ORIGIN + Vector2(target_cell.x * CELL, target_cell.y * CELL)
		arrow.position = pos + Vector2(CELL * 0.3, CELL * 0.2)
		arrow.add_theme_color_override("font_color", COLOR_INTENT)
		arrow.add_theme_font_size_override("font_size", 36)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(arrow)
		intent_arrows.append(arrow)

func _build_hud() -> void:
	# Top panel
	var top = ColorRect.new()
	top.color = COLOR_PANEL
	top.size = Vector2(1280, 55)
	add_child(top)
	var top_edge = ColorRect.new()
	top_edge.color = COLOR_ACCENT
	top_edge.position = Vector2(0, 53)
	top_edge.size = Vector2(1280, 2)
	add_child(top_edge)

	turn_label = Label.new()
	turn_label.text = "TURN %d / %d" % [turn + 1, MAX_TURNS]
	turn_label.position = Vector2(20, 14)
	turn_label.add_theme_color_override("font_color", COLOR_TEXT)
	turn_label.add_theme_font_size_override("font_size", 24)
	add_child(turn_label)

	phase_label = Label.new()
	phase_label.text = "PLAYER PHASE"
	phase_label.position = Vector2(500, 14)
	phase_label.size = Vector2(280, 30)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", COLOR_ACCENT)
	phase_label.add_theme_font_size_override("font_size", 24)
	add_child(phase_label)

	# Building integrity
	var bld_label = Label.new()
	bld_label.text = "BUILDINGS"
	bld_label.position = Vector2(1050, 6)
	bld_label.add_theme_color_override("font_color", COLOR_TEXT)
	bld_label.add_theme_font_size_override("font_size", 16)
	add_child(bld_label)
	status_label = Label.new()
	status_label.position = Vector2(1050, 28)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)

	# Bottom panel with info + end turn
	var bot = ColorRect.new()
	bot.color = COLOR_PANEL
	bot.position = Vector2(0, 640)
	bot.size = Vector2(1280, 80)
	add_child(bot)
	var bot_edge = ColorRect.new()
	bot_edge.color = COLOR_ACCENT
	bot_edge.position = Vector2(0, 640)
	bot_edge.size = Vector2(1280, 2)
	add_child(bot_edge)

	info_label = Label.new()
	info_label.text = "Click a mech to select, then click a tile to move or enemy to attack."
	info_label.position = Vector2(20, 660)
	info_label.size = Vector2(900, 40)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	info_label.add_theme_font_size_override("font_size", 18)
	add_child(info_label)

	end_turn_btn = _make_button("END TURN", Vector2(1050, 655))
	end_turn_btn.pressed.connect(func(): _end_player_turn())
	add_child(end_turn_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(180, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.18, 0.22)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb.duplicate())
	b.add_theme_stylebox_override("pressed", sb.duplicate())
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 20)
	return b

func _refresh_all() -> void:
	# Update building visuals
	for i in range(buildings.size()):
		var b = buildings[i]
		var s = building_sprites[i]
		var pos = ORIGIN + Vector2(b.cell.x * CELL + 10, b.cell.y * CELL + 10)
		s.rect.position = pos
		s.rect.color = COLOR_BUILDING if b.hp > 1 else COLOR_BUILDING_DMG
		s.label.text = "BLD HP:%d" % b.hp
		s.label.position = pos + Vector2(0, CELL - 34)
	# Update mech visuals
	for i in range(mechs.size()):
		var m = mechs[i]
		var s = mech_sprites[i]
		var pos = ORIGIN + Vector2(m.cell.x * CELL + 8, m.cell.y * CELL + 8)
		s.rect.position = pos
		if m.type == "punch":
			s.rect.color = COLOR_MECH_PUNCH
		elif m.type == "artillery":
			s.rect.color = COLOR_MECH_ARTILLERY
		else:
			s.rect.color = COLOR_MECH_SHIELD
		# Dim if already acted
		if m.has_moved and m.has_acted:
			s.rect.modulate = Color(0.5, 0.5, 0.5, 1.0)
		else:
			s.rect.modulate = Color(1, 1, 1, 1)
		var type_short = "PNC" if m.type == "punch" else ("ART" if m.type == "artillery" else "SHD")
		s.label.text = type_short
		s.label.position = pos + Vector2(0, CELL - 40)
		s.hp_label.text = "HP %d/%d" % [m.hp, m.max_hp]
		s.hp_label.position = pos + Vector2(-4, -16)
	# Update enemy visuals
	for i in range(enemies.size()):
		var e = enemies[i]
		if i >= enemy_sprites.size():
			break
		var s = enemy_sprites[i]
		var pos = ORIGIN + Vector2(e.cell.x * CELL + 12, e.cell.y * CELL + 12)
		s.rect.position = pos
		s.label.text = "E HP:%d" % e.hp
		s.label.position = pos + Vector2(0, CELL - 40)
	# Selection
	if selected_mech >= 0 and selected_mech < mechs.size():
		var m = mechs[selected_mech]
		select_highlight.position = ORIGIN + Vector2(m.cell.x * CELL, m.cell.y * CELL)
		select_highlight.visible = true
	else:
		select_highlight.visible = false
	# Status
	var alive_buildings = 0
	for b in buildings:
		if b.hp > 0:
			alive_buildings += 1
	status_label.text = "%d / %d alive" % [alive_buildings, buildings.size()]
	turn_label.text = "TURN %d / %d" % [turn + 1, MAX_TURNS]

func _input(event: InputEvent) -> void:
	if phase != "player":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		var cell = _pixel_to_cell(click_pos)
		if cell == Vector2i(-1, -1):
			selected_mech = -1
			_refresh_all()
			return
		_handle_cell_click(cell)

func _pixel_to_cell(p: Vector2) -> Vector2i:
	var rel = p - ORIGIN
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var cx = int(rel.x / CELL)
	var cy = int(rel.y / CELL)
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

func _handle_cell_click(cell: Vector2i) -> void:
	# Check if clicking on a mech to select it
	for i in range(mechs.size()):
		if mechs[i].cell == cell:
			selected_mech = i
			var m = mechs[i]
			var type_name = m.type.capitalize()
			info_label.text = "%s Mech selected. Click tile to move, enemy to attack." % type_name
			_refresh_all()
			return
	# If a mech is selected, try to move or attack
	if selected_mech < 0 or selected_mech >= mechs.size():
		return
	var m = mechs[selected_mech]
	# Check if clicking on enemy to attack
	var enemy_idx = _enemy_at_cell(cell)
	if enemy_idx >= 0:
		_do_attack(selected_mech, enemy_idx)
		return
	# Otherwise try to move
	if not m.has_moved:
		var dist = absi(cell.x - m.cell.x) + absi(cell.y - m.cell.y)
		if dist <= 2 and not _is_occupied_by_mech(cell) and not _is_building(cell):
			m.cell = cell
			m.has_moved = true
			mechs[selected_mech] = m
			info_label.text = "Mech moved. Click enemy to use ability."
			_refresh_all()
		else:
			info_label.text = "Can't move there (max 2 tiles, unoccupied)."

func _do_attack(mech_idx: int, enemy_idx: int) -> void:
	var m = mechs[mech_idx]
	if m.has_acted:
		info_label.text = "This mech already used its ability this turn."
		return
	var e = enemies[enemy_idx]
	var dist = absi(m.cell.x - e.cell.x) + absi(m.cell.y - e.cell.y)
	if m.type == "punch":
		if dist > 1:
			info_label.text = "Punch: must be adjacent (1 tile)."
			return
		e.hp -= 2
		# Push enemy 1 tile away
		var push_dir = Vector2i(e.cell.x - m.cell.x, e.cell.y - m.cell.y)
		var new_cell = e.cell + push_dir
		if _is_valid_cell(new_cell) and _enemy_at_cell(new_cell) < 0:
			e.cell = new_cell
		info_label.text = "PUNCH! Enemy takes 2 dmg and pushed back."
	elif m.type == "artillery":
		if dist < 2:
			info_label.text = "Artillery: min range 2 tiles."
			return
		e.hp -= 3
		info_label.text = "ARTILLERY! Enemy takes 3 dmg."
	elif m.type == "shield":
		if dist > 1:
			info_label.text = "Shield bash: must be adjacent."
			return
		e.hp -= 1
		# Shield also nullifies enemy intent
		e.intent_type = "blocked"
		info_label.text = "SHIELD BASH! 1 dmg + intent blocked."
	enemies[enemy_idx] = e
	m.has_acted = true
	mechs[mech_idx] = m
	# Remove dead enemies
	if e.hp <= 0:
		_remove_enemy(enemy_idx)
	_refresh_all()
	_build_intent_arrows()

func _end_player_turn() -> void:
	if phase != "player":
		return
	phase = "enemy_execute"
	phase_label.text = "ENEMY PHASE"
	info_label.text = "Enemies executing their intents..."
	_execute_enemy_intents()

func _execute_enemy_intents() -> void:
	for e in enemies:
		if e.intent_type == "blocked":
			continue
		var target_cell = e.cell + e.intent_dir
		if not _is_valid_cell(target_cell):
			continue
		# Check if target is a building
		for b in buildings:
			if b.cell == target_cell and b.hp > 0:
				b.hp -= 1
				break
		# Check if target is a mech
		for m in mechs:
			if m.cell == target_cell:
				m.hp -= 1
				break
	# Check lose condition: all buildings destroyed
	var alive = 0
	for b in buildings:
		if b.hp > 0:
			alive += 1
	if alive == 0:
		phase = "game_over"
		phase_label.text = "DEFEAT"
		info_label.text = "All buildings destroyed! Mission failed."
		_refresh_all()
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self) and main != null:
			main._enter_result(false)
		return
	# Check mech deaths
	for i in range(mechs.size() - 1, -1, -1):
		if mechs[i].hp <= 0:
			mechs[i].hp = 0
	# Advance turn
	turn += 1
	if turn >= MAX_TURNS:
		phase = "game_over"
		phase_label.text = "VICTORY"
		info_label.text = "Survived all turns! City saved!"
		_refresh_all()
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self) and main != null:
			main._enter_upgrade()
		return
	# Reset mechs for next turn
	for i in range(mechs.size()):
		mechs[i].has_moved = false
		mechs[i].has_acted = false
	selected_mech = -1
	_spawn_enemies_for_turn()
	phase = "player"
	phase_label.text = "PLAYER PHASE"
	info_label.text = "New turn. Select a mech and respond to enemy intents."
	_refresh_all()

func _remove_enemy(idx: int) -> void:
	enemies.remove_at(idx)
	if idx < enemy_sprites.size():
		var s = enemy_sprites[idx]
		if is_instance_valid(s.rect):
			s.rect.queue_free()
		if is_instance_valid(s.label):
			s.label.queue_free()
		enemy_sprites.remove_at(idx)

func _get_occupied_cells() -> Array:
	var cells = []
	for m in mechs:
		cells.append(m.cell)
	for b in buildings:
		cells.append(b.cell)
	for e in enemies:
		cells.append(e.cell)
	return cells

func _is_occupied_by_mech(cell: Vector2i) -> bool:
	for m in mechs:
		if m.cell == cell:
			return true
	return false

func _is_building(cell: Vector2i) -> bool:
	for b in buildings:
		if b.cell == cell:
			return true
	return false

func _enemy_at_cell(cell: Vector2i) -> int:
	for i in range(enemies.size()):
		if enemies[i].cell == cell:
			return i
	return -1

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS
