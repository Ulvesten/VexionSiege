## Purpose: Combat-screen HUD matching VexionSiege_Mockup.html — built fully in code.
extends CanvasLayer

# Vertical layout bands (1080×1920 canvas)
const TOP_BAR_H: float    = 180.0
const STAT_BARS_Y: float  = 180.0
const STAT_BARS_H: float  = 96.0
const BOTTOM_HUD_H: float = 196.0

var _wave_num: Label
var _hp_bar: ProgressBar
var _hp_val: Label
var _sh_row: HBoxContainer
var _shield_bar: ProgressBar
var _sh_val: Label
var _credits_val: Label

var _max_hp: float = 100.0
var _max_sh: float = 0.0

func _ready() -> void:
	_build()
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.ship_damaged.connect(_on_ship_damaged)
	EventBus.shield_initialized.connect(_on_shield_initialized)
	EventBus.shield_damaged.connect(_on_shield_damaged)
	EventBus.shield_broken.connect(_on_shield_broken)
	EventBus.credits_changed.connect(_on_credits_changed)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)

# ── Build ──────────────────────────────────────────────────────────────────

func _build() -> void:
	_build_top_bar()
	_build_stat_bars()
	_build_bottom_hud()

func _build_top_bar() -> void:
	var bar := _make_panel(Palette.BG, Color(0, 0, 0, 0))
	bar.position = Vector2(0, 0)
	bar.size     = Vector2(1080, TOP_BAR_H)
	add_child(bar)

	# Bottom border
	var sep := ColorRect.new()
	sep.color = Palette.BORDER2
	sep.position = Vector2(0, TOP_BAR_H - 1.0)
	sep.size     = Vector2(1080, 1)
	bar.add_child(sep)

	# Wave block — left. Badge above the number; sized so the 66px number can't
	# spill into the stat bars below (this was the overlap bug).
	var wave_vbox := VBoxContainer.new()
	wave_vbox.position = Vector2(54, 48)   # top padding for breathing room
	wave_vbox.add_theme_constant_override("separation", 4)
	bar.add_child(wave_vbox)

	var badge := Label.new()
	badge.text = "WAVE"
	_style_label(badge, 30, UIFonts.mono(), Palette.BLUE)
	wave_vbox.add_child(badge)

	_wave_num = Label.new()
	_wave_num.text = "001"
	_style_label(_wave_num, 66, UIFonts.mono_bold(), Color.WHITE)
	wave_vbox.add_child(_wave_num)

	# Hamburger menu button — right, vertically centred. Now wired.
	var menu := Button.new()
	menu.flat = true
	menu.position = Vector2(1080 - 54 - 96, (TOP_BAR_H - 96) / 2.0)
	menu.size = Vector2(96, 96)
	# Borderless by default (no box around the gear); a subtle box appears on hover.
	menu.add_theme_stylebox_override("normal", UIStyles.empty())
	menu.add_theme_stylebox_override("hover", UIStyles.panel(Palette.S2, Palette.BORDER3, 24))
	menu.add_theme_stylebox_override("pressed", UIStyles.panel(Palette.S3, Palette.BORDER3, 24))
	menu.add_theme_stylebox_override("focus", UIStyles.empty())
	menu.pressed.connect(func(): EventBus.menu_toggled.emit())
	bar.add_child(menu)
	var gear := UIIcons.make_rect(UIIcons.settings(), 56.0)
	if gear:
		gear.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu.add_child(gear)
	else:
		# Fallback: three hamburger lines.
		for i: int in 3:
			var line := ColorRect.new()
			line.color = Palette.MUTED
			line.size = Vector2(42, 4)
			line.position = Vector2(27, 32 + i * 16)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(line)

func _build_stat_bars() -> void:
	var container := _make_panel(Palette.BG, Color(0, 0, 0, 0))
	container.position = Vector2(0, STAT_BARS_Y)
	container.size     = Vector2(1080, STAT_BARS_H)
	add_child(container)

	var sep := ColorRect.new()
	sep.color = Palette.BORDER
	sep.position = Vector2(0, STAT_BARS_H - 1.0)
	sep.size     = Vector2(1080, 1)
	container.add_child(sep)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(54, 18)
	vbox.size     = Vector2(972, 60)
	vbox.add_theme_constant_override("separation", 15)
	container.add_child(vbox)

	# HP row
	var hp_row := HBoxContainer.new()
	hp_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hp_row.add_theme_constant_override("separation", 24)
	vbox.add_child(hp_row)
	hp_row.add_child(_make_stat_label("HP"))
	_hp_bar = _make_progress_bar(Palette.HP_FILL)
	hp_row.add_child(_hp_bar)
	_hp_val = _make_stat_value("100/100")
	hp_row.add_child(_hp_val)

	# SH row (hidden until shield unlocked)
	_sh_row = HBoxContainer.new()
	_sh_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sh_row.add_theme_constant_override("separation", 24)
	_sh_row.visible = false
	vbox.add_child(_sh_row)
	_sh_row.add_child(_make_stat_label("SH"))
	_shield_bar = _make_progress_bar(Palette.SH_FILL)
	_sh_row.add_child(_shield_bar)
	_sh_val = _make_stat_value("0/0")
	_sh_row.add_child(_sh_val)

func _build_bottom_hud() -> void:
	var container := _make_panel(Palette.BG, Color(0, 0, 0, 0))
	container.anchor_top = 1.0
	container.anchor_bottom = 1.0
	container.anchor_left = 0.0
	container.anchor_right = 1.0
	container.offset_top = -BOTTOM_HUD_H
	container.offset_bottom = 0.0
	add_child(container)

	# Top border
	var sep := ColorRect.new()
	sep.color = Palette.BORDER2
	sep.position = Vector2(0, 0)
	sep.size = Vector2(1080, 1)
	container.add_child(sep)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(54, 10)
	vbox.size = Vector2(972, BOTTOM_HUD_H - 20.0)
	vbox.add_theme_constant_override("separation", 8)
	container.add_child(vbox)

	# Credits row
	var credits_row := HBoxContainer.new()
	credits_row.custom_minimum_size = Vector2(0, 40)
	credits_row.add_theme_constant_override("separation", 14)
	vbox.add_child(credits_row)
	var credit_icon := UIIcons.make_rect(UIIcons.credits(), 40.0)
	if credit_icon:
		credit_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		credits_row.add_child(credit_icon)
	var credit_lbl := Label.new()
	credit_lbl.text = "CREDITS"
	credit_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_label(credit_lbl, 27, UIFonts.mono(), Palette.MUTED)
	credits_row.add_child(credit_lbl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_row.add_child(sp)
	_credits_val = Label.new()
	_credits_val.text = "0"
	_credits_val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_label(_credits_val, 48, UIFonts.mono_bold(), Palette.AMBER)
	credits_row.add_child(_credits_val)

	# UPGRADES + STATS buttons
	var btn_row := HBoxContainer.new()
	btn_row.custom_minimum_size = Vector2(0, 64)
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)
	btn_row.add_child(_make_hud_button("UPGRADES", Palette.BLUE,
		func(): EventBus.upgrades_toggle_requested.emit()))
	btn_row.add_child(_make_hud_button("STATS", Palette.TEAL,
		func(): EventBus.stats_toggle_requested.emit()))

	# Ability row — 3 slots (empty until abilities are equipped)
	var ability_row := HBoxContainer.new()
	ability_row.custom_minimum_size = Vector2(0, 44)
	ability_row.add_theme_constant_override("separation", 18)
	vbox.add_child(ability_row)
	for i: int in 3:
		ability_row.add_child(_make_ability_slot())

# ── Builders ─────────────────────────────────────────────────────────────────

func _make_hud_button(text: String, accent: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 64)
	var bg := Color(accent.r, accent.g, accent.b, 0.12)
	var border := Color(accent.r, accent.g, accent.b, 0.30)
	btn.add_theme_stylebox_override("normal", UIStyles.panel(bg, border, 30))
	# Clear hover/press feedback — brighter fill + border.
	btn.add_theme_stylebox_override("hover", UIStyles.btn_accent(accent, 0.32, 0.55, 30))
	btn.add_theme_stylebox_override("pressed", UIStyles.btn_accent(accent, 0.44, 0.75, 30))
	btn.add_theme_stylebox_override("focus", UIStyles.empty())
	btn.add_theme_font_override("font", UIFonts.display_bold())
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", accent)
	btn.pressed.connect(on_press)
	return btn

func _make_ability_slot() -> Panel:
	var slot := Panel.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0, 44)
	slot.add_theme_stylebox_override("panel", UIStyles.panel(Palette.S1, Palette.BORDER2, 24))
	var lbl := Label.new()
	lbl.text = "—"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", UIFonts.mono())
	lbl.add_theme_font_size_override("font_size", 27)
	lbl.add_theme_color_override("font_color", Palette.DIM)
	slot.add_child(lbl)
	return slot

func _make_panel(bg: Color, border: Color, radius: int = 0) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_stat_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(60, 0)
	_style_label(l, 27, UIFonts.mono(), Palette.MUTED)
	return l

func _make_stat_value(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(108, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(l, 27, UIFonts.mono(), Palette.MUTED)
	return l

func _make_progress_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 15)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UIStyles.bar_bg())
	bar.add_theme_stylebox_override("fill", UIStyles.bar_fill(fill_color))
	return bar

func _style_label(l: Label, size: int, font: Font, color: Color) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)

# ── Signal handlers ────────────────────────────────────────────────────────

func _on_wave_started(wave_number: int) -> void:
	_wave_num.text = "%03d" % wave_number

func _on_ship_damaged(_amount: float, current_hp: float) -> void:
	_hp_bar.value = current_hp
	_hp_val.text = "%d/%d" % [int(current_hp), int(_max_hp)]

func _on_shield_initialized(max_sh: float) -> void:
	_max_sh = max_sh
	_shield_bar.max_value = max_sh
	_sh_row.visible = max_sh > 0.0

func _on_shield_damaged(_amount: float, current_sh: float) -> void:
	_shield_bar.value = current_sh
	_sh_val.text = "%d/%d" % [int(current_sh), int(_max_sh)]
	_sh_row.visible = true

func _on_shield_broken() -> void:
	_shield_bar.value = 0.0
	_sh_val.text = "0/%d" % int(_max_sh)

func _on_credits_changed(new_total: BigNum) -> void:
	_credits_val.text = new_total.to_display()

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	if upgrade_id == "max_hp":
		_max_hp = new_value
		_hp_bar.max_value = new_value
