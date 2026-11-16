class_name CleaningMinigame
extends RepairMinigameBase
## Мини-игра "Чистка": на поле случайно разбросаны "грязные пятна"
## (кнопки), нужно нажать на каждое, пока не останется ни одного.
## Качество = 1.0 минус штраф за промахи по пустому полю (не применимо
## здесь, так как кликаем только по кнопкам) — фактически чистое время
## прохождения не ограничиваем, качество зависит от количества "лишних"
## нажатий после того как пятно уже было очищено (защита от спама).

const SPOT_COUNT := 8

var _spots_cleaned := 0
var _extra_clicks := 0


func get_title_text() -> String:
	return "Ремонт: чистка"


func get_instructions_text() -> String:
	return "Протрите все %d грязных пятна, нажимая на них." % SPOT_COUNT


func _build_game_area() -> void:
	var field := Control.new()
	field.custom_minimum_size = Vector2(440, 260)
	game_area.add_child(field)

	for i in range(SPOT_COUNT):
		var spot := Button.new()
		spot.text = "✦"
		spot.custom_minimum_size = Vector2(48, 48)
		spot.position = Vector2(randf_range(0, 392), randf_range(0, 212))
		spot.modulate = Color(0.45, 0.32, 0.18)
		spot.pressed.connect(_on_spot_pressed.bind(spot))
		field.add_child(spot)


func _on_spot_pressed(spot: Button) -> void:
	if spot.disabled:
		_extra_clicks += 1
		return
	spot.disabled = true
	spot.modulate = Color(0.3, 0.3, 0.3, 0.3)
	_spots_cleaned += 1
	if _spots_cleaned >= SPOT_COUNT:
		var quality: float = clampf(1.0 - float(_extra_clicks) * 0.05, 0.4, 1.0)
		_finish_with_quality(quality)
