extends Node2D
class_name Board

@export var peg_scene: PackedScene
@export var pocket_scene: PackedScene
@export var split_peg_chance_bonus: float = 0.0

@onready var pegs: Node2D = $Pegs
@onready var pockets: Node2D = $Pockets

func build_layout(board_kind: String = "classic") -> void:
	for child in pegs.get_children():
		child.queue_free()
	for child in pockets.get_children():
		child.queue_free()

	_spawn_pegs(board_kind)
	_spawn_pockets()

func _spawn_pegs(board_kind: String) -> void:
	var rows := 10
	var cols := 9
	var spacing_x := 100.0
	var spacing_y := 94.0
	var start_x := 140.0
	var start_y := 290.0

	match board_kind:
		"risk":
			rows = 8
			cols = 8
			spacing_x = 118.0
			spacing_y = 116.0
			start_x = 130.0
			start_y = 320.0
		"combo":
			rows = 12
			cols = 10
			spacing_x = 88.0
			spacing_y = 82.0
			start_x = 110.0
			start_y = 260.0
		"chaos":
			rows = 10
			cols = 9
			spacing_x = 102.0
			spacing_y = 92.0
			start_x = 130.0
			start_y = 280.0

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
	var y := 1820.0
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
		pockets.add_child(pocket)

func _random_peg_type(board_kind: String) -> Peg.PegType:
	var roll := randf()
	if board_kind == "combo":
		if roll < 0.35:
			return Peg.PegType.DAMAGE
		if roll < 0.70:
			return Peg.PegType.GOLD
		return Peg.PegType.MULTIPLIER
	if board_kind == "risk":
		if roll < 0.62:
			return Peg.PegType.DAMAGE
		if roll < 0.88:
			return Peg.PegType.GOLD
		return Peg.PegType.MULTIPLIER
	if roll < 0.5:
		return Peg.PegType.DAMAGE
	if roll < 0.8:
		return Peg.PegType.GOLD
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
