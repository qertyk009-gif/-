class_name NegotiationChat
extends Control
## NegotiationChat — полноэкранное окно чата торга с ботом.
## Работает в двух режимах: "purchase" (игрок покупает у бота-продавца)
## и "sale" (бот-покупатель хочет купить объявление игрока).
## Вся логика цифр — в NegotiationEngine; этот скрипт только дергает его
## методы и обновляет RichTextLabel-ленту сообщений + кнопки реплик.

signal deal_completed(final_price: float)
signal closed
signal scam_detected(scam_type: String)

enum Mode { PURCHASE, SALE }

var _mode: int = Mode.PURCHASE
var _listing: Dictionary = {}
var _state: NegotiationState
var _chat_log: RichTextLabel
var _quick_buttons_box: HBoxContainer
var _price_input: LineEdit
var _bot_name_label: Label
var _close_button: Button
var _pending_scam_type: String = ""
var _initial_price: float = 0.0


func setup_for_purchase(listing: Dictionary) -> void:
	_mode = Mode.PURCHASE
	_listing = listing
	_initial_price = listing.get("asking_price", 0.0)
	_build_ui()
	_state = NegotiationEngine.start_negotiation(listing.get("seller_bot", {}), _initial_price)
	_append_bot_line(DialogueGenerator.bot_greeting(listing.get("name", "товар"), _state.bot.mood))


func setup_for_sale(listing_entry: Dictionary) -> void:
	_mode = Mode.SALE
	_listing = listing_entry
	_initial_price = listing_entry.get("asking_price", 0.0)
	_build_ui()
	var buyer_bot := BotFactory.create_buyer_bot(_initial_price)
	_state = NegotiationEngine.start_negotiation(buyer_bot, _initial_price)
	_append_bot_line(DialogueGenerator.bot_greeting(listing_entry.get("name", "товар"), _state.bot.mood))


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 900)
	panel.position = Vector2(40, 60)
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = ThemeManager.get_bg_color().lightened(0.05)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_bot_name_label = Label.new()
	_bot_name_label.text = _listing.get("name", "Товар")
	_bot_name_label.add_theme_font_size_override("font_size", 18)
	_bot_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_bot_name_label)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	var view_3d_btn := Button.new()
	view_3d_btn.text = "👁 Осмотреть"
	view_3d_btn.pressed.connect(_on_inspect_pressed)
	vbox.add_child(view_3d_btn)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = true
	_chat_log.scroll_following = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.custom_minimum_size = Vector2(0, 460)
	vbox.add_child(_chat_log)

	var price_row := HBoxContainer.new()
	vbox.add_child(price_row)
	_price_input = LineEdit.new()
	_price_input.placeholder_text = "Своя цена"
	_price_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(_price_input)
	var offer_btn := Button.new()
	offer_btn.text = "Предложить"
	offer_btn.pressed.connect(_on_custom_offer_pressed)
	price_row.add_child(offer_btn)

	_quick_buttons_box = HBoxContainer.new()
	_quick_buttons_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_quick_buttons_box)
	_build_quick_buttons()


func _build_quick_buttons() -> void:
	_add_quick_button("Спросить о дефектах", _on_ask_defects)
	_add_quick_button("Попросить фото", _on_ask_photo)
	_add_quick_button("Пригрозить уйти", _on_threaten_leave)
	_add_quick_button("Принять цену бота", _on_accept_current)


func _add_quick_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	_quick_buttons_box.add_child(btn)


func _append_player_line(text: String) -> void:
	_chat_log.append_text("[right][color=#8fd1ff]Вы: %s[/color][/right]\n" % text)


func _append_bot_line(text: String) -> void:
	_chat_log.append_text("[color=#f0c060]%s: %s[/color]\n" % [_state.bot.get("display_name", "Бот"), text])


func _append_system_line(text: String) -> void:
	_chat_log.append_text("[color=#999999][i]%s[/i][/color]\n" % text)


func _on_custom_offer_pressed() -> void:
	if _state.is_over:
		return
	var text := _price_input.text.strip_edges()
	if not text.is_valid_float():
		return
	var offer: float = float(text)
	_price_input.text = ""
	_submit_offer(offer)


func _submit_offer(offer: float) -> void:
	_append_player_line(DialogueGenerator.player_line_offer(offer))
	var result: Dictionary = NegotiationEngine.offer_price(_state, offer)
	match result.outcome:
		"accepted":
			_append_bot_line(DialogueGenerator.bot_offer_accept(offer, _state.bot.mood))
			_handle_deal_accepted(offer)
		"counter":
			_append_bot_line(DialogueGenerator.bot_counter_offer(result.counter_price, _state.bot.mood))
		"rejected":
			_append_bot_line(DialogueGenerator.bot_offer_reject(offer, _state.bot.mood))
		"left":
			_append_bot_line(DialogueGenerator.bot_farewell(0.1))
			_handle_bot_left()


func _on_ask_defects() -> void:
	if _state.is_over:
		return
	_append_player_line(DialogueGenerator.player_line("ask_defects"))
	var defects: Array = _listing.get("defects", [])
	var has_hidden := false
	var hint := ""
	for d_id in defects:
		var d: Dictionary = GameData.get_defect(d_id)
		if not d.get("visible", false):
			has_hidden = true
			hint = d.get("diagnosis_hint", "есть небольшой нюанс")
			break
	var result: Dictionary = NegotiationEngine.ask_about_defects(_state, has_hidden, hint)
	if result.outcome == "left":
		_append_bot_line(DialogueGenerator.bot_farewell(0.1))
		_handle_bot_left()
		return
	_append_bot_line(DialogueGenerator.bot_defect_answer(result.honest, has_hidden, hint))
	if has_hidden and not result.honest:
		_append_system_line("Антифрод-навык мог бы помочь распознать обман (см. Профиль).")


func _on_ask_photo() -> void:
	if _state.is_over:
		return
	_append_player_line(DialogueGenerator.player_line("ask_photo"))
	var result: Dictionary = NegotiationEngine.ask_for_photo(_state)
	if result.outcome == "left":
		_append_bot_line(DialogueGenerator.bot_farewell(0.1))
		_handle_bot_left()
		return
	_append_bot_line(DialogueGenerator.bot_photo_response(result.complied))


func _on_threaten_leave() -> void:
	if _state.is_over:
		return
	_append_player_line(DialogueGenerator.player_line("threat_leave"))
	var result: Dictionary = NegotiationEngine.threaten_leave(_state)
	match result.outcome:
		"left":
			_append_bot_line(DialogueGenerator.bot_farewell(0.1))
			_handle_bot_left()
		"conceded":
			_append_bot_line(DialogueGenerator.bot_counter_offer(result.counter_price, _state.bot.mood))
		"stood_firm":
			_append_bot_line(DialogueGenerator.bot_threaten_response(_state.bot.mood))


func _on_accept_current() -> void:
	if _state.is_over:
		return
	var price: float = _state.current_price
	_append_player_line(DialogueGenerator.player_line("accept_deal", {"price": "%d" % int(price)}))
	_handle_deal_accepted(price)


func _handle_deal_accepted(final_price: float) -> void:
	if _mode == Mode.PURCHASE and _state.bot.get("is_scammer", false):
		if NegotiationEngine.roll_scam_trigger(_state.bot):
			_pending_scam_type = _state.bot.get("scam_type", "fake_prepay")
			_append_system_line(DialogueGenerator.bot_scam_line(_pending_scam_type))
			_show_scam_choice()
			return
	_finalize_deal(final_price)


func _show_scam_choice() -> void:
	for child in _quick_buttons_box.get_children():
		child.queue_free()
	_add_quick_button("Отказаться (подозрительно)", _on_decline_scam)
	_add_quick_button("Согласиться на предоплату", _on_fall_for_scam)


func _on_decline_scam() -> void:
	# Навык антифрода (GameState.get_antifraud_bonus()) в будущем может
	# повышать шанс автоматического распознавания обмана до выбора игрока.
	GameState.add_skill_xp("antifraud", 15)
	_append_system_line("Вы распознали подозрительную схему и отказались. Антифрод-навык пригодился! (+опыт)")
	_rebuild_quick_buttons_normal()
	_append_bot_line(DialogueGenerator.bot_farewell(0.2))
	_handle_bot_left()


func _on_fall_for_scam() -> void:
	_append_system_line("Вы перевели предоплату... и продавец пропал. Деньги потеряны, товар не получен.")
	var loss: float = min(GameState.money, _initial_price * 0.3)
	GameState.add_money(-loss)
	scam_detected.emit(_pending_scam_type)
	_disable_all_inputs()
	closed.emit()


func _rebuild_quick_buttons_normal() -> void:
	for child in _quick_buttons_box.get_children():
		child.queue_free()
	_build_quick_buttons()


func _finalize_deal(final_price: float) -> void:
	_append_system_line("Сделка заключена: %d ₽" % int(final_price))
	var discount_pct: float = 0.0
	if _mode == Mode.PURCHASE and _initial_price > 0:
		discount_pct = max(0.0, (_initial_price - final_price) / _initial_price * 100.0)
		GameState.record_negotiation_discount(discount_pct)
		GameState.add_skill_xp("negotiation", 10)
	deal_completed.emit(final_price)
	_disable_all_inputs()


func _handle_bot_left() -> void:
	_disable_all_inputs()


func _disable_all_inputs() -> void:
	_price_input.editable = false
	for child in _quick_buttons_box.get_children():
		if child is Button:
			child.disabled = true


func _on_close_pressed() -> void:
	closed.emit()


func _on_inspect_pressed() -> void:
	var inspector := ItemInspector3D.new()
	inspector.setup_view_only(_listing)
	get_tree().root.add_child(inspector)
	inspector.closed.connect(func(): inspector.queue_free())
