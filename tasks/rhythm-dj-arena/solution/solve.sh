#!/usr/bin/env bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scenes" "$GAME/scripts" "$GAME/demo_outputs"

# --- project.godot ---
cat > "$GAME/project.godot" << 'EOF'
; Engine configuration file.
config_version=5

[application]
config/name="Rhythm DJ Arena"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.6")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
EOF

# --- Main.tscn ---
cat > "$GAME/scenes/Main.tscn" << 'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

# --- Main.gd ---
cat > "$GAME/scripts/Main.gd" << 'GDEOF'
extends Node2D

enum State { TITLE, PLAYING, ROUND_END }

var state: int = State.TITLE
var scenario: String = "default"

var lane_keys: Array = [KEY_D, KEY_F, KEY_J, KEY_K]
var lane_count: int = 4
var lane_width: int = 60
var note_speed: float = 300.0
var hit_zone_y: float = 620.0
var spawn_interval: float = 0.6

var player_hp: float = 100.0
var opponent_hp: float = 100.0
var player_charge: float = 0.0
var max_charge: float = 100.0
var combo: int = 0
var score: int = 0

var player_notes: Array = []
var opponent_notes: Array = []
var spawn_timer: float = 0.0
var opp_spawn_timer: float = 0.0

var opp_attack_timer: float = 0.0
var opp_charge: float = 0.0

var title_panel: ColorRect
var vs_button: Button
var hud_score: Label
var hud_combo: Label
var hud_hp_player: ColorRect
var hud_hp_opponent: ColorRect
var hud_charge_bar: ColorRect
var result_label: Label

var player_lane_x: int = 160
var opponent_lane_x: int = 800

func _ready() -> void:
	_parse_args()
	_build_ui()
	if scenario == "autoplay":
		_start_game()

func _parse_args() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var a: String = args[i] as String
		if a == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1] as String
		i += 1

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.15)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	title_panel = ColorRect.new()
	title_panel.color = Color(0.1, 0.0, 0.2, 0.9)
	title_panel.position = Vector2(290, 150)
	title_panel.size = Vector2(700, 400)
	add_child(title_panel)

	var title_lbl: Label = Label.new()
	title_lbl.text = "RHYTHM DJ ARENA"
	title_lbl.position = Vector2(180, 60)
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.8))
	title_panel.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "Trade beats. Drop attacks. Win the stage."
	sub_lbl.position = Vector2(170, 130)
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 1.0))
	title_panel.add_child(sub_lbl)

	vs_button = Button.new()
	vs_button.text = "VS MODE"
	vs_button.position = Vector2(270, 250)
	vs_button.size = Vector2(160, 60)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	vs_button.add_theme_stylebox_override("normal", style)
	vs_button.add_theme_font_size_override("font_size", 24)
	vs_button.pressed.connect(_on_vs_pressed)
	title_panel.add_child(vs_button)

	hud_score = Label.new()
	hud_score.text = "SCORE: 0"
	hud_score.position = Vector2(20, 10)
	hud_score.add_theme_font_size_override("font_size", 20)
	hud_score.add_theme_color_override("font_color", Color(1, 1, 0))
	hud_score.visible = false
	add_child(hud_score)

	hud_combo = Label.new()
	hud_combo.text = "COMBO: 0"
	hud_combo.position = Vector2(20, 40)
	hud_combo.add_theme_font_size_override("font_size", 18)
	hud_combo.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	hud_combo.visible = false
	add_child(hud_combo)

	var hp_bg_p: ColorRect = ColorRect.new()
	hp_bg_p.color = Color(0.2, 0.2, 0.2)
	hp_bg_p.position = Vector2(100, 680)
	hp_bg_p.size = Vector2(200, 20)
	add_child(hp_bg_p)

	hud_hp_player = ColorRect.new()
	hud_hp_player.color = Color(0.0, 1.0, 0.4)
	hud_hp_player.position = Vector2(100, 680)
	hud_hp_player.size = Vector2(200, 20)
	hud_hp_player.visible = false
	add_child(hud_hp_player)

	var hp_bg_o: ColorRect = ColorRect.new()
	hp_bg_o.color = Color(0.2, 0.2, 0.2)
	hp_bg_o.position = Vector2(980, 680)
	hp_bg_o.size = Vector2(200, 20)
	add_child(hp_bg_o)

	hud_hp_opponent = ColorRect.new()
	hud_hp_opponent.color = Color(1.0, 0.2, 0.2)
	hud_hp_opponent.position = Vector2(980, 680)
	hud_hp_opponent.size = Vector2(200, 20)
	hud_hp_opponent.visible = false
	add_child(hud_hp_opponent)

	var charge_bg: ColorRect = ColorRect.new()
	charge_bg.color = Color(0.15, 0.15, 0.15)
	charge_bg.position = Vector2(540, 690)
	charge_bg.size = Vector2(200, 16)
	add_child(charge_bg)

	hud_charge_bar = ColorRect.new()
	hud_charge_bar.color = Color(1.0, 0.0, 1.0)
	hud_charge_bar.position = Vector2(540, 690)
	hud_charge_bar.size = Vector2(0, 16)
	hud_charge_bar.visible = false
	add_child(hud_charge_bar)

	# Lane backgrounds
	var divider_p: ColorRect = ColorRect.new()
	divider_p.color = Color(0.3, 0.0, 0.5)
	divider_p.position = Vector2(player_lane_x - 10, 0)
	divider_p.size = Vector2(lane_count * lane_width + 20, 720)
	add_child(divider_p)
	move_child(divider_p, 1)

	var divider_o: ColorRect = ColorRect.new()
	divider_o.color = Color(0.5, 0.0, 0.3)
	divider_o.position = Vector2(opponent_lane_x - 10, 0)
	divider_o.size = Vector2(lane_count * lane_width + 20, 720)
	add_child(divider_o)
	move_child(divider_o, 1)

	var hz_p: ColorRect = ColorRect.new()
	hz_p.color = Color(1, 1, 1, 0.3)
	hz_p.position = Vector2(player_lane_x - 10, hit_zone_y - 5)
	hz_p.size = Vector2(lane_count * lane_width + 20, 10)
	add_child(hz_p)

	var hz_o: ColorRect = ColorRect.new()
	hz_o.color = Color(1, 1, 1, 0.3)
	hz_o.position = Vector2(opponent_lane_x - 10, hit_zone_y - 5)
	hz_o.size = Vector2(lane_count * lane_width + 20, 10)
	add_child(hz_o)

	result_label = Label.new()
	result_label.text = ""
	result_label.position = Vector2(440, 300)
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_color", Color(1, 1, 0))
	result_label.visible = false
	add_child(result_label)

func _on_vs_pressed() -> void:
	_start_game()

func _start_game() -> void:
	state = State.PLAYING
	title_panel.visible = false
	hud_score.visible = true
	hud_combo.visible = true
	hud_hp_player.visible = true
	hud_hp_opponent.visible = true
	hud_charge_bar.visible = true

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	_spawn_notes(delta)
	_move_notes(delta)
	_opponent_ai(delta)
	_update_hud()
	_check_round_end()

func _spawn_notes(delta: float) -> void:
	spawn_timer += delta
	opp_spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var lane: int = randi() % lane_count
		var note: ColorRect = ColorRect.new()
		note.color = Color(0.0, 1.0, 1.0)
		note.size = Vector2(50, 20)
		note.position = Vector2(player_lane_x + lane * lane_width, -20)
		note.set_meta("lane", lane)
		add_child(note)
		player_notes.append(note)
	if opp_spawn_timer >= spawn_interval * 0.9:
		opp_spawn_timer = 0.0
		var lane: int = randi() % lane_count
		var note: ColorRect = ColorRect.new()
		note.color = Color(1.0, 0.4, 0.0)
		note.size = Vector2(50, 20)
		note.position = Vector2(opponent_lane_x + lane * lane_width, -20)
		note.set_meta("lane", lane)
		add_child(note)
		opponent_notes.append(note)

func _move_notes(delta: float) -> void:
	var to_remove_p: Array = []
	for n in player_notes:
		var note: ColorRect = n as ColorRect
		note.position.y += note_speed * delta
		if note.position.y > 720:
			to_remove_p.append(note)
			combo = 0
	for n in to_remove_p:
		var note: ColorRect = n as ColorRect
		player_notes.erase(note)
		note.queue_free()
	var to_remove_o: Array = []
	for n in opponent_notes:
		var note: ColorRect = n as ColorRect
		note.position.y += note_speed * delta
		if note.position.y > hit_zone_y:
			to_remove_o.append(note)
			opp_charge = min(opp_charge + 15.0, max_charge)
	for n in to_remove_o:
		var note: ColorRect = n as ColorRect
		opponent_notes.erase(note)
		note.queue_free()

func _input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev: InputEventKey = event as InputEventKey
		if kev.keycode == KEY_SPACE:
			_player_attack()
			return
		var lane: int = -1
		if kev.keycode == KEY_D:
			lane = 0
		elif kev.keycode == KEY_F:
			lane = 1
		elif kev.keycode == KEY_J:
			lane = 2
		elif kev.keycode == KEY_K:
			lane = 3
		if lane >= 0:
			_try_hit(lane)

func _try_hit(lane: int) -> void:
	var best_note: ColorRect = null
	var best_dist: float = 999.0
	for n in player_notes:
		var note: ColorRect = n as ColorRect
		var nl: int = note.get_meta("lane") as int
		if nl == lane:
			var dist: float = abs(note.position.y - hit_zone_y)
			if dist < 60.0 and dist < best_dist:
				best_dist = dist
				best_note = note
	if best_note != null:
		player_notes.erase(best_note)
		best_note.queue_free()
		combo += 1
		score += 100 * combo
		player_charge = min(player_charge + 12.0, max_charge)

func _player_attack() -> void:
	if player_charge >= max_charge:
		player_charge = 0.0
		opponent_hp -= 25.0

func _opponent_ai(delta: float) -> void:
	opp_attack_timer += delta
	if opp_charge >= max_charge and opp_attack_timer > 3.0:
		opp_charge = 0.0
		opp_attack_timer = 0.0
		player_hp -= 20.0

func _update_hud() -> void:
	hud_score.text = "SCORE: " + str(score)
	hud_combo.text = "COMBO: " + str(combo)
	var p_width: float = (player_hp / 100.0) * 200.0
	hud_hp_player.size = Vector2(max(p_width, 0.0), 20)
	var o_width: float = (opponent_hp / 100.0) * 200.0
	hud_hp_opponent.size = Vector2(max(o_width, 0.0), 20)
	var c_width: float = (player_charge / max_charge) * 200.0
	hud_charge_bar.size = Vector2(c_width, 16)

func _check_round_end() -> void:
	if player_hp <= 0.0:
		state = State.ROUND_END
		result_label.text = "OPPONENT WINS!"
		result_label.visible = true
	elif opponent_hp <= 0.0:
		state = State.ROUND_END
		result_label.text = "YOU WIN!"
		result_label.visible = true
GDEOF

# --- Demo traces ---
cat > "$GAME/demo_outputs/title_screen.json" << 'EOF'
{"duration_frames": 360, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}]}
EOF

cat > "$GAME/demo_outputs/gameplay_combo.json" << 'EOF'
{"duration_frames": 600, "events": [{"frame": 30, "type": "wait"}, {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 150, "type": "key_press", "keycode": "D"}, {"frame": 180, "type": "key_press", "keycode": "F"}, {"frame": 210, "type": "key_press", "keycode": "J"}, {"frame": 240, "type": "key_press", "keycode": "K"}, {"frame": 270, "type": "key_press", "keycode": "D"}, {"frame": 300, "type": "key_press", "keycode": "F"}, {"frame": 330, "type": "key_press", "keycode": "J"}, {"frame": 360, "type": "key_press", "keycode": "K"}, {"frame": 400, "type": "key_press", "keycode": "SPACE"}]}
EOF

cat > "$GAME/demo_outputs/attack_win.json" << 'EOF'
{"duration_frames": 900, "events": [{"frame": 30, "type": "wait"}, {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 120, "type": "key_press", "keycode": "D"}, {"frame": 150, "type": "key_press", "keycode": "F"}, {"frame": 180, "type": "key_press", "keycode": "J"}, {"frame": 210, "type": "key_press", "keycode": "K"}, {"frame": 250, "type": "key_press", "keycode": "SPACE"}, {"frame": 350, "type": "key_press", "keycode": "D"}, {"frame": 380, "type": "key_press", "keycode": "F"}, {"frame": 410, "type": "key_press", "keycode": "J"}, {"frame": 440, "type": "key_press", "keycode": "K"}, {"frame": 480, "type": "key_press", "keycode": "SPACE"}, {"frame": 580, "type": "key_press", "keycode": "D"}, {"frame": 610, "type": "key_press", "keycode": "F"}, {"frame": 640, "type": "key_press", "keycode": "J"}, {"frame": 670, "type": "key_press", "keycode": "K"}, {"frame": 710, "type": "key_press", "keycode": "SPACE"}, {"frame": 800, "type": "key_press", "keycode": "D"}, {"frame": 830, "type": "key_press", "keycode": "F"}, {"frame": 860, "type": "key_press", "keycode": "SPACE"}]}
EOF

echo "rhythm-dj-arena solution written to $GAME"
