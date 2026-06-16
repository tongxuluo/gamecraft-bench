#!/usr/bin/env bash
# Oracle reference implementation for simulation-space-station.
# Minimal space station crew management game.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Space Station"
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

enum GS { TITLE, STATION, EVENT, SUMMARY }
var state := GS.TITLE

# Modules
var modules := [
    {"name":"Bridge",       "x":100.0,"y":100.0,"w":160.0,"h":80.0,"power":2,"crew_needed":1,"crew":[],"active":true},
    {"name":"Life Support", "x":300.0,"y":100.0,"w":160.0,"h":80.0,"power":3,"crew_needed":1,"crew":[],"active":true},
    {"name":"Power Core",   "x":500.0,"y":100.0,"w":160.0,"h":80.0,"power":-4,"crew_needed":1,"crew":[],"active":true},
    {"name":"Crew Quarters","x":700.0,"y":100.0,"w":160.0,"h":80.0,"power":1,"crew_needed":0,"crew":[],"active":true},
    {"name":"Lab",          "x":100.0,"y":220.0,"w":160.0,"h":80.0,"power":2,"crew_needed":1,"crew":[],"active":false},
    {"name":"Airlock",      "x":300.0,"y":220.0,"w":160.0,"h":80.0,"power":1,"crew_needed":1,"crew":[],"active":false}
]

# Crew
var crew := [
    {"name":"Cmdr. Yeva","role":"Commander","fatigue":0.0,"health":100.0,"assigned_module":-1},
    {"name":"Dr. Osei",  "role":"Scientist","fatigue":0.0,"health":100.0,"assigned_module":-1},
    {"name":"Eng. Mira", "role":"Engineer", "fatigue":0.0,"health":100.0,"assigned_module":-1},
    {"name":"Pilot Zhen","role":"Pilot",    "fatigue":0.0,"health":100.0,"assigned_module":-1}
]

# Power
var power_available := 8
var power_used := 0

# Life support
var life_support_ok := true
var life_support_timer := 0.0

# Events
var event_timer := 10.0
var current_event := ""
var event_active := false
var events_handled := 0
var rng := RandomNumberGenerator.new()

# Cycle
var cycle := 1
var cycles_survived := 0
var resources := 100

# UI
var title_panel: ColorRect
var station_panel: ColorRect
var event_panel: ColorRect
var summary_panel: ColorRect
var hud_label: Label
var event_label: Label
var event_btn1: Button
var event_btn2: Button
var selected_crew := -1
var crew_btns: Array = []
var module_labels: Array = []

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    if scenario == "event":
        state = GS.STATION; station_panel.visible = true
        _trigger_event()
    elif scenario == "summary":
        cycles_survived = 15; events_handled = 8; resources = 75
        state = GS.SUMMARY; _show_summary()
    else:
        state = GS.TITLE; title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new(); bg.color = Color(0.03,0.03,0.08); bg.size = Vector2(1280,720); add_child(bg)
    title_panel = ColorRect.new(); title_panel.color = Color(0,0,0,0.92); title_panel.size = Vector2(1280,720); title_panel.visible = false; add_child(title_panel)
    var tl := Label.new(); tl.text = "SPACE STATION\nCrew Management Simulation\n\nAssign crew to modules.\nManage power. Respond to events.\nKeep life support running!"; tl.position = Vector2(340,160); tl.add_theme_font_size_override("font_size",32); tl.modulate = Color(0.5,0.8,1.0); title_panel.add_child(tl)
    var sb := Button.new(); sb.text = "LAUNCH STATION"; sb.position = Vector2(490,420); sb.size = Vector2(300,65); sb.add_theme_font_size_override("font_size",28); sb.pressed.connect(_on_start); title_panel.add_child(sb)
    station_panel = ColorRect.new(); station_panel.color = Color(0.03,0.03,0.08); station_panel.size = Vector2(1280,720); station_panel.visible = false; add_child(station_panel)
    hud_label = Label.new(); hud_label.position = Vector2(10,10); hud_label.add_theme_font_size_override("font_size",18); hud_label.modulate = Color(0.5,0.8,1.0); station_panel.add_child(hud_label)
    # Module labels
    for i in range(modules.size()):
        var ml := Label.new(); ml.position = Vector2(float(modules[i]["x"])+5.0, float(modules[i]["y"])+float(modules[i]["h"])+5.0); ml.add_theme_font_size_override("font_size",13); ml.modulate = Color(0.5,0.8,1.0); station_panel.add_child(ml); module_labels.append(ml)
    # Crew buttons
    var cl := Label.new(); cl.text = "CREW"; cl.position = Vector2(900,100); cl.add_theme_font_size_override("font_size",22); cl.modulate = Color(0.5,0.8,1.0); station_panel.add_child(cl)
    for i in range(crew.size()):
        var btn := Button.new(); btn.position = Vector2(900,130+i*70); btn.size = Vector2(360,60); btn.add_theme_font_size_override("font_size",16); btn.pressed.connect(_on_crew_select.bind(i)); station_panel.add_child(btn); crew_btns.append(btn)
    var rest_btn := Button.new(); rest_btn.text = "Send to Rest (Crew Quarters)"; rest_btn.position = Vector2(900,420); rest_btn.size = Vector2(360,55); rest_btn.add_theme_font_size_override("font_size",18); rest_btn.pressed.connect(_on_rest); station_panel.add_child(rest_btn)
    var build_btn := Button.new(); build_btn.text = "Build Lab Module (50 res)"; build_btn.position = Vector2(900,485); build_btn.size = Vector2(360,55); build_btn.add_theme_font_size_override("font_size",18); build_btn.pressed.connect(_on_build); station_panel.add_child(build_btn)
    # Event panel
    event_panel = ColorRect.new(); event_panel.color = Color(0.0,0.0,0.0,0.92); event_panel.size = Vector2(700,320); event_panel.position = Vector2(290,200); event_panel.visible = false; station_panel.add_child(event_panel)
    var evl := Label.new(); evl.text = "⚠ EVENT"; evl.position = Vector2(260,20); evl.add_theme_font_size_override("font_size",30); evl.modulate = Color(1.0,0.6,0.1); event_panel.add_child(evl)
    event_label = Label.new(); event_label.position = Vector2(30,70); event_label.size = Vector2(640,120); event_label.add_theme_font_size_override("font_size",20); event_label.modulate = Color(0.9,0.9,0.9); event_label.autowrap_mode = TextServer.AUTOWRAP_WORD; event_panel.add_child(event_label)
    event_btn1 = Button.new(); event_btn1.position = Vector2(60,220); event_btn1.size = Vector2(260,60); event_btn1.add_theme_font_size_override("font_size",18); event_btn1.pressed.connect(_on_event_choice.bind(0)); event_panel.add_child(event_btn1)
    event_btn2 = Button.new(); event_btn2.position = Vector2(380,220); event_btn2.size = Vector2(260,60); event_btn2.add_theme_font_size_override("font_size",18); event_btn2.pressed.connect(_on_event_choice.bind(1)); event_panel.add_child(event_btn2)
    # Summary
    summary_panel = ColorRect.new(); summary_panel.color = Color(0,0,0,0.92); summary_panel.size = Vector2(700,400); summary_panel.position = Vector2(290,160); summary_panel.visible = false; add_child(summary_panel)
    var sl := Label.new(); sl.name = "SummaryLabel"; sl.position = Vector2(50,30); sl.add_theme_font_size_override("font_size",24); sl.modulate = Color(0.5,0.8,1.0); summary_panel.add_child(sl)
    var nb := Button.new(); nb.text = "Continue"; nb.position = Vector2(250,320); nb.size = Vector2(200,55); nb.pressed.connect(_on_continue); summary_panel.add_child(nb)

func _on_start() -> void:
    title_panel.visible = false; station_panel.visible = true; state = GS.STATION

func _on_crew_select(idx: int) -> void:
    selected_crew = idx
    # Assign to module by clicking module area
    _refresh_ui()

func _on_rest() -> void:
    if selected_crew < 0: return
    crew[selected_crew]["assigned_module"] = 3  # Crew Quarters
    crew[selected_crew]["fatigue"] = max(0.0, float(crew[selected_crew]["fatigue"]) - 30.0)
    selected_crew = -1; _refresh_ui()

func _on_build() -> void:
    if resources >= 50:
        resources -= 50; modules[4]["active"] = true

func _trigger_event() -> void:
    var event_list := [
        {"text":"Supply ship arriving! Assign pilot to Airlock to dock.","opt1":"Dock (needs Pilot)","opt2":"Decline shipment","result1":"resources","result2":"nothing"},
        {"text":"System malfunction in Power Core! Engineer needed immediately.","opt1":"Repair (needs Engineer)","opt2":"Shut down module","result1":"power","result2":"power_loss"},
        {"text":"Distress signal detected. Respond or ignore?","opt1":"Respond (use resources)","opt2":"Ignore signal","result1":"morale","result2":"nothing"},
        {"text":"Meteor shower warning! Crew to Bridge for evasive maneuvers.","opt1":"Evade (needs Commander)","opt2":"Brace for impact","result1":"safe","result2":"damage"},
        {"text":"Experiment breakthrough in Lab! Publish results?","opt1":"Publish (gain resources)","opt2":"Continue research","result1":"resources","result2":"nothing"}
    ]
    var ev: Dictionary = event_list[rng.randi_range(0, event_list.size()-1)]
    current_event = str(ev["text"])
    event_label.text = current_event
    event_btn1.text = str(ev["opt1"])
    event_btn2.text = str(ev["opt2"])
    event_active = true; event_panel.visible = true

func _on_event_choice(choice: int) -> void:
    event_panel.visible = false; event_active = false; events_handled += 1
    if choice == 0:
        resources += 20
    else:
        resources -= 5
    _refresh_ui()

func _on_continue() -> void:
    summary_panel.visible = false; state = GS.STATION; station_panel.visible = true

func _show_summary() -> void:
    state = GS.SUMMARY; summary_panel.visible = true
    var sl: Label = summary_panel.get_node("SummaryLabel")
    sl.text = "CYCLE %d REPORT\n\nCycles Survived: %d\nEvents Handled: %d\nResources: %d\nLife Support: %s\nCrew Health: OK\n\nStation Status: OPERATIONAL" % [cycle, cycles_survived, events_handled, resources, "OK" if life_support_ok else "CRITICAL"]

func _refresh_ui() -> void:
    _calc_power()
    for i in range(modules.size()):
        var m: Dictionary = modules[i]
        var crew_here: Array = []
        for c in crew:
            if int(c["assigned_module"]) == i: crew_here.append(str(c["name"]))
        module_labels[i].text = "%s\nPwr:%d Crew:%s" % [str(m["name"]), int(m["power"]), ",".join(crew_here) if crew_here.size() > 0 else "none"]
    for i in range(crew_btns.size()):
        if i < crew.size():
            var c: Dictionary = crew[i]
            var mod_name := "unassigned"
            if int(c["assigned_module"]) >= 0 and int(c["assigned_module"]) < modules.size():
                mod_name = str(modules[int(c["assigned_module"])]["name"])
            crew_btns[i].text = "%s (%s)\nFatigue:%.0f%%  → %s" % [str(c["name"]), str(c["role"]), float(c["fatigue"]), mod_name]
            crew_btns[i].modulate = Color(0.3,1.0,0.3) if i == selected_crew else Color.WHITE
    hud_label.text = "Cycle %d  |  Power: %d/%d  |  Resources: %d  |  Life Support: %s  |  Events: %d" % [cycle, power_used, power_available, resources, "OK" if life_support_ok else "⚠CRITICAL", events_handled]

func _calc_power() -> void:
    power_used = 0
    for m in modules:
        if bool(m["active"]) and int(m["power"]) > 0:
            power_used += int(m["power"])
    life_support_ok = modules[1]["active"] and power_used <= power_available

func _process(delta: float) -> void:
    if state == GS.STATION:
        # Fatigue accumulates
        for c in crew:
            if int(c["assigned_module"]) >= 0 and int(c["assigned_module"]) != 3:
                c["fatigue"] = min(100.0, float(c["fatigue"]) + delta * 2.0)
            else:
                c["fatigue"] = max(0.0, float(c["fatigue"]) - delta * 5.0)
        # Life support degrades health if off
        if not life_support_ok:
            life_support_timer += delta
            if life_support_timer >= 5.0:
                life_support_timer = 0.0
                for c in crew: c["health"] = max(0.0, float(c["health"]) - 10.0)
        # Event timer
        if not event_active:
            event_timer -= delta
            if event_timer <= 0.0:
                event_timer = rng.randf_range(8.0, 15.0)
                cycles_survived += 1
                if cycles_survived % 5 == 0: _show_summary()
                else: _trigger_event()
        _refresh_ui()
    queue_redraw()

func _input(event: InputEvent) -> void:
    if state != GS.STATION or event_active: return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if selected_crew < 0: return
        var mp: Vector2 = event.position
        for i in range(modules.size()):
            var m: Dictionary = modules[i]
            if mp.x >= float(m["x"]) and mp.x <= float(m["x"])+float(m["w"]) and mp.y >= float(m["y"]) and mp.y <= float(m["y"])+float(m["h"]):
                crew[selected_crew]["assigned_module"] = i
                selected_crew = -1; _refresh_ui(); break

func _draw() -> void:
    if state == GS.TITLE: return
    for i in range(modules.size()):
        var m: Dictionary = modules[i]
        var col := Color(0.1,0.3,0.5) if bool(m["active"]) else Color(0.15,0.15,0.2)
        if str(m["name"]) == "Life Support": col = Color(0.1,0.5,0.2) if life_support_ok else Color(0.6,0.1,0.1)
        draw_rect(Rect2(float(m["x"]),float(m["y"]),float(m["w"]),float(m["h"])), col)
        draw_string(ThemeDB.fallback_font, Vector2(float(m["x"])+5.0,float(m["y"])+20.0), str(m["name"]), HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.8,0.9,1.0))
        # Crew dots
        var crew_count := 0
        for c in crew:
            if int(c["assigned_module"]) == i:
                draw_circle(Vector2(float(m["x"])+15.0+crew_count*20.0, float(m["y"])+55.0), 7.0, Color(0.9,0.8,0.3))
                crew_count += 1
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":453}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_station.json" << 'DEMO'
{"scenario":"event","duration_frames":540,"events":[{"frame":30,"type":"mouse_click","button":"left","x":940,"y":160},{"frame":60,"type":"mouse_click","button":"left","x":180,"y":140},{"frame":90,"type":"mouse_click","button":"left","x":940,"y":230},{"frame":120,"type":"mouse_click","button":"left","x":380,"y":140},{"frame":150,"type":"mouse_click","button":"left","x":190,"y":413},{"frame":210,"type":"mouse_click","button":"left","x":420,"y":350},{"frame":270,"type":"mouse_click","button":"left","x":640,"y":350},{"frame":330,"type":"wait"},{"frame":420,"type":"mouse_click","button":"left","x":940,"y":300},{"frame":450,"type":"mouse_click","button":"left","x":940,"y":453}]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_summary.json" << 'DEMO'
{"scenario":"summary","duration_frames":300,"events":[{"frame":60,"type":"wait"},{"frame":200,"type":"mouse_click","button":"left","x":540,"y":475}]}
DEMO

echo "Oracle written to $GAME_DIR"
