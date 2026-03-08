extends Camera2D

var _time := 0.0
var _duration := 0.0
var _amount := 0.0
var _base_offset := Vector2.ZERO

func _ready() -> void:
	_base_offset = offset
	EventBus.shake_requested.connect(request_shake)

func request_shake(amount: float, duration: float) -> void:
	_amount = maxf(_amount, amount * 40.0)
	_duration = maxf(_duration, duration)
	_time = 0.0

func _process(delta: float) -> void:
	if _time < _duration:
		_time += delta
		var t := 1.0 - (_time / _duration)
		offset = _base_offset + Vector2(
			randf_range(-_amount, _amount),
			randf_range(-_amount, _amount)
		) * t
	else:
		offset = _base_offset
		_amount = 0.0
		_duration = 0.0
