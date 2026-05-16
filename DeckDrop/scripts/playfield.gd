extends Control
## The 5x8 play grid. Owns visual rendering (cell outlines) and column-tap input.
## Emits `column_tapped(col)` for the game controller. No card data lives here yet.

const GRID_WIDTH := 5
const GRID_HEIGHT := 8

const COLOR_CELL_FILL := Color(0.10, 0.12, 0.18, 1.0)
const COLOR_CELL_LINE := Color(0.24, 0.30, 0.42, 1.0)
const COLOR_FLASH := Color(0.45, 0.65, 1.0, 1.0)
const FLASH_DURATION := 0.18

signal column_tapped(col: int)

var _flash_col: int = -1
var _flash_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


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
	var cell_w := size.x / float(GRID_WIDTH)
	var cell_h := size.y / float(GRID_HEIGHT)
	var pad := 6.0

	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			var rect := Rect2(
				x * cell_w + pad,
				y * cell_h + pad,
				cell_w - pad * 2.0,
				cell_h - pad * 2.0
			)
			draw_rect(rect, COLOR_CELL_FILL, true)
			draw_rect(rect, COLOR_CELL_LINE, false, 2.0)

	if _flash_col >= 0 and _flash_t > 0.0:
		var alpha := (_flash_t / FLASH_DURATION) * 0.32
		var flash_rect := Rect2(_flash_col * cell_w, 0.0, cell_w, size.y)
		var c := COLOR_FLASH
		c.a = alpha
		draw_rect(flash_rect, c, true)
