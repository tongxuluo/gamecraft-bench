#!/bin/bash
set -euo pipefail

# Oracle reference for openworld-bounty.
# Generates a minimal bounty hunter game with ColorRect placeholders.

GAME="${GAME:-/workspace/game}"
mkdir -p "$GAME"
cd "$GAME"

cat > project.godot <<'GODOT'
[application]
config/name="Bounty Hunter"
config/features=PackedStringArray("4.2", "Mobile")
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[input]
ui_accept={"deadzone":0.5,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194309,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)
]}
GODOT

cat > Main.gd <<'GDSCRIPT'
extends Node2D

var player: CharacterBody2D
var bounties: Array = []
var targets: Array = []
var regions: Array = []
var active_bounty: int = -1
var gold: int = 0
var in_combat: bool = false
var combat_target: Node2D = null

func _ready():
	var scenario = _get_scenario()
	if scenario == "title":
		_make_title_ui()
	else:
		_start_game(scenario)

func _get_scenario() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			return arg.split("=")[1]
		if arg == "--scenario" and OS.get_cmdline_user_args().size() > 0:
			var idx = OS.get_cmdline_user_args().find(arg)
			if idx >= 0 and idx + 1 < OS.get_cmdline_user_args().size():
				return OS.get_cmdline_user_args()[idx + 1]
	return ""

func _make_title_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title = Label.new()
	title.text = "Bounty Hunter"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 200
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var btn = Button.new()
	btn.text = "Start Hunt"
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.pressed.connect(_on_start)
	add_child(btn)

func _on_start():
	get_tree().change_scene_to_file("res://Main.tscn")

func _start_game(scenario: String):
	_gen_regions()
	_spawn_player(scenario)
	_spawn_bounties()
	_spawn_targets(scenario)
	_make_hud()
	if scenario.begins_with("combat"):
		_start_combat(scenario)

func _gen_regions():
	var r1 = ColorRect.new()
	r1.position = Vector2(0, 0)
	r1.size = Vector2(420, 720)
	r1.color = Color(0.35, 0.3, 0.2)
	add_child(r1)
	regions.append({"node": r1, "name": "town"})
	var r2 = ColorRect.new()
	r2.position = Vector2(420, 0)
	r2.size = Vector2(440, 720)
	r2.color = Color(0.1, 0.35, 0.15)
	add_child(r2)
	regions.append({"node": r2, "name": "forest"})
	var r3 = ColorRect.new()
	r3.position = Vector2(860, 0)
	r3.size = Vector2(420, 720)
	r3.color = Color(0.3, 0.15, 0.1)
	add_child(r3)
	regions.append({"node": r3, "name": "camp"})

func _spawn_player(scenario: String):
	player = CharacterBody2D.new()
	var sprite = ColorRect.new()
	sprite.size = Vector2(24, 24)
	sprite.color = Color(0.2, 0.5, 0.9)
	player.add_child(sprite)
	var coll = CollisionShape2D.new()
	coll.shape = RectangleShape2D.new()
	coll.shape.size = Vector2(24, 24)
	player.add_child(coll)
	if scenario.begins_with("pick") or scenario == "":
		player.position = Vector2(200, 360)
	elif scenario.begins_with("combat") or scenario == "track_target":
		player.position = Vector2(900, 360)
	elif scenario == "claim_reward":
		player.position = Vector2(200, 360)
		active_bounty = 0
		gold = 50
	else:
		player.position = Vector2(200, 360)
	add_child(player)

func _spawn_bounties():
	var board = ColorRect.new()
	board.position = Vector2(150, 100)
	board.size = Vector2(300, 200)
	board.color = Color(0.4, 0.3, 0.2)
	add_child(board)
	var bounty_data = [
		{"name": "Bandit Bob", "reward": 100, "stars": 1, "pos": Vector2(160, 110)},
		{"name": "Rogue Rex", "reward": 200, "stars": 2, "pos": Vector2(160, 160)},
		{"name": "Outlaw Olga", "reward": 300, "stars": 3, "pos": Vector2(160, 210)},
	]
	for i in range(bounty_data.size()):
		var b = bounty_data[i]
		var card = ColorRect.new()
		card.position = b.pos
		card.size = Vector2(280, 40)
		card.color = Color(0.5, 0.4, 0.3)
		card.set_meta("index", i)
		card.set_meta("reward", b.reward)
		card.set_meta("name", b.name)
		card.set_meta("active", false)
		add_child(card)
		var label = Label.new()
		label.text = "%s ★%d — %dg" % [b.name, b.stars, b.reward]
		label.position = Vector2(5, 5)
		card.add_child(label)
		bounties.append(card)

func _spawn_targets(scenario: String):
	var target_data = [
		{"pos": Vector2(950, 200), "type": "melee", "hp": 50, "color": Color(0.8, 0.2, 0.2)},
		{"pos": Vector2(1050, 400), "type": "ranged", "hp": 40, "color": Color(0.8, 0.4, 0.1)},
	]
	for i in range(target_data.size()):
		var data = target_data[i]
		var t = CharacterBody2D.new()
		t.position = data.pos
		var sprite = ColorRect.new()
		sprite.size = Vector2(28, 28)
		sprite.color = data.color
		t.add_child(sprite)
		t.set_meta("type", data.type)
		t.set_meta("hp", data.hp)
		t.set_meta("max_hp", data.hp)
		add_child(t)
		targets.append(t)

func _start_combat(scenario: String):
	in_combat = true
	combat_target = targets[0] if scenario == "combat_melee" else targets[1]

func _make_hud():
	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % gold
	gold_label.position = Vector2(10, 10)
	gold_label.name = "GoldLabel"
	add_child(gold_label)
	var compass = ColorRect.new()
	compass.position = Vector2(1180, 10)
	compass.size = Vector2(60, 60)
	compass.color = Color(0.1, 0.1, 0.1, 0.5)
	add_child(compass)
	var arrow = ColorRect.new()
	arrow.position = Vector2(10, 25)
	arrow.size = Vector2(40, 10)
	arrow.color = Color(0.0, 1.0, 0.0)
	compass.add_child(arrow)
	var combat_ui = ColorRect.new()
	combat_ui.position = Vector2(340, 600)
	combat_ui.size = Vector2(600, 80)
	combat_ui.color = Color(0.1, 0.1, 0.1, 0.7)
	combat_ui.name = "CombatUI"
	combat_ui.visible = false
	add_child(combat_ui)
	var atk1 = Button.new()
	atk1.text = "Melee"
	atk1.position = Vector2(20, 20)
	combat_ui.add_child(atk1)
	var atk2 = Button.new()
	atk2.text = "Ranged"
	atk2.position = Vector2(120, 20)
	combat_ui.add_child(atk2)

func _process(delta):
	if player == null:
		return
	_handle_movement(delta)
	_check_bounty_pickup()
	_check_combat()
	_check_reward()
	_update_hud()

func _handle_movement(delta):
	var input_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.velocity = input_vec * 200
	player.move_and_slide()

func _check_bounty_pickup():
	if active_bounty >= 0:
		return
	for b in bounties:
		var rect = Rect2(b.position, b.size)
		if rect.has_point(player.position):
			if Input.is_action_just_pressed("ui_accept"):
				active_bounty = b.get_meta("index")
				b.color = Color(0.0, 0.7, 0.0)
				var banner = Label.new()
				banner.text = "Bounty Active: " + b.get_meta("name")
				banner.position = Vector2(440, 100)
				add_child(banner)

func _check_combat():
	if in_combat and combat_target != null:
		var ui = get_node_or_null("CombatUI")
		if ui:
			ui.visible = true
		if Input.is_action_just_pressed("ui_accept"):
			var dmg = 10
			combat_target.set_meta("hp", combat_target.get_meta("hp") - dmg)
			if combat_target.get_meta("hp") <= 0:
				combat_target.visible = false
				in_combat = false
				var banner = Label.new()
				banner.text = "Target Defeated!"
				banner.position = Vector2(440, 100)
				add_child(banner)
	else:
		var ui = get_node_or_null("CombatUI")
		if ui:
			ui.visible = false
		for t in targets:
			if player.position.distance_to(t.position) < 50 and t.visible:
				in_combat = true
				combat_target = t

func _check_reward():
	if active_bounty < 0:
		return
	var town_rect = Rect2(regions[0].node.position, regions[0].node.size)
	if town_rect.has_point(player.position):
		var target = targets[active_bounty]
		if target != null and not target.visible:
			var reward = bounties[active_bounty].get_meta("reward")
			gold += reward
			active_bounty = -1
			var banner = Label.new()
			banner.text = "Bounty Complete! +%dg" % reward
			banner.position = Vector2(440, 100)
			add_child(banner)

func _update_hud():
	var label = get_node_or_null("GoldLabel")
	if label:
		label.text = "Gold: %d" % gold
GDSCRIPT

cat > Main.tscn <<'TSCN'
[gd_scene load_steps=2 format=3 uid="uid://main"]

[ext_resource type="Script" path="res://Main.gd" id="1_main"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")
TSCN

mkdir -p demo_outputs

cat > demo_outputs/title.json <<'JSON'
{"scenario": "title", "duration_frames": 180, "events": [{"frame": 30, "type": "wait"}, {"frame": 150, "type": "mouse_click", "button": "left", "x": 640, "y": 400}, {"frame": 170, "type": "wait"}]}
JSON

cat > demo_outputs/pick_bounty.json <<'JSON'
{"scenario": "pick_bounty", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "W"}, {"frame": 60, "type": "key_up", "keycode": "W"}, {"frame": 90, "type": "key_press", "keycode": "SPACE"}, {"frame": 110, "type": "key_up", "keycode": "SPACE"}, {"frame": 280, "type": "wait"}]}
JSON

cat > demo_outputs/track_target.json <<'JSON'
{"scenario": "track_target", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "D"}, {"frame": 180, "type": "key_up", "keycode": "D"}, {"frame": 280, "type": "wait"}]}
JSON

cat > demo_outputs/combat_melee.json <<'JSON'
{"scenario": "combat_melee", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "SPACE"}, {"frame": 60, "type": "key_up", "keycode": "SPACE"}, {"frame": 90, "type": "key_press", "keycode": "SPACE"}, {"frame": 120, "type": "key_up", "keycode": "SPACE"}, {"frame": 150, "type": "key_press", "keycode": "SPACE"}, {"frame": 180, "type": "key_up", "keycode": "SPACE"}, {"frame": 280, "type": "wait"}]}
JSON

cat > demo_outputs/combat_ranged.json <<'JSON'
{"scenario": "combat_ranged", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "SPACE"}, {"frame": 60, "type": "key_up", "keycode": "SPACE"}, {"frame": 90, "type": "key_press", "keycode": "SPACE"}, {"frame": 120, "type": "key_up", "keycode": "SPACE"}, {"frame": 280, "type": "wait"}]}
JSON

cat > demo_outputs/claim_reward.json <<'JSON'
{"scenario": "claim_reward", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "W"}, {"frame": 120, "type": "key_up", "keycode": "W"}, {"frame": 280, "type": "wait"}]}
JSON

cat > demo_outputs/full_bounty.json <<'JSON'
{"scenario": "full_bounty", "duration_frames": 300, "events": [{"frame": 30, "type": "key_press", "keycode": "D"}, {"frame": 120, "type": "key_up", "keycode": "D"}, {"frame": 150, "type": "key_press", "keycode": "SPACE"}, {"frame": 180, "type": "key_up", "keycode": "SPACE"}, {"frame": 280, "type": "wait"}]}
JSON

echo "openworld-bounty Oracle ready at $GAME"
