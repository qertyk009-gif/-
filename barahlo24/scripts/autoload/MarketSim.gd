extends Node
## MarketSim — симуляция рыночных событий (спрос/дефицит) по дням.
## Не делает тяжёлых вычислений в _process; пересчёт происходит только
## при явном вызове advance_day() (конец игрового дня), не каждый кадр.

var active_events: Array = []  # [{event_data, days_left}]

signal event_started(event: Dictionary)
signal event_ended(event: Dictionary)


func advance_day() -> void:
	var still_active: Array = []
	for entry in active_events:
		entry.days_left -= 1
		if entry.days_left > 0:
			still_active.append(entry)
		else:
			event_ended.emit(entry.event)
	active_events = still_active

	# Шанс нового события в этот день.
	if randf() < 0.35 and GameData.market_events.size() > 0:
		var ev: Dictionary = GameData.market_events[randi() % GameData.market_events.size()]
		active_events.append({"event": ev, "days_left": int(ev.get("duration_days", 1))})
		event_started.emit(ev)


## Множитель цены для категории с учётом активных событий (спрос).
func get_demand_mult(category_id: String) -> float:
	var mult := 1.0
	for entry in active_events:
		var ev: Dictionary = entry.event
		if ev.get("category", "all") == "all" or ev.get("category", "") == category_id:
			mult *= float(ev.get("demand_mult", 1.0))
	return mult


func get_supply_mult(category_id: String) -> float:
	var mult := 1.0
	for entry in active_events:
		var ev: Dictionary = entry.event
		if ev.get("category", "all") == "all" or ev.get("category", "") == category_id:
			mult *= float(ev.get("supply_mult", 1.0))
	return mult


func get_active_event_names() -> Array:
	var names: Array = []
	for entry in active_events:
		names.append(entry.event.get("name", ""))
	return names


func serialize() -> Array:
	var out: Array = []
	for entry in active_events:
		out.append({"event_id": entry.event.get("id", ""), "days_left": entry.days_left})
	return out


func deserialize(saved: Array) -> void:
	active_events.clear()
	for s in saved:
		for ev in GameData.market_events:
			if ev.get("id", "") == s.get("event_id", ""):
				active_events.append({"event": ev, "days_left": int(s.get("days_left", 1))})
				break
