#!/bin/bash
# Reference solution for gamecraft-bench/shooter-mech-sortie.
#
# A compact top-down mech shooter with a hangar loadout layer:
#   - Title -> hangar (equip weapons on hardpoints w/ weight/energy) -> mission
#     deploy -> top-down battle -> debrief. WASD move (momentum), mouse-aim
#     torso, 1/2 fire the two equipped weapons, salvage drops collected on touch.
#   - Mech armor depletes when hit, with damage states; 0 armor = mission fail.
#   - Multiple enemy types (infantry / vehicle / turret / rival mech) + a boss.
#   - Debrief screen: salvage, damage taken, accuracy, rating.
#   - Scenarios jump to hangar / battle / boss / debrief for deterministic demos.
#
# Oracle for the verifier: primitives only, so art items (A*) stay low while
# mechanic/content items pass. Logic in _physics_process for deterministic replay.
#
# NOTE (GDScript warnings-as-errors): explicit types on Dictionary-subscript /
# min()/max() derived values to avoid inferred-Variant parse errors.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="MechSortie"
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
const FIELD := Rect2(160, 110, 960, 500)
const MR := 18.0
const MAX_ARMOR := 10

const ARMORY := [
    {"name": "Autocannon", "cd": 0.16, "spd": 760.0, "dmg": 1, "weight": 3, "energy": 2, "spread": 0.04},
    {"name": "Missile Rack", "cd": 0.7, "spd": 460.0, "dmg": 3, "weight": 5, "energy": 4, "spread": 0.0},
    {"name": "Laser", "cd": 0.32, "spd": 1100.0, "dmg": 2, "weight": 2, "energy": 5, "spread": 0.0},
    {"name": "Flak", "cd": 0.5, "spd": 620.0, "dmg": 1, "weight": 4, "energy": 3, "spread": 0.18},
]
const MAX_WEIGHT := 10
const MAX_ENERGY := 9

var scenario := ""
var mode := "title"          # title, hangar, play, result
var loadout := [0, 1]        # two equipped armory indices
var sel_slot := 0
var salvage := 0
var armor := MAX_ARMOR
var shots := 0
var hits := 0
var dmg_taken := 0
var ppos := Vector2(300, 360)
var pvel := Vector2.ZERO
var aim := Vector2(640, 360)
var move := {"up": false, "down": false, "left": false, "right": false}
var fire_cd := [0.0, 0.0]
var bullets: Array = []      # {pos, vel, dmg}
var enemies: Array = []      # {pos, hp, kind, t, boss}
var crates: Array = []       # {pos}
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
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _load_scenario(id: String) -> void:
    if id == "title_flow":
        mode = "title"
    elif id == "hangar":
        mode = "hangar"
    elif id == "battle" or id == "combat":
        _deploy(false)
    elif id == "boss":
        _deploy(true)
    elif id == "near_victory":
        _deploy(false)
        while enemies.size() > 1:
            enemies.pop_back()
    elif id == "death":
        _deploy(false); armor = 1
    else:
        _deploy(false)

func _loadout_weight() -> int:
    var w := 0
    for idx in loadout:
        w += int(ARMORY[int(idx)]["weight"])
    return w

func _loadout_energy() -> int:
    var e := 0
    for idx in loadout:
        e += int(ARMORY[int(idx)]["energy"])
    return e

func _deploy(boss: bool) -> void:
    mode = "play"
    armor = MAX_ARMOR
    shots = 0
    hits = 0
    dmg_taken = 0
    ppos = Vector2(300, 360)
    pvel = Vector2.ZERO
    fire_cd = [0.0, 0.0]
    bullets = []
    crates = []
    won = false
    enemies = []
    if boss:
        enemies.append({"pos": Vector2(900, 360), "hp": 40, "kind": "boss", "t": 0.0, "boss": true})
        msg = "BOSS MECH - exploit your loadout."
    else:
        var kinds := ["infantry", "vehicle", "turret", "rival"]
        for i in range(5):
            var ex := FIELD.position.x + 420.0 + float(i % 3) * 180.0
            var ey := FIELD.position.y + 90.0 + float(i / 3) * 200.0 + float(i % 2) * 60.0
            var k: String = kinds[i % 4]
            var hpv := 3 if k != "rival" else 8
            enemies.append({"pos": Vector2(ex, ey), "hp": hpv, "kind": k, "t": float(i), "boss": false})
        msg = "Destroy all hostiles. WASD move, 1/2 fire weapons."

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "play":
        return
    for i in range(2):
        fire_cd[i] = max(0.0, float(fire_cd[i]) - delta)
    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    # momentum
    pvel = pvel.lerp(dir.normalized() * 170.0, 3.0 * delta)
    ppos += pvel * delta
    ppos.x = clampf(ppos.x, FIELD.position.x + MR, FIELD.position.x + FIELD.size.x - MR)
    ppos.y = clampf(ppos.y, FIELD.position.y + MR, FIELD.position.y + FIELD.size.y - MR)

    var bk: Array = []
    for b in bullets:
        b["pos"] += b["vel"] * delta
        if FIELD.grow(30).has_point(b["pos"]):
            bk.append(b)
    bullets = bk

    for e in enemies:
        e["t"] += delta
        var spd := 40.0 if str(e["kind"]) == "turret" else (90.0 if e["boss"] else 60.0)
        if str(e["kind"]) != "turret":
            e["pos"] += (ppos - e["pos"]).normalized() * spd * delta
        # enemy contact damages mech
        var rad := 32.0 if e["boss"] else 18.0
        if e["pos"].distance_to(ppos) < rad + MR and int(armor) > 0:
            armor -= 1
            dmg_taken += 1
            e["pos"] += (e["pos"] - ppos).normalized() * 40.0

    _collisions()
    # collect salvage crates
    var ck: Array = []
    for c in crates:
        if c["pos"].distance_to(ppos) < MR + 14.0:
            salvage += 25
        else:
            ck.append(c)
    crates = ck

    if armor <= 0:
        _finish(false)
    elif enemies.size() == 0:
        _finish(true)
    queue_redraw()

func _collisions() -> void:
    var keep: Array = []
    for b in bullets:
        var hit := false
        for e in enemies:
            var rad := 30.0 if e["boss"] else 16.0
            if b["pos"].distance_to(e["pos"]) < rad:
                e["hp"] = int(e["hp"]) - int(b["dmg"])
                hits += 1
                hit = true
                break
        if not hit:
            keep.append(b)
    bullets = keep
    var alive: Array = []
    for e in enemies:
        if int(e["hp"]) > 0:
            alive.append(e)
        else:
            crates.append({"pos": e["pos"]})
    enemies = alive

func _fire(slot: int) -> void:
    if mode != "play" or float(fire_cd[slot]) > 0.0:
        return
    var w: Dictionary = ARMORY[int(loadout[slot])]
    fire_cd[slot] = float(w["cd"])
    var d := (aim - ppos).normalized()
    var sp: float = float(w["spread"])
    var spd: float = float(w["spd"])
    var dmg: int = int(w["dmg"])
    if sp > 0.0:
        for off in [-sp, 0.0, sp]:
            bullets.append({"pos": ppos, "vel": d.rotated(off) * spd, "dmg": dmg})
            shots += 1
    else:
        bullets.append({"pos": ppos, "vel": d * spd, "dmg": dmg})
        shots += 1

func _finish(victory: bool) -> void:
    won = victory
    if victory:
        salvage += 100
    mode = "result"
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08, 0.09, 0.10))
    match mode:
        "title": _draw_title()
        "hangar": _draw_hangar()
        "play": _draw_play()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _panel(r: Rect2, c := Color(0.05, 0.06, 0.07, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.4, 0.55, 0.6, 0.9), false, 2.0)

func _button(r: Rect2, label: String, on := true) -> void:
    draw_rect(r, Color(0.10, 0.14, 0.16) if on else Color(0.16, 0.08, 0.08))
    draw_rect(r, Color(0.45, 0.65, 0.7) if on else Color(0.5, 0.3, 0.3), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.88, 0.92, 0.92))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("MECH SORTIE", Vector2(420, 250), 52, Color(0.55, 0.8, 0.85))
    _text("Customize the loadout. Deploy. Destroy. Salvage. Repeat.", Vector2(375, 312), 18, Color(0.82, 0.88, 0.9))
    _button(Rect2(500, 410, 280, 64), "ENTER HANGAR")

func _draw_hangar() -> void:
    _panel(Rect2(40, 90, 1200, 540))
    _text("HANGAR", Vector2(80, 140), 36, Color(0.6, 0.85, 0.9))
    _text("Salvage: %d   Weight %d/%d   Energy %d/%d" % [salvage, _loadout_weight(), MAX_WEIGHT, _loadout_energy(), MAX_ENERGY],
          Vector2(80, 178), 18, Color(0.85, 0.88, 0.9))
    # mech with two hardpoints
    draw_rect(Rect2(180, 280, 90, 130), Color(0.4, 0.45, 0.5))
    for s in range(2):
        var sr := Rect2(150 + s * 130, 230, 70, 36)
        draw_rect(sr, Color(0.2, 0.5, 0.55) if sel_slot == s else Color(0.18, 0.24, 0.28))
        draw_rect(sr, Color(0.5, 0.7, 0.75), false, 2.0)
        _text("S%d:%s" % [s + 1, str(ARMORY[int(loadout[s])]["name"]).left(6)], sr.position + Vector2(6, 24), 14, Color(0.9, 0.95, 0.95))
    _text("Selected slot: %d (click a weapon to equip)" % (sel_slot + 1), Vector2(150, 300), 16, Color(0.8, 0.85, 0.9))
    # armory list
    for i in range(ARMORY.size()):
        var r := Rect2(480, 230 + i * 70, 700, 56)
        _button(r, "%s   wt %d  en %d  dmg %d" % [str(ARMORY[i]["name"]), int(ARMORY[i]["weight"]), int(ARMORY[i]["energy"]), int(ARMORY[i]["dmg"])])
    _button(Rect2(480, 540, 300, 56), "DEPLOY ->")

func _draw_play() -> void:
    draw_rect(FIELD, Color(0.12, 0.13, 0.12))
    draw_rect(FIELD, Color(0.35, 0.45, 0.4), false, 3.0)
    for c in crates:
        draw_rect(Rect2(c["pos"] - Vector2(7, 7), Vector2(14, 14)), Color(0.95, 0.8, 0.3))
    for e in enemies:
        var col := Color(0.85, 0.4, 0.4)
        var k: String = str(e["kind"])
        if e["boss"]: col = Color(0.95, 0.3, 0.55)
        elif k == "vehicle": col = Color(0.8, 0.6, 0.3)
        elif k == "turret": col = Color(0.6, 0.6, 0.7)
        elif k == "rival": col = Color(0.9, 0.45, 0.7)
        var rad := 28.0 if e["boss"] else 15.0
        draw_circle(e["pos"], rad, col)
        if e["boss"]:
            _bar(Rect2(e["pos"].x - 50, e["pos"].y - 42, 100, 8), float(e["hp"]) / 40.0, Color(0.95, 0.3, 0.55))
    for b in bullets:
        draw_circle(b["pos"], 4.0, Color(0.6, 0.95, 1.0))
    # mech
    draw_rect(Rect2(ppos - Vector2(MR, MR), Vector2(MR * 2, MR * 2)), Color(0.5, 0.7, 0.85))
    if armor <= 3:
        draw_circle(ppos + Vector2(0, -8), 6, Color(0.5, 0.5, 0.5, 0.7))  # smoke (damaged)
    draw_line(ppos, ppos + (aim - ppos).normalized() * 34.0, Color(1, 1, 1, 0.7), 3.0)
    # HUD
    _panel(Rect2(0, 0, 1280, 58))
    _bar(Rect2(24, 22, 200, 18), float(armor) / float(MAX_ARMOR), Color(0.4, 0.8, 0.5))
    _text("ARMOR", Vector2(232, 38), 18, Color(0.8, 0.9, 0.8))
    _text("Salvage %d" % salvage, Vector2(360, 38), 20, Color(0.95, 0.85, 0.4))
    _text("S1:%s  S2:%s" % [str(ARMORY[int(loadout[0])]["name"]).left(7), str(ARMORY[int(loadout[1])]["name"]).left(7)], Vector2(540, 38), 18, Color(0.7, 0.85, 0.95))
    _text("Hostiles %d" % enemies.size(), Vector2(960, 38), 20, Color(0.9, 0.6, 0.6))
    _text(msg, Vector2(40, 698), 16, Color(0.82, 0.88, 0.9))

func _bar(r: Rect2, frac: float, c: Color) -> void:
    frac = clampf(frac, 0.0, 1.0)
    draw_rect(r, Color(0.1, 0.1, 0.1))
    draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), c)

func _draw_result() -> void:
    _panel(Rect2(300, 160, 680, 360))
    if won:
        _text("MISSION COMPLETE", Vector2(380, 240), 42, Color(0.5, 0.95, 0.6))
    else:
        _text("MECH DESTROYED", Vector2(400, 240), 42, Color(0.95, 0.4, 0.4))
    var acc := 0
    if shots > 0:
        acc = int(100.0 * float(hits) / float(shots))
    _text("Salvage earned: %d" % salvage, Vector2(420, 300), 22, Color(0.95, 0.85, 0.4))
    _text("Damage taken: %d" % dmg_taken, Vector2(420, 336), 20, Color(0.9, 0.7, 0.7))
    _text("Accuracy: %d%%" % acc, Vector2(420, 372), 20, Color(0.8, 0.85, 0.9))
    _text("Rating: %s" % ("S" if acc >= 70 and won else ("A" if won else "F")), Vector2(420, 408), 22, Color(0.9, 0.9, 0.5))
    _button(Rect2(420, 450, 180, 50), "HANGAR")
    _button(Rect2(660, 450, 180, 50), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move["up"] = p
            KEY_S, KEY_DOWN: move["down"] = p
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_1:
                if p: _fire(0)
            KEY_2:
                if p: _fire(1)
            KEY_TAB:
                if p: sel_slot = (sel_slot + 1) % 2
    if event is InputEventMouseMotion:
        aim = event.position
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        aim = event.position
        _click(event.position)

func _click(pos: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(pos):
            mode = "hangar"; queue_redraw()
    elif mode == "hangar":
        for s in range(2):
            if Rect2(150 + s * 130, 230, 70, 36).has_point(pos):
                sel_slot = s; queue_redraw(); return
        for i in range(ARMORY.size()):
            if Rect2(480, 230 + i * 70, 700, 56).has_point(pos):
                loadout[sel_slot] = i; queue_redraw(); return
        if Rect2(480, 540, 300, 56).has_point(pos):
            _deploy(false); queue_redraw()
    elif mode == "play":
        _fire(0)
    elif mode == "result":
        if Rect2(420, 450, 180, 50).has_point(pos):
            mode = "hangar"; queue_redraw()
        elif Rect2(660, 450, 180, 50).has_point(pos):
            mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_hangar.json" <<'EOF'
{
  "duration_frames": 440,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 80,  "type": "mouse_click", "button": "left", "x": 185, "y": 248},
    {"frame": 130, "type": "mouse_click", "button": "left", "x": 800, "y": 370},
    {"frame": 200, "type": "mouse_click", "button": "left", "x": 315, "y": 248},
    {"frame": 250, "type": "mouse_click", "button": "left", "x": 800, "y": 440},
    {"frame": 330, "type": "mouse_click", "button": "left", "x": 630, "y": 568},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_battle.json" <<'EOF'
{
  "scenario": "battle",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_move", "x": 760, "y": 250},
    {"frame": 40,  "type": "key_press", "keycode": "1"},
    {"frame": 70,  "type": "key_press", "keycode": "2"},
    {"frame": 110, "type": "key_down", "keycode": "D"},
    {"frame": 160, "type": "key_up", "keycode": "D"},
    {"frame": 190, "type": "mouse_move", "x": 820, "y": 420},
    {"frame": 200, "type": "key_press", "keycode": "1"},
    {"frame": 260, "type": "key_press", "keycode": "1"},
    {"frame": 320, "type": "key_press", "keycode": "2"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_boss.json" <<'EOF'
{
  "scenario": "boss",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_move", "x": 900, "y": 360},
    {"frame": 40,  "type": "key_press", "keycode": "1"},
    {"frame": 90,  "type": "key_press", "keycode": "2"},
    {"frame": 140, "type": "key_down", "keycode": "W"},
    {"frame": 190, "type": "key_up", "keycode": "W"},
    {"frame": 240, "type": "key_press", "keycode": "1"},
    {"frame": 320, "type": "key_press", "keycode": "2"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_clear.json" <<'EOF'
{
  "scenario": "near_victory",
  "duration_frames": 380,
  "events": [
    {"frame": 40,  "type": "mouse_move", "x": 760, "y": 250},
    {"frame": 50,  "type": "key_press", "keycode": "1"},
    {"frame": 120, "type": "key_press", "keycode": "1"},
    {"frame": 200, "type": "key_press", "keycode": "2"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_death.json" <<'EOF'
{
  "scenario": "death",
  "duration_frames": 360,
  "events": [
    {"frame": 40,  "type": "key_down", "keycode": "D"},
    {"frame": 300, "type": "key_up", "keycode": "D"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

echo "mech-sortie oracle generated at $GAME"
