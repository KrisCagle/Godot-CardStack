extends Node
## Transient per-match state — what mode the player launched, which date the
## daily run is tied to. Title sets these before changing scene; Game reads
## them in _start_new_game. Not persisted — defaults reset on app launch.
##
## Autoloaded as `MatchState`.

const MODE_STANDARD := "standard"
const MODE_DAILY := "daily"

var pending_mode: String = MODE_STANDARD
var daily_date: String = ""  # YYYY-MM-DD of the active daily run, "" otherwise


func today_date_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


# Deterministic seed for a given date — all players get the same deck on
# the same calendar day. We bias toward positive ints so they print cleanly
# in logs, but RandomNumberGenerator handles either sign.
func daily_seed_for(date_str: String) -> int:
	return absi(date_str.hash())


func launch_standard() -> void:
	pending_mode = MODE_STANDARD
	daily_date = ""


func launch_daily() -> void:
	pending_mode = MODE_DAILY
	daily_date = today_date_str()


func is_daily() -> bool:
	return pending_mode == MODE_DAILY


# Date string the current run's score should record against.
# Daily runs always record against the daily's own date; standard runs use
# whatever today is when the run ended.
func score_date_for_current_run() -> String:
	if is_daily():
		return daily_date
	return today_date_str()
