class_name ProfileTab
extends Control
## ProfileTab — профиль игрока: репутация, навыки, ежедневные задания,
## кнопка "Закончить день" (продвигает рыночную симуляцию и задания).

var _scroll: ScrollContainer
var _vbox: VBoxContainer


func _ready() -> void:
	_build_ui()


func on_tab_shown() -> void:
	_refresh()


func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 12)
	_scroll.add_child(_vbox)


func _refresh() -> void:
	for child in _vbox.get_children():
		child.queue_free()

	var rep_label := Label.new()
	rep_label.text = "Репутация: %.1f (отзывов: %d)" % [GameState.reputation, GameState.reviews_count]
	rep_label.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(rep_label)

	var skills_header := Label.new()
	skills_header.text = "Навыки"
	skills_header.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(skills_header)

	var skill_names := {
		"negotiation": "Торг", "repair": "Ремонт", "appraisal": "Оценка", "antifraud": "Антифрод"
	}
	for skill_id in skill_names.keys():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s: уровень %d" % [skill_names[skill_id], GameState.get_skill_level(skill_id)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var bar := ProgressBar.new()
		var needed: int = GameState.get_skill_level(skill_id) * 100
		bar.max_value = needed
		bar.value = GameState.skill_xp.get(skill_id, 0)
		bar.custom_minimum_size = Vector2(120, 0)
		row.add_child(bar)
		_vbox.add_child(row)

	var tasks_header := Label.new()
	tasks_header.text = "Задания на сегодня"
	tasks_header.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(tasks_header)

	for i in range(GameState.daily_tasks.size()):
		_vbox.add_child(_build_task_row(i, GameState.daily_tasks[i]))

	var events_header := Label.new()
	events_header.text = "Рыночные события: " + (", ".join(MarketSim.get_active_event_names()) if not MarketSim.get_active_event_names().is_empty() else "нет активных")
	_vbox.add_child(events_header)

	var end_day_btn := Button.new()
	end_day_btn.text = "Закончить день"
	end_day_btn.pressed.connect(_on_end_day_pressed)
	_vbox.add_child(end_day_btn)


func _build_task_row(index: int, entry: Dictionary) -> Control:
	var t: Dictionary = entry.task
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var desc := Label.new()
	desc.text = t.get("description", "")
	info.add_child(desc)

	var progress := Label.new()
	progress.text = "Прогресс: %d / %d" % [int(entry.progress), int(t.target)]
	progress.add_theme_font_size_override("font_size", 12)
	info.add_child(progress)

	if entry.completed and not entry.claimed:
		var claim_btn := Button.new()
		claim_btn.text = "Забрать награду"
		claim_btn.pressed.connect(_on_claim_task.bind(index))
		hbox.add_child(claim_btn)
	elif entry.claimed:
		var done_label := Label.new()
		done_label.text = "Получено ✔"
		hbox.add_child(done_label)

	return panel


func _on_claim_task(index: int) -> void:
	GameState.claim_daily_task(index)
	GameState.autosave()
	_refresh()


func _on_end_day_pressed() -> void:
	GameState.advance_day()
	GameState.autosave()
	_refresh()
