class_name CardView
extends Control
## Visual representation of a Card (or empty slot). Drawn via _draw so it scales
## cleanly from preview-sized slots to full grid cells without separate scenes.

var _card: Card = null


func set_card(card: Card) -> void:
	_card = card
	queue_redraw()


func clear() -> void:
	set_card(null)


func _draw() -> void:
	if _card == null:
		_draw_empty_slot()
		return
	_draw_card(_card)


func _draw_empty_slot() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.10, 0.12, 0.18, 1.0), true)
	draw_rect(rect, Color(0.25, 0.30, 0.42, 1.0), false, 2.0)


func _draw_card(card: Card) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.96, 0.96, 0.94, 1.0), true)
	draw_rect(rect, Color(0.20, 0.20, 0.25, 1.0), false, 2.0)

	var font := get_theme_default_font()
	var fg := card.suit_color()
	var rank_text := card.rank_label()
	var suit_text := card.suit_label()

	var rank_font_size := int(size.y * 0.30)
	var suit_font_size := int(size.y * 0.22)
	var center_font_size := int(size.y * 0.55)
	var pad := size.y * 0.08

	draw_string(font, Vector2(pad, pad + rank_font_size * 0.85), rank_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font_size, fg)
	draw_string(font, Vector2(pad, pad + rank_font_size + suit_font_size * 0.95), suit_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, suit_font_size, fg)
	draw_string(font, Vector2(0, size.y * 0.84), suit_text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, center_font_size, fg)
