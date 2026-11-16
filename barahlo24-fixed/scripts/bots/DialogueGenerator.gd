class_name DialogueGenerator
extends RefCounted
## DialogueGenerator — офлайн генератор реплик чата торга.
## Берёт шаблоны из GameData.phrases и подставляет значения через {ключ}.
## Выбор тона ответа бота (friendly/neutral/annoyed/hostile) определяется
## по его текущему настроению (см. NegotiationEngine._mood_tone, но для
## текста здесь считаем независимо по тому же принципу, чтобы не требовать
## ссылку на state).

static func format_phrase(template: String, vars: Dictionary) -> String:
	var result := template
	for key in vars.keys():
		result = result.replace("{%s}" % key, str(vars[key]))
	return result


static func pick_random(list: Array) -> String:
	if list.is_empty():
		return ""
	return list[randi() % list.size()]


static func mood_tone(mood: float) -> String:
	if mood >= 0.7:
		return "friendly"
	elif mood >= 0.4:
		return "neutral"
	elif mood >= 0.2:
		return "annoyed"
	return "hostile"


static func bot_greeting(item_name: String, mood: float) -> String:
	var tone := mood_tone(mood)
	var options: Array = GameData.phrases.get("bot_responses", {}).get("greeting", {}).get(tone, ["Здравствуйте."])
	return format_phrase(pick_random(options), {"item": item_name})


static func bot_offer_accept(offer: float, mood: float) -> String:
	var tone := mood_tone(mood)
	var options: Array = GameData.phrases.get("bot_responses", {}).get("offer_accept", {}).get(tone, ["Договорились."])
	return format_phrase(pick_random(options), {"offer": "%d" % int(offer)})


static func bot_offer_reject(offer: float, mood: float) -> String:
	var tone := mood_tone(mood)
	var options: Array = GameData.phrases.get("bot_responses", {}).get("offer_reject", {}).get(tone, ["Нет, не пойдёт."])
	return format_phrase(pick_random(options), {"offer": "%d" % int(offer)})


static func bot_counter_offer(counter: float, mood: float) -> String:
	var tone := mood_tone(mood)
	var options: Array = GameData.phrases.get("bot_responses", {}).get("counter_offer", {}).get(tone, ["Моя цена — {counter}."])
	return format_phrase(pick_random(options), {"counter": "%d" % int(counter)})


static func bot_defect_answer(honest: bool, has_defect: bool, defect_hint: String) -> String:
	var responses: Dictionary = GameData.phrases.get("bot_responses", {}).get("defect_question", {})
	if not has_defect:
		return format_phrase(pick_random(responses.get("honest_ok", ["Всё исправно."])), {})
	if honest:
		return format_phrase(pick_random(responses.get("honest_defect", ["Есть нюанс: {defect_hint}."])), {"defect_hint": defect_hint})
	return format_phrase(pick_random(responses.get("lying", ["Всё идеально!"])), {})


static func bot_photo_response(complied: bool) -> String:
	var responses: Dictionary = GameData.phrases.get("bot_responses", {}).get("photo_request", {})
	if complied:
		return pick_random(responses.get("comply", ["Вот фото."]))
	return pick_random(responses.get("stall", ["Фото потом."]))


static func bot_threaten_response(mood: float) -> String:
	var tone := mood_tone(mood)
	var options: Array = GameData.phrases.get("bot_responses", {}).get("threat_leave", {}).get(tone, ["Решайте сами."])
	return pick_random(options)


static func bot_farewell(mood: float) -> String:
	var tone := mood_tone(mood)
	var options: Array = GameData.phrases.get("bot_responses", {}).get("farewell_leave", {}).get(tone, ["До свидания."])
	return pick_random(options)


static func bot_scam_line(scam_type: String) -> String:
	var key := "scam_prepay" if scam_type == "fake_prepay" else "scam_swap"
	var options: Array = GameData.phrases.get("bot_responses", {}).get(key, {}).get("default", ["..."])
	return pick_random(options)


static func player_line_offer(offer: float) -> String:
	var options: Array = GameData.phrases.get("player_lines", {}).get("offer_price", ["Предлагаю {offer}."])
	return format_phrase(pick_random(options), {"offer": "%d" % int(offer)})


static func player_line(key: String, vars: Dictionary = {}) -> String:
	var options: Array = GameData.phrases.get("player_lines", {}).get(key, [""])
	return format_phrase(pick_random(options), vars)
