extends Control

@onready var level_label: Label = $CenterColumn/LevelLabel
@onready var xp_bar: ProgressBar = $CenterColumn/XPBar
@onready var best_label: Label = $CenterColumn/BestLabel
@onready var next_unlock_label: Label = $CenterColumn/NextUnlockLabel
@onready var play_button: Button = $CenterColumn/PlayButton
@onready var daily_button: Button = $CenterColumn/DailyButton
@onready var progress_button: Button = $CenterColumn/ProgressButton

const PROGRESS_PANEL_SCENE := preload("res://scenes/ProgressPanel.tscn")
var _progress_panel: Control = null


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	daily_button.pressed.connect(_on_daily_pressed)
	progress_button.pressed.connect(_on_progress_pressed)
	_refresh()


func _refresh() -> void:
	var needed := SaveData.xp_to_next_level()
	level_label.text = "Lv %d" % SaveData.level
	xp_bar.max_value = float(needed)
	xp_bar.value = float(SaveData.xp)
	best_label.text = "Best: %d" % SaveData.best_score

	var next_unlock := Themes.next_unlock_for_level(SaveData.level)
	if next_unlock.is_empty():
		next_unlock_label.text = "✨  All themes unlocked"
		next_unlock_label.modulate = Color(1.0, 0.95, 0.55)
	else:
		next_unlock_label.text = "Next: %s at Lv %d" % \
			[String(next_unlock.name), int(next_unlock.unlock_level)]
		next_unlock_label.modulate = Color(0.65, 0.78, 0.95)

	# Daily button shows today's best score if the player already attempted it.
	var today := MatchState.today_date_str()
	var today_best: int = int(SaveData.daily_scores.get(today, 0))
	if today_best > 0:
		daily_button.text = "🗓  DAILY · %d" % today_best
	else:
		daily_button.text = "🗓  DAILY"


func _on_play_pressed() -> void:
	MatchState.launch_standard()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_daily_pressed() -> void:
	MatchState.launch_daily()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_progress_pressed() -> void:
	if _progress_panel == null:
		_progress_panel = PROGRESS_PANEL_SCENE.instantiate()
		add_child(_progress_panel)
	_progress_panel.show_progress()
