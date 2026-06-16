extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state shared across screens.
var unlocked_rooms: Array = ["parlor"]
var current_room: String = "parlor"
var sanity: float = 100.0
var truth_found: bool = false

func _ready() -> void:
    _parse_args()
    if _scenario == "parlor":
        current_room = "parlor"
        _enter_play()
    elif _scenario == "kitchen":
        unlocked_rooms = ["parlor", "kitchen"]
        current_room = "kitchen"
        _enter_play()
    elif _scenario == "attic":
        unlocked_rooms = ["parlor", "kitchen", "attic"]
        current_room = "attic"
        _enter_play()
    elif _scenario == "ending":
        unlocked_rooms = ["parlor", "kitchen", "attic"]
        current_room = "attic"
        truth_found = true
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

func _enter_play() -> void:
    var p = preload("res://scripts/Play.gd").new()
    p.main = self
    _swap(p)

func _enter_ending() -> void:
    var e = preload("res://scripts/Ending.gd").new()
    e.main = self
    _swap(e)

func unlock_room(room_id: String) -> void:
    if not unlocked_rooms.has(room_id):
        unlocked_rooms.append(room_id)

func go_to_room(room_id: String) -> void:
    if not unlocked_rooms.has(room_id):
        return
    current_room = room_id
    _enter_play()

func reach_truth() -> void:
    truth_found = true
    _enter_ending()
