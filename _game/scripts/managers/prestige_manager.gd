## Purpose: Rebirth logic and Star Shard currency. Stub — unlocks after Galaxy 1 cleared (wave 500).
extends Node

var star_shards: int = 0
var prestige_count: int = 0

var _bonuses: Dictionary = {}

func _ready() -> void:
	EventBus.prestige_triggered.connect(_on_prestige_triggered)
	_load()

func can_prestige() -> bool:
	return GameManager.current_wave >= 500

func _on_prestige_triggered() -> void:
	if not can_prestige():
		return
	prestige_count += 1
	# Canonical lifetime key written by EconomyManager at run end (was reading a
	# never-written "economy/void_cores_ever", so shards always computed to 0).
	var total_cores: int = SaveManager.get_value("lifetime", "total_void_cores_ever", 0)
	var shards_earned: int = floori(sqrt(total_cores / 100.0))
	star_shards += shards_earned
	_apply_prestige_reset()
	_save()

func _apply_prestige_reset() -> void:
	# Spaceport upgrades reset 50% (rounded down) — wired in Phase 6
	pass

func _load() -> void:
	star_shards = SaveManager.get_value("prestige", "star_shards", 0)
	prestige_count = SaveManager.get_value("prestige", "count", 0)

func _save() -> void:
	SaveManager.set_value("prestige", "star_shards", star_shards)
	SaveManager.set_value("prestige", "count", prestige_count)
	SaveManager.save()
