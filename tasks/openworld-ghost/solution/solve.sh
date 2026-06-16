#!/bin/bash
set -euo pipefail
GAME="${GAME:-/workspace/game}"
mkdir -p "$GAME" && cd "$GAME"

cat > project.godot <<'GODOT'
[application]
config/name="Spectre Seeker"
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

func _grad(c1: Color, c2: Color, w: int = 64, h: int = 64) -> GradientTexture2D:
	var g = Gradient.new(); g.add_point(0.0, c1); g.add_point(1.0, c2)
	var gt = GradientTexture2D.new(); gt.gradient = g; gt.width = w; gt.height = h
	gt.fill = GradientTexture2D.FILL_LINEAR; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	return gt

func _noise(base: Color, contrast: float = 0.15, w: int = 64, h: int = 64) -> NoiseTexture2D:
	var n = FastNoiseLite.new(); n.noise_type = FastNoiseLite.TYPE_PERLIN; n.frequency = 0.08
	var nt = NoiseTexture2D.new(); nt.noise = n; nt.width = w; nt.height = h
	nt.color_ramp = Gradient.new()
	nt.color_ramp.add_point(0.0, base.darkened(contrast))
	nt.color_ramp.add_point(0.5, base)
	nt.color_ramp.add_point(1.0, base.lightened(contrast))
	return nt

var player: CharacterBody2D
var sanity: float = 100.0
var active_tool: int = 0
var tools: Array = ["EMF", "Thermal", "Spirit Box"]
var evidence: Dictionary = {}
var ghost_type: String = ""
var ghost_types: Array = ["Poltergeist", "Wraith", "Banshee", "Shade"]
var hunt_phase: bool = false
var hunt_timer: float = 0.0
var locations: Array = ["Mansion", "Forest", "Lighthouse", "Hospital"]
var loc_colors: Array = [
	[Color(0.08, 0.08, 0.12), Color(0.12, 0.10, 0.15)],
	[Color(0.05, 0.12, 0.06), Color(0.08, 0.15, 0.08)],
	[Color(0.08, 0.12, 0.16), Color(0.12, 0.16, 0.20)],
	[Color(0.14, 0.08, 0.08), Color(0.18, 0.10, 0.10)]
]
var current_location: int = 0
var ghosts: Array = []
var title_ui: Control
var world_root: Node2D
var cam: Camera2D
var flicker_overlay: ColorRect

func _ready():
	var s = _get_scenario()
	if s == "title": _make_title()
	else: _start_game(s)

func _get_scenario() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="): return a.split("=")[1]
	return ""

func _make_title():
	title_ui = Control.new(); title_ui.size = Vector2(1280, 720); add_child(title_ui)
	var bg = Sprite2D.new()
	bg.texture = _grad(Color(0.02, 0.02, 0.04), Color(0.06, 0.06, 0.10), 1280, 720)
	bg.position = Vector2(640, 360); bg.centered = true; title_ui.add_child(bg)
	# Fog particles
	for i in range(20):
		var f = Sprite2D.new()
		f.texture = _grad(Color(0.3, 0.3, 0.35, 0.2), Color(0.2, 0.2, 0.25, 0.0), 40, 30)
		f.position = Vector2(randi() % 1280, randi() % 720)
		f.centered = true; title_ui.add_child(f); _tween_fog(f)
	# House silhouette
	var house = Sprite2D.new()
	house.texture = _grad(Color(0.04, 0.04, 0.06), Color(0.06, 0.06, 0.08), 200, 180)
	house.position = Vector2(900, 420); house.centered = true; title_ui.add_child(house)
	var roof = Sprite2D.new()
	roof.texture = _grad(Color(0.03, 0.03, 0.05), Color(0.05, 0.05, 0.07), 240, 60)
	roof.position = Vector2(900, 310); roof.centered = true; title_ui.add_child(roof)
	# Flickering lantern
	var lantern = Sprite2D.new()
	lantern.texture = _grad(Color(0.8, 0.6, 0.2, 0.6), Color(0.6, 0.4, 0.1, 0.0), 30, 40)
	lantern.position = Vector2(820, 380); lantern.centered = true; title_ui.add_child(lantern)
	_tween_flicker(lantern)
	# Title
	var t = Label.new(); t.text = "Spectre Seeker"; t.position = Vector2(390, 200)
	t.add_theme_font_size_override("font_size", 52)
	t.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	title_ui.add_child(t)
	var st = Label.new(); st.text = "The Hunt Begins"; st.position = Vector2(490, 270)
	st.add_theme_font_size_override("font_size", 20)
	st.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	title_ui.add_child(st)
	# Button
	var b = Button.new(); b.text = "Begin Hunt"; b.position = Vector2(540, 360)
	b.size = Vector2(200, 50); b.flat = true
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	b.pressed.connect(func(): _tween_title_out()); title_ui.add_child(b)
	_tween_button_pulse(b)

func _tween_fog(f: Sprite2D):
	var tw = create_tween().set_loops()
	tw.tween_property(f, "position:x", f.position.x + 60, 5.0 + randf() * 3.0)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 5.0 + randf() * 3.0)
	tw.tween_callback(func(): f.position.x = f.position.x - 60; f.modulate = Color(1,1,1,0.2))

func _tween_flicker(l: Sprite2D):
	var tw = create_tween().set_loops()
	tw.tween_property(l, "modulate:a", 0.3, 0.3)
	tw.tween_property(l, "modulate:a", 0.8, 0.2)
	tw.tween_interval(0.1)
	tw.tween_property(l, "modulate:a", 0.4, 0.4)
	tw.tween_property(l, "modulate:a", 0.9, 0.15)

func _tween_button_pulse(btn: Button):
	var tw = create_tween().set_loops()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.8)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.8)

func _tween_title_out():
	var tw = create_tween()
	tw.tween_property(title_ui, "modulate", Color.TRANSPARENT, 0.6)
	tw.tween_callback(func(): title_ui.queue_free(); _start_game(""))

func _start_game(s: String):
	cam = Camera2D.new(); cam.position = Vector2(160, 360); add_child(cam)
	world_root = Node2D.new(); add_child(world_root)
	flicker_overlay = ColorRect.new()
	flicker_overlay.color = Color.BLACK; flicker_overlay.size = Vector2(1280, 720)
	flicker_overlay.modulate = Color.TRANSPARENT; flicker_overlay.z_index = 100
	add_child(flicker_overlay)
	_gen_locations()
	_spawn_player()
	_spawn_ghosts()
	_make_hud()
	if s == "mansion_hunt": current_location = 0
	elif s == "forest_hunt": current_location = 1
	elif s == "lighthouse_hunt": current_location = 2
	elif s == "hospital_hunt": current_location = 3
	elif s == "ghost_type_id": evidence = {"EMF": 5, "Temp": -5, "Spirit": "Help"}
	elif s == "hunt_phase": hunt_phase = true; hunt_timer = 30.0
	elif s == "low_sanity": sanity = 20.0

func _gen_locations():
	for i in range(4):
		var l = Node2D.new(); l.name = "Loc%d" % i; world_root.add_child(l)
		var bg = Sprite2D.new()
		bg.texture = _noise(loc_colors[i][0], 0.12, 320, 720)
		bg.position = Vector2(160 + i * 320, 360); bg.centered = true
		l.add_child(bg)
		# Location-specific props
		if i == 0: # Mansion - broken windows
			for j in range(3):
				var win = Sprite2D.new()
				win.texture = _grad(Color(0.15, 0.15, 0.20), Color(0.10, 0.10, 0.14), 30, 40)
				win.position = Vector2(80 + j * 90, 200 + j * 80); win.centered = true
				l.add_child(win)
		elif i == 1: # Forest - twisted trees
			for j in range(5):
				var tree = Sprite2D.new()
				tree.texture = _grad(Color(0.08, 0.25, 0.10), Color(0.05, 0.18, 0.07), 20, 50)
				tree.position = Vector2(60 + j * 60, 250 + (j % 2) * 100); tree.centered = true
				l.add_child(tree)
		elif i == 2: # Lighthouse - tower + waves
			var tower = Sprite2D.new()
			tower.texture = _grad(Color(0.20, 0.22, 0.25), Color(0.25, 0.27, 0.30), 40, 120)
			tower.position = Vector2(160, 300); tower.centered = true; l.add_child(tower)
			for j in range(4):
				var wave = Sprite2D.new()
				wave.texture = _grad(Color(0.15, 0.30, 0.45, 0.5), Color(0.20, 0.35, 0.50, 0.0), 60, 15)
				wave.position = Vector2(60 + j * 70, 600); wave.centered = true
				l.add_child(wave); _tween_wave(wave)
		elif i == 3: # Hospital - corridors + wheelchair
			for j in range(4):
				var wall = Sprite2D.new()
				wall.texture = _grad(Color(0.18, 0.12, 0.12), Color(0.22, 0.15, 0.15), 15, 80)
				wall.position = Vector2(50 + j * 70, 300); wall.centered = true
				l.add_child(wall)
			var chair = Sprite2D.new()
			chair.texture = _grad(Color(0.30, 0.25, 0.25), Color(0.35, 0.30, 0.30), 30, 25)
			chair.position = Vector2(160, 450); chair.centered = true; l.add_child(chair)

func _tween_wave(w: Sprite2D):
	var tw = create_tween().set_loops()
	tw.tween_property(w, "position:x", w.position.x + 10, 1.5)
	tw.tween_property(w, "position:x", w.position.x - 10, 1.5)

func _spawn_player():
	player = CharacterBody2D.new()
	var sp = Sprite2D.new()
	sp.texture = _grad(Color(0.5, 0.5, 0.6), Color(0.4, 0.4, 0.5), 22, 22)
	sp.centered = true; player.add_child(sp)
	var c = CollisionShape2D.new(); c.shape = RectangleShape2D.new(); c.shape.size = Vector2(22, 22)
	player.add_child(c)
	player.position = Vector2(160, 360); world_root.add_child(player)

func _spawn_ghosts():
	for i in range(4):
		var g = Sprite2D.new()
		g.position = Vector2(100 + i * 300, 250 + (i % 2) * 120); g.centered = true
		var ghost_colors = [Color(0.6, 0.6, 0.6), Color(0.3, 0.8, 0.9), Color(0.9, 0.2, 0.2), Color(0.2, 0.2, 0.3)]
		g.texture = _grad(ghost_colors[i], ghost_colors[i].lightened(0.1), 28, 28)
		g.set_meta("type", ghost_types[i])
		g.set_meta("behaviour", ["throw", "freeze", "scream", "hide"][i])
		world_root.add_child(g); ghosts.append(g)
		_tween_ghost_float(g)

func _tween_ghost_float(g: Sprite2D):
	var tw = create_tween().set_loops()
	tw.tween_property(g, "position:y", g.position.y - 8, 1.5)
	tw.tween_property(g, "position:y", g.position.y + 8, 1.5)

func _make_hud():
	var panel = ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.08, 0.80); panel.size = Vector2(280, 160)
	panel.position = Vector2(10, 10); add_child(panel)
	var s = Label.new(); s.text = "Sanity: 100%"; s.position = Vector2(20, 15); s.name = "Sanity"
	s.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85)); add_child(s)
	var t = Label.new(); t.text = "Tool: EMF"; t.position = Vector2(20, 40); t.name = "Tool"
	t.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8)); add_child(t)
	var e = Label.new(); e.text = "Evidence: 0"; e.position = Vector2(20, 65); e.name = "Evidence"
	e.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8)); add_child(e)
	var h = Label.new(); h.text = ""; h.position = Vector2(20, 90); h.name = "Hunt"
	h.add_theme_color_override("font_color", Color(1, 0.3, 0.3)); add_child(h)
	# Sanity bar
	var sb = ColorRect.new(); sb.color = Color(0.2, 0.5, 0.3); sb.size = Vector2(120, 10)
	sb.position = Vector2(20, 118); sb.name = "SanityBar"; add_child(sb)
	var sb_bg = ColorRect.new(); sb_bg.color = Color(0.15, 0.15, 0.18); sb_bg.size = Vector2(120, 10)
	sb_bg.position = Vector2(20, 118); sb_bg.z_index = -1; add_child(sb_bg)
	# Tool icons
	for i in range(3):
		var icon = Sprite2D.new()
		icon.texture = _grad(Color(0.4, 0.5, 0.6), Color(0.5, 0.6, 0.7), 16, 16)
		icon.position = Vector2(160 + i * 22, 135); icon.centered = true
		icon.name = "ToolIcon%d" % i; add_child(icon)

func _process(delta):
	if hunt_phase:
		hunt_timer -= delta
		if hunt_timer <= 0: hunt_phase = false
		# Flicker lights
		flicker_overlay.modulate = Color(0, 0, 0, 0.1 + randf() * 0.3)
	else:
		flicker_overlay.modulate = Color.TRANSPARENT
	if player == null: return
	var up = Input.is_action_pressed("ui_up")
	var down = Input.is_action_pressed("ui_down")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	var vel = Vector2.ZERO
	if up: vel.y = -120
	if down: vel.y = 120
	if left: vel.x = -120
	if right: vel.x = 120
	player.velocity = vel; player.move_and_slide()
	cam.position = player.position
	if Input.is_action_just_pressed("ui_accept"):
		active_tool = (active_tool + 1) % len(tools)
		_use_tool()
	sanity -= delta * 2
	if sanity < 0: sanity = 0
	if sanity < 30:
		for g in ghosts:
			g.position += Vector2(randf() * 2 - 1, randf() * 2 - 1) * delta * 50
	_update_hud()

func _use_tool():
	var tool = tools[active_tool]
	for g in ghosts:
		if player.position.distance_to(g.position) < 150:
			var gt = g.get_meta("type")
			if tool == "EMF":
				evidence["EMF"] = 5 if gt == "Poltergeist" else (4 if gt == "Wraith" else 3)
				_spawn_spark(g.position, Color(0.2, 0.8, 0.3))
			elif tool == "Thermal":
				evidence["Temp"] = -5 if gt == "Wraith" else -2
				_spawn_spark(g.position, Color(0.2, 0.5, 0.9))
			elif tool == "Spirit Box":
				evidence["Spirit"] = "Help" if gt == "Banshee" else "Leave"
				_spawn_spark(g.position, Color(0.8, 0.3, 0.8))

func _spawn_spark(pos: Vector2, c: Color):
	var s = Sprite2D.new()
	s.texture = _grad(c, Color(c.r, c.g, c.b, 0.0), 12, 12)
	s.position = pos; s.centered = true; add_child(s)
	var tw = create_tween()
	tw.tween_property(s, "scale", Vector2(3, 3), 0.3)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): s.queue_free())

func _update_hud():
	var s = get_node_or_null("Sanity")
	if s: s.text = "Sanity: %d%%" % int(sanity)
	var t = get_node_or_null("Tool")
	if t: t.text = "Tool: %s" % tools[active_tool]
	var e = get_node_or_null("Evidence")
	if e: e.text = "Evidence: %d" % len(evidence)
	var h = get_node_or_null("Hunt")
	if h:
		if hunt_phase: h.text = "HUNT! %.0fs" % hunt_timer
		else: h.text = ""
	var sb = get_node_or_null("SanityBar")
	if sb: sb.size.x = max(0, 120 * sanity / 100.0)
	for i in range(3):
		var icon = get_node_or_null("ToolIcon%d" % i)
		if icon: icon.modulate = Color.WHITE if i == active_tool else Color(0.4, 0.4, 0.4)
GDSCRIPT

cat > Main.tscn <<'TSCN'
[gd_scene load_steps=2 format=3 uid="uid://main"]
[ext_resource type="Script" path="res://Main.gd" id="1_main"]
[node name="Main" type="Node2D"]
script = ExtResource("1_main")
TSCN

mkdir -p demo_outputs

# Demo 1: title -> mansion -> tool switch -> spark effects
cat > demo_outputs/00_title_tools.json <<'EOF'
{"scenario": "title", "duration_frames": 450, "events": [
  {"frame": 90, "type": "mouse_click", "button": "left", "x": 640, "y": 385},
  {"frame": 150, "type": "key_press", "keycode": "D"},
  {"frame": 200, "type": "key_up", "keycode": "D"},
  {"frame": 220, "type": "key_press", "keycode": "SPACE"},
  {"frame": 225, "type": "key_up", "keycode": "SPACE"},
  {"frame": 260, "type": "key_press", "keycode": "SPACE"},
  {"frame": 265, "type": "key_up", "keycode": "SPACE"},
  {"frame": 300, "type": "key_press", "keycode": "D"},
  {"frame": 360, "type": "key_up", "keycode": "D"},
  {"frame": 430, "type": "wait"}
]}
EOF

# Demo 2: hunt phase with flicker
cat > demo_outputs/01_hunt.json <<'EOF'
{"scenario": "hunt_phase", "duration_frames": 300, "events": [
  {"frame": 30, "type": "key_press", "keycode": "W"},
  {"frame": 100, "type": "key_up", "keycode": "W"},
  {"frame": 120, "type": "key_press", "keycode": "D"},
  {"frame": 200, "type": "key_up", "keycode": "D"},
  {"frame": 280, "type": "wait"}
]}
EOF

# Other demos
for f in mansion_hunt forest_hunt lighthouse_hunt hospital_hunt ghost_type_id low_sanity; do
cat > demo_outputs/${f}.json <<EOF
{"scenario": "$f", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "W"}, {"frame": 120, "type": "key_up", "keycode": "W"}, {"frame": 280, "type": "wait"}]}
EOF
done

echo "openworld-ghost Oracle ready"
