#!/usr/bin/env bash
# Oracle reference implementation for idle-factory-planet.
# Minimal idle factory game: place machines, build chains, research, prestige.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Idle Factory Planet"
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

enum GS { TITLE, PLANET, RESEARCH, PRESTIGE_CONFIRM }
var state := GS.TITLE

# Grid
const COLS := 8
const ROWS := 5
const CELL := 80
const GRID_OX := 20.0
const GRID_OY := 120.0

var grid: Array = []  # each cell: null or machine dict

# Machine types
var machine_types := [
    {"id":"miner",     "name":"Miner",     "color":Color(0.5,0.4,0.3),"produces":"ore",   "consumes":"",     "rate":1.0, "cost":50.0},
    {"id":"smelter",   "name":"Smelter",   "color":Color(0.7,0.4,0.2),"produces":"metal", "consumes":"ore",  "rate":0.8, "cost":150.0},
    {"id":"fabricator","name":"Fabricator","color":Color(0.3,0.5,0.7),"produces":"parts", "consumes":"metal","rate":0.5, "cost":400.0},
    {"id":"seller",    "name":"Seller",    "color":Color(0.3,0.7,0.3),"produces":"credits","consumes":"parts","rate":0.3, "cost":1000.0}
]
var selected_machine_type := 0

# Resources
var ore: float = 0.0
var metal: float = 0.0
var parts: float = 0.0
var credits: float = 0.0
var credits_per_sec: float = 0.0

# Planet depletion
var ore_reserve: float = 1000.0
var ore_max: float = 1000.0

# Research
var research_items := [
    {"name":"Fast Miner",    "cost":200.0,"effect":"miner rate x2",  "done":false},
    {"name":"Multi Smelter", "cost":500.0,"effect":"smelter rate x2","done":false},
    {"name":"Storage Buffer","cost":800.0,"effect":"buffer +100",     "done":false}
]

# Prestige
var prestige_count := 0
var prestige_multiplier: float = 1.0

# UI
var title_panel: ColorRect
var planet_panel: ColorRect
var research_panel: ColorRect
var prestige_panel: ColorRect
var hud_label: Label
var machine_btns: Array = []
var research_btns: Array = []
var depletion_fill: ColorRect
var rate_label: Label

var rng := RandomNumberGenerator.new()
var scenario := ""
var prod_timer: float = 0.0

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _init_grid()
    _build_ui()
    if scenario == "factory":
        state = GS.PLANET
        title_panel.visible = false
        planet_panel.visible = true
        credits = 200.0
        _place_machine(0, 0, 0)
        _place_machine(2, 0, 1)
        _place_machine(4, 0, 2)
        _place_machine(6, 0, 3)
    elif scenario == "prestige":
        state = GS.PLANET
        title_panel.visible = false
        planet_panel.visible = true
        credits = 2000.0
        ore_reserve = 50.0
    else:
        state = GS.TITLE
        title_panel.visible = true

func _init_grid() -> void:
    grid.clear()
    for r in range(ROWS):
        var row: Array = []
        for c in range(COLS):
            row.append(null)
        grid.append(row)

func _place_machine(col: int, row: int, type_idx: int) -> void:
    if col >= COLS or row >= ROWS: return
    grid[row][col] = {"type": type_idx, "timer": 0.0, "active": true}

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.08, 0.08, 0.12)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.05, 0.05, 0.08, 0.97)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "IDLE FACTORY PLANET"
    tl.position = Vector2(280, 160)
    tl.add_theme_font_size_override("font_size", 52)
    tl.modulate = Color(0.7, 0.8, 0.9)
    title_panel.add_child(tl)

    var tl2 := Label.new()
    tl2.text = "Place machines. Build production chains.\nResearch upgrades. Deplete the planet. Prestige!"
    tl2.position = Vector2(320, 270)
    tl2.add_theme_font_size_override("font_size", 22)
    tl2.modulate = Color(0.6, 0.7, 0.8)
    title_panel.add_child(tl2)

    var play_btn := Button.new()
    play_btn.text = "LAND ON PLANET"
    play_btn.position = Vector2(490, 390)
    play_btn.size = Vector2(300, 70)
    play_btn.add_theme_font_size_override("font_size", 28)
    play_btn.pressed.connect(_on_start)
    title_panel.add_child(play_btn)

    # Planet panel
    planet_panel = ColorRect.new()
    planet_panel.color = Color(0.06, 0.06, 0.1)
    planet_panel.size = Vector2(1280, 720)
    planet_panel.visible = false
    add_child(planet_panel)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 8)
    hud_label.add_theme_font_size_override("font_size", 18)
    hud_label.modulate = Color(0.8, 0.85, 0.9)
    planet_panel.add_child(hud_label)

    # Depletion bar
    var dep_bg := ColorRect.new()
    dep_bg.color = Color(0.2, 0.1, 0.1)
    dep_bg.position = Vector2(10, 36)
    dep_bg.size = Vector2(300, 18)
    planet_panel.add_child(dep_bg)

    depletion_fill = ColorRect.new()
    depletion_fill.color = Color(0.6, 0.4, 0.2)
    depletion_fill.position = Vector2(10, 36)
    depletion_fill.size = Vector2(300, 18)
    planet_panel.add_child(depletion_fill)

    var dep_lbl := Label.new()
    dep_lbl.text = "ORE RESERVE"
    dep_lbl.position = Vector2(320, 36)
    dep_lbl.add_theme_font_size_override("font_size", 14)
    dep_lbl.modulate = Color(0.7, 0.6, 0.4)
    planet_panel.add_child(dep_lbl)

    rate_label = Label.new()
    rate_label.position = Vector2(10, 58)
    rate_label.add_theme_font_size_override("font_size", 14)
    rate_label.modulate = Color(0.6, 0.8, 0.6)
    planet_panel.add_child(rate_label)

    # Machine selector
    var ms_lbl := Label.new()
    ms_lbl.text = "SELECT MACHINE:"
    ms_lbl.position = Vector2(700, 120)
    ms_lbl.add_theme_font_size_override("font_size", 16)
    ms_lbl.modulate = Color(0.8, 0.85, 0.9)
    planet_panel.add_child(ms_lbl)

    for i in range(machine_types.size()):
        var mt: Dictionary = machine_types[i]
        var btn := Button.new()
        btn.text = "%s (cost:%.0f)" % [str(mt["name"]), float(mt["cost"])]
        btn.position = Vector2(700, 145 + i * 50)
        btn.size = Vector2(280, 42)
        btn.add_theme_font_size_override("font_size", 14)
        btn.pressed.connect(_on_select_machine.bind(i))
        planet_panel.add_child(btn)
        machine_btns.append(btn)

    # Research button
    var res_btn := Button.new()
    res_btn.text = "RESEARCH LAB"
    res_btn.position = Vector2(700, 380)
    res_btn.size = Vector2(280, 50)
    res_btn.add_theme_font_size_override("font_size", 18)
    res_btn.pressed.connect(_on_open_research)
    planet_panel.add_child(res_btn)

    # Prestige button
    var prestige_btn := Button.new()
    prestige_btn.text = "PRESTIGE (new planet)"
    prestige_btn.position = Vector2(700, 450)
    prestige_btn.size = Vector2(280, 50)
    prestige_btn.add_theme_font_size_override("font_size", 16)
    prestige_btn.modulate = Color(1.0, 0.85, 0.2)
    prestige_btn.pressed.connect(_on_prestige)
    planet_panel.add_child(prestige_btn)

    # Research panel
    research_panel = ColorRect.new()
    research_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    research_panel.size = Vector2(700, 400)
    research_panel.position = Vector2(290, 160)
    research_panel.visible = false
    add_child(research_panel)

    var rp_title := Label.new()
    rp_title.text = "RESEARCH LAB"
    rp_title.position = Vector2(230, 20)
    rp_title.add_theme_font_size_override("font_size", 28)
    rp_title.modulate = Color(0.7, 0.8, 0.9)
    research_panel.add_child(rp_title)

    for i in range(research_items.size()):
        var ri: Dictionary = research_items[i]
        var btn := Button.new()
        btn.position = Vector2(50, 80 + i * 70)
        btn.size = Vector2(600, 55)
        btn.add_theme_font_size_override("font_size", 18)
        btn.pressed.connect(_on_research.bind(i))
        research_panel.add_child(btn)
        research_btns.append(btn)

    var rp_close := Button.new()
    rp_close.text = "Close"
    rp_close.position = Vector2(280, 330)
    rp_close.size = Vector2(140, 45)
    rp_close.pressed.connect(func(): research_panel.visible = false)
    research_panel.add_child(rp_close)

    # Prestige panel
    prestige_panel = ColorRect.new()
    prestige_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    prestige_panel.size = Vector2(700, 360)
    prestige_panel.position = Vector2(290, 180)
    prestige_panel.visible = false
    add_child(prestige_panel)

    var pp_title := Label.new()
    pp_title.text = "PRESTIGE — NEW PLANET"
    pp_title.position = Vector2(150, 25)
    pp_title.add_theme_font_size_override("font_size", 26)
    pp_title.modulate = Color(1.0, 0.85, 0.2)
    prestige_panel.add_child(pp_title)

    var pp_info := Label.new()
    pp_info.name = "PrestigeInfo"
    pp_info.position = Vector2(50, 80)
    pp_info.size = Vector2(600, 160)
    pp_info.add_theme_font_size_override("font_size", 18)
    pp_info.modulate = Color(0.85, 0.8, 0.6)
    pp_info.autowrap_mode = TextServer.AUTOWRAP_WORD
    prestige_panel.add_child(pp_info)

    var pp_confirm := Button.new()
    pp_confirm.text = "MOVE TO NEW PLANET"
    pp_confirm.position = Vector2(80, 270)
    pp_confirm.size = Vector2(240, 55)
    pp_confirm.pressed.connect(_do_prestige)
    prestige_panel.add_child(pp_confirm)

    var pp_cancel := Button.new()
    pp_cancel.text = "Cancel"
    pp_cancel.position = Vector2(380, 270)
    pp_cancel.size = Vector2(160, 55)
    pp_cancel.pressed.connect(func(): prestige_panel.visible = false)
    prestige_panel.add_child(pp_cancel)

func _on_start() -> void:
    title_panel.visible = false
    planet_panel.visible = true
    state = GS.PLANET

func _on_select_machine(idx: int) -> void:
    selected_machine_type = idx

func _on_open_research() -> void:
    _refresh_research()
    research_panel.visible = true

func _on_research(idx: int) -> void:
    var ri: Dictionary = research_items[idx]
    if bool(ri["done"]): return
    if credits >= float(ri["cost"]):
        credits -= float(ri["cost"])
        ri["done"] = true
        if idx == 0:
            machine_types[0]["rate"] = float(machine_types[0]["rate"]) * 2.0
        elif idx == 1:
            machine_types[1]["rate"] = float(machine_types[1]["rate"]) * 2.0
    _refresh_research()

func _on_prestige() -> void:
    var pp_info: Label = prestige_panel.get_node("PrestigeInfo")
    var next_mult: float = prestige_multiplier * 1.5
    pp_info.text = "Move to a fresh planet with more ore.\nKeep all research progress.\nGain permanent production multiplier:\nx%.1f -> x%.1f\n\nPlanet %d -> %d" % [prestige_multiplier, next_mult, prestige_count+1, prestige_count+2]
    prestige_panel.visible = true

func _do_prestige() -> void:
    prestige_panel.visible = false
    prestige_count += 1
    prestige_multiplier *= 1.5
    ore_reserve = ore_max * (1.0 + float(prestige_count) * 0.5)
    ore_max = ore_reserve
    ore = 0.0; metal = 0.0; parts = 0.0
    _init_grid()

func _input(event: InputEvent) -> void:
    if state != GS.PLANET: return
    if research_panel.visible or prestige_panel.visible: return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mp: Vector2 = event.position
        var col: int = int((mp.x - GRID_OX) / CELL)
        var row: int = int((mp.y - GRID_OY) / CELL)
        if col >= 0 and col < COLS and row >= 0 and row < ROWS:
            var mt: Dictionary = machine_types[selected_machine_type]
            if credits >= float(mt["cost"]) and grid[row][col] == null:
                credits -= float(mt["cost"])
                _place_machine(col, row, selected_machine_type)

func _process(delta: float) -> void:
    if state != GS.PLANET: return
    prod_timer += delta
    if prod_timer >= 1.0:
        prod_timer -= 1.0
        _tick_production()
    _refresh_ui()
    queue_redraw()

func _tick_production() -> void:
    var miner_rate: float = float(machine_types[0]["rate"]) * prestige_multiplier
    var smelt_rate: float = float(machine_types[1]["rate"]) * prestige_multiplier
    var fab_rate: float = float(machine_types[2]["rate"]) * prestige_multiplier
    var sell_rate: float = float(machine_types[3]["rate"]) * prestige_multiplier

    var miner_count := 0
    var smelter_count := 0
    var fab_count := 0
    var seller_count := 0
    for r in range(ROWS):
        for c in range(COLS):
            if grid[r][c] != null:
                match int(grid[r][c]["type"]):
                    0: miner_count += 1
                    1: smelter_count += 1
                    2: fab_count += 1
                    3: seller_count += 1

    var ore_produced: float = float(miner_count) * miner_rate
    if ore_reserve > 0.0:
        var actual: float = minf(ore_produced, ore_reserve)
        ore += actual
        ore_reserve -= actual

    var smelt_possible: float = minf(float(smelter_count) * smelt_rate, ore)
    ore -= smelt_possible
    metal += smelt_possible

    var fab_possible: float = minf(float(fab_count) * fab_rate, metal)
    metal -= fab_possible
    parts += fab_possible

    var sell_possible: float = minf(float(seller_count) * sell_rate, parts)
    parts -= sell_possible
    credits_per_sec = sell_possible * 10.0 * prestige_multiplier
    credits += credits_per_sec

func _format_num(n: float) -> String:
    if n >= 1000000000.0: return "%.1fB" % (n / 1000000000.0)
    if n >= 1000000.0: return "%.1fM" % (n / 1000000.0)
    if n >= 1000.0: return "%.1fK" % (n / 1000.0)
    return "%.1f" % n

func _refresh_ui() -> void:
    hud_label.text = "Credits: %s  |  Prestige: %d  |  Mult: x%.1f  |  Ore:%s Metal:%s Parts:%s" % [_format_num(credits), prestige_count, prestige_multiplier, _format_num(ore), _format_num(metal), _format_num(parts)]
    depletion_fill.size.x = 300.0 * (ore_reserve / ore_max)
    rate_label.text = "Production: Ore->Metal->Parts->Credits  |  Credits/s: %s" % _format_num(credits_per_sec)
    for i in range(machine_btns.size()):
        var mt: Dictionary = machine_types[i]
        machine_btns[i].text = "%s (%.0f credits)%s" % [str(mt["name"]), float(mt["cost"]), " [SELECTED]" if i == selected_machine_type else ""]
        machine_btns[i].modulate = Color(0.3, 1.0, 0.5) if i == selected_machine_type else Color.WHITE

func _refresh_research() -> void:
    for i in range(research_btns.size()):
        var ri: Dictionary = research_items[i]
        if bool(ri["done"]):
            research_btns[i].text = "[DONE] %s — %s" % [str(ri["name"]), str(ri["effect"])]
        else:
            research_btns[i].text = "Research: %s (%.0f credits) — %s" % [str(ri["name"]), float(ri["cost"]), str(ri["effect"])]

func _draw() -> void:
    if state == GS.TITLE: return
    # Draw grid
    for r in range(ROWS):
        for c in range(COLS):
            var rx: float = GRID_OX + float(c) * CELL
            var ry: float = GRID_OY + float(r) * CELL
            draw_rect(Rect2(rx, ry, CELL-2, CELL-2), Color(0.12, 0.12, 0.18))
            if grid[r][c] != null:
                var type_idx: int = int(grid[r][c]["type"])
                var mt: Dictionary = machine_types[type_idx]
                draw_rect(Rect2(rx+2, ry+2, CELL-6, CELL-6), mt["color"])
                draw_string(ThemeDB.fallback_font, Vector2(rx+4, ry+20), str(mt["name"]).substr(0, 5), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
            # Draw conveyor hint between adjacent machines
            if c > 0 and grid[r][c] != null and grid[r][c-1] != null:
                draw_line(Vector2(rx, ry + CELL/2), Vector2(rx - CELL + 2, ry + CELL/2), Color(0.5, 0.5, 0.3, 0.6), 3.0)
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":425}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_factory.json" << 'DEMO'
{"scenario":"factory","duration_frames":540,"events":[
  {"frame":30,"type":"mouse_click","button":"left","x":740,"y":145},
  {"frame":60,"type":"mouse_click","button":"left","x":100,"y":200},
  {"frame":90,"type":"mouse_click","button":"left","x":740,"y":195},
  {"frame":120,"type":"mouse_click","button":"left","x":180,"y":200},
  {"frame":150,"type":"mouse_click","button":"left","x":740,"y":245},
  {"frame":180,"type":"mouse_click","button":"left","x":260,"y":200},
  {"frame":210,"type":"mouse_click","button":"left","x":740,"y":295},
  {"frame":240,"type":"mouse_click","button":"left","x":340,"y":200},
  {"frame":300,"type":"wait"},
  {"frame":360,"type":"mouse_click","button":"left","x":840,"y":380},
  {"frame":420,"type":"mouse_click","button":"left","x":640,"y":210},
  {"frame":480,"type":"wait"}
]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_prestige.json" << 'DEMO'
{"scenario":"prestige","duration_frames":360,"events":[
  {"frame":60,"type":"mouse_click","button":"left","x":840,"y":450},
  {"frame":150,"type":"mouse_click","button":"left","x":200,"y":297},
  {"frame":240,"type":"wait"},
  {"frame":300,"type":"mouse_click","button":"left","x":740,"y":145}
]}
DEMO

echo "Oracle written to $GAME_DIR"
