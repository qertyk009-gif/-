extends Node
## BotFactory — создание ботов-продавцов и ботов-покупателей.
##
## Бот — обычный Dictionary (не класс), чтобы было легко сериализовать
## в сохранение и передавать между сценами без лишних зависимостей.
##
## Поля бота:
##   personality_id   : String  — ссылка на data/bot_personalities.json
##   display_name     : String  — случайное имя для чата
##   greed, kindness, patience_base, mood_volatility, honesty, haste : float (0..1)
##   mood             : float (0..1), стартует ~0.6
##   patience         : int, остаток "ходов" терпения
##   min_price        : float  — скрытая минимальная цена (для продавца — цена,
##                      ниже которой не продаст; для покупателя — потолок, выше
##                      которого не купит)
##   is_scammer       : bool
##   scam_type        : String ("fake_prepay" | "item_swap" | "")

const FIRST_NAMES := [
	"Алексей", "Марина", "Дмитрий", "Ольга", "Сергей", "Наталья", "Игорь",
	"Татьяна", "Павел", "Светлана", "Андрей", "Юлия", "Виктор", "Елена",
	"Роман", "Анна", "Максим", "Ксения", "Денис", "Ирина"
]

const LAST_INITIALS := ["А.", "Б.", "В.", "Г.", "Д.", "К.", "М.", "Н.", "П.", "С.", "Т."]


func _random_name() -> String:
	var first: String = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last: String = LAST_INITIALS[randi() % LAST_INITIALS.size()]
	return "%s %s" % [first, last]


## Создаёт бота-продавца для товара с базовой "честной" ценой fair_price.
## condition (0..1) — состояние товара, влияет на итоговую запрашиваемую цену.
func create_seller_bot(fair_price: float, condition: float, force_personality: String = "") -> Dictionary:
	var pid := force_personality if force_personality != "" else GameData.random_personality_id()
	var personality := GameData.get_personality(pid)
	if personality.is_empty():
		personality = {"id": "kind", "greed": 0.3, "kindness": 0.8, "patience_base": 8,
			"mood_volatility": 0.3, "honesty": 0.8, "haste": 0.3, "min_price_mult_range": [0.9, 1.0]}

	var mult_range: Array = personality.get("min_price_mult_range", [0.9, 1.1])
	var min_mult: float = randf_range(mult_range[0], mult_range[1])
	# Скрытая минимальная цена продавца — ниже справедливой цены товара с учётом
	# состояния (чем хуже состояние, тем ниже реальная ценность) и личного множителя.
	var min_price: float = fair_price * condition * min_mult

	var is_scammer: bool = personality.id == "scammer"
	var scam_type := ""
	if is_scammer:
		var pool: Array = personality.get("scam_type_pool", ["fake_prepay"])
		scam_type = pool[randi() % pool.size()]

	return {
		"personality_id": personality.id,
		"display_name": _random_name(),
		"greed": personality.greed,
		"kindness": personality.kindness,
		"patience_base": personality.patience_base,
		"mood_volatility": personality.mood_volatility,
		"honesty": personality.honesty,
		"haste": personality.haste,
		"mood": 0.6,
		"patience": personality.patience_base,
		"min_price": min_price,
		"is_scammer": is_scammer,
		"scam_type": scam_type,
		"role": "seller",
	}


## Создаёт бота-покупателя для товара, выставленного игроком на продажу.
## asking_price — цена игрока. max_budget_mult определяет потолок щедрости бота.
func create_buyer_bot(asking_price: float, force_personality: String = "") -> Dictionary:
	var pid := force_personality if force_personality != "" else GameData.random_personality_id()
	var personality := GameData.get_personality(pid)
	if personality.is_empty():
		personality = {"id": "kind", "greed": 0.3, "kindness": 0.8, "patience_base": 8,
			"mood_volatility": 0.3, "honesty": 0.8, "haste": 0.3, "min_price_mult_range": [0.85, 1.0]}

	var mult_range: Array = personality.get("min_price_mult_range", [0.85, 1.0])
	var mult: float = randf_range(mult_range[0], mult_range[1])
	# Для покупателя "min_price" трактуется как потолок готовности платить —
	# жадные покупатели (та же характеристика greed) готовы платить меньше.
	var max_price: float = asking_price * mult

	return {
		"personality_id": personality.id,
		"display_name": _random_name(),
		"greed": personality.greed,
		"kindness": personality.kindness,
		"patience_base": personality.patience_base,
		"mood_volatility": personality.mood_volatility,
		"honesty": personality.honesty,
		"haste": personality.haste,
		"mood": 0.6,
		"patience": personality.patience_base,
		"min_price": max_price,
		"is_scammer": false,
		"scam_type": "",
		"role": "buyer",
	}


## Создаёт бота — продавца запчасти заданного качества (для мастерской).
func create_part_seller_bot(part_base_price: float, tier: Dictionary) -> Dictionary:
	var pid := GameData.random_personality_id()
	var personality := GameData.get_personality(pid)
	var price: float = part_base_price * float(tier.get("price_mult", 1.0))
	return {
		"personality_id": pid,
		"display_name": _random_name(),
		"greed": personality.get("greed", 0.5),
		"kindness": personality.get("kindness", 0.5),
		"patience_base": personality.get("patience_base", 6),
		"mood_volatility": personality.get("mood_volatility", 0.3),
		"honesty": personality.get("honesty", 0.7),
		"haste": personality.get("haste", 0.3),
		"mood": 0.6,
		"patience": personality.get("patience_base", 6),
		"min_price": price * 0.85,
		"is_scammer": false,
		"scam_type": "",
		"role": "part_seller",
		"asking_price": price,
		"tier": tier.get("tier", "original"),
	}
