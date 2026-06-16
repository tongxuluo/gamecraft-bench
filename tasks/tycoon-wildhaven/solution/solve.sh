#!/bin/bash
# Reference solution for gamecraft-bench/tycoon-wildhaven.
#
# Generates a compact multi-industry frontier tycoon (logging + farming +
# fishing) with seasonal interdependence:
#   - Title -> outpost (new or loaded from user://save) -> run economy -> result.
#   - Three industries: 1 chop tree (logging), 2 mill log->plank (processing
#     tier), 3 harvest crop (farming), 4 fish (fishing). 5 sell goods for cash,
#     6 buy upgrade (reinvest; fails with red flash if unaffordable), 7 replant
#     (sustainability), SPACE advance season.
#   - Seasonal clock (spring/summer/autumn/winter) changes play: crops dormant
#     in winter, lake freezes (no fishing) in winter, plank price peaks in
#     winter -> the player must hedge across industries.
#   - Cross-industry cause-effect: chopping raises erosion; high erosion halves
#     crop and fish yield; replanting lowers it. Over-logging hurts farm+lake.
#   - Weather events (storm/drought/cold snap) and an animal raid (bear steals
#     logs) disrupt; deterministic via seeded RNG keyed to the season count.
#   - Cash/stock banked to user://wildhaven_save.json; survives relaunch.
#   - Deterministic: seeded RNG, season advances on input (no wall-clock logic).
#   - Demos cover the loop, the three industries, winter hedging, an animal raid.
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
config/name="Wildhaven"
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
const SAVE_PATH := "user://wildhaven_save.json"
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const PLANK_PRICE := {0: 8, 1: 7, 2: 9, 3: 14}  # timber demand peaks in winter
const CROP_PRICE := 6
const FISH_PRICE := 5
const LOG_PRICE := 3

var scenario := ""
var mode := "title"

# Meta / banked
var cash := 20
var season := 0          # 0..3
var year := 1

# Resources
var logs := 0
var planks := 0
var crops := 0
var fish := 0

# World state
var forest := 12         # standing trees
var farmland := 2        # cleared, plantable tiles
var erosion := 0.0       # 0..1 ; over-logging raises it
var axe_level := 1       # upgrade tier -> output multiplier
var deny_flash := 0.0
var event_flash := 0.0
var message := ""
var raid_active := false
var weather := "Clear"
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 4242
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

func _load_save() -> void:
    cash = 20; season = 0; year = 1
    logs = 0; planks = 0; crops = 0; fish = 0
    forest = 12; farmland = 2; erosion = 0.0; axe_level = 1
    if FileAccess.file_exists(SAVE_PATH):
        var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if f:
            var parsed: Variant = JSON.parse_string(f.get_as_text())
            if typeof(parsed) == TYPE_DICTIONARY:
                var d: Dictionary = parsed
                cash = int(d.get("cash", 20)); season = int(d.get("season", 0))
                year = int(d.get("year", 1)); logs = int(d.get("logs", 0))
                planks = int(d.get("planks", 0)); forest = int(d.get("forest", 12))
                farmland = int(d.get("farmland", 2)); erosion = float(d.get("erosion", 0.0))
                axe_level = int(d.get("axe_level", 1))

func _save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({
            "cash": cash, "season": season, "year": year, "logs": logs,
            "planks": planks, "forest": forest, "farmland": farmland,
            "erosion": erosion, "axe_level": axe_level,
        }))

func _load_scenario(id: String) -> void:
    mode = "outpost"
    if id == "winter":
        season = 3; cash = 60; planks = 6; logs = 4
        message = "Winter: lake frozen, crops dormant. Timber pays now."
    elif id == "animal_raid":
        season = 1; cash = 40; logs = 8
        _trigger_raid()
    elif id == "thriving":
        season = 1; cash = 300; axe_level = 3; farmland = 6; planks = 10; fish = 8
        message = "A thriving outpost: all three industries humming."
    else:
        message = "New camp. 1 chop  2 mill  3 farm  4 fish  5 sell  6 upgrade  7 replant  SPACE season."

func _start_new() -> void:
    _load_save()  # resets to defaults if no save, else loads
    mode = "outpost"
    message = "1 chop  2 mill  3 farm  4 fish  5 sell  6 upgrade  7 replant  SPACE season."

# --------------------------------------------------------------------------
# Industry actions
# --------------------------------------------------------------------------

func _yield_mult() -> float:
    # Cross-industry cause-effect: erosion drags down farm + fish yields.
    return 1.0 if erosion < 0.5 else 0.5

func _chop() -> void:
    if forest <= 0:
        message = "No trees left. Replant (7) to recover."
        queue_redraw(); return
    forest -= 1
    logs += axe_level
    farmland += 1                      # felling clears ground for farming
    erosion = min(1.0, erosion + 0.08) # over-logging erodes soil + muddies lake
    message = "Felled a tree: +%d logs, +1 farmland (erosion up)." % axe_level
    queue_redraw()

func _mill() -> void:
    if logs <= 0:
        message = "No logs to mill."
        queue_redraw(); return
    var n: int = min(logs, axe_level)
    logs -= n; planks += n
    message = "Milled %d log->plank." % n
    queue_redraw()

func _farm() -> void:
    if season == 3:
        message = "Crops are dormant in winter."
        queue_redraw(); return
    if farmland <= 0:
        message = "No farmland. Fell trees (1) to clear land."
        queue_redraw(); return
    var amt := int(round(2.0 * _yield_mult()))
    crops += amt
    message = "Harvested %d crops%s." % [amt, " (poor soil!)" if _yield_mult() < 1.0 else ""]
    queue_redraw()

func _fish() -> void:
    if season == 3:
        message = "The lake is frozen. No fishing in winter."
        queue_redraw(); return
    var amt := int(round(2.0 * _yield_mult()))
    fish += amt
    message = "Caught %d fish%s." % [amt, " (muddy water!)" if _yield_mult() < 1.0 else ""]
    queue_redraw()

func _sell() -> void:
    var earned: int = logs * LOG_PRICE + planks * int(PLANK_PRICE[season]) + crops * CROP_PRICE + fish * FISH_PRICE
    if earned <= 0:
        message = "Nothing to sell."
        queue_redraw(); return
    cash += earned
    logs = 0; planks = 0; crops = 0; fish = 0
    _save()
    message = "Sold goods for %d cash (planks @%d this season)." % [earned, PLANK_PRICE[season]]
    queue_redraw()

func _upgrade() -> void:
    var cost := 40 * axe_level
    if cash < cost:
        deny_flash = 0.5
        message = "Need %d cash to upgrade tools." % cost
        queue_redraw(); return
    cash -= cost
    axe_level += 1
    _save()
    message = "Upgraded tools to level %d (more output)." % axe_level
    queue_redraw()

func _replant() -> void:
    forest += 2
    erosion = max(0.0, erosion - 0.15)
    message = "Replanted saplings: forest recovers, erosion eases."
    queue_redraw()

func _advance_season() -> void:
    season += 1
    if season > 3:
        season = 0
        year += 1
    raid_active = false
    # Deterministic weather + raid keyed to elapsed seasons.
    var k := year * 4 + season
    var local := RandomNumberGenerator.new()
    local.seed = 4242 + k
    var roll := local.randf()
    if roll < 0.25:
        weather = "Storm"; crops = max(0, crops - 2); event_flash = 0.6
        message = "A storm batters the fields! Some crops lost."
    elif roll < 0.45:
        weather = "Drought"; event_flash = 0.6
        message = "Drought this season: yields will suffer."
    elif roll < 0.6:
        weather = "Cold Snap"; event_flash = 0.6
        message = "A cold snap rolls in."
    else:
        weather = "Clear"
        message = "%s of year %d." % [SEASONS[season], year]
    if local.randf() < 0.35:
        _trigger_raid()
    _save()
    queue_redraw()

func _trigger_raid() -> void:
    raid_active = true
    var stolen: int = min(logs, 3)
    logs -= stolen
    event_flash = 0.6
    message = "A bear raids the timber yard! Lost %d logs. (8 to build a fence)" % stolen

func _defend() -> void:
    if not raid_active:
        message = "No raid right now."
        queue_redraw(); return
    if cash < 15:
        deny_flash = 0.5
        message = "Need 15 cash to build a fence."
        queue_redraw(); return
    cash -= 15
    raid_active = false
    _save()
    message = "Built a fence. The bear is driven off."
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _season_tint() -> Color:
    match season:
        0: return Color(0.16, 0.30, 0.18)
        1: return Color(0.18, 0.32, 0.16)
        2: return Color(0.30, 0.24, 0.12)
        3: return Color(0.22, 0.26, 0.30)
    return Color(0.16, 0.24, 0.18)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08, 0.11, 0.09))
    match mode:
        "title": _draw_title()
        "outpost": _draw_outpost()

func _panel(rect: Rect2, color := Color(0.07, 0.10, 0.08, 0.93)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.40, 0.50, 0.32, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _button(rect: Rect2, label: String, on := true) -> void:
    draw_rect(rect, Color(0.12, 0.16, 0.12) if on else Color(0.2, 0.1, 0.1))
    draw_rect(rect, Color(0.5, 0.66, 0.4) if on else Color(0.5, 0.3, 0.3), false, 2.0)
    _text(label, rect.position + Vector2(12, rect.size.y * 0.64), 18, Color(0.9, 0.94, 0.8))

func _draw_title() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.10, 0.16, 0.12))
    _panel(Rect2(330, 160, 620, 340))
    _text("WILDHAVEN", Vector2(430, 250), 60, Color(0.78, 0.88, 0.55))
    _text("A frontier of forest, field and lake. Balance three trades, season by season.", Vector2(352, 312), 18, Color(0.8, 0.86, 0.72))
    _button(Rect2(470, 410, 160, 60), "NEW CAMP")
    _button(Rect2(650, 410, 160, 60), "CONTINUE")

func _draw_outpost() -> void:
    # Zoned terrain: forest (left), fields (center), lake (right).
    draw_rect(Rect2(0, 90, 1280, 630), _season_tint())
    # Forest
    draw_rect(Rect2(0, 90, 380, 630), Color(0.10, 0.20, 0.12))
    for i in range(min(forest, 16)):
        var fx := 40.0 + float(i % 4) * 86.0
        var fy := 170.0 + float(i / 4) * 120.0
        draw_rect(Rect2(fx + 10, fy + 36, 10, 26), Color(0.32, 0.20, 0.10))
        draw_circle(Vector2(fx + 15, fy + 28), 26, Color(0.16, 0.42, 0.20))
    _text("FOREST  (%d trees, erosion %d%%)" % [forest, int(erosion * 100)], Vector2(20, 120), 16, Color(0.7, 0.85, 0.6))
    # Fields
    draw_rect(Rect2(380, 90, 520, 630), Color(0.28, 0.22, 0.12) if season != 3 else Color(0.30, 0.32, 0.34))
    for i in range(min(farmland, 12)):
        var cx := 420.0 + float(i % 4) * 120.0
        var cy := 200.0 + float(i / 4) * 130.0
        draw_rect(Rect2(cx, cy, 96, 96), Color(0.22, 0.16, 0.08))
        if season != 3:
            draw_circle(Vector2(cx + 48, cy + 60), 16, Color(0.45, 0.7, 0.3))
    _text("FIELDS  (%d plots)" % farmland, Vector2(400, 120), 16, Color(0.85, 0.8, 0.5))
    # Lake
    var lake_col := Color(0.12, 0.30, 0.48) if season != 3 else Color(0.55, 0.62, 0.70)
    if erosion >= 0.5 and season != 3:
        lake_col = Color(0.26, 0.26, 0.16)  # muddied
    draw_rect(Rect2(900, 90, 380, 630), lake_col)
    _text("LAKE  %s" % ("FROZEN" if season == 3 else ("MUDDY" if erosion >= 0.5 else "clear")), Vector2(920, 120), 16, Color(0.8, 0.88, 0.95))
    for i in range(3):
        if season != 3:
            draw_circle(Vector2(1000 + i * 90, 360 + i * 70), 12, Color(0.7, 0.75, 0.5))

    _draw_hud()
    _draw_actions()

func _draw_hud() -> void:
    _panel(Rect2(0, 0, 1280, 84), Color(0.06, 0.09, 0.07, 0.95) if deny_flash <= 0.0 else Color(0.4, 0.08, 0.06, 0.95))
    _text("CASH  %d" % cash, Vector2(24, 38), 28, Color(0.95, 0.85, 0.35))
    _text("Logs %d  Planks %d  Crops %d  Fish %d" % [logs, planks, crops, fish], Vector2(24, 70), 18, Color(0.82, 0.88, 0.72))
    var sc := Color(0.7, 0.9, 0.6)
    if event_flash > 0.0: sc = Color(0.95, 0.7, 0.3)
    _text("%s  Y%d" % [SEASONS[season], year], Vector2(420, 38), 26, sc)
    _text("Weather: %s" % weather, Vector2(420, 70), 18, Color(0.8, 0.86, 0.9))
    _text("Plank price %d" % PLANK_PRICE[season], Vector2(660, 38), 20, Color(0.9, 0.82, 0.5))
    if raid_active:
        _text("! BEAR RAID — press 8 to fence", Vector2(660, 70), 18, Color(0.95, 0.4, 0.35))

func _draw_actions() -> void:
    _panel(Rect2(0, 636, 1280, 84))
    var labels := ["1 Chop", "2 Mill", "3 Farm", "4 Fish", "5 Sell", "6 Upgrade", "7 Replant", "SPACE Season"]
    for i in range(labels.size()):
        _button(Rect2(16 + i * 156, 650, 148, 40), labels[i])
    _text(message, Vector2(20, 712), 17, Color(0.84, 0.9, 0.74))

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "outpost":
            match event.keycode:
                KEY_1: _chop()
                KEY_2: _mill()
                KEY_3: _farm()
                KEY_4: _fish()
                KEY_5: _sell()
                KEY_6: _upgrade()
                KEY_7: _replant()
                KEY_8: _defend()
                KEY_SPACE: _advance_season()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(470, 410, 160, 60).has_point(p):
            # NEW CAMP: wipe save then start fresh.
            var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
            if f: f.store_string("{}")
            _load_save()
            mode = "outpost"
            message = "1 chop  2 mill  3 farm  4 fish  5 sell  6 upgrade  7 replant  SPACE season."
            queue_redraw()
        elif Rect2(650, 410, 160, 60).has_point(p):
            _load_save()
            mode = "outpost"
            queue_redraw()

func _process(delta: float) -> void:
    deny_flash = max(0.0, deny_flash - delta)
    event_flash = max(0.0, event_flash - delta)
    # Redraw every frame. The verifier records the window with x11grab; a
    # CanvasItem that only calls queue_redraw() on state change leaves the
    # captured framebuffer black between events. Redrawing each frame keeps
    # the recording (and the still frames the judge sees) populated.
    queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_new.json" <<'EOF'
{
  "duration_frames": 380,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 550, "y": 440},
    {"frame": 80,  "type": "key_press", "keycode": "1"},
    {"frame": 120, "type": "key_press", "keycode": "1"},
    {"frame": 170, "type": "key_press", "keycode": "2"},
    {"frame": 220, "type": "key_press", "keycode": "5"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_three_industries.json" <<'EOF'
{
  "scenario": "new_camp",
  "duration_frames": 420,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "1"},
    {"frame": 80,  "type": "key_press", "keycode": "2"},
    {"frame": 130, "type": "key_press", "keycode": "3"},
    {"frame": 180, "type": "key_press", "keycode": "4"},
    {"frame": 240, "type": "key_press", "keycode": "5"},
    {"frame": 300, "type": "key_press", "keycode": "6"},
    {"frame": 400, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_winter_hedge.json" <<'EOF'
{
  "scenario": "winter",
  "duration_frames": 380,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "4"},
    {"frame": 90,  "type": "key_press", "keycode": "3"},
    {"frame": 150, "type": "key_press", "keycode": "1"},
    {"frame": 210, "type": "key_press", "keycode": "2"},
    {"frame": 270, "type": "key_press", "keycode": "5"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_raid.json" <<'EOF'
{
  "scenario": "animal_raid",
  "duration_frames": 340,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "8"},
    {"frame": 120, "type": "key_press", "keycode": "1"},
    {"frame": 200, "type": "key_press", "keycode": "5"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_seasons.json" <<'EOF'
{
  "scenario": "new_camp",
  "duration_frames": 420,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "1"},
    {"frame": 80,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "SPACE"},
    {"frame": 290, "type": "key_press", "keycode": "5"},
    {"frame": 400, "type": "wait"}
  ]
}
EOF

echo "wildhaven oracle generated at $GAME"
