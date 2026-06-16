extends Node2D

var current_screen: Node = null
var _scenario: String = ""

# Game state
var gold: int = 4
var round_num: int = 0
var jokers: Array = []
var deck: Array = []
var rng: RandomNumberGenerator = null

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 12345
	_parse_args()
	_init_deck()
	if _scenario == "hand_play":
		_enter_round()
	elif _scenario == "shop":
		round_num = 1
		gold = 8
		_enter_shop()
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

func _init_deck() -> void:
	deck.clear()
	var suits = ["Hearts", "Diamonds", "Clubs", "Spades"]
	for s in suits:
		for v in range(2, 15):
			deck.append({"suit": s, "value": v})

func _swap(new_node: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = new_node
	add_child(new_node)

func _enter_title() -> void:
	var t = preload("res://scripts/Title.gd").new()
	t.main = self
	_swap(t)

func _enter_round() -> void:
	round_num += 1
	var r = preload("res://scripts/Round.gd").new()
	r.main = self
	_swap(r)

func _enter_shop() -> void:
	var s = preload("res://scripts/Shop.gd").new()
	s.main = self
	_swap(s)

func _enter_win() -> void:
	var w = preload("res://scripts/WinLose.gd").new()
	w.main = self
	w.won = true
	_swap(w)

func _enter_lose() -> void:
	var w = preload("res://scripts/WinLose.gd").new()
	w.main = self
	w.won = false
	_swap(w)

func draw_cards(count: int) -> Array:
	var hand = []
	for i in range(count):
		if deck.size() == 0:
			_init_deck()
		var idx = rng.randi_range(0, deck.size() - 1)
		hand.append(deck[idx])
		deck.remove_at(idx)
	return hand
