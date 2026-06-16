#!/usr/bin/env bash
# Oracle reference implementation for simulation-transit-web.
# Minimal Mini Metro-style transit network game.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Transit Web"
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

enum GS { TITLE, MAP_SELECT, PLAYING, RESOURCE_GRANT, GAME_OVER }
var state := GS.TITLE

# Stations: shape, position, passengers
var stations: Array = []
var station_shapes := ["circle","triangle","square","diamond","star"]
var station_colors := [Color(0.9,0.3,0.3),Color(0.3,0.8,0.3),Color(0.3,0.5,0.9),Color(0.9,0.7,0.2),Color(0.8,0.3,0.8)]

# Lines: list of station indices, color, trains
var lines: Array = []
var line_colors := [Color(1.0,0.2,0.2),Color(0.2,0.8,0.2),Color(0.2,0.4,1.0),Color(1.0,0.8,0.1),Color(0.8,0.2,0.8)]
var max_lines := 3
var max_carriages := 6

# Trains: line_idx, position along line (0..1), direction
var trains: Array = []

# Resources
var lines_available := 3
var carriages_available := 6
var tunnels_available := 2

# Game state
var day := 1
var passengers_delivered := 0
var overcrowded_stations: Array = []
var game_timer := 0.0
var spawn_timer := 5.0
var resource_timer := 30.0
var rng := RandomNumberGenerator.new()

# Drawing
var drawing_line := false
var current_line_idx := -1
var draw_start_station := -1
var selected_line := -1

# Maps
var map_names := ["River City","Island Chain","Mountain Pass"]
var current_map := 0

# UI
var title_panel: ColorRect
var map_panel: ColorRect
var hud_label: Label
var resource_panel: ColorRect
var gameover_panel: ColorRect
var gameover_label: Label

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    if scenario == "gameplay":
        current_map = 0; _load_map(0); state = GS.PLAYING
    elif scenario == "gameover":
        day = 12; passengers_delivered = 340
        state = GS.GAME_OVER; _show_gameover()
    else:
        state = GS.TITLE; title_panel.visible = true

func _load_map(idx: int) -> void:
    stations.clear(); lines.clear(); trains.clear()
    match idx:
        0:
            stations = [
                {"shape":"circle","x":200.0,"y":360.0,"passengers":0,"max_passengers":6},
                {"shape":"triangle","x":450.0,"y":200.0,"passengers":0,"max_passengers":6},
                {"shape":"square","x":700.0,"y":360.0,"passengers":0,"max_passengers":6},
                {"shape":"circle","x":950.0,"y":200.0,"passengers":0,"max_passengers":6},
                {"shape":"triangle","x":1100.0,"y":450.0,"passengers":0,"max_passengers":6}
            ]
        1:
            stations = [
                {"shape":"circle","x":150.0,"y":300.0,"passengers":0,"max_passengers":5},
                {"shape":"square","x":400.0,"y":150.0,"passengers":0,"max_passengers":5},
                {"shape":"triangle","x":650.0,"y":300.0,"passengers":0,"max_passengers":5},
                {"shape":"diamond","x":900.0,"y":150.0,"passengers":0,"max_passengers":5},
                {"shape":"circle","x":1100.0,"y":400.0,"passengers":0,"max_passengers":5}
            ]
        _:
            stations = [
                {"shape":"circle","x":100.0,"y":400.0,"passengers":0,"max_passengers":7},
                {"shape":"triangle","x":350.0,"y":250.0,"passengers":0,"max_passengers":7},
                {"shape":"square","x":640.0,"y":400.0,"passengers":0,"max_passengers":7},
                {"shape":"diamond","x":900.0,"y":250.0,"passengers":0,"max_passengers":7},
                {"shape":"star","x":1150.0,"y":400.0,"passengers":0,"max_passengers":7}
            ]

func _build_ui() -> void:
    var bg := ColorRect.new(); bg.color = Color(0.12,0.14,0.18); bg.size = Vector2(1280,720); add_child(bg)
    title_panel = ColorRect.new(); title_panel.color = Color(0,0,0,0.92); title_panel.size = Vector2(1280,720); title_panel.visible = false; add_child(title_panel)
    var tl := Label.new(); tl.text = "TRANSIT WEB\nCity Transit Network Simulation\n\nClick two stations to draw a line.\nPrevent stations from overcrowding!\nEarn resources to expand your network."; tl.position = Vector2(320,160); tl.add_theme_font_size_override("font_size",32); tl.modulate = Color(0.8,0.9,1.0); title_panel.add_child(tl)
    var sb := Button.new(); sb.text = "SELECT MAP"; sb.position = Vector2(490,420); sb.size = Vector2(300,65); sb.add_theme_font_size_override("font_size",28); sb.pressed.connect(_on_select_map); title_panel.add_child(sb)
    map_panel = ColorRect.new(); map_panel.color = Color(0,0,0,0.92); map_panel.size = Vector2(1280,720); map_panel.visible = false; add_child(map_panel)
    var ml := Label.new(); ml.text = "SELECT MAP"; ml.position = Vector2(490,80); ml.add_theme_font_size_override("font_size",36); ml.modulate = Color(0.8,0.9,1.0); map_panel.add_child(ml)
    for i in range(3):
        var btn := Button.new(); btn.text = map_names[i]; btn.position = Vector2(440,200+i*100); btn.size = Vector2(400,70); btn.add_theme_font_size_override("font_size",28); btn.pressed.connect(_on_map_select.bind(i)); map_panel.add_child(btn)
    hud_label = Label.new(); hud_label.position = Vector2(10,10); hud_label.add_theme_font_size_override("font_size",18); hud_label.modulate = Color(0.8,0.9,1.0); add_child(hud_label)
    resource_panel = ColorRect.new(); resource_panel.color = Color(0,0,0,0.92); resource_panel.size = Vector2(700,380); resource_panel.position = Vector2(290,170); resource_panel.visible = false; add_child(resource_panel)
    var rl := Label.new(); rl.text = "WEEKLY RESOURCE GRANT\nChoose one:"; rl.position = Vector2(150,20); rl.add_theme_font_size_override("font_size",28); rl.modulate = Color(0.8,0.9,1.0); resource_panel.add_child(rl)
    var opts := ["Extra Line","Additional Carriage","Tunnel (cross river)","Extra Carriage x2"]
    for i in range(opts.size()):
        var btn := Button.new(); btn.text = opts[i]; btn.position = Vector2(100,90+i*60); btn.size = Vector2(500,50); btn.add_theme_font_size_override("font_size",22); btn.pressed.connect(_on_resource_choice.bind(i)); resource_panel.add_child(btn)
    gameover_panel = ColorRect.new(); gameover_panel.color = Color(0,0,0,0.92); gameover_panel.size = Vector2(700,380); gameover_panel.position = Vector2(290,170); gameover_panel.visible = false; add_child(gameover_panel)
    gameover_label = Label.new(); gameover_label.position = Vector2(50,30); gameover_label.add_theme_font_size_override("font_size",26); gameover_label.modulate = Color(0.8,0.9,1.0); gameover_panel.add_child(gameover_label)
    var rb := Button.new(); rb.text = "Play Again"; rb.position = Vector2(250,300); rb.size = Vector2(200,55); rb.pressed.connect(func(): gameover_panel.visible = false; state = GS.TITLE; title_panel.visible = true); gameover_panel.add_child(rb)

func _on_select_map() -> void: title_panel.visible = false; map_panel.visible = true
func _on_map_select(idx: int) -> void: map_panel.visible = false; current_map = idx; _load_map(idx); state = GS.PLAYING

func _on_resource_choice(idx: int) -> void:
    resource_panel.visible = false
    match idx:
        0: lines_available += 1; max_lines += 1
        1: carriages_available += 1; max_carriages += 1
        2: tunnels_available += 1
        3: carriages_available += 2; max_carriages += 2
    state = GS.PLAYING

func _show_gameover() -> void:
    gameover_panel.visible = true
    var efficiency := int(float(passengers_delivered) / max(1, day) * 10.0)
    gameover_label.text = "NETWORK COLLAPSED\n\nDays Survived: %d\nPassengers Delivered: %d\nNetwork Efficiency: %d%%\nLines Built: %d\n\nThe city needs a better planner..." % [day, passengers_delivered, efficiency, lines.size()]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    game_timer += delta
    # Spawn passengers
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        spawn_timer = rng.randf_range(3.0, 6.0) - day * 0.1
        var s_idx := rng.randi_range(0, stations.size()-1)
        stations[s_idx]["passengers"] = int(stations[s_idx]["passengers"]) + 1
    # Resource grant
    resource_timer -= delta
    if resource_timer <= 0.0:
        resource_timer = 30.0; day += 1
        state = GS.RESOURCE_GRANT; resource_panel.visible = true
    # Move trains
    for t in trains:
        var line_idx: int = int(t["line_idx"])
        if line_idx >= lines.size(): continue
        var ln: Dictionary = lines[line_idx]
        var stops: Array = ln["stops"]
        if stops.size() < 2: continue
        t["progress"] = float(t["progress"]) + delta * 0.3
        if float(t["progress"]) >= 1.0:
            t["progress"] = 0.0
            var cur_stop: int = int(t["stop_idx"])
            var dir: int = int(t["dir"])
            # Deliver passengers
            var at_station: int = stops[cur_stop]
            if at_station < stations.size():
                var delivered: int = min(int(stations[at_station]["passengers"]), 3)
                stations[at_station]["passengers"] = int(stations[at_station]["passengers"]) - delivered
                passengers_delivered += delivered
            cur_stop += dir
            if cur_stop >= stops.size(): cur_stop = stops.size()-2; t["dir"] = -1
            elif cur_stop < 0: cur_stop = 1; t["dir"] = 1
            t["stop_idx"] = cur_stop
    # Check overcrowding
    overcrowded_stations.clear()
    for i in range(stations.size()):
        if int(stations[i]["passengers"]) >= int(stations[i]["max_passengers"]):
            overcrowded_stations.append(i)
    if overcrowded_stations.size() >= 3:
        state = GS.GAME_OVER; _show_gameover()

func _update_hud() -> void:
    if state != GS.PLAYING: return
    hud_label.text = "Day %d  |  Delivered: %d  |  Lines: %d/%d  |  Trains: %d  |  Overcrowded: %d" % [day, passengers_delivered, lines.size(), max_lines, trains.size(), overcrowded_stations.size()]

func _input(event: InputEvent) -> void:
    if state != GS.PLAYING: return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mp: Vector2 = event.position
        var clicked_station := -1
        for i in range(stations.size()):
            if Vector2(float(stations[i]["x"]), float(stations[i]["y"])).distance_to(mp) < 22.0:
                clicked_station = i; break
        if clicked_station >= 0:
            if draw_start_station < 0:
                draw_start_station = clicked_station
            else:
                if draw_start_station != clicked_station:
                    _add_line_segment(draw_start_station, clicked_station)
                draw_start_station = -1
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        draw_start_station = -1

func _add_line_segment(a: int, b: int) -> void:
    # Find existing line containing station a or create new
    var found_line := -1
    for i in range(lines.size()):
        var stops: Array = lines[i]["stops"]
        if a in stops or b in stops:
            found_line = i; break
    if found_line < 0:
        if lines.size() >= max_lines: return
        var new_line_idx := lines.size()
        lines.append({"stops":[a,b],"color":line_colors[new_line_idx % line_colors.size()]})
        if carriages_available > 0:
            carriages_available -= 1
            trains.append({"line_idx":new_line_idx,"stop_idx":0,"progress":0.0,"dir":1})
    else:
        var stops: Array = lines[found_line]["stops"]
        if not (b in stops): stops.append(b)
        elif not (a in stops): stops.append(a)

func _draw() -> void:
    if state == GS.TITLE or state == GS.MAP_SELECT: return
    # Lines
    for ln in lines:
        var stops: Array = ln["stops"]
        var lcol: Color = ln["color"]
        for i in range(stops.size()-1):
            var a: int = stops[i]; var b: int = stops[i+1]
            if a < stations.size() and b < stations.size():
                draw_line(Vector2(float(stations[a]["x"]),float(stations[a]["y"])), Vector2(float(stations[b]["x"]),float(stations[b]["y"])), lcol, 5.0)
    # Stations
    for i in range(stations.size()):
        var s: Dictionary = stations[i]
        var sx: float = float(s["x"]); var sy: float = float(s["y"])
        var overcrowded := i in overcrowded_stations
        var scol := Color(1.0,0.2,0.2) if overcrowded else Color(0.9,0.9,0.9)
        match str(s["shape"]):
            "circle":  draw_circle(Vector2(sx,sy), 18.0, scol)
            "triangle":
                draw_colored_polygon(PackedVector2Array([Vector2(sx,sy-20.0),Vector2(sx-18.0,sy+12.0),Vector2(sx+18.0,sy+12.0)]), scol)
            "square":  draw_rect(Rect2(sx-14.0,sy-14.0,28.0,28.0), scol)
            "diamond":
                draw_colored_polygon(PackedVector2Array([Vector2(sx,sy-20.0),Vector2(sx+16.0,sy),Vector2(sx,sy+20.0),Vector2(sx-16.0,sy)]), scol)
            "star":
                draw_circle(Vector2(sx,sy), 18.0, scol)
                draw_circle(Vector2(sx,sy), 10.0, Color(0.12,0.14,0.18))
        draw_string(ThemeDB.fallback_font, Vector2(sx-8.0,sy+30.0), str(int(s["passengers"])), HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1.0,0.8,0.3))
        if overcrowded:
            draw_string(ThemeDB.fallback_font, Vector2(sx-12.0,sy-30.0), "FULL!", HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1.0,0.2,0.2))
    # Trains
    for t in trains:
        var line_idx: int = int(t["line_idx"])
        if line_idx >= lines.size(): continue
        var ln: Dictionary = lines[line_idx]
        var stops: Array = ln["stops"]
        var stop_idx: int = int(t["stop_idx"])
        if stop_idx >= stops.size()-1: continue
        var a: int = stops[stop_idx]; var b: int = stops[stop_idx+1]
        if a >= stations.size() or b >= stations.size(): continue
        var pa := Vector2(float(stations[a]["x"]),float(stations[a]["y"]))
        var pb := Vector2(float(stations[b]["x"]),float(stations[b]["y"]))
        var tp: Vector2 = pa.lerp(pb, float(t["progress"]))
        draw_rect(Rect2(tp.x-10.0,tp.y-7.0,20.0,14.0), ln["color"])
    # Draw start indicator
    if draw_start_station >= 0 and draw_start_station < stations.size():
        draw_circle(Vector2(float(stations[draw_start_station]["x"]),float(stations[draw_start_station]["y"])), 24.0, Color(1.0,1.0,0.0,0.5))
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":453}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_gameplay.json" << 'DEMO'
{"scenario":"gameplay","duration_frames":540,"events":[{"frame":30,"type":"mouse_click","button":"left","x":200,"y":360},{"frame":60,"type":"mouse_click","button":"left","x":450,"y":200},{"frame":90,"type":"mouse_click","button":"left","x":450,"y":200},{"frame":120,"type":"mouse_click","button":"left","x":700,"y":360},{"frame":150,"type":"mouse_click","button":"left","x":700,"y":360},{"frame":180,"type":"mouse_click","button":"left","x":950,"y":200},{"frame":240,"type":"wait"},{"frame":330,"type":"mouse_click","button":"left","x":200,"y":360},{"frame":360,"type":"mouse_click","button":"left","x":1100,"y":450},{"frame":420,"type":"wait"},{"frame":480,"type":"wait"}]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_gameover.json" << 'DEMO'
{"scenario":"gameover","duration_frames":300,"events":[{"frame":60,"type":"wait"},{"frame":200,"type":"mouse_click","button":"left","x":540,"y":475}]}
DEMO

echo "Oracle written to $GAME_DIR"
