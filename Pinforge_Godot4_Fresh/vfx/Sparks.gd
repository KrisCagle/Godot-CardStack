extends Node2D

@export var life := 0.25

func _ready() -> void:
	var timer := get_tree().create_timer(life)
	timer.timeout.connect(queue_free)
