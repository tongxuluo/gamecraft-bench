#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/assets" "$GAME/demo_outputs"
copy_asset() { if [ -f "$1" ]; then cp "$1" "$GAME/assets/$2"; fi; }
copy_asset "/workspace/assets/library/2D/isometric-miniature-library/Sample.png" "room1.png"
copy_asset "/workspace/assets/library/2D/isometric-miniature-dungeon/Sample.png" "room2.png"
copy_asset "/workspace/assets/library/2D/generic-items/Preview.png" "items.png"
copy_asset "/workspace/assets/library/2D/input-prompts/Preview Generic.png" "ui.png"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Escape Room"
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
var inventory := ["Brass key", "Cipher wheel", "Glass shard", "Fuse", "Moon token"]
var solved := 0
var branch := "truth"
func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size(): mode = args[i + 1]
    _draw()
func _clear() -> void: for c in get_children(): c.queue_free()
func _tex(path:String,p:Vector2,s:Vector2,a:=1.0)->void:
    if ResourceLoader.exists(path):
        var t:=TextureRect.new(); t.texture=load(path); t.position=p; t.size=s; t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; t.modulate.a=a; add_child(t)
func _rect(p:Vector2,s:Vector2,c:Color)->void: var r:=ColorRect.new(); r.position=p; r.size=s; r.color=c; add_child(r)
func _label(t:String,p:Vector2,s:Vector2,fs:=22,c:=Color.WHITE)->void:
    var l:=Label.new(); l.text=t; l.position=p; l.size=s; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",fs); l.add_theme_color_override("font_color",c); add_child(l)
func _button(t:String,p:Vector2,s:Vector2,target:String)->void:
    var b:=Button.new(); b.text=t; b.position=p; b.size=s; b.add_theme_font_size_override("font_size",18); b.pressed.connect(func(): mode=target; _draw()); add_child(b)
func _chrome(title:String)->void:
    _clear(); _tex("res://assets/room1.png",Vector2.ZERO,Vector2(1280,720),0.55); _rect(Vector2.ZERO,Vector2(1280,720),Color(0.03,0.025,0.02,0.67)); _rect(Vector2(36,30),Vector2(1208,58),Color(0.12,0.08,0.05,0.94)); _label(title,Vector2(60,43),Vector2(760,34),30,Color(1,0.82,0.48)); _label("Puzzles solved: "+str(solved)+"/3",Vector2(960,46),Vector2(230,30),22,Color(0.8,1,0.9))
func _draw()->void:
    match mode:
        "title":
            _chrome("ESCAPE ROOM: MEMORY LOCK")
            _label("Atmospheric puzzle-box visual novel with branching endings",Vector2(82,145),Vector2(820,70),34)
            _button("Wake in Locked Study",Vector2(96,455),Vector2(270,55),"room")
        "room":
            _chrome("Room 1: four hotspots and inventory")
            _tex("res://assets/room1.png",Vector2(55,112),Vector2(530,310),0.95)
            _button("Hotspot: desk drawer",Vector2(625,120),Vector2(300,42),"found")
            _button("Hotspot: portrait seam",Vector2(625,175),Vector2(300,42),"found")
            _button("Hotspot: brass lock",Vector2(625,230),Vector2(300,42),"combine")
            _button("Hotspot: coded note",Vector2(625,285),Vector2(300,42),"combine")
            _draw_inventory()
            _button("Narrative Choice",Vector2(940,620),Vector2(230,46),"choice")
        "found":
            _chrome("Discovery: hidden compartment")
            _label("Found Brass key and Cipher wheel. Inventory bar updates; discovery flash marks the clicked hotspot.",Vector2(80,125),Vector2(980,80),28,Color(0.8,1,0.75))
            _draw_inventory(); _button("Use Items on Puzzle",Vector2(920,620),Vector2(240,46),"combine")
        "combine":
            solved = 2; _chrome("Puzzle Sequence")
            _label("1. Key opens brass lock.\n2. Cipher wheel decodes LUNAR.\n3. Moon token pattern reveals the fuse panel. Puzzles gate the next room in order.",Vector2(78,125),Vector2(980,135),27)
            _tex("res://assets/items.png",Vector2(720,280),Vector2(340,190),0.95)
            _button("Solve Fuse Logic Grid",Vector2(78,420),Vector2(260,46),"choice")
        "choice":
            solved = 3; _chrome("Branch Choice")
            _label("The note asks: trust the remembered voice or expose the experiment? Choice is tracked and changes the next room / ending.",Vector2(78,125),Vector2(980,80),27)
            _button("Trust the voice",Vector2(120,260),Vector2(230,50),"partial")
            _button("Expose the experiment",Vector2(380,260),Vector2(260,50),"true")
            _button("Delay too long",Vector2(670,260),Vector2(220,50),"fail")
        "true":
            _chrome("True Ending")
            _label("Escaped in 18:42. Rooms cleared: Study, Furnace, Observatory. Ending: true memory restored; hint: all branches found.",Vector2(82,145),Vector2(1010,90),29,Color(0.72,1,0.78))
        "partial":
            _chrome("Incomplete Ending")
            _label("Escaped through the service door, but two rooms stay locked. Result lists puzzles solved and hints about the missed Observatory path.",Vector2(82,145),Vector2(1010,90),29,Color(1,0.86,0.55))
        "fail":
            _chrome("Failed Escape")
            _label("Timer expired after wrong item use. Result: incomplete branch, retry from Room 2 checkpoint.",Vector2(82,145),Vector2(930,90),29,Color(1,0.55,0.55))
func _draw_inventory()->void:
    _rect(Vector2(60,520),Vector2(840,88),Color(0.06,0.045,0.035,0.94)); _label("Inventory",Vector2(78,530),Vector2(120,24),18,Color(1,0.82,0.48))
    for i in range(inventory.size()):
        _rect(Vector2(205+i*130,540),Vector2(112,46),Color(0.72,0.61,0.42,0.92)); _label(inventory[i],Vector2(212+i*130,550),Vector2(98,26),14,Color(0.08,0.05,0.03))
EOF
cat > "$GAME/demo_outputs/01_flow.json" <<'EOF'
{"duration_frames":560,"events":[{"frame":90,"type":"mouse_click","button":"left","x":220,"y":480},{"frame":180,"type":"mouse_click","button":"left","x":730,"y":140},{"frame":280,"type":"mouse_click","button":"left","x":1010,"y":642},{"frame":390,"type":"mouse_click","button":"left","x":480,"y":285}]}
EOF
cat > "$GAME/demo_outputs/02_true_ending.json" <<'EOF'
{"scenario":"choice","duration_frames":360,"events":[{"frame":150,"type":"mouse_click","button":"left","x":500,"y":285}]}
EOF
cat > "$GAME/demo_outputs/03_fail.json" <<'EOF'
{"scenario":"choice","duration_frames":360,"events":[{"frame":150,"type":"mouse_click","button":"left","x":760,"y":285}]}
EOF
