## Purpose: Pooled floating combat-feedback labels — damage numbers and credit popups.
extends Node2D

const POOL_SIZE: int = 20
const BURST_POOL_SIZE: int = 8  # simultaneous death explosions

# Credits counter sits bottom-left of the HUD (mockup "CREDITS" row). Viewport coords.
const CREDITS_TARGET: Vector2 = Vector2(120.0, 1840.0)

var _labels: Array[Label] = []
var _tweens: Array[Tween] = []
var _next: int = 0  # ring index — oldest label is reused when pool is full

var _bursts: Array[CPUParticles2D] = []
var _burst_next: int = 0

func _ready() -> void:
	for i: int in POOL_SIZE:
		var lbl := Label.new()
		lbl.visible = false
		lbl.z_index = 50
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
		_labels.append(lbl)
		_tweens.append(null)
	for i: int in BURST_POOL_SIZE:
		_bursts.append(_make_burst())
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.credit_awarded.connect(_on_credit_awarded)
	EventBus.enemy_killed.connect(_on_enemy_killed)

# ── Damage numbers ──────────────────────────────────────────────────────────

func _on_enemy_damaged(position: Vector2, amount: float, is_crit: bool) -> void:
	var lbl := _acquire()
	lbl.text = _format(amount)
	lbl.add_theme_font_override("font", UIFonts.mono_bold() if is_crit else UIFonts.mono())
	lbl.add_theme_font_size_override("font_size", 42 if is_crit else 32)
	var col: Color = Color("#ffdd44") if is_crit else Color.WHITE  # crits read bright yellow
	lbl.add_theme_color_override("font_color", col)
	lbl.modulate = Color(col.r, col.g, col.b, 1.0)

	# Centre the label on the hit point
	lbl.position = position - Vector2(40.0, 12.0)
	lbl.visible = true

	var idx := _labels.find(lbl)
	var tween := create_tween()
	_tweens[idx] = tween
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): lbl.visible = false)

# ── Credit popups ───────────────────────────────────────────────────────────

func _on_credit_awarded(position: Vector2, amount: float) -> void:
	var lbl := _acquire()
	lbl.text = "+%s" % _format(amount)
	lbl.add_theme_font_override("font", UIFonts.mono())
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Palette.AMBER)
	lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	lbl.scale = Vector2.ONE
	lbl.position = position - Vector2(20.0, 10.0)
	lbl.visible = true

	var idx := _labels.find(lbl)
	var tween := create_tween()
	_tweens[idx] = tween
	tween.set_parallel(true)
	tween.tween_property(lbl, "position", CREDITS_TARGET, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "scale", Vector2(0.6, 0.6), 0.8).set_ease(Tween.EASE_IN)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.45)
	tween.chain().tween_callback(func():
		lbl.visible = false
		lbl.scale = Vector2.ONE
	)

# ── Death explosion bursts (DESIGN §337-341) ────────────────────────────────

func _on_enemy_killed(data: Dictionary) -> void:
	var type: String = data.get("type", "drone")
	var pos: Vector2 = data.get("position", Vector2.ZERO)
	var is_boss: bool = type == "boss"

	var p := _acquire_burst()
	p.position = pos
	p.color = Palette.enemy_color(type)
	# Bosses get a large multi-ring blast; everyone else a tight 8-12 dot burst.
	p.amount = 40 if is_boss else 10
	p.initial_velocity_min = 120.0 if is_boss else 60.0
	p.initial_velocity_max = 360.0 if is_boss else 180.0
	p.lifetime = 0.7 if is_boss else 0.45
	p.scale_amount_min = 4.0 if is_boss else 2.0
	p.scale_amount_max = 9.0 if is_boss else 4.0
	p.restart()
	p.emitting = true

func _make_burst() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.z_index = 40
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2.ZERO
	p.damping_min = 60.0
	p.damping_max = 120.0
	# White→transparent ramp multiplies with `color`, so any type tint fades out.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = ramp
	add_child(p)
	return p

func _acquire_burst() -> CPUParticles2D:
	# Prefer an idle emitter; otherwise reuse the oldest in ring order.
	for p: CPUParticles2D in _bursts:
		if not p.emitting:
			return p
	var idx := _burst_next
	_burst_next = (_burst_next + 1) % BURST_POOL_SIZE
	return _bursts[idx]

# ── Pool ────────────────────────────────────────────────────────────────────

func _acquire() -> Label:
	# Prefer a free (invisible) label; otherwise reuse the oldest via ring index.
	for i: int in POOL_SIZE:
		var lbl: Label = _labels[i]
		if not lbl.visible:
			return lbl
	# All active — reuse oldest, killing its in-flight tween.
	var idx := _next
	_next = (_next + 1) % POOL_SIZE
	if _tweens[idx] != null and _tweens[idx].is_valid():
		_tweens[idx].kill()
	_labels[idx].scale = Vector2.ONE
	return _labels[idx]

func _format(amount: float) -> String:
	if amount >= 1000.0:
		return BigNum.from(amount).to_display()
	return str(int(round(amount)))
