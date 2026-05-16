extends Control
## Game-screen root. Owns the deck, current card, and 3-card preview queue.
## Tapping a column logs the would-be placement and advances the queue;
## actual grid placement lands in task #4.

const PREVIEW_SIZE := 3

@onready var playfield: Control = $PlayField
@onready var score_label: Label = $HUD/ScoreLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var back_button: Button = $HUD/BackButton
@onready var current_card_view: CardView = $BottomArea/CurrentSlot
@onready var preview_card_views: Array[CardView] = [
	$BottomArea/Preview0,
	$BottomArea/Preview1,
	$BottomArea/Preview2,
]

var _deck: Deck
var _current: Card = null
var _preview: Array[Card] = []
var score: int = 0


func _ready() -> void:
	playfield.column_tapped.connect(_on_column_tapped)
	back_button.pressed.connect(_on_back_pressed)
	_start_new_game()


func _start_new_game() -> void:
	_deck = Deck.new()
	_preview.clear()
	for i in PREVIEW_SIZE:
		_preview.append(_deck.draw_card())
	_current = _deck.draw_card()
	score = 0
	_refresh()


func _on_column_tapped(col: int) -> void:
	if _current == null:
		return
	# Task #3 stub: log the placement and advance. Real placement in task #4.
	print("[game] place %s%s in col %d" % [_current.rank_label(), _current.suit_label(), col])
	_advance_queue()
	_refresh()


func _advance_queue() -> void:
	_current = _preview[0]
	for i in range(PREVIEW_SIZE - 1):
		_preview[i] = _preview[i + 1]
	_preview[PREVIEW_SIZE - 1] = _deck.draw_card()


func _refresh() -> void:
	score_label.text = "Score  %d" % score
	level_label.text = "Lv %d" % SaveData.level
	current_card_view.set_card(_current)
	for i in PREVIEW_SIZE:
		preview_card_views[i].set_card(_preview[i])


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
