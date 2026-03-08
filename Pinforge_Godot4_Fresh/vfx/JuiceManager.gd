extends Node2D
class_name JuiceManager

@export var impact_ring_scene: PackedScene
@export var sparks_scene: PackedScene
@export var beam_scene: PackedScene
@export var popup_scene: PackedScene

var _last_pocket_pos := Vector2.ZERO

func _ready() -> void:
	EventBus.peg_hit.connect(_on_peg_hit)
	EventBus.pocket_landed.connect(_on_pocket_landed)
	EventBus.drop_resolved.connect(_on_drop_resolved)

func _on_peg_hit(_peg_type: int, _value: float, world_pos: Vector2) -> void:
	_spawn(impact_ring_scene, world_pos)
	_spawn(sparks_scene, world_pos)

func _on_pocket_landed(_pocket_type: int, _totals: Dictionary, world_pos: Vector2) -> void:
	_last_pocket_pos = world_pos
	_spawn(beam_scene, world_pos)
	EventBus.shake_requested.emit(0.35, 0.12)

func _on_drop_resolved(totals: Dictionary) -> void:
	_spawn_popup(_last_pocket_pos, totals)

func _spawn(scene: PackedScene, pos: Vector2) -> void:
	if scene == null:
		return
	var node := scene.instantiate() as Node2D
	add_child(node)
	node.global_position = pos

func _spawn_popup(world_pos: Vector2, totals: Dictionary) -> void:
	if popup_scene == null:
		return
	var popup := popup_scene.instantiate()
	get_tree().root.add_child(popup)
	if popup.has_method("setup"):
		popup.setup(totals)
	var screen_pos := _world_to_screen(world_pos)
	if popup is Node2D:
		(popup as Node2D).global_position = world_pos
	elif popup is Control:
		(popup as Control).global_position = screen_pos

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos
