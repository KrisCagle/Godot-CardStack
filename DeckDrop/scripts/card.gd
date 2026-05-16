class_name Card
extends RefCounted
## Lightweight card value object — suit + rank, plus a Joker flag for wilds (task #8).
## Rank is 0..12 mapping 2..A so straights can compare with simple integer ordering.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }
enum Rank { TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }

const RANK_LABELS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUIT_LABELS := ["♣", "♦", "♥", "♠"]

var suit: int
var rank: int
var is_joker: bool


func _init(p_suit: int = 0, p_rank: int = 0, p_is_joker: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	is_joker = p_is_joker


func rank_label() -> String:
	if is_joker:
		return "★"
	return RANK_LABELS[rank] if rank >= 0 and rank < RANK_LABELS.size() else "?"


func suit_label() -> String:
	if is_joker:
		return "★"
	return SUIT_LABELS[suit] if suit >= 0 and suit < SUIT_LABELS.size() else "?"


func suit_color() -> Color:
	if is_joker:
		return Color(0.95, 0.78, 0.25)
	if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
		return Color(0.85, 0.20, 0.25)
	return Color(0.10, 0.13, 0.20)
