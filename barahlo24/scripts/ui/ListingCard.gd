class_name ListingCard
extends PanelContainer
## ListingCard — переиспользуемая карточка объявления в ленте.
## setup() заново заполняет её данными без создания/удаления нод (часть
## пул-паттерна в FeedTab). Не содержит 3D — только Control-элементы.

signal buy_pressed(listing: Dictionary)

var _listing: Dictionary = {}
var _title_label: Label
var _price_label: Label
var _condition_label: Label
var _defects_label: Label
var _icon_rect: ColorRect
var _buy_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(0, 96)
	_build_ui()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.17, 0.21)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	_icon_rect = ColorRect.new()
	_icon_rect.custom_minimum_size = Vector2(64, 64)
	hbox.add_child(_icon_rect)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.clip_text = true
	info_vbox.add_child(_title_label)

	_price_label = Label.new()
	_price_label.add_theme_color_override("font_color", Color(0.96, 0.75, 0.25))
	info_vbox.add_child(_price_label)

	_condition_label = Label.new()
	_condition_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(_condition_label)

	_defects_label = Label.new()
	_defects_label.add_theme_font_size_override("font_size", 12)
	_defects_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
	info_vbox.add_child(_defects_label)

	_buy_button = Button.new()
	_buy_button.text = "Торговаться"
	_buy_button.custom_minimum_size = Vector2(100, 0)
	_buy_button.pressed.connect(_on_buy_pressed)
	hbox.add_child(_buy_button)


func setup(listing: Dictionary) -> void:
	_listing = listing
	_title_label.text = listing.get("name", "Товар")
	_price_label.text = "%d ₽" % int(listing.get("asking_price", 0))
	var condition: float = listing.get("condition", 1.0)
	_condition_label.text = "Состояние: %d%%" % int(condition * 100)

	var known_defects: Array = listing.get("known_defects", [])
	if known_defects.is_empty():
		_defects_label.text = ""
	else:
		var names: Array = []
		for d_id in known_defects:
			names.append(GameData.get_defect(d_id).get("name", d_id))
		_defects_label.text = "Видно: " + ", ".join(names)

	var model_info: Dictionary = listing.get("model_info", {})
	var palette_idx: int = model_info.get("palette_index", 0)
	_icon_rect.color = ProceduralModel.PALETTE[clampi(palette_idx, 0, ProceduralModel.PALETTE.size() - 1)]


func _on_buy_pressed() -> void:
	buy_pressed.emit(_listing)
