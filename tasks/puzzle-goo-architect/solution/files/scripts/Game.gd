extends Node2D

var main: Node = null
var level_index: int = 0
var near_victory: bool = false

# Goo types
enum GooType { STANDARD, RIGID, BALLOON }

const GOO_COLORS := {
	GooType.STANDARD: Color(0.30, 0.85, 0.25),
	GooType.RIGID: Color(0.55, 0.58, 0.62),
	GooType.BALLOON: Color(0.90, 0.45, 0.70),
}
const GOO_NAMES := {
	GooType.STANDARD: "Standard",
	GooType.RIGID: "Rigid",
	GooType.BALLOON: "Balloon",
}

# Physics constants
const GRAVITY := 400.0
const SPRING_K := 180.0
const SPRING_DAMPING := 8.0
const RIGID_K := 500.0
const BALLOON_LIFT := -300.0
const MAX_BOND_LENGTH := 120.0
const SNAP_DISTANCE := 80.0
const BOND_BREAK_STRETCH := 2.2
const BLOB_RADIUS := 18.0

# Level data
var level_data: Dictionary = {}
var blobs: Array = []  # [{pos, vel, type, node, anchored}]
var bonds: Array = []  # [{a_idx, b_idx, rest_len, line_node}]
var supply: Dictionary = {}  # GooType -> count
var goal_rect: Rect2 = Rect2()
var goal_node: ColorRect = null
var collected: int = 0
var collect_quota: int = 1
var wind_force: Vector2 = Vector2.ZERO

# Drag state
var dragging: bool = false
var drag_type: int = -1
var drag_node: ColorRect = null
var drag_pos: Vector2 = Vector2.ZERO

# UI
var supply_labels: Dictionary = {}
var collected_label: Label = null
var level_label: Label = null

# Terrain
var terrain_rects: Array = []
var hazard_rects: Array = []

func _ready() -> void:
	_load_level()
	_build_scene()
	if near_victory:
		_setup_near_victory()

func _load_level() -> void:
	var levels = [
		{
			"name": "Tower Up",
			"terrain": [Rect2(200, 600, 880, 120)],
			"hazards": [],
			"goal": Rect2(600, 80, 80, 60),
			"anchor_positions": [Vector2(580, 580), Vector2(640, 580), Vector2(700, 580)],
			"supply": {GooType.STANDARD: 12, GooType.RIGID: 5, GooType.BALLOON: 0},
			"quota": 1,
			"wind": Vector2.ZERO,
		},
		{
			"name": "Bridge Gap",
			"terrain": [Rect2(50, 500, 350, 220), Rect2(880, 500, 350, 220)],
			"hazards": [Rect2(400, 680, 480, 40)],
			"goal": Rect2(950, 430, 80, 60),
			"anchor_positions": [Vector2(320, 480), Vector2(370, 480), Vector2(270, 480)],
			"supply": {GooType.STANDARD: 15, GooType.RIGID: 8, GooType.BALLOON: 3},
			"quota": 1,
			"wind": Vector2.ZERO,
		},
		{
			"name": "Wind Challenge",
			"terrain": [Rect2(100, 550, 400, 170), Rect2(800, 300, 300, 420)],
			"hazards": [],
			"goal": Rect2(900, 230, 80, 60),
			"anchor_positions": [Vector2(300, 530), Vector2(350, 530), Vector2(400, 530)],
			"supply": {GooType.STANDARD: 10, GooType.RIGID: 6, GooType.BALLOON: 5},
			"quota": 1,
			"wind": Vector2(60.0, 0.0),
		},
	]
	level_data = levels[level_index]
	supply = level_data["supply"].duplicate()
	collect_quota = level_data["quota"]
	wind_force = level_data["wind"]

func _build_scene() -> void:
	# Sky background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.25, 0.35)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Terrain
	for rect in level_data["terrain"]:
		var t = ColorRect.new()
		t.color = Color(0.25, 0.40, 0.20)
		t.position = rect.position
		t.size = rect.size
		add_child(t)
		terrain_rects.append(rect)
		# Terrain top edge highlight
		var edge = ColorRect.new()
		edge.color = Color(0.35, 0.55, 0.28)
		edge.position = rect.position
		edge.size = Vector2(rect.size.x, 4)
		add_child(edge)

	# Hazards (spikes)
	for rect in level_data["hazards"]:
		var h = ColorRect.new()
		h.color = Color(0.85, 0.20, 0.15)
		h.position = rect.position
		h.size = rect.size
		add_child(h)
		hazard_rects.append(rect)

	# Goal pipe
	goal_rect = level_data["goal"]
	goal_node = ColorRect.new()
	goal_node.color = Color(0.90, 0.75, 0.10)
	goal_node.position = goal_rect.position
	goal_node.size = goal_rect.size
	add_child(goal_node)
	# Pipe label
	var pipe_lbl = Label.new()
	pipe_lbl.text = "GOAL"
	pipe_lbl.position = goal_rect.position + Vector2(10, 15)
	pipe_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.0))
	pipe_lbl.add_theme_font_size_override("font_size", 18)
	add_child(pipe_lbl)

	# Wind indicator
	if wind_force.length() > 0:
		var wind_lbl = Label.new()
		wind_lbl.text = ">>> WIND >>>"
		wind_lbl.position = Vector2(500, 20)
		wind_lbl.size = Vector2(280, 30)
		wind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wind_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		wind_lbl.add_theme_font_size_override("font_size", 20)
		add_child(wind_lbl)

	# Initial anchor blobs
	for pos in level_data["anchor_positions"]:
		_add_blob(pos, GooType.STANDARD, true)

	# Auto-bond initial anchors
	for i in range(blobs.size()):
		for j in range(i + 1, blobs.size()):
			var dist: float = blobs[i]["pos"].distance_to(blobs[j]["pos"])
			if dist < SNAP_DISTANCE:
				_add_bond(i, j)

	# HUD
	_build_hud()

func _build_hud() -> void:
	# Supply panel background
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.0, 0.0, 0.0, 0.6)
	hud_bg.position = Vector2(10, 10)
	hud_bg.size = Vector2(220, 130)
	add_child(hud_bg)

	var y_off = 15
	for gtype in [GooType.STANDARD, GooType.RIGID, GooType.BALLOON]:
		if supply.has(gtype) and supply[gtype] > 0:
			var swatch = ColorRect.new()
			swatch.color = GOO_COLORS[gtype]
			swatch.position = Vector2(20, y_off)
			swatch.size = Vector2(24, 24)
			add_child(swatch)

			var lbl = Label.new()
			lbl.text = "%s: %d" % [GOO_NAMES[gtype], supply[gtype]]
			lbl.position = Vector2(52, y_off)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
			lbl.add_theme_font_size_override("font_size", 18)
			add_child(lbl)
			supply_labels[gtype] = lbl
			y_off += 32

	# Collected counter
	collected_label = Label.new()
	collected_label.text = "Collected: 0 / %d" % collect_quota
	collected_label.position = Vector2(1020, 15)
	collected_label.size = Vector2(250, 30)
	collected_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))
	collected_label.add_theme_font_size_override("font_size", 22)
	add_child(collected_label)

	# Level name
	level_label = Label.new()
	level_label.text = "Level %d: %s" % [level_index + 1, level_data["name"]]
	level_label.position = Vector2(1020, 50)
	level_label.size = Vector2(250, 30)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.65))
	level_label.add_theme_font_size_override("font_size", 18)
	add_child(level_label)

func _physics_process(delta: float) -> void:
	_simulate(delta)
	_update_visuals()
	_check_goal()
	_check_hazards()

func _simulate(delta: float) -> void:
	# Apply forces to non-anchored blobs
	for i in range(blobs.size()):
		var b = blobs[i]
		if b["anchored"]:
			continue
		# Gravity
		var force = Vector2(0, GRAVITY)
		# Wind
		force += wind_force
		# Balloon lift
		if b["type"] == GooType.BALLOON:
			force.y += BALLOON_LIFT
		b["vel"] += force * delta

	# Spring forces from bonds
	var bonds_to_remove: Array = []
	for bi in range(bonds.size()):
		var bond = bonds[bi]
		var a_idx: int = bond["a_idx"]
		var b_idx: int = bond["b_idx"]
		var a = blobs[a_idx]
		var b2 = blobs[b_idx]
		var diff: Vector2 = b2["pos"] - a["pos"]
		var dist: float = diff.length()
		if dist < 0.1:
			continue
		var rest: float = bond["rest_len"]
		var stretch_ratio: float = dist / rest
		# Break overstretched bonds
		if stretch_ratio > BOND_BREAK_STRETCH:
			bonds_to_remove.append(bi)
			continue
		var direction: Vector2 = diff / dist
		var displacement: float = dist - rest
		var k: float = SPRING_K
		if a["type"] == GooType.RIGID or b2["type"] == GooType.RIGID:
			k = RIGID_K
		var spring_force: Vector2 = direction * k * displacement
		var rel_vel: Vector2 = b2["vel"] - a["vel"]
		var damp_force: Vector2 = direction * rel_vel.dot(direction) * SPRING_DAMPING
		var total: Vector2 = spring_force + damp_force
		if not a["anchored"]:
			a["vel"] += total * delta
		if not b2["anchored"]:
			b2["vel"] -= total * delta

	# Remove broken bonds (reverse order)
	bonds_to_remove.sort()
	bonds_to_remove.reverse()
	for bi in bonds_to_remove:
		var bond = bonds[bi]
		if is_instance_valid(bond["line_node"]):
			bond["line_node"].queue_free()
		bonds.remove_at(bi)

	# Integrate positions and handle terrain collision
	for i in range(blobs.size()):
		var b = blobs[i]
		if b["anchored"]:
			continue
		b["vel"] *= 0.98  # air drag
		b["pos"] += b["vel"] * delta
		# Terrain collision
		for rect in terrain_rects:
			if rect.has_point(b["pos"]):
				# Push out of terrain
				var cx: float = rect.position.x + rect.size.x * 0.5
				var cy: float = rect.position.y + rect.size.y * 0.5
				var dx: float = b["pos"].x - cx
				var dy: float = b["pos"].y - cy
				var hx: float = rect.size.x * 0.5
				var hy: float = rect.size.y * 0.5
				var ox: float = hx - abs(dx)
				var oy: float = hy - abs(dy)
				if ox < oy:
					b["pos"].x += ox * sign(dx)
					b["vel"].x *= -0.3
				else:
					b["pos"].y += oy * sign(dy)
					b["vel"].y *= -0.3
		# Keep in bounds
		b["pos"].x = clamp(b["pos"].x, 10, 1270)
		b["pos"].y = clamp(b["pos"].y, 10, 710)

func _update_visuals() -> void:
	for i in range(blobs.size()):
		var b = blobs[i]
		var node: ColorRect = b["node"]
		node.position = b["pos"] - Vector2(BLOB_RADIUS, BLOB_RADIUS)
	# Update bond lines
	for bond in bonds:
		var line: Line2D = bond["line_node"]
		if is_instance_valid(line):
			line.set_point_position(0, blobs[bond["a_idx"]]["pos"])
			line.set_point_position(1, blobs[bond["b_idx"]]["pos"])
			# Color based on stretch
			var dist: float = blobs[bond["a_idx"]]["pos"].distance_to(blobs[bond["b_idx"]]["pos"])
			var ratio: float = dist / bond["rest_len"]
			if ratio > 1.8:
				line.default_color = Color(0.9, 0.2, 0.1)
			elif ratio > 1.4:
				line.default_color = Color(0.9, 0.7, 0.1)
			else:
				line.default_color = Color(0.6, 0.8, 0.5)

func _check_goal() -> void:
	for i in range(blobs.size()):
		var b = blobs[i]
		if goal_rect.has_point(b["pos"]):
			# Collect this blob
			collected += 1
			collected_label.text = "Collected: %d / %d" % [collected, collect_quota]
			# Remove blob visually
			b["node"].queue_free()
			# Remove bonds connected to this blob
			var to_remove: Array = []
			for bi in range(bonds.size()):
				if bonds[bi]["a_idx"] == i or bonds[bi]["b_idx"] == i:
					to_remove.append(bi)
			to_remove.sort()
			to_remove.reverse()
			for bi in to_remove:
				if is_instance_valid(bonds[bi]["line_node"]):
					bonds[bi]["line_node"].queue_free()
				bonds.remove_at(bi)
			# Mark blob as collected (move far away)
			b["pos"] = Vector2(-1000, -1000)
			b["vel"] = Vector2.ZERO
			b["anchored"] = true
			# Check win
			if collected >= collect_quota:
				_win()
			return

func _check_hazards() -> void:
	for i in range(blobs.size()):
		var b = blobs[i]
		if b["anchored"] and b["pos"].x < 0:
			continue
		for rect in hazard_rects:
			if rect.has_point(b["pos"]):
				# Destroy blob
				b["node"].queue_free()
				b["pos"] = Vector2(-1000, -1000)
				b["vel"] = Vector2.ZERO
				b["anchored"] = true
				# Remove bonds
				var to_remove: Array = []
				for bi in range(bonds.size()):
					if bonds[bi]["a_idx"] == i or bonds[bi]["b_idx"] == i:
						to_remove.append(bi)
				to_remove.sort()
				to_remove.reverse()
				for bi in to_remove:
					if is_instance_valid(bonds[bi]["line_node"]):
						bonds[bi]["line_node"].queue_free()
					bonds.remove_at(bi)
				return

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag(mb.position)
			else:
				_end_drag(mb.position)
	elif event is InputEventMouseMotion:
		if dragging and drag_node != null:
			drag_pos = event.position
			drag_node.position = drag_pos - Vector2(BLOB_RADIUS, BLOB_RADIUS)

func _start_drag(pos: Vector2) -> void:
	# Determine which goo type to place based on keyboard selection or default
	# Try types in order: 1=standard, 2=rigid, 3=balloon
	var selected_type = -1
	for gtype in [GooType.STANDARD, GooType.RIGID, GooType.BALLOON]:
		if supply.has(gtype) and supply[gtype] > 0:
			selected_type = gtype
			break
	if selected_type == -1:
		return
	# Check if click is in supply area (left panel)
	if pos.x < 240 and pos.y < 150:
		# Clicked supply area - pick type based on y position
		var y_off = 15
		for gtype in [GooType.STANDARD, GooType.RIGID, GooType.BALLOON]:
			if supply.has(gtype) and supply[gtype] > 0:
				if pos.y >= y_off and pos.y < y_off + 32:
					selected_type = gtype
					break
				y_off += 32
	dragging = true
	drag_type = selected_type
	drag_pos = pos
	# Create preview node
	drag_node = ColorRect.new()
	drag_node.color = GOO_COLORS[selected_type]
	drag_node.color.a = 0.7
	drag_node.size = Vector2(BLOB_RADIUS * 2, BLOB_RADIUS * 2)
	drag_node.position = pos - Vector2(BLOB_RADIUS, BLOB_RADIUS)
	add_child(drag_node)

func _end_drag(pos: Vector2) -> void:
	if not dragging:
		return
	dragging = false
	if drag_node != null:
		drag_node.queue_free()
		drag_node = null
	# Check if near any existing blob to attach
	var nearest_idx = -1
	var nearest_dist = SNAP_DISTANCE * 1.5
	for i in range(blobs.size()):
		var b = blobs[i]
		if b["pos"].x < 0:
			continue
		var d: float = pos.distance_to(b["pos"])
		if d < nearest_dist and d > BLOB_RADIUS * 2:
			nearest_dist = d
			nearest_idx = i
	if nearest_idx == -1:
		return  # Too far from structure
	# Place the blob
	if not supply.has(drag_type) or supply[drag_type] <= 0:
		return
	supply[drag_type] -= 1
	_update_supply_labels()
	var new_idx = _add_blob(pos, drag_type, false)
	# Bond to nearby blobs
	for i in range(blobs.size()):
		if i == new_idx:
			continue
		if blobs[i]["pos"].x < 0:
			continue
		var d: float = pos.distance_to(blobs[i]["pos"])
		if d < SNAP_DISTANCE:
			_add_bond(new_idx, i)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_select_goo_type(GooType.STANDARD)
			KEY_2:
				_select_goo_type(GooType.RIGID)
			KEY_3:
				_select_goo_type(GooType.BALLOON)
			KEY_ESCAPE:
				main._enter_level_select()

func _select_goo_type(gtype: int) -> void:
	# Just a hint for next drag - we use the first available by default
	pass

func _add_blob(pos: Vector2, gtype: int, anchored: bool) -> int:
	var node = ColorRect.new()
	node.color = GOO_COLORS[gtype]
	node.size = Vector2(BLOB_RADIUS * 2, BLOB_RADIUS * 2)
	node.position = pos - Vector2(BLOB_RADIUS, BLOB_RADIUS)
	add_child(node)
	var blob = {
		"pos": pos,
		"vel": Vector2.ZERO,
		"type": gtype,
		"node": node,
		"anchored": anchored,
	}
	blobs.append(blob)
	return blobs.size() - 1

func _add_bond(a_idx: int, b_idx: int) -> void:
	# Check if bond already exists
	for bond in bonds:
		if (bond["a_idx"] == a_idx and bond["b_idx"] == b_idx) or \
		   (bond["a_idx"] == b_idx and bond["b_idx"] == a_idx):
			return
	var rest_len: float = blobs[a_idx]["pos"].distance_to(blobs[b_idx]["pos"])
	if rest_len < 1.0:
		rest_len = 30.0
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.6, 0.8, 0.5)
	line.add_point(blobs[a_idx]["pos"])
	line.add_point(blobs[b_idx]["pos"])
	add_child(line)
	# Move line behind blobs
	move_child(line, get_child_count() - blobs.size() - 1)
	bonds.append({"a_idx": a_idx, "b_idx": b_idx, "rest_len": rest_len, "line_node": line})

func _update_supply_labels() -> void:
	for gtype in supply_labels:
		if supply_labels.has(gtype) and is_instance_valid(supply_labels[gtype]):
			supply_labels[gtype].text = "%s: %d" % [GOO_NAMES[gtype], supply[gtype]]

func _win() -> void:
	var total_supply = 0
	for gtype in level_data["supply"]:
		total_supply += level_data["supply"][gtype]
	var used = 0
	for gtype in level_data["supply"]:
		used += level_data["supply"][gtype] - supply[gtype]
	var saved = total_supply - used
	main._enter_result(level_index, saved)

func _setup_near_victory() -> void:
	# Place blobs near the goal for demo purposes
	var goal_center: Vector2 = goal_rect.position + goal_rect.size * 0.5
	var below = goal_center + Vector2(0, 80)
	# Build a small tower toward goal
	var positions = [
		below + Vector2(0, 120),
		below + Vector2(-30, 80),
		below + Vector2(30, 80),
		below + Vector2(0, 40),
		below + Vector2(-20, 0),
		below + Vector2(20, 0),
	]
	for i in range(positions.size()):
		var idx = _add_blob(positions[i], GooType.STANDARD, i < 2)
		# Bond to previous blobs
		for j in range(blobs.size() - 1):
			if blobs[j]["pos"].x < 0:
				continue
			var d: float = positions[i].distance_to(blobs[j]["pos"])
			if d < SNAP_DISTANCE:
				_add_bond(idx, j)
	# Reduce supply
	supply[GooType.STANDARD] = 2
	supply[GooType.RIGID] = 1
	_update_supply_labels()
