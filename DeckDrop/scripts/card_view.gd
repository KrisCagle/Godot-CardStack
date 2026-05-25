class_name CardView
extends Control
## Visual representation of a Card (or empty slot). Drawn via _draw so it scales
## cleanly from preview-sized slots to full grid cells without separate scenes.
## Static helpers let the playfield render placed cards directly into its own
## canvas without spawning 40 child nodes.

const COLOR_EMPTY_FILL := Color(0.10, 0.12, 0.18, 1.0)
const COLOR_EMPTY_LINE := Color(0.25, 0.30, 0.42, 1.0)
const COLOR_CARD_FACE := Color(0.96, 0.96, 0.94, 1.0)
const COLOR_CARD_BORDER := Color(0.20, 0.20, 0.25, 1.0)

var _card: Card = null


func set_card(card: Card) -> void:
	_card = card
	queue_redraw()


func clear() -> void:
	set_card(null)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _card == null:
		draw_empty_slot(self, rect)
	else:
		draw_card(self, _card, rect)


static func draw_empty_slot(canvas: Control, rect: Rect2) -> void:
	canvas.draw_rect(rect, COLOR_EMPTY_FILL, true)
	canvas.draw_rect(rect, COLOR_EMPTY_LINE, false, 2.0)


static func draw_card(canvas: Control, card: Card, rect: Rect2) -> void:
	var theme := Themes.current()
	draw_card_with_theme(canvas, card, rect, theme)


# Theme-explicit version so the Progress panel can draw mini previews of
# OTHER themes without temporarily mutating the global Themes.current().
# Game grid + preview slot use the active theme via the wrapper above.
static func draw_card_with_theme(canvas: Control, card: Card, rect: Rect2, theme: Dictionary) -> void:
	var face_color: Color = theme.card_face
	var border_color: Color = theme.card_border
	# Optional extended schema (see themes.gd top comment). Defaults match
	# the pre-extension look so old themes render identically.
	var border_width: float = float(theme.get("border_width", 2.0))
	var inner_ring: Color = theme.get("inner_ring", Color(0, 0, 0, 0))
	var face_accent: Color = theme.get("face_accent", Color(0, 0, 0, 0))
	if card.is_bomb:
		face_color = Color(1.00, 0.84, 0.82)
		border_color = Color(0.55, 0.18, 0.18)
	elif card.is_joker:
		face_color = Color(1.00, 0.96, 0.80)
		border_color = Color(0.65, 0.50, 0.15)
	elif card.is_sweep:
		face_color = Color(0.88, 1.00, 0.92)
		border_color = Color(0.25, 0.70, 0.55)
	elif card.is_shuffle:
		face_color = Color(0.96, 0.88, 1.00)
		border_color = Color(0.75, 0.45, 1.00)
	elif card.is_surge:
		border_color = Color(0.85, 0.45, 1.00)
		border_width = 4.0
	elif card.is_anchor:
		border_color = Color(0.55, 0.58, 0.65)
		border_width = 5.0
	elif card.is_flare:
		border_color = Color(0.40, 0.85, 1.00)
		border_width = 4.0
	elif card.is_crown:
		border_color = Color(0.95, 0.78, 0.30)
		border_width = 4.0
	elif card.is_mirror:
		border_color = Color(0.55, 0.85, 1.00)
		border_width = 4.0
	elif card.is_burst:
		border_color = Color(1.00, 0.65, 0.30)
		border_width = 4.0
	elif card.is_bonus:
		border_color = Color(1.00, 0.40, 0.70)
		border_width = 4.0

	# Face fill.
	canvas.draw_rect(rect, face_color, true)

	# Theme face accent — a subtle full-face tint overlay for themes that
	# want a vignette / atmospheric layer (Royal Velvet's gold mist, Galaxy's
	# cosmic violet, etc.). Drawn over the face fill but under the suit
	# stripe so the stripe still reads cleanly.
	if face_accent.a > 0.0:
		canvas.draw_rect(rect, face_accent, true)

	# Real-card polish: a suit-colored stripe across the top and a subtle
	# darkening across the bottom half so cards read with depth instead of
	# looking like flat rectangles. Skip for symbol-mode specials (Joker /
	# Bomb / Sweep / Shuffle) which have their own visual treatment.
	var is_symbol_card: bool = card.is_joker or card.is_bomb \
		or card.is_sweep or card.is_shuffle
	if not is_symbol_card:
		var stripe_pad_x: float = rect.size.x * 0.10
		var stripe_h: float = maxf(rect.size.y * 0.05, 3.0)
		var stripe := Rect2(
			rect.position + Vector2(stripe_pad_x, rect.size.y * 0.03),
			Vector2(rect.size.x - stripe_pad_x * 2, stripe_h)
		)
		canvas.draw_rect(stripe, _suit_color_for_theme(card, theme), true)

		var darken := Rect2(
			rect.position + Vector2(0, rect.size.y * 0.55),
			Vector2(rect.size.x, rect.size.y * 0.45)
		)
		canvas.draw_rect(darken, Color(0, 0, 0, 0.05), true)

	# Border last so it sits on top of the stripe + darken pass.
	canvas.draw_rect(rect, border_color, false, border_width)

	# Optional inset ring just inside the main border. Themes use this for
	# ornate framing (Royal Velvet) or frosted layering (Frost / Cyberpunk
	# / Galaxy). Inset = border_width + a small gap so the ring reads as a
	# separate line rather than thickening the border.
	if inner_ring.a > 0.0:
		var inset: float = border_width + 2.0
		var ring_rect := Rect2(
			rect.position + Vector2(inset, inset),
			rect.size - Vector2(inset * 2.0, inset * 2.0)
		)
		if ring_rect.size.x > 4.0 and ring_rect.size.y > 4.0:
			canvas.draw_rect(ring_rect, inner_ring, false, 1.5)

	var font := canvas.get_theme_default_font()
	var fg := _suit_color_for_theme(card, theme)
	var rank_text := card.rank_label()
	var suit_text := card.suit_label()

	var rank_font_size := int(rect.size.y * 0.30)
	var suit_font_size := int(rect.size.y * 0.22)
	var center_font_size := int(rect.size.y * 0.62)  # larger center suit for presence
	var pad := rect.size.y * 0.08

	canvas.draw_string(font,
		rect.position + Vector2(pad, pad + rank_font_size * 0.92),
		rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, fg)
	canvas.draw_string(font,
		rect.position + Vector2(pad, pad + rank_font_size + suit_font_size * 0.95),
		suit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, fg)
	canvas.draw_string(font,
		rect.position + Vector2(0, rect.size.y * 0.88),
		suit_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, center_font_size, fg)


# Parameterized version of card.suit_color() so we can render a card under
# a specific theme dict (e.g. Progress panel previews) without depending on
# Themes.current(). Mirrors card.suit_color()'s special-card overrides.
static func _suit_color_for_theme(card: Card, theme: Dictionary) -> Color:
	if card.kind == Card.Kind.JOKER:
		return Color(0.95, 0.78, 0.25)
	if card.kind == Card.Kind.BOMB:
		return Color(0.85, 0.30, 0.30)
	if card.kind == Card.Kind.SWEEP:
		return Color(0.30, 0.85, 0.70)
	if card.kind == Card.Kind.SHUFFLE:
		return Color(0.85, 0.55, 1.00)
	if card.suit == Card.Suit.HEARTS or card.suit == Card.Suit.DIAMONDS:
		return theme.card_text_red
	return theme.card_text_black
