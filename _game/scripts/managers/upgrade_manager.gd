## Purpose: Tracks purchased in-run upgrades and broadcasts stat changes via EventBus.
extends Node

# Current upgrade levels for this run
var _levels: Dictionary = {}

# Run-start base values, captured at reset. Upgrades are computed from THESE, not
# from the live (already-upgraded) values — otherwise each level compounds the last.
var _base_stats: Dictionary = {}

# Live stat values — reset each run, then modified by purchases
var _stats: Dictionary = {
	"fire_rate": 1.0,
	"damage": 10.0,
	"crit_chance": 0.0,
	"crit_multiplier": 2.0,
	"projectile_count": 1.0,
	"projectile_speed": 800.0,
	"range": 600.0,
	"max_hp": 100.0,
	"hp_regen": 0.0,
	"damage_reduction": 0.0,
	"credit_magnet": 1.0,
	"void_harvester": 1.0,
}

# Permanent bonuses injected by SpaceportSystem before each run
var spaceport_bonuses: Dictionary = {}

func _ready() -> void:
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.game_started.connect(_reset_for_run)
	EventBus.spaceport_bonus_applied.connect(apply_spaceport_bonus)

func _reset_for_run() -> void:
	_levels.clear()
	_stats = {
		"fire_rate": 1.0 + spaceport_bonuses.get("fire_rate_bonus", 0.0),
		"damage": 10.0,
		"crit_chance": spaceport_bonuses.get("crit_chance_bonus", 0.0),
		"crit_multiplier": 2.0,
		"projectile_count": 1.0,
		"projectile_speed": 800.0,
		"range": 600.0,
		"max_hp": 100.0 + spaceport_bonuses.get("max_hp_bonus", 0.0),
		"hp_regen": 0.0,
		"damage_reduction": 0.0,
		"credit_magnet": 1.0,
		"void_harvester": 1.0,
	}
	_base_stats = _stats.duplicate()
	for stat: String in _stats:
		EventBus.upgrade_applied.emit(stat, _stats[stat])

func _on_upgrade_purchased(upgrade_id: String) -> void:
	_levels[upgrade_id] = _levels.get(upgrade_id, 0) + 1
	var new_val: float = _calculate_stat(upgrade_id)
	_stats[upgrade_id] = new_val
	EventBus.upgrade_applied.emit(upgrade_id, new_val)

func _calculate_stat(id: String) -> float:
	var level: int = _levels.get(id, 0)
	# Always compute from the run-start base so levels don't compound each other.
	var base: float = _base_stats.get(id, _stats.get(id, 0.0))
	match id:
		"fire_rate":        return base * pow(1.12, level)
		"damage":           return base * pow(1.18, level)
		"crit_chance":      return minf(0.75, base + 0.05 * level)
		"crit_multiplier":  return minf(4.5, base + 0.25 * level)
		"projectile_count": return base + level
		"projectile_speed": return base * pow(1.15, level)
		"range":            return base * pow(1.08, level)
		"max_hp":           return base + 20.0 * level
		"hp_regen":         return base + 0.5 * level
		"damage_reduction": return minf(0.30, base + 0.03 * level)
		"credit_magnet":    return base * pow(1.15, level)
		"void_harvester":   return base * pow(1.10, level)
	return base

func get_level(upgrade_id: String) -> int:
	return _levels.get(upgrade_id, 0)

func get_stat(stat_id: String) -> float:
	return _stats.get(stat_id, 0.0)

func apply_spaceport_bonus(key: String, value: float) -> void:
	spaceport_bonuses[key] = value
