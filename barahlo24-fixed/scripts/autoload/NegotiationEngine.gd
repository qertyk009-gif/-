extends Node
## NegotiationEngine — офлайн-движок торга (без интернета и без LLM по умолчанию).
##
## Бот хранится как Dictionary (см. BotFactory). Торг моделируется пошагово:
## игрок делает действие (предложить цену / спросить дефекты / попросить фото /
## пригрозить уходом), движок считает реакцию бота по формулам ниже.
##
## ==================== ФОРМУЛЫ ТОРГА ====================
##
## 1) "Разрыв цены" (gap) — насколько предложение игрока отличается от скрытой
##    минимальной цены бота, в долях:
##        gap = (bot.min_price - offer) / bot.min_price        [для продавца]
##        gap = (offer - bot.min_price) / bot.min_price         [для покупателя]
##    gap > 0 значит предложение хуже для бота, чем его порог.
##
## 2) Вероятность СОГЛАСИЯ на предложение:
##        accept_chance = clamp(
##            mood * 0.5
##            + kindness * 0.3
##            - greed * 0.4
##            - gap * (1.0 + greed)
##            + haste * 0.2
##            , 0.0, 1.0)
##    Чем выше настроение/доброта/спешка и чем меньше gap и жадность — тем
##    выше шанс согласия. Если gap <= 0 (предложение не хуже порога бота),
##    шанс согласия получает гарантированный бонус +0.5, так как сделка и так
##    выгодна боту.
##
## 3) ВСТРЕЧНОЕ ПРЕДЛОЖЕНИЕ, если бот не согласился и не ушёл:
##    Бот сдвигает свою цену навстречу предложению игрока на долю step:
##        step = clamp(0.15 + kindness * 0.25 - greed * 0.15 + mood * 0.1, 0.05, 0.5)
##        counter = bot.current_price - (bot.current_price - offer) * step   [продавец]
##        counter = bot.current_price + (offer - bot.current_price) * step  [покупатель]
##    Результат никогда не переходит через min_price в невыгодную для бота
##    сторону (clamp относительно min_price).
##
## 4) НАСТРОЕНИЕ (mood) меняется от действий игрока:
##        слишком низкое предложение (gap > 0.35)   -> mood -= 0.15 * mood_volatility_factor
##        разумное предложение (0 < gap <= 0.35)      -> mood -= 0.05
##        предложение лучше или равно порогу (gap<=0) -> mood += 0.1
##        вопрос о дефектах/просьба фото               -> mood -= 0.03 (лёгкая настороженность)
##        угроза уйти                                   -> mood -= 0.2 * (1 - haste)
##    mood_volatility_factor = 0.5 + mood_volatility (т.е. волатильные боты
##    реагируют сильнее). mood всегда clamp(0..1).
##
## 5) ТЕРПЕНИЕ (patience) — целое число ходов. Каждый ход торга -1.
##    Если patience <= 0 ИЛИ mood <= 0.08, бот УХОДИТ (deal failed).
##    Торопыги (haste высокий) теряют дополнительно -1 терпения за ход,
##    если игрок не делает конкретного денежного предложения (просто болтает).
##
## 6) МОШЕННИКИ: при роли seller с is_scammer=true, после согласия на сделку
##    есть шанс scam_trigger_chance = 0.5 + (1 - honesty) * 0.3 того, что вместо
##    нормальной покупки боту вызывается событие обмана (фейковая предоплата
##    или подмена товара) — обрабатывается в вызывающем коде (UI чата), а не
##    здесь, т.к. это больше нарратив, чем формула.
##
## =========================================================

enum Action { OFFER_PRICE, ASK_DEFECTS, ASK_PHOTO, THREATEN_LEAVE, ACCEPT_CURRENT, SMALLTALK }

const MIN_ACCEPT_CHANCE_IF_GOOD := 0.5
const LEAVE_MOOD_THRESHOLD := 0.08

## Состояние одного раунда торга вынесено в scripts/bots/NegotiationState.gd
## (класс NegotiationState с глобальным class_name), чтобы тип был
## однозначно доступен отовсюду без вложенности в автозагрузку.


func start_negotiation(bot: Dictionary, start_price: float) -> NegotiationState:
	return NegotiationState.new(bot, start_price)


func _mood_volatility_factor(bot: Dictionary) -> float:
	return 0.5 + float(bot.get("mood_volatility", 0.3))


func _gap(state: NegotiationState, offer: float) -> float:
	var min_price: float = float(state.bot.get("min_price", 0.0))
	if min_price <= 0.0:
		return 0.0
	if state.role == "seller":
		return (min_price - offer) / min_price
	else:
		return (offer - min_price) / min_price


func _apply_mood_delta(state: NegotiationState, delta: float) -> void:
	var mood: float = float(state.bot.get("mood", 0.6))
	mood = clampf(mood + delta, 0.0, 1.0)
	state.bot["mood"] = mood


func _tick_patience(state: NegotiationState, cost: int = 1) -> void:
	var patience: int = int(state.bot.get("patience", 5))
	patience -= cost
	state.bot["patience"] = patience


## Основной вызов: игрок делает предложение цены.
## Возвращает Dictionary-результат для UI:
##   { "outcome": "accepted"|"counter"|"rejected"|"left",
##     "counter_price": float, "bot_mood_tone": String }
func offer_price(state: NegotiationState, offer: float) -> Dictionary:
	if state.is_over:
		return {"outcome": "left", "counter_price": 0.0, "bot_mood_tone": "neutral"}

	state.turns_taken += 1
	state.last_player_offer = offer
	var bot := state.bot

	var gap: float = _gap(state, offer)
	var mood: float = float(bot.get("mood", 0.6))
	var kindness: float = float(bot.get("kindness", 0.5))
	var greed: float = float(bot.get("greed", 0.5))
	var haste: float = float(bot.get("haste", 0.3))

	# --- Формула 2: вероятность согласия ---
	var accept_chance: float = mood * 0.5 + kindness * 0.3 - greed * 0.4 - gap * (1.0 + greed) + haste * 0.2
	if gap <= 0.0:
		accept_chance += MIN_ACCEPT_CHANCE_IF_GOOD
	accept_chance = clampf(accept_chance, 0.0, 1.0)

	# --- Формула 4: изменение настроения от предложения ---
	var vol: float = _mood_volatility_factor(bot)
	if gap > 0.35:
		_apply_mood_delta(state, -0.15 * vol)
	elif gap > 0.0:
		_apply_mood_delta(state, -0.05)
	else:
		_apply_mood_delta(state, 0.1)

	_tick_patience(state, 1)

	var rolled := randf()
	if rolled < accept_chance:
		state.current_price = offer
		state.is_over = true
		state.result = "deal"
		return {"outcome": "accepted", "counter_price": offer, "bot_mood_tone": _mood_tone(state.bot)}

	# Не согласился — проверяем, не ушёл ли бот.
	if _check_left(state):
		return {"outcome": "left", "counter_price": 0.0, "bot_mood_tone": "hostile"}

	# --- Формула 3: встречное предложение ---
	var step: float = clampf(0.15 + kindness * 0.25 - greed * 0.15 + mood * 0.1, 0.05, 0.5)
	var counter: float
	if state.role == "seller":
		counter = state.current_price - (state.current_price - offer) * step
		counter = max(counter, float(bot.get("min_price", 0.0)))
	else:
		counter = state.current_price + (offer - state.current_price) * step
		counter = min(counter, float(bot.get("min_price", 0.0)))
	state.current_price = counter

	return {"outcome": "counter", "counter_price": counter, "bot_mood_tone": _mood_tone(state.bot)}


## Игрок спрашивает про дефекты. Возвращает, честно ли отвечает бот и hint дефекта
## (если есть скрытый дефект и бот решил о нём сказать).
func ask_about_defects(state: NegotiationState, has_hidden_defect: bool, defect_hint: String) -> Dictionary:
	state.turns_taken += 1
	_apply_mood_delta(state, -0.03)
	_tick_patience(state, 1)
	if _check_left(state):
		return {"outcome": "left", "honest": false, "hint": ""}

	var honesty: float = float(state.bot.get("honesty", 0.7))
	var tells_truth: bool = randf() < honesty
	if not has_hidden_defect:
		return {"outcome": "answered", "honest": true, "hint": ""}
	if tells_truth:
		return {"outcome": "answered", "honest": true, "hint": defect_hint}
	return {"outcome": "answered", "honest": false, "hint": ""}


func ask_for_photo(state: NegotiationState) -> Dictionary:
	state.turns_taken += 1
	_apply_mood_delta(state, -0.03)
	_tick_patience(state, 1)
	if _check_left(state):
		return {"outcome": "left", "complied": false}
	var honesty: float = float(state.bot.get("honesty", 0.7))
	var complied: bool = randf() < (0.4 + honesty * 0.5)
	return {"outcome": "answered", "complied": complied}


func threaten_leave(state: NegotiationState) -> Dictionary:
	state.turns_taken += 1
	var haste: float = float(state.bot.get("haste", 0.3))
	_apply_mood_delta(state, -0.2 * (1.0 - haste))
	_tick_patience(state, 1)
	if _check_left(state):
		return {"outcome": "left"}

	# Шанс, что бот испугается и сделает хорошую уступку немедленно.
	var kindness: float = float(state.bot.get("kindness", 0.5))
	var mood: float = float(state.bot.get("mood", 0.6))
	var concede_chance: float = clampf(0.25 + kindness * 0.3 - float(state.bot.get("greed", 0.5)) * 0.2 + mood * 0.1, 0.0, 0.85)
	if randf() < concede_chance:
		var step := 0.3
		var concession: float
		if state.role == "seller":
			concession = state.current_price - (state.current_price - state.last_player_offer) * step
			concession = max(concession, float(state.bot.get("min_price", 0.0)))
		else:
			concession = state.current_price + (state.last_player_offer - state.current_price) * step
			concession = min(concession, float(state.bot.get("min_price", 0.0)))
		state.current_price = concession
		return {"outcome": "conceded", "counter_price": concession}
	return {"outcome": "stood_firm", "counter_price": state.current_price}


## Пустая реплика/приветствие — лёгкий расход терпения для торопыг (формула 5).
func small_talk(state: NegotiationState) -> void:
	state.turns_taken += 1
	var haste: float = float(state.bot.get("haste", 0.3))
	var extra: int = 1 if haste > 0.6 else 0
	_tick_patience(state, 1 + extra)
	_check_left(state)


func _check_left(state: NegotiationState) -> bool:
	var patience: int = int(state.bot.get("patience", 5))
	var mood: float = float(state.bot.get("mood", 0.6))
	if patience <= 0 or mood <= LEAVE_MOOD_THRESHOLD:
		state.is_over = true
		state.result = "left"
		return true
	return false


func _mood_tone(bot: Dictionary) -> String:
	var mood: float = float(bot.get("mood", 0.6))
	if mood >= 0.7:
		return "friendly"
	elif mood >= 0.4:
		return "neutral"
	elif mood >= 0.2:
		return "annoyed"
	return "hostile"


## Шанс срабатывания мошеннической схемы вместо нормальной сделки (формула 6).
func roll_scam_trigger(bot: Dictionary) -> bool:
	if not bot.get("is_scammer", false):
		return false
	var honesty: float = float(bot.get("honesty", 0.2))
	var chance: float = 0.5 + (1.0 - honesty) * 0.3
	return randf() < chance
