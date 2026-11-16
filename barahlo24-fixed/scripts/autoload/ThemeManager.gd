extends Node
## ThemeManager — переключение тёмной/светлой темы UI.
## Темы заданы программно (Theme resources создаются в коде), чтобы не
## тащить лишние бинарные .tres с шрифтами/текстурами.

signal theme_changed(is_dark: bool)

var is_dark_theme: bool = true
var dark_theme: Theme
var light_theme: Theme

const COLOR_DARK_BG := Color(0.07, 0.09, 0.12)
const COLOR_DARK_PANEL := Color(0.12, 0.15, 0.19)
const COLOR_DARK_ACCENT := Color(0.96, 0.75, 0.25)
const COLOR_DARK_TEXT := Color(0.92, 0.93, 0.95)

const COLOR_LIGHT_BG := Color(0.95, 0.96, 0.97)
const COLOR_LIGHT_PANEL := Color(1.0, 1.0, 1.0)
const COLOR_LIGHT_ACCENT := Color(0.85, 0.55, 0.1)
const COLOR_LIGHT_TEXT := Color(0.1, 0.11, 0.13)


func _ready() -> void:
	dark_theme = _build_theme(COLOR_DARK_BG, COLOR_DARK_PANEL, COLOR_DARK_ACCENT, COLOR_DARK_TEXT)
	light_theme = _build_theme(COLOR_LIGHT_BG, COLOR_LIGHT_PANEL, COLOR_LIGHT_ACCENT, COLOR_LIGHT_TEXT)


func _build_theme(bg: Color, panel: Color, accent: Color, text: Color) -> Theme:
	var theme := Theme.new()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = accent
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	button_style.content_margin_left = 16
	button_style.content_margin_right = 16
	button_style.content_margin_top = 8
	button_style.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", button_style)

	var button_pressed := button_style.duplicate()
	button_pressed.bg_color = accent.darkened(0.15)
	theme.set_stylebox("pressed", "Button", button_pressed)

	var button_hover := button_style.duplicate()
	button_hover.bg_color = accent.lightened(0.1)
	theme.set_stylebox("hover", "Button", button_hover)

	theme.set_color("font_color", "Button", Color(0.07, 0.07, 0.07))
	theme.set_color("font_color", "Label", text)
	theme.set_color("font_color", "RichTextLabel", text)
	theme.set_color("default_color", "RichTextLabel", text)

	return theme


func apply_theme(root: Control) -> void:
	root.theme = dark_theme if is_dark_theme else light_theme


func toggle_theme(root: Control) -> void:
	is_dark_theme = not is_dark_theme
	apply_theme(root)
	theme_changed.emit(is_dark_theme)


func get_bg_color() -> Color:
	return COLOR_DARK_BG if is_dark_theme else COLOR_LIGHT_BG


func get_accent_color() -> Color:
	return COLOR_DARK_ACCENT if is_dark_theme else COLOR_LIGHT_ACCENT
