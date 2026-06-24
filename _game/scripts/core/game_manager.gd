## Purpose: Run lifecycle and game state machine.
extends Node

enum State { MENU, PLAYING, PAUSED, GAME_OVER, SPACEPORT }

var current_state: State = State.MENU
var current_wave: int = 0

# Run tally — drives the Game Over stats and the Void Core reward (boss kills).
var _enemies_killed: int = 0
var _boss_kills: int = 0

func _ready() -> void:
	EventBus.ship_died.connect(_on_ship_died)
	EventBus.spaceport_opened.connect(_on_spaceport_opened)
	EventBus.spaceport_closed.connect(_on_spaceport_closed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_on_enemy_killed)

func start_run() -> void:
	current_wave = 0
	_enemies_killed = 0
	_boss_kills = 0
	TickSystem.resume()
	_set_state(State.PLAYING)
	EventBus.game_started.emit()

func pause_game() -> void:
	if current_state != State.PLAYING:
		return
	TickSystem.pause()
	_set_state(State.PAUSED)
	EventBus.game_paused.emit()

func resume_game() -> void:
	if current_state != State.PAUSED:
		return
	TickSystem.resume()
	_set_state(State.PLAYING)
	EventBus.game_resumed.emit()

func _on_ship_died() -> void:
	TickSystem.pause()
	_set_state(State.GAME_OVER)
	EventBus.game_over.emit({
		"wave_reached": current_wave,
		"enemies_killed": _enemies_killed,
		"boss_kills": _boss_kills,
	})

func _on_enemy_killed(data: Dictionary) -> void:
	_enemies_killed += 1
	if data.get("type", "") == "boss":
		_boss_kills += 1

func _on_wave_started(wave_number: int) -> void:
	current_wave = wave_number

func _on_spaceport_opened() -> void:
	_set_state(State.SPACEPORT)

# Closing the Spaceport (or "RUN AGAIN") begins a fresh run. Previously this only
# set MENU state and nothing called start_run() again, so the meta-loop dead-ended
# after the first death.
func _on_spaceport_closed() -> void:
	start_run()

func _set_state(new_state: State) -> void:
	current_state = new_state

func is_playing() -> bool:
	return current_state == State.PLAYING
