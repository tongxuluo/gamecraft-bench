extends Node2D

const SAVE_PATH := "user://save.json"

var current_screen: Node = null
var save_state: Dictionary = {"cleared": []}
var _scenario: String = ""

func _ready() -> void:
    _parse_args()
    _load_save()
    if _scenario.begins_with("battle_"):
        var stage_id := _scenario.substr(len("battle_"))
        _enter_battle(stage_id)
    elif _scenario == "stage_select":
        _enter_stage_select()
    elif _scenario == "stage_select_cleared1":
        if not save_state.cleared.has("stage1"):
            save_state.cleared.append("stage1")
            _write_save()
        _enter_stage_select()
    else:
        _enter_title()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            _scenario = args[i + 1]
            i += 2
            continue
        i += 1

func _swap(new_node: Node) -> void:
    if current_screen != null and is_instance_valid(current_screen):
        current_screen.queue_free()
    current_screen = new_node
    add_child(new_node)

func _enter_title() -> void:
    var t = preload("res://scripts/Title.gd").new()
    t.main = self
    t.has_save = save_state.cleared.size() > 0
    _swap(t)

func _enter_stage_select() -> void:
    var s = preload("res://scripts/StageSelect.gd").new()
    s.main = self
    s.cleared = save_state.cleared.duplicate()
    _swap(s)

func _enter_battle(stage_id: String) -> void:
    var b = preload("res://scripts/Battle.gd").new()
    b.main = self
    b.stage_id = stage_id
    _swap(b)

func _enter_result(stage_id: String, won: bool) -> void:
    if won and not save_state.cleared.has(stage_id):
        save_state.cleared.append(stage_id)
        _write_save()
    var r = preload("res://scripts/Result.gd").new()
    r.main = self
    r.stage_id = stage_id
    r.won = won
    _swap(r)

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var raw := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) == TYPE_DICTIONARY and parsed.has("cleared"):
        save_state = parsed

func _write_save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(save_state))
    f.close()
