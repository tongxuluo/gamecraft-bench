extends Node2D

var main: Node = null

const COLOR_BG = Color(0.05, 0.06, 0.08)
const COLOR_PANEL = Color(0.14, 0.16, 0.19)
const COLOR_ACCENT = Color(0.55, 0.60, 0.66)
const COLOR_TEXT = Color(0.90, 0.92, 0.94)
const COLOR_RED = Color(0.85, 0.30, 0.30)
const COLOR_GREEN = Color(0.40, 0.75, 0.40)
const COLOR_GOLD = Color(0.85, 0.70, 0.30)

const TRIBE_COLORS = {
	"Beast": Color(0.6, 0.4, 0.2),
	"Undead": Color(0.4, 0.6, 0.4),
	"Mech": Color(0.5, 0.5, 0.6),
	"Dragon": Color(0.8, 0.3, 0.1),
	"Elemental": Color(0.3, 0.5, 0.8),
}

var player_units: Array = []  # {name, tribe, atk, hp, max_hp, color, sprite, hp_bar, hp_label}
var enemy_units: Array = []
var battle_log: Array = []
var battle_timer: float = 0.0
var attack_interval: float = 1.0
var attack_timer: float = 0.0
var battle_over: bool = false
var fx_root: Node2D
var log_label: Label
var status_label: Label
var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = hash(main.round_num * 777)
	_apply_synergies()
	_generate_enemy_team()
	_build_ui()
	set_process(true)

func _apply_synergies() -> void:
	# Count tribes
	var tribe_counts = {}
	for slot in main.board_slots:
		if slot != null:
			var t = slot.tribe
			if not tribe_counts.has(t):
				tribe_counts[t] = 0
			tribe_counts[t] += 1

	# Apply synergy bonuses
	for slot in main.board_slots:
		if slot == null:
			continue
		if tribe_counts.get(slot.tribe, 0) >= 3:
			match slot.tribe:
				"Beast":
					slot.atk += 2
				"Mech":
					slot.hp += 3
					slot.max_hp += 3
				"Dragon":
					slot.atk += 4

func _generate_enemy_team() -> void:
	# Scale enemy strength with round number
	var num_enemies = mini(2 + main.round_num / 2, 6)
	var stat_scale = 1.0 + main.round_num * 0.3
	var pool = [
		{"name": "Goblin", "tribe": "Beast", "atk": 2, "hp": 3},
		{"name": "Shade", "tribe": "Undead", "atk": 3, "hp": 4},
		{"name": "Automaton", "tribe": "Mech", "atk": 2, "hp": 6},
		{"name": "Firebat", "tribe": "Dragon", "atk": 4, "hp": 3},
		{"name": "Wisp", "tribe": "Elemental", "atk": 3, "hp": 3},
		{"name": "Ogre", "tribe": "Beast", "atk": 5, "hp": 8},
		{"name": "Wraith", "tribe": "Undead", "atk": 4, "hp": 5},
	]
	for i in range(num_enemies):
		var idx = rng.randi_range(0, pool.size() - 1)
		var base = pool[idx]
		var e = {
			"name": base.name,
			"tribe": base.tribe,
			"atk": int(base.atk * stat_scale),
			"hp": int(base.hp * stat_scale),
			"max_hp": int(base.hp * stat_scale),
			"color": TRIBE_COLORS[base.tribe],
		}
		enemy_units.append(e)

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Battle arena divider
	var divider = ColorRect.new()
	divider.color = COLOR_ACCENT
	divider.position = Vector2(100, 350)
	divider.size = Vector2(1080, 3)
	add_child(divider)

	var vs_label = Label.new()
	vs_label.text = "VS"
	vs_label.position = Vector2(600, 330)
	vs_label.add_theme_color_override("font_color", COLOR_RED)
	vs_label.add_theme_font_size_override("font_size", 28)
	add_child(vs_label)

	# Header
	var header = Label.new()
	header.text = "ROUND %d - BATTLE" % main.round_num
	header.position = Vector2(0, 10)
	header.size = Vector2(1280, 40)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_theme_font_size_override("font_size", 26)
	add_child(header)

	# Player side label
	var p_label = Label.new()
	p_label.text = "YOUR TEAM (HP: %d)" % main.player_hp
	p_label.position = Vector2(20, 50)
	p_label.add_theme_color_override("font_color", COLOR_GREEN)
	p_label.add_theme_font_size_override("font_size", 18)
	add_child(p_label)

	# Enemy side label
	var e_label = Label.new()
	e_label.text = "OPPONENT"
	e_label.position = Vector2(20, 380)
	e_label.add_theme_color_override("font_color", COLOR_RED)
	e_label.add_theme_font_size_override("font_size", 18)
	add_child(e_label)

	# Draw player units (top half)
	var px = 80
	for slot in main.board_slots:
		if slot == null:
			px += 140
			continue
		var unit_data = _create_unit_visual(slot, Vector2(px, 100), true)
		player_units.append(unit_data)
		px += 140

	# Draw enemy units (bottom half)
	var ex = 80
	for e in enemy_units:
		var unit_data = _create_unit_visual(e, Vector2(ex, 420), false)
		e["visual"] = unit_data
		ex += 160

	# FX layer
	fx_root = Node2D.new()
	add_child(fx_root)

	# Battle log
	var log_panel = ColorRect.new()
	log_panel.color = COLOR_PANEL
	log_panel.position = Vector2(900, 50)
	log_panel.size = Vector2(360, 300)
	add_child(log_panel)
	log_label = Label.new()
	log_label.text = "Battle starting..."
	log_label.position = Vector2(910, 60)
	log_label.size = Vector2(340, 280)
	log_label.add_theme_color_override("font_color", COLOR_TEXT)
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(log_label)

	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.position = Vector2(0, 670)
	status_label.size = Vector2(1280, 40)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", COLOR_GOLD)
	status_label.add_theme_font_size_override("font_size", 22)
	add_child(status_label)

func _create_unit_visual(data: Dictionary, pos: Vector2, is_player: bool) -> Dictionary:
	var sprite = ColorRect.new()
	sprite.color = data.color
	sprite.position = pos
	sprite.size = Vector2(100, 100)
	add_child(sprite)

	var inner = ColorRect.new()
	inner.color = data.color * Color(1.3, 1.3, 1.3)
	inner.position = pos + Vector2(10, 10)
	inner.size = Vector2(80, 60)
	add_child(inner)

	var name_lbl = Label.new()
	name_lbl.text = data.name
	name_lbl.position = pos + Vector2(5, 72)
	name_lbl.size = Vector2(90, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0, 0, 0))
	name_lbl.add_theme_font_size_override("font_size", 12)
	add_child(name_lbl)

	# HP bar background
	var hp_bg = ColorRect.new()
	hp_bg.color = Color(0.2, 0.2, 0.2)
	hp_bg.position = pos + Vector2(0, 105)
	hp_bg.size = Vector2(100, 10)
	add_child(hp_bg)

	# HP bar fill
	var hp_bar = ColorRect.new()
	hp_bar.color = COLOR_GREEN if is_player else COLOR_RED
	hp_bar.position = pos + Vector2(0, 105)
	hp_bar.size = Vector2(100, 10)
	add_child(hp_bar)

	# HP text
	var hp_lbl = Label.new()
	hp_lbl.text = "%d/%d" % [data.hp, data.max_hp]
	hp_lbl.position = pos + Vector2(0, 118)
	hp_lbl.size = Vector2(100, 20)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	hp_lbl.add_theme_font_size_override("font_size", 12)
	add_child(hp_lbl)

	# ATK indicator
	var atk_lbl = Label.new()
	atk_lbl.text = "ATK:%d" % data.atk
	atk_lbl.position = pos + Vector2(0, -18)
	atk_lbl.size = Vector2(100, 18)
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	atk_lbl.add_theme_font_size_override("font_size", 11)
	add_child(atk_lbl)

	return {
		"data": data,
		"sprite": sprite,
		"inner": inner,
		"hp_bar": hp_bar,
		"hp_label": hp_lbl,
		"name_label": name_lbl,
		"alive": true,
		"is_player": is_player,
	}

func _process(dt: float) -> void:
	if battle_over:
		return
	battle_timer += dt
	attack_timer += dt
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		_do_attack_round()

func _do_attack_round() -> void:
	# Player units attack first (front row first = lower indices)
	var alive_players = []
	for u in player_units:
		if u.alive:
			alive_players.append(u)
	var alive_enemies = []
	for e in enemy_units:
		if e.has("visual") and e.visual.alive:
			alive_enemies.append(e)

	if alive_players.size() == 0 or alive_enemies.size() == 0:
		_end_battle()
		return

	# Player attacks
	if alive_players.size() > 0 and alive_enemies.size() > 0:
		var attacker = alive_players[0]  # Front row attacks first
		var target_e = alive_enemies[0]
		var dmg = attacker.data.atk
		target_e.hp -= dmg
		if target_e.hp < 0:
			target_e.hp = 0
		_update_hp_visual(target_e.visual, target_e.hp, target_e.max_hp)
		_add_log("%s hits %s for %d dmg" % [attacker.data.name, target_e.name, dmg])
		_attack_flash(attacker.sprite, target_e.visual.sprite)
		if target_e.hp <= 0:
			_kill_unit_visual(target_e.visual)
			_add_log("%s defeated!" % target_e.name)

	# Refresh alive lists
	alive_enemies.clear()
	for e in enemy_units:
		if e.has("visual") and e.visual.alive:
			alive_enemies.append(e)

	# Enemy attacks
	if alive_enemies.size() > 0 and alive_players.size() > 0:
		var e_attacker = alive_enemies[0]
		var target_p = alive_players[0]
		var dmg = e_attacker.atk
		target_p.data.hp -= dmg
		if target_p.data.hp < 0:
			target_p.data.hp = 0
		_update_hp_visual(target_p, target_p.data.hp, target_p.data.max_hp)
		_add_log("%s hits %s for %d dmg" % [e_attacker.name, target_p.data.name, dmg])
		_attack_flash(e_attacker.visual.sprite, target_p.sprite)
		if target_p.data.hp <= 0:
			_kill_unit_visual(target_p)
			_add_log("%s defeated!" % target_p.data.name)

	# Check end conditions
	var p_alive = 0
	for u in player_units:
		if u.alive:
			p_alive += 1
	var e_alive = 0
	for e in enemy_units:
		if e.has("visual") and e.visual.alive:
			e_alive += 1
	if p_alive == 0 or e_alive == 0:
		_end_battle()

func _update_hp_visual(unit_visual: Dictionary, current_hp: int, max_hp: int) -> void:
	if not unit_visual.alive:
		return
	if is_instance_valid(unit_visual.hp_bar):
		var ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		unit_visual.hp_bar.size.x = 100.0 * ratio
	if is_instance_valid(unit_visual.hp_label):
		unit_visual.hp_label.text = "%d/%d" % [current_hp, max_hp]

func _kill_unit_visual(unit_visual: Dictionary) -> void:
	unit_visual.alive = false
	if is_instance_valid(unit_visual.sprite):
		unit_visual.sprite.color = Color(0.15, 0.15, 0.15, 0.5)
	if is_instance_valid(unit_visual.inner):
		unit_visual.inner.color = Color(0.1, 0.1, 0.1, 0.3)
	if is_instance_valid(unit_visual.hp_bar):
		unit_visual.hp_bar.size.x = 0
	# Death spark
	if is_instance_valid(unit_visual.sprite):
		_spark(unit_visual.sprite.position + Vector2(50, 50), COLOR_RED)

func _attack_flash(attacker_sprite: ColorRect, target_sprite: ColorRect) -> void:
	if is_instance_valid(attacker_sprite):
		var orig_color = attacker_sprite.color
		attacker_sprite.color = Color(1, 1, 1)
		_restore_color_delayed(attacker_sprite, orig_color)
	if is_instance_valid(target_sprite):
		_spark(target_sprite.position + Vector2(50, 50), Color(1, 0.5, 0.2))

func _restore_color_delayed(rect: ColorRect, color: Color) -> void:
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(rect):
		rect.color = color

func _spark(at: Vector2, color: Color) -> void:
	for j in range(4):
		var s = ColorRect.new()
		s.color = color
		s.size = Vector2(6, 6)
		s.position = at - Vector2(3, 3)
		fx_root.add_child(s)
		var angle = randf() * TAU
		var dist = 12.0 + randf() * 10.0
		var target = at + Vector2(cos(angle), sin(angle)) * dist
		_animate_spark(s, target)

func _animate_spark(node: ColorRect, target: Vector2) -> void:
	var t = 0.0
	var dur = 0.3
	var start_pos = node.position
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not is_instance_valid(node):
			return
		var k = clampf(t / dur, 0, 1)
		node.position = start_pos.lerp(target, k) - Vector2(3, 3)
		node.modulate.a = 1.0 - k
	if is_instance_valid(node):
		node.queue_free()

func _add_log(msg: String) -> void:
	battle_log.append(msg)
	if battle_log.size() > 12:
		battle_log = battle_log.slice(battle_log.size() - 12)
	if is_instance_valid(log_label):
		log_label.text = "\n".join(battle_log)

func _end_battle() -> void:
	battle_over = true
	var surviving_enemies = 0
	for e in enemy_units:
		if e.has("visual") and e.visual.alive:
			surviving_enemies += 1

	var player_won = surviving_enemies == 0
	if not player_won:
		# Player loses HP equal to surviving enemy units
		main.player_hp -= surviving_enemies
		status_label.text = "DEFEAT! Lost %d HP. Remaining: %d" % [surviving_enemies, main.player_hp]
	else:
		status_label.text = "VICTORY! Your team wins this round!"

	# Award gold for next round
	var base_gold = 3 + main.round_num
	var interest = mini(main.player_gold / 10, 5)
	main.player_gold += base_gold + interest

	# Check game over
	if main.player_hp <= 0:
		await get_tree().create_timer(2.0).timeout
		main._enter_result(false)
		return

	# Check if all 8 rounds done
	if main.round_num >= 8:
		await get_tree().create_timer(2.0).timeout
		main._enter_result(true)
		return

	# Advance to next round
	main.round_num += 1
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(self):
		main._enter_shop()

