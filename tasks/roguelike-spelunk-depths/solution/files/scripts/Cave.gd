extends Node2D

var main: Node = null
var has_shop: bool = false

# Grid: 16 cols x 8 rows, cell 64px, side-view platformer
const COLS = 16
const ROWS = 8
const CELL = 64
const ORIGIN = Vector2(96, 80)

const COLOR_BG = Color(0.04, 0.03, 0.06)
const COLOR_ROCK = Color(0.3, 0.22, 0.15)
const COLOR_ROCK_ALT = Color(0.25, 0.18, 0.12)
const COLOR_AIR = Color(0.06, 0.05, 0.08)
const COLOR_GOLD = Color(0.95, 0.8, 0.2)
const COLOR_PLAYER = Color(0.2, 0.5, 0.9)
const COLOR_ENEMY = Color(0.8, 0.3, 0.3)
const COLOR_SHOP = Color(0.3, 0.7, 0.3)
const COLOR_EXIT = Color(0.4, 0.9, 0.6)
const COLOR_ROPE = Color(0.7, 0.6, 0.3)
const COLOR_GHOST = Color(0.9, 0.9, 1.0, 0.6)
const COLOR_PANEL = Color(0.12, 0.10, 0.08)
const COLOR_ACCENT = Color(0.85, 0.65, 0.25)
const COLOR_TEXT = Color(0.95, 0.9, 0.8)

var grid: Array = []  # 2D: "rock", "air", "gold", "exit", "shop_item"
var player_pos = Vector2i(2, 1)
var player_on_ground: bool = true
var player_vy: float = 0.0
var player_facing: int = 1  # 1=right, -1=left

var gold_cells: Array = []
var enemies: Array = []
var ropes_placed: Array = []
var shop_items: Array = []
var exit_cell = Vector2i(14, 7)

var ghost_active: bool = false
var ghost_pos = Vector2(0, 0)
var ghost_timer: float = 60.0
var floor_timer: float = 0.0

var player_sprite: ColorRect = null
var ghost_sprite: ColorRect = null
var timer_label: Label = null
var hp_label: Label = null
var gold_label: Label = null
var rope_label: Label = null
var bomb_label: Label = null
var floor_label: Label = null
var feedback_label: Label = null
var feedback_timer: float = 0.0

var hud_root: CanvasLayer = null
var grid_root: Node2D = null
var entity_root: Node2D = null
var floor_done: bool = false

func _ready() -> void:
	seed(hash(main.floor_num * 7777))
	_generate_cave()
	_build_visuals()
	_build_hud()
	_spawn_entities()
	set_process(true)
	set_process_input(true)

func _generate_cave() -> void:
	grid.clear()
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			if r == 0:
				# Top row mostly air
				if c == 0 or c == COLS - 1:
					row.append("rock")
				else:
					row.append("air")
			elif r == ROWS - 1:
				# Bottom row mostly rock with exit
				if c == exit_cell.x:
					row.append("exit")
				else:
					row.append("rock")
			else:
				# Middle: procedural
				if randf() < 0.35:
					row.append("rock")
				else:
					row.append("air")
		grid.append(row)
	# Ensure player start is air
	grid[1][2] = "air"
	grid[2][2] = "rock"  # ground under player
	# Ensure path to exit exists - carve a rough path
	var cur_r = 1
	var cur_c = 2
	while cur_r < ROWS - 1 or cur_c < exit_cell.x:
		if cur_c < exit_cell.x and randf() < 0.6:
			cur_c += 1
		elif cur_r < ROWS - 2:
			cur_r += 1
		if cur_r < ROWS and cur_c < COLS:
			grid[cur_r][cur_c] = "air"
	# Place gold
	gold_cells.clear()
	for i in range(5 + main.floor_num):
		var gc = Vector2i(2 + randi() % (COLS - 4), 1 + randi() % (ROWS - 2))
		if grid[gc.y][gc.x] == "air":
			gold_cells.append(gc)
	# Exit cell air above
	if exit_cell.y > 0:
		grid[exit_cell.y - 1][exit_cell.x] = "air"

func _build_visuals() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	grid_root = Node2D.new()
	grid_root.name = "Grid"
	add_child(grid_root)

	for r in range(ROWS):
		for c in range(COLS):
			var cell = ColorRect.new()
			match grid[r][c]:
				"rock":
					cell.color = COLOR_ROCK if (c + r) % 2 == 0 else COLOR_ROCK_ALT
				"air":
					cell.color = COLOR_AIR
				"exit":
					cell.color = COLOR_EXIT
				_:
					cell.color = COLOR_AIR
			cell.position = ORIGIN + Vector2(c * CELL, r * CELL)
			cell.size = Vector2(CELL - 1, CELL - 1)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_root.add_child(cell)

	# Gold sprites
	for gc in gold_cells:
		var g = ColorRect.new()
		g.color = COLOR_GOLD
		g.position = ORIGIN + Vector2(gc.x * CELL + 22, gc.y * CELL + 22)
		g.size = Vector2(20, 20)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_root.add_child(g)

	entity_root = Node2D.new()
	entity_root.name = "Entities"
	add_child(entity_root)

	# Player
	player_sprite = ColorRect.new()
	player_sprite.color = COLOR_PLAYER
	player_sprite.size = Vector2(CELL - 20, CELL - 10)
	player_sprite.position = _cell_pixel(player_pos) + Vector2(10, 5)
	entity_root.add_child(player_sprite)
	var plbl = Label.new()
	plbl.text = "P"
	plbl.position = player_sprite.position + Vector2(16, 14)
	plbl.add_theme_color_override("font_color", Color(1, 1, 1))
	plbl.add_theme_font_size_override("font_size", 22)
	entity_root.add_child(plbl)

	# Exit marker
	var exit_lbl = Label.new()
	exit_lbl.text = "EXIT"
	exit_lbl.position = ORIGIN + Vector2(exit_cell.x * CELL + 8, exit_cell.y * CELL + 20)
	exit_lbl.add_theme_color_override("font_color", Color(0.1, 0.3, 0.2))
	exit_lbl.add_theme_font_size_override("font_size", 18)
	grid_root.add_child(exit_lbl)

func _spawn_entities() -> void:
	# Enemies
	var enemy_count = 1 + main.floor_num
	for i in range(enemy_count):
		var ec = Vector2i(5 + randi() % (COLS - 7), 1 + randi() % (ROWS - 2))
		if grid[ec.y][ec.x] == "air" and ec != player_pos:
			var sprite = ColorRect.new()
			sprite.color = COLOR_ENEMY
			sprite.size = Vector2(CELL - 24, CELL - 16)
			sprite.position = _cell_pixel(ec) + Vector2(12, 8)
			entity_root.add_child(sprite)
			var lbl = Label.new()
			lbl.text = "E"
			lbl.position = sprite.position + Vector2(14, 10)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			lbl.add_theme_font_size_override("font_size", 18)
			entity_root.add_child(lbl)
			enemies.append({"cell": ec, "sprite": sprite, "label": lbl, "hp": 2})

	# Shop items
	if has_shop:
		var shop_x = 8 + randi() % 4
		var shop_y = 1
		for r in range(1, ROWS - 1):
			if grid[r][shop_x] == "air":
				shop_y = r
				break
		for i in range(3):
			var sx = shop_x + i
			if sx < COLS and grid[shop_y][sx] == "air":
				var sprite = ColorRect.new()
				sprite.color = COLOR_SHOP
				sprite.size = Vector2(30, 30)
				sprite.position = _cell_pixel(Vector2i(sx, shop_y)) + Vector2(17, 17)
				entity_root.add_child(sprite)
				var item_names = ["Rope+2", "Bomb+2", "HP+1"]
				var lbl = Label.new()
				lbl.text = "$%d" % (3 + i)
				lbl.position = sprite.position + Vector2(-5, -18)
				lbl.add_theme_color_override("font_color", COLOR_GOLD)
				lbl.add_theme_font_size_override("font_size", 14)
				entity_root.add_child(lbl)
				shop_items.append({"cell": Vector2i(sx, shop_y), "sprite": sprite, "label": lbl, "type": item_names[i], "price": 3 + i})

		# Shopkeeper
		var sk_sprite = ColorRect.new()
		sk_sprite.color = Color(0.9, 0.7, 0.4)
		sk_sprite.size = Vector2(CELL - 20, CELL - 10)
		sk_sprite.position = _cell_pixel(Vector2i(shop_x - 1, shop_y)) + Vector2(10, 5)
		entity_root.add_child(sk_sprite)
		var sk_lbl = Label.new()
		sk_lbl.text = "SK"
		sk_lbl.position = sk_sprite.position + Vector2(10, 14)
		sk_lbl.add_theme_color_override("font_color", Color(0.2, 0.1, 0.0))
		sk_lbl.add_theme_font_size_override("font_size", 18)
		entity_root.add_child(sk_lbl)

func _build_hud() -> void:
	hud_root = CanvasLayer.new()
	add_child(hud_root)

	var top = ColorRect.new()
	top.color = COLOR_PANEL
	top.size = Vector2(1280, 60)
	hud_root.add_child(top)
	var top_edge = ColorRect.new()
	top_edge.color = COLOR_ACCENT
	top_edge.position = Vector2(0, 58)
	top_edge.size = Vector2(1280, 2)
	hud_root.add_child(top_edge)

	hp_label = Label.new()
	hp_label.text = "HP %d/%d" % [main.player_hp, main.player_hp_max]
	hp_label.position = Vector2(20, 16)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	hp_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(hp_label)

	gold_label = Label.new()
	gold_label.text = "Gold: %d" % main.gold
	gold_label.position = Vector2(180, 16)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(gold_label)

	rope_label = Label.new()
	rope_label.text = "Rope: %d" % main.ropes
	rope_label.position = Vector2(360, 16)
	rope_label.add_theme_color_override("font_color", COLOR_ROPE)
	rope_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(rope_label)

	bomb_label = Label.new()
	bomb_label.text = "Bomb: %d" % main.bombs
	bomb_label.position = Vector2(520, 16)
	bomb_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	bomb_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(bomb_label)

	floor_label = Label.new()
	floor_label.text = "Floor %d / %d" % [main.floor_num, main.max_floors]
	floor_label.position = Vector2(700, 16)
	floor_label.size = Vector2(200, 30)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_color_override("font_color", COLOR_TEXT)
	floor_label.add_theme_font_size_override("font_size", 22)
	hud_root.add_child(floor_label)

	timer_label = Label.new()
	timer_label.text = "Ghost: %ds" % int(ghost_timer)
	timer_label.position = Vector2(1050, 16)
	timer_label.size = Vector2(200, 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	timer_label.add_theme_font_size_override("font_size", 20)
	hud_root.add_child(timer_label)

	# Bottom feedback
	feedback_label = Label.new()
	feedback_label.position = Vector2(0, 680)
	feedback_label.size = Vector2(1280, 30)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	feedback_label.add_theme_font_size_override("font_size", 18)
	hud_root.add_child(feedback_label)

func _process(dt: float) -> void:
	if floor_done:
		return
	floor_timer += dt
	ghost_timer -= dt
	timer_label.text = "Ghost: %ds" % max(int(ghost_timer), 0)

	if ghost_timer <= 0.0 and not ghost_active:
		_spawn_ghost()

	if ghost_active:
		# Ghost moves toward player
		var dir = (Vector2(player_pos) - ghost_pos).normalized()
		ghost_pos += dir * 60.0 * dt
		ghost_sprite.position = ORIGIN + ghost_pos * CELL
		# Check if ghost touches player
		if ghost_pos.distance_to(Vector2(player_pos)) < 0.8:
			main.player_hp = 0
			_die()

	if feedback_timer > 0.0:
		feedback_timer -= dt
		if feedback_timer <= 0.0:
			feedback_label.text = ""

	# Simple gravity for enemies (move them down if no ground)
	for e in enemies:
		var below = e.cell + Vector2i(0, 1)
		if below.y < ROWS and grid[below.y][below.x] == "air":
			e.cell = below
			e.sprite.position = _cell_pixel(e.cell) + Vector2(12, 8)
			e.label.position = e.sprite.position + Vector2(14, 10)

func _input(event: InputEvent) -> void:
	if floor_done:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_move_player(Vector2i(-1, 0))
			KEY_RIGHT:
				_move_player(Vector2i(1, 0))
			KEY_UP:
				_use_rope()
			KEY_DOWN:
				_interact()
			KEY_SPACE:
				_jump()
			KEY_B:
				_use_bomb()

func _move_player(dir: Vector2i) -> void:
	var new_pos = player_pos + dir
	if new_pos.x < 0 or new_pos.x >= COLS or new_pos.y < 0 or new_pos.y >= ROWS:
		return
	if grid[new_pos.y][new_pos.x] == "rock":
		return
	player_facing = dir.x
	player_pos = new_pos
	_apply_gravity()
	_update_player_visual()
	_check_cell()

func _jump() -> void:
	var up_pos = player_pos + Vector2i(0, -1)
	if up_pos.y < 0:
		return
	if grid[up_pos.y][up_pos.x] == "rock":
		return
	player_pos = up_pos
	_update_player_visual()
	_check_cell()

func _apply_gravity() -> void:
	# Fall until on ground
	var below = player_pos + Vector2i(0, 1)
	while below.y < ROWS and grid[below.y][below.x] != "rock":
		# Check if there's a rope here
		var on_rope = false
		for r in ropes_placed:
			if r == player_pos:
				on_rope = true
				break
		if on_rope:
			break
		player_pos = below
		below = player_pos + Vector2i(0, 1)

func _use_rope() -> void:
	if main.ropes <= 0:
		_show_feedback("No ropes!")
		return
	main.ropes -= 1
	rope_label.text = "Rope: %d" % main.ropes
	# Place rope above current position
	var rope_cell = player_pos + Vector2i(0, -1)
	if rope_cell.y >= 0:
		ropes_placed.append(rope_cell)
		var rope_sprite = ColorRect.new()
		rope_sprite.color = COLOR_ROPE
		rope_sprite.position = _cell_pixel(rope_cell) + Vector2(28, 0)
		rope_sprite.size = Vector2(8, CELL)
		entity_root.add_child(rope_sprite)
		# Move player up
		player_pos = rope_cell
		_update_player_visual()
		_show_feedback("Rope placed!")

func _use_bomb() -> void:
	if main.bombs <= 0:
		_show_feedback("No bombs!")
		return
	main.bombs -= 1
	bomb_label.text = "Bomb: %d" % main.bombs
	# Destroy adjacent rock in facing direction
	var target = player_pos + Vector2i(player_facing, 0)
	if target.x >= 0 and target.x < COLS and target.y >= 0 and target.y < ROWS:
		if grid[target.y][target.x] == "rock":
			grid[target.y][target.x] = "air"
			# Update visual
			var idx = target.y * COLS + target.x
			var children = grid_root.get_children()
			if idx < children.size():
				children[idx].color = COLOR_AIR
			_show_feedback("BOOM!")
			# Check enemies in blast
			var to_remove = []
			for e in enemies:
				if e.cell == target or (e.cell - target).length() < 1.5:
					to_remove.append(e)
			for e in to_remove:
				main.enemies_killed += 1
				if is_instance_valid(e.sprite):
					e.sprite.queue_free()
				if is_instance_valid(e.label):
					e.label.queue_free()
				enemies.erase(e)

func _interact() -> void:
	# Pick up gold or buy shop item
	var picked_gold = false
	var to_remove = []
	for gc in gold_cells:
		if gc == player_pos:
			to_remove.append(gc)
			main.gold += 5
			picked_gold = true
	for gc in to_remove:
		gold_cells.erase(gc)
	if picked_gold:
		gold_label.text = "Gold: %d" % main.gold
		_show_feedback("+5 Gold!")
		return

	# Shop interaction
	for item in shop_items:
		if item.cell == player_pos:
			if main.gold >= item.price:
				main.gold -= item.price
				gold_label.text = "Gold: %d" % main.gold
				match item.type:
					"Rope+2":
						main.ropes += 2
						rope_label.text = "Rope: %d" % main.ropes
					"Bomb+2":
						main.bombs += 2
						bomb_label.text = "Bomb: %d" % main.bombs
					"HP+1":
						main.player_hp = mini(main.player_hp + 1, main.player_hp_max)
						hp_label.text = "HP %d/%d" % [main.player_hp, main.player_hp_max]
				if is_instance_valid(item.sprite):
					item.sprite.queue_free()
				if is_instance_valid(item.label):
					item.label.queue_free()
				shop_items.erase(item)
				_show_feedback("Bought %s!" % item.type)
			else:
				_show_feedback("Not enough gold!")
			return

func _check_cell() -> void:
	# Check exit
	if player_pos == exit_cell:
		_exit_floor()
		return
	# Check enemy collision
	for e in enemies:
		if e.cell == player_pos:
			main.player_hp -= 1
			hp_label.text = "HP %d/%d" % [main.player_hp, main.player_hp_max]
			if main.player_hp <= 0:
				_die()
				return
			# Knock enemy away
			e.cell = e.cell + Vector2i(player_facing, 0)
			if e.cell.x < 0:
				e.cell.x = 0
			if e.cell.x >= COLS:
				e.cell.x = COLS - 1
			e.sprite.position = _cell_pixel(e.cell) + Vector2(12, 8)
			e.label.position = e.sprite.position + Vector2(14, 10)
			_show_feedback("Ouch! -1 HP")

func _spawn_ghost() -> void:
	ghost_active = true
	ghost_pos = Vector2(0, 0)
	ghost_sprite = ColorRect.new()
	ghost_sprite.color = COLOR_GHOST
	ghost_sprite.size = Vector2(CELL, CELL)
	ghost_sprite.position = ORIGIN
	entity_root.add_child(ghost_sprite)
	var glbl = Label.new()
	glbl.text = "GH"
	glbl.position = Vector2(16, 16)
	glbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.5))
	glbl.add_theme_font_size_override("font_size", 22)
	ghost_sprite.add_child(glbl)
	_show_feedback("THE GHOST APPEARS!")

func _exit_floor() -> void:
	if floor_done:
		return
	floor_done = true
	_show_feedback("Floor cleared!")
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self) and main != null:
		main.advance_floor()

func _die() -> void:
	if floor_done:
		return
	floor_done = true
	_show_feedback("You perished...")
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self) and main != null:
		main._enter_death()

func _update_player_visual() -> void:
	player_sprite.position = _cell_pixel(player_pos) + Vector2(10, 5)
	var children = entity_root.get_children()
	if children.size() > 1:
		children[1].position = player_sprite.position + Vector2(16, 14)

func _show_feedback(msg: String) -> void:
	feedback_label.text = msg
	feedback_timer = 2.0

func _cell_pixel(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c.x * CELL, c.y * CELL)
