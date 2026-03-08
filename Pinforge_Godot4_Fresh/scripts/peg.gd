extends StaticBody2D
class_name Peg

enum PegType {
	DAMAGE,
	GOLD,
	SHIELD,
	MULTIPLIER,
}

enum SpecialEffect {
	NONE,
	SPLIT,
	BURST,
	ECHO,
	PINBALL,
	ORBIT,
	BOOM,
	CHAIN,
	MULTI_PLUS,
	CASHOUT,
	CRIT,
	REFUND,
	OVERDRIVE,
	GHOST,
	MAGNET,
}

@export var peg_type: PegType = PegType.DAMAGE:
	set(value):
		peg_type = value
		queue_redraw()

@export var radius: float = 14.0
@export var value: float = -1.0
@export var is_split_peg: bool = false:
	set(value):
		is_split_peg = value
		queue_redraw()
@export var special_effect: SpecialEffect = SpecialEffect.NONE:
	set(value):
		special_effect = value
		queue_redraw()
@export_range(0, 3, 1) var tier: int = 0:
	set(value):
		tier = clampi(value, 0, 3)
		queue_redraw()
@export_range(0.0, 1.5, 0.01) var danger_level: float = 0.0:
	set(value):
		danger_level = clampf(value, 0.0, 1.5)
		queue_redraw()
@export var hits_to_level: int = 3

@onready var sprite: Node2D = get_node_or_null("Sprite2D")
var _hit_count: int = 0
var _recent_hit_timer: float = 0.0
var _pulse_seed: float = 0.0
var last_ball: Ball

func _ready() -> void:
	add_to_group("peg")
	_pulse_seed = randf_range(0.0, TAU)
	queue_redraw()

func _process(delta: float) -> void:
	if _recent_hit_timer > 0.0:
		_recent_hit_timer = maxf(0.0, _recent_hit_timer - delta)
		queue_redraw()

func _draw() -> void:
	var base: Color = _type_color()
	var pulse_time: float = Time.get_ticks_msec() * 0.001 * (1.2 + danger_level * 0.7 + float(tier) * 0.25)
	var pulse: float = sin(pulse_time + _pulse_seed) * 0.5 + 0.5
	var hit_bonus: float = 0.16 if _recent_hit_timer > 0.0 else 0.0
	var glow_alpha: float = 0.10 + float(tier) * 0.06 + danger_level * 0.10 + pulse * 0.06 + hit_bonus
	var glow: Color = base
	glow.a = glow_alpha

	var shadow_color := Color(0, 0, 0, 0.26)
	draw_circle(Vector2(3.0, 4.0), radius + 7.5 + float(tier) * 1.2, shadow_color)

	draw_circle(Vector2.ZERO, radius + 7.0 + float(tier) * 2.0 + danger_level * 2.0, glow)
	draw_circle(Vector2.ZERO, radius + 2.8, Color(0.07, 0.09, 0.15, 0.96))
	draw_circle(Vector2.ZERO, radius + 0.8, Color(0.74, 0.82, 0.96, 0.25))
	draw_circle(Vector2.ZERO, radius - 2.0, base.darkened(0.14))
	draw_circle(Vector2(-2.2, -2.2), radius * 0.52, base.lightened(0.18 + danger_level * 0.08))

	if tier >= 2:
		var spin: float = Time.get_ticks_msec() * 0.001 * (1.4 + float(tier) * 0.3)
		draw_arc(Vector2.ZERO, radius + 5.2, spin, spin + PI, 24, base.lightened(0.30), 1.8)
		if tier >= 3:
			# Animated chase ring for top-tier pins.
			draw_arc(Vector2.ZERO, radius + 8.8, spin * 1.3, spin * 1.3 + PI * 0.72, 20, base.lightened(0.45), 2.2)
			draw_arc(Vector2.ZERO, radius + 8.8, spin * 1.3 + PI, spin * 1.3 + PI + PI * 0.42, 12, base.lightened(0.24), 1.8)
			_draw_sparkles(base.lightened(0.55))

	if tier >= 1 or _recent_hit_timer > 0.0:
		_draw_icon(base.lightened(0.4))
	_draw_special_icon(base.lightened(0.65))

	if is_split_peg:
		draw_circle(Vector2.ZERO, radius * 0.36, Color("f8fafc"))
		draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 14, Color("ffffff"), 2.0)

func _draw_icon(color: Color) -> void:
	match peg_type:
		PegType.DAMAGE:
			var tri := PackedVector2Array([
				Vector2(0, -4.8),
				Vector2(4.8, 4.8),
				Vector2(-4.8, 4.8),
			])
			draw_colored_polygon(tri, color)
		PegType.GOLD:
			draw_rect(Rect2(-3.8, -3.8, 7.6, 7.6), color, true)
		PegType.SHIELD:
			var hex := PackedVector2Array([
				Vector2(-4.0, -2.0),
				Vector2(0.0, -4.8),
				Vector2(4.0, -2.0),
				Vector2(4.0, 2.0),
				Vector2(0.0, 4.8),
				Vector2(-4.0, 2.0),
			])
			draw_colored_polygon(hex, color)
		PegType.MULTIPLIER:
			var dia := PackedVector2Array([
				Vector2(0, -5.0),
				Vector2(5.0, 0),
				Vector2(0, 5.0),
				Vector2(-5.0, 0),
			])
			draw_colored_polygon(dia, color)

func _type_color() -> Color:
	match peg_type:
		PegType.DAMAGE:
			return Color("ff4f98")
		PegType.GOLD:
			return Color("fbcf4a")
		PegType.SHIELD:
			return Color("7ed5ff")
		PegType.MULTIPLIER:
			return Color("b48bff")
		_:
			return Color.WHITE

func on_ball_hit(_ball: Node2D) -> void:
	if _ball is Ball:
		last_ball = _ball as Ball
	EventBus.peg_hit.emit(int(peg_type), _hit_value(), global_position)
	_hit_count += 1
	_recent_hit_timer = 0.22
	if hits_to_level > 0 and _hit_count % hits_to_level == 0 and tier < 3:
		tier += 1
		EventBus.shake_requested.emit(0.16, 0.08)
	_play_hit_squash()

func _hit_value() -> float:
	if value >= 0.0:
		return value
	match peg_type:
		PegType.DAMAGE:
			return 8.0 * (1.0 + float(tier) * 0.30)
		PegType.GOLD:
			return 2.0 * (1.0 + float(tier) * 0.26)
		PegType.SHIELD:
			return 3.0 * (1.0 + float(tier) * 0.24)
		PegType.MULTIPLIER:
			return 0.2 + float(tier) * 0.06
		_:
			return 1.0

func _play_hit_squash() -> void:
	var target: Node2D = self
	if sprite:
		target = sprite
	target.scale = Vector2(1.12, 0.90)
	var tw := create_tween()
	tw.tween_property(target, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw_sparkles(color: Color) -> void:
	var t: float = Time.get_ticks_msec() * 0.001 + _pulse_seed
	var sparkle_count: int = 3
	for i in range(sparkle_count):
		var a: float = t * (1.5 + float(i) * 0.33) + float(i) * TAU / float(sparkle_count)
		var p := Vector2(cos(a), sin(a)) * (radius + 12.0 + sin(t * 2.0 + float(i)) * 2.4)
		draw_circle(p, 1.4, Color(color.r, color.g, color.b, 0.82))

func _draw_special_icon(color: Color) -> void:
	if special_effect == SpecialEffect.NONE:
		return
	# Backplate for readability.
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.55))
	match special_effect:
		SpecialEffect.SPLIT:
			_draw_split_glyph(color)
		SpecialEffect.BURST:
			_draw_star_glyph(color)
		SpecialEffect.ECHO:
			_draw_echo_glyph(color)
		SpecialEffect.PINBALL:
			_draw_pinball_glyph(color)
		SpecialEffect.ORBIT:
			_draw_orbit_glyph(color)
		SpecialEffect.BOOM:
			_draw_boom_glyph(color)
		SpecialEffect.CHAIN:
			_draw_chain_glyph(color)
		SpecialEffect.MULTI_PLUS:
			_draw_plus_glyph(color)
		SpecialEffect.CASHOUT:
			_draw_coin_glyph(color)
		SpecialEffect.CRIT:
			_draw_diamond_glyph(color)
		SpecialEffect.REFUND:
			_draw_refund_glyph(color)
		SpecialEffect.OVERDRIVE:
			_draw_flame_glyph(color)
		SpecialEffect.GHOST:
			_draw_ghost_glyph(color)
		SpecialEffect.MAGNET:
			_draw_magnet_glyph(color)
		_:
			pass


func _draw_split_glyph(color: Color) -> void:
	var tri1 := PackedVector2Array([Vector2(-6, -3), Vector2(-1, 5), Vector2(-11, 5)])
	var tri2 := PackedVector2Array([Vector2(6, -3), Vector2(1, 5), Vector2(11, 5)])
	draw_colored_polygon(tri1, color)
	draw_colored_polygon(tri2, color)

func _draw_star_glyph(color: Color) -> void:
	var star := PackedVector2Array([
		Vector2(0, -7), Vector2(2, -2), Vector2(8, -2), Vector2(3, 2),
		Vector2(6, 8), Vector2(0, 5), Vector2(-6, 8), Vector2(-3, 2),
		Vector2(-8, -2), Vector2(-2, -2),
	])
	draw_colored_polygon(star, color)

func _draw_echo_glyph(color: Color) -> void:
	draw_circle(Vector2(-3, 0), 3.8, color)
	draw_circle(Vector2(3, 0), 3.8, color)

func _draw_pinball_glyph(color: Color) -> void:
	draw_arc(Vector2.ZERO, 6.8, -PI * 0.1, PI * 1.1, 16, color, 2.2)

func _draw_orbit_glyph(color: Color) -> void:
	draw_circle(Vector2.ZERO, 2.6, color)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 22, color, 1.6)

func _draw_boom_glyph(color: Color) -> void:
	draw_line(Vector2(-6, -6), Vector2(6, 6), color, 2.2)
	draw_line(Vector2(-6, 6), Vector2(6, -6), color, 2.2)

func _draw_chain_glyph(color: Color) -> void:
	draw_circle(Vector2(-4, 0), 3.2, color)
	draw_circle(Vector2(4, 0), 3.2, color)
	draw_line(Vector2(-1, 0), Vector2(1, 0), color, 2.2)

func _draw_plus_glyph(color: Color) -> void:
	draw_line(Vector2(0, -6), Vector2(0, 6), color, 2.2)
	draw_line(Vector2(-6, 0), Vector2(6, 0), color, 2.2)

func _draw_coin_glyph(color: Color) -> void:
	draw_circle(Vector2.ZERO, 4.8, color)
	draw_circle(Vector2.ZERO, 2.8, Color(1, 1, 1, 0.35))

func _draw_diamond_glyph(color: Color) -> void:
	var dia := PackedVector2Array([
		Vector2(0, -6), Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0),
	])
	draw_colored_polygon(dia, color)

func _draw_refund_glyph(color: Color) -> void:
	draw_arc(Vector2(0, 1), 6.0, PI * 0.15, PI * 1.25, 16, color, 2.2)
	draw_line(Vector2(-6, 2), Vector2(-2, -1), color, 2.2)

func _draw_flame_glyph(color: Color) -> void:
	var flame := PackedVector2Array([
		Vector2(0, -7), Vector2(3, -2), Vector2(2, 5), Vector2(0, 7),
		Vector2(-2, 5), Vector2(-3, -2),
	])
	draw_colored_polygon(flame, color)

func _draw_ghost_glyph(color: Color) -> void:
	draw_circle(Vector2(0, -1), 4.8, color)
	draw_circle(Vector2(-2, -2), 1.1, Color(0, 0, 0, 0.5))
	draw_circle(Vector2(2, -2), 1.1, Color(0, 0, 0, 0.5))

func _draw_magnet_glyph(color: Color) -> void:
	draw_arc(Vector2.ZERO, 7.0, PI * 0.1, PI * 0.9, 16, color, 2.2)
	draw_line(Vector2(-5, 1), Vector2(-5, 6), color, 2.2)
	draw_line(Vector2(5, 1), Vector2(5, 6), color, 2.2)
