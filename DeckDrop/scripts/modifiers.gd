class_name Modifiers
extends RefCounted
## Per-run modifiers — a single mutator rolled at the start of each run that
## tweaks one or two game-feel knobs. Daily mode picks deterministically from
## today's date; standard mode rolls random.
##
## Modifier dict fields (all optional, default = no effect):
##   combo_time            — override the combo timer duration (seconds)
##   combo_increment_mult  — multiply COMBO_INCREMENT (per-combo bonus step)
##   combos_off            — disable the combo system entirely
##   base_mult             — multiply all hand scoring (post-combo, post-tier)
##   special_rate_mult     — multiply Joker/Bomb spawn rate
##   joker_ratio           — chance a special is a Joker (default 0.6 in game.gd)
##   round_length          — override placements per dealer round
##   cascade_mult_bonus    — extra +X added to per-cascade-tier multiplier

const POOL := [
	{
		"id": "hot_combo", "name": "Hot Combo",
		"description": "Combo timer 2s. +50% per combo step.",
		"combo_time": 2.0, "combo_increment_mult": 1.5,
	},
	{
		"id": "power_surge", "name": "Power Surge",
		"description": "+30% base score on every hand.",
		"base_mult": 1.30,
	},
	{
		"id": "steady_hand", "name": "Steady Hand",
		"description": "Combos OFF, +50% base score.",
		"combos_off": true, "base_mult": 1.50,
	},
	{
		"id": "joker_wild", "name": "Joker Wild",
		"description": "Specials 3× as often, mostly Jokers.",
		"special_rate_mult": 3.0, "joker_ratio": 0.85,
	},
	{
		"id": "bomb_squad", "name": "Bomb Squad",
		"description": "Specials 3× as often, mostly Bombs. +15% base.",
		"special_rate_mult": 3.0, "joker_ratio": 0.15, "base_mult": 1.15,
	},
	{
		"id": "tight_shoe", "name": "Tight Shoe",
		"description": "Specials half as often. +20% base score.",
		"special_rate_mult": 0.5, "base_mult": 1.20,
	},
	{
		"id": "wild_round", "name": "Wild Round",
		"description": "Dealer rounds only 7 cards. +25% base.",
		"round_length": 7, "base_mult": 1.25,
	},
	{
		"id": "cascade_king", "name": "Cascade King",
		"description": "Cascade tiers +50% stronger each step.",
		"cascade_mult_bonus": 0.5,
	},
]


# Random modifier for a standard run. Always returns one (no "none" option).
static func roll_random() -> Dictionary:
	var idx := randi() % POOL.size()
	return POOL[idx].duplicate(true)


# Deterministic modifier for a given date (daily mode).
static func for_daily(date_str: String) -> Dictionary:
	var idx := absi(date_str.hash()) % POOL.size()
	return POOL[idx].duplicate(true)


static func by_id(id: String) -> Dictionary:
	for m in POOL:
		if String(m.id) == id:
			return m.duplicate(true)
	return {}
