## Purpose: StyleBoxFlat factory matching VexionSiege_Mockup.html border/background treatments.
## All sizes are pre-scaled 3× from the 360px-wide mockup to the 1080px game canvas.
class_name UIStyles
extends Object

# ── Generic panel: S1 bg, BORDER2 border, radius 30 (10px * 3) ────────────
static func panel(
		bg: Color = Palette.S1,
		border: Color = Palette.BORDER2,
		radius: int = 30,
		border_px: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left   = border_px
	s.border_width_right  = border_px
	s.border_width_top    = border_px
	s.border_width_bottom = border_px
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	return s

# ── Panel with only selected sides bordered (e.g. top-bar border-bottom) ──
static func panel_border_sides(
		bg: Color,
		border: Color,
		top: int = 0, right: int = 0, bottom: int = 0, left: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_top    = top
	s.border_width_right  = right
	s.border_width_bottom = bottom
	s.border_width_left   = left
	return s

# ── ProgressBar background track ──────────────────────────────────────────
static func bar_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.BAR_BG
	s.corner_radius_top_left     = 9  # 3px * 3
	s.corner_radius_top_right    = 9
	s.corner_radius_bottom_left  = 9
	s.corner_radius_bottom_right = 9
	return s

# ── ProgressBar fill ───────────────────────────────────────────────────────
static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = 9
	s.corner_radius_top_right    = 9
	s.corner_radius_bottom_left  = 9
	s.corner_radius_bottom_right = 9
	return s

# ── Primary button: blue glow bg + blue border ─────────────────────────────
static func btn_primary() -> StyleBoxFlat:
	return panel(Palette.BLUE_GLOW, Color(Palette.BLUE.r, Palette.BLUE.g, Palette.BLUE.b, 0.30), 36)

# ── Secondary button: transparent + BORDER2 ────────────────────────────────
static func btn_secondary() -> StyleBoxFlat:
	return panel(Color(0, 0, 0, 0), Palette.BORDER2, 36)

# ── Amber-tinted button (continue/revive) ──────────────────────────────────
static func btn_amber() -> StyleBoxFlat:
	return panel(Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.06),
				 Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.30), 36)

# ── Purple-tinted reward block ─────────────────────────────────────────────
static func reward_block() -> StyleBoxFlat:
	return panel(Color(Palette.PURPLE.r, Palette.PURPLE.g, Palette.PURPLE.b, 0.05),
				 Color(Palette.PURPLE.r, Palette.PURPLE.g, Palette.PURPLE.b, 0.25), 36)

# ── Invisible (removes default Control background) ─────────────────────────
static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

# ── Hover highlight for transparent card overlays (card "selects" on hover) ──
static func card_hover() -> StyleBoxFlat:
	return panel(Color(1.0, 1.0, 1.0, 0.05), Color(1.0, 1.0, 1.0, 0.22), 30)

# ── Accent button states: brighter bg + border on hover/press for clear feedback
static func btn_accent(accent: Color, bg_a: float, border_a: float, radius: int = 30) -> StyleBoxFlat:
	return panel(Color(accent.r, accent.g, accent.b, bg_a),
				 Color(accent.r, accent.g, accent.b, border_a), radius)

# ── Currency chip: pill-shaped S2 + BORDER2 ───────────────────────────────
static func currency_chip() -> StyleBoxFlat:
	return panel(Palette.S2, Palette.BORDER2, 60)  # 20px * 3

# ── Tab underline (active) ─────────────────────────────────────────────────
static func tab_active_underline(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = color
	s.border_width_bottom = 2
	return s
