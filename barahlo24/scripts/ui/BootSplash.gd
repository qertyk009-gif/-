extends Control
## BootSplash — простая заставка при старте: логотип "Барахолка24" на тёмном
## фоне, короткая анимация и переход в главное меню / автозагрузка сохранения.

const MAIN_SCENE := "res://scenes/ui/MainHub.tscn"
const SPLASH_DURATION := 1.4

var _bg: ColorRect
var _title: Label
var _subtitle: Label


func _ready() -> void:
	_build_ui()
	_animate_in()
	var timer := get_tree().create_timer(SPLASH_DURATION)
	timer.timeout.connect(_go_to_main)


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = ThemeManager.get_bg_color()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(96, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = ThemeManager.get_accent_color()
	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_left = 48
	style.corner_radius_bottom_right = 48
	coin.add_theme_stylebox_override("panel", style)
	var coin_box := CenterContainer.new()
	coin_box.add_child(coin)
	vbox.add_child(coin_box)

	_title = Label.new()
	_title.text = "БАРАХОЛКА24"
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	vbox.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "симулятор перекупщика"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox.add_child(_subtitle)

	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0


func _animate_in() -> void:
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.5).set_delay(0.15)


func _go_to_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
