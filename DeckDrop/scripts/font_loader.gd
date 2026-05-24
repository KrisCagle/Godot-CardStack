extends Node
## At app startup, look for a custom display font at one of FONT_PATHS and
## assign it to the project's main theme as the default font. If no font is
## present we fall back silently to Godot's built-in font.
##
## Autoloaded as `FontLoader`. Drop any .ttf or .otf at assets/fonts/main.<ext>
## and the next launch picks it up.

const FONT_PATHS := [
	"res://assets/fonts/main.ttf",
	"res://assets/fonts/main.otf",
]
const THEME_PATH := "res://themes/main_theme.tres"


func _ready() -> void:
	var font: Font = null
	var loaded_path := ""
	for p in FONT_PATHS:
		if not ResourceLoader.exists(p):
			continue
		var res = load(p)
		if res is Font:
			font = res
			loaded_path = p
			break

	if font == null:
		print("[font] no custom font at assets/fonts/main.{ttf,otf} — using Godot default")
		return

	if not ResourceLoader.exists(THEME_PATH):
		print("[font] theme.tres not found at %s, can't apply custom font" % THEME_PATH)
		return

	var theme_res = load(THEME_PATH)
	if not (theme_res is Theme):
		print("[font] custom theme is not a Theme resource")
		return

	theme_res.default_font = font
	print("[font] loaded %s and applied to theme" % loaded_path)
