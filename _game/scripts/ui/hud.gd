## Purpose: Combat-screen HUD — built fully in code.
## Top bar: wave + credits + menu. Wave Info band: aggregate enemy HP + composition.
## Footer: ship HP (with shield overlay) + Energy, then UPGRADES/STATS + ability slots.
extends CanvasLayer

# Vertical layout bands (1080×1920 canvas)
const TOP_BAR_H: float    = 180.0
const WAVE_INFO_Y: float  = 180.0
const WAVE_INFO_H: float  = 132.0
const BOTTOM_HUD_H: float = 252.0

var _wave_num: Label
var _credits_val: Label

# Wave Info
var _threat_bar: ProgressBar
var _threat_val: Label
var _comp_row: HBoxContainer
var _last_counts: Dictionary = {}

# Footer bars
var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _hp_val: Label
var _energy_bar: ProgressBar
var _energy_val: Label

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
	EventBus.wave_threat_changed.connect(_on_wave_threat_changed)

# ── Build ──────────────────────────────────────────────────────────────────

func _build() -> void:
	_build_top_bar()
	_build_wave_info()
	_build_footer()

func _build_top_bar() -> void:
	var bar := _make_panel(Palette.BG, Color(0, 0, 0, 0))
	bar.position = Vector2(0, 0)
	bar.size     = Vector2(1080, TOP_BAR_H)
	add_child(bar)

	var sep := ColorRect.new()
	sep.color = Palette.BORDER2
	sep.position = Vector2(0, TOP_BAR_H - 1.0)
	sep.size     = Vector2(1080, 1)
	bar.add_child(sep)

	# Wave block — left.
	var wave_vbox := VBoxContainer.new()
	wave_vbox.position = Vector2(54, 44)
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

	# Credits — moved here from the footer. Sits left of the gear, right-aligned.
	var credits_row := HBoxContainer.new()
	credits_row.position = Vector2(560, 56)
	credits_row.size = Vector2(330, 68)
	credits_row.alignment = BoxContainer.ALIGNMENT_END
	credits_row.add_theme_constant_override("separation", 12)
	bar.add_child(credits_row)
	var credit_icon := UIIcons.make_rect(UIIcons.credits(), 40.0)
	if credit_icon:
		credit_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		credits_row.add_child(credit_icon)
	_credits_val = Label.new()
	_credits_val.text = "0"
	_credits_val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_label(_credits_val, 48, UIFonts.mono_bold(), Palette.AMBER)
	credits_row.add_child(_credits_val)

	# Gear menu — far right.
	var menu := Button.new()
	menu.flat = true
	menu.position = Vector2(1080 - 54 - 96, (TOP_BAR_H - 96) / 2.0)
	menu.size = Vector2(96, 96)
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
		for i: int in 3:
			var line := ColorRect.new()
			line.color = Palette.MUTED
			line.size = Vector2(42, 4)
			line.position = Vector2(27, 32 + i * 16)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(line)

func _build_wave_info() -> void:
	var container := _make_panel(Palette.BG, Color(0, 0, 0, 0))
	container.position = Vector2(0, WAVE_INFO_Y)
	container.size     = Vector2(1080, WAVE_INFO_H)
	add_child(container)

	var sep := ColorRect.new()
	sep.color = Palette.BORDER
	sep.position = Vector2(0, WAVE_INFO_H - 1.0)
	sep.size     = Vector2(1080, 1)
	container.add_child(sep)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(54, 18)
	vbox.size     = Vector2(972, WAVE_INFO_H - 30.0)
	vbox.add_theme_constant_override("separation", 12)
	container.add_child(vbox)

	# Enemy threat bar row: label + bar + value.
	var bar_row := HBoxContainer.new()
	bar_row.custom_minimum_size = Vector2(0, 36)
	bar_row.add_theme_constant_override("separation", 24)
	vbox.add_child(bar_row)
	bar_row.add_child(_make_stat_label("ENEMIES"))
	_threat_bar = _make_progress_bar(Palette.CORAL)
	bar_row.add_child(_threat_bar)
	_threat_val = _make_stat_value("0")
	_threat_val.custom_minimum_size = Vector2(150, 0)
	bar_row.add_child(_threat_val)

	# Composition chips (● drone×6 ⬢ bruiser×2 …) — rebuilt when counts change.
	_comp_row = HBoxContainer.new()
	_comp_row.custom_minimum_size = Vector2(0, 34)
	_comp_row.add_theme_constant_override("separation", 30)
	vbox.add_child(_comp_row)

func _build_footer() -> void:
	var container := _make_panel(Palette.BG, Color(0, 0, 0, 0))
	container.anchor_top = 1.0
	container.anchor_bottom = 1.0
	container.anchor_left = 0.0
	container.anchor_right = 1.0
	container.offset_top = -BOTTOM_HUD_H
	container.offset_bottom = 0.0
	add_child(container)

	var sep := ColorRect.new()
	sep.color = Palette.BORDER2
	sep.position = Vector2(0, 0)
	sep.size = Vector2(1080, 1)
	container.add_child(sep)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(54, 16)
	vbox.size = Vector2(972, BOTTOM_HUD_H - 28.0)
	vbox.add_theme_constant_override("separation", 12)
	container.add_child(vbox)

	# Bars row: HP (with shield overlay) on the left, Energy on the right.
	var bars := HBoxContainer.new()
	bars.custom_minimum_size = Vector2(0, 54)
	bars.add_theme_constant_override("separation", 36)
	vbox.add_child(bars)
	bars.add_child(_build_hp_cell())
	bars.add_child(_build_energy_cell())

	# UPGRADES + STATS buttons
	var btn_row := HBoxContainer.new()
	btn_row.custom_minimum_size = Vector2(0, 64)
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)
	btn_row.add_child(_make_hud_button("UPGRADES", Palette.BLUE,
		func(): EventBus.upgrades_toggle_requested.emit()))
	btn_row.add_child(_make_hud_button("STATS", Palette.TEAL,
		func(): EventBus.stats_toggle_requested.emit()))

	# Ability slots
	var ability_row := HBoxContainer.new()
	ability_row.custom_minimum_size = Vector2(0, 44)
	ability_row.add_theme_constant_override("separation", 18)
	vbox.add_child(ability_row)
	for i: int in 3:
		ability_row.add_child(_make_ability_slot())

# HP cell — "HP" label + a bar with the shield drawn ON TOP of the HP fill + value.
func _build_hp_cell() -> Control:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 18)
	cell.add_child(_make_stat_label("HP"))

	_hp_bar = _make_progress_bar(Palette.HP_FILL)
	# Shield bar overlays the HP bar (same rect) in blue — shows the shielded portion.
	_shield_bar = ProgressBar.new()
	_shield_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shield_bar.show_percentage = false
	_shield_bar.max_value = 100.0
	_shield_bar.value = 0.0
	_shield_bar.visible = false
	_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh_bg := StyleBoxEmpty.new()
	_shield_bar.add_theme_stylebox_override("background", sh_bg)
	var sh_fill := StyleBoxFlat.new()
	sh_fill.bg_color = Color(Palette.SH_FILL.r, Palette.SH_FILL.g, Palette.SH_FILL.b, 0.75)
	sh_fill.corner_radius_top_left = 9; sh_fill.corner_radius_top_right = 9
	sh_fill.corner_radius_bottom_left = 9; sh_fill.corner_radius_bottom_right = 9
	_shield_bar.add_theme_stylebox_override("fill", sh_fill)
	_hp_bar.add_child(_shield_bar)
	cell.add_child(_hp_bar)

	_hp_val = _make_stat_value("100/100")
	cell.add_child(_hp_val)
	return cell

# Energy cell — placeholder bar (full) for future abilities.
func _build_energy_cell() -> Control:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 18)
	cell.add_child(_make_stat_label("EN"))
	_energy_bar = _make_progress_bar(Palette.TEAL)
	_energy_bar.value = 100.0
	cell.add_child(_energy_bar)
	_energy_val = _make_stat_value("100/100")
	cell.add_child(_energy_val)
	return cell

# ── Builders ─────────────────────────────────────────────────────────────────

func _make_hud_button(text: String, accent: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 64)
	var bg := Color(accent.r, accent.g, accent.b, 0.12)
	var border := Color(accent.r, accent.g, accent.b, 0.30)
	btn.add_theme_stylebox_override("normal", UIStyles.panel(bg, border, 30))
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
	l.custom_minimum_size = Vector2(96, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_label(l, 27, UIFonts.mono(), Palette.MUTED)
	return l

func _make_stat_value(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(120, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	# Shield shares the HP bar's scale so the blue overlay reads as a shielded fraction.
	_shield_bar.max_value = _max_hp
	_shield_bar.visible = max_sh > 0.0

func _on_shield_damaged(_amount: float, current_sh: float) -> void:
	_shield_bar.max_value = _max_hp
	_shield_bar.value = current_sh
	_shield_bar.visible = current_sh > 0.0

func _on_shield_broken() -> void:
	_shield_bar.value = 0.0
	_shield_bar.visible = false

func _on_credits_changed(new_total: BigNum) -> void:
	_credits_val.text = new_total.to_display()

func _on_upgrade_applied(upgrade_id: String, new_value: float) -> void:
	if upgrade_id == "max_hp":
		_max_hp = new_value
		_hp_bar.max_value = new_value
		_shield_bar.max_value = new_value
		# Refresh the value label so the max can't lag the new HP (showed "120/100").
		_hp_val.text = "%d/%d" % [int(_hp_bar.value), int(_max_hp)]

func _on_wave_threat_changed(current_hp: float, max_hp: float, counts: Dictionary) -> void:
	if max_hp > 0.0:
		_threat_bar.max_value = max_hp
		_threat_bar.value = current_hp
	_threat_val.text = "%s hp" % BigNum.from(current_hp).to_display()
	if counts != _last_counts:
		_last_counts = counts.duplicate()
		_rebuild_composition(counts)

# Rebuild the enemy-type chips (glyph ×count, type-coloured).
func _rebuild_composition(counts: Dictionary) -> void:
	for c: Node in _comp_row.get_children():
		c.queue_free()
	# Stable display order.
	for t: String in ["boss", "bruiser", "bomber", "shielder", "drone", "swarm"]:
		if not counts.has(t) or int(counts[t]) <= 0:
			continue
		var chip := Label.new()
		chip.text = "%s %d" % [EnemyDefs.glyph(t), int(counts[t])]
		chip.add_theme_font_override("font", UIFonts.mono())
		chip.add_theme_font_size_override("font_size", 27)
		chip.add_theme_color_override("font_color", Palette.enemy_color(t))
		_comp_row.add_child(chip)
