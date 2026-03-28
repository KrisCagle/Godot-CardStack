extends Node2D

@export var ball_scene: PackedScene
@export var force_mobile_controls: bool = false

@onready var board: Board = $Board
@onready var launcher: Launcher = $Launcher
@onready var balls: Node2D = $Balls
@onready var backdrop: ColorRect = $Backdrop
@onready var glass_overlay: ColorRect = $Overlay/Glass
@onready var turn_accumulator: TurnAccumulator = $TurnAccumulator

@onready var stats_label: Label = $HUD/Root/Top/VBox/Stats
@onready var turn_label: Label = $HUD/Root/Top/VBox/Turn
@onready var message_label: Label = $HUD/Root/CenterMessage
@onready var left_button: Button = $HUD/Root/Bottom/Controls/Left
@onready var drop_button: Button = $HUD/Root/Bottom/Controls/Drop
@onready var right_button: Button = $HUD/Root/Bottom/Controls/Right
@onready var bottom_controls: MarginContainer = $HUD/Root/Bottom
@onready var top_vbox: VBoxContainer = $HUD/Root/Top/VBox

const MEGA_TURN_BASE := 110
const LIGHTNING_TEXTURE_PATH := "res://assets/vfx/lightning.png"
const MOBILE_TOUCH_NONE := 0
const MOBILE_TOUCH_LEFT := 1
const MOBILE_TOUCH_DROP := 2
const MOBILE_TOUCH_RIGHT := 3
const COMBAT_LOG_MAX := 8
const META_SHOP_PAGES = [
	["start_gold", "start_hp"],
	["shop_discount", "split_resonance"],
	["start_ammo", "second_chance"],
	["box_bonus", "box_control"],
]
const UNLOCK_PAGES = [
	["loadout_box_hunter", "unlock_elite_boxes"],
	["unlock_curse_pegs", "unlock_portal_pocket"],
]

enum NodeType {
	FIGHT,
	ELITE,
	EVENT,
	SHOP,
	REST,
	TREASURE,
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
	BOX_HUNTER,
}

enum CharacterType {
	STRIKER,
	HUSTLER,
	GUARDIAN,
	SHOWMAN,
}

var player_hp := 100
var enemy_hp := 130
var player_run_state: Dictionary[String, float] = {
	"shield": 0.0,
}
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
var shield_label: Label
var shield_bar: ProgressBar

var damage_peg_power := 8.0
var gold_peg_value := 2.0
var shield_peg_value := 3.0
var multiplier_peg_gain := 0.20
var combo_bonus := 1.0
var crit_multiplier := 2.0
var cashout_rate := 10.0
var pocket_refund_bonus := 0
var base_balls_per_drop := 1
var max_extra_balls_per_turn := 6
var shop_discount := 0.0
var legendary_chain_reaction := false
var legendary_portal_core := false
var legendary_fractal_engine := false
var has_volatile_chain := false
var has_link_chain := false
var has_lightning_chain := false
var has_domino_chain := false
var chain_power_multiplier := 1.0
var chain_links: Dictionary = {}
var chain_lockouts: Dictionary = {}
var lightning_texture_cache: Texture2D = null
var combo_burst_every := 0
var character_shop_discount_bonus := 0.0
var character_ball_fill := Color(0.96, 0.97, 1.0)
var character_ball_rim := Color("94a3b8")
var character_trail_tint := Color(0.9, 0.95, 1.0)
var character_gold_cycle_hits := 0
var guardian_drop_triggered := false
var next_drop_combo_seed := 0
var player_damage_reduction := 0.0
var start_turn_multiplier_bonus := 0.0
var has_siphon_matrix := false
var has_coin_armor := false
var has_jackpot_guard := false
var has_split_peg_effect := false
var has_burst_peg_effect := false
var has_echo_peg_effect := false
var has_pinball_peg_effect := false
var has_orbit_peg_effect := false
var has_boom_peg_effect := false
var has_chain_peg_effect := false
var has_multi_plus_peg_effect := false
var has_cashout_peg_effect := false
var has_crit_peg_effect := false
var has_refund_peg_effect := false
var has_overdrive_peg_effect := false
var has_ghost_peg_effect := false
var has_magnet_peg_effect := false
var last_pocket_effect := -1

var selected_loadout := LoadoutType.SPLIT
var selected_character := CharacterType.STRIKER
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
var mobile_touch_controls_enabled := false
var active_aim_touch_id := -1
var active_aim_touch_start := Vector2.ZERO
var active_aim_touch_moved := false
var active_aim_mouse := false
var active_aim_mouse_start := Vector2.ZERO
var active_aim_mouse_moved := false
var held_left_touch_id := -1
var held_right_touch_id := -1

var choice_panel: PanelContainer
var choice_title_label: Label
var choice_subtitle_label: Label
var choice_buttons: Array[Button] = []
var choice_row: HBoxContainer
var choice_context := ""
var choice_payload: Array[String] = []
var skill_choice_ids: Array[String] = []

var combo_sfx_player: AudioStreamPlayer
var combo_sfx_playback: AudioStreamGeneratorPlayback
var pause_button: Button
var arcade_frame: Control
var audio_manager: AudioManager

var menu_overlay: ColorRect
var menu_panel: PanelContainer
var menu_title_label: Label
var menu_subtitle_label: Label
var menu_primary_button: Button
var menu_secondary_button: Button
var menu_tertiary_button: Button
var music_slider: HSlider
var sfx_slider: HSlider
var audio_label: Label
var music_row: HBoxContainer
var sfx_row: HBoxContainer
var menu_mode := ""
var options_help_text: RichTextLabel
var combat_log_panel: PanelContainer
var combat_log_text: RichTextLabel
var combat_log_entries: Array[String] = []
var title_layer: Control
var title_logo: TextureRect
var title_logo_fallback: Label
var title_glow: ColorRect
var title_prompt: Label
var title_options: Label
var title_help_preview: RichTextLabel
var title_fx_root: Node2D
var title_sparks: CPUParticles2D
var title_embers: CPUParticles2D
var title_anim_time := 0.0
var home_prompt_hover := false
var home_prompt_click_fx := 0.0
var home_options_hover := false
var overdrive_label: Label
var level_label: Label

var meta_shards := 0
var meta_hp_level := 0
var meta_gold_level := 0
var meta_split_level := 0
var player_level := 1
var player_xp := 0
var threat_meter := 0.0
var heat_meter := 0.0
var pocket_lock_type := -1
var encounter_tilt := 0.0
var difficulty_league := 1
var selected_league := 1
var pending_skill_points := 0
var league_reward_multiplier := 1.0
var box_shard_bonus_per_hit := 0
var box_speed_multiplier := 1.0
var run_revive_available := false
var run_revive_used := false
var unlock_curse_pegs_enabled := false
var unlock_portal_pocket_enabled := false
var meta_shop_page := 0
var unlocks_page := 0

var run_rooms_cleared: int = 0
var run_elites_cleared: int = 0
var run_bosses_killed: int = 0
var run_best_combo: int = 0
var run_gold_earned: int = 0
var run_shards_earned: int = 0
var run_xp_earned: int = 0
var run_boxes_hit: int = 0
var run_was_victory: bool = false
var upgrade_tag_counts: Dictionary[String, int] = {
	"combo": 0,
	"cashout": 0,
	"split": 0,
	"control": 0,
	"economy": 0,
}

func _special_ids() -> Array[int]:
	var base: Array[int] = []
	if has_split_peg_effect:
		base.append(Peg.SpecialEffect.SPLIT)
	if has_burst_peg_effect:
		base.append(Peg.SpecialEffect.BURST)
	if has_echo_peg_effect:
		base.append(Peg.SpecialEffect.ECHO)
	if has_pinball_peg_effect:
		base.append(Peg.SpecialEffect.PINBALL)
	if has_orbit_peg_effect:
		base.append(Peg.SpecialEffect.ORBIT)
	if has_boom_peg_effect:
		base.append(Peg.SpecialEffect.BOOM)
	if has_chain_peg_effect:
		base.append(Peg.SpecialEffect.CHAIN)
	if has_multi_plus_peg_effect:
		base.append(Peg.SpecialEffect.MULTI_PLUS)
	if has_cashout_peg_effect:
		base.append(Peg.SpecialEffect.CASHOUT)
	if has_crit_peg_effect:
		base.append(Peg.SpecialEffect.CRIT)
	if has_refund_peg_effect:
		base.append(Peg.SpecialEffect.REFUND)
	if has_overdrive_peg_effect:
		base.append(Peg.SpecialEffect.OVERDRIVE)
	if has_ghost_peg_effect:
		base.append(Peg.SpecialEffect.GHOST)
	if has_magnet_peg_effect:
		base.append(Peg.SpecialEffect.MAGNET)
	if base.is_empty():
		return []
	var pool: Array[int] = base.duplicate()
	match selected_character:
		CharacterType.STRIKER:
			pool.append_array([Peg.SpecialEffect.BURST, Peg.SpecialEffect.BOOM, Peg.SpecialEffect.CRIT])
		CharacterType.HUSTLER:
			pool.append_array([Peg.SpecialEffect.CASHOUT, Peg.SpecialEffect.REFUND, Peg.SpecialEffect.ECHO])
		CharacterType.GUARDIAN:
			pool.append_array([Peg.SpecialEffect.ORBIT, Peg.SpecialEffect.PINBALL, Peg.SpecialEffect.GHOST])
		CharacterType.SHOWMAN:
			pool.append_array([Peg.SpecialEffect.CHAIN, Peg.SpecialEffect.MULTI_PLUS, Peg.SpecialEffect.OVERDRIVE])
	return pool

func _special_count_for_node(node_type: int) -> int:
	var base := maxi(0, act_idx - 1)
	var count := base
	if node_type == NodeType.ELITE:
		count += 1
	elif node_type == NodeType.BOSS:
		count += 2
	return clampi(count, 0, 8)

func _ready() -> void:
	randomize()
	_configure_platform_scaling()
	_ensure_input_actions()
	_build_choice_ui()
	_build_arcade_frame()
	_build_menu_ui()
	_build_combat_log_ui()
	_configure_hud_layout()
	_setup_combo_ui()
	_setup_shield_ui()
	_setup_combo_sfx()
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	_sync_audio_sliders()
	_load_meta_progress()
	EventBus.target_box_hit.connect(_on_target_box_hit)
	if ball_scene == null:
		ball_scene = load("res://scenes/Ball.tscn") as PackedScene

	left_button.pressed.connect(func(): launcher.nudge(-1.0))
	right_button.pressed.connect(func(): launcher.nudge(1.0))
	drop_button.pressed.connect(_drop_ball)
	pause_button.pressed.connect(_toggle_pause_menu)
	_setup_mobile_controls()

	_show_home_menu()

func _input(event: InputEvent) -> void:
	if not mobile_touch_controls_enabled:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _handle_mobile_touch_event(event):
			get_viewport().set_input_as_handled()
			return
	# Some mobile browsers route taps as mouse events.
	if awaiting_choice and choice_panel and choice_panel.visible and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var idx: int = _choice_index_at_point(mb.position)
			if idx >= 0:
				_on_choice_pressed(idx)
				get_viewport().set_input_as_handled()

func _configure_platform_scaling() -> void:
	if OS.has_feature("mobile"):
		return
	var window := get_window()
	if window:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_size = Vector2i(1080, 1920)
	RenderingServer.set_default_clear_color(Color("050a17"))

func _unhandled_input(event: InputEvent) -> void:
	if menu_overlay and menu_overlay.visible and menu_mode == "home":
		if event.is_action_pressed("drop_ball") or event.is_action_pressed("ui_accept"):
			_trigger_home_start(true)
			return
		if event.is_action_pressed("pause_game"):
			_show_options_menu()
			return
		if event is InputEventMouseButton and event.pressed:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index != MOUSE_BUTTON_LEFT:
				return
			var over_options := _is_point_over_title_options(mouse_event.position)
			if over_options:
				_show_options_menu()
				return
			var over_prompt := _is_point_over_title_prompt(mouse_event.position)
			_trigger_home_start(over_prompt)
			return
		if event is InputEventScreenTouch and event.pressed:
			var touch_event := event as InputEventScreenTouch
			var over_options_touch := _is_point_over_title_options(touch_event.position)
			if over_options_touch:
				_show_options_menu()
				return
			var over_prompt_touch := _is_point_over_title_prompt(touch_event.position)
			_trigger_home_start(over_prompt_touch)
			return

	if event.is_action_pressed("pause_game"):
		_toggle_pause_menu()
		return

	if menu_overlay and menu_overlay.visible:
		return

	if awaiting_choice and choice_panel and choice_panel.visible:
		if event is InputEventMouseButton:
			var choice_mouse := event as InputEventMouseButton
			if choice_mouse.button_index == MOUSE_BUTTON_LEFT and choice_mouse.pressed:
				var mouse_choice_index: int = _choice_index_at_point(choice_mouse.position)
				if mouse_choice_index >= 0:
					_on_choice_pressed(mouse_choice_index)
		elif event is InputEventScreenTouch:
			var choice_touch := event as InputEventScreenTouch
			if choice_touch.pressed:
				var touch_choice_index: int = _choice_index_at_point(choice_touch.position)
				if touch_choice_index >= 0:
					_on_choice_pressed(touch_choice_index)
		return

	if not in_combat or awaiting_choice:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				active_aim_mouse = true
				active_aim_mouse_start = mb.position
				active_aim_mouse_moved = false
				if _is_point_in_board_zone(mb.position):
					launcher.set_target_x(mb.position.x)
			else:
				if active_aim_mouse:
					var start_is_board: bool = _is_point_in_board_zone(active_aim_mouse_start)
					var release_is_board: bool = _is_point_in_board_zone(mb.position)
					var over_controls: bool = _is_touch_in_controls_zone(mb.position)
					if not active_aim_mouse_moved and (start_is_board or release_is_board) and not over_controls:
						_drop_ball()
				active_aim_mouse = false
				active_aim_mouse_moved = false
			return

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if active_aim_mouse and event.position.distance_to(active_aim_mouse_start) > 14.0:
			active_aim_mouse_moved = true
		if _is_point_in_board_zone(event.position):
			launcher.set_target_x(event.position.x)

	if event.is_action_pressed("drop_ball"):
		_drop_ball()

func _handle_mobile_touch_event(event: InputEvent) -> bool:
	if menu_overlay and menu_overlay.visible:
		return false

	if awaiting_choice and choice_panel and choice_panel.visible:
		if event is InputEventScreenTouch:
			var choice_touch := event as InputEventScreenTouch
			if choice_touch.pressed:
				var choice_index: int = _choice_index_at_point(choice_touch.position)
				if choice_index >= 0:
					_on_choice_pressed(choice_index)
					return true
		return false

	if not in_combat or awaiting_choice:
		return false

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			if _is_touch_in_controls_zone(touch_event.position):
				_handle_mobile_touch_press(touch_event.position, touch_event.index)
				return true
			active_aim_touch_id = touch_event.index
			active_aim_touch_start = touch_event.position
			active_aim_touch_moved = false
			if _is_point_in_board_zone(touch_event.position):
				launcher.set_target_x(touch_event.position.x)
			return true

		if touch_event.index == active_aim_touch_id:
			var release_is_board: bool = _is_point_in_board_zone(touch_event.position)
			var start_is_board: bool = _is_point_in_board_zone(active_aim_touch_start)
			if not active_aim_touch_moved and (start_is_board or release_is_board):
				_drop_ball()
		_release_mobile_touch_hold(touch_event.index)
		if touch_event.index == active_aim_touch_id:
			active_aim_touch_id = -1
		return true

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == active_aim_touch_id:
			if drag_event.position.distance_to(active_aim_touch_start) > 14.0:
				active_aim_touch_moved = true
			if _is_point_in_board_zone(drag_event.position):
				launcher.set_target_x(drag_event.position.x)
		return true

	return false

func _choice_index_at_point(point: Vector2) -> int:
	for i in choice_buttons.size():
		var btn := choice_buttons[i]
		if btn == null:
			continue
		if not btn.visible or btn.disabled:
			continue
		if btn.get_global_rect().has_point(point):
			return i
	return -1

func _setup_mobile_controls() -> void:
	mobile_touch_controls_enabled = _should_show_touch_controls()
	if bottom_controls:
		bottom_controls.visible = false
	if mobile_touch_controls_enabled:
		# Thumb-friendly hit area sizing for phones/tablets.
		left_button.custom_minimum_size = Vector2(240, 140)
		drop_button.custom_minimum_size = Vector2(320, 140)
		right_button.custom_minimum_size = Vector2(240, 140)

func _should_show_touch_controls() -> bool:
	if force_mobile_controls or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return false

func _is_touch_in_controls_zone(point: Vector2) -> bool:
	if not mobile_touch_controls_enabled:
		return false
	if bottom_controls == null or not bottom_controls.visible:
		return false
	return bottom_controls.get_global_rect().has_point(point)

func _is_point_in_board_zone(point: Vector2) -> bool:
	if mobile_touch_controls_enabled and bottom_controls and bottom_controls.visible:
		var board_limit_y: float = bottom_controls.get_global_rect().position.y - 10.0
		return point.y < board_limit_y
	return point.y < (get_viewport_rect().size.y * 0.78)

func _handle_mobile_touch_press(point: Vector2, touch_id: int) -> void:
	var action: int = _mobile_touch_action(point)
	match action:
		MOBILE_TOUCH_LEFT:
			held_left_touch_id = touch_id
			launcher.nudge(-1.0)
		MOBILE_TOUCH_DROP:
			_drop_ball()
		MOBILE_TOUCH_RIGHT:
			held_right_touch_id = touch_id
			launcher.nudge(1.0)

func _mobile_touch_action(point: Vector2) -> int:
	if drop_button and drop_button.get_global_rect().has_point(point):
		return MOBILE_TOUCH_DROP
	if left_button and left_button.get_global_rect().has_point(point):
		return MOBILE_TOUCH_LEFT
	if right_button and right_button.get_global_rect().has_point(point):
		return MOBILE_TOUCH_RIGHT
	return MOBILE_TOUCH_NONE

func _release_mobile_touch_hold(touch_id: int) -> void:
	if touch_id == held_left_touch_id:
		held_left_touch_id = -1
	if touch_id == held_right_touch_id:
		held_right_touch_id = -1

func _physics_process(delta: float) -> void:
	if in_combat and not awaiting_choice:
		var axis := Input.get_axis("aim_left", "aim_right")
		if axis != 0.0:
			launcher.nudge(axis, 480.0 * delta)
		if mobile_touch_controls_enabled:
			if held_left_touch_id != -1 and held_right_touch_id == -1:
				launcher.nudge(-1.0, 520.0 * delta)
			elif held_right_touch_id != -1 and held_left_touch_id == -1:
				launcher.nudge(1.0, 520.0 * delta)

func _process(delta: float) -> void:
	if menu_mode != "home":
		home_prompt_hover = false
		home_options_hover = false
		return
	if menu_overlay == null or not menu_overlay.visible:
		home_prompt_hover = false
		home_options_hover = false
		return
	title_anim_time += delta
	home_prompt_click_fx = maxf(0.0, home_prompt_click_fx - delta)
	var mp := get_viewport().get_mouse_position()
	home_prompt_hover = _is_point_over_title_prompt(mp)
	home_options_hover = _is_point_over_title_options(mp)
	_animate_home_title()

func _is_point_over_title_prompt(point: Vector2) -> bool:
	if title_prompt == null or not title_prompt.visible:
		return false
	return title_prompt.get_global_rect().has_point(point)

func _is_point_over_title_options(point: Vector2) -> bool:
	if title_options == null or not title_options.visible:
		return false
	return title_options.get_global_rect().has_point(point)

func _trigger_home_start(from_prompt_click: bool) -> void:
	if from_prompt_click:
		home_prompt_click_fx = 0.22
		if audio_manager:
			audio_manager.play_menu_click()
	_start_new_run(true)

func _start_new_run(skip_sanctum: bool = false) -> void:
	get_tree().paused = false
	_hide_menu_overlay()
	_set_combat_log_visible(false)
	_clear_combat_log()

	var run_meta: Dictionary = MetaManager.apply_meta_to_run({
		"start_hp": 100,
		"start_gold": 0,
		"start_ammo": 1,
	})
	player_hp = int(run_meta.get("start_hp", 100))
	gold = int(run_meta.get("start_gold", 0))
	act_idx = 1
	node_idx_in_act = 1
	encounter_idx = 1
	mega_turn_streak = 0
	current_board_kind = "classic"
	threat_meter = 0.0
	heat_meter = 0.0
	pocket_lock_type = -1
	encounter_tilt = 0.0
	difficulty_league = int(run_meta.get("difficulty_league", 1))
	league_reward_multiplier = float(run_meta.get("league_reward_multiplier", 1.0))
	box_shard_bonus_per_hit = int(run_meta.get("box_shard_bonus", 0))
	box_speed_multiplier = float(run_meta.get("box_speed_multiplier", 1.0))
	run_revive_available = bool(run_meta.get("revive_available", false))
	run_revive_used = false
	var unlock_state: Dictionary = run_meta.get("unlocks", {}) as Dictionary
	unlock_curse_pegs_enabled = bool(unlock_state.get("unlock_curse_pegs", false))
	unlock_portal_pocket_enabled = bool(unlock_state.get("unlock_portal_pocket", false))
	meta_shop_page = 0
	unlocks_page = 0

	run_rooms_cleared = 0
	run_elites_cleared = 0
	run_bosses_killed = 0
	run_best_combo = 0
	run_gold_earned = 0
	run_shards_earned = 0
	run_xp_earned = 0
	run_boxes_hit = 0

	starting_ammo = int(run_meta.get("start_ammo", 1))
	ammo = starting_ammo
	damage_peg_power = 8.0
	gold_peg_value = 2.0
	shield_peg_value = 3.0
	multiplier_peg_gain = 0.20
	combo_bonus = 1.0
	crit_multiplier = 2.0
	cashout_rate = 10.0
	pocket_refund_bonus = 0
	shop_discount = float(run_meta.get("shop_discount", 0.0))
	character_shop_discount_bonus = 0.0
	character_gold_cycle_hits = 0
	guardian_drop_triggered = false
	next_drop_combo_seed = int(run_meta.get("start_combo_seed", 0))
	player_damage_reduction = 0.0
	start_turn_multiplier_bonus = 0.0
	has_siphon_matrix = false
	has_coin_armor = false
	has_jackpot_guard = false
	player_run_state["shield"] = 0.0
	selected_character = CharacterType.STRIKER
	character_ball_fill = Color(0.96, 0.97, 1.0)
	character_ball_rim = Color("94a3b8")
	character_trail_tint = Color(0.9, 0.95, 1.0)
	turn_combo = 0
	combo_tier = 0
	base_balls_per_drop = 1
	max_extra_balls_per_turn = 6
	legendary_chain_reaction = false
	legendary_portal_core = false
	legendary_fractal_engine = false
	has_volatile_chain = false
	has_link_chain = false
	has_lightning_chain = false
	has_domino_chain = false
	chain_power_multiplier = 1.0
	chain_links.clear()
	chain_lockouts.clear()
	balls_in_play = 0
	extra_balls_spawned_this_turn = 0
	split_triggered_peg_ids.clear()
	board.split_peg_chance_bonus = float(run_meta.get("split_bonus", 0.0))
	board.target_speed_multiplier = box_speed_multiplier
	board.enable_curse_mix = unlock_curse_pegs_enabled
	for key in upgrade_tag_counts.keys():
		upgrade_tag_counts[key] = 0
	_apply_board_theme()
	_update_combo_ui()
	_update_shield_ui()
	EventBus.combo_changed.emit(0.0)

	awaiting_choice = false
	in_combat = false
	pending_complete_after_upgrade = false
	_set_controls_enabled(false)
	if skip_sanctum:
		_show_starter_build_choices()
		_update_hud("")
	else:
		_show_meta_choices()
		_update_hud("Spend shards or continue to your starter build.")

func _show_loadout_choices() -> void:
	var ids: Array[String] = MetaManager.loadouts_unlocked.duplicate()
	if ids.is_empty():
		ids = ["split", "greed", "vamp"]
	_show_choice("loadout", "Pick Your Loadout", "Each changes your run style.", ids)

func _show_character_choices() -> void:
	var ids: Array[String] = ["striker", "hustler", "guardian", "showman"]
	_show_choice("character", "Pick Your Driver", "Choose your ball style and passive.", ids)

func _show_starter_build_choices() -> void:
	var ids: Array[String] = [
		"striker_split",
		"hustler_greed",
		"guardian_vamp",
		"showman_box_hunter",
	]
	_show_choice("starter_build", "Pick your build.", "Driver + loadout fused into one start choice.", ids)

func _show_meta_choices() -> void:
	var ids := ["meta_hp", "meta_split", "meta_continue"]
	var subtitle := "Shards %d  |  Lv %d  |  HP Lv%d  Gold Lv%d  Split Lv%d" % [meta_shards, player_level, meta_hp_level, meta_gold_level, meta_split_level]
	_show_choice("meta", "Sanctum Upgrades", subtitle, ids)

func _drop_ball() -> void:
	if not in_combat or awaiting_resolve or awaiting_choice or ammo <= 0:
		return
	if ball_scene == null:
		_show_message("Ball scene missing. Reassign Main.ball_scene to res://scenes/Ball.tscn")
		return

	ammo -= 1
	if audio_manager:
		audio_manager.play_drop()
	awaiting_resolve = true
	_reset_turn()
	if start_turn_multiplier_bonus > 0.0:
		turn_multiplier += start_turn_multiplier_bonus
	if next_drop_combo_seed > 0:
		turn_combo = max(turn_combo, next_drop_combo_seed)
		next_drop_combo_seed = 0
		combo_tier = mini(5, int(turn_combo / 4))
		_update_combo_ui()
	guardian_drop_triggered = false
	EventBus.drop_started.emit()
	_log_combat_event("Drop cast: %d ball(s)." % maxi(1, base_balls_per_drop), Color(0.82, 0.92, 1.0))
	var start_count: int = maxi(1, base_balls_per_drop)
	for i in start_count:
		var spread_x := 0.0
		if start_count > 1:
			spread_x = lerpf(-120.0, 120.0, float(i) / float(start_count - 1))
		_spawn_ball(
			launcher.global_position + Vector2(0, 70),
			Vector2(spread_x + randf_range(-35.0, 35.0) + encounter_tilt * 120.0, 120.0)
		)

	_show_message("Ball in play... (%d)" % balls_in_play)
	_update_hud()

func _spawn_ball(spawn_pos: Vector2, velocity: Vector2) -> void:
	var ball := ball_scene.instantiate() as Ball
	ball.global_position = spawn_pos
	ball.linear_velocity = velocity
	ball.peg_hit.connect(_on_ball_peg_hit)
	ball.pocket_entered.connect(_on_ball_pocket_entered)
	ball.hazard_hit.connect(_on_ball_hazard_hit)
	ball.settled.connect(_on_ball_settled)
	balls.call_deferred("add_child", ball)
	call_deferred("_finalize_spawn_ball_theme", ball)
	active_ball = ball
	balls_in_play += 1

func _finalize_spawn_ball_theme(ball: Ball) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if not ball.is_inside_tree():
		call_deferred("_finalize_spawn_ball_theme", ball)
		return
	ball.apply_visual_theme(character_ball_fill, character_ball_rim, character_trail_tint)

func _on_ball_hazard_hit(damage: int, hazard_label: String, world_pos: Vector2) -> void:
	if not in_combat:
		return
	_apply_player_damage(maxi(1, damage), "%s hazard" % hazard_label, world_pos)

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
	if audio_manager:
		audio_manager.play_peg_hit(int(peg.peg_type))
	turn_combo += 1
	run_best_combo = maxi(run_best_combo, turn_combo)
	var old_tier := combo_tier
	combo_tier = mini(5, int(turn_combo / 4))
	if not turn_hit_pegs.has(peg):
		turn_hit_pegs.append(peg)

	if combo_burst_every > 0 and turn_combo % combo_burst_every == 0:
		_spawn_multiball_from_peg(peg.global_position)
		_pop_text("COMBO BURST!", peg.global_position + Vector2(0, -26), Color(0.78, 1.0, 0.98), 20)
		_shake(7.0)

	match peg.peg_type:
		Peg.PegType.DAMAGE:
			var added_damage := int(round(damage_peg_power + (turn_combo * combo_bonus)))
			if selected_character == CharacterType.STRIKER:
				added_damage = int(round(float(added_damage) * 1.05))
			turn_damage += added_damage
		Peg.PegType.GOLD:
			var added_gold := int(round(gold_peg_value))
			turn_gold += added_gold
			if selected_character == CharacterType.HUSTLER:
				character_gold_cycle_hits += 1
				if character_gold_cycle_hits % 3 == 0:
					turn_gold += 1
					_pop_text("+1 BONUS", peg.global_position + Vector2(0, -24), Color(1.0, 0.88, 0.35), 20)
			if has_coin_armor:
				_add_player_shield(1.0)
				_pop_text("+1 BLOCK", peg.global_position + Vector2(0, -42), Color(0.64, 0.92, 1.0), 18)
			if selected_character == CharacterType.GUARDIAN and not guardian_drop_triggered:
				guardian_drop_triggered = true
				player_hp += 1
				_pop_text("+1 GUARD", peg.global_position + Vector2(0, -40), Color(0.60, 0.94, 1.0), 20)
		Peg.PegType.SHIELD:
			var added_shield := int(round(shield_peg_value * (1.0 + float(peg.tier) * 0.24)))
			_add_player_shield(float(added_shield))
			_pop_text("+%d BLOCK" % added_shield, peg.global_position, Color(0.64, 0.92, 1.0), 22)
		Peg.PegType.MULTIPLIER:
			turn_multiplier += multiplier_peg_gain
			if selected_character == CharacterType.SHOWMAN:
				turn_multiplier += 0.05
			if current_enemy_type == EnemyType.PIN_KING:
				threat_meter = minf(10.0, threat_meter + 0.08)
				_pop_text("KING RAGE +THREAT", peg.global_position, Color(1.0, 0.65, 0.35))
	if peg.tier >= 3 and audio_manager and randf() < 0.22:
		audio_manager.play_tier_shimmer()
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

	_apply_special_peg_effect(peg)

	if selected_loadout == LoadoutType.SPLIT and turn_combo % 3 == 0:
		var burst := int(round(damage_peg_power * 0.9))
		turn_damage += burst
		turn_multiplier += 0.10
		_pop_text("SPLIT +%d" % burst, peg.global_position, Color(0.75, 0.95, 1.0))
		_shake(6.0)

	if combo_tier > old_tier:
		heat_meter = minf(1.0, heat_meter + 0.04 + float(combo_tier) * 0.01)
		_play_combo_tone(combo_tier)
		_pop_text("TIER %d" % combo_tier, peg.global_position + Vector2(0, -34), Color(1.0, 0.9, 0.55), 24)

	_try_chain_reactions(peg)

	EventBus.combo_changed.emit(clampf(float(turn_combo) / 20.0, 0.0, 1.0))
	_update_combo_ui()
	_update_hud()

func _apply_special_peg_effect(peg: Peg) -> void:
	if peg == null:
		return
	match peg.special_effect:
		Peg.SpecialEffect.SPLIT:
			if not has_split_peg_effect:
				return
			_spawn_multiball_from_peg(peg.global_position)
			_pop_text("SPLIT!", peg.global_position + Vector2(0, -20), Color(0.85, 0.95, 1.0), 18)
			_shake(5.0)
		Peg.SpecialEffect.BURST:
			if not has_burst_peg_effect:
				return
			_spawn_ball(peg.global_position + Vector2(-10, -8), Vector2(-180, 140))
			_spawn_ball(peg.global_position + Vector2(10, -8), Vector2(180, 140))
			_pop_text("BURST", peg.global_position + Vector2(0, -18), Color(1.0, 0.82, 0.5), 18)
		Peg.SpecialEffect.ECHO:
			if not has_echo_peg_effect:
				return
			if last_pocket_effect >= 0:
				_apply_pocket_echo(last_pocket_effect, 0.4)
				_pop_text("ECHO", peg.global_position + Vector2(0, -18), Color(0.85, 0.9, 1.0), 18)
		Peg.SpecialEffect.PINBALL:
			if not has_pinball_peg_effect:
				return
			turn_multiplier += 0.12
			_pop_text("BOUNCE+", peg.global_position + Vector2(0, -18), Color(0.9, 1.0, 0.75), 18)
		Peg.SpecialEffect.ORBIT:
			if not has_orbit_peg_effect:
				return
			turn_multiplier += 0.08
			turn_damage += int(round(damage_peg_power * 0.35))
			_pop_text("ORBIT", peg.global_position + Vector2(0, -18), Color(0.9, 0.8, 1.0), 18)
		Peg.SpecialEffect.BOOM:
			if not has_boom_peg_effect:
				return
			var boom_targets: Array[Peg] = _find_nearby_pegs(peg, 3, 200.0)
			for target in boom_targets:
				_apply_chain_hit(target, 0.6, "BOOM", Color(1.0, 0.62, 0.28))
			_spawn_impact_burst(peg.global_position, Color(1.0, 0.58, 0.2, 0.65), 1.3)
		Peg.SpecialEffect.CHAIN:
			if not has_chain_peg_effect:
				return
			var chain_target := _closest_peg_excluding(peg, 240.0)
			if chain_target:
				_apply_chain_hit(chain_target, 0.66, "CHAIN", Color(0.76, 0.92, 1.0))
				_spawn_link_beam(peg.global_position, chain_target.global_position, Color(0.76, 0.92, 1.0, 0.95))
		Peg.SpecialEffect.MULTI_PLUS:
			if not has_multi_plus_peg_effect:
				return
			turn_multiplier += 0.35
			_pop_text("M+", peg.global_position + Vector2(0, -18), Color(0.9, 0.85, 1.0), 18)
		Peg.SpecialEffect.CASHOUT:
			if not has_cashout_peg_effect:
				return
			turn_gold += int(round(gold_peg_value * 2.0))
			_pop_text("$+", peg.global_position + Vector2(0, -18), Color(1.0, 0.9, 0.4), 18)
		Peg.SpecialEffect.CRIT:
			if not has_crit_peg_effect:
				return
			turn_multiplier += 0.5
			_pop_text("CRIT+", peg.global_position + Vector2(0, -18), Color(1.0, 0.7, 0.9), 18)
		Peg.SpecialEffect.REFUND:
			if not has_refund_peg_effect:
				return
			ammo += 1
			_pop_text("+BALL", peg.global_position + Vector2(0, -18), Color(0.7, 1.0, 0.7), 18)
		Peg.SpecialEffect.OVERDRIVE:
			if not has_overdrive_peg_effect:
				return
			turn_multiplier += 0.2
			heat_meter = minf(1.0, heat_meter + 0.08)
			_pop_text("OD", peg.global_position + Vector2(0, -18), Color(1.0, 0.65, 0.45), 18)
		Peg.SpecialEffect.GHOST:
			if not has_ghost_peg_effect:
				return
			turn_multiplier += 0.12
			_pop_text("GHOST", peg.global_position + Vector2(0, -18), Color(0.85, 0.95, 1.0), 18)
		Peg.SpecialEffect.MAGNET:
			if not has_magnet_peg_effect:
				return
			turn_multiplier += 0.14
			_pop_text("MAG", peg.global_position + Vector2(0, -18), Color(0.8, 1.0, 0.9), 18)
		_:
			pass

func _on_ball_pocket_entered(pocket: Pocket) -> void:
	if audio_manager:
		audio_manager.play_pocket_land()
	pocket.trigger_celebration()
	if pocket_lock_type >= 0 and int(pocket.pocket_type) == pocket_lock_type:
		_show_message("Pocket locked! Find another lane.")
		_pop_text("LOCKED", pocket.global_position, Color(1.0, 0.45, 0.45), 28)
		turn_accumulator.pocket_landed(int(pocket.pocket_type), pocket.global_position)
		return
	turn_last_pocket = pocket.pocket_type
	if has_siphon_matrix:
		player_hp += 1
		_pop_text("+1 HP", pocket.global_position + Vector2(0, -34), Color(0.70, 1.0, 0.78), 20)
	match pocket.pocket_type:
		Pocket.PocketType.REFUND:
			var refund := 1 + pocket_refund_bonus
			ammo += refund
			_show_message("Refund! +%d balls" % refund)
			_pop_text("+%d BALL" % refund, pocket.global_position, Color(0.7, 1.0, 0.7), 30)
		Pocket.PocketType.CRIT:
			turn_multiplier *= crit_multiplier
			_show_message("Crit pocket! x%.1f" % crit_multiplier)
			_pop_text("CRIT x%.1f" % crit_multiplier, pocket.global_position, Color(1.0, 0.7, 0.9), 32)
		Pocket.PocketType.CASHOUT:
			var bonus_gold := int(round((turn_multiplier - 1.0) * cashout_rate))
			turn_gold += max(bonus_gold, 0)
			if has_jackpot_guard:
				var guard_gain: int = maxi(1, int(round((turn_multiplier - 1.0) * 2.0)))
				_add_player_shield(float(guard_gain))
				_pop_text("+%d BLOCK" % guard_gain, pocket.global_position + Vector2(0, -34), Color(0.66, 0.92, 1.0), 20)
			_show_message("Cashout bonus!")
			_pop_text("+%d GOLD" % max(bonus_gold, 0), pocket.global_position, Color(1.0, 0.9, 0.4), 30)
	last_pocket_effect = int(pocket.pocket_type)
	turn_accumulator.pocket_landed(int(pocket.pocket_type), pocket.global_position)
	var portal_chance := 0.0
	if legendary_portal_core:
		portal_chance = 0.45
	elif unlock_portal_pocket_enabled and pocket.pocket_type == Pocket.PocketType.CASHOUT:
		portal_chance = 0.20
	if portal_chance > 0.0 and extra_balls_spawned_this_turn < max_extra_balls_per_turn and randf() < portal_chance:
		_spawn_ball(Vector2(launcher.global_position.x, 230.0), Vector2(randf_range(-140.0, 140.0), 80.0))
		extra_balls_spawned_this_turn += 1
		_pop_text("PORTAL BALL!", pocket.global_position + Vector2(0, -30), Color(0.9, 0.7, 1.0), 24)

func _on_target_box_hit(reward_type: int, amount: float, world_pos: Vector2) -> void:
	if not in_combat:
		return
	run_boxes_hit += 1
	if audio_manager:
		audio_manager.play_target_box_hit()
	var int_amount: int = int(round(amount))
	match reward_type:
		MovingBoxTarget.RewardType.GOLD:
			turn_gold += int_amount
			_pop_text("+%d GOLD BOX" % int_amount, world_pos, Color(1.0, 0.88, 0.35), 24)
		MovingBoxTarget.RewardType.DAMAGE:
			turn_damage += int_amount
			_pop_text("+%d DMG BOX" % int_amount, world_pos, Color(1.0, 0.55, 0.75), 24)
		MovingBoxTarget.RewardType.AMMO:
			var ammo_gain: int = maxi(1, int(ceil(float(int_amount) / 5.0)))
			ammo += ammo_gain
			_pop_text("+%d BALL" % ammo_gain, world_pos, Color(0.70, 1.0, 0.78), 24)
		MovingBoxTarget.RewardType.MULTIPLIER:
			var mult_gain := amount * 0.04
			turn_multiplier += mult_gain
			_pop_text("+x%.2f" % mult_gain, world_pos, Color(0.86, 0.74, 1.0), 24)
		MovingBoxTarget.RewardType.JACKPOT:
			turn_damage = int(round(float(turn_damage) * 1.7))
			turn_gold = int(round(float(turn_gold) * 1.7))
			turn_multiplier += 0.40
			_pop_text("JACKPOT x1.7", world_pos, Color(1.0, 0.68, 0.28), 30)
		MovingBoxTarget.RewardType.COMBO_LOCK:
			next_drop_combo_seed = maxi(next_drop_combo_seed, int(maxf(8.0, amount)))
			_pop_text("NEXT DROP: HEAT", world_pos, Color(0.66, 0.84, 1.0), 24)
		MovingBoxTarget.RewardType.POCKET_CHARGE:
			var roll: int = randi() % 3
			if roll == 0:
				pocket_refund_bonus += 1
				_pop_text("REFUND+1", world_pos, Color(0.68, 1.0, 0.72), 22)
			elif roll == 1:
				crit_multiplier += 0.15
				_pop_text("CRIT+0.15", world_pos, Color(1.0, 0.70, 0.86), 22)
			else:
				cashout_rate += 2.5
				_pop_text("CASHOUT+2.5", world_pos, Color(1.0, 0.87, 0.45), 22)
		MovingBoxTarget.RewardType.SHARD_BURST:
			var shard_gain: int = maxi(1, int_amount + box_shard_bonus_per_hit)
			_award_meta_shards(shard_gain)
			_pop_text("+%d SHARD" % shard_gain, world_pos, Color(0.72, 0.95, 1.0), 24)
	var reward_log := _target_box_log_text(reward_type, int_amount, amount)
	if reward_log != "":
		_log_combat_event("Target Box: %s" % reward_log, _target_box_log_color(reward_type))
	if box_shard_bonus_per_hit > 0:
		_award_meta_shards(box_shard_bonus_per_hit)
		_pop_text("+%d SHARD" % box_shard_bonus_per_hit, world_pos + Vector2(0, -28), Color(0.72, 0.95, 1.0), 20)
	_update_hud()
	_shake(7.0)

func _target_box_log_text(reward_type: int, int_amount: int, amount: float) -> String:
	match reward_type:
		MovingBoxTarget.RewardType.GOLD:
			return "+%d gold" % int_amount
		MovingBoxTarget.RewardType.DAMAGE:
			return "+%d damage" % int_amount
		MovingBoxTarget.RewardType.AMMO:
			return "+%d balls" % maxi(1, int(ceil(float(int_amount) / 5.0)))
		MovingBoxTarget.RewardType.MULTIPLIER:
			return "+x%.2f mult" % (amount * 0.04)
		MovingBoxTarget.RewardType.JACKPOT:
			return "JACKPOT x1.7"
		MovingBoxTarget.RewardType.COMBO_LOCK:
			return "combo seed saved"
		MovingBoxTarget.RewardType.POCKET_CHARGE:
			return "pocket upgraded"
		MovingBoxTarget.RewardType.SHARD_BURST:
			return "+%d shards" % maxi(1, int_amount + box_shard_bonus_per_hit)
		_:
			return ""

func _target_box_log_color(reward_type: int) -> Color:
	match reward_type:
		MovingBoxTarget.RewardType.GOLD:
			return Color(1.0, 0.88, 0.35)
		MovingBoxTarget.RewardType.DAMAGE:
			return Color(1.0, 0.55, 0.75)
		MovingBoxTarget.RewardType.AMMO:
			return Color(0.70, 1.0, 0.78)
		MovingBoxTarget.RewardType.MULTIPLIER:
			return Color(0.86, 0.74, 1.0)
		MovingBoxTarget.RewardType.JACKPOT:
			return Color(1.0, 0.68, 0.28)
		MovingBoxTarget.RewardType.SHARD_BURST:
			return Color(0.72, 0.95, 1.0)
		_:
			return Color(0.88, 0.94, 1.0)

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

	enemy_hp -= dealt_damage
	gold += gained_gold
	if gained_gold > 0:
		run_gold_earned += gained_gold
	var chain_pct: int = int(round((1.0 - chain_power_multiplier) * 100.0))
	var chain_text := "Chain -%d%%" % chain_pct if chain_pct > 0 else "Chain OK"
	_log_combat_event(
		"Resolve -> DMG %d x%.2f | GOLD +%d | Heat %.2f | %s" % [dealt_damage, turn_multiplier, gained_gold, heat_meter, chain_text],
		Color(0.94, 0.98, 1.0)
	)

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
		heat_meter = minf(1.0, heat_meter + 0.12)
		var bonus := int(round((dealt_damage - threshold) * 0.25)) + 8 * mega_turn_streak
		gold += max(bonus, 8)
		_pop_text("MEGA TURN x%d  +%d GOLD" % [mega_turn_streak, max(bonus, 8)], Vector2(540, 220), Color(1.0, 0.9, 0.35))
		_show_message("Mega turn! Keep the streak alive.")
		_shake(12.0)
	else:
		mega_turn_streak = 0
		heat_meter = maxf(0.0, heat_meter - 0.03)

func _on_enemy_defeated() -> void:
	in_combat = false
	_set_controls_enabled(false)
	_set_combat_log_visible(false)

	if current_node_type == NodeType.BOSS:
		_show_message("Boss down! Act %d cleared." % act_idx)
		_log_combat_event("Boss defeated.", Color(1.0, 0.84, 0.54))
		_complete_boss_node()
		return

	var bounty := 10 + encounter_idx * 3
	if current_node_type == NodeType.ELITE:
		bounty = int(round(float(bounty) * 1.9))
	gold += bounty
	run_gold_earned += bounty
	pending_complete_after_upgrade = true
	if current_node_type == NodeType.ELITE:
		_show_message("Elite down! +%d bounty. Pick an upgrade." % bounty)
	else:
		_show_message("Enemy down! +%d bounty. Pick an upgrade." % bounty)
	_log_combat_event("Victory -> +%d bounty" % bounty, Color(0.82, 1.0, 0.78))
	_offer_upgrades()
	_update_hud()

func _enemy_attack() -> void:
	var damage := 8 + int(round(encounter_idx * 2.6))
	if current_node_type == NodeType.BOSS:
		damage += 8
	_log_combat_event("Enemy attack incoming: %d" % damage, Color(1.0, 0.72, 0.72))
	_apply_player_damage(damage, "Enemy", Vector2(540, 330))

func _apply_player_damage(damage: int, source: String, world_pos: Vector2) -> void:
	if damage <= 0 or not in_combat:
		return
	var scaled_damage := _scale_incoming_damage(damage, source)
	if player_damage_reduction > 0.0:
		scaled_damage = int(round(float(scaled_damage) * (1.0 - player_damage_reduction)))
	scaled_damage = maxi(1, scaled_damage)
	var shield_before: int = int(round(float(player_run_state.get("shield", 0.0))))
	if shield_before > 0:
		var absorbed: int = mini(shield_before, scaled_damage)
		if absorbed > 0:
			player_run_state["shield"] = maxf(0.0, float(shield_before - absorbed))
			scaled_damage -= absorbed
			if audio_manager:
				audio_manager.play_shield_block()
			_pop_text("BLOCK -%d" % absorbed, world_pos + Vector2(0, -44), Color(0.66, 0.92, 1.0), 20)
			_flash_shield_bar()
			_log_combat_event("Block absorbed %d." % absorbed, Color(0.66, 0.92, 1.0))
	if scaled_damage <= 0:
		_show_message("%s hits, but block absorbs it." % source)
		_log_combat_event("%s hit blocked." % source, Color(0.66, 0.92, 1.0))
		_update_hud()
		return
	player_hp -= scaled_damage
	if player_hp <= 0:
		if run_revive_available and not run_revive_used:
			run_revive_used = true
			player_hp = maxi(18, int(round(35.0 + float(act_idx) * 6.0)))
			_show_message("Second Chance activated! Back in the fight.")
			_pop_text("REVIVE!", world_pos, Color(0.72, 1.0, 0.86), 30)
			_shake(10.0)
			_log_combat_event("Second Chance activated.", Color(0.72, 1.0, 0.86))
			_update_hud()
			return
		player_hp = 0
		var gained_shards: int = maxi(3, encounter_idx + act_idx * 2)
		_award_meta_shards(gained_shards)
		_show_message("%s KO! Run ended." % source)
		_log_combat_event("Run ended by %s." % source, Color(1.0, 0.58, 0.58))
		_show_run_summary_menu(false)
		return
	if audio_manager:
		audio_manager.play_enemy_hit()
	_show_message("%s hits you for %d" % [source, scaled_damage])
	_log_combat_event("%s dealt %d to HP." % [source, scaled_damage], Color(1.0, 0.58, 0.58))
	_pop_text("-%d HP" % scaled_damage, world_pos + Vector2(0, -16), Color(1.0, 0.45, 0.45), 20)
	_shake(8.0)
	_update_hud()

func _scale_incoming_damage(base_damage: int, source: String) -> int:
	var run_depth: float = float(maxi(1, (act_idx - 1) * 7 + node_idx_in_act))
	var run_scale: float = 1.0 + run_depth * 0.055
	var pressure_scale: float = 1.0 + threat_meter * 0.22 + heat_meter * 0.14
	var league_scale: float = 1.0 + float(maxi(0, difficulty_league - 1)) * 0.20
	var hp_buffer: float = maxf(0.0, float(player_hp - 95))
	var hp_scale: float = 1.0 + hp_buffer / 220.0

	var source_scale: float = 1.0
	if source.contains("GATE"):
		source_scale = 1.55
	elif source.contains("BUMPER"):
		source_scale = 1.28
	elif source.contains("Enemy"):
		source_scale = 1.12

	var scaled: int = int(round(float(base_damage) * run_scale * pressure_scale * league_scale * hp_scale * source_scale))

	# Ensures incoming hits keep pressure even if player HP snowballs.
	var floor_damage: int = int(2 + floor(run_depth * 0.38) + act_idx)
	if source.contains("hazard"):
		floor_damage += 2 + int(round(board.hazard_strength * 5.0))
	if source.contains("GATE"):
		floor_damage += 2
	if current_node_type == NodeType.BOSS:
		floor_damage += 3

	return maxi(scaled, floor_damage)

func _offer_upgrades() -> void:
	var picks: Array[String] = _pick_upgrades_weighted(3, _upgrade_pool_ids())
	_show_choice("upgrade", "Choose One Upgrade", "Stack power and chase bigger numbers.", picks)

func _start_node(node_type: int) -> void:
	current_node_type = node_type
	awaiting_resolve = false
	ammo = starting_ammo

	if node_type == NodeType.FIGHT or node_type == NodeType.ELITE or node_type == NodeType.BOSS:
		in_combat = true
		_set_controls_enabled(true)
		_set_combat_log_visible(true)
		_clear_combat_log()
		current_enemy_type = _pick_enemy_for_node(node_type)
		current_board_kind = _pick_board_for_node(node_type)
		board.target_spawn_on_elite = bool(MetaManager.unlocks.get("unlock_elite_boxes", false))
		board.target_spawn_multiplier = 1.0
		board.target_speed_multiplier = box_speed_multiplier
		board.enable_curse_mix = unlock_curse_pegs_enabled
		if selected_loadout == LoadoutType.BOX_HUNTER:
			board.target_spawn_on_elite = true
			board.target_spawn_multiplier = 1.8
		_configure_encounter_hazards(node_type)
		board.set_meta("special_pool", _special_ids())
		board.set_meta("special_count", _special_count_for_node(node_type))
		board.build_layout(current_board_kind)
		chain_power_multiplier = 1.0
		if node_type == NodeType.BOSS:
			chain_power_multiplier = 0.72
		elif node_type == NodeType.ELITE:
			chain_power_multiplier = 0.86
		_setup_chain_links()
		_apply_board_theme()
		enemy_hp = _enemy_hp_for_encounter(node_type)
		# Encounter text now lives in the run log to keep the playfield clean.
		_log_combat_event("Encounter: %s | %s board" % [_enemy_name(current_enemy_type), current_board_kind.capitalize()], Color(0.92, 0.96, 1.0))
		if node_type == NodeType.BOSS and (has_volatile_chain or has_link_chain or has_lightning_chain or has_domino_chain):
			_pop_text("BOSS JAMMING CHAINS", Vector2(540, 300), Color(1.0, 0.55, 0.45), 24)
		_update_hud()
		return

	in_combat = false
	_set_controls_enabled(false)
	_set_combat_log_visible(false)
	if node_type == NodeType.EVENT:
		_offer_event()
	elif node_type == NodeType.SHOP:
		_offer_shop()
	elif node_type == NodeType.REST:
		_offer_rest()
	elif node_type == NodeType.TREASURE:
		_offer_treasure()

func _offer_next_room_choices() -> void:
	var next_room_idx := node_idx_in_act + 1
	var pool: Array[String] = []
	if next_room_idx <= 2:
		pool = ["fight", "fight", "event", "shop", "rest"]
	elif next_room_idx <= 4:
		pool = ["fight", "elite", "event", "shop", "rest", "treasure"]
	else:
		pool = ["fight", "elite", "elite", "shop", "treasure", "event"]
	var picks: Array[String] = _pick_unique_ids(pool, 3)
	_show_choice("next_room", "Choose Next Room", "Act %d - Room %d/6" % [act_idx, node_idx_in_act], picks)

func _pick_unique_ids(pool: Array[String], count: int) -> Array[String]:
	var source: Array[String] = pool.duplicate()
	source.shuffle()
	var picks: Array[String] = []
	for id in source:
		if not picks.has(id):
			picks.append(id)
		if picks.size() >= count:
			break
	return picks

func _offer_event() -> void:
	var ids := ["event_prune", "event_curse", "event_trade"]
	_show_choice("event", "Event Room", "Take a risk for a big spike.", ids)

func _offer_shop() -> void:
	var ids := ["shop_damage", "shop_multiplier", "shop_refund"]
	_show_choice("shop", "Shop Room", "Spend gold for permanent scaling.", ids)

func _offer_rest() -> void:
	var ids := ["rest_heal", "rest_ammo", "rest_focus"]
	_show_choice("rest", "Rest Site", "Recover and prep for the next fight.", ids)

func _offer_treasure() -> void:
	var picks: Array[String] = _pick_upgrades_weighted(3, _upgrade_pool_ids())
	_show_choice("treasure", "Treasure Vault", "Pick one premium upgrade.", picks)

func _complete_regular_node(auto_start_fight: bool = false) -> void:
	in_combat = false
	awaiting_resolve = false
	_set_controls_enabled(false)
	_award_progress_for_node(current_node_type)
	if current_node_type == NodeType.FIGHT or current_node_type == NodeType.ELITE:
		_decay_player_shield_after_fight()
	run_rooms_cleared += 1
	_apply_build_pressure()
	var threat_gain: float = 0.14
	match current_node_type:
		NodeType.ELITE:
			threat_gain += 0.12
		NodeType.EVENT:
			threat_gain += 0.04
		NodeType.TREASURE:
			threat_gain += 0.06
		_:
			pass
	threat_meter += threat_gain + float(difficulty_league - 1) * 0.06
	heat_meter = maxf(0.0, heat_meter - 0.08)
	encounter_idx += 1
	if node_idx_in_act >= 6:
		node_idx_in_act = 7
		_start_node(NodeType.BOSS)
		return
	node_idx_in_act += 1
	if auto_start_fight:
		_start_node(NodeType.FIGHT)
	else:
		_offer_next_room_choices()

func _complete_boss_node() -> void:
	in_combat = false
	awaiting_resolve = false
	_set_controls_enabled(false)
	_award_progress_for_node(NodeType.BOSS)
	_decay_player_shield_after_fight()
	run_bosses_killed += 1
	_apply_build_pressure(true)
	threat_meter += 0.28 + float(difficulty_league - 1) * 0.08
	heat_meter = maxf(0.0, heat_meter - 0.12)
	encounter_idx += 1
	if act_idx >= 3:
		_show_run_summary_menu(true)
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
	chain_lockouts.clear()
	extra_balls_spawned_this_turn = 0
	balls_in_play = 0
	last_pocket_effect = -1
	_update_combo_ui()
	EventBus.combo_changed.emit(0.0)

func _update_hud(status: String = "") -> void:
	var enemy_text := "%d" % enemy_hp
	var block_amount: int = int(round(float(player_run_state.get("shield", 0.0))))
	if level_label:
		level_label.text = "LV %d" % player_level
	stats_label.text = "HP %d  Block %d  Enemy %s  Gold %d  Balls %d  Shards %d  DMG %d x%.2f" % [
		player_hp,
		block_amount,
		enemy_text,
		gold,
		ammo,
		meta_shards,
		turn_damage,
		turn_multiplier,
	]
	var lock_text := ""
	if pocket_lock_type >= 0:
		lock_text = " LOCK:%s" % _pocket_name(pocket_lock_type)
	if status != "":
		message_label.text = status
	_update_shield_ui()

func _show_message(text: String) -> void:
	# Keep messages in the run log instead of centered playfield text.
	if in_combat:
		_log_combat_event(text, Color(0.86, 0.92, 1.0))
	if message_label:
		message_label.text = ""
		message_label.visible = false

func _ensure_input_actions() -> void:
	_add_action_if_missing("aim_left", [KEY_A, KEY_LEFT])
	_add_action_if_missing("aim_right", [KEY_D, KEY_RIGHT])
	_add_action_if_missing("drop_ball", [KEY_SPACE, KEY_ENTER])
	_add_action_if_missing("pause_game", [KEY_ESCAPE, KEY_P])

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
	choice_row = row
	vbox.add_child(row)

	for i in 4:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 180)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.clip_text = true
		btn.pressed.connect(_on_choice_pressed.bind(i))
		btn.button_down.connect(_on_choice_button_down.bind(i))
		row.add_child(btn)
		choice_buttons.append(btn)

func _build_arcade_frame() -> void:
	var root := $HUD/Root as Control
	arcade_frame = Control.new()
	arcade_frame.name = "ArcadeFrame"
	arcade_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arcade_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	arcade_frame.offset_left = 8.0
	arcade_frame.offset_top = 8.0
	arcade_frame.offset_right = -8.0
	arcade_frame.offset_bottom = -8.0
	root.add_child(arcade_frame)

	var frame_panel := PanelContainer.new()
	frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	arcade_frame.add_child(frame_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.0)
	style.border_color = Color(0.42, 0.72, 1.0, 0.68)
	style.set_border_width_all(6)
	style.set_corner_radius_all(22)
	frame_panel.add_theme_stylebox_override("panel", style)

func _configure_hud_layout() -> void:
	var top_container := $HUD/Root/Top as Control
	if top_container:
		top_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		top_container.offset_left = 26.0
		top_container.offset_right = -26.0
		top_container.offset_top = -52.0
		top_container.offset_bottom = 8.0
		top_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top_vbox:
		top_vbox.add_theme_constant_override("separation", 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		top_vbox.add_child(row)
		level_label = Label.new()
		level_label.add_theme_font_size_override("font_size", 26)
		level_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
		row.add_child(level_label)
		if stats_label:
			stats_label.reparent(row)
	if stats_label:
		stats_label.add_theme_font_size_override("font_size", 24)
	if turn_label:
		turn_label.visible = false

func _build_combat_log_ui() -> void:
	var root := $HUD/Root as Control
	combat_log_panel = PanelContainer.new()
	combat_log_panel.name = "CombatLog"
	combat_log_panel.visible = false
	combat_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_log_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	combat_log_panel.offset_left = 24.0
	combat_log_panel.offset_top = 16.0
	combat_log_panel.offset_right = -24.0
	combat_log_panel.offset_bottom = 138.0
	root.add_child(combat_log_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.06, 0.14, 0.82)
	panel_style.border_color = Color(0.42, 0.70, 1.0, 0.62)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	combat_log_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	combat_log_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Run Log"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	vbox.add_child(title)

	overdrive_label = Label.new()
	overdrive_label.text = "OVERDRIVE CALM"
	overdrive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overdrive_label.add_theme_font_size_override("font_size", 16)
	overdrive_label.add_theme_color_override("font_color", Color(0.98, 0.78, 1.0))
	vbox.add_child(overdrive_label)

	combat_log_text = RichTextLabel.new()
	combat_log_text.bbcode_enabled = true
	combat_log_text.scroll_active = true
	combat_log_text.scroll_following = true
	combat_log_text.fit_content = false
	combat_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log_text.custom_minimum_size = Vector2(0, 70)
	combat_log_text.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(combat_log_text)
	_refresh_combat_log_ui()

func _build_menu_ui() -> void:
	var root := $HUD/Root as Control

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(72, 52)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -96.0
	pause_button.offset_top = 24.0
	pause_button.offset_right = -24.0
	pause_button.offset_bottom = 76.0
	root.add_child(pause_button)

	menu_overlay = ColorRect.new()
	menu_overlay.visible = false
	menu_overlay.color = Color(0, 0, 0, 0.68)
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(menu_overlay)

	title_layer = Control.new()
	title_layer.visible = false
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_overlay.add_child(title_layer)

	title_glow = ColorRect.new()
	title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_glow.color = Color(0.95, 0.46, 0.12, 0.0)
	title_glow.visible = false
	title_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_glow.offset_left = 60.0
	title_glow.offset_top = 40.0
	title_glow.offset_right = -60.0
	title_glow.offset_bottom = 980.0
	title_layer.add_child(title_glow)

	title_logo = TextureRect.new()
	title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_logo.offset_left = 10.0
	title_logo.offset_top = -40.0
	title_logo.offset_right = -10.0
	title_logo.offset_bottom = 1120.0
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.texture = _load_title_logo_texture()
	title_logo.pivot_offset = Vector2(540.0, 540.0)
	title_layer.add_child(title_logo)

	title_fx_root = Node2D.new()
	title_fx_root.position = Vector2(540, 440)
	title_layer.add_child(title_fx_root)

	title_sparks = CPUParticles2D.new()
	title_sparks.amount = 42
	title_sparks.lifetime = 1.3
	title_sparks.one_shot = false
	title_sparks.explosiveness = 0.0
	title_sparks.direction = Vector2(0.0, -1.0)
	title_sparks.spread = 52.0
	title_sparks.initial_velocity_min = 26.0
	title_sparks.initial_velocity_max = 72.0
	title_sparks.gravity = Vector2(0.0, -14.0)
	title_sparks.scale_amount_min = 1.2
	title_sparks.scale_amount_max = 2.4
	title_sparks.color = Color(1.0, 0.62, 0.18, 0.92)
	title_sparks.emitting = true
	title_fx_root.add_child(title_sparks)

	title_embers = CPUParticles2D.new()
	title_embers.amount = 24
	title_embers.lifetime = 1.8
	title_embers.one_shot = false
	title_embers.explosiveness = 0.0
	title_embers.direction = Vector2(0.0, -1.0)
	title_embers.spread = 120.0
	title_embers.initial_velocity_min = 14.0
	title_embers.initial_velocity_max = 36.0
	title_embers.gravity = Vector2(0.0, -7.0)
	title_embers.scale_amount_min = 1.8
	title_embers.scale_amount_max = 3.2
	title_embers.color = Color(0.30, 0.74, 1.0, 0.72)
	title_embers.emitting = true
	title_fx_root.add_child(title_embers)

	title_logo_fallback = Label.new()
	title_logo_fallback.visible = title_logo.texture == null
	title_logo_fallback.text = "PINFORGE"
	title_logo_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_logo_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_logo_fallback.add_theme_font_size_override("font_size", 100)
	title_logo_fallback.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	title_logo_fallback.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_logo_fallback.offset_left = 40.0
	title_logo_fallback.offset_top = 280.0
	title_logo_fallback.offset_right = -40.0
	title_logo_fallback.offset_bottom = 430.0
	title_layer.add_child(title_logo_fallback)

	title_prompt = Label.new()
	title_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_prompt.text = "PRESS START"
	title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_prompt.add_theme_font_size_override("font_size", 42)
	title_prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	title_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title_prompt.offset_left = 40.0
	title_prompt.offset_top = -920.0
	title_prompt.offset_right = -40.0
	title_prompt.offset_bottom = -840.0
	title_prompt.pivot_offset = Vector2(500.0, 40.0)
	title_layer.add_child(title_prompt)

	title_options = Label.new()
	title_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_options.text = "OPTIONS"
	title_options.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_options.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_options.add_theme_font_size_override("font_size", 30)
	title_options.add_theme_color_override("font_color", Color(0.64, 0.82, 1.0))
	title_options.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title_options.offset_left = 40.0
	title_options.offset_top = -835.0
	title_options.offset_right = -40.0
	title_options.offset_bottom = -775.0
	title_options.pivot_offset = Vector2(500.0, 30.0)
	title_layer.add_child(title_options)

	title_help_preview = RichTextLabel.new()
	title_help_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_help_preview.bbcode_enabled = true
	title_help_preview.fit_content = true
	title_help_preview.scroll_active = false
	title_help_preview.add_theme_font_size_override("normal_font_size", 28)
	title_help_preview.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title_help_preview.offset_left = 86.0
	title_help_preview.offset_top = -800.0
	title_help_preview.offset_right = -86.0
	title_help_preview.offset_bottom = -520.0
	title_help_preview.text = "\n".join([
		"[center][b][color=#8CC9FF]Quick How-To[/color][/b][/center]",
		"[center]Drag to aim  •  [color=#FFD86A]DROP[/color] to cast a ball[/center]",
		"[center]Reduce Enemy HP before you run out of balls[/center]",
		"[center][color=#FF6FAF]Pink=Damage[/color]  [color=#FFD86A]Gold=Money[/color]  [color=#7FDBFF]Blue=Block[/color][/center]",
		"[center][color=#C6A3FF]Violet=Combo[/color]  Pockets: [color=#7CF4B0]Refund[/color] / [color=#FFB3DA]Crit[/color] / [color=#FFD86A]Cashout[/color][/center]",
	])
	title_layer.add_child(title_help_preview)

	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(760, 520)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -380.0
	menu_panel.offset_top = -260.0
	menu_panel.offset_right = 380.0
	menu_panel.offset_bottom = 260.0
	menu_panel.pivot_offset = menu_panel.custom_minimum_size * 0.5
	menu_overlay.add_child(menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	menu_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	menu_title_label = Label.new()
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 42)
	vbox.add_child(menu_title_label)

	menu_subtitle_label = Label.new()
	menu_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle_label.add_theme_font_size_override("font_size", 24)
	menu_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(menu_subtitle_label)

	menu_primary_button = Button.new()
	menu_primary_button.custom_minimum_size = Vector2(0, 96)
	menu_primary_button.add_theme_font_size_override("font_size", 24)
	menu_primary_button.pressed.connect(func() -> void: _on_menu_button_pressed(0))
	vbox.add_child(menu_primary_button)

	menu_secondary_button = Button.new()
	menu_secondary_button.custom_minimum_size = Vector2(0, 96)
	menu_secondary_button.add_theme_font_size_override("font_size", 24)
	menu_secondary_button.pressed.connect(func() -> void: _on_menu_button_pressed(1))
	vbox.add_child(menu_secondary_button)

	menu_tertiary_button = Button.new()
	menu_tertiary_button.custom_minimum_size = Vector2(0, 86)
	menu_tertiary_button.add_theme_font_size_override("font_size", 20)
	menu_tertiary_button.pressed.connect(func() -> void: _on_menu_button_pressed(2))
	vbox.add_child(menu_tertiary_button)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.16, 0.94)
	panel_style.border_color = Color(0.42, 0.68, 1.0, 0.50)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	menu_panel.add_theme_stylebox_override("panel", panel_style)

	var strong_button_style := StyleBoxFlat.new()
	strong_button_style.bg_color = Color(0.20, 0.42, 0.85, 0.92)
	strong_button_style.border_color = Color(0.55, 0.78, 1.0, 0.85)
	strong_button_style.set_border_width_all(2)
	strong_button_style.set_corner_radius_all(12)
	menu_primary_button.add_theme_stylebox_override("normal", strong_button_style)
	menu_primary_button.add_theme_color_override("font_color", Color.WHITE)

	var normal_button_style := StyleBoxFlat.new()
	normal_button_style.bg_color = Color(0.14, 0.20, 0.35, 0.92)
	normal_button_style.border_color = Color(0.40, 0.55, 0.90, 0.55)
	normal_button_style.set_border_width_all(2)
	normal_button_style.set_corner_radius_all(12)
	menu_secondary_button.add_theme_stylebox_override("normal", normal_button_style)
	menu_tertiary_button.add_theme_stylebox_override("normal", normal_button_style)
	menu_secondary_button.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	menu_tertiary_button.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	menu_title_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	menu_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))

	audio_label = Label.new()
	audio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_label.add_theme_font_size_override("font_size", 18)
	audio_label.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0))
	audio_label.text = "Audio Mix"
	vbox.add_child(audio_label)

	music_row = HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 10)
	vbox.add_child(music_row)
	var music_title := Label.new()
	music_title.text = "Music"
	music_title.custom_minimum_size = Vector2(90, 30)
	music_row.add_child(music_title)
	music_slider = HSlider.new()
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.min_value = -30.0
	music_slider.max_value = 0.0
	music_slider.step = 1.0
	music_slider.value_changed.connect(_on_music_slider_changed)
	music_row.add_child(music_slider)

	sfx_row = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	vbox.add_child(sfx_row)
	var sfx_title := Label.new()
	sfx_title.text = "SFX"
	sfx_title.custom_minimum_size = Vector2(90, 30)
	sfx_row.add_child(sfx_title)
	sfx_slider = HSlider.new()
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.min_value = -30.0
	sfx_slider.max_value = 6.0
	sfx_slider.step = 1.0
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	sfx_row.add_child(sfx_slider)

	options_help_text = RichTextLabel.new()
	options_help_text.bbcode_enabled = true
	options_help_text.fit_content = true
	options_help_text.scroll_active = true
	options_help_text.custom_minimum_size = Vector2(0, 340)
	options_help_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_help_text.add_theme_font_size_override("normal_font_size", 21)
	options_help_text.text = _options_help_bbcode()
	vbox.add_child(options_help_text)
	_set_audio_controls_visible(false)

func _show_menu_overlay(mode: String, title: String, subtitle: String, button_texts: Array[String]) -> void:
	menu_mode = mode
	menu_title_label.text = title
	menu_subtitle_label.text = subtitle
	_set_home_title_visible(mode == "home")
	_set_home_screen_mode(mode == "home" or mode == "options")
	_set_audio_controls_visible(mode == "options")
	_set_combat_log_visible(false)
	if mode == "options":
		menu_panel.offset_top = -440.0
		menu_panel.offset_bottom = 440.0
	else:
		menu_panel.offset_top = -260.0
		menu_panel.offset_bottom = 260.0
	if menu_overlay:
		menu_overlay.color = Color(0, 0, 0, 0.35) if mode == "home" else Color(0, 0, 0, 0.68)

	var buttons: Array[Button] = [menu_primary_button, menu_secondary_button, menu_tertiary_button]
	for i in range(buttons.size()):
		if i < button_texts.size():
			buttons[i].visible = true
			buttons[i].text = button_texts[i]
			buttons[i].disabled = false
		else:
			buttons[i].visible = false

	menu_overlay.visible = true
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE if mode == "home" else Control.MOUSE_FILTER_STOP
	if audio_manager:
		audio_manager.play_menu_open()
	_set_menu_visual_state(true)
	menu_panel.scale = Vector2(0.92, 0.92)
	menu_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(menu_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.14)

func _hide_menu_overlay() -> void:
	if menu_overlay:
		menu_overlay.visible = false
		menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if title_layer:
		title_layer.visible = false
	_set_home_screen_mode(false)
	_set_menu_visual_state(false)
	menu_mode = ""

func _set_home_title_visible(visible: bool) -> void:
	if title_layer:
		title_layer.visible = visible
	if visible:
		menu_panel.offset_top = 100.0
		menu_panel.offset_bottom = 620.0
		menu_title_label.visible = false
		menu_subtitle_label.visible = false
		menu_panel.visible = false
		title_anim_time = 0.0
	else:
		menu_panel.offset_top = -260.0
		menu_panel.offset_bottom = 260.0
		menu_title_label.visible = true
		menu_subtitle_label.visible = true
		menu_panel.visible = true
		if menu_primary_button:
			menu_primary_button.scale = Vector2.ONE

func _load_title_logo_texture() -> Texture2D:
	var candidates: Array[String] = [
		"res://assets/ui/pinforge_logo.png",
		"res://assets/ui/pinforge_logo.webp",
		"res://assets/ui/pinforge_logo.jpg",
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				return tex
	return null

func _set_home_screen_mode(enabled: bool) -> void:
	# Hide gameplay HUD and board visuals so the title reads like a separate screen.
	var top := $HUD/Root/Top as Control
	if top:
		top.visible = not enabled
	if message_label:
		message_label.visible = not enabled
	if pause_button:
		pause_button.visible = not enabled
	if board:
		board.visible = not enabled
	var walls := get_node_or_null("Walls") as Node2D
	if walls:
		walls.visible = not enabled
	if launcher:
		launcher.visible = not enabled
	if balls:
		balls.visible = not enabled

func _animate_home_title() -> void:
	var pulse: float = 1.0 + sin(title_anim_time * 2.8) * 0.025
	if title_logo:
		title_logo.scale = Vector2(pulse, pulse)
	if title_fx_root:
		title_fx_root.position = Vector2(540, 430 + sin(title_anim_time * 1.1) * 6.0)
	if title_glow:
		var glow_alpha: float = 0.02 + (sin(title_anim_time * 2.1) * 0.5 + 0.5) * 0.05
		title_glow.modulate.a = glow_alpha
	if title_prompt:
		var base_alpha := 0.45 + (sin(title_anim_time * 4.6) * 0.5 + 0.5) * 0.55
		var hover_bonus := 0.24 if home_prompt_hover else 0.0
		var click_bonus := 0.30 if home_prompt_click_fx > 0.0 else 0.0
		title_prompt.modulate = Color(1.0, 0.86 + hover_bonus * 0.2, 0.48 + hover_bonus * 0.2, clampf(base_alpha + hover_bonus + click_bonus, 0.0, 1.0))
		var prompt_scale := 1.0
		if home_prompt_hover:
			prompt_scale = 1.06
		if home_prompt_click_fx > 0.0:
			prompt_scale = 1.12
		title_prompt.scale = Vector2(prompt_scale, prompt_scale)
	if title_options:
		var opt_alpha := 0.55 + (sin(title_anim_time * 3.1 + 0.8) * 0.5 + 0.5) * 0.35
		var opt_hover := 0.24 if home_options_hover else 0.0
		title_options.modulate = Color(0.64 + opt_hover * 0.2, 0.82 + opt_hover * 0.1, 1.0, clampf(opt_alpha + opt_hover, 0.0, 1.0))
		var options_scale := 1.0
		if home_options_hover:
			options_scale = 1.05
		title_options.scale = Vector2(options_scale, options_scale)

func _sync_audio_sliders() -> void:
	if audio_manager == null:
		return
	if music_slider:
		music_slider.value = audio_manager.get_music_volume_db()
	if sfx_slider:
		sfx_slider.value = audio_manager.get_sfx_volume_db()

func _on_music_slider_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_music_volume_db(value)

func _on_sfx_slider_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_sfx_volume_db(value)

func _set_menu_visual_state(is_menu: bool) -> void:
	if glass_overlay:
		glass_overlay.visible = not is_menu
	if backdrop and backdrop.has_method("set_menu_mode"):
		backdrop.call("set_menu_mode", is_menu)

func _set_audio_controls_visible(visible: bool) -> void:
	if audio_label:
		audio_label.visible = visible
	if music_row:
		music_row.visible = visible
	if sfx_row:
		sfx_row.visible = visible
	if options_help_text:
		options_help_text.visible = visible

func _home_help_preview_bbcode() -> String:
	return "\n".join([
		"[center][b][color=#8CC9FF]Quick How-To[/color][/b][/center]",
		"[center]Drag to aim  •  [color=#FFD86A]Drop[/color] to cast[/center]",
		"[center][color=#FF6FAF]Pink=Damage[/color]  [color=#FFD86A]Gold=Money[/color]  [color=#7FDBFF]Blue=Block[/color]  [color=#C6A3FF]Violet=Combo[/color][/center]",
	])

func _options_help_bbcode() -> String:
	return "\n".join([
		"[b][color=#8CC9FF]How to Play[/color][/b]",
		"1) Aim with drag (or LEFT/RIGHT), then press DROP.",
		"2) Hit pegs to build [color=#FF6FAF]damage[/color], [color=#FFD86A]gold[/color], [color=#7FDBFF]block[/color], and [color=#C6A3FF]multiplier[/color].",
		"3) Land in pockets for jackpots: [color=#7CF4B0]REFUND[/color], [color=#FFB3DA]CRIT[/color], [color=#FFD86A]CASHOUT[/color].",
		"4) Block absorbs incoming damage. It decays between fights.",
		"",
		"[b][color=#FFC27A]Color + Effect Guide[/color][/b]",
		"[color=#FF6FAF]Pink pegs[/color] = damage scaling.",
		"[color=#FFD86A]Gold pegs[/color] = economy and shop power.",
		"[color=#7FDBFF]Blue pegs[/color] = block to absorb enemy hits.",
		"[color=#C6A3FF]Violet pegs[/color] = combo/multiplier tempo.",
		"Big moving hazards and gates deal direct HP damage if touched.",
		"Moving reward boxes above pockets give burst bonuses when hit.",
		"Combo tiers boost damage and multiplier scaling.",
		"",
		"[b][color=#9BFFB8]Run Tips[/color][/b]",
		"Take at least one damage scaler + one defense tool each act.",
		"Use elite/treasure rooms for power spikes before bosses.",
	])

func _log_combat_event(text: String, color: Color = Color(0.92, 0.96, 1.0)) -> void:
	if text == "":
		return
	var stamped := "[color=#%s]%s[/color]" % [color.to_html(false), text]
	combat_log_entries.append(stamped)
	if combat_log_entries.size() > COMBAT_LOG_MAX:
		combat_log_entries.remove_at(0)
	_refresh_combat_log_ui()

func _refresh_combat_log_ui() -> void:
	if combat_log_text == null:
		return
	if combat_log_entries.is_empty():
		combat_log_text.text = "[color=#8aa2be]Events from this encounter show up here.[/color]"
	else:
		combat_log_text.text = "\n".join(combat_log_entries)
	combat_log_text.scroll_to_line(maxi(0, combat_log_text.get_line_count() - 1))

func _clear_combat_log() -> void:
	combat_log_entries.clear()
	_refresh_combat_log_ui()

func _set_combat_log_visible(visible: bool) -> void:
	if combat_log_panel:
		combat_log_panel.visible = visible

func _show_home_menu() -> void:
	in_combat = false
	awaiting_resolve = false
	awaiting_choice = false
	pending_complete_after_upgrade = false
	if title_logo:
		title_logo.texture = _load_title_logo_texture()
	if title_logo_fallback:
		title_logo_fallback.visible = (title_logo == null or title_logo.texture == null)
	if choice_panel:
		choice_panel.visible = false
	_set_controls_enabled(false)
	_set_combat_log_visible(false)
	_clear_combat_log()
	_show_message("Welcome to Pinforge.")
	_show_menu_overlay(
		"home",
		"Pinforge",
		"Arcade Roguelite",
		[]
	)

func _show_options_menu() -> void:
	_show_menu_overlay(
		"options",
		"Options",
		"Audio and accessibility settings.",
		["Back To Title", "League: %s" % _league_name(selected_league), "Quit"]
	)

func _toggle_pause_menu() -> void:
	if menu_mode == "home" or menu_mode == "death":
		return
	if menu_overlay and menu_overlay.visible and menu_mode == "pause":
		get_tree().paused = false
		_hide_menu_overlay()
		_set_combat_log_visible(in_combat)
		return
	if not in_combat or awaiting_choice:
		return
	get_tree().paused = true
	_show_menu_overlay("pause", "Paused", "Take a breath. Your run is waiting.", ["Resume", "Restart Run", "Main Menu"])

func _show_death_menu(shards_gained: int) -> void:
	get_tree().paused = false
	in_combat = false
	awaiting_resolve = false
	awaiting_choice = false
	if choice_panel:
		choice_panel.visible = false
	_set_controls_enabled(false)
	_set_combat_log_visible(false)
	var subtitle := "Act %d Room %d  |  Gold %d  |  +%d shards this run" % [act_idx, node_idx_in_act, gold, shards_gained]
	_show_menu_overlay("death", "Run Over", subtitle, ["Try Again", "Main Menu"])

func _show_run_summary_menu(victory: bool) -> void:
	run_was_victory = victory
	get_tree().paused = false
	in_combat = false
	awaiting_resolve = false
	awaiting_choice = false
	if choice_panel:
		choice_panel.visible = false
	_set_controls_enabled(false)
	_set_combat_log_visible(false)
	var title := "Run Complete" if victory else "Run Summary"
	var xp_next: int = MetaManager.xp_to_next_level()
	var subtitle := "Act %d  | Rooms %d  | Elites %d  | Bosses %d\nCombo %d  | Gold %d  | Boxes %d\nShards +%d  | XP +%d  | Lv %d (%d/%d)\n%s" % [
		act_idx,
		run_rooms_cleared,
		run_elites_cleared,
		run_bosses_killed,
		run_best_combo,
		run_gold_earned,
		run_boxes_hit,
		run_shards_earned,
		run_xp_earned,
		player_level,
		player_xp,
		xp_next,
		_next_meta_hint(),
	]
	var second_button := "Level Skill (%d)" % pending_skill_points if pending_skill_points > 0 else "Unlocks"
	_show_menu_overlay("run_summary", title, subtitle, ["Spend Shards", second_button, "Start New Run"])

func _show_meta_shop_menu() -> void:
	meta_shop_page = clampi(meta_shop_page, 0, META_SHOP_PAGES.size() - 1)
	var shop_row: Array = META_SHOP_PAGES[meta_shop_page] as Array
	var perk_a: String = str(shop_row[0])
	var perk_b: String = str(shop_row[1])
	var subtitle := "Shards: %d  | Level %d\nBuy account perks that carry into every run. Page %d/%d." % [meta_shards, player_level, meta_shop_page + 1, META_SHOP_PAGES.size()]
	var nav_text := "Back"
	if meta_shop_page < META_SHOP_PAGES.size() - 1:
		nav_text = "Next Page"
	_show_menu_overlay("meta_shop", "Cabinet Perks", subtitle, [
		_perk_button_text(perk_a),
		_perk_button_text(perk_b),
		nav_text,
	])

func _show_unlocks_menu() -> void:
	unlocks_page = clampi(unlocks_page, 0, UNLOCK_PAGES.size() - 1)
	var unlock_row: Array = UNLOCK_PAGES[unlocks_page] as Array
	var unlock_a: String = str(unlock_row[0])
	var unlock_b: String = str(unlock_row[1])
	var subtitle := "Shards: %d  | Unlock new systems and loadouts. Page %d/%d." % [meta_shards, unlocks_page + 1, UNLOCK_PAGES.size()]
	var nav_text := "Back"
	if unlocks_page < UNLOCK_PAGES.size() - 1:
		nav_text = "Next Page"
	_show_menu_overlay("unlocks", "Unlocks", subtitle, [
		_unlock_button_text(unlock_a),
		_unlock_button_text(unlock_b),
		nav_text,
	])

func _show_skill_menu() -> void:
	skill_choice_ids = MetaManager.available_skill_choices(3)
	var subtitle := "Spend skill points from level-ups. Points left: %d" % pending_skill_points
	var buttons: Array[String] = []
	for id in skill_choice_ids:
		buttons.append(_skill_button_text(id))
	while buttons.size() < 3:
		buttons.append("Back")
	_show_menu_overlay("skills", "Level Skills", subtitle, buttons)

func _skill_button_text(skill_id: String) -> String:
	var tier := MetaManager.skill_tier(skill_id)
	var max_tier := MetaManager.skill_max_tier(skill_id)
	return "%s\n%s (Tier %d/%d)" % [_skill_title(skill_id), _skill_desc(skill_id), tier, max_tier]

func _perk_button_text(perk_id: String) -> String:
	var tier := MetaManager.perk_tier(perk_id)
	var max_tier := MetaManager.perk_max_tier(perk_id)
	var level_req := MetaManager.perk_level_requirement(perk_id)
	var cost := MetaManager.perk_cost(perk_id)
	if tier >= max_tier:
		return "%s\nMAXED  (Lv %d/%d)" % [_perk_title(perk_id), tier, max_tier]
	return "%s\nTier %d/%d  Cost %d  (Req Lv %d)" % [_perk_title(perk_id), tier, max_tier, cost, level_req]

func _unlock_button_text(unlock_id: String) -> String:
	var unlocked := bool(MetaManager.unlocks.get(unlock_id, false))
	if unlocked:
		return "%s\nUNLOCKED" % _unlock_title(unlock_id)
	var cost := MetaManager.unlock_cost(unlock_id)
	var req := MetaManager.unlock_level_requirement(unlock_id)
	return "%s\nCost %d  (Req Lv %d)" % [_unlock_title(unlock_id), cost, req]

func _perk_title(perk_id: String) -> String:
	match perk_id:
		"start_gold":
			return "Start Gold"
		"start_hp":
			return "Start HP"
		"shop_discount":
			return "Shop Discount"
		"split_resonance":
			return "Split Resonance"
		"start_ammo":
			return "Start Balls"
		"second_chance":
			return "Second Chance"
		"box_bonus":
			return "Box Shard Bonus"
		"box_control":
			return "Box Speed Control"
		_:
			return perk_id.capitalize()

func _unlock_title(unlock_id: String) -> String:
	match unlock_id:
		"loadout_box_hunter":
			return "Loadout: Box Hunter"
		"unlock_elite_boxes":
			return "Elite Moving Boxes"
		"unlock_curse_pegs":
			return "Cursed Peg Pool"
		"unlock_portal_pocket":
			return "Portal Pocket Pool"
		_:
			return unlock_id.capitalize()

func _skill_title(skill_id: String) -> String:
	match skill_id:
		"control_nudge":
			return "Control: Extra Ball"
		"craft_charge":
			return "Craft: Fast Charge"
		"hype_combo":
			return "Hype: Combo Seed"
		"econ_cache":
			return "Econ: Cache Boost"
		"survive_patch":
			return "Survive: Patch Kit"
		"show_jackpot":
			return "Show: Box Bonus"
		_:
			return skill_id.capitalize()

func _skill_desc(skill_id: String) -> String:
	match skill_id:
		"control_nudge":
			return "+1 starting ball each tier."
		"craft_charge":
			return "More split peg chance each tier."
		"hype_combo":
			return "Start drops with combo seed."
		"econ_cache":
			return "+10 starting gold each tier."
		"survive_patch":
			return "+8 starting HP each tier."
		"show_jackpot":
			return "+1 shard bonus from boxes."
		_:
			return ""

func _league_name(league: int) -> String:
	match league:
		1:
			return "Rookie"
		2:
			return "Regular"
		3:
			return "Pro"
		4:
			return "Master"
		_:
			return "Rookie"

func _next_meta_hint() -> String:
	var next_level := player_level + 1
	var next_xp := MetaManager.xp_to_next_level()
	return "Next level: %d XP to Lv %d. League: %s. Skill pts: %d." % [maxi(0, next_xp - player_xp), next_level, _league_name(selected_league), pending_skill_points]

func _on_menu_button_pressed(index: int) -> void:
	if audio_manager:
		audio_manager.play_menu_click()
	match menu_mode:
		"home":
			if index == 0:
				_start_new_run(true)
			elif index == 1:
				_start_new_run(false)
				_show_message("Sanctum open. Spend shards, then continue.")
			elif index == 2:
				_show_options_menu()
		"options":
			if index == 0:
				_show_home_menu()
			elif index == 1:
				MetaManager.cycle_selected_league()
				_refresh_meta_cache()
				_show_options_menu()
			elif index == 2:
				get_tree().quit()
		"pause":
			if index == 0:
				get_tree().paused = false
				_hide_menu_overlay()
				_set_combat_log_visible(in_combat)
			elif index == 1:
				get_tree().paused = false
				_start_new_run(true)
			elif index == 2:
				get_tree().paused = false
				_show_home_menu()
		"death":
			if index == 0:
				_start_new_run(true)
			elif index == 1:
				_show_home_menu()
		"run_summary":
			if index == 0:
				meta_shop_page = 0
				_show_meta_shop_menu()
			elif index == 1:
				if pending_skill_points > 0:
					_show_skill_menu()
				else:
					unlocks_page = 0
					_show_unlocks_menu()
			elif index == 2:
				_start_new_run(true)
		"skills":
			if index < skill_choice_ids.size():
				_try_pick_skill(skill_choice_ids[index])
			else:
				_show_run_summary_menu(run_was_victory)
		"meta_shop":
			var perk_page: Array = META_SHOP_PAGES[meta_shop_page] as Array
			if index == 0:
				_try_buy_perk(str(perk_page[0]))
			elif index == 1:
				_try_buy_perk(str(perk_page[1]))
			elif index == 2:
				if meta_shop_page < META_SHOP_PAGES.size() - 1:
					meta_shop_page += 1
					_show_meta_shop_menu()
				else:
					_show_run_summary_menu(run_was_victory)
		"unlocks":
			var unlock_page: Array = UNLOCK_PAGES[unlocks_page] as Array
			if index == 0:
				_try_unlock(str(unlock_page[0]))
			elif index == 1:
				_try_unlock(str(unlock_page[1]))
			elif index == 2:
				if unlocks_page < UNLOCK_PAGES.size() - 1:
					unlocks_page += 1
					_show_unlocks_menu()
				else:
					_show_run_summary_menu(run_was_victory)

func _show_choice(context: String, title: String, subtitle: String, payload_ids: Array) -> void:
	awaiting_choice = true
	choice_context = context
	choice_payload.clear()
	if context == "next_room":
		payload_ids = _ensure_three_next_room_choices(payload_ids)
	choice_title_label.text = title
	choice_subtitle_label.text = subtitle
	_set_controls_enabled(false)
	in_combat = false
	awaiting_resolve = false
	if context == "starter_build":
		var top_container := $HUD/Root/Top as Control
		if top_container:
			top_container.visible = false
		if message_label:
			message_label.text = ""
			message_label.visible = false
		if launcher:
			launcher.visible = false
		choice_panel.set_anchors_preset(Control.PRESET_CENTER)
		choice_panel.custom_minimum_size = Vector2(1040, 720)
		choice_panel.offset_left = -520.0
		choice_panel.offset_right = 520.0
		choice_panel.offset_top = -280.0
		choice_panel.offset_bottom = 440.0
		choice_title_label.add_theme_font_size_override("font_size", 44)
		choice_subtitle_label.add_theme_font_size_override("font_size", 24)
		if choice_row:
			choice_row.add_theme_constant_override("separation", 18)
		for btn in choice_buttons:
			btn.custom_minimum_size = Vector2(230, 360)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		var top_container_restore := $HUD/Root/Top as Control
		if top_container_restore:
			top_container_restore.visible = true
		if launcher:
			launcher.visible = true
		choice_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		choice_panel.custom_minimum_size = Vector2.ZERO
		choice_panel.offset_left = 24.0
		choice_panel.offset_right = -24.0
		choice_panel.offset_top = 340.0
		choice_panel.offset_bottom = -300.0
		choice_title_label.add_theme_font_size_override("font_size", 34)
		choice_subtitle_label.add_theme_font_size_override("font_size", 20)
		if choice_row:
			choice_row.add_theme_constant_override("separation", 10)
		for btn in choice_buttons:
			btn.custom_minimum_size = Vector2(0, 180)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for i in payload_ids.size():
		choice_payload.append(str(payload_ids[i]))

	for i in choice_buttons.size():
		if i < choice_payload.size():
			choice_buttons[i].visible = true
			choice_buttons[i].disabled = false
			choice_buttons[i].text = _choice_button_text(context, choice_payload[i])
		else:
			choice_buttons[i].visible = false
		var card_id := choice_payload[i] if i < choice_payload.size() else ""
		_apply_choice_card_style(choice_buttons[i], context, card_id)
		_apply_choice_card_art(choice_buttons[i], context, card_id)

	choice_panel.visible = true

func _ensure_three_next_room_choices(payload_ids: Array) -> Array:
	var fixed: Array = []
	for item in payload_ids:
		var id := str(item)
		if not fixed.has(id):
			fixed.append(id)
	var fallback := ["fight", "event", "shop", "rest", "elite", "treasure"]
	for id in fallback:
		if fixed.size() >= 3:
			break
		if not fixed.has(id):
			fixed.append(id)
	while fixed.size() > 3:
		fixed.pop_back()
	return fixed

func _apply_choice_card_art(btn: Button, context: String, id: String) -> void:
	if btn == null:
		return
	var art := btn.get_node_or_null("CardArt") as TextureRect
	var shade := btn.get_node_or_null("HoverShade") as ColorRect
	var text_label := btn.get_node_or_null("HoverText") as Label
	var glow := btn.get_node_or_null("Glow") as ColorRect
	var sheen := btn.get_node_or_null("Sheen") as ColorRect
	if context != "starter_build":
		btn.scale = Vector2.ONE
		if art:
			art.visible = false
		if shade:
			shade.visible = false
		if text_label:
			text_label.visible = false
		if glow:
			glow.visible = false
		if sheen:
			sheen.visible = false
		btn.text = _choice_button_text(context, id)
		return
	if art:
		art.visible = true
	if glow:
		glow.visible = true
	if sheen:
		sheen.visible = true
	# Hover text only on starter build.
	if shade:
		shade.visible = false
	if text_label:
		text_label.visible = false

func _apply_choice_card_style(btn: Button, context: String, id: String) -> void:
	if btn == null:
		return
	if context != "starter_build":
		btn.scale = Vector2.ONE
		return
	var art_paths := {
		"striker_split": "res://assets/cards/striker_split.png",
		"hustler_greed": "res://assets/cards/hustler_greed.png",
		"guardian_vamp": "res://assets/cards/guardian_vamp.png",
		"showman_box_hunter": "res://assets/cards/showman_box_hunter.png",
	}
	var palette := {
		"striker_split": Color("ff6fa6"),
		"hustler_greed": Color("f2c94c"),
		"guardian_vamp": Color("7dd3fc"),
		"showman_box_hunter": Color("c084fc"),
	}
	var accent: Color = palette.get(id, Color(0.7, 0.9, 1.0))
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.08, 0.10, 0.16, 0.92)
	base.border_color = accent
	base.set_border_width_all(2)
	base.set_corner_radius_all(14)
	base.shadow_color = Color(0, 0, 0, 0.45)
	base.shadow_size = 10

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.10, 0.12, 0.20, 0.96)
	hover.border_color = accent.lightened(0.3)
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(14)
	hover.shadow_color = Color(0, 0, 0, 0.55)
	hover.shadow_size = 12

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	pressed.border_color = accent.lightened(0.15)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(14)
	pressed.shadow_color = Color(0, 0, 0, 0.5)
	pressed.shadow_size = 8

	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	btn.add_theme_color_override("font_color_hover", Color(1, 1, 1))
	btn.add_theme_color_override("font_color_pressed", Color(0.95, 0.97, 1.0))
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_contents = true
	var label_text := btn.text
	btn.text = ""

	var art := btn.get_node_or_null("CardArt") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = "CardArt"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 6
		art.offset_top = 6
		art.offset_right = -6
		art.offset_bottom = -6
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.show_behind_parent = false
		btn.add_child(art)
	var art_path: String = art_paths.get(id, "")
	if art_path != "":
		var tex := load(art_path)
		if tex is Texture2D:
			art.texture = tex
			art.modulate = Color(1, 1, 1, 0.92)

	var shade := btn.get_node_or_null("HoverShade") as ColorRect
	if shade == null:
		shade = ColorRect.new()
		shade.name = "HoverShade"
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0, 0, 0, 0.45)
		shade.visible = false
		btn.add_child(shade)

	var text_label := btn.get_node_or_null("HoverText") as Label
	if text_label == null:
		text_label = Label.new()
		text_label.name = "HoverText"
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.add_theme_font_size_override("font_size", 18)
		text_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
		text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		text_label.visible = false
		btn.add_child(text_label)
	text_label.text = label_text

	if not btn.has_meta("hover_fx"):
		btn.set_meta("hover_fx", true)
		btn.mouse_entered.connect(func():
			if choice_context != "starter_build":
				return
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var shade_node := btn.get_node_or_null("HoverShade") as ColorRect
			var text_node := btn.get_node_or_null("HoverText") as Label
			if shade_node:
				shade_node.visible = true
			if text_node:
				text_node.visible = true
		)
		btn.mouse_exited.connect(func():
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var shade_node := btn.get_node_or_null("HoverShade") as ColorRect
			var text_node := btn.get_node_or_null("HoverText") as Label
			if shade_node:
				shade_node.visible = false
			if text_node:
				text_node.visible = false
		)
		btn.focus_entered.connect(func():
			if choice_context != "starter_build":
				return
			var shade_node := btn.get_node_or_null("HoverShade") as ColorRect
			var text_node := btn.get_node_or_null("HoverText") as Label
			if shade_node:
				shade_node.visible = true
			if text_node:
				text_node.visible = true
		)
		btn.focus_exited.connect(func():
			var shade_node := btn.get_node_or_null("HoverShade") as ColorRect
			var text_node := btn.get_node_or_null("HoverText") as Label
			if shade_node:
				shade_node.visible = false
			if text_node:
				text_node.visible = false
		)

	var glow := btn.get_node_or_null("Glow") as ColorRect
	if glow == null:
		glow = ColorRect.new()
		glow.name = "Glow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.color = Color(0, 0, 0, 0)
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.offset_left = -24
		glow.offset_top = -24
		glow.offset_right = 24
		glow.offset_bottom = 24
		glow.show_behind_parent = true
		btn.add_child(glow)
		var glow_style := StyleBoxFlat.new()
		glow_style.bg_color = Color(0, 0, 0, 0)
		glow_style.border_color = accent.lightened(0.55)
		glow_style.set_border_width_all(8)
		glow_style.set_corner_radius_all(18)
		glow.add_theme_stylebox_override("panel", glow_style)

	var sheen := btn.get_node_or_null("Sheen") as ColorRect
	if sheen == null:
		sheen = ColorRect.new()
		sheen.name = "Sheen"
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheen.color = Color(0, 0, 0, 0)
		sheen.set_anchors_preset(Control.PRESET_FULL_RECT)
		sheen.show_behind_parent = false
		btn.add_child(sheen)
		var sheen_mat := ShaderMaterial.new()
		sheen_mat.shader = load("res://shaders/card_sheen.shader") as Shader
		sheen_mat.set_shader_parameter("tint", accent)
		sheen_mat.set_shader_parameter("strength", 0.6)
		sheen_mat.set_shader_parameter("speed", 1.2)
		sheen.material = sheen_mat

	if not btn.has_meta("pulse_fx"):
		btn.set_meta("pulse_fx", true)
		glow.modulate.a = 0.35
		glow.pivot_offset = btn.size * 0.5
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(glow, "modulate:a", 0.85, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_choice_pressed(index: int) -> void:
	if not awaiting_choice:
		return
	if index < 0 or index >= choice_payload.size():
		return

	var pick := choice_payload[index]
	choice_panel.visible = false
	awaiting_choice = false
	var top_container := $HUD/Root/Top as Control
	if top_container:
		top_container.visible = true
	if launcher:
		launcher.visible = true

	match choice_context:
		"meta":
			_resolve_meta_pick(pick)
		"starter_build":
			_apply_starter_build(pick)
			node_idx_in_act = 1
			_start_node(NodeType.FIGHT)
		"character":
			_apply_character(pick)
			_show_loadout_choices()
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
			_complete_regular_node(true)
		"shop":
			_resolve_shop_pick(pick)
			_complete_regular_node(true)
		"rest":
			_resolve_rest_pick(pick)
			_complete_regular_node(true)
		"treasure":
			_apply_upgrade(pick)
			_show_message("Treasure: %s" % _upgrade_title(pick))
			_complete_regular_node(true)
		"victory":
			_start_new_run(true)

	_update_hud()

func _on_choice_button_down(index: int) -> void:
	if choice_panel == null or not choice_panel.visible:
		return
	if index < 0 or index >= choice_payload.size():
		return
	if not awaiting_choice:
		awaiting_choice = true
	_on_choice_pressed(index)

func _set_controls_enabled(enabled: bool) -> void:
	left_button.disabled = not enabled
	drop_button.disabled = not enabled
	right_button.disabled = not enabled
	if bottom_controls:
		bottom_controls.visible = mobile_touch_controls_enabled and enabled
	if not enabled:
		active_aim_touch_id = -1
		active_aim_touch_moved = false
		active_aim_mouse = false
		active_aim_mouse_moved = false
		held_left_touch_id = -1
		held_right_touch_id = -1

func _enemy_hp_for_encounter(node_type: int) -> int:
	var base := 120.0 * pow(1.21, encounter_idx - 1)
	if node_type == NodeType.ELITE:
		base *= 1.55
	if node_type == NodeType.BOSS:
		base *= 2.3
	base += (act_idx - 1) * 45.0
	base *= (1.0 + threat_meter * 0.07)
	base *= (1.0 + float(difficulty_league - 1) * 0.14)
	return int(round(base))

func _pick_enemy_for_node(node_type: int) -> int:
	if node_type == NodeType.BOSS:
		return EnemyType.PIN_KING
	var options := [EnemyType.SHIELD_SNAIL, EnemyType.TAX_COLLECTOR, EnemyType.PEG_EATER]
	return options[randi() % options.size()]

func _pick_board_for_node(node_type: int) -> String:
	if node_type == NodeType.BOSS:
		return "chaos"
	if node_type == NodeType.ELITE:
		var elite_options := ["risk", "combo", "chaos"]
		return elite_options[randi() % elite_options.size()]
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
	var danger_boost := 0.018 * float(maxi(0, difficulty_league - 1)) + heat_meter * 0.02
	backdrop.color = Color(
		clampf(tint.r + act_boost + danger_boost * 0.8, 0.0, 1.0),
		clampf(tint.g + act_boost * 0.5 + danger_boost * 0.3, 0.0, 1.0),
		clampf(tint.b + act_boost + danger_boost, 0.0, 1.0),
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

func _character_name() -> String:
	match selected_character:
		CharacterType.STRIKER:
			return "Striker"
		CharacterType.HUSTLER:
			return "Hustler"
		CharacterType.GUARDIAN:
			return "Guardian"
		CharacterType.SHOWMAN:
			return "Showman"
		_:
			return "Driver"

func _pocket_name(pocket_type: int) -> String:
	match pocket_type:
		Pocket.PocketType.REFUND:
			return "REFUND"
		Pocket.PocketType.CRIT:
			return "CRIT"
		Pocket.PocketType.CASHOUT:
			return "CASHOUT"
		_:
			return "?"

func _configure_encounter_hazards(node_type: int) -> void:
	var strength: float = 0.0
	strength += float(act_idx - 1) * 0.24
	strength += float(maxi(0, difficulty_league - 1)) * 0.20
	strength += threat_meter * 0.18
	if node_type == NodeType.BOSS:
		strength += 0.28
	elif node_type == NodeType.ELITE:
		strength += 0.12
	board.hazard_strength = clampf(strength, 0.0, 1.0)
	board.enable_moving_bumpers = act_idx >= 2 or difficulty_league >= 2
	board.enable_lane_gate = act_idx >= 3 or difficulty_league >= 3 or node_type == NodeType.BOSS

	pocket_lock_type = -1
	if (act_idx >= 3 or difficulty_league >= 3) and (node_type == NodeType.ELITE or node_type == NodeType.BOSS or randf() < 0.22):
		pocket_lock_type = randi() % 3

	encounter_tilt = 0.0
	if act_idx >= 2 or difficulty_league >= 2:
		encounter_tilt = randf_range(-0.55, 0.55) * (0.35 + board.hazard_strength * 0.5)

func _setup_chain_links() -> void:
	chain_links.clear()
	if not has_link_chain:
		return
	var pegs: Array[Peg] = board.get_random_pegs(9999)
	if pegs.size() < 2:
		return
	var pair_count: int = mini(10, int(pegs.size() / 2))
	for i in range(pair_count):
		var a: Peg = pegs[i * 2]
		var b: Peg = pegs[i * 2 + 1]
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		chain_links[a.get_instance_id()] = b.get_instance_id()
		chain_links[b.get_instance_id()] = a.get_instance_id()

func _try_chain_reactions(source_peg: Peg) -> void:
	if source_peg == null or not is_instance_valid(source_peg):
		return
	var source_id: int = source_peg.get_instance_id()
	if has_volatile_chain and randf() < 0.38:
		var nearby: Array[Peg] = _find_nearby_pegs(source_peg, 2, 170.0)
		for peg in nearby:
			_apply_chain_hit(peg, 0.50, "BOOM", Color(1.0, 0.62, 0.28))
		if not nearby.is_empty():
			_spawn_impact_burst(source_peg.global_position, Color(1.0, 0.58, 0.2, 0.65), 1.3)

	if has_link_chain and chain_links.has(source_id) and not chain_lockouts.has(source_id):
		var linked_id: int = int(chain_links.get(source_id, 0))
		if linked_id != 0:
			var linked_obj: Object = instance_from_id(linked_id)
			if linked_obj != null and is_instance_valid(linked_obj):
				var linked: Peg = linked_obj as Peg
				if linked != null:
					chain_lockouts[source_id] = true
					chain_lockouts[linked_id] = true
					_apply_chain_hit(linked, 0.58, "LINK", Color(0.68, 0.96, 1.0))
					_spawn_link_beam(source_peg.global_position, linked.global_position, Color(0.68, 0.92, 1.0, 0.9))

	if has_lightning_chain and turn_combo > 0 and turn_combo % 5 == 0:
		var zapped: Peg = _closest_peg_excluding(source_peg, 260.0)
		if zapped != null:
			_apply_chain_hit(zapped, 0.66, "ZAP", Color(0.80, 0.66, 1.0))
			_spawn_link_beam(source_peg.global_position, zapped.global_position, Color(0.76, 0.62, 1.0, 0.95))

	if has_domino_chain and turn_combo > 0 and turn_combo % 7 == 0:
		var domino: Array[Peg] = _find_nearby_pegs(source_peg, 3, 260.0)
		for peg in domino:
			_apply_chain_hit(peg, 0.44, "DOMINO", Color(1.0, 0.86, 0.42))

func _apply_chain_hit(peg: Peg, scalar: float, tag: String, color: Color) -> void:
	if peg == null or not is_instance_valid(peg):
		return
	var scale := scalar * chain_power_multiplier
	if scale <= 0.02:
		return
	var tier_scale: float = 1.0 + float(peg.tier) * 0.16
	match peg.peg_type:
		Peg.PegType.DAMAGE:
			var add_damage: int = int(round(damage_peg_power * 0.52 * scale * tier_scale))
			turn_damage += maxi(1, add_damage)
			EventBus.peg_hit.emit(int(peg.peg_type), float(add_damage), peg.global_position)
		Peg.PegType.GOLD:
			var add_gold: int = int(round(gold_peg_value * 0.9 * scale * tier_scale))
			turn_gold += maxi(1, add_gold)
			EventBus.peg_hit.emit(int(peg.peg_type), float(add_gold), peg.global_position)
		Peg.PegType.SHIELD:
			var add_shield: int = int(round(shield_peg_value * 0.8 * scale * tier_scale))
			_add_player_shield(float(maxi(1, add_shield)))
			EventBus.peg_hit.emit(int(peg.peg_type), float(add_shield), peg.global_position)
		Peg.PegType.MULTIPLIER:
			var add_mult: float = multiplier_peg_gain * 0.42 * scale * tier_scale
			turn_multiplier += maxf(0.02, add_mult)
			EventBus.peg_hit.emit(int(peg.peg_type), add_mult, peg.global_position)
	peg.call("_play_hit_squash")
	_pop_text(tag, peg.global_position + Vector2(0, -22), color, 18)

func _apply_pocket_echo(pocket_type: int, scale: float) -> void:
	match pocket_type:
		Pocket.PocketType.REFUND:
			var refund := maxi(1, int(round(scale)))
			ammo += refund
			_pop_text("REFUND", launcher.global_position + Vector2(0, 40), Color(0.7, 1.0, 0.7), 20)
		Pocket.PocketType.CRIT:
			turn_multiplier *= (1.0 + (crit_multiplier - 1.0) * scale)
			_pop_text("ECHO CRIT", launcher.global_position + Vector2(0, 40), Color(1.0, 0.7, 0.9), 20)
		Pocket.PocketType.CASHOUT:
			var bonus_gold := int(round((turn_multiplier - 1.0) * cashout_rate * scale))
			turn_gold += maxi(0, bonus_gold)
			_pop_text("ECHO $", launcher.global_position + Vector2(0, 40), Color(1.0, 0.9, 0.4), 20)
		_:
			pass

func _find_nearby_pegs(center_peg: Peg, limit: int, max_dist: float) -> Array[Peg]:
	var nearby: Array[Peg] = []
	if center_peg == null or not is_instance_valid(center_peg):
		return nearby
	var all_pegs: Array[Peg] = board.get_random_pegs(9999)
	var dist_map: Dictionary = {}
	for peg in all_pegs:
		if peg == center_peg:
			continue
		if not is_instance_valid(peg):
			continue
		var dist := center_peg.global_position.distance_to(peg.global_position)
		if dist <= max_dist:
			nearby.append(peg)
			dist_map[peg.get_instance_id()] = dist
	if nearby.size() <= limit:
		return nearby
	var picked: Array[Peg] = []
	while picked.size() < limit and not nearby.is_empty():
		var best_idx := 0
		var best_dist := float(dist_map.get(nearby[0].get_instance_id(), 999999.0))
		for i in range(1, nearby.size()):
			var d := float(dist_map.get(nearby[i].get_instance_id(), 999999.0))
			if d < best_dist:
				best_dist = d
				best_idx = i
		picked.append(nearby[best_idx])
		nearby.remove_at(best_idx)
	return picked

func _closest_peg_excluding(center_peg: Peg, max_dist: float) -> Peg:
	var candidates: Array[Peg] = _find_nearby_pegs(center_peg, 1, max_dist)
	if candidates.is_empty():
		return null
	return candidates[0]

func _spawn_link_beam(a: Vector2, b: Vector2, color: Color) -> void:
	var points: PackedVector2Array = _build_lightning_points(a, b, 6, 14.0)
	var glow := Line2D.new()
	glow.width = 10.0
	glow.default_color = Color(color.r, color.g, color.b, 0.45)
	for p in points:
		glow.add_point(p)
	glow.antialiased = true
	glow.z_index = 39
	$Balls.add_child(glow)

	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	for p in points:
		line.add_point(p)
	line.antialiased = true
	line.z_index = 40
	var lightning_tex: Texture2D = _get_lightning_texture()
	if lightning_tex != null:
		line.texture = lightning_tex
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.default_color = Color(1.0, 1.0, 1.0, 0.95)
	$Balls.add_child(line)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(line, "modulate:a", 0.0, 0.20)
	tw.tween_property(glow, "modulate:a", 0.0, 0.20)
	tw.tween_property(line, "width", 0.8, 0.20)
	tw.finished.connect(func():
		if is_instance_valid(line):
			line.queue_free()
		if is_instance_valid(glow):
			glow.queue_free()
	)

func _build_lightning_points(a: Vector2, b: Vector2, segments: int, amplitude: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir: Vector2 = b - a
	var normal: Vector2 = Vector2(-dir.y, dir.x).normalized()
	if normal.length_squared() < 0.0001:
		normal = Vector2.UP
	pts.append(a)
	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var base: Vector2 = a.lerp(b, t)
		var jitter: float = randf_range(-amplitude, amplitude) * (1.0 - abs(0.5 - t) * 1.2)
		pts.append(base + normal * jitter)
	pts.append(b)
	return pts

func _get_lightning_texture() -> Texture2D:
	if lightning_texture_cache != null:
		return lightning_texture_cache
	if ResourceLoader.exists(LIGHTNING_TEXTURE_PATH):
		lightning_texture_cache = load(LIGHTNING_TEXTURE_PATH) as Texture2D
	return lightning_texture_cache

func _node_id_to_enum(node_id: String) -> int:
	match node_id:
		"fight":
			return NodeType.FIGHT
		"elite":
			return NodeType.ELITE
		"event":
			return NodeType.EVENT
		"shop":
			return NodeType.SHOP
		"rest":
			return NodeType.REST
		"treasure":
			return NodeType.TREASURE
		_:
			return NodeType.FIGHT

func _choice_button_text(context: String, pick: String) -> String:
	match context:
		"meta":
			return "%s\n%s" % [_meta_title(pick), _meta_desc(pick)]
		"starter_build":
			return "%s\n%s" % [_starter_build_title(pick), _starter_build_desc(pick)]
		"character":
			return "%s\n%s" % [_character_title(pick), _character_desc(pick)]
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
		"rest":
			return "%s\n%s" % [_rest_title(pick), _rest_desc(pick)]
		"treasure":
			return "%s\n%s" % [_upgrade_title(pick), _upgrade_desc(pick)]
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
			var cost_hp := MetaManager.perk_cost("start_hp")
			return "Cost %d shards. +5 start HP. Lv %d/2." % [cost_hp, meta_hp_level]
		"meta_split":
			var cost_split := MetaManager.perk_cost("split_resonance")
			return "Cost %d shards. More split pegs. Lv %d/3." % [cost_split, meta_split_level]
		"meta_continue":
			return "Keep shards and choose a fused starter build."
		_:
			return ""

func _starter_build_title(build_id: String) -> String:
	match build_id:
		"striker_split":
			return "Striker // Split"
		"hustler_greed":
			return "Hustler // Greed"
		"guardian_vamp":
			return "Guardian // Vamp"
		"showman_box_hunter":
			return "Showman // Box Hunter"
		_:
			return "Starter Build"

func _starter_build_desc(build_id: String) -> String:
	match build_id:
		"striker_split":
			return "+5% damage pegs. Every 3rd hit bursts + multiplier."
		"hustler_greed":
			return "Gold cycle bonus + greed economy. Damage tradeoff."
		"guardian_vamp":
			return "Healing-focused sustain with safer long fights."
		"showman_box_hunter":
			return "Combo-forward style with more moving-box rewards."
		_:
			return ""

func _apply_starter_build(build_id: String) -> void:
	match build_id:
		"striker_split":
			_apply_character("striker")
			_apply_loadout("split")
		"hustler_greed":
			_apply_character("hustler")
			_apply_loadout("greed")
		"guardian_vamp":
			_apply_character("guardian")
			_apply_loadout("vamp")
		"showman_box_hunter":
			_apply_character("showman")
			_apply_loadout("box_hunter")
		_:
			_apply_character("striker")
			_apply_loadout("split")
	_show_message("Build selected: %s" % _starter_build_title(build_id))

func _loadout_title(loadout_id: String) -> String:
	match loadout_id:
		"split":
			return "Split Ball"
		"greed":
			return "Greed Ball"
		"vamp":
			return "Vamp Ball"
		"box_hunter":
			return "Box Hunter"
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
		"box_hunter":
			return "More moving boxes, fewer pegs."
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
		"box_hunter":
			selected_loadout = LoadoutType.BOX_HUNTER
			board.split_peg_chance_bonus += 0.05
	_show_message("Loadout: %s" % _loadout_title(loadout_id))

func _character_title(character_id: String) -> String:
	match character_id:
		"striker":
			return "Striker"
		"hustler":
			return "Hustler"
		"guardian":
			return "Guardian"
		"showman":
			return "Showman"
		_:
			return "Driver"

func _character_desc(character_id: String) -> String:
	match character_id:
		"striker":
			return "Hot pink ball. +5% damage peg value."
		"hustler":
			return "Gold ball. Every 3 gold pegs: +1 gold."
		"guardian":
			return "Cyan ball. First gold peg each drop heals +1 HP."
		"showman":
			return "Purple ball. Mult pegs add extra +0.05."
		_:
			return ""

func _apply_character(character_id: String) -> void:
	match character_id:
		"striker":
			selected_character = CharacterType.STRIKER
			character_ball_fill = Color("ff6ca6")
			character_ball_rim = Color("ffc2d8")
			character_trail_tint = Color("ff9dc0")
		"hustler":
			selected_character = CharacterType.HUSTLER
			character_ball_fill = Color("fbcf4a")
			character_ball_rim = Color("fff4b6")
			character_trail_tint = Color("ffe088")
			character_shop_discount_bonus = 0.04
			shop_discount += character_shop_discount_bonus
		"guardian":
			selected_character = CharacterType.GUARDIAN
			character_ball_fill = Color("7ed5ff")
			character_ball_rim = Color("d6f6ff")
			character_trail_tint = Color("9be6ff")
			player_hp += 6
		"showman":
			selected_character = CharacterType.SHOWMAN
			character_ball_fill = Color("bb8cff")
			character_ball_rim = Color("e8d7ff")
			character_trail_tint = Color("d3adff")
			combo_bonus += 0.20
			multiplier_peg_gain += 0.03
	_show_message("Driver: %s" % _character_title(character_id))

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
		"peg_split",
		"peg_burst",
		"peg_echo",
		"peg_pinball",
		"peg_orbit",
		"peg_boom",
		"peg_chain",
		"peg_multi_plus",
		"peg_cashout",
		"peg_crit",
		"peg_refund",
		"peg_overdrive",
		"peg_ghost",
		"peg_magnet",
		"legend_chain_reaction",
		"legend_portal_core",
		"legend_fractal_engine",
		"magnet_core",
		"heavy_shell",
		"echo_chamber",
		"siphon_matrix",
		"ricochet_drive",
		"overclock_coil",
		"link_network",
		"volatile_array",
		"shielded_shell",
		"jackpot_protocol",
			"combo_lock_relay",
			"shard_harvester",
			"chain_volatile",
			"chain_link",
			"chain_lightning",
			"chain_domino",
			"aegis_coating",
			"pin_prism",
			"neon_overdrive",
			"coin_armor",
			"jackpot_guard",
			"threat_burner",
		]

func _pick_upgrades_weighted(count: int, pool: Array[String]) -> Array[String]:
	var weighted_pool: Array[String] = []
	for id in pool:
		var weight: int = 1
		var tags := _upgrade_tags(id)
		for tag in tags:
			var stack := int(upgrade_tag_counts.get(tag, 0))
			if stack >= 2:
				weight += 2
			elif stack == 1:
				weight += 1
		for _i in range(weight):
			weighted_pool.append(id)
	weighted_pool.shuffle()
	var picks: Array[String] = []
	for id in weighted_pool:
		if not picks.has(id):
			picks.append(id)
		if picks.size() >= count:
			break
	if picks.size() < count:
		for id in pool:
			if not picks.has(id):
				picks.append(id)
			if picks.size() >= count:
				break
	return picks

func _upgrade_tags(upgrade_id: String) -> Array[String]:
	match upgrade_id:
		"peg_split", "peg_burst", "peg_echo", "peg_pinball", "peg_orbit", "peg_boom", "peg_chain", "peg_multi_plus", "peg_cashout", "peg_crit", "peg_refund", "peg_overdrive", "peg_ghost", "peg_magnet":
			return ["peg", "combo"]
		"combo_furnace", "turbo_multiplier":
			return ["combo"]
		"critical_core", "cashout_engine":
			return ["cashout"]
		"split_forge", "twin_launcher", "legend_fractal_engine":
			return ["split"]
		"refund_reactor", "double_load":
			return ["control"]
		"gold_rush", "legend_chain_reaction":
			return ["economy"]
		"magnet_core", "ricochet_drive", "combo_lock_relay":
			return ["combo"]
		"echo_chamber", "jackpot_protocol":
			return ["cashout"]
		"siphon_matrix", "shielded_shell":
			return ["control"]
		"heavy_shell", "volatile_array", "overclock_coil":
			return ["split"]
		"link_network", "shard_harvester":
			return ["economy"]
		"chain_volatile", "chain_lightning", "chain_domino":
			return ["combo"]
		"chain_link":
			return ["control"]
		"aegis_coating", "coin_armor", "jackpot_guard":
			return ["control"]
		"pin_prism", "neon_overdrive":
			return ["combo"]
		"threat_burner":
			return ["economy"]
		_:
			return []

func _apply_tag_synergy(tag: String) -> void:
	var count := int(upgrade_tag_counts.get(tag, 0))
	if count != 3:
		return
	match tag:
		"combo":
			multiplier_peg_gain += 0.10
			_show_message("Synergy: Combo Core online (+0.10 mult gain).")
		"cashout":
			cashout_rate += 6.0
			_show_message("Synergy: Cashout Core online (+6 cashout).")
		"split":
			max_extra_balls_per_turn += 2
			_show_message("Synergy: Split Core online (+2 extra balls).")
		"control":
			starting_ammo += 1
			_show_message("Synergy: Control Core online (+1 ball).")
		"economy":
			gold += 40
			_show_message("Synergy: Economy Core online (+40 gold).")

func _upgrade_title(upgrade_id: String) -> String:
	match upgrade_id:
		"peg_split":
			return "Split Pegs"
		"peg_burst":
			return "Burst Pegs"
		"peg_echo":
			return "Echo Pegs"
		"peg_pinball":
			return "Pinball Pegs"
		"peg_orbit":
			return "Orbit Pegs"
		"peg_boom":
			return "Boom Pegs"
		"peg_chain":
			return "Chain Pegs"
		"peg_multi_plus":
			return "Multi+ Pegs"
		"peg_cashout":
			return "Cashout Pegs"
		"peg_crit":
			return "Crit Pegs"
		"peg_refund":
			return "Refund Pegs"
		"peg_overdrive":
			return "Overdrive Pegs"
		"peg_ghost":
			return "Ghost Pegs"
		"peg_magnet":
			return "Magnet Pegs"
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
		"magnet_core":
			return "Magnet Core"
		"heavy_shell":
			return "Heavy Shell"
		"echo_chamber":
			return "Echo Chamber"
		"siphon_matrix":
			return "Siphon Matrix"
		"ricochet_drive":
			return "Ricochet Drive"
		"overclock_coil":
			return "Overclock Coil"
		"link_network":
			return "Link Network"
		"volatile_array":
			return "Volatile Array"
		"shielded_shell":
			return "Shielded Shell"
		"jackpot_protocol":
			return "Jackpot Protocol"
		"combo_lock_relay":
			return "Combo Lock Relay"
		"shard_harvester":
			return "Shard Harvester"
		"chain_volatile":
			return "Chain: Volatile"
		"chain_link":
			return "Chain: Link Network"
		"chain_lightning":
			return "Chain: Lightning"
		"chain_domino":
			return "Chain: Domino Run"
		"aegis_coating":
			return "Aegis Coating"
		"pin_prism":
			return "Pin Prism"
		"neon_overdrive":
			return "Neon Overdrive"
		"coin_armor":
			return "Coin Armor"
		"jackpot_guard":
			return "Jackpot Guard"
		"threat_burner":
			return "Threat Burner"
		_:
			return "Mysterious Relic"

func _upgrade_desc(upgrade_id: String) -> String:
	match upgrade_id:
		"peg_split":
			return "Split pegs spawn a mini-ball on hit."
		"peg_burst":
			return "Burst pegs fire two balls in a spread."
		"peg_echo":
			return "Echo pegs repeat your last pocket at 40%."
		"peg_pinball":
			return "Pinball pegs give a short super-bounce boost."
		"peg_orbit":
			return "Orbit pegs swirl the ball for extra hits."
		"peg_boom":
			return "Boom pegs trigger nearby pegs with a blast."
		"peg_chain":
			return "Chain pegs zap a nearby peg."
		"peg_multi_plus":
			return "Multi+ pegs add a big combo bump."
		"peg_cashout":
			return "Cashout pegs add bonus gold per hit."
		"peg_crit":
			return "Crit pegs boost your crit multiplier."
		"peg_refund":
			return "Refund pegs grant extra balls."
		"peg_overdrive":
			return "Overdrive pegs spike heat + multiplier."
		"peg_ghost":
			return "Ghost pegs add multiplier without bounce."
		"peg_magnet":
			return "Magnet pegs add a small pull bonus."
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
			return "Refund pocket +1 ball."
		"double_load":
			return "+1 starting ball."
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
		"magnet_core":
			return "Multiplier gain +0.07 and combo scaling +0.20."
		"heavy_shell":
			return "Damage +20%, but mult gain -0.03."
		"echo_chamber":
			return "Cashout +4 and crit pocket +0.20."
		"siphon_matrix":
			return "Gain 1 HP on every pocket landing."
		"ricochet_drive":
			return "Start each drop with +x0.12 multiplier."
		"overclock_coil":
			return "Damage +2 and +1 max extra balls."
		"link_network":
			return "Gold pegs stronger and combo scaling up."
		"volatile_array":
			return "Damage +1.5 and multiplier +0.05."
		"shielded_shell":
			return "+18 HP and take 8% less damage."
		"jackpot_protocol":
			return "Cashout +10. Better moving-box jackpots."
		"combo_lock_relay":
			return "Next drop starts at combo 8."
		"shard_harvester":
			return "Moving boxes grant +1 extra shard."
		"chain_volatile":
			return "Peg hits can explode into nearby pegs."
		"chain_link":
			return "Some pegs link and trigger each other."
		"chain_lightning":
			return "Every 5th hit zaps a nearby peg."
		"chain_domino":
			return "Every 7th hit runs a short peg domino."
		"aegis_coating":
			return "Shield pegs +40% and +10% damage reduction."
		"pin_prism":
			return "Upgrade 6 random pegs +1 tier instantly."
		"neon_overdrive":
			return "All pegs glow hotter: +0.04 mult, +1.2 damage, +0.4 shield."
		"coin_armor":
			return "Gold pegs grant +1 block."
		"jackpot_guard":
			return "Cashout grants block based on multiplier."
		"threat_burner":
			return "Lower Threat and Heat, gain gold."
		_:
			return ""

func _apply_upgrade(upgrade_id: String) -> void:
	var unlocked_special := false
	match upgrade_id:
		"peg_split":
			has_split_peg_effect = true
			unlocked_special = true
		"peg_burst":
			has_burst_peg_effect = true
			unlocked_special = true
		"peg_echo":
			has_echo_peg_effect = true
			unlocked_special = true
		"peg_pinball":
			has_pinball_peg_effect = true
			unlocked_special = true
		"peg_orbit":
			has_orbit_peg_effect = true
			unlocked_special = true
		"peg_boom":
			has_boom_peg_effect = true
			unlocked_special = true
		"peg_chain":
			has_chain_peg_effect = true
			unlocked_special = true
		"peg_multi_plus":
			has_multi_plus_peg_effect = true
			unlocked_special = true
		"peg_cashout":
			has_cashout_peg_effect = true
			unlocked_special = true
		"peg_crit":
			has_crit_peg_effect = true
			unlocked_special = true
		"peg_refund":
			has_refund_peg_effect = true
			unlocked_special = true
		"peg_overdrive":
			has_overdrive_peg_effect = true
			unlocked_special = true
		"peg_ghost":
			has_ghost_peg_effect = true
			unlocked_special = true
		"peg_magnet":
			has_magnet_peg_effect = true
			unlocked_special = true
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
		"magnet_core":
			multiplier_peg_gain += 0.07
			combo_bonus += 0.20
		"heavy_shell":
			damage_peg_power *= 1.20
			multiplier_peg_gain = maxf(0.05, multiplier_peg_gain - 0.03)
		"echo_chamber":
			cashout_rate += 4.0
			crit_multiplier += 0.20
		"siphon_matrix":
			player_hp += 8
			has_siphon_matrix = true
		"ricochet_drive":
			start_turn_multiplier_bonus += 0.12
		"overclock_coil":
			damage_peg_power += 2.0
			max_extra_balls_per_turn += 1
		"link_network":
			gold_peg_value += 0.7
			combo_bonus += 0.20
		"volatile_array":
			damage_peg_power += 1.5
			multiplier_peg_gain += 0.05
		"shielded_shell":
			player_hp += 18
			player_damage_reduction = minf(0.35, player_damage_reduction + 0.08)
		"jackpot_protocol":
			cashout_rate += 10.0
		"combo_lock_relay":
			next_drop_combo_seed = maxi(next_drop_combo_seed, 8)
		"shard_harvester":
			box_shard_bonus_per_hit += 1
		"chain_volatile":
			has_volatile_chain = true
		"chain_link":
			has_link_chain = true
			_setup_chain_links()
		"chain_lightning":
			has_lightning_chain = true
		"chain_domino":
			has_domino_chain = true
		"aegis_coating":
			shield_peg_value *= 1.40
			player_damage_reduction = minf(0.45, player_damage_reduction + 0.10)
		"pin_prism":
			for peg in board.get_random_pegs(6):
				if is_instance_valid(peg):
					peg.tier = mini(3, peg.tier + 1)
					peg.danger_level = minf(1.5, peg.danger_level + 0.08)
		"neon_overdrive":
			multiplier_peg_gain += 0.04
			damage_peg_power += 1.2
			shield_peg_value += 0.4
			for peg in board.get_random_pegs(999):
				if is_instance_valid(peg):
					peg.danger_level = minf(1.5, peg.danger_level + 0.10)
		"coin_armor":
			has_coin_armor = true
		"jackpot_guard":
			has_jackpot_guard = true
		"threat_burner":
			threat_meter = maxf(0.0, threat_meter - 0.45)
			heat_meter = maxf(0.0, heat_meter - 0.20)
			gold += 35

	if unlocked_special and in_combat:
		_refresh_special_pegs()

	var tags := _upgrade_tags(upgrade_id)
	for tag in tags:
		upgrade_tag_counts[tag] = int(upgrade_tag_counts.get(tag, 0)) + 1
		_apply_tag_synergy(tag)

func _refresh_special_pegs() -> void:
	var pool := _special_ids()
	if pool.is_empty():
		return
	var count := _special_count_for_node(current_node_type)
	if count <= 0:
		return
	var pegs: Array[Peg] = board.get_random_pegs(9999)
	if pegs.is_empty():
		return
	pegs.shuffle()
	var pick_count := mini(count, pegs.size())
	for i in range(pick_count):
		var peg := pegs[i]
		if peg == null:
			continue
		var special := pool[randi() % pool.size()]
		peg.special_effect = special as Peg.SpecialEffect

func _room_title(room_id: String) -> String:
	match room_id:
		"fight":
			return "Fight"
		"elite":
			return "Elite"
		"event":
			return "Event"
		"shop":
			return "Shop"
		"rest":
			return "Rest"
		"treasure":
			return "Treasure"
		_:
			return "Room"

func _room_desc(room_id: String) -> String:
	match room_id:
		"fight":
			return "Battle for bounty + upgrade."
		"elite":
			return "Hard fight, huge payout."
		"event":
			return "Risky choice, big swing."
		"shop":
			return "Spend gold on permanent boosts."
		"rest":
			return "Recover and prep for combat."
		"treasure":
			return "Premium free upgrade."
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
			return "Ball Flask"
		_:
			return "Shop"

func _shop_desc(shop_id: String) -> String:
	match shop_id:
		"shop_damage":
			return "40g: damage pegs +45%."
		"shop_multiplier":
			return "45g: multiplier pegs +0.20."
		"shop_refund":
			return "35g: +1 starting ball."
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
	cost = maxi(1, int(round(float(cost) * (1.0 - shop_discount))))
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
			_show_message("Purchased Ball Flask.")

func _rest_title(rest_id: String) -> String:
	match rest_id:
		"rest_heal":
			return "Repair Bay"
		"rest_ammo":
			return "Ball Refill"
		"rest_focus":
			return "Focus Core"
		_:
			return "Rest"

func _rest_desc(rest_id: String) -> String:
	match rest_id:
		"rest_heal":
			return "Restore 26 HP."
		"rest_ammo":
			return "+1 starting ball."
		"rest_focus":
			return "Combo +0.35 and mult gain +0.05."
		_:
			return ""

func _resolve_rest_pick(rest_id: String) -> void:
	match rest_id:
		"rest_heal":
			player_hp += 26
			_show_message("Repair Bay restored 26 HP.")
		"rest_ammo":
			starting_ammo += 1
			_show_message("Ball systems expanded (+1 start ball).")
		"rest_focus":
			combo_bonus += 0.35
			multiplier_peg_gain += 0.05
			_show_message("Focus Core stabilized your combo engine.")

func _try_buy_perk(perk_id: String) -> void:
	var ok := MetaManager.buy_perk(perk_id)
	_refresh_meta_cache()
	if ok:
		_show_message("Purchased perk: %s." % _perk_title(perk_id))
	else:
		_show_message(_meta_error_text())
	_show_meta_shop_menu()

func _try_unlock(unlock_id: String) -> void:
	var ok := MetaManager.unlock_item(unlock_id)
	_refresh_meta_cache()
	if ok:
		_show_message("Unlocked: %s." % _unlock_title(unlock_id))
	else:
		_show_message(_meta_error_text())
	_show_unlocks_menu()

func _try_pick_skill(skill_id: String) -> void:
	var ok := MetaManager.pick_skill(skill_id)
	_refresh_meta_cache()
	if ok:
		_show_message("Skill learned: %s." % _skill_title(skill_id))
	else:
		_show_message(_meta_error_text())
	if pending_skill_points > 0:
		_show_skill_menu()
	else:
		_show_run_summary_menu(run_was_victory)

func _meta_error_text() -> String:
	match MetaManager.last_error:
		"level_locked":
			return "Level too low for that purchase."
		"max_tier":
			return "That perk is already maxed."
		"already_unlocked":
			return "Already unlocked."
		"no_skill_points":
			return "No skill points available."
		"not_enough_shards":
			return "Not enough shards."
		_:
			return "Cannot purchase right now."

func _resolve_meta_pick(pick: String) -> void:
	match pick:
		"meta_hp":
			if MetaManager.buy_perk("start_hp"):
				_refresh_meta_cache()
				_show_message("Vitality unlocked.")
				_show_meta_choices()
			else:
				_show_message(_meta_error_text())
				_show_meta_choices()
		"meta_split":
			if MetaManager.buy_perk("split_resonance"):
				_refresh_meta_cache()
				_show_message("Split resonance unlocked.")
				_show_meta_choices()
			else:
				_show_message(_meta_error_text())
				_show_meta_choices()
		"meta_continue":
			_show_starter_build_choices()

func _build_power_score() -> float:
	var score := 0.0
	score += damage_peg_power * 1.18
	score += multiplier_peg_gain * 84.0
	score += shield_peg_value * 18.0
	score += combo_bonus * 48.0
	score += float(base_balls_per_drop) * 16.0
	score += float(starting_ammo) * 10.0
	score += float(player_run_state.get("shield", 0.0)) * 0.45
	if legendary_chain_reaction:
		score += 26.0
	if legendary_portal_core:
		score += 24.0
	if legendary_fractal_engine:
		score += 32.0
	return score

func _apply_build_pressure(is_boss_checkpoint: bool = false) -> void:
	var target := 64.0 + float(encounter_idx) * 12.0 + float(act_idx - 1) * 28.0
	if is_boss_checkpoint:
		target += 34.0
	var score := _build_power_score()
	threat_meter += heat_meter * 0.02
	if score < target:
		threat_meter += 0.11
		_show_message("Pressure rising: your build needs more scaling.")
	elif score > target * 1.32:
		threat_meter = maxf(0.0, threat_meter - 0.05)

func _scaled_shards(base_amount: int) -> int:
	return maxi(1, int(round(float(base_amount) * league_reward_multiplier)))

func _scaled_xp(base_amount: int) -> int:
	var mult := 1.0 + float(maxi(0, difficulty_league - 1)) * 0.10
	return maxi(1, int(round(float(base_amount) * mult)))

func _award_progress_for_node(node_type: int) -> void:
	match node_type:
		NodeType.FIGHT:
			_award_meta_shards(_scaled_shards(4))
			_award_player_xp(_scaled_xp(12))
		NodeType.ELITE:
			run_elites_cleared += 1
			_award_meta_shards(_scaled_shards(10))
			_award_player_xp(_scaled_xp(26))
		NodeType.EVENT:
			_award_meta_shards(_scaled_shards(2))
			_award_player_xp(_scaled_xp(8))
		NodeType.SHOP:
			_award_player_xp(_scaled_xp(6))
		NodeType.REST:
			_award_player_xp(_scaled_xp(6))
		NodeType.TREASURE:
			_award_meta_shards(_scaled_shards(6))
			_award_player_xp(_scaled_xp(14))
		NodeType.BOSS:
			_award_meta_shards(_scaled_shards(18 + act_idx * 3))
			_award_player_xp(_scaled_xp(60))

func _award_meta_shards(amount: int) -> void:
	if amount <= 0:
		return
	run_shards_earned += amount
	MetaManager.add_shards(amount)
	meta_shards = MetaManager.shards_total
	_show_message("Gained %d shards." % amount)

func _award_player_xp(amount: int) -> void:
	if amount <= 0:
		return
	run_xp_earned += amount
	var gained_levels := MetaManager.add_xp(amount)
	_refresh_meta_cache()
	if gained_levels > 0:
		_show_message("Level Up! You reached level %d." % player_level)

func _load_meta_progress() -> void:
	MetaManager.load_meta()
	_refresh_meta_cache()

func _save_meta_progress() -> void:
	MetaManager.save_meta()

func _refresh_meta_cache() -> void:
	meta_shards = MetaManager.shards_total
	meta_hp_level = MetaManager.perk_tier("start_hp")
	meta_gold_level = MetaManager.perk_tier("start_gold")
	meta_split_level = MetaManager.perk_tier("split_resonance")
	player_level = MetaManager.player_level
	player_xp = MetaManager.xp
	selected_league = MetaManager.selected_league
	pending_skill_points = MetaManager.pending_skill_points

func _add_player_shield(amount: float) -> void:
	if amount <= 0.0:
		return
	var current: float = float(player_run_state.get("shield", 0.0))
	player_run_state["shield"] = current + amount
	_update_shield_ui()

func _decay_player_shield_after_fight() -> void:
	var current: float = float(player_run_state.get("shield", 0.0))
	if current <= 0.0:
		return
	var decayed: float = floor(current * 0.60)
	if decayed >= current:
		return
	player_run_state["shield"] = decayed
	_pop_text("BLOCK %d->%d" % [int(round(current)), int(round(decayed))], Vector2(540, 248), Color(0.66, 0.92, 1.0), 18)
	_update_shield_ui()

func _setup_shield_ui() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top_vbox.add_child(row)

	shield_label = Label.new()
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shield_label.custom_minimum_size = Vector2(160, 30)
	shield_label.add_theme_font_size_override("font_size", 20)
	shield_label.add_theme_color_override("font_color", Color(0.74, 0.94, 1.0))
	row.add_child(shield_label)

	shield_bar = ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(280, 18)
	shield_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shield_bar.min_value = 0.0
	shield_bar.max_value = 40.0
	shield_bar.show_percentage = false
	row.add_child(shield_bar)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.28, 0.70, 1.0, 0.92)
	fill_style.set_corner_radius_all(8)
	shield_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.14, 0.22, 0.84)
	bg_style.set_corner_radius_all(8)
	shield_bar.add_theme_stylebox_override("background", bg_style)
	_update_shield_ui()
	row.visible = false

func _update_shield_ui() -> void:
	if shield_label == null or shield_bar == null:
		return
	var value: float = float(player_run_state.get("shield", 0.0))
	shield_label.text = "BLOCK %d" % int(round(value))
	shield_bar.max_value = maxf(25.0, value + 20.0)
	shield_bar.value = value

func _flash_shield_bar() -> void:
	if shield_bar == null:
		return
	shield_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(shield_bar, "modulate", Color(0.62, 0.92, 1.0, 1.0), 0.08)
	tween.tween_property(shield_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

func _setup_combo_ui() -> void:
	_update_combo_ui()

func _update_combo_ui() -> void:
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
	var ratio := clampf(float(turn_combo) / 20.0, 0.0, 1.0)
	if combo_label:
		combo_label.text = "OVERDRIVE %s" % tier_name
		combo_label.modulate = color
	if overdrive_label:
		overdrive_label.text = "OVERDRIVE %s  %d%%" % [tier_name, int(round(ratio * 100.0))]
		overdrive_label.modulate = color

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

func _shake(strength: float) -> void:
	EventBus.shake_requested.emit(clampf(strength / 20.0, 0.05, 1.0), 0.12)

func _pop_text(text: String, world_pos: Vector2, color: Color, font_size: int = 24) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	label.position = _world_to_hud_pos(world_pos) + Vector2(-110, -20)
	$HUD/Root.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 65.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.finished.connect(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _world_to_hud_pos(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos

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
