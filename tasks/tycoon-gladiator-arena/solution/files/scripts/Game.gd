extends Node2D

var gold: int = 100
var day: int = 1
var reputation: int = 0
var max_days: int = 20
var gladiators: Array = []
var selected_fighters: Array = []
var fight_active: bool = false
var fight_timer: float = 0.0
var fighter_a_hp: int = 100
var fighter_b_hp: int = 100

var hud_label: Label
var roster_container: Node2D
var arena_panel: ColorRect
var msg_label: Label
var train_btn: Button
var fight_btn: Button
var next_day_btn: Button
var hp_bar_a: ColorRect
var hp_bar_b: ColorRect
var fighter_labels: Array = []
var select_buttons: Array = []

func _ready() -> void:
	_init_gladiators()
	_build_ui()
	var sc: String = get_meta("scenario") if has_meta("scenario") else ""
	if sc == "fight":
		selected_fighters = [0, 1]
		_start_fight()

func _init_gladiators() -> void:
	gladiators.append({"name": "Maximus", "strength": 7, "speed": 5, "appeal": 6, "training": ""})
	gladiators.append({"name": "Brutus", "strength": 8, "speed": 3, "appeal": 4, "training": ""})
	gladiators.append({"name": "Felix", "strength": 4, "speed": 8, "appeal": 7, "training": ""})
	gladiators.append({"name": "Cassius", "strength": 6, "speed": 6, "appeal": 5, "training": ""})

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.18, 0.14, 0.10)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Arena floor panel
	arena_panel = ColorRect.new()
	arena_panel.color = Color(0.6, 0.5, 0.3)
	arena_panel.position = Vector2(400, 80)
	arena_panel.size = Vector2(460, 300)
	add_child(arena_panel)
	var arena_lbl: Label = Label.new()
	arena_lbl.text = "ARENA FLOOR"
	arena_lbl.position = Vector2(580, 90)
	arena_lbl.add_theme_font_size_override("font_size", 20)
	arena_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	add_child(arena_lbl)

	# HP bars
	hp_bar_a = ColorRect.new()
	hp_bar_a.color = Color(0.2, 0.8, 0.2)
	hp_bar_a.position = Vector2(430, 350)
	hp_bar_a.size = Vector2(200, 20)
	hp_bar_a.visible = false
	add_child(hp_bar_a)
	hp_bar_b = ColorRect.new()
	hp_bar_b.color = Color(0.8, 0.2, 0.2)
	hp_bar_b.position = Vector2(640, 350)
	hp_bar_b.size = Vector2(200, 20)
	hp_bar_b.visible = false
	add_child(hp_bar_b)

	# HUD
	hud_label = Label.new()
	hud_label.position = Vector2(20, 10)
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	add_child(hud_label)
	_update_hud()

	# Message label
	msg_label = Label.new()
	msg_label.position = Vector2(400, 400)
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(msg_label)

	# Roster
	roster_container = Node2D.new()
	roster_container.position = Vector2(20, 80)
	add_child(roster_container)
	_build_roster()

	# Buttons
	train_btn = _make_btn("TRAIN", Vector2(20, 600), _on_train)
	fight_btn = _make_btn("FIGHT NIGHT", Vector2(220, 600), _on_fight)
	next_day_btn = _make_btn("NEXT DAY", Vector2(460, 600), _on_next_day)

func _make_btn(txt: String, pos: Vector2, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = txt
	btn.position = pos
	btn.custom_minimum_size = Vector2(180, 50)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.45, 0.1)
	style.set_border_width_all(2)
	style.border_color = Color(0.8, 0.7, 0.3)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(callback)
	add_child(btn)
	return btn

func _build_roster() -> void:
	for child in roster_container.get_children():
		child.queue_free()
	fighter_labels.clear()
	select_buttons.clear()
	for i in range(gladiators.size()):
		var g: Dictionary = gladiators[i]
		var lbl: Label = Label.new()
		var n: String = g["name"]
		var st: int = g["strength"]
		var sp: int = g["speed"]
		var ap: int = g["appeal"]
		var tr: String = g["training"]
		lbl.text = "%s  STR:%d SPD:%d APP:%d [%s]" % [n, st, sp, ap, tr]
		lbl.position = Vector2(0, i * 50)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		roster_container.add_child(lbl)
		fighter_labels.append(lbl)
		var sel_btn: Button = Button.new()
		sel_btn.text = "SELECT"
		sel_btn.position = Vector2(320, i * 50 - 5)
		sel_btn.custom_minimum_size = Vector2(70, 30)
		sel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		sel_btn.pressed.connect(_on_select.bind(i))
		roster_container.add_child(sel_btn)
		select_buttons.append(sel_btn)

func _update_hud() -> void:
	hud_label.text = "Gold: %d | Day: %d/%d | Reputation: %d" % [gold, day, max_days, reputation]

func _on_select(idx: int) -> void:
	if selected_fighters.size() < 2 and not (idx in selected_fighters):
		selected_fighters.append(idx)
		msg_label.text = "Selected: " + _get_selected_names()

func _get_selected_names() -> String:
	var names: String = ""
	for i in range(selected_fighters.size()):
		var idx: int = selected_fighters[i]
		var g: Dictionary = gladiators[idx]
		var n: String = g["name"]
		if i > 0:
			names += " vs "
		names += n
	return names

func _on_train() -> void:
	for i in range(gladiators.size()):
		gladiators[i]["training"] = "strength"
		gladiators[i]["strength"] += 1
	gold -= 10
	msg_label.text = "All gladiators trained in strength!"
	_build_roster()
	_update_hud()

func _on_fight() -> void:
	if selected_fighters.size() < 2:
		msg_label.text = "Select 2 fighters first!"
		return
	_start_fight()

func _start_fight() -> void:
	fight_active = true
	fighter_a_hp = 100
	fighter_b_hp = 100
	fight_timer = 0.0
	hp_bar_a.visible = true
	hp_bar_b.visible = true
	hp_bar_a.size = Vector2(200, 20)
	hp_bar_b.size = Vector2(200, 20)
	msg_label.text = "FIGHT! " + _get_selected_names()

func _process(delta: float) -> void:
	if not fight_active:
		return
	fight_timer += delta
	if fight_timer < 0.3:
		return
	fight_timer = 0.0
	var idx_a: int = selected_fighters[0]
	var idx_b: int = selected_fighters[1]
	var ga: Dictionary = gladiators[idx_a]
	var gb: Dictionary = gladiators[idx_b]
	var dmg_a: int = ga["strength"] + randi() % 5
	var dmg_b: int = gb["strength"] + randi() % 5
	fighter_b_hp -= dmg_a
	fighter_a_hp -= dmg_b
	hp_bar_a.size = Vector2(max(0, fighter_a_hp) * 2, 20)
	hp_bar_b.size = Vector2(max(0, fighter_b_hp) * 2, 20)
	if fighter_a_hp <= 0 or fighter_b_hp <= 0:
		fight_active = false
		var winner_name: String = ""
		if fighter_a_hp > fighter_b_hp:
			winner_name = ga["name"]
		else:
			winner_name = gb["name"]
		var earned: int = 20 + gb["appeal"] * 3
		gold += earned
		reputation += 5
		msg_label.text = "%s WINS! Crowd roars! +%d gold" % [winner_name, earned]
		selected_fighters.clear()
		_update_hud()

func _on_next_day() -> void:
	day += 1
	if day > max_days:
		var main_node: Node = get_parent()
		if main_node.has_method("_switch_screen"):
			main_node._switch_screen("result")
		return
	for i in range(gladiators.size()):
		gladiators[i]["training"] = ""
	msg_label.text = "Day %d begins." % day
	selected_fighters.clear()
	_build_roster()
	_update_hud()
