## Жилой/рабочий модуль гантелеобразной станции — дуговая "голова молота"
## (см. отчёт о ревизии конфигурации 0.1.1, второе уточнение): четверть-секция
## прямоугольного тора, пол — дальняя грань, потолок — ближняя, где ровно по
## центру дуги (симметрично) расположен Connector_Corridor — точка стыковки с
## коридором (station_connector.gd/station_docking.gd).
##
## Меш (Hull + EndCap_Start/EndCap_End)/коллизия/Connector_Corridor —
## СТАТИЧНЫЕ, запечены прямо в habitat_module.tscn/work_module.tscn — обычное
## сохранённое MeshInstance3D/CollisionShape3D-поддерево, как у любой другой
## сцены (в т.ч. экспортируемое в .glb для правки в Blender). Раньше строилось
## в _build_geometry() через DumbbellMeshBuilder каждый _ready() из полей
## inner_radius_m/outer_radius_m/axial_half_width_m/angle_span_deg/
## arc_segment_count — при переходе на статику эти поля стали ни на что не
## влияющими мертвыми параметрами и были удалены целиком (в т.ч. из
## dumbbell_config.arc_room_inner/outer_radius_m — там они тоже больше не
## синхронизируются ни с чем и полностью декоративны); реальные текущие
## значения (пол/потолок/дуга) теперь видны только в самой запечённой
## геометрии, не в коде. Радиус пола на момент заморозки — 60 м (совпадает со
## старым доказанно рабочим кольцом станции, StationConfig.ring_radius_m, и с
## угловой скоростью плеча в station_dumbbell_rotator.tres — трогать НЕЛЬЗЯ
## без синхронной перенастройки физики ходьбы, см. её собственную историю в
## player_controller.gd). Чтобы изменить форму — перегенерировать геометрию
## через DumbbellMeshBuilder (см. git-историю этого файла до перехода на
## статику) и заново запечь в соответствующий .tscn.
##
## _build_geometry() остаётся переопределённым только ради того, что НЕ
## является геометрией меша: точка спавна (зависит от outer_radius_m — тоже
## оставленного как единственный ещё «живой» параметр, раз без него нельзя
## держать спавн на полу) и внутреннее освещение (по-прежнему процедурно —
## дешевле держать вычисляемым по dumbbell_config, чем перезапекать при каждой
## правке количества/цвета светильников).
##
## Наследует StationModule (module_id/spawn_point/регистрация в
## StationRoot.get_modules()), переопределяет только _build_geometry() — как
## и CylindricalStationModule. Заменяет отклонённую (плоские грани, без
## кривизны пола/потолка) rounded_box_station_module.gd.
@tool
class_name ArcRoomStationModule
extends StationModule

@export var dumbbell_config: DumbbellStationConfig
## Радиус пола — дальняя грань, здесь действует центробежная "гравитация".
## Единственный из прежних размерных полей, оставленный "живым" — он же
## определяет позицию точки спавна (outer_radius_m - 1.0), а не только
## запечённую геометрию. См. класс-комментарий про 60 м/физику ходьбы.
@export var outer_radius_m: float = 60.0
## Угловая протяжённость дуги — используется в contains_point() (какая точка
## принадлежит этому модулю, для отслеживания текущего модуля игрока) и для
## расстановки внутреннего освещения вдоль дуги. Не влияет на запечённый
## меш/коллизию — те уже зафиксированы отдельно, менять это число без
## перезапекания геометрии осмысленно только для сужения зоны "текущий
## модуль" и/или перестановки светильников, а не формы комнаты.
@export var angle_span_deg: float = 30.0
## Радиус, на котором расставляется внутреннее освещение — раньше вычислялся
## как середина inner/outer_radius_m, оба поля удалены вместе с процедурной
## геометрией (см. класс-комментарий); теперь самостоятельный параметр.
## 57.5 м — середина запечённой глубины комнаты на момент заморозки (пол 60 м,
## потолок 55 м).
@export var interior_light_radius_m: float = 57.5

func _build_geometry() -> void:
	_clear_generated_lights()

	if hull_material != null:
		_hull.material_override = hull_material
		for cap_name in ["EndCap_Start", "EndCap_End"]:
			var cap := get_node_or_null(cap_name) as MeshInstance3D
			if cap != null:
				cap.material_override = hull_material

	# Точка спавна — 1 м над полом, в центре дуги (та же симметрия, что и у
	# коннектора коридора на потолке).
	spawn_point.position = Vector3(0.0, outer_radius_m - 1.0, 0.0)

	_build_arc_interior_lights(deg_to_rad(angle_span_deg))

## Переопределяет StationModule.contains_point(): собственная локальная
## система координат (+Y радиально наружу, дуга свёрнута в плоскости XY —
## см. класс-комментарий и _build_arc_interior_lights() ниже, где phi=0 даёт
## позицию (0, r, 0)), а не +XZ, как у прежнего кольца — унаследованные
## angle_start_deg/angle_end_deg этим модулем не используются даже в
## собственной геометрии, поэтому и здесь сравниваем с angle_span_deg, а не с
## угловыми полями базового класса.
func contains_point(global_pos: Vector3) -> bool:
	var local: Vector3 = to_local(global_pos)
	var angle_deg: float = rad_to_deg(atan2(local.x, local.y))
	return absf(angle_deg) <= angle_span_deg * 0.5

## Внутреннее освещение отсека — несколько OmniLight3D вдоль дуги на середине
## радиальной глубины комнаты (interior_light_radius_m). Аналог
## StationModule._build_interior_lights() для этой (дуговой, но собственной,
## не унаследованной) геометрии.
func _build_arc_interior_lights(angle_span_rad: float) -> void:
	for i in range(dumbbell_config.interior_light_count_per_module):
		var t: float = (i + 0.5) / float(dumbbell_config.interior_light_count_per_module)
		var phi: float = -angle_span_rad * 0.5 + angle_span_rad * t
		var light := OmniLight3D.new()
		light.position = Vector3(sin(phi), cos(phi), 0.0) * interior_light_radius_m
		light.light_color = dumbbell_config.interior_light_color
		light.omni_range = dumbbell_config.interior_light_range_m
		light.light_energy = dumbbell_config.interior_light_energy
		add_child(light)
