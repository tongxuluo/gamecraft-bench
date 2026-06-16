#!/usr/bin/env bash
# Oracle reference implementation for simulation-news-editor.
# Minimal newsroom management game: assign reporters, publish editions.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="News Editor"
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

enum GS { TITLE, EDITOR, LAYOUT, SUMMARY, HIRE }
var state := GS.TITLE

# Reporters
var reporters := [
    {"name":"Alex","specialty":"Politics","reliability":0.9,"salary":20,"assigned":false,"story_idx":-1},
    {"name":"Bea", "specialty":"Crime",   "reliability":0.8,"salary":15,"assigned":false,"story_idx":-1},
    {"name":"Carl","specialty":"Sports",  "reliability":0.85,"salary":18,"assigned":false,"story_idx":-1},
    {"name":"Dana","specialty":"Business","reliability":0.75,"salary":16,"assigned":false,"story_idx":-1}
]

# Story leads
var story_leads: Array = []
var story_categories := ["Politics","Crime","Sports","Business","Culture"]
var rng := RandomNumberGenerator.new()

# Edition layout: front, inside, buried
var layout := {"front":-1,"inside":-1,"buried":-1}

# Stats
var edition := 1
var reputation := 50
var readership := 1000
var budget := 200
var accuracy_total := 0
var accuracy_count := 0
var editions_published := 0

# UI
var title_panel: ColorRect
var editor_panel: ColorRect
var layout_panel: ColorRect
var summary_panel: ColorRect
var hire_panel: ColorRect
var hud_label: Label
var story_btns: Array = []
var reporter_btns: Array = []
var layout_labels: Array = []
var selected_story := -1
var selected_reporter := -1

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    _generate_stories()
    if scenario == "editor":
        state = GS.EDITOR; editor_panel.visible = true
    elif scenario == "summary":
        editions_published = 3; reputation = 65; readership = 1400
        state = GS.SUMMARY; _show_summary()
    else:
        state = GS.TITLE; title_panel.visible = true

func _generate_stories() -> void:
    story_leads.clear()
    var headlines := [
        "Mayor Scandal Rocks City Hall","Bank Robbery Downtown","Championship Finals Tonight",
        "Stock Market Surges","Art Festival Opens","New Tax Policy Proposed",
        "Crime Wave Hits Suburbs","Local Team Wins Cup","Tech Giant Merger","Cultural Center Opens"
    ]
    for i in range(5):
        var cat: String = story_categories[rng.randi_range(0, story_categories.size()-1)]
        story_leads.append({
            "headline": headlines[rng.randi_range(0, headlines.size()-1)],
            "category": cat,
            "importance": rng.randi_range(1, 5),
            "assigned_reporter": -1,
            "fact_checked": false,
            "ready": false
        })

func _build_ui() -> void:
    var bg := ColorRect.new(); bg.color = Color(0.9,0.88,0.82); bg.size = Vector2(1280,720); add_child(bg)
    title_panel = ColorRect.new(); title_panel.color = Color(0.1,0.08,0.06,0.95); title_panel.size = Vector2(1280,720); title_panel.visible = false; add_child(title_panel)
    var tl := Label.new(); tl.text = "NEWS EDITOR\nNewsroom Management Simulation\n\nAssign reporters to stories.\nFact-check for accuracy or rush for speed.\nPublish editions to grow readership!"; tl.position = Vector2(320,160); tl.add_theme_font_size_override("font_size",32); tl.modulate = Color(0.9,0.85,0.7); title_panel.add_child(tl)
    var sb := Button.new(); sb.text = "OPEN NEWSROOM"; sb.position = Vector2(490,420); sb.size = Vector2(300,65); sb.add_theme_font_size_override("font_size",28); sb.pressed.connect(_on_start); title_panel.add_child(sb)
    hud_label = Label.new(); hud_label.position = Vector2(10,10); hud_label.add_theme_font_size_override("font_size",18); hud_label.modulate = Color(0.1,0.08,0.06); add_child(hud_label)
    # Editor panel
    editor_panel = ColorRect.new(); editor_panel.color = Color(0.85,0.82,0.76); editor_panel.size = Vector2(1280,720); editor_panel.visible = false; add_child(editor_panel)
    var el := Label.new(); el.text = "STORY LEADS"; el.position = Vector2(20,50); el.add_theme_font_size_override("font_size",22); el.modulate = Color(0.1,0.08,0.06); editor_panel.add_child(el)
    for i in range(5):
        var btn := Button.new(); btn.position = Vector2(20,90+i*60); btn.size = Vector2(580,52); btn.add_theme_font_size_override("font_size",16); btn.pressed.connect(_on_story_select.bind(i)); editor_panel.add_child(btn); story_btns.append(btn)
    var rl := Label.new(); rl.text = "REPORTERS"; rl.position = Vector2(650,50); rl.add_theme_font_size_override("font_size",22); rl.modulate = Color(0.1,0.08,0.06); editor_panel.add_child(rl)
    for i in range(4):
        var btn := Button.new(); btn.position = Vector2(650,90+i*70); btn.size = Vector2(400,60); btn.add_theme_font_size_override("font_size",16); btn.pressed.connect(_on_reporter_select.bind(i)); editor_panel.add_child(btn); reporter_btns.append(btn)
    var assign_btn := Button.new(); assign_btn.text = "Assign Reporter to Story"; assign_btn.position = Vector2(650,380); assign_btn.size = Vector2(400,55); assign_btn.add_theme_font_size_override("font_size",20); assign_btn.pressed.connect(_on_assign); editor_panel.add_child(assign_btn)
    var fc_btn := Button.new(); fc_btn.text = "Fact-Check Selected Story"; fc_btn.position = Vector2(650,445); fc_btn.size = Vector2(400,55); fc_btn.add_theme_font_size_override("font_size",20); fc_btn.pressed.connect(_on_fact_check); editor_panel.add_child(fc_btn)
    var layout_btn := Button.new(); layout_btn.text = "Go to Layout →"; layout_btn.position = Vector2(650,510); layout_btn.size = Vector2(400,55); layout_btn.add_theme_font_size_override("font_size",20); layout_btn.pressed.connect(_on_go_layout); editor_panel.add_child(layout_btn)
    # Layout panel
    layout_panel = ColorRect.new(); layout_panel.color = Color(0.95,0.93,0.88); layout_panel.size = Vector2(1280,720); layout_panel.visible = false; add_child(layout_panel)
    var ll := Label.new(); ll.text = "EDITION LAYOUT\nClick a slot, then click a ready story to place it."; ll.position = Vector2(20,20); ll.add_theme_font_size_override("font_size",22); ll.modulate = Color(0.1,0.08,0.06); layout_panel.add_child(ll)
    var slot_names := ["FRONT PAGE","INSIDE","BURIED"]
    for i in range(3):
        var slot := ColorRect.new(); slot.color = Color(0.7,0.65,0.58); slot.size = Vector2(360,120); slot.position = Vector2(20+i*380,100); layout_panel.add_child(slot)
        var sl := Label.new(); sl.text = slot_names[i] + "\n(empty)"; sl.position = Vector2(10,10); sl.size = Vector2(340,100); sl.add_theme_font_size_override("font_size",18); sl.modulate = Color(0.1,0.08,0.06); sl.autowrap_mode = TextServer.AUTOWRAP_WORD; slot.add_child(sl); layout_labels.append(sl)
        var slot_btn := Button.new(); slot_btn.text = "Place here"; slot_btn.position = Vector2(10,90); slot_btn.size = Vector2(340,25); slot_btn.pressed.connect(_on_place_story.bind(i)); slot.add_child(slot_btn)
    var ready_lbl := Label.new(); ready_lbl.name = "ReadyLabel"; ready_lbl.text = "Ready stories:"; ready_lbl.position = Vector2(20,260); ready_lbl.add_theme_font_size_override("font_size",20); ready_lbl.modulate = Color(0.1,0.08,0.06); layout_panel.add_child(ready_lbl)
    var pub_btn := Button.new(); pub_btn.text = "PUBLISH EDITION"; pub_btn.position = Vector2(490,620); pub_btn.size = Vector2(300,65); pub_btn.add_theme_font_size_override("font_size",26); pub_btn.pressed.connect(_on_publish); layout_panel.add_child(pub_btn)
    # Summary panel
    summary_panel = ColorRect.new(); summary_panel.color = Color(0.1,0.08,0.06,0.95); summary_panel.size = Vector2(700,420); summary_panel.position = Vector2(290,150); summary_panel.visible = false; add_child(summary_panel)
    var sl2 := Label.new(); sl2.name = "SummaryLabel"; sl2.position = Vector2(50,30); sl2.add_theme_font_size_override("font_size",24); sl2.modulate = Color(0.9,0.85,0.7); summary_panel.add_child(sl2)
    var nb := Button.new(); nb.text = "Next Edition"; nb.position = Vector2(250,340); nb.size = Vector2(200,55); nb.pressed.connect(_on_next_edition); summary_panel.add_child(nb)
    # Hire panel
    hire_panel = ColorRect.new(); hire_panel.color = Color(0.1,0.08,0.06,0.95); hire_panel.size = Vector2(700,400); hire_panel.position = Vector2(290,160); hire_panel.visible = false; add_child(hire_panel)
    var hl := Label.new(); hl.text = "HIRE / MANAGE REPORTERS\nBudget: 200"; hl.position = Vector2(150,20); hl.add_theme_font_size_override("font_size",26); hl.modulate = Color(0.9,0.85,0.7); hire_panel.add_child(hl)
    var candidates := ["Eve (Culture, $18)","Frank (Politics, $22)","Grace (Crime, $16)"]
    for i in range(candidates.size()):
        var hb := Button.new(); hb.text = "Hire: " + candidates[i]; hb.position = Vector2(100,100+i*70); hb.size = Vector2(500,55); hb.add_theme_font_size_override("font_size",20); hb.pressed.connect(_on_hire.bind(i)); hire_panel.add_child(hb)
    var hclose := Button.new(); hclose.text = "Close"; hclose.position = Vector2(280,320); hclose.size = Vector2(140,50); hclose.pressed.connect(func(): hire_panel.visible = false); hire_panel.add_child(hclose)

func _on_start() -> void:
    title_panel.visible = false; editor_panel.visible = true; state = GS.EDITOR; _refresh_editor()

func _on_story_select(idx: int) -> void: selected_story = idx; _refresh_editor()
func _on_reporter_select(idx: int) -> void: selected_reporter = idx; _refresh_editor()

func _on_assign() -> void:
    if selected_story < 0 or selected_reporter < 0: return
    if selected_story >= story_leads.size() or selected_reporter >= reporters.size(): return
    var r: Dictionary = reporters[selected_reporter]
    if bool(r["assigned"]): return
    r["assigned"] = true; r["story_idx"] = selected_story
    story_leads[selected_story]["assigned_reporter"] = selected_reporter
    story_leads[selected_story]["ready"] = true
    _refresh_editor()

func _on_fact_check() -> void:
    if selected_story < 0 or selected_story >= story_leads.size(): return
    story_leads[selected_story]["fact_checked"] = true
    _refresh_editor()

func _on_go_layout() -> void:
    editor_panel.visible = false; layout_panel.visible = true; state = GS.LAYOUT; _refresh_layout()

func _on_place_story(slot: int) -> void:
    if selected_story < 0 or selected_story >= story_leads.size(): return
    if not bool(story_leads[selected_story]["ready"]): return
    match slot:
        0: layout["front"] = selected_story
        1: layout["inside"] = selected_story
        2: layout["buried"] = selected_story
    _refresh_layout()

func _on_publish() -> void:
    editions_published += 1
    var accuracy := 0.0; var count := 0
    for slot_key in ["front","inside","buried"]:
        var idx: int = layout[slot_key]
        if idx >= 0 and idx < story_leads.size():
            var s: Dictionary = story_leads[idx]
            var r_idx: int = int(s["assigned_reporter"])
            var rel := 0.8
            if r_idx >= 0 and r_idx < reporters.size(): rel = float(reporters[r_idx]["reliability"])
            if bool(s["fact_checked"]): rel = min(1.0, rel + 0.1)
            accuracy += rel; count += 1
    if count > 0:
        var avg_acc: float = accuracy / float(count)
        accuracy_total += int(avg_acc * 100.0); accuracy_count += 1
        reputation = clamp(reputation + int((avg_acc - 0.5) * 20.0), 0, 100)
        readership = int(float(readership) * (1.0 + (avg_acc - 0.5) * 0.1))
    var salaries := 0
    for r in reporters: salaries += int(r["salary"])
    budget -= salaries; budget += 50 + int(float(readership) / 100.0)
    _show_summary()

func _show_summary() -> void:
    state = GS.SUMMARY; layout_panel.visible = false; summary_panel.visible = true
    var avg_acc := int(float(accuracy_total) / max(1, accuracy_count))
    var sl: Label = summary_panel.get_node("SummaryLabel")
    sl.text = "EDITION %d PUBLISHED\n\nAccuracy Rate: %d%%\nReputation: %d/100\nReadership: %d\nBudget: %d\n\nStories Published: %d\nReporters: %d" % [edition, avg_acc, reputation, readership, budget, editions_published, reporters.size()]

func _on_next_edition() -> void:
    summary_panel.visible = false; edition += 1
    for r in reporters: r["assigned"] = false; r["story_idx"] = -1
    layout = {"front":-1,"inside":-1,"buried":-1}
    _generate_stories(); state = GS.EDITOR; editor_panel.visible = true; _refresh_editor()

func _on_hire(idx: int) -> void:
    var new_reporters := [
        {"name":"Eve","specialty":"Culture","reliability":0.82,"salary":18,"assigned":false,"story_idx":-1},
        {"name":"Frank","specialty":"Politics","reliability":0.88,"salary":22,"assigned":false,"story_idx":-1},
        {"name":"Grace","specialty":"Crime","reliability":0.78,"salary":16,"assigned":false,"story_idx":-1}
    ]
    if idx < new_reporters.size(): reporters.append(new_reporters[idx])
    hire_panel.visible = false; _refresh_editor()

func _refresh_editor() -> void:
    for i in range(story_btns.size()):
        if i < story_leads.size():
            var s: Dictionary = story_leads[i]
            var status := "OK" if bool(s["ready"]) else "--"
            var fc := "(FC)" if bool(s["fact_checked"]) else ""
            var hl: String = str(s["headline"])
            story_btns[i].text = "%s %s (%s) Imp:%d %s" % [status, hl.substr(0, 30), str(s["category"]), int(s["importance"]), fc]
            story_btns[i].modulate = Color(0.3,1.0,0.3) if i == selected_story else Color.WHITE
    for i in range(reporter_btns.size()):
        if i < reporters.size():
            var r: Dictionary = reporters[i]
            reporter_btns[i].text = "%s (%s) Rel:%.0f%% $%d %s" % [str(r["name"]), str(r["specialty"]), float(r["reliability"])*100.0, int(r["salary"]), "[BUSY]" if bool(r["assigned"]) else ""]
            reporter_btns[i].modulate = Color(0.3,1.0,0.3) if i == selected_reporter else Color.WHITE
    hud_label.text = "Edition %d  |  Reputation: %d  |  Readership: %d  |  Budget: %d" % [edition, reputation, readership, budget]

func _refresh_layout() -> void:
    var slot_keys := ["front","inside","buried"]
    for i in range(3):
        var idx: int = layout[slot_keys[i]]
        if idx >= 0 and idx < story_leads.size():
            layout_labels[i].text = slot_keys[i].to_upper() + "\n" + str(story_leads[idx]["headline"]).substr(0, 40)
        else:
            layout_labels[i].text = slot_keys[i].to_upper() + "\n(empty)"
    var rl: Label = layout_panel.get_node("ReadyLabel")
    var ready_text := "Ready stories:\n"
    for i in range(story_leads.size()):
        if bool(story_leads[i]["ready"]): ready_text += "  [%d] %s\n" % [i, str(story_leads[i]["headline"]).substr(0, 40)]
    rl.text = ready_text

func _process(_delta: float) -> void:
    queue_redraw()
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":453}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_editor.json" << 'DEMO'
{"scenario":"editor","duration_frames":540,"events":[{"frame":30,"type":"mouse_click","button":"left","x":310,"y":120},{"frame":60,"type":"mouse_click","button":"left","x":850,"y":120},{"frame":90,"type":"mouse_click","button":"left","x":850,"y":413},{"frame":120,"type":"mouse_click","button":"left","x":310,"y":180},{"frame":150,"type":"mouse_click","button":"left","x":850,"y":190},{"frame":180,"type":"mouse_click","button":"left","x":850,"y":413},{"frame":210,"type":"mouse_click","button":"left","x":310,"y":120},{"frame":240,"type":"mouse_click","button":"left","x":850,"y":478},{"frame":300,"type":"mouse_click","button":"left","x":850,"y":543},{"frame":360,"type":"wait"},{"frame":420,"type":"mouse_click","button":"left","x":310,"y":120},{"frame":450,"type":"mouse_click","button":"left","x":200,"y":140},{"frame":480,"type":"mouse_click","button":"left","x":580,"y":140},{"frame":510,"type":"mouse_click","button":"left","x":960,"y":140}]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_summary.json" << 'DEMO'
{"scenario":"summary","duration_frames":300,"events":[{"frame":60,"type":"wait"},{"frame":200,"type":"mouse_click","button":"left","x":540,"y":490}]}
DEMO

echo "Oracle written to $GAME_DIR"
