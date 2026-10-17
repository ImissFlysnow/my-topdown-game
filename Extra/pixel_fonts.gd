extends RefCounted
class_name PixelFonts

# Native pixel grids avoid blurry or uneven strokes at the UI's small sizes.
const SMALL: FontFile = preload("res://Assets/Fonts/fusion-pixel-8px-zh-hans.otf")
const MEDIUM: FontFile = preload("res://Assets/Fonts/fusion-pixel-10px-zh-hans.otf")
const LARGE: FontFile = preload("res://Assets/Fonts/fusion-pixel-12px-zh-hans.otf")
static var configured := false

static func pixel_size(requested: int) -> int:
	if requested <= 9:
		return 8
	if requested <= 11:
		return 10
	if requested <= 17:
		return 12
	if requested <= 22:
		return 20
	return 24

static func get_font(requested: int = 12) -> FontFile:
	if not configured:
		for font: FontFile in [SMALL, MEDIUM, LARGE]:
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			font.allow_system_fallback = false
			font.oversampling = 1.0
		configured = true
	var size := pixel_size(requested)
	return SMALL if size == 8 else MEDIUM if size in [10, 20] else LARGE

static func apply(control: Control, requested: int = 12) -> void:
	control.add_theme_font_override("font", get_font(requested))
	control.add_theme_font_size_override("font_size", pixel_size(requested))
