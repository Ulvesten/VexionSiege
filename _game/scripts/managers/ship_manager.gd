## Purpose: Player ship HP, regen, and death — receives hull damage after ShieldSystem absorbs its share.
extends Node2D

var max_hp: float = 100.0
var current_hp: float = 100.0
var hp_regen: float = 0.0
var damage_reduction: float = 0.0

var _dead: bool = false

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.ship_hull_damaged.connect(_on_hull_damaged)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	_dead = false
	current_hp = max_hp

func _on_tick(delta: float) -> void:
	if _dead or hp_regen <= 0.0 or current_hp >= max_hp:
		return
	current_hp = minf(max_hp, current_hp + hp_regen * delta)
	EventBus.ship_damaged.emit(0.0, current_hp)

func _on_hull_damaged(raw_amount: float) -> void:
	if _dead:
		return
	var dmg: float = raw_amount * (1.0 - damage_reduction)
	current_hp -= dmg
	EventBus.ship_damaged.emit(dmg, current_hp)
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	current_hp = 0.0
	EventBus.ship_damaged.emit(0.0, 0.0)
	EventBus.ship_died.emit()

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	match upgrade_id:
		"max_hp":
			var old_max: float = max_hp
			max_hp = new_value
			current_hp = minf(current_hp + (max_hp - old_max), max_hp)
			EventBus.ship_damaged.emit(0.0, current_hp)
		"hp_regen":          hp_regen = new_value
		"damage_reduction":  damage_reduction = new_value
