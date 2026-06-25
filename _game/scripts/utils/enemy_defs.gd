## Purpose: Single source of truth for enemy base stats. Shared by EnemyManager (spawning)
## and WaveManager (computing a wave's total HP for the Wave Info threat bar).
class_name EnemyDefs
extends Object

# Base stats per type (before wave / elite multipliers).
const BASE: Dictionary = {
	"drone":    {"hp": 10.0,  "speed": 80.0,  "damage": 5.0,  "credits": 1.0},
	"bruiser":  {"hp": 60.0,  "speed": 45.0,  "damage": 15.0, "credits": 4.0},
	"swarm":    {"hp": 3.0,   "speed": 130.0, "damage": 2.0,  "credits": 0.5},
	"shielder": {"hp": 30.0,  "speed": 70.0,  "damage": 10.0, "credits": 6.0},
	"bomber":   {"hp": 25.0,  "speed": 70.0,  "damage": 30.0, "credits": 8.0},
	"boss":     {"hp": 500.0, "speed": 30.0,  "damage": 50.0, "credits": 50.0},
}

# Short display glyph per type, for the Wave Info composition chips.
const GLYPH: Dictionary = {
	"drone": "●", "bruiser": "⬢", "swarm": "∴", "shielder": "◉", "bomber": "✸", "boss": "◆",
}

static func stats(type: String) -> Dictionary:
	return BASE.get(type, BASE["drone"])

static func base_hp(type: String) -> float:
	return stats(type)["hp"]

static func glyph(type: String) -> String:
	return GLYPH.get(type, "●")
