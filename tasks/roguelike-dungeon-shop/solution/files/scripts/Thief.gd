extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.06, 0.06)
const COLOR_ALERT = Color(0.80, 0.20, 0.15)
const COLOR_TEXT = Color(0.95, 0.90, 0.80)
const COLOR_THIEF = Color(0.50, 0.30, 0.30)
const COLOR_GOLD = Color(0.90, 0.75, 0.20)

var thief_pos: Vector2 = Vector2(640, 400)
var thief_speed: float = 150.0
var thief_dir: Vector2 = Vector2(1, 0)
var thief_caught: bool = false
var thief_escaped: bool = false
var escape_timer: float = 0.0
var escape_time: float = 5.0
var stolen_item: Dictionary = {}
var thief_node: ColorRect = null
var result_shown: bool = false
var change_dir_timer: float = 0.0

func _ready() -> void:
	# Pick a random item to steal
	if main.shelves.size() > 0:
		var idx = randi() % main.shelves.size()
		stolen_item = main.shelves[idx]
	else:
		stolen_item = {"name": "Unknown", "type": "weapon", "price": 10, "base_price": 10}

	thief_pos = Vector2(randi_range(200, 1000), randi_range(200, 500))
	thief_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Alert banner
	var alert_bar = ColorRect.new()
	alert_bar.color = COLOR_ALERT
	alert_bar.size = Vector2(1280, 50)
	add_child(alert_bar)

	var alert_text = Label.new()
	alert_text.text = "THIEF ALERT! Click the thief to catch them!"
	alert_text.position = Vector2(0, 10)
	alert_text.size = Vector2(1280, 30)
	alert_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_text.add_theme_color_override("font_color", COLOR_TEXT)
	alert_text.add_theme_font_size_override("font_size", 24)
	add_child(alert_text)

	var stolen_label = Label.new()
	stolen_label.text = "Stealing: " + stolen_item.name + " (" + str(stolen_item.price) + "g)"
	stolen_label.position = Vector2(0, 660)
	stolen_label.size = Vector2(1280, 30)
	stolen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stolen_label.add_theme_color_override("font_color", COLOR_GOLD)
	stolen_label.add_theme_font_size_override("font_size", 20)
	add_child(stolen_label)

	# Timer display
	var timer_label = Label.new()
	timer_label.name = "EscapeTimer"
	timer_label.text = "Escaping in: " + str(int(escape_time)) + "s"
	timer_label.position = Vector2(0, 690)
	timer_label.size = Vector2(1280, 25)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_color_override("font_color", COLOR_ALERT)
	timer_label.add_theme_font_size_override("font_size", 16)
	add_child(timer_label)

	# Thief character
	thief_node = ColorRect.new()
	thief_node.color = COLOR_THIEF
	thief_node.position = thief_pos
	thief_node.size = Vector2(60, 60)
	add_child(thief_node)

	# Thief label
	var thief_label = Label.new()
	thief_label.name = "ThiefLabel"
	thief_label.text = "THIEF"
	thief_label.position = Vector2(0, 0)
	thief_label.size = Vector2(60, 60)
	thief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thief_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thief_label.add_theme_color_override("font_color", COLOR_TEXT)
	thief_label.add_theme_font_size_override("font_size", 12)
	thief_node.add_child(thief_label)

func _process(delta: float) -> void:
	if thief_caught or thief_escaped:
		return

	escape_timer += delta
	change_dir_timer += delta

	# Change direction periodically
	if change_dir_timer > 0.8:
		change_dir_timer = 0.0
		thief_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	# Move thief
	thief_pos += thief_dir * thief_speed * delta

	# Bounce off walls
	if thief_pos.x < 50 or thief_pos.x > 1170:
		thief_dir.x = -thief_dir.x
		thief_pos.x = clamp(thief_pos.x, 50, 1170)
	if thief_pos.y < 70 or thief_pos.y > 600:
		thief_dir.y = -thief_dir.y
		thief_pos.y = clamp(thief_pos.y, 70, 600)

	if thief_node:
		thief_node.position = thief_pos

	# Update timer
	var timer_node = get_node_or_null("EscapeTimer")
	if timer_node:
		timer_node.text = "Escaping in: " + str(max(0, int(escape_time - escape_timer))) + "s"

	# Check escape
	if escape_timer >= escape_time:
		thief_escaped = true
		_on_thief_escaped()

func _input(event: InputEvent) -> void:
	if thief_caught or thief_escaped or result_shown:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos = event.position
		var thief_rect = Rect2(thief_pos, Vector2(60, 60))
		if thief_rect.has_point(click_pos):
			thief_caught = true
			_on_thief_caught()

func _on_thief_caught() -> void:
	result_shown = true
	main.thieves_caught += 1

	if thief_node:
		thief_node.color = Color(0.2, 0.6, 0.2)

	var msg = Label.new()
	msg.text = "CAUGHT! Item recovered. +5g bounty!"
	msg.position = Vector2(0, 360)
	msg.size = Vector2(1280, 50)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	msg.add_theme_font_size_override("font_size", 32)
	add_child(msg)

	main.gold += 5

	# Return to shop after delay
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): main._enter_shop())

func _on_thief_escaped() -> void:
	result_shown = true

	# Remove stolen item from shelves
	if main.shelves.size() > 0:
		var idx = randi() % main.shelves.size()
		main.shelves.remove_at(idx)

	if thief_node:
		thief_node.color = Color(0.3, 0.1, 0.1)

	var msg = Label.new()
	msg.text = "ESCAPED! Item lost: " + stolen_item.name
	msg.position = Vector2(0, 360)
	msg.size = Vector2(1280, 50)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", COLOR_ALERT)
	msg.add_theme_font_size_override("font_size", 32)
	add_child(msg)

	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): main._enter_shop())
