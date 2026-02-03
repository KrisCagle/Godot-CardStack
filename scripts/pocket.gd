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

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), _base_color(), true)
	draw_rect(Rect2(-size * 0.5, size), Color(0, 0, 0, 0.45), false, 3.0)

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

func _on_body_entered(body: Node) -> void:
	if body is Ball:
		(body as Ball).enter_pocket(self)
