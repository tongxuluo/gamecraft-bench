extends Node2D

const GRID_SIZE: int = 8
const CELL_PX: int = 64
const GRID_OFFSET: Vector2 = Vector2(40, 80)
const BIOMES: Array = ["savanna", "arctic", "jungle", "aquatic"]
const BIOME_COLORS: Dictionary = {
	"savanna": Color(0.85, 0.7, 0.3),
	"arctic": Color(0.8, 0.9, 1.0),
	"jungle": Color(0.2, 0.6, 0.15),
	"aquatic": Color(0.2, 0.5, 0.85),
}

var animals_catalog: Array = [
	{"name": "Lion", "biome": "savanna", "popularity": 5, "cost": 80},
	{"name": "Penguin", "biome": "arctic", "popularity": 4, "cost": 60},
	{"name": "Parrot", "biome": "jungle", "popularity": 3, "cost": 40},
	{"name": "Dolphin", "biome": "aquatic", "popularity": 6, "cost": 100},
	{"name": "Elephant", "biome": "savanna", "popularity": 7, "cost": 120},
	{"name": "Polar Bear", "biome": "arctic", "popularity": 5, "cost": 90},
	{"name": "Monkey", "biome": "jungle", "popularity": 4, "cost": 50},
	{"name": "Seal", "biome": "aquatic", "popularity": 3, "cost": 45},
]

var gold: int = 500
var visitors: int = 0
var day: int = 1
var max_days: int = 30
var grid: Array = []  # 2D array of biome strings or ""
var placed_animals: Array = []  # {name, grid_x, grid_y, biome, popularity}
var selected_biome: int = 0
var mode: String = "build"  # build or animal

var hud_label: Label
var catalog_panel: ColorRect
var grid_node: Node2D
var scenario: String = ""

func _ready() -> void:
	scenario = get_meta("scenario") as String
	_init_grid()
	_build_ui()
	_draw_grid()
	if scenario == "building":
		_auto_build()
	elif scenario == "open":
		_auto_build()
		_auto_open()

func _init_grid() -> void:
	grid = []
	for x in range(GRID_SIZE):
		var col: Array = []
		for y in range(GRID_SIZE):
			col.append("")
		grid.append(col)

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.15, 0.35, 0.15)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	hud_label = Label.new()
	hud_label.position = Vector2(40, 10)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	add_child(hud_label)
	_update_hud()

	grid_node = Node2D.new()
	grid_node.position = GRID_OFFSET
	add_child(grid_node)

	# Right panel
	catalog_panel = ColorRect.new()
	catalog_panel.position = Vector2(620, 80)
	catalog_panel.size = Vector2(620, 600)
	catalog_panel.color = Color(0.12, 0.25, 0.12)
	add_child(catalog_panel)

	# Biome buttons
	var biome_label: Label = Label.new()
	biome_label.text = "Build Enclosure:"
	biome_label.position = Vector2(10, 10)
	biome_label.add_theme_font_size_override("font_size", 18)
	biome_label.add_theme_color_override("font_color", Color(1, 1, 1))
	catalog_panel.add_child(biome_label)

	for i in range(BIOMES.size()):
		var b_name: String = BIOMES[i]
		var btn: Button = Button.new()
		btn.text = b_name.capitalize() + " ($50)"
		btn.position = Vector2(10 + i * 150, 40)
		btn.custom_minimum_size = Vector2(140, 36)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = BIOME_COLORS[b_name]
		st.corner_radius_top_left = 4
		st.corner_radius_top_right = 4
		st.corner_radius_bottom_left = 4
		st.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", st)
		btn.pressed.connect(_on_biome_select.bind(i))
		catalog_panel.add_child(btn)

	# Animal catalog
	var anim_label: Label = Label.new()
	anim_label.text = "Acquire Animal:"
	anim_label.position = Vector2(10, 100)
	anim_label.add_theme_font_size_override("font_size", 18)
	anim_label.add_theme_color_override("font_color", Color(1, 1, 1))
	catalog_panel.add_child(anim_label)

	for i in range(animals_catalog.size()):
		var anim: Dictionary = animals_catalog[i]
		var btn: Button = Button.new()
		btn.text = "%s [%s] Pop:%d $%d" % [anim["name"], anim["biome"], anim["popularity"], anim["cost"]]
		btn.position = Vector2(10, 130 + i * 44)
		btn.custom_minimum_size = Vector2(580, 38)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = Color(0.25, 0.4, 0.25)
		st.corner_radius_top_left = 4
		st.corner_radius_top_right = 4
		st.corner_radius_bottom_left = 4
		st.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(_on_animal_buy.bind(i))
		catalog_panel.add_child(btn)

	# Next Day button
	var day_btn: Button = Button.new()
	day_btn.text = "NEXT DAY"
	day_btn.position = Vector2(10, 500)
	day_btn.custom_minimum_size = Vector2(200, 50)
	day_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var dst: StyleBoxFlat = StyleBoxFlat.new()
	dst.bg_color = Color(0.6, 0.35, 0.1)
	dst.corner_radius_top_left = 6
	dst.corner_radius_top_right = 6
	dst.corner_radius_bottom_left = 6
	dst.corner_radius_bottom_right = 6
	day_btn.add_theme_stylebox_override("normal", dst)
	day_btn.add_theme_font_size_override("font_size", 22)
	day_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	day_btn.pressed.connect(_on_next_day)
	catalog_panel.add_child(day_btn)

func _update_hud() -> void:
	hud_label.text = "Gold: %d  |  Visitors: %d  |  Day: %d / %d" % [gold, visitors, day, max_days]

func _draw_grid() -> void:
	for child in grid_node.get_children():
		child.queue_free()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell: ColorRect = ColorRect.new()
			cell.position = Vector2(x * CELL_PX, y * CELL_PX)
			cell.size = Vector2(CELL_PX - 2, CELL_PX - 2)
			var biome: String = grid[x][y]
			if biome != "":
				cell.color = BIOME_COLORS[biome]
			else:
				cell.color = Color(0.3, 0.5, 0.3)
			grid_node.add_child(cell)
	# Draw animals
	for anim in placed_animals:
		var lbl: Label = Label.new()
		lbl.text = anim["name"].substr(0, 2)
		lbl.position = Vector2(anim["grid_x"] * CELL_PX + 8, anim["grid_y"] * CELL_PX + 16)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		grid_node.add_child(lbl)

func _on_biome_select(idx: int) -> void:
	selected_biome = idx
	mode = "build"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mpos: Vector2 = event.position - GRID_OFFSET
		var gx: int = int(mpos.x) / CELL_PX
		var gy: int = int(mpos.y) / CELL_PX
		if gx >= 0 and gx < GRID_SIZE and gy >= 0 and gy < GRID_SIZE:
			if mode == "build":
				_place_enclosure(gx, gy)

func _place_enclosure(gx: int, gy: int) -> void:
	if gold < 50:
		return
	var biome_name: String = BIOMES[selected_biome]
	grid[gx][gy] = biome_name
	gold -= 50
	_update_hud()
	_draw_grid()

func _on_animal_buy(idx: int) -> void:
	var anim: Dictionary = animals_catalog[idx]
	var cost: int = anim["cost"] as int
	if gold < cost:
		return
	# Find matching enclosure cell without animal
	var target_x: int = -1
	var target_y: int = -1
	var req_biome: String = anim["biome"] as String
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid[x][y] == req_biome:
				var occupied: bool = false
				for pa in placed_animals:
					if pa["grid_x"] == x and pa["grid_y"] == y:
						occupied = true
						break
				if not occupied:
					target_x = x
					target_y = y
					break
		if target_x >= 0:
			break
	if target_x < 0:
		return
	gold -= cost
	placed_animals.append({
		"name": anim["name"],
		"biome": req_biome,
		"popularity": anim["popularity"],
		"grid_x": target_x,
		"grid_y": target_y,
	})
	_calc_visitors()
	_update_hud()
	_draw_grid()

func _calc_visitors() -> void:
	var total_pop: int = 0
	for anim in placed_animals:
		var pop: int = anim["popularity"] as int
		var gx: int = anim["grid_x"] as int
		var gy: int = anim["grid_y"] as int
		var cell_biome: String = grid[gx][gy]
		if cell_biome == anim["biome"]:
			total_pop += pop
		else:
			total_pop += pop / 2
	visitors = total_pop * 10

func _on_next_day() -> void:
	var revenue: int = visitors * 2
	gold += revenue
	day += 1
	if day > max_days:
		_end_game()
		return
	_update_hud()

func _end_game() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	main_node.set_meta("final_gold", gold)
	main_node.set_meta("final_visitors", visitors)
	main_node.set_meta("final_animals", placed_animals.size())
	main_node.set_meta("final_day", day - 1)
	main_node.go_to("Result")

func _auto_build() -> void:
	# Place some enclosures automatically
	grid[0][0] = "savanna"
	grid[1][0] = "savanna"
	grid[0][1] = "arctic"
	grid[2][0] = "jungle"
	grid[3][0] = "aquatic"
	gold -= 250
	# Add animals
	placed_animals.append({"name": "Lion", "biome": "savanna", "popularity": 5, "grid_x": 0, "grid_y": 0})
	placed_animals.append({"name": "Penguin", "biome": "arctic", "popularity": 4, "grid_x": 0, "grid_y": 1})
	placed_animals.append({"name": "Parrot", "biome": "jungle", "popularity": 3, "grid_x": 2, "grid_y": 0})
	gold -= 180
	_calc_visitors()
	_update_hud()
	_draw_grid()

func _auto_open() -> void:
	# Simulate a few days
	for i in range(5):
		var revenue: int = visitors * 2
		gold += revenue
		day += 1
	_update_hud()
