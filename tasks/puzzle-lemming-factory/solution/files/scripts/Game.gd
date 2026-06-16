extends Node2D

var main: Node = null
var level_id: int = 1
var near_victory: bool = false

# -- Constants --
const TILE_SIZE := 32
const GRID_W := 40  # 1280 / 32
const GRID_H := 18  # 576 / 32 (top 144px for HUD)
const HUD_HEIGHT := 144
const COLOR_TERRAIN := Color(0.35, 0.25, 0.15)
const COLOR_TERRAIN_DARK := Color(0.25, 0.18, 0.10)
const COLOR_BG := Color(0.08, 0.06, 0.04)
const COLOR_ENTRANCE := Color(0.2, 0.7, 0.3)
const COLOR_EXIT := Color(0.9, 0.7, 0.1)
const COLOR_HAZARD := Color(0.9, 0.2, 0.1)
const COLOR_CREATURE := Color(0.3, 0.5, 0.9)
const COLOR_DIGGER := Color(0.8, 0.4, 0.1)
const COLOR_BUILDER := Color(0.2, 0.8, 0.3)
const COLOR_BLOCKER := Color(0.8, 0.1, 0.1)
const COLOR_CLIMBER := Color(0.6, 0.2, 0.8)
const COLOR_HUD_BG := Color(0.12, 0.09, 0.06)
const COLOR_ACCENT := Color(0.85, 0.55, 0.15)

# -- Level data --
var grid: Array = []  # 2D array [x][y] -> 0=air, 1=terrain, 2=hazard
var entrance_pos: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO
var quota: int = 5
var total_creatures: int = 10
var spawn_rate: float = 1.5  # seconds between spawns
var job_supplies: Dictionary = {"digger": 5, "builder": 5, "blocker": 3, "climber": 3}

# -- State --
var creatures: Array = []
var saved_count: int = 0
var dead_count: int = 0
var spawned_count: int = 0
var spawn_timer: float = 0.0
var game_timer: float = 0.0
var selected_job: String = ""
var game_over: bool = false
var paused: bool = false

# -- UI refs --
var hud_saved_label: Label = null
var hud_timer_label: Label = null
var hud_alive_label: Label = null
var job_buttons: Dictionary = {}
var terrain_node: Node2D = null
var creatures_node: Node2D = null

func _ready() -> void:
	_load_level(level_id)
	if near_victory:
		saved_count = quota - 1
		spawned_count = total_creatures - 2
	_build_hud()
	_build_terrain_visual()

func _load_level(lvl: int) -> void:
	grid = []
	for x in range(GRID_W):
		var col: Array = []
		col.resize(GRID_H)
		for y in range(GRID_H):
			col[y] = 0
		grid.append(col)

	match lvl:
		1:
			quota = 5
			total_creatures = 10
			spawn_rate = 1.5
			job_supplies = {"digger": 5, "builder": 3, "blocker": 2, "climber": 2}
			entrance_pos = Vector2i(3, 5)
			exit_pos = Vector2i(36, 14)
			# Floor platform
			for x in range(GRID_W):
				for y in range(15, GRID_H):
					grid[x][y] = 1
			# Upper platform
			for x in range(0, 20):
				grid[x][8] = 1
				grid[x][9] = 1
			# Need to dig through floor at x=15
			for x in range(22, GRID_W):
				grid[x][12] = 1
				grid[x][13] = 1
			# Hazard pit
			for x in range(28, 32):
				grid[x][14] = 2
		2:
			quota = 7
			total_creatures = 12
			spawn_rate = 1.2
			job_supplies = {"digger": 3, "builder": 8, "blocker": 3, "climber": 2}
			entrance_pos = Vector2i(2, 4)
			exit_pos = Vector2i(37, 15)
			# Platforms with gaps
			for x in range(GRID_W):
				for y in range(16, GRID_H):
					grid[x][y] = 1
			for x in range(0, 12):
				grid[x][7] = 1
				grid[x][8] = 1
			for x in range(18, 30):
				grid[x][10] = 1
				grid[x][11] = 1
			for x in range(33, GRID_W):
				grid[x][13] = 1
				grid[x][14] = 1
			# Gap hazards
			for x in range(14, 17):
				grid[x][15] = 2
		3:
			quota = 8
			total_creatures = 15
			spawn_rate = 1.0
			job_supplies = {"digger": 4, "builder": 6, "blocker": 4, "climber": 5}
			entrance_pos = Vector2i(2, 3)
			exit_pos = Vector2i(37, 16)
			# Complex terrain
			for x in range(GRID_W):
				for y in range(17, GRID_H):
					grid[x][y] = 1
			# Multiple platforms
			for x in range(0, 10):
				grid[x][6] = 1
				grid[x][7] = 1
			# Wall
			for y in range(4, 12):
				grid[12][y] = 1
			for x in range(14, 25):
				grid[x][9] = 1
				grid[x][10] = 1
			# Another wall
			for y in range(8, 16):
				grid[26][y] = 1
			for x in range(28, GRID_W):
				grid[x][13] = 1
				grid[x][14] = 1
			# Hazards
			for x in range(10, 12):
				grid[x][16] = 2
			for x in range(30, 33):
				grid[x][16] = 2

func _build_hud() -> void:
	var hud_bg = ColorRect.new()
	hud_bg.color = COLOR_HUD_BG
	hud_bg.size = Vector2(1280, HUD_HEIGHT)
	hud_bg.z_index = 10
	add_child(hud_bg)

	var hud_border = ColorRect.new()
	hud_border.color = COLOR_ACCENT
	hud_border.position = Vector2(0, HUD_HEIGHT - 3)
	hud_border.size = Vector2(1280, 3)
	hud_border.z_index = 10
	add_child(hud_border)

	# Level name
	var lvl_label = Label.new()
	lvl_label.text = "Level %d" % level_id
	lvl_label.position = Vector2(20, 10)
	lvl_label.add_theme_color_override("font_color", COLOR_ACCENT)
	lvl_label.add_theme_font_size_override("font_size", 20)
	lvl_label.z_index = 11
	add_child(lvl_label)

	# Saved counter
	hud_saved_label = Label.new()
	hud_saved_label.position = Vector2(20, 40)
	hud_saved_label.size = Vector2(200, 30)
	hud_saved_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	hud_saved_label.add_theme_font_size_override("font_size", 18)
	hud_saved_label.z_index = 11
	add_child(hud_saved_label)

	# Alive counter
	hud_alive_label = Label.new()
	hud_alive_label.position = Vector2(20, 65)
	hud_alive_label.size = Vector2(200, 30)
	hud_alive_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	hud_alive_label.add_theme_font_size_override("font_size", 16)
	hud_alive_label.z_index = 11
	add_child(hud_alive_label)

	# Timer
	hud_timer_label = Label.new()
	hud_timer_label.position = Vector2(20, 90)
	hud_timer_label.size = Vector2(200, 30)
	hud_timer_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	hud_timer_label.add_theme_font_size_override("font_size", 16)
	hud_timer_label.z_index = 11
	add_child(hud_timer_label)

	# Job buttons
	var jobs = ["digger", "builder", "blocker", "climber"]
	var job_colors = [COLOR_DIGGER, COLOR_BUILDER, COLOR_BLOCKER, COLOR_CLIMBER]
	var job_keys = ["1", "2", "3", "4"]
	for i in range(jobs.size()):
		var btn = Button.new()
		btn.text = "%s [%s] x%d" % [jobs[i].capitalize(), job_keys[i], job_supplies.get(jobs[i], 0)]
		btn.position = Vector2(300 + i * 220, 20)
		btn.size = Vector2(200, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = job_colors[i].darkened(0.5)
		sb.border_color = job_colors[i]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		btn.add_theme_font_size_override("font_size", 16)
		btn.z_index = 11
		var job_name = jobs[i]
		btn.pressed.connect(func(): _select_job(job_name))
		add_child(btn)
		job_buttons[jobs[i]] = btn

	# Pause hint
	var pause_lbl = Label.new()
	pause_lbl.text = "[P] Pause  [ESC] Menu"
	pause_lbl.position = Vector2(300, 85)
	pause_lbl.size = Vector2(400, 30)
	pause_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.4))
	pause_lbl.add_theme_font_size_override("font_size", 14)
	pause_lbl.z_index = 11
	add_child(pause_lbl)

	# Selected job indicator
	var sel_lbl = Label.new()
	sel_lbl.name = "SelectedJobLabel"
	sel_lbl.text = "Selected: None"
	sel_lbl.position = Vector2(300, 110)
	sel_lbl.size = Vector2(400, 30)
	sel_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	sel_lbl.add_theme_font_size_override("font_size", 16)
	sel_lbl.z_index = 11
	add_child(sel_lbl)

	_update_hud()

func _build_terrain_visual() -> void:
	terrain_node = Node2D.new()
	terrain_node.position = Vector2(0, HUD_HEIGHT)
	add_child(terrain_node)
	_redraw_terrain()

	# Entrance marker
	var ent = ColorRect.new()
	ent.color = COLOR_ENTRANCE
	ent.position = Vector2(entrance_pos.x * TILE_SIZE, entrance_pos.y * TILE_SIZE - TILE_SIZE)
	ent.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	terrain_node.add_child(ent)
	var ent_lbl = Label.new()
	ent_lbl.text = "IN"
	ent_lbl.position = Vector2(entrance_pos.x * TILE_SIZE + 4, entrance_pos.y * TILE_SIZE - TILE_SIZE + 8)
	ent_lbl.add_theme_color_override("font_color", Color(0, 0, 0))
	ent_lbl.add_theme_font_size_override("font_size", 14)
	terrain_node.add_child(ent_lbl)

	# Exit marker
	var ext = ColorRect.new()
	ext.color = COLOR_EXIT
	ext.position = Vector2(exit_pos.x * TILE_SIZE, exit_pos.y * TILE_SIZE - TILE_SIZE)
	ext.size = Vector2(TILE_SIZE, TILE_SIZE * 2)
	terrain_node.add_child(ext)
	var ext_lbl = Label.new()
	ext_lbl.text = "EXIT"
	ext_lbl.position = Vector2(exit_pos.x * TILE_SIZE + 2, exit_pos.y * TILE_SIZE - TILE_SIZE + 8)
	ext_lbl.add_theme_color_override("font_color", Color(0, 0, 0))
	ext_lbl.add_theme_font_size_override("font_size", 12)
	terrain_node.add_child(ext_lbl)

	# Creatures container
	creatures_node = Node2D.new()
	terrain_node.add_child(creatures_node)

func _redraw_terrain() -> void:
	# Remove old terrain rects
	for child in terrain_node.get_children():
		if child.has_meta("terrain_tile"):
			child.queue_free()
	# Draw tiles
	for x in range(GRID_W):
		for y in range(GRID_H):
			if grid[x][y] == 0:
				continue
			var rect = ColorRect.new()
			if grid[x][y] == 1:
				rect.color = COLOR_TERRAIN if (x + y) % 2 == 0 else COLOR_TERRAIN_DARK
			else:
				rect.color = COLOR_HAZARD
			rect.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			rect.set_meta("terrain_tile", true)
			terrain_node.add_child(rect)
			terrain_node.move_child(rect, 0)

func _process(delta: float) -> void:
	if game_over or paused:
		return
	game_timer += delta

	# Spawn creatures
	if spawned_count < total_creatures:
		spawn_timer += delta
		if spawn_timer >= spawn_rate:
			spawn_timer -= spawn_rate
			_spawn_creature()

	# Update creatures
	var to_remove: Array = []
	for i in range(creatures.size()):
		var c: Dictionary = creatures[i]
		if c.dead:
			to_remove.append(i)
			continue
		_update_creature(c, delta)

	# Remove dead creatures (reverse order)
	to_remove.reverse()
	for idx in to_remove:
		var c: Dictionary = creatures[idx]
		if c.node and is_instance_valid(c.node):
			c.node.queue_free()
		creatures.remove_at(idx)

	# Check win/loss
	if not game_over:
		if saved_count >= quota:
			game_over = true
			_end_level(true)
		elif dead_count + saved_count >= total_creatures or \
			 (spawned_count >= total_creatures and creatures.size() == 0):
			game_over = true
			if saved_count >= quota:
				_end_level(true)
			else:
				_end_level(false)
		elif total_creatures - dead_count < quota:
			# Can't possibly win
			game_over = true
			_end_level(false)

	_update_hud()

func _spawn_creature() -> void:
	spawned_count += 1
	var c = {
		"x": float(entrance_pos.x * TILE_SIZE + TILE_SIZE / 2),
		"y": float(entrance_pos.y * TILE_SIZE),
		"dir": 1,  # 1=right, -1=left
		"job": "",
		"speed": 60.0,
		"falling": false,
		"dead": false,
		"dig_timer": 0.0,
		"build_count": 0,
		"climb_progress": 0.0,
		"node": null,
	}
	var rect = ColorRect.new()
	rect.color = COLOR_CREATURE
	rect.size = Vector2(12, 20)
	rect.position = Vector2(c.x - 6, c.y - 20)
	creatures_node.add_child(rect)
	c.node = rect
	creatures.append(c)

func _update_creature(c: Dictionary, delta: float) -> void:
	var gx = int(c.x / TILE_SIZE)
	var gy = int(c.y / TILE_SIZE)

	# Check if reached exit
	if gx == exit_pos.x and (gy == exit_pos.y or gy == exit_pos.y - 1):
		c.dead = true
		saved_count += 1
		return

	# Job-specific behavior
	match c.job:
		"blocker":
			# Blockers don't move
			return
		"digger":
			c.dig_timer += delta
			if c.dig_timer >= 0.5:
				c.dig_timer = 0.0
				# Dig the tile below
				var dig_y = gy + 1 if gy + 1 < GRID_H else gy
				if dig_y < GRID_H and grid[gx][dig_y] == 1:
					grid[gx][dig_y] = 0
					c.y += TILE_SIZE
					_redraw_terrain()
				else:
					c.job = ""
					if c.node:
						c.node.color = COLOR_CREATURE
			return
		"builder":
			if c.build_count < 6:
				c.dig_timer += delta
				if c.dig_timer >= 0.4:
					c.dig_timer = 0.0
					var bx = gx + c.dir
					var by = gy - 1
					if bx >= 0 and bx < GRID_W and by >= 0 and by < GRID_H and grid[bx][by] == 0:
						grid[bx][by] = 1
						c.build_count += 1
						c.x += c.dir * TILE_SIZE
						c.y -= TILE_SIZE
						_redraw_terrain()
					else:
						c.job = ""
						if c.node:
							c.node.color = COLOR_CREATURE
			else:
				c.job = ""
				if c.node:
					c.node.color = COLOR_CREATURE
			return
		"climber":
			# Check if there's a wall in front
			var wall_x = gx + c.dir
			if wall_x >= 0 and wall_x < GRID_W and gy >= 0 and gy < GRID_H:
				if grid[wall_x][gy] == 1:
					# Climb up
					c.y -= 80.0 * delta
					if c.node:
						c.node.position = Vector2(c.x - 6, c.y - 20)
					# Check if we cleared the wall
					var new_gy = int(c.y / TILE_SIZE)
					if new_gy >= 0 and new_gy < GRID_H:
						if wall_x < GRID_W and grid[wall_x][new_gy] == 0:
							c.x += c.dir * TILE_SIZE
							c.job = ""
							if c.node:
								c.node.color = COLOR_CREATURE
					elif new_gy < 0:
						c.job = ""
						if c.node:
							c.node.color = COLOR_CREATURE
					return

	# Gravity - check if there's ground below
	var below_y = gy + 1
	if below_y < GRID_H and grid[gx][below_y] == 0:
		c.falling = true
		c.y += 120.0 * delta
		# Check for hazard
		var fall_gy = int(c.y / TILE_SIZE)
		if fall_gy < GRID_H and gx < GRID_W and grid[gx][fall_gy] == 2:
			c.dead = true
			dead_count += 1
			return
		# Check if fell off map
		if c.y > GRID_H * TILE_SIZE:
			c.dead = true
			dead_count += 1
			return
	elif below_y >= GRID_H:
		c.dead = true
		dead_count += 1
		return
	else:
		c.falling = false
		# Snap to grid
		c.y = float(gy * TILE_SIZE)

		# Walk
		var next_x = c.x + c.dir * c.speed * delta
		var next_gx = int(next_x / TILE_SIZE)

		# Check wall ahead
		if next_gx >= 0 and next_gx < GRID_W and gy >= 0 and gy < GRID_H:
			if grid[next_gx][gy] == 1:
				# Hit wall - turn around (or climb if climber)
				if c.job == "climber":
					pass  # handled above
				else:
					c.dir *= -1
			else:
				# Check for blocker creatures
				var blocked = false
				for other in creatures:
					if other == c or other.dead:
						continue
					if other.job == "blocker":
						var other_gx = int(other.x / TILE_SIZE)
						var other_gy = int(other.y / TILE_SIZE)
						if other_gx == next_gx and other_gy == gy:
							blocked = true
							break
				if blocked:
					c.dir *= -1
				else:
					c.x = next_x
		else:
			# Hit edge of map - turn
			c.dir *= -1

	# Update visual
	if c.node and is_instance_valid(c.node):
		c.node.position = Vector2(c.x - 6, c.y - 20)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_select_job("digger")
			KEY_2:
				_select_job("builder")
			KEY_3:
				_select_job("blocker")
			KEY_4:
				_select_job("climber")
			KEY_P:
				paused = not paused
			KEY_ESCAPE:
				main._enter_level_select()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_over or paused:
			return
		if selected_job == "":
			return
		# Check if click is on a creature
		var click_pos: Vector2 = event.position - Vector2(0, HUD_HEIGHT)
		for c in creatures:
			if c.dead or c.job == "blocker":
				continue
			var cx = c.x
			var cy = c.y
			if abs(click_pos.x - cx) < 16 and abs(click_pos.y - cy) < 24:
				_assign_job(c, selected_job)
				break

func _select_job(job_name: String) -> void:
	if job_supplies.get(job_name, 0) <= 0:
		return
	selected_job = job_name
	var sel_lbl = get_node_or_null("SelectedJobLabel")
	if sel_lbl:
		sel_lbl.text = "Selected: %s" % job_name.capitalize()

func _assign_job(c: Dictionary, job_name: String) -> void:
	if job_supplies.get(job_name, 0) <= 0:
		return
	job_supplies[job_name] -= 1
	c.job = job_name
	c.dig_timer = 0.0
	c.build_count = 0
	# Update color
	match job_name:
		"digger":
			if c.node:
				c.node.color = COLOR_DIGGER
		"builder":
			if c.node:
				c.node.color = COLOR_BUILDER
		"blocker":
			if c.node:
				c.node.color = COLOR_BLOCKER
				c.node.size = Vector2(16, 24)
		"climber":
			if c.node:
				c.node.color = COLOR_CLIMBER
	_update_job_buttons()

func _update_job_buttons() -> void:
	var jobs = ["digger", "builder", "blocker", "climber"]
	var keys = ["1", "2", "3", "4"]
	for i in range(jobs.size()):
		var btn: Button = job_buttons.get(jobs[i])
		if btn:
			btn.text = "%s [%s] x%d" % [jobs[i].capitalize(), keys[i], job_supplies.get(jobs[i], 0)]

func _update_hud() -> void:
	if hud_saved_label:
		hud_saved_label.text = "Saved: %d / %d (quota: %d)" % [saved_count, total_creatures, quota]
	if hud_alive_label:
		hud_alive_label.text = "Alive: %d  Dead: %d  Remaining: %d" % [creatures.size(), dead_count, total_creatures - spawned_count]
	if hud_timer_label:
		var mins = int(game_timer) / 60
		var secs = int(game_timer) % 60
		hud_timer_label.text = "Time: %02d:%02d" % [mins, secs]

func _end_level(won: bool) -> void:
	# Short delay then show result
	await get_tree().create_timer(1.0).timeout
	main._enter_result(level_id, won, saved_count, quota)
