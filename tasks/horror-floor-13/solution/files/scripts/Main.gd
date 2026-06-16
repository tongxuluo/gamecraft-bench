extends Node2D

var current_screen: Node = null
var _scenario: String = ""

var corruption: int = 0
var passengers_served: int = 0
var current_floor: int = 1
var visited_floors: Array = []

func _ready() -> void:
    _parse_args()
    if _scenario == "elevator":
        _enter_elevator()
    elif _scenario == "floor13":
        corruption = 5
        current_floor = 13
        _enter_ending()
    elif _scenario == "floor_visit":
        current_floor = 3
        _enter_floor_view()
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

func _enter_elevator() -> void:
    var e = preload("res://scripts/Elevator.gd").new()
    e.main = self
    _swap(e)

func _enter_floor_view() -> void:
    var f = preload("res://scripts/FloorView.gd").new()
    f.main = self
    f.floor_num = current_floor
    _swap(f)

func _enter_ending() -> void:
    var e = preload("res://scripts/Ending.gd").new()
    e.main = self
    e.corruption = corruption
    _swap(e)

func arrive_at_floor(floor_num: int) -> void:
    current_floor = floor_num
    if not visited_floors.has(floor_num):
        visited_floors.append(floor_num)
    if floor_num == 13:
        _enter_ending()
    else:
        _enter_floor_view()

func add_corruption(amount: int) -> void:
    corruption += amount
    if corruption >= 6:
        current_floor = 13
        _enter_ending()
