## Прямой цилиндрический модуль гантелеобразной станции (документация 0.1.1):
## антенный/втулочный/передающий модуль неподвижного ствола, либо жилой/
## рабочий модуль на плече вращающегося барабана. Наследует StationModule
## (module_id/display_name/spawn_point/Hull/Collision-регистрацию, а значит и
## совместимость с Array[StationModule] в StationRoot.get_modules() и с
## player_controller.gd, который читает angle_start_deg/angle_end_deg у
## каждого элемента этого массива), но строит прямую трубу через
## DumbbellMeshBuilder вместо дуги тора родителя — переопределяет
## _build_geometry() целиком, унаследованное поле config: StationConfig не
## использует (у этого модуля своя конфигурация, dumbbell_config).
##
## angle_start_deg/angle_end_deg унаследованы, но для гантелеобразной станции
## не имеют точного геометрического смысла (эта станция — не дуга одной
## окружности) — заданы приблизительно, только чтобы не ломать существующий
## угловой перебор в player_controller.gd. Пересмотр — за будущей ревизией
## ТЗ-100 под новую топологию (см. изменения в ТЗ-000).
##
## Выставляет 2 коннектора (station_connector.gd) на торцах трубы —
## Connector_Near (y=0) и Connector_Far (y=length_m) — для сборки станции
## через стыковку (station_docking.gd) вместо жёстких Transform3D в
## station_dumbbell.tscn; не все модули используют оба (например, у антенны/
## передачи дальний торец — просто крепление оборудования, но коннектор всё
## равно создаётся для единообразия и на случай будущей замены детали).
@tool
class_name CylindricalStationModule
extends StationModule

@export var dumbbell_config: DumbbellStationConfig
@export var radius_m: float = 3.0
@export var length_m: float = 8.0

## Дальний торец (y = length_m) закрыт диском — обязательно для жилого/
## рабочего модуля (пол) и как площадка крепления антенны/лазера на стволе.
@export var cap_far_end: bool = true
## Дальний торец — ходимый пол (гравитация "на своих ногах"). Если false —
## отсек невесомый, торец нужен только для визуального замыкания/крепления.
@export var far_cap_is_floor: bool = false

func _build_geometry() -> void:
	_clear_children(_collision_root)
	_clear_generated_lights()
	for child in get_children():
		if child.name == "FarCap":
			child.free()

	_hull.mesh = DumbbellMeshBuilder.build_tube_wall_mesh(radius_m, length_m, dumbbell_config.segment_count)
	if hull_material != null:
		_hull.material_override = hull_material

	if cap_far_end:
		var far_cap := MeshInstance3D.new()
		far_cap.name = "FarCap"
		far_cap.mesh = DumbbellMeshBuilder.build_end_cap_mesh(radius_m, dumbbell_config.segment_count)
		far_cap.position = Vector3(0.0, length_m, 0.0)
		if hull_material != null:
			far_cap.material_override = hull_material
		add_child(far_cap)

	# Точка спавна: у пола (1 м от дальнего торца) для ходимых отсеков,
	# у середины трубы — для невесомых. FR-39-аналог из ТЗ-000.
	spawn_point.position = Vector3(0.0, length_m - 1.0 if far_cap_is_floor else length_m * 0.5, 0.0)

	StationConnector.ensure(self, "Connector_Near", Transform3D(StationConnector.flipped_basis(), Vector3.ZERO))
	StationConnector.ensure(self, "Connector_Far", Transform3D(Basis.IDENTITY, Vector3(0.0, length_m, 0.0)))

	var wall_shape := BoxShape3D.new()
	var chord_len: float = DumbbellMeshBuilder.wall_chord_length(radius_m, dumbbell_config.segment_count)
	wall_shape.size = Vector3(chord_len, length_m, dumbbell_config.wall_thickness_m)
	for local_transform in DumbbellMeshBuilder.tube_wall_collision_transforms(radius_m, length_m, dumbbell_config.segment_count):
		var cs := CollisionShape3D.new()
		cs.shape = wall_shape
		cs.transform = local_transform
		_collision_root.add_child(cs)

	if cap_far_end:
		var cap_shape := BoxShape3D.new()
		cap_shape.size = Vector3(radius_m * 2.0, dumbbell_config.wall_thickness_m, radius_m * 2.0)
		var cap_collision := CollisionShape3D.new()
		cap_collision.shape = cap_shape
		cap_collision.transform = Transform3D(Basis.IDENTITY,
				Vector3(0.0, length_m - dumbbell_config.wall_thickness_m * 0.5, 0.0))
		_collision_root.add_child(cap_collision)

	if far_cap_is_floor:
		_build_interior_lights_straight()

## Внутреннее освещение отсека: несколько OmniLight3D вдоль трубы. Аналог
## StationModule._build_interior_lights(), но для прямой (не дуговой) геометрии.
func _build_interior_lights_straight() -> void:
	for i in range(dumbbell_config.interior_light_count_per_module):
		var t: float = (i + 0.5) / float(dumbbell_config.interior_light_count_per_module)
		var light := OmniLight3D.new()
		light.position = Vector3(0.0, length_m * t, 0.0)
		light.light_color = dumbbell_config.interior_light_color
		light.omni_range = dumbbell_config.interior_light_range_m
		light.light_energy = dumbbell_config.interior_light_energy
		add_child(light)
