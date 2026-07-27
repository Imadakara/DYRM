## Процедурная геометрия станции: труба-дуга кольца (прямоугольное сечение,
## аппроксимация прямыми хордами — R-04), ступица, спицы. Все размеры приходят
## параметром — класс не хранит состояния. FR-30, FR-35
class_name StationMeshBuilder
extends RefCounted

## Строит меш дуги кольца: пол (floor_radius_m), потолок (ceiling_radius_m),
## две боковые стены по оси вращения (+Y), длина хорды — angle_span/segment_count.
## Открыта по торцам (стыки с соседними дугами станции). FR-30, FR-32
static func build_ring_arc_mesh(angle_start_rad: float, angle_end_rad: float,
		floor_radius_m: float, ceiling_radius_m: float, half_width_m: float,
		segment_count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d_phi: float = (angle_end_rad - angle_start_rad) / float(segment_count)

	for i in range(segment_count):
		var phi0: float = angle_start_rad + d_phi * i
		var phi1: float = phi0 + d_phi
		var radial0 := Vector3(cos(phi0), 0.0, sin(phi0))
		var radial1 := Vector3(cos(phi1), 0.0, sin(phi1))
		var side_lo := Vector3(0.0, -half_width_m, 0.0)
		var side_hi := Vector3(0.0, half_width_m, 0.0)

		# Пол (r = floor_radius_m) — видимая сторона обращена к оси (внутрь трубы).
		_add_quad(st, radial0 * floor_radius_m + side_lo, radial0 * floor_radius_m + side_hi,
				radial1 * floor_radius_m + side_hi, radial1 * floor_radius_m + side_lo)
		# Потолок (r = ceiling_radius_m) — видимая сторона обращена наружу (вниз, к полу).
		_add_quad(st, radial0 * ceiling_radius_m + side_hi, radial0 * ceiling_radius_m + side_lo,
				radial1 * ceiling_radius_m + side_lo, radial1 * ceiling_radius_m + side_hi)
		# Боковая стена (y = -half_width_m).
		_add_quad(st, radial0 * ceiling_radius_m + side_lo, radial0 * floor_radius_m + side_lo,
				radial1 * floor_radius_m + side_lo, radial1 * ceiling_radius_m + side_lo)
		# Боковая стена (y = +half_width_m).
		_add_quad(st, radial0 * floor_radius_m + side_hi, radial0 * ceiling_radius_m + side_hi,
				radial1 * ceiling_radius_m + side_hi, radial1 * floor_radius_m + side_hi)

	st.generate_normals()
	st.index()
	return st.commit()

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

## Трансформы прямоугольных коллайдеров для каждой хорды дуги — локальный X
## коллайдера направлен по касательной (длина хорды), Y — вдоль оси вращения
## станции (ширина трубы), Z — по радиусу (высота отсека). Хорды равной угловой
## ширины дают одинаковую длину — один BoxShape3D можно переиспользовать
## для всех сегментов дуги. FR-33
static func ring_arc_collision_transforms(angle_start_rad: float, angle_end_rad: float,
		mid_radius_m: float, segment_count: int) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var d_phi: float = (angle_end_rad - angle_start_rad) / float(segment_count)
	for i in range(segment_count):
		var phi_mid: float = angle_start_rad + d_phi * (i + 0.5)
		var radial_dir := Vector3(cos(phi_mid), 0.0, sin(phi_mid))
		var tangent_dir := Vector3(-sin(phi_mid), 0.0, cos(phi_mid))
		transforms.append(Transform3D(Basis(tangent_dir, Vector3.UP, radial_dir), radial_dir * mid_radius_m))
	return transforms

## Длина одной хорды дуги радиуса radius_m, метры.
static func ring_arc_chord_length(angle_start_rad: float, angle_end_rad: float,
		radius_m: float, segment_count: int) -> float:
	var d_phi: float = (angle_end_rad - angle_start_rad) / float(segment_count)
	return 2.0 * radius_m * sin(d_phi * 0.5)

## Меш ступицы: цилиндр вдоль локальной оси +Y узла-владельца.
static func build_hub_mesh(radius_m: float, length_m: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_m
	mesh.bottom_radius = radius_m
	mesh.height = length_m
	mesh.radial_segments = 24
	return mesh

## Меш спицы: тонкий цилиндр вдоль локальной оси +Y узла-владельца; ориентацию
## вдоль направления от ступицы к кольцу задаёт transform узла. FR-35
static func build_spoke_mesh(diameter_m: float, length_m: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = diameter_m * 0.5
	mesh.bottom_radius = diameter_m * 0.5
	mesh.height = length_m
	mesh.radial_segments = 12
	return mesh
