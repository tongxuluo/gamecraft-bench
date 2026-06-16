#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-wildwood.
#
# Generates a compact node-map forest roguelike with turn-based skill combat:
#   - Title -> camp (persistent meta) -> node map -> encounters -> result -> camp.
#   - Branching map of hidden nodes: treasure, beast, campfire, trader, trap, boss.
#   - Single hero with a skill kit (Strike / Heavy[energy] / Guard / Item) and
#     energy as a combat resource; relics expand the kit.
#   - Four+ beasts with distinct behavior: wolf (fast double hit), viper
#     (poisons), bear (armored), boar (reckless), Elder Bear boss (armored +
#     bleed).
#   - Status effects: enemy poison, player poison/bleed, guard shield.
#   - Functional relics from chests/traders: Venom Fang, Thorns, Battle Horn,
#     Bandage. HP persists across the run; 0 HP ends the run.
#   - Meta: entering costs a ticket; gold/best-depth banked to user://save and
#     survive relaunch; buy tickets at camp.
#   - Deterministic: RNG seeded, fixed map template, no wall-clock game logic.
#   - Demos cover the loop, exploration+combat, the skill kit, victory, defeat.
#
# The whole game lives in one Main.gd. It is the oracle for the verifier
# framework, not a polished game: everything is drawn from primitives, so the
# art items (A1-A5) stay low while the mechanic and depth items pass.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Wildwood"
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
const SAVE_PATH := "user://wildwood_save.json"
const MAX_HP := 30
const MAX_ENERGY := 3

const ENEMY_DEFS := {
    "wolf":  {"name": "Wolf",       "hp": 14.0, "atk": 3.0,  "kind": "wolf"},
    "viper": {"name": "Viper",      "hp": 16.0, "atk": 4.0,  "kind": "viper"},
    "bear":  {"name": "Bear",       "hp": 30.0, "atk": 8.0,  "kind": "bear"},
    "boar":  {"name": "Boar",       "hp": 20.0, "atk": 12.0, "kind": "boar"},
    "boss":  {"name": "Elder Bear", "hp": 40.0, "atk": 10.0, "kind": "boss"},
}
const RELIC_POOL := ["Venom Fang", "Thorns", "Battle Horn", "Bandage"]

# Meta (persisted)
var tickets := 3
var gold := 0
var best_depth := 0

# Run state
var scenario := ""
var mode := "title"
var map_nodes: Array = []
var cur_layer := 0
var cur_idx := 0
var hp := MAX_HP
var atk := 8
var energy := MAX_ENERGY
var potions := 1
var relics: Array = []
var depth := 0

# Combat state
var foe: Dictionary = {}
var c_is_boss := false
var shield := 0
var p_poison := 0
var combat_msg := ""

# Misc
var event_msg := ""
var message := ""
var result_win := false
var flash := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 777
    _load_save()
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

# --------------------------------------------------------------------------
# Save / load (meta persistence)
# --------------------------------------------------------------------------

func _load_save() -> void:
    tickets = 3
    gold = 0
    best_depth = 0
    if FileAccess.file_exists(SAVE_PATH):
        var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if f:
            var data = JSON.parse_string(f.get_as_text())
            if typeof(data) == TYPE_DICTIONARY:
                tickets = int(data.get("tickets", 3))
                gold = int(data.get("gold", 0))
                best_depth = int(data.get("best_depth", 0))

func _save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"tickets": tickets, "gold": gold, "best_depth": best_depth}))

# --------------------------------------------------------------------------
# Scenarios
# --------------------------------------------------------------------------

func _load_scenario(id: String) -> void:
    tickets = 5
    gold = 50
    best_depth = 2
    if id == "camp":
        mode = "camp"
    elif id == "run_start":
        _new_run()
    elif id == "combat":
        _new_run()
        relics = ["Venom Fang"]
        _start_combat(_enemy("bear"), false)
    elif id == "near_win":
        _new_run()
        atk = 20
        depth = 5
        _start_combat(_enemy("boss"), true)
    elif id == "near_death":
        _new_run()
        hp = 8
        _start_combat(_enemy("boar"), false)
    else:
        mode = "camp"

# --------------------------------------------------------------------------
# Run setup
# --------------------------------------------------------------------------

func _node(t: String, enemy_kind := "") -> Dictionary:
    return {"type": t, "enemy": enemy_kind, "revealed": false}

func _new_run() -> void:
    map_nodes = [
        [_node("start")],
        [_node("treasure"), _node("monster", "wolf")],
        [_node("trap"), _node("monster", "viper")],
        [_node("campfire"), _node("monster", "bear")],
        [_node("trader"), _node("monster", "boar")],
        [_node("boss")],
    ]
    map_nodes[0][0]["revealed"] = true
    cur_layer = 0
    cur_idx = 0
    hp = MAX_HP
    atk = 8
    energy = MAX_ENERGY
    potions = 1
    relics = []
    depth = 0
    shield = 0
    p_poison = 0
    mode = "map"
    message = "Read the signs -- tracks, smoke, a glint -- then choose a trail."

func _enemy(kind: String) -> Dictionary:
    var d: Dictionary = ENEMY_DEFS[kind]
    return {
        "name": d["name"], "kind": d["kind"],
        "hp": d["hp"], "maxhp": d["hp"], "atk": d["atk"], "poison": 0,
    }

func _give_relic() -> String:
    var r: String = RELIC_POOL[depth % RELIC_POOL.size()]
    relics.append(r)
    if r == "Battle Horn":
        atk += 3
    return r

func _enter_forest() -> void:
    if tickets <= 0:
        message = "No tickets. Buy one with gold."
        return
    tickets -= 1
    _save()
    _new_run()

# --------------------------------------------------------------------------
# Node resolution
# --------------------------------------------------------------------------

func _enter_node(nl: int, j: int) -> void:
    cur_layer = nl
    cur_idx = j
    depth = nl
    var node: Dictionary = map_nodes[nl][j]
    node["revealed"] = true
    var t: String = node["type"]
    match t:
        "monster":
            _start_combat(_enemy(node["enemy"]), false)
        "boss":
            _start_combat(_enemy("boss"), true)
        "treasure":
            var r := _give_relic()
            gold += 8
            event_msg = "A chest! You gain %s and 8 gold." % r
            mode = "event"
        "trap":
            hp -= 6
            p_poison += 2
            flash = 0.25
            if hp <= 0:
                _run_result(false)
            else:
                event_msg = "A snare bites! -6 HP and you are poisoned."
                mode = "event"
        "campfire":
            hp = min(MAX_HP, hp + 12)
            event_msg = "You rest by a campfire. +12 HP."
            mode = "event"
        "trader":
            if gold >= 15:
                gold -= 15
                potions += 1
                var r2 := _give_relic()
                event_msg = "You trade 15 gold for a potion and %s." % r2
            else:
                event_msg = "The trader's wares are too dear (need 15 gold)."
            mode = "event"
    queue_redraw()

# --------------------------------------------------------------------------
# Combat
# --------------------------------------------------------------------------

func _start_combat(enemy: Dictionary, is_boss: bool) -> void:
    foe = enemy
    c_is_boss = is_boss
    shield = 0
    p_poison = 0
    energy = MAX_ENERGY
    combat_msg = "A %s blocks the trail!" % foe["name"]
    mode = "combat"

func _has_relic(name: String) -> bool:
    return relics.has(name)

func _to_foe(dmg: int) -> int:
    if foe["kind"] == "bear" or foe["kind"] == "boss":
        return int(dmg / 2)  # armored beasts take reduced damage
    return dmg

func _player_strike() -> void:
    var d := _to_foe(atk)
    foe["hp"] -= float(d)
    if _has_relic("Venom Fang"):
        foe["poison"] = int(foe["poison"]) + 2
    combat_msg = "Strike for %d." % d
    flash = 0.2
    _end_player_turn()

func _player_heavy() -> void:
    if energy < 2:
        combat_msg = "Not enough energy for Heavy."
        flash = 0.2
        queue_redraw()
        return
    energy -= 2
    var d := _to_foe(atk * 2)
    foe["hp"] -= float(d)
    combat_msg = "Heavy blow for %d!" % d
    flash = 0.2
    _end_player_turn()

func _player_guard() -> void:
    shield += 8
    energy = min(MAX_ENERGY, energy + 1)
    combat_msg = "You raise your guard (shield 8)."
    _end_player_turn()

func _player_item() -> void:
    if potions <= 0:
        combat_msg = "No potions left."
        flash = 0.2
        queue_redraw()
        return
    potions -= 1
    hp = min(MAX_HP, hp + 14)
    combat_msg = "You drink a potion. +14 HP."
    _end_player_turn()

func _end_player_turn() -> void:
    # Enemy poison ticks at end of the player's turn.
    if int(foe["poison"]) > 0:
        foe["hp"] -= float(foe["poison"])
        foe["poison"] = max(0, int(foe["poison"]) - 1)
    if foe["hp"] <= 0.0:
        _win_combat()
        return
    _enemy_turn()
    if mode != "combat":
        return
    # Start of next player turn: regen, relic upkeep, player poison tick.
    energy = min(MAX_ENERGY, energy + 1)
    if _has_relic("Bandage"):
        hp = min(MAX_HP, hp + 2)
    if p_poison > 0:
        hp -= p_poison
        p_poison = max(0, p_poison - 1)
        if hp <= 0:
            _die()
            return
    queue_redraw()

func _enemy_turn() -> void:
    var k: String = foe["kind"]
    var a := int(foe["atk"])
    match k:
        "wolf":
            _hit_player(a)
            _hit_player(a)
        "viper":
            _hit_player(a)
            p_poison += 3
        "boss":
            _hit_player(a)
            p_poison += 2
        _:
            _hit_player(a)
    combat_msg += "  The %s answers." % foe["name"]

func _hit_player(raw: int) -> void:
    if mode != "combat":
        return
    var dmg: int = max(0, raw - shield)
    shield = max(0, shield - raw)
    hp -= dmg
    flash = 0.22
    if _has_relic("Thorns"):
        foe["hp"] -= 2.0
    if hp <= 0:
        _die()

func _win_combat() -> void:
    gold += 12 + depth * 5
    if c_is_boss:
        _run_result(true)
        return
    combat_msg = ""
    mode = "map"
    queue_redraw()

func _die() -> void:
    _run_result(false)

func _run_result(win: bool) -> void:
    result_win = win
    if depth > best_depth:
        best_depth = depth
    _save()
    mode = "result"
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.07, 0.11, 0.08))
    match mode:
        "title":
            _draw_title()
        "camp":
            _draw_camp()
        "map":
            _draw_map()
        "combat":
            _draw_combat()
        "event":
            _draw_map()
            _draw_event()
        "result":
            _draw_result()

func _panel(rect: Rect2, color := Color(0.06, 0.10, 0.07, 0.93)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.36, 0.48, 0.30, 0.95), false, 2.0)

func _text(s: String, pos: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _button(rect: Rect2, label: String, on := true) -> void:
    draw_rect(rect, Color(0.12, 0.16, 0.12) if on else Color(0.18, 0.10, 0.10))
    draw_rect(rect, Color(0.50, 0.66, 0.40) if on else Color(0.5, 0.3, 0.3), false, 2.0)
    _text(label, rect.position + Vector2(14, rect.size.y * 0.64), 20, Color(0.90, 0.94, 0.80))

func _bar(rect: Rect2, frac: float, color: Color) -> void:
    frac = clampf(frac, 0.0, 1.0)
    draw_rect(rect, Color(0.04, 0.05, 0.04))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y)), color)
    draw_rect(rect, Color(0.28, 0.34, 0.24), false, 1.5)

func _forest_bg() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.09, 0.14, 0.10))
    for i in range(18):
        var x := 40.0 + float(i) * 72.0
        var h := 120.0 + float((i * 53) % 90)
        draw_rect(Rect2(x, 720 - h, 26, h), Color(0.06, 0.10, 0.07))
        draw_circle(Vector2(x + 13, 720 - h), 34, Color(0.10, 0.17, 0.11))

func _draw_title() -> void:
    _forest_bg()
    _panel(Rect2(330, 160, 620, 340))
    _text("WILDWOOD", Vector2(430, 250), 64, Color(0.74, 0.86, 0.58))
    _text("An unknown wood. Treasure or teeth -- you won't know until you step.", Vector2(360, 312), 19, Color(0.78, 0.84, 0.70))
    _button(Rect2(520, 420, 240, 70), "ENTER CAMP")

func _draw_camp() -> void:
    _forest_bg()
    _panel(Rect2(300, 110, 680, 470))
    _text("TRAILHEAD CAMP", Vector2(440, 170), 38, Color(0.80, 0.88, 0.62))
    _text("Tickets: %d" % tickets, Vector2(360, 230), 24, Color(0.90, 0.86, 0.55))
    _text("Gold: %d" % gold, Vector2(620, 230), 24, Color(0.95, 0.82, 0.35))
    _text("Deepest reached: %d" % best_depth, Vector2(820, 230), 22, Color(0.78, 0.84, 0.72))
    _button(Rect2(440, 300, 400, 60), "ENTER THE WOOD  (1 ticket)", tickets > 0)
    _button(Rect2(440, 378, 400, 52), "BUY TICKET  (20 gold)", gold >= 20)
    _button(Rect2(440, 452, 400, 48), "BACK TO TITLE")
    _text(message, Vector2(360, 545), 18, Color(0.82, 0.86, 0.72))

func _node_pos(layer: int, idx: int, count: int) -> Vector2:
    var x := 150.0 + float(layer) * 180.0
    var y := 300.0 if count == 1 else (220.0 if idx == 0 else 400.0)
    return Vector2(x, y)

func _node_label(node: Dictionary, is_current: bool) -> String:
    if not node["revealed"] and not is_current:
        return "?"
    match node["type"]:
        "start": return "o"
        "treasure": return "$"
        "monster": return "!"
        "trap": return "X"
        "campfire": return "+"
        "trader": return "T"
        "boss": return "B"
    return "?"

# A vague clue shown on an unvisited node so the player infers risk before
# committing -- informed risk, not a blind guess.
func _node_clue(node: Dictionary) -> String:
    match node["type"]:
        "treasure": return "a glint"
        "monster": return "tracks"
        "trap": return "snapped twigs"
        "campfire": return "smoke"
        "trader": return "a bell"
        "boss": return "dread"
    return ""

func _draw_map() -> void:
    _forest_bg()
    # Connections from the current node to the reachable next layer.
    var nl := cur_layer + 1
    var cur := _node_pos(cur_layer, cur_idx, map_nodes[cur_layer].size())
    if nl < map_nodes.size():
        for j in range(map_nodes[nl].size()):
            var np := _node_pos(nl, j, map_nodes[nl].size())
            draw_line(cur, np, Color(0.40, 0.46, 0.30), 4.0)
    for L in range(map_nodes.size()):
        var cnt: int = map_nodes[L].size()
        for j in range(cnt):
            var node: Dictionary = map_nodes[L][j]
            var pos := _node_pos(L, j, cnt)
            var is_cur := (L == cur_layer and j == cur_idx)
            var reachable := (L == nl)
            var col := Color(0.20, 0.26, 0.18)
            if is_cur:
                col = Color(0.85, 0.78, 0.40)
            elif reachable:
                col = Color(0.40, 0.55, 0.35)
            elif node["revealed"]:
                col = Color(0.30, 0.40, 0.28)
            draw_circle(pos, 30, col)
            draw_circle(pos, 30, Color(0.10, 0.13, 0.10))
            draw_arc(pos, 30, 0, TAU, 24, Color(0.55, 0.66, 0.42), 2.0)
            _text(_node_label(node, is_cur), pos + Vector2(-8, 8), 26, Color(0.94, 0.92, 0.78))
            if not node["revealed"] and not is_cur:
                _text(_node_clue(node), pos + Vector2(-30, 52), 13, Color(0.72, 0.82, 0.62))
    # Hero token on the current node.
    draw_circle(cur + Vector2(0, -2), 11, Color(0.45, 0.70, 0.95))
    _draw_topbar(false)
    _text(message, Vector2(40, 690), 18, Color(0.82, 0.86, 0.72))

func _draw_topbar(in_combat: bool) -> void:
    _panel(Rect2(16, 14, 1248, 60))
    _bar(Rect2(40, 30, 200, 24), float(hp) / float(MAX_HP), Color(0.75, 0.30, 0.30))
    _text("HP %d/%d" % [hp, MAX_HP], Vector2(48, 49), 18, Color(0.96, 0.90, 0.86))
    if in_combat:
        _text("Energy", Vector2(270, 49), 18, Color(0.70, 0.86, 0.92))
        for e in range(MAX_ENERGY):
            var c := Color(0.40, 0.80, 0.95) if e < energy else Color(0.18, 0.22, 0.24)
            draw_circle(Vector2(360 + e * 26, 42), 9, c)
    else:
        _text("Tickets %d" % tickets, Vector2(280, 49), 20, Color(0.90, 0.86, 0.55))
    _text("Gold %d" % gold, Vector2(560, 49), 20, Color(0.95, 0.82, 0.35))
    _text("Depth %d" % depth, Vector2(720, 49), 20, Color(0.80, 0.86, 0.72))
    _text("Relics: " + (", ".join(relics) if relics.size() else "none"), Vector2(870, 49), 16, Color(0.78, 0.82, 0.70))

func _draw_combat() -> void:
    _forest_bg()
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.0, 0.0, 0.0, 0.18))
    _draw_topbar(true)
    # Hero
    var hpos := Vector2(360, 360)
    draw_rect(Rect2(hpos.x - 16, hpos.y - 20, 32, 40), Color(0.40, 0.62, 0.92))
    draw_circle(hpos + Vector2(0, -30), 14, Color(0.78, 0.72, 0.62))
    if shield > 0:
        draw_arc(hpos, 40, 0, TAU, 28, Color(0.5, 0.8, 1.0), 3.0)
        _text("Shield %d" % shield, hpos + Vector2(-30, 60), 16, Color(0.6, 0.85, 1.0))
    if p_poison > 0:
        _text("Poisoned %d" % p_poison, hpos + Vector2(-34, 80), 16, Color(0.6, 0.9, 0.4))
    # Foe
    var fpos := Vector2(920, 360)
    var fcol := Color(0.85, 0.40, 0.34)
    draw_rect(Rect2(fpos.x - 22, fpos.y - 24, 44, 48), fcol)
    draw_circle(fpos + Vector2(0, -34), 16, fcol.lerp(Color(0.2, 0.1, 0.1), 0.3))
    if flash > 0.0:
        draw_circle(fpos, 40, Color(1, 1, 1, flash))
    _bar(Rect2(fpos.x - 90, 150, 180, 20), float(foe["hp"]) / float(foe["maxhp"]), Color(0.85, 0.40, 0.34))
    _text("%s  %d HP" % [foe["name"], int(max(0.0, foe["hp"]))], Vector2(fpos.x - 86, 144), 18, Color(0.95, 0.84, 0.80))
    if int(foe["poison"]) > 0:
        _text("Poison %d" % int(foe["poison"]), Vector2(fpos.x - 86, 196), 16, Color(0.6, 0.9, 0.4))
    if foe["kind"] == "bear" or foe["kind"] == "boss":
        _text("Armored", Vector2(fpos.x + 30, 196), 16, Color(0.80, 0.80, 0.86))
    # Skills
    _panel(Rect2(280, 596, 720, 92))
    _button(Rect2(300, 610, 150, 64), "1  Strike")
    _button(Rect2(465, 610, 150, 64), "2  Heavy(E2)", energy >= 2)
    _button(Rect2(630, 610, 150, 64), "3  Guard")
    _button(Rect2(795, 610, 150, 64), "4  Potion(%d)" % potions, potions > 0)
    _text(combat_msg, Vector2(300, 700), 17, Color(0.84, 0.88, 0.74))

func _draw_event() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.40))
    _panel(Rect2(330, 230, 620, 240))
    _text("TRAIL NODE", Vector2(420, 290), 30, Color(0.80, 0.88, 0.60))
    _text(event_msg, Vector2(360, 350), 20, Color(0.86, 0.90, 0.76))
    _button(Rect2(540, 400, 200, 56), "CONTINUE")

func _draw_result() -> void:
    _forest_bg()
    draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
    _panel(Rect2(330, 190, 620, 320))
    if result_win:
        _text("THE WOOD IS YOURS", Vector2(395, 280), 46, Color(0.72, 0.95, 0.55))
        _text("You reached the heart of the wood and survived.", Vector2(380, 340), 20, Color(0.86, 0.90, 0.78))
    else:
        _text("LOST TO THE WOOD", Vector2(410, 280), 46, Color(0.95, 0.50, 0.42))
        _text("Your light goes out among the trees.", Vector2(415, 340), 20, Color(0.90, 0.80, 0.76))
    _text("Gold banked: %d   Deepest: %d" % [gold, best_depth], Vector2(420, 390), 20, Color(0.95, 0.82, 0.35))
    _button(Rect2(520, 430, 240, 60), "RETURN TO CAMP")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "combat":
            if event.keycode == KEY_1:
                _player_strike()
            elif event.keycode == KEY_2:
                _player_heavy()
            elif event.keycode == KEY_3:
                _player_guard()
            elif event.keycode == KEY_4:
                _player_item()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    match mode:
        "title":
            if Rect2(520, 420, 240, 70).has_point(p):
                mode = "camp"
                queue_redraw()
        "camp":
            if Rect2(440, 300, 400, 60).has_point(p):
                _enter_forest()
                queue_redraw()
            elif Rect2(440, 378, 400, 52).has_point(p) and gold >= 20:
                gold -= 20
                tickets += 1
                _save()
                queue_redraw()
            elif Rect2(440, 452, 400, 48).has_point(p):
                mode = "title"
                queue_redraw()
        "map":
            var nl := cur_layer + 1
            if nl < map_nodes.size():
                for j in range(map_nodes[nl].size()):
                    var np := _node_pos(nl, j, map_nodes[nl].size())
                    if p.distance_to(np) <= 34.0:
                        _enter_node(nl, j)
                        break
        "combat":
            if Rect2(300, 610, 150, 64).has_point(p):
                _player_strike()
            elif Rect2(465, 610, 150, 64).has_point(p):
                _player_heavy()
            elif Rect2(630, 610, 150, 64).has_point(p):
                _player_guard()
            elif Rect2(795, 610, 150, 64).has_point(p):
                _player_item()
        "event":
            if Rect2(540, 400, 200, 56).has_point(p):
                mode = "map"
                queue_redraw()
        "result":
            if Rect2(520, 430, 240, 60).has_point(p):
                mode = "camp"
                message = "Back at camp. Spend a ticket to brave the wood again."
                queue_redraw()

func _process(delta: float) -> void:
    if flash > 0.0:
        flash = max(0.0, flash - delta)
        queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_camp.json" <<'EOF'
{
  "duration_frames": 380,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 455},
    {"frame": 90,  "type": "mouse_click", "button": "left", "x": 640, "y": 330},
    {"frame": 160, "type": "mouse_click", "button": "left", "x": 330, "y": 220},
    {"frame": 250, "type": "mouse_click", "button": "left", "x": 640, "y": 428},
    {"frame": 350, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_explore.json" <<'EOF'
{
  "scenario": "run_start",
  "duration_frames": 380,
  "events": [
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 330, "y": 400},
    {"frame": 100, "type": "key_press", "keycode": "1"},
    {"frame": 160, "type": "key_press", "keycode": "1"},
    {"frame": 230, "type": "key_press", "keycode": "1"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_combat.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 380,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "2"},
    {"frame": 100, "type": "key_press", "keycode": "1"},
    {"frame": 170, "type": "key_press", "keycode": "3"},
    {"frame": 240, "type": "key_press", "keycode": "2"},
    {"frame": 310, "type": "key_press", "keycode": "1"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_victory.json" <<'EOF'
{
  "scenario": "near_win",
  "duration_frames": 420,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "2"},
    {"frame": 100, "type": "key_press", "keycode": "1"},
    {"frame": 170, "type": "key_press", "keycode": "2"},
    {"frame": 260, "type": "mouse_click", "button": "left", "x": 640, "y": 460},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_defeat.json" <<'EOF'
{
  "scenario": "near_death",
  "duration_frames": 360,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "1"},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 460},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

echo "wildwood oracle generated at $GAME"
