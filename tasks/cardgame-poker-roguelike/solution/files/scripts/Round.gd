extends Node2D

var main: Node = null

const COLOR_FELT = Color(0.05, 0.22, 0.12)
const COLOR_CARD = Color(0.95, 0.93, 0.88)
const COLOR_CARD_SEL = Color(0.70, 0.85, 0.70)
const COLOR_GOLD = Color(0.85, 0.70, 0.20)
const COLOR_RED = Color(0.85, 0.20, 0.20)
const COLOR_BLACK = Color(0.1, 0.1, 0.1)
const COLOR_PANEL = Color(0.08, 0.08, 0.10)
const COLOR_SCORE_BG = Color(0.06, 0.15, 0.09)

const HAND_TYPES = {
	"Royal Flush": {"chips": 100, "mult": 8},
	"Straight Flush": {"chips": 80, "mult": 8},
	"Four of a Kind": {"chips": 60, "mult": 7},
	"Full House": {"chips": 40, "mult": 4},
	"Flush": {"chips": 35, "mult": 4},
	"Straight": {"chips": 30, "mult": 4},
	"Three of a Kind": {"chips": 30, "mult": 3},
	"Two Pair": {"chips": 20, "mult": 2},
	"Pair": {"chips": 10, "mult": 2},
	"High Card": {"chips": 5, "mult": 1},
}

var blind_targets = [300, 800, 2000]
var hand_cards: Array = []
var selected: Array = []
var score: int = 0
var hands_left: int = 4
var discards_left: int = 3
var card_nodes: Array = []
var score_label: Label = null
var target_label: Label = null
var hands_label: Label = null
var discards_label: Label = null
var hand_type_label: Label = null
var play_btn: Button = null
var discard_btn: Button = null
var joker_container: Node2D = null
var message_label: Label = null

func _ready() -> void:
	_build_ui()
	_deal_hand()

func _get_blind_name() -> String:
	if main.round_num == 1:
		return "Small Blind"
	elif main.round_num == 2:
		return "Big Blind"
	else:
		return "Boss Blind"

func _get_target() -> int:
	var idx = mini(main.round_num - 1, blind_targets.size() - 1)
	return blind_targets[idx]

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_FELT
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Top panel - score and blind info
	var top_panel = ColorRect.new()
	top_panel.color = COLOR_PANEL
	top_panel.size = Vector2(1280, 80)
	add_child(top_panel)

	# Blind name
	var blind_label = Label.new()
	blind_label.text = _get_blind_name()
	blind_label.position = Vector2(20, 10)
	blind_label.size = Vector2(300, 60)
	blind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blind_label.add_theme_color_override("font_color", COLOR_GOLD)
	blind_label.add_theme_font_size_override("font_size", 28)
	add_child(blind_label)

	# Target score
	target_label = Label.new()
	target_label.text = "Target: " + str(_get_target())
	target_label.position = Vector2(320, 10)
	target_label.size = Vector2(250, 60)
	target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	target_label.add_theme_font_size_override("font_size", 22)
	add_child(target_label)

	# Current score
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(580, 10)
	score_label.size = Vector2(250, 60)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	score_label.add_theme_font_size_override("font_size", 22)
	add_child(score_label)

	# Hands left
	hands_label = Label.new()
	hands_label.text = "Hands: " + str(hands_left)
	hands_label.position = Vector2(850, 10)
	hands_label.size = Vector2(150, 60)
	hands_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hands_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	hands_label.add_theme_font_size_override("font_size", 20)
	add_child(hands_label)

	# Discards left
	discards_label = Label.new()
	discards_label.text = "Discards: " + str(discards_left)
	discards_label.position = Vector2(1020, 10)
	discards_label.size = Vector2(160, 60)
	discards_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discards_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	discards_label.add_theme_font_size_override("font_size", 20)
	add_child(discards_label)

	# Gold display
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "$" + str(main.gold)
	gold_label.position = Vector2(1180, 10)
	gold_label.size = Vector2(80, 60)
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 22)
	add_child(gold_label)

	# Joker slots area
	var joker_bg = ColorRect.new()
	joker_bg.color = Color(0.04, 0.12, 0.07)
	joker_bg.position = Vector2(20, 90)
	joker_bg.size = Vector2(1240, 80)
	add_child(joker_bg)

	var joker_title = Label.new()
	joker_title.text = "JOKERS"
	joker_title.position = Vector2(30, 95)
	joker_title.size = Vector2(100, 30)
	joker_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	joker_title.add_theme_font_size_override("font_size", 14)
	add_child(joker_title)

	joker_container = Node2D.new()
	joker_container.position = Vector2(30, 120)
	add_child(joker_container)
	_draw_jokers()

	# Hand type display
	hand_type_label = Label.new()
	hand_type_label.text = "Select cards to play"
	hand_type_label.position = Vector2(0, 400)
	hand_type_label.size = Vector2(1280, 40)
	hand_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_type_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	hand_type_label.add_theme_font_size_override("font_size", 22)
	add_child(hand_type_label)

	# Play Hand button
	play_btn = _make_button("PLAY HAND", Vector2(400, 640))
	play_btn.pressed.connect(_on_play_hand)
	add_child(play_btn)

	# Discard button
	discard_btn = _make_button("DISCARD", Vector2(720, 640))
	discard_btn.pressed.connect(_on_discard)
	add_child(discard_btn)

	# Message label for scoring feedback
	message_label = Label.new()
	message_label.text = ""
	message_label.position = Vector2(0, 440)
	message_label.size = Vector2(1280, 40)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", COLOR_GOLD)
	message_label.add_theme_font_size_override("font_size", 26)
	add_child(message_label)

func _draw_jokers() -> void:
	for c in joker_container.get_children():
		c.queue_free()
	for i in range(5):
		var slot = ColorRect.new()
		slot.size = Vector2(60, 40)
		slot.position = Vector2(i * 70, 0)
		if i < main.jokers.size():
			slot.color = Color(0.6, 0.2, 0.8)
			var jlbl = Label.new()
			jlbl.text = main.jokers[i]["name"].substr(0, 3)
			jlbl.size = Vector2(60, 40)
			jlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			jlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			jlbl.add_theme_font_size_override("font_size", 12)
			jlbl.add_theme_color_override("font_color", Color(1, 1, 1))
			slot.add_child(jlbl)
		else:
			slot.color = Color(0.15, 0.15, 0.15, 0.5)
		joker_container.add_child(slot)

func _deal_hand() -> void:
	hand_cards = main.draw_cards(8)
	selected.clear()
	_render_cards()

func _render_cards() -> void:
	for n in card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	card_nodes.clear()

	var start_x = 640 - (hand_cards.size() * 75) / 2
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		var is_sel = selected.has(i)
		var card_node = _create_card_visual(card, is_sel)
		var y_pos = 510 if not is_sel else 480
		card_node.position = Vector2(start_x + i * 75, y_pos)
		card_node.set_meta("card_index", i)
		add_child(card_node)
		card_nodes.append(card_node)

	_update_hand_type_preview()

func _create_card_visual(card: Dictionary, is_selected: bool) -> Control:
	var panel = Button.new()
	panel.size = Vector2(65, 100)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_SEL if is_selected else COLOR_CARD
	sb.border_color = Color(0.3, 0.3, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("normal", sb)
	panel.add_theme_stylebox_override("hover", sb)
	panel.add_theme_stylebox_override("pressed", sb)

	var suit_color = COLOR_RED if card["suit"] in ["Hearts", "Diamonds"] else COLOR_BLACK
	var value_str = _value_to_string(card["value"])
	var suit_char = _suit_to_char(card["suit"])

	panel.text = value_str + "\n" + suit_char
	panel.add_theme_color_override("font_color", suit_color)
	panel.add_theme_font_size_override("font_size", 18)

	panel.pressed.connect(func(): _toggle_card(card))
	return panel

func _toggle_card(card: Dictionary) -> void:
	var idx = hand_cards.find(card)
	if idx == -1:
		return
	if selected.has(idx):
		selected.erase(idx)
	elif selected.size() < 5:
		selected.append(idx)
	_render_cards()

func _value_to_string(v: int) -> String:
	match v:
		14: return "A"
		13: return "K"
		12: return "Q"
		11: return "J"
		_: return str(v)

func _suit_to_char(s: String) -> String:
	match s:
		"Hearts": return "H"
		"Diamonds": return "D"
		"Clubs": return "C"
		"Spades": return "S"
		_: return "?"

func _update_hand_type_preview() -> void:
	if selected.size() == 0:
		hand_type_label.text = "Select cards to play"
		return
	var sel_cards = []
	for i in selected:
		sel_cards.append(hand_cards[i])
	var ht = _evaluate_hand(sel_cards)
	var info = HAND_TYPES[ht]
	hand_type_label.text = ht + " (" + str(info["chips"]) + " x " + str(info["mult"]) + ")"

func _on_play_hand() -> void:
	if selected.size() == 0:
		return
	hands_left -= 1
	var sel_cards = []
	for i in selected:
		sel_cards.append(hand_cards[i])
	var ht = _evaluate_hand(sel_cards)
	var info = HAND_TYPES[ht]
	var chips = info["chips"]
	var mult = info["mult"]

	# Add card values to chips
	for c in sel_cards:
		chips += mini(c["value"], 10)

	# Apply joker effects
	for joker in main.jokers:
		if joker["effect"] == "mult_add":
			mult += joker["value"]
		elif joker["effect"] == "chips_add":
			chips += joker["value"]
		elif joker["effect"] == "mult_multiply":
			mult = mult * joker["value"]

	var hand_score = chips * mult
	score += hand_score
	main.gold += 1

	message_label.text = ht + "! " + str(chips) + " x " + str(mult) + " = " + str(hand_score)
	score_label.text = "Score: " + str(score)
	hands_label.text = "Hands: " + str(hands_left)

	# Remove played cards from hand
	var indices_sorted = selected.duplicate()
	indices_sorted.sort()
	indices_sorted.reverse()
	for idx in indices_sorted:
		hand_cards.remove_at(idx)
	selected.clear()

	# Check win/lose
	if score >= _get_target():
		# Beat the blind
		await get_tree().create_timer(1.0).timeout
		if main.round_num >= 3:
			main._enter_win()
		else:
			main._enter_shop()
		return

	if hands_left <= 0:
		await get_tree().create_timer(1.0).timeout
		main._enter_lose()
		return

	# Draw back up to 8
	var need = 8 - hand_cards.size()
	if need > 0:
		var new_cards = main.draw_cards(need)
		hand_cards.append_array(new_cards)
	_render_cards()

func _on_discard() -> void:
	if selected.size() == 0 or discards_left <= 0:
		return
	discards_left -= 1
	discards_label.text = "Discards: " + str(discards_left)

	var indices_sorted = selected.duplicate()
	indices_sorted.sort()
	indices_sorted.reverse()
	for idx in indices_sorted:
		hand_cards.remove_at(idx)
	selected.clear()

	var need = 8 - hand_cards.size()
	if need > 0:
		var new_cards = main.draw_cards(need)
		hand_cards.append_array(new_cards)
	_render_cards()

func _evaluate_hand(cards: Array) -> String:
	if cards.size() == 0:
		return "High Card"
	var values = []
	var suits = []
	for c in cards:
		values.append(c["value"])
		suits.append(c["suit"])
	values.sort()

	var is_flush = cards.size() >= 5 and _all_same_suit(suits)
	var is_straight = cards.size() >= 5 and _is_straight(values)

	# Count values
	var counts = {}
	for v in values:
		if counts.has(v):
			counts[v] += 1
		else:
			counts[v] = 1

	var count_vals = counts.values()
	count_vals.sort()
	count_vals.reverse()

	if is_flush and is_straight:
		if values[-1] == 14:
			return "Royal Flush"
		return "Straight Flush"
	if count_vals.size() > 0 and count_vals[0] == 4:
		return "Four of a Kind"
	if count_vals.size() >= 2 and count_vals[0] == 3 and count_vals[1] == 2:
		return "Full House"
	if is_flush:
		return "Flush"
	if is_straight:
		return "Straight"
	if count_vals.size() > 0 and count_vals[0] == 3:
		return "Three of a Kind"
	if count_vals.size() >= 2 and count_vals[0] == 2 and count_vals[1] == 2:
		return "Two Pair"
	if count_vals.size() > 0 and count_vals[0] == 2:
		return "Pair"
	return "High Card"

func _all_same_suit(suits: Array) -> bool:
	if suits.size() == 0:
		return false
	var first = suits[0]
	for s in suits:
		if s != first:
			return false
	return true

func _is_straight(values: Array) -> bool:
	if values.size() < 5:
		return false
	var sorted_v = values.duplicate()
	sorted_v.sort()
	for i in range(1, sorted_v.size()):
		if sorted_v[i] != sorted_v[i - 1] + 1:
			# Check ace-low straight
			if i == sorted_v.size() - 1 and sorted_v[-1] == 14:
				var low = sorted_v.duplicate()
				low[-1] = 1
				low.sort()
				var ok = true
				for j in range(1, low.size()):
					if low[j] != low[j - 1] + 1:
						ok = false
						break
				return ok
			return false
	return true

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_font_size_override("font_size", 22)
	return b
