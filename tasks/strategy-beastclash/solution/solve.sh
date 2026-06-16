#!/bin/bash
# Reference solution for gamecraft-bench/strategy-beastclash.
#
# Generates a compact single-lane animal-war (Age of War style) strategy game:
#   - Title -> kingdom select (3 factions) -> battle -> result.
#   - Food economy: passive regen + gatherer creatures; spending food spawns
#     units; unaffordable spend is refused with a red flash.
#   - Three creature roles: gatherer (economy), brawler (melee), ranged.
#   - Units march down a lane, fight on contact, die with a shrink effect; the
#     front line pushes back and forth. The AI fields its own escalating units.
#   - Evolution: a growth bar fills from kills/time and advances the era (1->3),
#     unlocking larger, stronger creatures and a grown den.
#   - Win by razing the enemy den; lose if your den falls. Styled result screen.
#   - Deterministic: RNG is seeded; no wall-clock reads drive game logic.
#   - Demo traces cover the loop, faction choice, economy, evolution, victory
#     and defeat.
#
# The whole game lives in one Main.gd. It is the oracle for the verifier
# framework, not a polished game: creatures/dens are drawn from primitives, so
# the art items (A1-A5) stay low while the mechanic items pass.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="BeastClash"
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
const P_BASE_X := 140.0
const E_BASE_X := 1140.0
const UNIT_Y := 486.0
const GROUND_Y := 540.0
const BASE_HP := 120.0
const ATTACK_INT := 0.6
const MAX_UNITS := 40

const UNIT_DEFS := {
    "gatherer": {"hp": 14.0, "dmg": 1.0, "spd": 22.0, "rng": 26.0, "cost": 10},
    "brawler":  {"hp": 42.0, "dmg": 6.0, "spd": 40.0, "rng": 30.0, "cost": 25},
    "ranged":   {"hp": 22.0, "dmg": 9.0, "spd": 32.0, "rng": 130.0, "cost": 40},
}
const EVOLVE_NEED := {1: 45.0, 2: 110.0}

const COL_PLAYER := Color(0.36, 0.62, 0.90)
const COL_ENEMY := Color(0.90, 0.36, 0.30)
const COL_FOOD := Color(0.95, 0.82, 0.35)

var kingdoms := {
    "lion":     {"name": "Lion Pride",   "trait": "Ferocious (+damage)", "tint": Color(0.93, 0.78, 0.40)},
    "wolf":     {"name": "Wolf Pack",    "trait": "Swift (+speed)",      "tint": Color(0.70, 0.74, 0.82)},
    "rhino":    {"name": "Rhino Herd",   "trait": "Hardy (+health)",     "tint": Color(0.66, 0.72, 0.58)},
}

var scenario := ""
var mode := "title"
var kingdom_id := "lion"
var food := 40.0
var xp := 0.0
var era := 1
var p_base_hp := BASE_HP
var e_base_hp := BASE_HP
var p_base_hit := 0.0
var e_base_hit := 0.0
var battle_time := 0.0
var ai_timer := 0.0
var ai_count := 0
var deny_flash := 0.0
var evolve_flash := 0.0
var message := ""
var result_win := false
var player_units: Array = []
var enemy_units: Array = []
var deaths: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 12345
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

func _start_battle() -> void:
    mode = "battle"
    player_units = []
    enemy_units = []
    deaths = []
    food = 40.0
    xp = 0.0
    era = 1
    p_base_hp = BASE_HP
    e_base_hp = BASE_HP
    battle_time = 0.0
    ai_timer = 0.0
    ai_count = 0
    deny_flash = 0.0
    evolve_flash = 0.0
    message = "Send creatures with 1 / 2 / 3."

func _load_scenario(id: String) -> void:
    _start_battle()
    if id == "wolf_start":
        kingdom_id = "wolf"
        food = 80.0
        message = "Wolf Pack start: swift creatures change the battle tempo."
    elif id == "rhino_start":
        kingdom_id = "rhino"
        food = 80.0
        message = "Rhino Herd start: hardy creatures hold the lane."
    elif id == "evolved":
        era = 3
        food = 130.0
        player_units.append(_make_unit("player", "brawler", 3))
        player_units.append(_make_unit("player", "ranged", 3))
        enemy_units.append(_make_unit("enemy", "brawler", 2))
        message = "Apex era: send your strongest beasts."
    elif id == "near_victory":
        era = 2
        food = 70.0
        e_base_hp = 8.0
        var a := _make_unit("player", "brawler", 2)
        a["x"] = E_BASE_X - 170.0
        player_units.append(a)
        var b := _make_unit("player", "brawler", 2)
        b["x"] = E_BASE_X - 220.0
        player_units.append(b)
        message = "The enemy den is nearly down -- push!"
    elif id == "near_defeat":
        food = 20.0
        p_base_hp = 8.0
        for k in range(3):
            var e := _make_unit("enemy", "brawler", 1)
            e["x"] = P_BASE_X + 150.0 + float(k) * 40.0
            enemy_units.append(e)
        message = "Your den is about to fall!"
    # "battle_start" and unknown ids fall through to a plain fresh battle.

func _faction_mods(side: String) -> Dictionary:
    if side != "player":
        return {"hp": 1.0, "dmg": 1.0, "spd": 1.0}
    match kingdom_id:
        "lion":
            return {"hp": 1.0, "dmg": 1.35, "spd": 1.0}
        "wolf":
            return {"hp": 0.9, "dmg": 1.0, "spd": 1.4}
        "rhino":
            return {"hp": 1.45, "dmg": 1.0, "spd": 0.85}
        _:
            return {"hp": 1.0, "dmg": 1.0, "spd": 1.0}

func _make_unit(side: String, kind: String, unit_era: int) -> Dictionary:
    var base: Dictionary = UNIT_DEFS[kind]
    var em := 1.0 + 0.6 * float(unit_era - 1)
    var fm := _faction_mods(side)
    var hp_val: float = base["hp"] * em * float(fm["hp"])
    var start_x := P_BASE_X + 36.0 if side == "player" else E_BASE_X - 36.0
    return {
        "side": side,
        "kind": kind,
        "era": unit_era,
        "x": start_x,
        "hp": hp_val,
        "maxhp": hp_val,
        "dmg": base["dmg"] * em * float(fm["dmg"]),
        "spd": base["spd"] * float(fm["spd"]),
        "rng": float(base["rng"]),
        "cd": 0.0,
        "hit": 0.0,
    }

func _spawn_player(kind: String) -> void:
    if mode != "battle":
        return
    if player_units.size() >= MAX_UNITS:
        return
    var cost: int = UNIT_DEFS[kind]["cost"]
    if food < float(cost):
        deny_flash = 0.45
        message = "Not enough food for a %s." % kind
        queue_redraw()
        return
    food -= float(cost)
    player_units.append(_make_unit("player", kind, era))
    message = "Sent a %s." % kind
    queue_redraw()

func _try_evolve() -> void:
    if mode != "battle":
        return
    if era >= 3:
        message = "Already at the apex era."
        return
    var need: float = EVOLVE_NEED[era]
    if xp < need:
        deny_flash = 0.45
        message = "Need more growth to evolve."
        return
    xp -= need
    era += 1
    evolve_flash = 0.7
    message = "Evolved to era %d!" % era

func _gain_xp(amount: float) -> void:
    xp += amount
    if era < 3 and xp >= float(EVOLVE_NEED[era]):
        xp -= float(EVOLVE_NEED[era])
        era += 1
        evolve_flash = 0.7
        message = "Evolved to era %d!" % era

func _nearest(arr: Array, x: float):
    var best = null
    var bd := 1.0e9
    for u in arr:
        var d: float = abs(u["x"] - x)
        if d < bd:
            bd = d
            best = u
    return best

func _process(delta: float) -> void:
    if mode != "battle":
        return
    battle_time += delta
    deny_flash = max(0.0, deny_flash - delta)
    evolve_flash = max(0.0, evolve_flash - delta)
    p_base_hit = max(0.0, p_base_hit - delta)
    e_base_hit = max(0.0, e_base_hit - delta)

    # Economy: base regen + gatherers.
    var gatherers := 0
    for u in player_units:
        if u["kind"] == "gatherer":
            gatherers += 1
    food += (6.0 + 4.0 * float(gatherers)) * delta
    _gain_xp(3.0 * delta)

    # Enemy AI: spawn escalating units on a shrinking interval.
    ai_timer += delta
    var e_era: int = clampi(1 + int(battle_time / 14.0), 1, 3)
    var interval: float = max(1.4, 3.2 - battle_time * 0.04)
    if ai_timer >= interval and enemy_units.size() < MAX_UNITS:
        ai_timer = 0.0
        var kinds := ["brawler", "ranged"]
        enemy_units.append(_make_unit("enemy", kinds[ai_count % 2], e_era))
        ai_count += 1

    _step_side(player_units, enemy_units, delta, true)
    _step_side(enemy_units, player_units, delta, false)
    _cull(delta)

    if e_base_hp <= 0.0:
        _finish(true)
    elif p_base_hp <= 0.0:
        _finish(false)
    queue_redraw()

func _step_side(units: Array, foes: Array, delta: float, is_player: bool) -> void:
    var sign := 1.0 if is_player else -1.0
    var goal_x := E_BASE_X - 40.0 if is_player else P_BASE_X + 40.0
    for u in units:
        u["hit"] = max(0.0, u["hit"] - delta)
        u["cd"] = max(0.0, u["cd"] - delta)
        # Gatherers forage near the home den instead of marching to war.
        if is_player and u["kind"] == "gatherer":
            u["x"] = move_toward(u["x"], P_BASE_X + 95.0, u["spd"] * delta)
            continue
        var tgt = _nearest(foes, u["x"])
        var target_x: float = tgt["x"] if tgt != null else goal_x
        if abs(target_x - u["x"]) <= u["rng"]:
            if u["cd"] <= 0.0:
                u["cd"] = ATTACK_INT
                if tgt != null:
                    tgt["hp"] -= u["dmg"]
                    tgt["hit"] = 0.16
                elif is_player:
                    e_base_hp = max(0.0, e_base_hp - u["dmg"])
                    e_base_hit = 0.2
                else:
                    p_base_hp = max(0.0, p_base_hp - u["dmg"])
                    p_base_hit = 0.2
        else:
            u["x"] += sign * u["spd"] * delta

func _cull(delta: float) -> void:
    var alive_p: Array = []
    for u in player_units:
        if u["hp"] > 0.0:
            alive_p.append(u)
        else:
            deaths.append({"x": u["x"], "side": "player", "ttl": 0.4})
    player_units = alive_p
    var alive_e: Array = []
    for u in enemy_units:
        if u["hp"] > 0.0:
            alive_e.append(u)
        else:
            deaths.append({"x": u["x"], "side": "enemy", "ttl": 0.4})
            food += 6.0
            _gain_xp(12.0)
    enemy_units = alive_e
    var keep: Array = []
    for d in deaths:
        d["ttl"] -= delta
        if d["ttl"] > 0.0:
            keep.append(d)
    deaths = keep

func _finish(win: bool) -> void:
    mode = "result"
    result_win = win
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.10, 0.13, 0.11))
    if mode == "title":
        _draw_title()
    elif mode == "select":
        _draw_select()
    elif mode == "battle":
        _draw_battle()
    elif mode == "result":
        _draw_battle()
        _draw_result()

func _draw_panel(rect: Rect2, color := Color(0.07, 0.09, 0.08, 0.92)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.42, 0.50, 0.34, 0.95), false, 2.0)

func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_button(rect: Rect2, text: String) -> void:
    draw_rect(rect, Color(0.13, 0.16, 0.13))
    draw_rect(rect, Color(0.55, 0.70, 0.42), false, 2.0)
    _draw_text(text, rect.position + Vector2(16, rect.size.y * 0.64), 22, Color(0.92, 0.95, 0.82))

func _draw_bar(rect: Rect2, frac: float, color: Color) -> void:
    frac = clampf(frac, 0.0, 1.0)
    draw_rect(rect, Color(0.05, 0.06, 0.05))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y)), color)
    draw_rect(rect, Color(0.30, 0.36, 0.26), false, 1.5)

func _draw_sky() -> void:
    draw_rect(Rect2(0, 0, 1280, GROUND_Y), Color(0.16, 0.22, 0.20))
    draw_rect(Rect2(0, GROUND_Y, 1280, 720 - GROUND_Y), Color(0.20, 0.16, 0.11))
    for i in range(40):
        var x := float((i * 137) % 1280)
        draw_rect(Rect2(x, GROUND_Y + float((i * 53) % 60), 20, 4), Color(0.26, 0.30, 0.14, 0.6))

func _draw_title() -> void:
    _draw_sky()
    _draw_panel(Rect2(330, 150, 620, 360))
    _draw_text("BEAST CLASH", Vector2(415, 250), 64, Color(0.93, 0.84, 0.50))
    _draw_text("Two animal kingdoms. One lane. Evolve and overrun.", Vector2(372, 310), 22, Color(0.80, 0.84, 0.72))
    _draw_button(Rect2(520, 420, 240, 70), "START BATTLE")

func _draw_select() -> void:
    _draw_sky()
    _draw_text("Choose your kingdom", Vector2(420, 90), 42, Color(0.92, 0.86, 0.66))
    var ids := ["lion", "wolf", "rhino"]
    for i in range(ids.size()):
        var id: String = ids[i]
        var r := Rect2(110 + i * 390, 200, 320, 300)
        _draw_panel(r)
        var k: Dictionary = kingdoms[id]
        draw_circle(r.position + Vector2(160, 95), 46, k["tint"])
        draw_circle(r.position + Vector2(160, 78), 20, Color(0.12, 0.12, 0.12))
        _draw_text(k["name"], r.position + Vector2(28, 185), 26, Color(0.95, 0.90, 0.72))
        _draw_text(k["trait"], r.position + Vector2(28, 222), 18, Color(0.78, 0.82, 0.70))
        _draw_button(Rect2(r.position + Vector2(70, 250), Vector2(180, 44)), "SELECT")

func _draw_den(x: float, hp: float, hit: float, is_player: bool) -> void:
    var col := COL_PLAYER if is_player else COL_ENEMY
    var w := 70.0 + 14.0 * float(era - 1)
    var h := 90.0 + 18.0 * float(era - 1)
    var base := Rect2(x - w * 0.5, GROUND_Y - h, w, h)
    var pulse := 0.04 * sin(battle_time * 2.0)
    draw_rect(base, Color(col.r * 0.4, col.g * 0.4, col.b * 0.4))
    draw_rect(base, col.lerp(Color(1, 1, 1), 0.15 + pulse), false, 4.0)
    if hit > 0.0:
        draw_rect(base, Color(1, 1, 1, hit), false, 5.0)
    draw_circle(Vector2(x, base.position.y), w * 0.4, col)

func _draw_unit(u: Dictionary) -> void:
    var is_p: bool = u["side"] == "player"
    var col := COL_PLAYER if is_p else COL_ENEMY
    if is_p:
        col = col.lerp(kingdoms[kingdom_id]["tint"], 0.35)
    var bob := sin(battle_time * 6.0 + u["x"] * 0.12) * 2.0
    var pos := Vector2(u["x"], UNIT_Y + bob)
    var scale := 0.8 + 0.32 * float(u["era"] - 1)
    var kind: String = u["kind"]
    if kind == "gatherer":
        draw_circle(pos, 9.0 * scale, Color(0.55, 0.80, 0.45))
    elif kind == "brawler":
        draw_rect(Rect2(pos.x - 12 * scale, pos.y - 14 * scale, 24 * scale, 26 * scale), col)
        draw_circle(pos + Vector2(0, -18 * scale), 8 * scale, col.lerp(Color(1, 1, 1), 0.2))
    else:
        draw_circle(pos, 11 * scale, col)
        var tip := 16.0 if is_p else -16.0
        draw_line(pos, pos + Vector2(tip, -8), col.lerp(Color(1, 1, 1), 0.3), 3.0)
    if u["hit"] > 0.0:
        draw_circle(pos, 16 * scale, Color(1, 1, 1, u["hit"]))
    var bar := Rect2(pos.x - 14, pos.y - 30 * scale, 28, 4)
    _draw_bar(bar, float(u["hp"]) / float(u["maxhp"]), Color(0.5, 0.85, 0.4) if is_p else Color(0.9, 0.5, 0.4))

func _draw_battle() -> void:
    _draw_sky()
    for d in deaths:
        var c := COL_PLAYER if d["side"] == "player" else COL_ENEMY
        draw_circle(Vector2(d["x"], UNIT_Y), 18.0 * float(d["ttl"]) / 0.4, Color(c.r, c.g, c.b, float(d["ttl"])))
    _draw_den(P_BASE_X, p_base_hp, p_base_hit, true)
    _draw_den(E_BASE_X, e_base_hp, e_base_hit, false)
    for u in player_units:
        _draw_unit(u)
    for u in enemy_units:
        _draw_unit(u)

    # HUD: food (top-left), evolution (top-center), den HP (above each den).
    var food_panel := Rect2(20, 16, 240, 64)
    _draw_panel(food_panel, Color(0.07, 0.09, 0.08, 0.92) if deny_flash <= 0.0 else Color(0.4, 0.08, 0.06, 0.92))
    _draw_text(kingdoms[kingdom_id]["name"], Vector2(36, 34), 15, Color(0.78, 0.84, 0.70))
    _draw_text("FOOD  %d" % int(food), Vector2(36, 62), 26, COL_FOOD)

    var evo_panel := Rect2(470, 16, 340, 56)
    _draw_panel(evo_panel, Color(0.07, 0.09, 0.08, 0.92) if evolve_flash <= 0.0 else Color(0.2, 0.45, 0.2, 0.95))
    _draw_text("ERA %d" % era, Vector2(486, 52), 24, Color(0.92, 0.86, 0.62))
    var need: float = EVOLVE_NEED[era] if era < 3 else 1.0
    var frac: float = (xp / need) if era < 3 else 1.0
    _draw_bar(Rect2(566, 30, 230, 22), frac, Color(0.55, 0.80, 0.45))

    _draw_bar(Rect2(P_BASE_X - 60, 92, 120, 16), p_base_hp / BASE_HP, COL_PLAYER)
    _draw_text("YOUR DEN", Vector2(P_BASE_X - 56, 126), 16, Color(0.80, 0.86, 0.92))
    _draw_bar(Rect2(E_BASE_X - 60, 92, 120, 16), e_base_hp / BASE_HP, COL_ENEMY)
    _draw_text("ENEMY DEN", Vector2(E_BASE_X - 58, 126), 16, Color(0.92, 0.80, 0.78))

    # Bottom hand: three creature cards with food cost.
    var hand := Rect2(330, 616, 620, 88)
    _draw_panel(hand)
    var kinds := ["gatherer", "brawler", "ranged"]
    var labels := ["1 Gatherer", "2 Brawler", "3 Ranged"]
    for i in range(3):
        var cr := Rect2(348 + i * 196, 628, 180, 64)
        var cost: int = UNIT_DEFS[kinds[i]]["cost"]
        var afford := food >= float(cost)
        draw_rect(cr, Color(0.13, 0.16, 0.13) if afford else Color(0.20, 0.10, 0.10))
        draw_rect(cr, Color(0.55, 0.70, 0.42) if afford else Color(0.5, 0.3, 0.3), false, 2.0)
        _draw_text(labels[i], cr.position + Vector2(12, 30), 18, Color(0.92, 0.95, 0.82))
        _draw_text("%d food" % cost, cr.position + Vector2(12, 54), 16, COL_FOOD)
    _draw_text(message, Vector2(40, 700), 18, Color(0.84, 0.88, 0.74))

func _draw_result() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.45))
    _draw_panel(Rect2(330, 190, 620, 320))
    if result_win:
        _draw_text("VICTORY", Vector2(470, 290), 60, Color(0.70, 0.95, 0.55))
        _draw_text("The enemy den is razed. Your beasts reign.", Vector2(395, 350), 22, Color(0.86, 0.90, 0.78))
    else:
        _draw_text("DEFEAT", Vector2(490, 290), 60, Color(0.95, 0.55, 0.45))
        _draw_text("Your den has fallen. The lane is lost.", Vector2(410, 350), 22, Color(0.90, 0.80, 0.76))
    _draw_button(Rect2(440, 420, 180, 60), "RETRY")
    _draw_button(Rect2(660, 420, 180, 60), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "battle":
            if event.keycode == KEY_1:
                _spawn_player("gatherer")
            elif event.keycode == KEY_2:
                _spawn_player("brawler")
            elif event.keycode == KEY_3:
                _spawn_player("ranged")
            elif event.keycode == KEY_4:
                _try_evolve()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(520, 420, 240, 70).has_point(p):
            mode = "select"
            queue_redraw()
    elif mode == "select":
        var ids := ["lion", "wolf", "rhino"]
        for i in range(ids.size()):
            var btn := Rect2(110 + i * 390 + 70, 450, 180, 44)
            if btn.has_point(p):
                kingdom_id = ids[i]
                _start_battle()
                queue_redraw()
    elif mode == "battle":
        var kinds := ["gatherer", "brawler", "ranged"]
        for i in range(3):
            if Rect2(348 + i * 196, 628, 180, 64).has_point(p):
                _spawn_player(kinds[i])
    elif mode == "result":
        if Rect2(440, 420, 180, 60).has_point(p):
            _start_battle()
            queue_redraw()
        elif Rect2(660, 420, 180, 60).has_point(p):
            mode = "title"
            queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_select.json" <<'EOF'
{
  "duration_frames": 380,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 455},
    {"frame": 90,  "type": "mouse_click", "button": "left", "x": 270, "y": 472},
    {"frame": 150, "type": "key_press", "keycode": "1"},
    {"frame": 200, "type": "key_press", "keycode": "2"},
    {"frame": 260, "type": "key_press", "keycode": "3"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_economy_push.json" <<'EOF'
{
  "scenario": "battle_start",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "1"},
    {"frame": 70,  "type": "key_press", "keycode": "1"},
    {"frame": 140, "type": "key_press", "keycode": "2"},
    {"frame": 220, "type": "key_press", "keycode": "2"},
    {"frame": 300, "type": "key_press", "keycode": "3"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_evolve.json" <<'EOF'
{
  "scenario": "evolved",
  "duration_frames": 440,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "2"},
    {"frame": 120, "type": "key_press", "keycode": "3"},
    {"frame": 220, "type": "key_press", "keycode": "2"},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_victory.json" <<'EOF'
{
  "scenario": "near_victory",
  "duration_frames": 360,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "2"},
    {"frame": 90,  "type": "key_press", "keycode": "2"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_defeat.json" <<'EOF'
{
  "scenario": "near_defeat",
  "duration_frames": 420,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "1"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/06_wolf_kingdom.json" <<'EOF'
{
  "scenario": "wolf_start",
  "duration_frames": 420,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "2"},
    {"frame": 90,  "type": "key_press", "keycode": "2"},
    {"frame": 150, "type": "key_press", "keycode": "3"},
    {"frame": 390, "type": "wait"}
  ]
}
EOF

echo "beastclash oracle generated at $GAME"
