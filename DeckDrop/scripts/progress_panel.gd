extends Control
## Progress overlay shown from Title — lifetime stats + achievement list.
## Lazy-instanced on first open; populates content from SaveData each time
## it's shown so updates after a run are reflected immediately.

signal close_pressed

@onready var stats_vbox: VBoxContainer = $Panel/VBox/StatsSection/StatsVBox
@onready var themes_vbox: VBoxContainer = $Panel/VBox/ThemesSection/ThemesVBox
@onready var achievements_vbox: VBoxContainer = $Panel/VBox/AchievementsSection/AchievementsScroll/AchievementsVBox
@onready var unlocked_label: Label = $Panel/VBox/AchievementsSection/UnlockedLabel
@onready var back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	visible = false


func show_progress() -> void:
	_populate_stats()
	_populate_themes()
	_populate_achievements()
	visible = true
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.22)


func hide_progress() -> void:
	visible = false


func _populate_stats() -> void:
	for c in stats_vbox.get_children():
		c.queue_free()
	var rows := [
		["Runs Played",        SaveData.get_stat("total_runs")],
		["Best Score",         SaveData.best_score],
		["Total Score",        SaveData.get_stat("total_score")],
		["Cards Placed",       SaveData.get_stat("total_cards_placed")],
		["Hands Cleared",      SaveData.get_stat("total_hands_cleared")],
		["Jokers Played",      SaveData.get_stat("total_jokers_played")],
		["Bombs Detonated",    SaveData.get_stat("total_bombs_played")],
		["Highest Combo",      "×%d" % SaveData.get_stat("highest_combo")],
		["Best Cascade Tier",  SaveData.get_stat("highest_cascade_tier")],
		["Best Dealer Beaten", SaveData.get_stat("highest_dealer_tier")],
		["Longest Run",        "%d cards" % SaveData.get_stat("longest_run_placements")],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = String(r[0])
		label.add_theme_font_size_override("font_size", 30)
		label.modulate = Color(0.72, 0.77, 0.90)
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)
		var value := Label.new()
		value.text = str(r[1])
		value.add_theme_font_size_override("font_size", 30)
		value.modulate = Color(1.0, 0.95, 0.70)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		stats_vbox.add_child(row)


func _populate_themes() -> void:
	for c in themes_vbox.get_children():
		c.queue_free()
	var current_id := String(Themes.current().id)
	for t in Themes.LIST:
		var id := String(t.id)
		var ul: int = int(t.unlock_level)
		var unlocked := SaveData.level >= ul

		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL

		# Felt color swatch on the left previews the theme.
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(36, 36)
		swatch.color = t.felt if unlocked else Color(0.20, 0.22, 0.28)
		row.add_child(swatch)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		if unlocked:
			if id == current_id:
				name_label.text = "  %s   ✓ CURRENT" % String(t.name)
				name_label.modulate = Color(1.00, 0.95, 0.50)
			else:
				name_label.text = "  %s   (unlocked)" % String(t.name)
				name_label.modulate = Color(0.72, 0.85, 1.00)
		else:
			name_label.text = "  %s   🔒 Lv %d" % [String(t.name), ul]
			name_label.modulate = Color(0.50, 0.55, 0.65)
		row.add_child(name_label)

		themes_vbox.add_child(row)


func _populate_achievements() -> void:
	for c in achievements_vbox.get_children():
		c.queue_free()
	var unlocked := 0
	for a in Achievements.LIST:
		var id := String(a.id)
		var is_open := SaveData.is_achievement_unlocked(id)
		if is_open:
			unlocked += 1
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 26)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if is_open:
			row.text = "✓  %s — %s   (+%d XP)" % [String(a.name), String(a.desc), int(a.xp)]
			row.modulate = Color(1.0, 0.95, 0.70)
		else:
			row.text = "🔒  %s   (+%d XP)" % [String(a.desc), int(a.xp)]
			row.modulate = Color(0.50, 0.55, 0.65)
		achievements_vbox.add_child(row)
	unlocked_label.text = "%d / %d UNLOCKED" % [unlocked, Achievements.LIST.size()]


func _on_back() -> void:
	hide_progress()
	close_pressed.emit()
