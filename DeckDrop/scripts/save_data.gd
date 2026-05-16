extends Node
## Persistent meta-progression: level, XP, best scores, daily leaderboard, achievements.
## Autoloaded as `SaveData`.

const SAVE_PATH := "user://savegame.cfg"

var level: int = 1
var xp: int = 0
var total_xp_earned: int = 0
var best_score: int = 0
var daily_scores: Dictionary = {}          # "YYYY-MM-DD" -> int (best that day)
var first_time_hands: Dictionary = {}      # hand_name -> true
var last_daily_login: String = ""

signal level_up(new_level: int)
signal xp_changed(xp: int, level: int)


func _ready() -> void:
	load_game()


func xp_to_next_level() -> int:
	return int(floor(100.0 * pow(float(level), 1.5)))


# Returns {"leveled_up": bool, "levels_gained": int}
func add_xp(amount: int) -> Dictionary:
	if amount <= 0:
		return {"leveled_up": false, "levels_gained": 0}
	xp += amount
	total_xp_earned += amount
	var levels_gained := 0
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		levels_gained += 1
		level_up.emit(level)
	xp_changed.emit(xp, level)
	save_game()
	return {"leveled_up": levels_gained > 0, "levels_gained": levels_gained}


# Returns true if this is a new daily best for the given date.
func record_score(score: int, date_str: String) -> bool:
	var new_daily_best := score > int(daily_scores.get(date_str, 0))
	if new_daily_best:
		daily_scores[date_str] = score
	if score > best_score:
		best_score = score
	save_game()
	return new_daily_best


# Returns true the first time this hand type is achieved (caller awards bonus XP).
func claim_first_time_hand(hand_name: String) -> bool:
	if first_time_hands.get(hand_name, false):
		return false
	first_time_hands[hand_name] = true
	save_game()
	return true


# Returns true the first time the player logs in on date_str (caller awards bonus XP).
func claim_daily_login(date_str: String) -> bool:
	if last_daily_login == date_str:
		return false
	last_daily_login = date_str
	save_game()
	return true


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "level", level)
	cfg.set_value("meta", "xp", xp)
	cfg.set_value("meta", "total_xp_earned", total_xp_earned)
	cfg.set_value("meta", "best_score", best_score)
	cfg.set_value("meta", "last_daily_login", last_daily_login)
	cfg.set_value("meta", "daily_scores", daily_scores)
	cfg.set_value("meta", "first_time_hands", first_time_hands)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	level = cfg.get_value("meta", "level", 1)
	xp = cfg.get_value("meta", "xp", 0)
	total_xp_earned = cfg.get_value("meta", "total_xp_earned", 0)
	best_score = cfg.get_value("meta", "best_score", 0)
	last_daily_login = cfg.get_value("meta", "last_daily_login", "")
	daily_scores = cfg.get_value("meta", "daily_scores", {})
	first_time_hands = cfg.get_value("meta", "first_time_hands", {})


func reset_progress() -> void:
	level = 1
	xp = 0
	total_xp_earned = 0
	best_score = 0
	daily_scores = {}
	first_time_hands = {}
	last_daily_login = ""
	save_game()
