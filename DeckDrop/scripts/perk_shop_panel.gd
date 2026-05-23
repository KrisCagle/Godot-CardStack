extends Control
## Modal shown after each dealer beat. Displays 3 perk buttons; emits
## `perk_picked(perk)` when the player chooses one. Caller awaits the signal
## (see game.gd._evaluate_round) and applies the perk before continuing.

signal perk_picked(perk: Dictionary)

@onready var title_label: Label = $Panel/VBox/Title
@onready var perk_buttons: Array[Button] = [
	$Panel/VBox/PerkRow/Perk0,
	$Panel/VBox/PerkRow/Perk1,
	$Panel/VBox/PerkRow/Perk2,
]

var _choices: Array = []


func _ready() -> void:
	visible = false
	for i in perk_buttons.size():
		var idx := i
		perk_buttons[i].pressed.connect(func(): _on_perk_pressed(idx))


func show_choices(choices: Array) -> void:
	_choices = choices
	for i in perk_buttons.size():
		var btn := perk_buttons[i]
		if i < choices.size():
			var p: Dictionary = choices[i]
			btn.text = "%s\n%s" % [String(p.name).to_upper(), String(p.description)]
			btn.add_theme_color_override("font_color", p.get("color", Color(1, 1, 1)))
			btn.disabled = false
			btn.visible = true
		else:
			btn.visible = false
	visible = true
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.22)


func hide_panel() -> void:
	visible = false


func _on_perk_pressed(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	var picked: Dictionary = _choices[idx]
	visible = false
	perk_picked.emit(picked)
