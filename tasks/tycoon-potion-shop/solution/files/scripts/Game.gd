extends Node2D

signal game_ended(stats: Dictionary)

var scenario: String = ""
var gold: int = 50
var day: int = 1
var reputation: int = 50
var max_days: int = 7

var ingredients: Dictionary = {
	"Moonpetal": 10,
	"Firemoss": 10,
	"Icecap": 10,
	"Shadowroot": 10
}

var recipes: Dictionary = {
	"Healing Potion": ["Moonpetal", "Firemoss"],
	"Frost Tonic": ["Icecap", "Moonpetal"],
	"Energy Elixir": ["Firemoss", "Shadowroot"],
	"Calm Draught": ["Icecap", "Shadowroot"]
}

var potion_prices: Dictionary = {
	"Healing Potion": 15,
	"Frost Tonic": 12,
	"Energy Elixir": 18,
	"Calm Draught": 10
}

var ailment_cures: Dictionary = {
	"Wounded": "Healing Potion",
	"Feverish": "Frost Tonic",
	"Exhausted": "Energy Elixir",
	"Anxious": "Calm Draught"
}

var inventory: Dictionary = {}
var selected_ingredients: Array = []
var customers: Array = []
var potions_sold: int = 0
var total_earned: int = 0

# UI refs
var gold_label: Label
var day_label: Label
var rep_label: Label
var msg_label: Label
var ingredient_buttons: Array = []
var brew_btn: Button
var next_day_btn: Button
var customer_panel: ColorRect
var customer_labels: Array = []
var inventory_label: Label
var restock_btn: Button

func _ready() -> void:
	_build_ui()
	if scenario == "customers":
		_spawn_customers()

func _build_ui() -> void:
	# Background - shop interior
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.12, 0.08, 0.18)
	add_child(bg)

	# Floor
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.position = Vector2(0, 550)
	floor_rect.size = Vector2(1280, 170)
	floor_rect.color = Color(0.25, 0.15, 0.1)
	add_child(floor_rect)

	# Cauldron area
	var cauldron: ColorRect = ColorRect.new()
	cauldron.position = Vector2(100, 350)
	cauldron.size = Vector2(180, 180)
	cauldron.color = Color(0.2, 0.2, 0.3)
	add_child(cauldron)
	var cauldron_lbl: Label = Label.new()
	cauldron_lbl.text = "Cauldron"
	cauldron_lbl.position = Vector2(140, 360)
	cauldron_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	add_child(cauldron_lbl)

	# HUD
	gold_label = Label.new()
	gold_label.position = Vector2(20, 10)
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	add_child(gold_label)

	day_label = Label.new()
	day_label.position = Vector2(200, 10)
	day_label.add_theme_font_size_override("font_size", 20)
	day_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(day_label)

	rep_label = Label.new()
	rep_label.position = Vector2(400, 10)
	rep_label.add_theme_font_size_override("font_size", 20)
	rep_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	add_child(rep_label)

	msg_label = Label.new()
	msg_label.position = Vector2(100, 560)
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	add_child(msg_label)

	# Ingredient cabinet
	var cab_lbl: Label = Label.new()
	cab_lbl.text = "Ingredients:"
	cab_lbl.position = Vector2(350, 80)
	cab_lbl.add_theme_font_size_override("font_size", 18)
	cab_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.9))
	add_child(cab_lbl)

	var idx: int = 0
	var keys: Array = ingredients.keys()
	for i in range(keys.size()):
		var ing_name: String = keys[i]
		var btn: Button = Button.new()
		btn.text = ing_name + " (" + str(ingredients[ing_name]) + ")"
		btn.position = Vector2(350, 110 + idx * 50)
		btn.custom_minimum_size = Vector2(180, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = Color(0.3, 0.2, 0.4)
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4
		s.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		btn.pressed.connect(_on_ingredient_pressed.bind(ing_name))
		add_child(btn)
		ingredient_buttons.append(btn)
		idx += 1

	# Brew button
	brew_btn = Button.new()
	brew_btn.text = "BREW"
	brew_btn.position = Vector2(140, 540)
	brew_btn.custom_minimum_size = Vector2(120, 45)
	brew_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var brew_s: StyleBoxFlat = StyleBoxFlat.new()
	brew_s.bg_color = Color(0.6, 0.3, 0.1)
	brew_s.corner_radius_top_left = 6
	brew_s.corner_radius_top_right = 6
	brew_s.corner_radius_bottom_left = 6
	brew_s.corner_radius_bottom_right = 6
	brew_btn.add_theme_stylebox_override("normal", brew_s)
	brew_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	brew_btn.pressed.connect(_on_brew)
	add_child(brew_btn)

	# Inventory display
	inventory_label = Label.new()
	inventory_label.position = Vector2(600, 80)
	inventory_label.add_theme_font_size_override("font_size", 16)
	inventory_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	add_child(inventory_label)

	# Customer counter area
	customer_panel = ColorRect.new()
	customer_panel.position = Vector2(800, 100)
	customer_panel.size = Vector2(440, 400)
	customer_panel.color = Color(0.18, 0.12, 0.22)
	add_child(customer_panel)
	var cust_title: Label = Label.new()
	cust_title.text = "Customers"
	cust_title.position = Vector2(820, 105)
	cust_title.add_theme_font_size_override("font_size", 20)
	cust_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
	add_child(cust_title)

	# Restock button
	restock_btn = Button.new()
	restock_btn.text = "RESTOCK (10g)"
	restock_btn.position = Vector2(350, 320)
	restock_btn.custom_minimum_size = Vector2(160, 40)
	restock_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var rs: StyleBoxFlat = StyleBoxFlat.new()
	rs.bg_color = Color(0.2, 0.4, 0.3)
	rs.corner_radius_top_left = 4
	rs.corner_radius_top_right = 4
	rs.corner_radius_bottom_left = 4
	rs.corner_radius_bottom_right = 4
	restock_btn.add_theme_stylebox_override("normal", rs)
	restock_btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	restock_btn.pressed.connect(_on_restock)
	add_child(restock_btn)

	# Next day button
	next_day_btn = Button.new()
	next_day_btn.text = "NEXT DAY"
	next_day_btn.position = Vector2(1100, 620)
	next_day_btn.custom_minimum_size = Vector2(140, 50)
	next_day_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var nd_s: StyleBoxFlat = StyleBoxFlat.new()
	nd_s.bg_color = Color(0.2, 0.2, 0.5)
	nd_s.corner_radius_top_left = 6
	nd_s.corner_radius_top_right = 6
	nd_s.corner_radius_bottom_left = 6
	nd_s.corner_radius_bottom_right = 6
	next_day_btn.add_theme_stylebox_override("normal", nd_s)
	next_day_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	next_day_btn.pressed.connect(_on_next_day)
	add_child(next_day_btn)

	_update_hud()

func _update_hud() -> void:
	gold_label.text = "Gold: " + str(gold)
	day_label.text = "Day: " + str(day) + "/" + str(max_days)
	rep_label.text = "Rep: " + str(reputation)
	var inv_text: String = "Potions:\n"
	for p in inventory.keys():
		var pname: String = p
		inv_text += "  " + pname + " x" + str(inventory[p]) + "\n"
	inventory_label.text = inv_text
	_update_ingredient_buttons()
	_update_customers_display()

func _update_ingredient_buttons() -> void:
	var keys: Array = ingredients.keys()
	for i in range(keys.size()):
		var ing_name: String = keys[i]
		if i < ingredient_buttons.size():
			ingredient_buttons[i].text = ing_name + " (" + str(ingredients[ing_name]) + ")"

func _on_ingredient_pressed(ing_name: String) -> void:
	if ingredients[ing_name] <= 0:
		msg_label.text = "Out of " + ing_name + "!"
		return
	selected_ingredients.append(ing_name)
	msg_label.text = "Selected: " + ", ".join(PackedStringArray(selected_ingredients))

func _on_brew() -> void:
	if selected_ingredients.size() < 2:
		msg_label.text = "Select at least 2 ingredients."
		return
	var sorted_sel: Array = selected_ingredients.duplicate()
	sorted_sel.sort()
	var brewed: String = ""
	for recipe_name in recipes.keys():
		var r: Array = recipes[recipe_name].duplicate()
		r.sort()
		if r == sorted_sel:
			brewed = recipe_name
			break
	if brewed == "":
		msg_label.text = "No valid recipe from those ingredients."
		selected_ingredients.clear()
		return
	# Consume ingredients
	for ing in selected_ingredients:
		ingredients[ing] -= 1
	selected_ingredients.clear()
	if not inventory.has(brewed):
		inventory[brewed] = 0
	inventory[brewed] += 1
	msg_label.text = "Brewed: " + brewed + "!"
	_update_hud()

func _on_restock() -> void:
	if gold < 10:
		msg_label.text = "Not enough gold to restock."
		return
	gold -= 10
	for k in ingredients.keys():
		ingredients[k] += 5
	msg_label.text = "Restocked all ingredients."
	_update_hud()

func _spawn_customers() -> void:
	customers.clear()
	var ailments: Array = ailment_cures.keys()
	var count: int = mini(3, ailments.size())
	for i in range(count):
		var ail: String = ailments[i]
		customers.append({"ailment": ail, "served": false})
	_update_customers_display()

func _update_customers_display() -> void:
	for lbl in customer_labels:
		lbl.queue_free()
	customer_labels.clear()
	for i in range(customers.size()):
		var c: Dictionary = customers[i]
		if c["served"]:
			continue
		var lbl: Label = Label.new()
		lbl.text = "Customer " + str(i + 1) + ": " + str(c["ailment"])
		lbl.position = Vector2(820, 140 + i * 60)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
		add_child(lbl)
		customer_labels.append(lbl)
		# Sell button
		var sell_btn: Button = Button.new()
		sell_btn.text = "Sell Cure"
		sell_btn.position = Vector2(1050, 135 + i * 60)
		sell_btn.custom_minimum_size = Vector2(100, 30)
		sell_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var ss: StyleBoxFlat = StyleBoxFlat.new()
		ss.bg_color = Color(0.4, 0.25, 0.5)
		ss.corner_radius_top_left = 4
		ss.corner_radius_top_right = 4
		ss.corner_radius_bottom_left = 4
		ss.corner_radius_bottom_right = 4
		sell_btn.add_theme_stylebox_override("normal", ss)
		sell_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
		sell_btn.pressed.connect(_on_sell.bind(i))
		add_child(sell_btn)
		customer_labels.append(sell_btn)

func _on_sell(customer_idx: int) -> void:
	if customer_idx >= customers.size():
		return
	var c: Dictionary = customers[customer_idx]
	if c["served"]:
		return
	var ail: String = c["ailment"]
	var needed: String = ailment_cures[ail]
	if not inventory.has(needed) or inventory[needed] <= 0:
		msg_label.text = "You don't have " + needed + "!"
		return
	inventory[needed] -= 1
	if inventory[needed] <= 0:
		inventory.erase(needed)
	customers[customer_idx]["served"] = true
	var price: int = potion_prices[needed]
	gold += price
	potions_sold += 1
	total_earned += price
	reputation += 5
	msg_label.text = "Sold " + needed + " for " + str(price) + "g!"
	_update_hud()

func _on_next_day() -> void:
	day += 1
	if day > max_days:
		var stats: Dictionary = {
			"gold": gold,
			"potions_sold": potions_sold,
			"total_earned": total_earned,
			"reputation": reputation,
			"days": max_days
		}
		emit_signal("game_ended", stats)
		return
	# New customers each day
	_spawn_customers()
	msg_label.text = "Day " + str(day) + " begins."
	_update_hud()
