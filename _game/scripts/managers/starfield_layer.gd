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

# Hyperdrive on wave clear: a 0→1→0 warp burst that streaks the stars to sell the
# jump to the next sector. Driven on the RAW _process clock (not TickSystem) because
# the wave-clear shop pauses TickSystem the instant the wave completes.
const WARP_BOOST: float = 12.0       # extra speed multiplier at full warp
const WARP_STREAK_PX: float = 90.0   # max streak length at full warp (fastest layer)
var _warp: float = 0.0
var _warp_tween: Tween

func _ready() -> void:
	randomize()
	_init_stars()
	TickSystem.tick.connect(_on_tick)
	EventBus.wave_completed.connect(_on_wave_completed)

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
	_advance_stars(delta)            # normal travel (respects pause + game speed)
	queue_redraw()

# Raw-clock warp overlay — runs even while TickSystem is paused (during the shop),
# adding the EXTRA hyperdrive movement on top of normal travel so the stars streak.
func _process(delta: float) -> void:
	if _warp <= 0.001:
		return
	_advance_stars(delta * _warp * WARP_BOOST)
	queue_redraw()

func _advance_stars(amount_scale: float) -> void:
	for layer: int in 3:
		var speed: float = LAYER_SPEEDS[layer]
		var pos: PackedVector2Array = _positions[layer]
		for i: int in pos.size():
			pos[i].y += speed * amount_scale
			if pos[i].y > VIEWPORT_H + 2.0:
				pos[i].y = -2.0
				pos[i].x = randf() * VIEWPORT_W
		_positions[layer] = pos

func _on_wave_completed(_wave: int) -> void:
	if _warp_tween != null and _warp_tween.is_valid():
		_warp_tween.kill()
	_warp = 0.0
	_warp_tween = create_tween()
	_warp_tween.tween_property(self, "_warp", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	_warp_tween.tween_property(self, "_warp", 0.0, 1.1).set_ease(Tween.EASE_IN)

func _draw() -> void:
	var streaking: bool = _warp > 0.05
	for layer: int in 3:
		var pos:  PackedVector2Array = _positions[layer]
		var rad:  PackedFloat32Array = _radii[layer]
		var op:   PackedFloat32Array = _opacities[layer]
		var blue: PackedByteArray    = _is_blue[layer]
		# Faster (nearer) layers streak longer for a parallax hyperdrive feel.
		var streak_len: float = _warp * WARP_STREAK_PX * (LAYER_SPEEDS[layer] / LAYER_SPEEDS[2])
		for i: int in pos.size():
			var col: Color
			if blue[i] == 1:
				col = Color(0.78, 0.88, 1.0, op[i])  # light-blue (#c7e0ff)
			else:
				col = Color(1.0, 1.0, 1.0, op[i])    # white
			if streaking and streak_len > 1.0:
				# Trail points back up (stars travel down), head at current pos.
				draw_line(pos[i], pos[i] - Vector2(0.0, streak_len), col, rad[i] * 2.0, true)
			else:
				draw_circle(pos[i], rad[i], col)
