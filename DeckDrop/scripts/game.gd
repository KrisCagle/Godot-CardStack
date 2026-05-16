extends Control
## Game-screen root. Owns the deck, current card, and preview queue.
## Tapping a column animates the current card down into the lowest empty cell,
## commits it, then runs the cascade loop. Difficulty ramps via TIER:
## score thresholds promote the run to higher tiers, and each tier shrinks
## the visible preview queue (less foresight = harder planning).
##
## Combo: each placement extends a 4-second timer and bumps the combo counter
## by 1. Scoring multiplies by (1 + (combo - 1) × 0.2). Let the timer run out
## and the next placement starts a fresh combo at 1.
##
## Game over: triggered when any column overflows (a card lands in row 0).
## End-of-run hands XP to SaveData (score/100 + first-time-hand bonuses) and
## shows the GameOverPanel with Play Again / Menu.

const PREVIEW_SIZE := 3
const DROP_DURATION := 0.26
const CLEAR_DELAY := 0.16
const GRAVITY_DELAY := 0.16

const TIER_THRESHOLDS := [0, 500, 1500, 3000, 5000, 8000, 12000, 18000, 25000, 35000]

const COMBO_TIME_MAX := 4.0
const COMBO_INCREMENT := 0.2

const FIRST_TIME_BONUSES := {
	"Pair": 0,
	"Two Pair": 0,
	"Three of a Kind": 25,
	"Straight": 50,
	"Flush": 75,
	"Full House": 100,
	"Four of a Kind": 150,
	"Straight Flush": 200,
	"Royal Flush": 500,
}

@onready var playfield: Control = $PlayField
@onready var score_label: Label = $HUD/ScoreLabel
@onready var tier_label: Label = $HUD/TierLabel
@onready var back_button: Button = $HUD/BackButton
@onready var combo_bar: ProgressBar = $HUD/ComboBar
@onready var combo_label: Label = $HUD/ComboLabel
@onready var current_card_view: CardView = $TopArea/CurrentSlot
@onready var preview_card_views: Array[CardView] = [
	$BottomArea/Preview0,
	$BottomArea/Preview1,
	$BottomArea/Preview2,
]
@onready var game_over_panel: Control = $GameOverPanel

var _deck: Deck
var _current: Card = null
var _preview: Array[Card] = []
var _is_animating: bool = false
var _game_over: bool = false
var score: int = 0
var _tier: int = 1
var _combo: int = 0
var _combo_timer: float = 0.0
var _best_hand_name: String = ""
var _best_hand_score: int = 0
var _hands_seen_this_run: Dictionary = {}


func _ready() -> void:
	playfield.column_tapped.connect(_on_column_tapped)
	back_button.pressed.connect(_on_back_pressed)
	game_over_panel.play_again_pressed.connect(_on_play_again_pressed)
	game_over_panel.menu_pressed.connect(_on_menu_pressed)
	_start_new_game()


func _start_new_game() -> void:
	_deck = Deck.new()
	_preview.clear()
	for i in PREVIEW_SIZE:
		_preview.append(_deck.draw_card())
	_current = _deck.draw_card()
	score = 0
	_tier = 1
	_combo = 0
	_combo_timer = 0.0
	_is_animating = false
	_game_over = false
	_best_hand_name = ""
	_best_hand_score = 0
	_hands_seen_this_run = {}
	playfield.reset()
	game_over_panel.hide_summary()
	_refresh()


func _process(delta: float) -> void:
	if _game_over:
		return
	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		_refresh_combo_display()


func _on_column_tapped(col: int) -> void:
	if _is_animating or _game_over or _current == null:
		return
	var target_row: int = playfield.lowest_empty_row(col)
	if target_row < 0:
		print("[game] column %d full" % col)
		return

	# Combo update happens BEFORE scoring so the cascade picks up the new value.
	if _combo_timer > 0.0:
		_combo += 1
	else:
		_combo = 1

	_is_animating = true
	var placed := _current
	await _animate_drop(placed, col, target_row)
	playfield.place_card(placed, col)
	await _process_cascades()
	_check_tier_up()

	if playfield.is_any_column_full():
		_end_run()
		return

	_advance_queue()
	_combo_timer = COMBO_TIME_MAX
	_refresh()
	_is_animating = false


func _animate_drop(card: Card, col: int, row: int) -> void:
	var temp := CardView.new()
	temp.size = current_card_view.size
	add_child(temp)
	temp.global_position = current_card_view.global_position
	temp.set_card(card)

	current_card_view.clear()

	var target_rect: Rect2 = playfield.cell_local_rect(col, row)
	var target_global: Vector2 = playfield.global_position + target_rect.position

	var tween := create_tween().set_parallel(true)
	tween.tween_property(temp, "global_position", target_global, DROP_DURATION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(temp, "size", target_rect.size, DROP_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished
	temp.queue_free()


func _process_cascades() -> void:
	var cascade_tier := 0
	var combo_mult := 1.0 + float(maxi(0, _combo - 1)) * COMBO_INCREMENT
	while true:
		var groups: Array = playfield.find_scoring_groups()
		if groups.is_empty():
			break
		cascade_tier += 1
		var tier_mult := 1.0 + float(cascade_tier - 1) * 0.5
		var all_cells: Array = []
		for g in groups:
			var earned := int(round(float(g.score) * tier_mult * combo_mult))
			score += earned
			all_cells.append_array(g.cells)

			if earned > _best_hand_score:
				_best_hand_score = earned
				_best_hand_name = String(g.name)
			_hands_seen_this_run[String(g.name)] = int(_hands_seen_this_run.get(g.name, 0)) + 1

			print("[score] %s (%s) %d × tier %.1f × combo %.1f → %d  (total %d)" \
				% [g.name, g.axis, g.score, tier_mult, combo_mult, earned, score])
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


func _end_run() -> void:
	_game_over = true
	_is_animating = false
	_combo_timer = 0.0

	# First-time hand bonuses: claim each new-to-player hand seen this run.
	var first_time_bonus := 0
	for hand_name in _hands_seen_this_run.keys():
		var hn: String = hand_name
		if SaveData.claim_first_time_hand(hn):
			var bonus: int = int(FIRST_TIME_BONUSES.get(hn, 0))
			if bonus > 0:
				first_time_bonus += bonus
				print("[xp] first %s! +%d xp" % [hn, bonus])

	var xp_from_score: int = int(floor(float(score) / 100.0))
	var total_xp: int = xp_from_score + first_time_bonus
	var previous_level: int = SaveData.level
	var add_result: Dictionary = SaveData.add_xp(total_xp)
	var is_new_best: bool = SaveData.record_score(score, _today_date())

	print("[run] over · score %d · xp +%d (score %d + hands %d)" \
		% [score, total_xp, xp_from_score, first_time_bonus])

	game_over_panel.show_summary({
		"score": score,
		"best_hand_name": _best_hand_name,
		"best_hand_score": _best_hand_score,
		"is_new_best": is_new_best,
		"xp_gained": total_xp,
		"xp_from_score": xp_from_score,
		"xp_from_hands": first_time_bonus,
		"previous_level": previous_level,
		"new_level": SaveData.level,
		"leveled_up": bool(add_result.get("leveled_up", false)),
	})


func _today_date() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


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
	_refresh_combo_display()


func _refresh_score() -> void:
	score_label.text = "Score  %d" % score


func _refresh_combo_display() -> void:
	combo_bar.max_value = COMBO_TIME_MAX
	combo_bar.value = _combo_timer
	var alive := _combo_timer > 0.0
	if alive and _combo > 1:
		combo_label.text = "COMBO ×%d" % _combo
	else:
		combo_label.text = ""

	var ratio := _combo_timer / COMBO_TIME_MAX if COMBO_TIME_MAX > 0.0 else 0.0
	var fill: Color
	if ratio > 0.66:
		fill = Color(0.40, 0.85, 0.55, 1.0)
	elif ratio > 0.33:
		fill = Color(0.90, 0.78, 0.45, 1.0)
	else:
		fill = Color(0.90, 0.45, 0.50, 1.0)
	if not alive:
		fill = Color(0.25, 0.28, 0.36, 1.0)
	combo_bar.modulate = fill


func _on_play_again_pressed() -> void:
	_start_new_game()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
