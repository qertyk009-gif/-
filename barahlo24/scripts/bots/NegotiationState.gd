class_name NegotiationState
extends RefCounted
## NegotiationState — состояние одного раунда торга между игроком и ботом.
## Вынесено в отдельный файл с глобальным class_name, чтобы тип был
## однозначно доступен из любого скрипта (включая саму автозагрузку
## NegotiationEngine) без неоднозначностей вложенных классов автозагрузок.

var bot: Dictionary
var role: String                # "seller" или "buyer" (роль БОТА)
var fair_price: float           # справедливая/рыночная цена для расчёта gap-сравнений UI
var current_price: float        # текущая цена бота (то, что он просит/готов дать)
var last_player_offer: float = 0.0
var turns_taken: int = 0
var is_over: bool = false
var result: String = ""         # "deal" | "left" | ""


func _init(p_bot: Dictionary, p_start_price: float) -> void:
	bot = p_bot
	role = p_bot.get("role", "seller")
	fair_price = p_start_price
	current_price = p_start_price
