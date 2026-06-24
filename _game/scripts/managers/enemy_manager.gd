## Purpose: Enemy pool, movement toward the ship, HP tracking, and death handling.
extends Node

# Ship sits at bottom-centre of 1080x1920
const SHIP_POSITION: Vector2 = Vector2(540.0, 1700.0)
const REACH_THRESHOLD: float = 30.0

var _active_enemies: Array[Node] = []
var _pool: ObjectPool

@export var enemy_scene: PackedScene

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.enemy_spawned.connect(_on_enemy_spawn_requested)
	EventBus.game_over.connect(_on_game_over)

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
	var base_speed: float = 80.0
	var base_hp: float = 10.0
	var base_damage: float = 5.0
	var base_credits: float = 1.0

	match data.get("type", "drone"):
		"drone":
			base_hp = 10.0; base_speed = 80.0; base_damage = 5.0; base_credits = 1.0
		"bruiser":
			base_hp = 60.0; base_speed = 45.0; base_damage = 15.0; base_credits = 4.0
		"swarm":
			base_hp = 3.0; base_speed = 130.0; base_damage = 2.0; base_credits = 0.5
		"shielder":
			base_hp = 30.0; base_speed = 70.0; base_damage = 10.0; base_credits = 6.0
		"bomber":
			base_hp = 25.0; base_speed = 70.0; base_damage = 30.0; base_credits = 8.0
		"boss":
			base_hp = 500.0; base_speed = 30.0; base_damage = 50.0; base_credits = 50.0

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
		EventBus.enemy_reached_ship.emit(dmg)
		_release_enemy(enemy, false)

func apply_damage(enemy: Node, amount: float) -> void:
	if not is_instance_valid(enemy) or not enemy.visible:
		return
	var hp: float = enemy.get_meta("hp", 0.0) - amount
	enemy.set_meta("hp", hp)
	if hp <= 0.0:
		_release_enemy(enemy, true)

func _release_enemy(enemy: Node, award_credits: bool) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	if award_credits:
		EventBus.enemy_killed.emit({
			"type": enemy.get_meta("type", "drone"),
			"credit_value": enemy.get_meta("credit_value", 1.0),
			"position": enemy.position,
		})
	if _pool != null:
		_pool.release(enemy)
	else:
		enemy.visible = false

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
