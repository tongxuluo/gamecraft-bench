#!/bin/bash
# Reference fallback solution for gamecraft-bench/roguelike-action-void-harvest-version2.
#
# Writes a compact survivor-like auto-attacking arena game into /workspace/game:
#   - title screen, character select, arena, level-up, victory and defeat
#   - original characters, weapons, enemy roles, XP shards, HUD and escalation
#   - deterministic scenarios and demo traces for verifier coverage
set -eu

GAME=/workspace/game
rm -rf "$GAME/project.godot" "$GAME/Main.tscn" "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Void Harvest"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEW := Vector2(1280, 720)
const ARENA := Rect2(Vector2(40, 70), Vector2(1200, 610))
const TARGET_TIME := 72.0
const PLAYER_R := 17.0

const BG := Color(0.025, 0.028, 0.040)
const PANEL := Color(0.060, 0.075, 0.092, 0.94)
const PANEL2 := Color(0.095, 0.105, 0.125, 0.97)
const TEXT := Color(0.88, 0.93, 0.92)
const MUTED := Color(0.50, 0.60, 0.62)
const CYAN := Color(0.22, 0.86, 0.92)
const AMBER := Color(0.96, 0.63, 0.20)
const ROSE := Color(0.92, 0.28, 0.46)
const LIME := Color(0.42, 0.88, 0.34)
const VIOLET := Color(0.60, 0.42, 0.96)

var ui: CanvasLayer
var root: Control
var rng := RandomNumberGenerator.new()
var scenario := ""
var state := "title"
var selected := 0
var result_victory := false
var result_title := ""
var result_note := ""
var paused_by_level := false

var player := {}
var enemies := []
var shots := []
var enemy_shots := []
var xp_shards := []
var mines := []
var beams := []
var texts := []
var warnings := []
var weapons := []
var upgrades_seen := {}

var run_time := 0.0
var spawn_timer := 0.0
var spawn_interval := 1.2
var level := 1
var xp := 0.0
var xp_need := 8.0
var phase := 1
var elapsed_draw := 0.0

var chars := [
	{"name": "Asteroid Miner", "role": "Tough salvage runner", "weapon": "Mag Rail", "hp": 118, "speed": 205, "color": Color(0.95, 0.58, 0.22), "passive": "+Armor, steady shots"},
	{"name": "Reef Witch", "role": "Fast shard caller", "weapon": "Ink Comet", "hp": 88, "speed": 250, "color": Color(0.16, 0.78, 0.72), "passive": "+Magnet, quick XP"},
	{"name": "Clockwork Beekeeper", "role": "Drone conductor", "weapon": "Tether Drone", "hp": 100, "speed": 220, "color": Color(0.90, 0.76, 0.25), "passive": "+Drone uptime"}
]

var all_weapons := {
	"Mag Rail": {"color": CYAN, "text": "Aimed rail bursts pierce the nearest target."},
	"Shard Mine": {"color": AMBER, "text": "Timed mines bloom into glass fragments."},
	"Tether Drone": {"color": Color(0.70, 0.90, 1.00), "text": "Orbiting drone bites nearby enemies."},
	"Ink Comet": {"color": VIOLET, "text": "Bouncing void shots ricochet through packs."},
	"Pressure Vent": {"color": ROSE, "text": "Radial pulses clear breathing room."}
}

func _ready() -> void:
	rng.seed = 42
	_parse_args()
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.size = VIEW
	ui.add_child(root)
	set_process(true)
	if scenario == "":
		_show_title()
	else:
		selected = 0
		_start_run(scenario)

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			scenario = args[i + 1]
			i += 2
		else:
			i += 1

func _clear_ui() -> void:
	for c in root.get_children():
		c.queue_free()

func _panel(pos: Vector2, size: Vector2, color := PANEL, border := CYAN) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", box)
	root.add_child(p)
	return p

func _label(text: String, pos: Vector2, size: Vector2, font := 24, color := TEXT, parent: Node = null) -> Label:
	if parent == null:
		parent = root
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _button(text: String, pos: Vector2, size: Vector2, call: Callable, parent: Node = null) -> Button:
	if parent == null:
		parent = root
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_stylebox_override("normal", _box(Color(0.09, 0.12, 0.15), CYAN))
	b.add_theme_stylebox_override("hover", _box(Color(0.13, 0.18, 0.22), Color(0.65, 1.00, 1.00)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.04, 0.07, 0.09), AMBER))
	b.pressed.connect(call)
	parent.add_child(b)
	return b

func _box(color: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	return s

func _show_title() -> void:
	state = "title"
	_clear_ui()
	queue_redraw()
	_panel(Vector2(360, 110), Vector2(560, 420), Color(0.045, 0.052, 0.072, 0.96), CYAN)
	_label("VOID HARVEST", Vector2(390, 150), Vector2(500, 70), 58, Color(0.72, 0.98, 1.00))
	_label("auto-attacking survivor arena", Vector2(440, 222), Vector2(400, 34), 22, MUTED)
	_label("Harvest shards in a hostile void field.\nBuild strange weapons before the rift closes.", Vector2(425, 290), Vector2(430, 72), 21, TEXT)
	_label("Arsenal: Mag Rail / Shard Mine / Tether Drone / Ink Comet / Pressure Vent", Vector2(385, 368), Vector2(510, 28), 16, Color(0.70, 0.85, 0.86))
	_button("BEGIN", Vector2(530, 420), Vector2(220, 64), Callable(self, "_show_select"))

func _show_select() -> void:
	state = "select"
	_clear_ui()
	queue_redraw()
	_label("Choose A Void Runner", Vector2(320, 56), Vector2(640, 56), 42, Color(0.72, 0.98, 1.00))
	for i in range(chars.size()):
		var c = chars[i]
		var x := 165.0 + i * 330.0
		_panel(Vector2(x, 150), Vector2(290, 390), Color(0.055, 0.068, 0.085, 0.96), c["color"])
		_label(c["name"], Vector2(x + 18, 170), Vector2(254, 38), 26, c["color"])
		_label(c["role"], Vector2(x + 22, 212), Vector2(246, 30), 18, TEXT)
		_label("Start: %s\n%s\nHP %d  Speed %d" % [c["weapon"], c["passive"], c["hp"], c["speed"]],
			Vector2(x + 28, 365), Vector2(234, 82), 18, MUTED)
		_button("SELECT", Vector2(x + 58, 462), Vector2(174, 52), Callable(self, "_select_char").bind(i))

func _select_char(i: int) -> void:
	selected = i
	_start_run("")

func _start_run(mode: String) -> void:
	state = "game"
	_clear_ui()
	rng.seed = 200 + selected
	enemies.clear()
	shots.clear()
	enemy_shots.clear()
	xp_shards.clear()
	mines.clear()
	beams.clear()
	texts.clear()
	warnings.clear()
	weapons.clear()
	upgrades_seen.clear()
	var c = chars[selected]
	player = {"pos": VIEW * 0.5, "hp": c["hp"], "max_hp": c["hp"], "speed": c["speed"], "color": c["color"], "magnet": 115.0, "hurt": 0.0}
	level = 1
	xp = 0
	xp_need = 8
	run_time = 0
	phase = 1
	spawn_timer = 0
	spawn_interval = 1.0
	_add_weapon(c["weapon"])
	if mode == "multi_weapon":
		_add_weapon("Shard Mine")
		_add_weapon("Tether Drone")
		_add_weapon("Pressure Vent")
		_spawn_pack(["seeker", "charger", "spitter", "shield"], 12)
	elif mode == "levelup":
		xp = xp_need - 1
		_spawn_pack(["seeker", "splitter"], 10)
		xp_shards.append({"pos": player["pos"] + Vector2(70, 0), "value": 2.0, "life": 99.0})
	elif mode == "enemy_showcase":
		_add_weapon("Shard Mine")
		_spawn_pack(["seeker", "charger", "spitter", "splitter", "shield"], 16)
	elif mode == "escalation":
		_add_weapon("Ink Comet")
		run_time = 16
		phase = 1
		spawn_interval = 0.38
		_spawn_pack(["seeker", "charger", "spitter"], 16)
	elif mode == "near_victory":
		_add_weapon("Shard Mine")
		_add_weapon("Tether Drone")
		run_time = TARGET_TIME - 8
		phase = 3
		_spawn_elite(true)
	elif mode == "near_defeat":
		player["hp"] = 16
		_spawn_pack(["charger", "spitter", "shield"], 12)
	else:
		_spawn_pack(["seeker"], 7)
	queue_redraw()

func _add_weapon(name: String) -> void:
	for w in weapons:
		if w["name"] == name:
			w["level"] += 1
			return
	weapons.append({"name": name, "cool": 0.15, "level": 1, "angle": rng.randf_range(0, TAU)})
	upgrades_seen[name] = true

func _process(delta: float) -> void:
	elapsed_draw += delta
	if state == "game":
		_update_game(delta)
	elif state == "result":
		pass
	queue_redraw()

func _update_game(delta: float) -> void:
	if paused_by_level:
		return
	run_time += delta
	player["hurt"] = max(0.0, float(player["hurt"]) - delta)
	_update_phase()
	_move_player(delta)
	_update_spawning(delta)
	_update_weapons(delta)
	_update_projectiles(delta)
	_update_enemies(delta)
	_update_pickups(delta)
	_update_effects(delta)
	if int(player["hp"]) <= 0:
		_show_result(false, "DEFEAT", "The void field consumed the runner.")
	elif run_time >= TARGET_TIME and not _elite_exists():
		_show_result(true, "VICTORY", "The harvest survived the final surge.")

func _update_phase() -> void:
	var old := phase
	var mid_mark := 20.0
	var late_mark := 48.0
	if scenario == "escalation":
		mid_mark = 20.0
		late_mark = 29.0
	if run_time >= late_mark:
		phase = 3
	elif run_time >= mid_mark:
		phase = 2
	else:
		phase = 1
	if phase != old:
		_float("PHASE %d: pressure rising" % phase, Vector2(520, 118), AMBER)
		if phase == 3:
			_spawn_elite(false)

func _move_player(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if v.length() > 0:
		v = v.normalized()
	var p: Vector2 = player["pos"]
	p += v * float(player["speed"]) * delta
	p.x = clamp(p.x, ARENA.position.x + PLAYER_R, ARENA.end.x - PLAYER_R)
	p.y = clamp(p.y, ARENA.position.y + PLAYER_R, ARENA.end.y - PLAYER_R)
	player["pos"] = p

func _update_spawning(delta: float) -> void:
	spawn_interval = max(0.34, 1.18 - phase * 0.22 - run_time * 0.004)
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		var pool := ["seeker"]
		if phase >= 2:
			pool = ["seeker", "charger", "spitter", "splitter"]
		if phase >= 3:
			pool = ["seeker", "charger", "spitter", "splitter", "shield"]
		_spawn_enemy(pool[rng.randi_range(0, pool.size() - 1)])

func _update_weapons(delta: float) -> void:
	for w in weapons:
		w["cool"] = float(w["cool"]) - delta
		w["angle"] = float(w["angle"]) + delta * 2.4
		if w["cool"] <= 0:
			_fire_weapon(w)

func _fire_weapon(w: Dictionary) -> void:
	var name: String = w["name"]
	var lv := int(w["level"])
	if name == "Mag Rail":
		w["cool"] = max(0.28, 0.82 - 0.07 * lv)
		var t = _nearest_enemy()
		if t != null:
			var dir := (Vector2(t["pos"]) - Vector2(player["pos"])).normalized()
			for i in range(lv):
				shots.append({"pos": player["pos"], "vel": dir.rotated((i - lv / 2.0) * 0.10) * 640, "dmg": 11 + lv * 2, "life": 0.72, "color": CYAN, "pierce": 2})
	elif name == "Shard Mine":
		w["cool"] = max(0.70, 1.85 - 0.14 * lv)
		var off := Vector2(rng.randf_range(-120, 120), rng.randf_range(-90, 90))
		mines.append({"pos": Vector2(player["pos"]) + off, "timer": 0.85, "radius": 58 + lv * 8, "dmg": 18 + lv * 4})
	elif name == "Tether Drone":
		w["cool"] = 0.28
		var center: Vector2 = player["pos"]
		var drone := center + Vector2.RIGHT.rotated(float(w["angle"])) * (62 + lv * 8)
		var t2 = _nearest_enemy(drone, 82 + lv * 12)
		if t2 != null:
			_damage_enemy(t2, 5 + lv * 2, drone, Color(0.70, 0.90, 1.0))
			beams.append({"a": drone, "b": t2["pos"], "life": 0.12, "color": Color(0.70, 0.90, 1.0)})
	elif name == "Ink Comet":
		w["cool"] = max(0.48, 1.08 - 0.08 * lv)
		var dir2 := Vector2.RIGHT.rotated(rng.randf_range(0, TAU))
		if _nearest_enemy() != null:
			dir2 = (Vector2(_nearest_enemy()["pos"]) - Vector2(player["pos"])).normalized()
		shots.append({"pos": player["pos"], "vel": dir2 * 410, "dmg": 8 + lv * 2, "life": 1.65, "color": VIOLET, "bounce": 2 + lv})
	elif name == "Pressure Vent":
		w["cool"] = max(0.95, 2.0 - 0.15 * lv)
		var r := 92 + lv * 18
		warnings.append({"pos": player["pos"], "radius": r, "life": 0.22, "color": ROSE})
		for e in enemies:
			if Vector2(e["pos"]).distance_to(player["pos"]) <= r:
				_damage_enemy(e, 13 + lv * 4, e["pos"], ROSE)

func _update_projectiles(delta: float) -> void:
	var keep := []
	for s in shots:
		var p: Vector2 = s["pos"]
		p += Vector2(s["vel"]) * delta
		s["pos"] = p
		s["life"] = float(s["life"]) - delta
		var hit := false
		for e in enemies:
			if Vector2(e["pos"]).distance_to(p) < float(e["r"]) + 5:
				_damage_enemy(e, int(s["dmg"]), p, s["color"])
				if s.has("pierce"):
					s["pierce"] = int(s["pierce"]) - 1
					hit = int(s["pierce"]) < 0
				elif s.has("bounce") and int(s["bounce"]) > 0:
					s["bounce"] = int(s["bounce"]) - 1
					s["vel"] = Vector2(s["vel"]).rotated(rng.randf_range(1.0, 2.3))
				else:
					hit = true
				break
		if float(s["life"]) > 0 and ARENA.grow(90).has_point(p) and not hit:
			keep.append(s)
	shots = keep
	var ep_keep := []
	for b in enemy_shots:
		var bp: Vector2 = b["pos"]
		bp += Vector2(b["vel"]) * delta
		b["pos"] = bp
		b["life"] = float(b["life"]) - delta
		if bp.distance_to(player["pos"]) < PLAYER_R + 6:
			_hurt_player(int(b["dmg"]))
		elif float(b["life"]) > 0 and ARENA.grow(80).has_point(bp):
			ep_keep.append(b)
	enemy_shots = ep_keep

func _update_enemies(delta: float) -> void:
	var ppos: Vector2 = player["pos"]
	for e in enemies:
		e["flash"] = max(0.0, float(e.get("flash", 0.0)) - delta)
		var pos: Vector2 = e["pos"]
		var to_p: Vector2 = ppos - pos
		var dist: float = max(1.0, to_p.length())
		var dir: Vector2 = to_p / dist
		var typ: String = e["type"]
		if typ == "charger":
			e["special"] = float(e.get("special", 1.3)) - delta
			if float(e["special"]) < 0.42 and float(e["special"]) > 0.0:
				warnings.append({"pos": pos + dir * 52, "radius": 30, "life": 0.04, "color": AMBER})
			if float(e["special"]) <= 0:
				e["vel"] = dir * 360
				e["special"] = 2.2
			pos += Vector2(e.get("vel", Vector2.ZERO)) * delta
			e["vel"] = Vector2(e.get("vel", Vector2.ZERO)).move_toward(Vector2.ZERO, 300 * delta)
			pos += dir * float(e["speed"]) * 0.22 * delta
		elif typ == "spitter":
			e["special"] = float(e.get("special", 1.0)) - delta
			pos += dir * float(e["speed"]) * (0.35 if dist > 260 else -0.25) * delta
			if float(e["special"]) <= 0:
				e["special"] = 1.7
				enemy_shots.append({"pos": pos, "vel": dir * 240, "dmg": 7 + phase, "life": 2.2})
		elif typ == "shield":
			pos += dir * float(e["speed"]) * 0.55 * delta
		elif typ == "elite":
			e["special"] = float(e.get("special", 1.8)) - delta
			pos += dir * float(e["speed"]) * 0.45 * delta
			if float(e["special"]) <= 0:
				e["special"] = 2.4
				var center := ppos + Vector2(rng.randf_range(-50, 50), rng.randf_range(-35, 35))
				warnings.append({"pos": center, "radius": 76, "life": 0.65, "color": VIOLET, "dmg": 18})
		else:
			pos += dir * float(e["speed"]) * delta
		e["pos"] = pos
		if pos.distance_to(ppos) < float(e["r"]) + PLAYER_R:
			_hurt_player(int(e["touch"]))
			e["pos"] = pos - dir * 22
	_resolve_dead()

func _update_pickups(delta: float) -> void:
	var keep := []
	for x in xp_shards:
		var p: Vector2 = x["pos"]
		var d := p.distance_to(player["pos"])
		if d < float(player["magnet"]):
			p = p.move_toward(player["pos"], (260 + (float(player["magnet"]) - d) * 3.2) * delta)
		if p.distance_to(player["pos"]) < 24:
			xp += float(x["value"])
			_float("+XP", p, LIME)
			if xp >= xp_need:
				_open_levelup()
		else:
			x["pos"] = p
			keep.append(x)
	xp_shards = keep

func _update_effects(delta: float) -> void:
	var keep_m := []
	for m in mines:
		m["timer"] = float(m["timer"]) - delta
		if float(m["timer"]) <= 0:
			warnings.append({"pos": m["pos"], "radius": m["radius"], "life": 0.28, "color": AMBER})
			for e in enemies:
				if Vector2(e["pos"]).distance_to(m["pos"]) <= float(m["radius"]):
					_damage_enemy(e, int(m["dmg"]), e["pos"], AMBER)
		else:
			keep_m.append(m)
	mines = keep_m
	var keep_w := []
	for w in warnings:
		w["life"] = float(w["life"]) - delta
		if w.has("dmg") and float(w["life"]) <= 0.05 and not w.has("done"):
			w["done"] = true
			if Vector2(w["pos"]).distance_to(player["pos"]) <= float(w["radius"]):
				_hurt_player(int(w["dmg"]))
		if float(w["life"]) > 0:
			keep_w.append(w)
	warnings = keep_w
	var keep_b := []
	for b in beams:
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) > 0:
			keep_b.append(b)
	beams = keep_b
	var keep_t := []
	for t in texts:
		t["life"] = float(t["life"]) - delta
		t["pos"] = Vector2(t["pos"]) + Vector2(0, -25) * delta
		if float(t["life"]) > 0:
			keep_t.append(t)
	texts = keep_t

func _spawn_pack(types: Array, count: int) -> void:
	for i in range(count):
		_spawn_enemy(types[i % types.size()])

func _spawn_enemy(typ: String) -> void:
	var edge := rng.randi_range(0, 3)
	var p := Vector2.ZERO
	if edge == 0:
		p = Vector2(rng.randf_range(ARENA.position.x, ARENA.end.x), ARENA.position.y - 35)
	elif edge == 1:
		p = Vector2(rng.randf_range(ARENA.position.x, ARENA.end.x), ARENA.end.y + 35)
	elif edge == 2:
		p = Vector2(ARENA.position.x - 35, rng.randf_range(ARENA.position.y, ARENA.end.y))
	else:
		p = Vector2(ARENA.end.x + 35, rng.randf_range(ARENA.position.y, ARENA.end.y))
	var d := _enemy_def(typ)
	d["pos"] = p
	d["hp"] = int(d["hp"]) + phase * 3
	d["max_hp"] = d["hp"]
	enemies.append(d)

func _spawn_elite(low_hp: bool) -> void:
	var e := _enemy_def("elite")
	e["pos"] = Vector2(980, 190)
	e["hp"] = 55 if low_hp else 180
	e["max_hp"] = 180
	enemies.append(e)
	_float("RIFT WARDEN ARRIVES", Vector2(475, 150), VIOLET)

func _enemy_def(typ: String) -> Dictionary:
	if typ == "charger":
		return {"type": typ, "hp": 30, "speed": 125, "r": 18, "touch": 8, "color": AMBER, "special": 1.0, "vel": Vector2.ZERO}
	if typ == "spitter":
		return {"type": typ, "hp": 24, "speed": 105, "r": 15, "touch": 4, "color": VIOLET, "special": 0.8}
	if typ == "splitter":
		return {"type": typ, "hp": 22, "speed": 118, "r": 15, "touch": 5, "color": LIME}
	if typ == "shield":
		return {"type": typ, "hp": 52, "speed": 78, "r": 22, "touch": 7, "color": Color(0.56, 0.72, 0.88), "armor": 3}
	if typ == "elite":
		return {"type": typ, "hp": 180, "speed": 78, "r": 34, "touch": 14, "color": Color(0.74, 0.52, 1.0), "special": 1.2}
	return {"type": "seeker", "hp": 18, "speed": 105 + phase * 12, "r": 14, "touch": 5, "color": Color(0.92, 0.30, 0.38)}

func _nearest_enemy(origin = null, range := 99999.0):
	if origin == null:
		origin = player["pos"]
	var best = null
	var best_d := range
	for e in enemies:
		var d := Vector2(e["pos"]).distance_to(origin)
		if d < best_d:
			best = e
			best_d = d
	return best

func _damage_enemy(e: Dictionary, amount: int, pos: Vector2, color: Color) -> void:
	var dmg := amount
	if e.has("armor"):
		dmg = max(1, amount - int(e["armor"]))
	e["hp"] = int(e["hp"]) - dmg
	e["flash"] = 0.12
	_float(str(dmg), pos, color)

func _resolve_dead() -> void:
	var keep := []
	var spawned := []
	for e in enemies:
		if int(e["hp"]) <= 0:
			var p: Vector2 = e["pos"]
			xp_shards.append({"pos": p, "value": 2.0 if e["type"] != "elite" else 12.0, "life": 99.0})
			_float("shard", p, LIME)
			if e["type"] == "splitter":
				for i in range(2):
					var s := _enemy_def("seeker")
					s["pos"] = p + Vector2.RIGHT.rotated(i * PI) * 22
					s["hp"] = 10
					s["max_hp"] = 10
					spawned.append(s)
			if e["type"] == "elite" and run_time >= TARGET_TIME - 12:
				_show_result(true, "VICTORY", "The Rift Warden broke before the last harvest bell.")
				return
		else:
			keep.append(e)
	enemies = keep + spawned

func _hurt_player(amount: int) -> void:
	if float(player["hurt"]) > 0:
		return
	player["hp"] = int(player["hp"]) - amount
	player["hurt"] = 0.42
	_float("-%d" % amount, Vector2(player["pos"]) + Vector2(0, -26), ROSE)

func _open_levelup() -> void:
	paused_by_level = true
	state = "levelup"
	_clear_ui()
	_panel(Vector2(270, 115), Vector2(740, 470), Color(0.045, 0.052, 0.072, 0.98), AMBER)
	_label("VOID MUTATION", Vector2(330, 142), Vector2(620, 54), 43, AMBER)
	_label("Choose a change. The field waits.", Vector2(405, 202), Vector2(470, 30), 20, TEXT)
	var picks := _upgrade_choices()
	for i in range(picks.size()):
		var name: String = picks[i]
		var x := 325.0 + i * 215.0
		var def = all_weapons.get(name, {"color": LIME, "text": "Sharpen the runner's survival stats."})
		_panel(Vector2(x, 272), Vector2(180, 205), Color(0.070, 0.083, 0.100, 0.98), def["color"])
		_label(name, Vector2(x + 10, 292), Vector2(160, 34), 21, def["color"])
		_label(def["text"], Vector2(x + 18, 332), Vector2(144, 78), 16, TEXT)
		_button("TAKE", Vector2(x + 30, 423), Vector2(120, 40), Callable(self, "_choose_upgrade").bind(name))

func _upgrade_choices() -> Array:
	var pool := ["Mag Rail", "Shard Mine", "Tether Drone", "Ink Comet", "Pressure Vent"]
	var picks := []
	for n in pool:
		if not upgrades_seen.has(n):
			picks.append(n)
		if picks.size() >= 3:
			return picks
	for n in pool:
		if picks.size() < 3:
			picks.append(n)
	return picks

func _choose_upgrade(name: String) -> void:
	_add_weapon(name)
	level += 1
	xp = max(0.0, xp - xp_need)
	xp_need += 5 + level * 2
	paused_by_level = false
	state = "game"
	_clear_ui()
	_float("%s online" % name, Vector2(500, 110), all_weapons[name]["color"])

func _elite_exists() -> bool:
	for e in enemies:
		if e["type"] == "elite":
			return true
	return false

func _show_result(victory: bool, title: String, note: String) -> void:
	state = "result"
	paused_by_level = false
	result_victory = victory
	result_title = title
	result_note = note
	_clear_ui()
	var border := LIME if victory else ROSE
	_panel(Vector2(350, 145), Vector2(580, 390), Color(0.045, 0.052, 0.070, 0.98), border)
	_label(title, Vector2(390, 190), Vector2(500, 70), 58, border)
	_label(note, Vector2(420, 285), Vector2(440, 52), 21, TEXT)
	_label("Time %.0fs   Level %d   Weapons %d" % [run_time, level, weapons.size()], Vector2(420, 350), Vector2(440, 32), 21, MUTED)
	_button("RETRY", Vector2(430, 438), Vector2(170, 56), Callable(self, "_retry"))
	_button("TITLE", Vector2(680, 438), Vector2(170, 56), Callable(self, "_title"))

func _retry() -> void:
	_start_run(scenario)

func _title() -> void:
	scenario = ""
	_show_title()

func _float(text: String, pos: Vector2, color: Color) -> void:
	texts.append({"text": text, "pos": pos, "color": color, "life": 0.75})

func _draw() -> void:
	_draw_background()
	if state == "title":
		_draw_title_art()
	elif state == "select":
		_draw_select_art()
	elif state == "game" or state == "levelup":
		_draw_game()
	elif state == "result":
		_draw_game(true)

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), BG)
	for i in range(12):
		var x := -80.0 + i * 135.0 + sin(elapsed_draw * 0.2 + i) * 8.0
		draw_line(Vector2(x, 0), Vector2(x + 130, 720), Color(0.08, 0.12, 0.15, 0.35), 18)
	for i in range(40):
		var p := Vector2(fposmod(i * 97.0 + elapsed_draw * 10.0, VIEW.x), fposmod(i * 53.0, VIEW.y))
		draw_circle(p, 1.5 + float(i % 3), Color(0.35, 0.80, 0.90, 0.18))

func _draw_title_art() -> void:
	draw_circle(Vector2(640, 345), 105 + sin(elapsed_draw * 2.0) * 4.0, Color(0.16, 0.32, 0.42, 0.35))
	draw_arc(Vector2(640, 345), 135, 0, TAU * 0.82, 80, CYAN, 4)
	draw_arc(Vector2(640, 345), 76, TAU * 0.18, TAU, 80, VIOLET, 3)

func _draw_select_art() -> void:
	for i in range(chars.size()):
		var c = chars[i]
		var center := Vector2(310 + i * 330, 292)
		draw_circle(center, 58, Color(c["color"].r, c["color"].g, c["color"].b, 0.18))
		draw_circle(center, 30, c["color"])
		draw_rect(Rect2(center + Vector2(-10, -56), Vector2(20, 45)), c["color"].lightened(0.25))
		draw_line(center + Vector2(-42, 30), center + Vector2(42, 30), c["color"], 6)

func _draw_game(dim := false) -> void:
	draw_rect(ARENA, Color(0.035, 0.048, 0.060))
	for x in range(int(ARENA.position.x), int(ARENA.end.x), 64):
		draw_line(Vector2(x, ARENA.position.y), Vector2(x + 80, ARENA.end.y), Color(0.10, 0.16, 0.18, 0.22), 1)
	for y in range(int(ARENA.position.y), int(ARENA.end.y), 64):
		draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color(0.08, 0.12, 0.15, 0.20), 1)
	draw_rect(ARENA, Color(0.20, 0.68, 0.75, 0.38), false, 3)
	for m in mines:
		draw_circle(m["pos"], 10 + sin(float(m["timer"]) * 12.0) * 3.0, AMBER)
		draw_arc(m["pos"], m["radius"], 0, TAU, 48, Color(0.96, 0.63, 0.20, 0.24), 2)
	for w in warnings:
		var a: float = clamp(float(w["life"]) * 1.5, 0.05, 0.7)
		draw_circle(w["pos"], w["radius"], Color(w["color"].r, w["color"].g, w["color"].b, a * 0.22))
		draw_arc(w["pos"], w["radius"], 0, TAU, 64, Color(w["color"].r, w["color"].g, w["color"].b, a), 3)
	for x in xp_shards:
		draw_circle(x["pos"], 7, LIME)
		draw_circle(x["pos"], 12, Color(0.42, 0.88, 0.34, 0.15))
	for s in shots:
		draw_circle(s["pos"], 5, s["color"])
		draw_line(s["pos"], Vector2(s["pos"]) - Vector2(s["vel"]).normalized() * 18, Color(s["color"].r, s["color"].g, s["color"].b, 0.45), 3)
	for b in enemy_shots:
		draw_circle(b["pos"], 6, ROSE)
	for beam in beams:
		draw_line(beam["a"], beam["b"], beam["color"], 3)
	for e in enemies:
		_draw_enemy(e)
	_draw_player()
	_draw_hud()
	for t in texts:
		_draw_text(t["text"], t["pos"], 22, t["color"])
	if dim or state == "levelup":
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.32))

func _draw_enemy(e: Dictionary) -> void:
	var p: Vector2 = e["pos"]
	var r := float(e["r"])
	var col: Color = e["color"]
	if float(e.get("flash", 0.0)) > 0:
		col = Color(1, 1, 1)
	if e["type"] == "charger":
		draw_polygon([p + Vector2(0, -r), p + Vector2(r * 1.2, r), p + Vector2(-r * 1.2, r)], [col])
	elif e["type"] == "spitter":
		draw_circle(p, r, col)
		draw_circle(p + Vector2(0, -3), 5, BG)
	elif e["type"] == "splitter":
		draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2, r * 2)), col)
	elif e["type"] == "shield":
		draw_circle(p, r, col)
		draw_arc(p, r + 8, -1.2, 1.2, 24, Color(0.86, 0.96, 1.0), 4)
	elif e["type"] == "elite":
		draw_circle(p, r + 8, Color(0.30, 0.16, 0.44))
		draw_polygon([p + Vector2(0, -r - 10), p + Vector2(r + 15, 0), p + Vector2(0, r + 10), p + Vector2(-r - 15, 0)], [col])
	else:
		draw_circle(p, r, col)
	var hp_w := r * 2.2
	draw_rect(Rect2(p + Vector2(-hp_w / 2, -r - 12), Vector2(hp_w, 4)), Color(0.15, 0.05, 0.07))
	draw_rect(Rect2(p + Vector2(-hp_w / 2, -r - 12), Vector2(hp_w * max(0, int(e["hp"])) / max(1, int(e["max_hp"])), 4)), LIME)

func _draw_player() -> void:
	var p: Vector2 = player["pos"]
	var col: Color = player["color"]
	if float(player["hurt"]) > 0:
		col = Color(1.0, 0.88, 0.88)
	draw_circle(p, PLAYER_R + 8, Color(col.r, col.g, col.b, 0.18))
	draw_circle(p, PLAYER_R, col)
	draw_rect(Rect2(p + Vector2(-6, -32), Vector2(12, 24)), col.lightened(0.35))
	for w in weapons:
		if w["name"] == "Tether Drone":
			var d := p + Vector2.RIGHT.rotated(float(w["angle"])) * (62 + int(w["level"]) * 8)
			draw_circle(d, 9, Color(0.70, 0.90, 1.0))
			draw_line(p, d, Color(0.70, 0.90, 1.0, 0.25), 2)

func _draw_hud() -> void:
	draw_rect(Rect2(Vector2(28, 16), Vector2(1224, 44)), Color(0.035, 0.045, 0.058, 0.92))
	draw_rect(Rect2(Vector2(50, 28), Vector2(210, 14)), Color(0.17, 0.05, 0.07))
	draw_rect(Rect2(Vector2(50, 28), Vector2(210 * max(0, int(player["hp"])) / max(1, int(player["max_hp"])), 14)), ROSE)
	draw_rect(Rect2(Vector2(300, 28), Vector2(230, 14)), Color(0.04, 0.13, 0.08))
	draw_rect(Rect2(Vector2(300, 28), Vector2(230 * clamp(xp / xp_need, 0, 1), 14)), LIME)
	_draw_text("HP %d/%d" % [player["hp"], player["max_hp"]], Vector2(54, 22), 18, TEXT)
	_draw_text("LV %d  XP %.0f/%.0f" % [level, xp, xp_need], Vector2(305, 22), 18, TEXT)
	_draw_text("Time %.0f / %.0f   Phase %d" % [run_time, TARGET_TIME, phase], Vector2(580, 22), 20, Color(0.74, 0.96, 1.0))
	var names := []
	for w in weapons:
		names.append("%s %d" % [w["name"], w["level"]])
	_draw_text("Weapons: " + ", ".join(names), Vector2(850, 22), 17, TEXT)

func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
GDSCRIPT_EOF

cat > "$GAME/demo_outputs/01_title_select_arena.json" <<'EOF'
{
  "duration_frames": 600,
  "events": [
    {"frame": 45, "type": "mouse_click", "button": "left", "x": 640, "y": 452},
    {"frame": 125, "type": "mouse_click", "button": "left", "x": 310, "y": 488},
    {"frame": 185, "type": "key_down", "keycode": "D"},
    {"frame": 275, "type": "key_up", "keycode": "D"},
    {"frame": 290, "type": "key_down", "keycode": "S"},
    {"frame": 380, "type": "key_up", "keycode": "S"},
    {"frame": 600, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_levelup_choice.json" <<'EOF'
{
  "scenario": "levelup",
  "duration_frames": 430,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "D"},
    {"frame": 75, "type": "key_up", "keycode": "D"},
    {"frame": 190, "type": "mouse_click", "button": "left", "x": 630, "y": 444},
    {"frame": 430, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_multi_weapon.json" <<'EOF'
{
  "scenario": "multi_weapon",
  "duration_frames": 520,
  "events": [
    {"frame": 25, "type": "key_down", "keycode": "W"},
    {"frame": 95, "type": "key_up", "keycode": "W"},
    {"frame": 110, "type": "key_down", "keycode": "A"},
    {"frame": 190, "type": "key_up", "keycode": "A"},
    {"frame": 520, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_enemy_showcase.json" <<'EOF'
{
  "scenario": "enemy_showcase",
  "duration_frames": 560,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "D"},
    {"frame": 105, "type": "key_up", "keycode": "D"},
    {"frame": 130, "type": "key_down", "keycode": "S"},
    {"frame": 210, "type": "key_up", "keycode": "S"},
    {"frame": 560, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_escalation.json" <<'EOF'
{
  "scenario": "escalation",
  "duration_frames": 600,
  "events": [
    {"frame": 30, "type": "key_down", "keycode": "A"},
    {"frame": 110, "type": "key_up", "keycode": "A"},
    {"frame": 130, "type": "key_down", "keycode": "W"},
    {"frame": 210, "type": "key_up", "keycode": "W"},
    {"frame": 600, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/06_near_victory.json" <<'EOF'
{
  "scenario": "near_victory",
  "duration_frames": 600,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "D"},
    {"frame": 100, "type": "key_up", "keycode": "D"},
    {"frame": 120, "type": "key_down", "keycode": "S"},
    {"frame": 220, "type": "key_up", "keycode": "S"},
    {"frame": 600, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/07_near_defeat.json" <<'EOF'
{
  "scenario": "near_defeat",
  "duration_frames": 420,
  "events": [
    {"frame": 35, "type": "key_down", "keycode": "A"},
    {"frame": 90, "type": "key_up", "keycode": "A"},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

echo "wrote Void Harvest fallback project to $GAME"
ls -1 "$GAME"
