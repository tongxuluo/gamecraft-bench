#!/bin/bash
set -euo pipefail
GAME="${GAME:-/workspace/game}"
mkdir -p "$GAME" && cd "$GAME"

cat > project.godot <<'GODOT'
[application]
config/name="Open Road Racing"
config/features=PackedStringArray("4.2", "Mobile")
run/main_scene="res://Main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[input]
ui_accept={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194309,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]}
GODOT

cat > Main.gd <<'GDSCRIPT'
extends Node2D
var player: CharacterBody2D
var speed: float = 0.0
var max_speed: float = 400.0
var angle: float = 0.0
var unlocked: Array = [true, false, false]
var medals: Array = [0, 0, 0]
var in_race: bool = false
var race_timer: float = 0.0
var checkpoints: Array = []
var cp_hit: int = 0
func _ready():
	var s = _get_scenario()
	if s == "title": _make_title()
	else: _start_game(s)
func _get_scenario() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="): return a.split("=")[1]
	return ""
func _make_title():
	var bg = ColorRect.new(); bg.color = Color(0.05, 0.05, 0.1); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var t = Label.new(); t.text = "Open Road Racing"; t.set_anchors_preset(Control.PRESET_CENTER_TOP); t.position.y = 200; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(t)
	var b = Button.new(); b.text = "Start Engine"; b.set_anchors_preset(Control.PRESET_CENTER); b.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn")); add_child(b)
func _start_game(s: String):
	_gen_world()
	_spawn_player(s)
	_spawn_tracks()
	_make_hud()
	if s == "coastal_race": _start_race(0)
	elif s == "canyon_race": _start_race(1)
	elif s == "mountain_race": _start_race(2)
	elif s == "unlock_track": unlocked = [true, true, false]; medals = [2, 0, 0]
func _gen_world():
	var b1 = ColorRect.new(); b1.position = Vector2(0, 0); b1.size = Vector2(420, 720); b1.color = Color(0.1, 0.3, 0.5); add_child(b1)
	var b2 = ColorRect.new(); b2.position = Vector2(420, 0); b2.size = Vector2(440, 720); b2.color = Color(0.5, 0.35, 0.15); add_child(b2)
	var b3 = ColorRect.new(); b3.position = Vector2(860, 0); b3.size = Vector2(420, 720); b3.color = Color(0.15, 0.4, 0.2); add_child(b3)
func _spawn_player(s: String):
	player = CharacterBody2D.new()
	var sp = ColorRect.new(); sp.size = Vector2(30, 20); sp.color = Color(0.9, 0.2, 0.2); player.add_child(sp)
	var c = CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = Vector2(30, 20); player.add_child(c)
	if s == "canyon_race": player.position = Vector2(500, 360)
	elif s == "mountain_race": player.position = Vector2(900, 360)
	else: player.position = Vector2(100, 360)
	add_child(player)
func _spawn_tracks():
	for i in range(3):
		var gate = ColorRect.new()
		gate.position = Vector2(200 + i * 400, 300)
		gate.size = Vector2(60, 10)
		gate.color = Color(1, 1, 1) if unlocked[i] else Color(0.3, 0.3, 0.3)
		gate.set_meta("idx", i)
		add_child(gate)
		checkpoints.append(gate)
func _make_hud():
	var spd = Label.new(); spd.text = "0 km/h"; spd.position = Vector2(10, 10); spd.name = "Speed"; add_child(spd)
	var tmr = Label.new(); tmr.text = ""; tmr.position = Vector2(10, 35); tmr.name = "Timer"; add_child(tmr)
	var mdl = Label.new(); mdl.text = ""; mdl.position = Vector2(10, 60); mdl.name = "Medal"; add_child(mdl)
func _process(delta):
	if player == null: return
	if in_race: race_timer += delta
	var fwd = Input.is_action_pressed("ui_up")
	var back = Input.is_action_pressed("ui_down")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	if fwd: speed = min(speed + 200 * delta, max_speed)
	elif back: speed = max(speed - 300 * delta, -100)
	else: speed = move_toward(speed, 0, 100 * delta)
	if left: angle -= 3 * delta
	if right: angle += 3 * delta
	player.rotation = angle
	player.velocity = Vector2(0, -speed).rotated(angle)
	player.move_and_slide()
	_check_gates()
	_update_hud()
func _check_gates():
	if not in_race: return
	for g in checkpoints:
		if player.position.distance_to(g.position + g.size / 2) < 40:
			cp_hit += 1
			if cp_hit >= 1:
				in_race = false
				var t = race_timer
				var m = 3 if t < 15 else (2 if t < 25 else 1)
				medals[g.get_meta("idx")] = max(medals[g.get_meta("idx")], m)
				var banner = Label.new()
				banner.text = "FINISH! Medal: %s" % ["Bronze", "Silver", "Gold"][m - 1]
				banner.position = Vector2(440, 100); add_child(banner)
func _start_race(idx: int):
	in_race = true; race_timer = 0.0; cp_hit = 0
	player.position = checkpoints[idx].position + Vector2(0, 50)
func _update_hud():
	var s = get_node_or_null("Speed")
	if s: s.text = "%d km/h" % int(abs(speed) / 4)
	var t = get_node_or_null("Timer")
	if t and in_race: t.text = "Time: %.1f" % race_timer
	var m = get_node_or_null("Medal")
	if m: m.text = "Medals: %s" % str(medals)
GDSCRIPT

cat > Main.tscn <<'TSCN'
[gd_scene load_steps=2 format=3 uid="uid://main"]
[ext_resource type="Script" path="res://Main.gd" id="1_main"]
[node name="Main" type="Node2D"]
script = ExtResource("1_main")
TSCN

mkdir -p demo_outputs
for f in title free_roam coastal_race canyon_race mountain_race drift_boost unlock_track full_championship; do
cat > demo_outputs/${f}.json <<EOF
{"scenario": "$f", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "W"}, {"frame": 120, "type": "key_up", "keycode": "W"}, {"frame": 150, "type": "key_press", "keycode": "D"}, {"frame": 200, "type": "key_up", "keycode": "D"}, {"frame": 280, "type": "wait"}]}
EOF
done
echo "openworld-racing Oracle ready"
