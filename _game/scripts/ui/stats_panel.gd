## Purpose: Slide-up ship-stats panel grouped by category. Live values mirrored from EventBus
## (upgrade_applied / upgrade_purchased / shield_initialized) — no direct manager references.
extends CanvasLayer

# Category ids
const OFFENCE := 0
const DEFENCE := 1
const ECONOMY := 2

# Stat definitions — base values match manager defaults (DESIGN.md). fmt drives display.
const STATS: Array[Dictionary] = [
	{"id": "fire_rate",        "label": "Fire Rate",       "cat": OFFENCE, "base": 1.0,   "fmt": "per_sec"},
	{"id": "damage",           "label": "Damage",          "cat": OFFENCE, "base": 10.0,  "fmt": "raw"},
	{"id": "crit_chance",      "label": "Crit Chance",     "cat": OFFENCE, "base": 0.0,   "fmt": "percent"},
	{"id": "crit_multiplier",  "label": "Crit Multiplier", "cat": OFFENCE, "base": 2.0,   "fmt": "mult"},
	{"id": "projectile_count", "label": "Projectiles",     "cat": OFFENCE, "base": 1.0,   "fmt": "int"},
	{"id": "projectile_speed", "label": "Bullet Speed",    "cat": OFFENCE, "base": 800.0, "fmt": "raw"},
	{"id": "range",            "label": "Range",           "cat": OFFENCE, "base": 600.0, "fmt": "raw"},
	{"id": "max_hp",           "label": "Max HP",          "cat": DEFENCE, "base": 100.0, "fmt": "raw"},
	{"id": "hp_regen",         "label": "HP Regen",        "cat": DEFENCE, "base": 0.0,   "fmt": "per_sec"},
	{"id": "damage_reduction", "label": "Damage Reduction","cat": DEFENCE, "base": 0.0,   "fmt": "percent"},
	{"id": "shield",           "label": "Max Shield",      "cat": DEFENCE, "base": 0.0,   "fmt": "raw"},
	{"id": "credit_magnet",    "label": "Credit Magnet",   "cat": ECONOMY, "base": 1.0,   "fmt": "mult"},
	{"id": "void_harvester",   "label": "Void Harvester",  "cat": ECONOMY, "base": 1.0,   "fmt": "mult"},
]

const PANEL_REST_Y := 720.0
const PANEL_HIDDEN_Y := 1960.0

var _panel: Panel
var _open: bool = false
var _tween: Tween
var _dragging: bool = false

# Per-stat live state
var _current: Dictionary = {}      # id -> current value
var _counts: Dictionary = {}       # id -> upgrade count
var _value_labels: Dictionary = {} # id -> Label (current value)
var _count_labels: Dictionary = {} # id -> Label (Lv N)

func _ready() -> void:
	layer = 11  # above HUD, below wave announcement (20)
	_init_state()
	_build()
	EventBus.stats_toggle_requested.connect(_toggle)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.shield_initialized.connect(_on_shield_initialized)
	EventBus.game_started.connect(_on_game_started)

# ── State ───────────────────────────────────────────────────────────────────

func _init_state() -> void:
	for s: Dictionary in STATS:
		_current[s["id"]] = s["base"]
		_counts[s["id"]] = 0

func _on_game_started() -> void:
	_init_state()
	_refresh_all()

# ── Build ───────────────────────────────────────────────────────────────────

func _build() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(0, PANEL_HIDDEN_Y)
	_panel.size = Vector2(1080, 1200)
	_panel.visible = false
	var style := UIStyles.panel(Palette.S1, Palette.BORDER2, 0)
	style.border_width_top = 1
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.position = Vector2(0, 0)
	outer.size = Vector2(1080, 1200)
	outer.add_theme_constant_override("separation", 0)
	_panel.add_child(outer)

	outer.add_child(_build_drag_handle())
	outer.add_child(_build_header())
	outer.add_child(_divider(Palette.BORDER2))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 980)
	outer.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	_build_section(list, "OFFENCE", OFFENCE)
	_build_section(list, "DEFENCE", DEFENCE)
	_build_section(list, "ECONOMY", ECONOMY)

func _build_header() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 24)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(title_vbox)

	var eyebrow := Label.new()
	eyebrow.text = "SHIP STATUS"
	eyebrow.add_theme_font_override("font", UIFonts.mono())
	eyebrow.add_theme_font_size_override("font_size", 27)
	eyebrow.add_theme_color_override("font_color", Palette.MUTED)
	title_vbox.add_child(eyebrow)

	var title := Label.new()
	title.text = "Stats"
	title.add_theme_font_override("font", UIFonts.display_bold())
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_vbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(90, 90)
	close_btn.add_theme_stylebox_override("normal", UIStyles.panel(Palette.S2, Palette.BORDER2, 18))
	close_btn.add_theme_stylebox_override("hover", UIStyles.panel(Palette.S2, Palette.BORDER3, 18))
	close_btn.add_theme_stylebox_override("pressed", UIStyles.panel(Palette.S3, Palette.BORDER3, 18))
	close_btn.add_theme_stylebox_override("focus", UIStyles.empty())
	close_btn.add_theme_font_override("font", UIFonts.mono())
	close_btn.add_theme_font_size_override("font_size", 36)
	close_btn.add_theme_color_override("font_color", Palette.MUTED)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close)
	hbox.add_child(close_btn)

	return margin

func _build_section(parent: VBoxContainer, title: String, category: int) -> void:
	# Section header
	var head_margin := MarginContainer.new()
	head_margin.add_theme_constant_override("margin_left", 54)
	head_margin.add_theme_constant_override("margin_right", 54)
	head_margin.add_theme_constant_override("margin_top", 30)
	head_margin.add_theme_constant_override("margin_bottom", 12)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", UIFonts.mono())
	head.add_theme_font_size_override("font_size", 27)
	head.add_theme_color_override("font_color", Palette.BLUE)
	head_margin.add_child(head)
	parent.add_child(head_margin)
	parent.add_child(_divider(Palette.BORDER))

	for s: Dictionary in STATS:
		if s["cat"] == category:
			parent.add_child(_build_row(s))

func _build_row(s: Dictionary) -> Control:
	var sid: String = s["id"]
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = s["label"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", UIFonts.display())
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	row.add_child(name_lbl)

	# Base value
	var base_lbl := Label.new()
	base_lbl.text = _format(s["base"], s["fmt"])
	base_lbl.custom_minimum_size = Vector2(150, 0)
	base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	base_lbl.add_theme_font_override("font", UIFonts.mono())
	base_lbl.add_theme_font_size_override("font_size", 27)
	base_lbl.add_theme_color_override("font_color", Palette.DIM)
	row.add_child(base_lbl)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_override("font", UIFonts.mono())
	arrow.add_theme_font_size_override("font_size", 27)
	arrow.add_theme_color_override("font_color", Palette.DIM)
	row.add_child(arrow)

	# Current value
	var cur_lbl := Label.new()
	cur_lbl.text = _format(s["base"], s["fmt"])
	cur_lbl.custom_minimum_size = Vector2(150, 0)
	cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cur_lbl.add_theme_font_override("font", UIFonts.mono_bold())
	cur_lbl.add_theme_font_size_override("font_size", 30)
	cur_lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(cur_lbl)
	_value_labels[sid] = cur_lbl

	# Upgrade count
	var count_lbl := Label.new()
	count_lbl.text = "Lv 0"
	count_lbl.custom_minimum_size = Vector2(120, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_override("font", UIFonts.mono())
	count_lbl.add_theme_font_size_override("font_size", 27)
	count_lbl.add_theme_color_override("font_color", Palette.MUTED)
	row.add_child(count_lbl)
	_count_labels[sid] = count_lbl

	return margin

func _divider(color: Color) -> ColorRect:
	var d := ColorRect.new()
	d.color = color
	d.custom_minimum_size = Vector2(0, 1)
	return d

# ── Live updates ────────────────────────────────────────────────────────────

func _on_upgrade_applied(stat: String, value: float) -> void:
	if not _current.has(stat):
		return
	_current[stat] = value
	_refresh_stat(stat)

func _on_upgrade_purchased(upgrade_id: String) -> void:
	if not _counts.has(upgrade_id):
		return
	_counts[upgrade_id] = _counts[upgrade_id] + 1
	_refresh_stat(upgrade_id)

func _on_shield_initialized(max_shield: float) -> void:
	_current["shield"] = max_shield
	_refresh_stat("shield")

func _refresh_all() -> void:
	for s: Dictionary in STATS:
		_refresh_stat(s["id"])

func _refresh_stat(sid: String) -> void:
	if not _value_labels.has(sid):
		return
	var meta: Dictionary = _stat_meta(sid)
	var base: float = meta["base"]
	var cur: float = _current[sid]
	var lbl: Label = _value_labels[sid]
	lbl.text = _format(cur, meta["fmt"])
	# Green when buffed above base, white otherwise.
	lbl.add_theme_color_override("font_color", Palette.GREEN if cur > base else Color.WHITE)
	var count: int = _counts[sid]
	_count_labels[sid].text = "Lv %d" % count
	_count_labels[sid].add_theme_color_override(
		"font_color", Palette.GREEN if count > 0 else Palette.MUTED)

func _stat_meta(sid: String) -> Dictionary:
	for s: Dictionary in STATS:
		if s["id"] == sid:
			return s
	return {}

func _format(value: float, fmt: String) -> String:
	match fmt:
		"per_sec":  return "%.1f/s" % value
		"percent":  return "%d%%" % roundi(value * 100.0)
		"mult":     return "%.2f×" % value
		"int":      return "%d" % roundi(value)
		_:          return "%.0f" % value if value < 1000.0 else BigNum.from(value).to_display()

# ── Open / close ─────────────────────────────────────────────────────────────

func _toggle() -> void:
	if _open:
		_close()
	else:
		_open_panel()

func _open_panel() -> void:
	_refresh_all()
	_open = true
	_panel.position.y = PANEL_HIDDEN_Y
	_panel.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", PANEL_REST_Y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _close() -> void:
	_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", PANEL_HIDDEN_Y, 0.25).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _panel.visible = false)

# ── Drag handle (touch / mouse) ──────────────────────────────────────────────
# A grab bar at the top of the panel. Drag it to slide the panel up/down; on
# release it snaps open or closed based on how far it was pulled.
func _build_drag_handle() -> Control:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 48)
	cc.mouse_filter = Control.MOUSE_FILTER_STOP
	var bar := ColorRect.new()
	bar.color = Palette.BORDER3
	bar.custom_minimum_size = Vector2(120, 9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let the container receive the drag
	cc.add_child(bar)
	cc.gui_input.connect(_on_handle_input)
	return cc

func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			if _tween != null and _tween.is_valid():
				_tween.kill()
		elif _dragging:
			_dragging = false
			_settle()
	elif _dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		_panel.position.y = clampf(_panel.position.y + event.relative.y, PANEL_REST_Y, PANEL_HIDDEN_Y)

func _settle() -> void:
	# Snap to whichever end the panel is closest to.
	if _panel.position.y > (PANEL_REST_Y + PANEL_HIDDEN_Y) * 0.5:
		_close()
	else:
		_open = true
		_tween = create_tween()
		_tween.tween_property(_panel, "position:y", PANEL_REST_Y, 0.2).set_ease(Tween.EASE_OUT)
