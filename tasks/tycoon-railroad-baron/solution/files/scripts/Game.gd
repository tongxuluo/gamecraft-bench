extends Node2D

var main_node: Node2D = null
var gold: int = 500
var month: int = 1
var max_months: int = 24

var cities: Array = []
var tracks: Array = []
var trains: Array = []
var selected_city: int = -1

var hud_gold: Label = null
var hud_month: Label = null
var hud_trains: Label = null
var status_label: Label = null
var map_node: Node2D = null

func _ready() -> void:
	main_node = get_meta("main") as Node2D
	_init_cities()
	_build_ui()
	var scenario: String = main_node.get("scenario") as String
	if scenario == "running":
		_setup_running_scenario()

func _init_cities() -> void:
	cities.append({"name": "New York", "pos": Vector2(900, 200)})
	cities.append({"name": "Chicago", "pos": Vector2(550, 180)})
	cities.append({"name": "Denver", "pos": Vector2(350, 280)})
	cities.append({"name": "Dallas", "pos": Vector2(550, 450)})
	cities.append({"name": "Atlanta", "pos": Vector2(750, 400)})
	cities.append({"name": "Seattle", "pos": Vector2(200, 120)})

func _build_ui() -> void:
	# Map background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.18, 0.22, 0.15)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Map area
	map_node = Node2D.new()
	add_child(map_node)
	_draw_cities()

	# HUD bar
	var hud_bg: ColorRect = ColorRect.new()
	hud_bg.color = Color(0.1, 0.08, 0.06, 0.9)
	hud_bg.size = Vector2(1280, 50)
	hud_bg.position = Vector2(0, 0)
	add_child(hud_bg)

	hud_gold = Label.new()
	hud_gold.text = "Gold: " + str(gold)
	hud_gold.position = Vector2(20, 12)
	hud_gold.add_theme_font_size_override("font_size", 20)
	hud_gold.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	add_child(hud_gold)

	hud_month = Label.new()
	hud_month.text = "Month: " + str(month) + "/" + str(max_months)
	hud_month.position = Vector2(200, 12)
	hud_month.add_theme_font_size_override("font_size", 20)
	hud_month.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(hud_month)

	hud_trains = Label.new()
	hud_trains.text = "Trains: " + str(trains.size())
	hud_trains.position = Vector2(420, 12)
	hud_trains.add_theme_font_size_override("font_size", 20)
	hud_trains.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(hud_trains)

	# Status
	status_label = Label.new()
	status_label.text = "Click a city to start building track"
	status_label.position = Vector2(20, 670)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	add_child(status_label)

	# Buttons panel
	var buy_btn: Button = Button.new()
	buy_btn.text = "Buy Train (100g)"
	buy_btn.position = Vector2(1050, 670)
	buy_btn.custom_minimum_size = Vector2(150, 40)
	buy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var bs: StyleBoxFlat = StyleBoxFlat.new()
	bs.bg_color = Color(0.3, 0.4, 0.5)
	buy_btn.add_theme_stylebox_override("normal", bs)
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	buy_btn.pressed.connect(_on_buy_train)
	add_child(buy_btn)

	var next_btn: Button = Button.new()
	next_btn.text = "Next Month"
	next_btn.position = Vector2(880, 670)
	next_btn.custom_minimum_size = Vector2(140, 40)
	next_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var ns: StyleBoxFlat = StyleBoxFlat.new()
	ns.bg_color = Color(0.4, 0.3, 0.2)
	next_btn.add_theme_stylebox_override("normal", ns)
	next_btn.add_theme_font_size_override("font_size", 14)
	next_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	next_btn.pressed.connect(_on_next_month)
	add_child(next_btn)

func _draw_cities() -> void:
	for i in range(cities.size()):
		var city: Dictionary = cities[i] as Dictionary
		var pos: Vector2 = city["pos"] as Vector2
		var dot: ColorRect = ColorRect.new()
		dot.color = Color(0.9, 0.8, 0.5)
		dot.size = Vector2(16, 16)
		dot.position = pos - Vector2(8, 8)
		map_node.add_child(dot)
		var lbl: Label = Label.new()
		lbl.text = city["name"] as String
		lbl.position = pos + Vector2(-20, 12)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
		map_node.add_child(lbl)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)

func _handle_click(pos: Vector2) -> void:
	var closest: int = -1
	var closest_dist: float = 40.0
	for i in range(cities.size()):
		var city: Dictionary = cities[i] as Dictionary
		var cpos: Vector2 = city["pos"] as Vector2
		var d: float = pos.distance_to(cpos)
		if d < closest_dist:
			closest_dist = d
			closest = i
	if closest == -1:
		selected_city = -1
		status_label.text = "Click a city to start building track"
		return
	if selected_city == -1:
		selected_city = closest
		var cname: String = cities[closest]["name"] as String
		status_label.text = "Selected: " + cname + " - click another city to connect"
	else:
		if closest != selected_city:
			_lay_track(selected_city, closest)
		selected_city = -1

func _lay_track(from_idx: int, to_idx: int) -> void:
	# Check if track already exists
	for t in tracks:
		var td: Dictionary = t as Dictionary
		var tf: int = td["from"] as int
		var tt: int = td["to"] as int
		if (tf == from_idx and tt == to_idx) or (tf == to_idx and tt == from_idx):
			status_label.text = "Track already exists!"
			return
	var from_pos: Vector2 = cities[from_idx]["pos"] as Vector2
	var to_pos: Vector2 = cities[to_idx]["pos"] as Vector2
	var dist: float = from_pos.distance_to(to_pos)
	var cost: int = int(dist * 0.5)
	if gold < cost:
		status_label.text = "Not enough gold! Need " + str(cost)
		return
	gold -= cost
	tracks.append({"from": from_idx, "to": to_idx})
	var fn: String = cities[from_idx]["name"] as String
	var tn: String = cities[to_idx]["name"] as String
	status_label.text = "Built track: " + fn + " - " + tn + " (cost: " + str(cost) + "g)"
	_update_hud()
	queue_redraw()

func _on_buy_train() -> void:
	if gold < 100:
		status_label.text = "Not enough gold for a train!"
		return
	if tracks.size() == 0:
		status_label.text = "Build track first!"
		return
	gold -= 100
	var route_idx: int = trains.size() % tracks.size()
	trains.append({"route": route_idx, "revenue": 0})
	status_label.text = "Bought train #" + str(trains.size()) + " assigned to route " + str(route_idx)
	_update_hud()

func _on_next_month() -> void:
	var income: int = 0
	for t in trains:
		var td: Dictionary = t as Dictionary
		var rev: int = 30 + randi() % 20
		td["revenue"] = (td["revenue"] as int) + rev
		income += rev
	gold += income
	month += 1
	if income > 0:
		status_label.text = "Month " + str(month - 1) + " income: +" + str(income) + "g"
	else:
		status_label.text = "No trains running. Buy trains to earn revenue."
	_update_hud()
	if month > max_months:
		_end_game()

func _update_hud() -> void:
	hud_gold.text = "Gold: " + str(gold)
	hud_month.text = "Month: " + str(month) + "/" + str(max_months)
	hud_trains.text = "Trains: " + str(trains.size())

func _draw() -> void:
	for t in tracks:
		var td: Dictionary = t as Dictionary
		var fi: int = td["from"] as int
		var ti: int = td["to"] as int
		var fp: Vector2 = cities[fi]["pos"] as Vector2
		var tp: Vector2 = cities[ti]["pos"] as Vector2
		draw_line(fp, tp, Color(0.7, 0.5, 0.2), 3.0)

func _end_game() -> void:
	main_node.set_meta("final_gold", gold)
	main_node.set_meta("final_tracks", tracks.size())
	main_node.set_meta("final_trains", trains.size())
	main_node.call("_switch_screen", "Result")

func _setup_running_scenario() -> void:
	# Pre-build a track and train for the running scenario
	tracks.append({"from": 0, "to": 1})
	trains.append({"route": 0, "revenue": 0})
	gold = 300
	status_label.text = "Train running on New York - Chicago route"
	_update_hud()
	queue_redraw()
