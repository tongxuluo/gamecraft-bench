#!/bin/bash
# Reference solution for gamecraft-bench/shooter-void-patrol.
#
# Compact side-scrolling shmup oracle:
#   - Title -> auto-scrolling stages -> enemy waves -> power-up chain -> boss
#     -> stage tally / continue / victory.
#   - Freely moving ship, forward fire, bombs, lives, continues, weapon tiers.
#   - Multiple stages/enemy types/boss phases are deterministic scenarios.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="VoidPatrol"
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
const STAGES := [
	{"name":"Asteroid Gate", "color":Color(0.03,0.05,0.13), "scroll":120},
	{"name":"Nebula Trench", "color":Color(0.12,0.04,0.18), "scroll":150},
	{"name":"Ice Wreckfield", "color":Color(0.04,0.12,0.18), "scroll":135},
	{"name":"Solar Foundry", "color":Color(0.18,0.08,0.03), "scroll":165},
	{"name":"Void Citadel", "color":Color(0.02,0.01,0.07), "scroll":180}
]
const ENEMY_TYPES := ["sweeper", "sine drone", "turret pod", "splitter"]
const TIER_NAMES := ["single", "spread", "laser", "homing"]

var scenario := ""
var mode := "title" # title, play, tally, continue, result
var stage := 0
var ship := Vector2(190, 360)
var keys := {}
var lives := 3
var continues := 1
var bombs := 2
var score := 0
var weapon_tier := 0
var stage_progress := 0.0
var scroll_x := 0.0
var fire_cd := 0.0
var boss_spawned := false
var boss_phase := 0
var stage_clear := false
var bullets := []
var enemy_bullets := []
var enemies := []
var powerups := []
var fx := []
var stars := []
var summary := ""

func _ready() -> void:
	randomize()
	scenario = _scenario_arg()
	for i in range(90):
		stars.append({"pos":Vector2(randf_range(0, VIEW.x), randf_range(0, VIEW.y)), "z":randf_range(0.4, 1.8)})
	if scenario == "stage2":
		_start_stage(1)
		weapon_tier = 2
	elif scenario == "power":
		_start_stage(0)
		powerups.append({"pos":Vector2(330, 300), "t":20.0})
		powerups.append({"pos":Vector2(430, 410), "t":20.0})
	elif scenario == "boss":
		_start_stage(4)
		stage_progress = 85
		_spawn_boss()
	elif scenario == "continue":
		mode = "continue"
		lives = 0
	elif scenario == "victory":
		_show_result(true)
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
	if event is InputEventKey:
		keys[event.keycode] = event.pressed
		if event.pressed and event.keycode == KEY_E and mode == "play":
			_bomb()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "title":
			_start_stage(0)
		elif mode == "play":
			_fire()
		elif mode == "tally":
			if stage >= STAGES.size() - 1:
				_show_result(true)
			else:
				_start_stage(stage + 1)
		elif mode == "continue":
			if continues > 0:
				continues -= 1
				lives = 3
				weapon_tier = 0
				_start_stage(stage)
			else:
				_show_result(false)
		elif mode == "result":
			mode = "title"

func _start_stage(idx: int) -> void:
	mode = "play"
	stage = clamp(idx, 0, STAGES.size() - 1)
	ship = Vector2(190, 360)
	stage_progress = 0
	scroll_x = 0
	fire_cd = 0
	boss_spawned = false
	stage_clear = false
	bullets.clear()
	enemy_bullets.clear()
	enemies.clear()
	powerups.clear()
	fx.clear()
	_spawn_wave()

func _process(delta: float) -> void:
	if mode == "play":
		_update_play(delta)
	_update_fx(delta)
	queue_redraw()

func _update_play(delta: float) -> void:
	var st: Dictionary = STAGES[stage]
	scroll_x += float(st.scroll) * delta
	stage_progress += delta * 7.0
	for s in stars:
		var pos: Vector2 = s.pos
		pos.x -= float(st.scroll) * float(s.z) * delta
		if pos.x < 0:
			pos.x = VIEW.x
			pos.y = randf_range(0, VIEW.y)
		s.pos = pos
	var mv := Vector2.ZERO
	if _down(KEY_W) or _down(KEY_UP): mv.y -= 1
	if _down(KEY_S) or _down(KEY_DOWN): mv.y += 1
	if _down(KEY_A) or _down(KEY_LEFT): mv.x -= 1
	if _down(KEY_D) or _down(KEY_RIGHT): mv.x += 1
	if mv.length() > 0:
		ship += mv.normalized() * 260.0 * delta
	ship.x = clamp(ship.x, 45.0, 560.0)
	ship.y = clamp(ship.y, 55.0, 665.0)
	if _down(KEY_SPACE):
		_fire()
	if fire_cd > 0:
		fire_cd -= delta
	_update_bullets(delta)
	_update_enemies(delta)
	_update_powerups(delta)
	if int(stage_progress) % 18 == 0 and int(stage_progress - delta * 7.0) % 18 != 0 and not boss_spawned:
		_spawn_wave()
	if stage_progress > 72 and not boss_spawned:
		_spawn_boss()
	if boss_spawned and enemies.is_empty() and not stage_clear:
		stage_clear = true
		summary = "STAGE CLEAR\n%s\nScore: %d\nLives: %d\nWeapon tier: %s" % [st.name, score, lives, TIER_NAMES[weapon_tier]]
		mode = "tally"

func _down(k: int) -> bool:
	return bool(keys.get(k, false))

func _fire() -> void:
	if fire_cd > 0:
		return
	var dirs := [0.0]
	if weapon_tier == 1:
		dirs = [-0.18, 0.0, 0.18]
	elif weapon_tier == 2:
		dirs = [0.0]
	elif weapon_tier >= 3:
		dirs = [-0.26, -0.08, 0.08, 0.26]
	for a in dirs:
		bullets.append({"pos":ship + Vector2(28, 0), "vel":Vector2(cos(a), sin(a)) * (560.0 + weapon_tier * 45.0), "t":2.0, "tier":weapon_tier})
	fire_cd = max(0.08, 0.20 - weapon_tier * 0.025)
	fx.append({"pos":ship + Vector2(32, 0), "t":0.12, "kind":"muzzle"})

func _bomb() -> void:
	if bombs <= 0:
		return
	bombs -= 1
	enemy_bullets.clear()
	for e in enemies:
		e.hp -= 3
		fx.append({"pos":e.pos, "t":0.55, "kind":"bomb"})
	enemies = enemies.filter(func(e): return e.hp > 0)
	score += 75
	fx.append({"pos":Vector2(640,360), "t":0.7, "kind":"screen"})

func _spawn_wave() -> void:
	for i in range(4):
		var kind: String = ENEMY_TYPES[(i + stage) % ENEMY_TYPES.size()]
		enemies.append({"kind":kind, "pos":Vector2(1110 + i * 72, 135 + i * 118), "hp":1 + int(kind == "turret pod") * 2, "t":0.0, "boss":false, "phase":0})
	if randf() < 0.75:
		powerups.append({"pos":Vector2(760, randf_range(130, 590)), "t":15.0})

func _spawn_boss() -> void:
	boss_spawned = true
	enemies.clear()
	enemies.append({"kind":"stage boss", "pos":Vector2(1000, 360), "hp":18, "t":0.0, "boss":true, "phase":0})

func _update_bullets(delta: float) -> void:
	for b in bullets:
		b.pos += b.vel * delta
		b.t -= delta
	for b in enemy_bullets:
		b.pos += b.vel * delta
		b.t -= delta
		if b.pos.distance_to(ship) < 18:
			b.t = 0
			_lose_life()
	for b in bullets:
		for e in enemies:
			var rad := 70.0 if e.boss else 24.0
			if b.pos.distance_to(e.pos) < rad:
				b.t = 0
				e.hp -= 2 if b.tier == 2 else 1
				fx.append({"pos":b.pos, "t":0.35, "kind":"hit"})
				if e.hp <= 0:
					score += 500 if e.boss else 80
					if not e.boss and randf() < 0.45:
						powerups.append({"pos":e.pos, "t":10.0})
					fx.append({"pos":e.pos, "t":0.7, "kind":"boom"})
				break
	enemies = enemies.filter(func(e): return e.hp > 0)
	bullets = bullets.filter(func(b): return b.t > 0 and b.pos.x < VIEW.x + 80)
	enemy_bullets = enemy_bullets.filter(func(b): return b.t > 0 and Rect2(-50,-50,1380,820).has_point(b.pos))

func _update_enemies(delta: float) -> void:
	for e in enemies:
		e.t += delta
		if e.boss:
			e.phase = 0 if e.hp > 12 else (1 if e.hp > 6 else 2)
			boss_phase = e.phase
			e.pos.y = 360 + sin(e.t * (1.2 + e.phase * 0.5)) * 95
			if int(e.t * 2.2) != int((e.t - delta) * 2.2):
				for i in range(5 + e.phase * 2):
					var a: float = PI + (i - 3) * 0.16
					enemy_bullets.append({"pos":e.pos + Vector2(-80, 0), "vel":Vector2(cos(a), sin(a)) * 175.0, "t":5.0})
		else:
			match e.kind:
				"sweeper":
					e.pos += Vector2(-150, 0) * delta
				"sine drone":
					e.pos += Vector2(-115, sin(e.t * 5.0) * 100) * delta
				"turret pod":
					e.pos += Vector2(-55, 0) * delta
				"splitter":
					e.pos += Vector2(-120, cos(e.t * 3.0) * 70) * delta
			if int(e.t * 1.6) != int((e.t - delta) * 1.6):
				enemy_bullets.append({"pos":e.pos, "vel":(ship - e.pos).normalized() * 170.0, "t":4.0})
		if e.pos.distance_to(ship) < 24:
			_lose_life()
		if e.pos.x < -60:
			e.hp = 0
	enemies = enemies.filter(func(e): return e.hp > 0)

func _update_powerups(delta: float) -> void:
	for p in powerups:
		p.pos += Vector2(-55, sin(Time.get_ticks_msec() * 0.004) * 25) * delta
		p.t -= delta
		if p.pos.distance_to(ship) < 28:
			p.t = 0
			weapon_tier = min(3, weapon_tier + 1)
			score += 120
			fx.append({"pos":ship, "t":0.5, "kind":"power"})
	powerups = powerups.filter(func(p): return p.t > 0 and p.pos.x > -30)

func _lose_life() -> void:
	lives -= 1
	weapon_tier = 0
	fx.append({"pos":ship, "t":0.7, "kind":"death"})
	if lives <= 0:
		mode = "continue"

func _show_result(win: bool) -> void:
	mode = "result"
	summary = ("VICTORY TALLY" if win else "GAME OVER") + "\nTotal score: %d\nLives used: %d\nStages cleared: %d\nContinues left: %d" % [score, 3 - lives, stage + 1, continues]

func _update_fx(delta: float) -> void:
	for f in fx:
		f.t -= delta
	fx = fx.filter(func(f): return f.t > 0)

func _draw() -> void:
	if mode == "play":
		_draw_play()
	elif mode == "tally":
		_draw_panel_screen("STAGE TALLY", summary)
	elif mode == "continue":
		_draw_panel_screen("CONTINUE?", "Lives depleted\nContinues remaining: %d\nClick to continue or exhaust to game over" % continues)
	elif mode == "result":
		_draw_panel_screen("VOID PATROL", summary)
	else:
		_draw_title()

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.01,0.015,0.04))
	for s in stars:
		draw_circle(s.pos, 1.5 * float(s.z), Color(0.75,0.85,1,0.7))
	_draw_ship(Vector2(640, 390), 2.2)
	_text("VOID PATROL", Vector2(440, 190), 60, Color(0.55,0.92,1.0))
	_text("side-scrolling power-chain shoot-em-up", Vector2(420, 255), 22, Color(0.84,0.88,0.96))
	_panel(Rect2(520, 520, 240, 58), Color(0.08,0.16,0.28))
	_text("CLICK START", Vector2(570, 556), 22, Color.WHITE)

func _draw_play() -> void:
	var st: Dictionary = STAGES[stage]
	draw_rect(Rect2(Vector2.ZERO, VIEW), st.color)
	for s in stars:
		draw_circle(s.pos, 1.3 * float(s.z), Color(0.8,0.9,1,0.65))
	for i in range(0, 1400, 180):
		var x := fmod(float(i) - scroll_x * 0.25, 1400.0) - 80.0
		draw_circle(Vector2(x, 90 + (i % 5) * 95), 44, Color(0.35,0.18,0.55,0.20))
	for b in bullets:
		draw_circle(b.pos, 5 + b.tier * 1.5, Color(0.45,0.95,1.0))
	for b in enemy_bullets:
		draw_circle(b.pos, 6, Color(1.0,0.24,0.22))
	for p in powerups:
		draw_circle(p.pos, 15, Color(0.2,1.0,0.45))
		draw_arc(p.pos, 22, 0, TAU, 24, Color(0.9,1,0.3), 2)
	for e in enemies:
		if e.boss:
			_draw_boss(e)
		else:
			_draw_enemy(e)
	_draw_ship(ship, 1.0)
	for f in fx:
		var a: float = clamp(f.t, 0.0, 1.0)
		var col: Color = Color(1,0.55,0.12,a)
		if f.kind == "power": col = Color(0.25,1,0.45,a)
		if f.kind == "screen": col = Color(0.65,0.9,1,a*0.35)
		draw_circle(f.pos, 58 * a, col)
	_draw_hud()

func _draw_hud() -> void:
	_panel(Rect2(18, 18, 720, 70), Color(0.02,0.05,0.10,0.78))
	_text("Score %d   Lives %d   Bombs %d   Weapon %s   Stage %d/5" % [score, lives, bombs, TIER_NAMES[weapon_tier], stage + 1], Vector2(40, 50), 18, Color.WHITE)
	_text("Progress %d%%   Boss phase %d" % [int(stage_progress), boss_phase + 1], Vector2(40, 78), 15, Color(0.75,0.9,1.0))

func _draw_ship(pos: Vector2, scale: float) -> void:
	draw_colored_polygon([pos + Vector2(34,0)*scale, pos + Vector2(-26,-18)*scale, pos + Vector2(-16,0)*scale, pos + Vector2(-26,18)*scale], Color(0.42,0.88,1.0))
	draw_line(pos + Vector2(-32,-18)*scale, pos + Vector2(-52,-30)*scale, Color(1,0.55,0.15), 4*scale)
	draw_line(pos + Vector2(-32,18)*scale, pos + Vector2(-52,30)*scale, Color(1,0.55,0.15), 4*scale)

func _draw_enemy(e: Dictionary) -> void:
	var col: Color = Color(0.95,0.24,0.30)
	if e.kind == "sine drone": col = Color(0.95,0.65,0.18)
	if e.kind == "turret pod": col = Color(0.55,0.25,0.85)
	if e.kind == "splitter": col = Color(0.25,0.95,0.55)
	draw_colored_polygon([e.pos + Vector2(-24,0), e.pos + Vector2(18,-18), e.pos + Vector2(18,18)], col)
	_text(e.kind, e.pos + Vector2(-32,-26), 11, Color.WHITE)

func _draw_boss(e: Dictionary) -> void:
	var r := Rect2(e.pos.x - 95, e.pos.y - 78, 150, 156)
	_panel(r, Color(0.45,0.12,0.22))
	for i in range(3):
		draw_circle(e.pos + Vector2(-50, -45 + i * 45), 16, Color(1,0.72,0.16))
	_text("BOSS phase " + str(e.phase + 1), e.pos + Vector2(-88,-104), 16, Color.WHITE)

func _draw_panel_screen(title: String, body: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.01,0.015,0.04))
	for s in stars:
		draw_circle(s.pos, 1.4 * float(s.z), Color(0.75,0.85,1,0.6))
	_panel(Rect2(340, 130, 600, 420), Color(0.06,0.10,0.18))
	_text(title, Vector2(440, 195), 42, Color(0.62,0.92,1))
	var lines := body.split("\n")
	for i in range(lines.size()):
		_text(lines[i], Vector2(430, 260 + i * 42), 22, Color.WHITE)
	_text("Click to continue", Vector2(520, 510), 17, Color(0.74,0.82,0.92))

func _panel(r: Rect2, c: Color) -> void:
	draw_rect(r, c)
	draw_rect(r, Color(0.45,0.85,1.0), false, 2)

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_stage.json" <<'EOF'
{
  "duration_frames": 420,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 540},
    {"frame": 80, "type": "key_down", "keycode": "SPACE"},
    {"frame": 120, "type": "key_down", "keycode": "W"},
    {"frame": 170, "type": "key_up", "keycode": "W"},
    {"frame": 200, "type": "key_down", "keycode": "S"},
    {"frame": 250, "type": "key_up", "keycode": "S"},
    {"frame": 300, "type": "key_press", "keycode": "E"},
    {"frame": 390, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_power_chain.json" <<'EOF'
{
  "scenario": "power",
  "duration_frames": 460,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "D"},
    {"frame": 55, "type": "key_down", "keycode": "W"},
    {"frame": 105, "type": "key_up", "keycode": "W"},
    {"frame": 130, "type": "key_down", "keycode": "S"},
    {"frame": 175, "type": "key_up", "keycode": "S"},
    {"frame": 210, "type": "key_down", "keycode": "SPACE"},
    {"frame": 310, "type": "key_up", "keycode": "SPACE"},
    {"frame": 430, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_stage_variation.json" <<'EOF'
{
  "scenario": "stage2",
  "duration_frames": 420,
  "events": [
    {"frame": 30, "type": "key_down", "keycode": "SPACE"},
    {"frame": 80, "type": "key_down", "keycode": "S"},
    {"frame": 140, "type": "key_up", "keycode": "S"},
    {"frame": 180, "type": "key_down", "keycode": "W"},
    {"frame": 240, "type": "key_up", "keycode": "W"},
    {"frame": 330, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_boss.json" <<'EOF'
{
  "scenario": "boss",
  "duration_frames": 520,
  "events": [
    {"frame": 20, "type": "key_down", "keycode": "SPACE"},
    {"frame": 100, "type": "key_press", "keycode": "E"},
    {"frame": 150, "type": "key_down", "keycode": "W"},
    {"frame": 210, "type": "key_up", "keycode": "W"},
    {"frame": 260, "type": "key_down", "keycode": "S"},
    {"frame": 320, "type": "key_up", "keycode": "S"},
    {"frame": 490, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_continue_result.json" <<'EOF'
{
  "scenario": "continue",
  "duration_frames": 360,
  "events": [
    {"frame": 80, "type": "mouse_click", "button": "left", "x": 640, "y": 500},
    {"frame": 180, "type": "key_down", "keycode": "SPACE"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

echo "void-patrol oracle generated at $GAME"
