extends Node2D

var current_screen: Node = null
var _scenario: String = ""

var battery: float = 100.0
var signals_found: int = 0
var pins_placed: int = 0
var triangulated: int = 0
var jamming_intensity: float = 0.2

const TOTAL_SIGNALS = 5

func _ready() -> void:
    _parse_args()
    if _scenario == "station":
        _enter_station()
    elif _scenario == "low_battery":
        battery = 15.0
        _enter_station()
    elif _scenario == "ending":
        triangulated = 3
        signals_found = 5
        _enter_ending()
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
        current_screen.queue_free()
    current_screen = new_node
    add_child(new_node)

func _enter_title() -> void:
    var t = preload("res://scripts/Title.gd").new()
    t.main = self
    _swap(t)

func _enter_station() -> void:
    var s = preload("res://scripts/Station.gd").new()
    s.main = self
    _swap(s)

func _enter_ending() -> void:
    var e = preload("res://scripts/Ending.gd").new()
    e.main = self
    _swap(e)
