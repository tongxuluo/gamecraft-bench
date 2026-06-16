#!/bin/bash
# Reference solution for gamecraft-bench/openworld-sky-islands.
#
# A compact 2D sky-island gliding exploration game:
#   - Title -> sky map of floating islands. WASD move, SPACE jump/glide.
#   - Gliding uses stamina (bar depletes while airborne, recharges on ground).
#   - Islands have mini-dungeons (platforming + enemies + wind crystal reward).
#   - Boss guardians on larger islands with attack patterns to dodge.
#   - Wind crystals = currency: spend to unlock abilities (dash, double-jump).
#   - Multiple island clusters with distinct themes (forest/crystal/volcanic).
#   - HUD: stamina, crystals, abilities. Result on defeating all bosses.
#   - Scenarios jump to glide / dungeon / boss for deterministic demos.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="SkyIslands"
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
const PR := 12.0
const GRAVITY := 400.0
const GLIDE_GRAV := 80.0
const JUMP_VEL := -280.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 30.0
const STAMINA_REGEN := 50.0

const ISLANDS := [
    {"name": "Forest Isle", "pos": Vector2(200, 500), "col": Color(0.3, 0.6, 0.3), "boss": false, "dungeon": true, "cleared": false},
    {"name": "Crystal Peak", "pos": Vector2(640, 400), "col": Color(0.5, 0.6, 0.9), "boss": true, "dungeon": true, "cleared": false},
    {"name": "Volcanic Rim", "pos": Vector2(1050, 480), "col": Color(0.7, 0.4, 0.3), "boss": true, "dungeon": true, "cleared": false},
]

var scenario := ""
var mode := "title"          # title, sky, dungeon, boss, result
var ppos := Vector2(200, 460)
var pvel := Vector2.ZERO
var grounded := true
var gliding := false
var stamina := MAX_STAMINA
var crystals := 0
var has_dash := false
var has_double := false
var has_updraft := false
var cur_island := 0
var boss_hp := 0
var boss_pos := Vector2(800, 300)
var boss_t := 0.0
var enemies: Array = []
var won := false
var anim := 0.0
var msg := ""
var move := {"left": false, "right": false}
var islands: Array = []

func _ready() -> void:
    _parse_args()
    if scenario != "":
        _load_scenario(scenario)
    queue_redraw()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]; i += 2
        else: i += 1

func _load_scenario(id: String) -> void:
    if id == "title_flow": mode = "title"
    elif id == "glide": _start(); ppos = Vector2(400, 200); pvel = Vector2(100, -50); grounded = false; gliding = true
    elif id == "dungeon": _start(); mode = "dungeon"; _setup_dungeon(0)
    elif id == "boss": _start(); mode = "boss"; _setup_boss(1)
    elif id == "near_win": _start(); islands[0]["cleared"] = true; islands[1]["cleared"] = true; mode = "boss"; _setup_boss(2)
    elif id == "unlock": _start(); crystals = 12; mode = "sky"; ppos = Vector2(640, 360)
    else: _start()

func _start() -> void:
    mode = "sky"; ppos = Vector2(200, 460); pvel = Vector2.ZERO
    grounded = true; gliding = false; stamina = MAX_STAMINA
    crystals = 0; has_dash = false; has_double = false; has_updraft = false; won = false
    islands = []
    for isl in ISLANDS:
        islands.append({"name": isl["name"], "pos": isl["pos"], "col": isl["col"],
                        "boss": isl["boss"], "dungeon": isl["dungeon"], "cleared": false})
    msg = "Glide between islands. SPACE jump/glide. Enter dungeons near islands."

func _setup_dungeon(idx: int) -> void:
    cur_island = idx
    ppos = Vector2(350, 400)
    enemies = []
    for i in range(3):
        enemies.append({"pos": Vector2(420 + float(i) * 140, 400), "hp": 3})
    msg = "Dungeon! Defeat enemies to earn a wind crystal."

func _setup_boss(idx: int) -> void:
    cur_island = idx
    boss_hp = 20
    boss_pos = Vector2(800, 250)
    ppos = Vector2(760, 250)
    boss_t = 0.0
    msg = "BOSS GUARDIAN! Dodge and attack."

func _physics_process(delta: float) -> void:
    anim += delta
    if mode == "sky":
        _sky_physics(delta)
    elif mode == "dungeon":
        _dungeon_physics(delta)
    elif mode == "boss":
        _boss_physics(delta)
    queue_redraw()

func _sky_physics(delta: float) -> void:
    var dir := 0.0
    if move["left"]: dir -= 1.0
    if move["right"]: dir += 1.0
    pvel.x = move_toward(pvel.x, dir * 200.0, 600.0 * delta)
    if gliding and stamina > 0:
        pvel.y += GLIDE_GRAV * delta
        stamina = max(0.0, stamina - STAMINA_DRAIN * delta)
        if stamina <= 0: gliding = false
    else:
        pvel.y += GRAVITY * delta
    ppos += pvel * delta
    for up in [Vector2(460, 360), Vector2(860, 330)]:
        var up_pos: Vector2 = up
        if ppos.distance_to(up_pos) < 70.0:
            pvel.y = min(pvel.y, -180.0)
            msg = "Updraft boost!"
    # ground check (islands as platforms)
    grounded = false
    for isl in islands:
        var ip: Vector2 = isl["pos"]
        if ppos.x > ip.x - 80 and ppos.x < ip.x + 80 and ppos.y >= ip.y - 20 and ppos.y <= ip.y + 10 and pvel.y >= 0:
            ppos.y = ip.y - 20
            pvel.y = 0
            grounded = true
            gliding = false
            stamina = min(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
    ppos.x = clampf(ppos.x, 40, VIEW.x - 40)
    if ppos.y > VIEW.y + 100:
        ppos = Vector2(200, 460); pvel = Vector2.ZERO; grounded = true; stamina = MAX_STAMINA
        msg = "Fell! Back to start."

func _dungeon_physics(delta: float) -> void:
    var dir := 0.0
    if move["left"]: dir -= 1.0
    if move["right"]: dir += 1.0
    ppos.x += dir * 200.0 * delta
    ppos.x = clampf(ppos.x, 100, VIEW.x - 100)
    # simple enemy contact = damage them
    for e in enemies:
        if ppos.distance_to(e["pos"]) < 40.0:
            e["hp"] = int(e["hp"]) - 1
            e["pos"] += (e["pos"] - ppos).normalized() * 60.0
    var alive: Array = []
    for e in enemies:
        if int(e["hp"]) > 0: alive.append(e)
    enemies = alive
    if enemies.size() == 0:
        crystals += 3
        islands[cur_island]["cleared"] = true
        mode = "sky"
        msg = "Dungeon cleared! +3 crystals."

func _boss_physics(delta: float) -> void:
    boss_t += delta
    boss_pos.x = 640 + sin(boss_t * 2.0) * 300.0
    # boss shoots at player periodically (simplified: contact damage)
    if ppos.distance_to(boss_pos) < 50.0:
        ppos += (ppos - boss_pos).normalized() * 80.0
    # player attacks boss on contact
    var dir := 0.0
    if move["left"]: dir -= 1.0
    if move["right"]: dir += 1.0
    ppos.x += dir * 220.0 * delta
    ppos.x = clampf(ppos.x, 100, VIEW.x - 100)
    if ppos.distance_to(boss_pos) < 60.0:
        boss_hp -= 1
    if boss_hp <= 0:
        islands[cur_island]["cleared"] = true
        crystals += 5
        msg = "Boss defeated! +5 crystals."
        if _all_cleared(): _finish(true)
        else: mode = "sky"

func _all_cleared() -> bool:
    for isl in islands:
        if not isl["cleared"]: return false
    return true

func _jump() -> void:
    if mode == "sky":
        if grounded:
            pvel.y = JUMP_VEL; grounded = false
        elif not gliding and stamina > 10:
            gliding = true
    elif mode == "dungeon" or mode == "boss":
        ppos.y -= 40  # simple jump in dungeon

func _enter_dungeon() -> void:
    if mode != "sky": return
    for i in range(islands.size()):
        var isl: Dictionary = islands[i]
        if isl["cleared"]: continue
        if ppos.distance_to(isl["pos"]) < 100.0:
            if isl["boss"]:
                mode = "boss"; _setup_boss(i)
            else:
                mode = "dungeon"; _setup_dungeon(i)
            return
    msg = "No dungeon nearby (or already cleared)."
    queue_redraw()

func _buy_ability() -> void:
    if mode != "sky": return
    if not has_dash and crystals >= 5:
        has_dash = true; crystals -= 5; msg = "Unlocked Dash!"
    elif not has_double and crystals >= 8:
        has_double = true; crystals -= 8; msg = "Unlocked Double Jump!"
    elif not has_updraft and crystals >= 10:
        has_updraft = true; crystals -= 10; msg = "Unlocked Updraft Creation!"
    else:
        msg = "Need more crystals for next ability."
    queue_redraw()

func _finish(victory: bool) -> void:
    won = victory; mode = "result"; queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.15, 0.2, 0.35))
    match mode:
        "title": _draw_title()
        "sky": _draw_sky()
        "dungeon": _draw_dungeon()
        "boss": _draw_boss()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
func _panel(r: Rect2, c := Color(0.06, 0.08, 0.14, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.4, 0.6, 0.9, 0.9), false, 2.0)
func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.10, 0.14, 0.24)); draw_rect(r, Color(0.5, 0.7, 0.95), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.88, 0.92, 0.98))

func _draw_title() -> void:
    for i in range(5):
        draw_circle(Vector2(220 + i * 210, 200 + 35 * sin(anim + i)), 42, Color(0.45, 0.62, 0.86, 0.45))
        draw_rect(Rect2(Vector2(170 + i * 210, 335 + 20 * sin(anim + i)), Vector2(110, 24)), Color(0.35 + i * 0.08, 0.55, 0.38 + i * 0.05))
    _panel(Rect2(330, 150, 620, 340))
    _text("SKY ISLANDS", Vector2(450, 250), 52, Color(0.5, 0.7, 0.95))
    _text("Glide between islands. Conquer dungeons. Defeat guardians.", Vector2(365, 312), 18, Color(0.8, 0.88, 0.95))
    _button(Rect2(500, 410, 280, 64), "TAKE FLIGHT")

func _draw_sky() -> void:
    # clouds
    for i in range(8):
        draw_circle(Vector2(fmod(float(i) * 180 + anim * 10, 1400) - 60, 100 + float(i % 3) * 80), 30, Color(0.3, 0.35, 0.5, 0.4))
    for up in [Vector2(460, 360), Vector2(860, 330)]:
        var up_pos: Vector2 = up
        for j in range(6):
            var y: float = up_pos.y + 80.0 - fmod(anim * 90.0 + float(j) * 28.0, 160.0)
            draw_line(Vector2(up_pos.x - 22.0 + float(j) * 8.0, y + 28.0), Vector2(up_pos.x + 18.0 - float(j) * 5.0, y - 24.0), Color(0.70, 0.95, 1.0, 0.45), 3.0)
        _text("updraft", up_pos + Vector2(-35, 95), 12, Color(0.78, 0.94, 1.0))
    # islands
    for isl in islands:
        var col: Color = isl["col"]
        if isl["cleared"]: col = col.darkened(0.3)
        draw_circle(isl["pos"] + Vector2(-40, 0), 38, col.lightened(0.05))
        draw_circle(isl["pos"] + Vector2(28, -4), 42, col)
        for k in range(3):
            draw_circle(isl["pos"] + Vector2(-42 + k * 36, -22 - 5 * sin(anim + k)), 13, col.lightened(0.22))
        draw_polygon([isl["pos"] + Vector2(-85, 18), isl["pos"] + Vector2(86, 18), isl["pos"] + Vector2(25, 72), isl["pos"] + Vector2(-35, 66)], [col.darkened(0.28)])
        _text(str(isl["name"]), isl["pos"] + Vector2(-40, 30), 13, Color(0.85, 0.9, 0.95))
        if isl["cleared"]: _text("✓", isl["pos"] + Vector2(-6, -4), 18, Color(0.5, 0.95, 0.5))
    # player
    var pc := Color(0.5, 0.9, 1.0) if not gliding else Color(0.8, 0.95, 1.0)
    draw_circle(ppos, PR, pc)
    if gliding:
        draw_line(ppos + Vector2(-24, 0), ppos + Vector2(24, 0), Color(1, 1, 1, 0.7), 4.0)
        draw_line(ppos + Vector2(-8, 8), ppos + Vector2(-28, 18), Color(0.8, 0.95, 1.0, 0.65), 3.0)
        draw_line(ppos + Vector2(8, 8), ppos + Vector2(28, 18), Color(0.8, 0.95, 1.0, 0.65), 3.0)
        draw_line(ppos + Vector2(0, 16), ppos + Vector2(-40, 48), Color(0.7, 0.9, 1.0, 0.18), 3.0)
        draw_line(ppos + Vector2(0, 16), ppos + Vector2(40, 48), Color(0.7, 0.9, 1.0, 0.18), 3.0)
    _draw_hud()

func _draw_dungeon() -> void:
    draw_rect(Rect2(80, 200, 1120, 400), Color(0.12, 0.10, 0.16))
    for i in range(5):
        draw_rect(Rect2(180 + i * 180, 520 - (i % 2) * 70, 120, 18), Color(0.26, 0.22, 0.36))
    for i in range(4):
        var x := 260 + i * 220
        draw_polygon([Vector2(x, 520), Vector2(x + 18, 470), Vector2(x + 36, 520)], [Color(0.95, 0.35, 0.25)])
    for e in enemies:
        draw_circle(e["pos"], 18, Color(0.9, 0.4, 0.4))
        draw_rect(Rect2(e["pos"] + Vector2(-18, -30), Vector2(36 * float(e["hp"]) / 3.0, 5)), Color(0.9, 0.25, 0.25))
    draw_circle(ppos, PR, Color(0.5, 0.9, 1.0))
    draw_circle(Vector2(1030, 402), 18 + 3 * sin(anim * 5), Color(0.55, 0.95, 1.0))
    _text("DUNGEON — defeat enemies", Vector2(400, 180), 22, Color(0.8, 0.85, 0.95))
    _draw_hud()

func _draw_boss() -> void:
    draw_rect(Rect2(80, 100, 1120, 520), Color(0.14, 0.08, 0.12))
    for i in range(5):
        var a: float = boss_t * 2.0 + float(i) * TAU / 5.0
        draw_circle(boss_pos + Vector2(cos(a), sin(a)) * 76, 10, Color(1.0, 0.45, 0.25, 0.75))
    draw_circle(boss_pos, 36, Color(0.95, 0.4, 0.6))
    var bar_w := 200.0 * (float(boss_hp) / 20.0)
    draw_rect(Rect2(boss_pos.x - 100, boss_pos.y - 50, bar_w, 10), Color(0.95, 0.3, 0.5))
    draw_circle(ppos, PR, Color(0.5, 0.9, 1.0))
    _text("BOSS GUARDIAN", Vector2(540, 90), 26, Color(0.95, 0.5, 0.7))
    _draw_hud()

func _draw_hud() -> void:
    _panel(Rect2(0, 0, 1280, 56))
    _text("Stamina", Vector2(24, 38), 18, Color(0.7, 0.9, 1.0))
    draw_rect(Rect2(110, 22, 160, 16), Color(0.1, 0.1, 0.15))
    draw_rect(Rect2(110, 22, 160 * (stamina / MAX_STAMINA), 16), Color(0.4, 0.8, 1.0))
    _text("Crystals %d" % crystals, Vector2(300, 38), 20, Color(0.9, 0.85, 0.4))
    var ab := ""
    if has_dash: ab += "Dash "
    if has_double: ab += "DblJump"
    if has_updraft: ab += "Updraft"
    _text("Abilities: %s" % (ab if ab != "" else "none"), Vector2(480, 38), 16, Color(0.7, 0.85, 0.95))
    var cleared := 0
    for isl in islands:
        if isl["cleared"]: cleared += 1
    _text("Cleared %d/%d" % [cleared, islands.size()], Vector2(750, 38), 20, Color(0.8, 0.9, 0.7))
    _text(msg, Vector2(40, 700), 16, Color(0.8, 0.88, 0.95))

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    _text("ALL GUARDIANS DEFEATED!", Vector2(360, 260), 38, Color(0.5, 0.9, 0.7))
    _text("Crystals collected: %d" % crystals, Vector2(440, 320), 22, Color(0.9, 0.85, 0.5))
    _button(Rect2(500, 420, 280, 54), "TITLE")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_SPACE: if p and not event.echo: _jump()
            KEY_E: if p and not event.echo: _enter_dungeon()
            KEY_U: if p: _buy_ability()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position): _start(); queue_redraw()
        elif mode == "result":
            if Rect2(500, 420, 280, 54).has_point(event.position): mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_glide.json" <<'EOF'
{"duration_frames":460,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":442},{"frame":80,"type":"key_press","keycode":"SPACE"},{"frame":120,"type":"key_down","keycode":"D"},{"frame":250,"type":"key_up","keycode":"D"},{"frame":300,"type":"key_press","keycode":"SPACE"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_dungeon.json" <<'EOF'
{"scenario":"dungeon","duration_frames":460,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":170,"type":"key_up","keycode":"D"},{"frame":190,"type":"key_down","keycode":"D"},{"frame":340,"type":"key_up","keycode":"D"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_boss.json" <<'EOF'
{"scenario":"boss","duration_frames":460,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":100,"type":"key_up","keycode":"D"},{"frame":130,"type":"key_down","keycode":"A"},{"frame":220,"type":"key_up","keycode":"A"},{"frame":250,"type":"key_down","keycode":"D"},{"frame":360,"type":"key_up","keycode":"D"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_glide.json" <<'EOF'
{"scenario":"glide","duration_frames":400,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":200,"type":"key_up","keycode":"D"},{"frame":240,"type":"key_press","keycode":"SPACE"},{"frame":380,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/05_win.json" <<'EOF'
{"scenario":"near_win","duration_frames":460,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":130,"type":"key_up","keycode":"D"},{"frame":160,"type":"key_down","keycode":"A"},{"frame":260,"type":"key_up","keycode":"A"},{"frame":300,"type":"key_down","keycode":"D"},{"frame":420,"type":"key_up","keycode":"D"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/06_unlock.json" <<'EOF'
{"scenario":"unlock","duration_frames":360,"events":[{"frame":40,"type":"key_press","keycode":"U"},{"frame":120,"type":"key_press","keycode":"U"},{"frame":200,"type":"key_press","keycode":"U"},{"frame":340,"type":"wait"}]}
EOF

echo "sky-islands oracle generated at $GAME"
