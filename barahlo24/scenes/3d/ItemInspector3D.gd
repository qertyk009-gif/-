class_name ItemInspector3D
extends Control
## ItemInspector3D — окно осмотра предмета в 3D. Единственное место в игре,
## где используется SubViewport с 3D-сценой; модель строится процедурно
## (ProceduralModel) из нескольких примитивов. Поддерживает вращение
## перетаскиванием и зум щипком/колесом. Может работать в двух режимах:
## - view-only (осмотр из ленты, без ремонта)
## - repair (с доступом к диагностике и мини-играм, см. WorkshopTab)

signal closed

var _viewport: SubViewport
var _camera: Camera3D
var _model_root: Node3D
var _listing_or_entry: Dictionary = {}
var _rotation_speed := 0.01
var _zoom: float = 3.0
var _dragging := false
var _last_drag_pos := Vector2.ZERO
var _defect_markers: Array = []  # [{defect_id, marker_node}]


func setup_view_only(listing: Dictionary) -> void:
	_listing_or_entry = listing
	_build_ui()
	_build_model(listing.get("model_info", {}))


func setup_for_repair(entry: Dictionary, on_marker_clicked: Callable) -> void:
	_listing_or_entry = entry
	_build_ui()
	var item_def: Dictionary = GameData.get_item(entry.get("item_id", ""))
	_build_model(item_def.get("model", {}))
	_place_defect_markers(entry, on_marker_clicked)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 700)
	panel.position = Vector2(60, 100)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = _listing_or_entry.get("name", "Предмет")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func(): closed.emit())
	header.add_child(close_btn)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(560, 500)
	viewport_container.stretch = true
	viewport_container.gui_input.connect(_on_viewport_gui_input)
	vbox.add_child(viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(560, 500)
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_viewport)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.15)
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	world_env.environment = env
	_viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.0
	light.shadow_enabled = false
	_viewport.add_child(light)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0, _zoom)
	_viewport.add_child(_camera)

	var hint := Label.new()
	hint.text = "Потяните, чтобы вращать. Колесо — приблизить."
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)


func _build_model(model_info: Dictionary) -> void:
	var family: String = model_info.get("family", "generic")
	var scale_mult: float = model_info.get("scale", 1.0)
	var palette_index: int = model_info.get("palette_index", 0)
	_model_root = ProceduralModel.build(family, scale_mult, palette_index)
	_viewport.add_child(_model_root)


func _place_defect_markers(entry: Dictionary, on_marker_clicked: Callable) -> void:
	var defects: Array = entry.get("defects", [])
	var repaired: Array = entry.get("repaired_defects", [])
	var angle_step := TAU / max(1, defects.size())
	var i := 0
	for d_id in defects:
		if d_id in repaired:
			i += 1
			continue
		var marker := CSGSphere3D.new()
		marker.radius = 0.06
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.25, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.2)
		marker.material = mat
		var angle: float = angle_step * i
		marker.position = Vector3(cos(angle) * 0.4, sin(angle) * 0.3, 0.3)
		_model_root.add_child(marker)
		_defect_markers.append({"defect_id": d_id, "node": marker})
		i += 1
	# Клики по маркерам обрабатываются через упрощённый raycast в WorkshopTab
	# (здесь просто храним ссылки); для MVP диагностика также доступна списком
	# кнопок в WorkshopTab, чтобы не зависеть от точности тача по 3D-объекту.
	if on_marker_clicked.is_valid():
		pass


func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_last_drag_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.3, 1.2, 6.0)
			_camera.position.z = _zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.3, 1.2, 6.0)
			_camera.position.z = _zoom
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_last_drag_pos = event.position
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _last_drag_pos
		_last_drag_pos = event.position
		if _model_root:
			_model_root.rotate_y(delta.x * _rotation_speed)
			_model_root.rotate_x(delta.y * _rotation_speed)
	elif event is InputEventScreenDrag:
		var delta: Vector2 = event.relative
		if _model_root:
			_model_root.rotate_y(delta.x * _rotation_speed)
			_model_root.rotate_x(delta.y * _rotation_speed)
