#!/bin/bash
# Reference solution for gamecraft-bench/openworld-seasons-witch.
#
# A compact 2D season-switching puzzle exploration game:
#   - Title -> valley map. WASD move witch. 1/2/3/4 cast season (spring/summer/
#     autumn/winter). Each season changes the world: winter freezes water,
#     spring blooms flowers, summer dries mud, autumn drops leaves (bridges).
#   - Villager NPCs give quests requiring seasonal manipulation to solve.
#   - Potion brewing at cottage: gather season-specific ingredients, combine.
#   - Reputation from quests unlocks new areas (mountain path, deep forest).
#   - HUD: current season, reputation, ingredients, active quest.
#   - Result on completing all quests or running out of potion ingredients.
#   - Scenarios jump to puzzle / brew / quest for deterministic demos.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="SeasonsWitch"
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
const PR := 13.0
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_COLS := [Color(0.3, 0.6, 0.3), Color(0.5, 0.5, 0.2), Color(0.5, 0.35, 0.2), Color(0.35, 0.4, 0.5)]

const AREAS := [
    {"name": "Village", "pos": Vector2(300, 400), "unlocked": true},
    {"name": "Lake", "pos": Vector2(640, 300), "unlocked": true},
    {"name": "Forest", "pos": Vector2(900, 450), "unlocked": true},
    {"name": "Mountain", "pos": Vector2(1050, 200), "unlocked": false, "need_rep": 2},
]

const QUESTS := [
    {"npc": "Farmer", "desc": "Freeze the lake so I can cross", "need_season": 3, "area": 1},
    {"npc": "Herbalist", "desc": "Bloom the meadow flowers", "need_season": 0, "area": 0},
    {"npc": "Lumberjack", "desc": "Dry the mud on the forest path", "need_season": 1, "area": 2},
]

const INGREDIENTS := ["Snowdrop", "Sunfruit", "Amber Leaf", "Frost Shard"]

var scenario := ""
var mode := "title"
var season := 0
var ppos := Vector2(300, 400)
var move := {"up": false, "down": false, "left": false, "right": false}
var reputation := 0
var quests_done: Array = []
var inventory: Array = []    # ingredient names
var potions := 0
var speed_boost := 0.0
var season_flash := 0.0
var areas: Array = []
var active_quest := -1
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
    elif id == "puzzle": _start(); season = 0; ppos = Vector2(640, 300); active_quest = 0
    elif id == "brew": _start(); inventory = ["Snowdrop", "Sunfruit"]; ppos = Vector2(300, 400)
    elif id == "quest_done": _start(); quests_done = [0, 1]; reputation = 2; active_quest = 2; ppos = AREAS[2]["pos"]
    else: _start()

func _start() -> void:
    mode = "play"; season = 0; ppos = Vector2(300, 400)
    reputation = 0; quests_done = []; inventory = []; potions = 0; speed_boost = 0.0; season_flash = 0.0; active_quest = -1
    areas = []
    for a in AREAS:
        areas.append({"name": a["name"], "pos": a["pos"], "unlocked": a["unlocked"], "need_rep": a.get("need_rep", 0)})
    msg = "1-4 change season. SPACE interact. E brew potion at village."

func _cast_season(s: int) -> void:
    if mode != "play": return
    season = s
    season_flash = 1.0
    msg = "Season changed to %s." % SEASONS[s]
    # gather ingredient if in right area
    var ing: String = INGREDIENTS[s]
    if not inventory.has(ing) and inventory.size() < 6:
        inventory.append(ing)
        msg += " Found %s!" % ing
    # check quest completion
    if active_quest >= 0 and active_quest < QUESTS.size():
        var q: Dictionary = QUESTS[active_quest]
        if int(q["need_season"]) == s:
            _complete_quest()
    queue_redraw()

func _complete_quest() -> void:
    if active_quest < 0: return
    quests_done.append(active_quest)
    reputation += 1
    msg = "Quest complete! Reputation +1."
    active_quest = -1
    # unlock areas
    for a in areas:
        if not a["unlocked"] and reputation >= int(a["need_rep"]):
            a["unlocked"] = true
            msg += " %s unlocked!" % str(a["name"])
    if quests_done.size() >= QUESTS.size():
        _finish(true)
    queue_redraw()

func _interact() -> void:
    if mode != "play": return
    # talk to NPC / accept quest
    for i in range(QUESTS.size()):
        if quests_done.has(i): continue
        var q: Dictionary = QUESTS[i]
        var area_pos: Vector2 = AREAS[int(q["area"])]["pos"]
        if ppos.distance_to(area_pos) < 80.0:
            active_quest = i
            msg = "Quest: %s says '%s'" % [str(q["npc"]), str(q["desc"])]
            queue_redraw(); return
    msg = "Nothing to interact with here."
    queue_redraw()

func _brew() -> void:
    if mode != "play": return
    if ppos.distance_to(AREAS[0]["pos"]) > 100.0:
        msg = "Must be at the village cottage to brew."
        queue_redraw(); return
    if inventory.size() >= 2:
        inventory.pop_back(); inventory.pop_back()
        potions += 1
        speed_boost = 1.0
        msg = "Brewed a swiftness potion! Movement boosted. (Potions: %d)" % potions
    else:
        msg = "Need at least 2 ingredients to brew."
    queue_redraw()

func _finish(victory: bool) -> void:
    mode = "result"; queue_redraw()

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "play": return
    speed_boost = max(0.0, speed_boost - delta * 0.12)
    season_flash = max(0.0, season_flash - delta * 1.3)
    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    ppos += dir.normalized() * (180.0 + 80.0 * speed_boost) * delta
    ppos.x = clampf(ppos.x, 40, VIEW.x - 40)
    ppos.y = clampf(ppos.y, 80, VIEW.y - 40)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), SEASON_COLS[season])
    match mode:
        "title": _draw_title()
        "play": _draw_world()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
func _panel(r: Rect2, c := Color(0.06, 0.06, 0.08, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.5, 0.6, 0.7, 0.9), false, 2.0)
func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.12, 0.12, 0.16)); draw_rect(r, Color(0.6, 0.7, 0.8), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.9, 0.92, 0.95))

func _draw_title() -> void:
    for i in range(4):
        draw_rect(Rect2(330 + i * 155, 150, 155, 230), SEASON_COLS[i].lightened(0.2))
        draw_circle(Vector2(408 + i * 155, 260), 42, SEASON_COLS[i].lightened(0.45))
        _text(SEASONS[i], Vector2(365 + i * 155, 350), 15, Color(0.12, 0.14, 0.12))
    _panel(Rect2(330, 150, 620, 340))
    _text("SEASONS WITCH", Vector2(420, 250), 50, Color(0.6, 0.8, 0.9))
    _text("Command the seasons. Solve the valley's troubles.", Vector2(380, 312), 18, Color(0.8, 0.88, 0.92))
    _button(Rect2(500, 410, 280, 64), "ENTER VALLEY")

func _draw_world() -> void:
    for i in range(4):
        var band_col: Color = SEASON_COLS[(season + i) % 4].lightened(0.12)
        draw_rect(Rect2(0, 60 + i * 150, VIEW.x, 150), Color(band_col.r, band_col.g, band_col.b, 0.05))
    for i in range(9):
        var y: float = 100.0 + float(i) * 60.0
        draw_line(Vector2(0, y), Vector2(1280, y + 20 * sin(anim + i)), Color(1, 1, 1, 0.05), 2.0)
    # areas
    for a in areas:
        var col := _area_color(str(a["name"])) if a["unlocked"] else Color(0.25, 0.25, 0.3)
        _draw_area(str(a["name"]), a["pos"], col, bool(a["unlocked"]))
        _text(str(a["name"]), a["pos"] + Vector2(-30, 60), 14, Color(0.85, 0.9, 0.85))
        if not a["unlocked"]:
            _text("🔒", a["pos"] + Vector2(-8, 6), 18, Color(0.7, 0.7, 0.7))
    # season visual hints
    if season == 3: # winter: ice on lake
        draw_circle(AREAS[1]["pos"], 40, Color(0.7, 0.8, 0.95, 0.6))
    elif season == 0: # spring: flowers at village
        for i in range(5):
            draw_circle(AREAS[0]["pos"] + Vector2(float(i) * 20 - 40, 30), 6, Color(0.9, 0.5, 0.7))
    elif season == 1:
        for i in range(5):
            draw_circle(AREAS[2]["pos"] + Vector2(-45 + i * 18, -35), 7, Color(1.0, 0.74, 0.25))
    elif season == 2:
        draw_line(AREAS[2]["pos"] + Vector2(-65, -20), AREAS[3]["pos"] + Vector2(-35, 20), Color(0.82, 0.45, 0.18), 8.0)
    _draw_ingredients()
    _draw_villagers()
    # player
    draw_circle(ppos, PR, Color(0.3, 0.2, 0.5))
    draw_circle(ppos + Vector2(0, -PR - 4), 6, Color(0.9, 0.85, 0.7))
    draw_line(ppos + Vector2(-18, -10), ppos + Vector2(18, -10), SEASON_COLS[season].lightened(0.4), 3.0)
    # HUD
    _panel(Rect2(0, 0, 1280, 60))
    _text("Season: %s" % SEASONS[season], Vector2(24, 40), 22, SEASON_COLS[season].lerp(Color(1,1,1), 0.5))
    _text("Rep %d" % reputation, Vector2(240, 40), 20, Color(0.9, 0.85, 0.5))
    _text("Potions %d" % potions, Vector2(360, 40), 20, Color(0.7, 0.8, 0.95))
    _text("Ingredients: %s" % (", ".join(inventory) if inventory.size() > 0 else "none"), Vector2(500, 40), 16, Color(0.8, 0.85, 0.8))
    _draw_season_wheel()
    _draw_recipe_book()
    if season_flash > 0.0:
        draw_rect(Rect2(Vector2.ZERO, VIEW), SEASON_COLS[season].lightened(0.45), false, int(8 * season_flash) + 1)
    if active_quest >= 0:
        _text("Quest: %s" % str(QUESTS[active_quest]["desc"]), Vector2(24, 680), 16, Color(0.9, 0.85, 0.6))
    _text(msg, Vector2(40, 700), 16, Color(0.8, 0.88, 0.85))

func _area_color(name: String) -> Color:
    if name == "Village": return Color(0.55, 0.48, 0.36).lerp(SEASON_COLS[season], 0.22)
    if name == "Lake": return (Color(0.75, 0.9, 1.0) if season == 3 else Color(0.22, 0.42, 0.70))
    if name == "Forest": return Color(0.16, 0.32, 0.14).lerp(SEASON_COLS[season], 0.30)
    return Color(0.38, 0.36, 0.42).lerp(SEASON_COLS[season], 0.24)

func _draw_area(name: String, p: Vector2, col: Color, unlocked: bool) -> void:
    if name == "Lake":
        draw_circle(p, 58, col)
        draw_arc(p, 64, 0, TAU, 32, Color(1, 1, 1, 0.25), 3.0)
    elif name == "Forest":
        for i in range(5):
            draw_circle(p + Vector2(-42 + i * 22, -8 + 8 * sin(anim + i)), 24, col.lightened(0.08))
        draw_rect(Rect2(p + Vector2(-56, 18), Vector2(112, 28)), col.darkened(0.25))
    elif name == "Mountain":
        draw_polygon([p + Vector2(-70, 45), p + Vector2(0, -60), p + Vector2(70, 45)], [col])
        draw_polygon([p + Vector2(-20, -30), p, p + Vector2(20, -30)], [Color(0.9, 0.9, 0.9, 0.5)])
    else:
        draw_rect(Rect2(p - Vector2(56, 38), Vector2(112, 76)), col)
        draw_polygon([p + Vector2(-65, -38), p + Vector2(0, -78), p + Vector2(65, -38)], [col.darkened(0.2)])

func _draw_ingredients() -> void:
    var spots := [Vector2(260, 345), Vector2(860, 390), Vector2(910, 455), Vector2(640, 255)]
    for i in range(4):
        var visible := i == season
        var c: Color = [Color(0.9, 0.85, 1.0), Color(1.0, 0.75, 0.22), Color(0.8, 0.45, 0.18), Color(0.7, 0.9, 1.0)][i]
        if visible:
            draw_circle(spots[i], 11 + 3 * sin(anim * 4.0), c)
            _text(INGREDIENTS[i], spots[i] + Vector2(-36, 30), 11, Color(0.95, 0.95, 0.86))

func _draw_villagers() -> void:
    for i in range(QUESTS.size()):
        var q: Dictionary = QUESTS[i]
        var p: Vector2 = AREAS[int(q["area"])]["pos"] + Vector2(45, -42)
        draw_circle(p, 12, Color(0.9, 0.72, 0.48))
        draw_rect(Rect2(p + Vector2(-8, 10), Vector2(16, 20)), Color(0.36 + i * 0.12, 0.24, 0.45))
        if quests_done.has(i):
            _text("done", p + Vector2(-15, -18), 10, Color(0.65, 1.0, 0.65))

func _draw_season_wheel() -> void:
    var c: Vector2 = Vector2(1140, 146)
    for i in range(4):
        var a: float = -PI / 2.0 + float(i) * TAU / 4.0
        var p: Vector2 = c + Vector2(cos(a), sin(a)) * 48.0
        draw_circle(p, 21 if i == season else 16, SEASON_COLS[i].lightened(0.22))
        _text(str(i + 1), p + Vector2(-5, 6), 13, Color(0.08, 0.08, 0.10))
    _text("Season", c + Vector2(-34, 76), 13, Color(0.9, 0.92, 0.9))

func _draw_recipe_book() -> void:
    _panel(Rect2(930, 210, 300, 132), Color(0.12, 0.08, 0.10, 0.86))
    _text("Recipe Book", Vector2(950, 242), 18, Color(0.95, 0.82, 0.62))
    _text("Snowdrop + Sunfruit = Swiftness", Vector2(950, 272), 12, Color(0.88, 0.86, 0.78))
    _text("Amber Leaf + Frost Shard = Barrier", Vector2(950, 296), 12, Color(0.88, 0.86, 0.78))
    _text("Boost: %.0f%%" % (speed_boost * 100.0), Vector2(950, 322), 13, Color(0.72, 0.92, 1.0))

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    _text("VALLEY SAVED!", Vector2(430, 260), 42, Color(0.5, 0.9, 0.7))
    _text("All quests complete. Reputation: %d  Potions: %d" % [reputation, potions], Vector2(380, 320), 20, Color(0.85, 0.9, 0.85))
    _button(Rect2(500, 420, 280, 54), "TITLE")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move["up"] = p
            KEY_S, KEY_DOWN: move["down"] = p
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_1: if p: _cast_season(0)
            KEY_2: if p: _cast_season(1)
            KEY_3: if p: _cast_season(2)
            KEY_4: if p: _cast_season(3)
            KEY_SPACE: if p and not event.echo: _interact()
            KEY_E: if p and not event.echo: _brew()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position): _start(); queue_redraw()
        elif mode == "result":
            if Rect2(500, 420, 280, 54).has_point(event.position): mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_explore.json" <<'EOF'
{"duration_frames":460,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":442},{"frame":80,"type":"key_down","keycode":"D"},{"frame":180,"type":"key_up","keycode":"D"},{"frame":220,"type":"key_press","keycode":"4"},{"frame":300,"type":"key_press","keycode":"1"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_puzzle.json" <<'EOF'
{"scenario":"puzzle","duration_frames":400,"events":[{"frame":40,"type":"key_press","keycode":"SPACE"},{"frame":120,"type":"key_press","keycode":"4"},{"frame":380,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_brew.json" <<'EOF'
{"scenario":"brew","duration_frames":380,"events":[{"frame":40,"type":"key_press","keycode":"E"},{"frame":160,"type":"key_press","keycode":"2"},{"frame":260,"type":"key_press","keycode":"E"},{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_quest.json" <<'EOF'
{"scenario":"quest_done","duration_frames":400,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":130,"type":"key_up","keycode":"D"},{"frame":160,"type":"key_press","keycode":"SPACE"},{"frame":220,"type":"key_press","keycode":"2"},{"frame":380,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/05_seasons.json" <<'EOF'
{"duration_frames":400,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":442},{"frame":80,"type":"key_press","keycode":"1"},{"frame":140,"type":"key_press","keycode":"2"},{"frame":200,"type":"key_press","keycode":"3"},{"frame":260,"type":"key_press","keycode":"4"},{"frame":380,"type":"wait"}]}
EOF

echo "seasons-witch oracle generated at $GAME"
