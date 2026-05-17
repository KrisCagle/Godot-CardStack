extends Node
## Persistent meta-progression: level, XP, best scores, daily leaderboard,
## first-time-hand achievements, lifetime stats, and unlock achievements.
## Autoloaded as `SaveData`.

const SAVE_PATH := "user://savegame.cfg"

const DEFAULT_STATS := {
	"total_runs": 0,
	"total_score": 0,
	"total_cards_placed": 0,
	"total_hands_cleared": 0,
	"total_jokers_played": 0,
	"total_bombs_played": 0,
	"highest_combo": 0,
	"highest_dealer_tier": 0,
	"highest_cascade_tier": 0,
	"longest_run_placements": 0,
}

var level: int = 1
var xp: int = 0
var total_xp_earned: int = 0
var best_score: int = 0
var daily_scores: Dictionary = {}
var first_time_hands: Dictionary = {}
var last_daily_login: String = ""

# Lifetime stats and one-shot achievements
var stats: Dictionary = {}
var achievements: Dictionary = {}

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


func record_score(score: int, date_str: String) -> bool:
	var new_daily_best := score > int(daily_scores.get(date_str, 0))
	if new_daily_best:
		daily_scores[date_str] = score
	if score > best_score:
		best_score = score
	save_game()
	return new_daily_best


func claim_first_time_hand(hand_name: String) -> bool:
	if first_time_hands.get(hand_name, false):
		return false
	first_time_hands[hand_name] = true
	save_game()
	return true


func claim_daily_login(date_str: String) -> bool:
	if last_daily_login == date_str:
		return false
	last_daily_login = date_str
	save_game()
	return true


# Lifetime stat counters --------------------------------------------------------


func get_stat(key: String) -> int:
	return int(stats.get(key, 0))


func increment_stat(key: String, by: int = 1) -> void:
	stats[key] = get_stat(key) + by
	save_game()


func update_max_stat(key: String, value: int) -> void:
	if value > get_stat(key):
		stats[key] = value
		save_game()


# Achievements ------------------------------------------------------------------


func claim_achievement(id: String) -> bool:
	if achievements.get(id, false):
		return false
	achievements[id] = true
	save_game()
	return true


func is_achievement_unlocked(id: String) -> bool:
	return bool(achievements.get(id, false))


func unlocked_achievement_count() -> int:
	var n := 0
	for a in achievements.values():
		if bool(a):
			n += 1
	return n


# Persistence -------------------------------------------------------------------


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "level", level)
	cfg.set_value("meta", "xp", xp)
	cfg.set_value("meta", "total_xp_earned", total_xp_earned)
	cfg.set_value("meta", "best_score", best_score)
	cfg.set_value("meta", "last_daily_login", last_daily_login)
	cfg.set_value("meta", "daily_scores", daily_scores)
	cfg.set_value("meta", "first_time_hands", first_time_hands)
	cfg.set_value("meta", "stats", stats)
	cfg.set_value("meta", "achievements", achievements)
	cfg.save(SAVE_PATH)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_init_stats_defaults()
		return
	level = cfg.get_value("meta", "level", 1)
	xp = cfg.get_value("meta", "xp", 0)
	total_xp_earned = cfg.get_value("meta", "total_xp_earned", 0)
	best_score = cfg.get_value("meta", "best_score", 0)
	last_daily_login = cfg.get_value("meta", "last_daily_login", "")
	daily_scores = cfg.get_value("meta", "daily_scores", {})
	first_time_hands = cfg.get_value("meta", "first_time_hands", {})
	stats = cfg.get_value("meta", "stats", {})
	achievements = cfg.get_value("meta", "achievements", {})
	_init_stats_defaults()


# Make sure every default stat key exists (handles forward-migration when we
# add new stats to an existing save).
func _init_stats_defaults() -> void:
	for key in DEFAULT_STATS.keys():
		if not stats.has(key):
			stats[key] = DEFAULT_STATS[key]


func reset_progress() -> void:
	level = 1
	xp = 0
	total_xp_earned = 0
	best_score = 0
	daily_scores = {}
	first_time_hands = {}
	last_daily_login = ""
	stats = {}
	achievements = {}
	_init_stats_defaults()
	save_game()
