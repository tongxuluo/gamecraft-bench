extends Node2D

var main: Node = null
var enemy_data: Dictionary = {}

const COLOR_BG = Color(0.02, 0.02, 0.05)
const COLOR_PLAYER_SHIP = Color(0.2, 0.25, 0.35)
const COLOR_ENEMY_SHIP = Color(0.35, 0.15, 0.15)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_ACCENT = Color(0.3, 0.6, 0.9)
const COLOR_DANGER = Color(0.9, 0.3, 0.2)
const COLOR_HEALTH = Color(0.2, 0.8, 0.3)
const COLOR_PANEL = Color(0.1, 0.12, 0.16)

var enemy_hull: int = 12
var enemy_max_hull: int = 12
var player_weapons_charged: bool = true
var combat_log: Array = []
var enemy_hull_bar: ColorRect = null
var player_hull_bar: ColorRect = null
var log_label: Label = null
var charge_label: Label = null

func _ready() -> void:
	enemy_hull = enemy_data.get("enemy_hull", 12)
	enemy_max_hull = enemy_hull

	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Player ship (left side)
	var player_ship = ColorRect.new()
	player_ship.color = COLOR_PLAYER_SHIP
	player_ship.size = Vector2(200, 100)
	player_ship.position = Vector2(100, 200)
	add_child(player_ship)

	var player_nose = ColorRect.new()
	player_nose.color = COLOR_PLAYER_SHIP
	player_nose.size = Vector2(40, 50)
	player_nose.position = Vector2(300, 225)
	add_child(player_nose)

	var player_lbl = Label.new()
	player_lbl.text = "YOUR SHIP"
	player_lbl.position = Vector2(140, 175)
	player_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	player_lbl.add_theme_font_size_override("font_size", 16)
	add_child(player_lbl)

	# Player hull bar
	var p_hull_bg = ColorRect.new()
	p_hull_bg.color = Color(0.2, 0.1, 0.1)
	p_hull_bg.size = Vector2(200, 16)
	p_hull_bg.position = Vector2(100, 310)
	add_child(p_hull_bg)

	player_hull_bar = ColorRect.new()
	player_hull_bar.color = COLOR_HEALTH
	player_hull_bar.size = Vector2(200.0 * main.hull / main.max_hull, 16)
	player_hull_bar.position = Vector2(100, 310)
	add_child(player_hull_bar)

	var p_hull_lbl = Label.new()
	p_hull_lbl.text = "Hull: " + str(main.hull) + "/" + str(main.max_hull)
	p_hull_lbl.position = Vector2(100, 328)
	p_hull_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	p_hull_lbl.add_theme_font_size_override("font_size", 14)
	add_child(p_hull_lbl)

	# Enemy ship (right side)
	var enemy_ship = ColorRect.new()
	enemy_ship.color = COLOR_ENEMY_SHIP
	enemy_ship.size = Vector2(200, 100)
	enemy_ship.position = Vector2(900, 200)
	add_child(enemy_ship)

	var enemy_nose = ColorRect.new()
	enemy_nose.color = COLOR_ENEMY_SHIP
	enemy_nose.size = Vector2(40, 50)
	enemy_nose.position = Vector2(860, 225)
	add_child(enemy_nose)

	var enemy_name_lbl = Label.new()
	enemy_name_lbl.text = enemy_data.get("enemy_name", "Enemy")
	enemy_name_lbl.position = Vector2(930, 175)
	enemy_name_lbl.add_theme_color_override("font_color", COLOR_DANGER)
	enemy_name_lbl.add_theme_font_size_override("font_size", 16)
	add_child(enemy_name_lbl)

	# Enemy hull bar
	var e_hull_bg = ColorRect.new()
	e_hull_bg.color = Color(0.2, 0.1, 0.1)
	e_hull_bg.size = Vector2(200, 16)
	e_hull_bg.position = Vector2(900, 310)
	add_child(e_hull_bg)

	enemy_hull_bar = ColorRect.new()
	enemy_hull_bar.color = COLOR_DANGER
	enemy_hull_bar.size = Vector2(200, 16)
	enemy_hull_bar.position = Vector2(900, 310)
	add_child(enemy_hull_bar)

	var e_hull_lbl = Label.new()
	e_hull_lbl.text = "Hull: " + str(enemy_hull) + "/" + str(enemy_max_hull)
	e_hull_lbl.position = Vector2(900, 328)
	e_hull_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	e_hull_lbl.add_theme_font_size_override("font_size", 14)
	add_child(e_hull_lbl)

	# Combat controls panel
	var panel_bg = ColorRect.new()
	panel_bg.color = COLOR_PANEL
	panel_bg.size = Vector2(1280, 280)
	panel_bg.position = Vector2(0, 440)
	add_child(panel_bg)

	# Fire weapons button
	var fire_btn = _make_button("FIRE WEAPONS", Vector2(50, 470), Vector2(200, 50))
	fire_btn.pressed.connect(_on_fire_pressed)
	add_child(fire_btn)

	# Charge status
	charge_label = Label.new()
	charge_label.text = "Weapons: CHARGED"
	charge_label.position = Vector2(50, 530)
	charge_label.add_theme_color_override("font_color", COLOR_HEALTH)
	charge_label.add_theme_font_size_override("font_size", 16)
	add_child(charge_label)

	# Systems status
	var sys_y = 470
	var sys_x = 320
	for sys_name in main.systems:
		var sys = main.systems[sys_name]
		var sys_lbl = Label.new()
		sys_lbl.text = sys_name.to_upper() + ": " + str(sys.power) + "/" + str(sys.max_power)
		if sys.damage > 0:
			sys_lbl.text += " [DMG:" + str(sys.damage) + "]"
		sys_lbl.position = Vector2(sys_x, sys_y)
		sys_lbl.add_theme_font_size_override("font_size", 14)
		if sys.damage > 0:
			sys_lbl.add_theme_color_override("font_color", COLOR_DANGER)
		else:
			sys_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		add_child(sys_lbl)
		sys_y += 25

	# Combat log
	log_label = Label.new()
	log_label.text = "-- Combat started --"
	log_label.position = Vector2(650, 470)
	log_label.size = Vector2(600, 200)
	log_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(log_label)

	# Flee button
	var flee_btn = _make_button("FLEE", Vector2(50, 570), Vector2(200, 50))
	flee_btn.pressed.connect(_on_flee_pressed)
	add_child(flee_btn)

	# Targeting lines (visual)
	var target_line = Line2D.new()
	target_line.add_point(Vector2(340, 250))
	target_line.add_point(Vector2(860, 250))
	target_line.width = 1.0
	target_line.default_color = Color(0.9, 0.3, 0.2, 0.3)
	add_child(target_line)

func _on_fire_pressed() -> void:
	if not player_weapons_charged:
		return
	var weapon_power = main.systems["weapons"].power
	var damage = weapon_power + 1
	enemy_hull -= damage
	player_weapons_charged = false
	_add_log("You fire! " + str(damage) + " damage to enemy.")

	# Update enemy hull bar
	var ratio = max(0.0, float(enemy_hull) / float(enemy_max_hull))
	enemy_hull_bar.size.x = 200.0 * ratio

	if enemy_hull <= 0:
		_add_log("Enemy destroyed!")
		_combat_victory()
		return

	# Enemy fires back
	_enemy_turn()

	# Recharge after 1 frame (simplified)
	charge_label.text = "Weapons: CHARGING..."
	charge_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	await get_tree().create_timer(1.0).timeout
	player_weapons_charged = true
	charge_label.text = "Weapons: CHARGED"
	charge_label.add_theme_color_override("font_color", COLOR_HEALTH)

func _enemy_turn() -> void:
	var enemy_dmg = enemy_data.get("enemy_weapons", 2)
	var shield_reduction = main.systems["shields"].power
	var actual_dmg = max(1, enemy_dmg - shield_reduction)
	main.hull -= actual_dmg
	_add_log("Enemy fires! " + str(actual_dmg) + " damage to hull.")

	# Random system damage
	var sys_keys = main.systems.keys()
	var hit_sys = sys_keys[randi() % sys_keys.size()]
	if randf() < 0.3:
		main.systems[hit_sys].damage += 1
		_add_log(hit_sys.to_upper() + " system damaged!")

	# Update player hull bar
	var ratio = max(0.0, float(main.hull) / float(main.max_hull))
	player_hull_bar.size.x = 200.0 * ratio

	if main.hull <= 0:
		_add_log("Ship destroyed!")
		main._enter_defeat()

func _on_flee_pressed() -> void:
	var engine_power = main.systems["engines"].power
	if randf() < 0.3 + engine_power * 0.15:
		_add_log("Escaped!")
		main._enter_sector_map()
	else:
		_add_log("Failed to escape!")
		_enemy_turn()

func _combat_victory() -> void:
	var scrap_reward = enemy_max_hull + randi() % 10
	main.scrap += scrap_reward
	_add_log("Gained " + str(scrap_reward) + " scrap.")
	await get_tree().create_timer(1.5).timeout
	if enemy_data.get("type", "") == "boss":
		main._enter_victory()
	else:
		main._enter_sector_map()

func _add_log(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 6:
		combat_log = combat_log.slice(combat_log.size() - 6)
	if log_label != null and is_instance_valid(log_label):
		log_label.text = "\n".join(combat_log)

func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.18, 0.25)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 18)
	return b
