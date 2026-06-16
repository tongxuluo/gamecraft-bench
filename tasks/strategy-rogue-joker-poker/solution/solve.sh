#!/bin/bash
# Reference solution for gamecraft-bench/strategy-rogue-joker-poker.
#
# Builds a compact poker-hand roguelite slice:
#   - title -> blind select -> poker round -> scoring -> shop -> boss/result
#   - selectable ranked/suited cards, play hand, discard and redraw
#   - visible chips x multiplier scoring and active joker trigger log
#   - three original jokers, shop purchases, boss rule, victory/defeat screens
#
# The oracle is intentionally modest. It validates that the rubric can observe
# the required mechanics; agents should build something richer and prettier.
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Rogue Joker Poker"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Control

const SUIT_COLORS := {
    "Hearts": Color(0.95, 0.22, 0.38),
    "Diamonds": Color(0.35, 0.75, 1.0),
    "Clubs": Color(0.25, 0.95, 0.55),
    "Spades": Color(0.72, 0.58, 1.0),
}
const SUIT_GLYPH := {"Hearts": "H", "Diamonds": "D", "Clubs": "C", "Spades": "S"}
const RANK_VALUE := {"A": 14, "K": 13, "Q": 12, "J": 11, "10": 10, "9": 9, "8": 8, "7": 7, "6": 6, "5": 5, "4": 4, "3": 3, "2": 2}

var scenario := ""
var screen := "title"
var ante := 1
var blind_name := "Small Blind"
var target_score := 260
var reward_money := 4
var hands_left := 4
var discards_left := 3
var money := 7
var current_score := 0
var hand: Array[Dictionary] = []
var deck_size := 40
var discard_used := false
var boss_rule := ""
var active_jokers: Array[Dictionary] = []
var score_label: Label
var message_label: Label
var trigger_label: Label

func _ready() -> void:
    randomize()
    _parse_args()
    active_jokers = [
        {"name": "Neon Gremlin", "rule": "+25 chips on every scored hand", "kind": "chips"},
        {"name": "Twin Mask", "rule": "x2 mult when a Pair or better uses a rank pair", "kind": "pair"},
        {"name": "Heart Thief", "rule": "+4 mult if any Heart is scored", "kind": "heart"},
    ]
    if scenario == "":
        _show_title()
    elif scenario == "shop_after_win":
        _show_shop()
    elif scenario == "boss_blind":
        _start_round("boss")
    elif scenario == "near_defeat":
        _start_round("defeat")
    else:
        _start_round(scenario)

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _clear() -> void:
    for child in get_children():
        child.queue_free()

func _panel(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
    var p := ColorRect.new()
    p.position = pos
    p.size = size
    p.color = color
    add_child(p)
    return p

func _label(text: String, pos: Vector2, size: Vector2, font_size := 24, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    add_child(l)
    return l

func _button(text: String, pos: Vector2, size: Vector2, callable: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(callable)
    add_child(b)
    return b

func _show_title() -> void:
    screen = "title"
    _clear()
    _panel(Vector2.ZERO, Vector2(1280, 720), Color(0.04, 0.02, 0.08))
    _panel(Vector2(130, 80), Vector2(1020, 520), Color(0.08, 0.17, 0.15))
    _panel(Vector2(180, 130), Vector2(920, 420), Color(0.02, 0.32, 0.22))
    _label("ROGUE JOKER POKER", Vector2(230, 145), Vector2(820, 80), 54, Color(1.0, 0.86, 0.35))
    _label("Build a strange joker engine, score poker hands, and beat the boss blind.", Vector2(270, 240), Vector2(740, 80), 26)
    _draw_joker_card(Vector2(520, 330), "Neon Gremlin", "+25 chips", Color(0.95, 0.25, 0.55))
    _button("Start Run", Vector2(520, 565), Vector2(240, 64), Callable(self, "_show_blind_select"))

func _show_blind_select() -> void:
    screen = "blind"
    _clear()
    _panel(Vector2.ZERO, Vector2(1280, 720), Color(0.03, 0.04, 0.08))
    _label("Ante %d - Choose Blind" % ante, Vector2(70, 45), Vector2(700, 60), 40, Color(1.0, 0.84, 0.35))
    _label("Target score, reward money, hands, and discards are visible before the round.", Vector2(72, 105), Vector2(900, 50), 22)
    _blind_button(Vector2(150, 220), "Small Blind", 260, 4, "normal_round")
    _blind_button(Vector2(480, 220), "Big Blind", 520, 6, "flush_setup")
    _blind_button(Vector2(810, 220), "Boss Blind", 900, 9, "boss")
    _label("Active Jokers", Vector2(80, 500), Vector2(220, 40), 26, Color(1.0, 0.86, 0.35))
    _draw_jokers(Vector2(270, 465))

func _blind_button(pos: Vector2, title: String, target: int, reward: int, mode: String) -> void:
    _panel(pos, Vector2(290, 170), Color(0.13, 0.10, 0.22))
    _label(title, pos + Vector2(20, 18), Vector2(250, 36), 28, Color(1.0, 0.86, 0.35))
    _label("Target %d\nReward $%d\nHands 4  Discards 3" % [target, reward], pos + Vector2(20, 60), Vector2(240, 80), 21)
    _button("Play", pos + Vector2(75, 120), Vector2(140, 42), func(): _start_round(mode))

func _start_round(mode: String) -> void:
    screen = "round"
    discard_used = false
    current_score = 0
    hands_left = 4
    discards_left = 3
    blind_name = "Small Blind"
    target_score = 260
    reward_money = 4
    boss_rule = ""
    if mode == "flush_setup":
        blind_name = "Big Blind"
        target_score = 520
        reward_money = 6
        hand = [_card("A","Hearts"), _card("K","Hearts"), _card("10","Hearts"), _card("8","Hearts"), _card("3","Hearts"), _card("9","Clubs"), _card("2","Spades"), _card("Q","Diamonds")]
    elif mode == "joker_showcase":
        blind_name = "Combo Table"
        target_score = 420
        hand = [_card("Q","Hearts"), _card("Q","Spades"), _card("8","Hearts"), _card("8","Clubs"), _card("4","Diamonds"), _card("A","Spades"), _card("7","Clubs"), _card("2","Diamonds")]
    elif mode == "boss":
        blind_name = "Boss Blind: Spade Eclipse"
        target_score = 620
        reward_money = 10
        boss_rule = "Boss rule: Spades are eclipsed and add 0 rank chips."
        hand = [_card("A","Spades"), _card("K","Spades"), _card("Q","Spades"), _card("J","Spades"), _card("10","Spades"), _card("9","Hearts"), _card("9","Diamonds"), _card("9","Clubs")]
    elif mode == "defeat":
        blind_name = "Big Blind"
        target_score = 1200
        hands_left = 1
        discards_left = 0
        hand = [_card("2","Clubs"), _card("5","Diamonds"), _card("7","Spades"), _card("9","Hearts"), _card("J","Clubs"), _card("3","Spades"), _card("4","Hearts"), _card("6","Diamonds")]
    else:
        hand = [_card("A","Hearts"), _card("A","Clubs"), _card("9","Diamonds"), _card("9","Spades"), _card("5","Hearts"), _card("6","Clubs"), _card("7","Diamonds"), _card("K","Spades")]
    _render_round("Select up to five cards, then Play Hand or Discard.")

func _card(rank: String, suit: String) -> Dictionary:
    return {"rank": rank, "suit": suit, "selected": false}

func _render_round(msg: String) -> void:
    _clear()
    _panel(Vector2.ZERO, Vector2(1280, 720), Color(0.03, 0.05, 0.07))
    _panel(Vector2(45, 35), Vector2(1190, 165), Color(0.08, 0.11, 0.16))
    _label(blind_name, Vector2(70, 55), Vector2(430, 44), 32, Color(1.0, 0.86, 0.35))
    score_label = _label("Score %d / Target %d" % [current_score, target_score], Vector2(70, 103), Vector2(430, 38), 27, Color(0.75, 1.0, 0.75))
    _label("Hands %d   Discards %d   Money $%d   Ante %d   Deck %d" % [hands_left, discards_left, money, ante, deck_size], Vector2(70, 145), Vector2(680, 34), 22)
    if boss_rule != "":
        _label(boss_rule, Vector2(760, 63), Vector2(430, 70), 22, Color(1.0, 0.45, 0.45))
    _draw_jokers(Vector2(725, 122), 0.78)
    message_label = _label(msg, Vector2(80, 220), Vector2(900, 42), 24, Color(1.0, 0.9, 0.58))
    trigger_label = _label("", Vector2(80, 270), Vector2(1100, 90), 22, Color(0.8, 0.95, 1.0))
    for i in range(hand.size()):
        _draw_card(i)
    _button("Play Hand", Vector2(1035, 500), Vector2(170, 58), Callable(self, "_play_selected"))
    _button("Discard", Vector2(1035, 575), Vector2(170, 58), Callable(self, "_discard_selected"))

func _draw_card(i: int) -> void:
    var c := hand[i]
    var pos := Vector2(95 + i * 112, 490)
    if c.selected:
        pos.y -= 34
    var card := Button.new()
    card.position = pos
    card.size = Vector2(96, 150)
    card.text = "%s\n%s" % [c.rank, SUIT_GLYPH[c.suit]]
    card.add_theme_font_size_override("font_size", 25)
    card.modulate = Color(1.0, 1.0, 1.0) if c.selected else Color(0.86, 0.86, 0.92)
    card.add_theme_color_override("font_color", SUIT_COLORS[c.suit])
    card.pressed.connect(func(): _toggle_card(i))
    add_child(card)
    if c.selected:
        _panel(pos + Vector2(6, 6), Vector2(84, 8), Color(1.0, 0.86, 0.25))

func _draw_joker_card(pos: Vector2, title: String, rule: String, color: Color, scale := 1.0) -> void:
    _panel(pos, Vector2(170, 120) * scale, Color(0.12, 0.08, 0.18))
    _panel(pos + Vector2(16, 16) * scale, Vector2(50, 50) * scale, color)
    _label(title, pos + Vector2(76, 14) * scale, Vector2(88, 34) * scale, int(15 * scale), Color(1.0, 0.86, 0.35))
    _label(rule, pos + Vector2(18, 72) * scale, Vector2(140, 42) * scale, int(13 * scale))

func _draw_jokers(pos: Vector2, scale := 1.0) -> void:
    for i in range(active_jokers.size()):
        var j := active_jokers[i]
        var colors := [Color(0.95,0.25,0.55), Color(0.25,0.75,1.0), Color(0.2,0.95,0.5), Color(1.0,0.7,0.2)]
        _draw_joker_card(pos + Vector2(i * 185 * scale, 0), j.name, j.rule, colors[i % colors.size()], scale)

func _toggle_card(i: int) -> void:
    var selected := 0
    for c in hand:
        if c.selected:
            selected += 1
    if not hand[i].selected and selected >= 5:
        message_label.text = "Only five cards can be scored."
        return
    hand[i].selected = not hand[i].selected
    _render_round("Selected cards glow upward. Choose Play Hand or Discard.")

func _discard_selected() -> void:
    if discards_left <= 0:
        message_label.text = "No discards left."
        return
    var did := false
    var replacements := [_card("10","Hearts"), _card("J","Hearts"), _card("Q","Hearts"), _card("4","Clubs"), _card("4","Spades")]
    var r := 0
    for i in range(hand.size()):
        if hand[i].selected:
            hand[i] = replacements[r % replacements.size()]
            r += 1
            did = true
    if did:
        discards_left -= 1
        deck_size -= r
        discard_used = true
    _render_round("Discard drew %d replacement cards. Discards left: %d." % [r, discards_left])

func _play_selected() -> void:
    var selected: Array[Dictionary] = []
    for c in hand:
        if c.selected:
            selected.append(c)
    if selected.is_empty():
        message_label.text = "Select at least one card first."
        return
    var result := _score_cards(selected)
    current_score += result.total
    hands_left -= 1
    _render_round(result.summary)
    trigger_label.text = result.triggers
    _pulse(score_label)
    if current_score >= target_score:
        await get_tree().create_timer(1.0).timeout
        if boss_rule != "":
            _show_result(true)
        else:
            _show_shop()
    elif hands_left <= 0:
        await get_tree().create_timer(1.0).timeout
        _show_result(false)
    else:
        for c in hand:
            c.selected = false

func _score_cards(cards: Array[Dictionary]) -> Dictionary:
    var hand_name := _hand_type(cards)
    var base := {"High Card": [20, 1], "Pair": [35, 2], "Two Pair": [50, 2], "Straight": [65, 3], "Flush": [70, 3], "Full House": [90, 4], "Four of a Kind": [120, 5], "Straight Flush": [150, 6]}
    var chips: int = base[hand_name][0]
    var mult: int = base[hand_name][1]
    var rank_chips := 0
    var has_heart := false
    var has_pair := hand_name in ["Pair", "Two Pair", "Full House", "Four of a Kind"]
    for c in cards:
        if boss_rule != "" and c.suit == "Spades":
            continue
        rank_chips += int(RANK_VALUE[c.rank])
        if c.suit == "Hearts":
            has_heart = true
    chips += rank_chips
    var triggers: Array[String] = []
    chips += 25
    triggers.append("Neon Gremlin +25 chips")
    if has_pair:
        mult *= 2
        triggers.append("Twin Mask x2 mult on paired ranks")
    if has_heart:
        mult += 4
        triggers.append("Heart Thief +4 mult for Hearts")
    if discard_used:
        mult += 3
        triggers.append("Discard Djinn memory +3 mult after a discard")
    var total := chips * mult
    var summary := "%s scored: (%d chips x %d mult) = +%d" % [hand_name, chips, mult, total]
    return {"total": total, "summary": summary, "triggers": "Joker triggers: " + " | ".join(triggers)}

func _hand_type(cards: Array[Dictionary]) -> String:
    var ranks: Array[int] = []
    var rank_counts := {}
    var suit_counts := {}
    for c in cards:
        var rv := int(RANK_VALUE[c.rank])
        ranks.append(rv)
        rank_counts[rv] = rank_counts.get(rv, 0) + 1
        suit_counts[c.suit] = suit_counts.get(c.suit, 0) + 1
    ranks.sort()
    var flush := false
    for s in suit_counts.keys():
        if suit_counts[s] >= 5:
            flush = true
    var straight := cards.size() >= 5 and _is_straight(ranks)
    var counts: Array[int] = []
    for k in rank_counts.keys():
        counts.append(rank_counts[k])
    counts.sort()
    counts.reverse()
    if straight and flush:
        return "Straight Flush"
    if counts[0] >= 4:
        return "Four of a Kind"
    if counts[0] >= 3 and counts.size() > 1 and counts[1] >= 2:
        return "Full House"
    if flush:
        return "Flush"
    if straight:
        return "Straight"
    if counts[0] >= 2 and counts.size() > 1 and counts[1] >= 2:
        return "Two Pair"
    if counts[0] >= 2:
        return "Pair"
    return "High Card"

func _is_straight(ranks: Array[int]) -> bool:
    var unique: Array[int] = []
    for r in ranks:
        if not unique.has(r):
            unique.append(r)
    if unique.size() < 5:
        return false
    for i in range(unique.size() - 4):
        if unique[i + 4] - unique[i] == 4:
            return true
    if unique.has(14) and unique.has(2) and unique.has(3) and unique.has(4) and unique.has(5):
        return true
    return false

func _show_shop() -> void:
    screen = "shop"
    _clear()
    _panel(Vector2.ZERO, Vector2(1280, 720), Color(0.04, 0.03, 0.08))
    _label("Blind Cleared - Night Market", Vector2(80, 50), Vector2(720, 60), 40, Color(1.0, 0.86, 0.35))
    _label("Money $%d. Buy one reward; it persists into the next blind." % money, Vector2(80, 110), Vector2(760, 40), 24)
    _shop_item(Vector2(150, 250), "Discard Djinn", "$5", "New joker: +3 mult after any discard.", func(): _buy_joker())
    _shop_item(Vector2(500, 250), "Gilded Hearts", "$4", "Enhance Heart cards; deck size +1.", func(): _buy_deck())
    _shop_item(Vector2(850, 250), "Chip Coupon", "$3", "Gain $2 and future rewards +1.", func(): _buy_coupon())
    _button("Continue", Vector2(1010, 610), Vector2(170, 58), Callable(self, "_continue_next_blind"))

func _shop_item(pos: Vector2, title: String, price: String, rule: String, cb: Callable) -> void:
    _panel(pos, Vector2(280, 250), Color(0.12, 0.08, 0.18))
    _label(title, pos + Vector2(22, 22), Vector2(230, 42), 28, Color(1.0, 0.86, 0.35))
    _label(price, pos + Vector2(22, 65), Vector2(80, 36), 24, Color(0.75, 1.0, 0.75))
    _label(rule, pos + Vector2(22, 112), Vector2(230, 72), 21)
    _button("Buy", pos + Vector2(70, 190), Vector2(140, 42), cb)

func _buy_joker() -> void:
    if active_jokers.size() < 4:
        active_jokers.append({"name": "Discard Djinn", "rule": "+3 mult after a discard", "kind": "discard"})
    money = max(0, money - 5)
    _show_shop()

func _buy_deck() -> void:
    deck_size += 1
    money = max(0, money - 4)
    _show_shop()

func _buy_coupon() -> void:
    money += 2
    reward_money += 1
    _show_shop()

func _continue_next_blind() -> void:
    ante += 1
    _start_round("boss")

func _show_result(won: bool) -> void:
    screen = "result"
    _clear()
    _panel(Vector2.ZERO, Vector2(1280, 720), Color(0.02, 0.02, 0.05))
    if won:
        _label("VICTORY", Vector2(420, 190), Vector2(480, 80), 64, Color(1.0, 0.86, 0.35))
        _label("The boss blind folds. Your joker engine survives the table.", Vector2(310, 290), Vector2(700, 60), 26)
    else:
        _label("DEFEAT", Vector2(450, 190), Vector2(420, 80), 64, Color(1.0, 0.3, 0.35))
        _label("No hands remain below the target. The table keeps your chips.", Vector2(320, 290), Vector2(680, 60), 26)
    _button("Retry", Vector2(430, 430), Vector2(180, 58), Callable(self, "_show_blind_select"))
    _button("Title", Vector2(680, 430), Vector2(180, 58), Callable(self, "_show_title"))

func _pulse(node: Control) -> void:
    var tw := create_tween()
    node.pivot_offset = node.size / 2
    tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.12)
    tw.tween_property(node, "scale", Vector2.ONE, 0.18)
GDSCRIPT_EOF

cat > "$GAME/demo_outputs/01_title_to_round.json" <<'EOF'
{
  "duration_frames": 360,
  "events": [
    {"frame": 25, "type": "mouse_click", "button": "left", "x": 640, "y": 596},
    {"frame": 80, "type": "mouse_click", "button": "left", "x": 370, "y": 360},
    {"frame": 135, "type": "mouse_click", "button": "left", "x": 140, "y": 560},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 250, "y": 560},
    {"frame": 165, "type": "mouse_click", "button": "left", "x": 360, "y": 560},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 475, "y": 560},
    {"frame": 210, "type": "mouse_click", "button": "left", "x": 1110, "y": 530},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_joker_showcase.json" <<'EOF'
{
  "scenario": "joker_showcase",
  "duration_frames": 330,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 140, "y": 560},
    {"frame": 45, "type": "mouse_click", "button": "left", "x": 250, "y": 560},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 360, "y": 560},
    {"frame": 75, "type": "mouse_click", "button": "left", "x": 475, "y": 560},
    {"frame": 100, "type": "mouse_click", "button": "left", "x": 1110, "y": 530},
    {"frame": 310, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_discard_flush.json" <<'EOF'
{
  "scenario": "flush_setup",
  "duration_frames": 420,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 810, "y": 560},
    {"frame": 45, "type": "mouse_click", "button": "left", "x": 925, "y": 560},
    {"frame": 75, "type": "mouse_click", "button": "left", "x": 1110, "y": 605},
    {"frame": 135, "type": "mouse_click", "button": "left", "x": 140, "y": 560},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 250, "y": 560},
    {"frame": 165, "type": "mouse_click", "button": "left", "x": 360, "y": 560},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 475, "y": 560},
    {"frame": 195, "type": "mouse_click", "button": "left", "x": 585, "y": 560},
    {"frame": 225, "type": "mouse_click", "button": "left", "x": 1110, "y": 530},
    {"frame": 400, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_shop_purchase.json" <<'EOF'
{
  "scenario": "shop_after_win",
  "duration_frames": 300,
  "events": [
    {"frame": 45, "type": "mouse_click", "button": "left", "x": 290, "y": 462},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 1095, "y": 635},
    {"frame": 280, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_boss_blind.json" <<'EOF'
{
  "scenario": "boss_blind",
  "duration_frames": 360,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 140, "y": 560},
    {"frame": 45, "type": "mouse_click", "button": "left", "x": 250, "y": 560},
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 360, "y": 560},
    {"frame": 75, "type": "mouse_click", "button": "left", "x": 475, "y": 560},
    {"frame": 90, "type": "mouse_click", "button": "left", "x": 585, "y": 560},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 1110, "y": 530},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/06_near_defeat.json" <<'EOF'
{
  "scenario": "near_defeat",
  "duration_frames": 300,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 140, "y": 560},
    {"frame": 45, "type": "mouse_click", "button": "left", "x": 250, "y": 560},
    {"frame": 75, "type": "mouse_click", "button": "left", "x": 1110, "y": 530},
    {"frame": 280, "type": "wait"}
  ]
}
EOF

echo "Wrote Rogue Joker Poker reference project to $GAME"
