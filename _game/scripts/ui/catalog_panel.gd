## Purpose: Read-only catalog of EVERY in-run upgrade, grouped by category, opened by the
## bottom-HUD UPGRADES button. Shows each upgrade's current level + next cost (or its
## locked / maxed / not-yet-implemented state). Buying still happens at the wave-clear shop.
extends CanvasLayer

const PANEL_REST_Y := 540.0      # 1380px-tall panel covers most of the screen
const PANEL_HIDDEN_Y := 1960.0
const PANEL_H := 1380.0

const SECTIONS: Array = [
	[UpgradeDefs.OFFENSE, "OFFENSIVE"],
	[UpgradeDefs.DEFENSE, "DEFENSIVE"],
	[UpgradeDefs.ECONOMY, "ECONOMY"],
]

var _panel: Panel
var _list: VBoxContainer
var _open: bool = false
var _tween: Tween
var _dragging: bool = false

# Live mirror of purchased levels (built from EventBus, like the shop/stats panels).
var _levels: Dictionary = {}
var _current_wave: int = 1

func _ready() -> void:
	layer = 12   # above HUD + stats, below wave announcement (20)
	_build()
	EventBus.upgrades_toggle_requested.connect(_toggle)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.wave_started.connect(func(n: int): _current_wave = n)
	EventBus.game_started.connect(func(): _levels.clear())

# ── Build ────────────────────────────────────────────────────────────────────

func _build() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(0, PANEL_HIDDEN_Y)
	_panel.size = Vector2(1080, PANEL_H)
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
	outer.size = Vector2(1080, PANEL_H)
	outer.add_theme_constant_override("separation", 0)
	_panel.add_child(outer)

	outer.add_child(_build_drag_handle())
	outer.add_child(_build_header())
	outer.add_child(_divider(Palette.BORDER2))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, PANEL_H - 220.0)
	outer.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)

# A grab bar at the top — drag the panel up/down (touch or mouse); snaps on release.
func _build_drag_handle() -> Control:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 42)
	cc.mouse_filter = Control.MOUSE_FILTER_STOP
	var bar := ColorRect.new()
	bar.color = Palette.BORDER3
	bar.custom_minimum_size = Vector2(120, 9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(bar)
	cc.gui_input.connect(_on_handle_input)
	return cc

func _build_header() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 24)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(title_vbox)

	var eyebrow := Label.new()
	eyebrow.text = "UPGRADE CATALOG"
	eyebrow.add_theme_font_override("font", UIFonts.mono())
	eyebrow.add_theme_font_size_override("font_size", 27)
	eyebrow.add_theme_color_override("font_color", Palette.MUTED)
	title_vbox.add_child(eyebrow)

	var title := Label.new()
	title.text = "Upgrades"
	title.add_theme_font_override("font", UIFonts.display_bold())
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_vbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(90, 90)
	close_btn.add_theme_stylebox_override("normal", UIStyles.panel(Palette.S2, Palette.BORDER2, 18))
	close_btn.add_theme_stylebox_override("hover", UIStyles.panel(Palette.S3, Palette.BORDER3, 18))
	close_btn.add_theme_stylebox_override("pressed", UIStyles.panel(Palette.S3, Palette.BORDER3, 18))
	close_btn.add_theme_stylebox_override("focus", UIStyles.empty())
	close_btn.add_theme_font_override("font", UIFonts.mono())
	close_btn.add_theme_font_size_override("font_size", 36)
	close_btn.add_theme_color_override("font_color", Palette.MUTED)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close)
	hbox.add_child(close_btn)

	return margin

# ── Rows ──────────────────────────────────────────────────────────────────────

func _populate() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for s: Array in SECTIONS:
		_build_section(s[0], s[1])

func _build_section(category: int, title: String) -> void:
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
	_list.add_child(head_margin)
	_list.add_child(_divider(Palette.BORDER))

	for entry: Dictionary in UpgradeDefs.POOL:
		if entry.get("cat", UpgradeDefs.OFFENSE) == category:
			_list.add_child(_build_row(entry))

func _build_row(entry: Dictionary) -> Control:
	var id: String = entry["id"]
	var rarity: int = entry.get("rarity", 0)
	var level: int = _levels.get(id, 0)
	var maxlvl: int = entry.get("max", 0)
	var enabled: bool = entry.get("enabled", true)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 27)
	margin.add_child(row)

	# Icon well.
	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(78, 78)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.add_theme_stylebox_override("panel", UIStyles.panel(Palette.S2, Palette.rarity_border(rarity), 18))
	row.add_child(icon_panel)
	var icon := Label.new()
	icon.text = entry.get("icon", "●")
	icon.add_theme_font_size_override("font_size", 36)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_panel.add_child(icon)

	# Name + description.
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = entry.get("label", "")
	name_lbl.add_theme_font_override("font", UIFonts.display_bold())
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", Color.WHITE if enabled else Palette.MUTED)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = entry.get("desc", "")
	desc_lbl.add_theme_font_override("font", UIFonts.display())
	desc_lbl.add_theme_font_size_override("font_size", 27)
	desc_lbl.add_theme_color_override("font_color", Palette.MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(desc_lbl)

	# Right column — level + state/cost.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)

	var level_lbl := Label.new()
	level_lbl.text = "Lv %d/%d" % [level, maxlvl]
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_lbl.add_theme_font_override("font", UIFonts.mono())
	level_lbl.add_theme_font_size_override("font_size", 27)
	level_lbl.add_theme_color_override("font_color", Palette.GREEN if level > 0 else Palette.MUTED)
	right.add_child(level_lbl)

	var state := _row_state(entry, level)
	var state_lbl := Label.new()
	state_lbl.text = state[0]
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_lbl.add_theme_font_override("font", UIFonts.mono_bold())
	state_lbl.add_theme_font_size_override("font_size", 30)
	state_lbl.add_theme_color_override("font_color", state[1])
	right.add_child(state_lbl)

	return margin

# Returns [text, color] for the right-hand state line.
func _row_state(entry: Dictionary, level: int) -> Array:
	if not entry.get("enabled", true):
		return ["SOON", Palette.MUTED]
	if level >= entry.get("max", 9999):
		return ["MAX", Palette.GREEN]
	if _current_wave < entry.get("unlock", 1):
		return ["🔒 W%d" % entry.get("unlock", 1), Palette.MUTED]
	var cost: int = UpgradeDefs.cost_for(entry.get("rarity", 0), level, UpgradeDefs.discount_mult())
	return ["%d₵" % cost, Palette.AMBER]

func _divider(color: Color) -> ColorRect:
	var d := ColorRect.new()
	d.color = color
	d.custom_minimum_size = Vector2(0, 1)
	return d

# ── Drag ──────────────────────────────────────────────────────────────────────

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
	if _panel.position.y > (PANEL_REST_Y + PANEL_HIDDEN_Y) * 0.5:
		_close()
	else:
		_open = true
		_tween = create_tween()
		_tween.tween_property(_panel, "position:y", PANEL_REST_Y, 0.2).set_ease(Tween.EASE_OUT)

# ── Open / close ────────────────────────────────────────────────────────────────

func _toggle() -> void:
	if _open:
		_close()
	else:
		_open_panel()

func _open_panel() -> void:
	_populate()
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

func _on_upgrade_purchased(id: String) -> void:
	_levels[id] = _levels.get(id, 0) + 1
	if _open:
		_populate()
