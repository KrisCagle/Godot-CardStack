class_name HandEvaluator
extends RefCounted
## Classifies a 5-card hand as a poker rank and computes its score.
##
## Score formula: base × multiplier
##   base       = sum of card values (2..14, with J=11, Q=12, K=13, A=14)
##   multiplier = from the hand rank table (see RANK_MULTIPLIER)
##
## Wild cards (Joker) are handled by brute-force substitution: for each Joker
## position, try all 52 rank/suit combinations and keep the result with the
## highest score. With 1-2 Jokers per hand (the realistic case in DeckDrop) the
## total work is small (52 or 2704 evaluations) and runs instantly.

enum HandRank {
	NONE,
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH,
}

const RANK_MULTIPLIER := {
	HandRank.NONE: 0,
	HandRank.HIGH_CARD: 0,
	HandRank.PAIR: 1,
	HandRank.TWO_PAIR: 3,
	HandRank.THREE_OF_A_KIND: 5,
	HandRank.STRAIGHT: 10,
	HandRank.FLUSH: 15,
	HandRank.FULL_HOUSE: 25,
	HandRank.FOUR_OF_A_KIND: 50,
	HandRank.STRAIGHT_FLUSH: 100,
	HandRank.ROYAL_FLUSH: 250,
}

const RANK_NAMES := {
	HandRank.NONE: "None",
	HandRank.HIGH_CARD: "High Card",
	HandRank.PAIR: "Pair",
	HandRank.TWO_PAIR: "Two Pair",
	HandRank.THREE_OF_A_KIND: "Three of a Kind",
	HandRank.STRAIGHT: "Straight",
	HandRank.FLUSH: "Flush",
	HandRank.FULL_HOUSE: "Full House",
	HandRank.FOUR_OF_A_KIND: "Four of a Kind",
	HandRank.STRAIGHT_FLUSH: "Straight Flush",
	HandRank.ROYAL_FLUSH: "Royal Flush",
}


# Returns {rank: HandRank, name: String, multiplier: int, base: int, score: int}
static func evaluate(cards: Array) -> Dictionary:
	if cards.size() != 5:
		return _make_result(HandRank.NONE, 0)
	for c in cards:
		if c == null:
			return _make_result(HandRank.NONE, 0)

	var jokers: Array = []
	for i in cards.size():
		if cards[i].is_joker:
			jokers.append(i)

	if jokers.is_empty():
		return _make_result(_classify(cards), _base_score(cards))

	return _best_substitution(cards.duplicate(), jokers, 0)


# Quick name lookup for popups/logs.
static func name_of(rank: int) -> String:
	return RANK_NAMES.get(rank, "?")


# --- internals ---


static func _best_substitution(cards: Array, joker_indices: Array, idx: int) -> Dictionary:
	if idx >= joker_indices.size():
		return _make_result(_classify(cards), _base_score(cards))

	var best := _make_result(HandRank.NONE, 0)
	var pos: int = joker_indices[idx]
	for suit in 4:
		for rank in 13:
			cards[pos] = Card.new(suit, rank, false)
			var result := _best_substitution(cards, joker_indices, idx + 1)
			if result.score > best.score \
				or (result.score == best.score and result.rank > best.rank):
				best = result
	return best


static func _make_result(rank: int, base: int) -> Dictionary:
	var mult: int = RANK_MULTIPLIER.get(rank, 0)
	return {
		"rank": rank,
		"name": RANK_NAMES.get(rank, "?"),
		"multiplier": mult,
		"base": base,
		"score": base * mult,
	}


static func _base_score(cards: Array) -> int:
	var total := 0
	for c in cards:
		total += c.rank + 2  # 0..12 → 2..14
	return total


static func _classify(cards: Array) -> int:
	var rank_counts: Dictionary = {}
	var suit_counts: Dictionary = {}
	var ranks: Array = []

	for c in cards:
		rank_counts[c.rank] = int(rank_counts.get(c.rank, 0)) + 1
		suit_counts[c.suit] = int(suit_counts.get(c.suit, 0)) + 1
		ranks.append(c.rank)

	var is_flush := suit_counts.size() == 1
	var is_straight := _is_straight(ranks)

	var counts: Array = rank_counts.values()
	counts.sort_custom(func(a, b): return a > b)

	if is_flush and is_straight:
		var sorted_ranks := ranks.duplicate()
		sorted_ranks.sort()
		# Royal flush only when high straight (10..A), not when wheel (A-low)
		if sorted_ranks[0] == Card.Rank.TEN and sorted_ranks[4] == Card.Rank.ACE:
			return HandRank.ROYAL_FLUSH
		return HandRank.STRAIGHT_FLUSH

	if counts[0] == 4:
		return HandRank.FOUR_OF_A_KIND
	if counts.size() >= 2 and counts[0] == 3 and counts[1] == 2:
		return HandRank.FULL_HOUSE
	if is_flush:
		return HandRank.FLUSH
	if is_straight:
		return HandRank.STRAIGHT
	if counts[0] == 3:
		return HandRank.THREE_OF_A_KIND
	if counts.size() >= 2 and counts[0] == 2 and counts[1] == 2:
		return HandRank.TWO_PAIR
	if counts[0] == 2:
		return HandRank.PAIR
	return HandRank.HIGH_CARD


static func _is_straight(ranks: Array) -> bool:
	if ranks.size() != 5:
		return false
	var sorted_ranks := ranks.duplicate()
	sorted_ranks.sort()
	# All 5 must be distinct ranks.
	for i in range(1, 5):
		if sorted_ranks[i] == sorted_ranks[i - 1]:
			return false
	# Wheel straight: 2-3-4-5-A
	if sorted_ranks[0] == Card.Rank.TWO \
		and sorted_ranks[1] == Card.Rank.THREE \
		and sorted_ranks[2] == Card.Rank.FOUR \
		and sorted_ranks[3] == Card.Rank.FIVE \
		and sorted_ranks[4] == Card.Rank.ACE:
		return true
	return sorted_ranks[4] - sorted_ranks[0] == 4
