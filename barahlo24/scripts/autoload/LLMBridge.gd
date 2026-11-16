extends Node
## LLMBridge — РАСШИРЯЕМАЯ точка подключения внешнего LLM для генерации
## реплик ботов в будущем. По умолчанию ОТКЛЮЧЕНА (enabled = false) и вся
## игра работает полностью офлайн через DialogueGenerator (шаблоны + подстановка).
##
## Никакой API-ключ никогда не хранится в APK / репозитории. Если захотите
## подключить LLM:
##   1. Установите enabled = true.
##   2. Передайте api_key через переменную окружения на вашем сервере-прокси
##      (НЕ храните ключ в клиенте) и заполните endpoint_url на ваш прокси.
##   3. Переопределите _call_remote() для реального HTTP-запроса (HTTPRequest).
## Если enabled = false или запрос не удался — всегда используется офлайн
## fallback-генератор, так что игра никогда не сломается без сети.

@export var enabled: bool = false
@export var endpoint_url: String = ""  # URL вашего backend-прокси, НЕ прямого API с ключом
@export var request_timeout_sec: float = 5.0

signal remote_response_ready(text: String)
signal remote_response_failed(reason: String)


## Основная точка входа. context — произвольные данные о ситуации торга
## (товар, цена, характер бота и т.п.), которые в будущем пойдут в промпт.
## Возвращает фразу синхронно: офлайн-путь всегда мгновенный; "удалённый"
## путь — заглушка, которая сразу падает в офлайн-fallback, чтобы интерфейс
## никогда не зависел от сети.
func generate_line(context: Dictionary, fallback_generator: Callable) -> String:
	if not enabled or endpoint_url.is_empty():
		return fallback_generator.call(context)

	# Заглушка интеграции: в реальном проекте здесь был бы асинхронный
	# HTTPRequest к endpoint_url (вашему прокси-серверу, который сам хранит
	# ключ на сервере). Пока явно не включено и не настроено — не делаем
	# никаких сетевых вызовов.
	push_warning("LLMBridge: enabled=true, но реальный HTTP-вызов не реализован в этой сборке. Используется офлайн-фоллбэк.")
	return fallback_generator.call(context)
