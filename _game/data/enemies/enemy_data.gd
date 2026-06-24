## Purpose: Data container for a single enemy type — all balancing lives here, not in scripts.
extends Resource
class_name EnemyData

@export var id: String = ""
@export var display_name: String = ""
@export var hp: float = 10.0
@export var speed: float = 80.0
@export var damage: float = 5.0
@export var credit_value: float = 1.0
@export var color: Color = Color(0.69, 0.75, 0.77)  # light grey default
@export var radius: float = 16.0
@export var sprite: Texture2D
