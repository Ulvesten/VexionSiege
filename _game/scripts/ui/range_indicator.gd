## Purpose: Rotating dashed circle around the ship that visualises current attack range.
## Child of the ship (draws around its own origin), so it follows the ship automatically.
extends Node2D

const SEGMENTS: int = 56          # dash count around the ring
const DASH_RATIO: float = 0.55    # fraction of each segment that is drawn (gap = rest)
const ROT_SPEED: float = 0.5      # radians/sec the dash pattern spins
const LINE_WIDTH: float = 2.0

var _radius: float = 600.0        # matches DESIGN base range; updated on upgrade
var _angle: float = 0.0

func _ready() -> void:
	z_index = -1   # behind the ship + bullets
	TickSystem.tick.connect(_on_tick)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	EventBus.game_started.connect(func(): _radius = 600.0; queue_redraw())

func _on_tick(delta: float) -> void:
	_angle = fmod(_angle + ROT_SPEED * delta, TAU)
	queue_redraw()

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	if upgrade_id == "range":
		_radius = new_value
		queue_redraw()

func _draw() -> void:
	var col: Color = Palette.BLUE
	col.a = 0.22
	var seg: float = TAU / float(SEGMENTS)
	for i: int in SEGMENTS:
		var a0: float = _angle + i * seg
		var a1: float = a0 + seg * DASH_RATIO
		var p0: Vector2 = Vector2(cos(a0), sin(a0)) * _radius
		var p1: Vector2 = Vector2(cos(a1), sin(a1)) * _radius
		draw_line(p0, p1, col, LINE_WIDTH, true)
