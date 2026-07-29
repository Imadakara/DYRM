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
## Число гранёных сегментов дуги пола/потолка.
@export var arc_segment_count: int = 6

func _build_geometry() -> void:
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
func _build_arc_collision(angle_span_rad: float) -> void:
	var mid_radius: float = (inner_radius_m + outer_radius_m) * 0.5
	var chord_len: float = DumbbellMeshBuilder.arc_room_chord_length(mid_radius, angle_span_rad, arc_segment_count)
	var wt: float = dumbbell_config.wall_thickness_m
	var axial_width: float = axial_half_width_m * 2.0

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

func _add_arc_collision_layer(radius_m: float, shape: BoxShape3D, angle_span_rad: float, z_offset_m: float = 0.0) -> void:
	for local_transform in DumbbellMeshBuilder.arc_room_collision_transforms(radius_m, angle_span_rad, arc_segment_count):
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var t: Transform3D = local_transform
		t.origin += Vector3(0.0, 0.0, z_offset_m)
		cs.transform = t
		_collision_root.add_child(cs)

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
