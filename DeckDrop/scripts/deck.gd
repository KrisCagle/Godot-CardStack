class_name Deck
extends RefCounted
## 52-card shoe. Auto-refills (reshuffles a fresh deck) when empty so endless mode
## never runs out of draws. Pass a non-zero seed for deterministic order (daily mode).

var _cards: Array[Card] = []
var _rng: RandomNumberGenerator


func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_refill_and_shuffle()


func draw_card() -> Card:
	if _cards.is_empty():
		_refill_and_shuffle()
	return _cards.pop_back()


func remaining() -> int:
	return _cards.size()


func _refill_and_shuffle() -> void:
	_cards.clear()
	for s in 4:
		for r in 13:
			_cards.append(Card.new(s, r))
	# Fisher-Yates shuffle
	for i in range(_cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _cards[i]
		_cards[i] = _cards[j]
		_cards[j] = tmp
