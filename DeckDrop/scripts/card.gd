class_name Card
extends RefCounted
## Card value object — a suit + rank for normal cards, or a special "kind" for
## wilds (Joker — counts as any rank/suit) and bombs (Bomb — clears its column
## on placement, no scoring). Property accessors (is_joker, is_bomb, is_special)
## let consumers branch cleanly without touching the kind int.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }
enum Rank { TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }
enum Kind { NORMAL, JOKER, BOMB, SWEEP, MULTI }

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
	var s: int
	var r: int
	if rng != null:
		s = rng.randi() % 4
		r = rng.randi() % 13
	else:
		s = randi() % 4
		r = randi() % 13
	return Card.new(s, r, Kind.MULTI)


func rank_label() -> String:
	if kind == Kind.JOKER:
		return "★"
	if kind == Kind.BOMB:
		return "✸"
	if kind == Kind.SWEEP:
		return "≈"
	# MULTI keeps its real rank label so the player can plan around its value.
	return RANK_LABELS[rank] if rank >= 0 and rank < RANK_LABELS.size() else "?"


func suit_label() -> String:
	if kind == Kind.JOKER:
		return "★"
	if kind == Kind.BOMB:
		return "✸"
	if kind == Kind.SWEEP:
		return "≈"
	return SUIT_LABELS[suit] if suit >= 0 and suit < SUIT_LABELS.size() else "?"


func suit_color() -> Color:
	if kind == Kind.JOKER:
		return Color(0.95, 0.78, 0.25)
	if kind == Kind.BOMB:
		return Color(0.85, 0.30, 0.30)
	if kind == Kind.SWEEP:
		return Color(0.30, 0.85, 0.70)
	# NORMAL and MULTI use theme-driven suit colors so MULTI reads as a
	# beefed-up regular card.
	var theme := Themes.current()
	if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
		return theme.card_text_red
	return theme.card_text_black
