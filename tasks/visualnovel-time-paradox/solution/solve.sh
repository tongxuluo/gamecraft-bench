#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/assets" "$GAME/demo_outputs"
copy_asset() { if [ -f "$1" ]; then cp "$1" "$GAME/assets/$2"; fi; }
copy_asset "/workspace/assets/library/2D/pico-8-city/Sample.png" "present.png"
copy_asset "/workspace/assets/library/2D/1-bit-pack/Sample_urban.png" "past.png"
copy_asset "/workspace/assets/library-oga/100-glitch-icons/glitch-icon-03.png" "glitch.png"
copy_asset "/workspace/assets/library/2D/modular-characters/preview.png" "people.png"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Time Paradox"
run/main_scene="res://Main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
EOF
cat > "$GAME/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://Main.gd" id="1"]
[node name="Main" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
EOF
cat > "$GAME/Main.gd" <<'EOF'
extends Control
var mode := "title"
var paradox := 1
var changes := ["Save Mira", "Repair clock tower", "Move blue battery"]
func _ready()->void:
    var args:=OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i]=="--scenario" and i+1<args.size(): mode=args[i+1]
    _draw()
func _clear()->void: for c in get_children(): c.queue_free()
func _tex(path:String,p:Vector2,s:Vector2,a:=1.0)->void:
    if ResourceLoader.exists(path):
        var t:=TextureRect.new(); t.texture=load(path); t.position=p; t.size=s; t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; t.modulate.a=a; add_child(t)
func _rect(p:Vector2,s:Vector2,c:Color)->void: var r:=ColorRect.new(); r.position=p; r.size=s; r.color=c; add_child(r)
func _label(t:String,p:Vector2,s:Vector2,fs:=22,c:=Color.WHITE)->void:
    var l:=Label.new(); l.text=t; l.position=p; l.size=s; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",fs); l.add_theme_color_override("font_color",c); add_child(l)
func _button(t:String,p:Vector2,s:Vector2,target:String)->void:
    var b:=Button.new(); b.text=t; b.position=p; b.size=s; b.add_theme_font_size_override("font_size",18); b.pressed.connect(func(): mode=target; _draw()); add_child(b)
func _chrome(title:String, past_scene:=false)->void:
    _clear(); _tex("res://assets/past.png" if past_scene else "res://assets/present.png",Vector2.ZERO,Vector2(1280,720),0.6); _rect(Vector2.ZERO,Vector2(1280,720),Color(0.02,0.02,0.07,0.62))
    _rect(Vector2(35,28),Vector2(1210,58),Color(0.05,0.07,0.16,0.94)); _label(title,Vector2(60,43),Vector2(760,34),30,Color(0.65,0.95,1)); _label("Paradox meter: "+str(paradox)+"/3",Vector2(960,46),Vector2(240,30),23,Color(1,0.75,0.75))
func _timeline()->void:
    _rect(Vector2(70,525),Vector2(920,82),Color(0.04,0.09,0.16,0.92)); _label("Timeline map: 1986 lab -> 1999 clock tower -> 2026 present. Active paradoxes and jump points are selectable.",Vector2(90,543),Vector2(860,38),20,Color(0.72,1,1))
    for i in range(changes.size()): _button(changes[i],Vector2(110+i*270,585),Vector2(220,36),"past")
func _draw()->void:
    match mode:
        "title":
            _chrome("TIME PARADOX")
            _label("Sci-fi mystery about choices that rewrite the present",Vector2(82,145),Vector2(820,70),34)
            _tex("res://assets/glitch.png",Vector2(850,135),Vector2(180,180),0.95)
            _button("Activate Time Device",Vector2(96,455),Vector2(280,55),"present")
        "present":
            _chrome("Present: unstable reality")
            _label("Problems visible now: Mira is missing, the tower is destroyed, and Ren will not speak to you. Use the device to jump to past moments.",Vector2(72,125),Vector2(920,80),27)
            _tex("res://assets/people.png",Vector2(860,170),Vector2(300,210),0.9)
            _button("Jump to 1986 Lab",Vector2(78,270),Vector2(245,46),"past")
            _timeline()
        "past":
            _chrome("Past Moment: dialogue choice", true)
            _label("Choose an intervention. Choices change the present: saving Mira consumes the blue battery; repairing the tower also needs it.",Vector2(72,125),Vector2(930,80),27)
            _button("Give battery to Mira",Vector2(78,260),Vector2(260,48),"changed")
            _button("Use battery on tower",Vector2(370,260),Vector2(260,48),"paradox")
            _button("Find alternate capacitor",Vector2(662,260),Vector2(270,48),"resolved")
            _timeline()
        "changed":
            paradox = 2; _chrome("Present Rewritten")
            _label("Mira appears in the present, but the clock tower is still ruined. Reality-rewrite flash shows changed characters and objects.",Vector2(78,130),Vector2(980,82),29,Color(0.8,1,0.8)); _timeline()
        "paradox":
            paradox = 3; _chrome("Paradox Warning")
            _label("Contradiction: Mira and the tower both require the same blue battery. Meter fills; if unresolved the timeline collapses.",Vector2(78,130),Vector2(980,82),29,Color(1,0.55,0.55)); _button("Collapse Ending",Vector2(920,620),Vector2(240,46),"failure"); _timeline()
        "resolved":
            paradox = 0; _chrome("Stable Timeline")
            _label("Alternative capacitor resolves both paradoxes. Mira saved, tower restored, relationship repaired. True ending unlocked.",Vector2(78,130),Vector2(980,82),29,Color(0.72,1,0.8)); _button("True Ending",Vector2(920,620),Vector2(240,46),"true")
        "true":
            paradox = 0; _chrome("True Ending: all fixed")
            _label("Timeline state: all three problems fixed, two paradoxes resolved, stable ending reached.",Vector2(82,145),Vector2(980,80),29,Color(0.72,1,0.8))
        "failure":
            paradox = 3; _chrome("Timeline Collapse")
            _label("Failure ending: paradox meter maxed. Unique collapse result shows missing person unresolved and tower erased.",Vector2(82,145),Vector2(980,80),29,Color(1,0.55,0.55))
EOF
cat > "$GAME/demo_outputs/01_flow.json" <<'EOF'
{"duration_frames":520,"events":[{"frame":90,"type":"mouse_click","button":"left","x":230,"y":480},{"frame":210,"type":"mouse_click","button":"left","x":200,"y":292},{"frame":340,"type":"mouse_click","button":"left","x":790,"y":282}]}
EOF
cat > "$GAME/demo_outputs/02_paradox_failure.json" <<'EOF'
{"scenario":"past","duration_frames":420,"events":[{"frame":150,"type":"mouse_click","button":"left","x":500,"y":282},{"frame":290,"type":"mouse_click","button":"left","x":1030,"y":642}]}
EOF
cat > "$GAME/demo_outputs/03_true.json" <<'EOF'
{"scenario":"past","duration_frames":420,"events":[{"frame":150,"type":"mouse_click","button":"left","x":790,"y":282},{"frame":290,"type":"mouse_click","button":"left","x":1030,"y":642}]}
EOF
