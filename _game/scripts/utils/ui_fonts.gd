## Purpose: Font factory for Space Mono (mono) and Rajdhani (display) from the mockup.
## Tries to load bundled TTF files; falls back to system fonts if not yet imported.
## To add the real fonts: download from Google Fonts and place at:
##   res://_game/assets/fonts/SpaceMono-Regular.ttf
##   res://_game/assets/fonts/SpaceMono-Bold.ttf
##   res://_game/assets/fonts/Rajdhani-SemiBold.ttf
##   res://_game/assets/fonts/Rajdhani-Bold.ttf
class_name UIFonts
extends Object

const _MONO_REG  := "res://_game/assets/fonts/SpaceMono-Regular.ttf"
const _MONO_BOLD := "res://_game/assets/fonts/SpaceMono-Bold.ttf"
const _DISP_SEMI := "res://_game/assets/fonts/Rajdhani-SemiBold.ttf"
const _DISP_BOLD := "res://_game/assets/fonts/Rajdhani-Bold.ttf"

static var _cache: Dictionary = {}

static func mono() -> Font:
	return _load_font("mono_reg", _MONO_REG, ["Space Mono", "Courier New", "monospace"], 400)

static func mono_bold() -> Font:
	return _load_font("mono_bold", _MONO_BOLD, ["Space Mono", "Courier New", "monospace"], 700)

static func display() -> Font:
	return _load_font("disp_semi", _DISP_SEMI, ["Rajdhani", "Segoe UI", "Arial", "sans-serif"], 600)

static func display_bold() -> Font:
	return _load_font("disp_bold", _DISP_BOLD, ["Rajdhani", "Segoe UI", "Arial", "sans-serif"], 700)

static func _load_font(key: String, path: String, fallback_names: Array, weight: int) -> Font:
	if _cache.has(key):
		return _cache[key]
	var font: Font
	if ResourceLoader.exists(path):
		font = load(path) as FontFile
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(fallback_names)
		sf.font_weight = weight
		font = sf
	_cache[key] = font
	return font
