#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/assets" "$GAME/demo_outputs"
copy_asset() { if [ -f "$1" ]; then cp "$1" "$GAME/assets/$2"; fi; }
copy_asset "/workspace/assets/library/2D/cartography-pack/Sample.png" "map.png"
copy_asset "/workspace/assets/library-oga/100-glitch-icons/glitch-icon-01.png" "glitch.png"
copy_asset "/workspace/assets/library/2D/modular-characters/preview.png" "people.png"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Spy Handler"
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
var resources := 4
var trust := {"Lark": 83, "Moth": 47, "Vega": 71}
var queue := ["URGENT Lark: tail at bridge", "Moth: target sighted", "Vega: extraction window closing"]
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
func _chrome(title:String)->void:
    _clear(); _rect(Vector2.ZERO,Vector2(1280,720),Color(0.025,0.04,0.035)); _tex("res://assets/map.png",Vector2(585,98),Vector2(600,360),0.72)
    _rect(Vector2(34,28),Vector2(1212,58),Color(0.04,0.08,0.07,0.96)); _label(title,Vector2(60,43),Vector2(760,34),30,Color(0.7,1,0.75)); _label("Resources: "+str(resources),Vector2(990,46),Vector2(190,30),23,Color(1,0.88,0.45))
func _draw()->void:
    match mode:
        "title":
            _chrome("SPY HANDLER")
            _label("Cold-war command desk: encrypted traffic, map pins, dossiers.",Vector2(82,145),Vector2(760,70),34)
            _button("Open Operations Briefing",Vector2(96,455),Vector2(300,55),"room")
        "room":
            _chrome("Operations Room")
            _rect(Vector2(58,115),Vector2(485,330),Color(0.02,0.08,0.06,0.94)); _label("MESSAGE TERMINAL\nIncoming messages arrive over time and queue by urgency.",Vector2(82,135),Vector2(420,70),24,Color(0.75,1,0.78))
            for i in range(queue.size()): _button(queue[i],Vector2(82,225+i*62),Vector2(405,44),"response")
            _draw_dossiers(); _button("Handle Selected Message",Vector2(885,620),Vector2(280,46),"response")
        "response":
            _chrome("Agent Message: triage decision")
            _label("Lark reports a tail near the bridge. Moth sends conflicting intel: target still inside embassy. Cross-reference trust before responding.",Vector2(70,120),Vector2(650,90),25)
            _draw_dossiers()
            _button("Send backup (-1 resource, Lark safe)",Vector2(76,270),Vector2(360,46),"success")
            _button("Order proceed (cheap, high risk)",Vector2(76,330),Vector2(330,46),"failure")
            _button("Wait 30 sec (window closes)",Vector2(76,390),Vector2(330,46),"failure")
        "success":
            resources = 3; trust["Lark"] = 91; _chrome("Transmission Sent")
            _label("Backup dispatched. Lark safe, surveillance succeeds, Moth's disinformation is flagged and trust ratings update.",Vector2(78,130),Vector2(980,85),29,Color(0.75,1,0.8))
            _button("Conclude Operations",Vector2(920,620),Vector2(245,46),"result_success")
        "failure":
            resources = 4; trust["Moth"] = 22; _chrome("Window Closed")
            _label("Proceeding on unreliable intel burns the extraction window. Lark captured, Moth likely turned, operation fails.",Vector2(78,130),Vector2(980,85),29,Color(1,0.55,0.55))
            _button("Conclude Operations",Vector2(920,620),Vector2(245,46),"result_fail")
        "result_success":
            _chrome("Operation Results")
            _label("Surveillance: success. Extraction: agent safe. Sabotage: delayed but network intact. Agent fates: Lark safe, Vega safe, Moth turned.",Vector2(78,130),Vector2(1030,95),28,Color(0.75,1,0.8))
        "result_fail":
            _chrome("Operation Failed")
            _label("Surveillance compromised. Extraction failed. Agent fates: Lark captured, Moth turned, Vega missing. Different choices produce different fates.",Vector2(78,130),Vector2(1030,95),28,Color(1,0.55,0.55))
func _draw_dossiers()->void:
    _tex("res://assets/people.png",Vector2(805,110),Vector2(320,190),0.9)
    _rect(Vector2(780,330),Vector2(360,185),Color(0.78,0.72,0.56,0.92))
    _label("DOSSIERS\nLark: extraction, trust "+str(trust["Lark"])+"%\nMoth: surveillance, trust "+str(trust["Moth"])+"%, possible disinfo\nVega: sabotage, trust "+str(trust["Vega"])+"%",Vector2(800,348),Vector2(325,145),20,Color(0.05,0.05,0.04))
EOF
cat > "$GAME/demo_outputs/01_flow.json" <<'EOF'
{"duration_frames":500,"events":[{"frame":90,"type":"mouse_click","button":"left","x":245,"y":480},{"frame":210,"type":"mouse_click","button":"left","x":245,"y":248},{"frame":330,"type":"mouse_click","button":"left","x":255,"y":293}]}
EOF
cat > "$GAME/demo_outputs/02_success.json" <<'EOF'
{"scenario":"response","duration_frames":360,"events":[{"frame":150,"type":"mouse_click","button":"left","x":255,"y":293},{"frame":280,"type":"mouse_click","button":"left","x":1030,"y":642}]}
EOF
cat > "$GAME/demo_outputs/03_failure.json" <<'EOF'
{"scenario":"response","duration_frames":360,"events":[{"frame":150,"type":"mouse_click","button":"left","x":250,"y":355},{"frame":280,"type":"mouse_click","button":"left","x":1030,"y":642}]}
EOF
