extends Node2D

@export var life := 0.16
@export var start_scale := 0.2
@export var end_scale := 1.1
@export var start_alpha := 0.8

func _ready() -> void:
	scale = Vector2.ONE * start_scale
	modulate.a = start_alpha
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * end_scale, life)
	tw.parallel().tween_property(self, "modulate:a", 0.0, life)
	tw.finished.connect(queue_free)
