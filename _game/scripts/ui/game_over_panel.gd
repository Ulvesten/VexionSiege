## Purpose: Game-over screen matching VexionSiege_Mockup.html — built fully in code.
extends CanvasLayer

var _wave_val: Label
var _enemies_val: Label
var _credits_earned_val: Label
var _best_wave_val: Label
var _reward_val: Label
var _subtitle: Label

var _wave_reached: int = 0
var _credits_earned: BigNum = BigNum.from(0.0)

func _ready() -> void:
	layer = 10
	visible = false
	_build()
	EventBus.game_over.connect(_on_game_over)
	# EconomyManager emits run_summary (earned cores/credits + best wave) during the
	# same game_over dispatch, BEFORE this panel's _on_game_over runs, so it owns those rows.
	EventBus.run_summary.connect(_on_run_summary)

# ── Build ──────────────────────────────────────────────────────────────────

func _build() -> void:
	# Full-screen dark background
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Palette.BG
	bg.add_theme_stylebox_override("panel", bg_s)
	add_child(bg)

	# Scrollable content centred horizontally
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(1080, 0)
	vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(vbox)

	# Top padding (notch area equivalent — 40px * 3 = 120)
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(top_pad)

	# Centre content with horizontal margins
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)   # 20px * 3
	margin.add_theme_constant_override("margin_right", 60)
	vbox.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	margin.add_child(content)

	# Top breathing room (replaces the removed "RUN ENDED" eyebrow).
	var title_pad := Control.new()
	title_pad.custom_minimum_size = Vector2(0, 24)
	content.add_child(title_pad)

	# "Ship Destroyed" — 36px * 3 = 108px display bold
	var title := Label.new()
	title.text = "Ship Destroyed"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIFonts.display_bold())
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(title)

	# Subtitle — updated with the real wave on game over (was a hardcoded "—").
	_subtitle = Label.new()
	_subtitle.text = "Milky Way"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", UIFonts.display())
	_subtitle.add_theme_font_size_override("font_size", 39)
	_subtitle.add_theme_color_override("font_color", Palette.MUTED)
	_subtitle.custom_minimum_size = Vector2(0, 72)   # margin-bottom 24px * 3
	content.add_child(_subtitle)

	# Stats block — PanelContainer so it SIZES to its rows (a bare Panel collapses to
	# ~0px and the rows overlap the blocks below — that was the overlap bug).
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UIStyles.panel(Palette.S1, Palette.BORDER2, 36))
	content.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 0)
	stats_panel.add_child(stats_vbox)

	_wave_val          = _add_stat_row(stats_vbox, "WAVES SURVIVED", "—",   true,  false)
	_enemies_val       = _add_stat_row(stats_vbox, "ENEMIES KILLED", "—",   false, false)
	_credits_earned_val = _add_stat_row(stats_vbox, "CREDITS EARNED", "—",  false, false)
	_best_wave_val     = _add_stat_row(stats_vbox, "BEST WAVE", "—", false, true)

	# Spacer
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 48)
	content.add_child(sp1)

	# Void cores reward block — PanelContainer so it sizes to its content (was a bare
	# Panel → collapsed → overlap).
	var reward := PanelContainer.new()
	reward.add_theme_stylebox_override("panel", UIStyles.reward_block())
	content.add_child(reward)

	var reward_hbox := HBoxContainer.new()
	reward_hbox.add_theme_constant_override("separation", 0)
	reward_hbox.custom_minimum_size = Vector2(0, 90)
	reward.add_child(reward_hbox)

	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 48)
	reward_margin.add_theme_constant_override("margin_right", 0)
	reward_margin.add_theme_constant_override("margin_top", 12)
	reward_margin.add_theme_constant_override("margin_bottom", 12)
	reward_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_hbox.add_child(reward_margin)

	var reward_vbox := VBoxContainer.new()
	reward_vbox.add_theme_constant_override("separation", 6)
	reward_margin.add_child(reward_vbox)

	var reward_lbl := Label.new()
	reward_lbl.text = "VOID CORES EARNED"
	reward_lbl.add_theme_font_override("font", UIFonts.mono())
	reward_lbl.add_theme_font_size_override("font_size", 27)   # 9px * 3
	reward_lbl.add_theme_color_override("font_color", Palette.PURPLE)
	reward_vbox.add_child(reward_lbl)

	_reward_val = Label.new()
	_reward_val.text = "+0 vc"
	_reward_val.add_theme_font_override("font", UIFonts.mono_bold())
	_reward_val.add_theme_font_size_override("font_size", 54)  # 18px * 3
	_reward_val.add_theme_color_override("font_color", Palette.PURPLE)
	reward_vbox.add_child(_reward_val)

	var reward_tex := UIIcons.make_rect(UIIcons.void_cores(), 96.0)
	if reward_tex:
		# Wrap so the icon keeps the same 120px-wide slot as the glyph it replaces.
		var icon_box := CenterContainer.new()
		icon_box.custom_minimum_size = Vector2(120, 0)
		icon_box.add_child(reward_tex)
		reward_hbox.add_child(icon_box)
	else:
		var reward_icon := Label.new()
		reward_icon.text = "◈"
		reward_icon.add_theme_font_size_override("font_size", 66)
		reward_icon.add_theme_color_override("font_color", Palette.PURPLE)
		reward_icon.custom_minimum_size = Vector2(120, 0)
		reward_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reward_hbox.add_child(reward_icon)

	# Buttons — pushed to bottom
	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 60)
	content.add_child(btn_spacer)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 24)   # 8px * 3
	content.add_child(btns)

	var continue_btn := _make_button("CONTINUE RUN — 30 GEMS", UIStyles.btn_amber(), Palette.AMBER, 45)
	continue_btn.pressed.connect(_on_continue_pressed)
	btns.add_child(continue_btn)

	var primary_btn := _make_button("ENTER SPACEPORT", UIStyles.btn_primary(), Palette.BLUE, 45)
	primary_btn.pressed.connect(_on_primary_pressed)
	btns.add_child(primary_btn)

	var secondary_btn := _make_button("RUN AGAIN", UIStyles.btn_secondary(), Palette.MUTED, 39)
	secondary_btn.pressed.connect(_on_secondary_pressed)
	btns.add_child(secondary_btn)

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 60)
	content.add_child(bottom_pad)

# ── Helpers ────────────────────────────────────────────────────────────────

func _add_stat_row(parent: VBoxContainer, lbl_text: String, default_val: String,
		highlight: bool, last: bool) -> Label:
	if not last:
		# Separator
		var sep := ColorRect.new()
		sep.color = Palette.BORDER
		sep.custom_minimum_size = Vector2(0, 1)
		parent.add_child(sep)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 99)   # 33px * 3
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var row_margin := MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 48)   # 16px * 3
	row_margin.add_theme_constant_override("margin_right", 48)
	row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(row_margin)

	var row_hbox := HBoxContainer.new()
	row_margin.add_child(row_hbox)

	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", UIFonts.mono())
	lbl.add_theme_font_size_override("font_size", 30)   # 10px * 3
	lbl.add_theme_color_override("font_color", Palette.MUTED)
	row_hbox.add_child(lbl)

	var val := Label.new()
	val.text = default_val
	val.add_theme_font_override("font", UIFonts.mono_bold())
	val.add_theme_font_size_override("font_size", 39)   # 13px * 3
	val.add_theme_color_override("font_color", Palette.AMBER if highlight else Color.WHITE)
	row_hbox.add_child(val)

	return val

func _make_button(text: String, style: StyleBoxFlat, color: Color, size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 117)  # ~39px * 3
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", UIStyles.btn_accent(color, 0.28, 0.6, 36))
	btn.add_theme_stylebox_override("pressed", UIStyles.btn_accent(color, 0.40, 0.8, 36))
	btn.add_theme_stylebox_override("focus", UIStyles.empty())
	btn.add_theme_font_override("font", UIFonts.display_bold())
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", color)
	return btn

# ── Signal handlers ────────────────────────────────────────────────────────

func _on_game_over(stats: Dictionary) -> void:
	_wave_reached = stats.get("wave_reached", 0)
	_wave_val.text = str(_wave_reached)
	_enemies_val.text = str(stats.get("enemies_killed", 0))
	_subtitle.text = "Reached Wave %d · Milky Way" % _wave_reached
	visible = true

# Earned-this-run figures (not lifetime totals). Fires before _on_game_over in the
# same dispatch, so these labels are already correct when the panel becomes visible.
func _on_run_summary(summary: Dictionary) -> void:
	_reward_val.text = "+%d vc" % int(summary.get("void_cores_earned", 0))
	var earned: BigNum = summary.get("credits_earned", BigNum.from(0.0))
	_credits_earned_val.text = earned.to_display()
	_best_wave_val.text = str(int(summary.get("best_wave", 0)))

func _on_continue_pressed() -> void:
	pass  # Phase 6: spend 30 gems

func _on_primary_pressed() -> void:
	visible = false
	EventBus.spaceport_opened.emit()

func _on_secondary_pressed() -> void:
	visible = false
	EventBus.spaceport_closed.emit()  # immediately restart a new run
