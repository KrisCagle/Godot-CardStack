extends Control
## Game-screen root. Owns the deck, current card, and preview queue.
## Tapping a column animates the current card down into the lowest empty cell,
## commits it, then runs the cascade loop. Difficulty ramps via TIER:
## score thresholds promote the run to higher tiers, and each tier shrinks
## the visible preview queue (less foresight = harder planning).

const PREVIEW_SIZE := 3
const DROP_DURATION := 0.26
const CLEAR_DELAY := 0.16
const GRAVITY_DELAY := 0.16

# Tier T requires score >= TIER_THRESHOLDS[T-1] (tier 1 is always active at 0).
const TIER_THRESHOLDS := [0, 500, 1500, 3000, 5000, 8000, 12000, 18000, 25000, 35000]

@onready var playfield: Control = $PlayField
@onready var score_label: Label = $HUD/ScoreLabel
@onready var tier_label: Label = $HUD/TierLabel
@onready var back_button: Button = $HUD/BackButton
@onready var current_card_view: CardView = $TopArea/CurrentSlot
@onready var preview_card_views: Array[CardView] = [
	$BottomArea/Preview0,
	$BottomArea/Preview1,
	$BottomArea/Preview2,
]

var _deck: Deck
var _current: Card = null
var _preview: Array[Card] = []
var _is_animating: bool = false
var score: int = 0
var _tier: int = 1


func _ready() -> void:
	playfield.column_tapped.connect(_on_column_tapped)
	back_button.pressed.connect(_on_back_pressed)
	_start_new_game()


func _start_new_game() -> void:
	_deck = Deck.new()
	_preview.clear()
	for i in PREVIEW_SIZE:
		_preview.append(_deck.draw_card())
	_current = _deck.draw_card()
	score = 0
	_tier = 1
	_is_animating = false
	playfield.reset()
	_refresh()


func _on_column_tapped(col: int) -> void:
	if _is_animating or _current == null:
		return
	var target_row := playfield.lowest_empty_row(col)
	if target_row < 0:
		print("[game] column %d full" % col)
		return
	_is_animating = true
	var placed := _current
	await _animate_drop(placed, col, target_row)
	playfield.place_card(placed, col)
	await _process_cascades()
	_check_tier_up()
	_advance_queue()
	_refresh()
	_is_animating = false


func _animate_drop(card: Card, col: int, row: int) -> void:
	var temp := CardView.new()
	temp.size = current_card_view.size
	add_child(temp)
	temp.global_position = current_card_view.global_position
	temp.set_card(card)

	current_card_view.clear()

	var target_rect := playfield.cell_local_rect(col, row)
	var target_global := playfield.global_position + target_rect.position

	var tween := create_tween().set_parallel(true)
	tween.tween_property(temp, "global_position", target_global, DROP_DURATION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(temp, "size", target_rect.size, DROP_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished
	temp.queue_free()


func _process_cascades() -> void:
	var cascade_tier := 0
	while true:
		var groups: Array = playfield.find_scoring_groups()
		if groups.is_empty():
			break
		cascade_tier += 1
		var tier_mult := 1.0 + float(cascade_tier - 1) * 0.5
		var all_cells: Array = []
		for g in groups:
			var earned := int(round(float(g.score) * tier_mult))
			score += earned
			all_cells.append_array(g.cells)
			print("[score] %s (%s) %d × %.1f → %d  (total %d)" \
				% [g.name, g.axis, g.score, tier_mult, earned, score])
		_refresh_score()

		var seen: Dictionary = {}
		var unique_cells: Array = []
		for c in all_cells:
			if not seen.has(c):
				seen[c] = true
				unique_cells.append(c)
		playfield.clear_cells(unique_cells)
		await get_tree().create_timer(CLEAR_DELAY).timeout
		playfield.apply_gravity()
		await get_tree().create_timer(GRAVITY_DELAY).timeout


func _check_tier_up() -> void:
	var new_tier := _compute_tier(score)
	if new_tier > _tier:
		_tier = new_tier
		print("[tier] up to %d (previews now %d)" % [_tier, _active_preview_count()])


func _compute_tier(s: int) -> int:
	var t := 1
	for i in range(TIER_THRESHOLDS.size()):
		if s >= TIER_THRESHOLDS[i]:
			t = i + 1
	return t


# Tier 1-2 → 3 previews, 3-4 → 2, 5-6 → 1, 7+ → 0 (only current visible).
func _active_preview_count() -> int:
	if _tier <= 2:
		return 3
	if _tier <= 4:
		return 2
	if _tier <= 6:
		return 1
	return 0


func _advance_queue() -> void:
	_current = _preview[0]
	for i in range(PREVIEW_SIZE - 1):
		_preview[i] = _preview[i + 1]
	_preview[PREVIEW_SIZE - 1] = _deck.draw_card()


func _refresh() -> void:
	_refresh_score()
	tier_label.text = "Tier %d" % _tier
	current_card_view.set_card(_current)
	var visible := _active_preview_count()
	for i in PREVIEW_SIZE:
		var slot := preview_card_views[i]
		slot.visible = i < visible
		if i < visible:
			slot.set_card(_preview[i])


func _refresh_score() -> void:
	score_label.text = "Score  %d" % score


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
