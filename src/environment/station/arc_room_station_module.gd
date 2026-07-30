## Жилой/рабочий модуль гантелеобразной станции — дуговая "голова молота"
## (см. отчёт о ревизии конфигурации 0.1.1, второе уточнение): четверть-секция
## прямоугольного тора, радиусы [inner_radius_m, outer_radius_m], дуга
## angle_span_deg (60° по уточнению) вокруг оси вращения, гранёный профиль
## пола/потолка из arc_segment_count хорд (6-8 по уточнению — не гладкая
## кривая, как у труб (segment_count=16), а читаемый глазом ломаный профиль).
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
@export var inner_radius_m: float = 14.0
## Радиус пола — дальняя грань, здесь действует центробежная "гравитация".
@export var outer_radius_m: float = 24.0
## Половина ширины отсека вдоль главной оси станции ("приплюснутое" измерение).
@export var axial_half_width_m: float = 4.0
@export var angle_span_deg: float = 60.0
## Число гранёных сегментов дуги пола/потолка (6-8 по уточнению автора —
## нечётное обязательно: дуга симметрична вокруг локального 0° (см.
## _arc_room_dir()), и при ЧЁТНОМ числе сегментов граница ровно двух соседних
## сегментов приходится точно на 0° — а это именно та точка, куда падает игрок
## при вертикальном падении от точки спавна (она тоже на 0°). Стык двух
## тонких (0.3 м) коробок-коллайдеров ровно под точкой контакта даёт
## неоднозначную/некорректную нормаль столкновения (эмпирически: до ~60° от
## ожидаемой радиальной), из-за чего is_on_floor() никогда не срабатывает и
## игрок бесконечно проваливается/скользит вместо приземления. Нечётное число
## сегментов кладёт СЕРЕДИНУ центрального сегмента на 0°, а не его границу.
@export var arc_segment_count: int = 7

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

## Пол/потолок/2 боковые стены — тонкие слои-коллайдеры на хорду-сегмент
## (как и CylindricalStationModule/StationModule), плюс 2 торцевые стены,
## закрывающие угловые пределы дуги (комната самостоятельная, не часть
## непрерывного кольца). Названа не так, как одноимённый метод в StationModule
## (_build_collision) — сигнатуры разные, GDScript требует их совпадения при
## переопределении метода с тем же именем.
## Запас поверх геометрической длины хорды для каждого коллайдера-сегмента
## СТЕН (не пола/потолка — см. ниже) — соседние сегменты слегка ЗАХОДЯТ друг
## на друга по касательной, а не стыкуются встык. Не влияет на видимую
## геометрию (мешу строит build_arc_room_wall_mesh() отдельно, без этого
## запаса) — только на физику.
const ARC_COLLISION_OVERLAP_FACTOR: float = 1.2
## См. использование в _build_arc_collision() — толщина ТОЛЬКО пола/потолка,
## сильно больше общего wall_thickness_m.
const ARC_FLOOR_THICKNESS_M: float = 3.0

func _build_arc_collision(angle_span_rad: float) -> void:
	var mid_radius: float = (inner_radius_m + outer_radius_m) * 0.5
	var wt: float = dumbbell_config.wall_thickness_m
	var axial_width: float = axial_half_width_m * 2.0

	# Пол и потолок — ОДНА коробка на весь угловой диапазон комнаты
	# (arc_segment_count=1 в вызовах ниже — не значение поля этого модуля,
	# оно по-прежнему используется для видимой геометрии, гранёной на
	# arc_segment_count граней), а не по сегменту на грань, как раньше.
	# Гранёный пол/потолок из нескольких тонких (0.3 м) коробок-сегментов имел
	# внутренние стыки, о которые Jolt время от времени спотыкался: при подходе
	# под острым углом на границе двух соседних коробок репортилась
	# некорректная нормаль столкновения (эмпирически: до ~60-90° от ожидаемой
	# радиальной) — is_on_floor() не срабатывал, и накопленная гравитационная
	# скорость раз за разом "вкладывалась" в паразитное касательное скольжение
	# вместо гашения об пол, разгоняя игрока через всю комнату (см. отчёт по
	# адаптации ТЗ-100 под гантелеобразную станцию, ТЗ-000 §17.3). Небольшой
	# запас по ширине соседних сегментов (ARC_COLLISION_OVERLAP_FACTOR) не
	# устранял проблему полностью — а несколько сегментов означают несколько
	# стыков в принципе. Одна плоская коробка на весь пол физически НЕ
	# идеально повторяет кривизну видимой (гранёной) геометрии — по центру
	# дуги (0°, там же точка спавна) совпадает точно, у угловых пределов
	# (±angle_span_rad/2) даёт зазор до R·(1-cos(angle_span_rad/2)) — у текущих
	# констант (24 м, 60°) это ~3,2 м, там, где пол визуально изгибается
	# сильнее всего, к тому же на границе с торцевой стеной. Компромисс,
	# выбранный сознательно ради того, чтобы пол вообще держал персонажа: без
	# внутренних стыков у одной коробки нет и точек, о которые Jolt может
	# споткнуться, — а именно это ломало ходьбу совсем, не просто неточно.
	#
	# Толщина пола/потолка — ARC_FLOOR_THICKNESS_M, а не тонкий общий
	# wall_thickness_m: игрок стоит ИМЕННО на этой границе, и
	# player_controller.gd каждый кадр силой возвращает его радиус ровно на
	# outer_radius_m (радиальная привязка) — при тонкой (0.3 м) плите
	# наблюдалось, что после нескольких таких мелких коррекций Jolt в какой-то
	# момент "теряет" контакт совсем: игрок проваливается сквозь плиту за один
	# кадр, is_on_floor() навсегда остаётся false, и накопленная
	# гравитационная скорость без всякого сопротивления разгоняет его в
	# открытое пространство за пределами станции (обнаружено эмпирически при
	# адаптации ТЗ-100 под гантелеобразную станцию, ТЗ-000 §17.3). Толстая
	# подложка даёт мелкой численной погрешности куда деться, не пробивая
	# коллизию насквозь; видимый пол (build_arc_room_wall_mesh) не меняется —
	# толщина уходит НАРУЖУ от него, в сторону корпуса станции.
	var full_chord_len: float = DumbbellMeshBuilder.arc_room_chord_length(outer_radius_m, angle_span_rad, 1)
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(full_chord_len, ARC_FLOOR_THICKNESS_M, axial_width)
	_add_arc_collision_layer(outer_radius_m + ARC_FLOOR_THICKNESS_M * 0.5, floor_shape, angle_span_rad, 0.0, 1)

	var ceiling_chord_len: float = DumbbellMeshBuilder.arc_room_chord_length(inner_radius_m, angle_span_rad, 1)
	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(ceiling_chord_len, ARC_FLOOR_THICKNESS_M, axial_width)
	_add_arc_collision_layer(inner_radius_m - ARC_FLOOR_THICKNESS_M * 0.5, ceiling_shape, angle_span_rad, 0.0, 1)

	# Боковые стены — по-прежнему гранёные (по arc_segment_count), с запасом
	# по ширине: игрок об них не "стоит" (is_on_floor() тут ни при чём),
	# поэтому тот же класс стыковой проблемы здесь не приводит к каскадному
	# срыву — а MAX_VELOCITY_SPEED_MULTIPLIER в player_controller.gd уже
	# страхует от одиночных всплесков скорости при боковом касании.
	var wall_chord_len: float = DumbbellMeshBuilder.arc_room_chord_length(mid_radius, angle_span_rad, arc_segment_count) \
			* ARC_COLLISION_OVERLAP_FACTOR
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(wall_chord_len, outer_radius_m - inner_radius_m, wt)
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

## segment_count_override — по умолчанию arc_segment_count (гранёные боковые
## стены), но пол/потолок вызывают с 1 (одна коробка на весь угловой
## диапазон, без внутренних стыков — см. класс-комментарий _build_arc_collision()).
func _add_arc_collision_layer(radius_m: float, shape: BoxShape3D, angle_span_rad: float,
		z_offset_m: float = 0.0, segment_count_override: int = -1) -> void:
	var count: int = segment_count_override if segment_count_override > 0 else arc_segment_count
	for local_transform in DumbbellMeshBuilder.arc_room_collision_transforms(radius_m, angle_span_rad, count):
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
