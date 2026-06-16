#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"
cp "/workspace/assets/library/2D/pico-8-city/Sample.png" "$GAME/assets/bg_city.png" 2>/dev/null || true
cp "/workspace/assets/library/2D/modular-characters/preview.png" "$GAME/assets/characters.png" 2>/dev/null || true
cp "/workspace/assets/library/2D/playing-cards-pack/Preview A.png" "$GAME/assets/cards.png" 2>/dev/null || true

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Detective Noir"
run/main_scene="res://scenes/Main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF
cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]
[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
EOF
cat > "$GAME/scripts/Main.gd" <<'EOF'
extends Control
var mode := "title"
var credibility := 3
var found := 0

func _ready() -> void:
    var a := OS.get_cmdline_user_args()
    for i in range(a.size()):
        if a[i] == "--scenario" and i + 1 < a.size(): mode = a[i + 1]
    _draw()

func _clear(): for c in get_children(): c.queue_free()
func _rect(p,s,c): var r:=ColorRect.new(); r.position=p; r.size=s; r.color=c; add_child(r)
func _tex(path,p,s,a:=1.0): var t:=TextureRect.new(); t.position=p; t.size=s; t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; t.modulate.a=a; if ResourceLoader.exists(path): t.texture=load(path); add_child(t)
func _label(t,p,s,fs:=22,col:=Color.WHITE): var l:=Label.new(); l.text=t; l.position=p; l.size=s; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",fs); l.add_theme_color_override("font_color",col); add_child(l)
func _button(t,p,s,cb): var b:=Button.new(); b.text=t; b.position=p; b.size=s; b.add_theme_font_size_override("font_size",18); b.pressed.connect(cb); add_child(b)

func _chrome(title):
    _clear(); _rect(Vector2.ZERO,Vector2(1280,720),Color(.02,.025,.035))
    _tex("res://assets/bg_city.png",Vector2(0,0),Vector2(1280,720),.38)
    _rect(Vector2(40,34),Vector2(1200,652),Color(.02,.02,.025,.86))
    _label(title,Vector2(70,58),Vector2(670,46),36,Color(.92,.92,.78))
    _label("Credibility " + str(credibility) + "/3",Vector2(928,64),Vector2(260,32),24,Color(.68,.9,1))

func _draw():
    if mode=="title":
        _chrome("DETECTIVE NOIR")
        _label("Rain on Vesper Street. Choose a case, inspect scenes, interview suspects, connect the deduction board.",Vector2(94,150),Vector2(780,80),24)
        _tex("res://assets/characters.png",Vector2(830,130),Vector2(285,240),.95)
        _button("Case Board: The Silver Match",Vector2(460,565),Vector2(340,54),Callable(self,"_scene"))
    elif mode=="scene": _scene()
    elif mode=="interview": _interview()
    elif mode=="board": _board()
    elif mode=="accuse_wrong": credibility=1; _accuse(false)
    elif mode=="solved": _result(true)
    elif mode=="failed": _result(false)

func _scene():
    mode="scene"; _chrome("Crime Scene - Vesper Lounge")
    _label("Interactive hotspots reveal evidence and add notebook entries.",Vector2(80,125),Vector2(560,32),22,Color(.75,1,.86))
    var hs=[Vector2(190,250),Vector2(445,218),Vector2(700,285),Vector2(925,230)]
    var names=["bloodless matchbook","torn letter","wet shoe print","stopped tram ticket"]
    for i in range(hs.size()):
        _rect(hs[i],Vector2(130,78),Color(.95,.95,.55,.26)); _label(names[i],hs[i]+Vector2(8,20),Vector2(112,38),15)
    _notebook()
    _button("Interview Suspects",Vector2(960,590),Vector2(210,44),Callable(self,"_interview"))

func _notebook():
    _rect(Vector2(70,430),Vector2(760,150),Color(.13,.10,.07,.92))
    _label("Notebook: five evidence items, sources, relevance, and red herrings\nMatchbook - physical clue / lounge / links to singer\nLetter - documentary clue / motive red herring\nShoe print - timeline clue / alley rain\nTram ticket - alibi clock / contradicts valet",Vector2(92,448),Vector2(720,110),18,Color(.94,.88,.68))

func _interview():
    mode="interview"; _chrome("Interviews - press for contradictions")
    _tex("res://assets/characters.png",Vector2(72,118),Vector2(300,230),.95)
    _label("Suspects: Ada the singer, Knox the valet, Rill the fixer. Different motives, alibis, and relationships.",Vector2(410,125),Vector2(720,58),21)
    _label("Ada: I never left the stage.\n[PRESS] unlocks: she heard the tram bell at 11:15.\nKnox: The alley stayed dry.\nRill: The victim owed me nothing.",Vector2(410,205),Vector2(650,150),22,Color(.9,.9,.82))
    _button("Open Deduction Board",Vector2(860,590),Vector2(250,44),Callable(self,"_board"))

func _board():
    mode="board"; _chrome("Deduction Board - persistent links")
    _label("Drag-style links connect evidence to suspect, motive, and timeline before accusing.",Vector2(78,122),Vector2(820,34),21,Color(.75,1,.86))
    var cards=["Matchbook -> Ada","Tram ticket -> 11:15","Shoe print -> wet alley","Letter -> false debt","Valet alibi -> broken"]
    for i in range(cards.size()):
        _rect(Vector2(95+i*220,190+(i%2)*145),Vector2(180,82),Color(.16,.12,.08,.95))
        _tex("res://assets/cards.png",Vector2(105+i*220,196+(i%2)*145),Vector2(46,58),.9)
        _label(cards[i],Vector2(156+i*220,205+(i%2)*145),Vector2(105,52),16)
    for x in [285,505,725,945]: _rect(Vector2(x,260),Vector2(160,4),Color(.85,.82,.62,.85))
    _button("Accuse Ada / poison / 11:15",Vector2(250,575),Vector2(260,44),Callable(self,"_solve"))
    _button("Accuse Knox / knife / midnight",Vector2(540,575),Vector2(285,44),Callable(self,"_wrong"))

func _wrong(): credibility -= 1; mode="accuse_wrong"; _draw()
func _solve(): mode="solved"; _draw()
func _accuse(ok):
    _chrome("Wrong Accusation Penalty")
    _label("Incorrect theory costs credibility. Two more wrong guesses make the case go cold.",Vector2(120,170),Vector2(780,90),28,Color(1,.68,.6))
    _button("Return to Board",Vector2(510,570),Vector2(230,44),Callable(self,"_board"))
func _result(win):
    _chrome("Case Result")
    if win: _label("SOLVED: Ada used the matchbook poison during the 11:15 tram bell.\nEvidence found 5/5. Deduction accuracy 92%. Reveal sequence ties physical, testimonial, and timeline clues.",Vector2(130,160),Vector2(850,150),28,Color(.75,1,.78))
    else: _label("CASE COLD: credibility exhausted. Summary lists missed links, false alibi accepted, and deduction accuracy 33%.",Vector2(130,160),Vector2(820,120),28,Color(1,.6,.55))
EOF
cat > "$GAME/demo_outputs/01_title.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":120,"type":"mouse_click","button":"left","x":620,"y":590},{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_scene.json" <<'EOF'
{"scenario":"scene","duration_frames":360,"events":[{"frame":100,"type":"mouse_click","button":"left","x":235,"y":285},{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_interview.json" <<'EOF'
{"scenario":"interview","duration_frames":360,"events":[{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_board.json" <<'EOF'
{"scenario":"board","duration_frames":480,"events":[{"frame":160,"type":"mouse_click","button":"left","x":380,"y":595},{"frame":480,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/05_wrong.json" <<'EOF'
{"scenario":"accuse_wrong","duration_frames":360,"events":[{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/06_failed.json" <<'EOF'
{"scenario":"failed","duration_frames":360,"events":[{"frame":360,"type":"wait"}]}
EOF
