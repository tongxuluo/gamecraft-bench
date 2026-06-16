extends Node2D

var main: Node = null
var level_index: int = 0

# Grid constants
const GRID_COLS := 8
const GRID_ROWS := 5
const CELL_SIZE := 80
const GRID_OFFSET := Vector2(240, 120)

# Colors
const COLOR_PCB := Color(0.05, 0.25, 0.12)
const COLOR_PCB_DARK := Color(0.03, 0.18, 0.08)
const COLOR_COPPER := Color(0.72, 0.45, 0.20)
const COLOR_GOLD := Color(0.85, 0.65, 0.13)
const COLOR_WIRE_OFF := Color(0.3, 0.3, 0.3)
const COLOR_WIRE_ON := Color(0.1, 0.9, 0.2)
const COLOR_CORRECT := Color(0.1, 0.9, 0.3)
const COLOR_WRONG := Color(0.9, 0.1, 0.1)
const COLOR_GATE_BG := Color(0.12, 0.12, 0.15)
const COLOR_GATE_BORDER := Color(0.6, 0.6, 0.7)
const COLOR_INPUT := Color(0.2, 0.5, 0.9)
const COLOR_OUTPUT := Color(0.9, 0.5, 0.2)

# Gate types
enum GateType { NONE, AND, OR, NOT, XOR }

# Level data
var levels = []
var grid: Array = []  # 2D array of GateType
var selected_gate: GateType = GateType.AND
var inputs: Array = []  # Array of {row, value}
var outputs: Array = []  # Array of {row, target_value, current_value}
var is_testing: bool = false
var level_complete: bool = false
var signal_anim_progress: float = 0.0
var wire_signals: Dictionary = {}  # cell key -> bool

# UI refs
var hud_label: Label = null
var gate_label: Label = null
var result_label: Label = null

func _ready() -> void:
	_init_levels()
	_init_grid()
	_build_ui()
	queue_redraw()

func _init_levels() -> void:
	# Level 1: Simple AND - two inputs, one output, need AND gate
	levels.append({
		"name": "AND Gate Basics",
		"description": "Route both inputs through an AND gate to the output.",
		"inputs": [{"row": 1, "value": true}, {"row": 3, "value": true}],
		"outputs": [{"row": 2, "target": true}],
		"truth_table": "A AND B = 1"
	})
	# Level 2: OR + NOT combo
	levels.append({
		"name": "OR + NOT Combo",
		"description": "Use OR then NOT to invert the combined signal.",
		"inputs": [{"row": 1, "value": false}, {"row": 3, "value": true}],
		"outputs": [{"row": 2, "target": false}],
		"truth_table": "NOT(A OR B) = 0"
	})
	# Level 3: Multi-gate XOR challenge
	levels.append({
		"name": "Multi-Gate XOR",
		"description": "Build XOR from AND, OR, NOT or use XOR directly.",
		"inputs": [{"row": 0, "value": true}, {"row": 2, "value": false}, {"row": 4, "value": true}],
		"outputs": [{"row": 1, "target": true}, {"row": 3, "target": true}],
		"truth_table": "A XOR B, B XOR C"
	})

func _init_grid() -> void:
	grid.clear()
	for r in range(GRID_ROWS):
		var row_arr = []
		for c in range(GRID_COLS):
			row_arr.append(GateType.NONE)
		grid.append(row_arr)
	var lvl = levels[level_index]
	inputs.clear()
	for inp in lvl["inputs"]:
		inputs.append({"row": inp["row"], "value": inp["value"]})
	outputs.clear()
	for outp in lvl["outputs"]:
		outputs.append({"row": outp["row"], "target": outp["target"], "current": false})
	is_testing = false
	level_complete = false
	signal_anim_progress = 0.0
	wire_signals.clear()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_PCB_DARK
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# HUD bar at top
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.02, 0.15, 0.08)
	hud_bg.size = Vector2(1280, 50)
	add_child(hud_bg)

	hud_label = Label.new()
	hud_label.text = "Level %d: %s" % [level_index + 1, levels[level_index]["name"]]
	hud_label.position = Vector2(20, 8)
	hud_label.size = Vector2(600, 40)
	hud_label.add_theme_color_override("font_color", COLOR_GOLD)
	hud_label.add_theme_font_size_override("font_size", 22)
	add_child(hud_label)

	# Gate palette label
	gate_label = Label.new()
	gate_label.position = Vector2(20, 60)
	gate_label.size = Vector2(200, 50)
	gate_label.add_theme_color_override("font_color", COLOR_COPPER)
	gate_label.add_theme_font_size_override("font_size", 18)
	_update_gate_label()
	add_child(gate_label)

	# Description
	var desc = Label.new()
	desc.text = levels[level_index]["description"]
	desc.position = Vector2(240, 60)
	desc.size = Vector2(700, 40)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	desc.add_theme_font_size_override("font_size", 16)
	add_child(desc)

	# Test button
	var test_btn = _make_button("TEST", Vector2(1050, 60), Vector2(100, 40))
	test_btn.pressed.connect(_on_test_pressed)
	add_child(test_btn)

	# Clear button
	var clear_btn = _make_button("CLEAR", Vector2(1160, 60), Vector2(100, 40))
	clear_btn.pressed.connect(_on_clear_pressed)
	add_child(clear_btn)

	# Result label (hidden initially)
	result_label = Label.new()
	result_label.position = Vector2(0, 680)
	result_label.size = Vector2(1280, 40)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 24)
	result_label.text = ""
	add_child(result_label)

func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.30, 0.15)
	sb.border_color = COLOR_COPPER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h = sb.duplicate()
	sb_h.bg_color = Color(0.12, 0.38, 0.20)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.88))
	b.add_theme_font_size_override("font_size", 18)
	return b

func _update_gate_label() -> void:
	var names = {GateType.AND: "AND", GateType.OR: "OR", GateType.NOT: "NOT", GateType.XOR: "XOR"}
	gate_label.text = "Gate: [%s] (1-4)" % names[selected_gate]

func _on_test_pressed() -> void:
	is_testing = true
	signal_anim_progress = 0.0
	_evaluate_circuit()
	_check_completion()
	queue_redraw()

func _on_clear_pressed() -> void:
	_init_grid()
	if result_label:
		result_label.text = ""
		result_label.add_theme_color_override("font_color", Color.WHITE)
	queue_redraw()

func _check_completion() -> void:
	var all_correct = true
	for outp in outputs:
		if outp["current"] != outp["target"]:
			all_correct = false
			break
	if all_correct:
		level_complete = true
		result_label.text = "LEVEL COMPLETE! Press ENTER for next level."
		result_label.add_theme_color_override("font_color", COLOR_CORRECT)
	else:
		result_label.text = "Output incorrect. Adjust your circuit and test again."
		result_label.add_theme_color_override("font_color", COLOR_WRONG)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				selected_gate = GateType.AND
				_update_gate_label()
			KEY_2:
				selected_gate = GateType.OR
				_update_gate_label()
			KEY_3:
				selected_gate = GateType.NOT
				_update_gate_label()
			KEY_4:
				selected_gate = GateType.XOR
				_update_gate_label()
			KEY_ENTER:
				if level_complete:
					main._enter_next_level()
			KEY_ESCAPE:
				main._enter_title()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_grid_click(event.position)

func _handle_grid_click(pos: Vector2) -> void:
	if level_complete:
		return
	var grid_pos = pos - GRID_OFFSET
	var col = int(grid_pos.x / CELL_SIZE)
	var row = int(grid_pos.y / CELL_SIZE)
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return
	if grid_pos.x < 0 or grid_pos.y < 0:
		return
	# Toggle: if same gate type, remove it; otherwise place selected
	if grid[row][col] == selected_gate:
		grid[row][col] = GateType.NONE
	else:
		grid[row][col] = selected_gate
	is_testing = false
	wire_signals.clear()
	if result_label:
		result_label.text = ""
	queue_redraw()

func _evaluate_circuit() -> void:
	# Signal propagation: left to right, column by column
	# Each cell can receive signals from left neighbor and from above/below
	wire_signals.clear()
	var cell_outputs: Dictionary = {}  # "row,col" -> bool

	# Initialize input signals
	for inp in inputs:
		var key = "%d,-1" % inp["row"]
		cell_outputs[key] = inp["value"]

	# Propagate column by column
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			var gate: int = grid[row][col]
			if gate == GateType.NONE:
				# Pass through from left if signal exists
				var left_key = "%d,%d" % [row, col - 1]
				var inp_key = "%d,-1" % row
				if cell_outputs.has(left_key):
					cell_outputs["%d,%d" % [row, col]] = cell_outputs[left_key]
					wire_signals["%d,%d" % [row, col]] = cell_outputs[left_key]
				elif col == 0 and cell_outputs.has(inp_key):
					cell_outputs["%d,%d" % [row, col]] = cell_outputs[inp_key]
					wire_signals["%d,%d" % [row, col]] = cell_outputs[inp_key]
				continue

			# Gather inputs for this gate
			var gate_inputs: Array = []
			# From left
			var left_key2 = "%d,%d" % [row, col - 1]
			var inp_key2 = "%d,-1" % row
			if cell_outputs.has(left_key2):
				gate_inputs.append(cell_outputs[left_key2])
			elif col == 0 and cell_outputs.has(inp_key2):
				gate_inputs.append(cell_outputs[inp_key2])
			# From above
			if row > 0:
				var above_key = "%d,%d" % [row - 1, col]
				if cell_outputs.has(above_key):
					gate_inputs.append(cell_outputs[above_key])
			# From below
			if row < GRID_ROWS - 1:
				var below_key = "%d,%d" % [row + 1, col]
				if cell_outputs.has(below_key):
					gate_inputs.append(cell_outputs[below_key])

			var result: bool = _compute_gate(gate, gate_inputs)
			cell_outputs["%d,%d" % [row, col]] = result
			wire_signals["%d,%d" % [row, col]] = result

	# Check outputs
	for i in range(outputs.size()):
		var outp = outputs[i]
		var found = false
		# Check rightmost column for matching row
		for col in range(GRID_COLS - 1, -1, -1):
			var key = "%d,%d" % [outp["row"], col]
			if cell_outputs.has(key):
				outputs[i]["current"] = cell_outputs[key]
				found = true
				break
		if not found:
			outputs[i]["current"] = false

func _compute_gate(gate: int, gate_inputs: Array) -> bool:
	if gate_inputs.is_empty():
		return false
	match gate:
		GateType.AND:
			if gate_inputs.size() < 2:
				return gate_inputs[0]
			var result = true
			for v in gate_inputs:
				if not v:
					result = false
			return result
		GateType.OR:
			var result = false
			for v in gate_inputs:
				if v:
					result = true
			return result
		GateType.NOT:
			return not gate_inputs[0]
		GateType.XOR:
			if gate_inputs.size() < 2:
				return gate_inputs[0]
			var count = 0
			for v in gate_inputs:
				if v:
					count += 1
			return count % 2 == 1
	return false

func _draw() -> void:
	_draw_grid()
	_draw_inputs()
	_draw_outputs()
	_draw_gates()
	_draw_wires()

func _draw_grid() -> void:
	# Draw grid background
	var grid_bg = Rect2(GRID_OFFSET - Vector2(5, 5), Vector2(GRID_COLS * CELL_SIZE + 10, GRID_ROWS * CELL_SIZE + 10))
	draw_rect(grid_bg, Color(0.04, 0.20, 0.10))
	draw_rect(grid_bg, COLOR_COPPER.darkened(0.3), false, 2.0)
	# Draw cells
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var pos = GRID_OFFSET + Vector2(col * CELL_SIZE, row * CELL_SIZE)
			var rect = Rect2(pos + Vector2(2, 2), Vector2(CELL_SIZE - 4, CELL_SIZE - 4))
			draw_rect(rect, Color(0.06, 0.22, 0.12))
			draw_rect(rect, Color(0.15, 0.35, 0.20), false, 1.0)

func _draw_inputs() -> void:
	for inp in inputs:
		var y = GRID_OFFSET.y + inp["row"] * CELL_SIZE + CELL_SIZE / 2
		var x = GRID_OFFSET.x - 60
		# Terminal box
		var rect = Rect2(Vector2(x - 30, y - 20), Vector2(60, 40))
		var color: Color = COLOR_WIRE_ON if inp["value"] else COLOR_WIRE_OFF
		draw_rect(rect, color.darkened(0.5))
		draw_rect(rect, color, false, 2.0)
		# Label
		var txt = "1" if inp["value"] else "0"
		draw_string(ThemeDB.fallback_font, Vector2(x - 5, y + 8), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, color)
		# Wire to grid
		draw_line(Vector2(x + 30, y), Vector2(GRID_OFFSET.x, y), color, 3.0)
		# Pin circle
		draw_circle(Vector2(x + 30, y), 6, color)

func _draw_outputs() -> void:
	var right_x = GRID_OFFSET.x + GRID_COLS * CELL_SIZE
	for outp in outputs:
		var y = GRID_OFFSET.y + outp["row"] * CELL_SIZE + CELL_SIZE / 2
		var x = right_x + 60
		# Determine color based on test state
		var color: Color = COLOR_OUTPUT
		if is_testing:
			if outp["current"] == outp["target"]:
				color = COLOR_CORRECT
			else:
				color = COLOR_WRONG
		# Terminal box
		var rect = Rect2(Vector2(x - 30, y - 20), Vector2(60, 40))
		draw_rect(rect, color.darkened(0.5))
		draw_rect(rect, color, false, 2.0)
		# Target label
		var txt = "1" if outp["target"] else "0"
		draw_string(ThemeDB.fallback_font, Vector2(x - 5, y + 8), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, color)
		# Wire from grid
		draw_line(Vector2(right_x, y), Vector2(x - 30, y), color, 3.0)
		# Pin circle
		draw_circle(Vector2(x - 30, y), 6, color)

func _draw_gates() -> void:
	var names = {GateType.AND: "AND", GateType.OR: "OR", GateType.NOT: "NOT", GateType.XOR: "XOR"}
	var gate_colors = {
		GateType.AND: Color(0.2, 0.4, 0.8),
		GateType.OR: Color(0.2, 0.7, 0.3),
		GateType.NOT: Color(0.8, 0.3, 0.3),
		GateType.XOR: Color(0.7, 0.5, 0.1)
	}
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var gate: int = grid[row][col]
			if gate == GateType.NONE:
				continue
			var pos = GRID_OFFSET + Vector2(col * CELL_SIZE, row * CELL_SIZE)
			var center = pos + Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
			var gc: Color = gate_colors[gate]
			# Gate body
			var body_rect = Rect2(pos + Vector2(8, 8), Vector2(CELL_SIZE - 16, CELL_SIZE - 16))
			draw_rect(body_rect, gc.darkened(0.6))
			draw_rect(body_rect, gc, false, 2.0)
			# Gate symbol
			draw_string(ThemeDB.fallback_font, center + Vector2(-14, 6), names[gate], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, gc.lightened(0.4))
			# Input pins (left side)
			if gate == GateType.NOT:
				draw_circle(Vector2(pos.x + 8, center.y), 4, gc)
			else:
				draw_circle(Vector2(pos.x + 8, pos.y + 25), 4, gc)
				draw_circle(Vector2(pos.x + 8, pos.y + 55), 4, gc)
			# Output pin (right side)
			draw_circle(Vector2(pos.x + CELL_SIZE - 8, center.y), 5, gc)
			# Signal indicator if testing
			if is_testing:
				var key = "%d,%d" % [row, col]
				if wire_signals.has(key):
					var sig_color: Color = COLOR_WIRE_ON if wire_signals[key] else COLOR_WIRE_OFF
					draw_circle(Vector2(pos.x + CELL_SIZE - 8, center.y), 3, sig_color)

func _draw_wires() -> void:
	if not is_testing:
		return
	# Draw signal flow lines between connected cells
	for row in range(GRID_ROWS):
		for col in range(1, GRID_COLS):
			var key = "%d,%d" % [row, col]
			var prev_key = "%d,%d" % [row, col - 1]
			if wire_signals.has(key) and wire_signals.has(prev_key):
				var from_pos = GRID_OFFSET + Vector2((col - 1) * CELL_SIZE + CELL_SIZE - 8, row * CELL_SIZE + CELL_SIZE / 2)
				var to_pos = GRID_OFFSET + Vector2(col * CELL_SIZE + 8, row * CELL_SIZE + CELL_SIZE / 2)
				var color: Color = COLOR_WIRE_ON if wire_signals[key] else COLOR_WIRE_OFF
				draw_line(from_pos, to_pos, color, 2.5)
	# Vertical connections
	for row in range(GRID_ROWS - 1):
		for col in range(GRID_COLS):
			var key = "%d,%d" % [row, col]
			var below_key = "%d,%d" % [row + 1, col]
			if wire_signals.has(key) and wire_signals.has(below_key):
				if grid[row][col] != GateType.NONE or grid[row + 1][col] != GateType.NONE:
					var from_pos = GRID_OFFSET + Vector2(col * CELL_SIZE + CELL_SIZE / 2, row * CELL_SIZE + CELL_SIZE - 8)
					var to_pos = GRID_OFFSET + Vector2(col * CELL_SIZE + CELL_SIZE / 2, (row + 1) * CELL_SIZE + 8)
					var color: Color = COLOR_WIRE_ON if wire_signals[below_key] else COLOR_WIRE_OFF
					draw_line(from_pos, to_pos, color, 2.0)

func _process(delta: float) -> void:
	if is_testing and signal_anim_progress < 1.0:
		signal_anim_progress += delta * 2.0
		queue_redraw()
