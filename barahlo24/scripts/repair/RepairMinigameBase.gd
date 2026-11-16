class_name RepairMinigameBase
extends Control
## RepairMinigameBase — общая обёртка для всех мини-игр ремонта: модальный
## фон, заголовок, область для конкретной мини-игры, кнопка отмены.
## Наследники переопределяют _build_game_area() и сами вызывают
## _finish_with_quality(q) по завершении (q в диапазоне 0..1).

signal finished(quality: float)

var game_area: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 420)
	panel.position = Vector2(100, 200)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = get_title_text()
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var instructions := Label.new()
	instructions.text = get_instructions_text()
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(instructions)

	game_area = VBoxContainer.new()
	game_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(game_area)

	var cancel_btn := Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.pressed.connect(func(): finished.emit(0.0))
	vbox.add_child(cancel_btn)

	_build_game_area()


func get_title_text() -> String:
	return "Мини-игра ремонта"


func get_instructions_text() -> String:
	return ""


func _build_game_area() -> void:
	pass


func _finish_with_quality(q: float) -> void:
	finished.emit(clampf(q, 0.0, 1.0))
