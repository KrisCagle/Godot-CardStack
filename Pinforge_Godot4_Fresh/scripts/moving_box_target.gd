extends Area2D
class_name MovingBoxTarget

enum RewardType {
	GOLD,
	DAMAGE,
	AMMO,
	MULTIPLIER,
	JACKPOT,
	COMBO_LOCK,
	POCKET_CHARGE,
	SHARD_BURST,
}

@export var reward_type: RewardType = RewardType.GOLD:
	set(value):
		reward_type = value
		queue_redraw()
@export var reward_amount: float = 12.0
@export var speed: float = 1.5
@export var movement_range: float = 210.0
@export var cooldown_time: float = 0.7

var _origin_x: float = 0.0
var _phase: float = 0.0
var _cooldown: float = 0.0
var _hit_flash: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = true
	_origin_x = global_position.x
	_phase = randf_range(0.0, TAU)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	global_position.x = _origin_x + sin(Time.get_ticks_msec() * 0.001 * speed + _phase) * movement_range
	if _cooldown > 0.0:
		_cooldown -= delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 3.8)
	queue_redraw()

func _draw() -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.5 + 0.5 * sin(t * 3.1 + _phase * 2.0)
	var live_scale: float = 1.0 if _cooldown <= 0.0 else 0.72
	var flash_mix: float = clampf(_hit_flash, 0.0, 1.0)
	var base := _type_color()
	base = base.lightened(0.08 * pulse).lerp(Color.WHITE, flash_mix * 0.45)
	var glow := base
	glow.a = (0.14 + 0.10 * pulse) * live_scale + flash_mix * 0.35
	var shadow := Color(0, 0, 0, 0.28)
	draw_rect(Rect2(Vector2(-68, -24) + Vector2(5, 6), Vector2(136, 52)), shadow, true)
	draw_rect(Rect2(-72, -30, 144, 60), glow, true)
	draw_rect(Rect2(-64, -24, 128, 48), Color(0.05, 0.08, 0.15, 0.90), true)
	draw_rect(Rect2(-61, -21, 122, 42), base, true)
	draw_rect(Rect2(-61, -21, 122, 42), Color(1, 1, 1, 0.38 + flash_mix * 0.4), false, 2.0)
	draw_rect(Rect2(-61, -21, 122, 10), Color(1, 1, 1, 0.16 + flash_mix * 0.25), true)
	for i in range(3):
		var y: float = -8.0 + float(i) * 8.0
		draw_line(Vector2(-52, y), Vector2(52, y), Color(1, 1, 1, 0.07), 1.0)

	var side_light := base.lightened(0.45)
	draw_rect(Rect2(-70, -18, 5, 36), side_light, true)
	draw_rect(Rect2(65, -18, 5, 36), side_light, true)

	var label := _label()
	var font := ThemeDB.fallback_font
	if font:
		var color := Color(0.03, 0.05, 0.10, 0.98)
		var text_size := 24
		draw_string(font, Vector2(-60, 9), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, text_size, color)

func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if body is Ball:
		_cooldown = cooldown_time
		_hit_flash = 1.0
		EventBus.target_box_hit.emit(int(reward_type), reward_amount, global_position)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.15, 0.86), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _label() -> String:
	match reward_type:
		RewardType.GOLD:
			return "GOLD"
		RewardType.DAMAGE:
			return "DMG"
		RewardType.AMMO:
			return "BALL"
		RewardType.MULTIPLIER:
			return "MULTI"
		RewardType.JACKPOT:
			return "JACKPOT"
		RewardType.COMBO_LOCK:
			return "LOCK"
		RewardType.POCKET_CHARGE:
			return "POCKET"
		RewardType.SHARD_BURST:
			return "SHARD"
		_:
			return "BONUS"

func _type_color() -> Color:
	match reward_type:
		RewardType.GOLD:
			return Color("fbcf4a")
		RewardType.DAMAGE:
			return Color("ff5e9a")
		RewardType.AMMO:
			return Color("73f0a8")
		RewardType.MULTIPLIER:
			return Color("b88cff")
		RewardType.JACKPOT:
			return Color("ff8c3a")
		RewardType.COMBO_LOCK:
			return Color("7ec7ff")
		RewardType.POCKET_CHARGE:
			return Color("96ff7f")
		RewardType.SHARD_BURST:
			return Color("77f0ff")
		_:
			return Color.WHITE
