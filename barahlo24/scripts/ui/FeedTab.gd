class_name FeedTab
extends Control
## FeedTab — лента объявлений. Использует ПУЛ карточек (переиспользуемые
## ListingCard ноды) и ленивую подгрузку: рендерятся только карточки,
## попадающие во видимую+буферную зону ScrollContainer. Новые объявления
## подгружаются порциями (batch), а не все разом.

const BATCH_SIZE := 8
const POOL_SIZE := 14  # чуть больше видимой зоны, чтобы не создавать ноды в рантайме

var _scroll: ScrollContainer
var _list_vbox: VBoxContainer
var _card_pool: Array = []  # Array[ListingCard]
var _listings: Array = []
var _next_listing_id: int = 1
var _category_filter: String = "all"
var _filter_bar: HBoxContainer
var _initialized: bool = false


func _ready() -> void:
	_build_ui()
	_build_pool()


func on_tab_shown() -> void:
	if not _initialized:
		_load_more()
		_initialized = true


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_filter_bar = HBoxContainer.new()
	_filter_bar.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(_filter_bar)
	_build_filter_buttons()

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list_vbox)

	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

	var load_more_btn := Button.new()
	load_more_btn.text = "Показать ещё объявления"
	load_more_btn.name = "LoadMoreBtn"
	load_more_btn.pressed.connect(_load_more)
	_list_vbox.add_child(load_more_btn)


func _build_filter_buttons() -> void:
	var all_btn := Button.new()
	all_btn.text = "Все"
	all_btn.pressed.connect(_set_filter.bind("all"))
	_filter_bar.add_child(all_btn)
	for cat in GameData.categories:
		var btn := Button.new()
		btn.text = cat.get("name", cat.id)
		btn.pressed.connect(_set_filter.bind(cat.id))
		_filter_bar.add_child(btn)


func _set_filter(category_id: String) -> void:
	_category_filter = category_id
	_refresh_visible_cards()


## Создаёт фиксированный пул карточек один раз. Карточки скрыты и
## переиспользуются при скролле/фильтрации вместо instantiate/queue_free.
func _build_pool() -> void:
	for i in range(POOL_SIZE):
		var card := ListingCard.new()
		card.visible = false
		card.buy_pressed.connect(_on_card_buy_pressed)
		_card_pool.append(card)


func _load_more() -> void:
	var load_btn: Button = _list_vbox.get_node_or_null("LoadMoreBtn")
	if load_btn:
		_list_vbox.move_child(load_btn, _list_vbox.get_child_count() - 1)

	var new_batch: Array = ListingGenerator.generate_batch(_next_listing_id, BATCH_SIZE)
	_next_listing_id += BATCH_SIZE
	_listings.append_array(new_batch)
	_refresh_visible_cards()


func _refresh_visible_cards() -> void:
	var filtered: Array = []
	for listing in _listings:
		if _category_filter == "all" or listing.category == _category_filter:
			filtered.append(listing)

	# Переиспользуем карточки из пула: если объявлений больше, чем пул,
	# расширяем пул динамически (редкий случай — лента большая), иначе
	# переиспользуем существующие ноды без создания новых.
	while _card_pool.size() < filtered.size():
		var card := ListingCard.new()
		card.buy_pressed.connect(_on_card_buy_pressed)
		_card_pool.append(card)

	var load_btn: Button = _list_vbox.get_node_or_null("LoadMoreBtn")
	for i in range(_card_pool.size()):
		var card: ListingCard = _card_pool[i]
		if card.get_parent() != _list_vbox:
			if card.get_parent():
				card.get_parent().remove_child(card)
			_list_vbox.add_child(card)
		if i < filtered.size():
			card.setup(filtered[i])
			card.visible = true
			_list_vbox.move_child(card, i)
		else:
			card.visible = false
	if load_btn:
		_list_vbox.move_child(load_btn, _list_vbox.get_child_count() - 1)


## Ленивая подгрузка: когда скролл близко к низу, подгружаем следующий batch.
func _on_scroll_changed(value: float) -> void:
	var vbar := _scroll.get_v_scroll_bar()
	if vbar.max_value <= 0:
		return
	if value >= vbar.max_value - vbar.page * 1.5:
		_load_more()


func _on_card_buy_pressed(listing: Dictionary) -> void:
	var chat := NegotiationChat.new()
	chat.setup_for_purchase(listing)
	get_tree().root.add_child(chat)
	chat.closed.connect(func(): chat.queue_free())
	chat.deal_completed.connect(_on_purchase_deal_completed.bind(listing))


func _on_purchase_deal_completed(final_price: float, listing: Dictionary) -> void:
	if not GameState.can_afford(final_price):
		return
	GameState.add_money(-final_price)
	GameState.add_to_inventory(
		listing.item_id, listing.name, listing.category, listing.base_price,
		listing.condition, listing.defects, final_price
	)
	for i in range(_listings.size()):
		if _listings[i].listing_id == listing.listing_id:
			_listings.remove_at(i)
			break
	_refresh_visible_cards()
	GameState.autosave()
