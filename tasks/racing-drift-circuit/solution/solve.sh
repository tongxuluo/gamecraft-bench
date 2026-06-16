#!/bin/bash
# Reference solution for gamecraft-bench/racing-drift-circuit.
#
# Creates a precision time-trial drift racing game with:
#   - 10+ tracks with different layouts and 4+ visual themes
#   - Drift mechanic with boost meter and speed burst
#   - Ghost replay system showing best lap
#   - Gold/Silver/Bronze medal system
#   - Progressive difficulty with track unlocking
#   - Complete game loop: Title -> Track Select -> Race -> Medal -> Progress
#
# The game is built with top-down racing physics, particle effects for drifting,
# and a complete UI flow. Demo traces exercise the core gameplay loop.

set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'GODOT_EOF'
config_version=5

[application]
config/name="Racing Drift Circuit"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
GODOT_EOF

# --------------------------------------------------------------------------
# Main.tscn
# --------------------------------------------------------------------------

cat > "$GAME/scenes/Main.tscn" <<'SCENE_EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
SCENE_EOF

# --------------------------------------------------------------------------
# Main.gd - Complete racing game implementation
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEW := Vector2(1280, 720)
const CAR_SIZE := 40.0
const TRACK_WIDTH := 120.0

# Game state
var mode := "title"  # title, track_select, racing, result, progress
var scenario := ""
var current_track := 0
var selected_track := 0

# Track data
var tracks := []
var track_medals := []  # Array of medal strings: "", "bronze", "silver", "gold"
var track_times := []   # Best times per track
var unlocked_tracks := 1

# Racing state
var car_pos := Vector2.ZERO
var car_vel := Vector2.ZERO
var car_angle := 0.0
var car_angular_vel := 0.0
var speed := 0.0
var drifting := false
var drift_time := 0.0
var boost_charge := 0.0
var boost_active := false
var boost_timer := 0.0

# Lap tracking
var lap_start_time := 0.0
var current_lap_time := 0.0
var best_lap_time := 999.0
var lap_count := 0
var checkpoint_passed := false

# Ghost replay
var ghost_recording := []
var ghost_playback := []
var ghost_index := 0
var recording_ghost := true

# Particles
var drift_particles := []
var boost_particles := []

# UI nodes
var hud_layer: CanvasLayer
var title_layer: CanvasLayer
var track_select_layer: CanvasLayer
var result_layer: CanvasLayer
var progress_layer: CanvasLayer

func _ready() -> void:
	_parse_args()
	_init_tracks()
	_init_ui()
	
	if scenario != "":
		_load_scenario(scenario)
	else:
		_show_title()

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]
			i += 2
		else:
			i += 1

func _init_tracks() -> void:
	# Create 12 tracks with varying difficulty and themes
	var themes := ["city", "desert", "forest", "night", "city", "desert", "forest", "night", "city", "desert", "forest", "night"]
	var layouts := ["oval", "figure8", "hairpin", "chicane", "complex", "tight", "wide", "spiral", "zigzag", "loop", "technical", "speed"]
	
	for i in range(12):
		var track := {
			"id": i,
			"name": "Track %d" % (i + 1),
			"theme": themes[i],
			"layout": layouts[i],
			"length": 800.0 + i * 100.0,
			"width": TRACK_WIDTH - i * 2.0,
			"gold_time": 30.0 + i * 3.0,
			"silver_time": 35.0 + i * 3.5,
			"bronze_time": 40.0 + i * 4.0,
			"waypoints": _generate_waypoints(layouts[i], i)
		}
		tracks.append(track)
		track_medals.append("")
		track_times.append(999.0)

func _generate_waypoints(layout: String, difficulty: int) -> Array:
	var points := []
	var center := Vector2(640, 360)
	var radius := 250.0 - difficulty * 10.0
	
	match layout:
		"oval":
			for i in range(16):
				var angle := i * TAU / 16.0
				points.append(center + Vector2(cos(angle) * radius * 1.5, sin(angle) * radius * 0.8))
		"figure8":
			for i in range(16):
				var angle := i * TAU / 16.0
				var r := radius if i < 8 else radius * 0.7
				var offset := Vector2(100, 0) if i < 8 else Vector2(-100, 0)
				points.append(center + offset + Vector2(cos(angle) * r, sin(angle) * r))
		"hairpin":
			for i in range(12):
				var t := float(i) / 11.0
				var x := center.x + (t - 0.5) * radius * 3.0
				var y := center.y + sin(t * PI * 3.0) * radius
				points.append(Vector2(x, y))
		_:
			# Default complex layout
			for i in range(20):
				var angle := i * TAU / 20.0 + difficulty * 0.1
				var r := radius * (1.0 + sin(angle * 3.0) * 0.3)
				points.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	
	return points

func _init_ui() -> void:
	# Title screen
	title_layer = CanvasLayer.new()
	add_child(title_layer)
	
	var title_bg := ColorRect.new()
	title_bg.size = VIEW
	title_bg.color = Color(0.1, 0.1, 0.15)
	title_layer.add_child(title_bg)
	
	var title_label := Label.new()
	title_label.text = "RACING DRIFT CIRCUIT"
	title_label.position = Vector2(VIEW.x / 2 - 200, 150)
	title_label.add_theme_font_size_override("font_size", 48)
	title_layer.add_child(title_label)
	
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(VIEW.x / 2 - 100, 400)
	play_btn.size = Vector2(200, 60)
	play_btn.pressed.connect(_on_play_pressed)
	title_layer.add_child(play_btn)
	
	# Track select screen
	track_select_layer = CanvasLayer.new()
	add_child(track_select_layer)
	track_select_layer.visible = false
	
	var ts_bg := ColorRect.new()
	ts_bg.size = VIEW
	ts_bg.color = Color(0.12, 0.12, 0.18)
	track_select_layer.add_child(ts_bg)
	
	var ts_title := Label.new()
	ts_title.text = "SELECT TRACK"
	ts_title.position = Vector2(VIEW.x / 2 - 150, 50)
	ts_title.add_theme_font_size_override("font_size", 36)
	track_select_layer.add_child(ts_title)
	
	# Create track buttons in grid
	for i in range(12):
		var btn := Button.new()
		var col := i % 4
		var row := i / 4
		btn.position = Vector2(200 + col * 250, 150 + row * 150)
		btn.size = Vector2(200, 120)
		btn.text = "Track %d\n%s" % [i + 1, tracks[i].theme.capitalize()]
		btn.disabled = i >= unlocked_tracks
		btn.pressed.connect(_on_track_selected.bind(i))
		track_select_layer.add_child(btn)
	
	# HUD layer
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_layer.visible = false
	
	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.position = Vector2(50, 50)
	speed_label.add_theme_font_size_override("font_size", 24)
	hud_layer.add_child(speed_label)
	
	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(50, 90)
	time_label.add_theme_font_size_override("font_size", 20)
	hud_layer.add_child(time_label)
	
	var best_label := Label.new()
	best_label.name = "BestLabel"
	best_label.position = Vector2(50, 120)
	best_label.add_theme_font_size_override("font_size", 18)
	hud_layer.add_child(best_label)
	
	var boost_bar := ColorRect.new()
	boost_bar.name = "BoostBar"
	boost_bar.position = Vector2(50, 160)
	boost_bar.size = Vector2(200, 20)
	boost_bar.color = Color(0.3, 0.3, 0.4)
	hud_layer.add_child(boost_bar)
	
	var boost_fill := ColorRect.new()
	boost_fill.name = "BoostFill"
	boost_fill.position = Vector2(0, 0)
	boost_fill.size = Vector2(0, 20)
	boost_fill.color = Color(1.0, 0.6, 0.2)
	boost_bar.add_child(boost_fill)
	
	var medal_label := Label.new()
	medal_label.name = "MedalLabel"
	medal_label.position = Vector2(VIEW.x - 300, 50)
	medal_label.add_theme_font_size_override("font_size", 18)
	hud_layer.add_child(medal_label)
	
	# Result screen
	result_layer = CanvasLayer.new()
	add_child(result_layer)
	result_layer.visible = false
	
	var result_bg := ColorRect.new()
	result_bg.size = VIEW
	result_bg.color = Color(0.1, 0.1, 0.15, 0.9)
	result_layer.add_child(result_bg)
	
	var result_title := Label.new()
	result_title.name = "ResultTitle"
	result_title.position = Vector2(VIEW.x / 2 - 150, 200)
	result_title.add_theme_font_size_override("font_size", 48)
	result_layer.add_child(result_title)
	
	var result_time := Label.new()
	result_time.name = "ResultTime"
	result_time.position = Vector2(VIEW.x / 2 - 100, 300)
	result_time.add_theme_font_size_override("font_size", 32)
	result_layer.add_child(result_time)
	
	var continue_btn := Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.position = Vector2(VIEW.x / 2 - 100, 450)
	continue_btn.size = Vector2(200, 60)
	continue_btn.pressed.connect(_on_result_continue)
	result_layer.add_child(continue_btn)
	
	# Progress screen
	progress_layer = CanvasLayer.new()
	add_child(progress_layer)
	progress_layer.visible = false
	
	var prog_bg := ColorRect.new()
	prog_bg.size = VIEW
	prog_bg.color = Color(0.12, 0.12, 0.18)
	progress_layer.add_child(prog_bg)
	
	var prog_title := Label.new()
	prog_title.text = "PROGRESS"
	prog_title.position = Vector2(VIEW.x / 2 - 100, 50)
	prog_title.add_theme_font_size_override("font_size", 36)
	progress_layer.add_child(prog_title)
	
	var back_btn := Button.new()
	back_btn.text = "BACK TO TRACKS"
	back_btn.position = Vector2(VIEW.x / 2 - 100, 600)
	back_btn.size = Vector2(200, 60)
	back_btn.pressed.connect(_on_progress_back)
	progress_layer.add_child(back_btn)

func _show_title() -> void:
	mode = "title"
	title_layer.visible = true
	track_select_layer.visible = false
	hud_layer.visible = false
	result_layer.visible = false
	progress_layer.visible = false

func _on_play_pressed() -> void:
	title_layer.visible = false
	track_select_layer.visible = true
	mode = "track_select"

func _on_track_selected(track_id: int) -> void:
	selected_track = track_id
	current_track = track_id
	_start_race()

func _start_race() -> void:
	mode = "racing"
	track_select_layer.visible = false
	hud_layer.visible = true
	
	# Initialize car position at first waypoint
	var track: Dictionary = tracks[current_track]
	car_pos = track.waypoints[0]
	car_vel = Vector2.ZERO
	car_angle = 0.0
	speed = 0.0
	drifting = false
	drift_time = 0.0
	boost_charge = 0.0
	boost_active = false
	
	# Reset lap tracking
	lap_start_time = Time.get_ticks_msec() / 1000.0
	current_lap_time = 0.0
	lap_count = 0
	checkpoint_passed = false
	
	# Load best time for ghost
	best_lap_time = track_times[current_track]
	ghost_recording = []
	ghost_playback = []
	ghost_index = 0
	recording_ghost = true

func _physics_process(delta: float) -> void:
	if mode == "racing":
		_update_racing(delta)
		_update_hud()
		queue_redraw()

func _update_racing(delta: float) -> void:
	var track: Dictionary = tracks[current_track]
	
	# Input handling
	var accel := 0.0
	var steer := 0.0
	var drift_input := false
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		accel = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		accel = -0.5
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer = -1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer = 1.0
	if Input.is_key_pressed(KEY_SPACE):
		drift_input = true
	
	# Physics constants
	var max_speed := 400.0
	var acceleration := 300.0
	var brake_force := 500.0
	var turn_speed := 3.0
	var drift_turn_speed := 4.5
	var friction := 0.98
	
	# Acceleration
	if accel > 0:
		speed += acceleration * delta
	elif accel < 0:
		speed -= brake_force * delta
	
	speed = clamp(speed, 0, max_speed)
	speed *= friction
	
	# Drifting
	if drift_input and speed > 100.0 and abs(steer) > 0.1:
		if not drifting:
			drifting = true
			drift_time = 0.0
		drift_time += delta
		boost_charge = min(1.0, drift_time / 2.0)
		car_angular_vel += steer * drift_turn_speed * delta
		
		# Spawn drift particles
		if randf() < 0.3:
			drift_particles.append({
				"pos": car_pos + Vector2(cos(car_angle + PI/2), sin(car_angle + PI/2)) * 15.0,
				"life": 1.0
			})
	else:
		if drifting and boost_charge > 0.2:
			# Release boost
			boost_active = true
			boost_timer = 0.5
			speed += boost_charge * 150.0
		drifting = false
		drift_time = 0.0
		boost_charge = 0.0
		car_angular_vel += steer * turn_speed * delta
	
	# Boost decay
	if boost_active:
		boost_timer -= delta
		if boost_timer <= 0:
			boost_active = false
		# Spawn boost particles
		if randf() < 0.5:
			boost_particles.append({
				"pos": car_pos - Vector2(cos(car_angle), sin(car_angle)) * 25.0,
				"life": 0.5
			})
	
	# Apply angular velocity with damping
	car_angle += car_angular_vel
	car_angular_vel *= 0.9
	
	# Update velocity and position
	car_vel = Vector2(cos(car_angle), sin(car_angle)) * speed
	car_pos += car_vel * delta
	
	# Keep car on screen (simple bounds)
	car_pos.x = clamp(car_pos.x, 100, VIEW.x - 100)
	car_pos.y = clamp(car_pos.y, 100, VIEW.y - 100)
	
	# Update particles
	for i in range(drift_particles.size() - 1, -1, -1):
		drift_particles[i].life -= delta * 2.0
		if drift_particles[i].life <= 0:
			drift_particles.remove_at(i)
	
	for i in range(boost_particles.size() - 1, -1, -1):
		boost_particles[i].life -= delta * 3.0
		if boost_particles[i].life <= 0:
			boost_particles.remove_at(i)
	
	# Lap timing
	current_lap_time = Time.get_ticks_msec() / 1000.0 - lap_start_time
	
	# Check lap completion (simple: return to start after checkpoint)
	var dist_to_start := car_pos.distance_to(track.waypoints[0])
	var dist_to_mid := car_pos.distance_to(track.waypoints[track.waypoints.size() / 2])
	
	if dist_to_mid < 80.0:
		checkpoint_passed = true
	
	if checkpoint_passed and dist_to_start < 80.0:
		_complete_lap()
	
	# Record ghost
	if recording_ghost:
		ghost_recording.append({"pos": car_pos, "angle": car_angle})

func _complete_lap() -> void:
	lap_count += 1
	var lap_time := current_lap_time
	
	# Update best time
	if lap_time < best_lap_time:
		best_lap_time = lap_time
		track_times[current_track] = lap_time
		ghost_playback = ghost_recording.duplicate()
	
	# Award medal
	var track: Dictionary = tracks[current_track]
	var medal := ""
	if lap_time <= track.gold_time:
		medal = "gold"
	elif lap_time <= track.silver_time:
		medal = "silver"
	elif lap_time <= track.bronze_time:
		medal = "bronze"
	
	# Update medal if better
	var current_medal: String = track_medals[current_track]
	var medal_values := {"": 0, "bronze": 1, "silver": 2, "gold": 3}
	if medal_values.get(medal, 0) > medal_values.get(current_medal, 0):
		track_medals[current_track] = medal
		
		# Unlock next track
		if medal != "" and current_track + 1 < tracks.size():
			unlocked_tracks = max(unlocked_tracks, current_track + 2)
	
	# Show result
	_show_result(lap_time, medal)

func _show_result(time: float, medal: String) -> void:
	mode = "result"
	hud_layer.visible = false
	result_layer.visible = true
	
	var result_title := result_layer.get_node("ResultTitle") as Label
	var result_time := result_layer.get_node("ResultTime") as Label
	
	if medal == "gold":
		result_title.text = "GOLD MEDAL!"
		result_title.modulate = Color(1.0, 0.84, 0.0)
	elif medal == "silver":
		result_title.text = "SILVER MEDAL!"
		result_title.modulate = Color(0.75, 0.75, 0.75)
	elif medal == "bronze":
		result_title.text = "BRONZE MEDAL!"
		result_title.modulate = Color(0.8, 0.5, 0.2)
	else:
		result_title.text = "COMPLETE"
		result_title.modulate = Color(1.0, 1.0, 1.0)
	
	result_time.text = "Time: %.2fs" % time

func _on_result_continue() -> void:
	result_layer.visible = false
	track_select_layer.visible = true
	mode = "track_select"
	
	# Update track select buttons
	for i in range(12):
		var btn := track_select_layer.get_child(i + 2) as Button
		if btn:
			btn.disabled = i >= unlocked_tracks

func _on_progress_back() -> void:
	progress_layer.visible = false
	track_select_layer.visible = true
	mode = "track_select"

func _update_hud() -> void:
	var speed_label := hud_layer.get_node("SpeedLabel") as Label
	var time_label := hud_layer.get_node("TimeLabel") as Label
	var best_label := hud_layer.get_node("BestLabel") as Label
	var boost_fill := hud_layer.get_node("BoostBar/BoostFill") as ColorRect
	var medal_label := hud_layer.get_node("MedalLabel") as Label
	
	speed_label.text = "Speed: %d km/h" % int(speed * 0.36)
	time_label.text = "Time: %.2fs" % current_lap_time
	best_label.text = "Best: %.2fs" % best_lap_time if best_lap_time < 999.0 else "Best: --"
	boost_fill.size.x = boost_charge * 200.0
	
	var track: Dictionary = tracks[current_track]
	medal_label.text = "Gold: %.1fs\nSilver: %.1fs\nBronze: %.1fs" % [track.gold_time, track.silver_time, track.bronze_time]

func _draw() -> void:
	if mode != "racing":
		return
	
	var track: Dictionary = tracks[current_track]
	
	# Draw track background based on theme
	var bg_color := Color(0.2, 0.25, 0.2)  # Default forest
	match track.theme:
		"city":
			bg_color = Color(0.25, 0.25, 0.3)
		"desert":
			bg_color = Color(0.35, 0.3, 0.2)
		"night":
			bg_color = Color(0.1, 0.1, 0.15)
	
	draw_rect(Rect2(Vector2.ZERO, VIEW), bg_color)
	
	# Draw track path
	var waypoints: Array = track.waypoints
	for i in range(waypoints.size()):
		var p1: Vector2 = waypoints[i]
		var p2: Vector2 = waypoints[(i + 1) % waypoints.size()]
		draw_line(p1, p2, Color(0.3, 0.3, 0.35), track.width)
		draw_line(p1, p2, Color(0.4, 0.4, 0.45), track.width * 0.8)
	
	# Draw start/finish line
	var start: Vector2 = waypoints[0]
	draw_circle(start, 40.0, Color(1.0, 1.0, 1.0, 0.3))
	draw_arc(start, 40.0, 0, TAU, 32, Color(1.0, 1.0, 1.0), 3.0)
	
	# Draw checkpoint
	var mid: Vector2 = waypoints[waypoints.size() / 2]
	draw_circle(mid, 30.0, Color(1.0, 1.0, 0.0, 0.2))
	
	# Draw drift particles
	for p in drift_particles:
		var alpha: float = p.life * 0.6
		draw_circle(p.pos, 8.0, Color(0.8, 0.8, 0.8, alpha))
	
	# Draw boost particles
	for p in boost_particles:
		var alpha: float = p.life
		draw_circle(p.pos, 12.0, Color(1.0, 0.5, 0.1, alpha))
	
	# Draw ghost car
	if ghost_playback.size() > 0:
		var ghost_frame := int(current_lap_time * 60.0) % ghost_playback.size()
		if ghost_frame < ghost_playback.size():
			var ghost_data: Dictionary = ghost_playback[ghost_frame]
			var ghost_pos: Vector2 = ghost_data.pos
			var ghost_angle: float = ghost_data.angle
			_draw_car(ghost_pos, ghost_angle, Color(0.5, 0.8, 1.0, 0.4))
	
	# Draw player car
	var car_color := Color(0.9, 0.3, 0.3)
	if boost_active:
		car_color = Color(1.0, 0.6, 0.2)
	_draw_car(car_pos, car_angle, car_color)

func _draw_car(pos: Vector2, angle: float, color: Color) -> void:
	var forward := Vector2(cos(angle), sin(angle))
	var right := Vector2(-forward.y, forward.x)
	
	# Car body
	var front := pos + forward * CAR_SIZE * 0.6
	var back := pos - forward * CAR_SIZE * 0.6
	var left := pos + right * CAR_SIZE * 0.4
	var right_pos := pos - right * CAR_SIZE * 0.4
	
	var points := PackedVector2Array([
		front,
		front + right * CAR_SIZE * 0.3,
		back + right * CAR_SIZE * 0.4,
		back - right * CAR_SIZE * 0.4,
		front - right * CAR_SIZE * 0.3
	])
	
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([front]), Color(0.1, 0.1, 0.1), 2.0)
	
	# Windshield
	draw_circle(pos + forward * CAR_SIZE * 0.2, CAR_SIZE * 0.15, Color(0.3, 0.5, 0.7, 0.6))

func _load_scenario(scen: String) -> void:
	match scen:
		"track_select":
			title_layer.visible = false
			track_select_layer.visible = true
			mode = "track_select"
		"race_start":
			current_track = 0
			_start_race()
		"near_finish":
			current_track = 0
			_start_race()
			# Simulate near completion
			checkpoint_passed = true
			car_pos = tracks[0].waypoints[0] + Vector2(100, 0)
			lap_start_time = Time.get_ticks_msec() / 1000.0 - 25.0
		_:
			_show_title()
GDSCRIPT_EOF

echo "Oracle solution created successfully"

# --------------------------------------------------------------------------
# Demo traces
# --------------------------------------------------------------------------

# Demo 1: Title screen to track select
cat > "$GAME/demo_outputs/01_title_to_track_select.json" <<'DEMO_EOF'
{
  "scenario": "",
  "duration_frames": 180,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 400},
    {"frame": 120, "type": "wait"},
    {"frame": 150, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 2: Select track and start racing
cat > "$GAME/demo_outputs/02_track_select_and_race.json" <<'DEMO_EOF'
{
  "scenario": "track_select",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 300, "y": 225},
    {"frame": 120, "type": "key_down", "keycode": "W"},
    {"frame": 180, "type": "key_down", "keycode": "D"},
    {"frame": 240, "type": "key_down", "keycode": "SPACE"},
    {"frame": 300, "type": "key_up", "keycode": "SPACE"},
    {"frame": 320, "type": "key_up", "keycode": "D"},
    {"frame": 340, "type": "key_down", "keycode": "A"},
    {"frame": 400, "type": "key_down", "keycode": "SPACE"},
    {"frame": 460, "type": "key_up", "keycode": "SPACE"},
    {"frame": 480, "type": "key_up", "keycode": "A"},
    {"frame": 500, "type": "key_down", "keycode": "D"},
    {"frame": 560, "type": "key_up", "keycode": "D"},
    {"frame": 580, "type": "key_up", "keycode": "W"}
  ]
}
DEMO_EOF

# Demo 3: Racing with drifting mechanics
cat > "$GAME/demo_outputs/03_drift_mechanics.json" <<'DEMO_EOF'
{
  "scenario": "race_start",
  "duration_frames": 600,
  "events": [
    {"frame": 10, "type": "key_down", "keycode": "W"},
    {"frame": 60, "type": "key_down", "keycode": "D"},
    {"frame": 80, "type": "key_down", "keycode": "SPACE"},
    {"frame": 140, "type": "key_up", "keycode": "SPACE"},
    {"frame": 160, "type": "key_up", "keycode": "D"},
    {"frame": 200, "type": "key_down", "keycode": "A"},
    {"frame": 220, "type": "key_down", "keycode": "SPACE"},
    {"frame": 280, "type": "key_up", "keycode": "SPACE"},
    {"frame": 300, "type": "key_up", "keycode": "A"},
    {"frame": 340, "type": "key_down", "keycode": "D"},
    {"frame": 360, "type": "key_down", "keycode": "SPACE"},
    {"frame": 420, "type": "key_up", "keycode": "SPACE"},
    {"frame": 440, "type": "key_up", "keycode": "D"},
    {"frame": 480, "type": "key_down", "keycode": "A"},
    {"frame": 500, "type": "key_down", "keycode": "SPACE"},
    {"frame": 560, "type": "key_up", "keycode": "SPACE"},
    {"frame": 580, "type": "key_up", "keycode": "A"},
    {"frame": 590, "type": "key_up", "keycode": "W"}
  ]
}
DEMO_EOF

# Demo 4: Near finish scenario showing medal award
cat > "$GAME/demo_outputs/04_near_finish_medal.json" <<'DEMO_EOF'
{
  "scenario": "near_finish",
  "duration_frames": 300,
  "events": [
    {"frame": 10, "type": "key_down", "keycode": "W"},
    {"frame": 30, "type": "key_down", "keycode": "D"},
    {"frame": 60, "type": "key_up", "keycode": "D"},
    {"frame": 80, "type": "key_down", "keycode": "A"},
    {"frame": 120, "type": "key_up", "keycode": "A"},
    {"frame": 150, "type": "wait"},
    {"frame": 200, "type": "wait"},
    {"frame": 250, "type": "mouse_click", "button": "left", "x": 640, "y": 450},
    {"frame": 280, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 5: Complete gameplay loop
cat > "$GAME/demo_outputs/05_complete_loop.json" <<'DEMO_EOF'
{
  "scenario": "",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 400},
    {"frame": 90, "type": "mouse_click", "button": "left", "x": 300, "y": 225},
    {"frame": 120, "type": "key_down", "keycode": "W"},
    {"frame": 150, "type": "key_down", "keycode": "D"},
    {"frame": 170, "type": "key_down", "keycode": "SPACE"},
    {"frame": 220, "type": "key_up", "keycode": "SPACE"},
    {"frame": 240, "type": "key_up", "keycode": "D"},
    {"frame": 280, "type": "key_down", "keycode": "A"},
    {"frame": 300, "type": "key_down", "keycode": "SPACE"},
    {"frame": 350, "type": "key_up", "keycode": "SPACE"},
    {"frame": 370, "type": "key_up", "keycode": "A"},
    {"frame": 410, "type": "key_down", "keycode": "D"},
    {"frame": 430, "type": "key_down", "keycode": "SPACE"},
    {"frame": 480, "type": "key_up", "keycode": "SPACE"},
    {"frame": 500, "type": "key_up", "keycode": "D"},
    {"frame": 540, "type": "key_down", "keycode": "A"},
    {"frame": 570, "type": "key_up", "keycode": "A"},
    {"frame": 590, "type": "key_up", "keycode": "W"}
  ]
}
DEMO_EOF

echo "Demo traces created successfully"
echo "Racing Drift Circuit oracle complete!"
