extends Control

var main: Node = null
var car_rects: Array = []
var player_marker: ColorRect = null
var guard_marker: ColorRect = null
var hp_label: Label = null
var gold_label: Label = null
var inv_label: Label = null
var info_label: Label = null
var guard_label: Label = null

func _ready() -> void:
	# Background - sky
	var bg = ColorRect.new()
	bg.color = Color(0.4, 0.6, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.3, 0.5, 0.2)
	ground.position = Vector2(0, 520)
	ground.size = Vector2(1280, 200)
	add_child(ground)

	# Track
	var track = ColorRect.new()
	track.color = Color(0.4, 0.35, 0.3)
	track.position = Vector2(0, 510)
	track.size = Vector2(1280, 15)
	add_child(track)

	# Draw 8 train cars
	var car_colors = {
		"start": Color(0.5, 0.5, 0.6),
		"combat": Color(0.7, 0.2, 0.2),
		"shop": Color(0.2, 0.6, 0.2),
		"trap": Color(0.7, 0.5, 0.1),
		"treasure": Color(0.8, 0.7, 0.1),
		"engine": Color(0.3, 0.3, 0.3)
	}

	for i in range(8):
		var car = ColorRect.new()
		var ctype = main.car_types[i]
		car.color = car_colors.get(ctype, Color(0.5, 0.5, 0.5))
		car.position = Vector2(60 + i * 148, 380)
		car.size = Vector2(135, 130)
		add_child(car)
		car_rects.append(car)

		# Car label
		var lbl = Label.new()
		lbl.text = ctype.to_upper()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.position = Vector2(70 + i * 148, 440)
		add_child(lbl)

		# Car number
		var num = Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 18)
		num.add_theme_color_override("font_color", Color(1, 1, 1))
		num.position = Vector2(120 + i * 148, 390)
		add_child(num)

	# Player marker (yellow triangle-ish)
	player_marker = ColorRect.new()
	player_marker.color = Color(1.0, 0.9, 0.0)
	player_marker.size = Vector2(20, 30)
	add_child(player_marker)
	_update_player_pos()

	# Guard marker (red)
	guard_marker = ColorRect.new()
	guard_marker.color = Color(0.9, 0.1, 0.1)
	guard_marker.size = Vector2(20, 30)
	add_child(guard_marker)
	_update_guard_pos()

	# HUD - top bar
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	hud_bg.position = Vector2(0, 0)
	hud_bg.size = Vector2(1280, 60)
	add_child(hud_bg)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 22)
	hp_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	hp_label.position = Vector2(20, 15)
	add_child(hp_label)

	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.0))
	gold_label.position = Vector2(250, 15)
	add_child(gold_label)

	inv_label = Label.new()
	inv_label.add_theme_font_size_override("font_size", 22)
	inv_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	inv_label.position = Vector2(450, 15)
	add_child(inv_label)

	guard_label = Label.new()
	guard_label.add_theme_font_size_override("font_size", 22)
	guard_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	guard_label.position = Vector2(850, 15)
	add_child(guard_label)

	# Info label at bottom
	info_label = Label.new()
	info_label.text = "Press RIGHT to move to next car"
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.add_theme_color_override("font_color", Color(1, 1, 1))
	info_label.position = Vector2(420, 660)
	add_child(info_label)

	_update_hud()

func _update_player_pos() -> void:
	var x = 110 + main.current_car * 148
	player_marker.position = Vector2(x, 350)

func _update_guard_pos() -> void:
	if main.guard_car >= 0:
		var x = 110 + main.guard_car * 148
		guard_marker.position = Vector2(x, 350)
		guard_marker.visible = true
	else:
		guard_marker.visible = false

func _update_hud() -> void:
	hp_label.text = "HP: " + str(main.hp) + "/" + str(main.max_hp)
	gold_label.text = "Gold: " + str(main.gold)
	var inv_text = "Items: "
	if main.inventory.size() == 0:
		inv_text += "(empty)"
	else:
		inv_text += ", ".join(main.inventory)
	inv_label.text = inv_text
	guard_label.text = "Guards at car: " + str(main.guard_car + 1)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			main.move_forward()
