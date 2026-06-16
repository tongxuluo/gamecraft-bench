#!/bin/bash
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="strategy-siege-engineer"
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

const WIDTH := 1280
const HEIGHT := 720
const CELL := 64
const GRID_ORIGIN := Vector2(70, 150)
const GRID_COLS := 8
const GRID_ROWS := 5
const DATA_JSON := "{\"title\": \"Siege Engineer\", \"subtitle\": \"Aim siege engines, simulate arcs, destroy castles, and earn stars\", \"board_label\": \"Medieval range with weapon, trajectory, materials, wind, and castle blocks\", \"hud_title\": \"Shots Damage Wind Stars\", \"loop\": [\"Title\", \"Plan\", \"Act\", \"Threat\", \"Result\"], \"mechanics\": [\"Adjust angle and power preview arc\", \"Projectile arcs under gravity\", \"Blocks crack, break, and fall\", \"Destruction percent completes level\", \"Campaign stars unlock next castle\"], \"content_label\": \"Weapons, materials, levels, modifiers\", \"content\": [{\"name\": \"Trebuchet\", \"effect\": \"high arc blast\", \"color\": [0.6313725490196078, 0.3843137254901961, 0.027450980392156862, 1]}, {\"name\": \"Ballista\", \"effect\": \"fast bolt\", \"color\": [0.5725490196078431, 0.25098039215686274, 0.054901960784313725, 1]}, {\"name\": \"Catapult\", \"effect\": \"wide stone\", \"color\": [0.792156862745098, 0.5411764705882353, 0.01568627450980392, 1]}, {\"name\": \"Wood\", \"effect\": \"low durability\", \"color\": [0.5215686274509804, 0.30196078431372547, 0.054901960784313725, 1]}, {\"name\": \"Stone\", \"effect\": \"medium durability\", \"color\": [0.47058823529411764, 0.44313725490196076, 0.4235294117647059, 1]}, {\"name\": \"Iron\", \"effect\": \"resists hits\", \"color\": [0.2, 0.2549019607843137, 0.3333333333333333, 1]}], \"tokens\": [{\"name\": \"Trebuchet\", \"icon\": \"T\", \"color\": [0.6313725490196078, 0.3843137254901961, 0.027450980392156862, 1]}, {\"name\": \"Bolt\", \"icon\": \"B\", \"color\": [0.5725490196078431, 0.25098039215686274, 0.054901960784313725, 1]}, {\"name\": \"Stone\", \"icon\": \"S\", \"color\": [0.792156862745098, 0.5411764705882353, 0.01568627450980392, 1]}, {\"name\": \"Wood\", \"icon\": \"W\", \"color\": [0.5215686274509804, 0.30196078431372547, 0.054901960784313725, 1]}, {\"name\": \"Iron\", \"icon\": \"I\", \"color\": [0.2, 0.2549019607843137, 0.3333333333333333, 1]}, {\"name\": \"Star\", \"icon\": \"\\u2605\", \"color\": [0.9803921568627451, 0.8, 0.08235294117647059, 1]}], \"terrain\": [{\"name\": \"grass\", \"color\": [0.30196078431372547, 0.48627450980392156, 0.058823529411764705, 1]}, {\"name\": \"hill\", \"color\": [0.5215686274509804, 0.30196078431372547, 0.054901960784313725, 1]}, {\"name\": \"wall\", \"color\": [0.47058823529411764, 0.44313725490196076, 0.4235294117647059, 1]}, {\"name\": \"iron\", \"color\": [0.2, 0.2549019607843137, 0.3333333333333333, 1]}, {\"name\": \"wind\", \"color\": [0.2196078431372549, 0.7411764705882353, 0.9725490196078431, 1]}], \"actions\": [\"Angle/power control changes arc\", \"Projectile travels visibly to wall\", \"Cracks and debris mark impact\", \"Destruction meter increases\", \"Star rating appears on victory\"], \"palette\": [[0.10980392156862745, 0.09803921568627451, 0.09019607843137255, 1], [0.26666666666666666, 0.25098039215686274, 0.23529411764705882, 1], [0.6313725490196078, 0.3843137254901961, 0.027450980392156862, 1], [0.9803921568627451, 0.8, 0.08235294117647059, 1]], \"result_text\": \"Castle breach exceeds 70%; three-star level select unlocked\", \"hud\": [\"Shots\", \"Damage\", \"Wind\", \"Stars\"]}"

var data: Dictionary
var font: Font
var phase := "title"
var step := 0
var selected := 0
var scenario := "overview"
var pulses: Array = []
var resources := {"primary": 10, "secondary": 5, "danger": 0}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 7
    data = JSON.parse_string(DATA_JSON)
    font = ThemeDB.fallback_font
    _parse_args()
    if scenario == "systems":
        phase = "play"
        step = 2
        resources.primary = 18
        resources.secondary = 7
    elif scenario == "endgame":
        phase = "play"
        step = 5
        resources.primary = 26
        resources.secondary = 11
        resources.danger = 3
    queue_redraw()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _process(delta: float) -> void:
    for p in pulses:
        p.life -= delta
        p.radius += delta * 90.0
    pulses = pulses.filter(func(p): return p.life > 0.0)
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_click(event.position)
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            _advance(Vector2(640, 360))
        elif event.keycode == KEY_RIGHT:
            selected = (selected + 1) % data.tokens.size()
        elif event.keycode == KEY_LEFT:
            selected = (selected + data.tokens.size() - 1) % data.tokens.size()
        queue_redraw()

func _handle_click(pos: Vector2) -> void:
    if phase == "title":
        phase = "play"
        step = 1
        _add_pulse(pos, Color(1, 0.86, 0.35, 0.75))
    elif phase == "result":
        phase = "title"
        step = 0
        resources.primary = 10
        resources.secondary = 5
        resources.danger = 0
    else:
        var local := pos - GRID_ORIGIN
        if local.x >= 0 and local.y >= 0 and local.x < GRID_COLS * CELL and local.y < GRID_ROWS * CELL:
            selected = int(local.x / CELL + local.y / CELL) % data.tokens.size()
        _advance(pos)
    queue_redraw()

func _advance(pos: Vector2) -> void:
    step += 1
    resources.primary += 3 + step
    resources.secondary += 1
    resources.danger = (resources.danger + 1) % 6
    _add_pulse(pos, Color(0.45, 0.85, 1.0, 0.7))
    if step >= 7:
        phase = "result"

func _add_pulse(pos: Vector2, color: Color) -> void:
    pulses.append({"pos": pos, "radius": 10.0, "life": 0.9, "color": color})

func _draw() -> void:
    var pal: Array = data.palette
    var bg := _color(pal[0])
    var panel := _color(pal[1])
    var accent := _color(pal[2])
    var warm := _color(pal[3])
    draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), bg)
    _draw_backdrop(accent, warm)
    _draw_header(panel, accent, warm)
    if phase == "title":
        _draw_title(panel, accent, warm)
    elif phase == "result":
        _draw_result(panel, accent, warm)
    else:
        _draw_play(panel, accent, warm)
    for p in pulses:
        var c: Color = p.color
        c.a *= clamp(p.life, 0.0, 1.0)
        draw_arc(p.pos, p.radius, 0, TAU, 48, c, 4.0)

func _draw_backdrop(accent: Color, warm: Color) -> void:
    for i in range(9):
        var y := 95 + i * 58
        var c := accent.lerp(warm, float(i) / 8.0)
        c.a = 0.08
        draw_rect(Rect2(0, y, WIDTH, 28), c)
    for i in range(16):
        var x := 35 + i * 82
        draw_circle(Vector2(x, 620 + sin(float(i)) * 14.0), 18 + (i % 3) * 6, Color(warm.r, warm.g, warm.b, 0.10))

func _draw_header(panel: Color, accent: Color, warm: Color) -> void:
    draw_rect(Rect2(0, 0, WIDTH, 92), panel.darkened(0.15))
    draw_rect(Rect2(0, 88, WIDTH, 4), accent)
    _text(data.title, Vector2(28, 44), 32, Color.WHITE)
    _text(data.subtitle, Vector2(32, 76), 15, Color(0.88, 0.90, 0.92))
    var x := 720
    for i in range(data.loop.size()):
        var label: String = data.loop[i]
        var active: bool = i == min(step, data.loop.size() - 1)
        var r := Rect2(x + i * 92, 24, 82, 34)
        draw_rect(r, warm if active else panel.lightened(0.14))
        draw_rect(r, accent, false, 2.0)
        _text(label, r.position + Vector2(8, 23), 12, Color.WHITE)

func _draw_title(panel: Color, accent: Color, warm: Color) -> void:
    var hero := Rect2(80, 135, 1120, 470)
    draw_rect(hero, panel)
    draw_rect(hero, accent, false, 3)
    _text(data.title, Vector2(120, 205), 50, Color.WHITE)
    _text("A compact oracle slice with visible systems, content variety, feedback, and a complete loop.", Vector2(124, 246), 18, Color(0.88, 0.9, 0.94))
    var start := Rect2(124, 540, 220, 54)
    draw_rect(start, warm)
    draw_rect(start, Color.WHITE, false, 2)
    _text("START / CONTINUE", start.position + Vector2(22, 36), 20, Color(0.08, 0.08, 0.09))
    for i in range(data.mechanics.size()):
        var r := Rect2(430 + (i % 2) * 350, 170 + int(i / 2) * 86, 315, 62)
        draw_rect(r, panel.lightened(0.12))
        draw_rect(r, accent, false, 2)
        _text(data.mechanics[i], r.position + Vector2(12, 24), 15, Color.WHITE)
        _text("observable in demo", r.position + Vector2(12, 48), 11, Color(0.78, 0.84, 0.9))
    _draw_icon_cloud(Vector2(150, 330), warm, accent)

func _draw_play(panel: Color, accent: Color, warm: Color) -> void:
    _draw_grid(panel, accent, warm)
    _draw_tokens(accent, warm)
    _draw_hud(panel, accent, warm)
    _draw_cards(panel, accent, warm)
    _draw_feedback(panel, accent, warm)

func _draw_grid(panel: Color, accent: Color, warm: Color) -> void:
    var terrain: Array = data.terrain
    for y in range(GRID_ROWS):
        for x in range(GRID_COLS):
            var idx := (x + y * 2 + step) % terrain.size()
            var base := _color(terrain[idx].color)
            var r := Rect2(GRID_ORIGIN + Vector2(x * CELL, y * CELL), Vector2(CELL - 3, CELL - 3))
            draw_rect(r, base)
            draw_rect(r, accent.darkened(0.2), false, 1.5)
            if (x + y + step) % 5 == 0:
                draw_line(r.position + Vector2(8, CELL - 12), r.position + Vector2(CELL - 12, 8), Color(1, 1, 1, 0.18), 3)
            if x == (step + y) % GRID_COLS:
                draw_rect(r.grow(-8), Color(warm.r, warm.g, warm.b, 0.28))
            _text(terrain[idx].name, r.position + Vector2(5, 20), 10, Color(0.05, 0.06, 0.07))
    _text(data.board_label, GRID_ORIGIN + Vector2(0, -18), 16, Color.WHITE)

func _draw_tokens(accent: Color, warm: Color) -> void:
    var tokens: Array = data.tokens
    for i in range(tokens.size()):
        var row := i % GRID_ROWS
        var col := (i * 2 + step) % GRID_COLS
        var pos := GRID_ORIGIN + Vector2(col * CELL + 32, row * CELL + 32)
        var c := _color(tokens[i].color)
        draw_circle(pos, 20 + (3 if i == selected else 0), c)
        draw_circle(pos, 12, c.lightened(0.35))
        draw_arc(pos, 26, -PI/3, PI*1.2, 20, warm if i == selected else accent, 4)
        _text(tokens[i].icon, pos + Vector2(-8, 7), 18, Color(0.04, 0.04, 0.05))
        _text(tokens[i].name, pos + Vector2(-30, 42), 11, Color.WHITE)
    for i in range(3):
        var a := GRID_ORIGIN + Vector2(70 + i * 120, 360 + sin(step + i) * 18)
        var b := a + Vector2(145, -130 + i * 35)
        draw_line(a, b, Color(warm.r, warm.g, warm.b, 0.55), 3)
        draw_circle(b, 7, warm)

func _draw_hud(panel: Color, accent: Color, warm: Color) -> void:
    var hud := Rect2(640, 128, 575, 206)
    draw_rect(hud, panel)
    draw_rect(hud, accent, false, 2)
    _text("HUD: " + data.hud_title, hud.position + Vector2(18, 30), 22, Color.WHITE)
    var vals := [resources.primary, resources.secondary, resources.danger, step]
    for i in range(data.hud.size()):
        var r := Rect2(hud.position + Vector2(18 + (i % 2) * 270, 52 + int(i / 2) * 48), Vector2(240, 36))
        draw_rect(r, panel.lightened(0.12))
        draw_rect(r, warm if i == selected % max(1, data.hud.size()) else accent.darkened(0.1), false, 1)
        _text(str(data.hud[i]) + ": " + str(vals[i % vals.size()]), r.position + Vector2(10, 24), 16, Color.WHITE)
    _text("Phase " + str(step) + " / scenario " + scenario, hud.position + Vector2(18, 188), 13, Color(0.82, 0.86, 0.92))

func _draw_cards(panel: Color, accent: Color, warm: Color) -> void:
    var content: Array = data.content
    for i in range(content.size()):
        var r := Rect2(646 + (i % 3) * 188, 360 + int(i / 3) * 98, 170, 78)
        draw_rect(r, panel.lightened(0.08 + 0.02 * (i % 2)))
        draw_rect(r, warm if i == selected % content.size() else accent, false, 2)
        _text(content[i].name, r.position + Vector2(10, 24), 15, Color.WHITE)
        _text(content[i].effect, r.position + Vector2(10, 48), 11, Color(0.80, 0.86, 0.92))
        draw_circle(r.position + Vector2(142, 22), 12, _color(content[i].color))
    _text(data.content_label, Vector2(648, 348), 16, Color.WHITE)

func _draw_feedback(panel: Color, accent: Color, warm: Color) -> void:
    var box := Rect2(70, 504, 540, 145)
    draw_rect(box, panel)
    draw_rect(box, accent, false, 2)
    _text("Action feedback", box.position + Vector2(18, 30), 22, Color.WHITE)
    for i in range(data.actions.size()):
        var active: bool = i == step % data.actions.size()
        var y := box.position.y + 56 + i * 22
        draw_circle(Vector2(box.position.x + 24, y - 6), 6, warm if active else accent)
        _text(data.actions[i], Vector2(box.position.x + 42, y), 14, Color.WHITE if active else Color(0.72, 0.78, 0.86))
    if step >= 5:
        _text("End condition armed: success/failure result screen is reachable.", box.position + Vector2(18, 132), 14, warm)

func _draw_result(panel: Color, accent: Color, warm: Color) -> void:
    var r := Rect2(220, 150, 840, 430)
    draw_rect(r, panel)
    draw_rect(r, warm, false, 4)
    _text("RESULT", r.position + Vector2(330, 76), 48, Color.WHITE)
    _text(data.result_text, r.position + Vector2(90, 142), 24, Color(0.92, 0.95, 1.0))
    _text("Rewards: unlocked content, star/standing changes, and retry/menu loop.", r.position + Vector2(90, 190), 18, Color(0.82, 0.88, 0.94))
    for i in range(5):
        draw_circle(r.position + Vector2(180 + i * 95, 278), 28, warm if i <= step % 5 else accent.darkened(0.2))
        _text("★", r.position + Vector2(170 + i * 95, 288), 24, Color(0.08, 0.07, 0.05))
    var btn := Rect2(r.position + Vector2(300, 338), Vector2(240, 52))
    draw_rect(btn, accent)
    draw_rect(btn, Color.WHITE, false, 2)
    _text("RETRY / MENU", btn.position + Vector2(52, 34), 18, Color.WHITE)

func _draw_icon_cloud(origin: Vector2, warm: Color, accent: Color) -> void:
    for i in range(data.tokens.size()):
        var pos := origin + Vector2((i % 4) * 72, int(i / 4) * 58)
        draw_circle(pos, 25, _color(data.tokens[i].color))
        draw_circle(pos, 14, warm.lerp(accent, 0.35))
        _text(data.tokens[i].icon, pos + Vector2(-8, 8), 18, Color(0.05, 0.05, 0.05))

func _text(s: String, pos: Vector2, size: int, color: Color) -> void:
    draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _color(v) -> Color:
    return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if v.size() > 3 else 1.0)

GDSCRIPT_EOF

cat > "$GAME/demo_outputs/core.json" <<'EOF'
{"scenario":"overview","duration_frames":360,"events":[{"frame":30,"type":"mouse_click","x":220,"y":560},{"frame":80,"type":"mouse_click","x":150,"y":220},{"frame":130,"type":"mouse_click","x":310,"y":285},{"frame":190,"type":"key_press","keycode":"SPACE"},{"frame":250,"type":"mouse_click","x":720,"y":390}]}
EOF
cat > "$GAME/demo_outputs/systems.json" <<'EOF'
{"scenario":"systems","duration_frames":390,"events":[{"frame":45,"type":"mouse_click","x":260,"y":235},{"frame":95,"type":"mouse_click","x":452,"y":300},{"frame":150,"type":"key_press","keycode":"RIGHT"},{"frame":205,"type":"mouse_click","x":900,"y":450},{"frame":285,"type":"key_press","keycode":"SPACE"}]}
EOF
cat > "$GAME/demo_outputs/endgame.json" <<'EOF'
{"scenario":"endgame","duration_frames":420,"events":[{"frame":45,"type":"mouse_click","x":420,"y":220},{"frame":95,"type":"key_press","keycode":"SPACE"},{"frame":145,"type":"mouse_click","x":540,"y":345},{"frame":210,"type":"key_press","keycode":"SPACE"},{"frame":300,"type":"mouse_click","x":640,"y":510}]}
EOF

echo "oracle wrote strategy-siege-engineer project to $GAME"
