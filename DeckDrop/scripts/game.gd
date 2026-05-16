extends Control
## Game-screen root controller. Currently wires the play field's column-tap signal
## to a log line + visual flash. Card data, deck, and scoring land in later tasks.

@onready var playfield: Control = $PlayField
@onready var score_label: Label = $HUD/ScoreLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var back_button: Button = $HUD/BackButton

var score: int = 0


func _ready() -> void:
	playfield.column_tapped.connect(_on_column_tapped)
	back_button.pressed.connect(_on_back_pressed)
	_refresh_hud()


func _refresh_hud() -> void:
	score_label.text = "Score  %d" % score
	level_label.text = "Lv %d" % SaveData.level


func _on_column_tapped(col: int) -> void:
	print("[game] column %d tapped" % col)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
