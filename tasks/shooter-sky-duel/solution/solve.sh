#!/bin/bash
# Reference solution for gamecraft-bench/shooter-sky-duel.
#
# Compact 2D aerial combat oracle:
#   - Title/hangar -> sortie select -> side-view physics dogfight -> debrief.
#   - Plane has thrust, drag, gravity, turning inertia, health, crash state.
#   - Score unlocks parts; hangar equips engine/wing/weapon/armor variants.
#   - Sorties, enemy aircraft types, boss weak points, HUD and feedback are
#     represented with simple procedural art so art scores stay limited.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="SkyDuel"
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

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT'
extends Node2D

const VIEW := Vector2(1280, 720)
const GROUND_Y := 670.0
const MISSIONS := [
	{"name":"Dawn Intercept", "sky":Color(0.34,0.68,0.94), "objective":"Destroy scouts", "hazard":"soft clouds"},
	{"name":"Storm Break", "sky":Color(0.18,0.23,0.36), "objective":"Survive lightning", "hazard":"storm cells"},
	{"name":"Flak Valley", "sky":Color(0.45,0.52,0.50), "objective":"Silence towers", "hazard":"flak bursts"},
	{"name":"High Ace", "sky":Color(0.22,0.42,0.78), "objective":"Duel circling aces", "hazard":"thin air"},
	{"name":"Gunship Run", "sky":Color(0.62,0.43,0.30), "objective":"Break convoy", "hazard":"smoke banks"},
	{"name":"Storm Carrier", "sky":Color(0.10,0.14,0.22), "objective":"Destroy carrier boss", "hazard":"night barrage"}
]
const ENEMY_TYPES := ["dive bomber", "circling ace", "heavy gunship", "fast interceptor"]

var scenario := ""
var mode := "title"
var mission := 0
var p := Vector2(260, 320)
var vel := Vector2(110, 0)
var angle := -0.10
var turn_v := 0.0
var aim := Vector2(720, 320)
var keys := {}
var health := 4
var max_health := 4
var score := 0
var accuracy_hits := 0
var shots := 0
var damage_taken := 0
var unlocked := 0
var engine := 0
var wing := 0
var weapon := 0
var armor := 0
var fire_cd := 0.0
var smoke_t := 0.0
var stall_t := 0.0
var crash_t := 0.0
var bullets := []
var enemies := []
var fx := []
var clouds := []
var debrief_text := ""
var boss_spawned := false
var sortie_time := 0.0

func _ready() -> void:
	randomize()
	scenario = _scenario_arg()
	for i in range(16):
		clouds.append(Vector2(randf_range(0, VIEW.x), randf_range(80, 430)))
	if scenario == "combat":
		_start_sortie(1)
	elif scenario == "hangar":
		mode = "hangar"
		score = 700
		unlocked = 3
	elif scenario == "boss":
		_start_sortie(5)
		_spawn_boss()
	elif scenario == "crash":
		_start_sortie(2)
		health = 1
		enemies.append(_enemy("heavy gunship", Vector2(335, 330)))
	elif scenario == "debrief":
		_show_debrief(true)
	else:
		mode = "title"
	set_process(true)

func _scenario_arg() -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--scenario" and i + 1 < args.size():
			return args[i + 1]
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim = event.position
	if event is InputEventKey:
		keys[event.keycode] = event.pressed
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		aim = event.position
		if mode == "title":
			mode = "hangar"
		elif mode == "hangar":
			_handle_hangar_click(event.position)
		elif mode == "sortie":
			_fire()
		elif mode == "debrief":
			mode = "title"

func _handle_hangar_click(pos: Vector2) -> void:
	if Rect2(1020, 600, 170, 54).has_point(pos):
		_start_sortie(mission)
		return
	if Rect2(890, 142, 220, 36).has_point(pos):
		mission = (mission + 1) % MISSIONS.size()
	for i in range(4):
		var r := Rect2(100, 180 + i * 88, 330, 54)
		if r.has_point(pos):
			if unlocked >= i:
				match i:
					0: engine = (engine + 1) % 3
					1: wing = (wing + 1) % 3
					2: weapon = (weapon + 1) % 3
					3: armor = (armor + 1) % 3

func _start_sortie(idx: int) -> void:
	mode = "sortie"
	mission = clamp(idx, 0, MISSIONS.size() - 1)
	p = Vector2(230, 320)
	vel = Vector2(120, 0)
	angle = -0.05
	turn_v = 0.0
	health = 4 + armor
	max_health = health
	damage_taken = 0
	sortie_time = 0.0
	fire_cd = 0.0
	boss_spawned = false
	bullets.clear()
	enemies.clear()
	fx.clear()
	for i in range(4):
		enemies.append(_enemy(ENEMY_TYPES[i], Vector2(760 + i * 95, 160 + i * 95)))

func _enemy(kind: String, pos: Vector2) -> Dictionary:
	var hp := 2
	if kind == "heavy gunship":
		hp = 5
	return {"kind": kind, "pos": pos, "hp": hp, "phase": 0, "t": 0.0, "boss": false}

func _spawn_boss() -> void:
	boss_spawned = true
	enemies.append({"kind":"carrier boss", "pos":Vector2(940, 300), "hp":14, "phase":0, "t":0.0, "boss":true, "weak":[Vector2(-70,-36), Vector2(-18,42), Vector2(68,-8)]})

func _process(delta: float) -> void:
	if mode == "sortie":
		_update_sortie(delta)
	for c in clouds:
		c.x -= 18.0 * delta
		if c.x < -80:
			c.x = VIEW.x + randf_range(10, 120)
			c.y = randf_range(70, 440)
	for f in fx:
		f.t -= delta
	fx = fx.filter(func(f): return f.t > 0.0)
	queue_redraw()

func _update_sortie(delta: float) -> void:
	sortie_time += delta
	var left := _down(KEY_A) or _down(KEY_LEFT)
	var right := _down(KEY_D) or _down(KEY_RIGHT)
	var thrust := _down(KEY_W) or _down(KEY_UP)
	var fire := _down(KEY_SPACE)
	turn_v += (int(right) - int(left)) * (1.8 + wing * 0.35) * delta
	turn_v *= 0.94
	angle += turn_v
	if thrust:
		vel += Vector2(cos(angle), sin(angle)) * (190.0 + engine * 45.0) * delta
		fx.append({"pos":p - Vector2(cos(angle), sin(angle)) * 30.0, "t":0.18, "kind":"exhaust"})
	vel.y += 95.0 * delta
	vel *= 0.995
	if vel.length() < 80.0 and p.y < 600.0:
		stall_t = 0.4
	if stall_t > 0:
		stall_t -= delta
	p += vel * delta
	if p.x < 40 or p.x > VIEW.x - 40:
		vel.x *= -0.45
	p.x = clamp(p.x, 40.0, VIEW.x - 40.0)
	if p.y < 50:
		p.y = 50
		vel.y = abs(vel.y) * 0.3
	if p.y > GROUND_Y:
		_damage(99)
	if fire_cd > 0:
		fire_cd -= delta
	if fire and fire_cd <= 0:
		_fire()
	_update_bullets(delta)
	_update_enemies(delta)
	if not boss_spawned and (mission >= 5 or sortie_time > 8.0):
		_spawn_boss()
	if enemies.is_empty() or score >= 900:
		_show_debrief(true)

func _down(k: int) -> bool:
	return bool(keys.get(k, false))

func _fire() -> void:
	if mode != "sortie" or fire_cd > 0:
		return
	var dirs := [angle]
	if weapon == 1:
		dirs = [angle - 0.16, angle, angle + 0.16]
	elif weapon == 2:
		dirs = [angle]
	for a in dirs:
		bullets.append({"pos":p + Vector2(cos(a), sin(a)) * 34.0, "vel":Vector2(cos(a), sin(a)) * (470.0 + weapon * 70.0), "t":2.2, "player":true})
	fire_cd = max(0.12, 0.30 - weapon * 0.06)
	shots += 1
	fx.append({"pos":p + Vector2(cos(angle), sin(angle)) * 38.0, "t":0.12, "kind":"muzzle"})

func _update_bullets(delta: float) -> void:
	for b in bullets:
		b.pos += b.vel * delta
		b.t -= delta
	for b in bullets:
		if not b.player:
			if b.pos.distance_to(p) < 24:
				b.t = 0
				_damage(1)
			continue
		for e in enemies:
			if b.pos.distance_to(e.pos) < (64 if e.boss else 25):
				b.t = 0
				e.hp -= 1
				accuracy_hits += 1
				fx.append({"pos":b.pos, "t":0.35, "kind":"spark"})
				if e.hp <= 0:
					score += 200 if e.boss else 80
					unlocked = max(unlocked, min(3, score / 220))
					fx.append({"pos":e.pos, "t":0.7, "kind":"boom"})
				break
	enemies = enemies.filter(func(e): return e.hp > 0)
	bullets = bullets.filter(func(b): return b.t > 0 and Rect2(-80, -80, 1440, 880).has_point(b.pos))

func _update_enemies(delta: float) -> void:
	for e in enemies:
		e.t += delta
		match e.kind:
			"dive bomber":
				e.pos += Vector2(-90, 70 * sin(e.t * 2.3)) * delta
			"circling ace":
				e.pos += Vector2(cos(e.t * 2.4), sin(e.t * 2.4)) * 70.0 * delta
			"heavy gunship":
				e.pos += Vector2(-24, sin(e.t) * 24) * delta
			"fast interceptor":
				e.pos += (p - e.pos).normalized() * 95.0 * delta
			"carrier boss":
				e.phase = 0 if e.hp > 9 else (1 if e.hp > 4 else 2)
				e.pos.y = 300 + sin(e.t * 1.4) * 40
		if e.pos.distance_to(p) < 30:
			_damage(1)
		if int(e.t * 2.0) != int((e.t - delta) * 2.0):
			var dir: Vector2 = (p - e.pos).normalized()
			if e.boss:
				for i in range(3):
					var a: float = atan2(dir.y, dir.x) + (i - 1) * 0.28
					bullets.append({"pos":e.pos, "vel":Vector2(cos(a), sin(a)) * 190.0, "t":4.0, "player":false})
			else:
				bullets.append({"pos":e.pos, "vel":dir * 165.0, "t":3.2, "player":false})

func _damage(amount: int) -> void:
	if crash_t > 0:
		return
	health -= amount
	damage_taken += amount
	smoke_t = 0.8
	fx.append({"pos":p, "t":0.4, "kind":"hit"})
	if health <= 0:
		crash_t = 1.0
		_show_debrief(false)

func _show_debrief(win: bool) -> void:
	mode = "debrief"
	var acc := 0
	if shots > 0:
		acc = int(float(accuracy_hits) / float(shots) * 100.0)
	var unlock := "New part unlocked!" if unlocked > 0 else "No unlocks"
	debrief_text = ("SORTIE COMPLETE" if win else "SORTIE FAILED") + "\nScore: %d\nEnemies destroyed: %d\nAccuracy: %d%%\nDamage taken: %d\n%s" % [score, accuracy_hits, acc, damage_taken, unlock]

func _draw() -> void:
	if mode == "sortie":
		_draw_sortie()
	elif mode == "hangar":
		_draw_hangar()
	elif mode == "debrief":
		_draw_debrief()
	else:
		_draw_title()

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.06,0.10,0.16))
	for c in clouds:
		draw_circle(c, 26, Color(0.45,0.55,0.62,0.18))
	_text("SKY DUEL", Vector2(470, 185), 62, Color(0.95,0.88,0.55))
	_text("physics dogfights / hangar parts / boss gunships", Vector2(390, 260), 22, Color(0.78,0.86,0.94))
	_draw_plane(Vector2(640, 390), -0.18, Color(0.8,0.9,1.0), 1.7)
	_panel(Rect2(520, 520, 240, 58), Color(0.13,0.20,0.28))
	_text("CLICK TO HANGAR", Vector2(548, 556), 22, Color.WHITE)

func _draw_hangar() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.10,0.12,0.14))
	_panel(Rect2(42, 42, 1196, 626), Color(0.13,0.16,0.18))
	_text("HANGAR - customize aircraft", Vector2(80, 92), 34, Color(0.95,0.82,0.45))
	_text("Score unlocks parts. Click categories to cycle equipment.", Vector2(80, 130), 18, Color(0.78,0.82,0.86))
	var labels := ["ENGINE thrust +" + str(engine), "WINGS turn +" + str(wing), "WEAPON pod " + str(weapon), "ARMOR plates +" + str(armor)]
	for i in range(4):
		var r := Rect2(100, 180 + i * 88, 330, 54)
		_panel(r, Color(0.18,0.22,0.26))
		_text(labels[i] + ("  UNLOCKED" if unlocked >= i else "  LOCKED"), r.position + Vector2(18, 34), 18, Color.WHITE if unlocked >= i else Color(0.5,0.55,0.6))
	_draw_plane(Vector2(660, 350), 0.0, Color(0.75 + armor*0.05,0.85,1.0), 2.8)
	_text("Stats: thrust %d  turn %d  firepower %d  armor %d" % [engine+1, wing+1, weapon+1, armor+1], Vector2(520, 520), 20, Color(0.86,0.93,1.0))
	var m: Dictionary = MISSIONS[mission]
	_panel(Rect2(860, 120, 300, 86), Color(0.18,0.22,0.28))
	_text("Mission: " + m.name, Vector2(890, 155), 18, Color.WHITE)
	_text("Objective: " + m.objective, Vector2(890, 183), 15, Color(0.76,0.82,0.9))
	_panel(Rect2(1020, 600, 170, 54), Color(0.28,0.36,0.20))
	_text("LAUNCH", Vector2(1062, 634), 22, Color.WHITE)

func _draw_sortie() -> void:
	var m: Dictionary = MISSIONS[mission]
	draw_rect(Rect2(Vector2.ZERO, VIEW), m.sky)
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, 60), Color(0.18,0.22,0.18))
	for i in range(0, 1280, 90):
		draw_line(Vector2(i, GROUND_Y + 12), Vector2(i + 40, GROUND_Y + 8), Color(0.28,0.32,0.28), 3)
	for c in clouds:
		draw_circle(c, 32, Color(1,1,1,0.18))
		draw_circle(c + Vector2(26, 8), 24, Color(1,1,1,0.12))
	for b in bullets:
		draw_circle(b.pos, 5 if b.player else 6, Color(1,0.92,0.25) if b.player else Color(1,0.22,0.18))
	for e in enemies:
		if e.boss:
			_draw_boss(e)
		else:
			_draw_enemy(e)
	if smoke_t > 0 or health < max_health:
		draw_circle(p - Vector2(cos(angle), sin(angle)) * 52, 18, Color(0.08,0.08,0.08,0.35))
	_draw_plane(p, angle, Color(0.78,0.88,1.0), 1.0)
	for f in fx:
		var a: float = clamp(f.t, 0.0, 1.0)
		if f.kind == "boom":
			draw_circle(f.pos, 42 * a, Color(1,0.48,0.08,a))
		elif f.kind == "spark":
			draw_circle(f.pos, 18 * a, Color(1,1,0.45,a))
		elif f.kind == "exhaust":
			draw_circle(f.pos, 15 * a, Color(1,0.55,0.1,a))
		else:
			draw_circle(f.pos, 24 * a, Color(1,1,1,a))
	_draw_hud()

func _draw_hud() -> void:
	_panel(Rect2(20, 18, 520, 90), Color(0.03,0.07,0.10,0.72))
	_text("SPD %03d  ALT %03d  HP %d/%d  AMMO INF" % [int(vel.length()), int(GROUND_Y - p.y), health, max_health], Vector2(42, 50), 18, Color.WHITE)
	_text("Score %d  Mission %d/6  Objective: %s" % [score, mission + 1, MISSIONS[mission].objective], Vector2(42, 82), 16, Color(0.86,0.92,1))
	if stall_t > 0:
		_text("STALL WARNING - DIVE FOR SPEED", Vector2(510, 138), 24, Color(1,0.24,0.18))

func _draw_debrief() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.05,0.07,0.10))
	_panel(Rect2(350, 120, 580, 440), Color(0.12,0.16,0.20))
	_text("DEBRIEF", Vector2(520, 178), 42, Color(0.96,0.82,0.45))
	var lines := debrief_text.split("\n")
	for i in range(lines.size()):
		_text(lines[i], Vector2(430, 240 + i * 42), 22, Color.WHITE)
	_text("Click to return to title", Vector2(510, 520), 18, Color(0.72,0.78,0.84))

func _draw_plane(pos: Vector2, a: float, col: Color, scale: float) -> void:
	var nose := pos + Vector2(cos(a), sin(a)) * 34 * scale
	var tail := pos - Vector2(cos(a), sin(a)) * 26 * scale
	var side: Vector2 = Vector2(-sin(a), cos(a))
	draw_colored_polygon([nose, tail + side * 20 * scale, pos - side * 5 * scale, tail - side * 20 * scale], col)
	draw_line(pos - side * 38 * scale, pos + side * 38 * scale, Color(0.45,0.62,0.78), 6 * scale)
	draw_circle(pos, 6 * scale, Color(0.1,0.18,0.24))

func _draw_enemy(e: Dictionary) -> void:
	var col: Color = Color(0.95,0.28,0.20)
	if e.kind == "circling ace": col = Color(0.95,0.70,0.20)
	if e.kind == "heavy gunship": col = Color(0.55,0.28,0.24)
	if e.kind == "fast interceptor": col = Color(0.95,0.18,0.55)
	_draw_plane(e.pos, PI, col, 0.75)
	_text(e.kind, e.pos + Vector2(-44, -32), 12, Color(0.1,0.1,0.12))

func _draw_boss(e: Dictionary) -> void:
	var pos: Vector2 = e.pos
	_panel(Rect2(pos.x - 120, pos.y - 58, 230, 116), Color(0.38,0.16,0.12))
	draw_circle(pos + Vector2(-68,-35), 18, Color(1,0.75,0.16))
	draw_circle(pos + Vector2(-20,38), 18, Color(1,0.75,0.16))
	draw_circle(pos + Vector2(64,-8), 18, Color(1,0.75,0.16))
	_text("BOSS phase " + str(e.phase + 1) + " weak points", pos + Vector2(-105,-78), 15, Color.WHITE)

func _panel(r: Rect2, c: Color) -> void:
	draw_rect(r, c)
	draw_rect(r, Color(0.72,0.82,0.92), false, 2)

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_hangar.json" <<'EOF'
{
  "duration_frames": 420,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 540},
    {"frame": 110, "type": "mouse_click", "button": "left", "x": 260, "y": 205},
    {"frame": 170, "type": "mouse_click", "button": "left", "x": 1088, "y": 626},
    {"frame": 240, "type": "key_down", "keycode": "W"},
    {"frame": 300, "type": "key_down", "keycode": "D"},
    {"frame": 330, "type": "key_up", "keycode": "D"},
    {"frame": 360, "type": "mouse_click", "button": "left", "x": 860, "y": 250},
    {"frame": 400, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_combat.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 520,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "W"},
    {"frame": 40, "type": "key_down", "keycode": "D"},
    {"frame": 80, "type": "mouse_click", "button": "left", "x": 850, "y": 260},
    {"frame": 130, "type": "key_up", "keycode": "D"},
    {"frame": 150, "type": "key_down", "keycode": "A"},
    {"frame": 190, "type": "mouse_click", "button": "left", "x": 820, "y": 420},
    {"frame": 230, "type": "key_up", "keycode": "A"},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 920, "y": 320},
    {"frame": 500, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_hangar_unlocks.json" <<'EOF'
{
  "scenario": "hangar",
  "duration_frames": 420,
  "events": [
    {"frame": 40, "type": "mouse_click", "button": "left", "x": 230, "y": 205},
    {"frame": 90, "type": "mouse_click", "button": "left", "x": 230, "y": 292},
    {"frame": 140, "type": "mouse_click", "button": "left", "x": 230, "y": 380},
    {"frame": 190, "type": "mouse_click", "button": "left", "x": 230, "y": 468},
    {"frame": 250, "type": "mouse_click", "button": "left", "x": 1088, "y": 626},
    {"frame": 330, "type": "key_down", "keycode": "W"},
    {"frame": 390, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_boss.json" <<'EOF'
{
  "scenario": "boss",
  "duration_frames": 520,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "W"},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 930, "y": 280},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 930, "y": 320},
    {"frame": 180, "type": "key_down", "keycode": "A"},
    {"frame": 240, "type": "key_up", "keycode": "A"},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 930, "y": 260},
    {"frame": 500, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_crash_debrief.json" <<'EOF'
{
  "scenario": "crash",
  "duration_frames": 360,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 180, "type": "wait"},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

echo "sky-duel oracle generated at $GAME"
