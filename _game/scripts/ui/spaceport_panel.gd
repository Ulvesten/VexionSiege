## Purpose: Spaceport meta-upgrade screen matching VexionSiege_Mockup.html — built fully in code.
extends CanvasLayer

const UPGRADES: Array[Dictionary] = [
	{"id":"reinforced_hull",  "tab":0, "tier":1, "icon":"🔩", "name":"Reinforced Hull",  "desc":"+25 base max HP",         "base_cost":10},
	{"id":"reactor_boost",    "tab":0, "tier":1, "icon":"⚡", "name":"Reactor Boost",    "desc":"+5% base fire rate",      "base_cost":15},
	{"id":"shield_generator", "tab":0, "tier":2, "icon":"🛡", "name":"Shield Gen",       "desc":"+25 max shield",          "base_cost":25},
	{"id":"targeting_system", "tab":0, "tier":2, "icon":"🎯", "name":"Targeting Sys",    "desc":"+3% base crit chance",    "base_cost":20},
	{"id":"engine_coolant",   "tab":0, "tier":3, "icon":"❄",  "name":"Engine Coolant",   "desc":"-10% upgrade cost",       "base_cost":30},
	{"id":"void_extractor",   "tab":1, "tier":2, "icon":"◈",  "name":"Void Extractor",   "desc":"+15% Void Cores per run", "base_cost":20},
	{"id":"starting_credits", "tab":1, "tier":1, "icon":"◉",  "name":"Starting Credits", "desc":"Begin run with bonus ₵",  "base_cost":10},
	{"id":"upgrade_discount", "tab":1, "tier":3, "icon":"✦",  "name":"Upgrade Discount", "desc":"-5% upgrade costs",       "base_cost":25},
	{"id":"galaxy_scanner",   "tab":2, "tier":4, "icon":"🔭", "name":"Galaxy Scanner",   "desc":"Reveal enemy HP bars",    "base_cost":50},
	{"id":"fast_forward",     "tab":2, "tier":4, "icon":"⏩", "name":"Fast Forward",     "desc":"Unlock 2× game speed",    "base_cost":100},
]

var _void_cores_val: Label
var _gems_val: Label
var _active_tab: int = 0
var _tab_buttons: Array[Button] = []
var _grid: GridContainer

# Local mirror of persisted upgrade levels, seeded on open and bumped on purchase,
# so cost display stays in sync without reaching into SpaceportSystem (a scene node,
# not a global) each frame. Pricing/gating mirror the SpaceportSystem model.
var _levels: Dictionary = {}
var _best_wave: int = 0

const COST_GROWTH: float = 1.6
const TIER_UNLOCK_WAVE: Dictionary = {1: 0, 2: 50, 3: 100, 4: 150}

func _cost_for(base_cost: int, level: int) -> int:
	return int(round(base_cost * pow(COST_GROWTH, level)))

func _unlock_wave(tier: int) -> int:
	return TIER_UNLOCK_WAVE.get(tier, 0)

func _is_tier_unlocked(tier: int) -> bool:
	return _best_wave >= _unlock_wave(tier)

# Cosmetic progression bands — distinct space-region names + colours so it reads
# at a glance which band an upgrade sits in. Separate from the gameplay Galaxies.
func _band_for(tier: int) -> Dictionary:
	match tier:
		1:  return {"name": "INNER CORE", "color": Palette.GREEN}
		2:  return {"name": "OUTER RIM",  "color": Palette.BLUE}
		3:  return {"name": "DEEP VOID",  "color": Palette.PURPLE}
		_:  return {"name": "FRONTIER",   "color": Palette.AMBER}

func _ready() -> void:
	layer = 10
	visible = false
	_build()
	EventBus.spaceport_opened.connect(_on_spaceport_opened)
	EventBus.spaceport_closed.connect(_on_spaceport_closed)
	EventBus.void_cores_changed.connect(_on_void_cores_changed)
	EventBus.gems_changed.connect(_on_gems_changed)
	EventBus.meta_upgrade_purchased.connect(_on_meta_purchased)

# ── Build ──────────────────────────────────────────────────────────────────

func _build() -> void:
	# Full-screen BG
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(1080, 0)
	outer.add_theme_constant_override("separation", 0)
	scroll.add_child(outer)

	outer.add_child(_build_header())
	outer.add_child(_build_divider())
	outer.add_child(_build_tab_bar())
	outer.add_child(_build_divider())

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 42)
	grid_margin.add_theme_constant_override("margin_right", 42)
	grid_margin.add_theme_constant_override("margin_top", 36)
	grid_margin.add_theme_constant_override("margin_bottom", 36)
	outer.add_child(grid_margin)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)
	grid_margin.add_child(_grid)

	var run_margin := MarginContainer.new()
	run_margin.add_theme_constant_override("margin_left", 42)
	run_margin.add_theme_constant_override("margin_right", 42)
	run_margin.add_theme_constant_override("margin_bottom", 48)
	outer.add_child(run_margin)

	var run_btn := Button.new()
	run_btn.text = "START NEW RUN"
	run_btn.custom_minimum_size = Vector2(0, 117)
	run_btn.add_theme_stylebox_override("normal",  UIStyles.btn_primary())
	run_btn.add_theme_stylebox_override("hover",   UIStyles.btn_accent(Palette.BLUE, 0.28, 0.6, 36))
	run_btn.add_theme_stylebox_override("pressed", UIStyles.btn_accent(Palette.BLUE, 0.40, 0.8, 36))
	run_btn.add_theme_stylebox_override("focus",   UIStyles.empty())
	run_btn.add_theme_font_override("font", UIFonts.display_bold())
	run_btn.add_theme_font_size_override("font_size", 45)
	run_btn.add_theme_color_override("font_color", Palette.BLUE)
	run_btn.pressed.connect(_on_run_pressed)
	run_margin.add_child(run_btn)

func _build_divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Palette.BORDER2
	d.custom_minimum_size = Vector2(0, 1)
	return d

func _build_header() -> Control:
	# MarginContainer propagates min-size to parent VBox correctly (Panel does not)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   54)
	margin.add_theme_constant_override("margin_right",  54)
	margin.add_theme_constant_override("margin_top",    96)
	margin.add_theme_constant_override("margin_bottom", 42)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	# Left: title block
	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 12)
	hbox.add_child(title_vbox)

	var eyebrow := Label.new()
	eyebrow.text = "META UPGRADES"
	eyebrow.add_theme_font_override("font", UIFonts.mono())
	eyebrow.add_theme_font_size_override("font_size", 27)
	eyebrow.add_theme_color_override("font_color", Palette.MUTED)
	title_vbox.add_child(eyebrow)

	var title := Label.new()
	title.text = "Spaceport"
	title.add_theme_font_override("font", UIFonts.display_bold())
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_vbox.add_child(title)

	# Right: currency chips
	var currency_vbox := VBoxContainer.new()
	currency_vbox.add_theme_constant_override("separation", 12)
	currency_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(currency_vbox)

	var void_result := _make_currency_chip(Palette.PURPLE, "0", "cores", UIIcons.void_cores())
	_void_cores_val = void_result.val
	currency_vbox.add_child(void_result.panel)

	var gem_result := _make_currency_chip(Palette.TEAL, "0", "gems")
	_gems_val = gem_result.val
	currency_vbox.add_child(gem_result.panel)

	return margin

func _build_tab_bar() -> Control:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 90)
	hbox.add_theme_constant_override("separation", 0)

	var _tab_names := PackedStringArray(["Hull", "Economy", "Galaxy"])
	for i: int in 3:
		var tab_name: String = _tab_names[i]
		var btn := Button.new()
		btn.text = tab_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.flat = true
		btn.add_theme_font_override("font", UIFonts.mono())
		btn.add_theme_font_size_override("font_size", 27)
		btn.add_theme_color_override("font_color", Palette.MUTED)
		btn.add_theme_stylebox_override("normal",  UIStyles.empty())
		btn.add_theme_stylebox_override("hover",   UIStyles.empty())
		btn.add_theme_stylebox_override("pressed", UIStyles.empty())
		btn.add_theme_stylebox_override("focus",   UIStyles.empty())
		hbox.add_child(btn)
		_tab_buttons.append(btn)
		var idx := i
		btn.pressed.connect(func(): _switch_tab(idx))

	_update_tab_visuals()
	return hbox

# ─── Currency chip ─────────────────────────────────────────────────────────
# Returns a small typed struct-like dict so caller can add panel to tree and
# keep the value Label reference without fragile get_child() indexing.
class ChipResult:
	var panel: Panel
	var val: Label

func _make_currency_chip(dot_color: Color, amount: String, unit: String,
		icon: Texture2D = null) -> ChipResult:
	var result := ChipResult.new()

	result.panel = Panel.new()
	result.panel.add_theme_stylebox_override("panel", UIStyles.currency_chip())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   30)
	margin.add_theme_constant_override("margin_right",  30)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	result.panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	# Real icon if available, else the coloured dot from the mockup.
	var icon_rect := UIIcons.make_rect(icon, 33.0)
	if icon_rect:
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)
	else:
		var dot := ColorRect.new()
		dot.color = dot_color
		dot.custom_minimum_size = Vector2(21, 21)
		hbox.add_child(dot)

	result.val = Label.new()
	result.val.text = amount
	result.val.add_theme_font_override("font", UIFonts.mono_bold())
	result.val.add_theme_font_size_override("font_size", 33)
	result.val.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(result.val)

	var unit_lbl := Label.new()
	unit_lbl.text = unit
	unit_lbl.add_theme_font_override("font", UIFonts.mono())
	unit_lbl.add_theme_font_size_override("font_size", 27)
	unit_lbl.add_theme_color_override("font_color", Palette.MUTED)
	hbox.add_child(unit_lbl)

	return result

# ─── Upgrade card ──────────────────────────────────────────────────────────

func _populate_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	for entry: Dictionary in UPGRADES:
		if entry.get("tab", 0) != _active_tab:
			continue
		_grid.add_child(_build_sp_card(entry))

func _build_sp_card(entry: Dictionary) -> Control:
	var tier: int = entry.get("tier", 1)
	var band: Dictionary = _band_for(tier)
	var band_color: Color = band["color"]

	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Border tinted to the progression band so each band reads distinctly.
	var band_border := Color(band_color.r, band_color.g, band_color.b, 0.45)
	card.add_theme_stylebox_override("panel", UIStyles.panel(Palette.S1, band_border, 30))

	# MarginContainer inside gives proper padding and propagates size
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   36)
	margin.add_theme_constant_override("margin_right",  36)
	margin.add_theme_constant_override("margin_top",    36)
	margin.add_theme_constant_override("margin_bottom", 36)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# Band eyebrow — names + colours the progression band this upgrade belongs to.
	var band_lbl := Label.new()
	band_lbl.text = band["name"]
	band_lbl.add_theme_font_override("font", UIFonts.mono())
	band_lbl.add_theme_font_size_override("font_size", 24)
	band_lbl.add_theme_color_override("font_color", band_color)
	vbox.add_child(band_lbl)

	var icon_lbl := Label.new()
	icon_lbl.text = entry.get("icon", "●")
	icon_lbl.add_theme_font_size_override("font_size", 54)
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = entry.get("name", "")
	name_lbl.add_theme_font_override("font", UIFonts.display_bold())
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = entry.get("desc", "")
	desc_lbl.add_theme_font_override("font", UIFonts.display())
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.add_theme_color_override("font_color", Palette.MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	# Footer: progress bar + cost
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	vbox.add_child(footer)

	var bar_bg_s := StyleBoxFlat.new()
	bar_bg_s.bg_color = Palette.BAR_BG
	bar_bg_s.corner_radius_top_left     = 4
	bar_bg_s.corner_radius_top_right    = 4
	bar_bg_s.corner_radius_bottom_left  = 4
	bar_bg_s.corner_radius_bottom_right = 4

	var bar_fill_s := StyleBoxFlat.new()
	bar_fill_s.bg_color = Palette.PURPLE
	bar_fill_s.corner_radius_top_left     = 4
	bar_fill_s.corner_radius_top_right    = 4
	bar_fill_s.corner_radius_bottom_left  = 4
	bar_fill_s.corner_radius_bottom_right = 4

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 9)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 0.0
	bar.add_theme_stylebox_override("background", bar_bg_s)
	bar.add_theme_stylebox_override("fill",       bar_fill_s)
	footer.add_child(bar)

	var uid: String = entry.get("id", "")
	var base_cost: int = entry.get("base_cost", 10)
	var level: int = _levels.get(uid, 0)
	var unlocked: bool = _is_tier_unlocked(tier)
	var cost: int = _cost_for(base_cost, level)

	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_override("font", UIFonts.mono_bold())
	cost_lbl.add_theme_font_size_override("font_size", 30)
	if unlocked:
		cost_lbl.text = "%dvc" % cost
		cost_lbl.add_theme_color_override("font_color", Palette.PURPLE)
	else:
		cost_lbl.text = "🔒 Wave %d" % _unlock_wave(tier)
		cost_lbl.add_theme_color_override("font_color", Palette.MUTED)
	footer.add_child(cost_lbl)

	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.45)   # greyed locked terminal

	# Invisible button overlay for tap-to-purchase (disabled while the tier is locked)
	var btn := Button.new()
	btn.flat = false
	btn.disabled = not unlocked
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal",  UIStyles.empty())
	btn.add_theme_stylebox_override("hover",   UIStyles.card_hover())   # card highlights on hover
	btn.add_theme_stylebox_override("pressed", UIStyles.card_hover())
	btn.add_theme_stylebox_override("focus",   UIStyles.empty())
	card.add_child(btn)

	if unlocked:
		btn.pressed.connect(func(): EventBus.void_cores_spend_requested.emit(cost, uid))

	return card

# ── Logic ──────────────────────────────────────────────────────────────────

func _switch_tab(idx: int) -> void:
	_active_tab = idx
	_update_tab_visuals()
	_populate_grid()

func _update_tab_visuals() -> void:
	for i: int in _tab_buttons.size():
		var active := (i == _active_tab)
		_tab_buttons[i].add_theme_color_override(
			"font_color", Palette.PURPLE if active else Palette.MUTED)

func _on_run_pressed() -> void:
	visible = false
	EventBus.spaceport_closed.emit()

func _on_spaceport_opened() -> void:
	_levels = SaveManager.get_value("spaceport", "upgrades", {}).duplicate()
	_best_wave = SaveManager.get_value("lifetime", "best_wave", 0)
	_active_tab = 0
	_update_tab_visuals()
	_populate_grid()
	visible = true

func _on_meta_purchased(id: String) -> void:
	_levels[id] = _levels.get(id, 0) + 1
	_populate_grid()

func _on_spaceport_closed() -> void:
	visible = false

func _on_void_cores_changed(new_total: int) -> void:
	if _void_cores_val:
		_void_cores_val.text = str(new_total)

func _on_gems_changed(new_total: int) -> void:
	if _gems_val:
		_gems_val.text = str(new_total)
