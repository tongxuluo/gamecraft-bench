#!/bin/bash
# Reference solution for gamecraft-bench/shooter-wave-commander.
#
# Compact wave-defense shooter oracle:
#   - Title/difficulty -> arena waves -> shop upgrades -> boss waves -> result.
#   - 360-degree movement/aiming, currency, upgrades, airstrike, shield/health.
#   - Enemy types/formations/boss phases are deterministic enough for demos.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="WaveCommander"
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
const ARENA := Rect2(95, 80, 1090, 560)
const ENEMY_TYPES := ["rusher", "gunner", "shield tank", "splitter", "support"]
const UPGRADE_NAMES := ["Fire Rate", "Damage", "Spread", "Shield Repair", "Mines", "Airstrike+"]

var scenario := ""
var mode := "title" # title, play, shop, result
var difficulty := 1
var wave := 1
var health := 100
var shield := 60
var currency := 0
var kills := 0
var highest_wave := 1
var upgrades_bought := 0
var airstrikes := 1
var damage := 1
var spread := false
var fire_rate := 0.22
var mines := 0
var player := Vector2(640, 360)
var aim := Vector2(850, 360)
var keys := {}
var fire_cd := 0.0
var wave_banner_t := 0.0
var airstrike_flash := 0.0
var shop_buttons := []
var bullets := []
var enemies := []
var enemy_bullets := []
var mine_list := []
var fx := []
var result_text := ""
var wave_spawned := false

func _ready() -> void:
	scenario = _scenario_arg()
	if scenario == "combat":
		_start_game()
	elif scenario == "shop":
		_start_game()
		wave = 2
		currency = 180
		_enter_shop()
	elif scenario == "boss":
		_start_game()
		wave = 5
		_spawn_wave()
	elif scenario == "result":
		wave = 12
		kills = 58
		upgrades_bought = 7
		_show_result()
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
		if event.pressed and event.keycode == KEY_E and mode == "play":
			_airstrike()
		if event.pressed and event.keycode == KEY_Q and mode == "play" and mines > 0:
			mines -= 1
			mine_list.append({"pos":player, "t":18.0})
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		aim = event.position
		if mode == "title":
			if Rect2(470, 430, 340, 55).has_point(event.position):
				difficulty = 1
				_start_game()
			elif Rect2(470, 500, 340, 55).has_point(event.position):
				difficulty = 2
				_start_game()
		elif mode == "play":
			_fire()
		elif mode == "shop":
			_handle_shop_click(event.position)
		elif mode == "result":
			mode = "title"

func _start_game() -> void:
	mode = "play"
	wave = 1
	health = 100
	shield = 60
	currency = 80
	kills = 0
	upgrades_bought = 0
	airstrikes = 1
	damage = 1
	spread = false
	fire_rate = 0.22
	mines = 0
	player = Vector2(640, 360)
	enemies.clear()
	bullets.clear()
	enemy_bullets.clear()
	mine_list.clear()
	fx.clear()
	_spawn_wave()

func _process(delta: float) -> void:
	if mode == "play":
		_update_play(delta)
	elif mode == "shop":
		pass
	_update_fx(delta)
	queue_redraw()

func _update_play(delta: float) -> void:
	if wave_banner_t > 0:
		wave_banner_t -= delta
	if airstrike_flash > 0:
		airstrike_flash -= delta
	var mv := Vector2.ZERO
	if _down(KEY_W) or _down(KEY_UP): mv.y -= 1
	if _down(KEY_S) or _down(KEY_DOWN): mv.y += 1
	if _down(KEY_A) or _down(KEY_LEFT): mv.x -= 1
	if _down(KEY_D) or _down(KEY_RIGHT): mv.x += 1
	if mv.length() > 0:
		player += mv.normalized() * 235.0 * delta
	player.x = clamp(player.x, ARENA.position.x + 20, ARENA.end.x - 20)
	player.y = clamp(player.y, ARENA.position.y + 20, ARENA.end.y - 20)
	if _down(KEY_SPACE):
		_fire()
	if fire_cd > 0:
		fire_cd -= delta
	_update_bullets(delta)
	_update_enemies(delta)
	_update_mines(delta)
	if enemies.is_empty():
		if wave >= 20:
			_show_result()
		else:
			currency += 50 + wave * 12
			_enter_shop()

func _down(k: int) -> bool:
	return bool(keys.get(k, false))

func _spawn_wave() -> void:
	mode = "play"
	highest_wave = max(highest_wave, wave)
	wave_banner_t = 1.6
	enemies.clear()
	enemy_bullets.clear()
	var count := 4 + wave
	if wave % 5 == 0:
		enemies.append({"kind":"boss", "pos":Vector2(640, 150), "hp":24 + wave, "phase":0, "t":0.0, "boss":true, "shield":0})
		for i in range(4):
			enemies.append(_enemy("support", Vector2(330 + i * 205, 220)))
		return
	for i in range(count):
		var kind: String = ENEMY_TYPES[(i + wave) % ENEMY_TYPES.size()]
		var pos: Vector2 = Vector2.ZERO
		match wave % 4:
			0: pos = Vector2(ARENA.position.x + 20, ARENA.position.y + 80 + i * 42)
			1: pos = Vector2(ARENA.end.x - 20, ARENA.position.y + 80 + i * 42)
			2: pos = Vector2(ARENA.position.x + 120 + i * 70, ARENA.position.y + 20)
			_: pos = Vector2(ARENA.position.x + 120 + i * 70, ARENA.end.y - 20)
		enemies.append(_enemy(kind, pos))

func _enemy(kind: String, pos: Vector2) -> Dictionary:
	var hp := 2
	var shield_val := 0
	if kind == "shield tank":
		hp = 6
		shield_val = 3
	if kind == "support":
		hp = 3
	return {"kind":kind, "pos":pos, "hp":hp, "shield":shield_val, "t":0.0, "boss":false, "phase":0}

func _enter_shop() -> void:
	mode = "shop"
	shop_buttons = []
	for i in range(UPGRADE_NAMES.size()):
		shop_buttons.append(Rect2(180 + (i % 3) * 310, 230 + int(i / 3) * 115, 260, 70))

func _handle_shop_click(pos: Vector2) -> void:
	for i in range(shop_buttons.size()):
		var r: Rect2 = shop_buttons[i]
		if r.has_point(pos) and currency >= 60:
			currency -= 60
			upgrades_bought += 1
			match i:
				0: fire_rate = max(0.08, fire_rate - 0.04)
				1: damage += 1
				2: spread = true
				3: shield = min(100, shield + 35)
				4: mines += 2
				5: airstrikes += 1
			fx.append({"pos":r.get_center(), "t":0.5, "kind":"upgrade"})
			return
	if Rect2(980, 600, 170, 52).has_point(pos):
		wave += 1
		_spawn_wave()

func _fire() -> void:
	if fire_cd > 0:
		return
	var dir: Vector2 = (aim - player).normalized()
	var base := atan2(dir.y, dir.x)
	var angles := [base]
	if spread:
		angles = [base - 0.20, base, base + 0.20]
	for a in angles:
		bullets.append({"pos":player + Vector2(cos(a), sin(a)) * 25.0, "vel":Vector2(cos(a), sin(a)) * 520.0, "t":1.5})
	fire_cd = fire_rate
	fx.append({"pos":player + dir * 30, "t":0.12, "kind":"muzzle"})

func _airstrike() -> void:
	if airstrikes <= 0:
		return
	airstrikes -= 1
	airstrike_flash = 0.45
	for e in enemies:
		e.hp -= 8
		fx.append({"pos":e.pos, "t":0.8, "kind":"air"})
	enemies = enemies.filter(func(e): return e.hp > 0)
	currency += 25

func _update_bullets(delta: float) -> void:
	for b in bullets:
		b.pos += b.vel * delta
		b.t -= delta
	for b in enemy_bullets:
		b.pos += b.vel * delta
		b.t -= delta
		if b.pos.distance_to(player) < 18:
			b.t = 0
			_take_damage(8)
	for b in bullets:
		for e in enemies:
			var rad := 54.0 if e.boss else 24.0
			if b.pos.distance_to(e.pos) < rad:
				b.t = 0
				if e.shield > 0:
					e.shield -= damage
					fx.append({"pos":b.pos, "t":0.25, "kind":"shield"})
				else:
					e.hp -= damage
					fx.append({"pos":b.pos, "t":0.35, "kind":"hit"})
				if e.hp <= 0:
					kills += 1
					currency += 12
					fx.append({"pos":e.pos, "t":0.65, "kind":"boom"})
					if e.kind == "splitter":
						enemies.append(_enemy("rusher", e.pos + Vector2(18, -18)))
						enemies.append(_enemy("rusher", e.pos + Vector2(18, 18)))
				break
	enemies = enemies.filter(func(e): return e.hp > 0)
	bullets = bullets.filter(func(b): return b.t > 0 and ARENA.grow(80).has_point(b.pos))
	enemy_bullets = enemy_bullets.filter(func(b): return b.t > 0 and ARENA.grow(80).has_point(b.pos))

func _update_enemies(delta: float) -> void:
	for e in enemies:
		e.t += delta
		if e.boss:
			e.phase = 0 if e.hp > 18 else (1 if e.hp > 9 else 2)
			e.pos.x = 640 + sin(e.t * 0.8) * 220
			if int(e.t * (1.3 + e.phase)) != int((e.t - delta) * (1.3 + e.phase)):
				for i in range(6 + e.phase * 2):
					var a: float = i * TAU / float(6 + e.phase * 2)
					enemy_bullets.append({"pos":e.pos, "vel":Vector2(cos(a), sin(a)) * 135.0, "t":4.0})
		else:
			var dir: Vector2 = (player - e.pos).normalized()
			match e.kind:
				"rusher":
					e.pos += dir * 125.0 * delta
				"gunner":
					e.pos += dir * 50.0 * delta
				"shield tank":
					e.pos += dir * 42.0 * delta
				"splitter":
					e.pos += dir.rotated(sin(e.t) * 0.7) * 85.0 * delta
				"support":
					e.pos += dir * 62.0 * delta
			if e.kind in ["gunner", "support"] and int(e.t * 1.2) != int((e.t - delta) * 1.2):
				enemy_bullets.append({"pos":e.pos, "vel":dir * 150.0, "t":3.2})
		if e.pos.distance_to(player) < 24:
			_take_damage(10)
			e.pos -= (player - e.pos).normalized() * 30

func _update_mines(delta: float) -> void:
	for m in mine_list:
		m.t -= delta
		for e in enemies:
			if e.pos.distance_to(m.pos) < 52:
				m.t = 0
				e.hp -= 5
				fx.append({"pos":m.pos, "t":0.6, "kind":"boom"})
	for e in enemies:
		if e.hp <= 0:
			kills += 1
	mine_list = mine_list.filter(func(m): return m.t > 0)
	enemies = enemies.filter(func(e): return e.hp > 0)

func _take_damage(amount: int) -> void:
	if shield > 0:
		shield -= amount
	else:
		health -= amount
	fx.append({"pos":player, "t":0.35, "kind":"damage"})
	if health <= 0:
		_show_result()

func _show_result() -> void:
	mode = "result"
	result_text = "RESULTS\nWaves survived: %d\nEnemies destroyed: %d\nUpgrades purchased: %d\nHighest wave reached: %d" % [wave, kills, upgrades_bought, highest_wave]

func _update_fx(delta: float) -> void:
	for f in fx:
		f.t -= delta
	fx = fx.filter(func(f): return f.t > 0)

func _draw() -> void:
	if mode == "play":
		_draw_play()
	elif mode == "shop":
		_draw_shop()
	elif mode == "result":
		_draw_result()
	else:
		_draw_title()

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.09,0.10,0.08))
	_panel(Rect2(90, 80, 1100, 560), Color(0.12,0.16,0.12))
	_text("WAVE COMMANDER", Vector2(390, 180), 54, Color(0.86,0.92,0.55))
	_text("hold the line / buy upgrades / call airstrikes", Vector2(410, 245), 22, Color(0.82,0.86,0.74))
	_draw_soldier(Vector2(640, 340), 2.2, Color(0.45,0.72,0.38))
	_panel(Rect2(470, 430, 340, 55), Color(0.20,0.32,0.18))
	_text("NORMAL DIFFICULTY", Vector2(525, 465), 22, Color.WHITE)
	_panel(Rect2(470, 500, 340, 55), Color(0.34,0.18,0.14))
	_text("HARD DIFFICULTY", Vector2(548, 535), 22, Color.WHITE)

func _draw_play() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08,0.10,0.08))
	_panel(ARENA, Color(0.15,0.18,0.12))
	for i in range(8):
		draw_line(Vector2(ARENA.position.x + i * 150, ARENA.position.y), Vector2(ARENA.position.x + i * 150, ARENA.end.y), Color(0.22,0.25,0.18), 1)
	for m in mine_list:
		draw_circle(m.pos, 12, Color(0.95,0.82,0.22))
	for b in bullets:
		draw_circle(b.pos, 5, Color(1,0.90,0.30))
	for b in enemy_bullets:
		draw_circle(b.pos, 5, Color(1,0.20,0.16))
	for e in enemies:
		if e.boss:
			_draw_boss(e)
		else:
			_draw_enemy(e)
	_draw_soldier(player, 1.0, Color(0.48,0.78,0.38))
	for f in fx:
		var a: float = clamp(f.t, 0.0, 1.0)
		var col: Color = Color(1,0.55,0.1,a)
		if f.kind == "air": col = Color(0.8,0.95,1,a)
		if f.kind == "damage": col = Color(1,0.1,0.1,a)
		if f.kind == "shield": col = Color(0.25,0.75,1,a)
		draw_circle(f.pos, 50 * a, col)
	if airstrike_flash > 0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.72,0.88,1.0, airstrike_flash))
	_draw_hud()
	if wave_banner_t > 0:
		_text("WAVE " + str(wave) + " INCOMING", Vector2(505, 148), 34, Color(1,0.92,0.35))

func _draw_shop() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.07,0.09,0.07))
	_panel(Rect2(100, 90, 1080, 560), Color(0.13,0.16,0.12))
	_text("FIELD SHOP - Currency $" + str(currency), Vector2(150, 155), 34, Color(0.88,0.92,0.55))
	for i in range(shop_buttons.size()):
		var r: Rect2 = shop_buttons[i]
		_panel(r, Color(0.18,0.22,0.16))
		_text(UPGRADE_NAMES[i], r.position + Vector2(18, 32), 20, Color.WHITE)
		_text("$60", r.position + Vector2(18, 58), 15, Color(0.9,0.86,0.45))
	_panel(Rect2(980, 600, 170, 52), Color(0.24,0.34,0.18))
	_text("NEXT WAVE", Vector2(1012, 633), 20, Color.WHITE)
	_text("Current: fire %.2f  dmg %d  spread %s  shield %d  mines %d  air %d" % [fire_rate, damage, str(spread), shield, mines, airstrikes], Vector2(150, 570), 16, Color(0.82,0.88,0.78))

func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.06,0.07,0.06))
	_panel(Rect2(350, 130, 580, 430), Color(0.12,0.15,0.12))
	_text("AFTER ACTION REPORT", Vector2(430, 195), 34, Color(0.9,0.88,0.48))
	var lines := result_text.split("\n")
	for i in range(lines.size()):
		_text(lines[i], Vector2(430, 260 + i * 44), 22, Color.WHITE)
	_text("Click to return to title", Vector2(515, 515), 17, Color(0.78,0.82,0.72))

func _draw_hud() -> void:
	_panel(Rect2(18, 18, 820, 66), Color(0.03,0.05,0.03,0.78))
	_text("HP %d  Shield %d  Wave %d  Enemies %d  $%d  Airstrikes %d" % [health, shield, wave, enemies.size(), currency, airstrikes], Vector2(38, 51), 18, Color.WHITE)
	_text("Damage %d  Fire %.2f  Spread %s  Mines %d" % [damage, fire_rate, str(spread), mines], Vector2(38, 78), 14, Color(0.80,0.88,0.74))

func _draw_soldier(pos: Vector2, scale: float, col: Color) -> void:
	draw_circle(pos, 18 * scale, col)
	var dir: Vector2 = (aim - pos).normalized()
	if dir.length() == 0:
		dir = Vector2.RIGHT
	draw_line(pos, pos + dir * 34 * scale, Color(0.1,0.12,0.08), 7 * scale)
	draw_circle(pos + dir * 36 * scale, 5 * scale, Color(0.95,0.86,0.35))

func _draw_enemy(e: Dictionary) -> void:
	var col: Color = Color(0.75,0.18,0.14)
	if e.kind == "gunner": col = Color(0.85,0.45,0.16)
	if e.kind == "shield tank": col = Color(0.30,0.45,0.75)
	if e.kind == "splitter": col = Color(0.65,0.22,0.72)
	if e.kind == "support": col = Color(0.28,0.70,0.42)
	draw_rect(Rect2(e.pos - Vector2(16,16), Vector2(32,32)), col)
	if e.shield > 0:
		draw_circle(e.pos, 25, Color(0.25,0.75,1,0.28))
	_text(e.kind, e.pos + Vector2(-35,-24), 11, Color.WHITE)

func _draw_boss(e: Dictionary) -> void:
	var r := Rect2(e.pos.x - 78, e.pos.y - 48, 156, 96)
	_panel(r, Color(0.48,0.14,0.10))
	draw_circle(e.pos + Vector2(-45,0), 18, Color(0.9,0.8,0.25))
	draw_circle(e.pos + Vector2(45,0), 18, Color(0.9,0.8,0.25))
	_text("BOSS phase " + str(e.phase + 1), e.pos + Vector2(-58,-66), 15, Color.WHITE)

func _panel(r: Rect2, c: Color) -> void:
	draw_rect(r, c)
	draw_rect(r, Color(0.64,0.72,0.45), false, 2)

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
	draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_wave.json" <<'EOF'
{
  "duration_frames": 420,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 455},
    {"frame": 70, "type": "mouse_move", "x": 900, "y": 350},
    {"frame": 80, "type": "key_down", "keycode": "SPACE"},
    {"frame": 130, "type": "key_down", "keycode": "D"},
    {"frame": 180, "type": "key_up", "keycode": "D"},
    {"frame": 240, "type": "key_press", "keycode": "E"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_shop_upgrades.json" <<'EOF'
{
  "scenario": "shop",
  "duration_frames": 460,
  "events": [
    {"frame": 40, "type": "mouse_click", "button": "left", "x": 300, "y": 260},
    {"frame": 90, "type": "mouse_click", "button": "left", "x": 610, "y": 260},
    {"frame": 140, "type": "mouse_click", "button": "left", "x": 920, "y": 260},
    {"frame": 210, "type": "mouse_click", "button": "left", "x": 1060, "y": 626},
    {"frame": 280, "type": "key_down", "keycode": "SPACE"},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_boss_wave.json" <<'EOF'
{
  "scenario": "boss",
  "duration_frames": 520,
  "events": [
    {"frame": 20, "type": "mouse_move", "x": 640, "y": 150},
    {"frame": 40, "type": "key_down", "keycode": "SPACE"},
    {"frame": 110, "type": "key_press", "keycode": "E"},
    {"frame": 180, "type": "key_down", "keycode": "A"},
    {"frame": 235, "type": "key_up", "keycode": "A"},
    {"frame": 300, "type": "key_down", "keycode": "D"},
    {"frame": 360, "type": "key_up", "keycode": "D"},
    {"frame": 500, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_mines_damage.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 440,
  "events": [
    {"frame": 30, "type": "key_press", "keycode": "Q"},
    {"frame": 60, "type": "mouse_move", "x": 1000, "y": 360},
    {"frame": 70, "type": "key_down", "keycode": "SPACE"},
    {"frame": 160, "type": "key_down", "keycode": "W"},
    {"frame": 230, "type": "key_up", "keycode": "W"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_results.json" <<'EOF'
{
  "scenario": "result",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 240, "type": "wait"}
  ]
}
EOF

echo "wave-commander oracle generated at $GAME"
