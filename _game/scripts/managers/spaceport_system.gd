## Purpose: Meta-upgrade hub — manages permanent Spaceport upgrades between runs via EventBus.
extends Node

var _owned_upgrades: Dictionary = {}
var _pending_purchase_id: String = ""

# Pricing: per-level cost grows exponentially from each upgrade's own base.
const COST_GROWTH: float = 1.6
# Tier unlocks gate by best wave ever reached (whole tier at once), +50 per tier.
const TIER_UNLOCK_WAVE: Dictionary = {1: 0, 2: 50, 3: 100, 4: 150}

func _ready() -> void:
	EventBus.void_cores_spend_result.connect(_on_spend_result)
	EventBus.meta_upgrade_purchased.connect(_on_meta_upgrade_purchased)
	_load()
	_push_bonuses()  # push saved bonuses immediately so UpgradeManager has them before game_started

func try_purchase(upgrade_id: String, base_cost: int) -> void:
	var level: int = get_level(upgrade_id)
	var cost: int = cost_for(base_cost, level)
	_pending_purchase_id = upgrade_id
	EventBus.void_cores_spend_requested.emit(cost, upgrade_id)

# Single source of truth for scaled cost — the panel calls this so the displayed
# cost and the charged cost can never drift.
func cost_for(base_cost: int, level: int) -> int:
	return int(round(base_cost * pow(COST_GROWTH, level)))

func unlock_wave_for_tier(tier: int) -> int:
	return TIER_UNLOCK_WAVE.get(tier, 0)

func is_tier_unlocked(tier: int) -> bool:
	var best: int = SaveManager.get_value("lifetime", "best_wave", 0)
	return best >= unlock_wave_for_tier(tier)

func get_level(upgrade_id: String) -> int:
	return _owned_upgrades.get(upgrade_id, 0)

func _on_spend_result(context: String, success: bool) -> void:
	# Void Cores are only ever spent on Spaceport upgrades, so a successful result's
	# context IS the purchased upgrade id. The panel emits the spend request directly
	# (it can't call this scene-node manager), so we must NOT gate on a
	# _pending_purchase_id round-trip — doing so silently dropped every purchase
	# (cores spent, level never incremented).
	_pending_purchase_id = ""
	if not success or context == "":
		return
	_owned_upgrades[context] = _owned_upgrades.get(context, 0) + 1
	EventBus.meta_upgrade_purchased.emit(context)
	_save()

func _on_meta_upgrade_purchased(_upgrade_id: String) -> void:
	_push_bonuses()  # re-push all bonuses so UpgradeManager has the latest values

func _push_bonuses() -> void:
	EventBus.spaceport_bonus_applied.emit("max_hp_bonus", get_level("reinforced_hull") * 25.0)
	EventBus.spaceport_bonus_applied.emit("fire_rate_bonus", get_level("reactor_boost") * 0.05)
	EventBus.spaceport_bonus_applied.emit("crit_chance_bonus", get_level("targeting_system") * 0.03)
	var shield_max: float = get_level("shield_generator") * 25.0
	EventBus.shield_activate_requested.emit(shield_max)

func _save() -> void:
	SaveManager.set_value("spaceport", "upgrades", _owned_upgrades)
	SaveManager.save()

func _load() -> void:
	_owned_upgrades = SaveManager.get_value("spaceport", "upgrades", {})
