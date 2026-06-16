#!/usr/bin/env bash
# Oracle reference implementation for idle-dungeon-guild.
# Minimal idle guild game: recruit heroes, dispatch quests, collect loot, prestige.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Idle Dungeon Guild"
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

enum GS { TITLE, GUILD, RESULTS, PRESTIGE_CONFIRM }
var state := GS.TITLE

var heroes: Array = []
var hero_classes := ["Warrior","Mage","Rogue","Healer"]
var hero_colors := [Color(0.8,0.3,0.2),Color(0.3,0.4,0.9),Color(0.2,0.7,0.3),Color(0.8,0.6,0.8)]

var dungeons := [
    {"name":"Goblin Cave",    "diff":1,"duration":5.0, "reward":20.0,"min_level":1},
    {"name":"Bandit Hideout", "diff":2,"duration":8.0, "reward":50.0,"min_level":2},
    {"name":"Dark Forest",    "diff":3,"duration":12.0,"reward":100.0,"min_level":4},
    {"name":"Dragon Lair",    "diff":5,"duration":20.0,"reward":300.0,"min_level":8}
]

var quest_active := false
var quest_dungeon := 0
var quest_timer: float = 0.0
var quest_duration: float = 0.0
var quest_party: Array = []

var gold: float = 0.0
var reputation: float = 0.0
var prestige_count := 0
var prestige_multiplier: float = 1.0
var equipment_pool: Array = []
var rng := RandomNumberGenerator.new()

var title_panel: ColorRect
var guild_panel: ColorRect
var results_panel: ColorRect
var prestige_panel: ColorRect
var hud_label: Label
var hero_btns: Array = []
var dungeon_btns: Array = []
var quest_bar_fill: ColorRect
var quest_label: Label
var results_label: Label
var rep_label: Label
var selected_heroes: Array = []

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _spawn_heroes()
    _build_ui()
    if scenario == "guild":
        state = GS.GUILD
        title_panel.visible = false
        guild_panel.visible = true
        gold = 80.0
    elif scenario == "prestige":
        state = GS.GUILD
        title_panel.visible = false
        guild_panel.visible = true
        gold = 500.0
        reputation = 95.0
        for h in heroes:
            h["level"] = 8
    else:
        state = GS.TITLE
        title_panel.visible = true

func _spawn_heroes() -> void:
    heroes.clear()
    var names := ["Aldric","Lyra","Shade","Mira"]
    for i in range(4):
        heroes.append({
            "name": names[i], "class": hero_classes[i],
            "level": 1, "xp": 0.0, "xp_needed": 100.0,
            "in_party": false
        })

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.07, 0.04)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.06, 0.04, 0.02, 0.97)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "IDLE DUNGEON GUILD"
    tl.position = Vector2(300, 160)
    tl.add_theme_font_size_override("font_size", 52)
    tl.modulate = Color(0.9, 0.75, 0.3)
    title_panel.add_child(tl)

    var tl2 := Label.new()
    tl2.text = "Recruit heroes. Send them on quests.\nWatch your guild grow to legend!"
    tl2.position = Vector2(380, 270)
    tl2.add_theme_font_size_override("font_size", 24)
    tl2.modulate = Color(0.7, 0.6, 0.4)
    title_panel.add_child(tl2)

    var play_btn := Button.new()
    play_btn.text = "OPEN GUILD HALL"
    play_btn.position = Vector2(490, 390)
    play_btn.size = Vector2(300, 70)
    play_btn.add_theme_font_size_override("font_size", 28)
    play_btn.pressed.connect(_on_start)
    title_panel.add_child(play_btn)

    guild_panel = ColorRect.new()
    guild_panel.color = Color(0.08, 0.05, 0.03)
    guild_panel.size = Vector2(1280, 720)
    guild_panel.visible = false
    add_child(guild_panel)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 8)
    hud_label.add_theme_font_size_override("font_size", 20)
    hud_label.modulate = Color(0.9, 0.8, 0.4)
    guild_panel.add_child(hud_label)

    rep_label = Label.new()
    rep_label.position = Vector2(10, 36)
    rep_label.add_theme_font_size_override("font_size", 16)
    rep_label.modulate = Color(0.6, 0.8, 0.9)
    guild_panel.add_child(rep_label)

    var hl := Label.new()
    hl.text = "HERO ROSTER (click to add to party)"
    hl.position = Vector2(10, 65)
    hl.add_theme_font_size_override("font_size", 18)
    hl.modulate = Color(0.8, 0.65, 0.3)
    guild_panel.add_child(hl)

    for i in range(heroes.size()):
        var btn := Button.new()
        btn.position = Vector2(10, 90 + i * 65)
        btn.size = Vector2(380, 56)
        btn.add_theme_font_size_override("font_size", 15)
        btn.pressed.connect(_on_hero_select.bind(i))
        guild_panel.add_child(btn)
        hero_btns.append(btn)

    var ql := Label.new()
    ql.text = "QUEST BOARD"
    ql.position = Vector2(420, 65)
    ql.add_theme_font_size_override("font_size", 18)
    ql.modulate = Color(0.8, 0.65, 0.3)
    guild_panel.add_child(ql)

    for i in range(dungeons.size()):
        var btn := Button.new()
        btn.position = Vector2(420, 90 + i * 70)
        btn.size = Vector2(420, 60)
        btn.add_theme_font_size_override("font_size", 14)
        btn.pressed.connect(_on_dispatch.bind(i))
        guild_panel.add_child(btn)
        dungeon_btns.append(btn)

    var bar_bg := ColorRect.new()
    bar_bg.color = Color(0.2, 0.15, 0.1)
    bar_bg.position = Vector2(420, 405)
    bar_bg.size = Vector2(420, 30)
    guild_panel.add_child(bar_bg)

    quest_bar_fill = ColorRect.new()
    quest_bar_fill.color = Color(0.8, 0.6, 0.2)
    quest_bar_fill.position = Vector2(420, 405)
    quest_bar_fill.size = Vector2(0, 30)
    guild_panel.add_child(quest_bar_fill)

    quest_label = Label.new()
    quest_label.position = Vector2(420, 440)
    quest_label.add_theme_font_size_override("font_size", 16)
    quest_label.modulate = Color(0.8, 0.7, 0.5)
    guild_panel.add_child(quest_label)

    var prestige_btn := Button.new()
    prestige_btn.text = "NEW GENERATION (Prestige)"
    prestige_btn.position = Vector2(10, 650)
    prestige_btn.size = Vector2(300, 50)
    prestige_btn.add_theme_font_size_override("font_size", 16)
    prestige_btn.modulate = Color(1.0, 0.85, 0.2)
    prestige_btn.pressed.connect(_on_prestige)
    guild_panel.add_child(prestige_btn)

    results_panel = ColorRect.new()
    results_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    results_panel.size = Vector2(600, 360)
    results_panel.position = Vector2(340, 180)
    results_panel.visible = false
    add_child(results_panel)

    var rl_title := Label.new()
    rl_title.text = "QUEST COMPLETE!"
    rl_title.position = Vector2(180, 20)
    rl_title.add_theme_font_size_override("font_size", 30)
    rl_title.modulate = Color(0.9, 0.8, 0.3)
    results_panel.add_child(rl_title)

    results_label = Label.new()
    results_label.position = Vector2(40, 70)
    results_label.add_theme_font_size_override("font_size", 20)
    results_label.modulate = Color(0.85, 0.8, 0.65)
    results_panel.add_child(results_label)

    var close_btn := Button.new()
    close_btn.text = "Continue"
    close_btn.position = Vector2(220, 290)
    close_btn.size = Vector2(160, 50)
    close_btn.pressed.connect(func(): results_panel.visible = false; state = GS.GUILD)
    results_panel.add_child(close_btn)

    prestige_panel = ColorRect.new()
    prestige_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    prestige_panel.size = Vector2(700, 380)
    prestige_panel.position = Vector2(290, 170)
    prestige_panel.visible = false
    add_child(prestige_panel)

    var pp_title := Label.new()
    pp_title.text = "NEW GENERATION — PRESTIGE"
    pp_title.position = Vector2(120, 25)
    pp_title.add_theme_font_size_override("font_size", 26)
    pp_title.modulate = Color(1.0, 0.85, 0.2)
    prestige_panel.add_child(pp_title)

    var pp_info := Label.new()
    pp_info.name = "PrestigeInfo"
    pp_info.position = Vector2(50, 80)
    pp_info.size = Vector2(600, 180)
    pp_info.add_theme_font_size_override("font_size", 18)
    pp_info.modulate = Color(0.85, 0.8, 0.6)
    pp_info.autowrap_mode = TextServer.AUTOWRAP_WORD
    prestige_panel.add_child(pp_info)

    var pp_confirm := Button.new()
    pp_confirm.text = "RETIRE HEROES"
    pp_confirm.position = Vector2(100, 280)
    pp_confirm.size = Vector2(200, 55)
    pp_confirm.pressed.connect(_do_prestige)
    prestige_panel.add_child(pp_confirm)

    var pp_cancel := Button.new()
    pp_cancel.text = "Cancel"
    pp_cancel.position = Vector2(380, 280)
    pp_cancel.size = Vector2(160, 55)
    pp_cancel.pressed.connect(func(): prestige_panel.visible = false)
    prestige_panel.add_child(pp_cancel)

func _on_start() -> void:
    title_panel.visible = false
    guild_panel.visible = true
    state = GS.GUILD

func _on_hero_select(idx: int) -> void:
    if quest_active: return
    var h: Dictionary = heroes[idx]
    if bool(h["in_party"]):
        h["in_party"] = false
        selected_heroes.erase(idx)
    else:
        if selected_heroes.size() < 4:
            h["in_party"] = true
            selected_heroes.append(idx)

func _on_dispatch(dungeon_idx: int) -> void:
    if quest_active or selected_heroes.is_empty(): return
    var dg: Dictionary = dungeons[dungeon_idx]
    var party_level := 0
    for hi in selected_heroes:
        party_level += int(heroes[hi]["level"])
    if party_level < int(dg["min_level"]): return
    quest_active = true
    quest_dungeon = dungeon_idx
    quest_duration = float(dg["duration"]) / prestige_multiplier
    quest_timer = 0.0
    quest_party = selected_heroes.duplicate()

func _on_prestige() -> void:
    var pp_info: Label = prestige_panel.get_node("PrestigeInfo")
    var next_mult: float = prestige_multiplier * 1.5
    pp_info.text = "Retire all heroes. Keep equipment.\nGain permanent bonuses:\n- Levelling speed x%.1f\n- Loot rate x%.1f\n\nCurrent generation: %d" % [next_mult, next_mult, prestige_count + 1]
    prestige_panel.visible = true

func _do_prestige() -> void:
    prestige_panel.visible = false
    prestige_count += 1
    prestige_multiplier *= 1.5
    reputation = 0.0
    quest_active = false
    selected_heroes.clear()
    _spawn_heroes()

func _process(delta: float) -> void:
    if state == GS.GUILD and quest_active:
        quest_timer += delta
        var progress: float = quest_timer / quest_duration
        quest_bar_fill.size.x = 420.0 * minf(progress, 1.0)
        var dg: Dictionary = dungeons[quest_dungeon]
        quest_label.text = "On quest: %s  (%.0fs / %.0fs)" % [str(dg["name"]), quest_timer, quest_duration]
        if quest_timer >= quest_duration:
            _complete_quest()
    elif state == GS.GUILD:
        quest_bar_fill.size.x = 0.0
        quest_label.text = "No active quest. Select heroes and dispatch."
    _refresh_ui()
    queue_redraw()

func _complete_quest() -> void:
    quest_active = false
    var dg: Dictionary = dungeons[quest_dungeon]
    var reward: float = float(dg["reward"]) * prestige_multiplier
    gold += reward
    reputation = minf(reputation + float(dg["diff"]) * 5.0, 100.0)
    var xp_gain: float = float(dg["diff"]) * 30.0 * prestige_multiplier
    var level_ups := ""
    for hi in quest_party:
        var h: Dictionary = heroes[hi]
        h["xp"] = float(h["xp"]) + xp_gain
        h["in_party"] = false
        while float(h["xp"]) >= float(h["xp_needed"]):
            h["xp"] = float(h["xp"]) - float(h["xp_needed"])
            h["level"] = int(h["level"]) + 1
            h["xp_needed"] = float(h["xp_needed"]) * 1.5
            level_ups += "%s levelled up to %d!\n" % [str(h["name"]), int(h["level"])]
    selected_heroes.clear()
    var loot_types := ["Iron Sword","Steel Armor","Lucky Ring","Magic Staff","Shadow Cloak"]
    var loot: String = loot_types[rng.randi_range(0, loot_types.size()-1)]
    equipment_pool.append(loot)
    results_label.text = "Dungeon: %s\nGold earned: %.0f\nReputation: %.0f/100\nLoot found: %s\n%s" % [str(dg["name"]), reward, reputation, loot, level_ups]
    results_panel.visible = true
    state = GS.RESULTS

func _refresh_ui() -> void:
    hud_label.text = "Gold: %.0f  |  Prestige: %d  |  Multiplier: x%.1f" % [gold, prestige_count, prestige_multiplier]
    rep_label.text = "Guild Reputation: %.0f / 100" % reputation
    for i in range(heroes.size()):
        var h: Dictionary = heroes[i]
        var party_mark := "[PARTY] " if bool(h["in_party"]) else ""
        hero_btns[i].text = "%s%s (%s) Lv%d  XP:%.0f/%.0f" % [party_mark, str(h["name"]), str(h["class"]), int(h["level"]), float(h["xp"]), float(h["xp_needed"])]
        hero_btns[i].modulate = hero_colors[i % hero_colors.size()] if bool(h["in_party"]) else Color.WHITE
    for i in range(dungeons.size()):
        var dg: Dictionary = dungeons[i]
        dungeon_btns[i].text = "%s  Diff:%d  Time:%.0fs  Reward:%.0f  MinLv:%d" % [str(dg["name"]), int(dg["diff"]), float(dg["duration"]), float(dg["reward"]) * prestige_multiplier, int(dg["min_level"])]

func _draw() -> void:
    if state == GS.TITLE: return
    var ox: float = 10.0
    var oy: float = 410.0
    draw_rect(Rect2(ox, oy, 380.0, 220.0), Color(0.15, 0.1, 0.06))
    draw_string(ThemeDB.fallback_font, Vector2(ox+5, oy+20), "Equipment (%d items):" % equipment_pool.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.7, 0.4))
    for i in range(mini(equipment_pool.size(), 8)):
        draw_string(ThemeDB.fallback_font, Vector2(ox+10, oy+40+i*22), "- %s" % str(equipment_pool[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.65, 0.5))
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":425}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_guild.json" << 'DEMO'
{"scenario":"guild","duration_frames":540,"events":[
  {"frame":30,"type":"mouse_click","button":"left","x":200,"y":118},
  {"frame":60,"type":"mouse_click","button":"left","x":630,"y":120},
  {"frame":300,"type":"wait"},
  {"frame":360,"type":"mouse_click","button":"left","x":540,"y":490},
  {"frame":420,"type":"mouse_click","button":"left","x":200,"y":118},
  {"frame":450,"type":"mouse_click","button":"left","x":630,"y":120},
  {"frame":480,"type":"wait"}
]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_prestige.json" << 'DEMO'
{"scenario":"prestige","duration_frames":360,"events":[
  {"frame":60,"type":"mouse_click","button":"left","x":160,"y":675},
  {"frame":150,"type":"mouse_click","button":"left","x":200,"y":307},
  {"frame":240,"type":"wait"},
  {"frame":300,"type":"mouse_click","button":"left","x":200,"y":118}
]}
DEMO

echo "Oracle written to $GAME_DIR"
