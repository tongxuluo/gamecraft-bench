extends Node2D

const SAVE_PATH = "user://save.json"

var current_screen: Node = null
var save_state: Dictionary = {"highest_night": 0}
var _scenario: String = ""

func _ready() -> void:
    _parse_args()
    _load_save()
    if _scenario == "night1":
        _enter_game(1)
    elif _scenario == "night2":
        _enter_game(2)
    elif _scenario == "night3":
        _enter_game(3)
    elif _scenario == "fuel_low":
        _enter_game(2, {"fuel": 18.0})
    elif _scenario == "result_win":
        _enter_result(3, true, 6, 0)
    elif _scenario == "result_lose":
        _enter_result(2, false, 1, 4)
    else:
        _enter_title()

func _parse_args() -> void:
    var args = OS.get_cmdline_user_args()
    var i = 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            _scenario = args[i + 1]
            i += 2
            continue
        i += 1

func _swap(new_node: Node) -> void:
    if current_screen != null and is_instance_valid(current_screen):
        # Brief fade transition (cover with a black ColorRect that fades out
        # in the new scene's _ready).
        current_screen.queue_free()
    current_screen = new_node
    add_child(new_node)

func _enter_title() -> void:
    var t = preload("res://scripts/Title.gd").new()
    t.main = self
    _swap(t)

func _enter_game(night: int, overrides: Dictionary = {}) -> void:
    var g = preload("res://scripts/Game.gd").new()
    g.main = self
    g.night = night
    g.overrides = overrides
    _swap(g)

func _enter_result(night: int, won: bool, saved: int, lost: int) -> void:
    if won and night > save_state.highest_night:
        save_state.highest_night = night
        _write_save()
    var r = preload("res://scripts/Result.gd").new()
    r.main = self
    r.night = night
    r.won = won
    r.saved = saved
    r.lost = lost
    _swap(r)

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var raw = f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) == TYPE_DICTIONARY and parsed.has("highest_night"):
        save_state = parsed

func _write_save() -> void:
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(save_state))
    f.close()
