## Purpose: Full-screen "WAVE N / COMPLETE" overlay that fades in, holds, and fades out.
extends CanvasLayer

var _container: Control
var _wave_label: Label
var _complete_label: Label
var _tween: Tween

func _ready() -> void:
	layer = 20  # above HUD (default) and panels (10)
	_build()
	EventBus.wave_completed.connect(_on_wave_completed)

func _build() -> void:
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.modulate = Color(1.0, 1.0, 1.0, 0.0)  # start hidden
	add_child(_container)

	# "WAVE N" — large Space Mono, white. Full width, centred. Upper third.
	_wave_label = Label.new()
	_wave_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_wave_label.offset_top = 600.0
	_wave_label.offset_bottom = 720.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_override("font", UIFonts.mono_bold())
	_wave_label.add_theme_font_size_override("font_size", 110)
	_wave_label.add_theme_color_override("font_color", Color.WHITE)
	_container.add_child(_wave_label)

	# "COMPLETE" — smaller Rajdhani, blue.
	_complete_label = Label.new()
	_complete_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_complete_label.offset_top = 720.0
	_complete_label.offset_bottom = 800.0
	_complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_complete_label.add_theme_font_override("font", UIFonts.display_bold())
	_complete_label.add_theme_font_size_override("font_size", 60)
	_complete_label.add_theme_color_override("font_color", Palette.BLUE)
	_complete_label.text = "COMPLETE"
	_container.add_child(_complete_label)

func _on_wave_completed(wave_number: int) -> void:
	_wave_label.text = "WAVE %d" % wave_number
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_container.modulate.a = 0.0
	# Tweens run on the SceneTree, unaffected by TickSystem.pause() during upgrade select.
	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)  # fade in
	_tween.tween_interval(1.0)                                                          # hold
	_tween.tween_property(_container, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)   # fade out
