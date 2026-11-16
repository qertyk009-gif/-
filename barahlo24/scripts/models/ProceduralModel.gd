class_name ProceduralModel
extends RefCounted
## ProceduralModel — построение low-poly 3D-моделей из примитивов (Box/Cylinder/
## Prism) прямо в коде, без внешних .glb/.fbx файлов. Это держит размер APK
## маленьким и гарантирует предсказуемый низкий полигонаж (каждая модель —
## несколько десятков-сотен треугольников, далеко меньше лимита в 2000).
##
## "Текстурная палитра" реализована как общий набор из 8 плоских цветов
## (PALETTE), переиспользуемых всеми моделями через StandardMaterial3D без
## затенения в реальном времени теней (shadow casting выключен на уровне
## рендера проекта/окружения) — дёшево по GPU на слабых устройствах.

const PALETTE := [
	Color(0.85, 0.86, 0.88), # 0 светло-серый (корпус техники)
	Color(0.15, 0.17, 0.2),  # 1 почти чёрный (экран/резина)
	Color(0.55, 0.58, 0.62), # 2 серый металлик
	Color(0.78, 0.35, 0.2),  # 3 оранжево-ржавый (рама велосипеда/дерево)
	Color(0.2, 0.45, 0.75),  # 4 синий акцент
	Color(0.9, 0.75, 0.25),  # 5 жёлтый акцент (инструменты)
	Color(0.4, 0.28, 0.18),  # 6 дерево/обивка
	Color(0.92, 0.92, 0.92), # 7 белый (детали/блики)
]

static var _material_cache: Dictionary = {}


static func get_material(palette_index: int) -> StandardMaterial3D:
	var idx: int = clampi(palette_index, 0, PALETTE.size() - 1)
	if _material_cache.has(idx):
		return _material_cache[idx]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE[idx]
	mat.roughness = 0.75
	mat.metallic = 0.05
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material_cache[idx] = mat
	return mat


## Строит модель по семейству (model.family) и возвращает корневой Node3D.
## scale_mult — доп. масштаб из item.model.scale. palette_index выбирает
## основной акцентный цвет корпуса (второстепенные части переиспользуют
## соседние индексы палитры).
static func build(family: String, scale_mult: float, palette_index: int) -> Node3D:
	var root := Node3D.new()
	match family:
		"slab_phone":
			_build_slab_phone(root, palette_index)
		"bike_frame":
			_build_bike_frame(root, palette_index)
		"power_tool":
			_build_power_tool(root, palette_index)
		"furniture_box":
			_build_furniture_box(root, palette_index)
		_:
			_build_generic_box(root, palette_index)
	root.scale = Vector3.ONE * scale_mult
	return root


static func _mesh_instance(mesh: Mesh, material: StandardMaterial3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _build_slab_phone(root: Node3D, palette_index: int) -> void:
	var body_mat := get_material(palette_index)
	var screen_mat := get_material(1)
	var body := BoxMesh.new()
	body.size = Vector3(0.5, 1.0, 0.06)
	root.add_child(_mesh_instance(body, body_mat, Vector3.ZERO))

	var screen := BoxMesh.new()
	screen.size = Vector3(0.44, 0.9, 0.01)
	root.add_child(_mesh_instance(screen, screen_mat, Vector3(0, 0.02, 0.036)))

	var camera_bump := CylinderMesh.new()
	camera_bump.top_radius = 0.04
	camera_bump.bottom_radius = 0.04
	camera_bump.height = 0.02
	root.add_child(_mesh_instance(camera_bump, get_material(2), Vector3(0.15, 0.4, -0.04), Vector3(90, 0, 0)))


static func _build_bike_frame(root: Node3D, palette_index: int) -> void:
	var frame_mat := get_material(palette_index)
	var wheel_mat := get_material(1)

	# Основная рама — наклонные цилиндры, имитирующие трубы рамы.
	var top_tube := CylinderMesh.new()
	top_tube.top_radius = 0.03
	top_tube.bottom_radius = 0.03
	top_tube.height = 0.9
	root.add_child(_mesh_instance(top_tube, frame_mat, Vector3(0, 0.35, 0), Vector3(0, 0, 70)))

	var down_tube := CylinderMesh.new()
	down_tube.top_radius = 0.03
	down_tube.bottom_radius = 0.03
	down_tube.height = 0.75
	root.add_child(_mesh_instance(down_tube, frame_mat, Vector3(-0.15, 0.0, 0), Vector3(0, 0, 25)))

	var seat_tube := CylinderMesh.new()
	seat_tube.top_radius = 0.03
	seat_tube.bottom_radius = 0.03
	seat_tube.height = 0.6
	root.add_child(_mesh_instance(seat_tube, frame_mat, Vector3(0.25, 0.15, 0), Vector3(0, 0, 10)))

	# Колёса.
	var wheel_front := CylinderMesh.new()
	wheel_front.top_radius = 0.38
	wheel_front.bottom_radius = 0.38
	wheel_front.height = 0.04
	root.add_child(_mesh_instance(wheel_front, wheel_mat, Vector3(-0.5, -0.35, 0), Vector3(90, 0, 0)))

	var wheel_back := CylinderMesh.new()
	wheel_back.top_radius = 0.38
	wheel_back.bottom_radius = 0.38
	wheel_back.height = 0.04
	root.add_child(_mesh_instance(wheel_back, wheel_mat, Vector3(0.5, -0.35, 0), Vector3(90, 0, 0)))

	# Руль и седло.
	var handlebar := BoxMesh.new()
	handlebar.size = Vector3(0.3, 0.03, 0.03)
	root.add_child(_mesh_instance(handlebar, get_material(2), Vector3(-0.55, 0.55, 0)))

	var seat := BoxMesh.new()
	seat.size = Vector3(0.18, 0.04, 0.1)
	root.add_child(_mesh_instance(seat, get_material(1), Vector3(0.45, 0.45, 0)))


static func _build_power_tool(root: Node3D, palette_index: int) -> void:
	var body_mat := get_material(palette_index)
	var accent_mat := get_material(5)

	var handle := BoxMesh.new()
	handle.size = Vector3(0.18, 0.5, 0.18)
	root.add_child(_mesh_instance(handle, body_mat, Vector3(0, -0.2, 0), Vector3(0, 0, -15)))

	var body := BoxMesh.new()
	body.size = Vector3(0.55, 0.22, 0.22)
	root.add_child(_mesh_instance(body, body_mat, Vector3(0.15, 0.15, 0)))

	var chuck := CylinderMesh.new()
	chuck.top_radius = 0.07
	chuck.bottom_radius = 0.09
	chuck.height = 0.15
	root.add_child(_mesh_instance(chuck, accent_mat, Vector3(0.45, 0.15, 0), Vector3(0, 0, 90)))

	var trigger := BoxMesh.new()
	trigger.size = Vector3(0.05, 0.1, 0.1)
	root.add_child(_mesh_instance(trigger, accent_mat, Vector3(0.05, -0.02, 0)))


static func _build_furniture_box(root: Node3D, palette_index: int) -> void:
	var main_mat := get_material(palette_index)
	var leg_mat := get_material(6)

	var top := BoxMesh.new()
	top.size = Vector3(0.9, 0.06, 0.6)
	root.add_child(_mesh_instance(top, main_mat, Vector3(0, 0.4, 0)))

	var leg_positions := [
		Vector3(0.4, 0.0, 0.25), Vector3(-0.4, 0.0, 0.25),
		Vector3(0.4, 0.0, -0.25), Vector3(-0.4, 0.0, -0.25),
	]
	for pos in leg_positions:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.06, 0.8, 0.06)
		root.add_child(_mesh_instance(leg, leg_mat, pos))


static func _build_generic_box(root: Node3D, palette_index: int) -> void:
	var mat := get_material(palette_index)
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	root.add_child(_mesh_instance(box, mat, Vector3.ZERO))


## Возвращает приблизительное число треугольников для контроля бюджета
## (используется только для отладочной печати/тестов, не влияет на рендер).
static func estimate_triangle_budget(family: String) -> int:
	match family:
		"slab_phone":
			return 3 * 12 + 32 * 2 + 16 * 2
		"bike_frame":
			return 3 * 16 * 2 + 16 * 2 * 2 + 12 * 2
		"power_tool":
			return 12 * 3 + 16 * 2
		"furniture_box":
			return 12 + 12 * 4
		_:
			return 12
