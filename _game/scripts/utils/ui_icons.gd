## Purpose: Icon-texture factory for currency / UI icons. Loads on demand and caches.
## Returns null if a texture is not yet imported by Godot, so callers must fall back
## to a glyph. (The source files are JPGs — re-export as transparent PNGs for the
## cleanest look; the dark JPG background blends acceptably on the dark UI surfaces.)
class_name UIIcons
extends Object

const CREDITS     := "res://_game/assets/sprites/icons/icon_credits.jpg"
const VOID_CORES  := "res://_game/assets/sprites/icons/icon_void_cores.jpg"
const STAR_SHARDS := "res://_game/assets/sprites/icons/icon_star_shards.jpg"
const SETTINGS    := "res://_game/assets/sprites/icons/icon_settings.jpg"

static var _cache: Dictionary = {}

static func credits() -> Texture2D:     return _load("credits", CREDITS)
static func void_cores() -> Texture2D:  return _load("void_cores", VOID_CORES)
static func star_shards() -> Texture2D: return _load("star_shards", STAR_SHARDS)
static func settings() -> Texture2D:    return _load("settings", SETTINGS)

static func _load(key: String, path: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var src := load(path) as Texture2D
		if src != null:
			tex = _key_out_background(src)
	_cache[key] = tex  # cache null too — avoids re-probing a missing import every frame
	return tex

# The source icons are JPGs (no alpha) with a dark square background that shows as an
# ugly box on the UI. Chroma-key it out: pixels darker than the threshold go fully
# transparent, with a short feather so anti-aliased / JPG-fringe edges fade cleanly.
# Done once per icon at load and cached.
static func _key_out_background(src: Texture2D) -> Texture2D:
	var img: Image = src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	const LO := 0.16   # below this luminance → transparent
	const HI := 0.34   # above this → fully opaque; between → feathered
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			var lum: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			if lum <= LO:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
			elif lum < HI:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, (lum - LO) / (HI - LO)))
	return ImageTexture.create_from_image(img)

# Build a square TextureRect for the icon, or null if the texture isn't available.
# Callers should branch on null and add a glyph fallback instead.
static func make_rect(tex: Texture2D, px: float, modulate: Color = Color.WHITE) -> TextureRect:
	if tex == null:
		return null
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = modulate
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
