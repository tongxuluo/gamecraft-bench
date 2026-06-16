extends Node2D

var main: Node = null
var level_index: int = 0

# Grid constants
const CELL_SIZE := 48
const GRID_OFFSET := Vector2(160, 60)
const GRID_W := 20
const GRID_H := 13

# Cell types
enum Cell { EMPTY, WALL, DESTRUCTIBLE, EXPLOSIVE, GLASS, EXIT, SPIKE, LAVA, BALL, BOULDER, SWITCH }

# Gravity direction
var gravity_dir = Vector2(0, 1)  # starts as down
var move_count = 0
var undo_stack: Array = []
var ball_pos = Vector2i(0, 0)
var grid: Array = []
var level_complete = false
var ball_dead = false

# Visual nodes
var cell_nodes: Array = []
var ball_node: Node2D = null
var hud_gravity_label: Label = null
var hud_level_label: Label = null
var hud_moves_label: Label = null
var hud_undo_label: Label = null

# Colors
const COLOR_WALL := Color(0.25, 0.28, 0.35)
const COLOR_DESTRUCTIBLE := Color(0.6, 0.45, 0.2)
const COLOR_EXPLOSIVE := Color(0.8, 0.2, 0.1)
const COLOR_GLASS := Color(0.5, 0.8, 0.9, 0.6)
const COLOR_EXIT := Color(0.2, 0.9, 0.4)
const COLOR_SPIKE := Color(0.9, 0.1, 0.2)
const COLOR_LAVA := Color(0.95, 0.4, 0.05)
const COLOR_BALL := Color(0.3, 0.6, 1.0)
const COLOR_BOULDER := Color(0.5, 0.5, 0.45)
const COLOR_SWITCH := Color(0.9, 0.8, 0.1)
const COLOR_BG := Color(0.06, 0.07, 0.10)
const COLOR_GRID_BG := Color(0.08, 0.09, 0.13)
const COLOR_ACCENT := Color(0.3, 0.7, 0.9)

# Levels data
var levels: Array = []

func _ready() -> void:
	_init_levels()
	_load_level(level_index)

func _init_levels() -> void:
	# Level 0: Simple intro - ball falls right to exit
	levels.append({
		"name": "First Steps",
		"grid": _make_level_0()
	})
	# Level 1: Destructible blocks in the way
	levels.append({
		"name": "Breaking Through",
		"grid": _make_level_1()
	})
	# Level 2: Explosive chain reaction
	levels.append({
		"name": "Chain Reaction",
		"grid": _make_level_2()
	})
	# Level 3: Glass and spikes
	levels.append({
		"name": "Fragile Path",
		"grid": _make_level_3()
	})
	# Level 4: Complex multi-step with all elements
	levels.append({
		"name": "Gravity Master",
		"grid": _make_level_4()
	})

func _make_empty_grid() -> Array:
	var g: Array = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(Cell.EMPTY)
		g.append(row)
	return g

func _add_border(g: Array) -> void:
	for x in range(GRID_W):
		g[0][x] = Cell.WALL
		g[GRID_H - 1][x] = Cell.WALL
	for y in range(GRID_H):
		g[y][0] = Cell.WALL
		g[y][GRID_W - 1] = Cell.WALL

func _make_level_0() -> Array:
	var g = _make_empty_grid()
	_add_border(g)
	# Ball on left, exit on right, small platform
	ball_pos = Vector2i(3, 6)
	g[8][3] = Cell.WALL
	g[8][4] = Cell.WALL
	g[8][5] = Cell.WALL
	# Platform in middle
	g[8][10] = Cell.WALL
	g[8][11] = Cell.WALL
	g[8][12] = Cell.WALL
	# Exit on right side
	g[6][17] = Cell.EXIT
	g[8][16] = Cell.WALL
	g[8][17] = Cell.WALL
	g[8][18] = Cell.WALL
	return g

func _make_level_1() -> Array:
	var g = _make_empty_grid()
	_add_border(g)
	ball_pos = Vector2i(2, 3)
	# Destructible wall blocking path
	for y in range(2, 11):
		g[y][8] = Cell.DESTRUCTIBLE
	# Platform under ball
	g[5][2] = Cell.WALL
	g[5][3] = Cell.WALL
	g[5][4] = Cell.WALL
	# Exit behind destructible wall
	g[6][16] = Cell.EXIT
	g[8][14] = Cell.WALL
	g[8][15] = Cell.WALL
	g[8][16] = Cell.WALL
	g[8][17] = Cell.WALL
	# Boulder that can break destructibles
	g[3][6] = Cell.BOULDER
	g[5][5] = Cell.WALL
	g[5][6] = Cell.WALL
	g[5][7] = Cell.WALL
	return g

func _make_level_2() -> Array:
	var g = _make_empty_grid()
	_add_border(g)
	ball_pos = Vector2i(2, 10)
	# Explosive crates that chain react
	g[10][6] = Cell.EXPLOSIVE
	g[10][7] = Cell.EXPLOSIVE
	g[8][7] = Cell.EXPLOSIVE
	# Walls forming a chamber
	for x in range(5, 9):
		g[7][x] = Cell.WALL
	for y in range(7, 12):
		g[y][5] = Cell.WALL
		g[y][9] = Cell.WALL
	# Destructible ceiling above explosives
	g[6][6] = Cell.DESTRUCTIBLE
	g[6][7] = Cell.DESTRUCTIBLE
	g[6][8] = Cell.DESTRUCTIBLE
	# Exit above
	g[3][7] = Cell.EXIT
	# Platform for ball
	g[11][2] = Cell.WALL
	g[11][3] = Cell.WALL
	return g

func _make_level_3() -> Array:
	var g = _make_empty_grid()
	_add_border(g)
	ball_pos = Vector2i(2, 2)
	# Glass platforms (break instantly)
	g[4][3] = Cell.GLASS
	g[4][4] = Cell.GLASS
	g[4][5] = Cell.GLASS
	g[4][6] = Cell.GLASS
	# Spikes below glass
	g[11][4] = Cell.SPIKE
	g[11][5] = Cell.SPIKE
	# Safe landing
	g[8][8] = Cell.WALL
	g[8][9] = Cell.WALL
	g[8][10] = Cell.WALL
	# More glass
	g[6][12] = Cell.GLASS
	g[6][13] = Cell.GLASS
	g[6][14] = Cell.GLASS
	# Lava hazard
	g[11][13] = Cell.LAVA
	g[11][14] = Cell.LAVA
	# Exit
	g[4][17] = Cell.EXIT
	g[6][16] = Cell.WALL
	g[6][17] = Cell.WALL
	g[6][18] = Cell.WALL
	return g

func _make_level_4() -> Array:
	var g = _make_empty_grid()
	_add_border(g)
	ball_pos = Vector2i(2, 11)
	# Complex level with all elements
	# Platforms
	for x in range(2, 6):
		g[9][x] = Cell.WALL
	for x in range(8, 13):
		g[7][x] = Cell.WALL
	for x in range(14, 18):
		g[5][x] = Cell.WALL
	# Destructibles blocking paths
	g[7][7] = Cell.DESTRUCTIBLE
	g[5][13] = Cell.DESTRUCTIBLE
	g[5][14] = Cell.DESTRUCTIBLE
	# Explosives for chain
	g[9][6] = Cell.EXPLOSIVE
	g[7][13] = Cell.EXPLOSIVE
	# Glass bridges
	g[3][15] = Cell.GLASS
	g[3][16] = Cell.GLASS
	g[3][17] = Cell.GLASS
	# Hazards
	g[11][8] = Cell.SPIKE
	g[11][9] = Cell.SPIKE
	g[11][10] = Cell.LAVA
	g[11][11] = Cell.LAVA
	# Boulder
	g[6][3] = Cell.BOULDER
	# Switch
	g[9][15] = Cell.SWITCH
	# Exit at top right
	g[2][17] = Cell.EXIT
	return g

func _load_level(idx: int) -> void:
	level_complete = false
	ball_dead = false
	move_count = 0
	undo_stack.clear()
	gravity_dir = Vector2(0, 1)
	# Clear old visuals
	for child in get_children():
		child.queue_free()
	cell_nodes.clear()
	ball_node = null
	# Deep copy grid
	var src: Array = levels[idx]["grid"]
	grid = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(src[y][x])
		grid.append(row)
	# Find ball position from level maker (stored in ball_pos during make)
	# Re-derive ball_pos for levels > 0
	_set_ball_pos_for_level(idx)
	# Build visuals next frame
	call_deferred("_build_visuals")

func _set_ball_pos_for_level(idx: int) -> void:
	match idx:
		0: ball_pos = Vector2i(3, 6)
		1: ball_pos = Vector2i(2, 3)
		2: ball_pos = Vector2i(2, 10)
		3: ball_pos = Vector2i(2, 2)
		4: ball_pos = Vector2i(2, 11)

func _build_visuals() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)
	# Grid background
	var grid_bg = ColorRect.new()
	grid_bg.color = COLOR_GRID_BG
	grid_bg.position = GRID_OFFSET - Vector2(4, 4)
	grid_bg.size = Vector2(GRID_W * CELL_SIZE + 8, GRID_H * CELL_SIZE + 8)
	add_child(grid_bg)
	# Draw cells
	cell_nodes = []
	for y in range(GRID_H):
		var row_nodes: Array = []
		for x in range(GRID_W):
			var node = _create_cell_visual(x, y, grid[y][x])
			if node != null:
				add_child(node)
			row_nodes.append(node)
		cell_nodes.append(row_nodes)
	# Draw ball
	ball_node = _create_ball_visual()
	add_child(ball_node)
	# Build HUD
	_build_hud()

func _cell_pos(x: int, y: int) -> Vector2:
	return GRID_OFFSET + Vector2(x * CELL_SIZE, y * CELL_SIZE)

func _create_cell_visual(x: int, y: int, cell_type: int) -> Node2D:
	if cell_type == Cell.EMPTY:
		return null
	var node = Node2D.new()
	node.position = _cell_pos(x, y)
	var rect = ColorRect.new()
	rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	rect.position = Vector2(1, 1)
	match cell_type:
		Cell.WALL:
			rect.color = COLOR_WALL
		Cell.DESTRUCTIBLE:
			rect.color = COLOR_DESTRUCTIBLE
		Cell.EXPLOSIVE:
			rect.color = COLOR_EXPLOSIVE
		Cell.GLASS:
			rect.color = COLOR_GLASS
		Cell.EXIT:
			rect.color = COLOR_EXIT
		Cell.SPIKE:
			rect.color = COLOR_SPIKE
		Cell.LAVA:
			rect.color = COLOR_LAVA
		Cell.BOULDER:
			rect.color = COLOR_BOULDER
		Cell.SWITCH:
			rect.color = COLOR_SWITCH
	node.add_child(rect)
	# Add label for special types
	if cell_type in [Cell.DESTRUCTIBLE, Cell.EXPLOSIVE, Cell.GLASS, Cell.EXIT, Cell.SPIKE, Cell.LAVA, Cell.SWITCH]:
		var lbl = Label.new()
		lbl.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		lbl.position = Vector2(1, 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		match cell_type:
			Cell.DESTRUCTIBLE: lbl.text = "D"
			Cell.EXPLOSIVE: lbl.text = "!"
			Cell.GLASS: lbl.text = "~"
			Cell.EXIT: lbl.text = "E"
			Cell.SPIKE: lbl.text = "^"
			Cell.LAVA: lbl.text = "~"
			Cell.SWITCH: lbl.text = "S"
		node.add_child(lbl)
	return node

func _create_ball_visual() -> Node2D:
	var node = Node2D.new()
	node.position = _cell_pos(ball_pos.x, ball_pos.y) + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	var circle = ColorRect.new()
	circle.color = COLOR_BALL
	circle.size = Vector2(CELL_SIZE - 8, CELL_SIZE - 8)
	circle.position = Vector2(-(CELL_SIZE - 8) / 2, -(CELL_SIZE - 8) / 2)
	node.add_child(circle)
	# Ball label
	var lbl = Label.new()
	lbl.text = "O"
	lbl.size = Vector2(CELL_SIZE - 8, CELL_SIZE - 8)
	lbl.position = Vector2(-(CELL_SIZE - 8) / 2, -(CELL_SIZE - 8) / 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	node.add_child(lbl)
	return node

func _build_hud() -> void:
	# Gravity direction indicator
	hud_gravity_label = Label.new()
	hud_gravity_label.position = Vector2(20, 10)
	hud_gravity_label.size = Vector2(200, 30)
	hud_gravity_label.add_theme_font_size_override("font_size", 20)
	hud_gravity_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_update_gravity_label()
	add_child(hud_gravity_label)

	hud_level_label = Label.new()
	hud_level_label.position = Vector2(500, 10)
	hud_level_label.size = Vector2(300, 30)
	hud_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_level_label.add_theme_font_size_override("font_size", 20)
	hud_level_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	hud_level_label.text = "Chamber %d: %s" % [level_index + 1, levels[level_index]["name"]]
	add_child(hud_level_label)

	hud_moves_label = Label.new()
	hud_moves_label.position = Vector2(1050, 10)
	hud_moves_label.size = Vector2(200, 30)
	hud_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_moves_label.add_theme_font_size_override("font_size", 20)
	hud_moves_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	hud_moves_label.text = "Moves: %d" % move_count
	add_child(hud_moves_label)

	hud_undo_label = Label.new()
	hud_undo_label.position = Vector2(20, 690)
	hud_undo_label.size = Vector2(400, 30)
	hud_undo_label.add_theme_font_size_override("font_size", 16)
	hud_undo_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	hud_undo_label.text = "Z=Undo  R=Restart  Arrows=Gravity"
	add_child(hud_undo_label)

func _update_gravity_label() -> void:
	if hud_gravity_label == null:
		return
	var dir_name = ""
	if gravity_dir == Vector2(0, 1): dir_name = "DOWN v"
	elif gravity_dir == Vector2(0, -1): dir_name = "UP ^"
	elif gravity_dir == Vector2(-1, 0): dir_name = "LEFT <"
	elif gravity_dir == Vector2(1, 0): dir_name = "RIGHT >"
	hud_gravity_label.text = "Gravity: %s" % dir_name

func _input(event: InputEvent) -> void:
	if level_complete:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if ball_dead:
			# Only allow undo and restart when dead
			match event.keycode:
				KEY_Z:
					_undo()
				KEY_R:
					_load_level(level_index)
			return
		var new_dir = gravity_dir
		match event.keycode:
			KEY_UP:
				new_dir = Vector2(0, -1)
			KEY_DOWN:
				new_dir = Vector2(0, 1)
			KEY_LEFT:
				new_dir = Vector2(-1, 0)
			KEY_RIGHT:
				new_dir = Vector2(1, 0)
			KEY_Z:
				_undo()
				return
			KEY_R:
				_load_level(level_index)
				return
			_:
				return
		if new_dir != gravity_dir:
			_save_state()
			gravity_dir = new_dir
			move_count += 1
			_simulate_gravity()
			_update_gravity_label()
			if hud_moves_label:
				hud_moves_label.text = "Moves: %d" % move_count

func _save_state() -> void:
	var state = {
		"grid": _deep_copy_grid(),
		"ball_pos": ball_pos,
		"gravity_dir": gravity_dir,
		"move_count": move_count
	}
	undo_stack.append(state)

func _deep_copy_grid() -> Array:
	var g: Array = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(grid[y][x])
		g.append(row)
	return g

func _undo() -> void:
	if undo_stack.is_empty():
		return
	var state: Dictionary = undo_stack.pop_back()
	grid = state["grid"]
	ball_pos = state["ball_pos"]
	gravity_dir = state["gravity_dir"]
	move_count = state["move_count"]
	ball_dead = false
	_rebuild_visuals()
	_update_gravity_label()
	if hud_moves_label:
		hud_moves_label.text = "Moves: %d" % move_count

func _rebuild_visuals() -> void:
	for child in get_children():
		child.queue_free()
	cell_nodes.clear()
	ball_node = null
	call_deferred("_build_visuals")

func _simulate_gravity() -> void:
	# Move ball and boulders in gravity direction
	var dir_i = Vector2i(int(gravity_dir.x), int(gravity_dir.y))
	var moved = true
	var iterations = 0
	while moved and iterations < 50:
		moved = false
		iterations += 1
		# Move ball
		var result = _move_object_in_dir(ball_pos, dir_i, true)
		if result != ball_pos:
			ball_pos = result
			moved = true
		# Move boulders
		var boulders = _find_boulders()
		for b_pos in boulders:
			var b_result = _move_object_in_dir(b_pos, dir_i, false)
			if b_result != b_pos:
				grid[b_pos.y][b_pos.x] = Cell.EMPTY
				grid[b_result.y][b_result.x] = Cell.BOULDER
				moved = true
	# Check for chain reactions (explosives)
	_process_explosions()
	# Update visuals
	_rebuild_visuals()

func _move_object_in_dir(pos: Vector2i, dir: Vector2i, is_ball: bool) -> Vector2i:
	var current = pos
	while true:
		var next = current + dir
		# Bounds check
		if next.x < 0 or next.x >= GRID_W or next.y < 0 or next.y >= GRID_H:
			break
		var cell: int = grid[next.y][next.x]
		# Check what's in the next cell
		match cell:
			Cell.EMPTY:
				current = next
			Cell.EXIT:
				if is_ball:
					level_complete = true
					current = next
					call_deferred("_on_level_complete")
				return current
			Cell.SPIKE, Cell.LAVA:
				if is_ball:
					ball_dead = true
					current = next
					call_deferred("_on_ball_dead")
				return current
			Cell.DESTRUCTIBLE:
				# Break it and stop
				grid[next.y][next.x] = Cell.EMPTY
				break
			Cell.GLASS:
				# Glass shatters instantly, object passes through
				grid[next.y][next.x] = Cell.EMPTY
				current = next
			Cell.EXPLOSIVE:
				# Trigger explosion
				grid[next.y][next.x] = Cell.EMPTY
				_explode_at(next)
				break
			Cell.SWITCH:
				# Activate switch (remove nearby destructibles)
				_activate_switch(next)
				current = next
				grid[next.y][next.x] = Cell.EMPTY
			_:
				# WALL, BOULDER - solid, stop
				break
	return current

func _find_boulders() -> Array:
	var result: Array = []
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid[y][x] == Cell.BOULDER:
				result.append(Vector2i(x, y))
	return result

func _explode_at(pos: Vector2i) -> void:
	# Destroy adjacent cells (3x3 area)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = pos.x + dx
			var ny = pos.y + dy
			if nx < 0 or nx >= GRID_W or ny < 0 or ny >= GRID_H:
				continue
			var cell: int = grid[ny][nx]
			if cell == Cell.DESTRUCTIBLE or cell == Cell.GLASS:
				grid[ny][nx] = Cell.EMPTY
			elif cell == Cell.EXPLOSIVE:
				grid[ny][nx] = Cell.EMPTY
				# Chain reaction
				call_deferred("_explode_at", Vector2i(nx, ny))

func _process_explosions() -> void:
	# Already handled inline during movement
	pass

func _activate_switch(pos: Vector2i) -> void:
	# Remove all destructible blocks within 3 cells
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nx = pos.x + dx
			var ny = pos.y + dy
			if nx < 0 or nx >= GRID_W or ny < 0 or ny >= GRID_H:
				continue
			if grid[ny][nx] == Cell.DESTRUCTIBLE:
				grid[ny][nx] = Cell.EMPTY

func _on_level_complete() -> void:
	main._enter_level_complete(level_index)

func _on_ball_dead() -> void:
	# Show death message, allow undo or restart
	var death_panel = ColorRect.new()
	death_panel.color = Color(0.1, 0.0, 0.0, 0.7)
	death_panel.size = Vector2(400, 150)
	death_panel.position = Vector2(440, 285)
	add_child(death_panel)
	var death_label = Label.new()
	death_label.text = "DESTROYED!\nPress Z to Undo or R to Restart"
	death_label.size = Vector2(400, 150)
	death_label.position = Vector2(440, 285)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 24)
	death_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	add_child(death_label)
