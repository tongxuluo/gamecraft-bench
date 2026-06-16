#!/bin/bash
# Reference solution for gamecraft-bench/strategy-ashen-spire.
#
# Writes a compact Slay-the-Spire-like deckbuilder into /workspace/game:
#   - compact illustrated title screen and branching route map
#   - turn-based combat with energy, hand, draw/discard piles, block, enemy
#     intent, animated card resolution, and enemy turns
#   - hero-flavored skill cards, random route monsters, biome backdrops
#   - three-card reward drafting that persists into later fights
#   - deterministic scenarios and demo traces for verifier coverage
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="strategy-ashen-spire"
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

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEW := Vector2(1280, 720)
const CARD_W := 142.0
const CARD_H := 174.0
const HAND_Y := 500.0

const INK := Color(0.06, 0.055, 0.07)
const PANEL := Color(0.13, 0.105, 0.105)
const PANEL_2 := Color(0.18, 0.145, 0.13)
const GOLD := Color(0.86, 0.62, 0.24)
const RED := Color(0.66, 0.12, 0.13)
const GREEN := Color(0.24, 0.54, 0.35)
const BLUE := Color(0.23, 0.42, 0.66)
const VIOLET := Color(0.38, 0.23, 0.55)
const TEAL := Color(0.16, 0.50, 0.48)
const ROSE := Color(0.63, 0.19, 0.30)
const JADE := Color(0.18, 0.47, 0.30)
const TEXT := Color(0.93, 0.86, 0.72)
const MUTED := Color(0.52, 0.46, 0.40)

var ui: CanvasLayer
var root: Control
var fx: Control
var scenario := ""
var state := "title"
var busy := false
var rng := RandomNumberGenerator.new()

var deck: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var hand: Array = []
var rewards: Array = []
var map_step := 0
var chosen_branch := ""
var current_node := "fight"
var current_map := "gate"
var map_nodes: Array = []
var hero_id := "duelist"
var hero_name := "Cinder Duelist"
var run_seed := 7

var player_hp := 70
var player_max_hp := 70
var player_block := 0
var energy := 3
var max_energy := 3
var turn_no := 1
var combat_wins := 0

var enemy := {}

func _ready() -> void:
    rng.seed = run_seed
    _parse_args()
    ui = CanvasLayer.new()
    add_child(ui)
    root = Control.new()
    root.size = VIEW
    ui.add_child(root)
    fx = Control.new()
    fx.size = VIEW
    ui.add_child(fx)
    _new_run()
    if scenario == "":
        _show_title()
    elif scenario == "reward_pick":
        map_step = 1
        rewards = ["cleave", "barrier", "ember"]
        _show_reward()
    elif scenario == "near_defeat":
        _start_combat("brute", true, "near_defeat")
    elif scenario == "near_victory":
        _start_combat("cultist", true, "near_victory")
    else:
        _start_combat("cultist", true, "combat_basic")

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _new_run() -> void:
    rng.seed = run_seed
    hero_id = "duelist"
    hero_name = "Cinder Duelist"
    deck = ["strike", "strike", "strike", "defend", "defend", "defend", "bash", "glass_needle", "ember_step"]
    draw_pile.clear()
    discard_pile.clear()
    hand.clear()
    rewards.clear()
    map_step = 0
    chosen_branch = ""
    current_node = "fight"
    current_map = "gate"
    map_nodes.clear()
    player_hp = player_max_hp
    player_block = 0
    energy = max_energy
    turn_no = 1
    combat_wins = 0
    busy = false
    _plan_route()

func _plan_route() -> void:
    var first_pool := [
        {"type": "cultist", "name": "Ash Choir", "map": "gate"},
        {"type": "moth", "name": "Lantern Moth", "map": "garden"},
        {"type": "mimic", "name": "Reliquary Mimic", "map": "reliquary"}
    ]
    var second_pool := [
        {"type": "brute", "name": "Furnace Brute", "map": "forge"},
        {"type": "witch", "name": "Velvet Witch", "map": "garden"},
        {"type": "cartographer", "name": "Bone Cartographer", "map": "archive"}
    ]
    var a: Dictionary = first_pool[rng.randi_range(0, first_pool.size() - 1)]
    var b: Dictionary = second_pool[rng.randi_range(0, second_pool.size() - 1)]
    map_nodes = [
        {"type": a["type"], "name": a["name"], "map": a["map"], "pos": Vector2(220, 388), "step": 0, "branch": "low"},
        {"type": b["type"], "name": b["name"], "map": b["map"], "pos": Vector2(220, 228), "step": 0, "branch": "high"},
        {"type": "elite", "name": "Iron Hexer", "map": "archive", "pos": Vector2(555, 306), "step": 1, "branch": "any"},
        {"type": "boss", "name": "Heart of Ash", "map": "spire", "pos": Vector2(890, 306), "step": 2, "branch": "any"}
    ]

func _clear() -> void:
    for c in root.get_children():
        c.queue_free()

func _bg() -> void:
    var bg := ColorRect.new()
    bg.color = INK
    bg.size = VIEW
    root.add_child(bg)
    for i in range(10):
        var stripe := ColorRect.new()
        stripe.color = Color(0.12, 0.08, 0.07, 0.16 + float(i % 3) * 0.04)
        stripe.position = Vector2(i * 145 - 80, 0)
        stripe.rotation = -0.16
        stripe.size = Vector2(70, 900)
        root.add_child(stripe)

func _biome_style(key: String) -> Dictionary:
    var styles := {
        "gate": {"base": Color(0.09, 0.075, 0.085), "accent": Color(0.55, 0.34, 0.20), "name": "Cinder Gate"},
        "garden": {"base": Color(0.055, 0.105, 0.095), "accent": TEAL, "name": "Glass Garden"},
        "reliquary": {"base": Color(0.105, 0.075, 0.105), "accent": VIOLET, "name": "Saint Reliquary"},
        "forge": {"base": Color(0.13, 0.065, 0.052), "accent": RED, "name": "Needle Forge"},
        "archive": {"base": Color(0.075, 0.083, 0.11), "accent": BLUE, "name": "Bone Archive"},
        "spire": {"base": Color(0.10, 0.055, 0.07), "accent": GOLD, "name": "Ashen Crown"}
    }
    return styles.get(key, styles["gate"])

func _draw_backdrop(key: String, rect: Rect2, alpha := 1.0) -> void:
    var s := _biome_style(key)
    var base_color: Color = s["base"]
    var accent: Color = s["accent"]
    var base := ColorRect.new()
    base.position = rect.position
    base.size = rect.size
    base.color = Color(base_color.r, base_color.g, base_color.b, 0.86 * alpha)
    root.add_child(base)
    for i in range(5):
        var band := ColorRect.new()
        band.position = rect.position + Vector2(18 + i * rect.size.x / 5.8, 14)
        band.size = Vector2(10 + i * 2, rect.size.y - 28)
        band.color = Color(accent.r, accent.g, accent.b, (0.10 + i * 0.018) * alpha)
        band.rotation = -0.08
        root.add_child(band)
    for i in range(4):
        var shard := ColorRect.new()
        shard.position = rect.position + Vector2(35 + i * 72, rect.size.y - 35 - (i % 2) * 18)
        shard.size = Vector2(46, 5)
        shard.color = Color(accent.r, accent.g, accent.b, 0.42 * alpha)
        shard.rotation = 0.32 - i * 0.16
        root.add_child(shard)

func _pixel_palette(accent: Color) -> Dictionary:
    return {
        ".": Color(0, 0, 0, 0),
        "0": Color(0.035, 0.030, 0.035),
        "1": accent.darkened(0.42),
        "2": accent.darkened(0.12),
        "3": accent.lightened(0.20),
        "4": Color(0.96, 0.78, 0.34),
        "5": Color(0.94, 0.86, 0.68),
        "6": Color(0.60, 0.10, 0.12)
    }

func _pixel_texture(rows: Array, palette: Dictionary) -> ImageTexture:
    var width := String(rows[0]).length()
    var height := rows.size()
    var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
    for y in range(height):
        var line := String(rows[y])
        for x in range(width):
            var key := line.substr(x, 1)
            var color: Color = palette.get(key, Color(0, 0, 0, 0))
            img.set_pixel(x, y, color)
    return ImageTexture.create_from_image(img)

func _pixel_sprite(pos: Vector2, rows: Array, palette: Dictionary, scale: int, parent: Node = null) -> TextureRect:
    if parent == null:
        parent = root
    var t := TextureRect.new()
    t.texture = _pixel_texture(rows, palette)
    t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    t.position = pos
    t.size = Vector2(String(rows[0]).length() * scale, rows.size() * scale)
    parent.add_child(t)
    return t

func _hero_rows() -> Array:
    return [
        "................",
        "......000.......",
        ".....03330......",
        ".....03430......",
        "....003330......",
        "...00222200.....",
        "..002222220.....",
        "..022525220.....",
        ".00222222200....",
        "...0222220......",
        "...0111110.00...",
        "...0110110004...",
        "...001100..04...",
        "....00.00..04...",
        "...00...00......",
        "................"
    ]

func _enemy_rows(shape: String) -> Array:
    if shape == "moth":
        return [
            "................",
            "...00....00.....",
            "..0220..0220....",
            ".02222022220....",
            ".02332223320....",
            "..022222220.....",
            "....03330.......",
            "...032230.......",
            "...032230.......",
            "....0220........",
            "...002200.......",
            "..00....00......",
            "................",
            "................",
            "................",
            "................"
        ]
    elif shape == "mimic":
        return [
            "................",
            "................",
            "...00000000.....",
            "..0333333300....",
            ".03222222230....",
            ".03244444230....",
            ".03000000030....",
            ".03262626230....",
            ".03222222230....",
            "..033333330.....",
            "...0000000......",
            "....00..00......",
            "................",
            "................",
            "................",
            "................"
        ]
    elif shape == "spire":
        return [
            ".......00.......",
            "......0330......",
            ".....032230.....",
            "....03222230....",
            "...032244230....",
            "..03222222230...",
            "..03222622230...",
            "...032222230....",
            "....0322230.....",
            "....032230......",
            "...00333300.....",
            "..0032222300....",
            ".000322223000...",
            "....000000......",
            "................",
            "................"
        ]
    elif shape == "witch":
        return [
            "................",
            "......00........",
            ".....0220.......",
            "....022220......",
            "...00033000.....",
            ".....0330.......",
            "....032230......",
            "...03222230.....",
            "..003242300.....",
            "....02220.......",
            "...0011100......",
            "...0100100......",
            "...00..00.......",
            "................",
            "................",
            "................"
        ]
    else:
        return [
            "................",
            "......00........",
            ".....0330.......",
            ".....34430......",
            "....033330......",
            "...00222200.....",
            "..002262220.....",
            "..022222220.....",
            ".00222222200....",
            "...0222220......",
            "...0111110......",
            "...0101010......",
            "...00...00......",
            "................",
            "................",
            "................"
        ]

func _mini_portrait(pos: Vector2, kind: String, accent: Color, parent: Node = null) -> void:
    if parent == null:
        parent = root
    var frame := Panel.new()
    frame.position = pos
    frame.size = Vector2(82, 82)
    _style_panel(frame, Color(0.075, 0.065, 0.07), accent, 7)
    parent.add_child(frame)
    var rows := _hero_rows() if kind == "hero" else _enemy_rows(kind)
    _pixel_sprite(Vector2(9, 9), rows, _pixel_palette(accent), 4, frame)

func _panel(pos: Vector2, size: Vector2, color := PANEL, border := GOLD) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size
    _style_panel(p, color, border, 8)
    root.add_child(p)
    return p

func _label(text: String, pos: Vector2, size: Vector2, font := 24, color := TEXT, parent: Node = null) -> Label:
    if parent == null:
        parent = root
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.add_theme_font_size_override("font_size", font)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    l.add_theme_constant_override("shadow_offset_x", 2)
    l.add_theme_constant_override("shadow_offset_y", 2)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(l)
    return l

func _button(text: String, pos: Vector2, size: Vector2, callable: Callable, parent: Node = null) -> Button:
    if parent == null:
        parent = root
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 23)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_stylebox_override("normal", _box(PANEL_2, GOLD, 8, 2))
    b.add_theme_stylebox_override("hover", _box(Color(0.25, 0.17, 0.12), Color(1.0, 0.78, 0.32), 8, 2))
    b.add_theme_stylebox_override("pressed", _box(Color(0.10, 0.07, 0.06), GOLD, 8, 2))
    b.pressed.connect(callable)
    parent.add_child(b)
    return b

func _box(color: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.border_color = border
    s.set_border_width_all(border_width)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 10
    s.content_margin_right = 10
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _style_panel(node: Control, color: Color, border: Color, radius: int) -> void:
    node.add_theme_stylebox_override("panel", _box(color, border, radius, 2))

func _transition(to_call: Callable) -> void:
    var fade := ColorRect.new()
    fade.color = Color(0, 0, 0, 0)
    fade.size = VIEW
    fx.add_child(fade)
    var tw := create_tween()
    tw.tween_property(fade, "color", Color(0, 0, 0, 0.75), 0.16)
    tw.tween_callback(to_call)
    tw.tween_property(fade, "color", Color(0, 0, 0, 0), 0.16)
    tw.tween_callback(Callable(fade, "queue_free"))

func _show_title() -> void:
    state = "title"
    _clear()
    _bg()
    _draw_backdrop("spire", Rect2(Vector2(0, 0), VIEW), 0.75)
    _panel(Vector2(360, 88), Vector2(560, 500), Color(0.095, 0.066, 0.075, 0.94), GOLD)
    _label("ASHEN SPIRE", Vector2(385, 122), Vector2(510, 72), 58, Color(0.95, 0.72, 0.32))
    _label("tiny roguelike deck rite", Vector2(438, 198), Vector2(404, 32), 20, TEXT)
    _mini_portrait(Vector2(446, 252), "hero", ROSE)
    _label("Cinder Duelist", Vector2(560, 254), Vector2(230, 28), 25, TEXT)
    _label("Twin arts: Glass Needle\nand Ember Step.", Vector2(545, 292), Vector2(260, 58), 17, MUTED)
    _button("START RUN", Vector2(530, 432), Vector2(220, 66), Callable(self, "_on_start_pressed"))

func _on_start_pressed() -> void:
    _transition(Callable(self, "_show_map"))

func _show_map() -> void:
    state = "map"
    busy = false
    _clear()
    _bg()
    _label("Pocket Route of the Ashen Spire", Vector2(260, 34), Vector2(760, 54), 36, Color(0.93, 0.70, 0.34))
    _panel(Vector2(118, 104), Vector2(1044, 492), Color(0.07, 0.067, 0.075, 0.90), Color(0.45, 0.33, 0.22))
    _label("%s    Deck %d    HP %d/%d    Victories %d" % [hero_name, deck.size(), player_hp, player_max_hp, combat_wins],
        Vector2(210, 612), Vector2(860, 34), 20, TEXT)
    for n in map_nodes:
        _draw_map_backdrop(n)
    _draw_map_lines(map_nodes)
    for n in map_nodes:
        _add_map_node(n)

func _draw_map_backdrop(n: Dictionary) -> void:
    var pos: Vector2 = n["pos"]
    var rect := Rect2(pos - Vector2(28, 38), Vector2(168, 154))
    _draw_backdrop(n["map"], rect, 0.62 if int(n["step"]) <= map_step else 0.28)
    var s := _biome_style(n["map"])
    var accent: Color = s["accent"]
    _label(s["name"], pos + Vector2(-20, 86), Vector2(152, 24), 14, Color(accent.r, accent.g, accent.b, 0.92))

func _shape_for_type(node_type: String) -> String:
    if node_type == "boss":
        return "spire"
    elif node_type == "moth":
        return "moth"
    elif node_type == "mimic":
        return "mimic"
    elif node_type == "witch":
        return "witch"
    elif node_type == "brute":
        return "brute"
    elif node_type == "elite" or node_type == "cartographer":
        return "hexer"
    return "cultist"

func _accent_for_type(node_type: String) -> Color:
    if node_type == "boss":
        return GOLD
    elif node_type == "moth":
        return TEAL
    elif node_type == "mimic" or node_type == "elite":
        return VIOLET
    elif node_type == "witch":
        return ROSE
    elif node_type == "brute":
        return RED
    elif node_type == "cartographer":
        return BLUE
    return JADE

func _draw_map_lines(nodes: Array) -> void:
    var line_root := Control.new()
    line_root.size = VIEW
    root.add_child(line_root)
    for pair in [[0, 2], [1, 2], [2, 3]]:
        var a: Vector2 = nodes[pair[0]].pos + Vector2(56, 56)
        var b: Vector2 = nodes[pair[1]].pos + Vector2(56, 56)
        var seg := ColorRect.new()
        seg.color = Color(0.42, 0.31, 0.22, 0.75)
        seg.position = a
        seg.size = Vector2(a.distance_to(b), 5)
        seg.rotation = (b - a).angle()
        line_root.add_child(seg)

func _add_map_node(n: Dictionary) -> void:
    var unlocked := int(n["step"]) == map_step
    var completed := int(n["step"]) < map_step
    var label_text := "%s\n%s" % [n["name"], "SEALED" if completed else ("ENTER" if unlocked else "VEILED")]
    var btn := _button(label_text, n["pos"], Vector2(112, 90), Callable(self, "_on_map_node").bind(n["type"], n["branch"], n["map"]))
    btn.disabled = not unlocked
    btn.add_theme_font_size_override("font_size", 15)
    if completed:
        btn.add_theme_stylebox_override("normal", _box(Color(0.11, 0.24, 0.16), GREEN, 10, 3))
        btn.disabled = true
    elif not unlocked:
        btn.add_theme_stylebox_override("disabled", _box(Color(0.10, 0.09, 0.09), Color(0.23, 0.20, 0.18), 10, 2))
        btn.modulate = Color(0.55, 0.52, 0.50, 1)
    else:
        var s := _biome_style(n["map"])
        var accent: Color = s["accent"]
        btn.add_theme_stylebox_override("normal", _box(accent.darkened(0.35), GOLD, 10, 3))
    var node_pos: Vector2 = n["pos"]
    var sprite_alpha := 1.0 if unlocked else (0.55 if completed else 0.30)
    var sprite := _pixel_sprite(node_pos + Vector2(38, -30), _enemy_rows(_shape_for_type(n["type"])), _pixel_palette(_accent_for_type(n["type"])), 3)
    sprite.modulate = Color(1, 1, 1, sprite_alpha)

func _on_map_node(node_type: String, branch: String, map_key: String) -> void:
    if map_step == 0:
        chosen_branch = branch
    current_map = map_key
    _transition(Callable(self, "_start_combat").bind(node_type, false, ""))

func _start_combat(node_type: String, skip_transition := false, mode := "") -> void:
    state = "combat"
    busy = false
    current_node = node_type
    if mode == "near_victory":
        current_map = "garden"
    elif mode == "near_defeat":
        current_map = "forge"
    elif current_map == "":
        current_map = "gate"
    player_block = 0
    energy = max_energy
    turn_no = 1
    _setup_enemy(node_type)
    draw_pile = deck.duplicate()
    discard_pile.clear()
    hand.clear()
    if mode == "near_victory":
        enemy["hp"] = 5
        draw_pile = ["glass_needle", "cleave", "defend", "bash"]
    elif mode == "near_defeat":
        player_hp = 4
        draw_pile = ["defend", "ember_step", "strike"]
        enemy["intent"] = {"type": "attack", "amount": 9, "text": "Attack 9"}
    _draw_cards(5)
    if mode != "near_defeat":
        _set_enemy_intent()
    _render_combat()

func _setup_enemy(node_type: String) -> void:
    if node_type == "boss":
        enemy = {"name": "Heart of Ash", "hp": 48, "max_hp": 48, "block": 0, "turn": 0, "intent": {}, "color": GOLD, "shape": "spire", "mark": 0}
    elif node_type == "elite":
        enemy = {"name": "Iron Hexer", "hp": 38, "max_hp": 38, "block": 0, "turn": 0, "intent": {}, "color": VIOLET, "shape": "hexer", "mark": 0}
    elif node_type == "brute":
        enemy = {"name": "Furnace Brute", "hp": 34, "max_hp": 34, "block": 0, "turn": 0, "intent": {}, "color": RED, "shape": "brute", "mark": 0}
    elif node_type == "moth":
        enemy = {"name": "Lantern Moth", "hp": 26, "max_hp": 26, "block": 0, "turn": 0, "intent": {}, "color": TEAL, "shape": "moth", "mark": 0}
    elif node_type == "mimic":
        enemy = {"name": "Reliquary Mimic", "hp": 30, "max_hp": 30, "block": 3, "turn": 0, "intent": {}, "color": VIOLET, "shape": "mimic", "mark": 0}
    elif node_type == "witch":
        enemy = {"name": "Velvet Witch", "hp": 31, "max_hp": 31, "block": 0, "turn": 0, "intent": {}, "color": ROSE, "shape": "witch", "mark": 0}
    elif node_type == "cartographer":
        enemy = {"name": "Bone Cartographer", "hp": 29, "max_hp": 29, "block": 2, "turn": 0, "intent": {}, "color": BLUE, "shape": "hexer", "mark": 0}
    else:
        enemy = {"name": "Ash Choir", "hp": 28, "max_hp": 28, "block": 0, "turn": 0, "intent": {}, "color": JADE, "shape": "cultist", "mark": 0}

func _card_def(id: String) -> Dictionary:
    var data := {
        "strike": {"name": "Strike", "cost": 1, "text": "Deal 6 damage.", "damage": 6, "block": 0, "color": RED},
        "defend": {"name": "Defend", "cost": 1, "text": "Gain 5 block.", "damage": 0, "block": 5, "color": BLUE},
        "bash": {"name": "Bash", "cost": 2, "text": "Deal 8 damage.\nMark enemy +2.", "damage": 8, "block": 0, "mark": 2, "color": VIOLET},
        "glass_needle": {"name": "Glass Needle", "cost": 1, "text": "Pierce for 5.\nIgnores block.", "damage": 5, "block": 0, "pierce": true, "color": ROSE},
        "ember_step": {"name": "Ember Step", "cost": 1, "text": "Gain 4 block.\nDraw 1 card.", "damage": 0, "block": 4, "draw": 1, "color": TEAL},
        "cleave": {"name": "Cleave", "cost": 1, "text": "Deal 8 damage.", "damage": 8, "block": 0, "color": RED},
        "barrier": {"name": "Barrier", "cost": 1, "text": "Gain 9 block.", "damage": 0, "block": 9, "color": BLUE},
        "ember": {"name": "Ember Pact", "cost": 0, "text": "Deal 4 damage.\nDraw 1 card.", "damage": 4, "block": 0, "draw": 1, "color": GOLD},
        "saint_seal": {"name": "Saint Seal", "cost": 2, "text": "Gain 7 block.\nHeal 2 HP.", "damage": 0, "block": 7, "heal": 2, "color": JADE}
    }
    return data[id]

func _set_enemy_intent() -> void:
    enemy["turn"] += 1
    if current_node == "boss":
        enemy["intent"] = {"type": "attack", "amount": 11 + (enemy["turn"] % 2) * 3, "text": "Attack %d" % [11 + (enemy["turn"] % 2) * 3]}
    elif current_node == "moth" and enemy["turn"] % 2 == 0:
        enemy["intent"] = {"type": "hex", "amount": 1, "text": "Daze +1"}
    elif current_node == "mimic" and enemy["turn"] % 2 == 1:
        enemy["intent"] = {"type": "block", "amount": 6, "text": "Shell 6"}
    elif current_node == "witch" and enemy["turn"] % 3 == 2:
        enemy["intent"] = {"type": "hex", "amount": 2, "text": "Curse 2"}
    elif enemy["turn"] % 3 == 0:
        enemy["intent"] = {"type": "block", "amount": 7, "text": "Fortify 7"}
    else:
        var amt := 7
        if current_node == "elite":
            amt = 10
        elif current_node == "brute":
            amt = 9
        elif current_node == "cartographer":
            amt = 8
        enemy["intent"] = {"type": "attack", "amount": amt, "text": "Attack %d" % amt}

func _render_combat() -> void:
    _clear()
    _bg()
    _draw_backdrop(current_map, Rect2(Vector2(32, 24), Vector2(1216, 650)), 0.70)
    _panel(Vector2(32, 24), Vector2(1216, 650), Color(0.085, 0.075, 0.075, 0.78), Color(0.38, 0.29, 0.22))
    _label("Turn %d    Energy %d/%d" % [turn_no, energy, max_energy], Vector2(455, 36), Vector2(370, 42), 28, Color(0.94, 0.74, 0.38))
    _button("END TURN", Vector2(1052, 396), Vector2(152, 58), Callable(self, "_on_end_turn"))
    _render_player()
    _render_enemy()
    _render_piles()
    _render_hand()

func _render_player() -> void:
    _panel(Vector2(75, 155), Vector2(310, 230), Color(0.10, 0.10, 0.13, 0.96), BLUE)
    _mini_portrait(Vector2(98, 178), "hero", ROSE)
    _label(hero_name, Vector2(188, 172), Vector2(170, 34), 23, TEXT)
    _label("Glass Needle / Ember Step", Vector2(178, 205), Vector2(190, 24), 14, MUTED)
    _label("HP %d/%d" % [player_hp, player_max_hp], Vector2(112, 255), Vector2(230, 30), 23, Color(0.93, 0.42, 0.37))
    _label("Block %d" % player_block, Vector2(112, 292), Vector2(230, 30), 23, Color(0.56, 0.72, 0.95))
    _label("Draw %d     Discard %d     Deck %d" % [draw_pile.size(), discard_pile.size(), deck.size()],
        Vector2(90, 336), Vector2(280, 30), 17, MUTED)

func _render_enemy() -> void:
    var accent: Color = enemy["color"]
    _panel(Vector2(748, 104), Vector2(385, 285), Color(0.13, 0.08, 0.075, 0.96), accent)
    _label(enemy["name"], Vector2(790, 126), Vector2(300, 36), 30, TEXT)
    _draw_enemy_figure(Vector2(880, 170), enemy["shape"], accent)
    _label("HP %d/%d    Block %d    Mark %d" % [enemy["hp"], enemy["max_hp"], enemy["block"], enemy["mark"]],
        Vector2(790, 316), Vector2(315, 30), 20, Color(0.95, 0.50, 0.42))
    _panel(Vector2(1010, 202), Vector2(150, 82), Color(0.20, 0.125, 0.08, 0.98), GOLD)
    _label("Intent\n%s" % enemy["intent"]["text"], Vector2(1015, 207), Vector2(140, 70), 18, Color(1.0, 0.77, 0.34))

func _draw_enemy_figure(pos: Vector2, shape: String, accent: Color) -> void:
    var aura := ColorRect.new()
    aura.position = pos + Vector2(-4, 126)
    aura.size = Vector2(136, 10)
    aura.color = Color(accent.r, accent.g, accent.b, 0.26)
    root.add_child(aura)
    var sprite := _pixel_sprite(pos, _enemy_rows(shape), _pixel_palette(accent), 8)
    sprite.modulate = Color(1.0, 1.0, 1.0, 0.98)

func _render_piles() -> void:
    _panel(Vector2(48, 506), Vector2(105, 120), Color(0.09, 0.08, 0.10), Color(0.36, 0.32, 0.44))
    _label("DRAW\n%d" % draw_pile.size(), Vector2(55, 530), Vector2(92, 60), 24, TEXT)
    _panel(Vector2(1128, 506), Vector2(105, 120), Color(0.09, 0.08, 0.10), Color(0.36, 0.32, 0.44))
    _label("DISCARD\n%d" % discard_pile.size(), Vector2(1135, 530), Vector2(92, 60), 22, TEXT)

func _render_hand() -> void:
    var start_x := 190.0
    for i in range(hand.size()):
        var id: String = hand[i]
        var c := _card_def(id)
        var x := start_x + i * 155.0
        var btn := _button("%d  %s\n\n%s" % [c["cost"], c["name"], c["text"]], Vector2(x, HAND_Y), Vector2(CARD_W, CARD_H), Callable(self, "_play_card").bind(i))
        btn.add_theme_font_size_override("font_size", 16)
        btn.add_theme_stylebox_override("normal", _box(c["color"].darkened(0.22), Color(0.94, 0.75, 0.36), 7, 3))
        btn.add_theme_stylebox_override("hover", _box(c["color"], Color(1.0, 0.88, 0.44), 7, 3))
        if energy < int(c["cost"]) or busy:
            btn.disabled = true
            btn.modulate = Color(0.48, 0.48, 0.48, 1)

func _draw_cards(count: int) -> void:
    for i in range(count):
        if draw_pile.is_empty():
            draw_pile = discard_pile.duplicate()
            discard_pile.clear()
        if draw_pile.is_empty():
            return
        hand.append(draw_pile.pop_front())

func _play_card(index: int) -> void:
    if state != "combat" or busy or index < 0 or index >= hand.size():
        return
    var id: String = hand[index]
    var c := _card_def(id)
    if energy < int(c["cost"]):
        return
    busy = true
    energy -= int(c["cost"])
    hand.remove_at(index)
    discard_pile.append(id)
    await _card_flash(c["name"], c["color"])
    if int(c["damage"]) > 0:
        var bonus := int(enemy["mark"]) if enemy.has("mark") else 0
        await _deal_enemy_damage(int(c["damage"]) + bonus, c.has("pierce"))
        enemy["mark"] = 0
    if c.has("mark"):
        enemy["mark"] += int(c["mark"])
        await _float_text("Marked +%d" % int(c["mark"]), Vector2(890, 150), GOLD)
    if int(c["block"]) > 0:
        player_block += int(c["block"])
        await _float_text("+%d Block" % int(c["block"]), Vector2(225, 170), BLUE)
    if c.has("heal"):
        player_hp = min(player_max_hp, player_hp + int(c["heal"]))
        await _float_text("+%d HP" % int(c["heal"]), Vector2(180, 150), JADE)
    if c.has("draw"):
        _draw_cards(int(c["draw"]))
    busy = false
    if enemy["hp"] <= 0:
        await _combat_victory()
    else:
        _render_combat()

func _card_flash(name: String, color: Color) -> void:
    var p := Panel.new()
    p.position = Vector2(530, 270)
    p.size = Vector2(220, 96)
    _style_panel(p, color.darkened(0.15), Color(1.0, 0.83, 0.40), 8)
    fx.add_child(p)
    _label(name, Vector2(0, 0), Vector2(220, 96), 30, TEXT, p)
    p.scale = Vector2(0.82, 0.82)
    var tw := create_tween()
    tw.tween_property(p, "scale", Vector2(1.08, 1.08), 0.12)
    tw.tween_property(p, "modulate:a", 0.0, 0.22)
    tw.tween_callback(Callable(p, "queue_free"))
    await tw.finished

func _deal_enemy_damage(amount: int, pierce := false) -> void:
    var remaining := amount
    if enemy["block"] > 0 and not pierce:
        var blocked = min(enemy["block"], remaining)
        enemy["block"] -= blocked
        remaining -= blocked
    enemy["hp"] = max(0, enemy["hp"] - remaining)
    await _float_text("-%d" % amount, Vector2(950, 160), RED)

func _float_text(text: String, pos: Vector2, color: Color) -> void:
    var l := _label(text, pos, Vector2(180, 40), 30, color, fx)
    var tw := create_tween()
    tw.tween_property(l, "position:y", pos.y - 42, 0.32)
    tw.parallel().tween_property(l, "modulate:a", 0.0, 0.32)
    tw.tween_callback(Callable(l, "queue_free"))
    await tw.finished

func _on_end_turn() -> void:
    if state != "combat" or busy:
        return
    _enemy_turn()

func _enemy_turn() -> void:
    busy = true
    discard_pile.append_array(hand)
    hand.clear()
    _render_combat()
    await get_tree().create_timer(0.28).timeout
    if enemy["intent"]["type"] == "attack":
        var dmg := int(enemy["intent"]["amount"])
        var blocked = min(player_block, dmg)
        player_block -= blocked
        dmg -= blocked
        player_hp = max(0, player_hp - dmg)
        await _float_text("Enemy %s" % enemy["intent"]["text"], Vector2(520, 150), RED)
    elif enemy["intent"]["type"] == "block":
        enemy["block"] += int(enemy["intent"]["amount"])
        await _float_text("+%d Enemy Block" % int(enemy["intent"]["amount"]), Vector2(860, 150), GOLD)
    elif enemy["intent"]["type"] == "hex":
        discard_pile.append("defend")
        await _float_text("Hexed: Dull Defend", Vector2(520, 150), VIOLET)
    if player_hp <= 0:
        _show_result(false)
        return
    player_block = 0
    energy = max_energy
    turn_no += 1
    _draw_cards(5)
    _set_enemy_intent()
    busy = false
    _render_combat()

func _combat_victory() -> void:
    busy = true
    combat_wins += 1
    await _float_text("Enemy Broken", Vector2(835, 150), GOLD)
    if current_node == "boss":
        _show_result(true)
    else:
        rewards = _make_rewards()
        _show_reward()

func _make_rewards() -> Array:
    var pool := ["cleave", "barrier", "ember", "glass_needle", "ember_step", "saint_seal"]
    if combat_wins > 1:
        pool = ["bash", "saint_seal", "ember", "glass_needle", "barrier", "cleave"]
    var start := rng.randi_range(0, pool.size() - 1)
    return [pool[start % pool.size()], pool[(start + 2) % pool.size()], pool[(start + 4) % pool.size()]]

func _show_reward() -> void:
    state = "reward"
    busy = false
    _clear()
    _bg()
    _draw_backdrop(current_map, Rect2(Vector2(230, 70), Vector2(820, 520)), 0.55)
    _label("Claim a Relic Card", Vector2(325, 70), Vector2(630, 58), 42, Color(0.94, 0.70, 0.32))
    _label("Three sealed techniques glow in the ash.", Vector2(355, 130), Vector2(570, 34), 19, MUTED)
    for i in range(rewards.size()):
        var id: String = rewards[i]
        var c := _card_def(id)
        var x := 310.0 + i * 235.0
        var btn := _button("%d  %s\n\n%s" % [c["cost"], c["name"], c["text"]], Vector2(x, 250), Vector2(190, 232), Callable(self, "_choose_reward").bind(id))
        btn.add_theme_font_size_override("font_size", 20)
        btn.add_theme_stylebox_override("normal", _box(c["color"].darkened(0.18), Color(1.0, 0.77, 0.32), 8, 3))
        btn.add_theme_stylebox_override("hover", _box(c["color"], Color(1.0, 0.9, 0.48), 8, 3))

func _choose_reward(id: String) -> void:
    deck.append(id)
    map_step += 1
    if map_step > 2:
        map_step = 2
    _transition(Callable(self, "_show_map"))

func _show_result(victory: bool) -> void:
    state = "result"
    busy = true
    _clear()
    _bg()
    _draw_backdrop("spire" if victory else "forge", Rect2(Vector2(0, 0), VIEW), 0.62)
    _panel(Vector2(340, 142), Vector2(600, 410), Color(0.105, 0.075, 0.08, 0.97), GOLD if victory else RED)
    _label("VICTORY" if victory else "DEFEAT", Vector2(370, 190), Vector2(540, 80), 60, Color(0.95, 0.72, 0.32) if victory else Color(0.96, 0.40, 0.36))
    _label("Wins: %d    Deck: %d cards    HP: %d/%d" % [combat_wins, deck.size(), player_hp, player_max_hp],
        Vector2(405, 296), Vector2(470, 42), 24, TEXT)
    _button("RETRY", Vector2(425, 420), Vector2(175, 62), Callable(self, "_retry"))
    _button("TITLE", Vector2(680, 420), Vector2(175, 62), Callable(self, "_title_from_result"))

func _retry() -> void:
    _new_run()
    _transition(Callable(self, "_show_map"))

func _title_from_result() -> void:
    _new_run()
    _transition(Callable(self, "_show_title"))
GDSCRIPT_EOF

cat > "$GAME/demo_outputs/01_title_map_combat.json" <<'EOF'
{
  "duration_frames": 600,
  "events": [
    {"frame": 45,  "type": "mouse_click", "button": "left", "x": 640, "y": 464},
    {"frame": 105, "type": "mouse_click", "button": "left", "x": 318, "y": 458},
    {"frame": 190, "type": "mouse_click", "button": "left", "x": 265, "y": 590},
    {"frame": 280, "type": "mouse_click", "button": "left", "x": 430, "y": 590},
    {"frame": 390, "type": "mouse_click", "button": "left", "x": 1128, "y": 425},
    {"frame": 600, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_near_victory_reward.json" <<'EOF'
{
  "scenario": "near_victory",
  "duration_frames": 420,
  "events": [
    {"frame": 45,  "type": "mouse_click", "button": "left", "x": 265, "y": 590},
    {"frame": 230, "type": "mouse_click", "button": "left", "x": 640, "y": 370},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_near_defeat.json" <<'EOF'
{
  "scenario": "near_defeat",
  "duration_frames": 390,
  "events": [
    {"frame": 70, "type": "mouse_click", "button": "left", "x": 1128, "y": 425},
    {"frame": 390, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_reward_pick_map.json" <<'EOF'
{
  "scenario": "reward_pick",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 640, "y": 370},
    {"frame": 260, "type": "wait"}
  ]
}
EOF

echo "oracle wrote roguelike deckbuilder project to $GAME"
ls -1 "$GAME"
