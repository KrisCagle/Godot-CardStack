extends Area2D
class_name Pocket

enum PocketType {
	REFUND,
	CRIT,
	CASHOUT,
}

@export var pocket_type: PocketType = PocketType.REFUND:
	set(value):
		pocket_type = value
		queue_redraw()

@export var size: Vector2 = Vector2(320, 90):
	set(value):
		size = value
		if has_node("CollisionShape2D"):
			var shape := $CollisionShape2D.shape as RectangleShape2D
			if shape:
				shape.size = size
		queue_redraw()
@export var danger_level: float = 0.0:
	set(value):
		danger_level = clampf(value, 0.0, 1.0)
		queue_redraw()

var _flash_timer: float = 0.0
var _pulse_phase: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_phase += delta
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
	queue_redraw()

func _draw() -> void:
	var base := _base_color()
	var pulse := 0.90 + 0.10 * sin(_pulse_phase * (2.6 + danger_level))
	var inner := base * pulse
	inner.a = 0.90
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, inner, true)
	draw_rect(rect, Color(0, 0, 0, 0.50), false, 3.0)

	# Arcade top light strip
	var top_strip := Rect2(rect.position.x, rect.position.y, rect.size.x, 12.0)
	draw_rect(top_strip, base.lightened(0.35), true)

	# Subtle scanline bars for cabinet look.
	var bars := 4
	for i in range(bars):
		var y := rect.position.y + 18.0 + float(i) * 16.0
		draw_rect(Rect2(rect.position.x + 8.0, y, rect.size.x - 16.0, 2.0), Color(1, 1, 1, 0.10), true)

	# Corner LEDs.
	var led := base.lightened(0.55)
	led.a = 0.8
	draw_circle(rect.position + Vector2(10, 10), 3.0, led)
	draw_circle(rect.position + Vector2(rect.size.x - 10, 10), 3.0, led)
	draw_circle(rect.position + Vector2(10, rect.size.y - 10), 3.0, led)
	draw_circle(rect.position + Vector2(rect.size.x - 10, rect.size.y - 10), 3.0, led)

	if _flash_timer > 0.0:
		var flash_alpha: float = clampf(_flash_timer * 2.2, 0.0, 0.55)
		draw_rect(rect, Color(1, 1, 1, flash_alpha), true)

	if danger_level > 0.15:
		var danger := Color(1.0, 0.26, 0.20, 0.10 + danger_level * 0.18)
		draw_rect(Rect2(rect.position.x, rect.position.y - 7.0, rect.size.x, 6.0), danger, true)

	_draw_label()

func label_text() -> String:
	match pocket_type:
		PocketType.REFUND:
			return "REFUND"
		PocketType.CRIT:
			return "CRIT"
		PocketType.CASHOUT:
			return "CASHOUT"
		_:
			return "?"

func _base_color() -> Color:
	match pocket_type:
		PocketType.REFUND:
			return Color("80ed99")
		PocketType.CRIT:
			return Color("ff99c8")
		PocketType.CASHOUT:
			return Color("ffca3a")
		_:
			return Color.DIM_GRAY

func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var label := label_text()
	var font_size := 22
	var pos := Vector2(-size.x * 0.5, 8.0)
	var text_color := Color(0.05, 0.08, 0.12, 0.92)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)

func trigger_celebration() -> void:
	_flash_timer = 0.22
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is Ball:
		(body as Ball).enter_pocket(self)
