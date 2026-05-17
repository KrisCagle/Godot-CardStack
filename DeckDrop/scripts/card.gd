class_name Card
extends RefCounted
## Card value object — a suit + rank for normal cards, or a special "kind" for
## wilds (Joker — counts as any rank/suit) and bombs (Bomb — clears its column
## on placement, no scoring). Property accessors (is_joker, is_bomb, is_special)
## let consumers branch cleanly without touching the kind int.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }
enum Rank { TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }
enum Kind { NORMAL, JOKER, BOMB }

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


func rank_label() -> String:
	if kind == Kind.JOKER:
		return "★"
	if kind == Kind.BOMB:
		return "✸"
	return RANK_LABELS[rank] if rank >= 0 and rank < RANK_LABELS.size() else "?"


func suit_label() -> String:
	if kind == Kind.JOKER:
		return "★"
	if kind == Kind.BOMB:
		return "✸"
	return SUIT_LABELS[suit] if suit >= 0 and suit < SUIT_LABELS.size() else "?"


func suit_color() -> Color:
	if kind == Kind.JOKER:
		return Color(0.95, 0.78, 0.25)
	if kind == Kind.BOMB:
		return Color(0.85, 0.30, 0.30)
	if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
		return Color(0.85, 0.20, 0.25)
	return Color(0.10, 0.13, 0.20)
