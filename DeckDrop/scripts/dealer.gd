class_name Dealer
extends RefCounted
## Dealer target generator. Static lookup keyed off the player's current tier.
##
## We don't generate actual 5-card hands here — only the target score the player
## must beat in their 5-placement round. The hand *name* is shown as flavour text
## ("DEALER: PAIR · 100 to beat") so the player has a sense of what they're up
## against without needing the dealer's cards on screen.

const TIER_TARGETS := [
	{"name": "Low Pair",       "score": 50,   "rank": HandEvaluator.HandRank.PAIR},
	{"name": "Pair",           "score": 100,  "rank": HandEvaluator.HandRank.PAIR},
	{"name": "Two Pair",       "score": 160,  "rank": HandEvaluator.HandRank.TWO_PAIR},
	{"name": "Trips",          "score": 240,  "rank": HandEvaluator.HandRank.THREE_OF_A_KIND},
	{"name": "Straight",       "score": 360,  "rank": HandEvaluator.HandRank.STRAIGHT},
	{"name": "Flush",          "score": 500,  "rank": HandEvaluator.HandRank.FLUSH},
	{"name": "Full House",     "score": 700,  "rank": HandEvaluator.HandRank.FULL_HOUSE},
	{"name": "Quads",          "score": 950,  "rank": HandEvaluator.HandRank.FOUR_OF_A_KIND},
	{"name": "Straight Flush", "score": 1400, "rank": HandEvaluator.HandRank.STRAIGHT_FLUSH},
	{"name": "Royal Flush",    "score": 2500, "rank": HandEvaluator.HandRank.ROYAL_FLUSH},
]


# Returns {name: String, score: int, rank: int} for the given tier.
# Clamps to the table bounds.
static func target_for_tier(tier: int) -> Dictionary:
	var idx := clampi(tier - 1, 0, TIER_TARGETS.size() - 1)
	return TIER_TARGETS[idx].duplicate()
