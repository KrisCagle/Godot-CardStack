extends Node

const SAVE_PATH := "user://meta_profile_v2.json"
const VERSION := 3

const PERK_MAX_TIERS: Dictionary = {
	"start_gold": 3,
	"start_hp": 2,
	"start_ammo": 1,
	"shop_discount": 3,
	"split_resonance": 3,
	"second_chance": 1,
	"box_bonus": 2,
	"box_control": 2,
}

const PERK_BASE_COST: Dictionary = {
	"start_gold": 60,
	"start_hp": 80,
	"start_ammo": 420,
	"shop_discount": 120,
	"split_resonance": 110,
	"second_chance": 900,
	"box_bonus": 170,
	"box_control": 220,
}

const PERK_LEVEL_REQ: Dictionary = {
	"start_gold": 1,
	"start_hp": 1,
	"start_ammo": 2,
	"shop_discount": 2,
	"split_resonance": 1,
	"second_chance": 6,
	"box_bonus": 3,
	"box_control": 4,
}

const UNLOCK_COSTS: Dictionary = {
	"loadout_box_hunter": 260,
	"unlock_curse_pegs": 320,
	"unlock_portal_pocket": 420,
	"unlock_elite_boxes": 380,
}

const UNLOCK_LEVEL_REQ: Dictionary = {
	"loadout_box_hunter": 3,
	"unlock_elite_boxes": 4,
	"unlock_curse_pegs": 5,
	"unlock_portal_pocket": 7,
}

const SKILL_MAX_TIERS: Dictionary = {
	"control_nudge": 2,
	"craft_charge": 2,
	"hype_combo": 2,
	"econ_cache": 2,
	"survive_patch": 2,
	"show_jackpot": 1,
}

const SKILL_LEVEL_REQ: Dictionary = {
	"control_nudge": 2,
	"craft_charge": 3,
	"hype_combo": 4,
	"econ_cache": 2,
	"survive_patch": 3,
	"show_jackpot": 6,
}

var shards_total: int = 0
var player_level: int = 1
var xp: int = 0
var perks: Dictionary = {}
var unlocks: Dictionary = {}
var loadouts_unlocked: Array[String] = ["split", "greed", "vamp"]
var difficulty_unlocked: int = 1
var selected_league: int = 1
var skills: Dictionary = {}
var pending_skill_points: int = 0
var last_error: String = ""

func _ready() -> void:
	load_meta()

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_default()
		save_meta()
		return

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_reset_default()
		return
	var text := f.get_as_text()
	f.close()

	var parser := JSON.new()
	if parser.parse(text) != OK:
		_reset_default()
		return
	var d := parser.data as Dictionary
	if d.is_empty():
		_reset_default()
		return

	shards_total = int(d.get("shards_total", 0))
	player_level = max(1, int(d.get("player_level", 1)))
	xp = max(0, int(d.get("xp", 0)))
	perks = d.get("perks", {}) as Dictionary
	unlocks = d.get("unlocks", {}) as Dictionary
	difficulty_unlocked = max(1, int(d.get("difficulty_unlocked", 1)))
	selected_league = clampi(int(d.get("selected_league", 1)), 1, difficulty_unlocked)
	skills = d.get("skills", {}) as Dictionary
	pending_skill_points = max(0, int(d.get("pending_skill_points", 0)))

	var loadouts_variant: Array = d.get("loadouts_unlocked", ["split", "greed", "vamp"]) as Array
	loadouts_unlocked.clear()
	for id in loadouts_variant:
		loadouts_unlocked.append(str(id))
	if loadouts_unlocked.is_empty():
		loadouts_unlocked = ["split", "greed", "vamp"]

func save_meta() -> void:
	var d := {
		"version": VERSION,
		"shards_total": shards_total,
		"player_level": player_level,
		"xp": xp,
		"perks": perks,
		"unlocks": unlocks,
		"loadouts_unlocked": loadouts_unlocked,
		"difficulty_unlocked": difficulty_unlocked,
		"selected_league": selected_league,
		"skills": skills,
		"pending_skill_points": pending_skill_points,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()

func can_afford(cost: int) -> bool:
	return shards_total >= cost

func spend_shards(cost: int) -> bool:
	if cost <= 0:
		return true
	if not can_afford(cost):
		return false
	shards_total -= cost
	save_meta()
	return true

func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	shards_total += amount
	save_meta()

func perk_tier(perk_id: String) -> int:
	return int(perks.get(perk_id, 0))

func perk_max_tier(perk_id: String) -> int:
	return int(PERK_MAX_TIERS.get(perk_id, 0))

func perk_level_requirement(perk_id: String) -> int:
	return int(PERK_LEVEL_REQ.get(perk_id, 1))

func unlock_level_requirement(unlock_id: String) -> int:
	return int(UNLOCK_LEVEL_REQ.get(unlock_id, 1))

func unlock_cost(unlock_id: String) -> int:
	return int(UNLOCK_COSTS.get(unlock_id, 0))

func perk_cost(perk_id: String) -> int:
	var base := int(PERK_BASE_COST.get(perk_id, 0))
	var tier := perk_tier(perk_id)
	return int(round(float(base) * (1.0 + float(tier) * 1.18)))

func buy_perk(perk_id: String) -> bool:
	last_error = ""
	var max_tier := perk_max_tier(perk_id)
	if max_tier <= 0:
		last_error = "unknown_perk"
		return false
	if player_level < perk_level_requirement(perk_id):
		last_error = "level_locked"
		return false
	var tier := perk_tier(perk_id)
	if tier >= max_tier:
		last_error = "max_tier"
		return false
	var cost := perk_cost(perk_id)
	if not spend_shards(cost):
		last_error = "not_enough_shards"
		return false
	perks[perk_id] = tier + 1
	save_meta()
	return true

func unlock_item(unlock_id: String) -> bool:
	last_error = ""
	if bool(unlocks.get(unlock_id, false)):
		last_error = "already_unlocked"
		return false
	if player_level < unlock_level_requirement(unlock_id):
		last_error = "level_locked"
		return false
	var cost := unlock_cost(unlock_id)
	if cost <= 0:
		last_error = "unknown_unlock"
		return false
	if not spend_shards(cost):
		last_error = "not_enough_shards"
		return false
	unlocks[unlock_id] = true
	if unlock_id == "loadout_box_hunter" and not loadouts_unlocked.has("box_hunter"):
		loadouts_unlocked.append("box_hunter")
	save_meta()
	return true

func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		player_level += 1
		gained += 1
		var unlocked_league := mini(4, 1 + int(floor(float(player_level - 1) / 6.0)))
		difficulty_unlocked = maxi(difficulty_unlocked, unlocked_league)
		pending_skill_points += 1
		selected_league = clampi(selected_league, 1, difficulty_unlocked)
	save_meta()
	return gained

func xp_to_next_level() -> int:
	return 80 + (player_level - 1) * 45

func apply_meta_to_run(run_state: Dictionary) -> Dictionary:
	var rs: Dictionary = run_state.duplicate(true) as Dictionary
	rs["start_gold"] = int(rs.get("start_gold", 0)) + perk_tier("start_gold") * 10
	rs["start_hp"] = int(rs.get("start_hp", 100)) + perk_tier("start_hp") * 5
	rs["start_ammo"] = int(rs.get("start_ammo", 1)) + perk_tier("start_ammo")
	rs["shop_discount"] = 0.05 * float(perk_tier("shop_discount"))
	rs["split_bonus"] = 0.02 * float(perk_tier("split_resonance"))
	rs["revive_available"] = perk_tier("second_chance") > 0
	rs["box_shard_bonus"] = perk_tier("box_bonus")
	rs["box_speed_multiplier"] = clampf(1.0 - 0.08 * float(perk_tier("box_control")), 0.78, 1.0)
	rs["league_reward_multiplier"] = 1.0 + float(maxi(0, selected_league - 1)) * 0.15
	rs["difficulty_league"] = selected_league
	rs["loadouts"] = loadouts_unlocked.duplicate()
	rs["unlocks"] = unlocks.duplicate()
	rs["skills"] = skills.duplicate()
	_apply_skills_to_run(rs)
	return rs

func skill_tier(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))

func skill_max_tier(skill_id: String) -> int:
	return int(SKILL_MAX_TIERS.get(skill_id, 0))

func skill_level_requirement(skill_id: String) -> int:
	return int(SKILL_LEVEL_REQ.get(skill_id, 1))

func can_pick_skill(skill_id: String) -> bool:
	if pending_skill_points <= 0:
		last_error = "no_skill_points"
		return false
	if player_level < skill_level_requirement(skill_id):
		last_error = "level_locked"
		return false
	if skill_tier(skill_id) >= skill_max_tier(skill_id):
		last_error = "max_tier"
		return false
	return true

func pick_skill(skill_id: String) -> bool:
	last_error = ""
	if not can_pick_skill(skill_id):
		return false
	skills[skill_id] = skill_tier(skill_id) + 1
	pending_skill_points = maxi(0, pending_skill_points - 1)
	save_meta()
	return true

func available_skill_choices(count: int = 3) -> Array[String]:
	var ids: Array[String] = []
	for key in SKILL_MAX_TIERS.keys():
		var id: String = str(key)
		if player_level >= skill_level_requirement(id) and skill_tier(id) < skill_max_tier(id):
			ids.append(id)
	ids.shuffle()
	if ids.size() <= count:
		return ids
	return ids.slice(0, count)

func cycle_selected_league() -> void:
	selected_league += 1
	if selected_league > difficulty_unlocked:
		selected_league = 1
	save_meta()

func _apply_skills_to_run(rs: Dictionary) -> void:
	rs["start_ammo"] = int(rs.get("start_ammo", 1)) + skill_tier("control_nudge")
	rs["split_bonus"] = float(rs.get("split_bonus", 0.0)) + 0.03 * float(skill_tier("craft_charge"))
	rs["start_combo_seed"] = 2 * skill_tier("hype_combo")
	rs["start_gold"] = int(rs.get("start_gold", 0)) + 10 * skill_tier("econ_cache")
	rs["start_hp"] = int(rs.get("start_hp", 100)) + 8 * skill_tier("survive_patch")
	rs["box_shard_bonus"] = int(rs.get("box_shard_bonus", 0)) + skill_tier("show_jackpot")

func _reset_default() -> void:
	shards_total = 0
	player_level = 1
	xp = 0
	perks = {}
	unlocks = {}
	loadouts_unlocked = ["split", "greed", "vamp"]
	difficulty_unlocked = 1
	selected_league = 1
	skills = {}
	pending_skill_points = 0
