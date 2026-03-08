extends Control

@onready var label: Label = $Label

func setup(totals: Dictionary) -> void:
	var dmg: float = float(totals.get("damage", 0.0))
	var gold: float = float(totals.get("gold", 0.0))
	var shield: float = float(totals.get("shield", 0.0))
	label.text = "+Dmg %d   +Gold %d   +Shield %d" % [int(dmg), int(gold), int(shield)]
	_play()

func _play() -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * 0.95
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.finished.connect(queue_free)
