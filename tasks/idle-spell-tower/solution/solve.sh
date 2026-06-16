#!/usr/bin/env bash
# Oracle reference implementation for idle-spell-tower.
# Minimal idle tower game: generate mana, build floors, research spells, fight monsters, prestige.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Idle Spell Tower"
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

enum GS { TITLE, TOWER, RESEARCH, PRESTIGE_CONFIRM }
var state := GS.TITLE

# Tower floors
var floors: Array = []
var floor_types := [
    {"id":"generator","name":"Mana Gen",  "color":Color(0.4,0.2,0.7),"mana_rate":1.0, "cost":50.0},
    {"id":"lab",      "name":"Spell Lab", "color":Color(0.2,0.5,0.8),"mana_rate":0.0, "cost":150.0},
    {"id":"caster",   "name":"Auto-Cast", "color":Color(0.7,0.3,0.5),"mana_rate":0.0, "cost":300.0}
]
const MAX_FLOORS := 10

# Mana
var mana: float = 0.0
var mana_per_sec: float = 0.0
var mana_crystals: float = 0.0

# Spells
var spells := [
    {"name":"Fireball",    "cost":100.0,"researched":false,"damage":10.0,"color":Color(1.0,0.4,0.1)},
    {"name":"Ice Shard",   "cost":200.0,"researched":false,"damage":15.0,"color":Color(0.4,0.7,1.0)},
    {"name":"Thunder",     "cost":400.0,"researched":false,"damage":25.0,"color":Color(0.9,0.9,0.2)},
    {"name":"Void Blast",  "cost":800.0,"researched":false,"damage":50.0,"color":Color(0.6,0.2,0.9)}
]
var active_spell := 0

# Monsters
var monsters: Array = []
var monster_spawn_timer: float = 5.0
var rng := RandomNumberGenerator.new()

# Prestige
var prestige_count := 0
var prestige_multiplier: float = 1.0

# UI
var title_panel: ColorRect
var tower_panel: ColorRect
var research_panel: ColorRect
var prestige_panel: ColorRect
var hud_label: Label
var floor_btns: Array = []
var spell_btns: Array = []
var research_btns: Array = []
var click_label: Label
var click_timer: float = 0.0

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    if scenario == "tower":
        state = GS.TOWER
        title_panel.visible = false
        tower_panel.visible = true
        mana = 200.0
        floors.append({"type": 0, "timer": 0.0})
        floors.append({"type": 0, "timer": 0.0})
        floors.append({"type": 2, "timer": 0.0})
        spells[0]["researched"] = true
    elif scenario == "prestige":
        state = GS.TOWER
        title_panel.visible = false
        tower_panel.visible = true
        mana = 5000.0
        for i in range(MAX_FLOORS):
            floors.append({"type": i % 3, "timer": 0.0})
        for s in spells:
            s["researched"] = true
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.03, 0.1)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.03, 0.02, 0.08, 0.97)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "IDLE SPELL TOWER"
    tl.position = Vector2(320, 150)
    tl.add_theme_font_size_override("font_size", 56)
    tl.modulate = Color(0.7, 0.5, 1.0)
    title_panel.add_child(tl)

    var tl2 := Label.new()
    tl2.text = "Build a wizard tower. Generate mana.\nResearch spells. Defeat monsters. Prestige!"
    tl2.position = Vector2(340, 260)
    tl2.add_theme_font_size_override("font_size", 24)
    tl2.modulate = Color(0.6, 0.5, 0.8)
    title_panel.add_child(tl2)

    var play_btn := Button.new()
    play_btn.text = "RAISE THE TOWER"
    play_btn.position = Vector2(490, 390)
    play_btn.size = Vector2(300, 70)
    play_btn.add_theme_font_size_override("font_size", 28)
    play_btn.pressed.connect(_on_start)
    title_panel.add_child(play_btn)

    # Tower panel
    tower_panel = ColorRect.new()
    tower_panel.color = Color(0.04, 0.02, 0.08)
    tower_panel.size = Vector2(1280, 720)
    tower_panel.visible = false
    add_child(tower_panel)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 8)
    hud_label.add_theme_font_size_override("font_size", 20)
    hud_label.modulate = Color(0.8, 0.6, 1.0)
    tower_panel.add_child(hud_label)

    # Click crystal button
    var click_btn := Button.new()
    click_btn.text = "CHANNEL MANA (click)"
    click_btn.position = Vector2(10, 40)
    click_btn.size = Vector2(220, 45)
    click_btn.add_theme_font_size_override("font_size", 15)
    click_btn.pressed.connect(_on_click_mana)
    tower_panel.add_child(click_btn)

    click_label = Label.new()
    click_label.position = Vector2(240, 50)
    click_label.add_theme_font_size_override("font_size", 20)
    click_label.modulate = Color(0.8, 0.6, 1.0)
    click_label.visible = false
    tower_panel.add_child(click_label)

    # Floor build buttons
    var fl_lbl := Label.new()
    fl_lbl.text = "BUILD FLOOR:"
    fl_lbl.position = Vector2(10, 95)
    fl_lbl.add_theme_font_size_override("font_size", 16)
    fl_lbl.modulate = Color(0.7, 0.5, 0.9)
    tower_panel.add_child(fl_lbl)

    for i in range(floor_types.size()):
        var ft: Dictionary = floor_types[i]
        var btn := Button.new()
        btn.text = "%s (%.0f mana)" % [str(ft["name"]), float(ft["cost"])]
        btn.position = Vector2(10, 118 + i * 48)
        btn.size = Vector2(260, 40)
        btn.add_theme_font_size_override("font_size", 14)
        btn.pressed.connect(_on_build_floor.bind(i))
        tower_panel.add_child(btn)
        floor_btns.append(btn)

    # Research button
    var res_btn := Button.new()
    res_btn.text = "SPELL RESEARCH"
    res_btn.position = Vector2(10, 280)
    res_btn.size = Vector2(260, 48)
    res_btn.add_theme_font_size_override("font_size", 16)
    res_btn.pressed.connect(_on_open_research)
    tower_panel.add_child(res_btn)

    # Prestige button
    var prestige_btn := Button.new()
    prestige_btn.text = "PRESTIGE (collapse tower)"
    prestige_btn.position = Vector2(10, 340)
    prestige_btn.size = Vector2(260, 48)
    prestige_btn.add_theme_font_size_override("font_size", 14)
    prestige_btn.modulate = Color(1.0, 0.85, 0.2)
    prestige_btn.pressed.connect(_on_prestige)
    tower_panel.add_child(prestige_btn)

    # Research panel
    research_panel = ColorRect.new()
    research_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    research_panel.size = Vector2(700, 420)
    research_panel.position = Vector2(290, 150)
    research_panel.visible = false
    add_child(research_panel)

    var rp_title := Label.new()
    rp_title.text = "SPELL RESEARCH TREE"
    rp_title.position = Vector2(180, 20)
    rp_title.add_theme_font_size_override("font_size", 28)
    rp_title.modulate = Color(0.7, 0.5, 1.0)
    research_panel.add_child(rp_title)

    for i in range(spells.size()):
        var btn := Button.new()
        btn.position = Vector2(50, 75 + i * 65)
        btn.size = Vector2(600, 55)
        btn.add_theme_font_size_override("font_size", 16)
        btn.pressed.connect(_on_research_spell.bind(i))
        research_panel.add_child(btn)
        research_btns.append(btn)

    var rp_close := Button.new()
    rp_close.text = "Close"
    rp_close.position = Vector2(280, 355)
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
    pp_title.text = "PRESTIGE — COLLAPSE TOWER"
    pp_title.position = Vector2(120, 25)
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
    pp_confirm.text = "COLLAPSE AND REBUILD"
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
    tower_panel.visible = true
    state = GS.TOWER

func _on_click_mana() -> void:
    var bonus: float = 10.0 * prestige_multiplier
    mana += bonus
    click_label.text = "+%.0f mana" % bonus
    click_label.visible = true
    click_timer = 1.0

func _on_build_floor(type_idx: int) -> void:
    if floors.size() >= MAX_FLOORS: return
    var ft: Dictionary = floor_types[type_idx]
    if mana >= float(ft["cost"]):
        mana -= float(ft["cost"])
        floors.append({"type": type_idx, "timer": 0.0})

func _on_open_research() -> void:
    _refresh_research()
    research_panel.visible = true

func _on_research_spell(idx: int) -> void:
    var sp: Dictionary = spells[idx]
    if bool(sp["researched"]): return
    if mana >= float(sp["cost"]):
        mana -= float(sp["cost"])
        sp["researched"] = true
        active_spell = idx
    _refresh_research()

func _on_prestige() -> void:
    var pp_info: Label = prestige_panel.get_node("PrestigeInfo")
    var next_mult: float = prestige_multiplier * 1.5
    pp_info.text = "Collapse the tower to 1 floor.\nGain permanent bonuses:\n- Mana generation x%.1f\n- Max floors +2\n- Access to higher spells\n\nPrestige count: %d -> %d" % [next_mult, prestige_count, prestige_count + 1]
    prestige_panel.visible = true

func _do_prestige() -> void:
    prestige_panel.visible = false
    prestige_count += 1
    prestige_multiplier *= 1.5
    mana = 0.0
    mana_crystals = 0.0
    monsters.clear()
    floors.clear()
    floors.append({"type": 0, "timer": 0.0})

func _process(delta: float) -> void:
    if state != GS.TOWER: return

    # Mana generation from generator floors
    var gen_count := 0
    for f in floors:
        if int(f["type"]) == 0:
            gen_count += 1
    mana_per_sec = float(gen_count) * float(floor_types[0]["mana_rate"]) * prestige_multiplier
    mana += mana_per_sec * delta

    # Auto-casters fire at monsters
    var caster_count := 0
    for f in floors:
        if int(f["type"]) == 2:
            caster_count += 1
    if caster_count > 0 and not monsters.is_empty():
        var researched_spell: int = -1
        for i in range(spells.size() - 1, -1, -1):
            if bool(spells[i]["researched"]):
                researched_spell = i
                break
        if researched_spell >= 0:
            var dmg: float = float(spells[researched_spell]["damage"]) * prestige_multiplier * float(caster_count)
            for m in monsters:
                m["hp"] = float(m["hp"]) - dmg * delta
            monsters = monsters.filter(func(m): return float(m["hp"]) > 0.0)
            if monsters.size() < 3:
                mana_crystals += dmg * delta * 0.1

    # Spawn monsters
    monster_spawn_timer -= delta
    if monster_spawn_timer <= 0.0:
        monster_spawn_timer = rng.randf_range(3.0, 8.0)
        monsters.append({"hp": 50.0 + float(prestige_count) * 20.0, "max_hp": 50.0 + float(prestige_count) * 20.0, "x": 1200.0, "y": rng.randf_range(400.0, 680.0)})

    # Move monsters toward tower
    for m in monsters:
        m["x"] = float(m["x"]) - 40.0 * delta
    monsters = monsters.filter(func(m): return float(m["x"]) > 300.0)

    # Click label fade
    if click_timer > 0.0:
        click_timer -= delta
        if click_timer <= 0.0:
            click_label.visible = false

    _refresh_ui()
    queue_redraw()

func _format_num(n: float) -> String:
    if n >= 1000000.0: return "%.1fM" % (n / 1000000.0)
    if n >= 1000.0: return "%.1fK" % (n / 1000.0)
    return "%.0f" % n

func _refresh_ui() -> void:
    hud_label.text = "Mana: %s (+%s/s)  |  Crystals: %s  |  Floors: %d/%d  |  Prestige: %d" % [_format_num(mana), _format_num(mana_per_sec), _format_num(mana_crystals), floors.size(), MAX_FLOORS, prestige_count]
    for i in range(floor_btns.size()):
        var ft: Dictionary = floor_types[i]
        floor_btns[i].text = "%s (%.0f mana)" % [str(ft["name"]), float(ft["cost"])]

func _refresh_research() -> void:
    for i in range(research_btns.size()):
        var sp: Dictionary = spells[i]
        if bool(sp["researched"]):
            research_btns[i].text = "[RESEARCHED] %s — dmg:%.0f" % [str(sp["name"]), float(sp["damage"])]
        else:
            research_btns[i].text = "Research: %s (%.0f mana) — dmg:%.0f" % [str(sp["name"]), float(sp["cost"]), float(sp["damage"])]

func _draw() -> void:
    if state == GS.TITLE: return

    # Draw tower cross-section
    var tower_x: float = 300.0
    var floor_h: float = 60.0
    var floor_w: float = 200.0
    var base_y: float = 680.0

    for i in range(floors.size()):
        var f: Dictionary = floors[i]
        var fy: float = base_y - float(i + 1) * floor_h
        var ft: Dictionary = floor_types[int(f["type"])]
        draw_rect(Rect2(tower_x, fy, floor_w, floor_h - 4), ft["color"])
        draw_string(ThemeDB.fallback_font, Vector2(tower_x + 5, fy + 20), str(ft["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(tower_x + 5, fy + 38), "Floor %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))

    # Tower base
    draw_rect(Rect2(tower_x - 20, base_y - 10, floor_w + 40, 10), Color(0.3, 0.2, 0.5))

    # Draw monsters
    for m in monsters:
        var mx: float = float(m["x"])
        var my: float = float(m["y"])
        draw_circle(Vector2(mx, my), 14.0, Color(0.8, 0.2, 0.2))
        var hp_ratio: float = float(m["hp"]) / float(m["max_hp"])
        draw_rect(Rect2(mx - 14, my - 22, 28.0 * hp_ratio, 6), Color(0.2, 0.9, 0.2))

    # Draw spell projectiles (visual only)
    var caster_count := 0
    for f in floors:
        if int(f["type"]) == 2:
            caster_count += 1
    if caster_count > 0 and not monsters.is_empty() and not spells.is_empty():
        for i in range(spells.size() - 1, -1, -1):
            if bool(spells[i]["researched"]):
                var sp: Dictionary = spells[i]
                var proj_x: float = tower_x + floor_w + fmod(Time.get_ticks_msec() * 0.3, 300.0)
                var proj_y: float = 500.0
                draw_circle(Vector2(proj_x, proj_y), 8.0, sp["color"])
                break

    # Mana counter visual
    draw_string(ThemeDB.fallback_font, Vector2(tower_x, 90), "MANA: %s" % _format_num(mana), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.5, 1.0))
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":425}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_tower.json" << 'DEMO'
{"scenario":"tower","duration_frames":540,"events":[
  {"frame":30,"type":"mouse_click","button":"left","x":130,"y":55},
  {"frame":60,"type":"mouse_click","button":"left","x":130,"y":55},
  {"frame":90,"type":"mouse_click","button":"left","x":130,"y":55},
  {"frame":120,"type":"mouse_click","button":"left","x":130,"y":118},
  {"frame":150,"type":"mouse_click","button":"left","x":130,"y":295},
  {"frame":180,"type":"mouse_click","button":"left","x":640,"y":210},
  {"frame":240,"type":"mouse_click","button":"left","x":130,"y":55},
  {"frame":300,"type":"mouse_click","button":"left","x":130,"y":166},
  {"frame":360,"type":"wait"},
  {"frame":420,"type":"mouse_click","button":"left","x":130,"y":55},
  {"frame":480,"type":"wait"}
]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_prestige.json" << 'DEMO'
{"scenario":"prestige","duration_frames":360,"events":[
  {"frame":60,"type":"mouse_click","button":"left","x":130,"y":340},
  {"frame":150,"type":"mouse_click","button":"left","x":200,"y":297},
  {"frame":240,"type":"wait"},
  {"frame":300,"type":"mouse_click","button":"left","x":130,"y":55}
]}
DEMO

echo "Oracle written to $GAME_DIR"
