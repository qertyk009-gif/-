extends Node
## GameState — центральное состояние игрока: деньги, репутация, навыки,
## инвентарь, активные объявления, день, ежедневные задания.
## Не содержит UI-логики. Сохраняется/загружается через SaveSystem.

signal money_changed(new_amount: float)
signal reputation_changed(new_value: float)
signal inventory_changed
signal day_advanced(day: int)
signal skill_changed(skill_id: String, level: int)
signal daily_task_updated(task: Dictionary)

const PLATFORM_FEE_RATE := 0.07  # комиссия площадки «Барахолка24» с каждой продажи
const STARTING_MONEY := 5000.0
const MAX_SKILL_LEVEL := 5

var money: float = STARTING_MONEY
var reputation: float = 0.0  # -100..100 накопленный рейтинг из отзывов
var reviews_count: int = 0
var current_day: int = 1

## Навыки 1..MAX_SKILL_LEVEL: торг, ремонт, оценка, антифрод.
var skills: Dictionary = {
	"negotiation": 1,
	"repair": 1,
	"appraisal": 1,
	"antifraud": 1,
}
var skill_xp: Dictionary = {
	"negotiation": 0, "repair": 0, "appraisal": 0, "antifraud": 0,
}

## Инвентарь — купленные игроком товары, ожидающие ремонта/продажи.
## Элемент: { instance_id, item_id, name, category, base_price, condition,
##            defects: [defect_id...], repaired_defects: [defect_id...],
##            purchase_price, photos_requested, bought_day }
var inventory: Array = []

## Активные объявления игрока на продажу.
## Элемент: { instance_id, item_id, name, asking_price, listed_day }
var active_listings: Array = []

## Статистика для ежедневных заданий / аналитики.
var stats_today: Dictionary = {
	"sold_count": 0,
	"sold_by_category": {},
	"profit_today": 0.0,
	"repairs_done": 0,
	"best_discount_pct": 0.0,
}

var daily_tasks: Array = []  # [{task_data, progress, completed, claimed}]
var _next_instance_id: int = 1


func _ready() -> void:
	_generate_daily_tasks()


func _new_instance_id() -> int:
	_next_instance_id += 1
	return _next_instance_id


func add_money(amount: float) -> void:
	money += amount
	money_changed.emit(money)


func can_afford(amount: float) -> bool:
	return money >= amount


func add_reputation(delta: float) -> void:
	reputation = clampf(reputation + delta, -100.0, 100.0)
	reviews_count += 1
	reputation_changed.emit(reputation)


func add_skill_xp(skill_id: String, xp: int) -> void:
	if not skill_xp.has(skill_id):
		return
	skill_xp[skill_id] += xp
	var needed := skills[skill_id] * 100
	while skill_xp[skill_id] >= needed and skills[skill_id] < MAX_SKILL_LEVEL:
		skill_xp[skill_id] -= needed
		skills[skill_id] += 1
		needed = skills[skill_id] * 100
		skill_changed.emit(skill_id, skills[skill_id])


func get_skill_level(skill_id: String) -> int:
	return int(skills.get(skill_id, 1))


## Негативная/позитивная поправка к расчётам торга от навыка "negotiation":
## каждый уровень даёт небольшое преимущество игроку (используется UI чата
## при желании усилить эффект реплик — не обязателен для базовой формулы бота).
func get_negotiation_bonus() -> float:
	return (get_skill_level("negotiation") - 1) * 0.03


func get_repair_quality_bonus() -> float:
	return (get_skill_level("repair") - 1) * 0.04


func get_appraisal_bonus() -> float:
	return (get_skill_level("appraisal") - 1) * 0.05


func get_antifraud_bonus() -> float:
	return (get_skill_level("antifraud") - 1) * 0.06


func add_to_inventory(item_id: String, display_name: String, category: String, base_price: float,
		condition: float, defects: Array, purchase_price: float) -> Dictionary:
	var entry := {
		"instance_id": _new_instance_id(),
		"item_id": item_id,
		"name": display_name,
		"category": category,
		"base_price": base_price,
		"condition": condition,
		"defects": defects.duplicate(),
		"repaired_defects": [],
		"installed_parts": {},  # defect_id -> tier
		"purchase_price": purchase_price,
		"bought_day": current_day,
	}
	inventory.append(entry)
	inventory_changed.emit()
	return entry


func remove_from_inventory(instance_id: int) -> void:
	for i in range(inventory.size()):
		if inventory[i].instance_id == instance_id:
			inventory.remove_at(i)
			inventory_changed.emit()
			return


func get_inventory_item(instance_id: int) -> Dictionary:
	for entry in inventory:
		if entry.instance_id == instance_id:
			return entry
	return {}


func list_for_sale(instance_id: int, asking_price: float) -> void:
	var item := get_inventory_item(instance_id)
	if item.is_empty():
		return
	remove_from_inventory(instance_id)
	active_listings.append({
		"instance_id": instance_id,
		"item_id": item.item_id,
		"name": item.name,
		"category": item.category,
		"asking_price": asking_price,
		"listed_day": current_day,
		"condition": item.condition,
	})


func remove_listing(instance_id: int) -> void:
	for i in range(active_listings.size()):
		if active_listings[i].instance_id == instance_id:
			active_listings.remove_at(i)
			return


## Завершает продажу: применяет комиссию площадки, обновляет статистику/задания.
func complete_sale(listing: Dictionary, final_price: float) -> float:
	var fee := final_price * PLATFORM_FEE_RATE
	var net := final_price - fee
	add_money(net)

	stats_today.sold_count += 1
	var cat: String = listing.get("category", "")
	stats_today.sold_by_category[cat] = int(stats_today.sold_by_category.get(cat, 0)) + 1
	stats_today.profit_today += net

	remove_listing(listing.get("instance_id", -1))
	_update_daily_tasks_progress()
	return net


func record_repair_done() -> void:
	stats_today.repairs_done += 1
	_update_daily_tasks_progress()


func record_negotiation_discount(discount_pct: float) -> void:
	if discount_pct > stats_today.best_discount_pct:
		stats_today.best_discount_pct = discount_pct
	_update_daily_tasks_progress()


func _generate_daily_tasks() -> void:
	daily_tasks.clear()
	var pool: Array = GameData.daily_tasks_pool.duplicate()
	pool.shuffle()
	var count: int = min(3, pool.size())
	for i in range(count):
		daily_tasks.append({"task": pool[i], "progress": 0, "completed": false, "claimed": false})
	_update_daily_tasks_progress()


func _update_daily_tasks_progress() -> void:
	for entry in daily_tasks:
		if entry.claimed:
			continue
		var t: Dictionary = entry.task
		var progress := 0
		match t.type:
			"sell_count":
				progress = stats_today.sold_count
			"sell_category":
				progress = int(stats_today.sold_by_category.get(t.category, 0))
			"profit_target":
				progress = int(stats_today.profit_today)
			"repair_count":
				progress = stats_today.repairs_done
			"negotiation_discount":
				progress = int(stats_today.best_discount_pct)
		entry.progress = progress
		if progress >= int(t.target) and not entry.completed:
			entry.completed = true
		daily_task_updated.emit(entry)


func claim_daily_task(index: int) -> void:
	if index < 0 or index >= daily_tasks.size():
		return
	var entry: Dictionary = daily_tasks[index]
	if entry.completed and not entry.claimed:
		entry.claimed = true
		var t: Dictionary = entry.task
		add_money(float(t.get("reward_money", 0)))
		add_reputation(float(t.get("reward_rep", 0)))


## Переход на следующий день: рыночные события, сброс дневной статистики,
## новые задания. Вызывается явно (кнопка "Закончить день"), не по таймеру.
func advance_day() -> void:
	current_day += 1
	MarketSim.advance_day()
	stats_today = {
		"sold_count": 0, "sold_by_category": {}, "profit_today": 0.0,
		"repairs_done": 0, "best_discount_pct": 0.0,
	}
	_generate_daily_tasks()
	day_advanced.emit(current_day)


func to_save_dict() -> Dictionary:
	return {
		"money": money,
		"reputation": reputation,
		"reviews_count": reviews_count,
		"current_day": current_day,
		"skills": skills,
		"skill_xp": skill_xp,
		"inventory": inventory,
		"active_listings": active_listings,
		"stats_today": stats_today,
		"daily_tasks": daily_tasks,
		"next_instance_id": _next_instance_id,
		"market_events": MarketSim.serialize(),
	}


func load_from_dict(data: Dictionary) -> void:
	money = float(data.get("money", STARTING_MONEY))
	reputation = float(data.get("reputation", 0.0))
	reviews_count = int(data.get("reviews_count", 0))
	current_day = int(data.get("current_day", 1))
	skills = data.get("skills", skills)
	skill_xp = data.get("skill_xp", skill_xp)
	inventory = data.get("inventory", [])
	active_listings = data.get("active_listings", [])
	stats_today = data.get("stats_today", stats_today)
	daily_tasks = data.get("daily_tasks", [])
	_next_instance_id = int(data.get("next_instance_id", 1))
	MarketSim.deserialize(data.get("market_events", []))
	if daily_tasks.is_empty():
		_generate_daily_tasks()
	money_changed.emit(money)
	reputation_changed.emit(reputation)
	inventory_changed.emit()


func autosave() -> void:
	SaveSystem.save_game(to_save_dict())


func try_load_save() -> bool:
	if not SaveSystem.has_save():
		return false
	var data := SaveSystem.load_game()
	if data.is_empty():
		return false
	load_from_dict(data)
	return true
