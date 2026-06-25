## Purpose: Enemy pool, movement toward the ship, HP tracking, and death handling.
extends Node

# Ship sits at bottom-centre of 1080x1920 (raised off the bottom HUD bar)
const SHIP_POSITION: Vector2 = Vector2(540.0, 1580.0)
const REACH_THRESHOLD: float = 30.0

# Minimal HP bar drawn under each enemy (local space; scales with the enemy).
const HP_BAR_W: float = 24.0
const HP_BAR_H: float = 3.0
const HP_BAR_Y: float = 14.0   # just below the 20px visual

var _active_enemies: Array[Node] = []
var _pool: ObjectPool

# Wave-threat aggregate (drives the HUD Wave Info bar): total HP set at wave start,
# current ticks down with damage + escapes, counts decrement on death/escape.
var _threat_total: float = 0.0
var _threat_current: float = 0.0
var _threat_counts: Dictionary = {}

@export var enemy_scene: PackedScene

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.enemy_spawned.connect(_on_enemy_spawn_requested)
	EventBus.wave_threat_total.connect(_on_wave_threat_total)
	EventBus.game_over.connect(_on_game_over)

func _on_wave_threat_total(total_hp: float, counts: Dictionary) -> void:
	_threat_total = total_hp
	_threat_current = total_hp
	_threat_counts = counts.duplicate()
	_emit_threat()

func _emit_threat() -> void:
	EventBus.wave_threat_changed.emit(_threat_current, _threat_total, _threat_counts)

func _on_tick(delta: float) -> void:
	for enemy: Node in _active_enemies:
		if not is_instance_valid(enemy) or not enemy.visible:
			continue
		_move_enemy(enemy, delta)
		_check_ship_collision(enemy)

func _on_enemy_spawn_requested(data: Dictionary) -> void:
	if enemy_scene == null:
		return
	if _pool == null:
		_pool = ObjectPool.new()
		_pool.setup(enemy_scene, self, 10)

	var enemy: Node = _pool.acquire()
	_configure_enemy(enemy, data)
	_active_enemies.append(enemy)

func _configure_enemy(enemy: Node, data: Dictionary) -> void:
	var stats: Dictionary = EnemyDefs.stats(data.get("type", "drone"))
	var base_hp: float = stats["hp"]
	var base_speed: float = stats["speed"]
	var base_damage: float = stats["damage"]
	var base_credits: float = stats["credits"]

	var hp_mult: float = data.get("hp_mult", 1.0)
	var speed_mult: float = data.get("speed_mult", 1.0)
	var credit_mult: float = data.get("credit_mult", 1.0)
	var elite_mult: float = 1.5 if data.get("is_elite", false) else 1.0

	var type: String = data.get("type", "drone")
	_apply_visual(enemy, type, data.get("is_elite", false))

	enemy.set_meta("type", type)
	enemy.set_meta("max_hp", base_hp * hp_mult * elite_mult)
	enemy.set_meta("hp", base_hp * hp_mult * elite_mult)
	enemy.set_meta("speed", base_speed * speed_mult * elite_mult)
	enemy.set_meta("damage", base_damage)
	enemy.set_meta("credit_value", base_credits * credit_mult)
	_update_hp_bar(enemy)

	# Spawn from the top edge only — x within margins, y just above the viewport.
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	enemy.position = Vector2(randf_range(40.0, viewport_width - 40.0), -30.0)

# Colour + size the pooled enemy per type (re-applied on every acquire).
func _apply_visual(enemy: Node, type: String, is_elite: bool) -> void:
	var s: float = Palette.enemy_scale(type)
	if enemy is Node2D:
		(enemy as Node2D).scale = Vector2(s, s)
	var visual := enemy.get_node_or_null("Visual")
	if visual is ColorRect:
		var col: Color = Palette.enemy_color(type)
		# Elites read as the same type but visibly hotter.
		(visual as ColorRect).color = col.lightened(0.35) if is_elite else col

func _move_enemy(enemy: Node, delta: float) -> void:
	var dir: Vector2 = (SHIP_POSITION - enemy.position).normalized()
	enemy.position += dir * enemy.get_meta("speed", 80.0) * delta

func _check_ship_collision(enemy: Node) -> void:
	if enemy.position.distance_to(SHIP_POSITION) < REACH_THRESHOLD:
		var dmg: float = enemy.get_meta("damage", 5.0)
		# Escaping enemy leaves with its remaining HP — drop it from the wave threat.
		_threat_current = maxf(0.0, _threat_current - maxf(enemy.get_meta("hp", 0.0), 0.0))
		EventBus.enemy_reached_ship.emit(dmg)
		_release_enemy(enemy, false)

func apply_damage(enemy: Node, amount: float) -> void:
	if not is_instance_valid(enemy) or not enemy.visible:
		return
	var before: float = enemy.get_meta("hp", 0.0)
	_threat_current = maxf(0.0, _threat_current - minf(amount, maxf(before, 0.0)))
	var hp: float = before - amount
	enemy.set_meta("hp", hp)
	if hp <= 0.0:
		_release_enemy(enemy, true)
	else:
		_update_hp_bar(enemy)
		_emit_threat()

# Minimal under-enemy HP bar. Bar nodes are created once per pooled enemy and reused;
# the fill width tracks hp/max_hp and the colour lerps green → coral as HP drops.
func _ensure_hp_bar(enemy: Node) -> ColorRect:
	var fill := enemy.get_node_or_null("HPBarFill") as ColorRect
	if fill != null:
		return fill
	var bg := ColorRect.new()
	bg.name = "HPBarBg"
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.position = Vector2(-HP_BAR_W * 0.5, HP_BAR_Y)
	bg.size = Vector2(HP_BAR_W, HP_BAR_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = 10
	enemy.add_child(bg)
	fill = ColorRect.new()
	fill.name = "HPBarFill"
	fill.position = Vector2(-HP_BAR_W * 0.5, HP_BAR_Y)
	fill.size = Vector2(HP_BAR_W, HP_BAR_H)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.z_index = 11
	enemy.add_child(fill)
	return fill

func _update_hp_bar(enemy: Node) -> void:
	var fill := _ensure_hp_bar(enemy)
	var maxhp: float = enemy.get_meta("max_hp", 1.0)
	var hp: float = enemy.get_meta("hp", maxhp)
	var ratio: float = clampf(hp / maxhp, 0.0, 1.0) if maxhp > 0.0 else 0.0
	fill.size = Vector2(HP_BAR_W * ratio, HP_BAR_H)
	fill.color = Palette.GREEN.lerp(Palette.CORAL, 1.0 - ratio)

func _release_enemy(enemy: Node, award_credits: bool) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	var type: String = enemy.get_meta("type", "drone")
	if _threat_counts.has(type):
		_threat_counts[type] = maxi(0, int(_threat_counts[type]) - 1)
		if _threat_counts[type] == 0:
			_threat_counts.erase(type)
	if award_credits:
		EventBus.enemy_killed.emit({
			"type": type,
			"credit_value": enemy.get_meta("credit_value", 1.0),
			"position": enemy.position,
		})
	if _pool != null:
		_pool.release(enemy)
	else:
		enemy.visible = false
	_emit_threat()

func get_nearest_in_range(from: Vector2, range_px: float) -> Node:
	var best: Node = null
	var best_dist: float = range_px
	for enemy: Node in _active_enemies:
		if not is_instance_valid(enemy) or not enemy.visible:
			continue
		var d: float = from.distance_to(enemy.position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best

func _on_game_over(_stats: Dictionary) -> void:
	for enemy: Node in _active_enemies.duplicate():
		if _pool != null:
			_pool.release(enemy)
		else:
			enemy.visible = false
	_active_enemies.clear()
