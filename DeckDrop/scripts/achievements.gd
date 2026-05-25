class_name Achievements
extends RefCounted
## Static achievement registry. Each entry: {id, name, desc, xp}.
## game.gd calls SaveData.claim_achievement(id) at the right event; if claimed
## for the first time, the caller awards `xp` and shows the unlock popup.

const LIST := [
	# Original 9 ----------------------------------------------------------------
	{"id": "first_dealer",  "name": "First Blood",   "desc": "Beat your first dealer round",   "xp": 50},
	{"id": "wild_thing",    "name": "Wild Thing",    "desc": "Score a hand using a Joker",     "xp": 75},
	{"id": "bombs_away",    "name": "Bombs Away",    "desc": "Detonate your first Bomb",       "xp": 50},
	{"id": "hot_streak",    "name": "Hot Streak",    "desc": "Reach combo ×5",                 "xp": 100},
	{"id": "triple_cascade","name": "Avalanche",     "desc": "Trigger a 3-tier cascade",       "xp": 100},
	{"id": "big_spender",   "name": "Big Spender",   "desc": "Score 5,000 in one run",         "xp": 200},
	{"id": "marathon",      "name": "Marathon",      "desc": "Survive to dealer tier 5",       "xp": 200},
	{"id": "royal_flush",   "name": "Royalty",       "desc": "Clear a Royal Flush",            "xp": 500},
	# Centenarian fires when _run_placements >= 100 — placement-based, not level.
	{"id": "centenarian",   "name": "Centenarian",   "desc": "Place 100 cards in a single run","xp": 300},

	# +15 from the threshold/event hooks wired into game.gd in c1df7ed ----------
	{"id": "cascading",     "name": "Mega Cascade",  "desc": "Trigger a 5-tier cascade",       "xp": 200},
	{"id": "mega_combo",    "name": "Mega Combo",    "desc": "Reach combo ×15",                "xp": 300},
	{"id": "bonus_hunter",  "name": "Bonus Hunter",  "desc": "Trigger 10 Bonus cards lifetime","xp": 150},
	{"id": "pair_up",       "name": "Pair Up",       "desc": "Score 50 Pairs lifetime",        "xp": 150},
	{"id": "flush_master",  "name": "Flush Master",  "desc": "Score 20 Flushes lifetime",      "xp": 200},
	{"id": "wager_wizard",  "name": "Wager Wizard",  "desc": "Win 5 wager rounds",             "xp": 200},
	{"id": "high_roller",   "name": "High Roller",   "desc": "Place a wager of 1,000+",        "xp": 250},
	{"id": "boss_slayer",   "name": "Boss Slayer",   "desc": "Beat 6 unique boss dealers",     "xp": 500},
	{"id": "theme_collector","name": "Theme Collector","desc": "Reach level 12 (unlock the Forest theme)", "xp": 300},
	{"id": "theme_master",  "name": "Theme Master",   "desc": "Reach level 30 (unlock every theme)",       "xp": 750},
	{"id": "anchor_master", "name": "Anchor Master", "desc": "Place 10 Anchor cards lifetime", "xp": 100},
	{"id": "crown_royalty", "name": "Crown Royalty", "desc": "Place 10 Crown cards lifetime",  "xp": 150},
	{"id": "sweep_crew",    "name": "Sweep Crew",    "desc": "Use 10 Sweep cards lifetime",    "xp": 100},
	{"id": "shuffler",      "name": "Shuffler",      "desc": "Use 5 Shuffle cards lifetime",   "xp": 100},
	{"id": "mirror_master", "name": "Mirror Master", "desc": "Place 5 Mirror cards lifetime",  "xp": 100},
	{"id": "burst_king",    "name": "Burst King",    "desc": "Trigger 5 Burst cards lifetime", "xp": 100},
]


static func by_id(id: String) -> Dictionary:
	for a in LIST:
		if String(a.id) == id:
			return a
	return {}
