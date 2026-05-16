extends Control
## Game-screen root. Owns the deck, current card, and 3-card preview queue.
## Tapping a column animates the current card down into the lowest empty cell,
## commits it, then runs the cascade loop: find scoring groups, accumulate
## score with a cascade-tier multiplier, clear cells, apply gravity, repeat.

const PREVIEW_SIZE := 3
const DROP_DURATION := 0.26
const CLEAR_DELAY := 0.16
const GRAVITY_DELAY := 0.16

@onready var playfield: Control = $PlayField
@onready var score_label: Label = $HUD/ScoreLabel
@onready var level_label: Label = $HUD/LevelLabel
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


# Scans the grid for scoring groups, awards points (cascade-tier × base), clears,
# applies gravity, and repeats until no new groups form. Tier 1 = 1.0x base,
# each subsequent cascade adds +0.5x.
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


func _advance_queue() -> void:
	_current = _preview[0]
	for i in range(PREVIEW_SIZE - 1):
		_preview[i] = _preview[i + 1]
	_preview[PREVIEW_SIZE - 1] = _deck.draw_card()


func _refresh() -> void:
	_refresh_score()
	level_label.text = "Lv %d" % SaveData.level
	current_card_view.set_card(_current)
	for i in PREVIEW_SIZE:
		preview_card_views[i].set_card(_preview[i])


func _refresh_score() -> void:
	score_label.text = "Score  %d" % score


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
