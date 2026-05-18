class_name Themes
extends RefCounted
## Visual themes — card face/border/text colors + table felt. Auto-applies the
## highest-unlocked theme (gated by SaveData.level), so leveling up visibly
## changes the look of the game without needing a picker UI.
##
## Specials (Joker, Bomb) override the face/border in CardView so their distinct
## warm tints stay readable across every theme.

const LIST := [
	{
		"id": "classic",
		"name": "Classic",
		"unlock_level": 1,
		"card_face": Color(0.96, 0.96, 0.94),
		"card_border": Color(0.20, 0.20, 0.25),
		"card_text_red": Color(0.85, 0.20, 0.25),
		"card_text_black": Color(0.10, 0.13, 0.20),
		"felt": Color(0.04, 0.07, 0.10),
	},
	{
		"id": "gold",
		"name": "Gold Trim",
		"unlock_level": 3,
		"card_face": Color(0.98, 0.96, 0.88),
		"card_border": Color(0.75, 0.58, 0.20),
		"card_text_red": Color(0.78, 0.18, 0.22),
		"card_text_black": Color(0.20, 0.15, 0.05),
		"felt": Color(0.10, 0.05, 0.14),
	},
	{
		"id": "neon",
		"name": "Neon",
		"unlock_level": 5,
		"card_face": Color(0.10, 0.10, 0.18),
		"card_border": Color(0.10, 0.85, 1.00),
		"card_text_red": Color(1.00, 0.40, 0.70),
		"card_text_black": Color(0.30, 0.95, 1.00),
		"felt": Color(0.14, 0.04, 0.22),
	},
	{
		"id": "crimson",
		"name": "Crimson",
		"unlock_level": 8,
		"card_face": Color(0.98, 0.93, 0.93),
		"card_border": Color(0.65, 0.10, 0.15),
		"card_text_red": Color(0.78, 0.16, 0.22),
		"card_text_black": Color(0.15, 0.07, 0.10),
		"felt": Color(0.10, 0.02, 0.04),
	},
	{
		"id": "forest",
		"name": "Forest",
		"unlock_level": 12,
		"card_face": Color(0.96, 0.96, 0.90),
		"card_border": Color(0.18, 0.45, 0.22),
		"card_text_red": Color(0.85, 0.20, 0.25),
		"card_text_black": Color(0.08, 0.18, 0.12),
		"felt": Color(0.04, 0.10, 0.06),
	},
]


# Returns the highest-unlock-level theme the player has access to.
static func current() -> Dictionary:
	var best: Dictionary = LIST[0]
	for t in LIST:
		var ul: int = int(t.get("unlock_level", 1))
		if SaveData.level >= ul and ul >= int(best.get("unlock_level", 1)):
			best = t
	return best


static func by_id(id: String) -> Dictionary:
	for t in LIST:
		if String(t.id) == id:
			return t
	return LIST[0]


static func is_unlocked(theme_id: String) -> bool:
	var t := by_id(theme_id)
	return SaveData.level >= int(t.get("unlock_level", 1))


# Returns the next-to-unlock theme based on the given level (or {} if all
# themes are already available).
static func next_unlock_for_level(level: int) -> Dictionary:
	var next: Dictionary = {}
	for t in LIST:
		var ul: int = int(t.get("unlock_level", 1))
		if ul <= level:
			continue
		if next.is_empty() or ul < int(next.get("unlock_level", 999999)):
			next = t
	return next
