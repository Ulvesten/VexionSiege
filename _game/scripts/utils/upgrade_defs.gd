## Purpose: Single source of truth for in-run upgrade definitions + cost math.
## Shared by the wave-clear shop (upgrade_panel) and the read-only catalog (catalog_panel)
## so the pool and pricing can never drift between them.
class_name UpgradeDefs
extends Object

# Categories (match stats_panel grouping).
const OFFENSE: int = 0
const DEFENSE: int = 1
const ECONOMY: int = 2

# In-run shop pricing: cost = rarity_base × 1.55 ^ (that upgrade's own level).
const RARITY_BASE: Array[int] = [5, 18, 50, 150]   # common, rare, epic, legendary
const COST_GROWTH: float = 1.55

# "enabled":false hides an upgrade from the wave-clear OFFER pool (effect not wired yet),
# but it STILL appears in the catalog as a "Soon" preview. "cat" drives catalog grouping.
const POOL: Array[Dictionary] = [
	{"id":"fire_rate",        "label":"Fire Rate",        "desc":"+12% shots per second",          "rarity":0, "unlock":1,  "max":20, "icon":"⚡", "cat":OFFENSE},
	{"id":"damage",           "label":"Damage",           "desc":"+18% base damage",               "rarity":0, "unlock":1,  "max":20, "icon":"💥", "cat":OFFENSE},
	{"id":"crit_chance",      "label":"Crit Chance",      "desc":"+5% critical hit chance",         "rarity":1, "unlock":1,  "max":15, "icon":"🎯", "cat":OFFENSE},
	{"id":"crit_multiplier",  "label":"Crit Damage",      "desc":"+0.25× on critical hits",         "rarity":1, "unlock":5,  "max":10, "icon":"✦", "cat":OFFENSE},
	{"id":"projectile_count", "label":"Multi-Shot",       "desc":"+1 projectile per shot",          "rarity":1, "unlock":10, "max":5,  "icon":"◈", "cat":OFFENSE},
	{"id":"projectile_speed", "label":"Bullet Speed",     "desc":"+15% projectile speed",           "rarity":0, "unlock":1,  "max":10, "icon":"→", "cat":OFFENSE},
	{"id":"range",            "label":"Range",            "desc":"+8% attack range",               "rarity":0, "unlock":1,  "max":15, "icon":"◎", "cat":OFFENSE},
	{"id":"max_hp",           "label":"Max HP",           "desc":"+20 max hull HP",                "rarity":0, "unlock":1,  "max":20, "icon":"♥", "cat":DEFENSE},
	{"id":"hp_regen",         "label":"HP Regen",         "desc":"+0.5 HP per second",             "rarity":0, "unlock":5,  "max":15, "icon":"✚", "cat":DEFENSE},
	{"id":"damage_reduction", "label":"Armor",            "desc":"-3% incoming damage",            "rarity":1, "unlock":10, "max":10, "icon":"🛡", "cat":DEFENSE},
	{"id":"credit_magnet",    "label":"Credit Magnet",    "desc":"+15% credits from kills",        "rarity":0, "unlock":1,  "max":20, "icon":"◉", "cat":ECONOMY},
	{"id":"void_harvester",   "label":"Void Harvester",   "desc":"+10% Void Cores per run",        "rarity":1, "unlock":1,  "max":10, "icon":"◈", "cat":ECONOMY},
	{"id":"chain_lightning",  "label":"Chain Lightning",  "desc":"On hit, arc to nearby enemy 60%","rarity":2, "unlock":15, "max":5,  "icon":"🔗", "cat":OFFENSE, "enabled": false},
	{"id":"explosive_round",  "label":"Explosive Round",  "desc":"On kill, AoE explosion",         "rarity":2, "unlock":20, "max":5,  "icon":"💣", "cat":OFFENSE, "enabled": false},
	{"id":"second_wind",      "label":"Second Wind",      "desc":"On death, revive once at 25% HP","rarity":3, "unlock":50, "max":1,  "icon":"🛡", "cat":DEFENSE, "enabled": false},
]

static func get_info(id: String) -> Dictionary:
	for entry: Dictionary in POOL:
		if entry["id"] == id:
			return entry
	return {}

static func cost_for(rarity: int, level: int, discount: float = 1.0) -> int:
	return int(round(RARITY_BASE[rarity] * pow(COST_GROWTH, level) * discount))

# Spaceport "Upgrade Discount" — −5%/level, floor 0.75×. Reads the persisted save.
static func discount_mult() -> float:
	var owned: Dictionary = SaveManager.get_value("spaceport", "upgrades", {})
	var lvl: int = owned.get("upgrade_discount", 0)
	return maxf(0.75, 1.0 - 0.05 * lvl)
