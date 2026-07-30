## Жилой/рабочий модуль гантелеобразной станции — дуговая "голова молота"
## (см. отчёт о ревизии конфигурации 0.1.1, второе уточнение): четверть-секция
## прямоугольного тора, радиусы [inner_radius_m, outer_radius_m], дуга
## angle_span_deg (60° по уточнению 0.1.1, позже уменьшена до 30° — см.
## комментарий у самого поля) вокруг оси вращения, гранёный профиль
## пола/потолка из arc_segment_count хорд — то же число (16) и та же схема
## коллизии, что у старого (доказанно рабочего) кольца станции, см.
## _build_arc_collision(); отказались от более ранней идеи "6-8 сегментов,
## читаемый глазом гранёный профиль" ради совпадения с рабочей конфигурацией.
## Пол — дальняя (outer_radius_m) грань, потолок — ближняя (inner_radius_m),
## где ровно по центру дуги (симметрично) расположен Connector_Corridor —
## точка стыковки с коридором (station_connector.gd/station_docking.gd).
##
## Наследует StationModule (module_id/spawn_point/регистрация в
## StationRoot.get_modules()), переопределяет только _build_geometry() — как
## и CylindricalStationModule. Заменяет отклонённую (плоские грани, без
## кривизны пола/потолка) rounded_box_station_module.gd.
@tool
class_name ArcRoomStationModule
extends StationModule

@export var dumbbell_config: DumbbellStationConfig
## Радиус потолка — ближняя к оси вращения грань, где коннектор коридора.
## Глубина комнаты (outer_radius_m - inner_radius_m) — 5 м, вдвое меньше
## исходных 10 м (запрос "уменьши высоту вдвое"): пол (outer_radius_m=60 м)
## сознательно не тронут — глубина уменьшена целиком за счёт потолка,
## сдвинутого ближе к полу. Стыковка по коннекторам (station_docking.gd)
## пересчитывает позицию комнаты автоматически при любом inner_radius_m —
## проверено эмпирически: абсолютный радиус пола от оси вращения не зависит
## от inner_radius_m/длины коридора, только от outer_radius_m, так что эта
## правка не требует правки corridor_length_m и не задевает физику ходьбы
## (та по-прежнему привязана к r=60, не изменившемуся). Это СОБСТВЕННОЕ поле
## модуля, НЕ читается из dumbbell_config.arc_room_inner_radius_m (то поле не
## синхронизировано с этим намеренно, см. его комментарий в
## dumbbell_station_config.gd) — держать оба значения в согласии вручную при
## следующей правке.
@export var inner_radius_m: float = 55.0
## Радиус пола — дальняя грань, здесь действует центробежная "гравитация".
## 60 м — тот же радиус, что у старого (доказанно рабочего) кольца станции
## (StationConfig.ring_radius_m) и что и в station_dumbbell_rotator.tres
## (ring_radius_m, задаёт угловую скорость плеча) — при меньшем радиусе (24 м
## первой ревизии) угловая скорость плеча заметно выше при том же g, и физика
## ходьбы разваливалась (см. отчёт по адаптации ТЗ-100 под ТЗ-000 §17.3).
@export var outer_radius_m: float = 60.0
## Половина ширины отсека вдоль главной оси станции ("приплюснутое" измерение).
@export var axial_half_width_m: float = 4.0
## Угловая протяжённость дуги (= "длина" комнаты вдоль пола) — 30°, вдвое
## меньше исходных 60° (запрос "уменьши длину вдвое"). Боковые стены
## (axial_half_width_m) и коннектор коридора не зависят от этого поля —
## сужение дуги не сдвигает и не ломает их.
@export var angle_span_deg: float = 30.0
## Число гранёных сегментов дуги пола/потолка/стен — ОДНО и то же значение
## для всех поверхностей И для видимой геометрии, буквально как у старого
## (доказанно рабочего) кольца: там config.arc_segment_count=16 на 45°-модуль
## (~2.8°/сегмент) — то же самое, независимо от пробовавшихся здесь ранее
## других значений/раздельных констант для пола и стен, ничего не решивших
## (см. историю правок _build_arc_collision()). Держим то же число, что и
## там, а не переизобретаем.
@export var arc_segment_count: int = 16

func _build_geometry() -> void:
	_collision_root.transform = Transform3D.IDENTITY
	_clear_children(_collision_root)
	_clear_generated_lights()
	for child in get_children():
		if child.name.begins_with("EndCap_"):
			child.free()

	var angle_span_rad: float = deg_to_rad(angle_span_deg)

	_hull.mesh = DumbbellMeshBuilder.build_arc_room_wall_mesh(
			inner_radius_m, outer_radius_m, axial_half_width_m, angle_span_rad, arc_segment_count)
	if hull_material != null:
		_hull.material_override = hull_material

	for sign_i in [-1.0, 1.0]:
		var end_cap := MeshInstance3D.new()
		end_cap.name = "EndCap_%s" % ("Start" if sign_i < 0.0 else "End")
		end_cap.mesh = DumbbellMeshBuilder.build_arc_room_end_cap_mesh(
				inner_radius_m, outer_radius_m, axial_half_width_m, sign_i * angle_span_rad * 0.5)
		if hull_material != null:
			end_cap.material_override = hull_material
		add_child(end_cap)

	# Точка спавна — 1 м над полом, в центре дуги (та же симметрия, что и у
	# коннектора коридора на потолке).
	spawn_point.position = Vector3(0.0, outer_radius_m - 1.0, 0.0)

	StationConnector.ensure(self, "Connector_Corridor",
			Transform3D(StationConnector.flipped_basis(), Vector3(0.0, inner_radius_m, 0.0)))

	_build_arc_collision(angle_span_rad)
	_build_arc_interior_lights(angle_span_rad)

## Пол/потолок/2 боковые стены — тонкие слои-коллайдеры на хорду-сегмент,
## буквально та же схема, что и у StationModule._build_collision() (старое
## кольцо): ОДНА общая длина хорды (посчитанная по среднему радиусу,
## mid_radius, тем же приёмом, что и там — не отдельно для пола/потолка/стен),
## ОДНА толщина (dumbbell_config.wall_thickness_m — тот же смысл, что и
## WALL_THICKNESS_M там), ОДНО число сегментов (arc_segment_count) без
## запаса/нахлёста. Плюс 2 торцевые стены, закрывающие угловые пределы дуги
## (комната самостоятельная, не часть непрерывного кольца — там аналога нет).
## Названа не так, как одноимённый метод в StationModule (_build_collision) —
## сигнатуры разные, GDScript требует их совпадения при переопределении
## метода с тем же именем.
func _build_arc_collision(angle_span_rad: float) -> void:
	var mid_radius: float = (inner_radius_m + outer_radius_m) * 0.5
	var wt: float = dumbbell_config.wall_thickness_m
	var axial_width: float = axial_half_width_m * 2.0
	var chord_len: float = DumbbellMeshBuilder.arc_room_chord_length(mid_radius, angle_span_rad, arc_segment_count)

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(chord_len, wt, axial_width)
	_add_arc_collision_layer(outer_radius_m + wt * 0.5, floor_shape, angle_span_rad)

	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(chord_len, wt, axial_width)
	_add_arc_collision_layer(inner_radius_m - wt * 0.5, ceiling_shape, angle_span_rad)

	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(chord_len, outer_radius_m - inner_radius_m, wt)
	_add_arc_collision_layer(mid_radius, wall_shape, angle_span_rad, axial_half_width_m)
	_add_arc_collision_layer(mid_radius, wall_shape, angle_span_rad, -axial_half_width_m)

	var end_shape := BoxShape3D.new()
	end_shape.size = Vector3(wt, outer_radius_m - inner_radius_m, axial_width)
	for sign_i in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		cs.shape = end_shape
		cs.transform = DumbbellMeshBuilder.arc_room_end_collision_transform(
				inner_radius_m, outer_radius_m, sign_i * angle_span_rad * 0.5)
		_collision_root.add_child(cs)

func _add_arc_collision_layer(radius_m: float, shape: BoxShape3D, angle_span_rad: float,
		z_offset_m: float = 0.0) -> void:
	for local_transform in DumbbellMeshBuilder.arc_room_collision_transforms(radius_m, angle_span_rad, arc_segment_count):
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var t: Transform3D = local_transform
		t.origin += Vector3(0.0, 0.0, z_offset_m)
		cs.transform = t
		_collision_root.add_child(cs)

## Переопределяет StationModule.contains_point(): собственная локальная
## система координат (+Y радиально наружу, дуга свёрнута в плоскости XY —
## см. класс-комментарий и _build_arc_interior_lights() ниже, где phi=0 даёт
## позицию (0, r, 0)), а не +XZ, как у прежнего кольца — унаследованные
## angle_start_deg/angle_end_deg этим модулем не используются даже в
## собственной геометрии (_build_geometry() строит дугу вокруг локального
## нуля через angle_span_deg), поэтому и здесь сравниваем с ним же, а не с
## угловыми полями базового класса.
func contains_point(global_pos: Vector3) -> bool:
	var local: Vector3 = to_local(global_pos)
	var angle_deg: float = rad_to_deg(atan2(local.x, local.y))
	return absf(angle_deg) <= angle_span_deg * 0.5

## Внутреннее освещение отсека — несколько OmniLight3D вдоль дуги на середине
## радиальной глубины. Аналог StationModule._build_interior_lights() для этой
## (дуговой, но собственной, не унаследованной) геометрии — названа иначе по
## той же причине, что и _build_arc_collision().
func _build_arc_interior_lights(angle_span_rad: float) -> void:
	var mid_radius: float = (inner_radius_m + outer_radius_m) * 0.5
	for i in range(dumbbell_config.interior_light_count_per_module):
		var t: float = (i + 0.5) / float(dumbbell_config.interior_light_count_per_module)
		var phi: float = -angle_span_rad * 0.5 + angle_span_rad * t
		var light := OmniLight3D.new()
		light.position = Vector3(sin(phi), cos(phi), 0.0) * mid_radius
		light.light_color = dumbbell_config.interior_light_color
		light.omni_range = dumbbell_config.interior_light_range_m
		light.light_energy = dumbbell_config.interior_light_energy
		add_child(light)
