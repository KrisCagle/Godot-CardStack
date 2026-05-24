class_name Card
extends RefCounted
## Card value object — a suit + rank for normal cards, or a special "kind" for
## wilds (Joker — counts as any rank/suit) and bombs (Bomb — clears its column
## on placement, no scoring). Property accessors (is_joker, is_bomb, is_special)
## let consumers branch cleanly without touching the kind int.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }
enum Rank { TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }
enum Kind { NORMAL, JOKER, BOMB, SWEEP, MULTI, STEEL, GLASS, PROMOTE, SHUFFLE }

const RANK_LABELS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUIT_LABELS := ["♣", "♦", "♥", "♠"]

var suit: int
var rank: int
var kind: int

var is_joker: bool:
	get:
		return kind == Kind.JOKER

var is_bomb: bool:
	get:
		return kind == Kind.BOMB

var is_sweep: bool:
	get:
		return kind == Kind.SWEEP

var is_multi: bool:
	get:
		return kind == Kind.MULTI

var is_steel: bool:
	get:
		return kind == Kind.STEEL

var is_glass: bool:
	get:
		return kind == Kind.GLASS

var is_promote: bool:
	get:
		return kind == Kind.PROMOTE

var is_shuffle: bool:
	get:
		return kind == Kind.SHUFFLE

var is_special: bool:
	get:
		return kind != Kind.NORMAL


func _init(p_suit: int = 0, p_rank: int = 0, p_kind: int = Kind.NORMAL) -> void:
	suit = p_suit
	rank = p_rank
	kind = p_kind


static func make_joker() -> Card:
	return Card.new(0, 0, Kind.JOKER)


static func make_bomb() -> Card:
	return Card.new(0, 0, Kind.BOMB)


static func make_sweep() -> Card:
	return Card.new(0, 0, Kind.SWEEP)


# Multi is a real card (rank + suit) that ALSO grants +1 extra combo on
# placement. Pass an RNG (e.g. _specials_rng) for daily-mode determinism.
static func make_multi(rng: RandomNumberGenerator = null) -> Card:
	return _make_random_kind(Kind.MULTI, rng)


# Steel: real card with rank+suit that NEVER clears. Permanent blocker;
# strategic for parking high-value cards in spots you don't want disturbed.
static func make_steel(rng: RandomNumberGenerator = null) -> Card:
	return _make_random_kind(Kind.STEEL, rng)


# Glass: real card that triples the score of any hand it participates in,
# then clears with the hand (glass breaks).
static func make_glass(rng: RandomNumberGenerator = null) -> Card:
	return _make_random_kind(Kind.GLASS, rng)


# Promote: real card that on placement bumps all 4-neighbor non-special
# cards by +1 rank (capped at Ace).
static func make_promote(rng: RandomNumberGenerator = null) -> Card:
	return _make_random_kind(Kind.PROMOTE, rng)


# Shuffle: consumed on placement (doesn't enter the grid); reorders all
# cards currently on the grid into random columns.
static func make_shuffle() -> Card:
	return Card.new(0, 0, Kind.SHUFFLE)


static func _make_random_kind(k: int, rng: RandomNumberGenerator) -> Card:
	var s: int
	var r: int
	if rng != null:
		s = rng.randi() % 4
		r = rng.randi() % 13
	else:
		s = randi() % 4
		r = randi() % 13
	return Card.new(s, r, k)


func rank_label() -> String:
	if kind == Kind.JOKER:
		return "★"
	if kind == Kind.BOMB:
		return "✸"
	if kind == Kind.SWEEP:
		return "≈"
	if kind == Kind.SHUFFLE:
		return "↻"
	# MULTI, STEEL, GLASS, PROMOTE keep their real rank label so the player
	# can plan around their value in scoring.
	return RANK_LABELS[rank] if rank >= 0 and rank < RANK_LABELS.size() else "?"


func suit_label() -> String:
	if kind == Kind.JOKER:
		return "★"
	if kind == Kind.BOMB:
		return "✸"
	if kind == Kind.SWEEP:
		return "≈"
	if kind == Kind.SHUFFLE:
		return "↻"
	return SUIT_LABELS[suit] if suit >= 0 and suit < SUIT_LABELS.size() else "?"


func suit_color() -> Color:
	if kind == Kind.JOKER:
		return Color(0.95, 0.78, 0.25)
	if kind == Kind.BOMB:
		return Color(0.85, 0.30, 0.30)
	if kind == Kind.SWEEP:
		return Color(0.30, 0.85, 0.70)
	if kind == Kind.SHUFFLE:
		return Color(0.85, 0.55, 1.00)
	# NORMAL, MULTI, STEEL, GLASS, PROMOTE use theme suit colors so the
	# real rank/suit reads through their colored borders.
	var theme := Themes.current()
	if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
		return theme.card_text_red
	return theme.card_text_black
