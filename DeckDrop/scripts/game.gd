extends Control
## Game-screen root. Owns the deck, current card, and preview queue.
## Tapping a column animates the current card down into the lowest empty cell,
## commits it, then runs the cascade loop. Difficulty ramps via TIER:
## score thresholds promote the run to higher tiers, and each tier shrinks
## the visible preview queue (less foresight = harder planning).
##
## Combo: each placement extends a 4-second timer and bumps the combo counter.
## Scoring multiplies by (1 + (combo - 1) × 0.2).
##
## Dealer Showdown: every ROUND_LENGTH placements, the dealer issues a target
## score. The player must clear at least one hand that scores higher during
## the round. Beat = bonus score + dealer scales up. Fail = immediate game over.
##
## Game over: triggered by column overflow OR dealer-round loss. End-of-run
## hands XP to SaveData (score/100 + first-time-hand bonuses) and shows the
## GameOverPanel with the relevant reason.
##
## Lifetime stats + Achievements: events through the run feed into SaveData
## counters and unlock checks. Newly-unlocked achievements pop a gold toast
## mid-screen and grant their bonus XP immediately.

const PREVIEW_SIZE := 3
const DROP_DURATION := 0.26
const CLEAR_DELAY := 0.16
const GRAVITY_DELAY := 0.16
const ROUND_LENGTH := 7  # placements per dealer round

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

@onready var playfield: PlayField = $PlayField
@onready var score_label: Label = $HUD/ScoreLabel
@onready var tier_label: Label = $HUD/TierLabel
@onready var back_button: Button = $HUD/BackButton
@onready var combo_bar: ProgressBar = $HUD/ComboBar
@onready var combo_label: Label = $HUD/ComboLabel
@onready var dealer_info_label: Label = $HUD/DealerInfoLabel
@onready var round_counter_label: Label = $HUD/RoundCounterLabel
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

# Dealer state
var _dealer_target: Dictionary = {}
var _round_placements: int = 0
var _round_best_score: int = 0
var _dealer_tier: int = 1
var _run_placements: int = 0  # total placements this run (for stats)

var _shake_tween: Tween = null
var _shake_orig: Vector2 = Vector2.ZERO

# Score count-up animation
var _displayed_score: int = 0
var _score_tween: Tween = null


func _ready() -> void:
	playfield.column_tapped.connect(_on_column_tapped)
	back_button.pressed.connect(_on_back_pressed)
	game_over_panel.play_again_pressed.connect(_on_play_again_pressed)
	game_over_panel.menu_pressed.connect(_on_menu_pressed)
	_start_new_game()


func _start_new_game() -> void:
	_deck = Deck.new()
	score = 0
	_tier = 1
	_combo = 0
	_combo_timer = 0.0
	_is_animating = false
	_game_over = false
	_best_hand_name = ""
	_best_hand_score = 0
	_hands_seen_this_run = {}
	_round_placements = 0
	_round_best_score = 0
	_dealer_tier = 1
	_dealer_target = Dealer.target_for_tier(_dealer_tier)
	_run_placements = 0
	_displayed_score = 0
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_preview.clear()
	for i in PREVIEW_SIZE:
		_preview.append(_draw_card_with_specials())
	_current = _draw_card_with_specials()
	playfield.reset()
	game_over_panel.hide_summary()
	_refresh()
	_show_round_splash("ROUND 1")


func _process(delta: float) -> void:
	if _game_over:
		return
	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		_refresh_combo_display()


func _on_column_tapped(col: int) -> void:
	if _is_animating or _game_over or _current == null:
		return

	if _current.is_bomb:
		await _drop_bomb(col)
		return

	var target_row: int = playfield.lowest_empty_row(col)
	if target_row < 0:
		print("[game] column %d full" % col)
		return

	_update_combo_state()

	_is_animating = true
	var placed := _current
	await _animate_drop(placed, col, target_row)
	Sfx.play("place")
	playfield.place_card(placed, col)
	_apply_placement_bonuses(col, target_row, placed)
	_on_placement_recorded(placed)
	await _process_cascades()
	_check_tier_up()

	if playfield.is_any_column_full():
		_end_run("column_overflow")
		return

	_round_placements += 1
	if _round_placements >= ROUND_LENGTH:
		await _evaluate_round()
		if _game_over:
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
		Sfx.play("clear")
		SaveData.update_max_stat("highest_cascade_tier", cascade_tier)
		if cascade_tier >= 3:
			_try_achievement("triple_cascade")
		var tier_mult := 1.0 + float(cascade_tier - 1) * 0.5
		if cascade_tier >= 2:
			_shake(7.0, 0.18)

		var all_cells: Array = []
		for g in groups:
			var earned := int(round(float(g.score) * tier_mult * combo_mult))
			score += earned
			all_cells.append_array(g.cells)

			if earned > _best_hand_score:
				_best_hand_score = earned
				_best_hand_name = String(g.name)
			if earned > _round_best_score:
				_round_best_score = earned
			_hands_seen_this_run[String(g.name)] = int(_hands_seen_this_run.get(g.name, 0)) + 1
			SaveData.increment_stat("total_hands_cleared")

			# Achievement: Royal Flush ever, Wild Thing if a Joker contributed.
			if int(g.rank) == HandEvaluator.HandRank.ROYAL_FLUSH:
				_try_achievement("royal_flush")
			for cell in g.cells:
				var p: Vector2i = cell
				var c: Card = playfield.card_at(p.x, p.y)
				if c != null and c.is_joker:
					_try_achievement("wild_thing")
					break

			print("[score] %s (%s) %d × tier %.1f × combo %.1f → %d  (total %d)" \
				% [g.name, g.axis, g.score, tier_mult, combo_mult, earned, score])

			_spawn_hand_popup(g, earned)
			_spawn_cell_glow(g)
			if int(g.rank) >= HandEvaluator.HandRank.FOUR_OF_A_KIND:
				_shake(14.0, 0.30)

		_refresh_score()
		if score >= 5000:
			_try_achievement("big_spender")

		var seen: Dictionary = {}
		var unique_cells: Array = []
		for c in all_cells:
			if not seen.has(c):
				seen[c] = true
				unique_cells.append(c)

		await get_tree().create_timer(0.18).timeout
		_spawn_clear_particles(unique_cells)
		playfield.clear_cells(unique_cells)
		await get_tree().create_timer(CLEAR_DELAY).timeout
		playfield.apply_gravity()
		await get_tree().create_timer(GRAVITY_DELAY).timeout


func _evaluate_round() -> void:
	var dealer_score: int = int(_dealer_target.get("score", 0))
	var dealer_name: String = String(_dealer_target.get("name", "?"))

	if _round_best_score > dealer_score:
		var bonus := int(round(float(dealer_score) * 0.5))
		score += bonus
		_refresh_score()
		print("[dealer] %s (%d) BEATEN with %d → +%d bonus" \
			% [dealer_name, dealer_score, _round_best_score, bonus])
		Sfx.play("win")
		_try_achievement("first_dealer")
		_spawn_dealer_popup("BEAT DEALER  +%d" % bonus, Color(0.45, 1.0, 0.65))
		_shake(10.0, 0.22)
		await get_tree().create_timer(0.55).timeout
		_dealer_tier += 1
		_dealer_target = Dealer.target_for_tier(_dealer_tier)
		SaveData.update_max_stat("highest_dealer_tier", _dealer_tier)
		if _dealer_tier >= 5:
			_try_achievement("marathon")
		_show_round_splash("ROUND %d" % _dealer_tier)
	else:
		print("[dealer] %s (%d) WINS — best %d not enough" \
			% [dealer_name, dealer_score, _round_best_score])
		Sfx.play("lose")
		_spawn_dealer_popup("DEALER WINS!", Color(1.0, 0.40, 0.45))
		_shake(18.0, 0.40)
		await get_tree().create_timer(1.1).timeout
		_end_run("dealer_won")
		return

	_round_placements = 0
	_round_best_score = 0
	_refresh_dealer_hud()


func _end_run(reason: String = "column_overflow") -> void:
	_game_over = true
	_is_animating = false
	_combo_timer = 0.0
	if reason == "column_overflow":
		Sfx.play("game_over")

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

	# Lifetime stat rollup
	SaveData.increment_stat("total_runs")
	SaveData.increment_stat("total_score", score)
	SaveData.update_max_stat("longest_run_placements", _run_placements)
	if SaveData.level >= 10:
		_try_achievement("centenarian")

	print("[run] over (%s) · score %d · xp +%d (score %d + hands %d)" \
		% [reason, score, total_xp, xp_from_score, first_time_bonus])

	game_over_panel.show_summary({
		"reason": reason,
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
	_preview[PREVIEW_SIZE - 1] = _draw_card_with_specials()


func _draw_card_with_specials() -> Card:
	var chance := _special_chance_for_tier(_tier)
	if randf() < chance:
		if randf() < 0.6:
			return Card.make_joker()
		return Card.make_bomb()
	return _deck.draw_card()


func _special_chance_for_tier(t: int) -> float:
	return clampf(0.025 + float(t - 1) * 0.005, 0.025, 0.065)


func _drop_bomb(col: int) -> void:
	_is_animating = true
	var bomb := _current

	_update_combo_state()

	var visual_row: int = playfield.lowest_empty_row(col)
	if visual_row < 0:
		visual_row = 0
	await _animate_drop(bomb, col, visual_row)

	var cells_to_clear: Array = []
	for y in PlayField.GRID_HEIGHT:
		if playfield.card_at(col, y) != null:
			cells_to_clear.append(Vector2i(col, y))

	if not cells_to_clear.is_empty():
		_spawn_clear_particles(cells_to_clear)
		playfield.clear_cells(cells_to_clear)
	Sfx.play("boom")
	_shake(16.0, 0.36)
	_spawn_bomb_popup(col)
	_on_placement_recorded(bomb)
	SaveData.increment_stat("total_bombs_played")
	_try_achievement("bombs_away")
	await get_tree().create_timer(0.30).timeout

	_round_placements += 1
	if _round_placements >= ROUND_LENGTH:
		await _evaluate_round()
		if _game_over:
			return

	_advance_queue()
	_combo_timer = COMBO_TIME_MAX
	_refresh()
	_is_animating = false


# Per-placement bookkeeping: stats, joker count.
func _on_placement_recorded(placed: Card) -> void:
	_run_placements += 1
	SaveData.increment_stat("total_cards_placed")
	if placed != null and placed.is_joker:
		SaveData.increment_stat("total_jokers_played")


# Centralized combo update so the bomb and normal-placement paths share rules.
# Bumps combo, plays SFX on first crossing into ≥2, claims Hot Streak at ≥5,
# and updates the lifetime highest_combo stat.
func _update_combo_state() -> void:
	if _combo_timer > 0.0:
		_combo += 1
		if _combo == 2:
			Sfx.play("combo")
		if _combo >= 5:
			_try_achievement("hot_streak")
	else:
		_combo = 1
	SaveData.update_max_stat("highest_combo", _combo)


# Claims an achievement; if newly unlocked, awards its XP and pops the toast.
func _try_achievement(id: String) -> void:
	if not SaveData.claim_achievement(id):
		return
	var a := Achievements.by_id(id)
	if a.is_empty():
		return
	var xp_award: int = int(a.get("xp", 0))
	if xp_award > 0:
		SaveData.add_xp(xp_award)
	_spawn_achievement_popup(a)
	print("[achievement] unlocked: %s (+%d xp)" % [String(a.get("name", id)), xp_award])


# Mid-screen gold toast for an achievement unlock.
func _spawn_achievement_popup(a: Dictionary) -> void:
	var popup := Label.new()
	popup.text = "🏆 %s   +%d XP" % [String(a.get("name", "")), int(a.get("xp", 0))]
	popup.add_theme_font_size_override("font_size", 56)
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	popup.add_theme_constant_override("outline_size", 12)
	popup.z_index = 130
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	await get_tree().process_frame

	popup.position = Vector2((size.x - popup.size.x) * 0.5, 320.0)
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.45, 0.45)
	popup.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(popup, "modulate:a", 1.0, 0.20)
	t.tween_property(popup, "position:y", 240.0, 1.40).set_delay(0.30)
	t.tween_property(popup, "modulate:a", 0.0, 0.45).set_delay(1.40)

	await t.finished
	popup.queue_free()


func _spawn_bomb_popup(col: int) -> void:
	var popup := Label.new()
	popup.text = "BOOM!"
	popup.add_theme_font_size_override("font_size", 96)
	popup.add_theme_color_override("font_color", Color(1.0, 0.50, 0.35))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	popup.add_theme_constant_override("outline_size", 14)
	popup.z_index = 110
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	await get_tree().process_frame

	var rect: Rect2 = playfield.cell_local_rect(col, int(PlayField.GRID_HEIGHT / 2))
	var center: Vector2 = playfield.global_position + rect.position + rect.size * 0.5
	popup.position = center - popup.size * 0.5
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.45, 0.45)

	var t := create_tween().set_parallel(true)
	t.tween_property(popup, "scale", Vector2(1.15, 1.15), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.10).set_delay(0.22)
	t.tween_property(popup, "modulate:a", 0.0, 0.45).set_delay(0.40)

	await t.finished
	popup.queue_free()


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
	_refresh_dealer_hud()


func _refresh_score() -> void:
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	if _displayed_score == score:
		score_label.text = "Score  %d" % score
		return
	_score_tween = create_tween()
	_score_tween.tween_method(_set_displayed_score, _displayed_score, score, 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_displayed_score(v: int) -> void:
	_displayed_score = v
	score_label.text = "Score  %d" % v


func _refresh_dealer_hud() -> void:
	var dealer_name: String = String(_dealer_target.get("name", "?"))
	var dealer_score: int = int(_dealer_target.get("score", 0))
	dealer_info_label.text = "⚔ DEALER: %s · %d to beat" % [dealer_name.to_upper(), dealer_score]
	var left := ROUND_LENGTH - _round_placements
	round_counter_label.text = "%d LEFT" % left
	if left <= 1:
		round_counter_label.modulate = Color(1.0, 0.4, 0.45)
	elif left <= 2:
		round_counter_label.modulate = Color(1.0, 0.75, 0.4)
	else:
		round_counter_label.modulate = Color(1.0, 0.95, 0.5)


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


# --- per-placement bonuses ---


func _apply_placement_bonuses(col: int, row: int, placed: Card) -> void:
	if placed == null or placed.is_joker:
		return
	var combo_mult := 1.0 + float(maxi(0, _combo - 1)) * COMBO_INCREMENT

	var adj_raw := _adjacency_bonus(col, row, placed)
	var squares: Array = playfield.find_same_suit_squares_at(col, row)
	var square_raw := squares.size() * 20
	var partial_hits: Array = _detect_partial_hits(col, row)
	var partial_raw := 0
	for h in partial_hits:
		partial_raw += int(h.bonus)

	var raw_total := adj_raw + square_raw + partial_raw
	if raw_total <= 0:
		return

	var earned := int(round(float(raw_total) * combo_mult))
	score += earned
	_refresh_score()

	for h in partial_hits:
		var multiplied := int(round(float(h.bonus) * combo_mult))
		_spawn_mini_popup("%s +%d" % [String(h.name), multiplied],
			_center_of_cells(h.cells), h.color)

	if partial_hits.is_empty():
		var rect: Rect2 = playfield.cell_local_rect(col, row)
		var center: Vector2 = playfield.global_position + rect.position + rect.size * 0.5
		var color: Color = Color(0.70, 1.00, 0.85) if square_raw == 0 else Color(0.80, 0.95, 1.00)
		_spawn_mini_popup("+%d" % earned, center, color)


func _detect_partial_hits(col: int, row: int) -> Array:
	var hits: Array = []
	for size: int in [3, 4]:
		for offset: int in size:
			var start_col: int = col - offset
			if start_col < 0 or start_col + size > PlayField.GRID_WIDTH:
				continue
			var hit := _check_partial_window(start_col, row, 1, 0, size)
			if not hit.is_empty():
				hits.append(hit)
	for size: int in [3, 4]:
		for offset: int in size:
			var start_row: int = row - offset
			if start_row < 0 or start_row + size > PlayField.GRID_HEIGHT:
				continue
			var hit := _check_partial_window(col, start_row, 0, 1, size)
			if not hit.is_empty():
				hits.append(hit)
	return hits


func _check_partial_window(start_col: int, start_row: int, dx: int, dy: int, size: int) -> Dictionary:
	var cells: Array = []
	var cards: Array = []
	for i in size:
		var c: Card = playfield.card_at(start_col + dx * i, start_row + dy * i)
		if c == null or c.is_special:
			return {}
		cards.append(c)
		cells.append(Vector2i(start_col + dx * i, start_row + dy * i))
	var classification := _classify_partial(cards)
	if int(classification.get("bonus", 0)) <= 0:
		return {}
	classification["cells"] = cells
	return classification


func _classify_partial(cards: Array) -> Dictionary:
	var size := cards.size()
	if size == 3:
		if cards[0].rank == cards[1].rank and cards[1].rank == cards[2].rank:
			return {"name": "MINI TRIPS", "bonus": 30, "color": Color(1.00, 0.65, 0.95)}
		return {"name": "", "bonus": 0, "color": Color.WHITE}
	if size == 4:
		var same_suit := true
		for i in range(1, 4):
			if cards[i].suit != cards[0].suit:
				same_suit = false
				break
		if same_suit:
			return {"name": "FLUSH+", "bonus": 50, "color": Color(0.50, 0.95, 0.60)}
		var ranks: Array = []
		for c in cards:
			ranks.append(c.rank)
		ranks.sort()
		var distinct := true
		for i in range(1, 4):
			if ranks[i] == ranks[i - 1]:
				distinct = false
				break
		if distinct and ranks[3] - ranks[0] == 3:
			return {"name": "STRAIGHT+", "bonus": 50, "color": Color(1.00, 0.85, 0.40)}
		return {"name": "", "bonus": 0, "color": Color.WHITE}
	return {"name": "", "bonus": 0, "color": Color.WHITE}


func _adjacency_bonus(col: int, row: int, placed: Card) -> int:
	var bonus := 0
	var neighbors := [
		Vector2i(col - 1, row),
		Vector2i(col + 1, row),
		Vector2i(col, row - 1),
		Vector2i(col, row + 1),
	]
	for n in neighbors:
		var neighbor: Card = playfield.card_at(n.x, n.y)
		if neighbor == null or neighbor.is_joker:
			continue
		if neighbor.rank == placed.rank:
			bonus += 5
		if neighbor.suit == placed.suit:
			bonus += 3
	return bonus


# --- popups, particles, shake ---


func _spawn_hand_popup(g: Dictionary, earned: int) -> void:
	var popup := Label.new()
	popup.text = "%s   +%d" % [String(g.name).to_upper(), earned]
	popup.add_theme_font_size_override("font_size", 56)
	var c := _color_for_hand_rank(int(g.rank))
	popup.add_theme_color_override("font_color", c)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	popup.add_theme_constant_override("outline_size", 10)
	popup.z_index = 100
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	await get_tree().process_frame

	var center := _center_of_cells(g.get("cells", []))
	popup.position = center - popup.size * 0.5
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.55, 0.55)
	var start_y := popup.position.y

	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", start_y - 160.0, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.40).set_delay(0.55)

	await tween.finished
	popup.queue_free()


func _spawn_dealer_popup(text: String, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 88)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	popup.add_theme_constant_override("outline_size", 14)
	popup.z_index = 120
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	await get_tree().process_frame

	popup.position = (size - popup.size) * 0.5
	popup.position.y -= 100.0
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.5, 0.5)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "scale", Vector2(1.1, 1.1), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.25)
	tween.tween_property(popup, "modulate:a", 0.0, 0.50).set_delay(0.65)

	await tween.finished
	popup.queue_free()


func _spawn_clear_particles(cells: Array) -> void:
	for cell in cells:
		var p: Vector2i = cell
		var rect: Rect2 = playfield.cell_local_rect(p.x, p.y)
		var center: Vector2 = playfield.global_position + rect.position + rect.size * 0.5
		var particles := CPUParticles2D.new()
		particles.position = center
		particles.amount = 14
		particles.lifetime = 0.55
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.direction = Vector2.UP
		particles.spread = 180.0
		particles.initial_velocity_min = 140.0
		particles.initial_velocity_max = 290.0
		particles.gravity = Vector2(0, 640)
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 6.0
		particles.color = Color(1.0, 0.92, 0.65, 1.0)
		particles.z_index = 50
		add_child(particles)
		particles.emitting = true
		get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


func _shake(intensity: float, duration: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		playfield.position = _shake_orig
	else:
		_shake_orig = playfield.position

	_shake_tween = create_tween()
	var elapsed := 0.0
	var step := 0.045
	while elapsed < duration:
		var amp := intensity * (1.0 - elapsed / duration)
		var offset := Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		_shake_tween.tween_property(playfield, "position", _shake_orig + offset, step)
		elapsed += step
	_shake_tween.tween_property(playfield, "position", _shake_orig, 0.05)


func _center_of_cells(cells: Array) -> Vector2:
	if cells.is_empty():
		return playfield.global_position + playfield.size * 0.5
	var sum := Vector2.ZERO
	for cell in cells:
		var p: Vector2i = cell
		var rect: Rect2 = playfield.cell_local_rect(p.x, p.y)
		sum += playfield.global_position + rect.position + rect.size * 0.5
	return sum / float(cells.size())


func _color_for_hand_rank(rank: int) -> Color:
	match rank:
		HandEvaluator.HandRank.ROYAL_FLUSH:
			return Color(1.0, 0.85, 0.30)
		HandEvaluator.HandRank.STRAIGHT_FLUSH:
			return Color(0.95, 0.65, 0.30)
		HandEvaluator.HandRank.FOUR_OF_A_KIND:
			return Color(0.85, 0.40, 0.95)
		HandEvaluator.HandRank.FULL_HOUSE:
			return Color(0.40, 0.80, 0.95)
		HandEvaluator.HandRank.FLUSH:
			return Color(0.50, 0.88, 0.50)
		HandEvaluator.HandRank.STRAIGHT:
			return Color(0.95, 0.78, 0.45)
		_:
			return Color(0.90, 0.90, 0.94)


func _spawn_cell_glow(g: Dictionary) -> void:
	var color := _color_for_hand_rank(int(g.rank))
	color.a = 0.75
	for cell in g.get("cells", []):
		var p: Vector2i = cell
		var rect: Rect2 = playfield.cell_local_rect(p.x, p.y)
		var pos: Vector2 = playfield.global_position + rect.position
		var glow := ColorRect.new()
		glow.position = pos
		glow.size = rect.size
		glow.color = color
		glow.pivot_offset = rect.size * 0.5
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.z_index = 60
		add_child(glow)
		var t := create_tween().set_parallel(true)
		t.tween_property(glow, "modulate:a", 0.0, 0.45)
		t.tween_property(glow, "scale", Vector2(1.18, 1.18), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.finished.connect(glow.queue_free)


func _show_round_splash(text: String) -> void:
	var splash := Label.new()
	splash.text = text
	splash.add_theme_font_size_override("font_size", 140)
	splash.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	splash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	splash.add_theme_constant_override("outline_size", 16)
	splash.z_index = 150
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(splash)
	await get_tree().process_frame
	splash.position = (size - splash.size) * 0.5
	splash.position.y -= 120.0
	splash.pivot_offset = splash.size * 0.5
	splash.scale = Vector2(0.4, 0.4)
	splash.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(splash, "scale", Vector2(1.0, 1.0), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(splash, "modulate:a", 1.0, 0.20)
	t.tween_property(splash, "modulate:a", 0.0, 0.40).set_delay(0.70)

	await t.finished
	splash.queue_free()


func _spawn_mini_popup(text: String, world_pos: Vector2, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 36)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	popup.add_theme_constant_override("outline_size", 6)
	popup.z_index = 90
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	await get_tree().process_frame
	popup.position = world_pos - popup.size * 0.5
	var start_y := popup.position.y

	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", start_y - 90.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.45).set_delay(0.25)

	await tween.finished
	popup.queue_free()


func _on_play_again_pressed() -> void:
	_start_new_game()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
