extends Node2D

var main: Node = null
var level_index: int = 0

# Grid constants
const CELL_SIZE := 64
const GRID_OFFSET := Vector2(240, 80)
const GRID_COLS := 10
const GRID_ROWS := 8

# Pipe types: each has an array of open directions (0=up,1=right,2=down,3=left)
# Stored as base openings; rotation adds to direction indices mod 4
enum PipeType { STRAIGHT, CORNER, T_JUNCTION, CROSS, RESERVOIR }

# Cell states
var grid: Array = []  # 2D array [row][col] of cell data
var fluid_grid: Array = []  # tracks fluid color per cell (-1 = none)

# Level data
var sources: Array = []  # {row, col, color, direction}
var drains: Array = []   # {row, col, color, direction}
var obstacles: Array = [] # {row, col}
var pipe_queue: Array = []
var queue_index: int = 0

# Game state
var countdown: float = 0.0
var countdown_max: float = 0.0
var flowing: bool = false
var flow_progress: int = 0
var flow_timer: float = 0.0
var flow_path: Array = []
var game_over: bool = false
var game_won: bool = false
var selected_rotation: int = 0  # 0-3

# UI references
var countdown_label: Label = null
var queue_display: Node2D = null
var status_label: Label = null
var level_label: Label = null
var rotation_label: Label = null

# Colors for fluids
var fluid_colors = [Color(0.2, 0.4, 0.9), Color(0.9, 0.2, 0.2), Color(0.2, 0.9, 0.3)]
var fluid_names = ["Blue Coolant", "Red Chemical", "Green Acid"]

func _ready() -> void:
	_init_level()
	_build_ui()
	_draw_grid()

func _init_level() -> void:
	# Initialize empty grid
	grid = []
	fluid_grid = []
	for r in range(GRID_ROWS):
		var row = []
		var frow = []
		for c in range(GRID_COLS):
			row.append({"pipe": -1, "rotation": 0})
			frow.append(-1)
		grid.append(row)
		fluid_grid.append(frow)

	sources = []
	drains = []
	obstacles = []
	pipe_queue = []

	match level_index:
		0:
			_setup_level_1()
		1:
			_setup_level_2()
		2:
			_setup_level_3()
		_:
			_setup_level_1()

func _setup_level_1() -> void:
	# Simple: one blue source on left, one blue drain on right
	countdown_max = 30.0
	countdown = countdown_max
	sources.append({"row": 3, "col": 0, "color": 0, "dir": 1})  # flows right
	drains.append({"row": 3, "col": 9, "color": 0, "dir": 3})   # accepts from left
	# Generate pipe queue
	pipe_queue = [PipeType.STRAIGHT, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.CORNER, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.CORNER, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.STRAIGHT, PipeType.T_JUNCTION, PipeType.STRAIGHT,
				  PipeType.CORNER, PipeType.STRAIGHT, PipeType.STRAIGHT]

func _setup_level_2() -> void:
	# Two sources, two drains, color matching
	countdown_max = 40.0
	countdown = countdown_max
	sources.append({"row": 1, "col": 0, "color": 0, "dir": 1})  # blue, flows right
	sources.append({"row": 5, "col": 0, "color": 1, "dir": 1})  # red, flows right
	drains.append({"row": 1, "col": 9, "color": 0, "dir": 3})   # blue drain
	drains.append({"row": 5, "col": 9, "color": 1, "dir": 3})   # red drain
	# Obstacle in middle
	obstacles.append({"row": 3, "col": 4})
	obstacles.append({"row": 3, "col": 5})
	obstacles.append({"row": 3, "col": 6})
	pipe_queue = [PipeType.STRAIGHT, PipeType.STRAIGHT, PipeType.CORNER,
				  PipeType.STRAIGHT, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.CORNER, PipeType.STRAIGHT, PipeType.T_JUNCTION,
				  PipeType.STRAIGHT, PipeType.STRAIGHT, PipeType.CORNER,
				  PipeType.STRAIGHT, PipeType.CROSS, PipeType.STRAIGHT,
				  PipeType.STRAIGHT, PipeType.CORNER, PipeType.STRAIGHT,
				  PipeType.STRAIGHT, PipeType.STRAIGHT]

func _setup_level_3() -> void:
	# Three sources, obstacles, tight timer
	countdown_max = 45.0
	countdown = countdown_max
	sources.append({"row": 0, "col": 0, "color": 0, "dir": 2})  # blue, flows down
	sources.append({"row": 4, "col": 0, "color": 1, "dir": 1})  # red, flows right
	sources.append({"row": 7, "col": 0, "color": 2, "dir": 1})  # green, flows right
	drains.append({"row": 0, "col": 9, "color": 0, "dir": 3})   # blue drain
	drains.append({"row": 4, "col": 9, "color": 1, "dir": 3})   # red drain
	drains.append({"row": 7, "col": 9, "color": 2, "dir": 3})   # green drain
	# Obstacles
	obstacles.append({"row": 2, "col": 3})
	obstacles.append({"row": 2, "col": 4})
	obstacles.append({"row": 5, "col": 5})
	obstacles.append({"row": 5, "col": 6})
	obstacles.append({"row": 6, "col": 3})
	pipe_queue = [PipeType.STRAIGHT, PipeType.CORNER, PipeType.STRAIGHT,
				  PipeType.T_JUNCTION, PipeType.STRAIGHT, PipeType.CORNER,
				  PipeType.STRAIGHT, PipeType.CROSS, PipeType.STRAIGHT,
				  PipeType.CORNER, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.RESERVOIR, PipeType.CORNER, PipeType.STRAIGHT,
				  PipeType.STRAIGHT, PipeType.T_JUNCTION, PipeType.CORNER,
				  PipeType.STRAIGHT, PipeType.STRAIGHT, PipeType.CORNER,
				  PipeType.STRAIGHT, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.CORNER, PipeType.STRAIGHT, PipeType.STRAIGHT,
				  PipeType.STRAIGHT, PipeType.CORNER, PipeType.STRAIGHT]

func _get_pipe_openings(pipe_type: int, rot: int) -> Array:
	# Returns array of directions this pipe connects to
	# Directions: 0=up, 1=right, 2=down, 3=left
	var base: Array = []
	match pipe_type:
		PipeType.STRAIGHT:
			base = [0, 2]  # up-down
		PipeType.CORNER:
			base = [0, 1]  # up-right
		PipeType.T_JUNCTION:
			base = [0, 1, 2]  # up-right-down
		PipeType.CROSS:
			base = [0, 1, 2, 3]  # all
		PipeType.RESERVOIR:
			base = [0, 1, 2, 3]  # all directions (acts as buffer)
	var rotated: Array = []
	for d in base:
		rotated.append((d + rot) % 4)
	return rotated

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.05, 0.06, 0.08)
	add_child(bg)

	# Level label
	level_label = Label.new()
	level_label.text = "Level " + str(level_index + 1)
	level_label.add_theme_font_size_override("font_size", 28)
	level_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8))
	level_label.position = Vector2(20, 10)
	add_child(level_label)

	# Countdown label
	countdown_label = Label.new()
	countdown_label.add_theme_font_size_override("font_size", 32)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	countdown_label.position = Vector2(1050, 10)
	add_child(countdown_label)
	_update_countdown_display()

	# Status label
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	status_label.position = Vector2(400, 10)
	status_label.text = "Place pipes to connect source to drain"
	add_child(status_label)

	# Rotation indicator
	rotation_label = Label.new()
	rotation_label.add_theme_font_size_override("font_size", 18)
	rotation_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	rotation_label.position = Vector2(20, 640)
	rotation_label.text = "Rotation: 0 (R to rotate)"
	add_child(rotation_label)

	# Pipe queue display
	_draw_queue()

	# Fluid color legend
	var legend_y = 600
	for i in range(fluid_colors.size()):
		if _level_uses_color(i):
			var swatch = ColorRect.new()
			swatch.size = Vector2(16, 16)
			swatch.color = fluid_colors[i]
			swatch.position = Vector2(20, legend_y)
			add_child(swatch)
			var lbl = Label.new()
			lbl.text = fluid_names[i]
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			lbl.position = Vector2(42, legend_y - 2)
			add_child(lbl)
			legend_y += 22

func _level_uses_color(c: int) -> bool:
	for s in sources:
		if s.color == c:
			return true
	return false

func _draw_queue() -> void:
	if queue_display != null:
		queue_display.queue_free()
	queue_display = Node2D.new()
	queue_display.position = Vector2(960, 80)
	add_child(queue_display)

	var qlbl = Label.new()
	qlbl.text = "PIPE QUEUE"
	qlbl.add_theme_font_size_override("font_size", 18)
	qlbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	qlbl.position = Vector2(0, -10)
	queue_display.add_child(qlbl)

	var show_count = mini(5, pipe_queue.size() - queue_index)
	for i in range(show_count):
		var idx = queue_index + i
		var cell_bg = ColorRect.new()
		cell_bg.size = Vector2(50, 50)
		if i == 0:
			cell_bg.color = Color(0.25, 0.3, 0.2)
		else:
			cell_bg.color = Color(0.15, 0.17, 0.2)
		cell_bg.position = Vector2(i * 58, 20)
		queue_display.add_child(cell_bg)
		var icon_rot = selected_rotation if i == 0 else 0
		_draw_pipe_icon(queue_display, Vector2(i * 58 + 25, 45), pipe_queue[idx], icon_rot, 20.0)

func _draw_pipe_icon(parent: Node, center: Vector2, pipe_type: int, rot: int, sz: float) -> void:
	var openings = _get_pipe_openings(pipe_type, rot)
	# Draw center dot
	var dot = ColorRect.new()
	dot.size = Vector2(8, 8)
	dot.position = center - Vector2(4, 4)
	dot.color = Color(0.6, 0.65, 0.7)
	parent.add_child(dot)
	# Draw arms for each opening direction
	for d in openings:
		var arm = ColorRect.new()
		var half = sz * 0.5
		match d:
			0:  # up
				arm.size = Vector2(6, half)
				arm.position = Vector2(center.x - 3, center.y - half)
			1:  # right
				arm.size = Vector2(half, 6)
				arm.position = Vector2(center.x, center.y - 3)
			2:  # down
				arm.size = Vector2(6, half)
				arm.position = Vector2(center.x - 3, center.y)
			3:  # left
				arm.size = Vector2(half, 6)
				arm.position = Vector2(center.x - half, center.y - 3)
		arm.color = Color(0.5, 0.55, 0.6)
		if pipe_type == PipeType.RESERVOIR:
			arm.color = Color(0.6, 0.5, 0.2)
		parent.add_child(arm)

func _draw_grid() -> void:
	# Remove old grid visuals
	for child in get_children():
		if child.is_in_group("grid_visual"):
			child.queue_free()

	# Draw grid cells
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var pos = GRID_OFFSET + Vector2(c * CELL_SIZE, r * CELL_SIZE)
			var cell = ColorRect.new()
			cell.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			cell.position = pos + Vector2(1, 1)
			cell.add_to_group("grid_visual")

			# Check if obstacle
			var is_obstacle = false
			for obs in obstacles:
				if obs.row == r and obs.col == c:
					is_obstacle = true
					break

			if is_obstacle:
				cell.color = Color(0.25, 0.2, 0.15)
			elif grid[r][c].pipe >= 0:
				cell.color = Color(0.12, 0.15, 0.18)
			else:
				cell.color = Color(0.08, 0.1, 0.12)
			add_child(cell)

			# Draw placed pipe
			if grid[r][c].pipe >= 0:
				var pipe_node = Node2D.new()
				pipe_node.add_to_group("grid_visual")
				add_child(pipe_node)
				var center = pos + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
				_draw_pipe_icon(pipe_node, center, grid[r][c].pipe, grid[r][c].rotation, CELL_SIZE * 0.8)

			# Draw fluid fill
			if fluid_grid[r][c] >= 0:
				var fluid_rect = ColorRect.new()
				fluid_rect.size = Vector2(CELL_SIZE * 0.6, CELL_SIZE * 0.6)
				fluid_rect.position = pos + Vector2(CELL_SIZE * 0.2, CELL_SIZE * 0.2)
				fluid_rect.color = fluid_colors[fluid_grid[r][c]]
				fluid_rect.color.a = 0.6
				fluid_rect.add_to_group("grid_visual")
				add_child(fluid_rect)

	# Draw sources
	for s in sources:
		var pos = GRID_OFFSET + Vector2(s.col * CELL_SIZE, s.row * CELL_SIZE)
		var src_rect = ColorRect.new()
		src_rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		src_rect.position = pos + Vector2(1, 1)
		src_rect.color = fluid_colors[s.color] * 0.7
		src_rect.add_to_group("grid_visual")
		add_child(src_rect)
		var src_lbl = Label.new()
		src_lbl.text = "S"
		src_lbl.add_theme_font_size_override("font_size", 24)
		src_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		src_lbl.position = pos + Vector2(22, 16)
		src_lbl.add_to_group("grid_visual")
		add_child(src_lbl)

	# Draw drains
	for d in drains:
		var pos = GRID_OFFSET + Vector2(d.col * CELL_SIZE, d.row * CELL_SIZE)
		var drn_rect = ColorRect.new()
		drn_rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		drn_rect.position = pos + Vector2(1, 1)
		drn_rect.color = fluid_colors[d.color] * 0.4
		drn_rect.add_to_group("grid_visual")
		add_child(drn_rect)
		var drn_lbl = Label.new()
		drn_lbl.text = "D"
		drn_lbl.add_theme_font_size_override("font_size", 24)
		drn_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		drn_lbl.position = pos + Vector2(22, 16)
		drn_lbl.add_to_group("grid_visual")
		add_child(drn_lbl)

	# Draw obstacles
	for obs in obstacles:
		var pos = GRID_OFFSET + Vector2(obs.col * CELL_SIZE, obs.row * CELL_SIZE)
		var obs_lbl = Label.new()
		obs_lbl.text = "X"
		obs_lbl.add_theme_font_size_override("font_size", 20)
		obs_lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.3))
		obs_lbl.position = pos + Vector2(24, 18)
		obs_lbl.add_to_group("grid_visual")
		add_child(obs_lbl)

func _update_countdown_display() -> void:
	if flowing:
		countdown_label.text = "FLOWING..."
		countdown_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		countdown_label.text = "Timer: " + str(int(countdown)) + "s"
		if countdown < 10:
			countdown_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		else:
			countdown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

func _process(delta: float) -> void:
	if game_over:
		return

	if not flowing:
		countdown -= delta
		if countdown <= 0:
			countdown = 0
			_start_flow()
		_update_countdown_display()
	else:
		flow_timer += delta
		if flow_timer >= 0.3:
			flow_timer = 0.0
			_advance_flow()

func _input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rotate_selection()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_rotate_selection()
		elif event.keycode == KEY_SPACE and not flowing:
			_start_flow()

func _rotate_selection() -> void:
	if flowing:
		return
	selected_rotation = (selected_rotation + 1) % 4
	rotation_label.text = "Rotation: " + str(selected_rotation * 90) + " deg (R to rotate)"
	_draw_queue()

func _handle_click(pos: Vector2) -> void:
	if flowing or queue_index >= pipe_queue.size():
		return

	# Convert click to grid coordinates
	var grid_pos = pos - GRID_OFFSET
	var col = int(grid_pos.x / CELL_SIZE)
	var row = int(grid_pos.y / CELL_SIZE)

	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		return

	# Check if cell is occupied by source, drain, obstacle, or existing pipe
	for s in sources:
		if s.row == row and s.col == col:
			return
	for d in drains:
		if d.row == row and d.col == col:
			return
	for obs in obstacles:
		if obs.row == row and obs.col == col:
			return
	if grid[row][col].pipe >= 0:
		return

	# Place pipe
	grid[row][col].pipe = pipe_queue[queue_index]
	grid[row][col].rotation = selected_rotation
	queue_index += 1
	_draw_grid()
	_draw_queue()

func _start_flow() -> void:
	flowing = true
	flow_timer = 0.0
	_update_countdown_display()
	status_label.text = "Fluid is flowing!"
	# Initialize flow from each source
	flow_path = []
	for s in sources:
		flow_path.append({"row": s.row, "col": s.col, "color": s.color, "from_dir": -1, "next_dir": s.dir})
		fluid_grid[s.row][s.col] = s.color
	_draw_grid()

func _advance_flow() -> void:
	var new_fronts: Array = []
	var any_advanced = false

	for front in flow_path:
		var next_dir: int = front.next_dir
		var dr = [-1, 0, 1, 0]
		var dc = [0, 1, 0, -1]
		var nr: int = front.row + dr[next_dir]
		var nc: int = front.col + dc[next_dir]

		# Check if we reached a drain
		for d in drains:
			if d.row == nr and d.col == nc and d.color == front.color:
				fluid_grid[nr][nc] = front.color
				_check_win()
				_draw_grid()
				return

		# Check bounds
		if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLS:
			_trigger_failure("Fluid overflowed off the grid!")
			return

		# Check if there's a pipe at the destination
		if grid[nr][nc].pipe < 0:
			# Check if it's another source (skip)
			var is_source = false
			for s in sources:
				if s.row == nr and s.col == nc:
					is_source = true
					break
			if not is_source:
				_trigger_failure("Fluid hit a dead end at (" + str(nr) + "," + str(nc) + ")!")
				return
			continue

		# Check pipe accepts flow from this direction
		var incoming_dir = (next_dir + 2) % 4  # opposite direction
		var pipe_openings = _get_pipe_openings(grid[nr][nc].pipe, grid[nr][nc].rotation)
		if not (incoming_dir in pipe_openings):
			_trigger_failure("Pipe at (" + str(nr) + "," + str(nc) + ") doesn't connect!")
			return

		# Check color contamination
		if fluid_grid[nr][nc] >= 0 and fluid_grid[nr][nc] != front.color:
			_trigger_failure("Color contamination! Fluids mixed!")
			return

		# Flow into this cell
		fluid_grid[nr][nc] = front.color
		any_advanced = true

		# Find next direction (exit through another opening)
		for opening in pipe_openings:
			if opening != incoming_dir:
				new_fronts.append({"row": nr, "col": nc, "color": front.color, "from_dir": incoming_dir, "next_dir": opening})
				break  # Take first available exit

	if any_advanced:
		flow_path = new_fronts
		_draw_grid()
	elif flow_path.size() == 0:
		_trigger_failure("Flow stopped - no path!")

func _check_win() -> void:
	# Check if all drains are filled
	for d in drains:
		if fluid_grid[d.row][d.col] != d.color:
			return
	# All drains reached!
	game_over = true
	game_won = true
	status_label.text = "LEVEL COMPLETE!"
	status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_show_end_buttons()

func _trigger_failure(reason: String) -> void:
	game_over = true
	game_won = false
	status_label.text = "OVERFLOW! " + reason
	status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_show_end_buttons()

func _show_end_buttons() -> void:
	var retry_btn = Button.new()
	retry_btn.text = "RETRY"
	retry_btn.position = Vector2(480, 660)
	retry_btn.custom_minimum_size = Vector2(140, 40)
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.pressed.connect(_on_retry)
	add_child(retry_btn)

	var next_btn = Button.new()
	if game_won and level_index < 2:
		next_btn.text = "NEXT LEVEL"
	else:
		next_btn.text = "MENU"
	next_btn.position = Vector2(660, 660)
	next_btn.custom_minimum_size = Vector2(140, 40)
	next_btn.add_theme_font_size_override("font_size", 20)
	next_btn.pressed.connect(_on_next)
	add_child(next_btn)

func _on_retry() -> void:
	main._enter_game(level_index)

func _on_next() -> void:
	if game_won and level_index < 2:
		main._enter_game(level_index + 1)
	else:
		main._enter_title()
