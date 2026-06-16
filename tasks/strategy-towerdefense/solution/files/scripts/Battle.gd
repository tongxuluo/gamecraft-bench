extends Node2D

var main: Node = null
var stage_id: String = "stage1"

# Grid: 12 cols × 7 rows, cell 64 px, origin (160, 96).
const COLS := 12
const ROWS := 7
const CELL := 64
const ORIGIN := Vector2(160, 96)

const COLOR_BG := Color(0.07, 0.08, 0.10)
const COLOR_TILE_A := Color(0.16, 0.18, 0.20)
const COLOR_TILE_B := Color(0.20, 0.22, 0.24)
const COLOR_TILE_LINE := Color(0.10, 0.11, 0.13)
const COLOR_PATH := Color(0.42, 0.32, 0.22)
const COLOR_PATH_EDGE := Color(0.55, 0.42, 0.30)
const COLOR_DEPLOY := Color(0.30, 0.55, 0.40, 0.30)
const COLOR_DEPLOY_HL := Color(0.40, 0.85, 0.55, 0.65)
const COLOR_PANEL := Color(0.18, 0.20, 0.23)
const COLOR_ACCENT := Color(0.55, 0.60, 0.66)
const COLOR_RED := Color(0.85, 0.30, 0.30)
const COLOR_TEXT := Color(0.90, 0.92, 0.94)

const STAGE_DATA := {
    "stage1": {
        "tint": Color(1.0, 1.0, 1.0),
        "path": [Vector2i(-1,3), Vector2i(2,3), Vector2i(2,1), Vector2i(7,1), Vector2i(7,5), Vector2i(11,5), Vector2i(12,5)],
        "deploy": [Vector2i(1,2), Vector2i(3,2), Vector2i(5,2), Vector2i(5,4), Vector2i(8,4), Vector2i(10,4), Vector2i(8,6), Vector2i(10,6)],
        "waves": [
            [{"type":"grunt","n":3,"interval":0.7}],
            [{"type":"grunt","n":3,"interval":0.6},{"type":"runner","n":2,"interval":0.5}],
            [{"type":"grunt","n":2,"interval":0.6},{"type":"brute","n":2,"interval":1.0}]
        ]
    },
    "stage2": {
        "tint": Color(0.85, 0.95, 1.10),
        "path": [Vector2i(-1,1), Vector2i(4,1), Vector2i(4,5), Vector2i(8,5), Vector2i(8,2), Vector2i(12,2)],
        "deploy": [Vector2i(2,3), Vector2i(3,3), Vector2i(5,3), Vector2i(6,4), Vector2i(7,4), Vector2i(9,4), Vector2i(10,3), Vector2i(11,4)],
        "waves": [
            [{"type":"runner","n":3,"interval":0.5}],
            [{"type":"grunt","n":3,"interval":0.6},{"type":"brute","n":2,"interval":1.2}],
            [{"type":"runner","n":2,"interval":0.5},{"type":"brute","n":3,"interval":1.0}]
        ]
    }
}

const UNITS := [
    {"id":"blocker","cost":2,"color":Color(0.35,0.55,0.85),"hp":6,"atk":1,"range":1.0,"rate":0.7,"label":"BLK"},
    {"id":"sniper", "cost":3,"color":Color(0.85,0.75,0.30),"hp":3,"atk":2,"range":4.5,"rate":1.2,"label":"SNP"},
    {"id":"medic",  "cost":4,"color":Color(0.55,0.85,0.55),"hp":4,"atk":1,"range":2.5,"rate":0.6,"label":"MED"},
]

const ENEMIES := {
    "grunt":  {"hp":4,"speed":1.0,"color":Color(0.80,0.30,0.30),"size":Vector2(40,40)},
    "runner": {"hp":2,"speed":2.0,"color":Color(0.90,0.55,0.30),"size":Vector2(32,32)},
    "brute":  {"hp":8,"speed":0.6,"color":Color(0.65,0.25,0.50),"size":Vector2(54,54)},
}

var grid_root: Node2D
var path_root: Node2D
var deploy_root: Node2D
var unit_root: Node2D
var enemy_root: Node2D
var fx_root: Node2D
var hud_root: CanvasLayer

var dp_label: Label
var dp_bar: ColorRect
var wave_label: Label
var life_label: Label
var feedback_label: Label

var dp: float = 4.0
var dp_max: float = 15.0
var dp_regen: float = 0.6
var life: int = 5
var wave_idx: int = 0
var wave_active: bool = false
var spawning: bool = false
var stage_done: bool = false

var path_world: Array = []
var path_total_len: float = 0.0
var deploy_cells: Array = []
var path_cells: Dictionary = {}

var enemies: Array = []
var units: Array = []

var dragging_idx: int = -1
var drag_ghost: ColorRect = null

var hand_buttons: Array = []
var feedback_timer: float = 0.0
var life_flash_timer: float = 0.0
var dp_flash_timer: float = 0.0

func _ready() -> void:
    var data: Dictionary = STAGE_DATA[stage_id]
    deploy_cells = data.deploy.duplicate()
    _compute_path(data.path)

    _build_grid(data.tint)
    _build_path(data.tint)
    _build_deploy_overlay()

    fx_root = Node2D.new()
    fx_root.name = "FX"
    add_child(fx_root)

    enemy_root = Node2D.new()
    enemy_root.name = "Enemies"
    add_child(enemy_root)

    unit_root = Node2D.new()
    unit_root.name = "Units"
    add_child(unit_root)

    _build_hud()
    _build_hand()

    set_process(true)
    set_process_input(true)
    _start_next_wave()

func _process(dt: float) -> void:
    if stage_done:
        return
    # DP regen.
    dp = min(dp + dp_regen * dt, dp_max)
    dp_label.text = "DP %d / %d" % [int(dp), int(dp_max)]
    dp_bar.size = Vector2(180.0 * (dp / dp_max), 8)
    if dp_flash_timer > 0.0:
        dp_flash_timer -= dt
        dp_bar.modulate = Color(1, 0.4, 0.4) if int(dp_flash_timer * 8) % 2 == 0 else Color(1, 1, 1)
        if dp_flash_timer <= 0.0:
            dp_bar.modulate = Color(1, 1, 1)
    if life_flash_timer > 0.0:
        life_flash_timer -= dt
        life_label.modulate = Color(1, 0.3, 0.3) if int(life_flash_timer * 8) % 2 == 0 else Color(1, 1, 1)
        if life_flash_timer <= 0.0:
            life_label.modulate = Color(1, 1, 1)

    # Move enemies along the path.
    var to_remove: Array = []
    for e in enemies:
        if e.hp <= 0:
            continue
        var blocker = _find_blocker_for(e)
        if blocker != null:
            e.last_atk += dt
            if e.last_atk >= 1.0:
                e.last_atk = 0.0
                blocker.hp -= 1
                _refresh_unit_hp(blocker)
                _spark(blocker.sprite.position + Vector2(CELL/2, CELL/2), Color(1, 0.5, 0.3))
                if blocker.hp <= 0:
                    _kill_unit(blocker)
            continue
        e.dist += e.speed * 64.0 * dt
        var pos = _path_pos(e.dist)
        if pos == null:
            life -= 1
            life_label.text = "LIVES %d" % life
            life_flash_timer = 0.6
            to_remove.append(e)
            if life <= 0:
                _end_battle(false)
                return
            continue
        e.sprite.position = pos - e.size * 0.5
        e.hp_label.position = pos + Vector2(-22, -e.size.y * 0.5 - 18)
    for e in to_remove:
        if e.hp > 0:
            enemies.erase(e)
        if is_instance_valid(e.sprite): e.sprite.queue_free()
        if is_instance_valid(e.hp_label): e.hp_label.queue_free()

    # Units shoot.
    for u in units:
        u.last_atk += dt
        if u.last_atk < u.def.rate:
            continue
        var target = _find_target_for(u)
        if target == null:
            continue
        u.last_atk = 0.0
        target.hp -= u.def.atk
        _refresh_enemy_hp(target)
        _projectile(_cell_center(u.cell), target.sprite.position + target.size * 0.5, u.def.color)
        if target.hp <= 0:
            _kill_enemy(target)

    # Wave progression.
    if wave_active and not spawning and _alive_enemies() == 0:
        wave_idx += 1
        var data: Dictionary = STAGE_DATA[stage_id]
        if wave_idx >= data.waves.size():
            _end_battle(true)
            return
        wave_label.text = "WAVE %d / %d" % [wave_idx + 1, data.waves.size()]
        wave_active = false
        await get_tree().create_timer(2.0).timeout
        if not stage_done:
            _start_next_wave()

    # Drag ghost follow cursor.
    if dragging_idx >= 0 and drag_ghost != null:
        drag_ghost.position = get_viewport().get_mouse_position() - drag_ghost.size * 0.5

    if feedback_timer > 0.0:
        feedback_timer -= dt
        if feedback_timer <= 0.0:
            feedback_label.text = ""

func _input(event: InputEvent) -> void:
    if stage_done:
        return
    if event is InputEventMouseButton and not event.pressed and dragging_idx >= 0:
        _try_deploy(get_viewport().get_mouse_position())

func _alive_enemies() -> int:
    var n := 0
    for e in enemies:
        if e.hp > 0:
            n += 1
    return n

# ---- grid / path / deploy build ----------------------------------------

func _build_grid(tint: Color) -> void:
    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    grid_root = Node2D.new()
    grid_root.name = "Grid"
    add_child(grid_root)

    for r in range(ROWS):
        for c in range(COLS):
            var cell := ColorRect.new()
            cell.color = (COLOR_TILE_A if (c + r) % 2 == 0 else COLOR_TILE_B) * tint
            cell.position = ORIGIN + Vector2(c * CELL, r * CELL)
            cell.size = Vector2(CELL, CELL)
            cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grid_root.add_child(cell)
            var line := ColorRect.new()
            line.color = COLOR_TILE_LINE
            line.position = cell.position
            line.size = Vector2(CELL, 1)
            line.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grid_root.add_child(line)
    var right_edge := ColorRect.new()
    right_edge.color = COLOR_ACCENT
    right_edge.position = ORIGIN
    right_edge.size = Vector2(2, ROWS * CELL)
    grid_root.add_child(right_edge)
    var bot_edge := ColorRect.new()
    bot_edge.color = COLOR_ACCENT
    bot_edge.position = ORIGIN + Vector2(0, ROWS * CELL - 2)
    bot_edge.size = Vector2(COLS * CELL, 2)
    grid_root.add_child(bot_edge)

func _compute_path(waypoints: Array) -> void:
    path_world.clear()
    path_cells.clear()
    path_total_len = 0.0
    for w in waypoints:
        path_world.append(_cell_center(w))
    # Mark every cell the path crosses (for deploy validation visualisation).
    for i in range(waypoints.size() - 1):
        var a: Vector2i = waypoints[i]
        var b: Vector2i = waypoints[i + 1]
        var step := Vector2i(sign(b.x - a.x), sign(b.y - a.y))
        var cur := a
        while cur != b:
            if cur.x >= 0 and cur.x < COLS and cur.y >= 0 and cur.y < ROWS:
                path_cells[cur] = true
            cur += step
        if cur.x >= 0 and cur.x < COLS and cur.y >= 0 and cur.y < ROWS:
            path_cells[cur] = true
    for i in range(path_world.size() - 1):
        path_total_len += path_world[i].distance_to(path_world[i + 1])

func _build_path(tint: Color) -> void:
    path_root = Node2D.new()
    path_root.name = "Path"
    add_child(path_root)
    # Draw path as fat colored segments between waypoints.
    for i in range(path_world.size() - 1):
        var a: Vector2 = path_world[i]
        var b: Vector2 = path_world[i + 1]
        _draw_segment(a, b, COLOR_PATH * tint, 36)
        _draw_segment(a, b, COLOR_PATH_EDGE * tint, 4)
    # Direction arrows.
    for i in range(path_world.size() - 1):
        var a: Vector2 = path_world[i]
        var b: Vector2 = path_world[i + 1]
        var mid := (a + b) * 0.5
        var arrow := Label.new()
        arrow.text = ">"
        arrow.position = mid - Vector2(8, 14)
        arrow.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
        arrow.add_theme_font_size_override("font_size", 22)
        arrow.rotation = (b - a).angle()
        path_root.add_child(arrow)

func _draw_segment(a: Vector2, b: Vector2, color: Color, thickness: int) -> void:
    var seg := ColorRect.new()
    seg.color = color
    var v := b - a
    var len := v.length()
    if len < 0.01:
        return
    seg.size = Vector2(len, thickness)
    seg.position = a - Vector2(0, thickness / 2.0)
    seg.pivot_offset = Vector2(0, thickness / 2.0)
    seg.rotation = v.angle()
    seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    path_root.add_child(seg)

func _build_deploy_overlay() -> void:
    deploy_root = Node2D.new()
    deploy_root.name = "Deploy"
    add_child(deploy_root)
    for c in deploy_cells:
        var marker := ColorRect.new()
        marker.color = COLOR_DEPLOY
        marker.position = ORIGIN + Vector2(c.x * CELL + 4, c.y * CELL + 4)
        marker.size = Vector2(CELL - 8, CELL - 8)
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        deploy_root.add_child(marker)
        # Inner dotted outline (simulated with corner dots).
        for dx in [4, CELL - 12]:
            for dy in [4, CELL - 12]:
                var dot := ColorRect.new()
                dot.color = Color(0.55, 0.85, 0.55, 0.85)
                dot.position = ORIGIN + Vector2(c.x * CELL + dx, c.y * CELL + dy)
                dot.size = Vector2(8, 8)
                dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
                deploy_root.add_child(dot)

func _path_pos(dist: float) -> Variant:
    if dist <= 0.0:
        return path_world[0]
    var d := dist
    for i in range(path_world.size() - 1):
        var seg_len: float = path_world[i].distance_to(path_world[i + 1])
        if d <= seg_len:
            var t = d / seg_len
            return path_world[i].lerp(path_world[i + 1], t)
        d -= seg_len
    return null

func _cell_center(c: Vector2i) -> Vector2:
    return ORIGIN + Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)

func _pixel_to_cell(p: Vector2) -> Vector2i:
    var rel := p - ORIGIN
    if rel.x < 0 or rel.y < 0:
        return Vector2i(-1, -1)
    var cx := int(rel.x / CELL)
    var cy := int(rel.y / CELL)
    if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
        return Vector2i(-1, -1)
    return Vector2i(cx, cy)

# ---- HUD ---------------------------------------------------------------

func _build_hud() -> void:
    hud_root = CanvasLayer.new()
    add_child(hud_root)
    # Top bar background.
    var top := ColorRect.new()
    top.color = COLOR_PANEL
    top.size = Vector2(1280, 60)
    hud_root.add_child(top)
    var top_edge := ColorRect.new()
    top_edge.color = COLOR_ACCENT
    top_edge.position = Vector2(0, 58)
    top_edge.size = Vector2(1280, 2)
    hud_root.add_child(top_edge)

    # DP (left).
    dp_label = Label.new()
    dp_label.text = "DP %d / %d" % [int(dp), int(dp_max)]
    dp_label.position = Vector2(20, 12)
    dp_label.add_theme_color_override("font_color", COLOR_TEXT)
    dp_label.add_theme_font_size_override("font_size", 22)
    hud_root.add_child(dp_label)
    var bar_bg := ColorRect.new()
    bar_bg.color = Color(0.10, 0.12, 0.14)
    bar_bg.position = Vector2(20, 42)
    bar_bg.size = Vector2(180, 8)
    hud_root.add_child(bar_bg)
    dp_bar = ColorRect.new()
    dp_bar.color = Color(0.40, 0.85, 0.55)
    dp_bar.position = Vector2(20, 42)
    dp_bar.size = Vector2(180.0 * (dp / dp_max), 8)
    hud_root.add_child(dp_bar)

    # Wave (center).
    wave_label = Label.new()
    wave_label.text = "WAVE 1 / ?"
    wave_label.position = Vector2(540, 16)
    wave_label.size = Vector2(200, 30)
    wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wave_label.add_theme_color_override("font_color", COLOR_TEXT)
    wave_label.add_theme_font_size_override("font_size", 24)
    hud_root.add_child(wave_label)

    # Lives (right).
    life_label = Label.new()
    life_label.text = "LIVES %d" % life
    life_label.position = Vector2(1100, 16)
    life_label.size = Vector2(160, 30)
    life_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    life_label.add_theme_color_override("font_color", COLOR_RED)
    life_label.add_theme_font_size_override("font_size", 24)
    hud_root.add_child(life_label)

    # Bottom bar.
    var bot := ColorRect.new()
    bot.color = COLOR_PANEL
    bot.position = Vector2(0, 600)
    bot.size = Vector2(1280, 120)
    hud_root.add_child(bot)
    var bot_edge := ColorRect.new()
    bot_edge.color = COLOR_ACCENT
    bot_edge.position = Vector2(0, 600)
    bot_edge.size = Vector2(1280, 2)
    hud_root.add_child(bot_edge)

    # Feedback label (transient messages).
    feedback_label = Label.new()
    feedback_label.position = Vector2(440, 568)
    feedback_label.size = Vector2(400, 30)
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
    feedback_label.add_theme_font_size_override("font_size", 18)
    hud_root.add_child(feedback_label)

func _build_hand() -> void:
    hand_buttons.clear()
    for i in range(UNITS.size()):
        var u: Dictionary = UNITS[i]
        var card := ColorRect.new()
        card.color = Color(0.12, 0.14, 0.16)
        card.position = Vector2(40 + i * 130, 620)
        card.size = Vector2(110, 80)
        hud_root.add_child(card)
        var border := ColorRect.new()
        border.color = COLOR_ACCENT
        border.position = card.position
        border.size = Vector2(110, 3)
        hud_root.add_child(border)
        var swatch := ColorRect.new()
        swatch.color = u.color
        swatch.position = card.position + Vector2(8, 28)
        swatch.size = Vector2(40, 40)
        hud_root.add_child(swatch)
        var name := Label.new()
        name.text = u.label
        name.position = card.position + Vector2(54, 8)
        name.add_theme_color_override("font_color", COLOR_TEXT)
        name.add_theme_font_size_override("font_size", 18)
        hud_root.add_child(name)
        var cost := Label.new()
        cost.text = "DP %d" % u.cost
        cost.position = card.position + Vector2(54, 36)
        cost.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
        cost.add_theme_font_size_override("font_size", 16)
        hud_root.add_child(cost)
        # Make the card pressable: a transparent Button covers it.
        var btn := Button.new()
        btn.flat = true
        btn.position = card.position
        btn.size = card.size
        btn.button_down.connect(func(): _start_drag(i))
        hud_root.add_child(btn)
        hand_buttons.append({"card": card, "border": border, "btn": btn, "idx": i})

func _start_drag(i: int) -> void:
    if stage_done:
        return
    var u: Dictionary = UNITS[i]
    if dp < u.cost:
        _flash_insufficient_dp(i)
        return
    dragging_idx = i
    drag_ghost = ColorRect.new()
    drag_ghost.color = u.color
    drag_ghost.size = Vector2(48, 48)
    drag_ghost.modulate = Color(1, 1, 1, 0.75)
    add_child(drag_ghost)
    # Highlight the card.
    if i < hand_buttons.size():
        hand_buttons[i].border.color = Color(1, 0.85, 0.4)

func _flash_insufficient_dp(i: int) -> void:
    feedback_label.text = "NOT ENOUGH DP"
    feedback_timer = 1.2
    dp_flash_timer = 0.6
    if i < hand_buttons.size():
        var card: ColorRect = hand_buttons[i].card
        var orig := card.color
        card.color = Color(0.50, 0.18, 0.18)
        await get_tree().create_timer(0.3).timeout
        if is_instance_valid(card):
            card.color = orig

func _try_deploy(mouse_pos: Vector2) -> void:
    var idx := dragging_idx
    var u: Dictionary = UNITS[idx]
    var cell := _pixel_to_cell(mouse_pos)
    var ok: bool = cell != Vector2i(-1, -1) and deploy_cells.has(cell) and not _unit_at_cell(cell)
    _end_drag()
    if not ok:
        feedback_label.text = "INVALID DEPLOY CELL"
        feedback_timer = 1.0
        _spark(mouse_pos, COLOR_RED)
        return
    if dp < u.cost:
        _flash_insufficient_dp(idx)
        return
    dp -= u.cost
    dp_label.text = "DP %d / %d" % [int(dp), int(dp_max)]
    _spawn_unit(u, cell)
    feedback_label.text = "DEPLOYED %s" % u.label
    feedback_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
    feedback_timer = 0.8
    await get_tree().create_timer(0.8).timeout
    if is_instance_valid(feedback_label):
        feedback_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))

func _end_drag() -> void:
    if drag_ghost != null and is_instance_valid(drag_ghost):
        drag_ghost.queue_free()
    drag_ghost = null
    if dragging_idx >= 0 and dragging_idx < hand_buttons.size():
        hand_buttons[dragging_idx].border.color = COLOR_ACCENT
    dragging_idx = -1

# ---- spawn / combat ----------------------------------------------------

func _spawn_unit(def: Dictionary, cell: Vector2i) -> void:
    var sprite := ColorRect.new()
    sprite.color = def.color
    sprite.position = ORIGIN + Vector2(cell.x * CELL + 8, cell.y * CELL + 8)
    sprite.size = Vector2(CELL - 16, CELL - 16)
    unit_root.add_child(sprite)
    # Inner highlight ring (so it reads as a sprite, not a flat rect).
    var inner := ColorRect.new()
    inner.color = def.color * Color(1.4, 1.4, 1.4)
    inner.position = sprite.position + Vector2(8, 8)
    inner.size = Vector2(sprite.size.x - 16, sprite.size.y - 16)
    inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    unit_root.add_child(inner)
    var label := Label.new()
    label.text = def.label
    label.position = sprite.position + Vector2(0, sprite.size.y - 18)
    label.size = Vector2(sprite.size.x, 18)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", Color(0, 0, 0))
    label.add_theme_font_size_override("font_size", 14)
    unit_root.add_child(label)
    var hp_label := Label.new()
    hp_label.position = sprite.position + Vector2(-2, -16)
    hp_label.size = Vector2(CELL, 16)
    hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
    hp_label.add_theme_font_size_override("font_size", 14)
    hp_label.text = "HP %d/%d" % [def.hp, def.hp]
    unit_root.add_child(hp_label)
    units.append({
        "sprite": sprite, "inner": inner, "label": label, "hp_label": hp_label,
        "cell": cell, "def": def, "hp": def.hp, "hp_max": def.hp,
        "last_atk": 0.0,
    })
    # Placement spark.
    _spark(_cell_center(cell), Color(0.55, 0.85, 0.55))

func _spawn_enemy(type_id: String) -> void:
    var def: Dictionary = ENEMIES[type_id]
    var sprite := ColorRect.new()
    sprite.color = def.color
    sprite.size = def.size
    sprite.position = path_world[0] - def.size * 0.5
    enemy_root.add_child(sprite)
    var inner := ColorRect.new()
    inner.color = def.color * Color(0.6, 0.6, 0.6)
    inner.size = Vector2(def.size.x - 12, def.size.y - 12)
    sprite.add_child(inner)
    inner.position = Vector2(6, 6)
    var hp_label := Label.new()
    hp_label.position = sprite.position + Vector2(-22, -def.size.y * 0.5 - 18)
    hp_label.size = Vector2(80, 16)
    hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
    hp_label.add_theme_font_size_override("font_size", 13)
    hp_label.text = "HP %d/%d" % [def.hp, def.hp]
    enemy_root.add_child(hp_label)
    enemies.append({
        "sprite": sprite, "hp_label": hp_label,
        "type": type_id, "size": def.size,
        "hp": def.hp, "hp_max": def.hp,
        "speed": def.speed, "dist": 0.0, "last_atk": 0.0,
    })

func _refresh_unit_hp(u: Dictionary) -> void:
    if is_instance_valid(u.hp_label):
        u.hp_label.text = "HP %d/%d" % [max(u.hp, 0), u.hp_max]

func _refresh_enemy_hp(e: Dictionary) -> void:
    if is_instance_valid(e.hp_label):
        e.hp_label.text = "HP %d/%d" % [max(e.hp, 0), e.hp_max]

func _kill_unit(u: Dictionary) -> void:
    units.erase(u)
    if is_instance_valid(u.sprite):
        var p = u.sprite.position + u.sprite.size * 0.5
        _spark(p, Color(0.85, 0.30, 0.30))
        u.sprite.queue_free()
    if is_instance_valid(u.hp_label): u.hp_label.queue_free()
    if u.has("inner") and is_instance_valid(u.inner): u.inner.queue_free()
    if u.has("label") and is_instance_valid(u.label): u.label.queue_free()

func _kill_enemy(e: Dictionary) -> void:
    enemies.erase(e)
    if is_instance_valid(e.sprite):
        var p = e.sprite.position + e.size * 0.5
        _spark(p, Color(0.95, 0.85, 0.40))
        e.sprite.queue_free()
    if is_instance_valid(e.hp_label): e.hp_label.queue_free()

func _unit_at_cell(c: Vector2i):
    for u in units:
        if u.cell == c:
            return u
    return null

func _find_blocker_for(e: Dictionary):
    # Adjacent unit to the enemy's current pixel position.
    if not is_instance_valid(e.sprite):
        return null
    var ec := _pixel_to_cell(e.sprite.position + e.size * 0.5)
    for u in units:
        if u.hp <= 0:
            continue
        if absi(u.cell.x - ec.x) + absi(u.cell.y - ec.y) <= 1:
            return u
    return null

func _find_target_for(u: Dictionary):
    var p := _cell_center(u.cell)
    var range_px: float = u.def.range * float(CELL)
    var best = null
    var best_d := 1e9
    for e in enemies:
        if e.hp <= 0:
            continue
        var d: float = (e.sprite.position + e.size * 0.5).distance_to(p)
        if d <= range_px and d < best_d:
            best_d = d
            best = e
    return best

func _projectile(from: Vector2, to: Vector2, color: Color) -> void:
    var dot := ColorRect.new()
    dot.color = color * Color(1.5, 1.5, 1.5)
    dot.size = Vector2(8, 8)
    dot.position = from - Vector2(4, 4)
    fx_root.add_child(dot)
    var t := 0.0
    var dur := 0.18
    while t < dur:
        await get_tree().process_frame
        t += get_process_delta_time()
        if not is_instance_valid(dot):
            return
        dot.position = from.lerp(to, clampf(t / dur, 0, 1)) - Vector2(4, 4)
    if is_instance_valid(dot):
        dot.queue_free()

func _spark(at: Vector2, color: Color) -> void:
    for j in range(6):
        var s := ColorRect.new()
        s.color = color
        s.size = Vector2(6, 6)
        s.position = at - Vector2(3, 3)
        fx_root.add_child(s)
        var angle := randf() * TAU
        var dist := 16.0 + randf() * 12.0
        var target := at + Vector2(cos(angle), sin(angle)) * dist
        _animate_spark(s, target)

func _animate_spark(node: ColorRect, target: Vector2) -> void:
    var t := 0.0
    var dur := 0.25
    var start: Vector2 = node.position
    while t < dur:
        await get_tree().process_frame
        t += get_process_delta_time()
        if not is_instance_valid(node):
            return
        var k = clampf(t / dur, 0, 1)
        node.position = start.lerp(target, k) - Vector2(3, 3)
        node.modulate.a = 1.0 - k
    if is_instance_valid(node):
        node.queue_free()

# ---- waves -------------------------------------------------------------

func _start_next_wave() -> void:
    var data: Dictionary = STAGE_DATA[stage_id]
    if wave_idx >= data.waves.size():
        _end_battle(true)
        return
    wave_label.text = "WAVE %d / %d" % [wave_idx + 1, data.waves.size()]
    wave_active = true
    spawning = true
    var groups: Array = data.waves[wave_idx]
    for g in groups:
        for k in range(g.n):
            if stage_done:
                spawning = false
                return
            _spawn_enemy(g.type)
            await get_tree().create_timer(g.interval).timeout
    spawning = false

func _end_battle(won: bool) -> void:
    if stage_done:
        return
    stage_done = true
    await get_tree().create_timer(0.4).timeout
    if is_instance_valid(self) and main != null:
        main._enter_result(stage_id, won)




