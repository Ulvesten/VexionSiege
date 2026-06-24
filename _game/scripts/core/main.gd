## Purpose: Scene root — wires up manager references that can't go through EventBus, then starts the run.
extends Node2D

@onready var enemy_manager: Node = $GameField/EnemyManager
@onready var auto_fire_system: Node = $GameField/AutoFireSystem
@onready var shield_system: Node = $GameField/ShieldSystem
@onready var wave_manager: Node = $GameField/WaveManager
@onready var economy_manager: Node = $GameField/EconomyManager
@onready var upgrade_manager: Node = $GameField/UpgradeManager
@onready var spaceport_system: Node = $GameField/SpaceportSystem
@onready var ability_manager: Node = $GameField/AbilityManager
@onready var prestige_manager: Node = $GameField/PrestigeManager
@onready var ship: Node2D = $GameField/Ship

func _ready() -> void:
	# Wire the one cross-manager reference that can't go through EventBus:
	# AutoFireSystem needs to query EnemyManager's enemy list for targeting.
	auto_fire_system.set_enemy_manager(enemy_manager)
	GameManager.start_run()
