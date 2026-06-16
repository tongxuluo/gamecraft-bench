#!/usr/bin/env bash
# Oracle reference implementation for platformer-ivory-beats.
# Vertical rhythm-reaction game (Piano Tiles style) with 3 modes.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

###############################################################################
# project.godot
###############################################################################
cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Ivory Beats"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
lane1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)]
}
lane2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":102,"location":0,"echo":false,"script":null)]
}
lane3={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":74,"key_label":0,"unicode":106,"location":0,"echo":false,"script":null)]
}
lane4={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":75,"key_label":0,"unicode":107,"location":0,"echo":false,"script":null)]
}
PREF

###############################################################################
# Main.tscn
###############################################################################
cat > "$GAME_DIR/Main.tscn" << 'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
TSCN

###############################################################################
# scripts/Main.gd  (part 1 of 5)
###############################################################################
cat > "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT'
extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────
const LANE_COUNT    := 4
const TILE_ROWS     := 8
const LANE_W        := 200.0
const TILE_H        := 80.0
const GRID_X        := 240.0
const GRID_Y        := 80.0
const HIT_ZONE_Y    := GRID_Y + TILE_H * (TILE_ROWS - 1)
const CLASSIC_GOAL  := 50
const ZEN_DURATION  := 30.0

# ── Game modes ────────────────────────────────────────────────────────────────
enum Mode { NONE, CLASSIC, ARCADE, ZEN }
enum GS   { TITLE, READY, PLAYING, DEAD }

var mode: int = Mode.NONE
var state: int = GS.TITLE

# ── Tile grid  ────────────────────────────────────────────────────────────────
# grid[row][lane] = true means dark tile
var grid: Array = []
var rng := RandomNumberGenerator.new()
var rng_seed := 12345

# ── Gameplay state ────────────────────────────────────────────────────────────
var score        := 0
var scroll_acc   := 0.0   # sub-row accumulator for smooth scroll
var scroll_speed := 1.5   # rows per second (Arcade increases this)
var zen_timer    := ZEN_DURATION
var game_started := false
var fault_lane   := -1
var fault_timer  := 0.0
const FAULT_FLASH := 0.5

# ── Shake ─────────────────────────────────────────────────────────────────────
var shake_timer  := 0.0
var shake_amt    := 0.0
const SHAKE_DUR  := 0.35

# ── Best scores ───────────────────────────────────────────────────────────────
var best_classic := 0.0   # time (lower=better), 0 = no record
var best_arcade  := 0
var best_zen     := 0
const SAVE_PATH  := "user://ivory_beats_save.cfg"

# ── UI nodes ──────────────────────────────────────────────────────────────────
var title_panel:    PanelContainer
var mode_btns:      Array = []
var best_labels:    Array = []
var ready_label:    Label
var hud_panel:      PanelContainer
var hud_score:      Label
var hud_mode:       Label
var hud_extra:      Label   # zen timer / classic progress
var result_panel:   PanelContainer
var result_title:   Label
var result_score:   Label
var result_best:    Label
var result_retry:   Button

# ── Tile visuals ──────────────────────────────────────────────────────────────
var tile_nodes: Array = []   # tile_nodes[row][lane] = ColorRect
var hit_flash:  Array = []   # per-lane flash overlay
var canvas:     CanvasLayer

func _ready() -> void:
	rng.seed = rng_seed
	_load_bests()
	_build_ui()
	_build_grid_visuals()
	_generate_tiles(TILE_ROWS + 4)
	_refresh_tile_visuals()

	var args := OS.get_cmdline_user_args()
	var scenario := ""
	for i in range(args.size()):
		if String(args[i]) == "--scenario" and i + 1 < args.size():
			scenario = String(args[i + 1])

	match scenario:
		"arcade":
			mode = Mode.ARCADE
			_enter_ready()
		"zen":
			mode = Mode.ZEN
			_enter_ready()
		"classic":
			mode = Mode.CLASSIC
			_enter_ready()
		_:
			_enter_title()

GDSCRIPT

###############################################################################
# scripts/Main.gd  (part 2 of 5) - append to Main.gd
###############################################################################
cat >> "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT2'
# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if state == GS.TITLE:
		return
	if state == GS.DEAD:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
				_restart()
		return

	# Lane key presses
	var lane := -1
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_D: lane = 0
			KEY_F: lane = 1
			KEY_J: lane = 2
			KEY_K: lane = 3
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mx: float = event.position.x
		for l in range(LANE_COUNT):
			var lx := GRID_X + l * LANE_W
			if mx >= lx and mx < lx + LANE_W:
				lane = l
				break

	if lane >= 0:
		if not game_started:
			game_started = true
			if mode == Mode.ZEN:
				zen_timer = ZEN_DURATION
		_tap_lane(lane)

func _tap_lane(lane: int) -> void:
	if state != GS.PLAYING:
		return
	var bottom_row := TILE_ROWS - 1
	if grid[bottom_row][lane]:
		# Hit!
		grid[bottom_row][lane] = false
		score += 1
		_flash_lane(lane)
		_shift_grid_down()
		_append_new_row()
		_refresh_tile_visuals()
		_update_hud()
		if mode == Mode.ARCADE:
			var tier := score / 10
			scroll_speed = 1.5 + tier * 0.4
		if mode == Mode.CLASSIC and score >= CLASSIC_GOAL:
			_win_classic()
	else:
		# Miss — wrong lane
		fault_lane = lane
		fault_timer = FAULT_FLASH
		_die()

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state == GS.PLAYING and game_started:
		# Arcade auto-scroll: tiles drift down; if bottom row has dark tile -> die
		if mode == Mode.ARCADE:
			scroll_acc += scroll_speed * delta
			while scroll_acc >= 1.0:
				scroll_acc -= 1.0
				_check_escape()
				_shift_grid_down()
				_append_new_row()
				_refresh_tile_visuals()

		# Zen countdown
		if mode == Mode.ZEN:
			zen_timer -= delta
			if zen_timer <= 0.0:
				zen_timer = 0.0
				_end_zen()
			_update_hud()

	# Fault flash
	if fault_timer > 0.0:
		fault_timer -= delta
		if fault_timer <= 0.0:
			fault_lane = -1
			_refresh_tile_visuals()

	# Shake
	if shake_timer > 0.0:
		shake_timer -= delta

	# Result panel slide-in
	if state == GS.DEAD and result_panel.visible:
		var ty := 160.0
		if result_panel.position.y < ty:
			result_panel.position.y = minf(result_panel.position.y + 800.0 * delta, ty)

	# Ready prompt pulse
	if state == GS.READY and ready_label.visible:
		var t := Time.get_ticks_msec() / 1000.0
		ready_label.modulate.a = 0.5 + 0.5 * sin(t * 4.0)

# ── Grid logic ────────────────────────────────────────────────────────────────
func _generate_tiles(count: int) -> void:
	grid.clear()
	for _i in range(count):
		var row := []
		for _l in range(LANE_COUNT):
			row.append(false)
		var dark := rng.randi_range(0, LANE_COUNT - 1)
		row[dark] = true
		grid.append(row)

func _shift_grid_down() -> void:
	grid.pop_back()

func _append_new_row() -> void:
	var row := []
	for _l in range(LANE_COUNT):
		row.append(false)
	var dark := rng.randi_range(0, LANE_COUNT - 1)
	row[dark] = true
	grid.insert(0, row)

func _check_escape() -> void:
	var bottom_row := TILE_ROWS - 1
	for l in range(LANE_COUNT):
		if grid[bottom_row][l]:
			fault_lane = l
			fault_timer = FAULT_FLASH
			_die()
			return

# ── State transitions ─────────────────────────────────────────────────────────
func _enter_title() -> void:
	state = GS.TITLE
	title_panel.visible = true
	ready_label.visible = false
	hud_panel.visible = false
	result_panel.visible = false
	_update_best_labels()

func _enter_ready() -> void:
	state = GS.READY
	game_started = false
	score = 0
	scroll_acc = 0.0
	scroll_speed = 1.5
	zen_timer = ZEN_DURATION
	fault_lane = -1
	rng.seed = rng_seed
	_generate_tiles(TILE_ROWS + 4)
	_refresh_tile_visuals()
	title_panel.visible = false
	result_panel.visible = false
	hud_panel.visible = true
	ready_label.visible = true
	_update_hud()
	state = GS.PLAYING

func _die() -> void:
	state = GS.DEAD
	shake_timer = SHAKE_DUR
	shake_amt = 10.0
	_refresh_tile_visuals()
	_show_result()

func _win_classic() -> void:
	state = GS.DEAD
	_show_result()

func _end_zen() -> void:
	state = GS.DEAD
	_show_result()

func _restart() -> void:
	_enter_ready()

# ── Result panel ──────────────────────────────────────────────────────────────
func _show_result() -> void:
	var is_new_best := false
	var best_str := ""
	match mode:
		Mode.CLASSIC:
			# Not timing classic in oracle — just show score
			if best_classic == 0.0 or score >= CLASSIC_GOAL:
				best_classic = 1.0
				is_new_best = true
				_save_bests()
			best_str = "Best: %d tiles" % CLASSIC_GOAL
		Mode.ARCADE:
			if score > best_arcade:
				best_arcade = score
				is_new_best = true
				_save_bests()
			best_str = "Best: %d" % best_arcade
		Mode.ZEN:
			if score > best_zen:
				best_zen = score
				is_new_best = true
				_save_bests()
			best_str = "Best: %d" % best_zen

	var mode_name: String = ["", "CLASSIC", "ARCADE", "ZEN"][mode]
	result_title.text = "— %s —" % mode_name
	result_score.text = "Score: %d" % score
	result_best.text = best_str + ("  ★ NEW BEST" if is_new_best else "")
	result_panel.position.y = -300.0
	result_panel.visible = true
	ready_label.visible = false

# ── Save / Load ───────────────────────────────────────────────────────────────
func _load_bests() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_classic = float(cfg.get_value("bests", "classic", 0.0))
		best_arcade  = int(cfg.get_value("bests", "arcade",  0))
		best_zen     = int(cfg.get_value("bests", "zen",     0))

func _save_bests() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bests", "classic", best_classic)
	cfg.set_value("bests", "arcade",  best_arcade)
	cfg.set_value("bests", "zen",     best_zen)
	cfg.save(SAVE_PATH)

# ── HUD update ────────────────────────────────────────────────────────────────
func _update_hud() -> void:
	hud_score.text = "SCORE: %d" % score
	var mode_name: String = ["", "CLASSIC", "ARCADE", "ZEN"][mode]
	hud_mode.text = mode_name
	match mode:
		Mode.CLASSIC:
			hud_extra.text = "%d / %d" % [score, CLASSIC_GOAL]
		Mode.ZEN:
			hud_extra.text = "%.1f s" % maxf(zen_timer, 0.0)
		Mode.ARCADE:
			var tier := score / 10
			hud_extra.text = "TIER %d" % tier

func _update_best_labels() -> void:
	best_labels[0].text = "Classic  best: %s" % ("--" if best_classic == 0.0 else "cleared")
	best_labels[1].text = "Arcade   best: %d" % best_arcade
	best_labels[2].text = "Zen      best: %d" % best_zen

# ── Tile visuals ──────────────────────────────────────────────────────────────
func _refresh_tile_visuals() -> void:
	var shake_x := 0.0
	var shake_y := 0.0
	if shake_timer > 0.0:
		var intensity := shake_amt * (shake_timer / SHAKE_DUR)
		shake_x = randf_range(-intensity, intensity)
		shake_y = randf_range(-intensity, intensity)

	for row in range(TILE_ROWS):
		for lane in range(LANE_COUNT):
			var tile: ColorRect = tile_nodes[row][lane]
			var is_dark: bool = grid[row][lane]
			var is_fault: bool = (fault_lane == lane and row == TILE_ROWS - 1 and fault_timer > 0.0)
			if is_fault:
				tile.color = Color(0.9, 0.1, 0.1, 1.0)
			elif is_dark:
				tile.color = Color(0.08, 0.08, 0.10, 1.0)
			else:
				tile.color = Color(0.96, 0.96, 0.96, 1.0)
			tile.position = Vector2(
				GRID_X + lane * LANE_W + shake_x,
				GRID_Y + row * TILE_H + shake_y
			)

func _flash_lane(lane: int) -> void:
	var fl: ColorRect = hit_flash[lane]
	fl.color = Color(0.0, 1.0, 0.6, 0.55)
	var tw := create_tween()
	tw.tween_property(fl, "color", Color(0.0, 1.0, 0.6, 0.0), 0.25)

# ── Build UI ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14, 1.0)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)
	move_child(bg, 0)

	# ── Title panel ──
	title_panel = PanelContainer.new()
	title_panel.position = Vector2(290, 80)
	title_panel.size = Vector2(700, 560)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.08, 0.08, 0.10, 0.97)
	tsb.border_color = Color(0.0, 1.0, 0.6, 0.6)
	tsb.set_border_width_all(2)
	tsb.set_corner_radius_all(12)
	title_panel.add_theme_stylebox_override("panel", tsb)
	canvas.add_child(title_panel)

	var tvbox := VBoxContainer.new()
	tvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tvbox.set("theme_override_constants/separation", 18)
	title_panel.add_child(tvbox)

	var title_lbl := Label.new()
	title_lbl.text = "IVORY BEATS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.set("theme_override_font_sizes/font_size", 60)
	title_lbl.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0))
	tvbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "tap the dark tiles"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.set("theme_override_font_sizes/font_size", 20)
	sub_lbl.set("theme_override_colors/font_color", Color(0.6, 0.6, 0.6, 1.0))
	tvbox.add_child(sub_lbl)

	var div := ColorRect.new()
	div.color = Color(0.0, 1.0, 0.6, 0.3)
	div.custom_minimum_size = Vector2(500, 2)
	tvbox.add_child(div)

	# Best scores
	var best_names := ["Classic  best: --", "Arcade   best: 0", "Zen      best: 0"]
	for i in range(3):
		var bl := Label.new()
		bl.text = best_names[i]
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.set("theme_override_font_sizes/font_size", 18)
		bl.set("theme_override_colors/font_color", Color(0.0, 0.9, 0.5, 0.9))
		tvbox.add_child(bl)
		best_labels.append(bl)

	var div2 := ColorRect.new()
	div2.color = Color(0.0, 1.0, 0.6, 0.3)
	div2.custom_minimum_size = Vector2(500, 2)
	tvbox.add_child(div2)

	# Mode buttons
	var mode_data := [["CLASSIC\n50 tiles, fastest time", Mode.CLASSIC],
					  ["ARCADE\nendless, accelerating", Mode.ARCADE],
					  ["ZEN\n30 seconds, max score", Mode.ZEN]]
	for md in mode_data:
		var btn := Button.new()
		btn.text = md[0]
		btn.custom_minimum_size = Vector2(400, 56)
		btn.set("theme_override_font_sizes/font_size", 20)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		bsb.border_color = Color(0.0, 0.9, 0.5, 0.7)
		bsb.set_border_width_all(2)
		bsb.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", bsb)
		var bhov := StyleBoxFlat.new()
		bhov.bg_color = Color(0.0, 0.3, 0.18, 1.0)
		bhov.border_color = Color(0.0, 1.0, 0.6, 1.0)
		bhov.set_border_width_all(2)
		bhov.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("hover", bhov)
		var m: int = md[1]
		btn.pressed.connect(func(): _on_mode_selected(m))
		tvbox.add_child(btn)
		mode_btns.append(btn)

	# ── Ready label ──
	ready_label = Label.new()
	ready_label.text = "▶  TAP TO BEGIN  ◀"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.set("theme_override_font_sizes/font_size", 30)
	ready_label.set("theme_override_colors/font_color", Color(0.0, 1.0, 0.6, 1.0))
	ready_label.position = Vector2(340, 640)
	ready_label.size = Vector2(600, 50)
	canvas.add_child(ready_label)

	# ── HUD panel ──
	hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(0, 0)
	hud_panel.size = Vector2(1280, 50)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.06, 0.06, 0.08, 0.92)
	hsb.border_color = Color(0.0, 0.8, 0.4, 0.4)
	hsb.set_border_width_all(1)
	hud_panel.add_theme_stylebox_override("panel", hsb)
	canvas.add_child(hud_panel)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(20, 8)
	hbox.size = Vector2(1240, 36)
	hbox.set("theme_override_constants/separation", 30)
	hud_panel.add_child(hbox)

	hud_mode = Label.new()
	hud_mode.text = "ARCADE"
	hud_mode.set("theme_override_font_sizes/font_size", 24)
	hud_mode.set("theme_override_colors/font_color", Color(0.0, 1.0, 0.6, 1.0))
	hbox.add_child(hud_mode)

	hud_score = Label.new()
	hud_score.text = "SCORE: 0"
	hud_score.set("theme_override_font_sizes/font_size", 24)
	hud_score.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0))
	hbox.add_child(hud_score)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	hud_extra = Label.new()
	hud_extra.text = ""
	hud_extra.set("theme_override_font_sizes/font_size", 24)
	hud_extra.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.0, 1.0))
	hbox.add_child(hud_extra)

	# ── Result panel ──
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(290, -300)
	result_panel.size = Vector2(700, 400)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.06, 0.06, 0.08, 0.97)
	rsb.border_color = Color(0.0, 1.0, 0.6, 0.8)
	rsb.set_border_width_all(3)
	rsb.set_corner_radius_all(14)
	rsb.shadow_color = Color(0.0, 0.5, 0.3, 0.4)
	rsb.shadow_size = 10
	result_panel.add_theme_stylebox_override("panel", rsb)
	canvas.add_child(result_panel)

	var rvbox := VBoxContainer.new()
	rvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rvbox.set("theme_override_constants/separation", 18)
	result_panel.add_child(rvbox)

	result_title = Label.new()
	result_title.text = "— RESULT —"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.set("theme_override_font_sizes/font_size", 36)
	result_title.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0))
	rvbox.add_child(result_title)

	var rdiv := ColorRect.new()
	rdiv.color = Color(0.0, 1.0, 0.6, 0.3)
	rdiv.custom_minimum_size = Vector2(500, 2)
	rvbox.add_child(rdiv)

	result_score = Label.new()
	result_score.text = "Score: 0"
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_score.set("theme_override_font_sizes/font_size", 40)
	result_score.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0))
	rvbox.add_child(result_score)

	result_best = Label.new()
	result_best.text = "Best: 0"
	result_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_best.set("theme_override_font_sizes/font_size", 22)
	result_best.set("theme_override_colors/font_color", Color(0.0, 0.9, 0.5, 1.0))
	rvbox.add_child(result_best)

	result_retry = Button.new()
	result_retry.text = "[ RETRY ]"
	result_retry.custom_minimum_size = Vector2(240, 52)
	result_retry.set("theme_override_font_sizes/font_size", 24)
	var rrsb := StyleBoxFlat.new()
	rrsb.bg_color = Color(0.0, 0.25, 0.14, 1.0)
	rrsb.border_color = Color(0.0, 0.9, 0.5, 0.9)
	rrsb.set_border_width_all(2)
	rrsb.set_corner_radius_all(8)
	result_retry.add_theme_stylebox_override("normal", rrsb)
	result_retry.pressed.connect(_restart)
	rvbox.add_child(result_retry)

	result_panel.visible = false
	hud_panel.visible = false
	ready_label.visible = false

func _on_mode_selected(m: int) -> void:
	mode = m
	_enter_ready()

# ── Build grid visuals ────────────────────────────────────────────────────────
func _build_grid_visuals() -> void:
	# Lane separator lines
	for l in range(LANE_COUNT + 1):
		var sep := ColorRect.new()
		sep.color = Color(0.3, 0.3, 0.35, 1.0)
		sep.position = Vector2(GRID_X + l * LANE_W - 1, GRID_Y)
		sep.size = Vector2(2, TILE_H * TILE_ROWS)
		add_child(sep)

	# Hit zone marker
	var hit_line := ColorRect.new()
	hit_line.color = Color(0.0, 1.0, 0.6, 0.7)
	hit_line.position = Vector2(GRID_X, HIT_ZONE_Y + TILE_H - 4)
	hit_line.size = Vector2(LANE_W * LANE_COUNT, 4)
	add_child(hit_line)

	# Hit zone glow
	var hit_glow := ColorRect.new()
	hit_glow.color = Color(0.0, 1.0, 0.6, 0.12)
	hit_glow.position = Vector2(GRID_X, HIT_ZONE_Y)
	hit_glow.size = Vector2(LANE_W * LANE_COUNT, TILE_H)
	add_child(hit_glow)

	# Key hint labels
	var keys := ["D", "F", "J", "K"]
	for l in range(LANE_COUNT):
		var kl := Label.new()
		kl.text = keys[l]
		kl.set("theme_override_font_sizes/font_size", 22)
		kl.set("theme_override_colors/font_color", Color(0.0, 0.8, 0.4, 0.8))
		kl.position = Vector2(GRID_X + l * LANE_W + LANE_W / 2 - 10, HIT_ZONE_Y + TILE_H + 6)
		add_child(kl)

	# Tile rects
	tile_nodes.clear()
	for row in range(TILE_ROWS):
		var row_arr := []
		for lane in range(LANE_COUNT):
			var tile := ColorRect.new()
			tile.size = Vector2(LANE_W - 4, TILE_H - 4)
			tile.position = Vector2(GRID_X + lane * LANE_W + 2, GRID_Y + row * TILE_H + 2)
			add_child(tile)
			row_arr.append(tile)
		tile_nodes.append(row_arr)

	# Per-lane hit flash overlays
	hit_flash.clear()
	for l in range(LANE_COUNT):
		var fl := ColorRect.new()
		fl.color = Color(0.0, 1.0, 0.6, 0.0)
		fl.position = Vector2(GRID_X + l * LANE_W, GRID_Y)
		fl.size = Vector2(LANE_W, TILE_H * TILE_ROWS)
		add_child(fl)
		hit_flash.append(fl)
GDSCRIPT2


###############################################################################
# Demo traces
###############################################################################

# opening: title -> select Arcade -> tap lanes
cat > "$GAME_DIR/demo_outputs/01_opening.json" << 'DEMO1'
{
  "duration_frames": 600,
  "events": [
    {"frame": 20,  "type": "mouse_click", "button": "left", "x": 640, "y": 310},
    {"frame": 50,  "type": "key_press", "keycode": "D"},
    {"frame": 65,  "type": "key_press", "keycode": "J"},
    {"frame": 80,  "type": "key_press", "keycode": "F"},
    {"frame": 95,  "type": "key_press", "keycode": "K"},
    {"frame": 110, "type": "key_press", "keycode": "D"},
    {"frame": 125, "type": "key_press", "keycode": "J"},
    {"frame": 140, "type": "key_press", "keycode": "F"},
    {"frame": 155, "type": "key_press", "keycode": "K"},
    {"frame": 170, "type": "key_press", "keycode": "D"},
    {"frame": 185, "type": "key_press", "keycode": "J"},
    {"frame": 200, "type": "key_press", "keycode": "F"},
    {"frame": 215, "type": "key_press", "keycode": "K"},
    {"frame": 230, "type": "key_press", "keycode": "D"},
    {"frame": 245, "type": "key_press", "keycode": "J"},
    {"frame": 260, "type": "key_press", "keycode": "F"},
    {"frame": 275, "type": "key_press", "keycode": "K"},
    {"frame": 290, "type": "key_press", "keycode": "D"},
    {"frame": 305, "type": "key_press", "keycode": "J"},
    {"frame": 320, "type": "key_press", "keycode": "F"},
    {"frame": 335, "type": "key_press", "keycode": "K"},
    {"frame": 350, "type": "wait"},
    {"frame": 590, "type": "wait"}
  ]
}
DEMO1

# arcade: scenario skips menu, play arcade mode with rapid taps
cat > "$GAME_DIR/demo_outputs/02_arcade.json" << 'DEMO2'
{
  "scenario": "arcade",
  "duration_frames": 600,
  "events": [
    {"frame": 5,   "type": "key_press", "keycode": "D"},
    {"frame": 18,  "type": "key_press", "keycode": "J"},
    {"frame": 31,  "type": "key_press", "keycode": "F"},
    {"frame": 44,  "type": "key_press", "keycode": "K"},
    {"frame": 57,  "type": "key_press", "keycode": "D"},
    {"frame": 70,  "type": "key_press", "keycode": "J"},
    {"frame": 83,  "type": "key_press", "keycode": "F"},
    {"frame": 96,  "type": "key_press", "keycode": "K"},
    {"frame": 109, "type": "key_press", "keycode": "D"},
    {"frame": 122, "type": "key_press", "keycode": "J"},
    {"frame": 135, "type": "key_press", "keycode": "F"},
    {"frame": 148, "type": "key_press", "keycode": "K"},
    {"frame": 161, "type": "key_press", "keycode": "D"},
    {"frame": 174, "type": "key_press", "keycode": "J"},
    {"frame": 187, "type": "key_press", "keycode": "F"},
    {"frame": 200, "type": "key_press", "keycode": "K"},
    {"frame": 213, "type": "key_press", "keycode": "D"},
    {"frame": 226, "type": "key_press", "keycode": "J"},
    {"frame": 239, "type": "key_press", "keycode": "F"},
    {"frame": 252, "type": "key_press", "keycode": "K"},
    {"frame": 265, "type": "key_press", "keycode": "D"},
    {"frame": 278, "type": "key_press", "keycode": "J"},
    {"frame": 291, "type": "key_press", "keycode": "F"},
    {"frame": 304, "type": "key_press", "keycode": "K"},
    {"frame": 317, "type": "key_press", "keycode": "D"},
    {"frame": 330, "type": "key_press", "keycode": "J"},
    {"frame": 343, "type": "key_press", "keycode": "F"},
    {"frame": 356, "type": "key_press", "keycode": "K"},
    {"frame": 369, "type": "key_press", "keycode": "D"},
    {"frame": 382, "type": "key_press", "keycode": "J"},
    {"frame": 395, "type": "wait"},
    {"frame": 590, "type": "wait"}
  ]
}
DEMO2


# zen: scenario skips menu, play zen mode for 30s countdown
cat > "$GAME_DIR/demo_outputs/03_zen.json" << 'DEMO3'
{
  "scenario": "zen",
  "duration_frames": 600,
  "events": [
    {"frame": 5,   "type": "key_press", "keycode": "D"},
    {"frame": 18,  "type": "key_press", "keycode": "J"},
    {"frame": 31,  "type": "key_press", "keycode": "F"},
    {"frame": 44,  "type": "key_press", "keycode": "K"},
    {"frame": 57,  "type": "key_press", "keycode": "D"},
    {"frame": 70,  "type": "key_press", "keycode": "J"},
    {"frame": 83,  "type": "key_press", "keycode": "F"},
    {"frame": 96,  "type": "key_press", "keycode": "K"},
    {"frame": 109, "type": "key_press", "keycode": "D"},
    {"frame": 122, "type": "key_press", "keycode": "J"},
    {"frame": 135, "type": "key_press", "keycode": "F"},
    {"frame": 148, "type": "key_press", "keycode": "K"},
    {"frame": 161, "type": "key_press", "keycode": "D"},
    {"frame": 174, "type": "key_press", "keycode": "J"},
    {"frame": 187, "type": "key_press", "keycode": "F"},
    {"frame": 200, "type": "key_press", "keycode": "K"},
    {"frame": 213, "type": "key_press", "keycode": "D"},
    {"frame": 226, "type": "key_press", "keycode": "J"},
    {"frame": 239, "type": "key_press", "keycode": "F"},
    {"frame": 252, "type": "key_press", "keycode": "K"},
    {"frame": 265, "type": "key_press", "keycode": "D"},
    {"frame": 278, "type": "key_press", "keycode": "J"},
    {"frame": 291, "type": "key_press", "keycode": "F"},
    {"frame": 304, "type": "key_press", "keycode": "K"},
    {"frame": 317, "type": "key_press", "keycode": "D"},
    {"frame": 330, "type": "key_press", "keycode": "J"},
    {"frame": 343, "type": "key_press", "keycode": "F"},
    {"frame": 356, "type": "key_press", "keycode": "K"},
    {"frame": 369, "type": "key_press", "keycode": "D"},
    {"frame": 382, "type": "key_press", "keycode": "J"},
    {"frame": 395, "type": "key_press", "keycode": "F"},
    {"frame": 408, "type": "key_press", "keycode": "K"},
    {"frame": 421, "type": "key_press", "keycode": "D"},
    {"frame": 434, "type": "key_press", "keycode": "J"},
    {"frame": 447, "type": "key_press", "keycode": "F"},
    {"frame": 460, "type": "key_press", "keycode": "K"},
    {"frame": 473, "type": "key_press", "keycode": "D"},
    {"frame": 486, "type": "key_press", "keycode": "J"},
    {"frame": 499, "type": "key_press", "keycode": "F"},
    {"frame": 512, "type": "key_press", "keycode": "K"},
    {"frame": 525, "type": "wait"},
    {"frame": 590, "type": "wait"}
  ]
}
DEMO3

# miss: tap wrong lane to trigger defeat + result panel
cat > "$GAME_DIR/demo_outputs/04_miss.json" << 'DEMO4'
{
  "scenario": "arcade",
  "duration_frames": 300,
  "events": [
    {"frame": 5,  "type": "key_press", "keycode": "D"},
    {"frame": 18, "type": "key_press", "keycode": "J"},
    {"frame": 31, "type": "key_press", "keycode": "F"},
    {"frame": 44, "type": "key_press", "keycode": "K"},
    {"frame": 57, "type": "key_press", "keycode": "D"},
    {"frame": 70, "type": "key_press", "keycode": "D"},
    {"frame": 90, "type": "wait"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "D"},
    {"frame": 235, "type": "key_press", "keycode": "J"},
    {"frame": 250, "type": "key_press", "keycode": "F"},
    {"frame": 265, "type": "key_press", "keycode": "K"},
    {"frame": 290, "type": "wait"}
  ]
}
DEMO4

echo "Oracle written to $GAME_DIR"
