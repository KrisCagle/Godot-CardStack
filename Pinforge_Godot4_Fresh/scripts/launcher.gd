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
	if scale.y > 0.0:
		scale.y = -abs(scale.y)
	var shadow := Color(0.0, 0.0, 0.0, 0.35)
	var base_color := Color(0.05, 0.08, 0.16, 0.98)
	var rim_color := Color(0.55, 0.78, 1.0, 0.85)
	var accent := Color("7dd3fc")

	# Cannon base ring
	draw_circle(Vector2(4, 6), 30.0, shadow)
	draw_circle(Vector2.ZERO, 30.0, base_color)
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, rim_color, 2.0)
	draw_circle(Vector2(-6, -8), 12.0, Color(1, 1, 1, 0.08))

	# Barrel (stylized capsule)
	var barrel := PackedVector2Array([
		Vector2(-14, -40),
		Vector2(14, -40),
		Vector2(18, -18),
		Vector2(0, 10),
		Vector2(-18, -18),
	])
	var barrel_shadow := PackedVector2Array([
		Vector2(-12, -36) + Vector2(4, 6),
		Vector2(12, -36) + Vector2(4, 6),
		Vector2(16, -16) + Vector2(4, 6),
		Vector2(0, 8) + Vector2(4, 6),
		Vector2(-16, -16) + Vector2(4, 6),
	])
	draw_colored_polygon(barrel_shadow, shadow)
	draw_colored_polygon(barrel, base_color.lightened(0.05))
	draw_polyline(barrel, rim_color, 2.0, true)

	# Muzzle glow (no aim line)
	var nozzle_pos := Vector2(0, -46)
	draw_arc(nozzle_pos, 14.0, 0.0, TAU, 22, accent, 1.6)
