#!/bin/bash
# Reference solution for gamecraft-bench/openworld-necromancer.
#
# A compact 2D necromancer open-world game:
#   - Title -> dark world map. WASD move player. Click to attack (dark bolt).
#   - Kill enemies -> corpses remain -> press E near corpse to raise as minion.
#   - Army panel shows minion count/types/HP/capacity. Minions auto-follow+fight.
#   - Conquer territory: clear defenders at a location, claim it (flag changes).
#   - Infamy meter rises from kills/conquests; hero hunters spawn at high infamy.
#   - Multiple regions (village/graveyard/forest/ruins) with different enemies.
#   - Result on conquering all or player death.
#   - Scenarios jump to combat / raise / conquer / hunters for deterministic demos.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Necromancer"
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
const PR := 14.0
const MAX_HP := 12
const MAX_MINIONS := 6
const REGIONS := [
    {"name": "Village", "pos": Vector2(300, 300), "col": Color(0.5, 0.5, 0.4), "enemies": 3, "conquered": false},
    {"name": "Graveyard", "pos": Vector2(700, 200), "col": Color(0.3, 0.3, 0.4), "enemies": 4, "conquered": false},
    {"name": "Forest", "pos": Vector2(500, 500), "col": Color(0.2, 0.35, 0.2), "enemies": 5, "conquered": false},
]

var scenario := ""
var mode := "title"
var ppos := Vector2(200, 360)
var aim := Vector2(640, 360)
var move := {"up": false, "down": false, "left": false, "right": false}
var hp := MAX_HP
var infamy := 0
var souls := 0
var soul_tick := 0.0
var minions: Array = []
var enemies: Array = []
var corpses: Array = []
var bolts: Array = []
var regions: Array = []
var fire_cd := 0.0
var hunter_spawned := false
var won := false
var anim := 0.0
var msg := ""

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
    elif id == "combat": _start(); _spawn_region_enemies(0)
    elif id == "raise": _start(); corpses = [{"pos": Vector2(400, 360), "kind": "guard"}]; _spawn_region_enemies(0)
    elif id == "conquer": _start(); regions[0]["conquered"] = true; regions[1]["conquered"] = true; _spawn_region_enemies(2)
    elif id == "hunters": _start(); infamy = 80; _spawn_hunter()
    else: _start(); _spawn_region_enemies(0)

func _start() -> void:
    mode = "play"; ppos = Vector2(200, 360); hp = MAX_HP; infamy = 0; souls = 0; soul_tick = 0.0
    minions = []; enemies = []; corpses = []; bolts = []; fire_cd = 0.0
    hunter_spawned = false; won = false
    regions = []
    for r in REGIONS:
        regions.append({"name": r["name"], "pos": r["pos"], "col": r["col"], "enemies": r["enemies"], "conquered": false})
    msg = "WASD move, click attack, E raise dead, SPACE conquer."

func _spawn_region_enemies(ri: int) -> void:
    enemies = []
    var r: Dictionary = regions[ri]
    var count: int = int(r["enemies"])
    for i in range(count):
        var ep: Vector2 = r["pos"] + Vector2(float(i) * 80 - 80, float(i % 2) * 60 - 30)
        var kind := "guard"
        if ri == 1: kind = "grave_archer"
        elif ri == 2: kind = "forest_brute"
        enemies.append({"pos": ep, "hp": 4 + ri, "kind": kind})

func _spawn_hunter() -> void:
    enemies.append({"pos": Vector2(1100, 200), "hp": 12, "kind": "hunter", "special": "shield"})
    hunter_spawned = true
    msg = "A HERO HUNTER approaches!"

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "play": return
    fire_cd = max(0.0, fire_cd - delta)
    var conquered_count := 0
    for r in regions:
        if r["conquered"]:
            conquered_count += 1
    if conquered_count > 0:
        soul_tick += delta
        if soul_tick >= 1.0:
            soul_tick = 0.0
            souls += conquered_count
    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    ppos += dir.normalized() * 180.0 * delta
    ppos.x = clampf(ppos.x, 40, VIEW.x - 40)
    ppos.y = clampf(ppos.y, 80, VIEW.y - 40)
    # bolts
    var bk: Array = []
    for b in bolts:
        b["pos"] += b["vel"] * delta
        if Rect2(0, 0, VIEW.x, VIEW.y).has_point(b["pos"]): bk.append(b)
    bolts = bk
    # enemies chase + contact damage
    for e in enemies:
        var d: Vector2 = ppos - e["pos"]
        e["pos"] += d.normalized() * 60.0 * delta
        if d.length() < PR + 14.0:
            hp -= 1
            e["pos"] += (e["pos"] - ppos).normalized() * 30.0
    # minions auto-attack nearest enemy
    for m in minions:
        if enemies.size() > 0:
            var nearest: Dictionary = enemies[0]
            for e in enemies:
                if e["pos"].distance_to(m["pos"]) < nearest["pos"].distance_to(m["pos"]):
                    nearest = e
            m["pos"] = m["pos"].move_toward(nearest["pos"], 90.0 * delta)
            if m["pos"].distance_to(nearest["pos"]) < 20.0:
                nearest["hp"] = int(nearest["hp"]) - int(m["dmg"])
                m["hp"] = max(1, int(m["hp"]) - (2 if str(nearest["kind"]) == "hunter" else 1))
        else:
            m["pos"] = m["pos"].move_toward(ppos + Vector2(30, 0), 70.0 * delta)
    # bolt vs enemy
    var bkeep: Array = []
    for b in bolts:
        var hit := false
        for e in enemies:
            if b["pos"].distance_to(e["pos"]) < 16.0:
                var blocked := str(e.get("special", "")) == "shield" and fmod(anim, 2.0) < 0.8
                e["hp"] = int(e["hp"]) - (1 if blocked else 3)
                hit = true
                break
        if not hit: bkeep.append(b)
    bolts = bkeep
    # cull dead enemies -> corpses
    var alive: Array = []
    for e in enemies:
        if int(e["hp"]) > 0: alive.append(e)
        else:
            corpses.append({"pos": e["pos"], "kind": e["kind"]}); infamy += 12 if str(e["kind"]) == "hunter" else 5
            if not hunter_spawned and infamy >= 60: _spawn_hunter()
    enemies = alive
    if hp <= 0: _finish(false)
    elif _all_conquered(): _finish(true)
    queue_redraw()

func _all_conquered() -> bool:
    for r in regions:
        if not r["conquered"]: return false
    return true

func _fire() -> void:
    if mode != "play" or fire_cd > 0.0: return
    fire_cd = 0.3
    var d := (aim - ppos).normalized()
    bolts.append({"pos": ppos, "vel": d * 500.0})

func _raise() -> void:
    if mode != "play" or minions.size() >= MAX_MINIONS: return
    for i in range(corpses.size()):
        if corpses[i]["pos"].distance_to(ppos) < 80.0:
            var kind := str(corpses[i].get("kind", "guard"))
            var mtype := "Skeleton"
            var mhp := 4
            var dmg := 1
            if kind == "grave_archer":
                mtype = "Spectral Archer"; mhp = 3; dmg = 2
            elif kind == "forest_brute":
                mtype = "Zombie Brute"; mhp = 7; dmg = 1
            elif kind == "hunter":
                mtype = "Elite Revenant"; mhp = 10; dmg = 3
            minions.append({"pos": corpses[i]["pos"], "type": mtype, "hp": mhp, "dmg": dmg})
            corpses.remove_at(i)
            msg = "Raised %s! Army: %d/%d" % [mtype, minions.size(), MAX_MINIONS]
            queue_redraw(); return
    msg = "No corpse nearby to raise."
    queue_redraw()

func _try_conquer() -> void:
    if mode != "play": return
    if enemies.size() > 0:
        msg = "Clear all defenders first!"; queue_redraw(); return
    for r in regions:
        if not r["conquered"] and ppos.distance_to(r["pos"]) < 100.0:
            r["conquered"] = true; infamy += 20; souls += 5
            msg = "Conquered %s! Soul income online." % str(r["name"])
            if not _all_conquered():
                var next := -1
                for i in range(regions.size()):
                    if not regions[i]["conquered"]: next = i; break
                if next >= 0: _spawn_region_enemies(next)
            queue_redraw(); return
    msg = "No unconquered region nearby."; queue_redraw()

func _finish(victory: bool) -> void:
    won = victory; mode = "result"; queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08, 0.06, 0.10))
    match mode:
        "title": _draw_title()
        "play": _draw_world()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
func _panel(r: Rect2, c := Color(0.06, 0.04, 0.08, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.6, 0.3, 0.7, 0.9), false, 2.0)
func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.14, 0.08, 0.16)); draw_rect(r, Color(0.7, 0.4, 0.8), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.92, 0.85, 0.95))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("NECROMANCER", Vector2(440, 250), 52, Color(0.7, 0.4, 0.9))
    _text("Raise the dead. Build your army. Conquer the land.", Vector2(380, 312), 18, Color(0.85, 0.8, 0.92))
    _button(Rect2(500, 410, 280, 64), "RISE")

func _draw_world() -> void:
    for i in range(regions.size() - 1):
        draw_line(regions[i]["pos"], regions[i + 1]["pos"], Color(0.45, 0.22, 0.55, 0.25), 5.0)
    for r in regions:
        var col: Color = r["col"]
        if r["conquered"]: col = Color(col.r * 0.5, col.g * 0.3, col.b * 0.6)
        draw_circle(r["pos"], 60, col)
        _text(str(r["name"]), r["pos"] + Vector2(-30, 70), 14, Color(0.8, 0.8, 0.85))
        if r["conquered"]: _text("☠", r["pos"] + Vector2(-8, 6), 22, Color(0.8, 0.4, 0.9))
    for c in corpses:
        draw_rect(Rect2(c["pos"] - Vector2(14, 5), Vector2(28, 8)), Color(0.4, 0.3, 0.3))
        draw_circle(c["pos"] + Vector2(-10, -4), 5, Color(0.5, 0.42, 0.36))
        _text(str(c.get("kind", "corpse")), c["pos"] + Vector2(-22, 22), 10, Color(0.65, 0.55, 0.55))
    for e in enemies:
        var kind := str(e["kind"])
        var ec := Color(0.9, 0.5, 0.3)
        if kind == "grave_archer": ec = Color(0.55, 0.65, 0.95)
        elif kind == "forest_brute": ec = Color(0.45, 0.75, 0.35)
        elif kind == "hunter": ec = Color(1.0, 0.8, 0.2)
        draw_polygon([e["pos"] + Vector2(0, -18), e["pos"] + Vector2(15, 8), e["pos"] + Vector2(0, 18), e["pos"] + Vector2(-15, 8)], [ec])
        if kind == "hunter":
            draw_circle(e["pos"], 24 + 4 * sin(anim * 5.0), Color(1.0, 0.92, 0.35, 0.35), false, 3)
            _text("shield hunter", e["pos"] + Vector2(-38, -28), 11, Color(1.0, 0.9, 0.45))
    for m in minions:
        var mt := str(m.get("type", "Skeleton"))
        var mc := Color(0.5, 0.3, 0.7)
        if mt == "Spectral Archer": mc = Color(0.55, 0.75, 1.0)
        elif mt == "Zombie Brute": mc = Color(0.45, 0.65, 0.35)
        elif mt == "Elite Revenant": mc = Color(0.95, 0.75, 0.25)
        draw_circle(m["pos"], 11, mc)
        draw_line(m["pos"] + Vector2(-8, 10), m["pos"] + Vector2(-16, 22), mc.lightened(0.25), 3.0)
        draw_line(m["pos"] + Vector2(8, 10), m["pos"] + Vector2(16, 22), mc.lightened(0.25), 3.0)
        draw_rect(Rect2(m["pos"] + Vector2(-14, -22), Vector2(28 * min(1.0, float(m.get("hp", 1)) / 10.0), 4)), Color(0.65, 0.95, 0.65))
    for b in bolts:
        draw_circle(b["pos"], 5, Color(0.7, 0.3, 0.9))
    draw_circle(ppos, PR, Color(0.3, 0.8, 0.3))
    draw_line(ppos, ppos + (aim - ppos).normalized() * 24.0, Color(0.7, 0.3, 0.9, 0.7), 2.0)
    _panel(Rect2(0, 0, 1280, 56))
    _text("HP %d/%d" % [hp, MAX_HP], Vector2(24, 38), 20, Color(0.8, 0.9, 0.7))
    _text("Army %d/%d" % [minions.size(), MAX_MINIONS], Vector2(200, 38), 20, Color(0.6, 0.5, 0.9))
    _text("Infamy %d" % infamy, Vector2(400, 38), 20, Color(0.9, 0.5, 0.5))
    _text("Souls %d" % souls, Vector2(520, 38), 20, Color(0.65, 0.9, 0.75))
    var conquered := 0
    for r in regions:
        if r["conquered"]: conquered += 1
    _text("Conquered %d/%d" % [conquered, regions.size()], Vector2(680, 38), 20, Color(0.8, 0.7, 0.9))
    var comp := ""
    for m in minions:
        comp += "%s hp%d  " % [str(m.get("type", "Skeleton")).left(10), int(m.get("hp", 1))]
    if comp != "":
        _text(comp, Vector2(900, 38), 13, Color(0.78, 0.72, 0.95))
    _text(msg, Vector2(40, 700), 16, Color(0.8, 0.8, 0.9))

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    if won:
        _text("THE LAND IS YOURS", Vector2(380, 260), 42, Color(0.7, 0.4, 0.95))
        _text("All regions conquered. Infamy: %d" % infamy, Vector2(420, 320), 20, Color(0.85, 0.8, 0.9))
    else:
        _text("FALLEN", Vector2(520, 260), 44, Color(0.95, 0.4, 0.4))
        _text("The necromancer is slain.", Vector2(460, 320), 20, Color(0.85, 0.8, 0.8))
    _button(Rect2(420, 420, 180, 54), "RETRY")
    _button(Rect2(660, 420, 180, 54), "TITLE")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move["up"] = p
            KEY_S, KEY_DOWN: move["down"] = p
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_E: if p and not event.echo: _raise()
            KEY_SPACE: if p and not event.echo: _try_conquer()
    if event is InputEventMouseMotion: aim = event.position
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        aim = event.position
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position):
                _start(); _spawn_region_enemies(0); queue_redraw()
        elif mode == "play": _fire()
        elif mode == "result":
            if Rect2(420, 420, 180, 54).has_point(event.position): _start(); _spawn_region_enemies(0); queue_redraw()
            elif Rect2(660, 420, 180, 54).has_point(event.position): mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_combat.json" <<'EOF'
{"duration_frames":460,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":442},{"frame":80,"type":"mouse_move","x":400,"y":300},{"frame":90,"type":"mouse_click","button":"left","x":400,"y":300},{"frame":140,"type":"mouse_click","button":"left","x":400,"y":300},{"frame":200,"type":"mouse_click","button":"left","x":500,"y":350},{"frame":300,"type":"key_press","keycode":"E"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_raise.json" <<'EOF'
{"scenario":"raise","duration_frames":400,"events":[{"frame":40,"type":"key_down","keycode":"D"},{"frame":120,"type":"key_up","keycode":"D"},{"frame":160,"type":"key_press","keycode":"E"},{"frame":250,"type":"mouse_click","button":"left","x":500,"y":300},{"frame":380,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_conquer.json" <<'EOF'
{"scenario":"conquer","duration_frames":460,"events":[{"frame":30,"type":"mouse_move","x":600,"y":500},{"frame":40,"type":"mouse_click","button":"left","x":600,"y":500},{"frame":100,"type":"mouse_click","button":"left","x":600,"y":500},{"frame":160,"type":"mouse_click","button":"left","x":600,"y":500},{"frame":240,"type":"mouse_click","button":"left","x":600,"y":500},{"frame":320,"type":"key_press","keycode":"SPACE"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_hunters.json" <<'EOF'
{"scenario":"hunters","duration_frames":460,"events":[{"frame":30,"type":"mouse_move","x":1100,"y":200},{"frame":40,"type":"mouse_click","button":"left","x":1100,"y":200},{"frame":100,"type":"mouse_click","button":"left","x":1100,"y":200},{"frame":160,"type":"key_press","keycode":"SPACE"},{"frame":240,"type":"mouse_click","button":"left","x":1100,"y":200},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/05_death.json" <<'EOF'
{"scenario":"combat","duration_frames":360,"events":[{"frame":60,"type":"wait"},{"frame":300,"type":"wait"}]}
EOF

echo "necromancer oracle generated at $GAME"
