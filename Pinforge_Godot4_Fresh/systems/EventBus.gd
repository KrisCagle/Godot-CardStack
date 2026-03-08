extends Node


signal drop_started()
signal peg_hit(peg_type: int, value: float, world_pos: Vector2)
signal pocket_landed(pocket_type: int, totals: Dictionary, world_pos: Vector2)
signal drop_resolved(totals: Dictionary)
signal combo_changed(combo: float)
signal shake_requested(amount: float, duration: float)
signal target_box_hit(reward_type: int, amount: float, world_pos: Vector2)
