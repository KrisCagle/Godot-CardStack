class_name Dealer
extends RefCounted
## Dealer target generator. Static lookup keyed off the player's current tier.
##
## We don't generate actual 5-card hands here — only the target score the player
## must beat in their 5-placement round. The hand *name* is shown as flavour text
## ("DEALER: PAIR · 100 to beat") so the player has a sense of what they're up
## against without needing the dealer's cards on screen.

const TIER_TARGETS := [
	{"name": "Low Pair",       "score": 50},
	{"name": "Pair",           "score": 100},
	{"name": "Two Pair",       "score": 160},
	{"name": "Trips",          "score": 240},
	{"name": "Straight",       "score": 360},
	{"name": "Flush",          "score": 500},
	{"name": "Full House",     "score": 700},
	{"name": "Quads",          "score": 950},
	{"name": "Straight Flush", "score": 1400},
	{"name": "Royal Flush",    "score": 2500},
]


# Returns {name: String, score: int} for the given tier. Clamps to table bounds.
static func target_for_tier(tier: int) -> Dictionary:
	var idx := clampi(tier - 1, 0, TIER_TARGETS.size() - 1)
	return TIER_TARGETS[idx].duplicate()
