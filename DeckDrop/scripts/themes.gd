class_name Themes
extends RefCounted
## Visual themes — card face/border/text colors + table felt + extended styling
## (border thickness, inset ring, face accent overlay). Auto-applies the
## highest-unlocked theme (gated by SaveData.level), but the player can pin
## any unlocked theme from the Progress panel.
##
## Schema notes:
##   card_face, card_border, card_text_red, card_text_black, felt — required.
##   border_width — optional float, defaults to 2.0 in CardView. Chunky frames
##                  (4-5) make the theme read as "ornate" vs "minimal".
##   inner_ring  — optional Color, defaults to transparent (none). When set
##                 to a visible alpha, CardView draws a thin inset ring just
##                 inside the main border for ornate / frosted styles.
##   face_accent — optional Color, defaults to transparent. When set, drawn
##                 as a faint overlay across the lower face for tinted /
##                 vignette effects.
##
## Specials (Joker, Bomb, Sweep, Shuffle) still get their own warm tints in
## CardView so the mechanic reads across every theme.

const LIST := [
	# Free starter — neutral baseline.
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
		"border_width": 3.0,
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
		"border_width": 3.0,
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
		"border_width": 3.0,
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
	# === New unlocks below — each uses the extended schema to feel distinct ===

	# Royal velvet purple table, cream face, thick gold frame + inset gold ring.
	# Reads as ornate / luxurious / casino-VIP.
	{
		"id": "royal_velvet",
		"name": "Royal Velvet",
		"unlock_level": 15,
		"card_face": Color(0.97, 0.93, 0.82),
		"card_border": Color(0.85, 0.65, 0.20),
		"card_text_red": Color(0.72, 0.10, 0.16),
		"card_text_black": Color(0.20, 0.10, 0.05),
		"felt": Color(0.16, 0.04, 0.20),
		"border_width": 5.0,
		"inner_ring": Color(0.95, 0.78, 0.30, 0.85),
		"face_accent": Color(0.85, 0.65, 0.20, 0.06),
	},

	# Frosted ice palette — pale blue felt, near-white face, chunky ice-blue
	# border with bright white inner ring. Cards feel like polished ice.
	{
		"id": "frost",
		"name": "Frost",
		"unlock_level": 18,
		"card_face": Color(0.94, 0.97, 1.00),
		"card_border": Color(0.45, 0.72, 0.92),
		"card_text_red": Color(0.78, 0.20, 0.30),
		"card_text_black": Color(0.10, 0.20, 0.35),
		"felt": Color(0.06, 0.14, 0.22),
		"border_width": 5.0,
		"inner_ring": Color(0.85, 0.95, 1.00, 0.95),
		"face_accent": Color(0.55, 0.85, 1.00, 0.05),
	},

	# Vintage bicycle paper — leather brown table, parchment face, thin dark
	# brown border, no ring. Classic deck-of-cards minimalism.
	{
		"id": "vintage",
		"name": "Vintage",
		"unlock_level": 22,
		"card_face": Color(0.96, 0.92, 0.82),
		"card_border": Color(0.30, 0.18, 0.10),
		"card_text_red": Color(0.72, 0.15, 0.18),
		"card_text_black": Color(0.18, 0.10, 0.05),
		"felt": Color(0.18, 0.10, 0.06),
		"border_width": 2.0,
		"face_accent": Color(0.55, 0.40, 0.20, 0.04),
	},

	# Cyberpunk — pure black felt, dark indigo face, hot magenta thick border
	# with cyan inner ring. Glowy / synthwave.
	{
		"id": "cyberpunk",
		"name": "Cyberpunk",
		"unlock_level": 26,
		"card_face": Color(0.08, 0.05, 0.18),
		"card_border": Color(1.00, 0.20, 0.75),
		"card_text_red": Color(1.00, 0.40, 0.65),
		"card_text_black": Color(0.30, 0.95, 1.00),
		"felt": Color(0.02, 0.02, 0.05),
		"border_width": 5.0,
		"inner_ring": Color(0.20, 0.95, 1.00, 0.90),
		"face_accent": Color(0.50, 0.10, 0.80, 0.10),
	},

	# Galaxy — deep navy felt with starry feel, near-black face, silver border
	# with bright silver inner ring + faint cosmic tint overlay.
	{
		"id": "galaxy",
		"name": "Galaxy",
		"unlock_level": 30,
		"card_face": Color(0.10, 0.10, 0.18),
		"card_border": Color(0.80, 0.82, 0.95),
		"card_text_red": Color(1.00, 0.55, 0.70),
		"card_text_black": Color(0.70, 0.85, 1.00),
		"felt": Color(0.03, 0.02, 0.10),
		"border_width": 4.0,
		"inner_ring": Color(0.95, 0.95, 1.00, 0.70),
		"face_accent": Color(0.40, 0.30, 0.85, 0.10),
	},
]


# Returns the highest-unlock-level theme the player has access to.
static func current() -> Dictionary:
	# Honor explicit player selection from the Progress panel if it's unlocked.
	var sel := String(SaveData.selected_theme_id)
	if not sel.is_empty():
		var selected := by_id(sel)
		if not selected.is_empty() \
			and SaveData.level >= int(selected.get("unlock_level", 1)):
			return selected
	# Otherwise auto-pick the highest-unlock-level theme the player has access to.
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
