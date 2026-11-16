class_name SolderingMinigame
extends RepairMinigameBase
## Мини-игра "Пайка": таймер-шкала заполняется, игрок должен удерживать
## нажатой кнопку "Паять", чтобы шкала "температуры" держалась в нужном
## диапазоне (не перегреть, не остудить). Длится несколько секунд реального
## времени, лёгкий _process только на линейную интерполяцию значения.

const DURATION_SEC := 6.0
const TARGET_MIN := 0.45
const TARGET_MAX := 0.75
const HEAT_RATE := 0.5
const COOL_RATE := 0.35

var _heat: float = 0.3
var _time_left: float = DURATION_SEC
var _time_in_range: float = 0.0
var _is_holding := false
var _heat_bar: ColorRect
var _heat_bar_bg_width: float = 400.0
var _timer_label: Label


func get_title_text() -> String:
	return "Ремонт: пайка"


func get_instructions_text() -> String:
	return "Удерживайте «Паять», чтобы шкала нагрева оставалась в зелёной зоне."


func _build_game_area() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(_heat_bar_bg_width, 32)
	bar_bg.color = Color(0.2, 0.2, 0.22)
	game_area.add_child(bar_bg)

	var target_zone := ColorRect.new()
	target_zone.color = Color(0.3, 0.75, 0.35, 0.5)
	target_zone.position = Vector2(_heat_bar_bg_width * TARGET_MIN, 0)
	target_zone.size = Vector2(_heat_bar_bg_width * (TARGET_MAX - TARGET_MIN), 32)
	bar_bg.add_child(target_zone)

	_heat_bar = ColorRect.new()
	_heat_bar.color = Color(0.95, 0.4, 0.15)
	_heat_bar.size = Vector2(6, 32)
	bar_bg.add_child(_heat_bar)

	_timer_label = Label.new()
	_timer_label.text = "Осталось: %.1f с" % _time_left
	game_area.add_child(_timer_label)

	var hold_btn := Button.new()
	hold_btn.text = "Паять (удерживать)"
	hold_btn.button_down.connect(func(): _is_holding = true)
	hold_btn.button_up.connect(func(): _is_holding = false)
	game_area.add_child(hold_btn)

	set_process(true)


func _process(delta: float) -> void:
	_time_left -= delta
	_timer_label.text = "Осталось: %.1f с" % max(0.0, _time_left)

	if _is_holding:
		_heat = clampf(_heat + HEAT_RATE * delta, 0.0, 1.0)
	else:
		_heat = clampf(_heat - COOL_RATE * delta, 0.0, 1.0)

	_heat_bar.position.x = _heat * (_heat_bar_bg_width - _heat_bar.size.x)

	if _heat >= TARGET_MIN and _heat <= TARGET_MAX:
		_time_in_range += delta

	if _time_left <= 0.0:
		set_process(false)
		var quality: float = clampf(_time_in_range / DURATION_SEC, 0.1, 1.0)
		_finish_with_quality(quality)
