class_name ScrewdriverMinigame
extends RepairMinigameBase
## Мини-игра "Отвёртка": по горизонтальной шкале бегает маркер, нужно
## нажать кнopку "Закрутить", когда маркер в зелёной зоне. 4 попытки,
## качество = доля точных попаданий. Лёгкая анимация через Tween, без
## тяжёлых вычислений в _process (только позиция по курсору Tween).

const ROUNDS := 4
const GREEN_ZONE_MIN := 0.42
const GREEN_ZONE_MAX := 0.58

var _marker: ColorRect
var _bar_width: float = 420.0
var _tween: Tween
var _current_round := 0
var _hits := 0
var _marker_pos_ratio := 0.0
var _direction := 1.0
var _round_label: Label


func get_title_text() -> String:
	return "Ремонт: отвёртка"


func get_instructions_text() -> String:
	return "Нажмите «Закрутить», когда бегунок в зелёной зоне. 4 попытки."


func _build_game_area() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(_bar_width, 36)
	bar_bg.color = Color(0.2, 0.2, 0.22)
	game_area.add_child(bar_bg)

	var green := ColorRect.new()
	green.color = Color(0.3, 0.75, 0.35)
	green.position = Vector2(_bar_width * GREEN_ZONE_MIN, 0)
	green.size = Vector2(_bar_width * (GREEN_ZONE_MAX - GREEN_ZONE_MIN), 36)
	bar_bg.add_child(green)

	_marker = ColorRect.new()
	_marker.color = Color(0.95, 0.8, 0.2)
	_marker.size = Vector2(8, 36)
	bar_bg.add_child(_marker)

	_round_label = Label.new()
	_round_label.text = "Попытка 1 / %d" % ROUNDS
	game_area.add_child(_round_label)

	var action_btn := Button.new()
	action_btn.text = "Закрутить"
	action_btn.pressed.connect(_on_action_pressed)
	game_area.add_child(action_btn)

	set_process(true)


func _process(delta: float) -> void:
	_marker_pos_ratio += _direction * delta * 0.6
	if _marker_pos_ratio >= 1.0:
		_marker_pos_ratio = 1.0
		_direction = -1.0
	elif _marker_pos_ratio <= 0.0:
		_marker_pos_ratio = 0.0
		_direction = 1.0
	_marker.position.x = _marker_pos_ratio * (_bar_width - _marker.size.x)


func _on_action_pressed() -> void:
	if _marker_pos_ratio >= GREEN_ZONE_MIN and _marker_pos_ratio <= GREEN_ZONE_MAX:
		_hits += 1
	_current_round += 1
	if _current_round >= ROUNDS:
		set_process(false)
		var quality: float = float(_hits) / float(ROUNDS)
		_finish_with_quality(quality)
	else:
		_round_label.text = "Попытка %d / %d" % [_current_round + 1, ROUNDS]
