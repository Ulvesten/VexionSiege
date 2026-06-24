## Purpose: Screen-shake controller — applies a decaying random offset to the active Camera2D.
extends Node

var _intensity: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.ship_damaged.connect(_on_ship_damaged)
	EventBus.shield_broken.connect(_on_shield_broken)
	EventBus.enemy_killed.connect(_on_enemy_killed)

## Trigger a shake. A stronger shake overrides a weaker one in progress so big
## hits are never swallowed by a lingering small shake.
func shake(intensity: float, duration: float) -> void:
	if not _active or intensity >= _intensity:
		_intensity = intensity
		_duration = duration
		_elapsed = 0.0
		_active = true

func _on_tick(delta: float) -> void:
	if not _active:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		_active = false
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_active = false
		cam.offset = Vector2.ZERO
		return
	var decay: float = 1.0 - (_elapsed / _duration)
	var amp: float = _intensity * decay
	cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))

func _on_ship_damaged(amount: float, _current_hp: float) -> void:
	if amount > 0.0:  # ship_damaged also fires with amount 0 on HP regen
		shake(4.0, 0.2)

func _on_shield_broken() -> void:
	shake(6.0, 0.3)

func _on_enemy_killed(data: Dictionary) -> void:
	if data.get("type", "") == "boss":
		shake(12.0, 0.6)
