extends Node2D

@export var ball_scene: PackedScene

@onready var board: Board = $Board
@onready var launcher: Launcher = $Launcher
@onready var balls: Node2D = $Balls
@onready var backdrop: ColorRect = $Backdrop

@onready var stats_label: Label = $HUD/Root/Top/VBox/Stats
@onready var turn_label: Label = $HUD/Root/Top/VBox/Turn
@onready var message_label: Label = $HUD/Root/CenterMessage
@onready var left_button: Button = $HUD/Root/Bottom/Controls/Left
@onready var drop_button: Button = $HUD/Root/Bottom/Controls/Drop
@onready var right_button: Button = $HUD/Root/Bottom/Controls/Right
@onready var top_vbox: VBoxContainer = $HUD/Root/Top/VBox

const MEGA_TURN_BASE := 110

enum NodeType {
	FIGHT,
	EVENT,
	SHOP,
	BOSS,
}

enum EnemyType {
	SHIELD_SNAIL,
	TAX_COLLECTOR,
	PEG_EATER,
	PIN_KING,
}

enum LoadoutType {
	SPLIT,
	GREED,
	VAMP,
}

var player_hp := 100
var enemy_hp := 130
var enemy_shield := 0
var gold := 0
var ammo := 1
var starting_ammo := 1

var turn_damage := 0
var turn_gold := 0
var turn_multiplier := 1.0
var turn_combo := 0
var turn_last_pocket := -1
var turn_hit_pegs: Array[Peg] = []
var split_triggered_peg_ids: Dictionary = {}
var extra_balls_spawned_this_turn := 0
var combo_tier := 0
var combo_label: Label

var damage_peg_power := 8.0
var gold_peg_value := 2.0
var multiplier_peg_gain := 0.20
var combo_bonus := 1.0
var crit_multiplier := 2.0
var cashout_rate := 10.0
var pocket_refund_bonus := 0
var base_balls_per_drop := 1
var max_extra_balls_per_turn := 6
var legendary_chain_reaction := false
var legendary_portal_core := false
var legendary_fractal_engine := false

var selected_loadout := LoadoutType.SPLIT
var act_idx := 1
var node_idx_in_act := 1
var encounter_idx := 1
var current_node_type := NodeType.FIGHT
var current_enemy_type := EnemyType.SHIELD_SNAIL
var current_board_kind := "classic"
var mega_turn_streak := 0

var active_ball: Ball
var awaiting_resolve := false
var awaiting_choice := false
var in_combat := false
var pending_complete_after_upgrade := false
var balls_in_play := 0

var choice_panel: PanelContainer
var choice_title_label: Label
var choice_subtitle_label: Label
var choice_buttons: Array[Button] = []
var choice_context := ""
var choice_payload: Array[String] = []

var camera_2d: Camera2D
var shake_strength := 0.0
var combo_sfx_player: AudioStreamPlayer
var combo_sfx_playback: AudioStreamGeneratorPlayback

var meta_shards := 0
var meta_hp_level := 0
var meta_gold_level := 0
var meta_split_level := 0

func _ready() -> void:
	randomize()
	_ensure_input_actions()
	_build_choice_ui()
	_setup_combo_ui()
	_setup_combo_sfx()
	_setup_camera()
	_load_meta_progress()
	if ball_scene == null:
		ball_scene = load("res://scenes/Ball.tscn") as PackedScene

	left_button.pressed.connect(func(): launcher.nudge(-1.0))
	right_button.pressed.connect(func(): launcher.nudge(1.0))
	drop_button.pressed.connect(_drop_ball)

	_start_new_run()

func _unhandled_input(event: InputEvent) -> void:
	if not in_combat or awaiting_choice:
		return

	if event is InputEventScreenDrag:
		launcher.set_target_x(event.position.x)
	elif event is InputEventScreenTouch and event.pressed:
		if event.position.y < 1450.0:
			launcher.set_target_x(event.position.x)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if event.position.y < 1450.0:
			launcher.set_target_x(event.position.x)

	if event.is_action_pressed("drop_ball"):
		_drop_ball()

func _physics_process(delta: float) -> void:
	if in_combat and not awaiting_choice:
		var axis := Input.get_axis("aim_left", "aim_right")
		if axis != 0.0:
			launcher.nudge(axis, 480.0 * delta)

	if shake_strength > 0.0 and camera_2d:
		camera_2d.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = max(0.0, shake_strength - (45.0 * delta))
	else:
		if camera_2d:
			camera_2d.offset = Vector2.ZERO

func _start_new_run() -> void:
	player_hp = 100 + meta_hp_level * 12
	gold = meta_gold_level * 8
	act_idx = 1
	node_idx_in_act = 1
	encounter_idx = 1
	mega_turn_streak = 0
	current_board_kind = "classic"

	starting_ammo = 1
	ammo = 1
	damage_peg_power = 8.0
	gold_peg_value = 2.0
	multiplier_peg_gain = 0.20
	combo_bonus = 1.0
	crit_multiplier = 2.0
	cashout_rate = 10.0
	pocket_refund_bonus = 0
	turn_combo = 0
	combo_tier = 0
	base_balls_per_drop = 1
	max_extra_balls_per_turn = 6
	legendary_chain_reaction = false
	legendary_portal_core = false
	legendary_fractal_engine = false
	balls_in_play = 0
	extra_balls_spawned_this_turn = 0
	split_triggered_peg_ids.clear()
	board.split_peg_chance_bonus = 0.02 * float(meta_split_level)
	_apply_board_theme()
	_update_combo_ui()

	awaiting_choice = false
	in_combat = false
	pending_complete_after_upgrade = false
	_set_controls_enabled(false)
	_show_meta_choices()
	_update_hud("Spend shards or continue to loadout.")

func _show_loadout_choices() -> void:
	var ids := ["split", "greed", "vamp"]
	_show_choice("loadout", "Pick Your Loadout", "Each changes your run style.", ids)

func _show_meta_choices() -> void:
	var ids := ["meta_hp", "meta_split", "meta_continue"]
	var subtitle := "Shards %d  |  HP Lv%d  Gold Lv%d  Split Lv%d" % [meta_shards, meta_hp_level, meta_gold_level, meta_split_level]
	_show_choice("meta", "Sanctum Upgrades", subtitle, ids)

func _drop_ball() -> void:
	if not in_combat or awaiting_resolve or awaiting_choice or ammo <= 0:
		return
	if ball_scene == null:
		_show_message("Ball scene missing. Reassign Main.ball_scene to res://scenes/Ball.tscn")
		return

	ammo -= 1
	awaiting_resolve = true
	_reset_turn()
	var start_count: int = maxi(1, base_balls_per_drop)
	for i in start_count:
		var spread_x := 0.0
		if start_count > 1:
			spread_x = lerpf(-120.0, 120.0, float(i) / float(start_count - 1))
		_spawn_ball(launcher.global_position + Vector2(0, 70), Vector2(spread_x + randf_range(-35.0, 35.0), 120.0))

	_show_message("Ball in play... (%d)" % balls_in_play)
	_update_hud()

func _spawn_ball(spawn_pos: Vector2, velocity: Vector2) -> void:
	var ball := ball_scene.instantiate() as Ball
	ball.global_position = spawn_pos
	ball.linear_velocity = velocity
	ball.peg_hit.connect(_on_ball_peg_hit)
	ball.pocket_entered.connect(_on_ball_pocket_entered)
	ball.settled.connect(_on_ball_settled)
	balls.add_child(ball)
	active_ball = ball
	balls_in_play += 1

func _spawn_multiball_from_peg(origin: Vector2) -> void:
	var desired := 2
	if legendary_fractal_engine:
		desired = 3
	var spawn_count: int = mini(desired, max_extra_balls_per_turn - extra_balls_spawned_this_turn)
	if spawn_count <= 0:
		return
	for i in spawn_count:
		var speed_x := randf_range(80.0, 180.0)
		if i == 0:
			speed_x *= -1.0
		_spawn_ball(origin + Vector2(randf_range(-8.0, 8.0), -12.0), Vector2(speed_x, randf_range(90.0, 180.0)))
		extra_balls_spawned_this_turn += 1

func _on_ball_peg_hit(peg: Peg) -> void:
	turn_combo += 1
	var old_tier := combo_tier
	combo_tier = mini(5, int(turn_combo / 4))
	if not turn_hit_pegs.has(peg):
		turn_hit_pegs.append(peg)

	match peg.peg_type:
		Peg.PegType.DAMAGE:
			var added_damage := int(round(damage_peg_power + (turn_combo * combo_bonus)))
			turn_damage += added_damage
			_pop_text("+%d DMG" % added_damage, peg.global_position, Color(1.0, 0.55, 0.55), 28)
			_spawn_impact_burst(peg.global_position, Color(1.0, 0.45, 0.45))
		Peg.PegType.GOLD:
			var added_gold := int(round(gold_peg_value))
			turn_gold += added_gold
			_pop_text("+%d G" % added_gold, peg.global_position, Color(1.0, 0.86, 0.4), 28)
			_spawn_impact_burst(peg.global_position, Color(1.0, 0.86, 0.4))
		Peg.PegType.MULTIPLIER:
			turn_multiplier += multiplier_peg_gain
			_pop_text("x+%.2f" % multiplier_peg_gain, peg.global_position, Color(0.62, 0.86, 1.0), 26)
			_spawn_impact_burst(peg.global_position, Color(0.62, 0.86, 1.0))
			if current_enemy_type == EnemyType.PIN_KING:
				enemy_shield += 6
				_pop_text("KING SHIELD +6", peg.global_position, Color(1.0, 0.65, 0.35))
	if legendary_chain_reaction:
		turn_gold += 1
		turn_multiplier += 0.05
		_pop_text("CHAIN!", peg.global_position + Vector2(0, -20), Color(0.85, 1.0, 0.75), 20)

	var peg_id := peg.get_instance_id()
	if peg.is_split_peg and not split_triggered_peg_ids.has(peg_id) and extra_balls_spawned_this_turn < max_extra_balls_per_turn:
		split_triggered_peg_ids[peg_id] = true
		_spawn_multiball_from_peg(peg.global_position)
		_pop_text("MULTIBALL!", peg.global_position, Color(0.95, 0.95, 1.0))
		_shake(8.0)

	if selected_loadout == LoadoutType.SPLIT and turn_combo % 3 == 0:
		var burst := int(round(damage_peg_power * 0.9))
		turn_damage += burst
		turn_multiplier += 0.10
		_pop_text("SPLIT +%d" % burst, peg.global_position, Color(0.75, 0.95, 1.0))
		_shake(6.0)

	if combo_tier > old_tier:
		_play_combo_tone(combo_tier)
		_pop_text("TIER %d" % combo_tier, peg.global_position + Vector2(0, -34), Color(1.0, 0.9, 0.55), 24)

	_update_combo_ui()
	_update_hud()

func _on_ball_pocket_entered(pocket: Pocket) -> void:
	turn_last_pocket = pocket.pocket_type
	match pocket.pocket_type:
		Pocket.PocketType.REFUND:
			var refund := 1 + pocket_refund_bonus
			ammo += refund
			_show_message("Refund! +%d ammo" % refund)
			_pop_text("+%d AMMO" % refund, pocket.global_position, Color(0.7, 1.0, 0.7), 30)
			_spawn_impact_burst(pocket.global_position, Color(0.7, 1.0, 0.7), 1.6)
		Pocket.PocketType.CRIT:
			turn_multiplier *= crit_multiplier
			_show_message("Crit pocket! x%.1f" % crit_multiplier)
			_pop_text("CRIT x%.1f" % crit_multiplier, pocket.global_position, Color(1.0, 0.7, 0.9), 32)
			_spawn_impact_burst(pocket.global_position, Color(1.0, 0.7, 0.9), 1.8)
		Pocket.PocketType.CASHOUT:
			var bonus_gold := int(round((turn_multiplier - 1.0) * cashout_rate))
			turn_gold += max(bonus_gold, 0)
			_show_message("Cashout bonus!")
			_pop_text("+%d GOLD" % max(bonus_gold, 0), pocket.global_position, Color(1.0, 0.9, 0.4), 30)
			_spawn_impact_burst(pocket.global_position, Color(1.0, 0.9, 0.4), 1.8)
	if legendary_portal_core and extra_balls_spawned_this_turn < max_extra_balls_per_turn and randf() < 0.45:
		_spawn_ball(Vector2(launcher.global_position.x, 230.0), Vector2(randf_range(-140.0, 140.0), 80.0))
		extra_balls_spawned_this_turn += 1
		_pop_text("PORTAL BALL!", pocket.global_position + Vector2(0, -30), Color(0.9, 0.7, 1.0), 24)

func _on_ball_settled() -> void:
	if not awaiting_resolve:
		return
	balls_in_play = maxi(0, balls_in_play - 1)
	if balls_in_play > 0:
		_update_hud()
		return
	awaiting_resolve = false

	var dealt_damage := int(round(turn_damage * turn_multiplier))
	dealt_damage = int(round(float(dealt_damage) * (1.0 + float(combo_tier) * 0.12)))
	var gained_gold := turn_gold

	if selected_loadout == LoadoutType.GREED:
		dealt_damage = int(round(dealt_damage * 0.74))
		gained_gold = int(round(gained_gold * 1.65))

	dealt_damage = _apply_enemy_rules_to_damage(dealt_damage)
	gained_gold = _apply_enemy_rules_to_gold(gained_gold)
	dealt_damage = _apply_enemy_shield(dealt_damage)

	enemy_hp -= dealt_damage
	gold += gained_gold

	if selected_loadout == LoadoutType.VAMP and dealt_damage > 0:
		var heal: int = maxi(1, int(round(dealt_damage * 0.18)))
		player_hp += heal
		_pop_text("+%d HP" % heal, launcher.global_position + Vector2(0, -30), Color(0.65, 1.0, 0.7))

	_resolve_mega_turn(dealt_damage)
	_resolve_peg_eater()

	if enemy_hp <= 0:
		enemy_hp = 0
		_on_enemy_defeated()
		return

	if ammo <= 0:
		_enemy_attack()
		ammo = starting_ammo

	_update_hud()

func _apply_enemy_rules_to_damage(value: int) -> int:
	var result := value
	if current_enemy_type == EnemyType.SHIELD_SNAIL and turn_combo < 5:
		result = int(round(result * 0.35))
		_show_message("Shield Snail blocked your weak combo.")
		_pop_text("BLOCKED", Vector2(540, 300), Color(0.85, 0.9, 1.0))
	if result < 0:
		result = 0
	return result

func _apply_enemy_rules_to_gold(value: int) -> int:
	var result := value
	if current_enemy_type == EnemyType.TAX_COLLECTOR and turn_last_pocket != Pocket.PocketType.CRIT:
		var stolen := int(round(result * 0.45))
		result = max(result - stolen, 0)
		_show_message("Tax Collector stole %d gold. Hit CRIT pocket to dodge tax." % stolen)
		_pop_text("-%d GOLD TAX" % stolen, Vector2(540, 340), Color(1.0, 0.6, 0.6))
	return result

func _apply_enemy_shield(value: int) -> int:
	if enemy_shield <= 0:
		return value
	var absorbed: int = mini(value, enemy_shield)
	enemy_shield -= absorbed
	if absorbed > 0:
		_pop_text("SHIELD -%d" % absorbed, Vector2(540, 260), Color(1.0, 0.75, 0.5))
	return max(value - absorbed, 0)

func _resolve_peg_eater() -> void:
	if current_enemy_type != EnemyType.PEG_EATER:
		return
	if turn_hit_pegs.is_empty():
		return
	var to_remove: int = mini(2, turn_hit_pegs.size())
	var subset: Array[Peg] = []
	for peg in turn_hit_pegs.slice(0, to_remove):
		subset.append(peg as Peg)
	var removed := board.remove_pegs(subset)
	if removed > 0:
		_pop_text("PEG EATER -%d PEGS" % removed, Vector2(540, 380), Color(1.0, 0.65, 0.65))

func _resolve_mega_turn(dealt_damage: int) -> void:
	var threshold := MEGA_TURN_BASE + (encounter_idx * 14)
	if dealt_damage >= threshold:
		mega_turn_streak += 1
		var bonus := int(round((dealt_damage - threshold) * 0.25)) + 8 * mega_turn_streak
		gold += max(bonus, 8)
		_pop_text("MEGA TURN x%d  +%d GOLD" % [mega_turn_streak, max(bonus, 8)], Vector2(540, 220), Color(1.0, 0.9, 0.35))
		_show_message("Mega turn! Keep the streak alive.")
		_shake(12.0)
	else:
		mega_turn_streak = 0

func _on_enemy_defeated() -> void:
	in_combat = false
	_set_controls_enabled(false)

	if current_node_type == NodeType.BOSS:
		_show_message("Boss down! Act %d cleared." % act_idx)
		_complete_boss_node()
		return

	var bounty := 10 + encounter_idx * 3
	gold += bounty
	pending_complete_after_upgrade = true
	_show_message("Enemy down! +%d bounty. Pick an upgrade." % bounty)
	_offer_upgrades()
	_update_hud()

func _enemy_attack() -> void:
	var damage := 8 + int(round(encounter_idx * 2.6))
	if current_node_type == NodeType.BOSS:
		damage += 8
	player_hp -= damage
	if player_hp <= 0:
		player_hp = 0
		_award_meta_shards(maxi(3, encounter_idx + act_idx * 2))
		_show_message("You were defeated. New run...")
		await get_tree().create_timer(1.1).timeout
		_start_new_run()
	else:
		_show_message("Enemy hits you for %d" % damage)
		_shake(8.0)

func _offer_upgrades() -> void:
	var pool := _upgrade_pool_ids()
	pool.shuffle()
	var picks: Array[String] = []
	for id in pool.slice(0, 3):
		picks.append(id as String)
	_show_choice("upgrade", "Choose One Upgrade", "Stack power and chase bigger numbers.", picks)

func _start_node(node_type: int) -> void:
	current_node_type = node_type
	awaiting_resolve = false
	ammo = starting_ammo
	enemy_shield = 0

	if node_type == NodeType.FIGHT or node_type == NodeType.BOSS:
		in_combat = true
		_set_controls_enabled(true)
		current_enemy_type = _pick_enemy_for_node(node_type)
		current_board_kind = _pick_board_for_node(node_type)
		board.build_layout(current_board_kind)
		_apply_board_theme()
		enemy_hp = _enemy_hp_for_encounter(node_type)
		_show_message("%s on %s board." % [_enemy_name(current_enemy_type), current_board_kind.capitalize()])
		_update_hud()
		return

	in_combat = false
	_set_controls_enabled(false)
	if node_type == NodeType.EVENT:
		_offer_event()
	elif node_type == NodeType.SHOP:
		_offer_shop()

func _offer_next_room_choices() -> void:
	var picks: Array[String] = []
	var pool := ["fight", "fight", "event", "shop", "fight", "event"]
	pool.shuffle()
	for i in 3:
		picks.append(pool[i])
	_show_choice("next_room", "Choose Next Room", "Act %d - Room %d/6" % [act_idx, node_idx_in_act], picks)

func _offer_event() -> void:
	var ids := ["event_prune", "event_curse", "event_trade"]
	_show_choice("event", "Event Room", "Take a risk for a big spike.", ids)

func _offer_shop() -> void:
	var ids := ["shop_damage", "shop_multiplier", "shop_refund"]
	_show_choice("shop", "Shop Room", "Spend gold for permanent scaling.", ids)

func _complete_regular_node() -> void:
	encounter_idx += 1
	if node_idx_in_act >= 6:
		node_idx_in_act = 7
		_start_node(NodeType.BOSS)
		return
	node_idx_in_act += 1
	_offer_next_room_choices()

func _complete_boss_node() -> void:
	encounter_idx += 1
	_award_meta_shards(8 + act_idx * 4)
	if act_idx >= 3:
		_show_choice("victory", "Run Complete", "You conquered the Pin King. Start a new run?", ["new_run", "new_run", "new_run"])
		return
	act_idx += 1
	node_idx_in_act = 1
	_show_message("Act %d begins. Choose your first room." % act_idx)
	_offer_next_room_choices()

func _reset_turn() -> void:
	turn_damage = 0
	turn_gold = 0
	turn_multiplier = 1.0
	turn_combo = 0
	combo_tier = 0
	turn_last_pocket = -1
	turn_hit_pegs.clear()
	split_triggered_peg_ids.clear()
	extra_balls_spawned_this_turn = 0
	balls_in_play = 0
	_update_combo_ui()

func _update_hud(status: String = "") -> void:
	var enemy_text := "%d" % enemy_hp
	if in_combat and enemy_shield > 0:
		enemy_text = "%d (+%d)" % [enemy_hp, enemy_shield]
	stats_label.text = "HP %d   Enemy %s   Gold %d   Ammo %d   Balls %d   Shards %d" % [player_hp, enemy_text, gold, ammo, balls_in_play, meta_shards]
	turn_label.text = "Act %d R%d  DMG %d x%.2f  | D%.1f G%.1f M+%.2f" % [act_idx, node_idx_in_act, turn_damage, turn_multiplier, damage_peg_power, gold_peg_value, multiplier_peg_gain]
	if status != "":
		message_label.text = status

func _show_message(text: String) -> void:
	message_label.text = text

func _ensure_input_actions() -> void:
	_add_action_if_missing("aim_left", [KEY_A, KEY_LEFT])
	_add_action_if_missing("aim_right", [KEY_D, KEY_RIGHT])
	_add_action_if_missing("drop_ball", [KEY_SPACE, KEY_ENTER])

func _add_action_if_missing(action_name: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if InputMap.action_get_events(action_name).is_empty():
		for key in keys:
			var event := InputEventKey.new()
			event.keycode = key
			InputMap.action_add_event(action_name, event)

func _build_choice_ui() -> void:
	var root := $HUD/Root as Control
	choice_panel = PanelContainer.new()
	choice_panel.name = "ChoicePanel"
	choice_panel.visible = false
	choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_panel.offset_left = 24.0
	choice_panel.offset_right = -24.0
	choice_panel.offset_top = 340.0
	choice_panel.offset_bottom = -300.0
	root.add_child(choice_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	choice_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	choice_title_label = Label.new()
	choice_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_title_label.add_theme_font_size_override("font_size", 34)
	vbox.add_child(choice_title_label)

	choice_subtitle_label = Label.new()
	choice_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_subtitle_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(choice_subtitle_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 180)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.clip_text = true
		btn.pressed.connect(_on_choice_pressed.bind(i))
		row.add_child(btn)
		choice_buttons.append(btn)

func _show_choice(context: String, title: String, subtitle: String, payload_ids: Array) -> void:
	awaiting_choice = true
	choice_context = context
	choice_payload.clear()
	choice_title_label.text = title
	choice_subtitle_label.text = subtitle
	_set_controls_enabled(false)

	for i in payload_ids.size():
		choice_payload.append(str(payload_ids[i]))

	for i in 3:
		if i < choice_payload.size():
			choice_buttons[i].visible = true
			choice_buttons[i].disabled = false
			choice_buttons[i].text = _choice_button_text(context, choice_payload[i])
		else:
			choice_buttons[i].visible = false

	choice_panel.visible = true

func _on_choice_pressed(index: int) -> void:
	if not awaiting_choice:
		return
	if index < 0 or index >= choice_payload.size():
		return

	var pick := choice_payload[index]
	choice_panel.visible = false
	awaiting_choice = false

	match choice_context:
		"meta":
			_resolve_meta_pick(pick)
		"loadout":
			_apply_loadout(pick)
			node_idx_in_act = 1
			_start_node(NodeType.FIGHT)
		"upgrade":
			_apply_upgrade(pick)
			_show_message("Picked: %s" % _upgrade_title(pick))
			if pending_complete_after_upgrade:
				pending_complete_after_upgrade = false
				_complete_regular_node()
		"next_room":
			_start_node(_node_id_to_enum(pick))
		"event":
			_resolve_event_pick(pick)
			_complete_regular_node()
		"shop":
			_resolve_shop_pick(pick)
			_complete_regular_node()
		"victory":
			_start_new_run()

	_update_hud()

func _set_controls_enabled(enabled: bool) -> void:
	left_button.disabled = not enabled
	drop_button.disabled = not enabled
	right_button.disabled = not enabled

func _enemy_hp_for_encounter(node_type: int) -> int:
	var base := 120.0 * pow(1.21, encounter_idx - 1)
	if node_type == NodeType.BOSS:
		base *= 2.3
	base += (act_idx - 1) * 45.0
	return int(round(base))

func _pick_enemy_for_node(node_type: int) -> int:
	if node_type == NodeType.BOSS:
		return EnemyType.PIN_KING
	var options := [EnemyType.SHIELD_SNAIL, EnemyType.TAX_COLLECTOR, EnemyType.PEG_EATER]
	return options[randi() % options.size()]

func _pick_board_for_node(node_type: int) -> String:
	if node_type == NodeType.BOSS:
		return "chaos"
	var options := ["classic", "risk", "combo"]
	return options[randi() % options.size()]

func _apply_board_theme() -> void:
	var tint := Color(0.05, 0.08, 0.13, 1.0)
	match current_board_kind:
		"classic":
			tint = Color(0.05, 0.08, 0.13, 1.0)
		"risk":
			tint = Color(0.11, 0.06, 0.10, 1.0)
		"combo":
			tint = Color(0.05, 0.10, 0.12, 1.0)
		"chaos":
			tint = Color(0.10, 0.05, 0.14, 1.0)
	var act_boost := 0.03 * float(act_idx - 1)
	backdrop.color = Color(
		clampf(tint.r + act_boost, 0.0, 1.0),
		clampf(tint.g + act_boost * 0.5, 0.0, 1.0),
		clampf(tint.b + act_boost, 0.0, 1.0),
		1.0
	)

func _enemy_name(enemy_type: int) -> String:
	match enemy_type:
		EnemyType.SHIELD_SNAIL:
			return "Shield Snail"
		EnemyType.TAX_COLLECTOR:
			return "Tax Collector"
		EnemyType.PEG_EATER:
			return "Peg Eater"
		EnemyType.PIN_KING:
			return "Pin King"
		_:
			return "Unknown"

func _node_id_to_enum(node_id: String) -> int:
	match node_id:
		"fight":
			return NodeType.FIGHT
		"event":
			return NodeType.EVENT
		"shop":
			return NodeType.SHOP
		_:
			return NodeType.FIGHT

func _choice_button_text(context: String, pick: String) -> String:
	match context:
		"meta":
			return "%s\n%s" % [_meta_title(pick), _meta_desc(pick)]
		"loadout":
			return "%s\n%s" % [_loadout_title(pick), _loadout_desc(pick)]
		"upgrade":
			return "%s\n%s" % [_upgrade_title(pick), _upgrade_desc(pick)]
		"next_room":
			return "%s\n%s" % [_room_title(pick), _room_desc(pick)]
		"event":
			return "%s\n%s" % [_event_title(pick), _event_desc(pick)]
		"shop":
			return "%s\n%s" % [_shop_title(pick), _shop_desc(pick)]
		"victory":
			return "New Run\nRestart from Act 1."
		_:
			return pick

func _meta_title(meta_id: String) -> String:
	match meta_id:
		"meta_hp":
			return "Vitality Shrine"
		"meta_split":
			return "Split Resonance"
		"meta_continue":
			return "Start Run"
		_:
			return "Meta"

func _meta_desc(meta_id: String) -> String:
	match meta_id:
		"meta_hp":
			var cost_hp := 5 + meta_hp_level * 3
			return "Cost %d shards. +12 start HP. Lv %d/8." % [cost_hp, meta_hp_level]
		"meta_split":
			var cost_split := 6 + meta_split_level * 4
			return "Cost %d shards. More split pegs. Lv %d/8." % [cost_split, meta_split_level]
		"meta_continue":
			return "Keep shards and choose loadout."
		_:
			return ""

func _loadout_title(loadout_id: String) -> String:
	match loadout_id:
		"split":
			return "Split Ball"
		"greed":
			return "Greed Ball"
		"vamp":
			return "Vamp Ball"
		_:
			return "Unknown"

func _loadout_desc(loadout_id: String) -> String:
	match loadout_id:
		"split":
			return "Every 3rd hit: burst + multiplier."
		"greed":
			return "+65% gold, -26% damage."
		"vamp":
			return "Heal 18% of damage dealt."
		_:
			return ""

func _apply_loadout(loadout_id: String) -> void:
	base_balls_per_drop = 1
	board.split_peg_chance_bonus = 0.0
	max_extra_balls_per_turn = 6
	match loadout_id:
		"split":
			selected_loadout = LoadoutType.SPLIT
			board.split_peg_chance_bonus = 0.10
			max_extra_balls_per_turn = 8
		"greed":
			selected_loadout = LoadoutType.GREED
		"vamp":
			selected_loadout = LoadoutType.VAMP
	_show_message("Loadout: %s" % _loadout_title(loadout_id))

func _upgrade_pool_ids() -> Array[String]:
	return [
		"sharpened_pins",
		"gold_rush",
		"turbo_multiplier",
		"combo_furnace",
		"critical_core",
		"cashout_engine",
		"refund_reactor",
		"double_load",
		"blood_bank",
		"twin_launcher",
		"split_forge",
		"legend_chain_reaction",
		"legend_portal_core",
		"legend_fractal_engine",
	]

func _upgrade_title(upgrade_id: String) -> String:
	match upgrade_id:
		"sharpened_pins":
			return "Sharpened Pins"
		"gold_rush":
			return "Gold Rush"
		"turbo_multiplier":
			return "Turbo Multiplier"
		"combo_furnace":
			return "Combo Furnace"
		"critical_core":
			return "Critical Core"
		"cashout_engine":
			return "Cashout Engine"
		"refund_reactor":
			return "Refund Reactor"
		"double_load":
			return "Double Load"
		"blood_bank":
			return "Blood Bank"
		"twin_launcher":
			return "Twin Launcher"
		"split_forge":
			return "Split Forge"
		"legend_chain_reaction":
			return "Legend: Chain Reaction"
		"legend_portal_core":
			return "Legend: Portal Core"
		"legend_fractal_engine":
			return "Legend: Fractal Engine"
		_:
			return "Mysterious Relic"

func _upgrade_desc(upgrade_id: String) -> String:
	match upgrade_id:
		"sharpened_pins":
			return "Damage pegs +35%."
		"gold_rush":
			return "Gold pegs +55%."
		"turbo_multiplier":
			return "Multiplier pegs +0.15."
		"combo_furnace":
			return "Combo scaling +0.9."
		"critical_core":
			return "Crit pocket +0.8."
		"cashout_engine":
			return "Cashout +8 per extra mult."
		"refund_reactor":
			return "Refund pocket +1 ammo."
		"double_load":
			return "+1 starting ammo."
		"blood_bank":
			return "+30 HP, damage pegs +15%."
		"twin_launcher":
			return "+1 ball each drop."
		"split_forge":
			return "More split pegs on boards."
		"legend_chain_reaction":
			return "Every peg hit also grants +1G and +0.05 mult."
		"legend_portal_core":
			return "Pocket hits can spawn bonus balls from the portal."
		"legend_fractal_engine":
			return "Split pegs spawn more balls and hit harder."
		_:
			return ""

func _apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"sharpened_pins":
			damage_peg_power *= 1.35
		"gold_rush":
			gold_peg_value *= 1.55
		"turbo_multiplier":
			multiplier_peg_gain += 0.15
		"combo_furnace":
			combo_bonus += 0.9
		"critical_core":
			crit_multiplier += 0.8
		"cashout_engine":
			cashout_rate += 8.0
		"refund_reactor":
			pocket_refund_bonus += 1
		"double_load":
			starting_ammo += 1
			ammo = max(ammo, starting_ammo)
		"blood_bank":
			player_hp += 30
			damage_peg_power *= 1.15
		"twin_launcher":
			base_balls_per_drop += 1
		"split_forge":
			board.split_peg_chance_bonus += 0.10
		"legend_chain_reaction":
			legendary_chain_reaction = true
		"legend_portal_core":
			legendary_portal_core = true
		"legend_fractal_engine":
			legendary_fractal_engine = true
			max_extra_balls_per_turn += 6
			damage_peg_power *= 1.25

func _room_title(room_id: String) -> String:
	match room_id:
		"fight":
			return "Fight"
		"event":
			return "Event"
		"shop":
			return "Shop"
		_:
			return "Room"

func _room_desc(room_id: String) -> String:
	match room_id:
		"fight":
			return "Battle for bounty + upgrade."
		"event":
			return "Risky choice, big swing."
		"shop":
			return "Spend gold on permanent boosts."
		_:
			return ""

func _event_title(event_id: String) -> String:
	match event_id:
		"event_prune":
			return "Ritual Prune"
		"event_curse":
			return "Cursed Surge"
		"event_trade":
			return "Pocket Altar"
		_:
			return "Event"

func _event_desc(event_id: String) -> String:
	match event_id:
		"event_prune":
			return "Remove 3 pegs, gain +2 damage."
		"event_curse":
			return "Lose 12 HP, gain +0.22 multiplier."
		"event_trade":
			return "Cashout +6 and combo +0.25."
		_:
			return ""

func _resolve_event_pick(event_id: String) -> void:
	match event_id:
		"event_prune":
			var removed := board.remove_pegs(board.get_random_pegs(3))
			damage_peg_power += 2.0
			_show_message("Pruned %d pegs. Damage power up." % removed)
		"event_curse":
			player_hp = max(1, player_hp - 12)
			multiplier_peg_gain += 0.22
			_show_message("Cursed surge: HP down, multiplier gain up.")
		"event_trade":
			cashout_rate += 6.0
			combo_bonus += 0.25
			_show_message("Pocket altar empowers your cashouts.")

func _shop_title(shop_id: String) -> String:
	match shop_id:
		"shop_damage":
			return "Iron Sharpening"
		"shop_multiplier":
			return "Prism Lens"
		"shop_refund":
			return "Ammo Flask"
		_:
			return "Shop"

func _shop_desc(shop_id: String) -> String:
	match shop_id:
		"shop_damage":
			return "40g: damage pegs +45%."
		"shop_multiplier":
			return "45g: multiplier pegs +0.20."
		"shop_refund":
			return "35g: +1 starting ammo."
		_:
			return ""

func _resolve_shop_pick(shop_id: String) -> void:
	var cost := 0
	match shop_id:
		"shop_damage":
			cost = 40
		"shop_multiplier":
			cost = 45
		"shop_refund":
			cost = 35
	if gold < cost:
		_show_message("Not enough gold. Left shop empty-handed.")
		return

	gold -= cost
	match shop_id:
		"shop_damage":
			damage_peg_power *= 1.45
			_show_message("Purchased Iron Sharpening.")
		"shop_multiplier":
			multiplier_peg_gain += 0.20
			_show_message("Purchased Prism Lens.")
		"shop_refund":
			starting_ammo += 1
			_show_message("Purchased Ammo Flask.")

func _resolve_meta_pick(pick: String) -> void:
	match pick:
		"meta_hp":
			var cost_hp := 5 + meta_hp_level * 3
			if meta_shards >= cost_hp and meta_hp_level < 8:
				meta_shards -= cost_hp
				meta_hp_level += 1
				_save_meta_progress()
				_show_message("Vitality unlocked.")
				_show_meta_choices()
			else:
				_show_message("Need more shards for Vitality.")
				_show_meta_choices()
		"meta_split":
			var cost_split := 6 + meta_split_level * 4
			if meta_shards >= cost_split and meta_split_level < 8:
				meta_shards -= cost_split
				meta_split_level += 1
				_save_meta_progress()
				_show_message("Split resonance unlocked.")
				_show_meta_choices()
			else:
				_show_message("Need more shards for Split resonance.")
				_show_meta_choices()
		"meta_continue":
			_show_loadout_choices()

func _award_meta_shards(amount: int) -> void:
	if amount <= 0:
		return
	meta_shards += amount
	_save_meta_progress()
	_show_message("Gained %d shards." % amount)

func _load_meta_progress() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://meta_save.cfg")
	if err != OK:
		meta_shards = 0
		meta_hp_level = 0
		meta_gold_level = 0
		meta_split_level = 0
		return
	meta_shards = int(cfg.get_value("meta", "shards", 0))
	meta_hp_level = int(cfg.get_value("meta", "hp_level", 0))
	meta_gold_level = int(cfg.get_value("meta", "gold_level", 0))
	meta_split_level = int(cfg.get_value("meta", "split_level", 0))

func _save_meta_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", meta_shards)
	cfg.set_value("meta", "hp_level", meta_hp_level)
	cfg.set_value("meta", "gold_level", meta_gold_level)
	cfg.set_value("meta", "split_level", meta_split_level)
	cfg.save("user://meta_save.cfg")

func _setup_combo_ui() -> void:
	combo_label = Label.new()
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_label.add_theme_font_size_override("font_size", 24)
	top_vbox.add_child(combo_label)
	_update_combo_ui()

func _update_combo_ui() -> void:
	if not combo_label:
		return
	var filled := mini(10, turn_combo)
	var meter := "".lpad(filled, "#") + "".lpad(10 - filled, "-")
	var tier_name := "CALM"
	var color := Color(0.78, 0.86, 1.0)
	match combo_tier:
		0:
			tier_name = "CALM"
			color = Color(0.78, 0.86, 1.0)
		1:
			tier_name = "HEAT"
			color = Color(0.95, 0.95, 0.7)
		2:
			tier_name = "RUSH"
			color = Color(1.0, 0.85, 0.55)
		3:
			tier_name = "FRENZY"
			color = Color(1.0, 0.72, 0.5)
		4:
			tier_name = "MAYHEM"
			color = Color(1.0, 0.6, 0.6)
		_:
			tier_name = "OVERDRIVE"
			color = Color(1.0, 0.56, 0.86)
	combo_label.text = "Combo %s  [%s]" % [tier_name, meter]
	combo_label.modulate = color

func _setup_combo_sfx() -> void:
	combo_sfx_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.1
	combo_sfx_player.stream = stream
	add_child(combo_sfx_player)
	combo_sfx_player.play()
	combo_sfx_playback = combo_sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _play_combo_tone(tier: int) -> void:
	if combo_sfx_playback == null:
		return
	var mix_rate := 44100.0
	var frames: int = int(0.045 * mix_rate)
	var freq := 360.0 + float(tier) * 90.0
	for i in frames:
		var t := float(i) / mix_rate
		var env := 1.0 - (float(i) / float(frames))
		var sample := sin(TAU * freq * t) * 0.18 * env
		combo_sfx_playback.push_frame(Vector2(sample, sample))

func _setup_camera() -> void:
	camera_2d = Camera2D.new()
	camera_2d.position = Vector2(540, 960)
	camera_2d.enabled = true
	add_child(camera_2d)

func _shake(strength: float) -> void:
	shake_strength = max(shake_strength, strength)

func _pop_text(text: String, world_pos: Vector2, color: Color, font_size: int = 24) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	label.position = world_pos + Vector2(-110, -20)
	$HUD/Root.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 65.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.finished.connect(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _spawn_impact_burst(world_pos: Vector2, color: Color, size_scale: float = 1.0) -> void:
	var burst := CPUParticles2D.new()
	burst.position = world_pos
	burst.amount = int(16.0 * size_scale)
	burst.lifetime = 0.24
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 8.0 * size_scale
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 120.0 * size_scale
	burst.initial_velocity_max = 240.0 * size_scale
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.modulate = color
	$Balls.add_child(burst)
	burst.emitting = true
	var timer := get_tree().create_timer(0.42)
	timer.timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)
