extends Node2D

@export var amount: int = 14
@export var lifetime: float = 0.08
@export var min_emit_speed: float = 1.0

var _particles: CPUParticles2D
var _trail_tint: Color = Color(0.92, 0.95, 1.0, 1.0)

func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.name = "SmokeParticles"
	_particles.z_index = 20
	_particles.emitting = false
	_particles.amount = amount
	_particles.lifetime = lifetime
	_particles.one_shot = false
	_particles.local_coords = false
	_particles.preprocess = 0.05
	_particles.explosiveness = 0.0
	_particles.direction = Vector2(0.0, -1.0)
	_particles.spread = 18.0
	_particles.initial_velocity_min = 16.0
	_particles.initial_velocity_max = 30.0
	_particles.gravity = Vector2.ZERO
	_particles.scale_amount_min = 0.55
	_particles.scale_amount_max = 1.1

	_apply_color_ramp()

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.35, 0.55))
	curve.add_point(Vector2(1.0, 0.16))
	_particles.scale_amount_curve = curve

	_particles.texture = _make_soft_smoke_texture()
	add_child(_particles)

	var line := get_node_or_null("Line2D") as Line2D
	if line != null:
		line.visible = false

func set_tint(tint: Color) -> void:
	_trail_tint = tint
	_apply_color_ramp()

func _process(_delta: float) -> void:
	var ball := get_parent() as RigidBody2D
	if ball == null:
		return

	_particles.global_position = ball.global_position

	var speed: float = ball.linear_velocity.length()
	if speed < min_emit_speed:
		_particles.emitting = false
		return

	_particles.emitting = true
	_particles.direction = (-ball.linear_velocity).normalized()
	_particles.initial_velocity_min = clampf(speed * 0.06, 8.0, 16.0)
	_particles.initial_velocity_max = clampf(speed * 0.12, 14.0, 28.0)

func _make_soft_smoke_texture(size: int = 64) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var max_radius := float(size) * 0.5

	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x), float(y))
			var dist := p.distance_to(center) / max_radius
			var t := clampf(1.0 - dist, 0.0, 1.0)
			var alpha := t * t * 0.9
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)

func _apply_color_ramp() -> void:
	if _particles == null:
		return
	var ramp := Gradient.new()
	# Strong near ball, then quickly taper so tail gets smaller/fainter.
	ramp.add_point(0.0, Color(_trail_tint.r, _trail_tint.g, _trail_tint.b, 0.42))
	ramp.add_point(0.20, Color(_trail_tint.r, _trail_tint.g, _trail_tint.b, 0.24))
	ramp.add_point(0.55, Color(_trail_tint.r, _trail_tint.g, _trail_tint.b, 0.10))
	ramp.add_point(1.0, Color(_trail_tint.r, _trail_tint.g, _trail_tint.b, 0.00))
	_particles.color_ramp = ramp
