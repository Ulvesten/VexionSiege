## Purpose: Data container for a permanent meta-upgrade in the Spaceport.
extends Resource
class_name SpaceportUpgrade

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost_void_cores: int = 10
@export var cost_multiplier: float = 1.0  # cost = cost_void_cores * cost_multiplier * level
@export var effect_type: String = ""
@export var effect_value: float = 0.0
@export var max_level: int = 1
