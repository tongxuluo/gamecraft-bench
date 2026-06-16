extends Node2D

var main: Node = null

const COLS = 10
const ROWS = 6
const CELL = 80
const ORIGIN = Vector2(80, 80)

const COLOR_BG = Color(0.06, 0.08, 0.05)
const COLOR_SOIL = Color(0.35, 0.25, 0.15)
const COLOR_SOIL_DARK = Color(0.28, 0.20, 0.12)
const COLOR_STONE = Color(0.22, 0.22, 0.22)
const COLOR_GRID_LINE = Color(0.15, 0.12, 0.08)
const COLOR_ACCENT = Color(0.45, 0.75, 0.35)
const COLOR_TEXT = Color(0.9, 0.95, 0.85)
const COLOR_PANEL = Color(0.12, 0.15, 0.10)
const COLOR_RED = Color(0.85, 0.3, 0.3)

const SEASON_COLORS = {
	"Spring": Color(0.5, 0.85, 0.5),
	"Summer": Color(0.9, 0.8, 0.3),
	"Autumn": Color(0.85, 0.5, 0.2),
	"Winter": Color(0.6, 0.7, 0.9),
}

const ENEMY_TYPES = {
	"Spring": {"name": "Sprout Bug", "color": Color(0.3, 0.7, 0.3), "hp": 3, "speed": 3},
	"Summer": {"name": "Sun Beetle", "color": Color(0.9, 0.6, 0.1), "hp": 5, "speed": 4},
	"Autumn": {"name": "Rot Slug", "color": Color(0.6, 0.35, 0.2), "hp": 6, "speed": 5},
	"Winter": {"name": "Frost Imp", "color": Color(0.4, 0.5, 0.9), "hp": 4, "speed": 2},
}

var grid_tiles: Array = []
var plants: Array = []
var enemies: Array = []
var player_cell = Vector2i(0, 3)

var selected_seed_idx: int = 0
var turn_count: int = 0
var floor_done: bool = false
var enemies_to_spawn: int = 0
var spawn_timer: float = 0.0
var total_enemies: int = 0

var hud_root: CanvasLayer = null
var hp_label: Label = null
var energy_label: Label = null
var floor_label: Label = null
var season_label: Label = null
var resource_label: Label = null
var seed_labels: Array = []
var feedback_label: Label = null
var feedback_timer: float = 0.0
var player_sprite: ColorRect = null

var grid_root: Node2D = null
var entity_root: Node2D = null

func _ready() -> void:
	seed(hash(main.floor_num * 1000))
	_generate_grid()
	_build_visuals()
	_build_hud()
	_spawn_initial_enemies()
	set_process(true)
	set_process_input(true)

func _generate_grid() -> void:
	grid_tiles.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			if c <= 2:
				row.append("soil")
			elif randf() < 0.55:
				row.append("soil")
			else:
				row.append("stone")
		grid_tiles.append(row)

func _build_visuals() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	grid_root = Node2D.new()
	grid_root.name = "Grid"
	add_child(grid_root)

	var season_color = SEASON_COLORS[main.get_season()]
	for r in range(ROWS):
		for c in range(COLS):
			var cell = ColorRect.new()
			if grid_tiles[r][c] == "soil":
				cell.color = COLOR_SOIL if (c + r) % 2 == 0 else COLOR_SOIL_DARK
			else:
				cell.color = COLOR_STONE
			cell.position = ORIGIN + Vector2(c * CELL, r * CELL)
			cell.size = Vector2(CELL - 2, CELL - 2)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_root.add_child(cell)

	# Season tint bar at top
	var season_bar = ColorRect.new()
	season_bar.color = season_color
	season_bar.position = Vector2(0, 0)
	season_bar.size = Vector2(1280, 4)
	add_child(season_bar)

	entity_root = Node2D.new()
	entity_root.name = "Entities"
	add_child(entity_root)

	# Player
	player_sprite = ColorRect.new()
	player_sprite.color = Color(0.2, 0.6, 0.9)
	player_sprite.size = Vector2(CELL - 20, CELL - 20)
	player_sprite.position = _cell_pos(player_cell) + Vector2(10, 10)
	entity_root.add_child(player_sprite)
	var player_label = Label.new()
	player_label.text = "G"
	player_label.position = player_sprite.position + Vector2(20, 15)
	player_label.add_theme_color_override("font_color", Color(1, 1, 1))
	player_label.add_theme_font_size_override("font_size", 24)
	entity_root.add_child(player_label)

func _build_hud() -> void:
	hud_root = CanvasLayer.new()
	add_child(hud_root)

	# Top bar
	var top = ColorRect.new()
	top.color = COLOR_PANEL
	top.size = Vector2(1280, 70)
	hud_root.add_child(top)
	var top_edge = ColorRect.new()
	top_edge.color = COLOR_ACCENT
	top_edge.position = Vector2(0, 68)
	top_edge.size = Vector2(1280, 2)
	hud_root.add_child(top_edge)

	hp_label = Label.new()
	hp_label.text = "HP %d/%d" % [main.player_hp, main.player_hp_max]
	hp_label.position = Vector2(20, 10)
	hp_label.add_theme_color_override("font_color", COLOR_RED)
	hp_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(hp_label)

	energy_label = Label.new()
	energy_label.text = "Energy %d/%d" % [main.energy, main.energy_max]
	energy_label.position = Vector2(20, 38)
	energy_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	energy_label.add_theme_font_size_override("font_size", 18)
	hud_root.add_child(energy_label)

	floor_label = Label.new()
	floor_label.text = "Floor %d / %d" % [main.floor_num, main.max_floors]
	floor_label.position = Vector2(500, 10)
	floor_label.size = Vector2(280, 30)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_color_override("font_color", COLOR_TEXT)
	floor_label.add_theme_font_size_override("font_size", 22)
	hud_root.add_child(floor_label)

	season_label = Label.new()
	season_label.text = main.get_season()
	season_label.position = Vector2(500, 40)
	season_label.size = Vector2(280, 26)
	season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	season_label.add_theme_color_override("font_color", SEASON_COLORS[main.get_season()])
	season_label.add_theme_font_size_override("font_size", 18)
	hud_root.add_child(season_label)

	resource_label = Label.new()
	resource_label.text = "Seeds: %d" % main.resources
	resource_label.position = Vector2(1050, 10)
	resource_label.size = Vector2(200, 30)
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	resource_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.5))
	resource_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(resource_label)

	# Bottom bar - seed hand
	var bot = ColorRect.new()
	bot.color = COLOR_PANEL
	bot.position = Vector2(0, 600)
	bot.size = Vector2(1280, 120)
	hud_root.add_child(bot)
	var bot_edge = ColorRect.new()
	bot_edge.color = COLOR_ACCENT
	bot_edge.position = Vector2(0, 600)
	bot_edge.size = Vector2(1280, 2)
	hud_root.add_child(bot_edge)

	# Show up to 4 seeds from deck
	seed_labels.clear()
	var hand_size = mini(4, main.seed_deck.size())
	for i in range(hand_size):
		var s = main.seed_deck[i]
		var card = ColorRect.new()
		card.color = Color(0.08, 0.10, 0.07)
		card.position = Vector2(30 + i * 160, 615)
		card.size = Vector2(140, 90)
		hud_root.add_child(card)

		var swatch = ColorRect.new()
		swatch.color = s.color
		swatch.position = card.position + Vector2(8, 8)
		swatch.size = Vector2(30, 30)
		hud_root.add_child(swatch)

		var name_l = Label.new()
		name_l.text = "%d: %s" % [i + 1, s.label]
		name_l.position = card.position + Vector2(44, 6)
		name_l.add_theme_color_override("font_color", COLOR_TEXT)
		name_l.add_theme_font_size_override("font_size", 16)
		hud_root.add_child(name_l)

		var cost_l = Label.new()
		cost_l.text = "E:%d" % s.cost
		cost_l.position = card.position + Vector2(44, 28)
		cost_l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		cost_l.add_theme_font_size_override("font_size", 14)
		hud_root.add_child(cost_l)

		var sel_marker = ColorRect.new()
		sel_marker.color = COLOR_ACCENT if i == selected_seed_idx else Color(0.2, 0.2, 0.2)
		sel_marker.position = card.position + Vector2(0, 86)
		sel_marker.size = Vector2(140, 4)
		hud_root.add_child(sel_marker)
		seed_labels.append(sel_marker)

	# Feedback
	feedback_label = Label.new()
	feedback_label.position = Vector2(700, 630)
	feedback_label.size = Vector2(500, 60)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	feedback_label.add_theme_font_size_override("font_size", 18)
	hud_root.add_child(feedback_label)

	# Instructions
	var instr = Label.new()
	instr.text = "H: Harvest | SPACE: End Turn"
	instr.position = Vector2(900, 670)
	instr.size = Vector2(350, 30)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	instr.add_theme_color_override("font_color", Color(0.5, 0.6, 0.45))
	instr.add_theme_font_size_override("font_size", 14)
	hud_root.add_child(instr)

func _spawn_initial_enemies() -> void:
	var count = 2 + main.floor_num
	if main.floor_num > main.max_floors:
		count = 6  # boss floor
	total_enemies = count
	enemies_to_spawn = count
	_spawn_one_enemy()
	enemies_to_spawn -= 1

func _spawn_one_enemy() -> void:
	var season = main.get_season()
	var edata = ENEMY_TYPES[season]
	var row = randi() % ROWS
	var ecell = Vector2i(COLS - 1, row)
	# Avoid occupied cells
	for e in enemies:
		if e.cell == ecell:
			ecell = Vector2i(COLS - 1, (row + 1) % ROWS)
	var sprite = ColorRect.new()
	sprite.color = edata.color
	sprite.size = Vector2(CELL - 24, CELL - 24)
	sprite.position = _cell_pos(ecell) + Vector2(12, 12)
	entity_root.add_child(sprite)
	var lbl = Label.new()
	lbl.text = "%d" % edata.hp
	lbl.position = sprite.position + Vector2(18, 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 18)
	entity_root.add_child(lbl)
	enemies.append({
		"cell": ecell, "hp": edata.hp, "hp_max": edata.hp,
		"speed_timer": 0, "speed": edata.speed,
		"sprite": sprite, "label": lbl, "type": season
	})

func _process(dt: float) -> void:
	if floor_done:
		return
	if feedback_timer > 0.0:
		feedback_timer -= dt
		if feedback_timer <= 0.0:
			feedback_label.text = ""
	# Spawn timer
	if enemies_to_spawn > 0:
		spawn_timer += dt
		if spawn_timer >= 1.5:
			spawn_timer = 0.0
			_spawn_one_enemy()
			enemies_to_spawn -= 1

func _input(event: InputEvent) -> void:
	if floor_done:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_move_player(Vector2i(0, -1))
			KEY_DOWN:
				_move_player(Vector2i(0, 1))
			KEY_LEFT:
				_move_player(Vector2i(-1, 0))
			KEY_RIGHT:
				_move_player(Vector2i(1, 0))
			KEY_1:
				_select_seed(0)
			KEY_2:
				_select_seed(1)
			KEY_3:
				_select_seed(2)
			KEY_4:
				_select_seed(3)
			KEY_H:
				_harvest_adjacent()
			KEY_SPACE:
				_end_turn()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_plant(event.position)

func _move_player(dir: Vector2i) -> void:
	var new_cell = player_cell + dir
	if new_cell.x < 0 or new_cell.x >= COLS or new_cell.y < 0 or new_cell.y >= ROWS:
		return
	# Check if enemy is there
	for e in enemies:
		if e.cell == new_cell:
			return
	player_cell = new_cell
	player_sprite.position = _cell_pos(player_cell) + Vector2(10, 10)
	# Reposition label
	var children = entity_root.get_children()
	if children.size() > 1:
		children[1].position = player_sprite.position + Vector2(20, 15)

func _select_seed(idx: int) -> void:
	if idx >= main.seed_deck.size() or idx >= 4:
		return
	selected_seed_idx = idx
	for i in range(seed_labels.size()):
		seed_labels[i].color = COLOR_ACCENT if i == idx else Color(0.2, 0.2, 0.2)

func _try_plant(mouse_pos: Vector2) -> void:
	var cell = _pixel_to_cell(mouse_pos)
	if cell == Vector2i(-1, -1):
		return
	if grid_tiles[cell.y][cell.x] != "soil":
		_show_feedback("Not a soil tile!")
		return
	# Check not occupied
	for p in plants:
		if p.cell == cell:
			_show_feedback("Already planted!")
			return
	if cell == player_cell:
		_show_feedback("Player is here!")
		return
	if selected_seed_idx >= main.seed_deck.size():
		_show_feedback("No seed selected!")
		return
	var s = main.seed_deck[selected_seed_idx]
	if main.energy < s.cost:
		_show_feedback("Not enough energy!")
		return
	# Plant it
	main.energy -= s.cost
	energy_label.text = "Energy %d/%d" % [main.energy, main.energy_max]
	var sprite = ColorRect.new()
	sprite.color = s.color * Color(0.5, 0.5, 0.5)  # dim = seedling
	sprite.size = Vector2(CELL - 30, CELL - 30)
	sprite.position = _cell_pos(cell) + Vector2(15, 15)
	entity_root.add_child(sprite)
	var lbl = Label.new()
	lbl.text = "."
	lbl.position = sprite.position + Vector2(16, 8)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 16)
	entity_root.add_child(lbl)
	plants.append({
		"cell": cell, "seed_data": s, "stage": 0, "hp": s.hp,
		"sprite": sprite, "label": lbl, "turns_alive": 0
	})
	_show_feedback("Planted %s!" % s.label)

func _harvest_adjacent() -> void:
	var harvested = 0
	var to_remove = []
	for p in plants:
		if p.stage >= 2:  # mature or blooming
			var dist = absi(p.cell.x - player_cell.x) + absi(p.cell.y - player_cell.y)
			if dist <= 1:
				to_remove.append(p)
				harvested += 1
	for p in to_remove:
		main.resources += 2
		if is_instance_valid(p.sprite):
			p.sprite.queue_free()
		if is_instance_valid(p.label):
			p.label.queue_free()
		plants.erase(p)
	if harvested > 0:
		resource_label.text = "Seeds: %d" % main.resources
		_show_feedback("Harvested %d plant(s)!" % harvested)
	else:
		_show_feedback("Nothing to harvest nearby")

func _end_turn() -> void:
	turn_count += 1
	# Grow plants
	for p in plants:
		p.turns_alive += 1
		if p.turns_alive >= 2 and p.stage == 0:
			p.stage = 1  # mature
			p.sprite.color = p.seed_data.color * Color(0.8, 0.8, 0.8)
			p.label.text = "M"
		elif p.turns_alive >= 4 and p.stage == 1:
			p.stage = 2  # blooming
			p.sprite.color = p.seed_data.color
			p.label.text = "B"

	# Plants attack adjacent enemies
	for p in plants:
		if p.stage >= 1 and p.seed_data.effect == "damage":
			for e in enemies:
				var dist = absi(e.cell.x - p.cell.x) + absi(e.cell.y - p.cell.y)
				if dist <= 1:
					var atk = p.seed_data.atk
					if main.get_season() == "Summer":
						atk += 1
					e.hp -= atk
					e.label.text = "%d" % max(e.hp, 0)
					break
		elif p.stage >= 1 and p.seed_data.effect == "heal":
			var dist = absi(p.cell.x - player_cell.x) + absi(p.cell.y - player_cell.y)
			if dist <= 2:
				main.player_hp = mini(main.player_hp + 1, main.player_hp_max)
				hp_label.text = "HP %d/%d" % [main.player_hp, main.player_hp_max]
		elif p.stage >= 1 and p.seed_data.effect == "energy":
			main.energy = mini(main.energy + 1, main.energy_max)
			energy_label.text = "Energy %d/%d" % [main.energy, main.energy_max]

	# Move enemies toward player
	var to_remove = []
	for e in enemies:
		if e.hp <= 0:
			to_remove.append(e)
			continue
		e.speed_timer += 1
		if e.speed_timer >= e.speed:
			e.speed_timer = 0
			var dir = Vector2i(sign(player_cell.x - e.cell.x), 0)
			if dir.x == 0:
				dir = Vector2i(0, sign(player_cell.y - e.cell.y))
			var new_cell = e.cell + dir
			# Check if blocked by plant
			var blocked = false
			for p in plants:
				if p.cell == new_cell and p.stage >= 1 and p.seed_data.effect == "block":
					blocked = true
					p.hp -= 1
					if p.hp <= 0:
						if is_instance_valid(p.sprite):
							p.sprite.queue_free()
						if is_instance_valid(p.label):
							p.label.queue_free()
						plants.erase(p)
					break
			if not blocked:
				if new_cell == player_cell:
					main.player_hp -= 1
					hp_label.text = "HP %d/%d" % [main.player_hp, main.player_hp_max]
					if main.player_hp <= 0:
						_end_floor(false)
						return
				else:
					e.cell = new_cell
					e.sprite.position = _cell_pos(e.cell) + Vector2(12, 12)
					e.label.position = e.sprite.position + Vector2(18, 12)

	for e in to_remove:
		if is_instance_valid(e.sprite):
			e.sprite.queue_free()
		if is_instance_valid(e.label):
			e.label.queue_free()
		enemies.erase(e)

	# Check win
	if enemies.size() == 0 and enemies_to_spawn <= 0:
		_end_floor(true)

func _end_floor(won: bool) -> void:
	if floor_done:
		return
	floor_done = true
	if won:
		_show_feedback("Floor cleared!")
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(self) and main != null:
			main.advance_floor()
	else:
		_show_feedback("You fell...")
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(self) and main != null:
			main._enter_result(false)

func _show_feedback(msg: String) -> void:
	feedback_label.text = msg
	feedback_timer = 2.0

func _cell_pos(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c.x * CELL, c.y * CELL)

func _pixel_to_cell(p: Vector2) -> Vector2i:
	var rel = p - ORIGIN
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var cx = int(rel.x / CELL)
	var cy = int(rel.y / CELL)
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)
