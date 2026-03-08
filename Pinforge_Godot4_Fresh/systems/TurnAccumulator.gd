extends Node
class_name TurnAccumulator

var totals: Dictionary[String, float] = {
	"damage": 0.0,
	"gold": 0.0,
	"shield": 0.0,
}

func _ready() -> void:
	EventBus.drop_started.connect(_on_drop_started)
	EventBus.peg_hit.connect(_on_peg_hit)

func _on_drop_started() -> void:
	totals = {
		"damage": 0.0,
		"gold": 0.0,
		"shield": 0.0,
	}

func _on_peg_hit(peg_type: int, value: float, _pos: Vector2) -> void:
	match peg_type:
		0:
			totals["damage"] += value
		1:
			totals["gold"] += value
		2:
			totals["shield"] += value
		3:
			pass
		_:
			totals["damage"] += value

func pocket_landed(pocket_type: int, world_pos: Vector2) -> void:
	EventBus.pocket_landed.emit(pocket_type, totals, world_pos)
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(func() -> void:
		EventBus.drop_resolved.emit(totals)
	)
