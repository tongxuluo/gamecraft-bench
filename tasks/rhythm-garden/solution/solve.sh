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
config/name="Rhythm Garden"
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

enum State { TITLE, OVERWORLD, MINIGAME, RESULT }

var state: int = State.TITLE
var current_minigame: int = -1
var scores: Array = [0, 0, 0]
var stars: Array = [0, 0, 0]
var beat_timer: float = 0.0
var beat_interval: float = 0.6
var targets: Array = []
var target_index: int = 0
var mg_time: float = 0.0
var mg_duration: float = 6.0
var hit_count: int = 0
var miss_count: int = 0
var scenario: String = ""

var bg: ColorRect
var title_label: Label
var play_btn: Button
var info_label: Label
var station_btns: Array = []
var target_rects: Array = []
var score_label: Label
var star_label: Label
var back_btn: Button

func _ready() -> void:
	_parse_args()
	_build_ui()
	_show_title()

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]
			i += 2
		else:
			i += 1

func _build_ui() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.85, 0.95, 0.80)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "Rhythm Garden"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(340, 180)
	title_label.size = Vector2(600, 80)
	title_label.add_theme_font_size_override("font_size", 48)
	add_child(title_label)

	play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(540, 400)
	play_btn.size = Vector2(200, 60)
	play_btn.pressed.connect(_on_play)
	add_child(play_btn)

	info_label = Label.new()
	info_label.text = ""
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(200, 20)
	info_label.size = Vector2(880, 40)
	info_label.add_theme_font_size_override("font_size", 22)
	add_child(info_label)

	score_label = Label.new()
	score_label.text = ""
	score_label.position = Vector2(20, 680)
	score_label.size = Vector2(400, 30)
	add_child(score_label)

	star_label = Label.new()
	star_label.text = ""
	star_label.position = Vector2(900, 680)
	star_label.size = Vector2(360, 30)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(star_label)

	back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(20, 20)
	back_btn.size = Vector2(100, 40)
	back_btn.pressed.connect(_on_back)
	back_btn.visible = false
	add_child(back_btn)

	var names: Array = ["Water Flowers", "Swat Bugs", "Bounce Seeds"]
	var colors: Array = [Color(0.4, 0.7, 1.0), Color(1.0, 0.5, 0.4), Color(0.5, 0.9, 0.5)]
	for idx in range(3):
		var btn: Button = Button.new()
		btn.text = names[idx]
		btn.position = Vector2(200 + idx * 340, 300)
		btn.size = Vector2(260, 80)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = colors[idx]
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		btn.add_theme_stylebox_override("normal", sb)
		btn.pressed.connect(_on_station.bind(idx))
		btn.visible = false
		add_child(btn)
		station_btns.append(btn)

	for t_idx in range(5):
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(60, 60)
		rect.color = Color(1.0, 0.8, 0.2)
		rect.position = Vector2(200 + t_idx * 180, 400)
		rect.visible = false
		add_child(rect)
		target_rects.append(rect)

func _show_title() -> void:
	state = State.TITLE
	title_label.visible = true
	play_btn.visible = true
	info_label.text = ""
	back_btn.visible = false
	_hide_stations()
	_hide_targets()
	_update_stars_display()

func _show_overworld() -> void:
	state = State.OVERWORLD
	title_label.visible = false
	play_btn.visible = false
	info_label.text = "Choose a minigame station!"
	back_btn.visible = false
	_hide_targets()
	for btn in station_btns:
		btn.visible = true
	_update_stars_display()

func _start_minigame(idx: int) -> void:
	state = State.MINIGAME
	current_minigame = idx
	_hide_stations()
	back_btn.visible = true
	beat_timer = 0.0
	mg_time = 0.0
	hit_count = 0
	miss_count = 0
	target_index = 0
	targets.clear()
	var count: int = 8
	for c in range(count):
		targets.append(false)
	_hide_targets()
	var mg_names: Array = ["Water Flowers", "Swat Bugs", "Bounce Seeds"]
	info_label.text = mg_names[idx] + " - Click targets in rhythm!"
	score_label.text = "Hits: 0"

func _show_result() -> void:
	state = State.RESULT
	_hide_targets()
	var total: int = targets.size()
	var pct: float = float(hit_count) / float(total) if total > 0 else 0.0
	var earned: int = 1
	if pct >= 0.9:
		earned = 3
	elif pct >= 0.6:
		earned = 2
	scores[current_minigame] = hit_count
	if earned > stars[current_minigame]:
		stars[current_minigame] = earned
	info_label.text = "Score: " + str(hit_count) + "/" + str(total) + " - Stars: " + str(earned)
	back_btn.visible = true
	_update_stars_display()

func _update_stars_display() -> void:
	var total_stars: int = 0
	for s in stars:
		total_stars += s
	star_label.text = "Stars: " + str(total_stars) + "/9"

func _hide_stations() -> void:
	for btn in station_btns:
		btn.visible = false

func _hide_targets() -> void:
	for rect in target_rects:
		rect.visible = false

func _on_play() -> void:
	_show_overworld()

func _on_station(idx: int) -> void:
	_start_minigame(idx)

func _on_back() -> void:
	_show_overworld()

func _process(delta: float) -> void:
	if state != State.MINIGAME:
		return
	mg_time += delta
	if mg_time >= mg_duration:
		_show_result()
		return
	beat_timer += delta
	if beat_timer >= beat_interval:
		beat_timer -= beat_interval
		if target_index < targets.size():
			_show_next_target()

func _show_next_target() -> void:
	_hide_targets()
	var vis_idx: int = target_index % target_rects.size()
	var rect: ColorRect = target_rects[vis_idx]
	rect.visible = true
	rect.color = Color(1.0, 0.8, 0.2)
	target_index += 1

func _input(event: InputEvent) -> void:
	if state == State.MINIGAME:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_check_hit(mb.position)

func _check_hit(pos: Vector2) -> void:
	for rect in target_rects:
		if rect.visible:
			var r: Rect2 = Rect2(rect.position, rect.size)
			if r.has_point(pos):
				hit_count += 1
				rect.color = Color(0.2, 1.0, 0.4)
				score_label.text = "Hits: " + str(hit_count)
				return
	miss_count += 1
GDEOF

# --- demo_outputs ---
cat > "$GAME/demo_outputs/demo_title_to_overworld.json" << 'EOF'
{"duration_frames": 360, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}]}
EOF

cat > "$GAME/demo_outputs/demo_play_water_flowers.json" << 'EOF'
{"duration_frames": 720, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 180, "type": "mouse_click", "button": "left", "x": 330, "y": 340}, {"frame": 240, "type": "mouse_click", "button": "left", "x": 230, "y": 430}, {"frame": 300, "type": "mouse_click", "button": "left", "x": 410, "y": 430}, {"frame": 360, "type": "mouse_click", "button": "left", "x": 590, "y": 430}, {"frame": 420, "type": "mouse_click", "button": "left", "x": 770, "y": 430}, {"frame": 480, "type": "mouse_click", "button": "left", "x": 950, "y": 430}]}
EOF

cat > "$GAME/demo_outputs/demo_full_session.json" << 'EOF'
{"duration_frames": 1800, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 180, "type": "mouse_click", "button": "left", "x": 330, "y": 340}, {"frame": 300, "type": "mouse_click", "button": "left", "x": 230, "y": 430}, {"frame": 360, "type": "mouse_click", "button": "left", "x": 410, "y": 430}, {"frame": 420, "type": "mouse_click", "button": "left", "x": 590, "y": 430}, {"frame": 540, "type": "mouse_click", "button": "left", "x": 20, "y": 40}, {"frame": 600, "type": "mouse_click", "button": "left", "x": 670, "y": 340}, {"frame": 720, "type": "mouse_click", "button": "left", "x": 230, "y": 430}, {"frame": 780, "type": "mouse_click", "button": "left", "x": 410, "y": 430}, {"frame": 840, "type": "mouse_click", "button": "left", "x": 590, "y": 430}, {"frame": 960, "type": "mouse_click", "button": "left", "x": 20, "y": 40}, {"frame": 1020, "type": "mouse_click", "button": "left", "x": 1010, "y": 340}, {"frame": 1140, "type": "mouse_click", "button": "left", "x": 230, "y": 430}, {"frame": 1200, "type": "mouse_click", "button": "left", "x": 410, "y": 430}, {"frame": 1260, "type": "mouse_click", "button": "left", "x": 590, "y": 430}, {"frame": 1380, "type": "mouse_click", "button": "left", "x": 20, "y": 40}]}
EOF

echo "Rhythm Garden oracle solution written to $GAME"
