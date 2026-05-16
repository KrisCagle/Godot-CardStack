extends Control
## The 5x8 play grid. Owns visual rendering (cell outlines + placed cards)
## and column-tap input. Holds the canonical grid state — game.gd asks where
## a card would land, then calls place_card after its drop animation finishes.

const GRID_WIDTH := 5
const GRID_HEIGHT := 8
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


func cell_local_rect(col: int, row: int) -> Rect2:
	var cell_w := size.x / float(GRID_WIDTH)
	var cell_h := size.y / float(GRID_HEIGHT)
	return Rect2(
		col * cell_w + CELL_PAD,
		row * cell_h + CELL_PAD,
		cell_w - CELL_PAD * 2.0,
		cell_h - CELL_PAD * 2.0
	)


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
