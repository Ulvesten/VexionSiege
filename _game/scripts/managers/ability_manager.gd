## Purpose: Active abilities — cooldown tracking and activation. Stub for Phase 4.
extends Node

const MAX_SLOTS: int = 3

var _abilities: Array[Dictionary] = []
var _current_fire_rate: float = 1.0  # cached via upgrade_applied so we never query UpgradeManager directly

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)

func _on_tick(delta: float) -> void:
	for ability: Dictionary in _abilities:
		if ability["current_cooldown"] > 0.0:
			ability["current_cooldown"] -= delta

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	if upgrade_id == "fire_rate":
		_current_fire_rate = new_value

func equip(ability_data: AbilityData) -> bool:
	if _abilities.size() >= MAX_SLOTS:
		return false
	_abilities.append({
		"id": ability_data.id,
		"cooldown": ability_data.cooldown,
		"current_cooldown": 0.0,
		"data": ability_data,
	})
	return true

func activate(slot: int) -> void:
	if slot >= _abilities.size():
		return
	var ability: Dictionary = _abilities[slot]
	if ability["current_cooldown"] > 0.0:
		return
	ability["current_cooldown"] = ability["cooldown"]
	_apply_effect(ability["data"])

func _apply_effect(data: AbilityData) -> void:
	match data.effect_type:
		"nova_burst":
			pass  # Phase 5: AoE damage to all enemies in range
		"repair_drone":
			EventBus.ship_hull_damaged.emit(-data.effect_value)  # negative = heal
		"time_warp":
			TickSystem.set_game_speed(0.2)
			await get_tree().create_timer(data.effect_value).timeout
			TickSystem.set_game_speed(1.0)
		"overclock":
			var boosted: float = _current_fire_rate * 3.0
			EventBus.upgrade_applied.emit("fire_rate", boosted)
			await get_tree().create_timer(data.effect_value).timeout
			EventBus.upgrade_applied.emit("fire_rate", _current_fire_rate)

func get_cooldown_ratio(slot: int) -> float:
	if slot >= _abilities.size():
		return 0.0
	var ab: Dictionary = _abilities[slot]
	if ab["cooldown"] <= 0.0:
		return 0.0
	return ab["current_cooldown"] / ab["cooldown"]
