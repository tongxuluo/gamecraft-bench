extends Node2D

var gold: int = 500
var reputation: int = 10
var notoriety: int = 0
var week: int = 1

var buildings: Array = []
var crews: Array = []
var max_grid_slots: int = 12

var building_types: Array = [
	{"name": "Dock", "cost": 100, "rep_bonus": 2, "desc": "Berth for ships"},
	{"name": "Tavern", "cost": 150, "rep_bonus": 5, "desc": "Attracts crews"},
	{"name": "Warehouse", "cost": 200, "rep_bonus": 1, "desc": "Stores loot"},
	{"name": "Cannon Tower", "cost": 300, "rep_bonus": 0, "desc": "Port defense"}
]

var trade_routes: Array = [
	{"name": "Merchant Convoy", "risk": 30, "reward": 200, "notoriety_gain": 5},
	{"name": "Sugar Galleon", "risk": 50, "reward": 400, "notoriety_gain": 10},
	{"name": "Royal Treasury Ship", "risk": 75, "reward": 800, "notoriety_gain": 20}
]

var hud_gold_label: Label
var hud_rep_label: Label
var hud_not_label: Label
var hud_week_label: Label
var msg_label: Label
var grid_container: Node2D
var game_over: bool = false

func _ready() -> void:
	_build_ui()
	var main_node: Node = get_parent()
	var scen: String = main_node.get("scenario") as String
	if scen == "building":
		_auto_build()
	elif scen == "raid":
		_auto_raid()

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.15)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# HUD bar
	var hud_bar: ColorRect = ColorRect.new()
	hud_bar.color = Color(0.08, 0.12, 0.25)
	hud_bar.size = Vector2(1280, 50)
	add_child(hud_bar)

	hud_gold_label = Label.new()
	hud_gold_label.position = Vector2(20, 12)
	hud_gold_label.add_theme_font_size_override("font_size", 18)
	hud_gold_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	add_child(hud_gold_label)

	hud_rep_label = Label.new()
	hud_rep_label.position = Vector2(250, 12)
	hud_rep_label.add_theme_font_size_override("font_size", 18)
	hud_rep_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	add_child(hud_rep_label)

	hud_not_label = Label.new()
	hud_not_label.position = Vector2(500, 12)
	hud_not_label.add_theme_font_size_override("font_size", 18)
	hud_not_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	add_child(hud_not_label)

	hud_week_label = Label.new()
	hud_week_label.position = Vector2(750, 12)
	hud_week_label.add_theme_font_size_override("font_size", 18)
	hud_week_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(hud_week_label)

	_update_hud()

	# Message area
	msg_label = Label.new()
	msg_label.position = Vector2(20, 620)
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	msg_label.text = "Welcome to your pirate port! Build structures and send raids."
	add_child(msg_label)

	# Building grid area
	grid_container = Node2D.new()
	grid_container.position = Vector2(20, 70)
	add_child(grid_container)
	_draw_grid()

	# Build buttons
	var build_label: Label = Label.new()
	build_label.text = "BUILD:"
	build_label.position = Vector2(20, 520)
	build_label.add_theme_font_size_override("font_size", 16)
	build_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	add_child(build_label)

	for i in range(building_types.size()):
		var btype: Dictionary = building_types[i]
		var btn: Button = Button.new()
		var bname: String = btype["name"] as String
		var bcost: int = btype["cost"] as int
		btn.text = bname + " (" + str(bcost) + "g)"
		btn.position = Vector2(100 + i * 200, 515)
		btn.custom_minimum_size = Vector2(180, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.25, 0.4)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(_on_build.bind(i))
		add_child(btn)

	# Raid buttons
	var raid_label: Label = Label.new()
	raid_label.text = "RAID:"
	raid_label.position = Vector2(20, 570)
	raid_label.add_theme_font_size_override("font_size", 16)
	raid_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	add_child(raid_label)

	for i in range(trade_routes.size()):
		var route: Dictionary = trade_routes[i]
		var btn: Button = Button.new()
		var rname: String = route["name"] as String
		btn.text = rname
		btn.position = Vector2(100 + i * 250, 565)
		btn.custom_minimum_size = Vector2(220, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.4, 0.15, 0.1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(_on_raid.bind(i))
		add_child(btn)

	# Next week button
	var next_btn: Button = Button.new()
	next_btn.text = "NEXT WEEK"
	next_btn.position = Vector2(1100, 12)
	next_btn.custom_minimum_size = Vector2(150, 35)
	next_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var ns: StyleBoxFlat = StyleBoxFlat.new()
	ns.bg_color = Color(0.2, 0.5, 0.3)
	ns.corner_radius_top_left = 4
	ns.corner_radius_top_right = 4
	ns.corner_radius_bottom_left = 4
	ns.corner_radius_bottom_right = 4
	next_btn.add_theme_stylebox_override("normal", ns)
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	next_btn.pressed.connect(_on_next_week)
	add_child(next_btn)

func _draw_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	for i in range(max_grid_slots):
		var slot: ColorRect = ColorRect.new()
		var col: int = i % 6
		var row: int = i / 6
		slot.position = Vector2(col * 130, row * 180)
		slot.size = Vector2(120, 160)
		if i < buildings.size():
			slot.color = Color(0.15, 0.35, 0.5)
		else:
			slot.color = Color(0.1, 0.15, 0.25)
		grid_container.add_child(slot)
		if i < buildings.size():
			var lbl: Label = Label.new()
			var bname: String = buildings[i] as String
			lbl.text = bname
			lbl.position = Vector2(col * 130 + 10, row * 180 + 70)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
			grid_container.add_child(lbl)

func _update_hud() -> void:
	hud_gold_label.text = "Gold: " + str(gold)
	hud_rep_label.text = "Reputation: " + str(reputation)
	hud_not_label.text = "Notoriety: " + str(notoriety)
	hud_week_label.text = "Week: " + str(week)

func _on_build(idx: int) -> void:
	if game_over:
		return
	if buildings.size() >= max_grid_slots:
		msg_label.text = "No more building slots available!"
		return
	var btype: Dictionary = building_types[idx]
	var bcost: int = btype["cost"] as int
	var bname: String = btype["name"] as String
	var brep: int = btype["rep_bonus"] as int
	if gold < bcost:
		msg_label.text = "Not enough gold to build " + bname + "!"
		return
	gold -= bcost
	reputation += brep
	buildings.append(bname)
	msg_label.text = "Built " + bname + "! +" + str(brep) + " reputation."
	_update_hud()
	_draw_grid()
	_check_crew_arrival()

func _on_raid(idx: int) -> void:
	if game_over:
		return
	if crews.size() == 0 and buildings.size() == 0:
		msg_label.text = "You need at least a dock and crew to raid!"
		return
	var route: Dictionary = trade_routes[idx]
	var rname: String = route["name"] as String
	var risk: int = route["risk"] as int
	var reward: int = route["reward"] as int
	var not_gain: int = route["notoriety_gain"] as int
	var roll: int = randi() % 100
	if roll >= risk:
		gold += reward
		notoriety += not_gain
		msg_label.text = "Raid on " + rname + " succeeded! +" + str(reward) + " gold."
	else:
		var loss: int = reward / 4
		gold = max(0, gold - loss)
		notoriety += not_gain / 2
		msg_label.text = "Raid on " + rname + " failed! Lost " + str(loss) + " gold."
	_update_hud()

func _on_next_week() -> void:
	if game_over:
		return
	week += 1
	_check_crew_arrival()
	_check_navy_attack()
	_update_hud()
	if week > 52:
		_end_game("You survived a full year!")

func _check_crew_arrival() -> void:
	if reputation >= 20 and crews.size() < 1:
		crews.append("Scurvy Dogs")
		msg_label.text += " A crew arrived: Scurvy Dogs!"
	elif reputation >= 40 and crews.size() < 2:
		crews.append("Sea Wolves")
		msg_label.text += " A crew arrived: Sea Wolves!"
	elif reputation >= 70 and crews.size() < 3:
		crews.append("Dread Corsairs")
		msg_label.text += " A crew arrived: Dread Corsairs!"

func _check_navy_attack() -> void:
	if notoriety < 30:
		return
	var defense: int = 0
	for b in buildings:
		var bname: String = b as String
		if bname == "Cannon Tower":
			defense += 25
	var attack_strength: int = notoriety + randi() % 20
	if attack_strength > defense + 40:
		var damage: int = (attack_strength - defense) * 5
		gold = max(0, gold - damage)
		msg_label.text = "Navy attacked! Lost " + str(damage) + " gold. Build more cannons!"
		if gold <= 0 and buildings.size() <= 1:
			_end_game("The Royal Navy destroyed your port!")
	else:
		msg_label.text = "Navy attacked but your defenses held!"
		notoriety = max(0, notoriety - 10)
	_update_hud()

func _end_game(reason: String) -> void:
	game_over = true
	var main_node: Node = get_parent()
	main_node.set("result_data", {"gold": gold, "reputation": reputation, "notoriety": notoriety, "week": week, "buildings": buildings.size(), "crews": crews.size(), "reason": reason})
	main_node.call("_switch_screen", "Result")

func _auto_build() -> void:
	_on_build(0)
	_on_build(1)
	_on_build(2)

func _auto_raid() -> void:
	_on_build(0)
	_on_raid(0)
