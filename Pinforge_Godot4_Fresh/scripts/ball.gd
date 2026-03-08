extends RigidBody2D
class_name Ball

signal peg_hit(peg: Peg)
signal pocket_entered(pocket: Pocket)
signal hazard_hit(damage: int, hazard_label: String, world_pos: Vector2)
signal settled()

@export var radius: float = 12.0
@export var fill_color: Color = Color("f8fafc")
@export var rim_color: Color = Color("94a3b8")

var _hit_peg_ids: Dictionary = {}
var _hit_hazard_ids: Dictionary = {}
var _settled_emitted := false
var _slow_time := 0.0
@onready var trail_node: Node = get_node_or_null("BallTrail")

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _draw() -> void:
	var shadow_color := Color(0, 0, 0, 0.28)
	draw_circle(Vector2(3.0, 5.0), radius + 2.0, shadow_color)
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 20, rim_color, 2.0)
	draw_circle(Vector2(-2.0, -2.0), radius * 0.45, fill_color.lightened(0.35))

func apply_visual_theme(body_color: Color, ring_color: Color, trail_tint: Color) -> void:
	fill_color = body_color
	rim_color = ring_color
	queue_redraw()
	if trail_node and trail_node.has_method("set_tint"):
		trail_node.call("set_tint", trail_tint)

func _physics_process(delta: float) -> void:
	if _settled_emitted:
		return

	if linear_velocity.length() < 25.0:
		_slow_time += delta
		if _slow_time >= 0.6:
			emit_settled()
	else:
		_slow_time = 0.0

	if global_position.y > 2050.0:
		emit_settled()

func emit_settled() -> void:
	if _settled_emitted:
		return
	_settled_emitted = true
	settled.emit()
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body is Peg:
		var peg := body as Peg
		var peg_id := peg.get_instance_id()
		if _hit_peg_ids.has(peg_id):
			return
		_hit_peg_ids[peg_id] = true
		peg.on_ball_hit(self)
		peg_hit.emit(peg)
	elif body.is_in_group("hazard"):
		var hazard_id: int = body.get_instance_id()
		if _hit_hazard_ids.has(hazard_id):
			return
		_hit_hazard_ids[hazard_id] = true
		var damage: int = int(body.get_meta("hazard_damage", 4))
		var hazard_label: String = str(body.get_meta("hazard_label", "HAZARD"))
		hazard_hit.emit(maxi(1, damage), hazard_label, global_position)

func enter_pocket(pocket: Pocket) -> void:
	if _settled_emitted:
		return
	pocket_entered.emit(pocket)
	emit_settled()
