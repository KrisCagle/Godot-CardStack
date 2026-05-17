extends Control

@onready var level_label: Label = $CenterColumn/LevelLabel
@onready var xp_bar: ProgressBar = $CenterColumn/XPBar
@onready var best_label: Label = $CenterColumn/BestLabel
@onready var play_button: Button = $CenterColumn/PlayButton
@onready var progress_button: Button = $CenterColumn/ProgressButton

const PROGRESS_PANEL_SCENE := preload("res://scenes/ProgressPanel.tscn")
var _progress_panel: Control = null


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	progress_button.pressed.connect(_on_progress_pressed)
	_refresh()


func _refresh() -> void:
	var needed := SaveData.xp_to_next_level()
	level_label.text = "Lv %d" % SaveData.level
	xp_bar.max_value = float(needed)
	xp_bar.value = float(SaveData.xp)
	best_label.text = "Best: %d" % SaveData.best_score


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_progress_pressed() -> void:
	if _progress_panel == null:
		_progress_panel = PROGRESS_PANEL_SCENE.instantiate()
		add_child(_progress_panel)
	_progress_panel.show_progress()
