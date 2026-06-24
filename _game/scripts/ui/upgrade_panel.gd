## Purpose: Wave-clear upgrade panel matching the upgrade screen in VexionSiege_Mockup.html.
extends CanvasLayer

# "max" = max level (DESIGN §143-177); upgrades at max are excluded from the offer pool.
const UPGRADE_POOL: Array[Dictionary] = [
	{"id":"fire_rate",        "label":"Fire Rate",        "desc":"+12% shots per second",          "rarity":0, "unlock":1,  "max":20, "icon":"⚡"},
	{"id":"damage",           "label":"Damage",           "desc":"+18% base damage",               "rarity":0, "unlock":1,  "max":20, "icon":"💥"},
	{"id":"crit_chance",      "label":"Crit Chance",      "desc":"+5% critical hit chance",         "rarity":1, "unlock":1,  "max":15, "icon":"🎯"},
	{"id":"crit_multiplier",  "label":"Crit Damage",      "desc":"+0.25× on critical hits",         "rarity":1, "unlock":5,  "max":10, "icon":"✦"},
	{"id":"projectile_count", "label":"Multi-Shot",       "desc":"+1 projectile per shot",          "rarity":1, "unlock":10, "max":5,  "icon":"◈"},
	{"id":"projectile_speed", "label":"Bullet Speed",     "desc":"+15% projectile speed",           "rarity":0, "unlock":1,  "max":10, "icon":"→"},
	{"id":"range",            "label":"Range",            "desc":"+8% attack range",               "rarity":0, "unlock":1,  "max":15, "icon":"◎"},
	{"id":"max_hp",           "label":"Max HP",           "desc":"+20 max hull HP",                "rarity":0, "unlock":1,  "max":20, "icon":"♥"},
	{"id":"hp_regen",         "label":"HP Regen",         "desc":"+0.5 HP per second",             "rarity":0, "unlock":5,  "max":15, "icon":"✚"},
	{"id":"damage_reduction", "label":"Armor",            "desc":"-3% incoming damage",            "rarity":1, "unlock":10, "max":10, "icon":"🛡"},
	{"id":"credit_magnet",    "label":"Credit Magnet",    "desc":"+15% credits from kills",        "rarity":0, "unlock":1,  "max":20, "icon":"◉"},
	{"id":"void_harvester",   "label":"Void Harvester",   "desc":"+10% Void Cores per run",        "rarity":1, "unlock":1,  "max":10, "icon":"◈"},
	{"id":"chain_lightning",  "label":"Chain Lightning",  "desc":"On hit, arc to nearby enemy 60%","rarity":2, "unlock":15, "max":5,  "icon":"🔗", "enabled": false},
	{"id":"explosive_round",  "label":"Explosive Round",  "desc":"On kill, AoE explosion",         "rarity":2, "unlock":20, "max":5,  "icon":"💣", "enabled": false},
	{"id":"second_wind",      "label":"Second Wind",      "desc":"On death, revive once at 25% HP","rarity":3, "unlock":50, "max":1,  "icon":"🛡", "enabled": false},
]

var _panel: Panel
var _header_wave: Label
var _cards_vbox: VBoxContainer
var _footer: Label
# Full-panel transparent button, only active during a manual (read-only) review.
# The panel covers the bottom-HUD UPGRADES button, so a second UPGRADES tap can't
# reach it — this on-panel catcher is the reachable close target. Disabled on
# wave-clear so it doesn't swallow taps meant for the (enabled) upgrade cards.
var _close_catcher: Button
var _current_upgrades: Array[String] = []
var _card_nodes: Array[Control] = []

# Local mirror of purchased levels. This panel is the only emitter of
# upgrade_purchased, so it can track levels itself without reaching into a manager.
var _levels: Dictionary = {}

# When shown on wave clear, picking advances to the next wave and a 10s auto-pick
# runs. When opened manually from the UPGRADES button, neither happens.
var _advance_on_close: bool = true
var _current_wave: int = 1
var _auto_timer: Timer
var _countdown: int = 0

const PANEL_REST_Y  := 1100.0   # panel is 820px tall → covers y 1100–1920
const PANEL_HIDDEN_Y := 1960.0
const AUTO_PICK_SECONDS := 10

# In-run shop pricing: cost = rarity_base × 1.55 ^ (that upgrade's own level).
const RARITY_BASE: Array[int] = [5, 18, 50, 150]   # common, rare, epic, legendary
const COST_GROWTH: float = 1.55

var _credits_value: float = 0.0
var _pending_uid: String = ""
var _countdown_bar: ProgressBar

func _ready() -> void:
	_build()
	_auto_timer = Timer.new()
	_auto_timer.wait_time = 1.0
	_auto_timer.one_shot = false
	_auto_timer.timeout.connect(_on_auto_tick)
	add_child(_auto_timer)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.wave_started.connect(func(n: int): _current_wave = n)
	EventBus.upgrades_toggle_requested.connect(_on_upgrades_toggle_requested)
	EventBus.game_started.connect(func(): _levels.clear())
	EventBus.credits_changed.connect(func(c: BigNum): _credits_value = c.value)
	EventBus.credits_spend_result.connect(_on_spend_result)

# ── Build ──────────────────────────────────────────────────────────────────

func _build() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(0, PANEL_HIDDEN_Y)
	_panel.size     = Vector2(1080, 820)
	_panel.visible  = false
	var panel_style := UIStyles.panel(Palette.S1, Palette.BORDER2, 0)
	panel_style.border_width_top = 1
	panel_style.border_width_left = 0
	panel_style.border_width_right = 0
	panel_style.border_width_bottom = 0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.position = Vector2(0, 0)
	outer_vbox.size     = Vector2(1080, 820)
	outer_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(outer_vbox)

	# Header
	var header := _build_header()
	outer_vbox.add_child(header)

	# Separator
	var sep := ColorRect.new()
	sep.color = Palette.BORDER2
	sep.custom_minimum_size = Vector2(0, 1)
	outer_vbox.add_child(sep)

	# Cards list
	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.add_child(_cards_vbox)

	# Footer
	_footer = Label.new()
	_footer.text = "TAP AN UPGRADE TO PURCHASE"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_override("font", UIFonts.mono())
	_footer.add_theme_font_size_override("font_size", 27)   # 9px * 3
	_footer.add_theme_color_override("font_color", Palette.MUTED)
	_footer.custom_minimum_size = Vector2(0, 48)
	outer_vbox.add_child(_footer)

	# Review-mode close catcher — added last so it sits above the cards. Invisible
	# (no styleboxes drawn) and disabled until a manual review opens it.
	_close_catcher = Button.new()
	_close_catcher.flat = true
	_close_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_close_catcher.add_theme_stylebox_override("normal", UIStyles.empty())
	_close_catcher.add_theme_stylebox_override("hover", UIStyles.empty())
	_close_catcher.add_theme_stylebox_override("pressed", UIStyles.empty())
	_close_catcher.add_theme_stylebox_override("focus", UIStyles.empty())
	_close_catcher.visible = false
	_close_catcher.pressed.connect(_slide_down)
	_panel.add_child(_close_catcher)

func _build_header() -> Control:
	var h := VBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(0, 0)
	# Padding via a container
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 54)    # 18px * 3
	pad.add_theme_constant_override("margin_right", 54)
	pad.add_theme_constant_override("margin_top", 36)     # 12px * 3
	pad.add_theme_constant_override("margin_bottom", 24)
	h.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	pad.add_child(inner)

	var eyebrow := Label.new()
	eyebrow.text = "WAVE CLEAR"
	eyebrow.add_theme_font_override("font", UIFonts.mono())
	eyebrow.add_theme_font_size_override("font_size", 30)  # 10px * 3
	eyebrow.add_theme_color_override("font_color", Palette.MUTED)
	inner.add_child(eyebrow)

	_header_wave = Label.new()
	_header_wave.text = "Wave — complete"
	_header_wave.add_theme_font_override("font", UIFonts.display_bold())
	_header_wave.add_theme_font_size_override("font_size", 60)  # 20px * 3
	_header_wave.add_theme_color_override("font_color", Color.WHITE)
	inner.add_child(_header_wave)

	var sub := Label.new()
	sub.text = "Choose one upgrade"
	sub.add_theme_font_override("font", UIFonts.display())
	sub.add_theme_font_size_override("font_size", 36)      # 12px * 3
	sub.add_theme_color_override("font_color", Palette.MUTED)
	inner.add_child(sub)

	# Auto-select countdown bar — drains amber→red over AUTO_PICK_SECONDS.
	_countdown_bar = ProgressBar.new()
	_countdown_bar.show_percentage = false
	_countdown_bar.custom_minimum_size = Vector2(0, 9)
	_countdown_bar.max_value = float(AUTO_PICK_SECONDS)
	_countdown_bar.value = float(AUTO_PICK_SECONDS)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Palette.BAR_BG
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = Palette.AMBER
	_countdown_bar.add_theme_stylebox_override("background", bg_s)
	_countdown_bar.add_theme_stylebox_override("fill", fill_s)
	inner.add_child(_countdown_bar)

	return h

# ── Cards ──────────────────────────────────────────────────────────────────

func _populate_cards(wave_number: int) -> void:
	for c: Control in _card_nodes:
		c.queue_free()
	_card_nodes.clear()

	_current_upgrades = _pick_three(wave_number)
	for i: int in _current_upgrades.size():
		var uid: String = _current_upgrades[i]
		var info: Dictionary = _get_upgrade_info(uid)
		var card := _build_card(info, i)
		_cards_vbox.add_child(card)
		_card_nodes.append(card)

func _build_card(info: Dictionary, index: int) -> Control:
	var rarity: int = info.get("rarity", 0)

	# Outer margin spaces cards apart inside the VBox.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)   # 14px * 3
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 12)    # 4px * 3
	margin.add_theme_constant_override("margin_bottom", 0)

	# Card: a Panel is NOT a layout container, so it must declare a min height
	# to claim vertical space — otherwise the VBox collapses every card to ~0px
	# and they stack on top of each other.
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := UIStyles.panel(Palette.rarity_bg(rarity), Palette.rarity_border(rarity), 30)
	card.add_theme_stylebox_override("panel", card_style)
	margin.add_child(card)

	# Content laid out by a full-rect MarginContainer (drives size off the card),
	# NOT absolute positioning. mouse_filter IGNORE so taps fall through to the button.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 36)
	pad.add_theme_constant_override("margin_right", 36)
	pad.add_theme_constant_override("margin_top", 21)
	pad.add_theme_constant_override("margin_bottom", 21)
	card.add_child(pad)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 36)  # 12px * 3
	pad.add_child(hbox)

	# Icon well — fixed 108×108, vertically centred so it doesn't stretch.
	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(108, 108)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_style := UIStyles.panel(Palette.S2, Palette.BORDER2, 24)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon_panel)

	var icon_label := Label.new()
	icon_label.text = info.get("icon", "●")
	icon_label.add_theme_font_size_override("font_size", 42)  # 14px * 3
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_panel.add_child(icon_label)

	# Name + desc — expands to fill the middle.
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = info.get("label", "")
	name_label.add_theme_font_override("font", UIFonts.display_bold())
	name_label.add_theme_font_size_override("font_size", 42)  # 14px * 3
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = info.get("desc", "")
	desc_label.add_theme_font_override("font", UIFonts.display())
	desc_label.add_theme_font_size_override("font_size", 33)  # 11px * 3
	desc_label.add_theme_color_override("font_color", Palette.MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_vbox.add_child(desc_label)

	# Right column — rarity dot + level, fixed width, top-aligned.
	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(120, 0)
	right_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_vbox.add_theme_constant_override("separation", 12)
	hbox.add_child(right_vbox)

	var dot := ColorRect.new()
	dot.color = Palette.rarity_dot(rarity)
	dot.custom_minimum_size = Vector2(18, 18)  # 6px * 3
	dot.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_vbox.add_child(dot)

	var level_label := Label.new()
	var cur_level: int = _levels.get(info.get("id", ""), 0)
	level_label.text = "Lv %d/%d" % [cur_level, info.get("max", 0)]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.add_theme_font_override("font", UIFonts.mono())
	level_label.add_theme_font_size_override("font_size", 27)  # 9px * 3
	level_label.add_theme_color_override("font_color", Palette.MUTED)
	right_vbox.add_child(level_label)

	# Credit cost — amber when affordable, coral when not.
	var uid_for_cost: String = info.get("id", "")
	var cost_val: int = _cost_for(uid_for_cost)
	var affordable: bool = _credits_value >= cost_val
	var cost_label := Label.new()
	cost_label.text = "%d₵" % cost_val
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_font_override("font", UIFonts.mono_bold())
	cost_label.add_theme_font_size_override("font_size", 30)
	cost_label.add_theme_color_override("font_color", Palette.AMBER if affordable else Palette.CORAL)
	right_vbox.add_child(cost_label)

	# Transparent full-rect button on top catches the tap for the whole card.
	# Only pickable on wave-clear AND when affordable; a manual review open (UPGRADES
	# button) is read-only so the shop can't be farmed by reopening the panel.
	var btn := Button.new()
	btn.flat = false
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal", UIStyles.empty())
	btn.add_theme_stylebox_override("hover", UIStyles.card_hover())    # card highlights on hover
	btn.add_theme_stylebox_override("pressed", UIStyles.card_hover())
	btn.add_theme_stylebox_override("focus", UIStyles.empty())
	card.add_child(btn)

	if _advance_on_close:
		# Wave-clear shop: only affordable cards are buyable (and thus hoverable).
		btn.disabled = not affordable
		if affordable:
			var idx := index
			btn.pressed.connect(func(): _choose(idx))
	else:
		# Read-only review: keep cards enabled so they show hover; tapping one closes.
		btn.disabled = false
		btn.pressed.connect(func(): _slide_down())

	return margin

# ── Logic ──────────────────────────────────────────────────────────────────

func _pick_three(wave_number: int) -> Array[String]:
	var pool: Array[String] = []
	for entry: Dictionary in UPGRADE_POOL:
		var id: String = entry["id"]
		if not entry.get("enabled", true):
			continue   # effect not implemented yet — keep out of the shop
		var unlocked: bool = wave_number >= entry.get("unlock", 1)
		var maxed: bool = _levels.get(id, 0) >= entry.get("max", 9999)
		if unlocked and not maxed:
			pool.append(id)
	pool.shuffle()
	var result: Array[String] = []
	for id: String in pool.slice(0, 3):
		result.append(id)
	return result

func _get_upgrade_info(upgrade_id: String) -> Dictionary:
	for entry: Dictionary in UPGRADE_POOL:
		if entry["id"] == upgrade_id:
			return entry
	return {}

func _cost_for(uid: String) -> int:
	var info: Dictionary = _get_upgrade_info(uid)
	var rarity: int = info.get("rarity", 0)
	var level: int = _levels.get(uid, 0)
	var base: int = RARITY_BASE[rarity]
	return int(round(base * pow(COST_GROWTH, level) * _discount_mult()))

func _discount_mult() -> float:
	var owned: Dictionary = SaveManager.get_value("spaceport", "upgrades", {})
	var lvl: int = owned.get("upgrade_discount", 0)
	return maxf(0.75, 1.0 - 0.05 * lvl)

func _choose(index: int) -> void:
	if index >= _current_upgrades.size():
		return
	var uid: String = _current_upgrades[index]
	var cost: int = _cost_for(uid)
	if _credits_value < cost:
		return   # not affordable — ignore the tap
	_auto_timer.stop()
	_pending_uid = uid
	EventBus.credits_spend_requested.emit(BigNum.from(cost), "inrun:" + uid)

# Result arrives synchronously inside _choose's call: on success bump the level,
# fire the existing upgrade_purchased, and advance the wave.
func _on_spend_result(context: String, success: bool) -> void:
	if not context.begins_with("inrun:"):
		return
	if not success:
		_pending_uid = ""
		return
	var uid: String = _pending_uid
	_pending_uid = ""
	_levels[uid] = _levels.get(uid, 0) + 1
	EventBus.upgrade_purchased.emit(uid)
	_slide_down()

func _on_wave_completed(wave_number: int) -> void:
	_advance_on_close = true
	_close_catcher.visible = false   # wave-clear: cards are tappable, no catcher
	_populate_cards(wave_number)
	# If every upgrade is unlocked-but-maxed there's nothing to offer — skip the
	# panel entirely and go straight to the next wave so the loop never stalls.
	if _current_upgrades.is_empty():
		EventBus.ready_for_next_wave.emit()
		return
	_header_wave.text = "Wave %d complete" % wave_number
	_start_countdown()
	_slide_up()

# Manual open/close from the bottom-HUD "UPGRADES" button. Reviews the current
# wave's offer without advancing the wave or auto-picking.
func _on_upgrades_toggle_requested() -> void:
	if _panel.visible:
		# Ignore while an active wave-clear pick is up — only a manual review closes here,
		# otherwise tapping UPGRADES would advance the wave without choosing.
		if not _advance_on_close:
			_slide_down()
		return
	_advance_on_close = false
	_populate_cards(_current_wave)
	_header_wave.text = "Upgrades"
	# Cards now close the review on tap (and show hover). Only fall back to the
	# full-panel catcher when there are no cards to tap, so it never soft-locks.
	if _current_upgrades.is_empty():
		_footer.text = "REVIEW — TAP ANYWHERE TO CLOSE"
		_close_catcher.visible = true
	else:
		_footer.text = "REVIEW — TAP A CARD TO CLOSE"
		_close_catcher.visible = false
	_slide_up()

func _start_countdown() -> void:
	_countdown = AUTO_PICK_SECONDS
	if _countdown_bar:
		_countdown_bar.value = float(AUTO_PICK_SECONDS)
		(_countdown_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Palette.AMBER
	_update_countdown_footer()
	_auto_timer.start()

func _on_auto_tick() -> void:
	_countdown -= 1
	if _countdown_bar:
		_countdown_bar.value = float(max(_countdown, 0))
		var t: float = 1.0 - (float(_countdown) / float(AUTO_PICK_SECONDS))
		(_countdown_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Palette.AMBER.lerp(Palette.CORAL, t)
	if _countdown <= 0:
		_auto_timer.stop()
		_auto_pick_affordable()
		return
	_update_countdown_footer()

func _auto_pick_affordable() -> void:
	var affordable: Array[int] = []
	for i: int in _current_upgrades.size():
		if _credits_value >= _cost_for(_current_upgrades[i]):
			affordable.append(i)
	if affordable.is_empty():
		_slide_down()   # nothing affordable → advance with no purchase
		return
	_choose(affordable[randi() % affordable.size()])

func _update_countdown_footer() -> void:
	_footer.text = "AUTO-SELECTING IN %ds — TAP TO CHOOSE" % _countdown

func _slide_up() -> void:
	TickSystem.pause()
	_panel.position.y = PANEL_HIDDEN_Y
	_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", PANEL_REST_Y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _slide_down() -> void:
	_auto_timer.stop()
	_close_catcher.visible = false
	var advance := _advance_on_close
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", PANEL_HIDDEN_Y, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_panel.visible = false
		TickSystem.resume()
		if advance:
			EventBus.ready_for_next_wave.emit()
	)
