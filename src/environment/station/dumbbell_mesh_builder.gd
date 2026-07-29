## Процедурная геометрия прямых цилиндрических модулей гантелеобразной станции
## (см. dumbbell_station_config.gd): полая труба, выдавленная вдоль локальной
## оси +Y, плюс плоская дисковая крышка на торце. В отличие от
## StationMeshBuilder (дуга тора), труба прямая — не требует разбиения по
## длине для сглаживания кривизны, только по окружности сечения.
class_name DumbbellMeshBuilder
extends RefCounted

## Стена трубы: полый цилиндр радиуса radius_m и длины length_m, открыт с
## обоих торцов. Видимая сторона — внутренняя (см. cull_disabled в материале
## интерьера, как и в StationMeshBuilder — не полагаемся на точность winding).
static func build_tube_wall_mesh(radius_m: float, length_m: float, segment_count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d_phi: float = TAU / float(segment_count)
	for i in range(segment_count):
		var phi0: float = d_phi * i
		var phi1: float = phi0 + d_phi
		var a0 := Vector3(cos(phi0) * radius_m, 0.0, sin(phi0) * radius_m)
		var a1 := Vector3(cos(phi1) * radius_m, 0.0, sin(phi1) * radius_m)
		var b0: Vector3 = a0 + Vector3(0.0, length_m, 0.0)
		var b1: Vector3 = a1 + Vector3(0.0, length_m, 0.0)
		_add_quad(st, a0, b0, b1, a1)
	st.generate_normals()
	st.index()
	return st.commit()

## Плоская дисковая крышка радиуса radius_m в плоскости XZ, на локальной
## высоте y=0 — вызывающий код сам переносит её на нужный торец (y=0 или
## y=length_m) через transform/position узла.
static func build_end_cap_mesh(radius_m: float, segment_count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	var d_phi: float = TAU / float(segment_count)
	for i in range(segment_count):
		var phi0: float = d_phi * i
		var phi1: float = phi0 + d_phi
		var p0 := Vector3(cos(phi0) * radius_m, 0.0, sin(phi0) * radius_m)
		var p1 := Vector3(cos(phi1) * radius_m, 0.0, sin(phi1) * radius_m)
		st.add_vertex(center)
		st.add_vertex(p0)
		st.add_vertex(p1)
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

## Коллайдеры стены: segment_count коробок по окружности сечения, каждая —
## на всю длину трубы (труба прямая, разбиение по длине не нужно — в отличие
## от дуги тора в StationMeshBuilder, кривизны вдоль оси здесь нет).
## Базис строится в коде (Basis(x,y,z) — конструктор берёт столбцы корректно;
## транспонирование нужно только при ручной записи Transform3D в текст .tscn,
## см. базу знаний Godot, пункт 1).
static func tube_wall_collision_transforms(radius_m: float, length_m: float, segment_count: int) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var d_phi: float = TAU / float(segment_count)
	for i in range(segment_count):
		var phi_mid: float = d_phi * (i + 0.5)
		var radial_dir := Vector3(cos(phi_mid), 0.0, sin(phi_mid))
		var tangent_dir := Vector3(-sin(phi_mid), 0.0, cos(phi_mid))
		var basis := Basis(tangent_dir, Vector3.UP, radial_dir)
		var origin: Vector3 = radial_dir * radius_m + Vector3(0.0, length_m * 0.5, 0.0)
		transforms.append(Transform3D(basis, origin))
	return transforms

## Длина хорды одного сегмента стены при данном радиусе и числе сегментов.
static func wall_chord_length(radius_m: float, segment_count: int) -> float:
	return 2.0 * radius_m * sin(PI / float(segment_count))

# ─── Дуговая комната (жилой/рабочий модуль) ────────────────────────────────
# "Голова молота": четверть-секция прямоугольного тора (см. отчёт о ревизии
# конфигурации 0.1.1, второе уточнение) — сечение прямоугольное (пол/потолок/
# 2 стены вдоль оси станции), но пол и потолок ИЗОГНУТЫ по окружности
# вращения (радиусы inner/outer), а не плоские, как в первой (отклонённой)
# попытке. Кривизна приближена гранёным профилем из небольшого числа хорд
# (segment_count = 6-8 по ТЗ пользователя, не 16, как у труб) — рёбра должны
# читаться на глаз, а не давать гладкую дугу.
#
# Локальная система координат элемента: +Y — радиально наружу от оси
# вращения (0° дуги — центр диапазона, лежит точно на +Y, чтобы коннектор
# коридора в центре "потолка" не требовал доп. поворота — симметрия по ТЗ),
# +Z — вдоль главной оси станции (половина ширины отсека — "приплюснутое"
# измерение), +X — по касательной. Та же роль осей, что и у DumbbellArmLayout/
# StationDocking для стыковки барабан-коридор-комната.

## Радиальное направление в локальной плоскости XY на угле phi от центра
## дуги (phi=0 → точно +Y).
static func _arc_room_dir(phi: float) -> Vector3:
	return Vector3(sin(phi), cos(phi), 0.0)

## Стена дуговой комнаты: пол (r=outer_radius_m) + потолок (r=inner_radius_m)
## + 2 плоские боковые стены (z=±half_axial_width_m), гранёные по дуге
## angle_span_rad вокруг локального +Y. Углы обоих торцов (см.
## build_arc_room_end_cap_mesh) в этой функции не строятся — комната
## самостоятельная (не часть непрерывного кольца, в отличие от
## StationMeshBuilder.build_ring_arc_mesh), торцы нужно закрывать отдельно.
static func build_arc_room_wall_mesh(inner_radius_m: float, outer_radius_m: float,
		half_axial_width_m: float, angle_span_rad: float, segment_count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var angle_start: float = -angle_span_rad * 0.5
	var d_phi: float = angle_span_rad / float(segment_count)
	var side_lo := Vector3(0.0, 0.0, -half_axial_width_m)
	var side_hi := Vector3(0.0, 0.0, half_axial_width_m)
	for i in range(segment_count):
		var dir0: Vector3 = _arc_room_dir(angle_start + d_phi * i)
		var dir1: Vector3 = _arc_room_dir(angle_start + d_phi * (i + 1))

		# Пол — видимая сторона обращена к оси (внутрь, вверх по +Y).
		_add_quad(st, dir0 * outer_radius_m + side_lo, dir0 * outer_radius_m + side_hi,
				dir1 * outer_radius_m + side_hi, dir1 * outer_radius_m + side_lo)
		# Потолок — видимая сторона обращена наружу (к полу, вниз по -Y).
		_add_quad(st, dir0 * inner_radius_m + side_hi, dir0 * inner_radius_m + side_lo,
				dir1 * inner_radius_m + side_lo, dir1 * inner_radius_m + side_hi)
		# Боковые стены вдоль оси станции.
		_add_quad(st, dir0 * inner_radius_m + side_lo, dir0 * outer_radius_m + side_lo,
				dir1 * outer_radius_m + side_lo, dir1 * inner_radius_m + side_lo)
		_add_quad(st, dir0 * outer_radius_m + side_hi, dir0 * inner_radius_m + side_hi,
				dir1 * inner_radius_m + side_hi, dir1 * outer_radius_m + side_hi)
	st.generate_normals()
	st.index()
	return st.commit()

## Торцевая стена дуговой комнаты на одном из угловых пределов
## (angle_rad = ±angle_span_rad/2) — замыкает комнату сбоку (StationMeshBuilder
## оставляет такие торцы открытыми для соседней дуги кольца; здесь соседей
## нет, комната самостоятельная).
static func build_arc_room_end_cap_mesh(inner_radius_m: float, outer_radius_m: float,
		half_axial_width_m: float, angle_rad: float) -> ArrayMesh:
	var dir: Vector3 = _arc_room_dir(angle_rad)
	var side_lo := Vector3(0.0, 0.0, -half_axial_width_m)
	var side_hi := Vector3(0.0, 0.0, half_axial_width_m)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, dir * inner_radius_m + side_lo, dir * inner_radius_m + side_hi,
			dir * outer_radius_m + side_hi, dir * outer_radius_m + side_lo)
	st.generate_normals()
	st.index()
	return st.commit()

## Коллайдеры пола/потолка/2 стен: по одной коробке на хорду-сегмент (как и
## у CylindricalStationModule/StationModule — тонкие слои по всем 4
## поверхностям, не сплошной монолит). Базис строится в коде, конструктором
## Basis(x,y,z) — безопасно (см. базу знаний Godot, пункт 1).
static func arc_room_collision_transforms(radius_m: float, angle_span_rad: float,
		segment_count: int) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var angle_start: float = -angle_span_rad * 0.5
	var d_phi: float = angle_span_rad / float(segment_count)
	for i in range(segment_count):
		var phi_mid: float = angle_start + d_phi * (i + 0.5)
		var radial_dir: Vector3 = _arc_room_dir(phi_mid)
		var tangent_dir := Vector3(cos(phi_mid), -sin(phi_mid), 0.0)
		var basis := Basis(tangent_dir, radial_dir, Vector3(0.0, 0.0, 1.0))
		transforms.append(Transform3D(basis, radial_dir * radius_m))
	return transforms

## Длина хорды одного сегмента дуговой комнаты при данном радиусе.
static func arc_room_chord_length(radius_m: float, angle_span_rad: float, segment_count: int) -> float:
	return 2.0 * radius_m * sin(angle_span_rad / float(segment_count) * 0.5)

## Коллайдер торцевой стены дуговой комнаты, закрывающий один из угловых
## пределов (angle_rad = ±angle_span_rad/2) — сама комната самостоятельная
## (не часть кольца), поэтому, в отличие от арок StationMeshBuilder, торцы
## должны быть закрыты, а не оставлены проёмом в соседнюю дугу.
static func arc_room_end_collision_transform(inner_radius_m: float, outer_radius_m: float, angle_rad: float) -> Transform3D:
	var radial_dir: Vector3 = _arc_room_dir(angle_rad)
	var tangent_dir := Vector3(cos(angle_rad), -sin(angle_rad), 0.0)
	var mid_radius: float = (inner_radius_m + outer_radius_m) * 0.5
	var basis := Basis(tangent_dir, radial_dir, Vector3(0.0, 0.0, 1.0))
	return Transform3D(basis, radial_dir * mid_radius)
