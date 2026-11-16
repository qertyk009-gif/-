extends Control
## MainHub — корневой UI-контроллер: нижняя навигация между вкладками
## (Лента / Инвентарь / Мастерская / Профиль) и верхняя панель денег/дня.
## Каждая вкладка — отдельный Control-скрипт, создаваемый программно и
## добавляемый в общий контейнер; показывается только активная вкладка,
## чтобы не тратить ресурсы на скрытые.

var _content_container: Control
var _top_bar_money: Label
var _top_bar_day: Label
var _top_bar_rep: Label
var _tabs: Dictionary = {}  # name -> Control instance
var _tab_buttons: Dictionary = {}
var _active_tab: String = "feed"

const TAB_ORDER := ["feed", "inventory", "workshop", "profile"]
const TAB_LABELS := {
	"feed": "Лента", "inventory": "Инвентарь", "workshop": "Мастерская", "profile": "Профиль"
}


func _ready() -> void:
	if not GameState.try_load_save():
		pass # первый запуск — остаются стартовые значения GameState
	ThemeManager.apply_theme(self)
	_build_layout()
	_build_tabs()
	_switch_tab("feed")
	GameState.money_changed.connect(_on_money_changed)
	GameState.reputation_changed.connect(_on_rep_changed)
	GameState.day_advanced.connect(_on_day_changed)
	_refresh_top_bar()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeManager.get_bg_color()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# Верхняя панель.
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 56)
	root_vbox.add_child(top_bar)
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_hbox)

	_top_bar_money = Label.new()
	_top_bar_money.add_theme_font_size_override("font_size", 18)
	top_hbox.add_child(_top_bar_money)

	_top_bar_rep = Label.new()
	_top_bar_rep.add_theme_font_size_override("font_size", 18)
	top_hbox.add_child(_top_bar_rep)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	_top_bar_day = Label.new()
	_top_bar_day.add_theme_font_size_override("font_size", 18)
	top_hbox.add_child(_top_bar_day)

	var theme_btn := Button.new()
	theme_btn.text = "Тема"
	theme_btn.pressed.connect(_on_theme_toggle)
	top_hbox.add_child(theme_btn)

	# Контейнер содержимого вкладок.
	_content_container = Control.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_content_container)

	# Нижняя навигация.
	var nav_bar := PanelContainer.new()
	nav_bar.custom_minimum_size = Vector2(0, 64)
	root_vbox.add_child(nav_bar)
	var nav_hbox := HBoxContainer.new()
	nav_bar.add_child(nav_hbox)
	for tab_id in TAB_ORDER:
		var btn := Button.new()
		btn.text = TAB_LABELS[tab_id]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.pressed.connect(_switch_tab.bind(tab_id))
		nav_hbox.add_child(btn)
		_tab_buttons[tab_id] = btn


func _build_tabs() -> void:
	var feed := FeedTab.new()
	feed.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_container.add_child(feed)
	_tabs["feed"] = feed

	var inventory := InventoryTab.new()
	inventory.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_container.add_child(inventory)
	_tabs["inventory"] = inventory

	var workshop := WorkshopTab.new()
	workshop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_container.add_child(workshop)
	_tabs["workshop"] = workshop

	var profile := ProfileTab.new()
	profile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_container.add_child(profile)
	_tabs["profile"] = profile


func _switch_tab(tab_id: String) -> void:
	_active_tab = tab_id
	for key in _tabs.keys():
		var tab: Control = _tabs[key]
		tab.visible = (key == tab_id)
		if tab.visible and tab.has_method("on_tab_shown"):
			tab.on_tab_shown()
	for key in _tab_buttons.keys():
		_tab_buttons[key].button_pressed = (key == tab_id)


func open_inventory_item(instance_id: int) -> void:
	_switch_tab("workshop")
	if _tabs.has("workshop"):
		_tabs["workshop"].open_item_for_repair(instance_id)


func _refresh_top_bar() -> void:
	_top_bar_money.text = "%d ₽" % int(GameState.money)
	_top_bar_rep.text = "Реп. %.0f" % GameState.reputation
	_top_bar_day.text = "День %d" % GameState.current_day


func _on_money_changed(_v: float) -> void:
	_refresh_top_bar()


func _on_rep_changed(_v: float) -> void:
	_refresh_top_bar()


func _on_day_changed(_d: int) -> void:
	_refresh_top_bar()
	if _tabs.has("feed"):
		_tabs["feed"].on_tab_shown()


func _on_theme_toggle() -> void:
	ThemeManager.toggle_theme(self)
	var bg: ColorRect = get_child(0)
	bg.color = ThemeManager.get_bg_color()
