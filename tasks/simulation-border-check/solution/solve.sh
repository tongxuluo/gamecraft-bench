#!/usr/bin/env bash
# Oracle reference implementation for simulation-border-check.
# Minimal Papers Please-style document inspection game.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Border Check"
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

enum GS { TITLE, INSPECTING, END_OF_DAY }
var state := GS.TITLE

var day := 1
var time_left := 180.0
var earnings := 0
var total_earnings := 0
var citations := 0
var processed := 0
var correct := 0

var traveler_name := ""
var traveler_nationality := ""
var doc_valid := true
var doc_discrepancy := ""
var current_docs: Array = []
var decision_made := false

var rules: Array = []
var rng := RandomNumberGenerator.new()

var title_panel: ColorRect
var desk_panel: ColorRect
var traveler_label: Label
var doc_panels: Array = []
var rulebook_label: Label
var approve_btn: Button
var deny_btn: Button
var stamp_label: Label
var hud_label: Label
var eod_panel: ColorRect
var eod_label: Label
var moral_panel: ColorRect
var moral_label: Label

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    _setup_rules()
    if scenario == "inspection":
        desk_panel.visible = true
        state = GS.INSPECTING
        _next_traveler()
    elif scenario == "end_of_day":
        processed = 6; correct = 5; earnings = 25; total_earnings = 55
        state = GS.END_OF_DAY
        _show_eod()
    else:
        state = GS.TITLE
        title_panel.visible = true

func _setup_rules() -> void:
    rules = ["All travelers must present a valid Passport."]
    if day >= 2: rules.append("Citizens of REDLAND require a Work Permit.")
    if day >= 3: rules.append("Vaccination Card required for all travelers.")
    if day >= 4: rules.append("Entry Visa required for non-citizens.")
    if day >= 5: rules.append("Passports must not be expired.")

func _next_traveler() -> void:
    decision_made = false
    stamp_label.visible = false
    var names := ["Arno Voss","Mira Chen","Dmitri Koval","Fatima Al-Said","Jorge Reyes","Yuki Tanaka"]
    var nations := ["ARSTOTZKA","REDLAND","OBRISTAN","KOLECHIA","ANTEGRIA","IMPOR"]
    traveler_name = names[rng.randi_range(0, names.size()-1)]
    traveler_nationality = nations[rng.randi_range(0, nations.size()-1)]
    current_docs.clear()
    doc_valid = true
    doc_discrepancy = ""
    var expired := rng.randf() < 0.2 and day >= 5
    current_docs.append({"type":"Passport","name":traveler_name,"expiry":"2027-01-01" if not expired else "2024-01-01","valid": not expired})
    if expired: doc_valid = false; doc_discrepancy = "Passport expired"
    if traveler_nationality == "REDLAND" and day >= 2:
        var has_permit := rng.randf() > 0.3
        if has_permit: current_docs.append({"type":"Work Permit","name":traveler_name,"valid":true})
        else: doc_valid = false; doc_discrepancy = "Missing Work Permit"
    if day >= 3:
        var has_vax := rng.randf() > 0.25
        if has_vax: current_docs.append({"type":"Vaccination Card","name":traveler_name,"valid":true})
        else: doc_valid = false; doc_discrepancy = "Missing Vaccination Card"
    var show_moral := rng.randf() < 0.2
    if show_moral:
        var events := ["Traveler offers a bribe of 10 credits.","Traveler claims refugee status.","Traveler asks you to help their family."]
        moral_label.text = "MORAL CHOICE:\n" + events[rng.randi_range(0, events.size()-1)]
        moral_panel.visible = true
    else:
        moral_panel.visible = false
    _update_desk()

func _update_desk() -> void:
    traveler_label.text = "Traveler: %s\nNationality: %s\nDocuments: %d" % [traveler_name, traveler_nationality, current_docs.size()]
    for i in range(doc_panels.size()):
        if i < current_docs.size():
            doc_panels[i].visible = true
            var lbl: Label = doc_panels[i].get_child(0)
            var d: Dictionary = current_docs[i]
            lbl.text = "%s\n%s\n%s" % [str(d["type"]), str(d["name"]), str(d.get("expiry",""))]
        else:
            doc_panels[i].visible = false
    var rt := "RULES (Day %d):\n" % day
    for r in rules: rt += "• %s\n" % r
    rulebook_label.text = rt

func _build_ui() -> void:
    var bg := ColorRect.new(); bg.color = Color(0.12,0.1,0.08); bg.size = Vector2(1280,720); add_child(bg)
    title_panel = ColorRect.new(); title_panel.color = Color(0,0,0,0.92); title_panel.size = Vector2(1280,720); title_panel.visible = false; add_child(title_panel)
    var tl := Label.new(); tl.text = "BORDER CHECK\nDocument Inspection Simulation\n\nInspect documents. Approve or deny entry.\nEvery mistake costs you."; tl.position = Vector2(360,180); tl.add_theme_font_size_override("font_size",34); tl.modulate = Color(0.8,0.7,0.5); title_panel.add_child(tl)
    var sb := Button.new(); sb.text = "BEGIN DUTY"; sb.position = Vector2(490,420); sb.size = Vector2(300,65); sb.add_theme_font_size_override("font_size",28); sb.pressed.connect(_on_start); title_panel.add_child(sb)
    desk_panel = ColorRect.new(); desk_panel.color = Color(0.18,0.14,0.1); desk_panel.size = Vector2(1280,720); desk_panel.visible = false; add_child(desk_panel)
    traveler_label = Label.new(); traveler_label.position = Vector2(20,20); traveler_label.add_theme_font_size_override("font_size",20); traveler_label.modulate = Color(0.9,0.85,0.7); desk_panel.add_child(traveler_label)
    for i in range(4):
        var dp := ColorRect.new(); dp.color = Color(0.15,0.12,0.08); dp.size = Vector2(200,130); dp.position = Vector2(20+i*215,180); dp.visible = false; desk_panel.add_child(dp)
        var dl := Label.new(); dl.position = Vector2(8,8); dl.size = Vector2(184,114); dl.add_theme_font_size_override("font_size",14); dl.modulate = Color(0.9,0.85,0.7); dl.autowrap_mode = TextServer.AUTOWRAP_WORD; dp.add_child(dl); doc_panels.append(dp)
    rulebook_label = Label.new(); rulebook_label.position = Vector2(880,20); rulebook_label.size = Vector2(380,300); rulebook_label.add_theme_font_size_override("font_size",16); rulebook_label.modulate = Color(0.8,0.75,0.6); rulebook_label.autowrap_mode = TextServer.AUTOWRAP_WORD; desk_panel.add_child(rulebook_label)
    approve_btn = Button.new(); approve_btn.text = "APPROVE ✓"; approve_btn.position = Vector2(200,380); approve_btn.size = Vector2(200,70); approve_btn.add_theme_font_size_override("font_size",26); approve_btn.modulate = Color(0.3,1.0,0.3); approve_btn.pressed.connect(_on_approve); desk_panel.add_child(approve_btn)
    deny_btn = Button.new(); deny_btn.text = "DENY ✗"; deny_btn.position = Vector2(450,380); deny_btn.size = Vector2(200,70); deny_btn.add_theme_font_size_override("font_size",26); deny_btn.modulate = Color(1.0,0.3,0.3); deny_btn.pressed.connect(_on_deny); desk_panel.add_child(deny_btn)
    stamp_label = Label.new(); stamp_label.position = Vector2(200,470); stamp_label.add_theme_font_size_override("font_size",26); stamp_label.visible = false; desk_panel.add_child(stamp_label)
    hud_label = Label.new(); hud_label.position = Vector2(20,680); hud_label.add_theme_font_size_override("font_size",18); hud_label.modulate = Color(0.8,0.75,0.6); desk_panel.add_child(hud_label)
    moral_panel = ColorRect.new(); moral_panel.color = Color(0.1,0.08,0.05,0.95); moral_panel.size = Vector2(600,160); moral_panel.position = Vector2(340,520); moral_panel.visible = false; desk_panel.add_child(moral_panel)
    moral_label = Label.new(); moral_label.position = Vector2(20,20); moral_label.size = Vector2(560,90); moral_label.add_theme_font_size_override("font_size",18); moral_label.modulate = Color(0.9,0.8,0.5); moral_label.autowrap_mode = TextServer.AUTOWRAP_WORD; moral_panel.add_child(moral_label)
    var dm := Button.new(); dm.text = "Dismiss"; dm.position = Vector2(240,110); dm.size = Vector2(120,35); dm.pressed.connect(func(): moral_panel.visible = false); moral_panel.add_child(dm)
    eod_panel = ColorRect.new(); eod_panel.color = Color(0.05,0.04,0.03,0.95); eod_panel.size = Vector2(700,420); eod_panel.position = Vector2(290,150); eod_panel.visible = false; add_child(eod_panel)
    eod_label = Label.new(); eod_label.position = Vector2(50,30); eod_label.add_theme_font_size_override("font_size",24); eod_label.modulate = Color(0.8,0.75,0.6); eod_panel.add_child(eod_label)
    var nb := Button.new(); nb.text = "Next Day"; nb.position = Vector2(250,340); nb.size = Vector2(200,55); nb.pressed.connect(_on_next_day); eod_panel.add_child(nb)

func _on_start() -> void:
    title_panel.visible = false; desk_panel.visible = true; state = GS.INSPECTING; _next_traveler()

func _stamp(approved: bool) -> void:
    if decision_made: return
    decision_made = true; processed += 1
    var correct_decision := (approved and doc_valid) or (not approved and not doc_valid)
    if correct_decision:
        correct += 1; earnings += 5
        stamp_label.text = "%s — Correct! +5" % ("APPROVED" if approved else "DENIED")
        stamp_label.modulate = Color(0.3,1.0,0.3)
    else:
        citations += 1
        stamp_label.text = "%s — CITATION! %s" % [("APPROVED" if approved else "DENIED"), doc_discrepancy]
        stamp_label.modulate = Color(1.0,0.3,0.3)
    stamp_label.visible = true
    get_tree().create_timer(1.5).timeout.connect(_next_traveler)

func _on_approve() -> void: _stamp(true)
func _on_deny() -> void: _stamp(false)

func _on_next_day() -> void:
    eod_panel.visible = false; day += 1; time_left = 180.0; processed = 0; correct = 0; earnings = 0; citations = 0
    _setup_rules(); state = GS.INSPECTING; _next_traveler()

func _show_eod() -> void:
    eod_panel.visible = true; total_earnings += earnings
    var expenses := 48; var net := earnings - expenses
    eod_label.text = "END OF DAY %d\n\nProcessed: %d  Correct: %d  Citations: %d\nEarnings: %d credits\nExpenses (rent+food+heat): %d\nNet: %d  |  Total Savings: %d\n\nEndings depend on your choices..." % [day, processed, correct, citations, earnings, expenses, net, total_earnings]

func _process(delta: float) -> void:
    if state == GS.INSPECTING:
        time_left -= delta
        if time_left <= 0.0: _show_eod(); state = GS.END_OF_DAY
        hud_label.text = "Day %d  |  Time: %.0fs  |  Processed: %d  |  Earnings: %d  |  Citations: %d" % [day, time_left, processed, earnings, citations]
    queue_redraw()
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":453}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_inspection.json" << 'DEMO'
{"scenario":"inspection","duration_frames":540,"events":[{"frame":30,"type":"mouse_click","button":"left","x":300,"y":415},{"frame":90,"type":"mouse_click","button":"left","x":550,"y":415},{"frame":150,"type":"mouse_click","button":"left","x":300,"y":415},{"frame":210,"type":"mouse_click","button":"left","x":300,"y":415},{"frame":270,"type":"mouse_click","button":"left","x":550,"y":415},{"frame":330,"type":"mouse_click","button":"left","x":300,"y":415},{"frame":390,"type":"mouse_click","button":"left","x":300,"y":415},{"frame":450,"type":"mouse_click","button":"left","x":550,"y":415}]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_end_of_day.json" << 'DEMO'
{"scenario":"end_of_day","duration_frames":300,"events":[{"frame":60,"type":"wait"},{"frame":200,"type":"mouse_click","button":"left","x":540,"y":490}]}
DEMO

echo "Oracle written to $GAME_DIR"
