extends Node2D

var main: Node = null
var level_index: int = 0

# Grid constants
const CELL_SIZE := 48
const GRID_OFFSET := Vector2(160, 80)
const GRID_W := 20
const GRID_H := 12

# Entity types
enum EntityType { OBJECT, NOUN, VERB, PROPERTY }
# Object kinds
enum ObjKind { BABA, WALL, ROCK, FLAG, SKULL, WATER, KEY }

# Properties
const PROP_STOP := "STOP"
const PROP_WIN := "WIN"
const PROP_PUSH := "PUSH"
const PROP_YOU := "YOU"
const PROP_DEFEAT := "DEFEAT"

# Colors for word blocks
var noun_color = Color(0.9, 0.2, 0.4)
var verb_color = Color(0.95, 0.95, 0.95)
var prop_color = Color(0.2, 0.7, 0.9)

# Object colors
var obj_colors = {
	ObjKind.BABA: Color(0.9, 0.9, 0.9),
	ObjKind.WALL: Color(0.3, 0.3, 0.35),
	ObjKind.ROCK: Color(0.6, 0.45, 0.2),
	ObjKind.FLAG: Color(0.9, 0.85, 0.1),
	ObjKind.SKULL: Color(0.7, 0.1, 0.1),
	ObjKind.WATER: Color(0.1, 0.3, 0.8),
	ObjKind.KEY: Color(0.8, 0.6, 0.1),
}

var obj_names = {
	ObjKind.BABA: "BABA",
	ObjKind.WALL: "WALL",
	ObjKind.ROCK: "ROCK",
	ObjKind.FLAG: "FLAG",
	ObjKind.SKULL: "SKULL",
	ObjKind.WATER: "WATER",
	ObjKind.KEY: "KEY",
}

# Entity data
class Entity:
	var etype: int  # EntityType
	var kind: int   # ObjKind (for OBJECT type)
	var word: String # text for word blocks
	var gx: int
	var gy: int
	var node: Node = null

var entities: Array = []
var history: Array = []  # undo stack
var active_rules: Array = []  # [{noun_kind, property}]
var _processing_input = false

func _ready() -> void:
	_draw_background()
	_load_level(level_index)
	_rebuild_visuals()
	_evaluate_rules()

func _draw_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)
	# Grid lines
	for x in range(GRID_W + 1):
		var line = ColorRect.new()
		line.color = Color(0.15, 0.15, 0.2)
		line.size = Vector2(1, GRID_H * CELL_SIZE)
		line.position = GRID_OFFSET + Vector2(x * CELL_SIZE, 0)
		line.z_index = -5
		add_child(line)
	for y in range(GRID_H + 1):
		var line = ColorRect.new()
		line.color = Color(0.15, 0.15, 0.2)
		line.size = Vector2(GRID_W * CELL_SIZE, 1)
		line.position = GRID_OFFSET + Vector2(0, y * CELL_SIZE)
		line.z_index = -5
		add_child(line)

func _load_level(idx: int) -> void:
	entities.clear()
	history.clear()
	var levels = _get_levels()
	if idx >= levels.size():
		idx = 0
	var data: Array = levels[idx]
	for item in data:
		var e = Entity.new()
		e.etype = item[0]
		e.kind = item[1]
		e.word = item[2]
		e.gx = item[3]
		e.gy = item[4]
		entities.append(e)

func _get_levels() -> Array:
	# Each level is an array of [etype, kind, word, gx, gy]
	# Level 1: Simple - push FLAG IS WIN together, walk to flag
	var l1 = [
		[EntityType.OBJECT, ObjKind.BABA, "", 2, 5],
		[EntityType.OBJECT, ObjKind.FLAG, "", 17, 5],
		[EntityType.NOUN, ObjKind.BABA, "BABA", 4, 1],
		[EntityType.VERB, -1, "IS", 5, 1],
		[EntityType.PROPERTY, -1, "YOU", 6, 1],
		[EntityType.NOUN, ObjKind.FLAG, "FLAG", 10, 5],
		[EntityType.VERB, -1, "IS", 11, 5],
		[EntityType.PROPERTY, -1, "WIN", 13, 5],
		# Walls around border
		[EntityType.OBJECT, ObjKind.WALL, "", 0, 0], [EntityType.OBJECT, ObjKind.WALL, "", 1, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 2, 0], [EntityType.OBJECT, ObjKind.WALL, "", 3, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 4, 0], [EntityType.OBJECT, ObjKind.WALL, "", 5, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 6, 0], [EntityType.OBJECT, ObjKind.WALL, "", 7, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 8, 0], [EntityType.OBJECT, ObjKind.WALL, "", 9, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 10, 0], [EntityType.OBJECT, ObjKind.WALL, "", 11, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 12, 0], [EntityType.OBJECT, ObjKind.WALL, "", 13, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 14, 0], [EntityType.OBJECT, ObjKind.WALL, "", 15, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 16, 0], [EntityType.OBJECT, ObjKind.WALL, "", 17, 0],
		[EntityType.OBJECT, ObjKind.WALL, "", 18, 0], [EntityType.OBJECT, ObjKind.WALL, "", 19, 0],
		[EntityType.NOUN, ObjKind.WALL, "WALL", 1, 9],
		[EntityType.VERB, -1, "IS", 2, 9],
		[EntityType.PROPERTY, -1, "STOP", 3, 9],
	]

	# Level 2: Push rocks to reach flag
	var l2 = [
		[EntityType.OBJECT, ObjKind.BABA, "", 1, 5],
		[EntityType.OBJECT, ObjKind.FLAG, "", 18, 5],
		[EntityType.OBJECT, ObjKind.ROCK, "", 5, 5],
		[EntityType.OBJECT, ObjKind.ROCK, "", 10, 5],
		[EntityType.NOUN, ObjKind.BABA, "BABA", 1, 1],
		[EntityType.VERB, -1, "IS", 2, 1],
		[EntityType.PROPERTY, -1, "YOU", 3, 1],
		[EntityType.NOUN, ObjKind.FLAG, "FLAG", 15, 1],
		[EntityType.VERB, -1, "IS", 16, 1],
		[EntityType.PROPERTY, -1, "WIN", 17, 1],
		[EntityType.NOUN, ObjKind.ROCK, "ROCK", 1, 10],
		[EntityType.VERB, -1, "IS", 2, 10],
		[EntityType.PROPERTY, -1, "PUSH", 3, 10],
	]

	# Level 3: YOU reassignment - become the rock
	var l3 = [
		[EntityType.OBJECT, ObjKind.BABA, "", 2, 5],
		[EntityType.OBJECT, ObjKind.ROCK, "", 10, 3],
		[EntityType.OBJECT, ObjKind.FLAG, "", 18, 3],
		[EntityType.OBJECT, ObjKind.WALL, "", 5, 3], [EntityType.OBJECT, ObjKind.WALL, "", 5, 4],
		[EntityType.OBJECT, ObjKind.WALL, "", 5, 5], [EntityType.OBJECT, ObjKind.WALL, "", 5, 6],
		[EntityType.NOUN, ObjKind.BABA, "BABA", 1, 1],
		[EntityType.VERB, -1, "IS", 2, 1],
		[EntityType.PROPERTY, -1, "YOU", 3, 1],
		[EntityType.NOUN, ObjKind.ROCK, "ROCK", 7, 8],
		[EntityType.VERB, -1, "IS", 8, 8],
		[EntityType.PROPERTY, -1, "YOU", 9, 8],
		[EntityType.NOUN, ObjKind.FLAG, "FLAG", 15, 1],
		[EntityType.VERB, -1, "IS", 16, 1],
		[EntityType.PROPERTY, -1, "WIN", 17, 1],
		[EntityType.NOUN, ObjKind.WALL, "WALL", 1, 10],
		[EntityType.VERB, -1, "IS", 2, 10],
		[EntityType.PROPERTY, -1, "STOP", 3, 10],
	]

	# Level 4: Skull is defeat, must break rule
	var l4 = [
		[EntityType.OBJECT, ObjKind.BABA, "", 1, 5],
		[EntityType.OBJECT, ObjKind.FLAG, "", 18, 5],
		[EntityType.OBJECT, ObjKind.SKULL, "", 10, 5],
		[EntityType.OBJECT, ObjKind.SKULL, "", 11, 5],
		[EntityType.NOUN, ObjKind.BABA, "BABA", 1, 1],
		[EntityType.VERB, -1, "IS", 2, 1],
		[EntityType.PROPERTY, -1, "YOU", 3, 1],
		[EntityType.NOUN, ObjKind.FLAG, "FLAG", 15, 1],
		[EntityType.VERB, -1, "IS", 16, 1],
		[EntityType.PROPERTY, -1, "WIN", 17, 1],
		[EntityType.NOUN, ObjKind.SKULL, "SKULL", 8, 9],
		[EntityType.VERB, -1, "IS", 9, 9],
		[EntityType.PROPERTY, -1, "DEFEAT", 10, 9],
		[EntityType.NOUN, ObjKind.SKULL, "SKULL", 8, 10],
		[EntityType.VERB, -1, "IS", 9, 10],
		[EntityType.PROPERTY, -1, "PUSH", 10, 10],
	]

	# Level 5: Multiple rules, key and water
	var l5 = [
		[EntityType.OBJECT, ObjKind.BABA, "", 1, 6],
		[EntityType.OBJECT, ObjKind.FLAG, "", 18, 2],
		[EntityType.OBJECT, ObjKind.KEY, "", 9, 6],
		[EntityType.OBJECT, ObjKind.WATER, "", 14, 2], [EntityType.OBJECT, ObjKind.WATER, "", 14, 3],
		[EntityType.OBJECT, ObjKind.WATER, "", 14, 4], [EntityType.OBJECT, ObjKind.WATER, "", 14, 5],
		[EntityType.OBJECT, ObjKind.WATER, "", 14, 6],
		[EntityType.NOUN, ObjKind.BABA, "BABA", 1, 1],
		[EntityType.VERB, -1, "IS", 2, 1],
		[EntityType.PROPERTY, -1, "YOU", 3, 1],
		[EntityType.NOUN, ObjKind.FLAG, "FLAG", 16, 1],
		[EntityType.VERB, -1, "IS", 17, 1],
		[EntityType.PROPERTY, -1, "WIN", 18, 1],
		[EntityType.NOUN, ObjKind.WATER, "WATER", 1, 10],
		[EntityType.VERB, -1, "IS", 2, 10],
		[EntityType.PROPERTY, -1, "DEFEAT", 3, 10],
		[EntityType.NOUN, ObjKind.KEY, "KEY", 7, 10],
		[EntityType.VERB, -1, "IS", 8, 10],
		[EntityType.PROPERTY, -1, "PUSH", 9, 10],
	]

	return [l1, l2, l3, l4, l5]

func _rebuild_visuals() -> void:
	for e in entities:
		if e.node != null and is_instance_valid(e.node):
			e.node.queue_free()
		e.node = _create_entity_visual(e)
		add_child(e.node)
	_update_positions()

func _create_entity_visual(e: Entity) -> Node2D:
	var container = Node2D.new()
	var rect = ColorRect.new()
	rect.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
	rect.position = Vector2(1, 1)

	match e.etype:
		EntityType.OBJECT:
			rect.color = obj_colors.get(e.kind, Color.WHITE)
			container.add_child(rect)
			var lbl = Label.new()
			lbl.text = obj_names.get(e.kind, "?")[0]
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color.BLACK)
			lbl.position = Vector2(16, 12)
			container.add_child(lbl)
		EntityType.NOUN:
			rect.color = noun_color
			container.add_child(rect)
			var lbl = Label.new()
			lbl.text = e.word
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.position = Vector2(3, 14)
			container.add_child(lbl)
		EntityType.VERB:
			rect.color = verb_color
			container.add_child(rect)
			var lbl = Label.new()
			lbl.text = e.word
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color.BLACK)
			lbl.position = Vector2(12, 14)
			container.add_child(lbl)
		EntityType.PROPERTY:
			rect.color = prop_color
			container.add_child(rect)
			var lbl = Label.new()
			lbl.text = e.word
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.position = Vector2(3, 14)
			container.add_child(lbl)
	return container

func _update_positions() -> void:
	for e in entities:
		if e.node != null and is_instance_valid(e.node):
			e.node.position = GRID_OFFSET + Vector2(e.gx * CELL_SIZE, e.gy * CELL_SIZE)

func _evaluate_rules() -> void:
	active_rules.clear()
	# Check horizontal triplets
	for e in entities:
		if e.etype == EntityType.NOUN:
			var verb = _entity_at(e.gx + 1, e.gy, EntityType.VERB)
			if verb != null:
				var prop = _entity_at(e.gx + 2, e.gy, EntityType.PROPERTY)
				if prop != null:
					active_rules.append({"noun_kind": e.kind, "property": prop.word})
	# Check vertical triplets
	for e in entities:
		if e.etype == EntityType.NOUN:
			var verb = _entity_at(e.gx, e.gy + 1, EntityType.VERB)
			if verb != null:
				var prop = _entity_at(e.gx, e.gy + 2, EntityType.PROPERTY)
				if prop != null:
					active_rules.append({"noun_kind": e.kind, "property": prop.word})
	_highlight_active_rules()

func _highlight_active_rules() -> void:
	# Reset and highlight word blocks that are part of active rules
	for e in entities:
		if e.etype != EntityType.OBJECT and e.node != null and is_instance_valid(e.node):
			# Reset color first
			if e.node.get_child_count() > 0:
				var r0 = e.node.get_child(0)
				if r0 is ColorRect:
					match e.etype:
						EntityType.NOUN:
							r0.color = noun_color
						EntityType.VERB:
							r0.color = verb_color
						EntityType.PROPERTY:
							r0.color = prop_color
			var is_active = false
			if e.etype == EntityType.NOUN:
				for r in active_rules:
					if r.noun_kind == e.kind:
						is_active = true
						break
			elif e.etype == EntityType.VERB:
				is_active = _is_verb_in_rule(e)
			elif e.etype == EntityType.PROPERTY:
				is_active = _is_prop_in_rule(e)
			if is_active and e.node.get_child_count() > 0:
				var r1 = e.node.get_child(0)
				if r1 is ColorRect:
					r1.color = r1.color.lightened(0.3)

func _is_verb_in_rule(e: Entity) -> bool:
	# Check if this verb is between a noun and property
	var left = _entity_at(e.gx - 1, e.gy, EntityType.NOUN)
	var right = _entity_at(e.gx + 1, e.gy, EntityType.PROPERTY)
	if left != null and right != null:
		return true
	var up = _entity_at(e.gx, e.gy - 1, EntityType.NOUN)
	var down = _entity_at(e.gx, e.gy + 1, EntityType.PROPERTY)
	if up != null and down != null:
		return true
	return false

func _is_prop_in_rule(e: Entity) -> bool:
	var verb = _entity_at(e.gx - 1, e.gy, EntityType.VERB)
	if verb != null:
		var noun = _entity_at(e.gx - 2, e.gy, EntityType.NOUN)
		if noun != null:
			return true
	var verb2 = _entity_at(e.gx, e.gy - 1, EntityType.VERB)
	if verb2 != null:
		var noun2 = _entity_at(e.gx, e.gy - 2, EntityType.NOUN)
		if noun2 != null:
			return true
	return false

func _entity_at(gx: int, gy: int, etype: int) -> Entity:
	for e in entities:
		if e.gx == gx and e.gy == gy and e.etype == etype:
			return e
	return null

func _entities_at(gx: int, gy: int) -> Array:
	var result = []
	for e in entities:
		if e.gx == gx and e.gy == gy:
			result.append(e)
	return result

func _has_property(kind: int, prop: String) -> bool:
	for r in active_rules:
		if r.noun_kind == kind and r.property == prop:
			return true
	return false

func _input(event: InputEvent) -> void:
	if _processing_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var dir = Vector2i.ZERO
		match event.keycode:
			KEY_UP:
				dir = Vector2i(0, -1)
			KEY_DOWN:
				dir = Vector2i(0, 1)
			KEY_LEFT:
				dir = Vector2i(-1, 0)
			KEY_RIGHT:
				dir = Vector2i(1, 0)
			KEY_Z:
				_undo()
				return
			KEY_R:
				_reset()
				return
			KEY_ESCAPE:
				main._enter_level_select()
				return
		if dir != Vector2i.ZERO:
			_do_move(dir)

func _save_state() -> Array:
	var state = []
	for e in entities:
		state.append([e.gx, e.gy])
	return state

func _restore_state(state: Array) -> void:
	for i in range(min(state.size(), entities.size())):
		entities[i].gx = state[i][0]
		entities[i].gy = state[i][1]
	_update_positions()
	_evaluate_rules()

func _undo() -> void:
	if history.size() > 0:
		var state = history.pop_back()
		_restore_state(state)

func _reset() -> void:
	history.clear()
	for e in entities:
		if e.node != null and is_instance_valid(e.node):
			e.node.queue_free()
	entities.clear()
	_load_level(level_index)
	_rebuild_visuals()
	_evaluate_rules()

func _do_move(dir: Vector2i) -> void:
	_processing_input = true
	var state = _save_state()
	var moved = false

	# Find all YOU entities
	var you_entities = []
	for e in entities:
		if e.etype == EntityType.OBJECT and _has_property(e.kind, PROP_YOU):
			you_entities.append(e)

	for you in you_entities:
		var nx = you.gx + dir.x
		var ny = you.gy + dir.y
		if _can_move_to(you, nx, ny, dir):
			_push_chain(nx, ny, dir)
			you.gx = nx
			you.gy = ny
			moved = true

	if moved:
		history.append(state)
		_update_positions()
		_evaluate_rules()
		_check_win_defeat()

	_processing_input = false

func _can_move_to(_mover: Entity, gx: int, gy: int, dir: Vector2i) -> bool:
	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return false
	var at = _entities_at(gx, gy)
	for e in at:
		if e.etype == EntityType.OBJECT and _has_property(e.kind, PROP_STOP):
			if not _has_property(e.kind, PROP_PUSH):
				return false
		if _is_pushable(e):
			var nnx = gx + dir.x
			var nny = gy + dir.y
			if not _can_push_to(nnx, nny, dir):
				return false
	return true

func _is_pushable(e: Entity) -> bool:
	if e.etype != EntityType.OBJECT:
		return true  # word blocks are always pushable
	return _has_property(e.kind, PROP_PUSH)

func _can_push_to(gx: int, gy: int, dir: Vector2i) -> bool:
	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return false
	var at = _entities_at(gx, gy)
	for e in at:
		if e.etype == EntityType.OBJECT and _has_property(e.kind, PROP_STOP):
			if not _has_property(e.kind, PROP_PUSH):
				return false
		if _is_pushable(e):
			var nnx = gx + dir.x
			var nny = gy + dir.y
			if not _can_push_to(nnx, nny, dir):
				return false
	return true

func _push_chain(gx: int, gy: int, dir: Vector2i) -> void:
	var at = _entities_at(gx, gy)
	for e in at:
		if _is_pushable(e):
			var nnx = gx + dir.x
			var nny = gy + dir.y
			_push_chain(nnx, nny, dir)
			e.gx = nnx
			e.gy = nny

func _check_win_defeat() -> void:
	var you_entities = []
	for e in entities:
		if e.etype == EntityType.OBJECT and _has_property(e.kind, PROP_YOU):
			you_entities.append(e)

	for you in you_entities:
		var at = _entities_at(you.gx, you.gy)
		for e in at:
			if e == you:
				continue
			if e.etype == EntityType.OBJECT:
				if _has_property(e.kind, PROP_WIN):
					_win()
					return
				if _has_property(e.kind, PROP_DEFEAT):
					_defeat()
					return

func _win() -> void:
	main._enter_win_screen(level_index)

func _defeat() -> void:
	# Reset level on defeat
	_reset()
