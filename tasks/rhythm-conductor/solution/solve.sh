#!/usr/bin/env bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scenes" "$GAME/scripts" "$GAME/demo_outputs"

# --- project.godot ---
cat > "$GAME/project.godot" << 'EOF'
; Engine configuration file.
; Do not edit by hand.

config_version=5

[application]
config/name="Rhythm Conductor"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.6")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

# --- scenes/Main.tscn ---
cat > "$GAME/scenes/Main.tscn" << 'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

# --- scripts/Main.gd ---
cat > "$GAME/scripts/Main.gd" << 'GDEOF'
extends Node2D

enum State { TITLE, BATTLE, LEVELUP, GAMEOVER }

var state: int = State.TITLE
var wave: int = 1
var max_waves: int = 3
var troop_hp: float = 100.0
var enemy_hp: float = 100.0
var beat_timer: float = 0.0
var beat_interval: float = 0.8
var beat_phase: float = 0.0
var combo: int = 0
var commands: Array = ["MARCH", "ATTACK", "DEFEND", "CHARGE"]
var cmd_buttons: Array = []
var pending_command: String = ""
var command_timer: float = 0.0
var enemy_attack_timer: float = 0.0
var scenario: String = "default"

var bg_rect: ColorRect
var title_label: Label
var campaign_btn: Button
var hud_wave: Label
var hud_troop: Label
var hud_enemy: Label
var hud_combo: Label
var beat_indicator: ColorRect
var cmd_panel: ColorRect
var troop_rect: ColorRect
var enemy_rect: ColorRect
var levelup_label: Label
var continue_btn: Button
var gameover_label: Label

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]
	_build_ui()
	_show_title()

func _build_ui() -> void:
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.1, 0.08, 0.12)
	bg_rect.position = Vector2.ZERO
	bg_rect.size = Vector2(1280, 720)
	add_child(bg_rect)

	title_label = Label.new()
	title_label.text = "RHYTHM CONDUCTOR"
	title_label.position = Vector2(440, 200)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	add_child(title_label)

	campaign_btn = Button.new()
	campaign_btn.text = "CAMPAIGN"
	campaign_btn.position = Vector2(540, 400)
	campaign_btn.size = Vector2(200, 60)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.6, 0.15, 0.1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	campaign_btn.add_theme_stylebox_override("normal", sb)
	campaign_btn.pressed.connect(_on_campaign)
	add_child(campaign_btn)

	hud_wave = Label.new()
	hud_wave.position = Vector2(20, 10)
	hud_wave.add_theme_font_size_override("font_size", 22)
	hud_wave.visible = false
	add_child(hud_wave)

	hud_troop = Label.new()
	hud_troop.position = Vector2(20, 40)
	hud_troop.add_theme_font_size_override("font_size", 20)
	hud_troop.visible = false
	add_child(hud_troop)

	hud_enemy = Label.new()
	hud_enemy.position = Vector2(20, 68)
	hud_enemy.add_theme_font_size_override("font_size", 20)
	hud_enemy.visible = false
	add_child(hud_enemy)

	hud_combo = Label.new()
	hud_combo.position = Vector2(1100, 10)
	hud_combo.add_theme_font_size_override("font_size", 22)
	hud_combo.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	hud_combo.visible = false
	add_child(hud_combo)

	beat_indicator = ColorRect.new()
	beat_indicator.size = Vector2(40, 40)
	beat_indicator.position = Vector2(620, 520)
	beat_indicator.color = Color(0.3, 0.3, 0.3)
	beat_indicator.visible = false
	add_child(beat_indicator)

	troop_rect = ColorRect.new()
	troop_rect.size = Vector2(120, 180)
	troop_rect.position = Vector2(150, 250)
	troop_rect.color = Color(0.2, 0.5, 0.8)
	troop_rect.visible = false
	add_child(troop_rect)

	enemy_rect = ColorRect.new()
	enemy_rect.size = Vector2(120, 180)
	enemy_rect.position = Vector2(1000, 250)
	enemy_rect.color = Color(0.7, 0.2, 0.2)
	enemy_rect.visible = false
	add_child(enemy_rect)

	cmd_panel = ColorRect.new()
	cmd_panel.size = Vector2(1280, 120)
	cmd_panel.position = Vector2(0, 600)
	cmd_panel.color = Color(0.15, 0.12, 0.18)
	cmd_panel.visible = false
	add_child(cmd_panel)

	for i in range(4):
		var btn: Button = Button.new()
		btn.text = commands[i]
		btn.position = Vector2(140 + i * 260, 620)
		btn.size = Vector2(200, 70)
		var bsb: StyleBoxFlat = StyleBoxFlat.new()
		bsb.bg_color = Color(0.25, 0.2, 0.35)
		bsb.corner_radius_top_left = 6
		bsb.corner_radius_top_right = 6
		bsb.corner_radius_bottom_left = 6
		bsb.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", bsb)
		btn.pressed.connect(_on_command.bind(commands[i]))
		btn.visible = false
		add_child(btn)
		cmd_buttons.append(btn)

	levelup_label = Label.new()
	levelup_label.text = "WAVE COMPLETE - LEVEL UP!"
	levelup_label.position = Vector2(400, 280)
	levelup_label.add_theme_font_size_override("font_size", 36)
	levelup_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	levelup_label.visible = false
	add_child(levelup_label)

	continue_btn = Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.position = Vector2(540, 400)
	continue_btn.size = Vector2(200, 60)
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	add_child(continue_btn)

	gameover_label = Label.new()
	gameover_label.text = "VICTORY!"
	gameover_label.position = Vector2(500, 300)
	gameover_label.add_theme_font_size_override("font_size", 48)
	gameover_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	gameover_label.visible = false
	add_child(gameover_label)

func _show_title() -> void:
	state = State.TITLE
	title_label.visible = true
	campaign_btn.visible = true
	_hide_battle()
	levelup_label.visible = false
	continue_btn.visible = false
	gameover_label.visible = false

func _hide_battle() -> void:
	hud_wave.visible = false
	hud_troop.visible = false
	hud_enemy.visible = false
	hud_combo.visible = false
	beat_indicator.visible = false
	troop_rect.visible = false
	enemy_rect.visible = false
	cmd_panel.visible = false
	for btn in cmd_buttons:
		btn.visible = false

func _show_battle() -> void:
	state = State.BATTLE
	title_label.visible = false
	campaign_btn.visible = false
	levelup_label.visible = false
	continue_btn.visible = false
	gameover_label.visible = false
	hud_wave.visible = true
	hud_troop.visible = true
	hud_enemy.visible = true
	hud_combo.visible = true
	beat_indicator.visible = true
	troop_rect.visible = true
	enemy_rect.visible = true
	cmd_panel.visible = true
	for btn in cmd_buttons:
		btn.visible = true
	enemy_hp = 80.0 + wave * 20.0
	enemy_attack_timer = 0.0
	combo = 0
	_update_hud()

func _on_campaign() -> void:
	wave = 1
	troop_hp = 100.0
	_show_battle()

func _on_command(cmd: String) -> void:
	if state != State.BATTLE:
		return
	var timing_quality: float = abs(beat_phase - 0.5)
	if timing_quality < 0.2:
		combo += 1
		beat_indicator.color = Color(0.2, 0.9, 0.3)
	else:
		combo = 0
		beat_indicator.color = Color(0.9, 0.3, 0.2)

	var multiplier: float = 1.0 + combo * 0.15
	if cmd == "ATTACK":
		enemy_hp -= 12.0 * multiplier
	elif cmd == "CHARGE":
		enemy_hp -= 20.0 * multiplier
		troop_hp -= 5.0
	elif cmd == "DEFEND":
		troop_hp = min(troop_hp + 3.0, 100.0)
	elif cmd == "MARCH":
		enemy_hp -= 5.0 * multiplier

	pending_command = cmd
	command_timer = 0.3
	_check_wave_end()
	_update_hud()

func _check_wave_end() -> void:
	if enemy_hp <= 0.0:
		if wave >= max_waves:
			_show_gameover()
		else:
			_show_levelup()
	elif troop_hp <= 0.0:
		gameover_label.text = "DEFEAT..."
		gameover_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		_show_gameover()

func _show_levelup() -> void:
	state = State.LEVELUP
	_hide_battle()
	levelup_label.visible = true
	continue_btn.visible = true

func _on_continue() -> void:
	wave += 1
	troop_hp = min(troop_hp + 30.0, 100.0)
	_show_battle()

func _show_gameover() -> void:
	state = State.GAMEOVER
	_hide_battle()
	gameover_label.visible = true

func _update_hud() -> void:
	hud_wave.text = "Wave: %d / %d" % [wave, max_waves]
	hud_troop.text = "Troops HP: %d" % int(troop_hp)
	hud_enemy.text = "Enemy HP: %d" % int(max(enemy_hp, 0.0))
	hud_combo.text = "Combo: x%d" % combo

func _process(delta: float) -> void:
	if state != State.BATTLE:
		return
	beat_timer += delta
	beat_phase = fmod(beat_timer, beat_interval) / beat_interval
	var brightness: float = 1.0 - abs(beat_phase - 0.5) * 2.0
	if pending_command == "":
		beat_indicator.color = Color(brightness * 0.8, brightness * 0.6, brightness * 0.2)

	if command_timer > 0.0:
		command_timer -= delta
		if command_timer <= 0.0:
			pending_command = ""

	enemy_attack_timer += delta
	if enemy_attack_timer >= 2.5:
		enemy_attack_timer = 0.0
		troop_hp -= 8.0
		_check_wave_end()
		_update_hud()
GDEOF

# --- demo_outputs ---
cat > "$GAME/demo_outputs/demo_title_to_battle.json" << 'EOF'
{"duration_frames": 360, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}]}
EOF

cat > "$GAME/demo_outputs/demo_attack_rhythm.json" << 'EOF'
{"duration_frames": 360, "events": [{"frame": 30, "type": "wait"}, {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 400, "y": 655}, {"frame": 168, "type": "mouse_click", "button": "left", "x": 400, "y": 655}, {"frame": 216, "type": "mouse_click", "button": "left", "x": 400, "y": 655}, {"frame": 264, "type": "mouse_click", "button": "left", "x": 400, "y": 655}]}
EOF

cat > "$GAME/demo_outputs/demo_defend_and_charge.json" << 'EOF'
{"duration_frames": 360, "events": [{"frame": 30, "type": "wait"}, {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 660, "y": 655}, {"frame": 168, "type": "mouse_click", "button": "left", "x": 660, "y": 655}, {"frame": 216, "type": "mouse_click", "button": "left", "x": 920, "y": 655}, {"frame": 264, "type": "mouse_click", "button": "left", "x": 920, "y": 655}, {"frame": 312, "type": "mouse_click", "button": "left", "x": 920, "y": 655}]}
EOF

echo "rhythm-conductor oracle solution written to $GAME"
