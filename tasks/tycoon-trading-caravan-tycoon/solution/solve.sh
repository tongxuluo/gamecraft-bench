#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Trading Caravan Tycoon"
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
var money := 140
var cargo := "silk x2, salt x1"
var risk := 18

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            mode = args[i + 1]
    _draw()

func _clear() -> void:
    for c in get_children():
        c.queue_free()

func _rect(p: Vector2, s: Vector2, c: Color) -> void:
    var r := ColorRect.new()
    r.position = p
    r.size = s
    r.color = c
    add_child(r)

func _label(t: String, p: Vector2, s: Vector2, fs := 20, c := Color.WHITE) -> void:
    var l := Label.new()
    l.text = t
    l.position = p
    l.size = s
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", c)
    add_child(l)

func _button(t: String, p: Vector2, s: Vector2, cb: Callable) -> void:
    var b := Button.new()
    b.text = t
    b.position = p
    b.size = s
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(cb)
    add_child(b)

func _town(p: Vector2, name: String, price: String, col: Color) -> void:
    _rect(p, Vector2(105, 78), col)
    _label(name, p + Vector2(10, 10), Vector2(85, 22), 18, Color(0.07, 0.04, 0.02))
    _label(price, p + Vector2(10, 38), Vector2(88, 30), 14, Color(0.07, 0.04, 0.02))

func _cargo(p: Vector2, name: String, col: Color) -> void:
    _rect(p, Vector2(78, 50), col)
    _label(name, p + Vector2(8, 14), Vector2(62, 20), 15, Color(0.06, 0.03, 0.01))

func _market(title: String) -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280,720), Color(0.17,0.12,0.07))
    _rect(Vector2(45,35), Vector2(1190,78), Color(0.31,0.22,0.12))
    _label(title, Vector2(70,52), Vector2(560,42), 34, Color(1.0,0.82,0.42))
    _label("Coins %d   Cargo: %s   Risk %d%%   Goal 300 coins" % [money, cargo, risk], Vector2(650,60), Vector2(560,28), 20)
    _rect(Vector2(70,135), Vector2(610,470), Color(0.24,0.18,0.10))
    _label("REGION MAP", Vector2(100,158), Vector2(190,28), 24, Color(1.0,0.82,0.42))
    _town(Vector2(150,270), "Oasis", "salt 12", Color(0.85,0.68,0.38))
    _town(Vector2(380,210), "Spire", "silk 44", Color(0.72,0.58,0.42))
    _town(Vector2(465,420), "Harbor", "spice 31", Color(0.46,0.68,0.82))
    _town(Vector2(245,450), "Mine", "ore 8", Color(0.58,0.54,0.48))
    _rect(Vector2(245,318), Vector2(260,8), Color(0.88,0.72,0.42))
    _rect(Vector2(470,288), Vector2(8,145), Color(0.88,0.72,0.42))
    _rect(Vector2(288,493), Vector2(180,8), Color(0.88,0.72,0.42))
    _rect(Vector2(350,330), Vector2(42,30), Color(0.55,0.25,0.10))
    _rect(Vector2(720,135), Vector2(225,470), Color(0.23,0.16,0.09))
    _label("MARKET BOARD", Vector2(750,158), Vector2(170,28), 24, Color(1.0,0.82,0.42))
    _cargo(Vector2(755,215), "silk 28", Color(0.82,0.45,0.72))
    _cargo(Vector2(850,215), "salt 10", Color(0.92,0.88,0.76))
    _cargo(Vector2(755,285), "spice 18", Color(0.92,0.38,0.18))
    _cargo(Vector2(850,285), "ore 7", Color(0.54,0.54,0.50))
    _button("Buy Silk", Vector2(760,380), Vector2(150,38), Callable(self,"_buy"))
    _button("Plan Route", Vector2(760,430), Vector2(150,38), Callable(self,"_route"))
    _button("Upgrade", Vector2(760,480), Vector2(150,38), Callable(self,"_upgrade"))
    _rect(Vector2(980,135), Vector2(230,470), Color(0.27,0.18,0.10))
    _label("LEDGER", Vector2(1015,158), Vector2(160,28), 24, Color(1.0,0.82,0.42))

func _draw() -> void:
    if mode == "title":
        _clear()
        _rect(Vector2.ZERO, Vector2(1280,720), Color(0.18,0.12,0.07))
        _rect(Vector2(180,92), Vector2(920,430), Color(0.31,0.22,0.12))
        _rect(Vector2(350,330), Vector2(520,10), Color(0.9,0.7,0.38))
        for x in [300, 440, 580, 720, 860]:
            _rect(Vector2(x, 245), Vector2(82, 60), Color(0.72, 0.55, 0.34))
        _rect(Vector2(570,380), Vector2(140,55), Color(0.50,0.25,0.10))
        _label("TRADING CARAVAN TYCOON", Vector2(270,150), Vector2(760,70), 48, Color(1.0,0.82,0.42))
        _label("Buy low, cross dangerous routes, and sell before debt catches you.", Vector2(330,245), Vector2(630,55), 24)
        _button("Start Caravan", Vector2(530,462), Vector2(220,54), Callable(self,"_market_start"))
    elif mode == "market":
        _market("Market Phase")
        _label("Oasis buys silk for 41 but salt is cheap here. Capacity 3/5.", Vector2(1010,205), Vector2(170,90), 18)
    elif mode == "bought":
        money = 112
        cargo = "silk x3, salt x1"
        _market("Cargo Bought")
        _label("Bought silk at 28. Expected Spire sale: +39 coins after toll.", Vector2(1010,205), Vector2(170,90), 18)
    elif mode == "route_choice":
        _market("Route Planning")
        _label("Dune Road: cost 8, risk 18%, 2 days.\nBandit Pass: cost 3, risk 42%, 1 day.\nRiver Toll: cost 16, risk 6%.", Vector2(1010,205), Vector2(170,145), 18)
        _button("Take Pass", Vector2(1018,385), Vector2(150,38), Callable(self,"_bandit"))
    elif mode == "bandit_event":
        risk = 42
        _market("Travel Event")
        _label("Bandits ambush the shortcut. Guard upgrade blocks cargo loss; without it lose one silk.", Vector2(1010,205), Vector2(170,110), 18)
    elif mode == "upgrade_shop":
        _market("Upgrade Shop")
        _label("Choose one:\n- Guard: -20% bandit loss\n- Cold crate: spice never spoils\n- Scout: reveals route events", Vector2(1010,205), Vector2(170,145), 18)
    elif mode == "near_profit":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.18,0.12,0.07)); _rect(Vector2(260,145), Vector2(760,410), Color(0.31,0.22,0.12)); _label("TRADE EMPIRE FUNDED", Vector2(365,205), Vector2(560,60), 42, Color(1.0,0.82,0.42)); _label("Coins 326 | Contracts 4 | Cargo safe | New town unlocked: Glassport.", Vector2(385,305), Vector2(540,80), 24); _button("Retry", Vector2(515,455), Vector2(120,42), Callable(self,"_market_start")); _button("Title", Vector2(650,455), Vector2(120,42), Callable(self,"_title"))
    elif mode == "near_bankrupt":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.13,0.06,0.04)); _rect(Vector2(260,145), Vector2(760,410), Color(0.30,0.12,0.08)); _label("CARAVAN BANKRUPT", Vector2(410,205), Vector2(500,60), 42, Color(1.0,0.52,0.42)); _label("Debt 46 | Cargo spoiled | Bandit loss unpaid. Return to market and plan safer routes.", Vector2(385,305), Vector2(540,80), 24); _button("Retry", Vector2(580,455), Vector2(120,42), Callable(self,"_market_start"))

func _title() -> void:
    mode = "title"
    _draw()

func _market_start() -> void:
    mode = "market"
    _draw()

func _buy() -> void:
    mode = "bought"
    _draw()

func _route() -> void:
    mode = "route_choice"
    _draw()

func _upgrade() -> void:
    mode = "upgrade_shop"
    _draw()

func _bandit() -> void:
    mode = "bandit_event"
    _draw()
EOF
cat > "$GAME/demo_outputs/00_title.json" <<'EOF'
{"duration_frames":210,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":488},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/01_market.json" <<'EOF'
{"scenario":"market","duration_frames":270,"events":[{"frame":40,"type":"mouse_click","button":"left","x":835,"y":400},{"frame":205,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_route.json" <<'EOF'
{"scenario":"route_choice","duration_frames":270,"events":[{"frame":40,"type":"mouse_click","button":"left","x":1090,"y":405},{"frame":205,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_upgrade.json" <<'EOF'
{"scenario":"upgrade_shop","duration_frames":210,"events":[{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_profit.json" <<'EOF'
{"scenario":"near_profit","duration_frames":180,"events":[{"frame":140,"type":"wait"}]}
EOF
