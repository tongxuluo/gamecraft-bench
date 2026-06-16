#!/bin/bash
# Reference solution for gamecraft-bench/visualnovel-lastsignal.
#
# A compact post-apocalyptic radio visual novel of triage. ORIGINAL prose.
#   - Title -> the watch -> field a sequence of radio calls, each a moral
#     choice that spends limited resources -> one of 3 endings.
#   - Resources: Supplies and Power, shown permanently, spent by choices.
#     Helping costs resources; an unaffordable choice is disabled/refused.
#   - Resources + past choices are persistent and GATE the ending (gave nearly
#     everything -> THE BEACON; hoarded/refused -> THE COLD SURVIVOR; emptied
#     the stores -> NOTHING LEFT TO GIVE).
#   - Several distinct callers with their own voice and dilemma.
#   - Scenarios jump to specific calls/endings for deterministic demos.
#
# Oracle for the verifier framework, not a polished game: drawn from primitives,
# so the art items (A1-A4) stay low while mechanic/content items pass.
#
# NOTE (GDScript warnings-as-errors): min()/max()/Dictionary subscripts/JSON
# return Variant; each such value is given an explicit type to avoid the
# "inferred Variant" parse error that fails the whole script.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="LastSignal"
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

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT'
extends Node2D

const VIEW := Vector2(1280, 720)

# Calls along the night. Each: caller name, scene tint, plea text, and choices.
# A choice has a label, a cost {supplies, power}, an outcome line, and may
# track whether the player gave or refused (for the ending).
var calls := [
    {
        "id": "family", "caller": "A Family at the Roadblock", "bg": "night",
        "text": "Static, then a woman's voice, fast and low. 'There are four of us — two kids. The roadblock's crawling with them and we can't move. Please. Anything you can spare to draw them off, a flare, a noise, anything.'",
        "choice": [
            {"label": "Burn power on a decoy broadcast to draw them off", "supplies": 0, "power": 3,
             "give": true, "ok": "You flood the band with noise from the far tower. Over the radio you hear them run — and then her, weeping thank-yous into the dark."},
            {"label": "Send a supply drop from the cache", "supplies": 3, "power": 0,
             "give": true, "ok": "You mark the cache and talk her to it through the static. 'We made it,' she breathes. 'We made it.'"},
            {"label": "Tell her you have nothing. Cut the channel.", "supplies": 0, "power": 0,
             "give": false, "ok": "You say the words and let the static swallow them. The line goes quiet. You do not know if they ran in time."},
        ],
    },
    {
        "id": "stranger", "caller": "A Stranger Who Knows Too Much", "bg": "ruin",
        "text": "A man's voice, calm, unhurried. 'I know this station has power. I know what's in your cache — I helped stock it, once. Open the door and I'll keep your secret. Refuse, and others will hear it.' It might be true. It might be a knife.",
        "choice": [
            {"label": "Open the door and let him in", "supplies": 2, "power": 1,
             "give": true, "ok": "You unbar the door. He is exactly who he said — and grateful, in his cold way. The cache is lighter, but the night is no longer yours alone."},
            {"label": "Refuse, and brace for what he sends", "supplies": 0, "power": 0,
             "give": false, "ok": "You refuse. He laughs, soft, and the line dies. By the small hours, others are circling the station who were not there before."},
            {"label": "Probe — ask what he really wants", "supplies": 0, "power": 1,
             "give": false, "ok": "You keep him talking, learning the shape of the lie. He wants the tower, not shelter. You note it, and tell him nothing true."},
        ],
    },
]

# Persistent resources (state).
var supplies := 6
var power := 6
var gave := 0           # count of generous choices
var refused := 0        # count of refusals
var scenario := ""
var mode := "title"     # title, call, result, ending
var idx := 0
var line_t := 0.0
var msg := ""
var deny_flash := 0.0
var anim := 0.0
var ending_id := "survivor"

func _ready() -> void:
    _parse_args()
    if scenario != "":
        _load_scenario(scenario)
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

func _load_scenario(id: String) -> void:
    if id == "title_flow":
        mode = "title"
    elif id == "call_family":
        _begin_new(); idx = 0; mode = "call"; line_t = 0.0
    elif id == "call_stranger":
        _begin_new(); idx = 1; mode = "call"; line_t = 0.0
    elif id == "low_supplies":
        _begin_new(); supplies = 1; power = 2; idx = 0; mode = "call"; line_t = 0.0
    elif id == "ending_beacon":
        gave = 2; supplies = 1; power = 1; _go_ending()
    elif id == "ending_survivor":
        refused = 2; supplies = 6; power = 6; _go_ending()
    else:
        _begin_new(); mode = "call"

func _begin_new() -> void:
    supplies = 6
    power = 6
    gave = 0
    refused = 0
    idx = 0
    mode = "call"
    line_t = 0.0
    msg = ""

# --------------------------------------------------------------------------
# Calls + resource-spending choices
# --------------------------------------------------------------------------

func _cur() -> Dictionary:
    if idx < 0 or idx >= calls.size():
        return {}
    var c: Dictionary = calls[idx]
    return c

func _can_afford(o: Dictionary) -> bool:
    return supplies >= int(o.get("supplies", 0)) and power >= int(o.get("power", 0))

func _choose(ci: int) -> void:
    if mode != "call":
        return
    var c: Dictionary = _cur()
    if c.is_empty():
        return
    var opts: Array = c["choice"]
    if ci < 0 or ci >= opts.size():
        return
    var o: Dictionary = opts[ci]
    if not _can_afford(o):
        deny_flash = 0.5
        msg = "You don't have the supplies or power to do that."
        queue_redraw()
        return
    supplies -= int(o.get("supplies", 0))
    power -= int(o.get("power", 0))
    if bool(o.get("give", false)):
        gave += 1
    else:
        refused += 1
    msg = str(o["ok"])
    line_t = 0.0
    mode = "result"
    queue_redraw()

func _continue_after_result() -> void:
    idx += 1
    if idx >= calls.size():
        _go_ending()
    else:
        mode = "call"
        line_t = 0.0
    queue_redraw()

func _go_ending() -> void:
    if gave >= 2 and (supplies + power) <= 3:
        ending_id = "beacon"
    elif supplies <= 0 or power <= 0:
        ending_id = "nothing"
    elif refused >= 2:
        ending_id = "survivor"
    elif gave >= 1:
        ending_id = "beacon"
    else:
        ending_id = "survivor"
    mode = "ending"
    line_t = 0.0
    queue_redraw()

func _ending_data() -> Dictionary:
    match ending_id:
        "beacon":
            return {"title": "THE BEACON", "bg": "dawn",
                "text": "You gave until your stores ran thin, and when dawn finally grayed the windows, you were not alone. The voices you saved found their way to your door, and the station that should have been a tomb became a light. They will remember who answered."}
        "nothing":
            return {"title": "NOTHING LEFT TO GIVE", "bg": "night",
                "text": "You spent it all — every flare, every watt, every kindness — and the last call came when the cache was bare. You had nothing but your voice, and your voice could not reach them. Generosity is a kind of grave, dug one good deed at a time."}
        _:
            return {"title": "THE COLD SURVIVOR", "bg": "ruin",
                "text": "You kept the door barred and the cache full, and you outlasted them all. The station hums on, well-stocked and silent. You are alive, and warm, and the static no longer carries any voice that knows your name."}

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _bg_color(tag: String) -> Color:
    match tag:
        "night": return Color(0.06, 0.07, 0.12)
        "ruin": return Color(0.10, 0.08, 0.09)
        "dawn": return Color(0.16, 0.13, 0.14)
    return Color(0.07, 0.07, 0.10)

func _draw() -> void:
    match mode:
        "title": _draw_title()
        "call": _draw_call()
        "result": _draw_result()
        "ending": _draw_ending()

func _panel(rect: Rect2, color := Color(0.04, 0.05, 0.07, 0.94)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.38, 0.46, 0.52, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _wrap(s: String, rect: Rect2, size: int, color: Color) -> void:
    draw_multiline_string(ThemeDB.fallback_font, rect.position, s, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, color)

func _button(rect: Rect2, label: String, on := true) -> void:
    draw_rect(rect, Color(0.10, 0.13, 0.15) if on else Color(0.16, 0.08, 0.08))
    draw_rect(rect, Color(0.45, 0.58, 0.62) if on else Color(0.5, 0.3, 0.3), false, 2.0)
    _text(label, rect.position + Vector2(16, rect.size.y * 0.64), 18, Color(0.88, 0.92, 0.92) if on else Color(0.7, 0.6, 0.6))

func _scene_bg(tag: String) -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), _bg_color(tag))
    # console silhouette + a pulsing signal ring
    draw_rect(Rect2(120, 360, 1040, 160), Color(0.09, 0.10, 0.14))
    var r := 40.0 + 8.0 * sin(anim * 3.0)
    draw_arc(Vector2(220, 300), r, 0, TAU, 28, Color(0.4, 0.8, 0.7, 0.5), 3.0)
    draw_circle(Vector2(220, 300), 10, Color(0.5, 0.9, 0.8))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.10))

func _draw_resources() -> void:
    _panel(Rect2(978, 14, 288, 96), Color(0.04, 0.05, 0.07, 0.94) if deny_flash <= 0.0 else Color(0.30, 0.06, 0.06, 0.95))
    _text("SUPPLIES", Vector2(996, 44), 18, Color(0.85, 0.82, 0.6))
    _bar(Rect2(1120, 30, 130, 18), float(supplies) / 6.0, Color(0.85, 0.75, 0.35))
    _text("POWER", Vector2(996, 84), 18, Color(0.6, 0.85, 0.85))
    _bar(Rect2(1120, 70, 130, 18), float(power) / 6.0, Color(0.4, 0.8, 0.8))

func _bar(rect: Rect2, frac: float, color: Color) -> void:
    frac = clampf(frac, 0.0, 1.0)
    draw_rect(rect, Color(0.05, 0.06, 0.07))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * frac, rect.size.y)), color)
    draw_rect(rect, Color(0.25, 0.30, 0.30), false, 1.5)

func _draw_title() -> void:
    _scene_bg("night")
    _panel(Rect2(300, 150, 680, 360))
    _text("LAST SIGNAL", Vector2(430, 250), 58, Color(0.55, 0.82, 0.78))
    _text("The world is quiet. Your station still has power. Who do you save?", Vector2(345, 312), 19, Color(0.80, 0.86, 0.86))
    _button(Rect2(500, 410, 280, 64), "TAKE THE WATCH")

func _draw_call() -> void:
    var c: Dictionary = _cur()
    _scene_bg(str(c.get("bg", "night")))
    _draw_resources()
    _panel(Rect2(40, 540, 1200, 150))
    _panel(Rect2(60, 512, 420, 40), Color(0.10, 0.16, 0.18, 0.95))
    _text("● RADIO — %s" % str(c.get("caller", "")), Vector2(76, 540), 19, Color(0.7, 0.9, 0.85))
    var full: String = str(c.get("text", ""))
    var shown := full
    if line_t < 1.0:
        shown = full.substr(0, int(float(full.length()) * line_t))
    _wrap(shown, Rect2(72, 556, 1140, 120), 20, Color(0.90, 0.92, 0.92))
    if line_t >= 1.0:
        var opts: Array = c["choice"]
        for i in range(opts.size()):
            var o: Dictionary = opts[i]
            var cost := ""
            var s: int = int(o.get("supplies", 0))
            var p: int = int(o.get("power", 0))
            if s > 0: cost += "  [-%d sup]" % s
            if p > 0: cost += "  [-%d pwr]" % p
            _button(Rect2(120, 250 + i * 64, 1040, 52), "%d. %s%s" % [i + 1, str(o["label"]), cost], _can_afford(o))

func _draw_result() -> void:
    var c: Dictionary = _cur()
    _scene_bg(str(c.get("bg", "night")))
    _draw_resources()
    _panel(Rect2(220, 250, 840, 220))
    _wrap(msg, Rect2(260, 296, 760, 150), 22, Color(0.90, 0.92, 0.92))
    _button(Rect2(560, 420, 180, 40), "Next call")

func _draw_ending() -> void:
    var e: Dictionary = _ending_data()
    _scene_bg(str(e["bg"]))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _draw_resources()
    _panel(Rect2(220, 170, 840, 360))
    _text(str(e["title"]), Vector2(270, 250), 44, Color(0.6, 0.85, 0.8))
    _wrap(str(e["text"]), Rect2(270, 300, 740, 180), 22, Color(0.90, 0.92, 0.92))
    _button(Rect2(420, 480, 200, 54), "WATCH AGAIN")
    _button(Rect2(660, 480, 200, 54), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "call":
            if event.keycode == KEY_1: _choose(0)
            elif event.keycode == KEY_2: _choose(1)
            elif event.keycode == KEY_3: _choose(2)
            elif event.keycode == KEY_SPACE and line_t < 1.0: line_t = 1.0; queue_redraw()
        elif mode == "result":
            if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _continue_after_result()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(p):
            _begin_new(); queue_redraw()
    elif mode == "call":
        var c: Dictionary = _cur()
        if line_t >= 1.0:
            var opts: Array = c["choice"]
            for i in range(opts.size()):
                if Rect2(120, 250 + i * 64, 1040, 52).has_point(p):
                    _choose(i); return
        else:
            line_t = 1.0; queue_redraw()
    elif mode == "result":
        if Rect2(560, 420, 180, 40).has_point(p):
            _continue_after_result()
    elif mode == "ending":
        if Rect2(420, 480, 200, 54).has_point(p):
            _begin_new(); queue_redraw()
        elif Rect2(660, 480, 200, 54).has_point(p):
            mode = "title"; queue_redraw()

func _process(delta: float) -> void:
    anim += delta
    if deny_flash > 0.0:
        deny_flash = max(0.0, deny_flash - delta)
    if mode == "call":
        queue_redraw()  # keep the signal ring pulsing
        if line_t < 1.0:
            line_t = min(1.0, line_t + delta * 1.6)
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_call.json" <<'EOF'
{
  "duration_frames": 400,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 160, "type": "key_press", "keycode": "1"},
    {"frame": 260, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_family_give.json" <<'EOF'
{
  "scenario": "call_family",
  "duration_frames": 380,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "2"},
    {"frame": 250, "type": "key_press", "keycode": "SPACE"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_low_supplies_deny.json" <<'EOF'
{
  "scenario": "low_supplies",
  "duration_frames": 400,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 140, "type": "key_press", "keycode": "2"},
    {"frame": 230, "type": "key_press", "keycode": "1"},
    {"frame": 330, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_ending_beacon.json" <<'EOF'
{
  "scenario": "ending_beacon",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 220, "type": "mouse_click", "button": "left", "x": 520, "y": 507},
    {"frame": 290, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_ending_survivor.json" <<'EOF'
{
  "scenario": "ending_survivor",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 240, "type": "wait"}
  ]
}
EOF

echo "lastsignal oracle generated at $GAME"
