## Purpose: Test telemetry — prints structured EventBus events to stdout so they can be
## read back via the MCP `logs_read(source="game")`. Gives ground-truth on the economy /
## shop / run flow without needing screenshots. Flip ENABLED off to silence.
extends Node

const ENABLED: bool = true

func _ready() -> void:
	if not ENABLED:
		return
	# Run lifecycle
	EventBus.game_started.connect(func(): _log("game_started"))
	EventBus.ship_died.connect(func(): _log("ship_died"))
	EventBus.game_over.connect(func(s: Dictionary): _log("game_over %s" % s))
	EventBus.run_summary.connect(func(s: Dictionary): _log("run_summary %s" % s))
	# Waves
	EventBus.wave_started.connect(func(n: int): _log("wave_started w=%d" % n))
	EventBus.wave_completed.connect(func(n: int): _log("wave_completed w=%d" % n))
	# In-run shop / upgrades
	EventBus.upgrade_purchased.connect(func(id: String): _log("upgrade_purchased %s" % id))
	EventBus.credits_spend_requested.connect(func(a: BigNum, c: String): _log("credits_spend_req %s amount=%.0f" % [c, a.value]))
	EventBus.credits_spend_result.connect(func(c: String, ok: bool): _log("credits_spend_res %s ok=%s" % [c, ok]))
	# Spaceport / meta
	EventBus.spaceport_opened.connect(func(): _log("spaceport_opened"))
	EventBus.spaceport_closed.connect(func(): _log("spaceport_closed"))
	EventBus.void_cores_spend_requested.connect(func(a: int, c: String): _log("vc_spend_req %s amount=%d" % [c, a]))
	EventBus.void_cores_spend_result.connect(func(c: String, ok: bool): _log("vc_spend_res %s ok=%s" % [c, ok]))
	EventBus.meta_upgrade_purchased.connect(func(id: String): _log("meta_purchased %s" % id))
	_log("DebugLogger ready")

func _log(msg: String) -> void:
	print("[DBG] ", msg)
