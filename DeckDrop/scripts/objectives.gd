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
]


# Returns 3 random non-duplicate objectives from POOL.
static func roll_for_run() -> Array:
	var pool := POOL.duplicate(true)
	pool.shuffle()
	return pool.slice(0, 3)
