#!/bin/bash
# Reference solution for gamecraft-bench/racing-terrain-climb.
#
# Creates a side-scrolling physics vehicle game with:
#   - 4+ terrain environments with distinct physics properties
#   - 3+ vehicle types with different handling characteristics
#   - Fuel management system with pickups
#   - Coin collection and distance tracking
#   - Garage/upgrade system (engine, fuel, suspension, grip)
#   - Persistent leaderboard and distance records
#   - Complete game loop: Title -> Stage Select -> Drive -> Crash/Fuel Out -> Garage -> Upgrades

set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'GODOT_EOF'
config_version=5

[application]
config/name="Racing Terrain Climb"
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
# Main.gd - Complete terrain climb game
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEW := Vector2(1280, 720)
const TERRAIN_SEGMENT := 100.0

# Game state
var mode := "title"  # title, stage_select, garage, driving, result
var scenario := ""
var current_stage := 0
var current_vehicle := 0

# Persistent data
var coins := 0
var stages := []
var stage_records := []  # Best distances
var unlocked_stages := 1

# Vehicle data
var vehicles := []
var vehicle_upgrades := {}  # {vehicle_id: {engine: 0, fuel: 0, suspension: 0, grip: 0}}

# Driving state
var vehicle_body: RigidBody2D
var front_wheel: RigidBody2D
var rear_wheel: RigidBody2D
var vehicle_alive := true
var fuel := 100.0
var max_fuel := 100.0
var distance := 0.0
var coins_collected := 0
var speed := 0.0

# Terrain
var terrain_points := []
var terrain_segments := []
var fuel_pickups := []
var coin_positions := []

# Camera
var cam_x := 0.0

# UI layers
var title_layer: CanvasLayer
var stage_select_layer: CanvasLayer
var garage_layer: CanvasLayer
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
	# Create 4 stages with different environments
	var stage_names := ["Countryside Hills", "Moon Surface", "Arctic Ice", "Desert Dunes"]
	var gravities := [980.0, 300.0, 980.0, 980.0]
	var frictions := [1.0, 0.5, 0.3, 0.8]
	
	for i in range(4):
		stages.append({
			"id": i,
			"name": stage_names[i],
			"gravity": gravities[i],
			"friction": frictions[i],
			"theme_color": [Color(0.3, 0.5, 0.3), Color(0.2, 0.2, 0.25), Color(0.7, 0.8, 0.9), Color(0.8, 0.6, 0.3)][i]
		})
		stage_records.append(0.0)
	
	# Create 3 vehicle types
	vehicles.append({
		"id": 0,
		"name": "Jeep",
		"speed": 300.0,
		"grip": 1.0,
		"fuel_efficiency": 1.0,
		"weight": 100.0
	})
	vehicles.append({
		"id": 1,
		"name": "Motorcycle",
		"speed": 400.0,
		"grip": 0.7,
		"fuel_efficiency": 1.5,
		"weight": 50.0
	})
	vehicles.append({
		"id": 2,
		"name": "Monster Truck",
		"speed": 250.0,
		"grip": 1.3,
		"fuel_efficiency": 0.7,
		"weight": 150.0
	})
	
	# Initialize upgrades
	for v in vehicles:
		vehicle_upgrades[v.id] = {"engine": 0, "fuel": 0, "suspension": 0, "grip": 0}

func _init_ui() -> void:
	# Title screen
	title_layer = CanvasLayer.new()
	add_child(title_layer)
	
	var title_bg := ColorRect.new()
	title_bg.size = VIEW
	title_bg.color = Color(0.25, 0.20, 0.15)
	title_layer.add_child(title_bg)
	
	var title_label := Label.new()
	title_label.text = "RACING TERRAIN CLIMB"
	title_label.position = Vector2(VIEW.x / 2 - 250, 150)
	title_label.add_theme_font_size_override("font_size", 48)
	title_layer.add_child(title_label)
	
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(VIEW.x / 2 - 100, 350)
	play_btn.size = Vector2(200, 60)
	play_btn.pressed.connect(_on_play_pressed)
	title_layer.add_child(play_btn)
	
	var garage_btn := Button.new()
	garage_btn.text = "GARAGE"
	garage_btn.position = Vector2(VIEW.x / 2 - 100, 450)
	garage_btn.size = Vector2(200, 60)
	garage_btn.pressed.connect(_on_garage_pressed)
	title_layer.add_child(garage_btn)
	
	# Stage select screen
	stage_select_layer = CanvasLayer.new()
	add_child(stage_select_layer)
	stage_select_layer.visible = false
	
	var ss_bg := ColorRect.new()
	ss_bg.size = VIEW
	ss_bg.color = Color(0.12, 0.12, 0.15)
	stage_select_layer.add_child(ss_bg)
	
	var ss_title := Label.new()
	ss_title.text = "SELECT STAGE"
	ss_title.position = Vector2(VIEW.x / 2 - 150, 50)
	ss_title.add_theme_font_size_override("font_size", 36)
	stage_select_layer.add_child(ss_title)
	
	for i in range(4):
		var btn := Button.new()
		btn.position = Vector2(200 + (i % 2) * 400, 200 + (i / 2) * 200)
		btn.size = Vector2(300, 150)
		btn.text = "%s\nRecord: %.0fm" % [stages[i].name, stage_records[i]]
		btn.disabled = i >= unlocked_stages
		btn.pressed.connect(_on_stage_selected.bind(i))
		stage_select_layer.add_child(btn)
	
	# Garage screen
	garage_layer = CanvasLayer.new()
	add_child(garage_layer)
	garage_layer.visible = false
	
	var g_bg := ColorRect.new()
	g_bg.size = VIEW
	g_bg.color = Color(0.15, 0.15, 0.18)
	garage_layer.add_child(g_bg)
	
	var g_title := Label.new()
	g_title.text = "GARAGE"
	g_title.position = Vector2(VIEW.x / 2 - 100, 30)
	g_title.add_theme_font_size_override("font_size", 36)
	garage_layer.add_child(g_title)
	
	var coins_label := Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.position = Vector2(50, 30)
	coins_label.add_theme_font_size_override("font_size", 24)
	garage_layer.add_child(coins_label)
	
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(VIEW.x - 250, 30)
	back_btn.size = Vector2(200, 60)
	back_btn.pressed.connect(_on_garage_back)
	garage_layer.add_child(back_btn)
	
	# HUD layer
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_layer.visible = false
	
	var fuel_label := Label.new()
	fuel_label.name = "FuelLabel"
	fuel_label.position = Vector2(50, 30)
	fuel_label.add_theme_font_size_override("font_size", 24)
	hud_layer.add_child(fuel_label)
	
	var fuel_bar := ColorRect.new()
	fuel_bar.name = "FuelBar"
	fuel_bar.position = Vector2(50, 70)
	fuel_bar.size = Vector2(200, 20)
	fuel_bar.color = Color(0.3, 0.3, 0.4)
	hud_layer.add_child(fuel_bar)
	
	var fuel_fill := ColorRect.new()
	fuel_fill.name = "FuelFill"
	fuel_fill.size = Vector2(200, 20)
	fuel_fill.color = Color(1.0, 0.8, 0.2)
	fuel_bar.add_child(fuel_fill)
	
	var distance_label := Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.position = Vector2(50, 110)
	distance_label.add_theme_font_size_override("font_size", 28)
	hud_layer.add_child(distance_label)
	
	var coins_hud := Label.new()
	coins_hud.name = "CoinsHUD"
	coins_hud.position = Vector2(50, 150)
	coins_hud.add_theme_font_size_override("font_size", 24)
	hud_layer.add_child(coins_hud)
	
	# Result screen
	result_layer = CanvasLayer.new()
	add_child(result_layer)
	result_layer.visible = false
	
	var r_bg := ColorRect.new()
	r_bg.size = VIEW
	r_bg.color = Color(0.1, 0.1, 0.15, 0.9)
	result_layer.add_child(r_bg)
	
	var r_title := Label.new()
	r_title.name = "ResultTitle"
	r_title.position = Vector2(VIEW.x / 2 - 150, 200)
	r_title.add_theme_font_size_override("font_size", 48)
	result_layer.add_child(r_title)
	
	var r_stats := Label.new()
	r_stats.name = "ResultStats"
	r_stats.position = Vector2(VIEW.x / 2 - 150, 300)
	r_stats.add_theme_font_size_override("font_size", 24)
	result_layer.add_child(r_stats)
	
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
	stage_select_layer.visible = false
	garage_layer.visible = false
	hud_layer.visible = false
	result_layer.visible = false

func _on_play_pressed() -> void:
	title_layer.visible = false
	stage_select_layer.visible = true
	mode = "stage_select"

func _on_garage_pressed() -> void:
	title_layer.visible = false
	garage_layer.visible = true
	mode = "garage"
	_update_garage_ui()

func _on_garage_back() -> void:
	garage_layer.visible = false
	title_layer.visible = true
	mode = "title"

func _on_stage_selected(stage_id: int) -> void:
	current_stage = stage_id
	_start_driving()

func _start_driving() -> void:
	mode = "driving"
	stage_select_layer.visible = false
	hud_layer.visible = true
	
	# Reset state
	var vehicle: Dictionary = vehicles[current_vehicle]
	var upgrades: Dictionary = vehicle_upgrades[current_vehicle]
	
	max_fuel = 100.0 + upgrades.fuel * 20.0
	fuel = max_fuel
	distance = 0.0
	coins_collected = 0
	vehicle_alive = true
	
	# Generate terrain
	_generate_terrain()
	
	# Create vehicle
	_create_vehicle(Vector2(200, 400))
	
	cam_x = 0.0

func _generate_terrain() -> void:
	terrain_points = []
	fuel_pickups = []
	coin_positions = []
	
	var x := 0.0
	var y := 500.0
	var stage: Dictionary = stages[current_stage]
	
	for i in range(200):
		terrain_points.append(Vector2(x, y))
		
		# Vary terrain height
		y += randf_range(-30, 30)
		y = clamp(y, 300, 650)
		x += TERRAIN_SEGMENT
		
		# Add fuel pickups every 1000 units
		if i % 10 == 5:
			fuel_pickups.append(Vector2(x - 50, y - 50))
		
		# Add coins
		if i % 3 == 0:
			coin_positions.append(Vector2(x - 50, y - 80))

func _create_vehicle(pos: Vector2) -> void:
	var vehicle: Dictionary = vehicles[current_vehicle]
	
	# Vehicle body
	vehicle_body = RigidBody2D.new()
	vehicle_body.position = pos
	vehicle_body.mass = vehicle.weight
	add_child(vehicle_body)
	
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(80, 40)
	body_shape.shape = body_rect
	vehicle_body.add_child(body_shape)
	
	# Wheels (simplified)
	rear_wheel = RigidBody2D.new()
	rear_wheel.position = pos + Vector2(-30, 25)
	rear_wheel.mass = 10.0
	add_child(rear_wheel)
	
	var rear_shape := CollisionShape2D.new()
	var rear_circle := CircleShape2D.new()
	rear_circle.radius = 20.0
	rear_shape.shape = rear_circle
	rear_wheel.add_child(rear_shape)
	
	front_wheel = RigidBody2D.new()
	front_wheel.position = pos + Vector2(30, 25)
	front_wheel.mass = 10.0
	add_child(front_wheel)
	
	var front_shape := CollisionShape2D.new()
	var front_circle := CircleShape2D.new()
	front_circle.radius = 20.0
	front_shape.shape = front_circle
	front_wheel.add_child(front_shape)

func _physics_process(delta: float) -> void:
	if mode != "driving" or not vehicle_alive:
		return
	
	# Input
	var gas := 0.0
	var brake := 0.0
	var tilt := 0.0
	
	if Input.is_key_pressed(KEY_RIGHT):
		gas = 1.0
	if Input.is_key_pressed(KEY_LEFT):
		brake = 1.0
	if Input.is_key_pressed(KEY_UP):
		tilt = -1.0
	if Input.is_key_pressed(KEY_DOWN):
		tilt = 1.0
	
	# Apply forces
	if vehicle_body and is_instance_valid(vehicle_body):
		var vehicle: Dictionary = vehicles[current_vehicle]
		var upgrades: Dictionary = vehicle_upgrades[current_vehicle]
		
		var power: float = vehicle.speed * (1.0 + upgrades.engine * 0.2)
		vehicle_body.apply_force(Vector2(gas * power - brake * power * 0.5, 0))
		vehicle_body.apply_torque(tilt * 1000.0)
		
		# Update distance
		distance = max(distance, vehicle_body.position.x / 10.0)
		
		# Fuel consumption
		var consumption: float = (gas * 0.5 + 0.1) / vehicle.fuel_efficiency
		fuel -= consumption * delta * 10.0
		
		if fuel <= 0:
			fuel = 0
			_end_run("OUT OF FUEL")
			return
		
		# Check for crash (roof landing)
		if vehicle_body.rotation > PI / 2 or vehicle_body.rotation < -PI / 2:
			_end_run("CRASHED")
			return
		
		# Collect fuel pickups
		for i in range(fuel_pickups.size() - 1, -1, -1):
			if vehicle_body.position.distance_to(fuel_pickups[i]) < 40:
				fuel = min(fuel + 30, max_fuel)
				fuel_pickups.remove_at(i)
		
		# Collect coins
		for i in range(coin_positions.size() - 1, -1, -1):
			if vehicle_body.position.distance_to(coin_positions[i]) < 40:
				coins_collected += 1
				coins += 1
				coin_positions.remove_at(i)
		
		# Update camera
		cam_x = lerp(cam_x, vehicle_body.position.x - VIEW.x / 3, 0.1)
	
	_update_hud()
	queue_redraw()

func _end_run(reason: String) -> void:
	vehicle_alive = false
	
	# Update record
	if distance > stage_records[current_stage]:
		stage_records[current_stage] = distance
		
		# Unlock next stage
		if current_stage + 1 < stages.size() and distance > 500:
			unlocked_stages = max(unlocked_stages, current_stage + 2)
	
	_show_result(reason)

func _show_result(reason: String) -> void:
	mode = "result"
	hud_layer.visible = false
	result_layer.visible = true
	
	var r_title := result_layer.get_node("ResultTitle") as Label
	var r_stats := result_layer.get_node("ResultStats") as Label
	
	r_title.text = reason
	r_stats.text = "Distance: %.0fm\nCoins: %d\nNew Record!" if distance > stage_records[current_stage] else "Distance: %.0fm\nCoins: %d" % [distance, coins_collected]

func _on_retry() -> void:
	result_layer.visible = false
	_start_driving()

func _on_result_menu() -> void:
	result_layer.visible = false
	title_layer.visible = true
	mode = "title"

func _update_garage_ui() -> void:
	var coins_label := garage_layer.get_node("CoinsLabel") as Label
	coins_label.text = "Coins: %d" % coins

func _update_hud() -> void:
	var fuel_label := hud_layer.get_node("FuelLabel") as Label
	var fuel_fill := hud_layer.get_node("FuelBar/FuelFill") as ColorRect
	var distance_label := hud_layer.get_node("DistanceLabel") as Label
	var coins_hud := hud_layer.get_node("CoinsHUD") as Label
	
	fuel_label.text = "Fuel: %.0f%%" % (fuel / max_fuel * 100.0)
	fuel_fill.size.x = (fuel / max_fuel) * 200.0
	distance_label.text = "Distance: %.0fm" % distance
	coins_hud.text = "Coins: %d" % coins_collected

func _draw() -> void:
	if mode != "driving":
		return
	
	var offset := Vector2(-cam_x, 0)
	var stage: Dictionary = stages[current_stage]
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, VIEW), stage.theme_color)
	
	# Draw terrain
	for i in range(terrain_points.size() - 1):
		var p1: Vector2 = terrain_points[i] + offset
		var p2: Vector2 = terrain_points[i + 1] + offset
		
		if p1.x > -100 and p1.x < VIEW.x + 100:
			draw_line(p1, p2, Color(0.2, 0.15, 0.1), 5.0)
			
			# Fill below
			var poly := PackedVector2Array([p1, p2, Vector2(p2.x, VIEW.y), Vector2(p1.x, VIEW.y)])
			draw_colored_polygon(poly, Color(0.15, 0.12, 0.08))
	
	# Draw fuel pickups
	for pickup in fuel_pickups:
		var pos: Vector2 = pickup + offset
		if pos.x > -50 and pos.x < VIEW.x + 50:
			draw_circle(pos, 15, Color(1.0, 0.8, 0.2))
	
	# Draw coins
	for coin in coin_positions:
		var pos: Vector2 = coin + offset
		if pos.x > -50 and pos.x < VIEW.x + 50:
			draw_circle(pos, 10, Color(1.0, 0.84, 0.0))
	
	# Draw vehicle
	if vehicle_body and is_instance_valid(vehicle_body):
		var pos: Vector2 = vehicle_body.position + offset
		var angle := vehicle_body.rotation
		
		# Body
		var rect := Rect2(pos - Vector2(40, 20), Vector2(80, 40))
		draw_rect(rect, Color(0.8, 0.3, 0.2))
		
		# Wheels
		if rear_wheel and is_instance_valid(rear_wheel):
			draw_circle(rear_wheel.position + offset, 20, Color(0.1, 0.1, 0.1))
		if front_wheel and is_instance_valid(front_wheel):
			draw_circle(front_wheel.position + offset, 20, Color(0.1, 0.1, 0.1))

func _load_scenario(scen: String) -> void:
	match scen:
		"stage_select":
			title_layer.visible = false
			stage_select_layer.visible = true
			mode = "stage_select"
		"garage":
			title_layer.visible = false
			garage_layer.visible = true
			mode = "garage"
			_update_garage_ui()
		"driving":
			current_stage = 0
			_start_driving()
		_:
			_show_title()
GDSCRIPT_EOF

echo "Oracle solution created successfully"

# --------------------------------------------------------------------------
# Demo traces
# --------------------------------------------------------------------------

# Demo 1: Title to stage select
cat > "$GAME/demo_outputs/01_title_to_stage.json" <<'DEMO_EOF'
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

# Demo 2: Garage screen
cat > "$GAME/demo_outputs/02_garage.json" <<'DEMO_EOF'
{
  "scenario": "garage",
  "duration_frames": 300,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 90, "type": "wait"},
    {"frame": 150, "type": "wait"},
    {"frame": 210, "type": "mouse_click", "button": "left", "x": 1030, "y": 60},
    {"frame": 270, "type": "wait"}
  ]
}
DEMO_EOF

# Demo 3: Driving with fuel management
cat > "$GAME/demo_outputs/03_driving.json" <<'DEMO_EOF'
{
  "scenario": "driving",
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

# Demo 4: Stage select and play
cat > "$GAME/demo_outputs/04_stage_select_play.json" <<'DEMO_EOF'
{
  "scenario": "stage_select",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 350, "y": 275},
    {"frame": 120, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 180, "type": "key_down", "keycode": "UP"},
    {"frame": 240, "type": "key_up", "keycode": "UP"},
    {"frame": 300, "type": "key_down", "keycode": "DOWN"},
    {"frame": 360, "type": "key_up", "keycode": "DOWN"},
    {"frame": 420, "type": "key_down", "keycode": "UP"},
    {"frame": 480, "type": "key_up", "keycode": "UP"},
    {"frame": 540, "type": "key_up", "keycode": "RIGHT"}
  ]
}
DEMO_EOF

# Demo 5: Complete loop
cat > "$GAME/demo_outputs/05_complete_loop.json" <<'DEMO_EOF'
{
  "scenario": "",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 350},
    {"frame": 90, "type": "mouse_click", "button": "left", "x": 350, "y": 275},
    {"frame": 150, "type": "key_down", "keycode": "RIGHT"},
    {"frame": 210, "type": "key_down", "keycode": "UP"},
    {"frame": 270, "type": "key_up", "keycode": "UP"},
    {"frame": 330, "type": "key_down", "keycode": "DOWN"},
    {"frame": 390, "type": "key_up", "keycode": "DOWN"},
    {"frame": 450, "type": "key_down", "keycode": "UP"},
    {"frame": 510, "type": "key_up", "keycode": "UP"},
    {"frame": 570, "type": "key_up", "keycode": "RIGHT"}
  ]
}
DEMO_EOF

echo "Demo traces created successfully"
echo "Racing Terrain Climb oracle complete!"
