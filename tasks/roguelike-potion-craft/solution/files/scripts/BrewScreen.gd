extends Node2D

var main: Node = null

const COLOR_BG = Color(0.07, 0.05, 0.10)
const COLOR_PANEL = Color(0.14, 0.12, 0.20)
const COLOR_ACCENT = Color(0.50, 0.75, 0.55)
const COLOR_PURPLE = Color(0.60, 0.35, 0.75)
const COLOR_TEXT = Color(0.90, 0.88, 0.82)
const COLOR_SLOT = Color(0.18, 0.16, 0.24)
const COLOR_SLOT_FILLED = Color(0.25, 0.22, 0.35)

const RECIPES = [
	{"name": "Healing Potion", "ingredients": ["Moonpetal", "Redcap"], "color": Color(0.8, 0.2, 0.3)},
	{"name": "Fire Resist Potion", "ingredients": ["Flameleaf", "Icemoss"], "color": Color(0.9, 0.5, 0.1)},
	{"name": "Invisibility Potion", "ingredients": ["Shadowroot", "Dewdrop"], "color": Color(0.4, 0.4, 0.7)},
	{"name": "Strength Elixir", "ingredients": ["Ironite", "Thornberry"], "color": Color(0.7, 0.6, 0.2)},
	{"name": "Glow Tonic", "ingredients": ["Glowcap", "Sunbloom"], "color": Color(0.9, 0.9, 0.3)},
	{"name": "Purification Brew", "ingredients": ["Crystalwort", "Ashite", "Dewdrop"], "color": Color(0.3, 0.8, 0.8)},
	{"name": "Berserker Draught", "ingredients": ["Redcap", "Flameleaf", "Ironite"], "color": Color(0.9, 0.2, 0.1)},
	{"name": "Shadow Veil", "ingredients": ["Shadowroot", "Moonpetal", "Glowcap"], "color": Color(0.3, 0.2, 0.5)},
]

var selected_ingredients: Array = []
var ingredient_buttons: Array = []
var result_label: Label = null
var recipe_list_label: Label = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "BREWING CAULDRON"
	title.position = Vector2(0, 15)
	title.size = Vector2(800, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_PURPLE)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)

	# Ingredient selection area
	var ing_title = Label.new()
	ing_title.text = "Your Ingredients (click to add to cauldron):"
	ing_title.position = Vector2(30, 70)
	ing_title.size = Vector2(700, 30)
	ing_title.add_theme_color_override("font_color", COLOR_TEXT)
	ing_title.add_theme_font_size_override("font_size", 18)
	add_child(ing_title)

	# Show unique ingredients as buttons
	var unique_ings = []
	for ing in main.inventory:
		if not unique_ings.has(ing):
			unique_ings.append(ing)

	var bx = 30
	var by = 110
	for i in range(unique_ings.size()):
		var ing_name = unique_ings[i]
		var count = main.inventory.count(ing_name)
		var btn = Button.new()
		btn.text = ing_name + " (x" + str(count) + ")"
		btn.position = Vector2(bx, by)
		btn.size = Vector2(180, 40)
		var sb = StyleBoxFlat.new()
		sb.bg_color = COLOR_SLOT
		sb.border_color = COLOR_ACCENT
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", COLOR_TEXT)
		btn.add_theme_font_size_override("font_size", 16)
		var captured_name = ing_name
		btn.pressed.connect(func(): _add_ingredient(captured_name))
		add_child(btn)
		ingredient_buttons.append(btn)
		bx += 190
		if bx > 700:
			bx = 30
			by += 50

	# Cauldron slots
	var cauldron_label = Label.new()
	cauldron_label.text = "Cauldron Slots:"
	cauldron_label.position = Vector2(30, 300)
	cauldron_label.size = Vector2(400, 30)
	cauldron_label.add_theme_color_override("font_color", COLOR_PURPLE)
	cauldron_label.add_theme_font_size_override("font_size", 20)
	add_child(cauldron_label)

	for i in range(3):
		var slot = ColorRect.new()
		slot.color = COLOR_SLOT
		slot.position = Vector2(30 + i * 160, 340)
		slot.size = Vector2(140, 60)
		add_child(slot)

	# Brew button
	var brew_btn = Button.new()
	brew_btn.text = "BREW!"
	brew_btn.position = Vector2(30, 430)
	brew_btn.size = Vector2(200, 50)
	var sb2 = StyleBoxFlat.new()
	sb2.bg_color = Color(0.25, 0.50, 0.30)
	sb2.border_color = COLOR_ACCENT
	sb2.set_border_width_all(2)
	sb2.set_corner_radius_all(6)
	brew_btn.add_theme_stylebox_override("normal", sb2)
	brew_btn.add_theme_stylebox_override("hover", sb2)
	brew_btn.add_theme_stylebox_override("pressed", sb2)
	brew_btn.add_theme_color_override("font_color", COLOR_TEXT)
	brew_btn.add_theme_font_size_override("font_size", 24)
	brew_btn.pressed.connect(_brew)
	add_child(brew_btn)

	# Clear button
	var clear_btn = Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.position = Vector2(250, 430)
	clear_btn.size = Vector2(150, 50)
	var sb3 = StyleBoxFlat.new()
	sb3.bg_color = Color(0.40, 0.15, 0.15)
	sb3.border_color = Color(0.70, 0.30, 0.30)
	sb3.set_border_width_all(2)
	sb3.set_corner_radius_all(6)
	clear_btn.add_theme_stylebox_override("normal", sb3)
	clear_btn.add_theme_stylebox_override("hover", sb3)
	clear_btn.add_theme_stylebox_override("pressed", sb3)
	clear_btn.add_theme_color_override("font_color", COLOR_TEXT)
	clear_btn.add_theme_font_size_override("font_size", 20)
	clear_btn.pressed.connect(_clear_slots)
	add_child(clear_btn)

	# Result label
	result_label = Label.new()
	result_label.text = ""
	result_label.position = Vector2(30, 500)
	result_label.size = Vector2(700, 60)
	result_label.add_theme_color_override("font_color", COLOR_ACCENT)
	result_label.add_theme_font_size_override("font_size", 22)
	add_child(result_label)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "BACK TO MAP"
	back_btn.position = Vector2(30, 640)
	back_btn.size = Vector2(200, 50)
	var sb4 = StyleBoxFlat.new()
	sb4.bg_color = COLOR_PANEL
	sb4.border_color = Color(0.50, 0.50, 0.50)
	sb4.set_border_width_all(1)
	sb4.set_corner_radius_all(4)
	back_btn.add_theme_stylebox_override("normal", sb4)
	back_btn.add_theme_stylebox_override("hover", sb4)
	back_btn.add_theme_stylebox_override("pressed", sb4)
	back_btn.add_theme_color_override("font_color", COLOR_TEXT)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(func(): main._enter_map())
	add_child(back_btn)

	# Recipe book panel (right side)
	var recipe_panel = ColorRect.new()
	recipe_panel.color = COLOR_PANEL
	recipe_panel.position = Vector2(800, 0)
	recipe_panel.size = Vector2(480, 720)
	add_child(recipe_panel)

	var rbook_title = Label.new()
	rbook_title.text = "Recipe Book"
	rbook_title.position = Vector2(820, 15)
	rbook_title.size = Vector2(440, 40)
	rbook_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rbook_title.add_theme_color_override("font_color", COLOR_PURPLE)
	rbook_title.add_theme_font_size_override("font_size", 24)
	add_child(rbook_title)

	recipe_list_label = Label.new()
	recipe_list_label.position = Vector2(820, 60)
	recipe_list_label.size = Vector2(440, 640)
	recipe_list_label.add_theme_color_override("font_color", COLOR_TEXT)
	recipe_list_label.add_theme_font_size_override("font_size", 16)
	recipe_list_label.text = _get_recipe_text()
	add_child(recipe_list_label)

	_update_slots()

var slot_labels: Array = []

func _update_slots() -> void:
	for lbl in slot_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	slot_labels = []
	for i in range(3):
		var lbl = Label.new()
		if i < selected_ingredients.size():
			lbl.text = selected_ingredients[i]
		else:
			lbl.text = "(empty)"
		lbl.position = Vector2(35 + i * 160, 350)
		lbl.size = Vector2(130, 40)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", COLOR_TEXT if i < selected_ingredients.size() else Color(0.5, 0.5, 0.5))
		lbl.add_theme_font_size_override("font_size", 14)
		add_child(lbl)
		slot_labels.append(lbl)

func _add_ingredient(ing_name: String) -> void:
	if selected_ingredients.size() >= 3:
		return
	if not main.inventory.has(ing_name):
		return
	selected_ingredients.append(ing_name)
	main.inventory.erase(ing_name)
	_update_slots()
	result_label.text = ""

func _clear_slots() -> void:
	for ing in selected_ingredients:
		main.inventory.append(ing)
	selected_ingredients = []
	_update_slots()
	result_label.text = ""

func _brew() -> void:
	if selected_ingredients.size() < 2:
		result_label.text = "Need at least 2 ingredients!"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		return

	var sorted_sel = selected_ingredients.duplicate()
	sorted_sel.sort()

	var matched_recipe = null
	for recipe in RECIPES:
		var sorted_recipe = recipe["ingredients"].duplicate()
		sorted_recipe.sort()
		if sorted_sel == sorted_recipe:
			matched_recipe = recipe
			break

	if matched_recipe != null:
		var potion_name = matched_recipe["name"]
		main.potions.append(potion_name)
		result_label.text = "Brewed: " + potion_name + "!"
		result_label.add_theme_color_override("font_color", COLOR_ACCENT)
		# Discover recipe
		var already = false
		for r in main.discovered_recipes:
			if r["name"] == potion_name:
				already = true
				break
		if not already:
			main.discovered_recipes.append(matched_recipe)
			result_label.text += " (NEW RECIPE!)"
		if recipe_list_label:
			recipe_list_label.text = _get_recipe_text()
	else:
		result_label.text = "The mixture fizzles... no potion created."
		result_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.3))
		# Return ingredients on failure
		for ing in selected_ingredients:
			main.inventory.append(ing)

	selected_ingredients = []
	_update_slots()

func _get_recipe_text() -> String:
	var text = ""
	if main.discovered_recipes.size() == 0:
		text = "No recipes discovered yet.\nExperiment by combining ingredients!"
	else:
		for r in main.discovered_recipes:
			text += r["name"] + "\n"
			text += "  = " + " + ".join(r["ingredients"]) + "\n\n"
	text += "\n--- Unknown Recipes: " + str(RECIPES.size() - main.discovered_recipes.size()) + " ---"
	return text
