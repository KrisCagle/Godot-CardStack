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
@onready var wager_button: Button = $BottomArea/WagerButton
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

# Perk-driven run state. These accumulate across all picked perks; reset in
# _start_new_game. Each one is read at a specific hook point.
var _active_surge_combo_bonus: int = 1
var _anchor_free: bool = false
var _royal_treatment_bonus: float = 0.0
var _preview_visible_bonus: int = 0
var _time_stretch: bool = false
var _in_cascade: bool = false
var _xp_objective_mult: float = 1.0
var _lucky_draw_remaining: int = 0
# Second batch of perks
var _hearts_heater: bool = false
var _sharp_discount: bool = false
var _double_down: bool = false           # perk acquired
var _double_down_pending: bool = false   # consumed on first hand of round
var _combo_shield: bool = false
var _combo_reached_2_this_run: bool = false
var _action_surge: bool = false
var _bomb_score_bonus: int = 0

# Bonus cards: track Card refs that still have their "first hand 2×" pending.
# Cleared as soon as any hand the card participates in scores.
var _bonus_cards: Dictionary = {}

# Wager / Banking: amount banked for the current dealer round. Win = pay 2×
# back into score; lose = forfeit. One bank per round.
var _wager: int = 0

# Round target: each dealer round picks a random column the player should
# fill with 4 standard placements to earn a flat bonus. Resets each round.
const ROUND_TARGET_FILL := 4
const ROUND_TARGET_BONUS := 400
var _round_target_col: int = -1
var _round_target_count: int = 0
var _round_target_complete: bool = false
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
	wager_button.pressed.connect(_on_wager_pressed)
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
	_active_surge_combo_bonus = 1
	_anchor_free = false
	_royal_treatment_bonus = 0.0
	_preview_visible_bonus = 0
	_time_stretch = false
	_in_cascade = false
	_xp_objective_mult = 1.0
	_lucky_draw_remaining = 0
	_hearts_heater = false
	_sharp_discount = false
	_double_down = false
	_double_down_pending = false
	_combo_shield = false
	_combo_reached_2_this_run = false
	_action_surge = false
	_bomb_score_bonus = 0
	_bonus_cards = {}
	_wager = 0
	_roll_round_target()
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
	# Time Stretch perk: pause combo timer while cascades are resolving.
	if _time_stretch and _in_cascade:
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
	if _current.is_shuffle:
		await _drop_shuffle(col)
		return
	if _current.is_mirror:
		await _drop_mirror(col)
		return
	if _current.is_burst:
		await _drop_burst(col)
		return

	var target_row: int = playfield.lowest_empty_row(col)
	if target_row < 0:
		print("[game] column %d full" % col)
		return

	_update_combo_state()
	# Surge grants extra combo steps (Echo Combo perk bumps this from +1 to +2).
	if _current.is_surge and not _combos_disabled:
		_combo += _active_surge_combo_bonus
		SaveData.update_max_stat("highest_combo", _combo)
		_update_objective("max_combo", _combo)

	_is_animating = true
	var placed := _current
	await _animate_drop(placed, col, target_row)
	Sfx.play("place")
	playfield.place_card(placed, col)
	# Bonus cards: track the placed Card ref so the next hand it's in scores 2×.
	if placed.is_bonus:
		_bonus_cards[placed] = true
	_apply_placement_bonuses(col, target_row, placed)
	if placed.is_crown:
		_apply_crown_effect(col, target_row)
	_on_placement_recorded(placed)
	_track_round_target(col)
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
	_in_cascade = true
	var cascade_tier := 0
	var combo_mult := 1.0 + float(maxi(0, _combo - 1)) * _active_combo_increment
	while true:
		var groups: Array = playfield.find_scoring_groups()
		if groups.is_empty():
			break

		# Upstream filter: drop groups that wouldn't actually clear anything
		# (all-Anchor cells), and drop row groups when the boss rule says so.
		# Without this, a pair-of-Anchors loops forever — same group keeps
		# returning, cascade_tier keeps incrementing, sound + Avalanche
		# achievement keep firing.
		var actionable: Array = []
		for g in groups:
			if _boss_rule == "no_rows" and String(g.get("axis", "")) == "row":
				continue
			# Boss: The Whale — columns don't score or clear this round.
			if _boss_rule == "no_columns" and String(g.get("axis", "")) == "column":
				continue
			var has_clearable := false
			for cell in g.cells:
				var pc: Card = playfield.card_at(cell.x, cell.y)
				if pc == null:
					continue
				# Anchor Free perk lets Anchor cells clear normally.
				if not pc.is_anchor or _anchor_free:
					has_clearable = true
					break
			if has_clearable:
				actionable.append(g)

		if actionable.is_empty():
			break

		cascade_tier += 1
		Sfx.play("clear")
		SaveData.update_max_stat("highest_cascade_tier", cascade_tier)
		_update_objective("max_cascade", cascade_tier)
		if cascade_tier >= 3:
			_try_achievement("triple_cascade")
		if cascade_tier >= 5:
			_try_achievement("cascading")
		var tier_mult := 1.0 + float(cascade_tier - 1) * (0.5 + _active_cascade_tier_bonus)
		if cascade_tier >= 2:
			_shake(7.0, 0.18)

		# Multi-hand bonus: when multiple groups fire in the same tier we
		# bump combo (one per extra hand), apply a score multiplier, and
		# pop a celebratory DOUBLE/TRIPLE/QUAD CASCADE label. Makes the
		# "set up two columns then drop the trigger" play feel huge.
		var n_groups: int = actionable.size()
		var multi_mult: float = 1.0
		if n_groups >= 4:
			multi_mult = 2.0
		elif n_groups == 3:
			multi_mult = 1.5
		elif n_groups == 2:
			multi_mult = 1.25
		if n_groups >= 2 and not _combos_disabled:
			# Extra +1 combo per additional hand cleared this tier (combo
			# was already bumped once for the placement that triggered the
			# cascade).
			_combo += n_groups - 1
			SaveData.update_max_stat("highest_combo", _combo)
			_update_objective("max_combo", _combo)
			# Recompute combo_mult for this tier so the bump applies now.
			combo_mult = 1.0 + float(maxi(0, _combo - 1)) * _active_combo_increment
		if n_groups >= 2:
			_spawn_multi_hand_splash(n_groups)

		var all_cells: Array = []
		var group_idx: int = 0
		for g in actionable:
			# Flare: any Flare card in the hand triples the score (single 3×
			# regardless of how many — avoids 9× / 27× cheese).
			var has_flare: bool = false
			for cell in g.cells:
				var p: Vector2i = cell
				var gc: Card = playfield.card_at(p.x, p.y)
				if gc != null and gc.is_flare:
					has_flare = true
					break
			var flare_mult: float = 3.0 if has_flare else 1.0
			# Royal Treatment perk: face-card-containing hands get a bonus.
			var royal_mult: float = 1.0
			if _royal_treatment_bonus > 0.0:
				for cell in g.cells:
					var p2: Vector2i = cell
					var rc: Card = playfield.card_at(p2.x, p2.y)
					if rc != null and not rc.is_special and rc.rank >= Card.Rank.JACK:
						royal_mult = 1.0 + _royal_treatment_bonus
						break
			# Hearts Heater perk: +20% per Heart in the scoring hand.
			var hearts_mult: float = 1.0
			if _hearts_heater:
				var heart_count := 0
				for cell in g.cells:
					var p3: Vector2i = cell
					var hc: Card = playfield.card_at(p3.x, p3.y)
					if hc != null and not hc.is_special and hc.suit == Card.Suit.HEARTS:
						heart_count += 1
				hearts_mult = 1.0 + float(heart_count) * 0.2
			# Double Down perk: first scoring hand of the round gets 2×, then
			# the flag clears for the rest of the round.
			var double_mult: float = 1.0
			if _double_down_pending:
				double_mult = 2.0
				_double_down_pending = false
			# Bonus card: if any cell in this hand is a tracked Bonus, score 2×
			# and clear that bonus state (one-shot).
			var bonus_mult: float = 1.0
			for cell in g.cells:
				var p4: Vector2i = cell
				var bc: Card = playfield.card_at(p4.x, p4.y)
				if bc != null and _bonus_cards.get(bc, false):
					bonus_mult = 2.0
					_bonus_cards.erase(bc)
					SaveData.increment_stat("total_bonus_triggered")
					_check_threshold_achievement("bonus_hunter", "total_bonus_triggered", 10)
					break
			var earned := int(round(float(g.score) * tier_mult * combo_mult * _active_base_mult * flare_mult * royal_mult * hearts_mult * double_mult * bonus_mult * multi_mult))
			score += earned
			all_cells.append_array(g.cells)

			if earned > _best_hand_score:
				_best_hand_score = earned
				_best_hand_name = String(g.name)
			# Boss rules that gate what counts toward beating the round:
			#   royal_only — only Three of a Kind+ count (The Legend).
			#   high_only  — only Flush+ count (The Boss).
			# Hands below the threshold still score normally; they just don't
			# advance _round_best_score against the dealer.
			var rank_int: int = int(g.get("rank", 0))
			var counts_for_round_best := true
			if _boss_rule == "royal_only" and rank_int < HandEvaluator.HandRank.THREE_OF_A_KIND:
				counts_for_round_best = false
			elif _boss_rule == "high_only" and rank_int < HandEvaluator.HandRank.FLUSH:
				counts_for_round_best = false
			if counts_for_round_best and earned > _round_best_score:
				_round_best_score = earned
			_hands_seen_this_run[String(g.name)] = int(_hands_seen_this_run.get(g.name, 0)) + 1
			SaveData.increment_stat("total_hands_cleared")
			_update_objective("hand_count", 1, String(g.name))
			_update_objective("single_hand_score", earned)
			# Hand-specific lifetime counters + achievements.
			match String(g.name):
				"Pair":
					SaveData.increment_stat("total_pairs_scored")
					_check_threshold_achievement("pair_up", "total_pairs_scored", 50)
				"Flush":
					SaveData.increment_stat("total_flushes_scored")
					_check_threshold_achievement("flush_master", "total_flushes_scored", 20)

			# Achievement: Royal Flush ever, Wild Thing if a Joker contributed.
			if int(g.rank) == HandEvaluator.HandRank.ROYAL_FLUSH:
				_try_achievement("royal_flush")
			for cell in g.cells:
				var p: Vector2i = cell
				var c: Card = playfield.card_at(p.x, p.y)
				if c != null and c.is_joker:
					_try_achievement("wild_thing")
					break

			print("[score] %s (%s) %d × tier %.1f × combo %.1f × multi %.2f → %d  (total %d)" \
				% [g.name, g.axis, g.score, tier_mult, combo_mult, multi_mult, earned, score])

			# Stagger popup + glow per group so multi-hand drops cascade visually
			# (ping … ping … ping) instead of one big simultaneous flash.
			_spawn_hand_popup_delayed(g, earned, group_idx * 0.12)
			_spawn_cell_glow_delayed(g, group_idx * 0.12)
			if int(g.rank) >= HandEvaluator.HandRank.FOUR_OF_A_KIND:
				_shake(14.0, 0.30)
			group_idx += 1

		_refresh_score()
		if score >= 5000:
			_try_achievement("big_spender")

		var seen: Dictionary = {}
		var unique_cells: Array = []
		for c in all_cells:
			if seen.has(c):
				continue
			seen[c] = true
			# Anchor cells participate in scoring but never clear — leave them
			# on the grid as permanent blockers. Unless Anchor Free perk says
			# otherwise.
			var p: Vector2i = c
			var card_here: Card = playfield.card_at(p.x, p.y)
			if card_here != null and card_here.is_anchor and not _anchor_free:
				continue
			unique_cells.append(c)

		# Hold a touch longer when multiple groups are staggering — lets the
		# last popup (group N at +N*0.12s) actually appear before everything
		# clears off-screen.
		var stagger_hold: float = 0.18 + maxf(0.0, float(n_groups - 1) * 0.12)
		await get_tree().create_timer(stagger_hold).timeout
		_spawn_clear_particles(unique_cells)
		playfield.clear_cells(unique_cells)
		await get_tree().create_timer(CLEAR_DELAY).timeout
		playfield.apply_gravity()
		await get_tree().create_timer(GRAVITY_DELAY).timeout
	_in_cascade = false


func _evaluate_round() -> void:
	var dealer_score: int = int(_dealer_target.get("score", 0))
	var dealer_name: String = String(_dealer_target.get("name", "?"))

	if _round_best_score > dealer_score:
		var was_boss := bool(_dealer_target.get("is_boss", false))
		# Bosses double the win payout (100% of target vs 50%).
		var bonus_mult: float = 1.0 if was_boss else 0.5
		var bonus := int(round(float(dealer_score) * bonus_mult))
		# Wager payout: if banked, return 2× the wager (net gain = wager amount).
		if _wager > 0:
			var payout: int = _wager * 2
			score += payout
			_spawn_mini_popup("WAGER  +%d" % payout,
				Vector2(size.x * 0.5, 260.0),
				Color(0.95, 1.00, 0.55))
			_wager = 0
			SaveData.increment_stat("total_wagers_won")
			_check_threshold_achievement("wager_wizard", "total_wagers_won", 5)
		score += bonus
		_refresh_score()
		print("[dealer] %s (%d) BEATEN with %d → +%d bonus" \
			% [dealer_name, dealer_score, _round_best_score, bonus])
		Sfx.play("win")
		_try_achievement("first_dealer")
		_update_objective("dealers_beaten", 1)
		# Boss tracking for the Boss Slayer achievement.
		if was_boss:
			SaveData.mark_boss_beaten(String(_dealer_target.get("id", "")))
			if SaveData.bosses_beaten_count() >= 6:
				_try_achievement("boss_slayer")
		_spawn_dealer_popup("BEAT DEALER  +%d" % bonus, Color(0.45, 1.0, 0.65))
		_shake(10.0, 0.22)
		await get_tree().create_timer(0.55).timeout
		_clear_boss_rule()
		_dealer_tier += 1
		_dealer_target = Dealer.target_for_tier(_dealer_tier)
		# Sharp Discount perk: trim boss dealer targets by 25%.
		if _sharp_discount and bool(_dealer_target.get("is_boss", false)):
			var dt: Dictionary = _dealer_target.duplicate(true)
			dt["score"] = int(round(float(dt.get("score", 0)) * 0.75))
			_dealer_target = dt
		SaveData.update_max_stat("highest_dealer_tier", _dealer_tier)
		if _dealer_tier >= 5:
			_try_achievement("marathon")
		# Round-start perk effects: Action Surge refills actions; Double Down
		# rearms its single-hand bonus for the new round.
		if _action_surge:
			_discards_remaining = DISCARDS_PER_RUN
			_holds_remaining = HOLDS_PER_RUN
		if _double_down:
			_double_down_pending = true
		# Roll a fresh column target for the new round.
		_roll_round_target()
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
	# Level-threshold achievement check after the XP award resolves.
	if SaveData.level >= 12:
		_try_achievement("theme_collector")

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
	var base := 0
	if _tier <= 2:
		base = 3
	elif _tier <= 4:
		base = 2
	elif _tier <= 6:
		base = 1
	# Wider View perk bumps the visible preview count; cap at the underlying
	# queue size so we don't index out of range.
	return clampi(base + _preview_visible_bonus, 0, PREVIEW_SIZE)


func _advance_queue() -> void:
	_current = _preview[0]
	for i in range(PREVIEW_SIZE - 1):
		_preview[i] = _preview[i + 1]
	_preview[PREVIEW_SIZE - 1] = _draw_card_with_specials()


func _draw_card_with_specials() -> Card:
	# Lucky Draw perk: next N draws are guaranteed normal cards (skip the
	# special roll entirely). Counter is set by the perk match arm.
	if _lucky_draw_remaining > 0:
		_lucky_draw_remaining -= 1
		return _deck.draw_card()
	var chance := _special_chance_for_tier(_tier) * _active_special_rate_mult
	# Use the seeded _specials_rng so daily-mode special placements are
	# deterministic too — without this, two players on the same daily seed
	# could see different Joker/Bomb positions.
	if _specials_rng.randf() < chance:
		# Joker share comes off the top; the remaining 10 specials (Bomb /
		# Sweep / Surge / Anchor / Flare / Crown / Shuffle / Mirror / Burst /
		# Bonus) split the rest in equal tenths so the joker_ratio modifier
		# still controls the Joker share.
		if _specials_rng.randf() < _active_joker_ratio:
			return Card.make_joker()
		var roll: int = _specials_rng.randi() % 10
		match roll:
			0:
				return Card.make_bomb()
			1:
				return Card.make_sweep()
			2:
				return Card.make_surge(_specials_rng)
			3:
				return Card.make_anchor(_specials_rng)
			4:
				return Card.make_flare(_specials_rng)
			5:
				return Card.make_crown(_specials_rng)
			6:
				return Card.make_shuffle()
			7:
				return Card.make_mirror(_specials_rng)
			8:
				return Card.make_burst(_specials_rng)
			_:
				return Card.make_bonus(_specials_rng)
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
	# Bomb Discount perk: bombs grant a flat score bonus on detonation.
	if _bomb_score_bonus > 0:
		score += _bomb_score_bonus
		_refresh_score()
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


# Promote effect: bump all 4-neighbor non-special cards by +1 rank, capped
# at Ace. Fires a small popup showing how many cards got bumped.
func _apply_crown_effect(col: int, row: int) -> void:
	var neighbors := [
		Vector2i(col - 1, row),
		Vector2i(col + 1, row),
		Vector2i(col, row - 1),
		Vector2i(col, row + 1),
	]
	var promoted := 0
	for n in neighbors:
		var c: Card = playfield.card_at(n.x, n.y)
		if c == null or c.is_special:
			continue
		if c.rank >= Card.Rank.ACE:
			continue
		c.rank += 1
		promoted += 1
	if promoted > 0:
		playfield.queue_redraw()
		var rect: Rect2 = playfield.cell_local_rect(col, row)
		var center: Vector2 = playfield.global_position + rect.position + rect.size * 0.5
		_spawn_mini_popup("↑ %d" % promoted, center, Color(1.00, 0.85, 0.40))


# Shuffle special: consumed on placement (doesn't enter the grid). Gathers
# every card on the grid, shuffles them, and re-places into random columns
# bottom-up. Steel cards get shuffled too — Steel only resists CLEAR, not
# rearrangement.
func _drop_shuffle(col: int) -> void:
	_is_animating = true
	var shuffle_card := _current

	_update_combo_state()

	var visual_row: int = playfield.lowest_empty_row(col)
	if visual_row < 0:
		visual_row = 0
	await _animate_drop(shuffle_card, col, visual_row)

	var all_cards: Array = []
	for x in PlayField.GRID_WIDTH:
		for y in PlayField.GRID_HEIGHT:
			var c: Card = playfield.card_at(x, y)
			if c != null:
				all_cards.append(c)
	all_cards.shuffle()

	playfield.reset()
	for c in all_cards:
		var attempts := 0
		while attempts < 20:
			var col_pick: int = randi() % PlayField.GRID_WIDTH
			var row_pick: int = playfield.lowest_empty_row(col_pick)
			if row_pick >= 0:
				playfield.place_card(c, col_pick)
				break
			attempts += 1

	Sfx.play("clear")
	_spawn_dealer_popup("SHUFFLE!", Color(0.85, 0.55, 1.00))
	_shake(10.0, 0.30)
	_on_placement_recorded(shuffle_card)
	await get_tree().create_timer(CLEAR_DELAY).timeout
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


# Mirror special: places a copy of itself (rank + suit) in the tapped column
# AND its mirror column (GRID_WIDTH-1-col). The Mirror card itself is consumed
# and the two copies behave as normal cards.
func _drop_mirror(col: int) -> void:
	_is_animating = true
	var mirror := _current
	_update_combo_state()

	var target_row: int = playfield.lowest_empty_row(col)
	var mirror_col: int = PlayField.GRID_WIDTH - 1 - col
	var mirror_row: int = -1
	if mirror_col != col:
		mirror_row = playfield.lowest_empty_row(mirror_col)

	if target_row < 0 and mirror_row < 0:
		# Nowhere to land; consume harmlessly.
		_is_animating = false
		_advance_queue()
		_refresh()
		return

	var anim_row := target_row if target_row >= 0 else mirror_row
	var anim_col := col if target_row >= 0 else mirror_col
	await _animate_drop(mirror, anim_col, anim_row)
	Sfx.play("place")

	if target_row >= 0:
		var primary := Card.new(mirror.suit, mirror.rank)
		playfield.place_card(primary, col)
		_apply_placement_bonuses(col, target_row, primary)
	if mirror_col != col and mirror_row >= 0:
		var twin := Card.new(mirror.suit, mirror.rank)
		playfield.place_card(twin, mirror_col)
		_apply_placement_bonuses(mirror_col, mirror_row, twin)

	_spawn_dealer_popup("MIRROR!", Color(0.55, 0.85, 1.00))
	_on_placement_recorded(mirror)
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


# Burst special: real card that, on placement, clears the 3×3 of cells around
# its landing cell (the burst card itself stays — it's a real card).
func _drop_burst(col: int) -> void:
	_is_animating = true
	var burst := _current
	_update_combo_state()

	var target_row: int = playfield.lowest_empty_row(col)
	if target_row < 0:
		# Column full — consume harmlessly.
		_is_animating = false
		_advance_queue()
		_refresh()
		return

	await _animate_drop(burst, col, target_row)
	Sfx.play("place")
	var burst_real := Card.new(burst.suit, burst.rank)
	playfield.place_card(burst_real, col)
	_apply_placement_bonuses(col, target_row, burst_real)

	# Clear 3×3 of cells around the burst, excluding itself.
	var cells_to_clear: Array = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var x: int = col + dx
			var y: int = target_row + dy
			if x < 0 or x >= PlayField.GRID_WIDTH:
				continue
			if y < 0 or y >= PlayField.GRID_HEIGHT:
				continue
			var neighbor: Card = playfield.card_at(x, y)
			if neighbor == null:
				continue
			# Respect Anchors (unless the Anchor Free perk says otherwise).
			if neighbor.is_anchor and not _anchor_free:
				continue
			cells_to_clear.append(Vector2i(x, y))

	if not cells_to_clear.is_empty():
		_spawn_clear_particles(cells_to_clear)
		playfield.clear_cells(cells_to_clear)
	Sfx.play("boom")
	_spawn_dealer_popup("BURST!", Color(1.00, 0.65, 0.30))
	_shake(14.0, 0.30)
	_on_placement_recorded(burst)
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
	if placed == null:
		return
	if placed.is_joker:
		SaveData.increment_stat("total_jokers_played")
		_update_objective("jokers_placed", 1)
	if placed.is_bomb:
		SaveData.increment_stat("total_bombs_played")
		_update_objective("bombs_detonated", 1)
	# Objective hooks for the rest of the special pool.
	if placed.is_anchor:
		_update_objective("anchors_placed", 1)
		SaveData.increment_stat("total_anchors_placed")
		_check_threshold_achievement("anchor_master", "total_anchors_placed", 10)
	if placed.is_flare:
		_update_objective("flares_placed", 1)
	if placed.is_crown:
		_update_objective("crowns_placed", 1)
		SaveData.increment_stat("total_crowns_placed")
		_check_threshold_achievement("crown_royalty", "total_crowns_placed", 10)
	if placed.is_sweep:
		_update_objective("waves_used", 1)
		SaveData.increment_stat("total_sweeps_used")
		_check_threshold_achievement("sweep_crew", "total_sweeps_used", 10)
	if placed.is_shuffle:
		_update_objective("shuffles_used", 1)
		SaveData.increment_stat("total_shuffles_used")
		_check_threshold_achievement("shuffler", "total_shuffles_used", 5)
	if placed.is_mirror:
		SaveData.increment_stat("total_mirrors_placed")
		_check_threshold_achievement("mirror_master", "total_mirrors_placed", 5)
	if placed.is_burst:
		SaveData.increment_stat("total_bursts_used")
		_check_threshold_achievement("burst_king", "total_bursts_used", 5)
	# Long-tail per-run + lifetime
	if _run_placements >= 100:
		# Centenarian was originally "level 10" but the trigger has always been
		# placement-based; leave it as the long-run badge.
		_try_achievement("centenarian")


# Helper: claim an achievement once its tracked stat reaches `threshold`.
# Safe to call every time the stat increments — claim_achievement is idempotent.
func _check_threshold_achievement(achievement_id: String, stat_key: String, threshold: int) -> void:
	if SaveData.get_stat(stat_key) >= threshold:
		_try_achievement(achievement_id)


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
			_combo_reached_2_this_run = true
		if _combo >= 5:
			_try_achievement("hot_streak")
		if _combo >= 15:
			_try_achievement("mega_combo")
	else:
		# Combo Shield perk: once combo hit 2 this run, it can't drop below 2.
		if _combo_shield and _combo_reached_2_this_run:
			_combo = 2
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

	# Wager: bank 20% of current score. Disabled once banked OR if score
	# too low to make a meaningful bank.
	if _wager > 0:
		wager_button.text = "BANKED  %d" % _wager
		wager_button.disabled = true
	else:
		var stake: int = int(round(float(score) * 0.20))
		wager_button.text = "BANK  %d" % stake
		wager_button.disabled = stake <= 0 or _game_over


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
	_update_objective("perks_picked", 1)
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
		"big_spender":
			_active_base_mult *= 1.20
		"echo_combo":
			_active_surge_combo_bonus = 2
		"anchor_free":
			_anchor_free = true
		"royal_treatment":
			_royal_treatment_bonus = 0.5
		"wider_view":
			_preview_visible_bonus += 1
		"time_stretch":
			_time_stretch = true
		"xp_doubler":
			_xp_objective_mult = 1.5
		"lucky_draw":
			_lucky_draw_remaining = 5
		"hearts_heater":
			_hearts_heater = true
		"quick_tap":
			_active_combo_time += 3.0
		"round_stretcher":
			_active_round_length += 2
		"sharp_discount":
			_sharp_discount = true
			# Apply to currently-rolled dealer if it's a boss.
			if bool(_dealer_target.get("is_boss", false)):
				var dt: Dictionary = _dealer_target.duplicate(true)
				dt["score"] = int(round(float(dt.get("score", 0)) * 0.75))
				_dealer_target = dt
		"double_down":
			_double_down = true
			_double_down_pending = true  # arm for current round too
		"combo_shield":
			_combo_shield = true
		"action_surge":
			_action_surge = true
			# Refill immediately for the upcoming round.
			_discards_remaining = DISCARDS_PER_RUN
			_holds_remaining = HOLDS_PER_RUN
		"bomb_discount":
			_bomb_score_bonus = 200


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
	# XP Multiplier perk: bump objective XP rewards.
	var xp_reward: int = int(round(float(obj.xp) * _xp_objective_mult))
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
	# Horizontal 3- and 4-windows containing (col, row).
	for size: int in [3, 4]:
		for offset: int in size:
			var start_col: int = col - offset
			if start_col < 0 or start_col + size > PlayField.GRID_WIDTH:
				continue
			var hit := _check_partial_window(start_col, row, 1, 0, size)
			if not hit.is_empty():
				hits.append(hit)
	# Vertical 3- and 4-windows.
	for size: int in [3, 4]:
		for offset: int in size:
			var start_row: int = row - offset
			if start_row < 0 or start_row + size > PlayField.GRID_HEIGHT:
				continue
			var hit := _check_partial_window(col, start_row, 0, 1, size)
			if not hit.is_empty():
				hits.append(hit)
	# Diagonal 4-windows (Connect 4 four-in-a-row, both directions). The
	# placed cell can be at any offset 0..3 along the window.
	for offset: int in 4:
		# ↘ diagonal: dx=1, dy=1
		var sc: int = col - offset
		var sr: int = row - offset
		if sc >= 0 and sc + 4 <= PlayField.GRID_WIDTH \
			and sr >= 0 and sr + 4 <= PlayField.GRID_HEIGHT:
			var hit_dr := _check_partial_window(sc, sr, 1, 1, 4)
			if not hit_dr.is_empty():
				hits.append(hit_dr)
		# ↙ diagonal: dx=-1, dy=1. Start at the rightmost cell of the window.
		var sc2: int = col + offset
		var sr2: int = row - offset
		if sc2 - 3 >= 0 and sc2 < PlayField.GRID_WIDTH \
			and sr2 >= 0 and sr2 + 4 <= PlayField.GRID_HEIGHT:
			var hit_dl := _check_partial_window(sc2, sr2, -1, 1, 4)
			if not hit_dl.is_empty():
				hits.append(hit_dl)
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
		# QUAD STRIKE — 4 same rank in a 4-window. Connect 4 four-in-a-row
		# meets four-of-a-kind. Rarest 4-window pattern, highest payout.
		var all_same_rank := true
		for i in range(1, 4):
			if cards[i].rank != cards[0].rank:
				all_same_rank = false
				break
		if all_same_rank:
			return {"name": "QUAD STRIKE", "bonus": 150, "color": Color(0.85, 0.40, 1.00)}
		var same_suit := true
		for i in range(1, 4):
			if cards[i].suit != cards[0].suit:
				same_suit = false
				break
		if same_suit:
			return {"name": "FLUSH+", "bonus": 75, "color": Color(0.50, 0.95, 0.60)}
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
			return {"name": "STRAIGHT+", "bonus": 75, "color": Color(1.00, 0.85, 0.40)}
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


# Wrapper that delays the popup spawn so multi-hand cascades stagger visually
# (popup A at t=0, popup B at t+0.12s, popup C at t+0.24s …). Awaiting on a
# zero-duration timer would still work; the explicit branch just dodges a
# pointless allocation when there's no delay.
func _spawn_hand_popup_delayed(g: Dictionary, earned: int, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_spawn_hand_popup(g, earned)


# Same idea for the cell glow halo so the glow appears in lockstep with its
# matching popup during staggered multi-hand reveals.
func _spawn_cell_glow_delayed(g: Dictionary, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_spawn_cell_glow(g)


# Celebration banner when 2+ scoring groups fire in the same cascade tier.
# Sits center-screen, scales in, holds, fades. Color and label scale with
# the count: gold for DOUBLE, hot-pink for TRIPLE, electric for QUAD+.
func _spawn_multi_hand_splash(count: int) -> void:
	var text: String
	var color: Color
	if count >= 4:
		text = "QUAD CASCADE!"
		color = Color(0.55, 0.95, 1.00)
	elif count == 3:
		text = "TRIPLE!"
		color = Color(1.00, 0.55, 0.85)
	else:
		text = "DOUBLE!"
		color = Color(1.00, 0.88, 0.40)

	var popup := Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 96)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	popup.add_theme_constant_override("outline_size", 14)
	popup.z_index = 125
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	await get_tree().process_frame

	popup.position = (size - popup.size) * 0.5
	popup.position.y -= 220.0
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.45, 0.45)
	popup.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(popup, "scale", Vector2(1.15, 1.15), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.22)
	t.tween_property(popup, "modulate:a", 1.0, 0.18)
	t.tween_property(popup, "modulate:a", 0.0, 0.45).set_delay(0.70)

	await t.finished
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
# Rolls a fresh round target. Picks a random column and tints it on the
# playfield. Called at game start and at the start of each new dealer round.
func _roll_round_target() -> void:
	_round_target_col = randi() % PlayField.GRID_WIDTH
	_round_target_count = 0
	_round_target_complete = false
	if playfield != null:
		playfield.target_col = _round_target_col
		playfield.queue_redraw()


# Each standard column tap counts toward the round target if it lands in the
# tinted column. On hitting the threshold, awards the flat bonus + popup.
# Specials (Sweep / Shuffle / Mirror / Burst) intentionally don't count —
# only deliberate column-tap placements.
func _track_round_target(col: int) -> void:
	if _round_target_complete or _round_target_col < 0:
		return
	if col != _round_target_col:
		return
	_round_target_count += 1
	if _round_target_count >= ROUND_TARGET_FILL:
		_round_target_complete = true
		score += ROUND_TARGET_BONUS
		_spawn_dealer_popup("TARGET FILLED  +%d" % ROUND_TARGET_BONUS,
			Color(1.00, 0.85, 0.40))
		_refresh_score()


func _on_wager_pressed() -> void:
	if _game_over or _wager > 0:
		return
	var stake: int = int(round(float(score) * 0.20))
	if stake <= 0:
		return
	_wager = stake
	score -= stake
	Sfx.play("place")
	_spawn_mini_popup("BANK  %d" % stake,
		Vector2(size.x * 0.5, 220.0),
		Color(0.95, 0.85, 0.40))
	SaveData.update_max_stat("max_wager", stake)
	if stake >= 1000:
		_try_achievement("high_roller")
	_refresh_score()
	_refresh_actions()


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
