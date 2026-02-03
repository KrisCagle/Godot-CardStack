extends StaticBody2D
class_name Peg

enum PegType {
	DAMAGE,
	GOLD,
	MULTIPLIER,
}

@export var peg_type: PegType = PegType.DAMAGE:
	set(value):
		peg_type = value
		queue_redraw()

@export var radius: float = 14.0
@export var is_split_peg: bool = false:
	set(value):
		is_split_peg = value
		queue_redraw()

func _ready() -> void:
	add_to_group("peg")
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, _type_color())
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 20, Color(0, 0, 0, 0.45), 2.0)
	if is_split_peg:
		draw_circle(Vector2.ZERO, radius * 0.36, Color("f8fafc"))
		draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 14, Color("ffffff"), 2.0)

func _type_color() -> Color:
	match peg_type:
		PegType.DAMAGE:
			return Color("ff6b6b")
		PegType.GOLD:
			return Color("ffd166")
		PegType.MULTIPLIER:
			return Color("8ecae6")
		_:
			return Color.WHITE
