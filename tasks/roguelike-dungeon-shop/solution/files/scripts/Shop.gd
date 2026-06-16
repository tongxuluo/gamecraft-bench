extends Node2D

var main: Node = null

const COLOR_BG = Color(0.14, 0.12, 0.10)
const COLOR_SHELF = Color(0.35, 0.25, 0.15)
const COLOR_SHELF_SLOT = Color(0.25, 0.18, 0.10)
const COLOR_ITEM_WEAPON = Color(0.60, 0.65, 0.70)
const COLOR_ITEM_POTION = Color(0.30, 0.70, 0.40)
const COLOR_ITEM_ARMOR = Color(0.50, 0.45, 0.35)
const COLOR_ITEM_MAGIC = Color(0.55, 0.40, 0.80)
const COLOR_GOLD = Color(0.90, 0.75, 0.20)
const COLOR_TEXT = Color(0.95, 0.90, 0.80)
const COLOR_PANEL = Color(0.20, 0.16, 0.12)
const COLOR_CUSTOMER = Color(0.40, 0.55, 0.70)

var shelf_slots: Array = []
var inv_slots: Array = []
var dragging_item: Dictionary = {}
var dragging_from: String = ""
var dragging_index: int = -1
var drag_node: ColorRect = null

var customers: Array = []
var customer_timer: float = 0.0
var customer_spawn_interval: float = 3.0
var customers_served: int = 0
var day_timer: float = 0.0
var day_duration: float = 30.0
var day_ended: bool = false

var price_popup: Control = null
var price_item_index: int = -1

var thief_chance: float = 0.2
var thief_active: bool = false

func _ready() -> void:
	thief_chance = 0.15 + main.day * 0.05
	customer_spawn_interval = max(1.5, 3.5 - main.day * 0.3)
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Header bar
	var header = ColorRect.new()
	header.color = COLOR_PANEL
	header.size = Vector2(1280, 50)
	add_child(header)

	var day_label = Label.new()
	day_label.name = "DayLabel"
	day_label.text = "Day " + str(main.day) + " / " + str(main.MAX_DAYS)
	day_label.position = Vector2(20, 10)
	day_label.size = Vector2(200, 30)
	day_label.add_theme_color_override("font_color", COLOR_TEXT)
	day_label.add_theme_font_size_override("font_size", 22)
	add_child(day_label)

	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: " + str(main.gold)
	gold_label.position = Vector2(250, 10)
	gold_label.size = Vector2(200, 30)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 22)
	add_child(gold_label)

	var target_label = Label.new()
	target_label.name = "TargetLabel"
	target_label.text = "Target: " + str(main.DAY_TARGETS[main.day]) + "g"
	target_label.position = Vector2(480, 10)
	target_label.size = Vector2(200, 30)
	target_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	target_label.add_theme_font_size_override("font_size", 22)
	add_child(target_label)

	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "Time: " + str(int(day_duration)) + "s"
	timer_label.position = Vector2(700, 10)
	timer_label.size = Vector2(200, 30)
	timer_label.add_theme_color_override("font_color", COLOR_TEXT)
	timer_label.add_theme_font_size_override("font_size", 22)
	add_child(timer_label)

	var end_btn = Button.new()
	end_btn.name = "EndDayBtn"
	end_btn.text = "END DAY"
	end_btn.position = Vector2(1100, 5)
	end_btn.size = Vector2(160, 40)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.5, 0.25, 0.15)
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	end_btn.add_theme_stylebox_override("normal", sb)
	end_btn.add_theme_stylebox_override("hover", sb)
	end_btn.add_theme_stylebox_override("pressed", sb)
	end_btn.add_theme_color_override("font_color", COLOR_TEXT)
	end_btn.add_theme_font_size_override("font_size", 20)
	end_btn.pressed.connect(_on_end_day)
	add_child(end_btn)

	# Shelves area (top half)
	_build_shelves()

	# Inventory area (bottom)
	_build_inventory()

	# Customer area (right side)
	var cust_area = ColorRect.new()
	cust_area.color = Color(0.10, 0.12, 0.14)
	cust_area.position = Vector2(900, 60)
	cust_area.size = Vector2(370, 400)
	add_child(cust_area)

	var cust_title = Label.new()
	cust_title.text = "CUSTOMERS"
	cust_title.position = Vector2(900, 65)
	cust_title.size = Vector2(370, 30)
	cust_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cust_title.add_theme_color_override("font_color", COLOR_TEXT)
	cust_title.add_theme_font_size_override("font_size", 18)
	add_child(cust_title)

func _build_shelves() -> void:
	shelf_slots = []
	var shelf_bg = ColorRect.new()
	shelf_bg.color = COLOR_SHELF
	shelf_bg.position = Vector2(40, 70)
	shelf_bg.size = Vector2(840, 260)
	add_child(shelf_bg)

	var shelf_title = Label.new()
	shelf_title.text = "SHOP SHELVES (click item to set price)"
	shelf_title.position = Vector2(50, 75)
	shelf_title.size = Vector2(400, 25)
	shelf_title.add_theme_color_override("font_color", COLOR_TEXT)
	shelf_title.add_theme_font_size_override("font_size", 16)
	add_child(shelf_title)

	for i in range(main.max_shelves):
		var slot_x = 60 + (i % 4) * 200
		var slot_y = 110 + (i / 4) * 120
		var slot = ColorRect.new()
		slot.color = COLOR_SHELF_SLOT
		slot.position = Vector2(slot_x, slot_y)
		slot.size = Vector2(180, 100)
		slot.name = "ShelfSlot_" + str(i)
		add_child(slot)

		if i < main.shelves.size():
			var item = main.shelves[i]
			var item_rect = _make_item_display(item, Vector2(slot_x + 10, slot_y + 10))
			add_child(item_rect)

			var price_label = Label.new()
			price_label.name = "ShelfPrice_" + str(i)
			price_label.text = str(item.price) + "g"
			price_label.position = Vector2(slot_x + 10, slot_y + 75)
			price_label.size = Vector2(160, 20)
			price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price_label.add_theme_color_override("font_color", COLOR_GOLD)
			price_label.add_theme_font_size_override("font_size", 16)
			add_child(price_label)

		shelf_slots.append({"rect": Rect2(Vector2(slot_x, slot_y), Vector2(180, 100)), "index": i})

func _build_inventory() -> void:
	inv_slots = []
	var inv_bg = ColorRect.new()
	inv_bg.color = Color(0.12, 0.14, 0.12)
	inv_bg.position = Vector2(40, 480)
	inv_bg.size = Vector2(840, 220)
	add_child(inv_bg)

	var inv_title = Label.new()
	inv_title.text = "INVENTORY (drag to shelves)"
	inv_title.position = Vector2(50, 485)
	inv_title.size = Vector2(400, 25)
	inv_title.add_theme_color_override("font_color", COLOR_TEXT)
	inv_title.add_theme_font_size_override("font_size", 16)
	add_child(inv_title)

	for i in range(main.inventory.size()):
		var slot_x = 60 + (i % 4) * 200
		var slot_y = 520 + (i / 4) * 100
		var item = main.inventory[i]
		var item_rect = _make_item_display(item, Vector2(slot_x, slot_y))
		item_rect.name = "InvItem_" + str(i)
		add_child(item_rect)

		var name_label = Label.new()
		name_label.text = item.name
		name_label.position = Vector2(slot_x, slot_y + 55)
		name_label.size = Vector2(180, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", COLOR_TEXT)
		name_label.add_theme_font_size_override("font_size", 13)
		add_child(name_label)

		inv_slots.append({"rect": Rect2(Vector2(slot_x, slot_y), Vector2(180, 70)), "index": i})

func _make_item_display(item: Dictionary, pos: Vector2) -> ColorRect:
	var rect = ColorRect.new()
	var col = COLOR_ITEM_WEAPON
	match item.type:
		"potion": col = COLOR_ITEM_POTION
		"armor": col = COLOR_ITEM_ARMOR
		"magic": col = COLOR_ITEM_MAGIC
	rect.color = col
	rect.position = pos
	rect.size = Vector2(160, 50)
	return rect

func _get_item_color(item: Dictionary) -> Color:
	match item.type:
		"potion": return COLOR_ITEM_POTION
		"armor": return COLOR_ITEM_ARMOR
		"magic": return COLOR_ITEM_MAGIC
	return COLOR_ITEM_WEAPON

func _process(delta: float) -> void:
	if day_ended:
		return

	day_timer += delta
	var remaining = max(0, day_duration - day_timer)
	var timer_node = get_node_or_null("TimerLabel")
	if timer_node:
		timer_node.text = "Time: " + str(int(remaining)) + "s"

	if day_timer >= day_duration:
		_on_end_day()
		return

	# Spawn customers
	customer_timer += delta
	if customer_timer >= customer_spawn_interval and customers.size() < 3:
		customer_timer = 0.0
		_spawn_customer()

	# Process customers
	_process_customers(delta)

func _spawn_customer() -> void:
	if main.shelves.size() == 0:
		return
	var budget = randi_range(10, 30 + main.day * 10)
	var is_thief = randf() < thief_chance and main.security_level < 3
	var cy = 100 + customers.size() * 110
	var cust = {
		"budget": budget,
		"is_thief": is_thief,
		"browse_time": 0.0,
		"max_browse": randf_range(3.0, 6.0),
		"decided": false,
		"y_pos": cy,
		"node": null
	}

	var cnode = ColorRect.new()
	cnode.color = COLOR_CUSTOMER if not is_thief else Color(0.60, 0.30, 0.30)
	cnode.position = Vector2(920, cy)
	cnode.size = Vector2(50, 50)
	add_child(cnode)

	var budget_label = Label.new()
	budget_label.text = str(budget) + "g"
	budget_label.position = Vector2(980, cy + 15)
	budget_label.size = Vector2(80, 20)
	budget_label.add_theme_color_override("font_color", COLOR_GOLD)
	budget_label.add_theme_font_size_override("font_size", 16)
	add_child(budget_label)

	var type_label = Label.new()
	type_label.text = "Adventurer" if not is_thief else "???"
	type_label.position = Vector2(1070, cy + 15)
	type_label.size = Vector2(120, 20)
	type_label.add_theme_color_override("font_color", COLOR_TEXT)
	type_label.add_theme_font_size_override("font_size", 14)
	add_child(type_label)

	cust.node = cnode
	cust["budget_label"] = budget_label
	cust["type_label"] = type_label
	customers.append(cust)

func _process_customers(delta: float) -> void:
	var to_remove = []
	for i in range(customers.size()):
		var c = customers[i]
		if c.decided:
			continue
		c.browse_time += delta
		if c.browse_time >= c.max_browse:
			c.decided = true
			if c.is_thief and main.shelves.size() > 0:
				# Thief steals!
				thief_active = true
				main._enter_thief()
				return
			else:
				_customer_buy(c)
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		_remove_customer(idx)

func _customer_buy(c: Dictionary) -> void:
	# Find affordable item on shelves
	for i in range(main.shelves.size()):
		var item = main.shelves[i]
		if item.price <= c.budget:
			# Check if price is reasonable (within 1.5x base)
			if item.price <= item.base_price * 1.8:
				main.gold += item.price
				main.total_profit += item.price
				main.shelves.remove_at(i)
				customers_served += 1
				_refresh_gold()
				return
	# Customer leaves without buying (too expensive)

func _remove_customer(idx: int) -> void:
	if idx >= customers.size():
		return
	var c = customers[idx]
	if c.node and is_instance_valid(c.node):
		c.node.queue_free()
	if c.has("budget_label") and is_instance_valid(c.budget_label):
		c.budget_label.queue_free()
	if c.has("type_label") and is_instance_valid(c.type_label):
		c.type_label.queue_free()
	customers.remove_at(idx)

func _refresh_gold() -> void:
	var gold_node = get_node_or_null("GoldLabel")
	if gold_node:
		gold_node.text = "Gold: " + str(main.gold)

func _input(event: InputEvent) -> void:
	if day_ended:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		if event.pressed:
			_handle_click(pos)
		elif dragging_index >= 0:
			_handle_drop(pos)

func _handle_click(pos: Vector2) -> void:
	# Check if clicking on inventory item to drag
	for slot in inv_slots:
		if slot.rect.has_point(pos) and slot.index < main.inventory.size():
			dragging_item = main.inventory[slot.index]
			dragging_from = "inventory"
			dragging_index = slot.index
			return

	# Check if clicking on shelf item to adjust price
	for slot in shelf_slots:
		if slot.rect.has_point(pos) and slot.index < main.shelves.size():
			_show_price_popup(slot.index)
			return

func _handle_drop(pos: Vector2) -> void:
	if dragging_index < 0:
		return

	# Check if dropping on a shelf slot
	for slot in shelf_slots:
		if slot.rect.has_point(pos):
			if slot.index >= main.shelves.size() and main.shelves.size() < main.max_shelves:
				# Place item on shelf
				var item = main.inventory[dragging_index]
				main.shelves.append(item)
				main.inventory.remove_at(dragging_index)
				_rebuild()
				break

	dragging_item = {}
	dragging_from = ""
	dragging_index = -1

func _show_price_popup(shelf_idx: int) -> void:
	if price_popup and is_instance_valid(price_popup):
		price_popup.queue_free()

	price_item_index = shelf_idx
	var item = main.shelves[shelf_idx]

	price_popup = Control.new()
	price_popup.position = Vector2(400, 350)
	add_child(price_popup)

	var popup_bg = ColorRect.new()
	popup_bg.color = COLOR_PANEL
	popup_bg.size = Vector2(300, 150)
	price_popup.add_child(popup_bg)

	var border = ColorRect.new()
	border.color = COLOR_GOLD
	border.size = Vector2(304, 154)
	border.position = Vector2(-2, -2)
	price_popup.add_child(border)
	border.z_index = -1

	var name_l = Label.new()
	name_l.text = item.name + " (base: " + str(item.base_price) + "g)"
	name_l.position = Vector2(10, 10)
	name_l.size = Vector2(280, 25)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_color", COLOR_TEXT)
	name_l.add_theme_font_size_override("font_size", 16)
	price_popup.add_child(name_l)

	var price_l = Label.new()
	price_l.name = "PriceDisplay"
	price_l.text = "Price: " + str(item.price) + "g"
	price_l.position = Vector2(10, 45)
	price_l.size = Vector2(280, 30)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_l.add_theme_color_override("font_color", COLOR_GOLD)
	price_l.add_theme_font_size_override("font_size", 22)
	price_popup.add_child(price_l)

	var minus_btn = Button.new()
	minus_btn.text = "-5"
	minus_btn.position = Vector2(30, 90)
	minus_btn.size = Vector2(60, 40)
	minus_btn.pressed.connect(func(): _adjust_price(-5))
	price_popup.add_child(minus_btn)

	var minus1_btn = Button.new()
	minus1_btn.text = "-1"
	minus1_btn.position = Vector2(100, 90)
	minus1_btn.size = Vector2(40, 40)
	minus1_btn.pressed.connect(func(): _adjust_price(-1))
	price_popup.add_child(minus1_btn)

	var plus1_btn = Button.new()
	plus1_btn.text = "+1"
	plus1_btn.position = Vector2(160, 90)
	plus1_btn.size = Vector2(40, 40)
	plus1_btn.pressed.connect(func(): _adjust_price(1))
	price_popup.add_child(plus1_btn)

	var plus_btn = Button.new()
	plus_btn.text = "+5"
	plus_btn.position = Vector2(210, 90)
	plus_btn.size = Vector2(60, 40)
	plus_btn.pressed.connect(func(): _adjust_price(5))
	price_popup.add_child(plus_btn)

func _adjust_price(amount: int) -> void:
	if price_item_index < 0 or price_item_index >= main.shelves.size():
		return
	main.shelves[price_item_index].price = max(1, main.shelves[price_item_index].price + amount)
	if price_popup and is_instance_valid(price_popup):
		var pd = price_popup.get_node_or_null("PriceDisplay")
		if pd:
			pd.text = "Price: " + str(main.shelves[price_item_index].price) + "g"

func _on_end_day() -> void:
	if day_ended:
		return
	day_ended = true
	# Clean up customers
	for c in customers:
		_remove_customer_nodes(c)
	customers.clear()
	if price_popup and is_instance_valid(price_popup):
		price_popup.queue_free()
	main._end_day()

func _remove_customer_nodes(c: Dictionary) -> void:
	if c.node and is_instance_valid(c.node):
		c.node.queue_free()
	if c.has("budget_label") and is_instance_valid(c.budget_label):
		c.budget_label.queue_free()
	if c.has("type_label") and is_instance_valid(c.type_label):
		c.type_label.queue_free()

func _rebuild() -> void:
	# Quick rebuild by re-entering shop
	main._enter_shop()
