## Purpose: Data container for a single in-run upgrade — all balancing lives here, not in scripts.
extends Resource
class_name UpgradeData

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

enum EffectType {
	FIRE_RATE, DAMAGE, CRIT_CHANCE, CRIT_MULTIPLIER,
	PROJECTILE_COUNT, PROJECTILE_SPEED, RANGE,
	BOUNCE_SHOT, PIERCE, CHAIN_LIGHTNING, EXPLOSIVE_ROUND,
	HOMING, OVERCHARGE,
	MAX_HP, HP_REGEN, DAMAGE_REDUCTION, THORNS,
	EMERGENCY_SHIELD, SECOND_WIND,
	CREDIT_MAGNET, VOID_HARVESTER, KILL_STREAK,
	BOSS_BOUNTY, COMPOUND_INTEREST,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var effect_type: EffectType = EffectType.DAMAGE
@export var effect_value: float = 0.0
@export var max_level: int = 1
@export var unlock_wave: int = 1
