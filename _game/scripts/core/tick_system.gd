## Purpose: Global tick that drives all manager updates instead of per-manager _process() calls.
extends Node

signal tick(delta: float)

var game_speed: float = 1.0

var _paused: bool = false

func _process(delta: float) -> void:
	if not _paused:
		tick.emit(delta * game_speed)

func pause() -> void:
	_paused = true

func resume() -> void:
	_paused = false

func set_game_speed(speed: float) -> void:
	game_speed = clampf(speed, 0.0, 10.0)
