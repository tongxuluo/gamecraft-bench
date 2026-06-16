extends Node2D

var main: Node = null

const GRID_SIZE = 7
const CELL_SIZE = 70
const GRID_OFFSET = Vector2(200, 80)

const COLOR_BG = Color(0.06, 0.08, 0.10)
const COLOR_CELL = Color(0.14, 0.16, 0.20)
const COLOR_CELL_VISITED = Color(0.10, 0.12, 0.15)
const COLOR_PLAYER = Color(0.40, 0.85, 0.50)
const COLOR_INGREDIENT = Color(0.80, 0.70, 0.30)
const COLOR_EXIT = Color(0.90, 0.40, 0.40)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)
const COLOR_TEXT = Color(0.90, 0.88, 0.82)

const ALL_INGREDIENTS = [
	"Moonpetal", "Redcap", "Crystalwort", "Flameleaf",
	"Icemoss", "Shadowroot", "Sunbloom", "Ironite",
	"Dewdrop", "Thornberry", "Glowcap", "Ashite"
]

const INGREDIENT_ICONS = {
	"Moonpetal": "M", "Redcap": "R", "Crystalwort": "C",
	"Flameleaf": "F", "Icemoss": "I", "Shadowroot": "S",
	"Sunbloom": "B", "Ironite": "N", "Dewdrop": "D",
	"Thornberry": "T", "Glowcap": "G", "Ashite": "A"
}

var player_pos = Vector2i(3, 3)
var grid_data: Array = []  # 2D array: null or ingredient name
var visited: Array = []
var gather_count: int = 0
var max_gather: int = 6
var exit_pos = Vector2i(6, 6)
var floor_label: Label = null
var inv_label: Label = null
var info_label: Label = null

func _ready() -> void:
	_generate_map()
	_build_ui()

func _generate_map() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = main.current_floor * 42
	grid_data = []
	visited = []
	var ingredient_count = 4 + main.current_floor * 2
	for y in range(GRID_SIZE):
		var row = []
		var vrow = []
		for x in range(GRID_SIZE):
			row.append(null)
			vrow.append(false)
		grid_data.append(row)
		visited.append(vrow)

	# Place ingredients randomly
	var placed = 0
	while placed < ingredient_count:
		var rx = rng.randi_range(0, GRID_SIZE - 1)
		var ry = rng.randi_range(0, GRID_SIZE - 1)
		if Vector2i(rx, ry) == player_pos or Vector2i(rx, ry) == exit_pos:
			continue
		if grid_data[ry][rx] != null:
			continue
		var ing_idx = rng.randi_range(0, ALL_INGREDIENTS.size() - 1)
		grid_data[ry][rx] = ALL_INGREDIENTS[ing_idx]
		placed += 1

	visited[player_pos.y][player_pos.x] = true
	max_gather = 4 + main.current_floor * 2

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Draw grid
	_draw_grid()

	# Side panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(720, 0)
	panel.size = Vector2(560, 720)
	add_child(panel)

	floor_label = Label.new()
	floor_label.text = "Floor " + str(main.current_floor) + " / 3"
	floor_label.position = Vector2(740, 20)
	floor_label.size = Vector2(520, 40)
	floor_label.add_theme_color_override("font_color", COLOR_TEXT)
	floor_label.add_theme_font_size_override("font_size", 28)
	add_child(floor_label)

	inv_label = Label.new()
	inv_label.text = _get_inv_text()
	inv_label.position = Vector2(740, 80)
	inv_label.size = Vector2(520, 300)
	inv_label.add_theme_color_override("font_color", COLOR_TEXT)
	inv_label.add_theme_font_size_override("font_size", 18)
	add_child(inv_label)

	info_label = Label.new()
	info_label.text = "Arrow keys: move\nGather ingredients by stepping on them\nReach the red EXIT to proceed"
	info_label.position = Vector2(740, 400)
	info_label.size = Vector2(520, 200)
	info_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.60))
	info_label.add_theme_font_size_override("font_size", 16)
	add_child(info_label)

	# Brew button
	var brew_btn = Button.new()
	brew_btn.text = "OPEN CAULDRON"
	brew_btn.position = Vector2(780, 620)
	brew_btn.size = Vector2(220, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.15, 0.30)
	sb.border_color = Color(0.55, 0.40, 0.70)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	brew_btn.add_theme_stylebox_override("normal", sb)
	brew_btn.add_theme_stylebox_override("hover", sb)
	brew_btn.add_theme_stylebox_override("pressed", sb)
	brew_btn.add_theme_color_override("font_color", COLOR_TEXT)
	brew_btn.add_theme_font_size_override("font_size", 20)
	brew_btn.pressed.connect(func(): main._enter_brew())
	add_child(brew_btn)

var grid_container: Node2D = null

func _draw_grid() -> void:
	if grid_container != null:
		grid_container.queue_free()
	grid_container = Node2D.new()
	add_child(grid_container)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var pos = GRID_OFFSET + Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var cell = ColorRect.new()
			if visited[y][x]:
				cell.color = COLOR_CELL_VISITED
			else:
				cell.color = COLOR_CELL
			cell.position = pos
			cell.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			grid_container.add_child(cell)

			# Ingredient icon
			if grid_data[y][x] != null:
				var icon = Label.new()
				var ing_name = grid_data[y][x]
				icon.text = INGREDIENT_ICONS.get(ing_name, "?")
				icon.position = pos + Vector2(10, 5)
				icon.size = Vector2(CELL_SIZE - 14, CELL_SIZE - 14)
				icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				icon.add_theme_color_override("font_color", COLOR_INGREDIENT)
				icon.add_theme_font_size_override("font_size", 28)
				grid_container.add_child(icon)

			# Exit marker
			if Vector2i(x, y) == exit_pos:
				var ex = Label.new()
				ex.text = "X"
				ex.position = pos + Vector2(10, 5)
				ex.size = Vector2(CELL_SIZE - 14, CELL_SIZE - 14)
				ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ex.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ex.add_theme_color_override("font_color", COLOR_EXIT)
				ex.add_theme_font_size_override("font_size", 32)
				grid_container.add_child(ex)

	# Player
	var pp = GRID_OFFSET + Vector2(player_pos.x * CELL_SIZE, player_pos.y * CELL_SIZE)
	var player_rect = ColorRect.new()
	player_rect.color = COLOR_PLAYER
	player_rect.position = pp + Vector2(15, 15)
	player_rect.size = Vector2(CELL_SIZE - 34, CELL_SIZE - 34)
	grid_container.add_child(player_rect)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var dir = Vector2i.ZERO
		if event.keycode == KEY_UP:
			dir = Vector2i(0, -1)
		elif event.keycode == KEY_DOWN:
			dir = Vector2i(0, 1)
		elif event.keycode == KEY_LEFT:
			dir = Vector2i(-1, 0)
		elif event.keycode == KEY_RIGHT:
			dir = Vector2i(1, 0)

		if dir != Vector2i.ZERO:
			var new_pos = player_pos + dir
			if new_pos.x >= 0 and new_pos.x < GRID_SIZE and new_pos.y >= 0 and new_pos.y < GRID_SIZE:
				player_pos = new_pos
				visited[player_pos.y][player_pos.x] = true
				_check_gather()
				_check_exit()
				_draw_grid()
				if inv_label:
					inv_label.text = _get_inv_text()

func _check_gather() -> void:
	var ing = grid_data[player_pos.y][player_pos.x]
	if ing != null:
		main.inventory.append(ing)
		grid_data[player_pos.y][player_pos.x] = null
		gather_count += 1

func _check_exit() -> void:
	if player_pos == exit_pos:
		main._enter_shop()

func _get_inv_text() -> String:
	var text = "Inventory:\n"
	if main.inventory.size() == 0:
		text += "  (empty)\n"
	else:
		var counts = {}
		for ing in main.inventory:
			if counts.has(ing):
				counts[ing] += 1
			else:
				counts[ing] = 1
		for k in counts.keys():
			text += "  " + k + " x" + str(counts[k]) + "\n"
	text += "\nPotions:\n"
	if main.potions.size() == 0:
		text += "  (none brewed)\n"
	else:
		for p in main.potions:
			text += "  " + p + "\n"
	text += "\nGold: " + str(main.gold)
	text += "\nReputation: " + str(main.reputation) + "/" + str(main.max_reputation)
	return text
