extends Control
## Progress overlay shown from Title — lifetime stats + achievement list.
## Lazy-instanced on first open; populates content from SaveData each time
## it's shown so updates after a run are reflected immediately.

signal close_pressed

@onready var stats_vbox: VBoxContainer = $Panel/VBox/StatsSection/StatsVBox
@onready var daily_vbox: VBoxContainer = $Panel/VBox/DailySection/DailyVBox
@onready var themes_vbox: VBoxContainer = $Panel/VBox/ThemesSection/ThemesVBox
@onready var achievements_vbox: VBoxContainer = $Panel/VBox/AchievementsSection/AchievementsScroll/AchievementsVBox
@onready var unlocked_label: Label = $Panel/VBox/AchievementsSection/UnlockedLabel
@onready var back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	visible = false


func show_progress() -> void:
	_populate_stats()
	_populate_daily_history()
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


func _populate_daily_history() -> void:
	for c in daily_vbox.get_children():
		c.queue_free()

	var dates: Array = SaveData.daily_scores.keys()
	dates.sort()
	dates.reverse()  # most recent first
	var today := MatchState.today_date_str()
	var shown := 0

	for date in dates:
		if shown >= 7:
			break
		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL

		var date_text := String(date)
		var date_label := Label.new()
		date_label.add_theme_font_size_override("font_size", 28)
		date_label.size_flags_horizontal = SIZE_EXPAND_FILL
		if date_text == today:
			date_label.text = "  %s   (today)" % date_text
			date_label.modulate = Color(1.00, 0.95, 0.55)
		else:
			date_label.text = "  %s" % date_text
			date_label.modulate = Color(0.72, 0.77, 0.90)
		row.add_child(date_label)

		var score_label := Label.new()
		score_label.text = "%d   " % int(SaveData.daily_scores[date])
		score_label.add_theme_font_size_override("font_size", 28)
		score_label.modulate = Color(1.00, 0.95, 0.70)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(score_label)

		daily_vbox.add_child(row)
		shown += 1

	if shown == 0:
		var empty := Label.new()
		empty.text = "No daily runs yet — tap DAILY on the title to start."
		empty.add_theme_font_size_override("font_size", 24)
		empty.modulate = Color(0.55, 0.60, 0.72)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		daily_vbox.add_child(empty)


func _populate_themes() -> void:
	for c in themes_vbox.get_children():
		c.queue_free()
	var current_id := String(Themes.current().id)
	for t in Themes.LIST:
		var id := String(t.id)
		var ul: int = int(t.unlock_level)
		var unlocked := SaveData.level >= ul
		themes_vbox.add_child(_make_theme_row(t, unlocked, id == current_id))


# One row per theme: mini card-preview swatch on the left (felt frame + a
# pretend K♠ rendered with that theme's actual colors + border + ring), then
# the theme name + status. Locked themes desaturate the swatch and show the
# required level. Unlocked rows are tappable to apply the theme.
func _make_theme_row(t: Dictionary, unlocked: bool, is_active: bool) -> Control:
	var id := String(t.id)
	var ul: int = int(t.get("unlock_level", 1))

	# Outer button so the whole row is tappable when unlocked. For locked
	# themes we still use a Button so the row sizing matches, but disable it.
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.disabled = not unlocked
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 0)  # we draw our own labels
	if unlocked:
		var theme_id := id
		btn.pressed.connect(func(): _on_theme_selected(theme_id))

	# HBox layout inside the button.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.anchor_left = 0.0
	hbox.anchor_top = 0.0
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 16.0
	hbox.offset_right = -16.0
	hbox.offset_top = 8.0
	hbox.offset_bottom = -8.0
	btn.add_child(hbox)

	# Card preview — a Control with a custom _draw that paints felt + mini
	# card using this theme's colors.
	var preview := _ThemeSwatch.new()
	preview.custom_minimum_size = Vector2(72, 80)
	preview.theme_dict = t
	preview.locked = not unlocked
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(preview)

	# Right side: name + status, stacked.
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.text = String(t.name)
	if unlocked:
		name_label.modulate = Color(1.00, 0.95, 0.75) if is_active \
			else Color(0.85, 0.92, 1.00)
	else:
		name_label.modulate = Color(0.55, 0.58, 0.65)
	vbox.add_child(name_label)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 22)
	if not unlocked:
		status.text = "🔒  Reach level %d" % ul
		status.modulate = Color(0.55, 0.58, 0.65)
	elif is_active:
		status.text = "✓ Active"
		status.modulate = Color(1.00, 0.85, 0.30)
	else:
		status.text = "Tap to apply"
		status.modulate = Color(0.60, 0.78, 1.00)
	vbox.add_child(status)

	return btn


# Lightweight Control subclass that draws a felt-framed mini card preview
# using a specific theme dict (not Themes.current()). Lets the Progress
# panel show what each theme actually looks like without the player having
# to switch to it first.
class _ThemeSwatch extends Control:
	var theme_dict: Dictionary = {}
	var locked: bool = false

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		# Felt frame so each swatch reads like a tabletop snapshot.
		var felt: Color = theme_dict.get("felt", Color(0.06, 0.08, 0.12))
		if locked:
			felt = Color(0.18, 0.20, 0.25)
		draw_rect(rect, felt, true)
		draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.5)

		# Inset mini-card area.
		var pad := 8.0
		var card_rect := Rect2(
			rect.position + Vector2(pad, pad),
			rect.size - Vector2(pad * 2.0, pad * 2.0)
		)
		# Use a fake King of Spades — readable rank + clear suit color cue.
		var sample := Card.new(Card.Suit.SPADES, Card.Rank.KING)
		if locked:
			# Grayed silhouette — no theme reveal until unlocked.
			draw_rect(card_rect, Color(0.30, 0.32, 0.40), true)
			draw_rect(card_rect, Color(0.50, 0.55, 0.62), false, 2.0)
			var font := get_theme_default_font()
			var fs := int(card_rect.size.y * 0.5)
			draw_string(font,
				card_rect.position + Vector2(0, card_rect.size.y * 0.7),
				"?", HORIZONTAL_ALIGNMENT_CENTER, card_rect.size.x, fs,
				Color(0.65, 0.68, 0.75))
			return
		CardView.draw_card_with_theme(self, sample, card_rect, theme_dict)


func _on_theme_selected(id: String) -> void:
	SaveData.selected_theme_id = id
	SaveData.save_game()
	_populate_themes()


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
