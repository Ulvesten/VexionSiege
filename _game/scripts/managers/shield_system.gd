## Purpose: Shield HP, regen, and regen delay — sits in front of ship HP and absorbs incoming damage.
extends Node

var max_shield: float = 0.0
var current_shield: float = 0.0
var regen_rate: float = 5.0       # HP/sec
var regen_delay: float = 5.0      # seconds after damage before regen starts

var _regen_timer: float = 0.0
var _active: bool = false

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.enemy_reached_ship.connect(_on_enemy_reached_ship)
	EventBus.game_started.connect(_on_game_started)
	EventBus.shield_activate_requested.connect(_on_shield_activate_requested)

func _on_game_started() -> void:
	if max_shield > 0.0:
		current_shield = max_shield
		_active = true
		_regen_timer = 0.0
		EventBus.shield_initialized.emit(max_shield)
		EventBus.shield_damaged.emit(0.0, current_shield)

func activate(max_sh: float) -> void:
	max_shield = max_sh
	current_shield = max_sh
	_active = max_sh > 0.0
	_regen_timer = 0.0
	if _active:
		EventBus.shield_initialized.emit(max_sh)
		EventBus.shield_damaged.emit(0.0, current_shield)

func _on_shield_activate_requested(max_sh: float) -> void:
	activate(max_sh)

func _on_tick(delta: float) -> void:
	if not _active or max_shield <= 0.0:
		return
	if _regen_timer > 0.0:
		_regen_timer -= delta
		return
	if current_shield < max_shield:
		current_shield = minf(max_shield, current_shield + regen_rate * delta)
		EventBus.shield_damaged.emit(0.0, current_shield)
		if current_shield >= max_shield:
			EventBus.shield_recharged.emit()

func absorb_damage(amount: float) -> float:
	if not _active or current_shield <= 0.0:
		return amount
	_regen_timer = regen_delay
	var absorbed: float = minf(current_shield, amount)
	current_shield -= absorbed
	EventBus.shield_damaged.emit(absorbed, current_shield)
	if current_shield <= 0.0:
		EventBus.shield_broken.emit()
	return amount - absorbed

func _on_enemy_reached_ship(damage: float) -> void:
	var remainder: float = absorb_damage(damage)
	EventBus.ship_hull_damaged.emit(remainder)

func is_active() -> bool:
	return _active and max_shield > 0.0
