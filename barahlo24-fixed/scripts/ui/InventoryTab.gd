class_name InventoryTab
extends Control
## InventoryTab — список купленных товаров игрока (в ремонте или готовых
## к продаже) + список активных объявлений на продажу.

var _scroll: ScrollContainer
var _list_vbox: VBoxContainer


func _ready() -> void:
	_build_ui()


func on_tab_shown() -> void:
	_refresh()


func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list_vbox)


func _refresh() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()

	var header1 := Label.new()
	header1.text = "На ремонте / складе"
	header1.add_theme_font_size_override("font_size", 18)
	_list_vbox.add_child(header1)

	if GameState.inventory.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Пока пусто. Купите что-нибудь в ленте!"
		_list_vbox.add_child(empty_label)
	for entry in GameState.inventory:
		_list_vbox.add_child(_build_inventory_row(entry))

	var header2 := Label.new()
	header2.text = "Мои объявления"
	header2.add_theme_font_size_override("font_size", 18)
	_list_vbox.add_child(header2)

	if GameState.active_listings.is_empty():
		var empty2 := Label.new()
		empty2.text = "Нет активных объявлений."
		_list_vbox.add_child(empty2)
	for listing in GameState.active_listings:
		_list_vbox.add_child(_build_listing_row(listing))


func _build_inventory_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var title := Label.new()
	title.text = entry.get("name", "Товар")
	info.add_child(title)

	var remaining: int = entry.get("defects", []).size() - entry.get("repaired_defects", []).size()
	var status := Label.new()
	status.text = "Куплено за %d ₽. Невылеченных дефектов: %d" % [int(entry.get("purchase_price", 0)), remaining]
	status.add_theme_font_size_override("font_size", 12)
	info.add_child(status)

	var repair_btn := Button.new()
	repair_btn.text = "Ремонт"
	repair_btn.pressed.connect(_on_open_workshop.bind(entry.get("instance_id", -1)))
	hbox.add_child(repair_btn)

	var sell_btn := Button.new()
	sell_btn.text = "Продать"
	sell_btn.pressed.connect(_on_sell_pressed.bind(entry))
	hbox.add_child(sell_btn)

	return panel


func _build_listing_row(listing: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var title := Label.new()
	title.text = "%s — выставлено за %d ₽" % [listing.get("name", "Товар"), int(listing.get("asking_price", 0))]
	info.add_child(title)

	var negotiate_btn := Button.new()
	negotiate_btn.text = "Покупатель пишет"
	negotiate_btn.pressed.connect(_on_negotiate_sale.bind(listing))
	hbox.add_child(negotiate_btn)

	return panel


func _on_open_workshop(instance_id: int) -> void:
	var hub := _find_main_hub()
	if hub:
		hub.open_inventory_item(instance_id)


func _on_sell_pressed(entry: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Выставить на продажу"
	var suggested: float = entry.get("base_price", 1000) * entry.get("condition", 1.0)
	var line_edit := LineEdit.new()
	line_edit.text = "%d" % int(suggested)
	dialog.add_child(line_edit)
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func():
		var price_text: String = line_edit.text.strip_edges()
		var price: float = float(price_text) if price_text.is_valid_float() else suggested
		GameState.list_for_sale(entry.get("instance_id", -1), price)
		GameState.autosave()
		_refresh()
		dialog.queue_free()
	)
	dialog.popup_centered()


func _on_negotiate_sale(listing: Dictionary) -> void:
	var chat := NegotiationChat.new()
	chat.setup_for_sale(listing)
	get_tree().root.add_child(chat)
	chat.closed.connect(func(): chat.queue_free())
	chat.deal_completed.connect(_on_sale_completed.bind(listing))


func _on_sale_completed(final_price: float, listing: Dictionary) -> void:
	var net: float = GameState.complete_sale(listing, final_price)
	GameState.add_reputation(randf_range(0.5, 2.0))
	GameState.autosave()
	_refresh()
	print("Продано за %d, чистыми получено %d" % [int(final_price), int(net)])


func _find_main_hub() -> Node:
	var node: Node = self
	while node:
		if node.has_method("open_inventory_item"):
			return node
		node = node.get_parent()
	return null
