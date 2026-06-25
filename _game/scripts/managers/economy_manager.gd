## Purpose: Tracks and mutates all currencies — Credits (in-run), Void Cores, and Gems (persistent).
extends Node

var credits: BigNum = BigNum.from(0.0)
var void_cores: int = 0
var gems: int = 0

var _credit_multiplier: float = 1.0
var _void_core_multiplier: float = 1.0
var _kill_streak_count: int = 0
var _kill_streak_timer: float = 0.0
var _credits_earned_run: BigNum = BigNum.from(0.0)  # total credits earned this run (for Game Over)

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.game_over.connect(_on_run_ended)
	EventBus.game_started.connect(_on_game_started)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	EventBus.void_cores_spend_requested.connect(_on_void_cores_spend_requested)
	EventBus.credits_spend_requested.connect(_on_credits_spend_requested)
	_load_persistent()

func _on_game_started() -> void:
	credits = BigNum.from(0.0)
	_credit_multiplier = 1.0
	_void_core_multiplier = 1.0
	_kill_streak_count = 0
	_credits_earned_run = BigNum.from(0.0)
	EventBus.credits_changed.emit(credits)

func _on_tick(delta: float) -> void:
	if _kill_streak_timer > 0.0:
		_kill_streak_timer -= delta
		if _kill_streak_timer <= 0.0:
			_kill_streak_count = 0

func add_credits(amount: float) -> void:
	var gained := BigNum.from(amount * _credit_multiplier)
	credits = credits.add(gained)
	_credits_earned_run = _credits_earned_run.add(gained)
	EventBus.credits_changed.emit(credits)

func spend_credits(amount: BigNum) -> bool:
	# Tolerance mirrors the shop's affordability check — float-accumulated credits can
	# read as 4.9999 vs a cost of 5, and an exact-cost buy must still succeed.
	if credits.value + 0.01 < amount.value:
		return false
	credits = credits.sub(amount)   # sub() clamps at 0, so a near-equal buy zeroes out
	EventBus.credits_changed.emit(credits)
	return true

func add_void_cores(amount: int) -> void:
	void_cores += amount
	EventBus.void_cores_changed.emit(void_cores)
	_save_persistent()

func _on_credits_spend_requested(amount: BigNum, context: String) -> void:
	var ok: bool = spend_credits(amount)
	EventBus.credits_spend_result.emit(context, ok)

func _on_void_cores_spend_requested(amount: int, context: String) -> void:
	if void_cores < amount:
		EventBus.void_cores_spend_result.emit(context, false)
		return
	void_cores -= amount
	EventBus.void_cores_changed.emit(void_cores)
	_save_persistent()
	EventBus.void_cores_spend_result.emit(context, true)

func add_gems(amount: int) -> void:
	gems += amount
	EventBus.gems_changed.emit(gems)
	_save_persistent()

func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	EventBus.gems_changed.emit(gems)
	_save_persistent()
	return true

func _on_enemy_killed(data: Dictionary) -> void:
	var base_value: float = data.get("credit_value", 1.0)
	var streak_bonus: float = 1.0 + (minf(_kill_streak_count, 10) * 0.05)
	var gained: float = base_value * streak_bonus * _credit_multiplier
	add_credits(base_value * streak_bonus)
	if data.has("position"):
		EventBus.credit_awarded.emit(data["position"], gained)
	_kill_streak_count += 1
	_kill_streak_timer = 3.0

func _on_run_ended(stats: Dictionary) -> void:
	var wave: int = stats.get("wave_reached", 0)
	var boss_kills: int = stats.get("boss_kills", 0)
	var cores: int = floori(wave / 10.0) + boss_kills * 5
	cores = int(cores * _void_core_multiplier)
	add_void_cores(cores)

	# Lifetime stats — persist; drive prestige (sqrt) + Spaceport tier gating.
	var total_cores: int = SaveManager.get_value("lifetime", "total_void_cores_ever", 0)
	SaveManager.set_value("lifetime", "total_void_cores_ever", total_cores + cores)
	var best: int = SaveManager.get_value("lifetime", "best_wave", 0)
	if wave > best:
		SaveManager.set_value("lifetime", "best_wave", wave)
	var runs: int = SaveManager.get_value("lifetime", "total_runs", 0)
	SaveManager.set_value("lifetime", "total_runs", runs + 1)
	SaveManager.save()

	EventBus.run_summary.emit({
		"void_cores_earned": cores,
		"credits_earned": _credits_earned_run,
		"best_wave": SaveManager.get_value("lifetime", "best_wave", 0),
	})

	credits = BigNum.from(0.0)
	EventBus.credits_changed.emit(credits)

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	match upgrade_id:
		"credit_magnet":  _credit_multiplier = new_value
		"void_harvester": _void_core_multiplier = new_value

func _save_persistent() -> void:
	SaveManager.set_value("economy", "void_cores", void_cores)
	SaveManager.set_value("economy", "gems", gems)
	SaveManager.save()

func _load_persistent() -> void:
	void_cores = SaveManager.get_value("economy", "void_cores", 0)
	gems = SaveManager.get_value("economy", "gems", 0)
