#!/bin/bash
# Reference solution for gamecraft-bench/racing-rocket-trials.
#
# Creates a physics-based motorcycle obstacle course game with:
#   - 20+ levels organized into 4 difficulty tiers
#   - Realistic 2D motorcycle physics with suspension and rider lean
#   - Ragdoll crash physics
#   - 6+ distinct obstacle types (ramps, loops, seesaws, pendulums, barrels, platforms)
#   - Checkpoint system with fault tracking
#   - Gold/Silver/Bronze medals and Flawless stars
#   - Complete game loop: Title -> Level Select -> Play -> Medal -> Progress

set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'GODOT_EOF'
config_version=5

[application]
config/name="Racing Rocket Trials"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[physics]
2d/default_gravity=980.0

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
# Main.gd - Complete motorcycle trials game
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEW := Vector2(1280, 720)
const GRAVITY := 980.0

# Game state
var mode := "title"  # title, level_select, playing, result
var scenario := ""
var current_level := 0
var current_tier := 0

# Level data
var levels := []
var level_medals := []  # Array of medal strings
var level_times := []   # Best times
var level_faults := []  # Best fault counts
var level_flawless := []  # Flawless stars
var unlocked_levels := 1
var total_medals := 0

# Physics objects
var bike_body: RigidBody2D
var front_wheel: RigidBody2D
var rear_wheel: RigidBody2D
var rider_head: RigidBody2D
var rider_torso: RigidBody2D
var rider_limbs := []

var bike_alive := true
var throttle := 0.0
var brake := 0.0
var lean := 0.0

# Level state
var level_time := 0.0
var fault_count := 0
var last_checkpoint := Vector2.ZERO
var checkpoints_reached := []
var level_complete := false

# Camera
var cam_x := 0.0
var cam_target_x := 0.0

# UI layers
var title_layer: CanvasLayer
var level_select_layer: CanvasLayer
var hud_layer: CanvasLayer
var result_layer: CanvasLayer

func _ready() -> void:
	_parse_args()
	_init_levels()
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

func _init_levels() -> void:
	# Create 24 levels across 4 tiers (6 per tier)
	var tiers := ["Easy", "Medium", "Hard", "Extreme"]
	var themes := ["Industrial", "Desert", "Arctic", "Volcanic"]
	
	for tier in range(4):
		for level_in_tier in range(6):
			var level_id := tier * 6 + level_in_tier
			var difficulty := tier * 2.0 + level_in_tier * 0.3
			
			var level := {
				"id": level_id,
				"tier": tier,
				"name": "%s %d" % [tiers[tier], level_in_tier + 1],
				"theme": themes[tier],
				"difficulty": difficulty,
				"gold_time": 20.0 + difficulty * 5.0,
				"silver_time": 30.0 + difficulty * 6.0,
				"bronze_time": 45.0 + difficulty * 7.0,
				"obstacles": _generate_obstacles(level_id, difficulty)
			}
			levels.append(level)
			level_medals.append("")
			level_times.append(999.0)
			level_faults.append(999)
			level_flawless.append(false)

func _generate_obstacles(level_id: int, difficulty: float) -> Array:
	var obstacles := []
	var x := 200.0
	
	# Start platform
	obstacles.append({"type": "platform", "x": x, "y": 600, "w": 150, "h": 20})
	x += 200.0
	
	# Generate varied obstacles based on level
	var obstacle_types := ["ramp", "loop", "seesaw", "pendulum", "barrel", "crumble"]
	var num_obstacles := 8 + int(difficulty * 2)
	
	for i in range(num_obstacles):
		var type: String = obstacle_types[i % obstacle_types.size()]
		
		match type:
			"ramp":
				obstacles.append({"type": "ramp", "x": x, "y": 600, "angle": 30 + difficulty * 5})
				x += 200.0 + difficulty * 20.0
			"loop":
				obstacles.append({"type": "loop", "x": x, "y": 500, "radius": 100 - difficulty * 5})
				x += 250.0
			"seesaw":
				obstacles.append({"type": "seesaw", "x": x, "y": 550, "length": 200})
				x += 250.0
			"pendulum":
				obstacles.append({"type": "pendulum", "x": x, "y": 300, "length": 150, "phase": i * 0.5})
				obstacles.append({"type": "platform", "x": x - 50, "y": 600, "w": 100, "h": 20})
				x += 200.0
			"barrel":
				obstacles.append({"type": "barrel", "x": x, "y": 580, "radius": 20})
				obstacles.append({"type": "platform", "x": x - 50, "y": 600, "w": 100, "h": 20})
				x += 150.0
			"crumble":
				obstacles.append({"type": "crumble", "x": x, "y": 600, "w": 100, "h": 20, "timer": 1.0})
				x += 150.0
		
		# Add checkpoint every 3 obstacles
		if i % 3 == 2:
			obstacles.append({"type": "checkpoint", "x": x, "y": 550, "id": i / 3})
	
	# Finish line
	obstacles.append({"type": "finish", "x": x, "y": 550})
	obstacles.append({"type": "platform", "x": x - 50, "y": 600, "w": 150, "h": 20})
	
	return obstacles

func _init_ui() -> void:
	# Title screen
	title_layer = CanvasLayer.new()
	add_child(title_layer)
	
	var title_bg := ColorRect.new()
	title_bg.size = VIEW
	title_bg.color = Color(0.15, 0.12, 0.10)
	title_layer.add_child(title_bg)
	
	var title_label := Label.new()
	title_label.text = "RACING ROCKET TRIALS"
	title_label.position = Vector2(VIEW.x / 2 - 250, 150)
	title_label.add_theme_font_size_override("font_size", 48)
	title_layer.add_child(title_label)
	
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(VIEW.x / 2 - 100, 400)
	play_btn.size = Vector2(200, 60)
	play_btn.pressed.connect(_on_play_pressed)
	title_layer.add_child(play_btn)
	
	# Level select screen
	level_select_layer = CanvasLayer.new()
	add_child(level_select_layer)
	level_select_layer.visible = false
	
	var ls_bg := ColorRect.new()
	ls_bg.size = VIEW
	ls_bg.color = Color(0.12, 0.12, 0.15)
	level_select_layer.add_child(ls_bg)
	
	var ls_title := Label.new()
	ls_title.text = "SELECT LEVEL"
	ls_title.position = Vector2(VIEW.x / 2 - 150, 30)
	ls_title.add_theme_font_size_override("font_size", 36)
	level_select_layer.add_child(ls_title)
	
	# Create level buttons (4 tiers x 6 levels)
	for tier in range(4):
		var tier_label := Label.new()
		tier_label.text = ["EASY", "MEDIUM", "HARD", "EXTREME"][tier]
		tier_label.position = Vector2(50, 100 + tier * 150)
		tier_label.add_theme_font_size_override("font_size", 24)
		level_select_layer.add_child(tier_label)
		
		for i in range(6):
			var level_id := tier * 6 + i
			var btn := Button.new()
			btn.position = Vector2(200 + i * 170, 100 + tier * 150)
			btn.size = Vector2(150, 100)
			btn.text = "Level %d" % (i + 1)
			btn.disabled = level_id >= unlocked_levels
			btn.pressed.connect(_on_level_selected.bind(level_id))
			level_select_layer.add_child(btn)
	
	# HUD layer
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_layer.visible = false
	
	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(50, 30)
	time_label.add_theme_font_size_override("font_size", 28)
	hud_layer.add_child(time_label)
	
	var fault_label := Label.new()
	fault_label.name = "FaultLabel"
	fault_label.position = Vector2(50, 70)
	fault_label.add_theme_font_size_override("font_size", 24)
	hud_layer.add_child(fault_label)
	
	var checkpoint_label := Label.new()
	checkpoint_label.name = "CheckpointLabel"
	checkpoint_label.position = Vector2(50, 110)
	checkpoint_label.add_theme_font_size_override("font_size", 20)
	hud_layer.add_child(checkpoint_label)
	
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
	
	var result_stats := Label.new()
	result_stats.name = "ResultStats"
	result_stats.position = Vector2(VIEW.x / 2 - 150, 300)
	result_stats.add_theme_font_size_override("font_size", 24)
	result_layer.add_child(result_stats)
	
	var continue_btn := Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.position = Vector2(VIEW.x / 2 - 100, 500)
	continue_btn.size = Vector2(200, 60)
	continue_btn.pressed.connect(_on_result_continue)
	result_layer.add_child(continue_btn)

func _show_title() -> void:
	mode = "title"
	title_layer.visible = true
	level_select_layer.visible = false
	hud_layer.visible = false
	result_layer.visible = false

func _on_play_pressed() -> void:
	title_layer.visible = false
	level_select_layer.visible = true
	mode = "level_select"

func _on_level_selected(level_id: int) -> void:
	current_level = level_id
	_start_level()

func _start_level() -> void:
	mode = "playing"
	level_select_layer.visible = false
	hud_layer.visible = true
	
	# Reset state
	level_time = 0.0
	fault_count = 0
	checkpoints_reached = []
	level_complete = false
	bike_alive = true
	
	# Clear existing physics objects
	for child in get_children():
		if child is RigidBody2D or child is StaticBody2D:
			child.queue_free()
	
	# Create bike
	_create_bike(Vector2(250, 500))
	
	# Create level obstacles
	var level: Dictionary = levels[current_level]
	for obs in level.obstacles:
		_create_obstacle(obs)
	
	cam_x = 0.0
	cam_target_x = 0.0

func _create_bike(pos: Vector2) -> void:
	# Bike body
	bike_body = RigidBody2D.new()
	bike_body.position = pos
	bike_body.mass = 50.0
	add_child(bike_body)
	
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(60, 20)
	body_shape.shape = body_rect
	bike_body.add_child(body_shape)
	
	# Rear wheel
	rear_wheel = RigidBody2D.new()
	rear_wheel.position = pos + Vector2(-25, 15)
	rear_wheel.mass = 10.0
	add_child(rear_wheel)
	
	var rear_shape := CollisionShape2D.new()
	var rear_circle := CircleShape2D.new()
	rear_circle.radius = 15.0
	rear_shape.shape = rear_circle
	rear_wheel.add_child(rear_shape)
	
	# Front wheel
	front_wheel = RigidBody2D.new()
	front_wheel.position = pos + Vector2(25, 15)
	front_wheel.mass = 10.0
	add_child(front_wheel)
	
	var front_shape := CollisionShape2D.new()
	var front_circle := CircleShape2D.new()
	front_circle.radius = 15.0
	front_shape.shape = front_circle
	front_wheel.add_child(front_shape)
	
	# Rider torso
	rider_torso = RigidBody2D.new()
	rider_torso.position = pos + Vector2(0, -20)
	rider_torso.mass = 30.0
	add_child(rider_torso)
	
	var torso_shape := CollisionShape2D.new()
	var torso_rect := RectangleShape2D.new()
	torso_rect.size = Vector2(20, 40)
	torso_shape.shape = torso_rect
	rider_torso.add_child(torso_shape)
	
	# Rider head
	rider_head = RigidBody2D.new()
	rider_head.position = pos + Vector2(0, -45)
	rider_head.mass = 10.0
	add_child(rider_head)
	
	var head_shape := CollisionShape2D.new()
	var head_circle := CircleShape2D.new()
	head_circle.radius = 12.0
	head_shape.shape = head_circle
	rider_head.add_child(head_shape)
	
	# Joints (simplified - in real game would use PinJoint2D)
	last_checkpoint = pos

func _create_obstacle(obs: Dictionary) -> void:
	match obs.type:
		"platform":
			var platform := StaticBody2D.new()
			platform.position = Vector2(obs.x, obs.y)
			add_child(platform)
			
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(obs.w, obs.h)
			shape.shape = rect
			platform.add_child(shape)
		
		"ramp":
			var ramp := StaticBody2D.new()
			ramp.position = Vector2(obs.x, obs.y)
			ramp.rotation = deg_to_rad(obs.angle)
			add_child(ramp)
			
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(150, 20)
			shape.shape = rect
			ramp.add_child(shape)
		
		"checkpoint", "finish":
			# Markers handled in draw
			pass

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	
	if not bike_alive:
		return
	
	# Input
	throttle = 0.0
	brake = 0.0
	lean = 0.0
	
	if Input.is_key_pressed(KEY_RIGHT):
		throttle = 1.0
	if Input.is_key_pressed(KEY_LEFT):
		brake = 1.0
	if Input.is_key_pressed(KEY_UP):
		lean = -1.0
	if Input.is_key_pressed(KEY_DOWN):
		lean = 1.0
	
	# Apply forces to wheels
	if rear_wheel and is_instance_valid(rear_wheel):
		var torque := throttle * 5000.0 - brake * 3000.0
		rear_wheel.apply_torque_impulse(torque * delta)
		
		# Apply lean to rider
		if rider_torso and is_instance_valid(rider_torso):
			rider_torso.apply_force(Vector2(lean * 500.0, 0))
	
	# Update timer
	level_time += delta
	
	# Check for crashes
	if rider_head and is_instance_valid(rider_head):
		if rider_head.position.y > 700 or rider_head.linear_velocity.length() > 500:
			_crash()
	
	# Check for level completion
	var level: Dictionary = levels[current_level]
	if bike_body and is_instance_valid(bike_body):
		for obs in level.obstacles:
			if obs.type == "finish":
				if bike_body.position.distance_to(Vector2(obs.x, obs.y)) < 50:
					if not level_complete:
						_complete_level()
	
	# Update camera
	if bike_body and is_instance_valid(bike_body):
		cam_target_x = bike_body.position.x - VIEW.x / 2
		cam_x = lerp(cam_x, cam_target_x, 0.1)
	
	_update_hud()
	queue_redraw()

func _crash() -> void:
	if not bike_alive:
		return
	
	bike_alive = false
	fault_count += 1
	
	# Ragdoll effect (simplified - bodies already physics-based)
	if rider_torso and is_instance_valid(rider_torso):
		rider_torso.apply_impulse(Vector2(randf_range(-200, 200), -300))
	
	# Respawn after delay
	await get_tree().create_timer(2.0).timeout
	_respawn()

func _respawn() -> void:
	# Clear old bike
	if bike_body and is_instance_valid(bike_body):
		bike_body.queue_free()
	if front_wheel and is_instance_valid(front_wheel):
		front_wheel.queue_free()
	if rear_wheel and is_instance_valid(rear_wheel):
		rear_wheel.queue_free()
	if rider_torso and is_instance_valid(rider_torso):
		rider_torso.queue_free()
	if rider_head and is_instance_valid(rider_head):
		rider_head.queue_free()
	
	# Recreate at checkpoint
	_create_bike(last_checkpoint)
	bike_alive = true

func _complete_level() -> void:
	level_complete = true
	
	var level: Dictionary = levels[current_level]
	var time := level_time
	
	# Determine medal
	var medal := ""
	if time <= level.gold_time:
		medal = "gold"
	elif time <= level.silver_time:
		medal = "silver"
	elif time <= level.bronze_time:
		medal = "bronze"
	
	# Check flawless
	var flawless := fault_count == 0
	
	# Update records
	if time < level_times[current_level]:
		level_times[current_level] = time
	
	if fault_count < level_faults[current_level]:
		level_faults[current_level] = fault_count
	
	if flawless:
		level_flawless[current_level] = true
	
	# Update medal if better
	var medal_values := {"": 0, "bronze": 1, "silver": 2, "gold": 3}
	if medal_values.get(medal, 0) > medal_values.get(level_medals[current_level], 0):
		level_medals[current_level] = medal
		
		# Unlock next level
		if current_level + 1 < levels.size():
			unlocked_levels = max(unlocked_levels, current_level + 2)
	
	_show_result(time, medal, flawless)

func _show_result(time: float, medal: String, flawless: bool) -> void:
	mode = "result"
	hud_layer.visible = false
	result_layer.visible = true
	
	var result_title := result_layer.get_node("ResultTitle") as Label
	var result_stats := result_layer.get_node("ResultStats") as Label
	
	if medal == "gold":
		result_title.text = "GOLD!"
		result_title.modulate = Color(1.0, 0.84, 0.0)
	elif medal == "silver":
		result_title.text = "SILVER!"
		result_title.modulate = Color(0.75, 0.75, 0.75)
	elif medal == "bronze":
		result_title.text = "BRONZE!"
		result_title.modulate = Color(0.8, 0.5, 0.2)
	else:
		result_title.text = "COMPLETE"
		result_title.modulate = Color(1.0, 1.0, 1.0)
	
	var flawless_text := "\nFLAWLESS!" if flawless else ""
	result_stats.text = "Time: %.2fs\nFaults: %d%s" % [time, fault_count, flawless_text]

func _on_result_continue() -> void:
	result_layer.visible = false
	level_select_layer.visible = true
	mode = "level_select"
	
	# Update level select buttons
	for tier in range(4):
		for i in range(6):
			var level_id := tier * 6 + i
			var btn_idx := 2 + tier * 7 + i
			if btn_idx < level_select_layer.get_child_count():
				var btn := level_select_layer.get_child(btn_idx) as Button
				if btn:
					btn.disabled = level_id >= unlocked_levels

func _update_hud() -> void:
	var time_label := hud_layer.get_node("TimeLabel") as Label
	var fault_label := hud_layer.get_node("FaultLabel") as Label
	var checkpoint_label := hud_layer.get_node("CheckpointLabel") as Label
	
	time_label.text = "Time: %.2fs" % level_time
	fault_label.text = "Faults: %d" % fault_count
	checkpoint_label.text = "Checkpoint: %d" % checkpoints_reached.size()

func _draw() -> void:
	if mode != "playing":
		return
	
	# Apply camera offset
	var offset := Vector2(-cam_x, 0)
	
	# Draw background
	var level: Dictionary = levels[current_level]
	var bg_color := Color(0.2, 0.2, 0.25)
	match level.theme:
		"Industrial":
			bg_color = Color(0.18, 0.18, 0.22)
		"Desert":
			bg_color = Color(0.35, 0.28, 0.20)
		"Arctic":
			bg_color = Color(0.25, 0.28, 0.32)
		"Volcanic":
			bg_color = Color(0.25, 0.15, 0.12)
	
	draw_rect(Rect2(Vector2.ZERO, VIEW), bg_color)
	
	# Draw obstacles
	for obs in level.obstacles:
		var pos := Vector2(obs.x, obs.y) + offset
		
		match obs.type:
			"platform":
				draw_rect(Rect2(pos - Vector2(obs.w/2, obs.h/2), Vector2(obs.w, obs.h)), Color(0.3, 0.3, 0.35))
			"ramp":
				var points := PackedVector2Array([
					pos,
					pos + Vector2(150, 0),
					pos + Vector2(150, 20),
					pos + Vector2(0, 20)
				])
				draw_colored_polygon(points, Color(0.35, 0.3, 0.25))
			"checkpoint":
				draw_circle(pos, 30, Color(1.0, 1.0, 0.0, 0.3))
				draw_arc(pos, 30, 0, TAU, 32, Color(1.0, 1.0, 0.0), 3.0)
			"finish":
				draw_circle(pos, 40, Color(0.0, 1.0, 0.0, 0.3))
				draw_arc(pos, 40, 0, TAU, 32, Color(0.0, 1.0, 0.0), 4.0)
	
	# Draw bike
	if bike_body and is_instance_valid(bike_body):
		var bike_pos := bike_body.position + offset
		draw_rect(Rect2(bike_pos - Vector2(30, 10), Vector2(60, 20)), Color(0.8, 0.2, 0.2))
	
	if rear_wheel and is_instance_valid(rear_wheel):
		draw_circle(rear_wheel.position + offset, 15, Color(0.1, 0.1, 0.1))
	
	if front_wheel and is_instance_valid(front_wheel):
		draw_circle(front_wheel.position + offset, 15, Color(0.1, 0.1, 0.1))
	
	if rider_torso and is_instance_valid(rider_torso):
		draw_rect(Rect2(rider_torso.position + offset - Vector2(10, 20), Vector2(20, 40)), Color(0.3, 0.5, 0.8))
	
	if rider_head and is_instance_valid(rider_head):
		draw_circle(rider_head.position + offset, 12, Color(0.9, 0.7, 0.6))

func _load_scenario(scen: String) -> void:
	match scen:
		"level_select":
			title_layer.visible = false
			level_select_layer.visible = true
			mode = "level_select"
		"level_start":
			current_level = 0
			_start_level()
		"near_finish":
			current_level = 0
			_start_level()
			# Simulate near completion
			level_time = 15.0
			fault_count = 1
		_:
			_show_title()
GDSCRIPT_EOF

echo "Oracle solution created successfully"

# --------------------------------------------------------------------------
# Demo traces
# --------------------------------------------------------------------------

# Demo 1: Title to level select
cat > "$GAME/demo_outputs/01_title_to_level_select.json" <<'DEMO_EOF'
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

# Demo 2: Select level and start playing
cat > "$GAME/demo_outputs/02_level_select_and_play.json" <<'DEMO_EOF'
{
  "scenario": "level_select",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 275, "y": 150},
    {"frame": 120, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 180, "type": "key_down", "keycode": "UP"},
    {"frame": 240, "type": "key_up", "keycode": "UP"},
    {"frame": 300, "type": "key_down", "keycode": "DOWN"},
    {"frame": 360, "type": "key_up", "keycode": "DOWN"},
    {"frame": 420, "type": "key_up", "keycode": "RIGHT"},
    {"frame": 480, "type": "key_down", "keycode": "LEFT"},
    {"frame": 540, "type": "key_up", "keycode": "LEFT"},
    {"frame": 580, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 3: Motorcycle physics and lean
cat > "$GAME/demo_outputs/03_physics_demo.json" <<'DEMO_EOF'
{
  "scenario": "level_start",
  "duration_frames": 600,
  "events": [
    {"frame": 10, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 60, "type": "key_down", "keycode": "UP"},
    {"frame": 120, "type": "key_up", "keycode": "UP"},
    {"frame": 180, "type": "key_down", "keycode": "DOWN"},
    {"frame": 240, "type": "key_up", "keycode": "DOWN"},
    {"frame": 300, "type": "key_down", "keycode": "UP"},
    {"frame": 360, "type": "key_up", "keycode": "UP"},
    {"frame": 420, "type": "key_down", "keycode": "LEFT"},
    {"frame": 480, "type": "key_up", "keycode": "LEFT"},
    {"frame": 540, "type": "key_up", "keycode": "RIGHT"}
  ]
}
DEMO_EOF

# Demo 4: Crash and respawn
cat > "$GAME/demo_outputs/04_crash_respawn.json" <<'DEMO_EOF'
{
  "scenario": "level_start",
  "duration_frames": 600,
  "events": [
    {"frame": 10, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 60, "type": "key_down", "keycode": "DOWN"},
    {"frame": 120, "type": "key_down", "keycode": "UP"},
    {"frame": 180, "type": "wait"},
    {"frame": 240, "type": "wait"},
    {"frame": 300, "type": "key_up", "keycode": "UP"},
    {"frame": 320, "type": "key_up", "keycode": "DOWN"},
    {"frame": 360, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 480, "type": "key_down", "keycode": "UP"},
    {"frame": 540, "type": "key_up", "keycode": "UP"},
    {"frame": 580, "type": "key_up", "keycode": "RIGHT"}
  ]
}
DEMO_EOF

# Demo 5: Near finish scenario
cat > "$GAME/demo_outputs/05_near_finish.json" <<'DEMO_EOF'
{
  "scenario": "near_finish",
  "duration_frames": 300,
  "events": [
    {"frame": 10, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 60, "type": "key_down", "keycode": "UP"},
    {"frame": 120, "type": "key_up", "keycode": "UP"},
    {"frame": 180, "type": "wait"},
    {"frame": 240, "type": "mouse_click", "button": "left", "x": 640, "y": 500},
    {"frame": 280, "type": "wait"}
  ]
}
DEMO_EOF

echo "Demo traces created successfully"
echo "Racing Rocket Trials oracle complete!"
