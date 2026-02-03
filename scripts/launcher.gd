extends Node2D
class_name Launcher

@export var min_x: float = 90.0
@export var max_x: float = 990.0
@export var aim_offset: Vector2 = Vector2(0, 80)

func set_target_x(new_x: float) -> void:
	global_position.x = clamp(new_x, min_x, max_x)
	queue_redraw()

func nudge(dir: float, amount: float = 28.0) -> void:
	set_target_x(global_position.x + dir * amount)

func _draw() -> void:
	var p1 := Vector2.ZERO
	var p2 := aim_offset
	draw_line(p1, p2, Color("e2e8f0"), 4.0)
	draw_circle(p1, 14.0, Color("fb7185"))
