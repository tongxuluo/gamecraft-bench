extends Node2D

var main: Node = null

const COLOR_BG = Color(0.09, 0.07, 0.05)
const COLOR_PANEL = Color(0.16, 0.13, 0.10)
const COLOR_ACCENT = Color(0.85, 0.70, 0.30)
const COLOR_TEXT = Color(0.92, 0.90, 0.82)
const COLOR_GOOD = Color(0.40, 0.80, 0.45)
const COLOR_BAD = Color(0.85, 0.30, 0.25)

const CUSTOMER_REQUESTS = [
	"I need a Healing Potion!",
	"Do you have a Fire Resist Potion?",
	"I seek an Invisibility Potion.",
	"Give me a Strength Elixir!",
	"I require a Glow Tonic.",
	"A Purification Brew, please.",
	"I want a Berserker Draught!",
	"Do you sell Shadow Veil?",
]

const REQUEST_TO_POTION = {
	"I need a Healing Potion!": "Healing Potion",
	"Do you have a Fire Resist Potion?": "Fire Resist Potion",
	"I seek an Invisibility Potion.": "Invisibility Potion",
	"Give me a Strength Elixir!": "Strength Elixir",
	"I require a Glow Tonic.": "Glow Tonic",
	"A Purification Brew, please.": "Purification Brew",
	"I want a Berserker Draught!": "Berserker Draught",
	"Do you sell Shadow Veil?": "Shadow Veil",
}

var customers: Array = []
var customer_panels: Array = []
var feedback_label: Label = null
var stats_label: Label = null
var served_count: int = 0
var max_customers: int = 3

func _ready() -> void:
	max_customers = 2 + main.current_floor
	_generate_customers()
	_build_ui()

func _generate_customers() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = main.current_floor * 100 + main.customers_served
	customers = []
	for i in range(max_customers):
		var idx = rng.randi_range(0, CUSTOMER_REQUESTS.size() - 1)
		customers.append(CUSTOMER_REQUESTS[idx])

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "POTION SHOP - Floor " + str(main.current_floor)
	title.position = Vector2(0, 10)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)

	# Customer panels
	_draw_customers()

	# Potion inventory on the right
	var inv_panel = ColorRect.new()
	inv_panel.color = COLOR_PANEL
	inv_panel.position = Vector2(850, 70)
	inv_panel.size = Vector2(400, 400)
	add_child(inv_panel)

	var inv_title = Label.new()
	inv_title.text = "Your Potions:"
	inv_title.position = Vector2(870, 80)
	inv_title.size = Vector2(360, 30)
	inv_title.add_theme_color_override("font_color", COLOR_TEXT)
	inv_title.add_theme_font_size_override("font_size", 20)
	add_child(inv_title)

	if main.potions.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "(no potions - go brew some!)"
		empty_lbl.position = Vector2(870, 120)
		empty_lbl.size = Vector2(360, 30)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 16)
		add_child(empty_lbl)
	else:
		for i in range(main.potions.size()):
			var plbl = Label.new()
			plbl.text = str(i + 1) + ". " + main.potions[i]
			plbl.position = Vector2(870, 120 + i * 35)
			plbl.size = Vector2(360, 30)
			plbl.add_theme_color_override("font_color", COLOR_TEXT)
			plbl.add_theme_font_size_override("font_size", 18)
			add_child(plbl)

	# Feedback
	feedback_label = Label.new()
	feedback_label.text = ""
	feedback_label.position = Vector2(30, 550)
	feedback_label.size = Vector2(800, 50)
	feedback_label.add_theme_color_override("font_color", COLOR_GOOD)
	feedback_label.add_theme_font_size_override("font_size", 22)
	add_child(feedback_label)

	# Stats
	stats_label = Label.new()
	stats_label.text = "Gold: " + str(main.gold) + "  |  Reputation: " + str(main.reputation) + "/" + str(main.max_reputation)
	stats_label.position = Vector2(30, 610)
	stats_label.size = Vector2(800, 40)
	stats_label.add_theme_color_override("font_color", COLOR_TEXT)
	stats_label.add_theme_font_size_override("font_size", 20)
	add_child(stats_label)

	# Navigation buttons
	var back_btn = _make_nav_button("BACK TO MAP", Vector2(30, 660))
	back_btn.pressed.connect(func(): main._enter_map())
	add_child(back_btn)

	var brew_btn = _make_nav_button("BREW MORE", Vector2(250, 660))
	brew_btn.pressed.connect(func(): main._enter_brew())
	add_child(brew_btn)

	var next_btn = _make_nav_button("NEXT FLOOR", Vector2(470, 660))
	next_btn.pressed.connect(func(): _try_next_floor())
	add_child(next_btn)

func _draw_customers() -> void:
	for panel in customer_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	customer_panels = []

	for i in range(customers.size()):
		var container = Node2D.new()
		add_child(container)
		customer_panels.append(container)

		var panel = ColorRect.new()
		panel.color = COLOR_PANEL
		panel.position = Vector2(30, 70 + i * 150)
		panel.size = Vector2(780, 130)
		container.add_child(panel)

		# Customer icon (simple colored rect)
		var icon = ColorRect.new()
		icon.color = Color(0.5 + i * 0.15, 0.4, 0.3)
		icon.position = Vector2(50, 90 + i * 150)
		icon.size = Vector2(50, 50)
		container.add_child(icon)

		var cust_label = Label.new()
		cust_label.text = "Customer " + str(i + 1) + ":"
		cust_label.position = Vector2(120, 80 + i * 150)
		cust_label.size = Vector2(600, 30)
		cust_label.add_theme_color_override("font_color", COLOR_ACCENT)
		cust_label.add_theme_font_size_override("font_size", 18)
		container.add_child(cust_label)

		var req_label = Label.new()
		req_label.text = "\"" + customers[i] + "\""
		req_label.position = Vector2(120, 110 + i * 150)
		req_label.size = Vector2(500, 30)
		req_label.add_theme_color_override("font_color", COLOR_TEXT)
		req_label.add_theme_font_size_override("font_size", 16)
		container.add_child(req_label)

		# Sell buttons for each potion
		if main.potions.size() > 0:
			var sell_btn = Button.new()
			sell_btn.text = "SELL"
			sell_btn.position = Vector2(680, 100 + i * 150)
			sell_btn.size = Vector2(100, 40)
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.20, 0.40, 0.20)
			sb.border_color = COLOR_GOOD
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			sell_btn.add_theme_stylebox_override("normal", sb)
			sell_btn.add_theme_stylebox_override("hover", sb)
			sell_btn.add_theme_stylebox_override("pressed", sb)
			sell_btn.add_theme_color_override("font_color", COLOR_TEXT)
			sell_btn.add_theme_font_size_override("font_size", 16)
			var cust_idx = i
			sell_btn.pressed.connect(func(): _sell_to_customer(cust_idx))
			container.add_child(sell_btn)

func _sell_to_customer(cust_idx: int) -> void:
	if cust_idx >= customers.size():
		return
	if main.potions.size() == 0:
		feedback_label.text = "No potions to sell!"
		feedback_label.add_theme_color_override("font_color", COLOR_BAD)
		return

	var wanted = REQUEST_TO_POTION.get(customers[cust_idx], "")
	var sold_potion = main.potions[0]

	if sold_potion == wanted:
		main.gold += 10 + main.current_floor * 5
		main.potions.remove_at(0)
		feedback_label.text = "Perfect! Sold " + sold_potion + " for " + str(10 + main.current_floor * 5) + " gold!"
		feedback_label.add_theme_color_override("font_color", COLOR_GOOD)
		main.customers_served += 1
	else:
		main.reputation -= 1
		main.potions.remove_at(0)
		feedback_label.text = "Wrong potion! They wanted " + wanted + ". Reputation -1"
		feedback_label.add_theme_color_override("font_color", COLOR_BAD)

	customers.remove_at(cust_idx)
	served_count += 1

	stats_label.text = "Gold: " + str(main.gold) + "  |  Reputation: " + str(main.reputation) + "/" + str(main.max_reputation)

	if main.reputation <= 0:
		main._enter_game_over()
		return

	_draw_customers()

func _try_next_floor() -> void:
	if served_count >= 1:
		main._enter_floor_complete()
	else:
		feedback_label.text = "Serve at least 1 customer before advancing!"
		feedback_label.add_theme_color_override("font_color", COLOR_BAD)

func _make_nav_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 45)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = Color(0.50, 0.50, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 16)
	return b
