#!/bin/bash
set -euo pipefail
GAME="${GAME:-/workspace/game}"
mkdir -p "$GAME" && cd "$GAME"

cat > project.godot <<'GODOT'
[application]
config/name="Lost Civilisations"
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
var health: int = 100
var tools: Array = ["Brush", "Pickaxe", "Trowel"]
var active_tool: int = 0
var artefacts: Array = []
var museum: Dictionary = {}
var research: int = 0
var sites: Array = ["Desert Temple", "Jungle Ruin", "Underwater Site", "Mountain Tomb"]
var site_colours: Array = [Color(0.8, 0.7, 0.5), Color(0.2, 0.5, 0.2), Color(0.3, 0.5, 0.6), Color(0.7, 0.8, 0.9)]
var current_site: int = 0
var dig_layers: Array = []
var hazard_active: bool = false
var hazard_timer: float = 0.0
var artefact_types: Array = [
	{"name": "Pottery Shard", "rarity": "common", "depth": 1},
	{"name": "Stone Tablet", "rarity": "uncommon", "depth": 2},
	{"name": "Jewellery", "rarity": "rare", "depth": 3},
	{"name": "Bone Fragment", "rarity": "common", "depth": 1},
	{"name": "Ancient Coin", "rarity": "uncommon", "depth": 2},
	{"name": "Golden Idol", "rarity": "legendary", "depth": 4}
]
func _ready():
	var s = _get_scenario()
	if s == "title": _make_title()
	else: _start_game(s)
func _get_scenario() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="): return a.split("=")[1]
	return ""
func _make_title():
	var bg = ColorRect.new(); bg.color = Color(0.2, 0.15, 0.1); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var t = Label.new(); t.text = "Lost Civilisations"; t.set_anchors_preset(Control.PRESET_CENTER_TOP); t.position.y = 200; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(t)
	var b = Button.new(); b.text = "Begin Expedition"; b.set_anchors_preset(Control.PRESET_CENTER); b.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn")); add_child(b)
func _start_game(s: String):
	_gen_sites()
	_spawn_player()
	_make_dig_layers()
	_make_hud()
	if s == "desert_excavation": current_site = 0
	elif s == "jungle_ruin": current_site = 1
	elif s == "underwater_site": current_site = 2; hazard_active = true
	elif s == "mountain_tomb": current_site = 3; hazard_active = true
	elif s == "artefact_discovery": current_site = 0; _reveal_artefact(5)
	elif s == "puzzle_solve": current_site = 1; _make_puzzle()
	elif s == "museum_view": artefacts = [artefact_types[0], artefact_types[2], artefact_types[5]]
func _noise(base: Color, contrast: float = 0.15, w: int = 64, h: int = 64) -> NoiseTexture2D:
	var n = FastNoiseLite.new(); n.noise_type = FastNoiseLite.TYPE_PERLIN; n.frequency = 0.08
	var nt = NoiseTexture2D.new(); nt.noise = n; nt.width = w; nt.height = h
	nt.color_ramp = Gradient.new()
	nt.color_ramp.add_point(0.0, base.darkened(contrast))
	nt.color_ramp.add_point(0.5, base)
	nt.color_ramp.add_point(1.0, base.lightened(contrast))
	return nt

func _grad(c1: Color, c2: Color, w: int = 64, h: int = 64) -> GradientTexture2D:
	var g = Gradient.new(); g.add_point(0.0, c1); g.add_point(1.0, c2)
	var gt = GradientTexture2D.new(); gt.gradient = g; gt.width = w; gt.height = h
	gt.fill = GradientTexture2D.FILL_LINEAR; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	return gt

func _gen_sites():
	for i in range(4):
		var s = Sprite2D.new()
		s.texture = _noise(site_colours[i], 0.12, 320, 720)
		s.position = Vector2(i * 320 + 160, 360); s.centered = true
		add_child(s)
		# Site props
		for j in range(4):
			var prop = Sprite2D.new()
			var pc = site_colours[i].darkened(0.15) if i < 2 else site_colours[i].lightened(0.1)
			prop.texture = _grad(pc, pc.lightened(0.1), 30, 40)
			prop.position = Vector2(i * 320 + 50 + j * 60, 150 + j * 110)
			prop.centered = true; add_child(prop)
func _spawn_player():
	player = CharacterBody2D.new()
	var sp = ColorRect.new(); sp.size = Vector2(24, 24); sp.color = Color(0.7, 0.5, 0.3); player.add_child(sp)
	var c = CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = Vector2(24, 24); player.add_child(c)
	player.position = Vector2(160, 360); add_child(player)
func _make_dig_layers():
	for i in range(5):
		var l = ColorRect.new()
		l.position = Vector2(100, 200 + i * 80)
		l.size = Vector2(200, 60)
		l.color = Color(0.4 + i * 0.05, 0.3 + i * 0.03, 0.2 + i * 0.02)
		l.set_meta("depth", i); l.set_meta("removed", false)
		add_child(l); dig_layers.append(l)
func _make_puzzle():
	var puzzle = ColorRect.new()
	puzzle.position = Vector2(500, 200); puzzle.size = Vector2(200, 200)
	puzzle.color = Color(0.3, 0.3, 0.3); puzzle.name = "Puzzle"
	add_child(puzzle)
func _make_hud():
	var h = Label.new(); h.text = "Health: %d" % health; h.position = Vector2(10, 10); h.name = "Health"; add_child(h)
	var t = Label.new(); t.text = "Tool: %s" % tools[active_tool]; t.position = Vector2(10, 35); t.name = "Tool"; add_child(t)
	var a = Label.new(); a.text = "Artefacts: 0"; a.position = Vector2(10, 60); a.name = "Artefacts"; add_child(a)
	var r = Label.new(); r.text = "Research: 0"; r.position = Vector2(10, 85); r.name = "Research"; add_child(r)
func _process(delta):
	if player == null: return
	if hazard_active:
		hazard_timer += delta
		if hazard_timer > 3.0:
			health -= 10; hazard_timer = 0.0
			if health <= 0: health = 100; player.position = Vector2(160, 360)
	var up = Input.is_action_pressed("ui_up")
	var down = Input.is_action_pressed("ui_down")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	var vel = Vector2.ZERO
	if up: vel.y = -100
	if down: vel.y = 100
	if left: vel.x = -100
	if right: vel.x = 100
	player.velocity = vel
	player.move_and_slide()
	if Input.is_action_just_pressed("ui_accept"):
		active_tool = (active_tool + 1) % len(tools)
		_excavate()
	_update_hud()
func _excavate():
	for l in dig_layers:
		if player.position.distance_to(l.position + l.size / 2) < 80 and not l.get_meta("removed"):
			l.set_meta("removed", true); l.visible = false
			var depth = l.get_meta("depth")
			for a in artefact_types:
				if a["depth"] == depth + 1 and randf() < 0.5:
					artefacts.append(a)
					research += 10 if a["rarity"] == "common" else (20 if a["rarity"] == "uncommon" else (50 if a["rarity"] == "rare" else 100))
func _reveal_artefact(idx: int):
	for l in dig_layers: l.set_meta("removed", true); l.visible = false
	artefacts.append(artefact_types[idx])
func _update_hud():
	var h = get_node_or_null("Health")
	if h: h.text = "Health: %d" % health
	var t = get_node_or_null("Tool")
	if t: t.text = "Tool: %s" % tools[active_tool]
	var a = get_node_or_null("Artefacts")
	if a: a.text = "Artefacts: %d" % len(artefacts)
	var r = get_node_or_null("Research")
	if r: r.text = "Research: %d" % research
GDSCRIPT

cat > Main.tscn <<'TSCN'
[gd_scene load_steps=2 format=3 uid="uid://main"]
[ext_resource type="Script" path="res://Main.gd" id="1_main"]
[node name="Main" type="Node2D"]
script = ExtResource("1_main")
TSCN

mkdir -p demo_outputs
for f in title desert_excavation jungle_ruin underwater_site mountain_tomb artefact_discovery puzzle_solve museum_view; do
cat > demo_outputs/${f}.json <<EOF
{"scenario": "$f", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "W"}, {"frame": 120, "type": "key_up", "keycode": "W"}, {"frame": 150, "type": "key_press", "keycode": "D"}, {"frame": 200, "type": "key_up", "keycode": "D"}, {"frame": 280, "type": "wait"}]}
EOF
done
echo "openworld-archaeology Oracle ready"
