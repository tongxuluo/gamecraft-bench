extends Control

var main: Node = null

var options: Array = []
var option_buttons: Array = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_generate_options()
	_build_ui()

func _generate_options() -> void:
	# 3 equipment choices based on current fight
	var all_equipment = [
		{"name": "Flame Sword", "desc": "Replace a BLANK with FIRE ATK (10 dmg)", "face_old": "blank", "face_new": "fire_sword"},
		{"name": "Tower Shield", "desc": "Replace a BLANK with DEF+ (8 block)", "face_old": "blank", "face_new": "double_shield"},
		{"name": "Vampiric Blade", "desc": "Replace a BLANK with VAMP (4 dmg + 3 heal)", "face_old": "blank", "face_new": "vampiric"},
		{"name": "Sharpened Edge", "desc": "Replace a SHIELD with ATK (5 dmg)", "face_old": "shield", "face_new": "sword"},
		{"name": "Battle Medic", "desc": "Replace a SWORD with HEAL (6 hp)", "face_old": "sword", "face_new": "heart"},
		{"name": "Skull Charm", "desc": "Replace a BLANK with SKULL (8 special)", "face_old": "blank", "face_new": "skull"},
	]
	# Pick 3 based on fight index
	var start = (main.current_fight - 1) * 2
	if start < 0:
		start = 0
	for i in range(3):
		var idx = (start + i) % all_equipment.size()
		options.append(all_equipment[idx])

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.1, 0.15)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "EQUIPMENT FOUND!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(390, 50)
	title.size = Vector2(500, 50)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Choose one piece of equipment to modify your dice:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	subtitle.position = Vector2(340, 110)
	subtitle.size = Vector2(600, 30)
	add_child(subtitle)

	# Equipment options
	for i in range(options.size()):
		var opt = options[i]
		var y_pos = 180 + i * 160

		# Card background
		var card = ColorRect.new()
		card.color = Color(0.15, 0.18, 0.25)
		card.position = Vector2(290, y_pos)
		card.size = Vector2(700, 130)
		add_child(card)

		# Name
		var name_lbl = Label.new()
		name_lbl.text = opt["name"]
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		name_lbl.position = Vector2(310, y_pos + 15)
		name_lbl.size = Vector2(400, 35)
		add_child(name_lbl)

		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = opt["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		desc_lbl.position = Vector2(310, y_pos + 55)
		desc_lbl.size = Vector2(500, 25)
		add_child(desc_lbl)

		# Choose button
		var btn = Button.new()
		btn.text = "EQUIP"
		btn.position = Vector2(820, y_pos + 40)
		btn.size = Vector2(140, 45)
		btn.add_theme_font_size_override("font_size", 18)
		var idx = i
		btn.pressed.connect(func(): _on_choose(idx))
		btn.name = "EquipBtn%d" % i
		add_child(btn)
		option_buttons.append(btn)

func _on_choose(index: int) -> void:
	var opt = options[index]
	# Find a die with the old face and replace it
	var replaced = false
	for d in range(5):
		var faces = main.dice_faces[d]
		for f in range(faces.size()):
			if faces[f] == opt["face_old"] and not replaced:
				main.dice_faces[d][f] = opt["face_new"]
				replaced = true
				break
		if replaced:
			break
	main.equipment_collected.append(opt["name"])
	main.advance_after_equipment()
