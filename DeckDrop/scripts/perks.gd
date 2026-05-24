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
	{
		"id": "big_spender", "name": "Big Spender",
		"description": "+20% base score (stacks)",
		"color": Color(1.00, 0.85, 0.40),
	},
	{
		"id": "echo_combo", "name": "Echo Combo",
		"description": "Surge cards grant +2 combo (was +1)",
		"color": Color(0.85, 0.45, 1.00),
	},
	{
		"id": "anchor_free", "name": "Anchor Free",
		"description": "Anchors clear like normal cards",
		"color": Color(0.65, 0.78, 0.92),
	},
	{
		"id": "royal_treatment", "name": "Royal Treatment",
		"description": "Face-card hands score +50%",
		"color": Color(0.95, 0.78, 0.30),
	},
	{
		"id": "wider_view", "name": "Wider View",
		"description": "+1 visible preview slot",
		"color": Color(0.55, 0.95, 0.75),
	},
	{
		"id": "time_stretch", "name": "Time Stretch",
		"description": "Combo timer pauses during cascades",
		"color": Color(0.50, 0.95, 1.00),
	},
	{
		"id": "xp_doubler", "name": "XP Multiplier",
		"description": "Objectives give +50% XP",
		"color": Color(0.95, 0.85, 0.45),
	},
	{
		"id": "lucky_draw", "name": "Lucky Draw",
		"description": "Next 5 cards are normal (no specials)",
		"color": Color(0.75, 1.00, 0.75),
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
