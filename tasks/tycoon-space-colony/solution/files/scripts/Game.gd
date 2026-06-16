extends Node2D

const GRID_SIZE: int = 8
const CELL_PX: int = 60
const GRID_OFFSET: Vector2 = Vector2(40, 100)

enum ModuleType { NONE, HABITAT, FARM, SOLAR, RECYCLER, MINE }

var module_names: Array = ["Empty", "Habitat", "Farm", "Solar Panel", "O2 Recycler", "Mine"]
var module_colors: Array = [
	Color(0.15, 0.15, 0.2), Color(0.2, 0.5, 0.8), Color(0.1, 0.7, 0.2),
	Color(0.9, 0.8, 0.1), Color(0.3, 0.7, 0.9), Color(0.6, 0.4, 0.2)
]

var grid: Array = []
var oxygen: float = 100.0
var food: float = 100.0
var power: float = 100.0
var materials: float = 50.0
var colonists: int = 10
var cycle: int = 0
var selected_module: int = ModuleType.HABITAT
var game_over: bool = false
var scenario: String = ""

var bg: ColorRect
var hud_label: Label
var cycle_label: Label
var event_label: Label
var build_buttons: Array = []
var advance_btn: Button
var grid_rects: Array = []

func _ready() -> void:
	scenario = get_meta("scenario") if has_meta("scenario") else ""
	_init_grid()
	_build_ui()
	if scenario == "crisis":
		oxygen = 30.0
		food = 20.0
		power = 40.0
		colonists = 20
		cycle = 5
	_update_hud()

func _init_grid() -> void:
	grid.resize(GRID_SIZE * GRID_SIZE)
	for i in range(grid.size()):
		grid[i] = ModuleType.NONE

func _build_ui() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.1)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	hud_label = Label.new()
	hud_label.position = Vector2(40, 10)
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	add_child(hud_label)

	cycle_label = Label.new()
	cycle_label.position = Vector2(40, 50)
	cycle_label.add_theme_font_size_override("font_size", 18)
	cycle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(cycle_label)

	event_label = Label.new()
	event_label.position = Vector2(40, 640)
	event_label.add_theme_font_size_override("font_size", 14)
	event_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	add_child(event_label)

	_draw_grid()
	_build_panel()

func _draw_grid() -> void:
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var rect: ColorRect = ColorRect.new()
			rect.size = Vector2(CELL_PX - 2, CELL_PX - 2)
			rect.position = GRID_OFFSET + Vector2(col * CELL_PX, row * CELL_PX)
			rect.color = module_colors[0]
			add_child(rect)
			grid_rects.append(rect)
			var btn: Button = Button.new()
			btn.position = rect.position
			btn.custom_minimum_size = Vector2(CELL_PX - 2, CELL_PX - 2)
			btn.size = Vector2(CELL_PX - 2, CELL_PX - 2)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.flat = true
			btn.modulate = Color(1, 1, 1, 0.01)
			var idx: int = row * GRID_SIZE + col
			btn.pressed.connect(_on_cell_pressed.bind(idx))
			add_child(btn)

func _build_panel() -> void:
	var panel_x: float = 560.0
	var label: Label = Label.new()
	label.text = "BUILD MODULE:"
	label.position = Vector2(panel_x, 100)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(label)

	for i in range(1, ModuleType.size()):
		var b: Button = Button.new()
		b.text = module_names[i]
		b.position = Vector2(panel_x, 130 + (i - 1) * 50)
		b.custom_minimum_size = Vector2(180, 40)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var st: StyleBoxFlat = StyleBoxFlat.new()
		var mc: Color = module_colors[i]
		st.bg_color = mc.darkened(0.3)
		st.border_color = mc
		st.set_border_width_all(2)
		st.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_color_override("font_color", Color(1, 1, 1))
		b.pressed.connect(_on_select_module.bind(i))
		add_child(b)
		build_buttons.append(b)

	advance_btn = Button.new()
	advance_btn.text = "ADVANCE CYCLE"
	advance_btn.position = Vector2(panel_x, 420)
	advance_btn.custom_minimum_size = Vector2(200, 50)
	advance_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var adv_style: StyleBoxFlat = StyleBoxFlat.new()
	adv_style.bg_color = Color(0.1, 0.3, 0.5)
	adv_style.border_color = Color(0.0, 0.8, 1.0)
	adv_style.set_border_width_all(2)
	adv_style.set_corner_radius_all(6)
	advance_btn.add_theme_stylebox_override("normal", adv_style)
	advance_btn.add_theme_font_size_override("font_size", 18)
	advance_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	advance_btn.pressed.connect(_on_advance)
	add_child(advance_btn)

	var cost_label: Label = Label.new()
	cost_label.text = "Costs: Habitat=10mat, Farm=8mat, Solar=12mat\nRecycler=15mat, Mine=10mat"
	cost_label.position = Vector2(panel_x, 500)
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	add_child(cost_label)

func _get_module_cost(m: int) -> float:
	match m:
		ModuleType.HABITAT: return 10.0
		ModuleType.FARM: return 8.0
		ModuleType.SOLAR: return 12.0
		ModuleType.RECYCLER: return 15.0
		ModuleType.MINE: return 10.0
	return 0.0

func _on_select_module(m: int) -> void:
	selected_module = m

func _on_cell_pressed(idx: int) -> void:
	if game_over:
		return
	if grid[idx] != ModuleType.NONE:
		return
	var cost: float = _get_module_cost(selected_module)
	if materials < cost:
		event_label.text = "Not enough materials!"
		return
	materials -= cost
	grid[idx] = selected_module
	grid_rects[idx].color = module_colors[selected_module]
	event_label.text = "Built " + module_names[selected_module]
	_update_hud()

func _on_advance() -> void:
	if game_over:
		return
	cycle += 1
	_process_cycle()
	_check_meteor()
	_check_game_over()
	_update_hud()

func _process_cycle() -> void:
	var habitats: int = 0
	var farms: int = 0
	var solars: int = 0
	var recyclers: int = 0
	var mines: int = 0
	for i in range(grid.size()):
		match grid[i]:
			ModuleType.HABITAT: habitats += 1
			ModuleType.FARM: farms += 1
			ModuleType.SOLAR: solars += 1
			ModuleType.RECYCLER: recyclers += 1
			ModuleType.MINE: mines += 1
	power += solars * 5.0 - colonists * 1.0
	oxygen += recyclers * 8.0 - colonists * 2.0
	food += farms * 6.0 - colonists * 1.5
	materials += mines * 4.0
	var capacity: int = habitats * 5
	if colonists < capacity and food > 20 and oxygen > 20:
		colonists += 1

func _check_meteor() -> void:
	var rng: float = randf()
	if rng < 0.15:
		var occupied: Array = []
		for i in range(grid.size()):
			if grid[i] != ModuleType.NONE:
				occupied.append(i)
		if occupied.size() > 0:
			var target: int = occupied[randi() % occupied.size()]
			var mod_idx: int = grid[target]
			var destroyed_name: String = module_names[mod_idx]
			grid[target] = ModuleType.NONE
			grid_rects[target].color = module_colors[0]
			event_label.text = "METEOR! Destroyed " + destroyed_name
			return
	event_label.text = "Cycle " + str(cycle) + " complete."

func _check_game_over() -> void:
	if oxygen <= 0 or food <= 0 or power <= -20:
		game_over = true
		_go_result("Colony collapsed at cycle " + str(cycle))
	elif cycle >= 20:
		game_over = true
		_go_result("Colony survived 20 cycles! Pop: " + str(colonists))

func _go_result(msg: String) -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	main_node.set_meta("result_msg", msg)
	main_node.set_meta("result_cycle", cycle)
	main_node.set_meta("result_pop", colonists)
	main_node.go_to("Result")

func _update_hud() -> void:
	hud_label.text = "O2: %.0f  Food: %.0f  Power: %.0f  Materials: %.0f  Colonists: %d" % [oxygen, food, power, materials, colonists]
	cycle_label.text = "Cycle: %d / 20  |  Selected: %s" % [cycle, module_names[selected_module]]
