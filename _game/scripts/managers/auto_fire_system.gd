## Purpose: Ship fires automatically — targets nearest enemy in range, manages projectile pool.
extends Node

const SHIP_POSITION: Vector2 = Vector2(540.0, 1700.0)

# Stats — defaults match DESIGN.md base values
var fire_rate: float = 1.0
var damage: float = 10.0
var range_px: float = 600.0
var projectile_speed: float = 800.0
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0
var projectile_count: int = 1

var _fire_cooldown: float = 0.0
var _enemy_manager: Node = null
var _pool: ObjectPool

@export var projectile_scene: PackedScene

func _ready() -> void:
	TickSystem.tick.connect(_on_tick)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	EventBus.game_over.connect(_on_game_over)
	EventBus.game_started.connect(_on_game_started)

func set_enemy_manager(em: Node) -> void:
	_enemy_manager = em

func _on_game_started() -> void:
	_fire_cooldown = 0.5  # brief delay before first shot

func _on_tick(delta: float) -> void:
	# Move projectiles every tick, not just when a new shot fires
	if _pool != null:
		for proj: Node in _get_active_projectiles():
			_move_projectile(proj, delta)

	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return

	_fire_cooldown = 1.0 / fire_rate
	_try_fire()

func _try_fire() -> void:
	if _enemy_manager == null:
		return
	var target: Node = _enemy_manager.get_nearest_in_range(SHIP_POSITION, range_px)
	if target == null:
		return
	for i: int in projectile_count:
		_fire_at(target, i)

func _fire_at(target: Node, spread_index: int) -> void:
	# Roll crit once at fire time so the stored damage and the floating number agree.
	var is_crit: bool = Helpers.chance(crit_chance)
	var dmg: float = damage * (crit_multiplier if is_crit else 1.0)

	if projectile_scene == null:
		# Instant-hit fallback until projectile scene is built
		EventBus.enemy_damaged.emit(target.position, dmg, is_crit)
		_enemy_manager.apply_damage(target, dmg)
		return

	if _pool == null:
		_pool = ObjectPool.new()
		_pool.setup(projectile_scene, self, 20)

	var proj: Node = _pool.acquire()
	proj.position = SHIP_POSITION
	var base_dir: Vector2 = (target.position - SHIP_POSITION).normalized()
	var spread_angle: float = deg_to_rad((spread_index - (projectile_count - 1) / 2.0) * 8.0)
	proj.set_meta("direction", base_dir.rotated(spread_angle))
	proj.set_meta("speed", projectile_speed)
	proj.set_meta("damage", dmg)
	proj.set_meta("is_crit", is_crit)
	proj.set_meta("target", target)

func _move_projectile(proj: Node, delta: float) -> void:
	proj.position += proj.get_meta("direction", Vector2.UP) * proj.get_meta("speed", 800.0) * delta
	var target: Node = proj.get_meta("target", null)
	if is_instance_valid(target) and target.visible:
		if proj.position.distance_to(target.position) < 20.0:
			var dmg: float = proj.get_meta("damage", damage)
			EventBus.enemy_damaged.emit(proj.position, dmg, proj.get_meta("is_crit", false))
			_enemy_manager.apply_damage(target, dmg)
			_pool.release(proj)
	elif not _in_bounds(proj.position):
		_pool.release(proj)

func _in_bounds(pos: Vector2) -> bool:
	var r: Rect2 = get_viewport().get_visible_rect()
	return r.grow(100.0).has_point(pos)

func _get_active_projectiles() -> Array[Node]:
	if _pool == null:
		return []
	var result: Array[Node] = []
	for proj: Node in _pool._pool:
		if proj.visible:
			result.append(proj)
	return result

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	match upgrade_id:
		"fire_rate":         fire_rate = new_value
		"damage":            damage = new_value
		"crit_chance":       crit_chance = new_value
		"crit_multiplier":   crit_multiplier = new_value
		"projectile_count":  projectile_count = int(new_value)
		"projectile_speed":  projectile_speed = new_value
		"range":             range_px = new_value

func _on_game_over(_stats: Dictionary) -> void:
	_fire_cooldown = 9999.0
