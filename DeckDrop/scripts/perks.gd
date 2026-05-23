class_name Perks
extends RefCounted
## Mid-run perk catalog. After each dealer beat, the perk shop draws 3 random
## perks from POOL and the player picks one. Effects apply for the remainder
## of the run (stacking with the run modifier and with previously-picked perks).
##
## Effects are interpreted in game.gd._apply_perk via the `id` field, so adding
## a new perk = add a POOL entry + a match arm in _apply_perk.

const POOL := [
	{
		"id": "discard_master", "name": "Discard Master",
		"description": "+2 discards (max 5)",
		"color": Color(0.55, 0.95, 0.70),
	},
	{
		"id": "hold_master", "name": "Hold Master",
		"description": "+2 holds (max 5)",
		"color": Color(0.55, 0.95, 0.70),
	},
	{
		"id": "refill_actions", "name": "Refill Actions",
		"description": "Discards + Holds restored to full",
		"color": Color(0.75, 1.00, 0.55),
	},
	{
		"id": "combo_time", "name": "Combo Time",
		"description": "Combo timer +1.5 seconds",
		"color": Color(0.95, 0.65, 1.00),
	},
	{
		"id": "combo_power", "name": "Combo Power",
		"description": "Combo bonus +0.1 per step",
		"color": Color(0.95, 0.65, 1.00),
	},
	{
		"id": "base_power", "name": "Base Power",
		"description": "+15% base score on every hand",
		"color": Color(1.00, 0.85, 0.40),
	},
	{
		"id": "joker_magnet", "name": "Joker Magnet",
		"description": "Specials are mostly Jokers",
		"color": Color(1.00, 0.85, 0.30),
	},
	{
		"id": "cascade_king", "name": "Cascade King",
		"description": "Cascade tiers +30% stronger",
		"color": Color(0.45, 0.85, 1.00),
	},
	{
		"id": "dealer_pity", "name": "Dealer Pity",
		"description": "Next dealer's target -20%",
		"color": Color(1.00, 0.70, 0.45),
	},
]


# Returns 3 random non-duplicate perks from POOL.
static func roll_choice() -> Array:
	var pool := POOL.duplicate(true)
	pool.shuffle()
	return pool.slice(0, 3)


static func by_id(id: String) -> Dictionary:
	for p in POOL:
		if String(p.id) == id:
			return p.duplicate(true)
	return {}
