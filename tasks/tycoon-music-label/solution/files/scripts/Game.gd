extends Node2D

var gold: int = 50000
var week: int = 1
var reputation: int = 10
var roster: Array = []
var scouting_pool: Array = []
var albums_released: Array = []
var genres: Array = ["Pop", "Rock", "Hip-Hop", "Electronic", "Country", "R&B"]
var trend_genre: String = "Pop"

var hud_gold_label: Label = null
var hud_week_label: Label = null
var hud_rep_label: Label = null
var roster_container: Node2D = null
var scout_container: Node2D = null
var info_label: Label = null
var release_panel: Node2D = null

func _ready() -> void:
	_generate_scouting_pool()
	trend_genre = genres[randi() % genres.size()]
	_build_ui()
	var main_node: Node = get_parent()
	var scen: String = main_node.get("scenario")
	if scen == "scouting":
		_show_scouting()
	elif scen == "release":
		_seed_release_state()
		_show_release_panel()

func _generate_scouting_pool() -> void:
	var names: Array = ["Luna Vex", "DJ Krono", "The Velvet Chains", "MC Blaze", "Aria Storm", "Neon Dusk"]
	var talents: Array = [70, 85, 60, 90, 75, 80]
	scouting_pool.clear()
	for i in range(names.size()):
		var artist: Dictionary = {
			"name": names[i],
			"genre": genres[i % genres.size()],
			"talent": talents[i],
			"signed": false,
			"album_ready": false,
			"studio_weeks": 0
		}
		scouting_pool.append(artist)

func _seed_release_state() -> void:
	var artist: Dictionary = {
		"name": "Luna Vex",
		"genre": "Pop",
		"talent": 70,
		"signed": true,
		"album_ready": true,
		"studio_weeks": 4
	}
	roster.append(artist)
	gold = 35000

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# HUD bar
	var hud_bar: ColorRect = ColorRect.new()
	hud_bar.color = Color(0.1, 0.0, 0.15)
	hud_bar.size = Vector2(1280, 50)
	add_child(hud_bar)

	hud_gold_label = Label.new()
	hud_gold_label.position = Vector2(20, 12)
	hud_gold_label.add_theme_font_size_override("font_size", 18)
	hud_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	add_child(hud_gold_label)

	hud_week_label = Label.new()
	hud_week_label.position = Vector2(300, 12)
	hud_week_label.add_theme_font_size_override("font_size", 18)
	hud_week_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	add_child(hud_week_label)

	hud_rep_label = Label.new()
	hud_rep_label.position = Vector2(550, 12)
	hud_rep_label.add_theme_font_size_override("font_size", 18)
	hud_rep_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	add_child(hud_rep_label)

	_update_hud()

	# Trend panel
	var trend_label: Label = Label.new()
	trend_label.text = "Trending: " + trend_genre
	trend_label.position = Vector2(900, 12)
	trend_label.add_theme_font_size_override("font_size", 16)
	trend_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.8))
	add_child(trend_label)

	# Info label
	info_label = Label.new()
	info_label.position = Vector2(20, 660)
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(info_label)

	# Action buttons
	_add_action_button("Scout Artists", Vector2(20, 70), _show_scouting)
	_add_action_button("Studio", Vector2(200, 70), _show_studio)
	_add_action_button("Release", Vector2(380, 70), _show_release_panel)
	_add_action_button("Next Week", Vector2(560, 70), _advance_week)
	_add_action_button("End Year", Vector2(740, 70), _end_year)

	# Roster container
	roster_container = Node2D.new()
	roster_container.position = Vector2(20, 140)
	add_child(roster_container)

	# Scout container
	scout_container = Node2D.new()
	scout_container.position = Vector2(20, 140)
	scout_container.visible = false
	add_child(scout_container)

	# Release panel
	release_panel = Node2D.new()
	release_panel.position = Vector2(20, 140)
	release_panel.visible = false
	add_child(release_panel)

	_refresh_roster()

func _add_action_button(text: String, pos: Vector2, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(150, 40)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.05, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(callback)
	add_child(btn)

func _update_hud() -> void:
	hud_gold_label.text = "Gold: $" + str(gold)
	hud_week_label.text = "Week: " + str(week) + " / 52"
	hud_rep_label.text = "Reputation: " + str(reputation)

func _refresh_roster() -> void:
	for c in roster_container.get_children():
		c.queue_free()
	if roster.size() == 0:
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No artists signed yet. Scout some talent!"
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		roster_container.add_child(empty_lbl)
		return
	for i in range(roster.size()):
		var a: Dictionary = roster[i]
		var lbl: Label = Label.new()
		var status: String = "Recording" if not a["album_ready"] and a["studio_weeks"] > 0 else ("Album Ready" if a["album_ready"] else "Idle")
		lbl.text = a["name"] + " | " + a["genre"] + " | Talent: " + str(a["talent"]) + " | " + status
		lbl.position = Vector2(0, i * 30)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
		roster_container.add_child(lbl)

func _hide_panels() -> void:
	scout_container.visible = false
	release_panel.visible = false
	roster_container.visible = false

func _show_scouting() -> void:
	_hide_panels()
	scout_container.visible = true
	for c in scout_container.get_children():
		c.queue_free()
	var header: Label = Label.new()
	header.text = "-- Scouting Pool --"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	scout_container.add_child(header)
	var idx: int = 0
	for a in scouting_pool:
		if a["signed"]:
			continue
		var btn: Button = Button.new()
		btn.text = "Sign: " + a["name"] + " (" + a["genre"] + ", Talent " + str(a["talent"]) + ") - $5000"
		btn.position = Vector2(0, 40 + idx * 50)
		btn.custom_minimum_size = Vector2(500, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.1, 0.25)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		var artist_ref: Dictionary = a
		btn.pressed.connect(_sign_artist.bind(artist_ref))
		scout_container.add_child(btn)
		idx += 1

func _sign_artist(artist: Dictionary) -> void:
	if gold < 5000:
		info_label.text = "Not enough gold to sign this artist!"
		return
	gold -= 5000
	artist["signed"] = true
	roster.append(artist)
	reputation += 2
	info_label.text = "Signed " + artist["name"] + "!"
	_update_hud()
	_show_scouting()

func _show_studio() -> void:
	_hide_panels()
	roster_container.visible = true
	for c in roster_container.get_children():
		c.queue_free()
	var header: Label = Label.new()
	header.text = "-- Studio: Assign Recording --"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	roster_container.add_child(header)
	var idx: int = 0
	for i in range(roster.size()):
		var a: Dictionary = roster[i]
		if a["album_ready"] or a["studio_weeks"] > 0:
			continue
		var btn: Button = Button.new()
		btn.text = "Record: " + a["name"] + " ($3000/session)"
		btn.position = Vector2(0, 40 + idx * 50)
		btn.custom_minimum_size = Vector2(400, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.15, 0.25)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(_start_recording.bind(i))
		roster_container.add_child(btn)
		idx += 1

func _start_recording(artist_idx: int) -> void:
	if gold < 3000:
		info_label.text = "Not enough gold for studio time!"
		return
	gold -= 3000
	roster[artist_idx]["studio_weeks"] = 4
	info_label.text = roster[artist_idx]["name"] + " is now recording (4 weeks)."
	_update_hud()
	_show_studio()

func _show_release_panel() -> void:
	_hide_panels()
	release_panel.visible = true
	for c in release_panel.get_children():
		c.queue_free()
	var header: Label = Label.new()
	header.text = "-- Release Albums --"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	release_panel.add_child(header)
	var idx: int = 0
	for i in range(roster.size()):
		var a: Dictionary = roster[i]
		if not a["album_ready"]:
			continue
		var btn: Button = Button.new()
		btn.text = "Release album by " + a["name"] + " ($2000 marketing)"
		btn.position = Vector2(0, 40 + idx * 50)
		btn.custom_minimum_size = Vector2(450, 40)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.2, 0.1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(_release_album.bind(i))
		release_panel.add_child(btn)
		idx += 1
	if idx == 0:
		var none_lbl: Label = Label.new()
		none_lbl.text = "No albums ready. Send artists to the studio first."
		none_lbl.position = Vector2(0, 40)
		none_lbl.add_theme_font_size_override("font_size", 15)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		release_panel.add_child(none_lbl)

func _release_album(artist_idx: int) -> void:
	if gold < 2000:
		info_label.text = "Not enough gold for marketing!"
		return
	gold -= 2000
	var a: Dictionary = roster[artist_idx]
	var chart_score: int = a["talent"] + randi() % 30
	if a["genre"] == trend_genre:
		chart_score += 20
	var revenue: int = chart_score * 200
	gold += revenue
	reputation += chart_score / 20
	a["album_ready"] = false
	a["studio_weeks"] = 0
	var album_record: Dictionary = {"artist": a["name"], "genre": a["genre"], "chart": chart_score, "revenue": revenue, "week": week}
	albums_released.append(album_record)
	info_label.text = a["name"] + " charted at #" + str(max(1, 100 - chart_score)) + "! Revenue: $" + str(revenue)
	_update_hud()
	_show_release_panel()

func _advance_week() -> void:
	week += 1
	for a in roster:
		if a["studio_weeks"] > 0:
			a["studio_weeks"] -= 1
			if a["studio_weeks"] <= 0:
				a["album_ready"] = true
	# Weekly passive income from reputation
	gold += reputation * 50
	_update_hud()
	_hide_panels()
	roster_container.visible = true
	_refresh_roster()
	info_label.text = "Week " + str(week) + " begins. Passive income: $" + str(reputation * 50)
	if week > 52:
		_end_year()

func _end_year() -> void:
	var main_node: Node = get_parent()
	main_node.set("gold", gold)
	main_node.set("reputation", reputation)
	main_node.set("albums_released", albums_released)
	main_node.set("roster_size", roster.size())
	main_node.call("change_screen", "Result")
