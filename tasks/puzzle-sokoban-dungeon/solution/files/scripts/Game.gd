extends Node2D

var main: Node = null
var floor_num: int = 1
var force_death: bool = false

# Grid constants
const CELL_SIZE := 48
const GRID_OFFSET := Vector2(160, 60)
const GRID_W := 20
const GRID_H := 13

# Tile types
enum Tile { FLOOR, WALL, PLATE, DOOR_RED, DOOR_BLUE, EXIT, HAZARD, CHEST }

# Entity types
enum EntType { PLAYER, CRATE_STD, CRATE_ICE, CRATE_HEAVY, ENEMY_CHASER, ENEMY_PATROL, ENEMY_MIMIC, KEY_RED, KEY_BLUE, ITEM_FREEZE, ITEM_PULL, ITEM_TELEPORT }

# Colors
const C_WALL := Color(0.25, 0.22, 0.18)
const C_FLOOR := Color(0.35, 0.32, 0.28)
const C_PLATE := Color(0.9, 0.75, 0.2)
const C_DOOR_RED := Color(0.8, 0.2, 0.2)
const C_DOOR_BLUE := Color(0.2, 0.4, 0.9)
const C_EXIT := Color(0.3, 0.9, 0.4)
const C_HAZARD := Color(0.6, 0.1, 0.6)
const C_CHEST := Color(0.7, 0.55, 0.1)
const C_PLAYER := Color(0.2, 0.7, 0.9)
const C_CRATE := Color(0.6, 0.45, 0.2)
const C_CRATE_ICE := Color(0.6, 0.85, 0.95)
const C_CRATE_HEAVY := Color(0.4, 0.35, 0.3)
const C_ENEMY_CHASER := Color(0.9, 0.2, 0.2)
const C_ENEMY_PATROL := Color(0.9, 0.5, 0.1)
const C_ENEMY_MIMIC := Color(0.7, 0.2, 0.8)
const C_KEY_RED := Color(1.0, 0.3, 0.3)
const C_KEY_BLUE := Color(0.3, 0.5, 1.0)
const C_ITEM := Color(0.2, 0.9, 0.6)

# State
var grid: Array = []  # 2D array of Tile
var entities: Array = []  # Array of dicts {type, pos, ...}
var player_pos: Vector2i = Vector2i(1, 1)
var player_hp: int = 3
var turn_count: int = 0
var inventory: Array = []  # items
var keys_held: Array = []  # "red", "blue"
var history: Array = []  # for undo
var game_over: bool = false
var level_won: bool = false
var frozen_turns: int = 0
var heavy_push_state: Dictionary = {}  # pos -> push_count

# Visuals
var tile_nodes: Array = []
var entity_nodes: Array = []
var hud_label: Label = null
var inv_label: Label = null
var msg_label: Label = null

# Patrol paths for patrol enemies
var patrol_paths: Dictionary = {}  # entity_index -> {path: Array, idx: int, dir: int}

func _ready() -> void:
	seed(floor_num * 12345)
	_generate_level()
	_draw_grid()
	_draw_entities()
	_create_hud()
	if force_death:
		# Simulate immediate death for demo
		call_deferred("_trigger_death")

func _trigger_death() -> void:
	game_over = true
	_show_message("YOU DIED")
	await get_tree().create_timer(0.5).timeout
	main._enter_death_screen(floor_num, turn_count)

func _create_hud() -> void:
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0, 0, 0, 0.8)
	hud_bg.position = Vector2(0, 0)
	hud_bg.size = Vector2(1280, 50)
	add_child(hud_bg)

	hud_label = Label.new()
	hud_label.position = Vector2(10, 8)
	hud_label.size = Vector2(600, 34)
	hud_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	hud_label.add_theme_font_size_override("font_size", 20)
	add_child(hud_label)

	inv_label = Label.new()
	inv_label.position = Vector2(700, 8)
	inv_label.size = Vector2(570, 34)
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inv_label.add_theme_color_override("font_color", C_ITEM)
	inv_label.add_theme_font_size_override("font_size", 18)
	add_child(inv_label)

	msg_label = Label.new()
	msg_label.position = Vector2(0, 340)
	msg_label.size = Vector2(1280, 60)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	msg_label.add_theme_font_size_override("font_size", 36)
	msg_label.text = ""
	add_child(msg_label)

	_update_hud()

func _update_hud() -> void:
	if hud_label:
		hud_label.text = "Floor: %d | HP: %d | Turns: %d | Keys: %s" % [floor_num, player_hp, turn_count, ",".join(keys_held) if keys_held.size() > 0 else "none"]
	if inv_label:
		var items_str = ""
		for i in range(inventory.size()):
			items_str += "[%d] %s  " % [i + 1, inventory[i]]
		inv_label.text = items_str if items_str != "" else "No items"

func _show_message(text: String) -> void:
	if msg_label:
		msg_label.text = text

func _generate_level() -> void:
	# Initialize grid with walls on borders
	grid = []
	for y in range(GRID_H):
		var row = []
		for x in range(GRID_W):
			if x == 0 or x == GRID_W - 1 or y == 0 or y == GRID_H - 1:
				row.append(Tile.WALL)
			else:
				row.append(Tile.FLOOR)
		grid.append(row)

	# Add internal walls based on floor
	var wall_count = 8 + floor_num * 3
	for i in range(wall_count):
		var wx = randi_range(2, GRID_W - 3)
		var wy = randi_range(2, GRID_H - 3)
		if Vector2i(wx, wy) != Vector2i(1, 1):
			grid[wy][wx] = Tile.WALL

	# Place player
	player_pos = Vector2i(1, 1)
	grid[1][1] = Tile.FLOOR

	# Place exit
	var exit_pos = Vector2i(GRID_W - 2, GRID_H - 2)
	grid[exit_pos.y][exit_pos.x] = Tile.EXIT

	# Place pressure plates and crates
	var num_plates = 1 + floor_num
	if num_plates > 4:
		num_plates = 4
	for i in range(num_plates):
		var pp = _find_empty_floor()
		grid[pp.y][pp.x] = Tile.PLATE
		# Place a crate near the plate
		var cp = _find_empty_floor()
		var crate_type = EntType.CRATE_STD
		if floor_num >= 2 and i == 0:
			crate_type = EntType.CRATE_ICE
		elif floor_num >= 3 and i == 1:
			crate_type = EntType.CRATE_HEAVY
		entities.append({"type": crate_type, "pos": cp})

	# Place doors
	if floor_num >= 2:
		var dp = _find_empty_floor()
		grid[dp.y][dp.x] = Tile.DOOR_RED
		# Place matching key
		var kp = _find_empty_floor()
		entities.append({"type": EntType.KEY_RED, "pos": kp})
	if floor_num >= 3:
		var dp2 = _find_empty_floor()
		grid[dp2.y][dp2.x] = Tile.DOOR_BLUE
		var kp2 = _find_empty_floor()
		entities.append({"type": EntType.KEY_BLUE, "pos": kp2})

	# Place enemies
	var num_enemies = floor_num
	if num_enemies > 5:
		num_enemies = 5
	for i in range(num_enemies):
		var ep = _find_empty_floor_far()
		var etype: int
		if i % 3 == 0:
			etype = EntType.ENEMY_CHASER
		elif i % 3 == 1:
			etype = EntType.ENEMY_PATROL
		else:
			etype = EntType.ENEMY_MIMIC
		entities.append({"type": etype, "pos": ep})
		if etype == EntType.ENEMY_PATROL:
			var idx = entities.size() - 1
			var path = [ep, ep + Vector2i(2, 0), ep + Vector2i(2, 2), ep + Vector2i(0, 2)]
			patrol_paths[idx] = {"path": path, "idx": 0, "dir": 1}

	# Place items in chests
	if floor_num >= 1:
		var chest_pos = _find_empty_floor()
		grid[chest_pos.y][chest_pos.x] = Tile.CHEST
	if floor_num >= 2:
		var chest_pos2 = _find_empty_floor()
		grid[chest_pos2.y][chest_pos2.x] = Tile.CHEST

	# Place hazard tiles
	if floor_num >= 2:
		for i in range(2):
			var hp = _find_empty_floor()
			grid[hp.y][hp.x] = Tile.HAZARD

func _find_empty_floor() -> Vector2i:
	for _attempt in range(100):
		var x = randi_range(2, GRID_W - 3)
		var y = randi_range(2, GRID_H - 3)
		if grid[y][x] == Tile.FLOOR and Vector2i(x, y) != player_pos:
			if not _has_entity_at(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(3, 3)

func _find_empty_floor_far() -> Vector2i:
	for _attempt in range(100):
		var x = randi_range(GRID_W / 2, GRID_W - 3)
		var y = randi_range(GRID_H / 2, GRID_H - 3)
		if grid[y][x] == Tile.FLOOR and Vector2i(x, y) != player_pos:
			if not _has_entity_at(Vector2i(x, y)):
				return Vector2i(x, y)
	return _find_empty_floor()

func _has_entity_at(pos: Vector2i) -> bool:
	for e in entities:
		if e.pos == pos:
			return true
	return false

func _get_entity_at(pos: Vector2i) -> int:
	for i in range(entities.size()):
		if entities[i].pos == pos:
			return i
	return -1

func _is_crate(etype: int) -> bool:
	return etype == EntType.CRATE_STD or etype == EntType.CRATE_ICE or etype == EntType.CRATE_HEAVY

func _is_enemy(etype: int) -> bool:
	return etype == EntType.ENEMY_CHASER or etype == EntType.ENEMY_PATROL or etype == EntType.ENEMY_MIMIC

func _is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= GRID_W or pos.y < 0 or pos.y >= GRID_H:
		return false
	var t = grid[pos.y][pos.x]
	if t == Tile.WALL:
		return false
	if t == Tile.DOOR_RED and not keys_held.has("red"):
		return false
	if t == Tile.DOOR_BLUE and not keys_held.has("blue"):
		return false
	return true

func _is_pushable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= GRID_W or pos.y < 0 or pos.y >= GRID_H:
		return false
	var t = grid[pos.y][pos.x]
	return t != Tile.WALL and t != Tile.DOOR_RED and t != Tile.DOOR_BLUE

func _draw_grid() -> void:
	# Clear old
	for n in tile_nodes:
		if is_instance_valid(n):
			n.queue_free()
	tile_nodes.clear()

	for y in range(GRID_H):
		for x in range(GRID_W):
			var rect = ColorRect.new()
			rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			rect.position = GRID_OFFSET + Vector2(x * CELL_SIZE + 1, y * CELL_SIZE + 1)
			match grid[y][x]:
				Tile.WALL:
					rect.color = C_WALL
				Tile.FLOOR:
					rect.color = C_FLOOR
				Tile.PLATE:
					rect.color = C_PLATE
				Tile.DOOR_RED:
					rect.color = C_DOOR_RED
				Tile.DOOR_BLUE:
					rect.color = C_DOOR_BLUE
				Tile.EXIT:
					rect.color = C_EXIT
				Tile.HAZARD:
					rect.color = C_HAZARD
				Tile.CHEST:
					rect.color = C_CHEST
			add_child(rect)
			tile_nodes.append(rect)

			# Add label for special tiles
			if grid[y][x] == Tile.EXIT:
				var lbl = Label.new()
				lbl.text = "EXIT"
				lbl.position = rect.position + Vector2(4, 12)
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.add_theme_color_override("font_color", Color(0, 0, 0))
				add_child(lbl)
				tile_nodes.append(lbl)
			elif grid[y][x] == Tile.PLATE:
				var lbl = Label.new()
				lbl.text = "O"
				lbl.position = rect.position + Vector2(16, 10)
				lbl.add_theme_font_size_override("font_size", 18)
				lbl.add_theme_color_override("font_color", Color(0.3, 0.2, 0))
				add_child(lbl)
				tile_nodes.append(lbl)
			elif grid[y][x] == Tile.CHEST:
				var lbl = Label.new()
				lbl.text = "?"
				lbl.position = rect.position + Vector2(16, 10)
				lbl.add_theme_font_size_override("font_size", 18)
				lbl.add_theme_color_override("font_color", Color(0, 0, 0))
				add_child(lbl)
				tile_nodes.append(lbl)

func _draw_entities() -> void:
	for n in entity_nodes:
		if is_instance_valid(n):
			n.queue_free()
	entity_nodes.clear()

	# Draw player
	var p_rect = ColorRect.new()
	p_rect.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 6)
	p_rect.position = GRID_OFFSET + Vector2(player_pos.x * CELL_SIZE + 3, player_pos.y * CELL_SIZE + 3)
	p_rect.color = C_PLAYER
	add_child(p_rect)
	entity_nodes.append(p_rect)
	var p_lbl = Label.new()
	p_lbl.text = "@"
	p_lbl.position = p_rect.position + Vector2(14, 8)
	p_lbl.add_theme_font_size_override("font_size", 22)
	p_lbl.add_theme_color_override("font_color", Color(0, 0, 0))
	add_child(p_lbl)
	entity_nodes.append(p_lbl)

	# Draw entities
	for e in entities:
		var r = ColorRect.new()
		r.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 6)
		r.position = GRID_OFFSET + Vector2(e.pos.x * CELL_SIZE + 3, e.pos.y * CELL_SIZE + 3)
		var lbl_text = ""
		match e.type:
			EntType.CRATE_STD:
				r.color = C_CRATE
				lbl_text = "#"
			EntType.CRATE_ICE:
				r.color = C_CRATE_ICE
				lbl_text = "~"
			EntType.CRATE_HEAVY:
				r.color = C_CRATE_HEAVY
				lbl_text = "H"
			EntType.ENEMY_CHASER:
				r.color = C_ENEMY_CHASER
				lbl_text = "C"
			EntType.ENEMY_PATROL:
				r.color = C_ENEMY_PATROL
				lbl_text = "P"
			EntType.ENEMY_MIMIC:
				r.color = C_ENEMY_MIMIC
				lbl_text = "M"
			EntType.KEY_RED:
				r.color = C_KEY_RED
				lbl_text = "K"
			EntType.KEY_BLUE:
				r.color = C_KEY_BLUE
				lbl_text = "K"
			EntType.ITEM_FREEZE:
				r.color = C_ITEM
				lbl_text = "F"
			EntType.ITEM_PULL:
				r.color = C_ITEM
				lbl_text = ">"
			EntType.ITEM_TELEPORT:
				r.color = C_ITEM
				lbl_text = "T"
		add_child(r)
		entity_nodes.append(r)
		if lbl_text != "":
			var el = Label.new()
			el.text = lbl_text
			el.position = r.position + Vector2(14, 8)
			el.add_theme_font_size_override("font_size", 20)
			el.add_theme_color_override("font_color", Color(0, 0, 0))
			add_child(el)
			entity_nodes.append(el)

func _input(event: InputEvent) -> void:
	if game_over or level_won:
		return

	var dir = Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		dir = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down"):
		dir = Vector2i(0, 1)
	elif event.is_action_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right"):
		dir = Vector2i(1, 0)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_undo()
			return
		elif event.keycode == KEY_1:
			_use_item(0)
			return
		elif event.keycode == KEY_2:
			_use_item(1)
			return
		elif event.keycode == KEY_3:
			_use_item(2)
			return

	if dir != Vector2i.ZERO:
		_do_turn(dir)

func _save_state() -> Dictionary:
	var ent_copy = []
	for e in entities:
		ent_copy.append(e.duplicate())
	return {
		"player_pos": player_pos,
		"player_hp": player_hp,
		"turn_count": turn_count,
		"entities": ent_copy,
		"inventory": inventory.duplicate(),
		"keys_held": keys_held.duplicate(),
		"frozen_turns": frozen_turns,
		"grid": grid.duplicate(true)
	}

func _undo() -> void:
	if history.size() == 0:
		return
	var state: Dictionary = history.pop_back()
	player_pos = state.player_pos
	player_hp = state.player_hp
	turn_count = state.turn_count
	entities = state.entities
	inventory = state.inventory
	keys_held = state.keys_held
	frozen_turns = state.frozen_turns
	grid = state.grid
	_draw_grid()
	_draw_entities()
	_update_hud()
	_show_message("")

func _use_item(idx: int) -> void:
	if idx >= inventory.size():
		return
	var item_name: String = inventory[idx]
	inventory.remove_at(idx)
	match item_name:
		"freeze":
			frozen_turns = 3
			_show_message("Enemies frozen for 3 turns!")
		"pull":
			_pull_nearest_crate()
		"teleport":
			var tp = _find_empty_floor()
			player_pos = tp
	_draw_entities()
	_update_hud()

func _pull_nearest_crate() -> void:
	var best_dist = 999
	var best_idx = -1
	for i in range(entities.size()):
		if _is_crate(entities[i].type):
			var d: int = abs(entities[i].pos.x - player_pos.x) + abs(entities[i].pos.y - player_pos.y)
			if d < best_dist and d > 1:
				best_dist = d
				best_idx = i
	if best_idx >= 0:
		# Move crate one step toward player
		var cpos: Vector2i = entities[best_idx].pos
		var diff = player_pos - cpos
		var step = Vector2i(signi(diff.x), signi(diff.y))
		if step.x != 0 and step.y != 0:
			step.y = 0  # prefer horizontal
		var new_pos = cpos + step
		if _is_pushable(new_pos) and _get_entity_at(new_pos) < 0:
			entities[best_idx].pos = new_pos

func _do_turn(dir: Vector2i) -> void:
	history.append(_save_state())
	if history.size() > 50:
		history.pop_front()

	var new_pos = player_pos + dir

	# Check if there's a crate to push
	var ent_idx = _get_entity_at(new_pos)
	if ent_idx >= 0 and _is_crate(entities[ent_idx].type):
		var crate_dest = new_pos + dir
		if not _is_pushable(crate_dest) or _get_entity_at(crate_dest) >= 0:
			return  # Can't push
		# Heavy crate needs two pushes
		if entities[ent_idx].type == EntType.CRATE_HEAVY:
			var key_str = "%d,%d" % [new_pos.x, new_pos.y]
			if heavy_push_state.has(key_str):
				heavy_push_state.erase(key_str)
			else:
				heavy_push_state[key_str] = 1
				# First push: count the turn but crate doesn't move
				turn_count += 1
				if frozen_turns > 0:
					frozen_turns -= 1
				else:
					_move_enemies(dir)
				_check_enemy_collision()
				_draw_entities()
				_update_hud()
				_show_message("Heavy crate... push again!")
				return
		# Move crate
		entities[ent_idx].pos = crate_dest
		# Ice crate slides until hitting wall
		if entities[ent_idx].type == EntType.CRATE_ICE:
			var slide_pos = crate_dest
			while true:
				var next_slide = slide_pos + dir
				if not _is_pushable(next_slide) or _get_entity_at(next_slide) >= 0:
					break
				slide_pos = next_slide
			entities[ent_idx].pos = slide_pos
	elif ent_idx >= 0 and _is_enemy(entities[ent_idx].type):
		# Walking into enemy = damage
		player_hp -= 1
		if player_hp <= 0:
			game_over = true
			main._enter_death_screen(floor_num, turn_count)
			return
	elif not _is_walkable(new_pos):
		return  # Can't move there

	# Move player
	if _is_walkable(new_pos):
		if ent_idx < 0 or _is_crate(entities[ent_idx].type):
			player_pos = new_pos

	# Pick up items/keys
	_check_pickups()

	# Check if on exit
	if grid[player_pos.y][player_pos.x] == Tile.EXIT:
		_check_win()
		if level_won:
			return

	# Check hazard
	if grid[player_pos.y][player_pos.x] == Tile.HAZARD:
		player_hp -= 1
		_show_message("Hazard! -1 HP")
		if player_hp <= 0:
			game_over = true
			main._enter_death_screen(floor_num, turn_count)
			return

	# Check chest
	if grid[player_pos.y][player_pos.x] == Tile.CHEST:
		grid[player_pos.y][player_pos.x] = Tile.FLOOR
		var items_pool = ["freeze", "pull", "teleport"]
		var item_name: String = items_pool[randi() % items_pool.size()]
		if inventory.size() < 3:
			inventory.append(item_name)
			_show_message("Found: " + item_name + "!")
		_draw_grid()

	turn_count += 1

	# Move enemies
	if frozen_turns > 0:
		frozen_turns -= 1
	else:
		_move_enemies(dir)

	_check_enemy_collision()

	# Open doors if plates are satisfied
	_check_plates()

	_draw_entities()
	_update_hud()

func _check_pickups() -> void:
	var to_remove = []
	for i in range(entities.size()):
		if entities[i].pos == player_pos:
			match entities[i].type:
				EntType.KEY_RED:
					keys_held.append("red")
					to_remove.append(i)
				EntType.KEY_BLUE:
					keys_held.append("blue")
					to_remove.append(i)
				EntType.ITEM_FREEZE:
					if inventory.size() < 3:
						inventory.append("freeze")
					to_remove.append(i)
				EntType.ITEM_PULL:
					if inventory.size() < 3:
						inventory.append("pull")
					to_remove.append(i)
				EntType.ITEM_TELEPORT:
					if inventory.size() < 3:
						inventory.append("teleport")
					to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		entities.remove_at(idx)

func _check_plates() -> void:
	# Check if all plates have crates on them
	var all_plates_filled = true
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid[y][x] == Tile.PLATE:
				var has_crate = false
				for e in entities:
					if e.pos == Vector2i(x, y) and _is_crate(e.type):
						has_crate = true
						break
				if not has_crate:
					all_plates_filled = false

	# If all plates filled, open all doors
	if all_plates_filled:
		for y in range(GRID_H):
			for x in range(GRID_W):
				if grid[y][x] == Tile.DOOR_RED or grid[y][x] == Tile.DOOR_BLUE:
					grid[y][x] = Tile.FLOOR
		_draw_grid()

func _check_win() -> void:
	# Win condition: reach exit with all plates satisfied
	level_won = true
	main._enter_floor_transition(floor_num + 1)

func _check_enemy_collision() -> void:
	for e in entities:
		if _is_enemy(e.type) and e.pos == player_pos:
			player_hp -= 1
			if player_hp <= 0:
				game_over = true
				main._enter_death_screen(floor_num, turn_count)
				return
			else:
				_show_message("Hit! HP: " + str(player_hp))

func _move_enemies(player_dir: Vector2i) -> void:
	for i in range(entities.size()):
		if not _is_enemy(entities[i].type):
			continue
		var epos: Vector2i = entities[i].pos
		var new_epos = epos
		match entities[i].type:
			EntType.ENEMY_CHASER:
				# Move toward player
				var diff = player_pos - epos
				var step = Vector2i.ZERO
				if abs(diff.x) >= abs(diff.y):
					step = Vector2i(signi(diff.x), 0)
				else:
					step = Vector2i(0, signi(diff.y))
				new_epos = epos + step
			EntType.ENEMY_PATROL:
				# Follow patrol path
				if patrol_paths.has(i):
					var pd: Dictionary = patrol_paths[i]
					var path_arr: Array = pd.path
					var pidx: int = pd.idx
					var pdir: int = pd.dir
					pidx += pdir
					if pidx >= path_arr.size():
						pidx = path_arr.size() - 2
						pdir = -1
					elif pidx < 0:
						pidx = 1
						pdir = 1
					pd.idx = pidx
					pd.dir = pdir
					new_epos = path_arr[pidx]
					patrol_paths[i] = pd
				else:
					new_epos = epos
			EntType.ENEMY_MIMIC:
				# Copies player movement direction
				new_epos = epos + player_dir

		# Validate enemy move
		if new_epos.x >= 0 and new_epos.x < GRID_W and new_epos.y >= 0 and new_epos.y < GRID_H:
			if grid[new_epos.y][new_epos.x] != Tile.WALL and _get_entity_at(new_epos) < 0:
				entities[i].pos = new_epos
			elif new_epos == player_pos:
				entities[i].pos = new_epos  # Allow moving onto player (collision)

