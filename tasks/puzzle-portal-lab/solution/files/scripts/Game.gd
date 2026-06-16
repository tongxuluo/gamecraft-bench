extends Node2D

var main: Node = null
var chamber_index: int = 0

# Constants
const TILE_SIZE := 40
const GRID_W := 32  # 1280 / 40
const GRID_H := 18  # 720 / 40
const GRAVITY := 980.0
const PLAYER_SPEED := 200.0
const JUMP_VELOCITY := -420.0
const CUBE_PUSH_SPEED := 100.0

# Colors
const COLOR_WALL := Color(0.25, 0.27, 0.30)
const COLOR_FLOOR := Color(0.88, 0.90, 0.92)
const COLOR_PORTAL_SURFACE := Color(0.75, 0.78, 0.82)
const COLOR_PLAYER := Color(0.2, 0.6, 0.9)
const COLOR_PORTAL_BLUE := Color(0.1, 0.4, 0.95)
const COLOR_PORTAL_ORANGE := Color(0.95, 0.5, 0.05)
const COLOR_LASER := Color(1.0, 0.1, 0.1)
const COLOR_TARGET_OFF := Color(0.5, 0.2, 0.2)
const COLOR_TARGET_ON := Color(0.1, 1.0, 0.2)
const COLOR_CUBE := Color(0.6, 0.55, 0.4)
const COLOR_BUTTON := Color(0.7, 0.3, 0.7)
const COLOR_BUTTON_ON := Color(0.3, 0.9, 0.5)
const COLOR_DOOR_LOCKED := Color(0.7, 0.2, 0.1)
const COLOR_DOOR_OPEN := Color(0.1, 0.8, 0.3)
const COLOR_EMITTER := Color(0.8, 0.1, 0.1)
const COLOR_HAZARD := Color(0.9, 0.2, 0.0)
const COLOR_BG := Color(0.92, 0.94, 0.96)

# Game state
var grid: Array = []  # 2D array: 0=empty, 1=wall, 2=portal_surface
var player_pos = Vector2.ZERO
var player_vel = Vector2.ZERO
var player_on_ground = false

var portal_blue_pos = Vector2(-1, -1)
var portal_blue_dir = Vector2.ZERO  # normal direction (outward from wall)
var portal_orange_pos = Vector2(-1, -1)
var portal_orange_dir = Vector2.ZERO

var cubes: Array = []  # [{pos, vel, on_ground}]
var laser_emitters: Array = []  # [{pos, dir}]
var targets: Array = []  # [{pos, active}]
var buttons: Array = []  # [{pos, active}]
var door_pos = Vector2.ZERO
var door_open = false
var hazards: Array = []  # [{pos, size}]

var laser_segments: Array = []  # computed each frame

# Visuals
var player_node: ColorRect = null
var portal_blue_node: Node2D = null
var portal_orange_node: Node2D = null
var door_node: ColorRect = null
var cube_nodes: Array = []
var target_nodes: Array = []
var button_nodes: Array = []
var laser_draw_node: Node2D = null
var hazard_nodes: Array = []
var hud_label: Label = null
var portal_preview_node: Node2D = null


func _ready() -> void:
	_load_chamber(chamber_index)
	_build_visuals()

func _load_chamber(idx: int) -> void:
	grid = []
	cubes = []
	laser_emitters = []
	targets = []
	buttons = []
	hazards = []
	portal_blue_pos = Vector2(-1, -1)
	portal_orange_pos = Vector2(-1, -1)
	door_open = false

	# Initialize empty grid
	for y in range(GRID_H):
		var row = []
		for x in range(GRID_W):
			row.append(0)
		grid.append(row)

	# Build walls around border
	for x in range(GRID_W):
		grid[0][x] = 1
		grid[GRID_H - 1][x] = 1
	for y in range(GRID_H):
		grid[y][0] = 1
		grid[y][GRID_W - 1] = 1

	if idx == 0:
		_setup_chamber_1()
	elif idx == 1:
		_setup_chamber_2()
	elif idx == 2:
		_setup_chamber_3()

func _setup_chamber_1() -> void:
	# Basic traversal: wall in the middle, place portals to walk through
	# Middle wall
	for y in range(3, 15):
		grid[y][16] = 1
	# Portal surfaces on the wall
	grid[10][16] = 2
	grid[11][16] = 2
	grid[10][15] = 2  # left side surface
	grid[11][15] = 2

	# Player starts left (one tile above floor)
	player_pos = Vector2(4 * TILE_SIZE, 15 * TILE_SIZE)

	# Floor platform left side
	for x in range(1, 16):
		grid[16][x] = 1

	# Floor platform right side
	for x in range(17, 31):
		grid[16][x] = 1

	# Target on right side
	targets.append({"pos": Vector2(25, 8), "active": false})

	# Laser emitter on left side pointing right
	laser_emitters.append({"pos": Vector2(3, 8), "dir": Vector2(1, 0)})

	# Door on far right
	door_pos = Vector2(30, 15)

	# Portal surfaces on left wall near emitter
	grid[8][2] = 2
	grid[9][2] = 2
	# Portal surfaces on right side near target
	grid[7][26] = 2
	grid[8][26] = 2
	grid[9][26] = 2

func _setup_chamber_2() -> void:
	# Laser redirection: laser must bounce through portals to hit target
	# Floor
	for x in range(1, 31):
		grid[16][x] = 1

	# Platforms
	for x in range(1, 10):
		grid[10][x] = 1
	for x in range(22, 31):
		grid[10][x] = 1

	# Middle elevated platform
	for x in range(12, 20):
		grid[7][x] = 1

	# Portal surfaces
	for y in range(4, 9):
		grid[y][11] = 2
	for y in range(4, 9):
		grid[y][20] = 2
	for x in range(12, 20):
		grid[8][x] = 2  # underside of platform

	# Player starts left
	player_pos = Vector2(3 * TILE_SIZE, 15 * TILE_SIZE)

	# Laser emitter on left wall pointing right
	laser_emitters.append({"pos": Vector2(2, 5), "dir": Vector2(1, 0)})

	# Target on right upper area
	targets.append({"pos": Vector2(28, 5), "active": false})

	# Second target requiring cube on button
	targets.append({"pos": Vector2(15, 3), "active": false})
	buttons.append({"pos": Vector2(15, 15), "active": false})

	# Cube
	cubes.append({"pos": Vector2(6 * TILE_SIZE, 9 * TILE_SIZE), "vel": Vector2.ZERO, "on_ground": false})

	# Door
	door_pos = Vector2(29, 15)

	# Hazard
	hazards.append({"pos": Vector2(10, 16), "size": Vector2(2, 1)})


func _setup_chamber_3() -> void:
	# Momentum launch: fall through floor portal, launch from wall portal
	# Floor with gap
	for x in range(1, 12):
		grid[16][x] = 1
	for x in range(20, 31):
		grid[16][x] = 1

	# High platform on left
	for x in range(1, 6):
		grid[6][x] = 1

	# Portal surfaces on floor edge (for floor portal)
	grid[16][12] = 2
	grid[16][13] = 2
	grid[16][14] = 2

	# Portal surfaces on right wall (for wall portal exit)
	for y in range(10, 16):
		grid[y][19] = 2

	# Portal surfaces on left wall
	for y in range(8, 14):
		grid[y][6] = 2

	# Player starts on high platform
	player_pos = Vector2(3 * TILE_SIZE, 5 * TILE_SIZE)

	# Laser emitter pointing down from ceiling
	laser_emitters.append({"pos": Vector2(25, 2), "dir": Vector2(0, 1)})

	# Target on ceiling right side
	targets.append({"pos": Vector2(28, 3), "active": false})

	# Portal surfaces on ceiling
	for x in range(23, 28):
		grid[1][x] = 2

	# Cube on left floor
	cubes.append({"pos": Vector2(8 * TILE_SIZE, 15 * TILE_SIZE), "vel": Vector2.ZERO, "on_ground": false})

	# Button on right side (cube must land on it via momentum)
	buttons.append({"pos": Vector2(24, 15), "active": false})

	# Door on far right
	door_pos = Vector2(29, 15)

	# Hazard in the gap
	hazards.append({"pos": Vector2(14, 17), "size": Vector2(4, 1)})

func _build_visuals() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)

	# Draw grid tiles
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid[y][x] == 1:
				var tile = ColorRect.new()
				tile.color = COLOR_WALL
				tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				tile.size = Vector2(TILE_SIZE, TILE_SIZE)
				add_child(tile)
				# Wall detail lines
				var detail = ColorRect.new()
				detail.color = Color(0.3, 0.32, 0.35)
				detail.position = Vector2(x * TILE_SIZE, y * TILE_SIZE + TILE_SIZE - 2)
				detail.size = Vector2(TILE_SIZE, 2)
				add_child(detail)
			elif grid[y][x] == 2:
				var tile = ColorRect.new()
				tile.color = COLOR_PORTAL_SURFACE
				tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				tile.size = Vector2(TILE_SIZE, TILE_SIZE)
				add_child(tile)
				# Highlight border for portal surface
				var highlight = ColorRect.new()
				highlight.color = Color(0.6, 0.8, 1.0, 0.4)
				highlight.position = Vector2(x * TILE_SIZE + 2, y * TILE_SIZE + 2)
				highlight.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
				add_child(highlight)


	# Laser emitters
	for em in laser_emitters:
		var emitter = ColorRect.new()
		emitter.color = COLOR_EMITTER
		emitter.position = Vector2(em["pos"].x * TILE_SIZE + 5, em["pos"].y * TILE_SIZE + 5)
		emitter.size = Vector2(TILE_SIZE - 10, TILE_SIZE - 10)
		add_child(emitter)
		# Emitter detail
		var detail = ColorRect.new()
		detail.color = Color(1.0, 0.3, 0.3)
		detail.position = Vector2(em["pos"].x * TILE_SIZE + 12, em["pos"].y * TILE_SIZE + 12)
		detail.size = Vector2(TILE_SIZE - 24, TILE_SIZE - 24)
		add_child(detail)

	# Targets
	for i in range(targets.size()):
		var t = ColorRect.new()
		t.color = COLOR_TARGET_OFF
		t.position = Vector2(targets[i]["pos"].x * TILE_SIZE + 8, targets[i]["pos"].y * TILE_SIZE + 8)
		t.size = Vector2(TILE_SIZE - 16, TILE_SIZE - 16)
		add_child(t)
		target_nodes.append(t)
		# Target ring
		var ring = ColorRect.new()
		ring.color = Color(0.6, 0.3, 0.3)
		ring.position = Vector2(targets[i]["pos"].x * TILE_SIZE + 4, targets[i]["pos"].y * TILE_SIZE + 4)
		ring.size = Vector2(TILE_SIZE - 8, TILE_SIZE - 8)
		ring.z_index = -1
		add_child(ring)

	# Buttons
	for i in range(buttons.size()):
		var b = ColorRect.new()
		b.color = COLOR_BUTTON
		b.position = Vector2(buttons[i]["pos"].x * TILE_SIZE + 4, buttons[i]["pos"].y * TILE_SIZE + TILE_SIZE - 12)
		b.size = Vector2(TILE_SIZE - 8, 12)
		add_child(b)
		button_nodes.append(b)

	# Cubes
	for i in range(cubes.size()):
		var c = ColorRect.new()
		c.color = COLOR_CUBE
		c.position = cubes[i]["pos"]
		c.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
		add_child(c)
		cube_nodes.append(c)
		# Cube detail
		var detail = ColorRect.new()
		detail.color = Color(0.65, 0.6, 0.45)
		detail.position = Vector2(6, 6)
		detail.size = Vector2(TILE_SIZE - 16, TILE_SIZE - 16)
		c.add_child(detail)

	# Door
	door_node = ColorRect.new()
	door_node.color = COLOR_DOOR_LOCKED
	door_node.position = Vector2(door_pos.x * TILE_SIZE + 4, door_pos.y * TILE_SIZE)
	door_node.size = Vector2(TILE_SIZE - 8, TILE_SIZE)
	add_child(door_node)
	# Door frame
	var frame = ColorRect.new()
	frame.color = Color(0.4, 0.4, 0.4)
	frame.position = Vector2(door_pos.x * TILE_SIZE, door_pos.y * TILE_SIZE)
	frame.size = Vector2(TILE_SIZE, TILE_SIZE)
	frame.z_index = -1
	add_child(frame)

	# Hazards
	for h in hazards:
		var hz = ColorRect.new()
		hz.color = COLOR_HAZARD
		hz.position = Vector2(h["pos"].x * TILE_SIZE, h["pos"].y * TILE_SIZE)
		hz.size = Vector2(h["size"].x * TILE_SIZE, h["size"].y * TILE_SIZE)
		add_child(hz)
		hazard_nodes.append(hz)

	# Player
	player_node = ColorRect.new()
	player_node.color = COLOR_PLAYER
	player_node.position = player_pos
	player_node.size = Vector2(TILE_SIZE - 8, TILE_SIZE - 4)
	player_node.z_index = 5
	add_child(player_node)
	# Player visor
	var visor = ColorRect.new()
	visor.color = Color(0.8, 0.9, 1.0)
	visor.position = Vector2(8, 4)
	visor.size = Vector2(16, 8)
	player_node.add_child(visor)

	# Laser draw layer
	laser_draw_node = Node2D.new()
	laser_draw_node.z_index = 3
	add_child(laser_draw_node)

	# Portal preview
	portal_preview_node = Node2D.new()
	portal_preview_node.z_index = 8
	add_child(portal_preview_node)

	# HUD
	hud_label = Label.new()
	hud_label.position = Vector2(10, 2)
	hud_label.size = Vector2(400, 30)
	hud_label.add_theme_color_override("font_color", COLOR_WALL)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.z_index = 10
	hud_label.text = "Chamber %02d | LMB: Blue Portal | RMB: Orange Portal" % (chamber_index + 1)
	add_child(hud_label)


func _process(delta: float) -> void:
	_handle_player_movement(delta)
	_handle_cubes(delta)
	_update_buttons()
	_compute_lasers()
	_check_targets()
	_check_door()
	_update_visuals()
	_check_hazards()
	_check_portal_traversal()

func _handle_player_movement(delta: float) -> void:
	var move_dir = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_LEFT):
		move_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_RIGHT):
		move_dir += 1.0

	player_vel.x = move_dir * PLAYER_SPEED

	# Gravity
	if not player_on_ground:
		player_vel.y += GRAVITY * delta
	else:
		if Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE):
			player_vel.y = JUMP_VELOCITY
			player_on_ground = false

	# Move X
	var new_x = player_pos.x + player_vel.x * delta
	if not _collides_at(Vector2(new_x, player_pos.y), Vector2(TILE_SIZE - 8, TILE_SIZE - 4)):
		player_pos.x = new_x
	else:
		player_vel.x = 0.0
		# Try pushing cube
		_try_push_cube(player_pos, Vector2(sign(move_dir), 0), delta)

	# Move Y
	var new_y = player_pos.y + player_vel.y * delta
	if not _collides_at(Vector2(player_pos.x, new_y), Vector2(TILE_SIZE - 8, TILE_SIZE - 4)):
		player_pos.y = new_y
		player_on_ground = false
	else:
		if player_vel.y > 0:
			player_on_ground = true
			# Snap to grid
			player_pos.y = floor(new_y / TILE_SIZE) * TILE_SIZE
		player_vel.y = 0.0

func _collides_at(pos: Vector2, size: Vector2) -> bool:
	# Check grid collision
	var left = int(pos.x / TILE_SIZE)
	var right = int((pos.x + size.x - 1) / TILE_SIZE)
	var top = int(pos.y / TILE_SIZE)
	var bottom = int((pos.y + size.y - 1) / TILE_SIZE)

	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			if y < 0 or y >= GRID_H or x < 0 or x >= GRID_W:
				return true
			if grid[y][x] == 1:
				return true
	return false

func _try_push_cube(from_pos: Vector2, dir: Vector2, delta: float) -> void:
	for i in range(cubes.size()):
		var cube_rect = Rect2(cubes[i]["pos"], Vector2(TILE_SIZE - 4, TILE_SIZE - 4))
		var player_rect = Rect2(from_pos + dir * 2, Vector2(TILE_SIZE - 8, TILE_SIZE - 4))
		if player_rect.intersects(cube_rect):
			var new_cube_x = cubes[i]["pos"].x + dir.x * CUBE_PUSH_SPEED * delta
			if not _collides_at(Vector2(new_cube_x, cubes[i]["pos"].y), Vector2(TILE_SIZE - 4, TILE_SIZE - 4)):
				cubes[i]["pos"].x = new_cube_x

func _handle_cubes(delta: float) -> void:
	for i in range(cubes.size()):
		# Gravity on cubes
		cubes[i]["vel"].y += GRAVITY * delta
		var new_y = cubes[i]["pos"].y + cubes[i]["vel"].y * delta
		if not _collides_at(Vector2(cubes[i]["pos"].x, new_y), Vector2(TILE_SIZE - 4, TILE_SIZE - 4)):
			cubes[i]["pos"].y = new_y
			cubes[i]["on_ground"] = false
		else:
			if cubes[i]["vel"].y > 0:
				cubes[i]["on_ground"] = true
				cubes[i]["pos"].y = floor(new_y / TILE_SIZE) * TILE_SIZE
			cubes[i]["vel"].y = 0.0

		# Horizontal momentum decay
		if cubes[i]["on_ground"]:
			cubes[i]["vel"].x *= 0.9
		var new_x = cubes[i]["pos"].x + cubes[i]["vel"].x * delta
		if not _collides_at(Vector2(new_x, cubes[i]["pos"].y), Vector2(TILE_SIZE - 4, TILE_SIZE - 4)):
			cubes[i]["pos"].x = new_x
		else:
			cubes[i]["vel"].x = 0.0

		# Check cube portal traversal
		_check_cube_portal(i)


func _check_cube_portal(cube_idx: int) -> void:
	if portal_blue_pos == Vector2(-1, -1) or portal_orange_pos == Vector2(-1, -1):
		return
	var cube_center = cubes[cube_idx]["pos"] + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var blue_center = portal_blue_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var orange_center = portal_orange_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

	if cube_center.distance_to(blue_center) < TILE_SIZE * 0.7:
		_teleport_cube(cube_idx, portal_orange_pos, portal_orange_dir, portal_blue_dir)
	elif cube_center.distance_to(orange_center) < TILE_SIZE * 0.7:
		_teleport_cube(cube_idx, portal_blue_pos, portal_blue_dir, portal_orange_dir)

func _teleport_cube(cube_idx: int, exit_pos: Vector2, exit_dir: Vector2, entry_dir: Vector2) -> void:
	var exit_world = exit_pos * TILE_SIZE + exit_dir * TILE_SIZE
	cubes[cube_idx]["pos"] = exit_world
	# Conserve momentum through portal
	var speed = cubes[cube_idx]["vel"].length()
	if speed < 50:
		speed = 200.0
	cubes[cube_idx]["vel"] = exit_dir * speed

func _check_portal_traversal() -> void:
	if portal_blue_pos == Vector2(-1, -1) or portal_orange_pos == Vector2(-1, -1):
		return
	var player_center = player_pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var blue_center = portal_blue_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var orange_center = portal_orange_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

	if player_center.distance_to(blue_center) < TILE_SIZE * 0.6:
		_teleport_player(portal_orange_pos, portal_orange_dir, portal_blue_dir)
	elif player_center.distance_to(orange_center) < TILE_SIZE * 0.6:
		_teleport_player(portal_blue_pos, portal_blue_dir, portal_orange_dir)

func _teleport_player(exit_pos: Vector2, exit_dir: Vector2, entry_dir: Vector2) -> void:
	var exit_world = exit_pos * TILE_SIZE + exit_dir * TILE_SIZE
	player_pos = exit_world
	# Conserve momentum: transform velocity based on entry/exit directions
	var speed = player_vel.length()
	if speed < 50:
		speed = 200.0
	player_vel = exit_dir * speed
	player_on_ground = false

func _update_buttons() -> void:
	for i in range(buttons.size()):
		var btn_rect = Rect2(
			Vector2(buttons[i]["pos"].x * TILE_SIZE, buttons[i]["pos"].y * TILE_SIZE + TILE_SIZE - 12),
			Vector2(TILE_SIZE, 12)
		)
		var pressed = false
		# Check cubes on button
		for cube in cubes:
			var cube_rect = Rect2(cube["pos"], Vector2(TILE_SIZE - 4, TILE_SIZE - 4))
			if cube_rect.intersects(btn_rect):
				pressed = true
				break
		# Check player on button
		var player_rect = Rect2(player_pos, Vector2(TILE_SIZE - 8, TILE_SIZE - 4))
		if player_rect.intersects(btn_rect):
			pressed = true
		buttons[i]["active"] = pressed

func _compute_lasers() -> void:
	laser_segments = []
	# Reset laser-activated targets each frame
	for i in range(targets.size()):
		targets[i]["active"] = false
	for em in laser_emitters:
		var start = Vector2(em["pos"].x * TILE_SIZE + TILE_SIZE / 2, em["pos"].y * TILE_SIZE + TILE_SIZE / 2)
		var dir: Vector2 = em["dir"]
		_trace_laser(start, dir, 0)

func _trace_laser(start: Vector2, dir: Vector2, depth: int) -> void:
	if depth > 5:
		return
	var pos = start
	var max_dist = 2000.0
	var step = 2.0
	var traveled = 0.0

	while traveled < max_dist:
		pos += dir * step
		traveled += step

		# Check if hit target
		for i in range(targets.size()):
			var target_center = targets[i]["pos"] * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			if pos.distance_to(target_center) < TILE_SIZE * 0.4:
				targets[i]["active"] = true
				laser_segments.append({"start": start, "end": pos})
				return

		# Check if hit portal
		if portal_blue_pos != Vector2(-1, -1) and portal_orange_pos != Vector2(-1, -1):
			var blue_center = portal_blue_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			if pos.distance_to(blue_center) < TILE_SIZE * 0.5:
				laser_segments.append({"start": start, "end": pos})
				var exit_center = portal_orange_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
				_trace_laser(exit_center + portal_orange_dir * TILE_SIZE * 0.6, portal_orange_dir, depth + 1)
				return
			var orange_center = portal_orange_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			if pos.distance_to(orange_center) < TILE_SIZE * 0.5:
				laser_segments.append({"start": start, "end": pos})
				var exit_center = portal_blue_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
				_trace_laser(exit_center + portal_blue_dir * TILE_SIZE * 0.6, portal_blue_dir, depth + 1)
				return

		# Check wall collision
		var gx = int(pos.x / TILE_SIZE)
		var gy = int(pos.y / TILE_SIZE)
		if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
			laser_segments.append({"start": start, "end": pos})
			return
		if grid[gy][gx] == 1:
			laser_segments.append({"start": start, "end": pos})
			return

	laser_segments.append({"start": start, "end": pos})


func _check_targets() -> void:
	# Reset targets that aren't hit by lasers (they get set in _compute_lasers)
	# Buttons also count as target activators
	for i in range(targets.size()):
		# If a button is associated (same index), button can activate target
		if i < buttons.size() and buttons[i]["active"]:
			targets[i]["active"] = true

func _check_door() -> void:
	var all_active = true
	for t in targets:
		if not t["active"]:
			all_active = false
			break
	door_open = all_active

	# Check if player reached open door
	if door_open:
		var player_center = player_pos + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		var door_center = door_pos * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		if player_center.distance_to(door_center) < TILE_SIZE:
			main._enter_completion(chamber_index)

func _check_hazards() -> void:
	var player_rect = Rect2(player_pos, Vector2(TILE_SIZE - 8, TILE_SIZE - 4))
	for h in hazards:
		var h_rect = Rect2(
			Vector2(h["pos"].x * TILE_SIZE, h["pos"].y * TILE_SIZE),
			Vector2(h["size"].x * TILE_SIZE, h["size"].y * TILE_SIZE)
		)
		if player_rect.intersects(h_rect):
			# Reset player to start
			_load_chamber(chamber_index)
			_rebuild_dynamic_visuals()
			return

func _rebuild_dynamic_visuals() -> void:
	# Remove old cube nodes
	for cn in cube_nodes:
		if is_instance_valid(cn):
			cn.queue_free()
	cube_nodes = []
	# Recreate cubes
	for i in range(cubes.size()):
		var c = ColorRect.new()
		c.color = COLOR_CUBE
		c.position = cubes[i]["pos"]
		c.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
		add_child(c)
		cube_nodes.append(c)
		var detail = ColorRect.new()
		detail.color = Color(0.65, 0.6, 0.45)
		detail.position = Vector2(6, 6)
		detail.size = Vector2(TILE_SIZE - 16, TILE_SIZE - 16)
		c.add_child(detail)

func _update_visuals() -> void:
	# Player
	player_node.position = player_pos

	# Cubes
	for i in range(cubes.size()):
		if i < cube_nodes.size() and is_instance_valid(cube_nodes[i]):
			cube_nodes[i].position = cubes[i]["pos"]

	# Targets
	for i in range(targets.size()):
		if i < target_nodes.size() and is_instance_valid(target_nodes[i]):
			target_nodes[i].color = COLOR_TARGET_ON if targets[i]["active"] else COLOR_TARGET_OFF

	# Buttons
	for i in range(buttons.size()):
		if i < button_nodes.size() and is_instance_valid(button_nodes[i]):
			button_nodes[i].color = COLOR_BUTTON_ON if buttons[i]["active"] else COLOR_BUTTON

	# Door
	if is_instance_valid(door_node):
		door_node.color = COLOR_DOOR_OPEN if door_open else COLOR_DOOR_LOCKED

	# Lasers - redraw
	for child in laser_draw_node.get_children():
		child.queue_free()
	for seg in laser_segments:
		var line = Line2D.new()
		line.add_point(seg["start"])
		line.add_point(seg["end"])
		line.width = 3.0
		line.default_color = COLOR_LASER
		laser_draw_node.add_child(line)
		# Glow line
		var glow = Line2D.new()
		glow.add_point(seg["start"])
		glow.add_point(seg["end"])
		glow.width = 8.0
		glow.default_color = Color(1.0, 0.2, 0.2, 0.3)
		laser_draw_node.add_child(glow)

	# Portal visuals
	_update_portal_visuals()

func _update_portal_visuals() -> void:
	if is_instance_valid(portal_blue_node):
		portal_blue_node.queue_free()
	if is_instance_valid(portal_orange_node):
		portal_orange_node.queue_free()

	if portal_blue_pos != Vector2(-1, -1):
		portal_blue_node = _create_portal_visual(portal_blue_pos, COLOR_PORTAL_BLUE)
		add_child(portal_blue_node)
	if portal_orange_pos != Vector2(-1, -1):
		portal_orange_node = _create_portal_visual(portal_orange_pos, COLOR_PORTAL_ORANGE)
		add_child(portal_orange_node)

func _create_portal_visual(grid_pos: Vector2, color: Color) -> Node2D:
	var container = Node2D.new()
	container.position = grid_pos * TILE_SIZE
	container.z_index = 4
	# Outer glow
	var outer = ColorRect.new()
	outer.color = Color(color.r, color.g, color.b, 0.4)
	outer.position = Vector2(-4, -4)
	outer.size = Vector2(TILE_SIZE + 8, TILE_SIZE + 8)
	container.add_child(outer)
	# Main portal
	var main_rect = ColorRect.new()
	main_rect.color = color
	main_rect.position = Vector2(2, 2)
	main_rect.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
	container.add_child(main_rect)
	# Inner dark (event horizon)
	var inner = ColorRect.new()
	inner.color = Color(0.02, 0.02, 0.05)
	inner.position = Vector2(8, 8)
	inner.size = Vector2(TILE_SIZE - 16, TILE_SIZE - 16)
	container.add_child(inner)
	# Energy ring detail
	var ring = ColorRect.new()
	ring.color = Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.7)
	ring.position = Vector2(6, 6)
	ring.size = Vector2(TILE_SIZE - 12, 3)
	container.add_child(ring)
	return container


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos: Vector2 = event.position
		var gx = int(mouse_pos.x / TILE_SIZE)
		var gy = int(mouse_pos.y / TILE_SIZE)

		if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
			return

		# Only place on portal surfaces
		if grid[gy][gx] != 2:
			return

		# Determine portal direction (normal pointing away from adjacent wall)
		var portal_dir = _get_surface_normal(gx, gy)

		if event.button_index == MOUSE_BUTTON_LEFT:
			portal_blue_pos = Vector2(gx, gy)
			portal_blue_dir = portal_dir
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			portal_orange_pos = Vector2(gx, gy)
			portal_orange_dir = portal_dir

	# Portal preview on mouse move
	if event is InputEventMouseMotion:
		_update_preview(event.position)

func _get_surface_normal(gx: int, gy: int) -> Vector2:
	# Check adjacent cells to determine which direction the portal faces
	# Portal faces away from the nearest wall
	if gx > 0 and grid[gy][gx - 1] == 1:
		return Vector2(1, 0)  # Wall to left, portal faces right
	if gx < GRID_W - 1 and grid[gy][gx + 1] == 1:
		return Vector2(-1, 0)  # Wall to right, portal faces left
	if gy > 0 and grid[gy - 1][gx] == 1:
		return Vector2(0, 1)  # Wall above, portal faces down
	if gy < GRID_H - 1 and grid[gy + 1][gx] == 1:
		return Vector2(0, -1)  # Wall below, portal faces up
	return Vector2(0, -1)  # Default: faces up

func _update_preview(mouse_pos: Vector2) -> void:
	# Clear old preview
	for child in portal_preview_node.get_children():
		child.queue_free()

	var gx = int(mouse_pos.x / TILE_SIZE)
	var gy = int(mouse_pos.y / TILE_SIZE)

	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return
	if grid[gy][gx] != 2:
		return

	# Show preview rectangle
	var preview = ColorRect.new()
	preview.color = Color(0.5, 0.8, 1.0, 0.3)
	preview.position = Vector2(gx * TILE_SIZE, gy * TILE_SIZE)
	preview.size = Vector2(TILE_SIZE, TILE_SIZE)
	portal_preview_node.add_child(preview)

	# Show direction arrow
	var dir = _get_surface_normal(gx, gy)
	var arrow = ColorRect.new()
	arrow.color = Color(1, 1, 1, 0.6)
	var center = Vector2(gx * TILE_SIZE + TILE_SIZE / 2, gy * TILE_SIZE + TILE_SIZE / 2)
	arrow.position = center + dir * 10 - Vector2(4, 4)
	arrow.size = Vector2(8, 8)
	portal_preview_node.add_child(arrow)