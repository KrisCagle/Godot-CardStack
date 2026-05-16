extends Control

@onready var level_label: Label = $CenterColumn/LevelLabel
@onready var xp_bar: ProgressBar = $CenterColumn/XPBar
@onready var best_label: Label = $CenterColumn/BestLabel
@onready var play_button: Button = $CenterColumn/PlayButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	_refresh()


func _refresh() -> void:
	var needed := SaveData.xp_to_next_level()
	level_label.text = "Lv %d" % SaveData.level
	xp_bar.max_value = float(needed)
	xp_bar.value = float(SaveData.xp)
	best_label.text = "Best: %d" % SaveData.best_score


func _on_play_pressed() -> void:
	# Game scene comes online in task #2. For now, just a stub.
	push_warning("Game scene not built yet — wiring up in task #2.")
