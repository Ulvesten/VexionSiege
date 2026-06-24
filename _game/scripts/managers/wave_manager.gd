## Purpose: Spawns waves, tracks wave number, and drives the scaling formula from DESIGN.md.
extends Node

var wave_number: int = 0

var _enemies_remaining: int = 0
var _wave_active: bool = false
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.5
var _enemies_to_spawn: Array[String] = []
var _boss_kills_this_run: int = 0

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.game_started.connect(_begin_first_wave)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.all_enemies_cleared.connect(_on_all_enemies_cleared)
	EventBus.ready_for_next_wave.connect(_start_next_wave)

func _on_tick(delta: float) -> void:
	if not _wave_active or _enemies_to_spawn.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_next_enemy()
		_spawn_timer = _spawn_interval

func _begin_first_wave() -> void:
	wave_number = 0
	_boss_kills_this_run = 0
	_start_next_wave()

func _start_next_wave() -> void:
	wave_number += 1
	_wave_active = true
	_enemies_to_spawn = _build_spawn_list()
	_enemies_remaining = _enemies_to_spawn.size()
	_spawn_timer = 0.0
	EventBus.wave_started.emit(wave_number)

func _build_spawn_list() -> Array[String]:
	var count: int = 5 + floori(wave_number * 1.4)
	var is_swarm: bool = (wave_number % 10 == 0)
	if is_swarm:
		count *= 3
	var is_boss: bool = _is_boss_wave()
	var list: Array[String] = []
	if is_boss:
		list.append("boss")
		count -= 1
	for i: int in count:
		list.append(_pick_enemy_type(is_swarm))
	list.shuffle()
	return list

func _pick_enemy_type(swarm_only: bool) -> String:
	if swarm_only:
		return "swarm"
	var roll: float = randf()
	if wave_number >= 15 and roll < 0.05:
		return "bomber"
	if wave_number >= 8 and roll < 0.15:
		return "shielder"
	if wave_number >= 5 and roll < 0.25:
		return "bruiser"
	if roll < 0.35:
		return "swarm"
	return "drone"

func _is_boss_wave() -> bool:
	if wave_number == 25 or wave_number == 50 or wave_number == 100:
		return true
	return wave_number > 100 and (wave_number % 100 == 0)

func _spawn_next_enemy() -> void:
	if _enemies_to_spawn.is_empty():
		return
	var enemy_type: String = _enemies_to_spawn.pop_front()
	EventBus.enemy_spawned.emit({
		"type": enemy_type,
		"wave": wave_number,
		"hp_mult": get_hp_multiplier(),
		"speed_mult": get_speed_multiplier(),
		"credit_mult": get_credit_multiplier(),
		"is_elite": is_elite_wave(),
	})

func _on_enemy_killed(data: Dictionary) -> void:
	if data.get("type", "") == "boss":
		_boss_kills_this_run += 1
	_enemies_remaining -= 1
	if _enemies_remaining <= 0 and _enemies_to_spawn.is_empty():
		EventBus.all_enemies_cleared.emit()

func _on_all_enemies_cleared() -> void:
	_wave_active = false
	EventBus.wave_completed.emit(wave_number)

func get_hp_multiplier() -> float:
	return 1.0 + (wave_number * 0.08)

func get_speed_multiplier() -> float:
	return 1.0 + (wave_number * 0.015)

func get_credit_multiplier() -> float:
	return 1.0 + (wave_number * 0.05)

func is_elite_wave() -> bool:
	return wave_number >= 50 and (wave_number % 25 == 0)

func get_boss_kills() -> int:
	return _boss_kills_this_run
