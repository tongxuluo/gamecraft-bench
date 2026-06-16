extends Node2D

var main: Node = null
var fight_index: int = 0

var enemy_name: String = ""
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_damage: int = 0

var hand: Array = []
var selected_indices: Array = []
var current_word: String = ""

var hand_tiles: Array = []
var word_label: Label = null
var enemy_hp_label: Label = null
var player_hp_label: Label = null
var message_label: Label = null
var enemy_name_label: Label = null
var submit_btn: Button = null

var rare_letters = {"Q": 3, "Z": 3, "X": 2, "J": 2, "K": 1}

var valid_words: Array = [
	"the", "and", "for", "are", "not", "you", "all", "can", "her", "was",
	"one", "our", "out", "day", "had", "hot", "oil", "sit", "now", "old",
	"red", "run", "eat", "ten", "top", "sun", "his", "let", "say", "she",
	"too", "use", "cat", "dog", "hat", "rat", "bat", "mat", "sat", "tin",
	"tan", "ton", "den", "hen", "men", "pen", "net", "set", "get", "wet",
	"hit", "bit", "fit", "lit", "pit", "dot", "got", "lot", "pot", "cut",
	"but", "gut", "hut", "nut", "put", "rut", "dug", "bug", "hug", "mug",
	"rug", "tug", "dim", "him", "rim", "sir", "fir", "did", "hid", "kid",
	"lid", "rid", "big", "dig", "fig", "pig", "wig", "bin", "din", "fin",
	"gin", "kin", "pin", "sin", "win", "dip", "hip", "lip", "nip", "rip",
	"sip", "tip", "zip", "ash", "ore", "ire", "ice", "ace",
	"fire", "hire", "tire", "wire", "dire", "sire",
	"heal", "deal", "meal", "real", "seal", "teal", "veal", "zeal",
	"cold", "bold", "fold", "gold", "hold", "mold", "sold", "told",
	"hand", "band", "land", "sand", "send", "tend", "rend", "bend",
	"dent", "gent", "lent", "rent", "sent", "tent", "vent", "went",
	"hint", "lint", "mint", "tint", "hunt", "dust", "gust", "just",
	"must", "rust", "bust", "lust", "risk", "disk", "fist", "gist",
	"list", "mist", "cast", "fast", "last", "mast", "past", "vast",
	"best", "nest", "pest", "rest", "test", "vest", "west", "zest",
	"cost", "host", "lost", "most", "post", "spell", "shell", "smell",
	"stone", "store", "train", "trail", "brain", "drain", "grain",
	"light", "might", "night", "right", "sight", "tight", "fight",
	"at", "an", "am", "as", "be", "do", "go", "he", "if", "in",
	"is", "it", "me", "my", "no", "of", "on", "or", "so", "to", "up", "we"
]

func _ready() -> void:
	_setup_enemy()
	_draw_hand()
	_build_ui()

func _setup_enemy() -> void:
	match fight_index:
		0:
			enemy_name = "Slime"
			enemy_hp = 20
			enemy_max_hp = 20
			enemy_damage = 8
		1:
			enemy_name = "Skeleton"
			enemy_hp = 35
			enemy_max_hp = 35
			enemy_damage = 12
		2:
			enemy_name = "Dark Mage"
			enemy_hp = 50
			enemy_max_hp = 50
			enemy_damage = 15
		3:
			enemy_name = "Dragon (BOSS)"
			enemy_hp = 80
			enemy_max_hp = 80
			enemy_damage = 20

func _draw_hand() -> void:
	hand.clear()
	var pool = main.letter_pool.duplicate()
	pool.shuffle()
	for i in range(min(7, pool.size())):
		hand.append(pool[i])

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.12)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Enemy area
	var enemy_bg = ColorRect.new()
	enemy_bg.color = Color(0.15, 0.08, 0.08)
	enemy_bg.position = Vector2(340, 30)
	enemy_bg.size = Vector2(600, 160)
	add_child(enemy_bg)

	enemy_name_label = Label.new()
	enemy_name_label.text = enemy_name
	enemy_name_label.add_theme_font_size_override("font_size", 32)
	enemy_name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	enemy_name_label.position = Vector2(370, 45)
	add_child(enemy_name_label)

	enemy_hp_label = Label.new()
	enemy_hp_label.add_theme_font_size_override("font_size", 24)
	enemy_hp_label.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	enemy_hp_label.position = Vector2(370, 90)
	add_child(enemy_hp_label)
	_update_enemy_hp()

	var atk_lbl = Label.new()
	atk_lbl.text = "Attacks for: " + str(enemy_damage) + " dmg"
	atk_lbl.add_theme_font_size_override("font_size", 20)
	atk_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	atk_lbl.position = Vector2(370, 125)
	add_child(atk_lbl)

	var fight_lbl = Label.new()
	fight_lbl.text = "Fight " + str(fight_index + 1) + "/4"
	fight_lbl.add_theme_font_size_override("font_size", 20)
	fight_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	fight_lbl.position = Vector2(780, 45)
	add_child(fight_lbl)

	# Player HP
	player_hp_label = Label.new()
	player_hp_label.add_theme_font_size_override("font_size", 24)
	player_hp_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	player_hp_label.position = Vector2(50, 650)
	add_child(player_hp_label)
	_update_player_hp()

	# Word display area
	var word_bg = ColorRect.new()
	word_bg.color = Color(0.1, 0.1, 0.2)
	word_bg.position = Vector2(340, 300)
	word_bg.size = Vector2(600, 60)
	add_child(word_bg)

	word_label = Label.new()
	word_label.text = "_ _ _"
	word_label.add_theme_font_size_override("font_size", 36)
	word_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	word_label.position = Vector2(360, 310)
	add_child(word_label)

	# Message
	message_label = Label.new()
	message_label.text = "Click letters to form a word"
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	message_label.position = Vector2(340, 260)
	add_child(message_label)

	# Hand tiles
	_build_hand_tiles()

	# Submit button
	submit_btn = Button.new()
	submit_btn.text = "CAST SPELL"
	submit_btn.position = Vector2(540, 580)
	submit_btn.custom_minimum_size = Vector2(200, 50)
	submit_btn.add_theme_font_size_override("font_size", 22)
	submit_btn.pressed.connect(Callable(self, "_on_submit"))
	add_child(submit_btn)

	# Clear button
	var clear_btn = Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.position = Vector2(340, 580)
	clear_btn.custom_minimum_size = Vector2(150, 50)
	clear_btn.add_theme_font_size_override("font_size", 20)
	clear_btn.pressed.connect(Callable(self, "_on_clear"))
	add_child(clear_btn)

func _build_hand_tiles() -> void:
	for t in hand_tiles:
		if is_instance_valid(t):
			t.queue_free()
	hand_tiles.clear()
	var start_x = 280
	var y = 430
	for i in range(hand.size()):
		var tile = ColorRect.new()
		tile.size = Vector2(80, 90)
		tile.position = Vector2(start_x + i * 100, y)
		tile.color = Color(0.2, 0.15, 0.35)
		var lbl = Label.new()
		lbl.text = hand[i]
		lbl.add_theme_font_size_override("font_size", 40)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.position = Vector2(25, 18)
		tile.add_child(lbl)
		# Rarity indicator
		if hand[i] in rare_letters:
			var star = Label.new()
			star.text = "+" + str(rare_letters[hand[i]])
			star.add_theme_font_size_override("font_size", 14)
			star.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
			star.position = Vector2(55, 65)
			tile.add_child(star)
		add_child(tile)
		hand_tiles.append(tile)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		for i in range(hand_tiles.size()):
			if i in selected_indices:
				continue
			var tile = hand_tiles[i]
			var rect = Rect2(tile.position, tile.size)
			if rect.has_point(click_pos):
				_select_tile(i)
				break

func _select_tile(idx: int) -> void:
	selected_indices.append(idx)
	current_word += hand[idx]
	hand_tiles[idx].color = Color(0.4, 0.3, 0.7)
	word_label.text = current_word

func _on_clear() -> void:
	selected_indices.clear()
	current_word = ""
	word_label.text = "_ _ _"
	for i in range(hand_tiles.size()):
		hand_tiles[i].color = Color(0.2, 0.15, 0.35)

func _on_submit() -> void:
	if current_word.length() < 2:
		message_label.text = "Word too short! (min 2 letters)"
		return
	var word_lower = current_word.to_lower()
	if word_lower not in valid_words:
		message_label.text = "'" + current_word + "' is not valid! Turn wasted."
		_enemy_attacks()
		_on_clear()
		return
	# Calculate damage
	var base_damage = current_word.length() * 2
	var bonus = 0
	for ch in current_word:
		if ch in rare_letters:
			bonus += rare_letters[ch]
	var total_damage = base_damage + bonus
	enemy_hp -= total_damage
	if enemy_hp < 0:
		enemy_hp = 0
	_update_enemy_hp()
	message_label.text = "'" + current_word + "' deals " + str(total_damage) + " damage!"
	_on_clear()
	if enemy_hp <= 0:
		_enemy_defeated()
		return
	_enemy_attacks()

func _enemy_attacks() -> void:
	main.player_hp -= enemy_damage
	if main.player_hp < 0:
		main.player_hp = 0
	_update_player_hp()
	if main.player_hp <= 0:
		message_label.text = "You have been slain!"
		submit_btn.disabled = true
		await get_tree().create_timer(1.5).timeout
		main.on_player_died()

func _enemy_defeated() -> void:
	message_label.text = enemy_name + " defeated!"
	submit_btn.disabled = true
	await get_tree().create_timer(1.5).timeout
	main.advance_after_combat()

func _update_enemy_hp() -> void:
	enemy_hp_label.text = "HP: " + str(enemy_hp) + " / " + str(enemy_max_hp)

func _update_player_hp() -> void:
	player_hp_label.text = "Player HP: " + str(main.player_hp) + " / " + str(main.player_max_hp)
