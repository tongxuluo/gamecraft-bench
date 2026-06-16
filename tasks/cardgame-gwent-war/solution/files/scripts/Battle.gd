extends Node2D

const GameData = preload("res://scripts/GameData.gd")

var main: Node = null
var seed_value: int = 42
var force_pass_scenario: bool = false

const COLOR_BG = Color(0.05, 0.08, 0.05)
const COLOR_ROW_MELEE = Color(0.20, 0.12, 0.10)
const COLOR_ROW_RANGED = Color(0.12, 0.18, 0.12)
const COLOR_ROW_SIEGE = Color(0.10, 0.12, 0.20)
const COLOR_CARD_BG = Color(0.22, 0.20, 0.18)
const COLOR_CARD_HERO = Color(0.35, 0.28, 0.10)
const COLOR_CARD_SPY = Color(0.15, 0.10, 0.30)
const COLOR_CARD_WEATHER = Color(0.10, 0.20, 0.30)
const COLOR_CARD_HORN = Color(0.30, 0.25, 0.10)
const COLOR_GOLD = Color(0.82, 0.68, 0.21)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_PANEL = Color(0.15, 0.13, 0.11)
const COLOR_SELECTED = Color(0.9, 0.8, 0.2, 0.6)

# Game state
var rng = RandomNumberGenerator.new()
var player_hand: Array = []
var ai_hand: Array = []
var player_rows: Array = [[], [], []]  # melee, ranged, siege
var ai_rows: Array = [[], [], []]
var weather_active: Array = [false, false, false]  # per row
var horn_active_player: Array = [false, false, false]
var horn_active_ai: Array = [false, false, false]
var player_passed: bool = false
var ai_passed: bool = false
var player_turn: bool = true
var selected_card_index: int = -1
var round_number: int = 1

# UI references
var hand_cards: Array = []
var row_buttons: Array = []
var pass_btn: Button = null
var score_label: Label = null
var round_label: Label = null
var status_label: Label = null
var ai_timer: float = -1.0
var row_score_labels: Array = []
var ai_row_score_labels: Array = []

func _ready() -> void:
	rng.seed = seed_value
	_deal_cards()
	_build_ui()
	if not player_turn:
		ai_timer = 0.8

func _deal_cards() -> void:
	var player_deck = GameData.get_faction_deck(main.player_faction, rng)
	var ai_deck = GameData.get_ai_deck(rng)
	# Draw 10 cards each
	var draw_count = mini(10, player_deck.size())
	for i in range(draw_count):
		player_hand.append(player_deck[i])
	draw_count = mini(10, ai_deck.size())
	for i in range(draw_count):
		ai_hand.append(ai_deck[i])

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Divider line (center of board)
	var divider = ColorRect.new()
	divider.color = COLOR_GOLD
	divider.position = Vector2(100, 355)
	divider.size = Vector2(1000, 4)
	add_child(divider)

	# AI rows (top: siege=2, ranged=1, melee=0 from top)
	var ai_row_colors = [COLOR_ROW_SIEGE, COLOR_ROW_RANGED, COLOR_ROW_MELEE]
	var ai_row_names = ["AI Siege", "AI Ranged", "AI Melee"]
	for i in range(3):
		var row_bg = ColorRect.new()
		row_bg.color = ai_row_colors[i]
		row_bg.position = Vector2(100, 50 + i * 100)
		row_bg.size = Vector2(1000, 90)
		add_child(row_bg)
		var lbl = Label.new()
		lbl.text = ai_row_names[i]
		lbl.position = Vector2(105, 52 + i * 100)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
		lbl.add_theme_font_size_override("font_size", 12)
		add_child(lbl)
		var score_lbl = Label.new()
		score_lbl.text = "0"
		score_lbl.position = Vector2(1060, 70 + i * 100)
		score_lbl.size = Vector2(40, 40)
		score_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		score_lbl.add_theme_font_size_override("font_size", 22)
		add_child(score_lbl)
		ai_row_score_labels.append(score_lbl)

	# Player rows (bottom: melee=0, ranged=1, siege=2 from divider)
	var player_row_colors = [COLOR_ROW_MELEE, COLOR_ROW_RANGED, COLOR_ROW_SIEGE]
	var player_row_names = ["Melee", "Ranged", "Siege"]
	for i in range(3):
		var row_bg = ColorRect.new()
		row_bg.color = player_row_colors[i]
		row_bg.position = Vector2(100, 365 + i * 100)
		row_bg.size = Vector2(1000, 90)
		add_child(row_bg)
		var lbl = Label.new()
		lbl.text = player_row_names[i]
		lbl.position = Vector2(105, 367 + i * 100)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
		lbl.add_theme_font_size_override("font_size", 12)
		add_child(lbl)
		# Clickable row button (invisible, on top)
		var btn = Button.new()
		btn.position = Vector2(100, 365 + i * 100)
		btn.size = Vector2(1000, 90)
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		var row_idx = i
		btn.pressed.connect(_on_row_clicked.bind(row_idx))
		add_child(btn)
		row_buttons.append(btn)
		var score_lbl = Label.new()
		score_lbl.text = "0"
		score_lbl.position = Vector2(1060, 390 + i * 100)
		score_lbl.size = Vector2(40, 40)
		score_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		score_lbl.add_theme_font_size_override("font_size", 22)
		add_child(score_lbl)
		row_score_labels.append(score_lbl)

	# Score totals
	score_label = Label.new()
	score_label.position = Vector2(1120, 330)
	score_label.size = Vector2(150, 50)
	score_label.add_theme_color_override("font_color", COLOR_TEXT)
	score_label.add_theme_font_size_override("font_size", 18)
	add_child(score_label)

	# Round indicator
	round_label = Label.new()
	round_label.text = "Round " + str(round_number) + " | Wins: " + str(main.round_wins_player) + "-" + str(main.round_wins_ai)
	round_label.position = Vector2(100, 10)
	round_label.size = Vector2(400, 30)
	round_label.add_theme_color_override("font_color", COLOR_GOLD)
	round_label.add_theme_font_size_override("font_size", 18)
	add_child(round_label)

	# Status label
	status_label = Label.new()
	status_label.text = "Your turn - select a card"
	status_label.position = Vector2(500, 10)
	status_label.size = Vector2(400, 30)
	status_label.add_theme_color_override("font_color", COLOR_TEXT)
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)

	# Pass button
	pass_btn = Button.new()
	pass_btn.text = "PASS"
	pass_btn.position = Vector2(1150, 665)
	pass_btn.size = Vector2(110, 45)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.15, 0.15)
	sb.border_color = Color(0.7, 0.3, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	pass_btn.add_theme_stylebox_override("normal", sb)
	pass_btn.add_theme_stylebox_override("hover", sb)
	pass_btn.add_theme_stylebox_override("pressed", sb)
	pass_btn.add_theme_color_override("font_color", COLOR_TEXT)
	pass_btn.add_theme_font_size_override("font_size", 18)
	pass_btn.pressed.connect(_on_pass)
	add_child(pass_btn)

	_refresh_hand()
	_refresh_scores()

func _refresh_hand() -> void:
	for c in hand_cards:
		if is_instance_valid(c):
			c.queue_free()
	hand_cards.clear()
	var hand_y = 670
	var card_w = 90
	var card_h = 45
	var start_x = 20
	var spacing = 5
	for i in range(player_hand.size()):
		var card = player_hand[i]
		var panel = Button.new()
		panel.position = Vector2(start_x + i * (card_w + spacing), hand_y)
		panel.size = Vector2(card_w, card_h)
		var card_color = _get_card_color(card)
		var sb = StyleBoxFlat.new()
		sb.bg_color = card_color
		sb.border_color = COLOR_GOLD if i == selected_card_index else Color(0.4, 0.4, 0.35)
		sb.set_border_width_all(2 if i == selected_card_index else 1)
		sb.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("normal", sb)
		panel.add_theme_stylebox_override("hover", sb)
		panel.add_theme_stylebox_override("pressed", sb)
		panel.add_theme_color_override("font_color", COLOR_TEXT)
		panel.add_theme_font_size_override("font_size", 11)
		var display_name = card.name
		if card.type == GameData.CardType.UNIT or card.type == GameData.CardType.HERO:
			display_name = card.name + " (" + str(card.power) + ")"
		elif card.type == GameData.CardType.SPY:
			display_name = "SPY " + str(card.power)
		panel.text = display_name
		var idx = i
		panel.pressed.connect(_on_card_selected.bind(idx))
		add_child(panel)
		hand_cards.append(panel)

func _get_card_color(card: Dictionary) -> Color:
	match card.type:
		GameData.CardType.HERO:
			return COLOR_CARD_HERO
		GameData.CardType.SPY:
			return COLOR_CARD_SPY
		GameData.CardType.WEATHER:
			return COLOR_CARD_WEATHER
		GameData.CardType.HORN:
			return COLOR_CARD_HORN
		_:
			return COLOR_CARD_BG

func _refresh_board_cards() -> void:
	# Remove old board card labels
	for child in get_children():
		if child.is_in_group("board_card"):
			child.queue_free()
	# Draw player row cards
	for row_i in range(3):
		var cards = player_rows[row_i]
		for ci in range(cards.size()):
			var lbl = Label.new()
			lbl.add_to_group("board_card")
			var c = cards[ci]
			var effective_power = _get_effective_power(c, row_i, false)
			lbl.text = c.name.substr(0, 6) + " " + str(effective_power)
			lbl.position = Vector2(140 + ci * 85, 385 + row_i * 100)
			lbl.size = Vector2(80, 70)
			lbl.add_theme_color_override("font_color", COLOR_TEXT)
			lbl.add_theme_font_size_override("font_size", 13)
			var bg = ColorRect.new()
			bg.add_to_group("board_card")
			bg.color = _get_card_color(c).lerp(Color.BLACK, 0.2)
			bg.position = Vector2(138 + ci * 85, 383 + row_i * 100)
			bg.size = Vector2(78, 30)
			add_child(bg)
			add_child(lbl)
	# Draw AI row cards
	for row_i in range(3):
		var cards = ai_rows[row_i]
		var display_row = 2 - row_i  # AI melee at bottom of AI section
		for ci in range(cards.size()):
			var lbl = Label.new()
			lbl.add_to_group("board_card")
			var c = cards[ci]
			var effective_power = _get_effective_power(c, row_i, true)
			lbl.text = c.name.substr(0, 6) + " " + str(effective_power)
			lbl.position = Vector2(140 + ci * 85, 65 + display_row * 100)
			lbl.size = Vector2(80, 70)
			lbl.add_theme_color_override("font_color", COLOR_TEXT)
			lbl.add_theme_font_size_override("font_size", 13)
			var bg = ColorRect.new()
			bg.add_to_group("board_card")
			bg.color = _get_card_color(c).lerp(Color.BLACK, 0.2)
			bg.position = Vector2(138 + ci * 85, 63 + display_row * 100)
			bg.size = Vector2(78, 30)
			add_child(bg)
			add_child(lbl)

func _get_effective_power(card: Dictionary, row_idx: int, is_ai: bool) -> int:
	var power = card.power
	if card.type == GameData.CardType.HERO:
		return power  # immune to weather
	if weather_active[row_idx]:
		power = 1
	if is_ai and horn_active_ai[row_idx]:
		power = power * 2
	elif not is_ai and horn_active_player[row_idx]:
		power = power * 2
	return power

func _calc_row_power(cards: Array, row_idx: int, is_ai: bool) -> int:
	var total = 0
	for c in cards:
		total += _get_effective_power(c, row_idx, is_ai)
	return total

func _calc_total_power(rows: Array, is_ai: bool) -> int:
	var total = 0
	for i in range(3):
		total += _calc_row_power(rows[i], i, is_ai)
	return total

func _refresh_scores() -> void:
	var p_total = _calc_total_power(player_rows, false)
	var a_total = _calc_total_power(ai_rows, true)
	score_label.text = "You: " + str(p_total) + "\nAI: " + str(a_total)
	for i in range(3):
		row_score_labels[i].text = str(_calc_row_power(player_rows[i], i, false))
		ai_row_score_labels[i].text = str(_calc_row_power(ai_rows[i], 2 - i, true))

func _on_card_selected(idx: int) -> void:
	if not player_turn or player_passed:
		return
	selected_card_index = idx
	status_label.text = "Click a row to play card"
	_refresh_hand()

func _on_row_clicked(row_idx: int) -> void:
	if not player_turn or player_passed:
		return
	if selected_card_index < 0 or selected_card_index >= player_hand.size():
		return
	var card = player_hand[selected_card_index]
	# Validate row placement
	if card.type == GameData.CardType.WEATHER:
		_play_weather(card, row_idx)
	elif card.type == GameData.CardType.HORN:
		_play_horn(card, row_idx, false)
	elif card.type == GameData.CardType.SPY:
		_play_spy(card, row_idx)
	else:
		# Unit or Hero - must match card's row
		if card.row != row_idx:
			status_label.text = "Wrong row! This card goes to " + _row_name(card.row)
			return
		player_rows[row_idx].append(card)
	player_hand.remove_at(selected_card_index)
	selected_card_index = -1
	_after_player_play()

func _play_weather(card: Dictionary, row_idx: int) -> void:
	weather_active[row_idx] = true
	status_label.text = "Weather affects " + _row_name(row_idx) + " row!"

func _play_horn(card: Dictionary, row_idx: int, is_ai: bool) -> void:
	if is_ai:
		horn_active_ai[row_idx] = true
	else:
		horn_active_player[row_idx] = true

func _play_spy(card: Dictionary, row_idx: int) -> void:
	# Spy goes to enemy side but player draws 2
	ai_rows[card.row].append(card)
	# Draw 2 cards (from remaining deck - simulate by creating bonus cards)
	var bonus1 = {"name": "Recruit", "power": 3, "row": GameData.Row.MELEE, "type": GameData.CardType.UNIT}
	var bonus2 = {"name": "Scout", "power": 2, "row": GameData.Row.RANGED, "type": GameData.CardType.UNIT}
	player_hand.append(bonus1)
	player_hand.append(bonus2)
	status_label.text = "Spy played! Drew 2 cards."

func _row_name(row_idx: int) -> String:
	match row_idx:
		0: return "Melee"
		1: return "Ranged"
		2: return "Siege"
		_: return "Unknown"

func _after_player_play() -> void:
	_refresh_hand()
	_refresh_board_cards()
	_refresh_scores()
	player_turn = false
	if ai_passed:
		# Check if player also wants to keep going or round ends
		player_turn = true
		status_label.text = "AI passed. Play or pass to end round."
	else:
		status_label.text = "AI thinking..."
		ai_timer = 0.8

func _on_pass() -> void:
	if not player_turn or player_passed:
		return
	player_passed = true
	status_label.text = "You passed."
	if ai_passed:
		_end_round()
	else:
		player_turn = false
		ai_timer = 0.8

func _process(delta: float) -> void:
	if ai_timer > 0:
		ai_timer -= delta
		if ai_timer <= 0:
			ai_timer = -1.0
			_ai_play()

func _ai_play() -> void:
	if ai_passed:
		player_turn = true
		status_label.text = "Your turn"
		return
	if ai_hand.size() == 0:
		ai_passed = true
		status_label.text = "AI has no cards. Your turn."
		if player_passed:
			_end_round()
		else:
			player_turn = true
		return

	var p_total = _calc_total_power(player_rows, false)
	var a_total = _calc_total_power(ai_rows, true)

	# AI strategy: if ahead by a lot and player passed, pass too
	if player_passed and a_total > p_total:
		ai_passed = true
		_end_round()
		return

	# Force pass scenario for demo
	if force_pass_scenario and ai_hand.size() <= 7:
		ai_passed = true
		status_label.text = "AI passes (bluff)!"
		if player_passed:
			_end_round()
		else:
			player_turn = true
		return

	# Play strongest card that fits
	var best_idx = -1
	var best_power = -1
	for i in range(ai_hand.size()):
		var c = ai_hand[i]
		if c.type == GameData.CardType.UNIT or c.type == GameData.CardType.HERO:
			if c.power > best_power:
				best_power = c.power
				best_idx = i
	if best_idx >= 0:
		var card = ai_hand[best_idx]
		ai_rows[card.row].append(card)
		ai_hand.remove_at(best_idx)
	else:
		# Play first available special
		if ai_hand.size() > 0:
			var card = ai_hand[0]
			if card.type == GameData.CardType.WEATHER:
				weather_active[card.row] = true
			elif card.type == GameData.CardType.HORN:
				horn_active_ai[card.row] = true
			elif card.type == GameData.CardType.SPY:
				player_rows[card.row].append(card)
				var b1 = {"name": "Imp", "power": 2, "row": GameData.Row.MELEE, "type": GameData.CardType.UNIT}
				var b2 = {"name": "Shade", "power": 2, "row": GameData.Row.RANGED, "type": GameData.CardType.UNIT}
				ai_hand.append(b1)
				ai_hand.append(b2)
			ai_hand.remove_at(0)

	_refresh_board_cards()
	_refresh_scores()

	if player_passed:
		# AI keeps playing until it decides to pass
		var new_a_total = _calc_total_power(ai_rows, true)
		if new_a_total > p_total + 5:
			ai_passed = true
			_end_round()
			return
		ai_timer = 0.8
	else:
		player_turn = true
		status_label.text = "Your turn - select a card"

func _end_round() -> void:
	var p_total = _calc_total_power(player_rows, false)
	var a_total = _calc_total_power(ai_rows, true)
	var player_won = p_total >= a_total
	# Clear board for next round
	player_rows = [[], [], []]
	ai_rows = [[], [], []]
	weather_active = [false, false, false]
	horn_active_player = [false, false, false]
	horn_active_ai = [false, false, false]
	player_passed = false
	ai_passed = false
	main._enter_round_result(player_won)
