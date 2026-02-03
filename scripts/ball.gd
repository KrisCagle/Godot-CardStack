extends RigidBody2D
class_name Ball

signal peg_hit(peg: Peg)
signal pocket_entered(pocket: Pocket)
signal settled()

@export var radius: float = 12.0

var _hit_peg_ids: Dictionary = {}
var _settled_emitted := false
var _slow_time := 0.0
var _trail: Line2D
var _trail_points: Array[Vector2] = []

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	_setup_trail()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color("f8fafc"))
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 20, Color("94a3b8"), 2.0)

func _physics_process(delta: float) -> void:
	if _settled_emitted:
		return

	_update_trail()

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
		peg_hit.emit(peg)

func enter_pocket(pocket: Pocket) -> void:
	if _settled_emitted:
		return
	pocket_entered.emit(pocket)
	emit_settled()

func _setup_trail() -> void:
	_trail = Line2D.new()
	_trail.width = 5.0
	_trail.default_color = Color(0.78, 0.9, 1.0, 0.55)
	_trail.z_index = -1
	_trail.top_level = true
	_trail.global_position = Vector2.ZERO
	add_child(_trail)

func _update_trail() -> void:
	if not _trail:
		return
	_trail_points.append(global_position)
	if _trail_points.size() > 12:
		_trail_points.remove_at(0)
	_trail.clear_points()
	for p in _trail_points:
		_trail.add_point(p)
