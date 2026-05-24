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

const DISCARDS_PER_RUN := 3
const HOLDS_PER_RUN := 3

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
@onready var discard_button: Button = $BottomArea/DiscardButton
@onready var hold_button: Button = $BottomArea/HoldButton
@onready var objectives_vbox: VBoxContainer = $BottomArea/ObjectivesContainer/ObjectivesVBox

const PERK_SHOP_SCENE := preload("res://scenes/PerkShopPanel.tscn")
var _perk_shop: Control = null

var _deck: Deck
var _specials_rng: RandomNumberGenerator = null
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

# Player actions: discard burns the current card; hold sets it aside or swaps
# with the held card. Both consume their respective counters.
var _discards_remaining: int = DISCARDS_PER_RUN
var _holds_remaining: int = HOLDS_PER_RUN
var _held_card: Card = null

# Per-run objectives: 3 random goals from Objectives.POOL. progress + completion
# tracked here; XP rewarded immediately on completion via SaveData.
var _objectives: Array = []
var _objective_progress: Dictionary = {}
var _objective_completed: Dictionary = {}
var _objective_xp_earned: int = 0

# Per-run modifier rolled in _start_new_game (or picked deterministically for
# daily mode). _active_* live values reflect modifier overrides on top of the
# constant defaults so the rest of the file can read live values without
# remembering "did the modifier touch this?"
var _modifier: Dictionary = {}
# Active boss rule (empty string = no boss rule). Set when transitioning to a
# boss dealer; cleared on next transition. Effects branch off this value in
# _process_cascades, _refresh_actions, and the combo path.
var _boss_rule: String = ""
var _combos_saved_state: bool = false  # restored when no_combos boss ends
var _active_combo_time: float = COMBO_TIME_MAX
var _active_combo_increment: float = COMBO_INCREMENT
var _active_round_length: int = ROUND_LENGTH
var _active_base_mult: float = 1.0
var _active_special_rate_mult: float = 1.0
var _active_joker_ratio: float = 0.6
var _active_cascade_tier_bonus: float = 0.0
var _combos_disabled: bool = false

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
	discard_button.pressed.connect(_on_discard_pressed)
	hold_button.pressed.connect(_on_hold_pressed)
	_perk_shop = PERK_SHOP_SCENE.instantiate()
	add_child(_perk_shop)
	_start_new_game()


func _start_new_game() -> void:
	# Daily mode uses a deterministic seed derived from today's date — every
	# player gets the same deck order AND the same Joker/Bomb positions.
	var seed_value := 0
	if MatchState.is_daily():
		seed_value = MatchState.daily_seed_for(MatchState.daily_date)
	_deck = Deck.new(seed_value)
	_specials_rng = RandomNumberGenerator.new()
	if seed_value != 0:
		# Offset so deck and specials don't draw correlated values from the
		# same stream. Both are still deterministic per-date.
		_specials_rng.seed = seed_value + 0x9E3779B9
	else:
		_specials_rng.randomize()
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
	_discards_remaining = DISCARDS_PER_RUN
	_holds_remaining = HOLDS_PER_RUN
	_held_card = null
	_objectives = Objectives.roll_for_run()
	_objective_progress = {}
	_objective_completed = {}
	for obj in _objectives:
		_objective_progress[obj.id] = 0
		_objective_completed[obj.id] = false
	_objective_xp_earned = 0
	if MatchState.is_daily():
		_modifier = Modifiers.for_daily(MatchState.daily_date)
	else:
		_modifier = Modifiers.roll_random()
	_apply_modifier(_modifier)
	_boss_rule = ""
	_combos_saved_state = _combos_disabled
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_preview.clear()
	for i in PREVIEW_SIZE:
		_preview.append(_draw_card_with_specials())
	_current = _draw_card_with_specials()
	playfield.reset()
	game_over_panel.hide_summary()
	_refresh()
	var splash_prefix := "DAILY · " if MatchState.is_daily() else ""
	var splash_subtitle: String = String(_modifier.get("name", "")).to_upper()
	_show_round_splash("%sROUND 1" % splash_prefix, splash_subtitle)


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
	if _current.is_sweep:
		await _drop_sweep(col)
		return

	var target_row: int = playfield.lowest_empty_row(col)
	if target_row < 0:
		print("[game] column %d full" % col)
		return

	_update_combo_state()
	# Multi grants an extra combo step (only when combos are enabled by modifier).
	if _current.is_multi and not _combos_disabled:
		_combo += 1
		SaveData.update_max_stat("highest_combo", _combo)
		_update_objective("max_combo", _combo)

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
	if _round_placements >= _active_round_length:
		await _evaluate_round()
		if _game_over:
			return

	_advance_queue()
	_combo_timer = _active_combo_time
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
	var combo_mult := 1.0 + float(maxi(0, _combo - 1)) * _active_combo_increment
	while true:
		var groups: Array = playfield.find_scoring_groups()
		if groups.is_empty():
			break
		cascade_tier += 1
		Sfx.play("clear")
		SaveData.update_max_stat("highest_cascade_tier", cascade_tier)
		_update_objective("max_cascade", cascade_tier)
		if cascade_tier >= 3:
			_try_achievement("triple_cascade")
		var tier_mult := 1.0 + float(cascade_tier - 1) * (0.5 + _active_cascade_tier_bonus)
		if cascade_tier >= 2:
			_shake(7.0, 0.18)

		var all_cells: Array = []
		for g in groups:
			# Boss: The Sharp — rows don't score or clear this round.
			if _boss_rule == "no_rows" and String(g.get("axis", "")) == "row":
				continue
			var earned := int(round(float(g.score) * tier_mult * combo_mult * _active_base_mult))
			score += earned
			all_cells.append_array(g.cells)

			if earned > _best_hand_score:
				_best_hand_score = earned
				_best_hand_name = String(g.name)
			# Boss: The Legend — only Trips+ count toward beating the dealer.
			var counts_for_round_best: bool = (_boss_rule != "royal_only"
				or int(g.get("rank", 0)) >= HandEvaluator.HandRank.THREE_OF_A_KIND)
			if counts_for_round_best and earned > _round_best_score:
				_round_best_score = earned
			_hands_seen_this_run[String(g.name)] = int(_hands_seen_this_run.get(g.name, 0)) + 1
			SaveData.increment_stat("total_hands_cleared")
			_update_objective("hand_count", 1, String(g.name))
			_update_objective("single_hand_score", earned)

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
		var was_boss := bool(_dealer_target.get("is_boss", false))
		# Bosses double the win payout (100% of target vs 50%).
		var bonus_mult: float = 1.0 if was_boss else 0.5
		var bonus := int(round(float(dealer_score) * bonus_mult))
		score += bonus
		_refresh_score()
		print("[dealer] %s (%d) BEATEN with %d → +%d bonus" \
			% [dealer_name, dealer_score, _round_best_score, bonus])
		Sfx.play("win")
		_try_achievement("first_dealer")
		_update_objective("dealers_beaten", 1)
		_spawn_dealer_popup("BEAT DEALER  +%d" % bonus, Color(0.45, 1.0, 0.65))
		_shake(10.0, 0.22)
		await get_tree().create_timer(0.55).timeout
		_clear_boss_rule()
		_dealer_tier += 1
		_dealer_target = Dealer.target_for_tier(_dealer_tier)
		SaveData.update_max_stat("highest_dealer_tier", _dealer_tier)
		if _dealer_tier >= 5:
			_try_achievement("marathon")
		var is_boss := bool(_dealer_target.get("is_boss", false))
		if is_boss:
			_apply_boss_rule(String(_dealer_target.get("rule_id", "")))
			await _show_round_splash("BOSS · ROUND %d" % _dealer_tier,
				"%s — %s" % [
					String(_dealer_target.get("name", "?")).to_upper(),
					String(_dealer_target.get("rule_text", "")),
				])
		else:
			await _show_round_splash("ROUND %d" % _dealer_tier,
				"— %s —" % String(_dealer_target.get("name", "?")).to_upper())
		# Perk shop appears between rounds — Balatro-style build-up.
		_perk_shop.show_choices(Perks.roll_choice())
		var picked: Dictionary = await _perk_shop.perk_picked
		_apply_perk(picked)
		_refresh()
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
	var is_new_best: bool = SaveData.record_score(score, MatchState.score_date_for_current_run())

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
		"xp_gained": total_xp + _objective_xp_earned,
		"xp_from_score": xp_from_score,
		"xp_from_hands": first_time_bonus,
		"xp_from_objectives": _objective_xp_earned,
		"previous_level": previous_level,
		"new_level": SaveData.level,
		"leveled_up": bool(add_result.get("leveled_up", false)),
		"objectives_completed": _completed_objective_count(),
		"objectives_total": _objectives.size(),
		"modifier_name": String(_modifier.get("name", "")),
	})


func _completed_objective_count() -> int:
	var n := 0
	for obj in _objectives:
		if bool(_objective_completed.get(obj.id, false)):
			n += 1
	return n


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
	var chance := _special_chance_for_tier(_tier) * _active_special_rate_mult
	# Use the seeded _specials_rng so daily-mode special placements are
	# deterministic too — without this, two players on the same daily seed
	# could see different Joker/Bomb positions.
	if _specials_rng.randf() < chance:
		# Joker share comes off the top; remaining specials (Bomb / Sweep /
		# Multi) split the rest in equal thirds so the joker_ratio modifier
		# still does its job cleanly.
		if _specials_rng.randf() < _active_joker_ratio:
			return Card.make_joker()
		var roll := _specials_rng.randf()
		if roll < 0.34:
			return Card.make_bomb()
		elif roll < 0.67:
			return Card.make_sweep()
		else:
			return Card.make_multi(_specials_rng)
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
	if _round_placements >= _active_round_length:
		await _evaluate_round()
		if _game_over:
			return

	_advance_queue()
	_combo_timer = _active_combo_time
	_refresh()
	_is_animating = false


# Sweep special: drops into the tapped column visually, then clears the bottom
# row of the grid (regardless of hand) and is consumed. Does not enter the grid.
func _drop_sweep(col: int) -> void:
	_is_animating = true
	var sweep := _current

	_update_combo_state()

	var visual_row: int = playfield.lowest_empty_row(col)
	if visual_row < 0:
		visual_row = 0
	await _animate_drop(sweep, col, visual_row)

	# Clear bottom row across all columns.
	var cells_to_clear: Array = []
	var bottom_row: int = PlayField.GRID_HEIGHT - 1
	for x in PlayField.GRID_WIDTH:
		if playfield.card_at(x, bottom_row) != null:
			cells_to_clear.append(Vector2i(x, bottom_row))

	if not cells_to_clear.is_empty():
		_spawn_clear_particles(cells_to_clear)
		playfield.clear_cells(cells_to_clear)
	Sfx.play("clear")
	_spawn_dealer_popup("SWEEP!", Color(0.40, 0.90, 0.75))
	_shake(12.0, 0.28)
	_on_placement_recorded(sweep)
	await get_tree().create_timer(CLEAR_DELAY).timeout
	playfield.apply_gravity()
	await get_tree().create_timer(GRAVITY_DELAY).timeout
	await _process_cascades()
	_check_tier_up()

	if playfield.is_any_column_full():
		_end_run("column_overflow")
		return

	_round_placements += 1
	if _round_placements >= _active_round_length:
		await _evaluate_round()
		if _game_over:
			return

	_advance_queue()
	_combo_timer = _active_combo_time
	_refresh()
	_is_animating = false


# Per-placement bookkeeping: stats, joker/bomb count, objective progress.
func _on_placement_recorded(placed: Card) -> void:
	_run_placements += 1
	SaveData.increment_stat("total_cards_placed")
	_update_objective("placements", 1)
	if placed != null and placed.is_joker:
		SaveData.increment_stat("total_jokers_played")
		_update_objective("jokers_placed", 1)
	if placed != null and placed.is_bomb:
		SaveData.increment_stat("total_bombs_played")
		_update_objective("bombs_detonated", 1)


# Centralized combo update so the bomb and normal-placement paths share rules.
# Bumps combo, plays SFX on first crossing into ≥2, claims Hot Streak at ≥5,
# and updates the lifetime highest_combo stat.
func _update_combo_state() -> void:
	if _combos_disabled:
		_combo = 0
		return
	if _combo_timer > 0.0:
		_combo += 1
		if _combo == 2:
			Sfx.play("combo")
		if _combo >= 5:
			_try_achievement("hot_streak")
	else:
		_combo = 1
	SaveData.update_max_stat("highest_combo", _combo)
	_update_objective("max_combo", _combo)


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
	_refresh_actions()
	_refresh_objectives()


func _refresh_actions() -> void:
	discard_button.text = "DISCARD ×%d" % _discards_remaining
	# Boss: The Cheat — discards locked while this round is active.
	discard_button.disabled = _discards_remaining <= 0 or _game_over \
		or _boss_rule == "no_discards"

	if _held_card == null:
		hold_button.text = "HOLD ×%d" % _holds_remaining
	else:
		hold_button.text = "HOLD: %s%s   ×%d" % \
			[_held_card.rank_label(), _held_card.suit_label(), _holds_remaining]
	hold_button.disabled = _holds_remaining <= 0 or _game_over


# Rebuilds the objectives display from the current progress/completion state.
# Called from _refresh and from _update_objective when something changed.
func _refresh_objectives() -> void:
	if objectives_vbox == null:
		return
	for c in objectives_vbox.get_children():
		c.queue_free()
	for obj in _objectives:
		var progress: int = int(_objective_progress.get(obj.id, 0))
		var target: int = int(obj.target)
		var done: bool = bool(_objective_completed.get(obj.id, false))
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 20)
		if done:
			row.text = "✓  %s" % String(obj.name)
			row.modulate = Color(0.50, 1.00, 0.65)
		else:
			row.text = "◯  %s   %d/%d" % [String(obj.name), progress, target]
			row.modulate = Color(0.75, 0.80, 0.92)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objectives_vbox.add_child(row)


# Updates objective progress for an event. event_type matches obj.type; for
# hand_count, hand_name must also match obj.target_name. Increment types add
# `value`; max types take max(current, value).
func _update_objective(event_type: String, value: int = 1, hand_name: String = "") -> void:
	if _game_over:
		return
	var any_updated := false
	for obj in _objectives:
		if bool(_objective_completed.get(obj.id, false)):
			continue
		if String(obj.type) != event_type:
			continue
		if event_type == "hand_count":
			if String(obj.get("target_name", "")) != hand_name:
				continue
		var current: int = int(_objective_progress.get(obj.id, 0))
		var new_value: int = current
		if event_type == "max_combo" or event_type == "max_cascade" or event_type == "single_hand_score":
			new_value = maxi(current, value)
		else:
			new_value = current + value
		if new_value == current:
			continue
		_objective_progress[obj.id] = new_value
		any_updated = true
		if new_value >= int(obj.target):
			_objective_completed[obj.id] = true
			_on_objective_complete(obj)
	if any_updated:
		_refresh_objectives()


# Applies one perk's effect to active run state. Perks stack with the modifier
# and with previously-applied perks (multiplicatively or additively depending
# on the field).
func _apply_perk(perk: Dictionary) -> void:
	var id: String = String(perk.get("id", ""))
	Sfx.play("win")
	print("[perk] applied: %s" % id)
	match id:
		"discard_master":
			_discards_remaining = mini(_discards_remaining + 2, 5)
		"hold_master":
			_holds_remaining = mini(_holds_remaining + 2, 5)
		"refill_actions":
			_discards_remaining = DISCARDS_PER_RUN
			_holds_remaining = HOLDS_PER_RUN
		"combo_time":
			_active_combo_time += 1.5
		"combo_power":
			_active_combo_increment += 0.1
		"base_power":
			_active_base_mult *= 1.15
		"joker_magnet":
			_active_joker_ratio = 0.85
		"cascade_king":
			_active_cascade_tier_bonus += 0.3
		"dealer_pity":
			# Lower the just-rolled next dealer's target by 20%
			var t: Dictionary = _dealer_target.duplicate(true)
			t["score"] = int(round(float(t.get("score", 0)) * 0.8))
			_dealer_target = t


# Activates a boss rule for the current round. Saves prior _combos_disabled
# state so we can restore it when the boss ends (otherwise a modifier like
# Steady Hand that already disabled combos would get clobbered).
func _apply_boss_rule(rule: String) -> void:
	_boss_rule = rule
	if rule == "no_combos":
		_combos_saved_state = _combos_disabled
		_combos_disabled = true


func _clear_boss_rule() -> void:
	var prior := _boss_rule
	_boss_rule = ""
	if prior == "no_combos":
		_combos_disabled = _combos_saved_state


func _apply_modifier(mod: Dictionary) -> void:
	_active_combo_time = float(mod.get("combo_time", COMBO_TIME_MAX))
	_active_combo_increment = COMBO_INCREMENT * float(mod.get("combo_increment_mult", 1.0))
	_active_round_length = int(mod.get("round_length", ROUND_LENGTH))
	_active_base_mult = float(mod.get("base_mult", 1.0))
	_active_special_rate_mult = float(mod.get("special_rate_mult", 1.0))
	_active_joker_ratio = float(mod.get("joker_ratio", 0.6))
	_active_cascade_tier_bonus = float(mod.get("cascade_mult_bonus", 0.0))
	_combos_disabled = bool(mod.get("combos_off", false))
	print("[mod] %s — %s" % [String(mod.get("name", "?")), String(mod.get("description", ""))])


func _on_objective_complete(obj: Dictionary) -> void:
	var xp_reward: int = int(obj.xp)
	SaveData.add_xp(xp_reward)
	_objective_xp_earned += xp_reward
	print("[obj] complete: %s (+%d XP)" % [obj.name, xp_reward])
	Sfx.play("win")
	_spawn_dealer_popup("OBJECTIVE!  %s  +%d" % [String(obj.name).to_upper(), xp_reward],
		Color(0.85, 1.00, 0.65))


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
	var dealer_color: Color = _dealer_target.get("color", Color(0.85, 0.55, 0.55))
	if bool(_dealer_target.get("is_boss", false)):
		dealer_info_label.text = "⚠ BOSS · %s · %d to beat" % [dealer_name.to_upper(), dealer_score]
	else:
		dealer_info_label.text = "⚔ %s · %d to beat" % [dealer_name.to_upper(), dealer_score]
	dealer_info_label.modulate = dealer_color
	var left := _active_round_length - _round_placements
	round_counter_label.text = "%d LEFT" % left
	if left <= 1:
		round_counter_label.modulate = Color(1.0, 0.4, 0.45)
	elif left <= 2:
		round_counter_label.modulate = Color(1.0, 0.75, 0.4)
	else:
		round_counter_label.modulate = Color(1.0, 0.95, 0.5)


func _refresh_combo_display() -> void:
	combo_bar.max_value = _active_combo_time
	combo_bar.value = _combo_timer
	var alive := _combo_timer > 0.0 and not _combos_disabled
	if alive and _combo > 1:
		combo_label.text = "COMBO ×%d" % _combo
	elif _combos_disabled:
		combo_label.text = "COMBOS OFF"
	else:
		combo_label.text = ""

	var ratio := _combo_timer / _active_combo_time if _active_combo_time > 0.0 else 0.0
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
	var combo_mult := 1.0 + float(maxi(0, _combo - 1)) * _active_combo_increment

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


func _show_round_splash(text: String, subtitle: String = "") -> void:
	# Title at 120pt + optional subtitle at 48pt with autowrap. Previous version
	# stuffed both into one Label so boss subtitles like "THE LEGEND — Only
	# Trips+ count" rendered at 120pt and ran way off-screen.
	const MAX_WIDTH := 980.0
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.z_index = 150
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 8)
	add_child(container)

	var title_label := Label.new()
	title_label.text = text
	title_label.add_theme_font_size_override("font_size", 120)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title_label.add_theme_constant_override("outline_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	container.add_child(title_label)

	if not subtitle.is_empty():
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.add_theme_font_size_override("font_size", 48)
		sub_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
		sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		sub_label.add_theme_constant_override("outline_size", 10)
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
		container.add_child(sub_label)

	await get_tree().process_frame
	container.size = container.get_combined_minimum_size()
	container.position = (size - container.size) * 0.5
	container.position.y -= 80.0
	container.pivot_offset = container.size * 0.5
	container.scale = Vector2(0.4, 0.4)
	container.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(container, "scale", Vector2(1.0, 1.0), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(container, "modulate:a", 1.0, 0.20)
	t.tween_property(container, "modulate:a", 0.0, 0.40).set_delay(0.85)

	await t.finished
	container.queue_free()


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


# Burns the current card without placing it. Advances queue, draws next.
func _on_discard_pressed() -> void:
	if _is_animating or _game_over or _current == null:
		return
	if _discards_remaining <= 0:
		return
	_discards_remaining -= 1
	Sfx.play("place")
	_advance_queue()
	_refresh()


# Holds the current card aside (if held slot empty) or swaps current with the
# held card. Each press consumes one hold use.
func _on_hold_pressed() -> void:
	if _is_animating or _game_over or _current == null:
		return
	if _holds_remaining <= 0:
		return
	_holds_remaining -= 1
	Sfx.play("place")
	if _held_card == null:
		_held_card = _current
		_advance_queue()
	else:
		var tmp: Card = _held_card
		_held_card = _current
		_current = tmp
	_refresh()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
