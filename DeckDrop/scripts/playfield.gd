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
const COL_WINDOW := 5  # Score the bottom N cards of any column when filled.
const CELL_PAD := 6.0

const COLOR_FLASH := Color(0.45, 0.65, 1.0, 1.0)
const FLASH_DURATION := 0.18

signal column_tapped(col: int)

# grid[col][row] -> Card or null. Row 0 is top, row GRID_HEIGHT-1 is bottom.
var grid: Array = []

var _flash_col: int = -1
var _flash_t: float = 0.0


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
# bottom 5 (when filled). Returns groups with score > 0 (HighCard skipped).
# Each entry: {cells: Array[Vector2i], name, score, rank, multiplier, axis}.
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
		for x in GRID_WIDTH:
			cells.append(Vector2i(x, y))
		groups.append({
			"cells": cells,
			"name": result.name,
			"score": int(result.score),
			"rank": int(result.rank),
			"multiplier": int(result.multiplier),
			"axis": "row",
		})

	var start_y := GRID_HEIGHT - COL_WINDOW
	for x in GRID_WIDTH:
		var col_cards: Array = []
		var complete := true
		for y in range(start_y, GRID_HEIGHT):
			var c: Card = grid[x][y]
			if c == null:
				complete = false
				break
			col_cards.append(c)
		if not complete:
			continue
		var result: Dictionary = HandEvaluator.evaluate(col_cards)
		if int(result.score) <= 0:
			continue
		var cells: Array = []
		for y in range(start_y, GRID_HEIGHT):
			cells.append(Vector2i(x, y))
		groups.append({
			"cells": cells,
			"name": result.name,
			"score": int(result.score),
			"rank": int(result.rank),
			"multiplier": int(result.multiplier),
			"axis": "column",
		})

	# Diagonals (down-right: \) — with width 5, only one x-start fits.
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
		for i in 5:
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
		for i in 5:
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
	if _flash_t <= 0.0:
		return
	_flash_t = maxf(_flash_t - delta, 0.0)
	queue_redraw()
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
	# Felt surface — slightly darker than the page so the play area has presence
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.07, 0.10, 1.0), true)

	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			var rect := cell_local_rect(x, y)
			var card: Card = grid[x][y]
			if card == null:
				CardView.draw_empty_slot(self, rect)
			else:
				CardView.draw_card(self, card, rect)

	if _flash_col >= 0 and _flash_t > 0.0:
		var cell_w := size.x / float(GRID_WIDTH)
		var alpha := (_flash_t / FLASH_DURATION) * 0.32
		var flash_rect := Rect2(_flash_col * cell_w, 0.0, cell_w, size.y)
		var c := COLOR_FLASH
		c.a = alpha
		draw_rect(flash_rect, c, true)
