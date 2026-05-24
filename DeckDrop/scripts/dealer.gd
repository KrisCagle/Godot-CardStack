class_name Dealer
extends RefCounted
## Named dealer characters. Each dealer occupies one tier; player progresses
## through the roster by beating successive dealers. Each entry has a color
## (used to tint the HUD dealer line + the round-transition splash) and a
## one-liner description for flavour.
##
## All target scores match the previous numeric curve so existing balance
## tuning carries over — this refactor adds personality without shifting math.

const ROSTER := [
	{
		"id": "apprentice", "name": "The Apprentice",
		"score": 25,   "color": Color(0.65, 0.85, 1.00),
		"description": "Pair of low cards — easy mark",
	},
	{
		"id": "hustler", "name": "The Hustler",
		"score": 100,  "color": Color(0.95, 0.78, 0.45),
		"description": "Quick to bet, quick to bluff",
	},
	{
		"id": "sharp", "name": "The Sharp",
		"score": 160,  "color": Color(0.55, 0.95, 0.70),
		"description": "Reads the table cold",
		"is_boss": true, "rule_id": "no_rows", "rule_text": "Rows don't score",
	},
	{
		"id": "magician", "name": "The Magician",
		"score": 240,  "color": Color(0.80, 0.55, 1.00),
		"description": "Sleight of hand",
	},
	{
		"id": "whale", "name": "The Whale",
		"score": 360,  "color": Color(0.45, 0.85, 1.00),
		"description": "Plays big — pays bigger",
		"is_boss": true, "rule_id": "no_columns", "rule_text": "Columns don't score",
	},
	{
		"id": "cheat", "name": "The Cheat",
		"score": 500,  "color": Color(1.00, 0.55, 0.50),
		"description": "Always one card up",
		"is_boss": true, "rule_id": "no_discards", "rule_text": "Discards locked",
	},
	{
		"id": "royal", "name": "The Royal",
		"score": 700,  "color": Color(0.95, 0.85, 0.40),
		"description": "Demands the crown",
	},
	{
		"id": "boss", "name": "The Boss",
		"score": 950,  "color": Color(1.00, 0.45, 0.55),
		"description": "House never loses",
		"is_boss": true, "rule_id": "high_only", "rule_text": "Only Flush+ counts",
	},
	{
		"id": "ace", "name": "The Ace",
		"score": 1400, "color": Color(0.45, 1.00, 0.85),
		"description": "Top of the deck",
		"is_boss": true, "rule_id": "no_combos", "rule_text": "Combos disabled",
	},
	{
		"id": "legend", "name": "The Legend",
		"score": 2500, "color": Color(1.00, 0.85, 0.25),
		"description": "Royalty of the floor",
		"is_boss": true, "rule_id": "royal_only", "rule_text": "Only Trips+ count",
	},
]


# Returns {id, name, score, color, description} for the given tier.
# Clamps to roster bounds.
static func target_for_tier(tier: int) -> Dictionary:
	var idx := clampi(tier - 1, 0, ROSTER.size() - 1)
	return ROSTER[idx].duplicate(true)
