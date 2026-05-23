extends Control
## Game-over modal. `show_summary(data)` fills the labels and fades the panel in;
## the panel signals back when the player picks PLAY AGAIN or MENU.
##
## `data` keys:
##   score, best_hand_name, best_hand_score, is_new_best,
##   xp_gained, xp_from_score, xp_from_hands,
##   previous_level, new_level, leveled_up

signal play_again_pressed
signal menu_pressed

@onready var title_label: Label = $Panel/VBox/Title
@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var best_badge: Label = $Panel/VBox/BestBadge
@onready var best_hand_label: Label = $Panel/VBox/BestHandLabel
@onready var xp_label: Label = $Panel/VBox/XpLabel
@onready var level_label: Label = $Panel/VBox/LevelLabel
@onready var play_again_button: Button = $Panel/VBox/ButtonRow/PlayAgainButton
@onready var menu_button: Button = $Panel/VBox/ButtonRow/MenuButton


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)
	visible = false


func show_summary(data: Dictionary) -> void:
	var reason: String = String(data.get("reason", "column_overflow"))
	if reason == "dealer_won":
		title_label.text = "DEALER WINS"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.50))
	else:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))

	score_label.text = "Score  %d" % int(data.get("score", 0))
	best_badge.visible = bool(data.get("is_new_best", false))

	var bh_name: String = data.get("best_hand_name", "")
	var bh_score: int = int(data.get("best_hand_score", 0))
	if bh_name.is_empty():
		best_hand_label.text = "No scoring hands this run"
		best_hand_label.modulate = Color(0.55, 0.60, 0.72)
	else:
		best_hand_label.text = "Best hand: %s   +%d" % [bh_name, bh_score]
		best_hand_label.modulate = Color(0.78, 0.84, 0.95)

	var xp_gained: int = int(data.get("xp_gained", 0))
	var xp_from_hands: int = int(data.get("xp_from_hands", 0))
	var xp_from_objectives: int = int(data.get("xp_from_objectives", 0))
	var objectives_completed: int = int(data.get("objectives_completed", 0))
	var objectives_total: int = int(data.get("objectives_total", 0))
	var bonus_parts: Array = []
	if xp_from_hands > 0:
		bonus_parts.append("+%d first-time" % xp_from_hands)
	if xp_from_objectives > 0:
		bonus_parts.append("+%d obj %d/%d" % [xp_from_objectives, objectives_completed, objectives_total])
	if bonus_parts.is_empty():
		xp_label.text = "+%d XP" % xp_gained
	else:
		xp_label.text = "+%d XP   (%s)" % [xp_gained, ", ".join(bonus_parts)]

	var modifier_name: String = String(data.get("modifier_name", ""))
	if not modifier_name.is_empty():
		# Append modifier to best-hand line in a softer color (since BestHandLabel
		# is the only easy-to-augment label) — keeps panel layout untouched.
		var current_text := best_hand_label.text
		best_hand_label.text = "%s\nModifier: %s" % [current_text, modifier_name]

	var leveled_up: bool = bool(data.get("leveled_up", false))
	var prev: int = int(data.get("previous_level", 0))
	var new_lvl: int = int(data.get("new_level", 0))
	if leveled_up:
		level_label.text = "Lv %d  →  Lv %d!" % [prev, new_lvl]
		level_label.modulate = Color(1.0, 0.88, 0.40)
	else:
		var next_xp := SaveData.xp_to_next_level()
		level_label.text = "Lv %d   ·   %d / %d XP" % [new_lvl, SaveData.xp, next_xp]
		level_label.modulate = Color(0.70, 0.75, 0.88)

	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)


func hide_summary() -> void:
	visible = false


func _on_play_again() -> void:
	play_again_pressed.emit()


func _on_menu() -> void:
	menu_pressed.emit()
