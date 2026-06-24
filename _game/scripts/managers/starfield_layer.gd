## Purpose: Three-layer parallax starfield driven by TickSystem — wraps at screen bottom.
extends Node2D

const VIEWPORT_W: float  = 1080.0
const VIEWPORT_H: float  = 1920.0
const STARS_PER_LAYER: int = 25  # 75 total stars

# Base downward speed (px/game-sec) per layer — delta from TickSystem already carries game_speed
const LAYER_SPEEDS: Array[float] = [30.0, 70.0, 150.0]

# Stars stored as PackedVector2Array (pos) + packed floats (radius, opacity, hue)
var _positions: Array[PackedVector2Array] = []
var _radii:     Array[PackedFloat32Array] = []
var _opacities: Array[PackedFloat32Array] = []
var _is_blue:   Array[PackedByteArray]    = []  # 1 = light-blue tint, 0 = white

func _ready() -> void:
	randomize()
	_init_stars()
	TickSystem.tick.connect(_on_tick)

func _init_stars() -> void:
	for _layer: int in 3:
		var pos   := PackedVector2Array()
		var rad   := PackedFloat32Array()
		var op    := PackedFloat32Array()
		var blue  := PackedByteArray()
		for _i: int in STARS_PER_LAYER:
			pos.append(Vector2(randf() * VIEWPORT_W, randf() * VIEWPORT_H))
			rad.append(randf_range(0.5, 1.5))       # radius → diameter 1–3px
			op.append(randf_range(0.2, 0.9))
			blue.append(1 if randf() > 0.65 else 0) # ~35% light-blue, 65% white
		_positions.append(pos)
		_radii.append(rad)
		_opacities.append(op)
		_is_blue.append(blue)

func _on_tick(delta: float) -> void:
	for layer: int in 3:
		var speed: float = LAYER_SPEEDS[layer]
		var pos: PackedVector2Array = _positions[layer]
		for i: int in pos.size():
			pos[i].y += speed * delta
			if pos[i].y > VIEWPORT_H + 2.0:
				pos[i].y = -2.0
				pos[i].x = randf() * VIEWPORT_W
		_positions[layer] = pos
	queue_redraw()

func _draw() -> void:
	for layer: int in 3:
		var pos:  PackedVector2Array = _positions[layer]
		var rad:  PackedFloat32Array = _radii[layer]
		var op:   PackedFloat32Array = _opacities[layer]
		var blue: PackedByteArray    = _is_blue[layer]
		for i: int in pos.size():
			var col: Color
			if blue[i] == 1:
				col = Color(0.78, 0.88, 1.0, op[i])  # light-blue (#c7e0ff)
			else:
				col = Color(1.0, 1.0, 1.0, op[i])    # white
			draw_circle(pos[i], rad[i], col)
