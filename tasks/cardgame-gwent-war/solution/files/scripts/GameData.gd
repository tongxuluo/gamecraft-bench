extends RefCounted
class_name GameData

# Card types
enum CardType { UNIT, HERO, SPY, WEATHER, HORN, DECOY }
# Rows
enum Row { MELEE, RANGED, SIEGE }

static func get_faction_deck(faction: String, rng: RandomNumberGenerator) -> Array:
	var deck = []
	if faction == "northern":
		deck = _northern_deck()
	else:
		deck = _monsters_deck()
	# Shuffle
	for i in range(deck.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	return deck

static func _northern_deck() -> Array:
	var cards = []
	# Melee units
	cards.append({"name": "Swordsman", "power": 4, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Swordsman", "power": 4, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Knight", "power": 6, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Knight", "power": 6, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Champion", "power": 8, "row": Row.MELEE, "type": CardType.HERO})
	# Ranged units
	cards.append({"name": "Archer", "power": 3, "row": Row.RANGED, "type": CardType.UNIT})
	cards.append({"name": "Archer", "power": 3, "row": Row.RANGED, "type": CardType.UNIT})
	cards.append({"name": "Crossbowman", "power": 5, "row": Row.RANGED, "type": CardType.UNIT})
	cards.append({"name": "Marksman", "power": 7, "row": Row.RANGED, "type": CardType.HERO})
	# Siege units
	cards.append({"name": "Catapult", "power": 4, "row": Row.SIEGE, "type": CardType.UNIT})
	cards.append({"name": "Trebuchet", "power": 6, "row": Row.SIEGE, "type": CardType.UNIT})
	cards.append({"name": "Ballista", "power": 5, "row": Row.SIEGE, "type": CardType.UNIT})
	# Special
	cards.append({"name": "Spy", "power": 2, "row": Row.MELEE, "type": CardType.SPY})
	cards.append({"name": "Frost", "power": 0, "row": Row.MELEE, "type": CardType.WEATHER})
	cards.append({"name": "Horn", "power": 0, "row": Row.RANGED, "type": CardType.HORN})
	return cards

static func _monsters_deck() -> Array:
	var cards = []
	# Melee swarm
	cards.append({"name": "Ghoul", "power": 3, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Ghoul", "power": 3, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Ghoul", "power": 3, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Werewolf", "power": 5, "row": Row.MELEE, "type": CardType.UNIT})
	cards.append({"name": "Vampire Lord", "power": 7, "row": Row.MELEE, "type": CardType.HERO})
	# Ranged
	cards.append({"name": "Harpy", "power": 3, "row": Row.RANGED, "type": CardType.UNIT})
	cards.append({"name": "Harpy", "power": 3, "row": Row.RANGED, "type": CardType.UNIT})
	cards.append({"name": "Griffin", "power": 5, "row": Row.RANGED, "type": CardType.UNIT})
	cards.append({"name": "Dragon", "power": 9, "row": Row.RANGED, "type": CardType.HERO})
	# Siege
	cards.append({"name": "Earth Elemental", "power": 4, "row": Row.SIEGE, "type": CardType.UNIT})
	cards.append({"name": "Fire Elemental", "power": 5, "row": Row.SIEGE, "type": CardType.UNIT})
	cards.append({"name": "Golem", "power": 6, "row": Row.SIEGE, "type": CardType.UNIT})
	# Special
	cards.append({"name": "Spy Bat", "power": 1, "row": Row.RANGED, "type": CardType.SPY})
	cards.append({"name": "Fog", "power": 0, "row": Row.RANGED, "type": CardType.WEATHER})
	cards.append({"name": "War Cry", "power": 0, "row": Row.MELEE, "type": CardType.HORN})
	return cards

static func get_ai_deck(rng: RandomNumberGenerator) -> Array:
	# AI always plays monsters if player is northern, vice versa
	var deck = _monsters_deck()
	for i in range(deck.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	return deck
