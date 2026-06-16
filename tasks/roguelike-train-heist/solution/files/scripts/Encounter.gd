extends Control

var main: Node = null
var car_type: String = ""

var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_name: String = ""
var enemy_damage: int = 0

var encounter_done: bool = false

var status_label: Label = null
var enemy_hp_label: Label = null
var player_hp_label: Label = null
var action_label: Label = null
var attack_btn: Button = null
var continue_btn: Button = null
var shop_panel: Control = null

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	match car_type:
		"combat":
			bg.color = Color(0.2, 0.1, 0.1)
			_setup_combat()
		"shop":
			bg.color = Color(0.1, 0.2, 0.1)
			_setup_shop()
		"trap":
			bg.color = Color(0.25, 0.2, 0.05)
			_setup_trap()
		"treasure":
			bg.color = Color(0.2, 0.2, 0.05)
			_setup_treasure()
		_:
			bg.color = Color(0.2, 0.2, 0.2)
			_setup_empty()

func _setup_combat() -> void:
	enemy_name = "Guard"
	enemy_hp = 40
	enemy_max_hp = 40
	enemy_damage = 12

	# Title
	var title = Label.new()
	title.text = "COMBAT - " + enemy_name
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.position = Vector2(450, 40)
	add_child(title)

	# Enemy visual (big red rect)
	var enemy_rect = ColorRect.new()
	enemy_rect.color = Color(0.7, 0.15, 0.15)
	enemy_rect.position = Vector2(540, 150)
	enemy_rect.size = Vector2(200, 200)
	add_child(enemy_rect)

	var enemy_lbl = Label.new()
	enemy_lbl.text = enemy_name
	enemy_lbl.add_theme_font_size_override("font_size", 24)
	enemy_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	enemy_lbl.position = Vector2(590, 230)
	add_child(enemy_lbl)

	# Enemy HP
	enemy_hp_label = Label.new()
	enemy_hp_label.add_theme_font_size_override("font_size", 22)
	enemy_hp_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	enemy_hp_label.position = Vector2(570, 360)
	add_child(enemy_hp_label)
	_update_enemy_hp()

	# Player HP
	player_hp_label = Label.new()
	player_hp_label.add_theme_font_size_override("font_size", 22)
	player_hp_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	player_hp_label.position = Vector2(100, 500)
	add_child(player_hp_label)
	_update_player_hp()

	# Attack button
	attack_btn = Button.new()
	attack_btn.text = "  ATTACK  "
	attack_btn.position = Vector2(540, 500)
	attack_btn.custom_minimum_size = Vector2(200, 50)
	attack_btn.pressed.connect(_on_attack)
	add_child(attack_btn)

	# Status
	status_label = Label.new()
	status_label.text = "Click ATTACK to fight!"
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
	status_label.position = Vector2(440, 580)
	add_child(status_label)

	# Continue button (hidden until combat done)
	continue_btn = Button.new()
	continue_btn.text = "  CONTINUE  "
	continue_btn.position = Vector2(540, 640)
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	add_child(continue_btn)

func _on_attack() -> void:
	if encounter_done:
		return
	# Player attacks enemy
	var player_dmg = 15
	if main.inventory.has("Knife"):
		player_dmg = 25
	enemy_hp -= player_dmg
	_update_enemy_hp()

	if enemy_hp <= 0:
		enemy_hp = 0
		_update_enemy_hp()
		status_label.text = "Enemy defeated! +15 gold"
		main.gold += 15
		encounter_done = true
		attack_btn.visible = false
		continue_btn.visible = true
		return

	# Enemy attacks back
	main.hp -= enemy_damage
	_update_player_hp()
	status_label.text = "You dealt " + str(player_dmg) + " dmg. Enemy hit you for " + str(enemy_damage) + "!"

	if main.hp <= 0:
		main.hp = 0
		_update_player_hp()
		main._enter_gameover("You died in combat!")

func _update_enemy_hp() -> void:
	enemy_hp_label.text = "Enemy HP: " + str(enemy_hp) + "/" + str(enemy_max_hp)

func _update_player_hp() -> void:
	player_hp_label.text = "Your HP: " + str(main.hp) + "/" + str(main.max_hp)

func _on_continue() -> void:
	main._enter_train_view()

func _setup_shop() -> void:
	var title = Label.new()
	title.text = "BLACK MARKET CAR"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	title.position = Vector2(440, 40)
	add_child(title)

	var gold_lbl = Label.new()
	gold_lbl.text = "Your Gold: " + str(main.gold)
	gold_lbl.add_theme_font_size_override("font_size", 22)
	gold_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0))
	gold_lbl.position = Vector2(100, 100)
	add_child(gold_lbl)

	# Shop items
	var items = [
		{"name": "Health Kit", "cost": 20, "desc": "Restore 30 HP"},
		{"name": "Knife", "cost": 15, "desc": "+10 attack damage"},
		{"name": "Armor", "cost": 25, "desc": "Reduce damage taken"}
	]

	for i in range(items.size()):
		var item = items[i]
		var panel = ColorRect.new()
		panel.color = Color(0.15, 0.3, 0.15)
		panel.position = Vector2(100, 160 + i * 140)
		panel.size = Vector2(500, 120)
		add_child(panel)

		var name_lbl = Label.new()
		name_lbl.text = item["name"] + " - " + str(item["cost"]) + " gold"
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		name_lbl.position = Vector2(120, 175 + i * 140)
		add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = item["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		desc_lbl.position = Vector2(120, 210 + i * 140)
		add_child(desc_lbl)

		var buy_btn = Button.new()
		buy_btn.text = "BUY"
		buy_btn.position = Vector2(480, 185 + i * 140)
		buy_btn.custom_minimum_size = Vector2(100, 40)
		buy_btn.pressed.connect(_on_buy.bind(item["name"], item["cost"]))
		add_child(buy_btn)

	# Continue button
	continue_btn = Button.new()
	continue_btn.text = "  LEAVE SHOP  "
	continue_btn.position = Vector2(540, 640)
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

	# Status
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
	status_label.position = Vector2(100, 600)
	add_child(status_label)

func _on_buy(item_name: String, cost: int) -> void:
	if main.gold < cost:
		status_label.text = "Not enough gold!"
		return
	if item_name == "Health Kit":
		main.hp = min(main.hp + 30, main.max_hp)
		main.gold -= cost
		status_label.text = "Healed 30 HP!"
	else:
		if main.inventory.size() >= 3:
			status_label.text = "Inventory full! (3 slots max)"
			return
		if main.inventory.has(item_name):
			status_label.text = "Already have " + item_name + "!"
			return
		main.inventory.append(item_name)
		main.gold -= cost
		status_label.text = "Bought " + item_name + "!"

func _setup_trap() -> void:
	var title = Label.new()
	title.text = "TRAP CAR"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
	title.position = Vector2(520, 40)
	add_child(title)

	# Trap visual
	var trap_rect = ColorRect.new()
	trap_rect.color = Color(0.6, 0.4, 0.0)
	trap_rect.position = Vector2(440, 200)
	trap_rect.size = Vector2(400, 200)
	add_child(trap_rect)

	var trap_lbl = Label.new()
	trap_lbl.text = "TRIPWIRE DETECTED"
	trap_lbl.add_theme_font_size_override("font_size", 24)
	trap_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.0))
	trap_lbl.position = Vector2(490, 280)
	add_child(trap_lbl)

	# Status
	status_label = Label.new()
	status_label.text = "Choose: Disarm (risky) or Take the hit"
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
	status_label.position = Vector2(380, 450)
	add_child(status_label)

	var disarm_btn = Button.new()
	disarm_btn.text = "  DISARM  "
	disarm_btn.position = Vector2(400, 520)
	disarm_btn.custom_minimum_size = Vector2(180, 50)
	disarm_btn.pressed.connect(_on_disarm)
	add_child(disarm_btn)

	var take_btn = Button.new()
	take_btn.text = "  TAKE HIT  "
	take_btn.position = Vector2(700, 520)
	take_btn.custom_minimum_size = Vector2(180, 50)
	take_btn.pressed.connect(_on_take_hit)
	add_child(take_btn)

	# Continue button (hidden)
	continue_btn = Button.new()
	continue_btn.text = "  CONTINUE  "
	continue_btn.position = Vector2(540, 640)
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	add_child(continue_btn)

func _on_disarm() -> void:
	if encounter_done:
		return
	encounter_done = true
	# Deterministic: success if player has Knife
	if main.inventory.has("Knife"):
		status_label.text = "Disarmed with your Knife! No damage taken."
	else:
		var dmg = 10
		main.hp -= dmg
		status_label.text = "Failed to disarm! Took " + str(dmg) + " damage."
		if main.hp <= 0:
			main.hp = 0
			main._enter_gameover("Killed by a trap!")
			return
	continue_btn.visible = true

func _on_take_hit() -> void:
	if encounter_done:
		return
	encounter_done = true
	var dmg = 15
	if main.inventory.has("Armor"):
		dmg = 8
	main.hp -= dmg
	status_label.text = "Took " + str(dmg) + " damage from the trap."
	if main.hp <= 0:
		main.hp = 0
		main._enter_gameover("Killed by a trap!")
		return
	continue_btn.visible = true

func _setup_treasure() -> void:
	var title = Label.new()
	title.text = "TREASURE CAR"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.0))
	title.position = Vector2(470, 40)
	add_child(title)

	# Treasure chest visual
	var chest = ColorRect.new()
	chest.color = Color(0.6, 0.5, 0.1)
	chest.position = Vector2(490, 200)
	chest.size = Vector2(300, 200)
	add_child(chest)

	var chest_lbl = Label.new()
	chest_lbl.text = "CHEST"
	chest_lbl.add_theme_font_size_override("font_size", 28)
	chest_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
	chest_lbl.position = Vector2(590, 280)
	add_child(chest_lbl)

	# Loot info
	var loot_gold = 25
	main.gold += loot_gold

	status_label = Label.new()
	status_label.text = "Found " + str(loot_gold) + " gold!"
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	status_label.position = Vector2(500, 450)
	add_child(status_label)

	# Continue
	continue_btn = Button.new()
	continue_btn.text = "  CONTINUE  "
	continue_btn.position = Vector2(540, 560)
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

func _setup_empty() -> void:
	var title = Label.new()
	title.text = "EMPTY CAR"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	title.position = Vector2(510, 300)
	add_child(title)

	continue_btn = Button.new()
	continue_btn.text = "  CONTINUE  "
	continue_btn.position = Vector2(540, 500)
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)
