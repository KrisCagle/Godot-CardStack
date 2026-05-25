class_name Objectives
extends RefCounted
## Per-run objectives. Roll 3 random at run start; each one tracks against a
## game event type and pays out bonus XP when its target is met.
##
## Event types consumed by game.gd._update_objective:
##   hand_count        — match `target_name` to scored hand name; +1 per
##   max_combo         — track highest combo reached
##   max_cascade       — track highest cascade tier reached
##   single_hand_score — track highest single scoring earn this run
##   dealers_beaten    — +1 per dealer beat
##   placements        — +1 per card placed
##   jokers_placed     — +1 per Joker placed
##   bombs_detonated   — +1 per Bomb detonated
##   anchors_placed    — +1 per Anchor placed
##   flares_placed     — +1 per Flare placed
##   crowns_placed     — +1 per Crown placed
##   waves_used        — +1 per Sweep used
##   shuffles_used     — +1 per Shuffle used
##   perks_picked      — +1 per perk picked from the shop

const POOL := [
	{"id": "flush_one",      "name": "Score a Flush",            "type": "hand_count", "target_name": "Flush",            "target": 1,    "xp": 100},
	{"id": "flush_three",    "name": "Score 3 Flushes",          "type": "hand_count", "target_name": "Flush",            "target": 3,    "xp": 250},
	{"id": "straight_one",   "name": "Score a Straight",         "type": "hand_count", "target_name": "Straight",         "target": 1,    "xp": 100},
	{"id": "full_house_one", "name": "Score a Full House",       "type": "hand_count", "target_name": "Full House",       "target": 1,    "xp": 200},
	{"id": "quads_one",      "name": "Score Four of a Kind",     "type": "hand_count", "target_name": "Four of a Kind",   "target": 1,    "xp": 300},
	{"id": "trips_three",    "name": "Score 3 Trips",            "type": "hand_count", "target_name": "Three of a Kind",  "target": 3,    "xp": 200},
	{"id": "combo_5",        "name": "Reach Combo ×5",           "type": "max_combo",                                     "target": 5,    "xp": 150},
	{"id": "combo_10",       "name": "Reach Combo ×10",          "type": "max_combo",                                     "target": 10,   "xp": 300},
	{"id": "dealers_3",      "name": "Beat 3 Dealers",           "type": "dealers_beaten",                                "target": 3,    "xp": 200},
	{"id": "dealers_5",      "name": "Beat 5 Dealers",           "type": "dealers_beaten",                                "target": 5,    "xp": 400},
	{"id": "score_2000",     "name": "Score 2000 in one hand",   "type": "single_hand_score",                             "target": 2000, "xp": 250},
	{"id": "place_30",       "name": "Place 30 cards",           "type": "placements",                                    "target": 30,   "xp": 100},
	{"id": "place_50",       "name": "Place 50 cards",           "type": "placements",                                    "target": 50,   "xp": 200},
	{"id": "joker_use",      "name": "Place a Joker",            "type": "jokers_placed",                                 "target": 1,    "xp": 100},
	{"id": "bomb_use",       "name": "Detonate a Bomb",          "type": "bombs_detonated",                               "target": 1,    "xp": 100},
	{"id": "cascade_3",      "name": "Trigger a 3-tier cascade", "type": "max_cascade",                                   "target": 3,    "xp": 250},
	{"id": "anchor_count",   "name": "Place 3 Anchors",          "type": "anchors_placed",                                "target": 3,    "xp": 150},
	{"id": "flare_count",    "name": "Place 2 Flares",           "type": "flares_placed",                                 "target": 2,    "xp": 200},
	{"id": "crown_count",    "name": "Place 2 Crowns",           "type": "crowns_placed",                                 "target": 2,    "xp": 150},
	{"id": "shuffle_use",    "name": "Use a Shuffle",            "type": "shuffles_used",                                 "target": 1,    "xp": 100},
	{"id": "wave_use",       "name": "Use a Sweep",              "type": "waves_used",                                    "target": 1,    "xp": 100},
	{"id": "perks_picked",   "name": "Pick 5 perks",             "type": "perks_picked",                                  "target": 5,    "xp": 250},
]


# Returns 3 random non-duplicate objectives from POOL.
static func roll_for_run() -> Array:
	var pool := POOL.duplicate(true)
	pool.shuffle()
	return pool.slice(0, 3)
