extends Node2D

@export var life := 0.22

func _ready() -> void:
	scale = Vector2(0.6, 0.0)
	modulate.a = 0.8
	var tw := create_tween()
	tw.tween_property(self, "scale:y", 1.2, life * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, life)
	tw.finished.connect(queue_free)
