extends Node2D
class_name Board

@export var peg_scene: PackedScene
@export var pocket_scene: PackedScene
@export var target_scene: PackedScene
@export var split_peg_chance_bonus: float = 0.0
@export var target_spawn_on_elite: bool = false
@export var target_spawn_multiplier: float = 1.0
@export var target_speed_multiplier: float = 1.0
@export var enable_curse_mix: bool = false
@export var hazard_strength: float = 0.0
@export var enable_moving_bumpers: bool = false
@export var enable_lane_gate: bool = false

@onready var pegs: Node2D = $Pegs
@onready var pockets: Node2D = $Pockets
@onready var targets: Node2D = get_node_or_null("Targets")
@onready var hazards: Node2D = get_node_or_null("Hazards")

var _hazard_nodes: Array[Node2D] = []
var _hazard_origins: Array[Vector2] = []
var _hazard_phases: Array[float] = []
var _hazard_ranges: Array[float] = []
var _hazard_speeds: Array[float] = []
var _hazard_axis: Array[Vector2] = []

func build_layout(board_kind: String = "classic") -> void:
	_ensure_aux_nodes()
	for child in pegs.get_children():
		child.queue_free()
	for child in pockets.get_children():
		child.queue_free()
	for child in targets.get_children():
		child.queue_free()
	for child in hazards.get_children():
		child.queue_free()
	_hazard_nodes.clear()
	_hazard_origins.clear()
	_hazard_phases.clear()
	_hazard_ranges.clear()
	_hazard_speeds.clear()
	_hazard_axis.clear()

	_spawn_pegs(board_kind)
	_spawn_pockets()
	_spawn_targets(board_kind)
	_spawn_hazards(board_kind)
	_assign_special_pegs()

func _process(_delta: float) -> void:
	if _hazard_nodes.is_empty():
		return
	var t: float = Time.get_ticks_msec() * 0.001
	for i in range(_hazard_nodes.size()):
		var node := _hazard_nodes[i]
		if not is_instance_valid(node):
			continue
		var offset := sin(t * _hazard_speeds[i] + _hazard_phases[i]) * _hazard_ranges[i]
		node.global_position = _hazard_origins[i] + _hazard_axis[i] * offset

func _spawn_pegs(board_kind: String) -> void:
	var rows := 10
	var cols := 9
	var spacing_x := 100.0
	var spacing_y := 94.0
	var start_x := 140.0
	var start_y := 290.0
	var board_offset_y := 80.0

	match board_kind:
		"risk":
			rows = 8
			cols = 8
			spacing_x = 118.0
			spacing_y = 116.0
			start_x = 130.0
			start_y = 320.0 + board_offset_y
		"combo":
			rows = 12
			cols = 10
			spacing_x = 88.0
			spacing_y = 82.0
			start_x = 110.0
			start_y = 260.0 + board_offset_y
		"chaos":
			rows = 10
			cols = 9
			spacing_x = 102.0
			spacing_y = 92.0
			start_x = 130.0
			start_y = 280.0 + board_offset_y
		_:
			start_y += board_offset_y

	var multiplier_pegs: Array[Peg] = []
	for row in rows:
		for col in cols:
			var x := start_x + (col * spacing_x) + (row % 2) * (spacing_x * 0.5)
			if x > 980.0:
				continue
			var peg := peg_scene.instantiate() as Peg
			peg.global_position = Vector2(x, start_y + row * spacing_y)
			peg.peg_type = _random_peg_type(board_kind)
			peg.is_split_peg = _is_split_peg(board_kind, peg.peg_type)
			peg.danger_level = clampf(hazard_strength, 0.0, 1.5)
			if hazard_strength > 0.22 and randf() < hazard_strength * 0.32:
				peg.tier = 1
			if hazard_strength > 0.52 and randf() < (hazard_strength - 0.45) * 0.55:
				peg.tier = 2
			if hazard_strength > 0.82 and randf() < 0.12:
				peg.tier = 3
			pegs.add_child(peg)
			if peg.peg_type == Peg.PegType.MULTIPLIER:
				multiplier_pegs.append(peg)

	# Guarantee at least one visible split peg each board so multiball shows up every run.
	if not multiplier_pegs.is_empty():
		var top_split := multiplier_pegs[0]
		for mpeg in multiplier_pegs:
			if mpeg.global_position.y < top_split.global_position.y:
				top_split = mpeg
		top_split.is_split_peg = true

func _spawn_pockets() -> void:
	var pocket_width := 320.0
	var y := 1785.0
	var x_values := [180.0, 540.0, 900.0]
	var types: Array[Pocket.PocketType] = [
	Pocket.PocketType.REFUND,
	Pocket.PocketType.CRIT,
	Pocket.PocketType.CASHOUT,
	]

	for i in x_values.size():
		var pocket := pocket_scene.instantiate() as Pocket
		pocket.global_position = Vector2(x_values[i], y)
		pocket.size = Vector2(pocket_width, 90.0)
		pocket.pocket_type = types[i]
		pocket.danger_level = hazard_strength
		pockets.add_child(pocket)

func _spawn_targets(board_kind: String) -> void:
	var spawn := board_kind == "chaos"
	if target_spawn_on_elite and (board_kind == "risk" or board_kind == "combo"):
		spawn = true
	if not spawn:
		return
	if target_scene == null:
		target_scene = load("res://scenes/MovingBoxTarget.tscn") as PackedScene
	if target_scene == null:
		return

	var lanes := [260.0, 540.0, 820.0]
	if target_spawn_multiplier >= 1.7:
		lanes = [190.0, 380.0, 540.0, 700.0, 890.0]
	var rewards: Array[int] = [
		MovingBoxTarget.RewardType.GOLD,
		MovingBoxTarget.RewardType.DAMAGE,
		MovingBoxTarget.RewardType.MULTIPLIER,
		MovingBoxTarget.RewardType.JACKPOT,
		MovingBoxTarget.RewardType.COMBO_LOCK,
		MovingBoxTarget.RewardType.POCKET_CHARGE,
		MovingBoxTarget.RewardType.SHARD_BURST,
		MovingBoxTarget.RewardType.AMMO,
	]
	rewards.shuffle()
	for i in range(lanes.size()):
		var box := target_scene.instantiate() as MovingBoxTarget
		box.global_position = Vector2(lanes[i], 1720.0)
		box.speed = (1.4 + float(i) * 0.35) * target_spawn_multiplier * target_speed_multiplier
		box.movement_range = 145.0 + float(i) * 30.0
		box.reward_type = rewards[i % rewards.size()] as MovingBoxTarget.RewardType
		box.reward_amount = 10.0 + float(i) * 4.0
		if box.reward_type == MovingBoxTarget.RewardType.JACKPOT:
			box.reward_amount = 1.0
		elif box.reward_type == MovingBoxTarget.RewardType.COMBO_LOCK:
			box.reward_amount = 8.0
		elif box.reward_type == MovingBoxTarget.RewardType.POCKET_CHARGE:
			box.reward_amount = 1.0
		elif box.reward_type == MovingBoxTarget.RewardType.SHARD_BURST:
			box.reward_amount = 4.0 + float(i)
		targets.add_child(box)

func _random_peg_type(board_kind: String) -> Peg.PegType:
	var roll := randf()
	if enable_curse_mix and roll < 0.10:
		return Peg.PegType.MULTIPLIER
	if board_kind == "combo":
		if roll < 0.35:
			return Peg.PegType.DAMAGE
		if roll < 0.70:
			return Peg.PegType.GOLD
		if roll < 0.86:
			return Peg.PegType.SHIELD
		return Peg.PegType.MULTIPLIER
	if board_kind == "risk":
		if roll < 0.58:
			return Peg.PegType.DAMAGE
		if roll < 0.80:
			return Peg.PegType.GOLD
		if roll < 0.92:
			return Peg.PegType.SHIELD
		return Peg.PegType.MULTIPLIER
	if roll < 0.46:
		return Peg.PegType.DAMAGE
	if roll < 0.74:
		return Peg.PegType.GOLD
	if roll < 0.90:
		return Peg.PegType.SHIELD
	return Peg.PegType.MULTIPLIER

func _is_split_peg(board_kind: String, peg_type: Peg.PegType) -> bool:
	if peg_type != Peg.PegType.MULTIPLIER:
		return false

	var base_chance: float = 0.22
	if board_kind == "combo":
		base_chance = 0.30
	elif board_kind == "risk":
		base_chance = 0.18
	elif board_kind == "chaos":
		base_chance = 0.26

	var chance: float = clampf(base_chance + split_peg_chance_bonus, 0.0, 0.65)
	return randf() < chance

func _ensure_aux_nodes() -> void:
	if targets == null:
		targets = Node2D.new()
		targets.name = "Targets"
		add_child(targets)
	if hazards == null:
		hazards = Node2D.new()
		hazards.name = "Hazards"
		add_child(hazards)

func _assign_special_pegs() -> void:
	var special_pool: Array[int] = []
	if has_meta("special_pool"):
		var pool: Variant = get_meta("special_pool")
		if pool is Array:
			special_pool = pool as Array[int]
	var count := 0
	if has_meta("special_count"):
		count = int(get_meta("special_count"))
	if special_pool.is_empty() or count <= 0:
		return
	var all_pegs := get_random_pegs(9999)
	if all_pegs.is_empty():
		return
	all_pegs.shuffle()
	var pick_count := mini(count, all_pegs.size())
	for i in range(pick_count):
		var peg := all_pegs[i]
		if peg == null:
			continue
		var special := special_pool[randi() % special_pool.size()]
		peg.special_effect = special as Peg.SpecialEffect

func _spawn_hazards(board_kind: String) -> void:
	if not enable_moving_bumpers and not enable_lane_gate:
		return
	if enable_moving_bumpers:
		var count := 1
		if hazard_strength > 0.35:
			count = 2
		if hazard_strength > 0.75:
			count = 3
		for i in range(count):
			var x := 260.0 + float(i) * 260.0
			if count == 3:
				x = 170.0 + float(i) * 360.0
			var y := 990.0 + float(i % 2) * 220.0
			_make_hazard_bumper(Vector2(x, y), 28.0 + hazard_strength * 6.0, true)
	if enable_lane_gate:
		var gate_y := 1260.0
		if board_kind == "risk":
			gate_y = 1160.0
		_make_hazard_gate(Vector2(540, gate_y))

func _make_hazard_bumper(origin: Vector2, radius: float, moving: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.global_position = origin
	body.add_to_group("hazard")
	body.set_meta("hazard_label", "BUMPER")
	body.set_meta("hazard_damage", int(round(4.0 + hazard_strength * 5.0)))
	hazards.add_child(body)

	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	body.add_child(shape_node)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array(_circle_points(radius + 5.0, 20))
	visual.color = Color(1.0, 0.62, 0.28, 0.44)
	body.add_child(visual)

	var core := Polygon2D.new()
	core.polygon = PackedVector2Array(_circle_points(radius - 3.0, 18))
	core.color = Color(0.98, 0.28, 0.52, 0.82)
	body.add_child(core)

	if moving:
		_hazard_nodes.append(body)
		_hazard_origins.append(origin)
		_hazard_phases.append(randf_range(0.0, TAU))
		_hazard_ranges.append(95.0 + hazard_strength * 55.0)
		_hazard_speeds.append(0.8 + hazard_strength * 1.2)
		_hazard_axis.append(Vector2(1, 0))

func _make_hazard_gate(origin: Vector2) -> void:
	var gate := StaticBody2D.new()
	gate.collision_layer = 1
	gate.collision_mask = 1
	gate.global_position = origin
	gate.add_to_group("hazard")
	gate.set_meta("hazard_label", "GATE")
	gate.set_meta("hazard_damage", int(round(8.0 + hazard_strength * 6.0)))
	hazards.add_child(gate)

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(250.0, 18.0)
	shape_node.shape = rect
	gate.add_child(shape_node)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-130, -12),
		Vector2(130, -12),
		Vector2(130, 12),
		Vector2(-130, 12),
	])
	visual.color = Color(0.72, 0.18, 0.86, 0.80)
	gate.add_child(visual)

	_hazard_nodes.append(gate)
	_hazard_origins.append(origin)
	_hazard_phases.append(randf_range(0.0, TAU))
	_hazard_ranges.append(280.0 + hazard_strength * 120.0)
	_hazard_speeds.append(0.42 + hazard_strength * 0.9)
	_hazard_axis.append(Vector2(1, 0))

func _circle_points(radius: float, points: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(points):
		var a := TAU * float(i) / float(points)
		out.append(Vector2(cos(a), sin(a)) * radius)
	return out

func remove_pegs(pegs_to_remove: Array[Peg]) -> int:
	var removed := 0
	for peg in pegs_to_remove:
		if is_instance_valid(peg):
			peg.queue_free()
			removed += 1
	return removed

func get_random_pegs(count: int) -> Array[Peg]:
	var all_pegs: Array[Peg] = []
	for child in pegs.get_children():
		if child is Peg:
			all_pegs.append(child as Peg)
	all_pegs.shuffle()
	if all_pegs.size() <= count:
		return all_pegs
	return all_pegs.slice(0, count)
