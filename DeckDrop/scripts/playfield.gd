class_name PlayField
extends Control
## The 5x8 play grid. Owns visual rendering, column-tap input, and grid state.
## Game.gd asks where a card would land, animates the drop, then commits the
## card via place_card and runs the scoring/cascade loop using find_scoring_groups,
## clear_cells, and apply_gravity.
##
## Scoring axes: full rows (top-to-bottom), bottom-5 of each column, and 5-card
## diagonals (down-right and down-left, 4 starting positions each in our 5×8 grid).

const GRID_WIDTH := 5
const GRID_HEIGHT := 8
const COL_WINDOW := 5  # Length of a column scoring window.
const CELL_PAD := 6.0

const COLOR_FLASH := Color(0.45, 0.65, 1.0, 1.0)
const FLASH_DURATION := 0.18

signal column_tapped(col: int)

# grid[col][row] -> Card or null. Row 0 is top, row GRID_HEIGHT-1 is bottom.
var grid: Array = []

var _flash_col: int = -1
var _flash_t: float = 0.0

# game.gd sets this to highlight the current round's target column. -1 = no
# target (e.g., game over, between rounds). Drawn as a faint gold tint.
var target_col: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_init_grid()


func reset() -> void:
	_init_grid()
	queue_redraw()


func lowest_empty_row(col: int) -> int:
	if col < 0 or col >= GRID_WIDTH:
		return -1
	for y in range(GRID_HEIGHT - 1, -1, -1):
		if grid[col][y] == null:
			return y
	return -1


# How many cards are currently in this column. Drives Hot Stack scoring
# bonuses and the warning glow at 6+/7+.
func column_height(col: int) -> int:
	if col < 0 or col >= GRID_WIDTH:
		return 0
	var n: int = 0
	for y in GRID_HEIGHT:
		if grid[col][y] != null:
			n += 1
	return n


# Returns the grid row of the lowest filled cell in the column, or -1 if
# the column is empty. Used by the "stuck stack" mercy clear to nuke the
# very bottom card of an overflowing column when no hand can fire.
func lowest_filled_row(col: int) -> int:
	if col < 0 or col >= GRID_WIDTH:
		return -1
	for y in range(GRID_HEIGHT - 1, -1, -1):
		if grid[col][y] != null:
			return y
	return -1


func place_card(card: Card, col: int) -> int:
	var row := lowest_empty_row(col)
	if row < 0:
		return -1
	grid[col][row] = card
	queue_redraw()
	return row


# True if any column has filled all 8 rows (Tetris-style overflow = game over).
func is_any_column_full() -> bool:
	for x in GRID_WIDTH:
		if grid[x][0] != null:
			return true
	return false


func cell_local_rect(col: int, row: int) -> Rect2:
	var cell_w := size.x / float(GRID_WIDTH)
	var cell_h := size.y / float(GRID_HEIGHT)
	return Rect2(
		col * cell_w + CELL_PAD,
		row * cell_h + CELL_PAD,
		cell_w - CELL_PAD * 2.0,
		cell_h - CELL_PAD * 2.0
	)


# Scans the grid for scoring 5-card groups: every filled row + each column's
# bottom 5 + every full 5-card diagonal. Returns groups with score > 0
# (HighCard skipped).
#
# `cells` is the SUBSET of the 5-card line that should actually clear, based
# on hand strength:
#   - Pair        → 2 cells (the pair, kickers stay)
#   - Two Pair    → 4 cells (both pairs, kicker stays)
#   - Three of a Kind → 3 cells (the trips, kickers stay)
#   - Four of a Kind → 4 cells (the quads, kicker stays)
#   - Straight / Flush / Full House / Straight Flush / Royal Flush → all 5
#   - Hands with any Joker → all 5 (we can't tell which rank it substituted for)
#
# The full poker score still applies — the kickers staying is purely a board-
# state choice that gives the "stack up for low hands, sweep for big hands" feel.
func find_scoring_groups() -> Array:
	var groups: Array = []

	for y in GRID_HEIGHT:
		var row_cards: Array = []
		var complete := true
		for x in GRID_WIDTH:
			var c: Card = grid[x][y]
			if c == null:
				complete = false
				break
			row_cards.append(c)
		if not complete:
			continue
		var result: Dictionary = HandEvaluator.evaluate(row_cards)
		if int(result.score) <= 0:
			continue
		var cells: Array = []
		for i in _clearing_indices(row_cards, int(result.rank)):
			cells.append(Vector2i(i, y))
		groups.append({
			"cells": cells,
			"name": result.name,
			"score": int(result.score),
			"rank": int(result.rank),
			"multiplier": int(result.multiplier),
			"axis": "row",
		})

	# Columns: pick the BEST 5-card subset out of all the cards currently in
	# the column, not just contiguous windows. This is the key fix for
	# "the column has a pair but nothing fires" on tall stacks — a pair
	# whose two cards sit far apart in the column (say row 0 and row 6)
	# isn't inside any 5-card window, so the old contiguous-window scan
	# missed it. Now we evaluate every 5-of-N combination and pick the
	# single highest scorer per column.
	for x in GRID_WIDTH:
		var best: Dictionary = _best_column_subset(x)
		if not best.is_empty():
			groups.append(best)

	# Diagonals (down-right: \)
	for y_start in range(GRID_HEIGHT - 4):
		var diag_cards: Array = []
		var complete := true
		for i in 5:
			var c: Card = grid[i][y_start + i]
			if c == null:
				complete = false
				break
			diag_cards.append(c)
		if not complete:
			continue
		var result: Dictionary = HandEvaluator.evaluate(diag_cards)
		if int(result.score) <= 0:
			continue
		var cells: Array = []
		for i in _clearing_indices(diag_cards, int(result.rank)):
			cells.append(Vector2i(i, y_start + i))
		groups.append({
			"cells": cells,
			"name": result.name,
			"score": int(result.score),
			"rank": int(result.rank),
			"multiplier": int(result.multiplier),
			"axis": "diag↘",
		})

	# Diagonals (down-left: /)
	for y_start in range(GRID_HEIGHT - 4):
		var diag_cards: Array = []
		var complete := true
		for i in 5:
			var c: Card = grid[GRID_WIDTH - 1 - i][y_start + i]
			if c == null:
				complete = false
				break
			diag_cards.append(c)
		if not complete:
			continue
		var result: Dictionary = HandEvaluator.evaluate(diag_cards)
		if int(result.score) <= 0:
			continue
		var cells: Array = []
		for i in _clearing_indices(diag_cards, int(result.rank)):
			cells.append(Vector2i(GRID_WIDTH - 1 - i, y_start + i))
		groups.append({
			"cells": cells,
			"name": result.name,
			"score": int(result.score),
			"rank": int(result.rank),
			"multiplier": int(result.multiplier),
			"axis": "diag↙",
		})

	return groups


# Returns the indices (0..4) within a 5-card line that should clear, given the
# poker rank the line evaluated to. Lower hands clear only matched cards (pair,
# trips, quads); fuller patterns (straight, flush, full house, +) sweep all 5.
# Any joker in the line forces a full sweep — we can't pinpoint which cells
# "belonged to" the wild substitution.
static func _clearing_indices(cards: Array, rank: int) -> Array:
	for c in cards:
		if c.is_joker:
			return [0, 1, 2, 3, 4]
	match rank:
		HandEvaluator.HandRank.PAIR:
			return _indices_with_rank_count(cards, 2)
		HandEvaluator.HandRank.TWO_PAIR:
			return _indices_with_rank_count(cards, 2)
		HandEvaluator.HandRank.THREE_OF_A_KIND:
			return _indices_with_rank_count(cards, 3)
		HandEvaluator.HandRank.FOUR_OF_A_KIND:
			return _indices_with_rank_count(cards, 4)
		_:
			return [0, 1, 2, 3, 4]


# Returns the indices in `cards` whose rank appears at least `target_count`
# times in the array. Used to pick out the "matched" cards in pair/trips/quads
# hands.
static func _indices_with_rank_count(cards: Array, target_count: int) -> Array:
	var rank_counts: Dictionary = {}
	for c in cards:
		rank_counts[c.rank] = int(rank_counts.get(c.rank, 0)) + 1
	var result: Array = []
	for i in cards.size():
		if int(rank_counts.get(cards[i].rank, 0)) >= target_count:
			result.append(i)
	return result


# Public wrapper so game.gd can ask "is there any hand on this column?"
# without having to know about the internal subset machinery (used by the
# stuck-stack mercy clear).
func column_subset_for_test(col: int) -> Dictionary:
	return _best_column_subset(col)


# Best 5-of-N column subset.
#
# Why not "scan every 5-card window": a Connect 4–style tall column can hold
# up to 8 cards. A Pair whose two members sit at e.g. row 0 and row 7 is
# not contained in any contiguous 5-card window, so contiguous-window
# scanning would never detect the hand — the player sees an obvious pair
# in the column but nothing fires. We avoid that by evaluating every 5-card
# combination of the column's present cards and emitting the single highest-
# scoring one. The matched cells get the standard `_clearing_indices` rule
# (kickers stay for pair/trips/quads, full sweep for straight/flush/+).
#
# Cost: at most C(8,5)=56 evaluations per column per cascade tier — cheap.
func _best_column_subset(x: int) -> Dictionary:
	# Collect (row, card) pairs for every filled cell in the column.
	var rows: Array = []   # grid-row index for each entry
	var cards: Array = []  # the Card at that row
	for y in GRID_HEIGHT:
		var c: Card = grid[x][y]
		if c != null:
			rows.append(y)
			cards.append(c)
	var n: int = cards.size()
	if n < COL_WINDOW:
		return {}

	var best_result: Dictionary = {}
	var best_idxs: Array = []

	# Enumerate 5-of-N combinations. N ≤ 8 so this is tiny.
	for i0 in range(0, n - 4):
		for i1 in range(i0 + 1, n - 3):
			for i2 in range(i1 + 1, n - 2):
				for i3 in range(i2 + 1, n - 1):
					for i4 in range(i3 + 1, n):
						var subset := [cards[i0], cards[i1], cards[i2], cards[i3], cards[i4]]
						var result: Dictionary = HandEvaluator.evaluate(subset)
						if int(result.score) <= 0:
							continue
						if best_result.is_empty() \
							or int(result.score) > int(best_result.get("score", 0)):
							best_result = result
							best_idxs = [i0, i1, i2, i3, i4]

	if best_result.is_empty():
		return {}

	# Map clearing indices (0..4 within the subset) back to grid rows.
	var subset_cards: Array = []
	for idx in best_idxs:
		subset_cards.append(cards[idx])
	var clear_in_subset: Array = _clearing_indices(subset_cards, int(best_result.rank))
	var cells: Array = []
	for ci in clear_in_subset:
		var grid_row: int = rows[best_idxs[ci]]
		cells.append(Vector2i(x, grid_row))

	return {
		"cells": cells,
		"name": best_result.name,
		"score": int(best_result.score),
		"rank": int(best_result.rank),
		"multiplier": int(best_result.multiplier),
		"axis": "column",
	}


# Returns the 2×2 same-suit squares that include (col, row), as a list of
# top-left Vector2i corners. Empty array if none. Used for adjacency-style
# suit-cluster bonuses on placement (does not clear cells).
func find_same_suit_squares_at(col: int, row: int) -> Array:
	var squares: Array = []
	# The cell (col, row) can be any of the four corners of a 2×2.
	var candidates := [
		Vector2i(col, row),
		Vector2i(col - 1, row),
		Vector2i(col, row - 1),
		Vector2i(col - 1, row - 1),
	]
	for tl in candidates:
		if tl.x < 0 or tl.y < 0:
			continue
		if tl.x + 1 >= GRID_WIDTH or tl.y + 1 >= GRID_HEIGHT:
			continue
		var c1: Card = grid[tl.x][tl.y]
		var c2: Card = grid[tl.x + 1][tl.y]
		var c3: Card = grid[tl.x][tl.y + 1]
		var c4: Card = grid[tl.x + 1][tl.y + 1]
		if c1 == null or c2 == null or c3 == null or c4 == null:
			continue
		# Jokers don't count toward suit matching here (treat as mismatched).
		if c1.is_joker or c2.is_joker or c3.is_joker or c4.is_joker:
			continue
		if c1.suit == c2.suit and c2.suit == c3.suit and c3.suit == c4.suit:
			squares.append(tl)
	return squares


# Returns the card at (col, row), or null. Public accessor so game.gd doesn't
# need to reach into grid[][] directly.
func card_at(col: int, row: int) -> Card:
	if col < 0 or col >= GRID_WIDTH or row < 0 or row >= GRID_HEIGHT:
		return null
	return grid[col][row]


func clear_cells(cells: Array) -> void:
	for cell in cells:
		var p: Vector2i = cell
		if p.x >= 0 and p.x < GRID_WIDTH and p.y >= 0 and p.y < GRID_HEIGHT:
			grid[p.x][p.y] = null
	queue_redraw()


# Drops cards down so each column is bottom-aligned with no gaps.
func apply_gravity() -> void:
	for x in GRID_WIDTH:
		var stack: Array = []
		for y in GRID_HEIGHT:
			if grid[x][y] != null:
				stack.append(grid[x][y])
		var write_y := GRID_HEIGHT - 1
		for i in range(stack.size() - 1, -1, -1):
			grid[x][write_y] = stack[i]
			write_y -= 1
		while write_y >= 0:
			grid[x][write_y] = null
			write_y -= 1
	queue_redraw()


# --- internals ---


func _init_grid() -> void:
	grid.clear()
	grid.resize(GRID_WIDTH)
	for x in GRID_WIDTH:
		var col_array: Array = []
		col_array.resize(GRID_HEIGHT)
		for y in GRID_HEIGHT:
			col_array[y] = null
		grid[x] = col_array


func _process(delta: float) -> void:
	# Always redraw — the anticipation-glow outlines pulse via Time.
	# Cheap: we're drawing ~40 cells of simple rects per frame.
	queue_redraw()
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
		if _flash_t == 0.0:
			_flash_col = -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_tap(mb.position.x)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_handle_tap(st.position.x)


func _handle_tap(local_x: float) -> void:
	var col := _col_from_x(local_x)
	if col < 0:
		return
	_flash_col = col
	_flash_t = FLASH_DURATION
	queue_redraw()
	column_tapped.emit(col)


func _col_from_x(local_x: float) -> int:
	if size.x <= 0.0:
		return -1
	var cell_w := size.x / float(GRID_WIDTH)
	var col := int(local_x / cell_w)
	if col < 0 or col >= GRID_WIDTH:
		return -1
	return col


func _draw() -> void:
	# Felt surface — pulled from the active theme so leveling up visibly changes
	# the table the cards sit on.
	draw_rect(Rect2(Vector2.ZERO, size), Themes.current().felt, true)

	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			var rect := cell_local_rect(x, y)
			var card: Card = grid[x][y]
			if card == null:
				CardView.draw_empty_slot(self, rect)
			else:
				CardView.draw_card(self, card, rect)

	# Anticipation glow: faint pulsing gold outline on each column's drop
	# target so the player sees where their card will land before tapping.
	# Color shifts to orange at 6+ ("hot"), red at 7+ ("danger") so the
	# player gets a clear "this column is loaded — clear from here for a
	# big payoff, or stop dropping into it" signal.
	var t_ms := float(Time.get_ticks_msec())
	var pulse: float = 0.18 + 0.10 * sin(t_ms * 0.003)
	var hot_pulse: float = 0.32 + 0.18 * sin(t_ms * 0.006)
	var danger_pulse: float = 0.45 + 0.30 * sin(t_ms * 0.010)
	for x in GRID_WIDTH:
		var drop_row := lowest_empty_row(x)
		if drop_row < 0:
			continue
		var aim_rect := cell_local_rect(x, drop_row)
		var height: int = column_height(x)
		var glow_color: Color
		var glow_thickness: float
		if height >= 7:
			# Danger: next drop will fill the column → loss. Hard red pulse.
			glow_color = Color(1.0, 0.25, 0.25, danger_pulse)
			glow_thickness = 5.0
		elif height >= 6:
			# Hot stack: big multiplier waiting. Orange pulse.
			glow_color = Color(1.0, 0.55, 0.20, hot_pulse)
			glow_thickness = 4.0
		else:
			# Normal anticipation: gentle gold.
			glow_color = Color(1.0, 0.85, 0.40, pulse)
			glow_thickness = 3.0
		draw_rect(aim_rect, glow_color, false, glow_thickness)

	# (Round target column tint removed — was reading as a mystery yellow bar.
	# target_col is still tracked so game.gd's bonus logic keeps working; only
	# the visual is gone.)

	if _flash_col >= 0 and _flash_t > 0.0:
		var cell_w := size.x / float(GRID_WIDTH)
		var alpha := (_flash_t / FLASH_DURATION) * 0.32
		var flash_rect := Rect2(_flash_col * cell_w, 0.0, cell_w, size.y)
		var c := COLOR_FLASH
		c.a = alpha
		draw_rect(flash_rect, c, true)
