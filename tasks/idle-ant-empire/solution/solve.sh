#!/usr/bin/env bash
# Oracle reference implementation for idle-ant-empire.
# Minimal idle ant colony game: assign workers, gather food, unlock ants, prestige.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Idle Ant Empire"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[debug]
gdscript/warnings/untyped_declaration=0
gdscript/warnings/treat_warnings_as_errors=false
PREF

cat > "$GAME_DIR/Main.tscn" << 'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
TSCN

cat > "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT'
extends Node2D

enum GS { TITLE, COLONY, PRESTIGE_CONFIRM }
var state := GS.TITLE

# Resources
var food: float = 0.0
var prestige_count := 0
var prestige_multiplier: float = 1.0

# Ant counts
var total_ants := 10
var gatherers := 5
var builders := 2
var soldiers := 2
var nurses := 1

# Production
var food_per_sec: float = 0.0
var hatch_timer: float = 0.0

# Unlockable ant types
var unlocked_types: Array = []
var ant_types := [
    {"name":"Leaf-Cutter","cost":200.0,"bonus":"food x2","unlocked":false,"color":Color(0.3,0.7,0.2)},
    {"name":"Fire Ant",   "cost":500.0,"bonus":"defence","unlocked":false,"color":Color(0.9,0.3,0.1)},
    {"name":"Flying Ant", "cost":1000.0,"bonus":"explore","unlocked":false,"color":Color(0.5,0.5,0.9)},
    {"name":"Mega Ant",   "cost":5000.0,"bonus":"prod x10","unlocked":false,"color":Color(0.8,0.6,0.1)}
]

# Chambers
var chambers := [
    {"name":"Nursery",      "cost":100.0,"built":true, "color":Color(0.6,0.4,0.2)},
    {"name":"Food Storage", "cost":300.0,"built":false,"color":Color(0.7,0.5,0.1)},
    {"name":"Queen Chamber","cost":800.0,"built":false,"color":Color(0.8,0.3,0.5)}
]

# Seasonal challenge
var challenge_timer: float = 20.0
var challenge_active := false
var challenge_type := ""
var challenge_label: Label

# UI
var title_panel: ColorRect
var colony_panel: ColorRect
var prestige_panel: ColorRect
var hud_label: Label
var food_label: Label
var role_labels: Array = []
var chamber_btns: Array = []
var ant_type_btns: Array = []
var click_label: Label
var click_timer: float = 0.0

var rng := RandomNumberGenerator.new()
var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    if scenario == "colony":
        state = GS.COLONY
        title_panel.visible = false
        colony_panel.visible = true
        food = 150.0
    elif scenario == "prestige":
        state = GS.COLONY
        title_panel.visible = false
        colony_panel.visible = true
        food = 10000.0
        total_ants = 200
        gatherers = 100
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.12, 0.08, 0.04)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Title panel
    title_panel = ColorRect.new()
    title_panel.color = Color(0.08, 0.05, 0.02, 0.97)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "IDLE ANT EMPIRE"
    tl.position = Vector2(340, 160)
    tl.add_theme_font_size_override("font_size", 56)
    tl.modulate = Color(0.8, 0.6, 0.2)
    title_panel.add_child(tl)

    var tl2 := Label.new()
    tl2.text = "Build your colony from a single queen\nto millions of ants!"
    tl2.position = Vector2(380, 260)
    tl2.add_theme_font_size_override("font_size", 24)
    tl2.modulate = Color(0.7, 0.55, 0.3)
    title_panel.add_child(tl2)

    var play_btn := Button.new()
    play_btn.text = "START COLONY"
    play_btn.position = Vector2(490, 380)
    play_btn.size = Vector2(300, 70)
    play_btn.add_theme_font_size_override("font_size", 30)
    play_btn.pressed.connect(_on_start)
    title_panel.add_child(play_btn)

    # Colony panel
    colony_panel = ColorRect.new()
    colony_panel.color = Color(0.1, 0.07, 0.03)
    colony_panel.size = Vector2(1280, 720)
    colony_panel.visible = false
    add_child(colony_panel)

    food_label = Label.new()
    food_label.position = Vector2(20, 10)
    food_label.add_theme_font_size_override("font_size", 28)
    food_label.modulate = Color(0.9, 0.8, 0.3)
    colony_panel.add_child(food_label)

    hud_label = Label.new()
    hud_label.position = Vector2(20, 50)
    hud_label.add_theme_font_size_override("font_size", 18)
    hud_label.modulate = Color(0.7, 0.6, 0.4)
    colony_panel.add_child(hud_label)

    # Click to gather button
    var click_btn := Button.new()
    click_btn.text = "GATHER FOOD (click)"
    click_btn.position = Vector2(20, 90)
    click_btn.size = Vector2(220, 50)
    click_btn.add_theme_font_size_override("font_size", 16)
    click_btn.pressed.connect(_on_click_gather)
    colony_panel.add_child(click_btn)

    click_label = Label.new()
    click_label.position = Vector2(250, 100)
    click_label.add_theme_font_size_override("font_size", 20)
    click_label.modulate = Color(0.9, 0.9, 0.3)
    click_label.visible = false
    colony_panel.add_child(click_label)

    # Role assignment
    var role_title := Label.new()
    role_title.text = "ANT ROLES"
    role_title.position = Vector2(20, 160)
    role_title.add_theme_font_size_override("font_size", 20)
    role_title.modulate = Color(0.8, 0.6, 0.2)
    colony_panel.add_child(role_title)

    var roles := ["Gatherers","Builders","Soldiers","Nurses"]
    var role_colors := [Color(0.3,0.8,0.3),Color(0.6,0.4,0.2),Color(0.9,0.3,0.2),Color(0.8,0.6,0.8)]
    for i in range(4):
        var lbl := Label.new()
        lbl.position = Vector2(20, 190 + i * 40)
        lbl.add_theme_font_size_override("font_size", 16)
        lbl.modulate = role_colors[i]
        colony_panel.add_child(lbl)
        role_labels.append(lbl)

        var plus_btn := Button.new()
        plus_btn.text = "+"
        plus_btn.position = Vector2(220, 188 + i * 40)
        plus_btn.size = Vector2(36, 30)
        plus_btn.pressed.connect(_on_role_plus.bind(i))
        colony_panel.add_child(plus_btn)

        var minus_btn := Button.new()
        minus_btn.text = "-"
        minus_btn.position = Vector2(260, 188 + i * 40)
        minus_btn.size = Vector2(36, 30)
        minus_btn.pressed.connect(_on_role_minus.bind(i))
        colony_panel.add_child(minus_btn)

    # Chambers
    var ch_title := Label.new()
    ch_title.text = "CHAMBERS"
    ch_title.position = Vector2(20, 360)
    ch_title.add_theme_font_size_override("font_size", 20)
    ch_title.modulate = Color(0.8, 0.6, 0.2)
    colony_panel.add_child(ch_title)

    for i in range(chambers.size()):
        var btn := Button.new()
        btn.position = Vector2(20, 390 + i * 55)
        btn.size = Vector2(280, 46)
        btn.add_theme_font_size_override("font_size", 15)
        btn.pressed.connect(_on_build_chamber.bind(i))
        colony_panel.add_child(btn)
        chamber_btns.append(btn)

    # Ant types
    var at_title := Label.new()
    at_title.text = "ANT TYPES"
    at_title.position = Vector2(340, 160)
    at_title.add_theme_font_size_override("font_size", 20)
    at_title.modulate = Color(0.8, 0.6, 0.2)
    colony_panel.add_child(at_title)

    for i in range(ant_types.size()):
        var btn := Button.new()
        btn.position = Vector2(340, 190 + i * 60)
        btn.size = Vector2(300, 50)
        btn.add_theme_font_size_override("font_size", 15)
        btn.pressed.connect(_on_unlock_ant.bind(i))
        colony_panel.add_child(btn)
        ant_type_btns.append(btn)

    # Colony cross-section visual
    var colony_bg := ColorRect.new()
    colony_bg.color = Color(0.18, 0.12, 0.06)
    colony_bg.position = Vector2(680, 150)
    colony_bg.size = Vector2(560, 520)
    colony_panel.add_child(colony_bg)

    var colony_lbl := Label.new()
    colony_lbl.text = "COLONY CROSS-SECTION"
    colony_lbl.position = Vector2(700, 160)
    colony_lbl.add_theme_font_size_override("font_size", 16)
    colony_lbl.modulate = Color(0.7, 0.55, 0.3)
    colony_panel.add_child(colony_lbl)

    # Prestige button
    var prestige_btn := Button.new()
    prestige_btn.text = "PRESTIGE (reset + bonus)"
    prestige_btn.position = Vector2(20, 620)
    prestige_btn.size = Vector2(300, 55)
    prestige_btn.add_theme_font_size_override("font_size", 18)
    prestige_btn.modulate = Color(1.0, 0.8, 0.2)
    prestige_btn.pressed.connect(_on_prestige)
    colony_panel.add_child(prestige_btn)

    # Challenge label
    challenge_label = Label.new()
    challenge_label.position = Vector2(680, 680)
    challenge_label.add_theme_font_size_override("font_size", 18)
    challenge_label.modulate = Color(1.0, 0.4, 0.2)
    challenge_label.visible = false
    colony_panel.add_child(challenge_label)

    # Prestige confirm panel
    prestige_panel = ColorRect.new()
    prestige_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    prestige_panel.size = Vector2(700, 380)
    prestige_panel.position = Vector2(290, 170)
    prestige_panel.visible = false
    add_child(prestige_panel)

    var pl := Label.new()
    pl.text = "PRESTIGE — RESET COLONY"
    pl.position = Vector2(150, 30)
    pl.add_theme_font_size_override("font_size", 28)
    pl.modulate = Color(1.0, 0.8, 0.2)
    prestige_panel.add_child(pl)

    var pl2 := Label.new()
    pl2.name = "PrestigeInfo"
    pl2.position = Vector2(50, 90)
    pl2.add_theme_font_size_override("font_size", 20)
    pl2.modulate = Color(0.9, 0.85, 0.6)
    prestige_panel.add_child(pl2)

    var confirm_btn := Button.new()
    confirm_btn.text = "CONFIRM PRESTIGE"
    confirm_btn.position = Vector2(100, 260)
    confirm_btn.size = Vector2(220, 55)
    confirm_btn.add_theme_font_size_override("font_size", 18)
    confirm_btn.pressed.connect(_do_prestige)
    prestige_panel.add_child(confirm_btn)

    var cancel_btn := Button.new()
    cancel_btn.text = "Cancel"
    cancel_btn.position = Vector2(380, 260)
    cancel_btn.size = Vector2(160, 55)
    cancel_btn.pressed.connect(func(): prestige_panel.visible = false)
    prestige_panel.add_child(cancel_btn)

func _on_start() -> void:
    title_panel.visible = false
    colony_panel.visible = true
    state = GS.COLONY

func _on_click_gather() -> void:
    var bonus: float = 5.0 * prestige_multiplier
    food += bonus
    click_label.text = "+%.0f" % bonus
    click_label.visible = true
    click_timer = 1.0

func _get_role_count(idx: int) -> int:
    match idx:
        0: return gatherers
        1: return builders
        2: return soldiers
        3: return nurses
    return 0

func _set_role_count(idx: int, val: int) -> void:
    match idx:
        0: gatherers = val
        1: builders = val
        2: soldiers = val
        3: nurses = val

func _on_role_plus(idx: int) -> void:
    var cur := _get_role_count(idx)
    var used := gatherers + builders + soldiers + nurses
    if used < total_ants:
        _set_role_count(idx, cur + 1)

func _on_role_minus(idx: int) -> void:
    var cur := _get_role_count(idx)
    if cur > 0:
        _set_role_count(idx, cur - 1)

func _on_build_chamber(idx: int) -> void:
    var ch: Dictionary = chambers[idx]
    if bool(ch["built"]): return
    if food >= float(ch["cost"]):
        food -= float(ch["cost"])
        ch["built"] = true

func _on_unlock_ant(idx: int) -> void:
    var at: Dictionary = ant_types[idx]
    if bool(at["unlocked"]): return
    if food >= float(at["cost"]):
        food -= float(at["cost"])
        at["unlocked"] = true
        total_ants += 10

func _on_prestige() -> void:
    var info_lbl: Label = prestige_panel.get_node("PrestigeInfo")
    var next_mult: float = prestige_multiplier * 1.5
    info_lbl.text = "Current multiplier: x%.1f\nAfter prestige: x%.1f\n\nYour colony resets but gains:\n- Queen fertility +50%%\n- Gathering speed x%.1f\n- Defence strength +25%%" % [prestige_multiplier, next_mult, next_mult]
    prestige_panel.visible = true

func _do_prestige() -> void:
    prestige_panel.visible = false
    prestige_count += 1
    prestige_multiplier *= 1.5
    food = 0.0
    total_ants = 10
    gatherers = 5; builders = 2; soldiers = 2; nurses = 1
    for at in ant_types: at["unlocked"] = false
    for ch in chambers: ch["built"] = (ch["name"] == "Nursery")

func _process(delta: float) -> void:
    if state != GS.COLONY:
        return

    # Food production
    var leaf_bonus: float = 2.0 if bool(ant_types[0]["unlocked"]) else 1.0
    var mega_bonus: float = 10.0 if bool(ant_types[3]["unlocked"]) else 1.0
    food_per_sec = float(gatherers) * 1.2 * prestige_multiplier * leaf_bonus * mega_bonus
    food += food_per_sec * delta

    # Hatch new ants (nurses)
    hatch_timer -= delta
    if hatch_timer <= 0.0:
        hatch_timer = max(5.0, 10.0 - float(nurses))
        if nurses > 0:
            total_ants += nurses

    # Click label fade
    if click_timer > 0.0:
        click_timer -= delta
        if click_timer <= 0.0:
            click_label.visible = false

    # Seasonal challenge
    challenge_timer -= delta
    if challenge_timer <= 0.0 and not challenge_active:
        challenge_timer = rng.randf_range(15.0, 25.0)
        challenge_active = true
        var challenges := ["RAIN: Deploy builders! (need 3+)", "PREDATOR: Deploy soldiers! (need 3+)", "WINTER: Food reserves low!"]
        challenge_type = challenges[rng.randi_range(0, challenges.size()-1)]
        challenge_label.text = "CHALLENGE: " + challenge_type
        challenge_label.visible = true
        get_tree().create_timer(8.0).timeout.connect(_resolve_challenge)

    _refresh_ui()
    queue_redraw()

func _resolve_challenge() -> void:
    challenge_active = false
    challenge_label.visible = false
    var bonus: float = 50.0 * prestige_multiplier
    food += bonus

func _format_num(n: float) -> String:
    if n >= 1000000000.0: return "%.1fB" % (n / 1000000000.0)
    if n >= 1000000.0: return "%.1fM" % (n / 1000000.0)
    if n >= 1000.0: return "%.1fK" % (n / 1000.0)
    return "%.0f" % n

func _refresh_ui() -> void:
    food_label.text = "FOOD: %s  (+%s/s)" % [_format_num(food), _format_num(food_per_sec)]
    hud_label.text = "Ants: %d  |  Prestige: %d  |  Multiplier: x%.1f" % [total_ants, prestige_count, prestige_multiplier]

    var role_names := ["Gatherers","Builders","Soldiers","Nurses"]
    var role_vals := [gatherers, builders, soldiers, nurses]
    for i in range(4):
        role_labels[i].text = "%s: %d" % [role_names[i], role_vals[i]]

    for i in range(chambers.size()):
        var ch: Dictionary = chambers[i]
        if bool(ch["built"]):
            chamber_btns[i].text = "[BUILT] %s" % str(ch["name"])
        else:
            chamber_btns[i].text = "Build %s (%s food)" % [str(ch["name"]), _format_num(float(ch["cost"]))]

    for i in range(ant_types.size()):
        var at: Dictionary = ant_types[i]
        if bool(at["unlocked"]):
            ant_type_btns[i].text = "[UNLOCKED] %s — %s" % [str(at["name"]), str(at["bonus"])]
        else:
            ant_type_btns[i].text = "Unlock %s (%s food) — %s" % [str(at["name"]), _format_num(float(at["cost"])), str(at["bonus"])]

func _draw() -> void:
    if state != GS.COLONY:
        return

    # Draw colony cross-section
    var ox: float = 690.0
    var oy: float = 200.0

    # Tunnels
    draw_rect(Rect2(ox, oy, 540.0, 460.0), Color(0.22, 0.15, 0.08))

    # Draw chambers
    var ch_positions := [Vector2(ox+20, oy+20), Vector2(ox+200, oy+20), Vector2(ox+380, oy+20)]
    var ch_sizes := [Vector2(160, 100), Vector2(160, 100), Vector2(140, 100)]
    for i in range(chambers.size()):
        var ch: Dictionary = chambers[i]
        var col: Color = ch["color"] if bool(ch["built"]) else Color(0.15, 0.1, 0.05)
        draw_rect(Rect2(ch_positions[i], ch_sizes[i]), col)
        draw_string(ThemeDB.fallback_font, ch_positions[i] + Vector2(5, 20), str(ch["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.8, 0.5))

    # Draw ants moving
    var ant_count: int = min(total_ants, 20)
    for i in range(ant_count):
        var t: float = fmod(float(i) * 0.3 + Time.get_ticks_msec() * 0.001, 1.0)
        var ax: float = ox + 20.0 + t * 500.0
        var ay: float = oy + 140.0 + float(i % 5) * 30.0
        var ant_col := Color(0.1, 0.08, 0.04)
        if i < ant_types.size() and bool(ant_types[i]["unlocked"]):
            ant_col = ant_types[i]["color"]
        draw_circle(Vector2(ax, ay), 5.0, ant_col)

    # Draw food counter in colony
    draw_string(ThemeDB.fallback_font, Vector2(ox+10, oy+440), "Food: %s" % _format_num(food), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.8, 0.3))
    draw_string(ThemeDB.fallback_font, Vector2(ox+10, oy+465), "Ants: %d  Prestige x%.1f" % [total_ants, prestige_multiplier], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.6, 0.4))
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":415}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_colony.json" << 'DEMO'
{"scenario":"colony","duration_frames":540,"events":[
  {"frame":30,"type":"mouse_click","button":"left","x":130,"y":115},
  {"frame":60,"type":"mouse_click","button":"left","x":237,"y":193},
  {"frame":90,"type":"mouse_click","button":"left","x":237,"y":233},
  {"frame":120,"type":"mouse_click","button":"left","x":130,"y":115},
  {"frame":150,"type":"mouse_click","button":"left","x":130,"y":115},
  {"frame":180,"type":"mouse_click","button":"left","x":160,"y":413},
  {"frame":240,"type":"mouse_click","button":"left","x":490,"y":250},
  {"frame":300,"type":"mouse_click","button":"left","x":130,"y":115},
  {"frame":360,"type":"mouse_click","button":"left","x":130,"y":115},
  {"frame":420,"type":"mouse_click","button":"left","x":130,"y":115},
  {"frame":480,"type":"wait"}
]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_prestige.json" << 'DEMO'
{"scenario":"prestige","duration_frames":360,"events":[
  {"frame":60,"type":"mouse_click","button":"left","x":170,"y":648},
  {"frame":150,"type":"mouse_click","button":"left","x":210,"y":287},
  {"frame":240,"type":"wait"},
  {"frame":300,"type":"mouse_click","button":"left","x":130,"y":115}
]}
DEMO

echo "Oracle written to $GAME_DIR"
