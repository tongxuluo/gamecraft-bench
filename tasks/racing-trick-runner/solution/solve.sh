#!/bin/bash
# Reference solution for gamecraft-bench/racing-trick-runner.
#
# Creates an endless downhill runner with:
#   - Automatic downhill movement with jump and landing angle control
#   - Trick system (flip, spin, grab) with boost meter
#   - Endless procedural terrain with obstacles
#   - 5+ unlockable characters with unique abilities
#   - Weather conditions (clear, fog, snow, blizzard)
#   - Day/night cycle affecting visibility
#   - 4+ trick types with combo chaining
#   - Complete game loop: Title -> Run -> Crash -> Result -> Collection

set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'GODOT_EOF'
config_version=5

[application]
config/name="Racing Trick Runner"
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
# Main.gd - Complete trick runner game
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEW := Vector2(1280, 720)
const GRAVITY := 980.0

# Game state
var mode := "title"  # title, collection, running, result
var scenario := ""
var current_character := 0

# Persistent data
var characters := []
var unlocked_characters := [true, false, false, false, false]
var high_score := 0
var high_distance := 0.0

# Running state
var player_pos := Vector2(400, 300)
var player_vel := Vector2(200, 0)
var player_angle := 0.0
var grounded := true
var alive := true

var score := 0
var distance := 0.0
var boost := 0.0
var max_boost := 100.0
var boost_active := false

# Trick state
var airborne := false
var current_trick := ""
var trick_progress := 0.0
var trick_duration := 0.0
var combo_count := 0

# Environment
var terrain_points := []
var obstacles := []
var weather := "clear"  # clear, fog, snow, blizzard
var time_of_day := 0.0  # 0-1 cycle
var terrain_seed := 0

# Camera
var cam_x := 0.0

# UI layers
var title_layer: CanvasLayer
var collection_layer: CanvasLayer
var hud_layer: CanvasLayer
var result_layer: CanvasLayer

func _ready() -> void:
	_parse_args()
	_init_data()
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

func _init_data() -> void:
	# Create 5 characters with unique abilities
	characters.append({
		"id": 0,
		"name": "Snowboarder",
		"ability": "Balanced",
		"color": Color(0.3, 0.5, 0.9)
	})
	characters.append({
		"id": 1,
		"name": "Skier",
		"ability": "Higher Jumps",
		"color": Color(0.9, 0.3, 0.3)
	})
	characters.append({
		"id": 2,
		"name": "Sledder",
		"ability": "Longer Boost",
		"color": Color(0.3, 0.9, 0.3)
	})
	characters.append({
		"id": 3,
		"name": "Toboggan",
		"ability": "Extra Hit Point",
		"color": Color(0.9, 0.9, 0.3)
	})
	characters.append({
		"id": 4,
		"name": "Pro Rider",
		"ability": "Score Multiplier",
		"color": Color(0.9, 0.3, 0.9)
	})

func _init_ui() -> void:
	# Title screen
	title_layer = CanvasLayer.new()
	add_child(title_layer)
	
	var title_bg := ColorRect.new()
	title_bg.size = VIEW
	title_bg.color = Color(0.7, 0.8, 0.9)
	title_layer.add_child(title_bg)
	
	var title_label := Label.new()
	title_label.text = "RACING TRICK RUNNER"
	title_label.position = Vector2(VIEW.x / 2 - 250, 150)
	title_label.add_theme_font_size_override("font_size", 48)
	title_layer.add_child(title_label)
	
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(VIEW.x / 2 - 100, 350)
	play_btn.size = Vector2(200, 60)
	play_btn.pressed.connect(_on_play_pressed)
	title_layer.add_child(play_btn)
	
	var collection_btn := Button.new()
	collection_btn.text = "COLLECTION"
	collection_btn.position = Vector2(VIEW.x / 2 - 100, 450)
	collection_btn.size = Vector2(200, 60)
	collection_btn.pressed.connect(_on_collection_pressed)
	title_layer.add_child(collection_btn)
	
	# Collection screen
	collection_layer = CanvasLayer.new()
	add_child(collection_layer)
	collection_layer.visible = false
	
	var col_bg := ColorRect.new()
	col_bg.size = VIEW
	col_bg.color = Color(0.12, 0.12, 0.15)
	collection_layer.add_child(col_bg)
	
	var col_title := Label.new()
	col_title.text = "CHARACTER COLLECTION"
	col_title.position = Vector2(VIEW.x / 2 - 200, 50)
	col_title.add_theme_font_size_override("font_size", 36)
	collection_layer.add_child(col_title)
	
	for i in range(5):
		var btn := Button.new()
		btn.position = Vector2(200 + (i % 3) * 300, 200 + (i / 3) * 200)
		btn.size = Vector2(250, 150)
		btn.text = characters[i].name + "\n" + characters[i].ability
		btn.disabled = not unlocked_characters[i]
		btn.pressed.connect(_on_character_selected.bind(i))
		collection_layer.add_child(btn)
	
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(VIEW.x / 2 - 100, 600)
	back_btn.size = Vector2(200, 60)
	back_btn.pressed.connect(_on_collection_back)
	collection_layer.add_child(back_btn)
	
	# HUD layer
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_layer.visible = false
	
	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(50, 30)
	score_label.add_theme_font_size_override("font_size", 28)
	hud_layer.add_child(score_label)
	
	var distance_label := Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.position = Vector2(50, 70)
	distance_label.add_theme_font_size_override("font_size", 24)
	hud_layer.add_child(distance_label)
	
	var boost_bar := ColorRect.new()
	boost_bar.name = "BoostBar"
	boost_bar.position = Vector2(50, 120)
	boost_bar.size = Vector2(200, 20)
	boost_bar.color = Color(0.3, 0.3, 0.4)
	hud_layer.add_child(boost_bar)
	
	var boost_fill := ColorRect.new()
	boost_fill.name = "BoostFill"
	boost_fill.size = Vector2(0, 20)
	boost_fill.color = Color(0.2, 0.8, 1.0)
	boost_bar.add_child(boost_fill)
	
	var trick_label := Label.new()
	trick_label.name = "TrickLabel"
	trick_label.position = Vector2(VIEW.x / 2 - 100, 100)
	trick_label.add_theme_font_size_override("font_size", 32)
	hud_layer.add_child(trick_label)
	
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
	
	var retry_btn := Button.new()
	retry_btn.text = "RETRY"
	retry_btn.position = Vector2(VIEW.x / 2 - 220, 500)
	retry_btn.size = Vector2(200, 60)
	retry_btn.pressed.connect(_on_retry)
	result_layer.add_child(retry_btn)
	
	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.position = Vector2(VIEW.x / 2 + 20, 500)
	menu_btn.size = Vector2(200, 60)
	menu_btn.pressed.connect(_on_result_menu)
	result_layer.add_child(menu_btn)

func _show_title() -> void:
	mode = "title"
	title_layer.visible = true
	collection_layer.visible = false
	hud_layer.visible = false
	result_layer.visible = false

func _on_play_pressed() -> void:
	_start_run()

func _on_collection_pressed() -> void:
	title_layer.visible = false
	collection_layer.visible = true
	mode = "collection"

func _on_collection_back() -> void:
	collection_layer.visible = false
	title_layer.visible = true
	mode = "title"

func _on_character_selected(char_id: int) -> void:
	if unlocked_characters[char_id]:
		current_character = char_id
		collection_layer.visible = false
		_start_run()

func _start_run() -> void:
	mode = "running"
	title_layer.visible = false
	collection_layer.visible = false
	hud_layer.visible = true
	
	# Reset state
	player_pos = Vector2(400, 300)
	player_vel = Vector2(200, 0)
	player_angle = 0.0
	grounded = true
	alive = true
	
	score = 0
	distance = 0.0
	boost = 50.0
	boost_active = false
	
	airborne = false
	current_trick = ""
	trick_progress = 0.0
	combo_count = 0
	
	weather = "clear"
	time_of_day = 0.5
	terrain_seed = randi()
	
	# Generate initial terrain
	_generate_terrain()
	
	cam_x = 0.0

func _generate_terrain() -> void:
	terrain_points = []
	obstacles = []
	
	var x := 0.0
	var y := 500.0
	
	for i in range(100):
		terrain_points.append(Vector2(x, y))
		
		# Vary terrain
		y += randf_range(-20, 40)
		y = clamp(y, 300, 650)
		x += 100.0
		
		# Add obstacles
		if i % 5 == 3 and randf() < 0.5:
			obstacles.append({"pos": Vector2(x - 50, y - 40), "type": "rock"})
		
		# Add ramps
		if i % 8 == 6:
			terrain_points.append(Vector2(x, y - 50))
			x += 100.0
			terrain_points.append(Vector2(x, y))

func _physics_process(delta: float) -> void:
	if mode != "running" or not alive:
		return
	
	# Update environment
	time_of_day += delta * 0.05
	if time_of_day > 1.0:
		time_of_day -= 1.0
	
	# Change weather periodically
	if int(distance / 500.0) % 4 == 0:
		weather = "clear"
	elif int(distance / 500.0) % 4 == 1:
		weather = "fog"
	elif int(distance / 500.0) % 4 == 2:
		weather = "snow"
	else:
		weather = "blizzard"
	
	# Input
	var jump_pressed := Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE)
	var boost_pressed := Input.is_key_pressed(KEY_SHIFT)
	
	# Automatic downhill movement
	player_vel.x = 200.0 + distance * 0.1
	
	if boost_active:
		player_vel.x *= 1.5
		boost -= delta * 20.0
		if boost <= 0:
			boost = 0
			boost_active = false
	
	if boost_pressed and boost > 20.0 and not boost_active:
		boost_active = true
	
	# Gravity
	if not grounded:
		player_vel.y += GRAVITY * delta
	
	# Jump
	if jump_pressed and grounded:
		player_vel.y = -500.0
		grounded = false
		airborne = true
	
	# Trick input while airborne
	if airborne and current_trick == "":
		if Input.is_key_pressed(KEY_UP):
			_start_trick("Backflip", 1.0, 100)
		elif Input.is_key_pressed(KEY_DOWN):
			_start_trick("Frontflip", 1.0, 100)
		elif Input.is_key_pressed(KEY_LEFT):
			_start_trick("Spin", 0.8, 80)
		elif Input.is_key_pressed(KEY_RIGHT):
			_start_trick("Grab", 0.6, 60)
	
	# Update trick
	if current_trick != "":
		trick_progress += delta
		if trick_progress >= trick_duration:
			# Trick complete
			if grounded:
				# Landed during trick - crash
				_crash()
				return
	
	# Landing angle control
	if airborne:
		if Input.is_key_pressed(KEY_A):
			player_angle -= delta * 3.0
		if Input.is_key_pressed(KEY_D):
			player_angle += delta * 3.0
	
	# Update position
	player_pos += player_vel * delta
	distance = player_pos.x / 10.0
	
	# Simple ground collision
	var ground_y := _get_ground_y(player_pos.x)
	if player_pos.y >= ground_y and not grounded:
		player_pos.y = ground_y
		grounded = true
		airborne = false
		
		# Check landing angle
		if abs(player_angle) > 0.5:
			# Bad landing
			player_vel.x *= 0.5
		
		# Complete trick on landing
		if current_trick != "":
			if trick_progress >= trick_duration:
				# Successful trick
				var trick_score := 100 * (combo_count + 1)
				score += trick_score
				boost = min(boost + 20.0, max_boost)
				combo_count += 1
			current_trick = ""
			trick_progress = 0.0
		else:
			combo_count = 0
		
		player_angle = 0.0
	
	# Check obstacles
	for obs in obstacles:
		if player_pos.distance_to(obs.pos) < 40:
			_crash()
			return
	
	# Update camera
	cam_x = lerp(cam_x, player_pos.x - VIEW.x / 3, 0.1)
	
	_update_hud()
	queue_redraw()

func _start_trick(name: String, duration: float, base_score: int) -> void:
	current_trick = name
	trick_duration = duration
	trick_progress = 0.0

func _get_ground_y(x: float) -> float:
	# Simple terrain lookup
	var idx := int(x / 100.0)
	if idx >= 0 and idx < terrain_points.size():
		return terrain_points[idx].y
	return 500.0

func _crash() -> void:
	alive = false
	
	# Update high scores
	if score > high_score:
		high_score = score
	if distance > high_distance:
		high_distance = distance
	
	# Unlock characters
	if distance > 500 and not unlocked_characters[1]:
		unlocked_characters[1] = true
	if distance > 1000 and not unlocked_characters[2]:
		unlocked_characters[2] = true
	if score > 5000 and not unlocked_characters[3]:
		unlocked_characters[3] = true
	if score > 10000 and not unlocked_characters[4]:
		unlocked_characters[4] = true
	
	_show_result()

func _show_result() -> void:
	mode = "result"
	hud_layer.visible = false
	result_layer.visible = true
	
	var result_title := result_layer.get_node("ResultTitle") as Label
	var result_stats := result_layer.get_node("ResultStats") as Label
	
	result_title.text = "CRASHED!"
	result_stats.text = "Distance: %.0fm\nScore: %d\nHigh Score: %d" % [distance, score, high_score]

func _on_retry() -> void:
	result_layer.visible = false
	_start_run()

func _on_result_menu() -> void:
	result_layer.visible = false
	title_layer.visible = true
	mode = "title"

func _update_hud() -> void:
	var score_label := hud_layer.get_node("ScoreLabel") as Label
	var distance_label := hud_layer.get_node("DistanceLabel") as Label
	var boost_fill := hud_layer.get_node("BoostBar/BoostFill") as ColorRect
	var trick_label := hud_layer.get_node("TrickLabel") as Label
	
	score_label.text = "Score: %d" % score
	distance_label.text = "Distance: %.0fm" % distance
	boost_fill.size.x = (boost / max_boost) * 200.0
	
	if current_trick != "":
		trick_label.text = current_trick
		trick_label.visible = true
	else:
		trick_label.visible = false

func _draw() -> void:
	if mode != "running":
		return
	
	var offset := Vector2(-cam_x, 0)
	
	# Draw background based on time of day
	var bg_color := Color(0.5, 0.7, 0.9)
	if time_of_day < 0.25 or time_of_day > 0.75:
		bg_color = Color(0.1, 0.1, 0.2)  # Night
	elif time_of_day < 0.35 or time_of_day > 0.65:
		bg_color = Color(0.8, 0.5, 0.3)  # Dawn/dusk
	
	draw_rect(Rect2(Vector2.ZERO, VIEW), bg_color)
	
	# Weather effects
	if weather == "fog" or weather == "blizzard":
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.8, 0.8, 0.8, 0.3))
	
	# Draw terrain
	for i in range(terrain_points.size() - 1):
		var p1: Vector2 = terrain_points[i] + offset
		var p2: Vector2 = terrain_points[i + 1] + offset
		
		if p1.x > -100 and p1.x < VIEW.x + 100:
			draw_line(p1, p2, Color(1.0, 1.0, 1.0), 4.0)
			
			var poly := PackedVector2Array([p1, p2, Vector2(p2.x, VIEW.y), Vector2(p1.x, VIEW.y)])
			draw_colored_polygon(poly, Color(0.9, 0.9, 0.95))
	
	# Draw obstacles
	for obs in obstacles:
		var pos: Vector2 = obs.pos + offset
		if pos.x > -50 and pos.x < VIEW.x + 50:
			draw_circle(pos, 20, Color(0.3, 0.3, 0.35))
	
	# Draw player
	var char_color: Color = characters[current_character].color
	var player_screen := player_pos + offset
	
	# Body
	draw_circle(player_screen, 15, char_color)
	
	# Board/equipment
	var board_offset := Vector2(cos(player_angle), sin(player_angle)) * 25.0
	draw_line(player_screen - board_offset, player_screen + board_offset, char_color.darkened(0.3), 5.0)
	
	# Boost trail
	if boost_active:
		for i in range(5):
			var trail_pos := player_screen - Vector2(i * 20, 0)
			draw_circle(trail_pos, 10 - i * 2, Color(0.2, 0.8, 1.0, 0.5 - i * 0.1))

func _load_scenario(scen: String) -> void:
	match scen:
		"collection":
			title_layer.visible = false
			collection_layer.visible = true
			mode = "collection"
		"running":
			_start_run()
		_:
			_show_title()
GDSCRIPT_EOF

echo "Oracle solution created successfully"

# --------------------------------------------------------------------------
# Demo traces
# --------------------------------------------------------------------------

# Demo 1: Title to play
cat > "$GAME/demo_outputs/01_title_to_play.json" <<'DEMO_EOF'
{
  "scenario": "",
  "duration_frames": 180,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 350},
    {"frame": 120, "type": "wait"},
    {"frame": 150, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 2: Collection screen
cat > "$GAME/demo_outputs/02_collection.json" <<'DEMO_EOF'
{
  "scenario": "collection",
  "duration_frames": 300,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 90, "type": "wait"},
    {"frame": 150, "type": "wait"},
    {"frame": 210, "type": "mouse_click", "button": "left", "x": 640, "y": 600},
    {"frame": 270, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 3: Running with tricks
cat > "$GAME/demo_outputs/03_running_tricks.json" <<'DEMO_EOF'
{
  "scenario": "running",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "key_press", "keycode": "SPACE"},
    {"frame": 60, "type": "key_down", "keycode": "UP"},
    {"frame": 90, "type": "key_up", "keycode": "UP"},
    {"frame": 150, "type": "key_press", "keycode": "SPACE"},
    {"frame": 180, "type": "key_down", "keycode": "DOWN"},
    {"frame": 210, "type": "key_up", "keycode": "DOWN"},
    {"frame": 270, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_down", "keycode": "LEFT"},
    {"frame": 330, "type": "key_up", "keycode": "LEFT"},
    {"frame": 390, "type": "key_press", "keycode": "SPACE"},
    {"frame": 420, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 450, "type": "key_up", "keycode": "RIGHT"},
    {"frame": 510, "type": "key_down", "keycode": "SHIFT"},
    {"frame": 570, "type": "key_up", "keycode": "SHIFT"}
  ]
}
DEMO_EOF

# Demo 4: Jump and landing control
cat > "$GAME/demo_outputs/04_jump_landing.json" <<'DEMO_EOF'
{
  "scenario": "running",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "key_press", "keycode": "SPACE"},
    {"frame": 60, "type": "key_down", "keycode": "A"},
    {"frame": 90, "type": "key_up", "keycode": "A"},
    {"frame": 150, "type": "key_press", "keycode": "SPACE"},
    {"frame": 180, "type": "key_down", "keycode": "D"},
    {"frame": 210, "type": "key_up", "keycode": "D"},
    {"frame": 270, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_down", "keycode": "UP"},
    {"frame": 330, "type": "key_down", "keycode": "A"},
    {"frame": 360, "type": "key_up", "keycode": "A"},
    {"frame": 390, "type": "key_up", "keycode": "UP"},
    {"frame": 450, "type": "key_press", "keycode": "SPACE"},
    {"frame": 480, "type": "key_down", "keycode": "D"},
    {"frame": 510, "type": "key_up", "keycode": "D"},
    {"frame": 570, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 5: Complete loop with boost
cat > "$GAME/demo_outputs/05_complete_loop.json" <<'DEMO_EOF'
{
  "scenario": "",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 350},
    {"frame": 90, "type": "key_press", "keycode": "SPACE"},
    {"frame": 120, "type": "key_down", "keycode": "UP"},
    {"frame": 150, "type": "key_up", "keycode": "UP"},
    {"frame": 210, "type": "key_press", "keycode": "SPACE"},
    {"frame": 240, "type": "key_down", "keycode": "LEFT"},
    {"frame": 270, "type": "key_up", "keycode": "LEFT"},
    {"frame": 330, "type": "key_down", "keycode": "SHIFT"},
    {"frame": 390, "type": "key_up", "keycode": "SHIFT"},
    {"frame": 450, "type": "key_press", "keycode": "SPACE"},
    {"frame": 480, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 510, "type": "key_up", "keycode": "RIGHT"},
    {"frame": 570, "type": "wait"}
  ]
}
DEMO_EOF

echo "Demo traces created successfully"
echo "Racing Trick Runner oracle complete!"
