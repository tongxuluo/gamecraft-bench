#!/usr/bin/env bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scenes" "$GAME/scripts" "$GAME/demo_outputs"

# --- project.godot ---
cat > "$GAME/project.godot" << 'EOF'
; Engine configuration file.
config_version=5

[application]
config/name="RhythmNoteHighway"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.6")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
EOF

# --- scenes/Main.tscn ---
cat > "$GAME/scenes/Main.tscn" << 'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

# --- scripts/Main.gd (part 1) ---
cat > "$GAME/scripts/Main.gd" << 'GDEOF'
extends Node2D

enum State { TITLE, SONG_SELECT, PLAYING, RESULTS }

var state: int = State.TITLE
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var multiplier: int = 1
var life: float = 1.0
var hits_perfect: int = 0
var hits_good: int = 0
var misses: int = 0

var lane_keys: Array = [KEY_D, KEY_F, KEY_J, KEY_K]
var lane_x: Array = [440, 540, 640, 740]
var note_speed: float = 300.0
var judge_y: float = 620.0

var notes: Array = []
var active_notes: Array = []
var song_time: float = 0.0
var song_playing: bool = false
var feedback_timer: float = 0.0
var feedback_text: String = ""

var songs: Array = [
  {"name": "Easy Breeze", "bpm": 100, "difficulty": 1},
  {"name": "Neon Rush", "bpm": 140, "difficulty": 2},
  {"name": "Chaos Storm", "bpm": 180, "difficulty": 3}
]
var selected_song: int = 0

var title_btn: Button
var song_buttons: Array = []
var result_btn: Button
var scenario: String = ""

func _ready() -> void:
  var args: PackedStringArray = OS.get_cmdline_user_args()
  for i in range(args.size()):
    var a: String = args[i]
    if a.begins_with("--scenario="):
      scenario = a.substr(11)
    elif a == "--scenario" and i + 1 < args.size():
      scenario = args[i + 1]
  _build_title()

func _build_title() -> void:
  _clear_children()
  state = State.TITLE
  var bg: ColorRect = ColorRect.new()
  bg.color = Color(0.05, 0.0, 0.15)
  bg.position = Vector2.ZERO
  bg.size = Vector2(1280, 720)
  add_child(bg)
  var stage: ColorRect = ColorRect.new()
  stage.color = Color(0.1, 0.0, 0.3)
  stage.position = Vector2(200, 100)
  stage.size = Vector2(880, 400)
  add_child(stage)
  var stripe: ColorRect = ColorRect.new()
  stripe.color = Color(0.8, 0.0, 1.0, 0.4)
  stripe.position = Vector2(200, 480)
  stripe.size = Vector2(880, 4)
  add_child(stripe)
  var title_lbl: Label = Label.new()
  title_lbl.text = "RHYTHM NOTE HIGHWAY"
  title_lbl.position = Vector2(400, 200)
  title_lbl.add_theme_font_size_override("font_size", 40)
  title_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.8))
  add_child(title_lbl)
  title_btn = Button.new()
  title_btn.text = "PLAY"
  title_btn.position = Vector2(560, 400)
  title_btn.size = Vector2(160, 60)
  var sb: StyleBoxFlat = StyleBoxFlat.new()
  sb.bg_color = Color(0.8, 0.0, 1.0)
  sb.corner_radius_top_left = 8
  sb.corner_radius_top_right = 8
  sb.corner_radius_bottom_left = 8
  sb.corner_radius_bottom_right = 8
  title_btn.add_theme_stylebox_override("normal", sb)
  title_btn.pressed.connect(_on_play_pressed)
  add_child(title_btn)

func _on_play_pressed() -> void:
  _build_song_select()

func _build_song_select() -> void:
  _clear_children()
  state = State.SONG_SELECT
  song_buttons.clear()
  var bg: ColorRect = ColorRect.new()
  bg.color = Color(0.02, 0.0, 0.1)
  bg.size = Vector2(1280, 720)
  add_child(bg)
  var hdr: Label = Label.new()
  hdr.text = "SELECT SONG"
  hdr.position = Vector2(500, 60)
  hdr.add_theme_font_size_override("font_size", 32)
  hdr.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
  add_child(hdr)
  for i in range(songs.size()):
    var s: Dictionary = songs[i]
    var btn: Button = Button.new()
    btn.text = s["name"] + "  [Diff: " + str(s["difficulty"]) + "]"
    btn.position = Vector2(440, 180 + i * 120)
    btn.size = Vector2(400, 80)
    var bsb: StyleBoxFlat = StyleBoxFlat.new()
    bsb.bg_color = Color(0.15, 0.0, 0.3)
    bsb.corner_radius_top_left = 6
    bsb.corner_radius_top_right = 6
    bsb.corner_radius_bottom_left = 6
    bsb.corner_radius_bottom_right = 6
    btn.add_theme_stylebox_override("normal", bsb)
    btn.pressed.connect(_on_song_selected.bind(i))
    add_child(btn)
    song_buttons.append(btn)

func _on_song_selected(idx: int) -> void:
  selected_song = idx
  _start_game()

func _start_game() -> void:
  _clear_children()
  state = State.PLAYING
  score = 0
  combo = 0
  max_combo = 0
  multiplier = 1
  life = 1.0
  hits_perfect = 0
  hits_good = 0
  misses = 0
  song_time = 0.0
  song_playing = true
  active_notes.clear()
  _generate_notes()

func _generate_notes() -> void:
  notes.clear()
  var song: Dictionary = songs[selected_song]
  var bpm_val: int = song["bpm"]
  var beat_interval: float = 60.0 / float(bpm_val)
  var total_beats: int = 32 + selected_song * 16
  for i in range(total_beats):
    var t: float = 2.0 + float(i) * beat_interval
    var lane: int = (i * 7 + selected_song * 3) % 4
    notes.append({"time": t, "lane": lane, "hit": false, "missed": false})

func _process(delta: float) -> void:
  if state != State.PLAYING:
    return
  if not song_playing:
    return
  song_time += delta
  for n in notes:
    if n["hit"] or n["missed"]:
      continue
    var time_to_judge: float = n["time"] - song_time
    if time_to_judge < 2.5 and not active_notes.has(n):
      active_notes.append(n)
  var to_remove: Array = []
  for n in active_notes:
    var time_diff: float = song_time - n["time"]
    if time_diff > 0.3 and not n["hit"]:
      n["missed"] = true
      misses += 1
      combo = 0
      multiplier = 1
      life -= 0.08
      feedback_text = "MISS"
      feedback_timer = 0.5
      to_remove.append(n)
  for n in to_remove:
    active_notes.erase(n)
  var all_done: bool = true
  for n in notes:
    if not n["hit"] and not n["missed"]:
      all_done = false
      break
  if all_done or life <= 0.0:
    song_playing = false
    _show_results()
    return
  if feedback_timer > 0.0:
    feedback_timer -= delta
  queue_redraw()

func _input(event: InputEvent) -> void:
  if state != State.PLAYING or not song_playing:
    return
  if event is InputEventKey and event.pressed and not event.echo:
    var kev: InputEventKey = event as InputEventKey
    for i in range(4):
      if kev.keycode == lane_keys[i]:
        _check_hit(i)
        break

func _check_hit(lane: int) -> void:
  var best_note: Dictionary = {}
  var best_diff: float = 999.0
  for n in active_notes:
    if n["lane"] != lane or n["hit"] or n["missed"]:
      continue
    var diff: float = absf(song_time - n["time"])
    if diff < best_diff:
      best_diff = diff
      best_note = n
  if best_note.is_empty():
    return
  if best_diff < 0.05:
    best_note["hit"] = true
    hits_perfect += 1
    combo += 1
    score += 300 * multiplier
    feedback_text = "PERFECT"
    feedback_timer = 0.4
  elif best_diff < 0.15:
    best_note["hit"] = true
    hits_good += 1
    combo += 1
    score += 100 * multiplier
    feedback_text = "GOOD"
    feedback_timer = 0.4
  else:
    return
  if combo > max_combo:
    max_combo = combo
  multiplier = mini(1 + combo / 10, 4)
  active_notes.erase(best_note)

func _draw() -> void:
  if state != State.PLAYING:
    return
  draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.0, 0.08))
  for i in range(4):
    var lx: int = lane_x[i]
    draw_rect(Rect2(lx - 40, 0, 80, 720), Color(0.08, 0.0, 0.15))
    draw_rect(Rect2(lx - 40, 0, 1, 720), Color(0.2, 0.0, 0.4))
    draw_rect(Rect2(lx + 40, 0, 1, 720), Color(0.2, 0.0, 0.4))
  draw_rect(Rect2(380, judge_y, 400, 4), Color(1.0, 1.0, 1.0, 0.9))
  var key_labels: Array = ["D", "F", "J", "K"]
  for i in range(4):
    var lx: int = lane_x[i]
    draw_circle(Vector2(lx, judge_y), 25, Color(0.3, 0.0, 0.6, 0.6))
    draw_string(ThemeDB.fallback_font, Vector2(lx - 6, judge_y + 6), key_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.8))
  var note_colors: Array = [Color(1, 0.2, 0.2), Color(0.2, 1, 0.2), Color(0.2, 0.5, 1), Color(1, 1, 0.2)]
  for n in active_notes:
    if n["hit"] or n["missed"]:
      continue
    var time_to_judge: float = n["time"] - song_time
    var ny: float = judge_y - time_to_judge * note_speed
    var lane_idx: int = n["lane"]
    var lx: int = lane_x[lane_idx]
    var nc: Color = note_colors[lane_idx]
    draw_rect(Rect2(lx - 30, ny - 12, 60, 24), nc)
  draw_string(ThemeDB.fallback_font, Vector2(20, 30), "Score: " + str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
  draw_string(ThemeDB.fallback_font, Vector2(20, 55), "Combo: " + str(combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.8, 0))
  draw_string(ThemeDB.fallback_font, Vector2(20, 80), "x" + str(multiplier), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 1, 0.5))
  draw_rect(Rect2(900, 20, 300, 20), Color(0.2, 0.2, 0.2))
  var life_w: float = maxf(life, 0.0) * 300.0
  var life_color: Color = Color(0.2, 1, 0.3) if life > 0.3 else Color(1, 0.2, 0.2)
  draw_rect(Rect2(900, 20, life_w, 20), life_color)
  draw_string(ThemeDB.fallback_font, Vector2(900, 55), "LIFE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.7))
  if feedback_timer > 0.0:
    var fc: Color = Color(1, 1, 0) if feedback_text == "PERFECT" else Color(0.5, 1, 0.5) if feedback_text == "GOOD" else Color(1, 0.2, 0.2)
    draw_string(ThemeDB.fallback_font, Vector2(580, 550), feedback_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, fc)

func _show_results() -> void:
  _clear_children()
  state = State.RESULTS
  var bg: ColorRect = ColorRect.new()
  bg.color = Color(0.02, 0.0, 0.1)
  bg.size = Vector2(1280, 720)
  add_child(bg)
  var total: int = hits_perfect + hits_good + misses
  var pct: float = float(hits_perfect + hits_good) / maxf(float(total), 1.0)
  var grade: String = "C"
  if pct >= 0.95 and misses == 0:
    grade = "S"
  elif pct >= 0.85:
    grade = "A"
  elif pct >= 0.7:
    grade = "B"
  var grade_lbl: Label = Label.new()
  grade_lbl.text = grade
  grade_lbl.position = Vector2(580, 100)
  grade_lbl.add_theme_font_size_override("font_size", 80)
  var gc: Color = Color(1, 0.84, 0) if grade == "S" else Color(0.2, 1, 0.5) if grade == "A" else Color(0.4, 0.6, 1) if grade == "B" else Color(0.7, 0.7, 0.7)
  grade_lbl.add_theme_color_override("font_color", gc)
  add_child(grade_lbl)
  var info_lbl: Label = Label.new()
  info_lbl.text = "Score: " + str(score) + "\nPerfect: " + str(hits_perfect) + "\nGood: " + str(hits_good) + "\nMiss: " + str(misses) + "\nMax Combo: " + str(max_combo)
  info_lbl.position = Vector2(480, 250)
  info_lbl.add_theme_font_size_override("font_size", 22)
  info_lbl.add_theme_color_override("font_color", Color.WHITE)
  add_child(info_lbl)
  result_btn = Button.new()
  result_btn.text = "BACK TO TITLE"
  result_btn.position = Vector2(520, 550)
  result_btn.size = Vector2(240, 60)
  var rsb: StyleBoxFlat = StyleBoxFlat.new()
  rsb.bg_color = Color(0.3, 0.0, 0.6)
  rsb.corner_radius_top_left = 8
  rsb.corner_radius_top_right = 8
  rsb.corner_radius_bottom_left = 8
  rsb.corner_radius_bottom_right = 8
  result_btn.add_theme_stylebox_override("normal", rsb)
  result_btn.pressed.connect(_build_title)
  add_child(result_btn)

func _clear_children() -> void:
  for c in get_children():
    c.queue_free()
GDEOF

# --- Demo traces ---
cat > "$GAME/demo_outputs/title_to_song_select.json" << 'EOF'
{"duration_frames": 360, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}]}
EOF

cat > "$GAME/demo_outputs/play_easy_song.json" << 'EOF'
{"duration_frames": 1800, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 180, "type": "mouse_click", "button": "left", "x": 640, "y": 180}, {"frame": 300, "type": "key_press", "keycode": "D"}, {"frame": 360, "type": "key_press", "keycode": "F"}, {"frame": 420, "type": "key_press", "keycode": "J"}, {"frame": 480, "type": "key_press", "keycode": "K"}, {"frame": 540, "type": "key_press", "keycode": "D"}, {"frame": 600, "type": "key_press", "keycode": "F"}, {"frame": 660, "type": "key_press", "keycode": "J"}, {"frame": 720, "type": "key_press", "keycode": "K"}]}
EOF

cat > "$GAME/demo_outputs/song_select_hard.json" << 'EOF'
{"duration_frames": 600, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 200, "type": "mouse_click", "button": "left", "x": 640, "y": 420}]}
EOF

echo "Build complete."
