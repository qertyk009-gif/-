class_name PartSwapMinigame
extends RepairMinigameBase
## Мини-игра "Замена детали": игрок видит сетку из карточек-"болтов"
## и должен открутить их все в правильном порядке (от 1 до N), кликая по
## порядку. Ошибка (клик не по следующему номеру) немного снижает качество,
## но не проваливает попытку полностью — имитирует аккуратность разборки.

const BOLT_COUNT := 6

var _buttons: Array = []
var _order: Array = []
var _next_index := 0
var _mistakes := 0


func get_title_text() -> String:
	return "Ремонт: замена детали"


func get_instructions_text() -> String:
	return "Открутите болты по порядку номеров: от 1 до %d." % BOLT_COUNT


func _build_game_area() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	game_area.add_child(grid)

	_order = range(1, BOLT_COUNT + 1)
	_order.shuffle()

	for i in range(BOLT_COUNT):
		var btn := Button.new()
		btn.text = str(_order[i])
		btn.custom_minimum_size = Vector2(90, 90)
		btn.pressed.connect(_on_bolt_pressed.bind(i, btn))
		grid.add_child(btn)
		_buttons.append(btn)


func _on_bolt_pressed(index: int, btn: Button) -> void:
	if btn.disabled:
		return
	var value: int = int(btn.text)
	_next_index += 1
	if value == _next_index:
		btn.disabled = true
		btn.modulate = Color(0.5, 0.9, 0.5)
	else:
		_mistakes += 1
		btn.modulate = Color(0.9, 0.4, 0.4)
		_next_index -= 1  # не считается выполненным, попробуйте снова другой болт

	if _next_index >= BOLT_COUNT:
		var quality: float = clampf(1.0 - float(_mistakes) * 0.15, 0.1, 1.0)
		_finish_with_quality(quality)
