## Purpose: Data container for an active ability — cooldown and effect live here.
extends Resource
class_name AbilityData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cooldown: float = 30.0
@export var effect_type: String = ""
@export var effect_value: float = 0.0
@export var unlock_cost_void_cores: int = 50
