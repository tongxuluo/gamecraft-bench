extends Node2D

var main: Node = null
var battle_idx: int = 0

# 4 lanes, player row and opponent row
const LANES = 4
const LANE_WIDTH = 200
const LANE_START_X = 240
const PLAYER_ROW_Y = 460
const OPPONENT_ROW_Y = 180
const HAND_Y = 600
const SCALE_X = 1050
const SCALE_Y = 300

const COLOR_BG = Color(0.05, 0.04, 0.03)
const COLOR_TABLE = Color(0.12, 0.09, 0.06)
const COLOR_LANE_LINE = Color(0.20, 0.16, 0.10)
const COLOR_CARD_BG = Color(0.15, 0.12, 0.08)
const COLOR_CARD_BORDER = Color(0.45, 0.38, 0.25)
const COLOR_CARD_SELECTED = Color(0.90, 0.70, 0.20)
const COLOR_SACRIFICE = Color(0.80, 0.15, 0.15)
const COLOR_TEXT = Color(0.82, 0.76, 0.62)
const COLOR_BLOOD = Color(0.70, 0.10, 0.10)
const COLOR_SIGIL = Color(0.50, 0.75, 0.90)
const COLOR_SCALE_BG = Color(0.10, 0.08, 0.06)
const COLOR_SCALE_PLAYER = Color(0.30, 0.70, 0.40)
const COLOR_SCALE_OPPONENT = Color(0.70, 0.30, 0.30)

# Card definitions: {name, attack, health, blood_cost, sigils[]}
const CARD_DEFS = [
	{"name": "Squirrel", "attack": 0, "health": 1, "blood_cost": 0, "sigils": [], "color": Color(0.55, 0.45, 0.30)},
	{"name": "Stoat", "attack": 1, "health": 3, "blood_cost": 1, "sigils": [], "color": Color(0.60, 0.50, 0.35)},
	{"name": "Wolf", "attack": 3, "health": 2, "blood_cost": 2, "sigils": [], "color": Color(0.40, 0.40, 0.45)},
	{"name": "Adder", "attack": 1, "health": 1, "blood_cost": 1, "sigils": ["touch_of_death"], "color": Color(0.30, 0.55, 0.30)},
	{"name": "Raven", "attack": 2, "health": 1, "blood_cost": 1, "sigils": ["airborne"], "color": Color(0.20, 0.20, 0.30)},
	{"name": "Grizzly", "attack": 4, "health": 6, "blood_cost": 3, "sigils": [], "color": Color(0.50, 0.35, 0.20)},
	{"name": "Mantis", "attack": 1, "health": 1, "blood_cost": 1, "sigils": ["bifurcated_strike"], "color": Color(0.35, 0.60, 0.30)},
	{"name": "Cat", "attack": 0, "health": 1, "blood_cost": 0, "sigils": ["many_lives"], "color": Color(0.60, 0.55, 0.50)},
]

# Sigil display names
const SIGIL_NAMES = {
	"airborne": "AIR",
	"touch_of_death": "DEATH",
	"bifurcated_strike": "BIFUR",
	"many_lives": "x9",
	"mighty_leap": "LEAP",
	"unkillable": "UNDYING",
	"fledgling": "FLEDGE",
	"stinky": "STINK",
}

# Battle configurations
const BATTLES = [
	{
		"opponent_plays": [
			{"turn": 1, "lane": 0, "card_idx": 0},
			{"turn": 2, "lane": 1, "card_idx": 1},
			{"turn": 3, "lane": 2, "card_idx": 1},
			{"turn": 4, "lane": 3, "card_idx": 2},
		],
		"player_hand": [0, 0, 0, 1, 4, 3, 2],
	},
	{
		"opponent_plays": [
			{"turn": 1, "lane": 1, "card_idx": 1},
			{"turn": 1, "lane": 2, "card_idx": 0},
			{"turn": 2, "lane": 0, "card_idx": 4},
			{"turn": 3, "lane": 3, "card_idx": 2},
			{"turn": 4, "lane": 0, "card_idx": 1},
		],
		"player_hand": [0, 0, 7, 1, 6, 2, 5],
	},
]

# Game state
var player_field = [null, null, null, null]  # cards on field per lane
var opponent_field = [null, null, null, null]
var player_hand = []  # indices into CARD_DEFS
var hand_draw_idx = 0

var scale_player = 0  # damage dealt TO opponent
var scale_opponent = 0  # damage dealt TO player
var scale_diff = 0  # positive = player winning
const SCALE_WIN_THRESHOLD = 5

var current_turn = 0
var phase = "player_play"  # player_play, sacrifice_select, battle_done
var selected_hand_card = -1  # index in player_hand
var sacrifices_needed = 0
var sacrifices_done = 0
var sacrifice_targets = []  # lane indices being sacrificed
var target_lane = -1

var battle_over = false
var bell_pressed = false

# UI references
var hand_nodes = []
var field_player_nodes = [null, null, null, null]
var field_opponent_nodes = [null, null, null, null]
var scale_bar: ColorRect = null
var scale_indicator: ColorRect = null
var scale_label: Label = null
var phase_label: Label = null
var turn_label: Label = null
var info_label: Label = null
var bell_btn: Button = null

func _ready() -> void:
	var config = BATTLES[battle_idx % BATTLES.size()]
	player_hand = config.player_hand.duplicate()

	current_turn = 1
	_build_ui()
	_draw_hand()
	_opponent_turn()
	_update_phase_label()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Table surface
	var table = ColorRect.new()
	table.color = COLOR_TABLE
	table.position = Vector2(80, 100)
	table.size = Vector2(900, 440)
	add_child(table)

	# Lane dividers
	for i in range(LANES + 1):
		var line = ColorRect.new()
		line.color = COLOR_LANE_LINE
		line.position = Vector2(LANE_START_X + i * LANE_WIDTH, 120)
		line.size = Vector2(2, 400)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)

	# Row divider (center line between player and opponent)
	var mid_line = ColorRect.new()
	mid_line.color = Color(0.30, 0.22, 0.14)
	mid_line.position = Vector2(LANE_START_X, 330)
	mid_line.size = Vector2(LANES * LANE_WIDTH, 3)
	mid_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid_line)

	# Row labels
	var opp_label = Label.new()
	opp_label.text = "OPPONENT"
	opp_label.position = Vector2(LANE_START_X, 125)
	opp_label.add_theme_color_override("font_color", Color(0.55, 0.35, 0.35))
	opp_label.add_theme_font_size_override("font_size", 16)
	add_child(opp_label)

	var pl_label = Label.new()
	pl_label.text = "YOUR CREATURES"
	pl_label.position = Vector2(LANE_START_X, 345)
	pl_label.add_theme_color_override("font_color", Color(0.35, 0.55, 0.35))
	pl_label.add_theme_font_size_override("font_size", 16)
	add_child(pl_label)

	# Damage scale
	var scale_bg = ColorRect.new()
	scale_bg.color = COLOR_SCALE_BG
	scale_bg.position = Vector2(SCALE_X - 10, SCALE_Y - 80)
	scale_bg.size = Vector2(180, 200)
	add_child(scale_bg)

	var scale_title = Label.new()
	scale_title.text = "SCALE"
	scale_title.position = Vector2(SCALE_X, SCALE_Y - 75)
	scale_title.size = Vector2(160, 20)
	scale_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_title.add_theme_color_override("font_color", COLOR_TEXT)
	scale_title.add_theme_font_size_override("font_size", 18)
	add_child(scale_title)

	# Scale bar background
	var bar_track = ColorRect.new()
	bar_track.color = Color(0.20, 0.18, 0.14)
	bar_track.position = Vector2(SCALE_X + 60, SCALE_Y - 50)
	bar_track.size = Vector2(40, 140)
	add_child(bar_track)

	# Scale indicator (moves up/down)
	scale_indicator = ColorRect.new()
	scale_indicator.color = Color(0.85, 0.80, 0.60)
	scale_indicator.position = Vector2(SCALE_X + 62, SCALE_Y + 15)
	scale_indicator.size = Vector2(36, 8)
	add_child(scale_indicator)

	scale_label = Label.new()
	scale_label.text = "0"
	scale_label.position = Vector2(SCALE_X, SCALE_Y + 80)
	scale_label.size = Vector2(160, 30)
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_label.add_theme_color_override("font_color", COLOR_TEXT)
	scale_label.add_theme_font_size_override("font_size", 22)
	add_child(scale_label)

	# Phase / info labels
	phase_label = Label.new()
	phase_label.text = "YOUR TURN - Play a card"
	phase_label.position = Vector2(80, 555)
	phase_label.size = Vector2(600, 30)
	phase_label.add_theme_color_override("font_color", COLOR_TEXT)
	phase_label.add_theme_font_size_override("font_size", 20)
	add_child(phase_label)

	turn_label = Label.new()
	turn_label.text = "Turn 1"
	turn_label.position = Vector2(1050, 555)
	turn_label.size = Vector2(150, 30)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	turn_label.add_theme_font_size_override("font_size", 18)
	add_child(turn_label)

	info_label = Label.new()
	info_label.text = ""
	info_label.position = Vector2(240, 570)
	info_label.size = Vector2(700, 25)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color(0.90, 0.60, 0.30))
	info_label.add_theme_font_size_override("font_size", 16)
	add_child(info_label)

	# Bell (end turn) button
	var bell_bg = ColorRect.new()
	bell_bg.color = Color(0.25, 0.20, 0.12)
	bell_bg.position = Vector2(1050, 480)
	bell_bg.size = Vector2(140, 50)
	add_child(bell_bg)

	var bell_label = Label.new()
	bell_label.text = "RING BELL"
	bell_label.position = Vector2(1050, 490)
	bell_label.size = Vector2(140, 30)
	bell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bell_label.add_theme_color_override("font_color", COLOR_TEXT)
	bell_label.add_theme_font_size_override("font_size", 18)
	add_child(bell_label)

	bell_btn = Button.new()
	bell_btn.flat = true
	bell_btn.position = Vector2(1050, 480)
	bell_btn.size = Vector2(140, 50)
	bell_btn.pressed.connect(func(): _on_bell_pressed())
	add_child(bell_btn)

	# Lane click areas for placing cards
	for i in range(LANES):
		var lane_btn = Button.new()
		lane_btn.flat = true
		lane_btn.position = Vector2(LANE_START_X + i * LANE_WIDTH + 2, 340)
		lane_btn.size = Vector2(LANE_WIDTH - 4, 180)
		var lane_idx = i
		lane_btn.pressed.connect(func(): _on_lane_clicked(lane_idx))
		add_child(lane_btn)

	# Hand area background
	var hand_bg = ColorRect.new()
	hand_bg.color = Color(0.08, 0.06, 0.04)
	hand_bg.position = Vector2(0, HAND_Y - 10)
	hand_bg.size = Vector2(1280, 130)
	add_child(hand_bg)

func _draw_hand() -> void:
	# Clear old hand nodes
	for n in hand_nodes:
		if is_instance_valid(n):
			n.queue_free()
	hand_nodes.clear()

	var start_x = 100
	var card_w = 140
	var card_h = 100
	var gap = 10

	for i in range(player_hand.size()):
		var card_def = CARD_DEFS[player_hand[i]]
		var card_x = start_x + i * (card_w + gap)
		var card_y = HAND_Y

		# Card background
		var card_bg = ColorRect.new()
		card_bg.color = card_def.color
		card_bg.position = Vector2(card_x, card_y)
		card_bg.size = Vector2(card_w, card_h)
		add_child(card_bg)
		hand_nodes.append(card_bg)

		# Card border
		var border = ColorRect.new()
		border.color = COLOR_CARD_BORDER
		border.position = Vector2(card_x, card_y)
		border.size = Vector2(card_w, 3)
		add_child(border)
		hand_nodes.append(border)

		# Card name
		var name_lbl = Label.new()
		name_lbl.text = card_def.name
		name_lbl.position = Vector2(card_x + 5, card_y + 5)
		name_lbl.size = Vector2(card_w - 10, 20)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		name_lbl.add_theme_font_size_override("font_size", 16)
		add_child(name_lbl)
		hand_nodes.append(name_lbl)

		# Attack / Health
		var stats_lbl = Label.new()
		stats_lbl.text = "%d / %d" % [card_def.attack, card_def.health]
		stats_lbl.position = Vector2(card_x + 5, card_y + 28)
		stats_lbl.size = Vector2(card_w - 10, 20)
		stats_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		stats_lbl.add_theme_font_size_override("font_size", 14)
		add_child(stats_lbl)
		hand_nodes.append(stats_lbl)

		# Blood cost
		var cost_lbl = Label.new()
		var cost_text = "FREE" if card_def.blood_cost == 0 else "BLOOD: %d" % card_def.blood_cost
		cost_lbl.text = cost_text
		cost_lbl.position = Vector2(card_x + 5, card_y + 50)
		cost_lbl.size = Vector2(card_w - 10, 20)
		cost_lbl.add_theme_color_override("font_color", COLOR_BLOOD if card_def.blood_cost > 0 else Color(0.40, 0.60, 0.40))
		cost_lbl.add_theme_font_size_override("font_size", 13)
		add_child(cost_lbl)
		hand_nodes.append(cost_lbl)

		# Sigils
		if card_def.sigils.size() > 0:
			var sigil_lbl = Label.new()
			var sigil_texts = []
			for s in card_def.sigils:
				if SIGIL_NAMES.has(s):
					sigil_texts.append(SIGIL_NAMES[s])
			sigil_lbl.text = " ".join(sigil_texts)
			sigil_lbl.position = Vector2(card_x + 5, card_y + 72)
			sigil_lbl.size = Vector2(card_w - 10, 20)
			sigil_lbl.add_theme_color_override("font_color", COLOR_SIGIL)
			sigil_lbl.add_theme_font_size_override("font_size", 12)
			add_child(sigil_lbl)
			hand_nodes.append(sigil_lbl)

		# Click button
		var btn = Button.new()
		btn.flat = true
		btn.position = Vector2(card_x, card_y)
		btn.size = Vector2(card_w, card_h)
		var idx = i
		btn.pressed.connect(func(): _on_hand_card_clicked(idx))
		add_child(btn)
		hand_nodes.append(btn)

func _draw_field_card(lane: int, is_player: bool, card_data: Dictionary) -> void:
	var x = LANE_START_X + lane * LANE_WIDTH + 20
	var y = PLAYER_ROW_Y if is_player else OPPONENT_ROW_Y
	var w = LANE_WIDTH - 40
	var h = 120

	var container = Node2D.new()
	add_child(container)

	var card_def = card_data.def

	# Card rect
	var rect = ColorRect.new()
	rect.color = card_def.color
	rect.position = Vector2(x, y)
	rect.size = Vector2(w, h)
	container.add_child(rect)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = card_def.name
	name_lbl.position = Vector2(x + 4, y + 4)
	name_lbl.size = Vector2(w - 8, 20)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	name_lbl.add_theme_font_size_override("font_size", 15)
	container.add_child(name_lbl)

	# Stats
	var stats = Label.new()
	stats.text = "ATK:%d  HP:%d" % [card_data.attack, card_data.health]
	stats.position = Vector2(x + 4, y + 28)
	stats.size = Vector2(w - 8, 20)
	stats.add_theme_color_override("font_color", COLOR_TEXT)
	stats.add_theme_font_size_override("font_size", 13)
	container.add_child(stats)

	# Sigils
	if card_def.sigils.size() > 0:
		var sigil_lbl = Label.new()
		var sigil_texts = []
		for s in card_def.sigils:
			if SIGIL_NAMES.has(s):
				sigil_texts.append(SIGIL_NAMES[s])
		sigil_lbl.text = " ".join(sigil_texts)
		sigil_lbl.position = Vector2(x + 4, y + 50)
		sigil_lbl.size = Vector2(w - 8, 20)
		sigil_lbl.add_theme_color_override("font_color", COLOR_SIGIL)
		sigil_lbl.add_theme_font_size_override("font_size", 11)
		container.add_child(sigil_lbl)

	# Sacrifice indicator for player cards
	if is_player and phase == "sacrifice_select":
		var sac_btn = Button.new()
		sac_btn.flat = true
		sac_btn.position = Vector2(x, y)
		sac_btn.size = Vector2(w, h)
		var l = lane
		sac_btn.pressed.connect(func(): _on_sacrifice_clicked(l))
		container.add_child(sac_btn)

	if is_player:
		field_player_nodes[lane] = container
	else:
		field_opponent_nodes[lane] = container

func _on_hand_card_clicked(idx: int) -> void:
	if battle_over:
		return
	if phase != "player_play":
		return
	if idx < 0 or idx >= player_hand.size():
		return

	var card_def = CARD_DEFS[player_hand[idx]]
	selected_hand_card = idx

	if card_def.blood_cost == 0:
		# Free card - go straight to lane selection
		phase = "player_play"
		info_label.text = "Click a lane to place " + card_def.name
		_update_phase_label()
	else:
		# Need sacrifices
		sacrifices_needed = card_def.blood_cost
		sacrifices_done = 0
		sacrifice_targets.clear()
		phase = "sacrifice_select"
		info_label.text = "Sacrifice %d creature(s) - click your field cards" % sacrifices_needed
		_update_phase_label()
		_refresh_field()

func _on_sacrifice_clicked(lane: int) -> void:
	if phase != "sacrifice_select":
		return
	if player_field[lane] == null:
		return
	if sacrifice_targets.has(lane):
		return

	sacrifice_targets.append(lane)
	sacrifices_done += 1

	# Visual feedback - mark sacrificed
	if field_player_nodes[lane] != null and is_instance_valid(field_player_nodes[lane]):
		var sac_mark = ColorRect.new()
		sac_mark.color = Color(0.80, 0.10, 0.10, 0.5)
		var x = LANE_START_X + lane * LANE_WIDTH + 20
		sac_mark.position = Vector2(x, PLAYER_ROW_Y)
		sac_mark.size = Vector2(LANE_WIDTH - 40, 120)
		field_player_nodes[lane].add_child(sac_mark)

	info_label.text = "Sacrificed %d / %d" % [sacrifices_done, sacrifices_needed]

	if sacrifices_done >= sacrifices_needed:
		# Perform sacrifices
		for sl in sacrifice_targets:
			_kill_field_card(sl, true)
		sacrifice_targets.clear()
		phase = "player_play"
		info_label.text = "Now click a lane to place your card"
		_update_phase_label()
		_refresh_field()

func _on_lane_clicked(lane: int) -> void:
	if battle_over:
		return
	if phase != "player_play":
		return
	if selected_hand_card < 0:
		return
	if player_field[lane] != null:
		info_label.text = "Lane occupied! Choose another."
		return

	var card_def = CARD_DEFS[player_hand[selected_hand_card]]

	# Check if sacrifice was needed but not done
	if card_def.blood_cost > 0 and sacrifices_done < card_def.blood_cost:
		info_label.text = "Must sacrifice %d creatures first!" % card_def.blood_cost
		return

	# Place card
	var card_data = {
		"def": card_def,
		"attack": card_def.attack,
		"health": card_def.health,
		"sigils": card_def.sigils.duplicate(),
	}
	player_field[lane] = card_data
	player_hand.remove_at(selected_hand_card)
	selected_hand_card = -1
	sacrifices_done = 0
	info_label.text = card_def.name + " placed in lane " + str(lane + 1)
	_refresh_field()
	_draw_hand()

func _on_bell_pressed() -> void:
	if battle_over:
		return
	if phase == "sacrifice_select":
		# Cancel sacrifice
		phase = "player_play"
		selected_hand_card = -1
		sacrifices_done = 0
		sacrifice_targets.clear()
		info_label.text = "Cancelled. Pick a card."
		_update_phase_label()
		_refresh_field()
		return

	# End player turn -> combat phase
	selected_hand_card = -1
	_resolve_combat()

	if battle_over:
		return

	# Opponent turn
	current_turn += 1
	turn_label.text = "Turn %d" % current_turn
	_opponent_turn()

	# Draw a squirrel for free each turn
	if player_hand.size() < 10:
		player_hand.append(0)
	_draw_hand()
	_update_phase_label()

func _resolve_combat() -> void:
	# Player cards attack
	for i in range(LANES):
		if player_field[i] == null:
			continue
		var card = player_field[i]
		var atk = card.attack
		if atk <= 0:
			continue

		# Check sigils
		var is_airborne = card.sigils.has("airborne")
		var is_bifurcated = card.sigils.has("bifurcated_strike")
		var is_touch_of_death = card.sigils.has("touch_of_death")

		if is_airborne:
			# Hits directly unless opponent has mighty_leap
			var blocked = false
			if opponent_field[i] != null and opponent_field[i].sigils.has("mighty_leap"):
				blocked = true
			if not blocked:
				scale_player += atk
			else:
				_damage_opponent_card(i, atk, is_touch_of_death)
		elif is_bifurcated:
			# Hits current lane and adjacent
			var lanes_hit = [i]
			if i > 0:
				lanes_hit.append(i - 1)
			if i < LANES - 1:
				lanes_hit.append(i + 1)
			for l in lanes_hit:
				if opponent_field[l] != null:
					_damage_opponent_card(l, atk, is_touch_of_death)
				else:
					scale_player += atk
		else:
			# Normal attack
			if opponent_field[i] != null:
				_damage_opponent_card(i, atk, is_touch_of_death)
			else:
				scale_player += atk

	# Opponent cards attack
	for i in range(LANES):
		if opponent_field[i] == null:
			continue
		var card = opponent_field[i]
		var atk = card.attack
		if atk <= 0:
			continue

		if player_field[i] != null:
			_damage_player_card(i, atk)
		else:
			scale_opponent += atk

	# Update scale
	scale_diff = scale_player - scale_opponent
	_update_scale_display()

	# Check win/lose
	if scale_diff >= SCALE_WIN_THRESHOLD:
		_end_battle(true)
	elif scale_diff <= -SCALE_WIN_THRESHOLD:
		_end_battle(false)

	_refresh_field()

func _damage_opponent_card(lane: int, dmg: int, touch_of_death: bool) -> void:
	if opponent_field[lane] == null:
		return
	if touch_of_death:
		opponent_field[lane].health = 0
	else:
		opponent_field[lane].health -= dmg
	if opponent_field[lane].health <= 0:
		opponent_field[lane] = null

func _damage_player_card(lane: int, dmg: int) -> void:
	if player_field[lane] == null:
		return
	player_field[lane].health -= dmg
	if player_field[lane].health <= 0:
		var card = player_field[lane]
		# Check many_lives sigil
		if card.sigils.has("many_lives"):
			card.health = card.def.health
			# Return to hand
			player_hand.append(_find_card_idx(card.def.name))
			_draw_hand()
		player_field[lane] = null

func _kill_field_card(lane: int, is_player: bool) -> void:
	if is_player:
		var card = player_field[lane]
		if card != null and card.sigils.has("unkillable"):
			player_hand.append(_find_card_idx(card.def.name))
			_draw_hand()
		player_field[lane] = null
	else:
		opponent_field[lane] = null

func _find_card_idx(card_name: String) -> int:
	for i in range(CARD_DEFS.size()):
		if CARD_DEFS[i].name == card_name:
			return i
	return 0

func _opponent_turn() -> void:
	var config = BATTLES[battle_idx % BATTLES.size()]
	for play in config.opponent_plays:
		if play.turn == current_turn:
			var lane = play.lane
			if opponent_field[lane] == null:
				var card_def = CARD_DEFS[play.card_idx]
				opponent_field[lane] = {
					"def": card_def,
					"attack": card_def.attack,
					"health": card_def.health,
					"sigils": card_def.sigils.duplicate(),
				}
	_refresh_field()

func _update_scale_display() -> void:
	scale_label.text = "%+d" % scale_diff
	# Move indicator: center is y=SCALE_Y+15, range +-50
	var offset = clampf(float(scale_diff) / float(SCALE_WIN_THRESHOLD) * 50.0, -50.0, 50.0)
	scale_indicator.position.y = SCALE_Y + 15 - offset
	if scale_diff > 0:
		scale_indicator.color = COLOR_SCALE_PLAYER
	elif scale_diff < 0:
		scale_indicator.color = COLOR_SCALE_OPPONENT
	else:
		scale_indicator.color = Color(0.85, 0.80, 0.60)

func _update_phase_label() -> void:
	match phase:
		"player_play":
			phase_label.text = "YOUR TURN - Select a card, then a lane"
		"sacrifice_select":
			phase_label.text = "SACRIFICE - Click creatures to sacrifice"
		"battle_done":
			phase_label.text = ""

func _refresh_field() -> void:
	# Clear existing field nodes
	for i in range(LANES):
		if field_player_nodes[i] != null and is_instance_valid(field_player_nodes[i]):
			field_player_nodes[i].queue_free()
			field_player_nodes[i] = null
		if field_opponent_nodes[i] != null and is_instance_valid(field_opponent_nodes[i]):
			field_opponent_nodes[i].queue_free()
			field_opponent_nodes[i] = null

	# Redraw
	for i in range(LANES):
		if player_field[i] != null:
			_draw_field_card(i, true, player_field[i])
		if opponent_field[i] != null:
			_draw_field_card(i, false, opponent_field[i])

func _end_battle(player_won: bool) -> void:
	battle_over = true
	phase = "battle_done"

	var result_bg = ColorRect.new()
	result_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	result_bg.position = Vector2(340, 250)
	result_bg.size = Vector2(600, 200)
	add_child(result_bg)

	var result_lbl = Label.new()
	if player_won:
		result_lbl.text = "VICTORY"
		result_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.40))
	else:
		result_lbl.text = "DEFEAT"
		result_lbl.add_theme_color_override("font_color", Color(0.80, 0.25, 0.25))
	result_lbl.position = Vector2(340, 280)
	result_lbl.size = Vector2(600, 60)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 48)
	add_child(result_lbl)

	var continue_btn = Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.position = Vector2(540, 380)
	continue_btn.size = Vector2(200, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.14, 0.10)
	sb.border_color = COLOR_CARD_BORDER
	sb.set_border_width_all(2)
	continue_btn.add_theme_stylebox_override("normal", sb)
	continue_btn.add_theme_stylebox_override("hover", sb)
	continue_btn.add_theme_stylebox_override("pressed", sb)
	continue_btn.add_theme_color_override("font_color", COLOR_TEXT)
	continue_btn.add_theme_font_size_override("font_size", 22)
	continue_btn.pressed.connect(func(): main._enter_map())
	add_child(continue_btn)




