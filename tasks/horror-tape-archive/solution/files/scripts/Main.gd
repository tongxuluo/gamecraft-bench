extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Persistent run state (kept in-memory only; resets on launch).
var night_idx: int = 0
var tape_idx: int = 0
var sanity: float = 100.0
var found_total: int = 0

const NIGHT_COUNT := 3
const TAPES_PER_NIGHT := 3

func _ready() -> void:
    _parse_args()
    randomize()
    if _scenario == "tape_select":
        _enter_tape_select()
    elif _scenario.begins_with("tape_play"):
        var parts := _scenario.split("_")
        # Format: tape_play_nNtT  -> e.g. tape_play_n1t1
        if parts.size() >= 3:
            var nt := parts[parts.size() - 1]
            var n_idx := int(nt.substr(1, 1)) - 1
            var t_idx := int(nt.substr(3, 1)) - 1
            night_idx = clampi(n_idx, 0, NIGHT_COUNT - 1)
            tape_idx = clampi(t_idx, 0, TAPES_PER_NIGHT - 1)
        _enter_tape_player(false)
    elif _scenario == "mark_anomaly":
        # Pre-seek the player near the first anomaly so demo can mark it.
        night_idx = 0
        tape_idx = 0
        _enter_tape_player(true)
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
    _swap(t)

func _enter_tape_select() -> void:
    var s = preload("res://scripts/TapeSelect.gd").new()
    s.main = self
    s.night_idx = night_idx
    s.sanity = sanity
    s.found_total = found_total
    _swap(s)

func _enter_tape_player(seek_to_anomaly: bool) -> void:
    var p = preload("res://scripts/TapePlayer.gd").new()
    p.main = self
    p.night_idx = night_idx
    p.tape_idx = tape_idx
    p.start_sanity = sanity
    p.seek_to_anomaly = seek_to_anomaly
    _swap(p)

func _on_tape_finished(found: int, anomalies_total: int, sanity_after: float) -> void:
    sanity = sanity_after
    found_total += found
    var r = preload("res://scripts/NightResult.gd").new()
    r.main = self
    r.night_idx = night_idx
    r.tape_idx = tape_idx
    r.found = found
    r.total = anomalies_total
    r.sanity = sanity
    _swap(r)

func _next_tape() -> void:
    tape_idx += 1
    if tape_idx >= TAPES_PER_NIGHT:
        tape_idx = 0
        night_idx += 1
        if night_idx >= NIGHT_COUNT:
            night_idx = 0
    _enter_tape_select()
