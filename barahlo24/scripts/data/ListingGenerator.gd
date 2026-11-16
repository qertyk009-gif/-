class_name ListingGenerator
extends RefCounted
## ListingGenerator — процедурная генерация объявлений для ленты.
##
## ФОРМУЛЫ ЭКОНОМИКИ ОБЪЯВЛЕНИЯ:
## 1) condition (состояние товара, 0.35..1.0) — равномерно случайное.
## 2) Для каждого возможного дефекта товара (item.possible_defects) бросаем
##    индивидуальный шанс появления:
##        defect_chance = (1.0 - condition) * 0.6 + 0.08
##    Чем хуже condition, тем больше шанс, что конкретный дефект есть.
## 3) fair_price (справедливая/истинная цена) = item.base_price (из JSON).
##    Передаётся в BotFactory.create_seller_bot(fair_price, condition), который
##    сам считает скрытую min_price = fair_price * condition * min_mult.
## 4) Отображаемая цена объявления (то, что просит бот изначально):
##        asking_price = min_price * (1.1 + greed * 0.5) * random(0.95..1.1)
##                        * demand_mult(category)
##    Жадные боты изначально заламывают цену сильнее; рыночный спрос (MarketSim)
##    дополнительно поднимает/опускает цену по категории.

static func generate_listing(listing_id: int) -> Dictionary:
	var item: Dictionary = GameData.random_item()
	if item.is_empty():
		return {}

	var condition: float = randf_range(0.35, 1.0)
	var possible_defects: Array = item.get("possible_defects", [])
	var defects: Array = []
	for d_id in possible_defects:
		var chance: float = (1.0 - condition) * 0.6 + 0.08
		if randf() < chance:
			defects.append(d_id)

	var fair_price: float = float(item.get("price", 1000))
	var bot: Dictionary = BotFactory.create_seller_bot(fair_price, condition)

	var demand_mult: float = MarketSim.get_demand_mult(item.get("category", ""))
	var greed: float = bot.get("greed", 0.5)
	var asking_price: float = bot.min_price * (1.1 + greed * 0.5) * randf_range(0.95, 1.1) * demand_mult
	asking_price = round(asking_price / 10.0) * 10.0

	var known_defects: Array = []
	for d_id in defects:
		var d: Dictionary = GameData.get_defect(d_id)
		if d.get("visible", false):
			known_defects.append(d_id)

	return {
		"listing_id": listing_id,
		"item_id": item.id,
		"name": item.get("name", "Товар"),
		"category": item.get("category", ""),
		"base_price": fair_price,
		"model_info": item.get("model", {}),
		"condition": condition,
		"defects": defects,
		"known_defects": known_defects,
		"asking_price": asking_price,
		"seller_bot": bot,
		"photo_requested": false,
	}


static func generate_batch(start_id: int, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		var listing := generate_listing(start_id + i)
		if not listing.is_empty():
			out.append(listing)
	return out
