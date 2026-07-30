## Прямой цилиндрический модуль гантелеобразной станции (документация 0.1.1):
## антенный/втулочный/передающий модуль неподвижного ствола. Наследует
## StationModule (module_id/display_name/spawn_point/Hull/Collision-
## регистрацию, а значит и совместимость с Array[StationModule] в
## StationRoot.get_modules() и с player_controller.gd, который читает
## angle_start_deg/angle_end_deg у каждого элемента этого массива).
##
## Меш/FarCap/коллизия/Connector_Near/Connector_Far — СТАТИЧНЫЕ, запечены
## прямо в соответствующем .tscn (antenna_module.tscn/hub_shell_module.tscn/
## transmission_module.tscn) — обычное сохранённое MeshInstance3D/
## CollisionShape3D-поддерево, как у любой другой сцены (в т.ч.
## экспортируемое в .glb для правки в Blender). Раньше строилось в
## _build_geometry() через DumbbellMeshBuilder каждый _ready() из
## radius_m/length_m/cap_far_end/dumbbell_config — при переходе на статику
## cap_far_end (был нужен только чтобы решить, строить ли FarCap-меш) стал
## мёртвым и удалён; radius_m/length_m остались — они ещё нужны для
## contains_point() и точки спавна (см. ниже), не только для формы меша.
## Чтобы изменить форму — перегенерировать геометрию через DumbbellMeshBuilder
## (см. git-историю этого файла до перехода на статику) и заново запечь.
##
## angle_start_deg/angle_end_deg унаследованы, но для гантелеобразной станции
## не имеют точного геометрического смысла (эта станция — не дуга одной
## окружности) — заданы приблизительно, только чтобы не ломать существующий
## угловой перебор в player_controller.gd. Пересмотр — за будущей ревизией
## ТЗ-100 под новую топологию (см. изменения в ТЗ-000).
@tool
class_name CylindricalStationModule
extends StationModule

@export var dumbbell_config: DumbbellStationConfig
@export var radius_m: float = 3.0
@export var length_m: float = 8.0

## Дальний торец — ходимый пол (гравитация "на своих ногах"). Если false —
## отсек невесомый, торец нужен только для визуального замыкания/крепления.
@export var far_cap_is_floor: bool = false

func _build_geometry() -> void:
	_clear_generated_lights()

	if hull_material != null:
		_hull.material_override = hull_material
		var far_cap := get_node_or_null("FarCap") as MeshInstance3D
		if far_cap != null:
			far_cap.material_override = hull_material

	# Точка спавна: у пола (1 м от дальнего торца) для ходимых отсеков,
	# у середины трубы — для невесомых. FR-39-аналог из ТЗ-000.
	spawn_point.position = Vector3(0.0, length_m - 1.0 if far_cap_is_floor else length_m * 0.5, 0.0)

	if far_cap_is_floor:
		_build_interior_lights_straight()

## Переопределяет StationModule.contains_point(): прямой осевой отсек, не дуга
## — угол (унаследованные angle_start_deg/angle_end_deg, здесь заглушки, см.
## класс-комментарий) не имеет геометрического смысла. Точка принадлежит
## отсеку, если её проекция на локальную +Y (ось трубы, y=0 — ближний торец,
## y=length_m — дальний) лежит в пределах длины трубы, И она лежит достаточно
## близко к самой оси (радиус трубы) — без этого условия точка на полу плеча
## (радиус 24 м) может случайно попасть в диапазон Y какого-нибудь модуля
## ствола просто по совпадению чисел, хотя физически находится в десятках
## метров в стороне от него (обнаружено T-29: "habitat" ошибочно
## определялся как "hub").
func contains_point(global_pos: Vector3) -> bool:
	var local: Vector3 = to_local(global_pos)
	if local.y < 0.0 or local.y > length_m:
		return false
	return Vector2(local.x, local.z).length() <= radius_m

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
