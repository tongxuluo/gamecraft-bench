#!/bin/bash
set -euo pipefail
GAME="${GAME:-/workspace/game}"
mkdir -p "$GAME" && cd "$GAME"

cat > project.godot <<'GODOT'
[application]
config/name="Open Waters Fishing"
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
var cast_meter: float = 0.0
var casting: bool = false
var hooked: bool = false
var tension: float = 0.0
var reeling: bool = false
var weather: int = 0
var weather_names: Array = ["Sunny", "Rainy", "Foggy"]
var time_of_day: float = 0.0
var journal: Dictionary = {}
var species: Array = ["Bass", "Trout", "Salmon", "Marlin", "Golden Koi"]
var caught: Array = []
func _ready():
	var s = _get_scenario()
	if s == "title": _make_title()
	else: _start_game(s)
func _get_scenario() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="): return a.split("=")[1]
	return ""
func _make_title():
	var bg = ColorRect.new(); bg.color = Color(0.1, 0.2, 0.3); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var t = Label.new(); t.text = "Open Waters Fishing"; t.set_anchors_preset(Control.PRESET_CENTER_TOP); t.position.y = 200; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(t)
	var b = Button.new(); b.text = "Cast Off"; b.set_anchors_preset(Control.PRESET_CENTER); b.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn")); add_child(b)
func _start_game(s: String):
	_gen_world()
	_spawn_player()
	_make_hud()
	if s == "lake_fishing": player.position = Vector2(200, 200); weather = 0
	elif s == "river_fishing": player.position = Vector2(640, 200); weather = 1
	elif s == "ocean_fishing": player.position = Vector2(1100, 200); weather = 0
	elif s == "bite_reel": player.position = Vector2(200, 200); hooked = true; tension = 0.5
	elif s == "rare_fish": player.position = Vector2(1100, 200); journal["Golden Koi"] = 1
	elif s == "weather_change": weather = 1; time_of_day = 0.3
	elif s == "journal_view": caught = ["Bass", "Trout"]
func _gen_world():
	var lake = ColorRect.new(); lake.position = Vector2(0, 0); lake.size = Vector2(400, 720); lake.color = Color(0.3, 0.5, 0.7); add_child(lake)
	var river = ColorRect.new(); river.position = Vector2(400, 0); river.size = Vector2(480, 720); river.color = Color(0.2, 0.4, 0.6); add_child(river)
	var ocean = ColorRect.new(); ocean.position = Vector2(880, 0); ocean.size = Vector2(400, 720); ocean.color = Color(0.1, 0.2, 0.4); add_child(ocean)
	var shore = ColorRect.new(); shore.position = Vector2(0, 500); shore.size = Vector2(1280, 220); shore.color = Color(0.4, 0.6, 0.3); add_child(shore)
func _spawn_player():
	player = CharacterBody2D.new()
	var sp = ColorRect.new(); sp.size = Vector2(24, 24); sp.color = Color(0.8, 0.6, 0.4); player.add_child(sp)
	var c = CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = Vector2(24, 24); player.add_child(c)
	player.position = Vector2(200, 480); add_child(player)
func _make_hud():
	var w = Label.new(); w.text = "Weather: %s" % weather_names[weather]; w.position = Vector2(10, 10); w.name = "Weather"; add_child(w)
	var t = Label.new(); t.text = "Tension: 0.0"; t.position = Vector2(10, 35); t.name = "Tension"; add_child(t)
	var j = Label.new(); j.text = "Caught: %d/5" % len(caught); j.position = Vector2(10, 60); j.name = "Journal"; add_child(j)
	var cm = Label.new(); cm.text = "Cast: 0%"; cm.position = Vector2(10, 85); cm.name = "Cast"; add_child(cm)
func _process(delta):
	if player == null: return
	time_of_day += delta * 0.01
	if time_of_day > 1.0: time_of_day = 0.0
	var up = Input.is_action_pressed("ui_up")
	var down = Input.is_action_pressed("ui_down")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	var vel = Vector2.ZERO
	if up: vel.y = -120
	if down: vel.y = 120
	if left: vel.x = -120
	if right: vel.x = 120
	player.velocity = vel
	player.move_and_slide()
	if Input.is_action_just_pressed("ui_accept"):
		if not hooked and not casting:
			casting = true; cast_meter = 0.0
		elif hooked:
			reeling = true; tension += 0.1
	if casting:
		cast_meter += delta * 50
		if cast_meter >= 100:
			casting = false; hooked = true; tension = 0.3
	if hooked and not reeling:
		tension += delta * 5
		if tension > 1.0: hooked = false; tension = 0.0
	if reeling:
		tension -= delta * 10
		if tension <= 0.0:
			hooked = false; reeling = false; tension = 0.0
			var sp = species[min(len(caught), 4)]
			if not journal.has(sp): journal[sp] = 0
			journal[sp] += 1
			if not caught.has(sp): caught.append(sp)
	_update_hud()
func _update_hud():
	var w = get_node_or_null("Weather")
	if w: w.text = "Weather: %s" % weather_names[weather]
	var t = get_node_or_null("Tension")
	if t: t.text = "Tension: %.1f" % tension
	var j = get_node_or_null("Journal")
	if j: j.text = "Caught: %d/5" % len(caught)
	var cm = get_node_or_null("Cast")
	if cm: cm.text = "Cast: %d%%" % int(cast_meter)
GDSCRIPT

cat > Main.tscn <<'TSCN'
[gd_scene load_steps=2 format=3 uid="uid://main"]
[ext_resource type="Script" path="res://Main.gd" id="1_main"]
[node name="Main" type="Node2D"]
script = ExtResource("1_main")
TSCN

mkdir -p demo_outputs
for f in title lake_fishing river_fishing ocean_fishing bite_reel rare_fish weather_change journal_view; do
cat > demo_outputs/${f}.json <<EOF
{"scenario": "$f", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "W"}, {"frame": 120, "type": "key_up", "keycode": "W"}, {"frame": 150, "type": "key_press", "keycode": "D"}, {"frame": 200, "type": "key_up", "keycode": "D"}, {"frame": 280, "type": "wait"}]}
EOF
done
echo "openworld-fishing Oracle ready"
