extends Node
## GameData — загрузка и хранение статичных игровых данных из data/*.json.
## Все справочники (товары, дефекты, запчасти, характеры ботов, фразы,
## рыночные события, ежедневные задания) читаются один раз при старте игры
## и кэшируются в памяти. Никакого обращения к диску в рантайме после этого.

var categories: Array = []
var items: Array = []
var defects: Array = []
var parts: Array = []
var personalities: Array = []
var phrases: Dictionary = {}
var market_events: Array = []
var daily_tasks_pool: Array = []

var _items_by_id: Dictionary = {}
var _defects_by_id: Dictionary = {}
var _parts_by_id: Dictionary = {}
var _personalities_by_id: Dictionary = {}
var _categories_by_id: Dictionary = {}

func _ready() -> void:
	_load_all()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: файл не найден: " + path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: не удалось открыть файл: " + path)
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: ошибка парсинга JSON: " + path)
	return parsed


func _load_all() -> void:
	var cat_data = _load_json("res://data/categories.json")
	if cat_data:
		categories = cat_data.get("categories", [])
		for c in categories:
			_categories_by_id[c.id] = c

	var items_data = _load_json("res://data/items.json")
	if items_data:
		items = items_data.get("items", [])
		for it in items:
			_items_by_id[it.id] = it

	var defects_data = _load_json("res://data/defects.json")
	if defects_data:
		defects = defects_data.get("defects", [])
		for d in defects:
			_defects_by_id[d.id] = d

	var parts_data = _load_json("res://data/parts.json")
	if parts_data:
		parts = parts_data.get("parts", [])
		for p in parts:
			_parts_by_id[p.id] = p

	var pers_data = _load_json("res://data/bot_personalities.json")
	if pers_data:
		personalities = pers_data.get("personalities", [])
		for p in personalities:
			_personalities_by_id[p.id] = p

	var phrases_data = _load_json("res://data/phrases.json")
	if phrases_data:
		phrases = phrases_data

	var market_data = _load_json("res://data/market_events.json")
	if market_data:
		market_events = market_data.get("events", [])

	var tasks_data = _load_json("res://data/daily_tasks.json")
	if tasks_data:
		daily_tasks_pool = tasks_data.get("tasks_pool", [])

	print("GameData: загружено items=%d defects=%d parts=%d personalities=%d" % [
		items.size(), defects.size(), parts.size(), personalities.size()
	])


func get_item(id: String) -> Dictionary:
	return _items_by_id.get(id, {})


func get_defect(id: String) -> Dictionary:
	return _defects_by_id.get(id, {})


func get_part(id: String) -> Dictionary:
	return _parts_by_id.get(id, {})


func get_personality(id: String) -> Dictionary:
	return _personalities_by_id.get(id, {})


func get_category(id: String) -> Dictionary:
	return _categories_by_id.get(id, {})


func get_items_by_category(category_id: String) -> Array:
	var result: Array = []
	for it in items:
		if it.get("category", "") == category_id:
			result.append(it)
	return result


func random_item() -> Dictionary:
	if items.is_empty():
		return {}
	return items[randi() % items.size()]


func random_personality_id() -> String:
	if personalities.is_empty():
		return "kind"
	return personalities[randi() % personalities.size()].id
