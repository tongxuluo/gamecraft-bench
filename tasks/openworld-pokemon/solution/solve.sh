#!/bin/bash
# Reference solution for gamecraft-bench/openworld-creature.
#
# Drops a minimal but coherent open-world creature-capture RPG into
# /workspace/game/.  Covers all mechanic requirements with simple shapes
# and colours; art-style requirements (A1-A5) are intentionally low.
#
# Scenarios:
#   default         — title → explore → can enter grass / talk to NPCs
#   wild_encounter  — skip title, start in battle vs a wild creature
#   trainer_battle  — skip title, start in battle vs an NPC trainer
#   near_victory    — skip title, battle with enemy at 1 HP
#   town_heal       — skip title, player already in town near healer
#
# Demo traces exercise different requirement subsets.
set -eu

GAME=${GAME:-/workspace/game}
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot + Main scene
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="WildRealm"
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

# --------------------------------------------------------------------------
# Main.gd — single-file game.
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const VIEWPORT := Vector2(1280, 720)
const PLAYER_SPEED := 200.0

# Colours
const C_GRASS      := Color(0.35, 0.65, 0.25)
const C_GRASS_DARK := Color(0.20, 0.45, 0.15)
const C_TOWN       := Color(0.60, 0.50, 0.35)
const C_WATER      := Color(0.25, 0.50, 0.75)
const C_PLAYER     := Color(0.20, 0.60, 0.90)
const C_NPC_TRAINER:= Color(0.90, 0.40, 0.20)
const C_NPC_HEALER := Color(0.90, 0.70, 0.20)
const C_NPC_GYM    := Color(0.70, 0.20, 0.80)
const C_WILD_A     := Color(0.20, 0.80, 0.40)
const C_WILD_B     := Color(0.80, 0.30, 0.80)
const C_BLOCKER    := Color(0.30, 0.25, 0.20)
const C_UI_BG      := Color(0.10, 0.10, 0.12, 0.90)
const C_HP_GREEN   := Color(0.30, 0.85, 0.35)
const C_HP_RED     := Color(0.90, 0.25, 0.20)

# State
enum Mode { TITLE, WORLD, BATTLE, DIALOG, RESULT }
var mode: int = Mode.TITLE
var _scenario: String = ""

# World
var player_pos: Vector2 = Vector2(100, 360)
var player_hp: int = 20
var player_max_hp: int = 20
var player_level: int = 5
var player_xp: int = 0
var player_xp_next: int = 100
var gym_defeated: bool = false
var blocker_visible: bool = true
var encounter_cd: float = 0.0

# Battle
var enemy_name: String = ""
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_level: int = 0
var enemy_colour: Color = Color.WHITE
var is_trainer_battle: bool = false
var battle_msg: String = ""
var battle_anim: float = 0.0
var battle_anim_type: String = ""
var capture_shake: int = 0

# Nodes (created at runtime)
var title_root: Node
var world_root: Node
var battle_root: Node
var dialog_root: Node
var result_root: Node

var battle_player_sprite: ColorRect
var battle_enemy_sprite: ColorRect
var battle_player_hp_bar: ColorRect
var battle_enemy_hp_bar: ColorRect
var battle_player_hp_text: Label
var battle_enemy_hp_text: Label
var battle_player_lv: Label
var battle_enemy_lv: Label
var battle_msg_label: Label
var attack_btn: Button
var capture_btn: Button
var flee_btn: Button

var dialog_text: Label
var dialog_npc_name: Label
var npc_talking: String = ""

var result_text: Label
var result_btn: Button

var world_player: ColorRect
var world_blocker: ColorRect

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _ready() -> void:
    _parse_args()
    _build_title()
    _build_world()
    _build_battle()
    _build_dialog()
    _build_result()
    if _scenario == "wild_encounter":
        _start_battle(false)
    elif _scenario == "trainer_battle":
        _start_battle(true)
    elif _scenario == "near_victory":
        player_xp = player_xp_next - 10  # one kill away from levelling up
        _start_battle(true)
        enemy_hp = 1
    elif _scenario == "town_heal":
        mode = Mode.WORLD
        player_pos = Vector2(600, 480)
        title_root.visible = false
        world_root.visible = true
        _refresh_world()
    elif _scenario == "post_gym":
        mode = Mode.WORLD
        player_pos = Vector2(640, 360)
        gym_defeated = true
        blocker_visible = false
        title_root.visible = false
        world_root.visible = true
        _refresh_world()
    else:
        mode = Mode.TITLE
        title_root.visible = true
        world_root.visible = false
    battle_root.visible = false
    dialog_root.visible = false
    result_root.visible = false

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            _scenario = args[i + 1]
            i += 2
            continue
        i += 1

func _build_title() -> void:
    title_root = CanvasLayer.new()
    title_root.name = "Title"
    add_child(title_root)

    var bg := ColorRect.new()
    bg.color = Color(0.15, 0.25, 0.40)
    bg.size = VIEWPORT
    title_root.add_child(bg)

    var title := Label.new()
    title.text = "WildRealm"
    title.add_theme_font_size_override("font_size", 72)
    title.position = Vector2(VIEWPORT.x / 2 - 200, 180)
    title.size = Vector2(400, 100)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_root.add_child(title)

    var start_btn := Button.new()
    start_btn.text = "Start Adventure"
    start_btn.position = Vector2(VIEWPORT.x / 2 - 120, 380)
    start_btn.size = Vector2(240, 60)
    start_btn.add_theme_font_size_override("font_size", 28)
    start_btn.pressed.connect(_on_start_game)
    title_root.add_child(start_btn)

func _on_start_game() -> void:
    mode = Mode.WORLD
    title_root.visible = false
    world_root.visible = true
    _refresh_world()

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _build_world() -> void:
    world_root = Node2D.new()
    world_root.name = "World"
    add_child(world_root)
    world_root.visible = false

    # Region 1: Grassland (left)
    var grass := ColorRect.new()
    grass.color = C_GRASS
    grass.position = Vector2(0, 0)
    grass.size = Vector2(500, 720)
    grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(grass)

    # Tall grass patch
    var tall := ColorRect.new()
    tall.color = C_GRASS_DARK
    tall.position = Vector2(180, 220)
    tall.size = Vector2(180, 180)
    tall.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(tall)
    var tall_label := Label.new()
    tall_label.text = "Tall Grass"
    tall_label.position = Vector2(180, 200)
    tall_label.add_theme_font_size_override("font_size", 14)
    world_root.add_child(tall_label)

    # Region 2: Town (middle)
    var town := ColorRect.new()
    town.color = C_TOWN
    town.position = Vector2(500, 0)
    town.size = Vector2(300, 720)
    town.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(town)
    var town_label := Label.new()
    town_label.text = "Town"
    town_label.position = Vector2(600, 20)
    town_label.add_theme_font_size_override("font_size", 18)
    world_root.add_child(town_label)

    # Region 3: Water / locked area (right)
    var water := ColorRect.new()
    water.color = C_WATER
    water.position = Vector2(800, 0)
    water.size = Vector2(480, 720)
    water.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(water)
    var water_label := Label.new()
    water_label.text = "Riverlands"
    water_label.position = Vector2(950, 20)
    water_label.add_theme_font_size_override("font_size", 18)
    world_root.add_child(water_label)

    # Blocker (bridge/gate) between town and water
    world_blocker = ColorRect.new()
    world_blocker.color = C_BLOCKER
    world_blocker.position = Vector2(780, 300)
    world_blocker.size = Vector2(40, 120)
    world_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(world_blocker)
    var blocker_label := Label.new()
    blocker_label.text = "LOCKED"
    blocker_label.position = Vector2(770, 280)
    blocker_label.add_theme_font_size_override("font_size", 12)
    world_root.add_child(blocker_label)

    # Player
    world_player = ColorRect.new()
    world_player.color = C_PLAYER
    world_player.size = Vector2(32, 32)
    world_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(world_player)

    # NPC Trainer
    var npc_trainer := ColorRect.new()
    npc_trainer.color = C_NPC_TRAINER
    npc_trainer.position = Vector2(580, 180)
    npc_trainer.size = Vector2(32, 32)
    npc_trainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(npc_trainer)
    var nt_label := Label.new()
    nt_label.text = "Trainer"
    nt_label.position = Vector2(570, 160)
    nt_label.add_theme_font_size_override("font_size", 12)
    world_root.add_child(nt_label)

    # NPC Healer
    var npc_healer := ColorRect.new()
    npc_healer.color = C_NPC_HEALER
    npc_healer.position = Vector2(580, 480)
    npc_healer.size = Vector2(32, 32)
    npc_healer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(npc_healer)
    var nh_label := Label.new()
    nh_label.text = "Healer"
    nh_label.position = Vector2(570, 460)
    nh_label.add_theme_font_size_override("font_size", 12)
    world_root.add_child(nh_label)

    # Gym Leader
    var npc_gym := ColorRect.new()
    npc_gym.color = C_NPC_GYM
    npc_gym.position = Vector2(640, 340)
    npc_gym.size = Vector2(32, 32)
    npc_gym.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_root.add_child(npc_gym)
    var ng_label := Label.new()
    ng_label.text = "Gym Leader"
    ng_label.position = Vector2(620, 320)
    ng_label.add_theme_font_size_override("font_size", 12)
    world_root.add_child(ng_label)

    # Mini HUD
    var hud := CanvasLayer.new()
    hud.name = "WorldHUD"
    world_root.add_child(hud)
    var hud_bg := ColorRect.new()
    hud_bg.color = C_UI_BG
    hud_bg.position = Vector2(10, 10)
    hud_bg.size = Vector2(220, 70)
    hud.add_child(hud_bg)
    var hud_hp := Label.new()
    hud_hp.name = "HudHP"
    hud_hp.text = "HP: 20 / 20"
    hud_hp.position = Vector2(20, 15)
    hud_hp.add_theme_font_size_override("font_size", 16)
    hud.add_child(hud_hp)
    var hud_lv := Label.new()
    hud_lv.name = "HudLv"
    hud_lv.text = "Lv 5"
    hud_lv.position = Vector2(20, 40)
    hud_lv.add_theme_font_size_override("font_size", 16)
    hud.add_child(hud_lv)

func _refresh_world() -> void:
    world_player.position = player_pos
    world_blocker.visible = blocker_visible
    var hud := world_root.get_node("WorldHUD")
    hud.get_node("HudHP").text = "HP: %d / %d" % [player_hp, player_max_hp]
    hud.get_node("HudLv").text = "Lv %d  XP: %d/%d" % [player_level, player_xp, player_xp_next]

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _build_battle() -> void:
    battle_root = CanvasLayer.new()
    battle_root.name = "Battle"
    add_child(battle_root)
    battle_root.visible = false

    # Background
    var bg := ColorRect.new()
    bg.color = Color(0.12, 0.15, 0.18)
    bg.size = VIEWPORT
    battle_root.add_child(bg)

    # Enemy sprite (top right)
    battle_enemy_sprite = ColorRect.new()
    battle_enemy_sprite.position = Vector2(900, 80)
    battle_enemy_sprite.size = Vector2(120, 120)
    battle_root.add_child(battle_enemy_sprite)

    # Enemy name + level
    battle_enemy_lv = Label.new()
    battle_enemy_lv.position = Vector2(900, 60)
    battle_enemy_lv.add_theme_font_size_override("font_size", 18)
    battle_root.add_child(battle_enemy_lv)

    # Enemy HP bar bg
    var ehp_bg := ColorRect.new()
    ehp_bg.color = Color(0.20, 0.20, 0.20)
    ehp_bg.position = Vector2(880, 210)
    ehp_bg.size = Vector2(160, 16)
    battle_root.add_child(ehp_bg)
    # Enemy HP bar fill
    battle_enemy_hp_bar = ColorRect.new()
    battle_enemy_hp_bar.color = C_HP_GREEN
    battle_enemy_hp_bar.position = Vector2(880, 210)
    battle_enemy_hp_bar.size = Vector2(160, 16)
    battle_root.add_child(battle_enemy_hp_bar)
    battle_enemy_hp_text = Label.new()
    battle_enemy_hp_text.position = Vector2(880, 228)
    battle_enemy_hp_text.add_theme_font_size_override("font_size", 14)
    battle_root.add_child(battle_enemy_hp_text)

    # Player sprite (bottom left)
    battle_player_sprite = ColorRect.new()
    battle_player_sprite.color = C_PLAYER
    battle_player_sprite.position = Vector2(200, 420)
    battle_player_sprite.size = Vector2(120, 120)
    battle_root.add_child(battle_player_sprite)

    # Player name + level
    battle_player_lv = Label.new()
    battle_player_lv.position = Vector2(200, 400)
    battle_player_lv.add_theme_font_size_override("font_size", 18)
    battle_root.add_child(battle_player_lv)

    # Player HP bar bg
    var php_bg := ColorRect.new()
    php_bg.color = Color(0.20, 0.20, 0.20)
    php_bg.position = Vector2(180, 550)
    php_bg.size = Vector2(160, 16)
    battle_root.add_child(php_bg)
    # Player HP bar fill
    battle_player_hp_bar = ColorRect.new()
    battle_player_hp_bar.color = C_HP_GREEN
    battle_player_hp_bar.position = Vector2(180, 550)
    battle_player_hp_bar.size = Vector2(160, 16)
    battle_root.add_child(battle_player_hp_bar)
    battle_player_hp_text = Label.new()
    battle_player_hp_text.position = Vector2(180, 568)
    battle_player_hp_text.add_theme_font_size_override("font_size", 14)
    battle_root.add_child(battle_player_hp_text)

    # Message area
    var msg_bg := ColorRect.new()
    msg_bg.color = C_UI_BG
    msg_bg.position = Vector2(40, 620)
    msg_bg.size = Vector2(700, 80)
    battle_root.add_child(msg_bg)
    battle_msg_label = Label.new()
    battle_msg_label.position = Vector2(60, 635)
    battle_msg_label.size = Vector2(660, 50)
    battle_msg_label.add_theme_font_size_override("font_size", 18)
    battle_root.add_child(battle_msg_label)

    # Buttons
    attack_btn = Button.new()
    attack_btn.text = "Tackle"
    attack_btn.position = Vector2(820, 620)
    attack_btn.size = Vector2(130, 50)
    attack_btn.add_theme_font_size_override("font_size", 20)
    attack_btn.pressed.connect(_on_attack)
    battle_root.add_child(attack_btn)

    capture_btn = Button.new()
    capture_btn.text = "Throw Ball"
    capture_btn.position = Vector2(960, 620)
    capture_btn.size = Vector2(130, 50)
    capture_btn.add_theme_font_size_override("font_size", 20)
    capture_btn.pressed.connect(_on_capture)
    battle_root.add_child(capture_btn)

    flee_btn = Button.new()
    flee_btn.text = "Flee"
    flee_btn.position = Vector2(1100, 620)
    flee_btn.size = Vector2(130, 50)
    flee_btn.add_theme_font_size_override("font_size", 20)
    flee_btn.pressed.connect(_on_flee)
    battle_root.add_child(flee_btn)

func _refresh_battle() -> void:
    var e_ratio: float = float(enemy_hp) / float(max(enemy_max_hp, 1))
    battle_enemy_hp_bar.size.x = 160 * e_ratio
    battle_enemy_hp_bar.color = C_HP_GREEN if e_ratio > 0.3 else C_HP_RED
    battle_enemy_hp_text.text = "HP %d / %d" % [enemy_hp, enemy_max_hp]
    battle_enemy_lv.text = "%s  Lv %d" % [enemy_name, enemy_level]
    battle_enemy_sprite.color = enemy_colour

    var p_ratio: float = float(player_hp) / float(max(player_max_hp, 1))
    battle_player_hp_bar.size.x = 160 * p_ratio
    battle_player_hp_bar.color = C_HP_GREEN if p_ratio > 0.3 else C_HP_RED
    battle_player_hp_text.text = "HP %d / %d" % [player_hp, player_max_hp]
    battle_player_lv.text = "Player  Lv %d" % [player_level]

    battle_msg_label.text = battle_msg

    # Disable flee in trainer battles
    flee_btn.disabled = is_trainer_battle

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _build_dialog() -> void:
    dialog_root = CanvasLayer.new()
    dialog_root.name = "Dialog"
    add_child(dialog_root)
    dialog_root.visible = false

    var panel := ColorRect.new()
    panel.color = C_UI_BG
    panel.position = Vector2(80, 500)
    panel.size = Vector2(1120, 180)
    dialog_root.add_child(panel)

    dialog_npc_name = Label.new()
    dialog_npc_name.position = Vector2(100, 510)
    dialog_npc_name.add_theme_font_size_override("font_size", 20)
    dialog_root.add_child(dialog_npc_name)

    dialog_text = Label.new()
    dialog_text.position = Vector2(100, 545)
    dialog_text.size = Vector2(1080, 120)
    dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialog_text.add_theme_font_size_override("font_size", 18)
    dialog_root.add_child(dialog_text)

func _build_result() -> void:
    result_root = CanvasLayer.new()
    result_root.name = "Result"
    add_child(result_root)
    result_root.visible = false

    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.08, 0.85)
    bg.size = VIEWPORT
    result_root.add_child(bg)

    result_text = Label.new()
    result_text.position = Vector2(VIEWPORT.x / 2 - 300, VIEWPORT.y / 2 - 60)
    result_text.size = Vector2(600, 120)
    result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_text.add_theme_font_size_override("font_size", 64)
    result_root.add_child(result_text)

    result_btn = Button.new()
    result_btn.text = "Continue"
    result_btn.position = Vector2(VIEWPORT.x / 2 - 80, VIEWPORT.y / 2 + 80)
    result_btn.size = Vector2(160, 50)
    result_btn.add_theme_font_size_override("font_size", 22)
    result_btn.pressed.connect(_on_result_continue)
    result_root.add_child(result_btn)

func _on_result_continue() -> void:
    result_root.visible = false
    if mode == Mode.RESULT:
        if gym_defeated and blocker_visible:
            blocker_visible = false
            _show_dialog("System", "The river bridge has lowered! New areas are now accessible.")
            return
        mode = Mode.WORLD
        world_root.visible = true
        _refresh_world()

func _show_dialog(npc: String, text: String) -> void:
    npc_talking = npc
    dialog_npc_name.text = npc
    dialog_text.text = text
    dialog_root.visible = true
    if mode != Mode.DIALOG:
        mode = Mode.DIALOG

func _close_dialog() -> void:
    dialog_root.visible = false
    mode = Mode.WORLD
    world_root.visible = true
    _refresh_world()

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _process(delta: float) -> void:
    if mode == Mode.WORLD:
        _process_world(delta)
    elif mode == Mode.BATTLE:
        _process_battle(delta)
    elif mode == Mode.RESULT and battle_anim > 0:
        battle_anim -= delta
        if battle_anim <= 0:
            battle_anim = 0

func _process_world(delta: float) -> void:
    if encounter_cd > 0:
        encounter_cd -= delta

    var move := Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        move.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        move.y += 1
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        move.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        move.x += 1

    if move != Vector2.ZERO:
        move = move.normalized() * PLAYER_SPEED * delta
        var new_pos := player_pos + move
        # Bounds
        new_pos.x = clampf(new_pos.x, 0, VIEWPORT.x - 32)
        new_pos.y = clampf(new_pos.y, 0, VIEWPORT.y - 32)
        # Blocker collision
        if blocker_visible and new_pos.x + 32 > 780 and new_pos.x < 820 and new_pos.y + 32 > 300 and new_pos.y < 420:
            new_pos.x = minf(new_pos.x, 780 - 32)
        player_pos = new_pos
        _refresh_world()

        # Tall grass encounter check
        if encounter_cd <= 0 and _in_tall_grass(player_pos):
            encounter_cd = 1.5
            if randf() < 0.4:
                _start_battle(false)

func _in_tall_grass(pos: Vector2) -> bool:
    return pos.x + 16 >= 180 and pos.x + 16 <= 360 and pos.y + 16 >= 220 and pos.y + 16 <= 400

func _process_battle(delta: float) -> void:
    if battle_anim > 0:
        battle_anim -= delta
        # Capture shake animation
        if battle_anim_type == "capture":
            var shake := sin(battle_anim * 30.0) * 5.0 * (capture_shake + 1)
            battle_enemy_sprite.position.x = 900 + shake
        # Attack lunge animation
        elif battle_anim_type == "attack_player":
            var t := 1.0 - battle_anim / 0.4
            battle_player_sprite.position.x = 200 + sin(t * PI) * 60.0
        elif battle_anim_type == "attack_enemy":
            var t := 1.0 - battle_anim / 0.4
            battle_enemy_sprite.position.x = 900 - sin(t * PI) * 60.0

        if battle_anim <= 0:
            battle_anim = 0
            battle_anim_type = ""
            battle_enemy_sprite.position = Vector2(900, 80)
            battle_player_sprite.position = Vector2(200, 420)
            if battle_msg.begins_with("CAUGHT"):
                _end_battle(true)
            elif battle_msg.begins_with("Broke free"):
                _enemy_turn()
            elif battle_msg.begins_with("You defeated") or battle_msg.begins_with("You were defeated"):
                pass  # wait for result screen
            else:
                _enemy_turn()

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _unhandled_input(event: InputEvent) -> void:
    if mode == Mode.DIALOG and event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if npc_talking == "System" and gym_defeated:
                _close_dialog()
            elif npc_talking == "Trainer" or npc_talking == "Healer" or npc_talking == "Gym Leader":
                _handle_npc_action()
            else:
                _close_dialog()
            return
    if mode == Mode.BATTLE and event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            return  # buttons handle themselves

func _handle_npc_action() -> void:
    if npc_talking == "Trainer":
        dialog_root.visible = false
        _start_battle(true)
    elif npc_talking == "Healer":
        player_hp = player_max_hp
        dialog_text.text = "Your creatures are fully healed!"
        npc_talking = ""
        # Click again to close
    elif npc_talking == "Gym Leader":
        dialog_root.visible = false
        _start_battle(true)
        is_trainer_battle = true
        enemy_name = "Gym Leader"
        enemy_level = 8
        enemy_hp = 25
        enemy_max_hp = 25
        enemy_colour = C_NPC_GYM
        _refresh_battle()
    elif npc_talking == "":
        _close_dialog()

func _start_battle(trainer: bool) -> void:
    mode = Mode.BATTLE
    world_root.visible = false
    title_root.visible = false
    battle_root.visible = true
    dialog_root.visible = false
    result_root.visible = false
    is_trainer_battle = trainer

    if trainer:
        if _scenario == "near_victory":
            enemy_name = "Trainer"
            enemy_level = 3
            enemy_hp = 1
            enemy_max_hp = 15
        else:
            enemy_name = "Trainer"
            enemy_level = 3
            enemy_hp = 15
            enemy_max_hp = 15
        enemy_colour = C_NPC_TRAINER
    else:
        if randf() < 0.5:
            enemy_name = "Leaflet"
            enemy_colour = C_WILD_A
        else:
            enemy_name = "Bloombug"
            enemy_colour = C_WILD_B
        enemy_level = randi() % 3 + 2
        enemy_hp = 10 + enemy_level * 2
        enemy_max_hp = enemy_hp

    battle_msg = "A wild %s appeared!" % enemy_name if not trainer else "%s wants to battle!" % enemy_name
    battle_anim = 0.0
    capture_shake = 0
    _refresh_battle()

func _on_attack() -> void:
    if mode != Mode.BATTLE or battle_anim > 0:
        return
    # Player attacks
    var dmg := randi() % 3 + 3 + player_level
    enemy_hp -= dmg
    if enemy_hp < 0:
        enemy_hp = 0
    battle_msg = "You used Tackle! %s took %d damage." % [enemy_name, dmg]
    battle_anim = 0.4
    battle_anim_type = "attack_player"
    _refresh_battle()

func _on_capture() -> void:
    if mode != Mode.BATTLE or battle_anim > 0 or is_trainer_battle:
        return
    battle_msg = "You threw a Capture Ball..."
    battle_anim = 1.2
    battle_anim_type = "capture"
    # Success chance scales with missing HP
    var ratio: float = float(enemy_hp) / float(max(enemy_max_hp, 1))
    var success: bool = randf() > ratio * 0.8
    capture_shake = randi() % 3 + 1
    if success:
        battle_msg = "CAUGHT! You captured %s!" % enemy_name
    else:
        battle_msg = "Broke free! %s escaped the ball!" % enemy_name
    _refresh_battle()

func _on_flee() -> void:
    if mode != Mode.BATTLE or battle_anim > 0 or is_trainer_battle:
        return
    battle_msg = "You got away safely!"
    _end_battle(false)

func _enemy_turn() -> void:
    if mode != Mode.BATTLE:
        return
    if enemy_hp <= 0:
        _battle_victory()
        return
    var dmg := randi() % 3 + 2 + enemy_level
    player_hp -= dmg
    if player_hp < 0:
        player_hp = 0
    battle_msg = "%s attacked! You took %d damage." % [enemy_name, dmg]
    battle_anim = 0.4
    battle_anim_type = "attack_enemy"
    _refresh_battle()
    if player_hp <= 0:
        _battle_defeat()

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _battle_victory() -> void:
    if enemy_name == "Gym Leader":
        gym_defeated = true
    mode = Mode.RESULT
    result_root.visible = true
    result_text.text = "Victory!"
    # Award XP
    var xp_gain := enemy_level * 10 + 20
    player_xp += xp_gain
    var leveled := false
    while player_xp >= player_xp_next:
        player_xp -= player_xp_next
        player_level += 1
        player_max_hp += 5
        player_hp = player_max_hp
        player_xp_next = player_level * 25
        leveled = true
    if leveled:
        battle_msg = "Victory! Gained %d XP. Level up! You are now Lv %d!" % [xp_gain, player_level]
    else:
        battle_msg = "Victory! Gained %d XP." % xp_gain
    result_btn.text = "Continue"
    _refresh_world()

func _battle_defeat() -> void:
    mode = Mode.RESULT
    result_root.visible = true
    result_text.text = "Defeat..."
    battle_msg = "You were defeated..."
    result_btn.text = "Retry"
    # Reset player
    player_hp = player_max_hp
    player_pos = Vector2(100, 360)
    _refresh_world()

func _end_battle(captured: bool) -> void:
    mode = Mode.WORLD
    battle_root.visible = false
    world_root.visible = true
    _refresh_world()

func _on_world_click(pos: Vector2) -> void:
    if mode != Mode.WORLD:
        return
    # Trainer NPC click (580,180) size 32
    if pos.x >= 580 and pos.x <= 612 and pos.y >= 180 and pos.y <= 212:
        _show_dialog("Trainer", "Hey, let's battle! (Click to start)")
        return
    # Healer NPC click (580,480)
    if pos.x >= 580 and pos.x <= 612 and pos.y >= 480 and pos.y <= 512:
        _show_dialog("Healer", "Welcome! I'll heal your creatures. (Click to heal)")
        return
    # Gym Leader click (640,340)
    if pos.x >= 640 and pos.x <= 672 and pos.y >= 340 and pos.y <= 372:
        _show_dialog("Gym Leader", "Prove your strength! (Click to battle)")
        return

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _input(event: InputEvent) -> void:
    if mode == Mode.WORLD and event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _on_world_click(event.position)
            get_viewport().set_input_as_handled()

GDSCRIPT_EOF

# --------------------------------------------------------------------------
# Demo traces. Coordinates target the 1280×720 viewport.
# --------------------------------------------------------------------------

cat > "$GAME/demo_outputs/title_explore.json" <<'EOF'
{
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 410},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 270, "y": 310},
    {"frame": 540, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/battle_attack.json" <<'EOF'
{
  "scenario": "wild_encounter",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/battle_capture.json" <<'EOF'
{
  "scenario": "wild_encounter",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 1025, "y": 645},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/town_heal.json" <<'EOF'
{
  "duration_frames": 360,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 410},
    {"frame": 90,  "type": "mouse_click", "button": "left", "x": 596, "y": 496},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 596, "y": 496},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/trainer_fight.json" <<'EOF'
{
  "scenario": "trainer_battle",
  "duration_frames": 420,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/level_up.json" <<'EOF'
{
  "scenario": "near_victory",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/gym_unlock.json" <<'EOF'
{
  "duration_frames": 600,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 410},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 656, "y": 356},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 656, "y": 356},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 420, "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 540, "type": "mouse_click", "button": "left", "x": 885, "y": 645},
    {"frame": 600, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/region_unlocked.json" <<'EOF'
{
  "scenario": "post_gym",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 900, "y": 360},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
