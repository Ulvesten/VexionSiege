## Purpose: Stateless utility functions shared across systems.
class_name Helpers
extends Object

static func rand_screen_edge_position(viewport_size: Vector2, margin: float = 50.0) -> Vector2:
	var edge: int = randi() % 4
	match edge:
		0: return Vector2(randf_range(0.0, viewport_size.x), -margin)
		1: return Vector2(randf_range(0.0, viewport_size.x), viewport_size.y + margin)
		2: return Vector2(-margin, randf_range(0.0, viewport_size.y))
		_: return Vector2(viewport_size.x + margin, randf_range(0.0, viewport_size.y))

static func format_time(seconds: float) -> String:
	var m: int = int(seconds) / 60
	var s: int = int(seconds) % 60
	return "%02d:%02d" % [m, s]

static func direction_toward(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	return (to_pos - from_pos).normalized()

static func chance(probability: float) -> bool:
	return randf() < probability
