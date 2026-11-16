extends Node
## SaveSystem — локальное сохранение/загрузка прогресса в user://save_game.json.
## Формат — чистый JSON. Автосохранение триггерится извне (GameState) после
## значимых событий (покупка/продажа/ремонт/завершение дня), а не каждый кадр.

const SAVE_PATH := "user://save_game.json"

signal save_completed
signal load_completed(success: bool)


func save_game(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: не удалось открыть файл для записи: " + SAVE_PATH)
		return
	var json_text := JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()
	save_completed.emit()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		load_completed.emit(false)
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		load_completed.emit(false)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: повреждённый или пустой файл сохранения.")
		load_completed.emit(false)
		return {}
	load_completed.emit(true)
	return parsed


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save_game.json")
