extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL = Color(0.15, 0.12, 0.22)
const COLOR_GOLD = Color(0.95, 0.80, 0.20)
const COLOR_ACCENT = Color(0.70, 0.55, 0.90)
const COLOR_CELL = Color(0.20, 0.17, 0.28)
const COLOR_CELL_HIGHLIGHT = Color(0.30, 0.25, 0.40)
const COLOR_RED = Color(0.90, 0.25, 0.25)
const COLOR_GREEN = Color(0.25, 0.85, 0.35)

const GRID_COLS = 3
const GRID_ROWS = 3
const CELL_SIZE = 120
const GRID_OFFSET = Vector2(430, 120)
const CELL_GAP = 10

# Symbol definitions: {name: [emoji, base_value, color]}
const SYMBOLS = {
	"cherry": ["C", 3, Color(0.90, 0.15, 0.20)],
	"coin": ["$", 2, Color(0.95, 0.80, 0.20)],
	"gem": ["G", 5, Color(0.20, 0.60, 0.95)],
	"cat": ["@", 0, Color(0.85, 0.65, 0.30)],
	"milk": ["M", 1, Color(0.95, 0.95, 0.95)],
	"ore": ["O", 2, Color(0.50, 0.50, 0.55)],
	"furnace": ["F", 0, Color(0.95, 0.40, 0.10)],
	"thief": ["T", -1, Color(0.30, 0.30, 0.35)],
	"diamond": ["D", 8, Color(0.70, 0.90, 1.0)],
	"clover": ["L", 4, Color(0.20, 0.80, 0.30)],
	"bomb": ["B", -2, Color(0.20, 0.20, 0.20)],
	"crown": ["K", 10, Color(1.0, 0.85, 0.0)]
}

var grid: Array = []  # 3x3 array of symbol names
var cell_labels: Array = []
var spinning: bool = false
var spin_timer: float = 0.0
var spin_duration: float = 1.2
var spin_ticks: int = 0
var turn_earnings: int = 0

var gold_label: Label = null
var rent_label: Label = null
var round_label: Label = null
var earnings_label: Label = null
var info_label: Label = null
var spin_btn: Button = null

func _ready() -> void:
	_draw_bg()
	_draw_hud()
	_draw_grid()
	_init_grid()
	_update_hud()

func _draw_bg() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

func _draw_hud() -> void:
	gold_label = Label.new()
	gold_label.position = Vector2(50, 20)
	gold_label.size = Vector2(300, 40)
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	add_child(gold_label)

	rent_label = Label.new()
	rent_label.position = Vector2(50, 60)
	rent_label.size = Vector2(300, 40)
	rent_label.add_theme_font_size_override("font_size", 24)
	rent_label.add_theme_color_override("font_color", COLOR_RED)
	add_child(rent_label)

	round_label = Label.new()
	round_label.position = Vector2(50, 100)
	round_label.size = Vector2(300, 40)
	round_label.add_theme_font_size_override("font_size", 22)
	round_label.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(round_label)

	earnings_label = Label.new()
	earnings_label.position = Vector2(430, 530)
	earnings_label.size = Vector2(420, 50)
	earnings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	earnings_label.add_theme_font_size_override("font_size", 30)
	earnings_label.add_theme_color_override("font_color", COLOR_GREEN)
	add_child(earnings_label)

	info_label = Label.new()
	info_label.position = Vector2(50, 550)
	info_label.size = Vector2(350, 150)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.text = "SPACE to spin\nPay rent every 3 spins\nBuild synergies!"
	add_child(info_label)

	spin_btn = _make_button("SPIN [SPACE]", Vector2(490, 600))
	spin_btn.pressed.connect(_on_spin)
	add_child(spin_btn)

func _draw_grid() -> void:
	# Grid background panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = GRID_OFFSET - Vector2(15, 15)
	panel.size = Vector2(GRID_COLS * (CELL_SIZE + CELL_GAP) + 20, GRID_ROWS * (CELL_SIZE + CELL_GAP) + 20)
	add_child(panel)

	cell_labels = []
	for row in range(GRID_ROWS):
		var row_labels = []
		for col in range(GRID_COLS):
			var x = GRID_OFFSET.x + col * (CELL_SIZE + CELL_GAP)
			var y = GRID_OFFSET.y + row * (CELL_SIZE + CELL_GAP)
			var cell_bg = ColorRect.new()
			cell_bg.color = COLOR_CELL
			cell_bg.position = Vector2(x, y)
			cell_bg.size = Vector2(CELL_SIZE, CELL_SIZE)
			add_child(cell_bg)

			var lbl = Label.new()
			lbl.position = Vector2(x, y)
			lbl.size = Vector2(CELL_SIZE, CELL_SIZE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 52)
			add_child(lbl)
			row_labels.append(lbl)
		cell_labels.append(row_labels)

func _init_grid() -> void:
	grid = []
	for row in range(GRID_ROWS):
		var row_data = []
		for col in range(GRID_COLS):
			var idx = main.rng.randi_range(0, main.symbol_pool.size() - 1)
			row_data.append(main.symbol_pool[idx])
		grid.append(row_data)
	_update_grid_display()

func _update_grid_display() -> void:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var sym_name = grid[row][col]
			var sym_data = SYMBOLS[sym_name]
			cell_labels[row][col].text = sym_data[0]
			cell_labels[row][col].add_theme_color_override("font_color", sym_data[2])

func _update_hud() -> void:
	gold_label.text = "Gold: " + str(main.gold)
	rent_label.text = "Rent: " + str(main.rent) + " (due in " + str(3 - main.spins_this_cycle) + " spins)"
	round_label.text = "Round: " + str(main.round_num)

func _on_spin() -> void:
	if spinning:
		return
	spinning = true
	spin_timer = 0.0
	spin_ticks = 0
	turn_earnings = 0
	earnings_label.text = ""
	spin_btn.disabled = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_on_spin()

func _process(delta: float) -> void:
	if not spinning:
		return
	spin_timer += delta
	# Animate: shuffle symbols rapidly
	var tick_interval = 0.08
	var elapsed_ticks = int(spin_timer / tick_interval)
	if elapsed_ticks > spin_ticks:
		spin_ticks = elapsed_ticks
		_randomize_grid_visual()
	if spin_timer >= spin_duration:
		spinning = false
		_finalize_spin()

func _randomize_grid_visual() -> void:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx = main.rng.randi_range(0, main.symbol_pool.size() - 1)
			var sym_name = main.symbol_pool[idx]
			var sym_data = SYMBOLS[sym_name]
			cell_labels[row][col].text = sym_data[0]
			cell_labels[row][col].add_theme_color_override("font_color", sym_data[2])

func _finalize_spin() -> void:
	# Set final grid from pool
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx = main.rng.randi_range(0, main.symbol_pool.size() - 1)
			grid[row][col] = main.symbol_pool[idx]
	_update_grid_display()
	# Calculate earnings
	turn_earnings = _calculate_earnings()
	main.gold += turn_earnings
	earnings_label.text = "+" + str(turn_earnings) + " gold!"
	if turn_earnings <= 0:
		earnings_label.add_theme_color_override("font_color", COLOR_RED)
		earnings_label.text = str(turn_earnings) + " gold"
	else:
		earnings_label.add_theme_color_override("font_color", COLOR_GREEN)
	main.spins_this_cycle += 1
	_update_hud()
	spin_btn.disabled = false
	# Check rent
	if main.spins_this_cycle >= 3:
		_pay_rent()

func _calculate_earnings() -> int:
	var total = 0
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var sym = grid[row][col]
			var base = SYMBOLS[sym][1]
			var bonus = _get_adjacency_bonus(row, col, sym)
			total += base + bonus
	return total

func _get_adjacency_bonus(row: int, col: int, sym: String) -> int:
	var bonus = 0
	var neighbors = _get_neighbors(row, col)
	match sym:
		"cherry":
			# Cherry next to cherry = x2 base
			for n in neighbors:
				if grid[n[0]][n[1]] == "cherry":
					bonus += 3
		"cat":
			# Cat multiplies adjacent milk by 3
			for n in neighbors:
				if grid[n[0]][n[1]] == "milk":
					bonus += 3
		"ore":
			# Ore next to furnace = +5
			for n in neighbors:
				if grid[n[0]][n[1]] == "furnace":
					bonus += 5
		"furnace":
			# Furnace next to ore = +5
			for n in neighbors:
				if grid[n[0]][n[1]] == "ore":
					bonus += 5
		"thief":
			# Thief steals 2 from each neighbor
			for n in neighbors:
				if grid[n[0]][n[1]] != "thief" and grid[n[0]][n[1]] != "bomb":
					bonus -= 2
		"gem":
			# Gem next to gem = +4
			for n in neighbors:
				if grid[n[0]][n[1]] == "gem":
					bonus += 4
		"clover":
			# Clover boosts all adjacent by +2
			bonus += neighbors.size() * 2
		"diamond":
			# Diamond next to crown = +15
			for n in neighbors:
				if grid[n[0]][n[1]] == "crown":
					bonus += 15
		"crown":
			# Crown next to diamond = +15
			for n in neighbors:
				if grid[n[0]][n[1]] == "diamond":
					bonus += 15
		"bomb":
			# Bomb destroys value of neighbors
			for n in neighbors:
				bonus -= SYMBOLS[grid[n[0]][n[1]]][1]
		"coin":
			# Coin next to coin = +2
			for n in neighbors:
				if grid[n[0]][n[1]] == "coin":
					bonus += 2
	return bonus

func _get_neighbors(row: int, col: int) -> Array:
	var result = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var nr = row + dr
			var nc = col + dc
			if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLS:
				result.append([nr, nc])
	return result

func _pay_rent() -> void:
	main.spins_this_cycle = 0
	if main.gold < main.rent:
		# Game over
		main._enter_game_over()
		return
	main.gold -= main.rent
	main.round_num += 1
	main.rent = 15 + (main.round_num - 1) * 8
	_update_hud()
	# Go to shop between rounds
	main._enter_shop()

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	b.add_theme_font_size_override("font_size", 24)
	return b
