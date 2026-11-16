class_name WorkshopTab
extends Control
## WorkshopTab — мастерская: выбор предмета из инвентаря, диагностика,
## покупка запчастей у ботов, запуск мини-игр ремонта, расчёт итогового
## качества ремонта и его влияния на цену при продаже.

var _scroll: ScrollContainer
var _list_vbox: VBoxContainer
var _current_entry: Dictionary = {}
var _detail_panel: PanelContainer
var _defect_list_vbox: VBoxContainer


func _ready() -> void:
	_build_ui()


func on_tab_shown() -> void:
	_refresh_item_list()


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(220, 0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_vbox)

	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail_panel)

	_defect_list_vbox = VBoxContainer.new()
	_detail_panel.add_child(_defect_list_vbox)
	_show_no_selection()


func _refresh_item_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()
	for entry in GameState.inventory:
		var btn := Button.new()
		btn.text = entry.get("name", "Товар")
		btn.pressed.connect(_select_item.bind(entry.get("instance_id", -1)))
		_list_vbox.add_child(btn)


func open_item_for_repair(instance_id: int) -> void:
	_select_item(instance_id)


func _select_item(instance_id: int) -> void:
	_current_entry = GameState.get_inventory_item(instance_id)
	if _current_entry.is_empty():
		_show_no_selection()
		return
	_render_detail()


func _show_no_selection() -> void:
	for child in _defect_list_vbox.get_children():
		child.queue_free()
	var label := Label.new()
	label.text = "Выберите предмет слева для ремонта."
	_defect_list_vbox.add_child(label)


func _render_detail() -> void:
	for child in _defect_list_vbox.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = _current_entry.get("name", "Товар")
	title.add_theme_font_size_override("font_size", 20)
	_defect_list_vbox.add_child(title)

	var view_btn := Button.new()
	view_btn.text = "Осмотреть в 3D"
	view_btn.pressed.connect(_on_inspect_pressed)
	_defect_list_vbox.add_child(view_btn)

	var defects: Array = _current_entry.get("defects", [])
	var repaired: Array = _current_entry.get("repaired_defects", [])

	if defects.is_empty():
		var ok_label := Label.new()
		ok_label.text = "Дефектов не обнаружено. Товар готов к продаже."
		_defect_list_vbox.add_child(ok_label)
		return

	for d_id in defects:
		var row := _build_defect_row(d_id, d_id in repaired)
		_defect_list_vbox.add_child(row)


func _build_defect_row(defect_id: String, is_repaired: bool) -> Control:
	var defect: Dictionary = GameData.get_defect(defect_id)
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = defect.get("name", defect_id)
	info.add_child(name_label)

	if is_repaired:
		var status := Label.new()
		status.text = "Исправлено"
		status.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4))
		info.add_child(status)
		return panel

	var diag_btn := Button.new()
	diag_btn.text = "Диагностика"
	diag_btn.pressed.connect(_on_diagnose.bind(defect_id))
	hbox.add_child(diag_btn)

	var requires_part = defect.get("requires_part", null)
	if requires_part != null:
		var buy_btn := Button.new()
		buy_btn.text = "Купить деталь"
		buy_btn.pressed.connect(_on_buy_part.bind(defect_id, requires_part))
		hbox.add_child(buy_btn)

	var repair_btn := Button.new()
	repair_btn.text = "Чинить"
	repair_btn.pressed.connect(_on_start_repair_minigame.bind(defect_id))
	hbox.add_child(repair_btn)

	return panel


func _on_inspect_pressed() -> void:
	var inspector := ItemInspector3D.new()
	inspector.setup_for_repair(_current_entry, Callable())
	get_tree().root.add_child(inspector)
	inspector.closed.connect(func(): inspector.queue_free())


func _on_diagnose(defect_id: String) -> void:
	var defect: Dictionary = GameData.get_defect(defect_id)
	var appraisal_bonus: float = GameState.get_appraisal_bonus()
	GameState.add_skill_xp("appraisal", 5)
	var dialog := AcceptDialog.new()
	dialog.title = "Диагностика"
	dialog.dialog_text = defect.get("diagnosis_hint", "Неясно, в чём проблема.") + \
		"\nСерьёзность: %d%%" % int(defect.get("severity", 0.2) * 100.0 * (1.0 - appraisal_bonus))
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())


func _on_buy_part(defect_id: String, part_id: String) -> void:
	var part: Dictionary = GameData.get_part(part_id)
	if part.is_empty():
		return
	var tiers: Array = part.get("quality_tiers", [])
	var dialog := ConfirmationDialog.new()
	dialog.title = "Купить деталь: " + part.get("name", part_id)
	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)
	var option := OptionButton.new()
	for tier in tiers:
		var tier_bot_price: float = float(part.get("base_price", 100)) * float(tier.get("price_mult", 1.0))
		option.add_item("%s — ~%d ₽" % [tier.get("tier", "original"), int(tier_bot_price)])
	vbox.add_child(option)
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(func():
		var idx: int = option.selected
		if idx >= 0 and idx < tiers.size():
			_purchase_part(defect_id, part_id, part, tiers[idx])
		dialog.queue_free()
	)
	dialog.popup_centered()


func _purchase_part(defect_id: String, part_id: String, part: Dictionary, tier: Dictionary) -> void:
	var bot: Dictionary = BotFactory.create_part_seller_bot(float(part.get("base_price", 100)), tier)
	var price: float = bot.get("asking_price", 100.0)
	if not GameState.can_afford(price):
		_show_message("Недостаточно денег на эту деталь.")
		return
	GameState.add_money(-price)
	if not _current_entry.has("installed_parts"):
		_current_entry["installed_parts"] = {}
	_current_entry["installed_parts"][defect_id] = tier.get("tier", "original")
	GameState.autosave()
	_show_message("Деталь «%s» (%s) куплена за %d ₽." % [part.get("name", part_id), tier.get("tier", "original"), int(price)])


func _on_start_repair_minigame(defect_id: String) -> void:
	var defect: Dictionary = GameData.get_defect(defect_id)
	var minigame_type: String = defect.get("minigame", "screwdriver")
	var requires_part = defect.get("requires_part", null)
	if requires_part != null and not _current_entry.get("installed_parts", {}).has(defect_id):
		_show_message("Сначала купите подходящую деталь для этого дефекта.")
		return

	var minigame: Control = RepairMinigameFactory.create(minigame_type)
	get_tree().root.add_child(minigame)
	minigame.finished.connect(_on_minigame_finished.bind(defect_id, minigame))


func _on_minigame_finished(quality: float, defect_id: String, minigame: Control) -> void:
	minigame.queue_free()
	var repair_skill_bonus: float = GameState.get_repair_quality_bonus()
	var part_tier: String = _current_entry.get("installed_parts", {}).get(defect_id, "")
	var part_quality_mult: float = 1.0
	if part_tier != "":
		var defect: Dictionary = GameData.get_defect(defect_id)
		var part: Dictionary = GameData.get_part(defect.get("requires_part", ""))
		for tier in part.get("quality_tiers", []):
			if tier.get("tier", "") == part_tier:
				part_quality_mult = float(tier.get("quality_mult", 1.0))
				break

	var final_quality: float = clampf((quality + repair_skill_bonus) * (0.5 + part_quality_mult * 0.5), 0.0, 1.0)

	if final_quality < 0.2 and part_tier != "" and part_quality_mult <= 0.0:
		_show_message("Неподходящая деталь — ремонт не удался, дефект остался.")
		return

	var repaired: Array = _current_entry.get("repaired_defects", [])
	repaired.append(defect_id)
	_current_entry["repaired_defects"] = repaired
	# Улучшаем общее состояние предмета пропорционально качеству ремонта.
	var defect_severity: float = GameData.get_defect(defect_id).get("severity", 0.2)
	_current_entry["condition"] = clampf(_current_entry.get("condition", 0.5) + defect_severity * final_quality, 0.0, 1.0)

	GameState.add_skill_xp("repair", 20)
	GameState.record_repair_done()
	GameState.autosave()
	_show_message("Ремонт завершён. Качество: %d%%" % int(final_quality * 100))
	_render_detail()


func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
