class_name Achievements
extends RefCounted
## Static achievement registry. Each entry: {id, name, desc, xp}.
## game.gd calls SaveData.claim_achievement(id) at the right event; if claimed
## for the first time, the caller awards `xp` and shows the unlock popup.

const LIST := [
	{"id": "first_dealer",  "name": "First Blood",   "desc": "Beat your first dealer round",   "xp": 50},
	{"id": "wild_thing",    "name": "Wild Thing",    "desc": "Score a hand using a Joker",     "xp": 75},
	{"id": "bombs_away",    "name": "Bombs Away",    "desc": "Detonate your first Bomb",       "xp": 50},
	{"id": "hot_streak",    "name": "Hot Streak",    "desc": "Reach combo ×5",                 "xp": 100},
	{"id": "triple_cascade","name": "Avalanche",     "desc": "Trigger a 3-tier cascade",       "xp": 100},
	{"id": "big_spender",   "name": "Big Spender",   "desc": "Score 5,000 in one run",         "xp": 200},
	{"id": "marathon",      "name": "Marathon",      "desc": "Survive to dealer tier 5",       "xp": 200},
	{"id": "royal_flush",   "name": "Royalty",       "desc": "Clear a Royal Flush",            "xp": 500},
	{"id": "centenarian",   "name": "Centenarian",   "desc": "Reach player level 10",          "xp": 300},
]


static func by_id(id: String) -> Dictionary:
	for a in LIST:
		if String(a.id) == id:
			return a
	return {}
