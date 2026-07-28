## Процедурная геометрия станции-гантели: модуль (закрытая коробка с проёмом
## на стороне рукояти), рукоять/лок-камера (открытая с торцов прямая труба),
## ступица (цилиндр). Все размеры приходят параметром — класс не хранит
## состояния.
class_name StationMeshBuilder
extends RefCounted

## Меш комнаты модуля: пол (Y=0), потолок (Y=height_m), дальняя стена (-Z) и
## две боковые (+-X). Сторона +Z открыта — там дверной проём в рукоять.
static func build_room_mesh(width_m: float, depth_m: float, height_m: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = width_m * 0.5

	# Пол — видимая сторона вверх (+Y).
	_add_quad(st, Vector3(-hw, 0.0, -depth_m), Vector3(hw, 0.0, -depth_m),
			Vector3(hw, 0.0, 0.0), Vector3(-hw, 0.0, 0.0))
	# Потолок — видимая сторона вниз (-Y).
	_add_quad(st, Vector3(-hw, height_m, 0.0), Vector3(hw, height_m, 0.0),
			Vector3(hw, height_m, -depth_m), Vector3(-hw, height_m, -depth_m))
	# Дальняя стена (Z = -depth_m) — видимая сторона к проёму (+Z).
	_add_quad(st, Vector3(-hw, 0.0, -depth_m), Vector3(-hw, height_m, -depth_m),
			Vector3(hw, height_m, -depth_m), Vector3(hw, 0.0, -depth_m))
	# Левая стена (X = -hw) — видимая сторона внутрь (+X).
	_add_quad(st, Vector3(-hw, 0.0, 0.0), Vector3(-hw, height_m, 0.0),
			Vector3(-hw, height_m, -depth_m), Vector3(-hw, 0.0, -depth_m))
	# Правая стена (X = +hw) — видимая сторона внутрь (-X).
	_add_quad(st, Vector3(hw, 0.0, -depth_m), Vector3(hw, height_m, -depth_m),
			Vector3(hw, height_m, 0.0), Vector3(hw, 0.0, 0.0))

	st.generate_normals()
	st.index()
	return st.commit()

## Меш прямой трубы (рукоять/лок-камера): пол, потолок, две боковые стены;
## открыта с обоих торцов (Z=0 и Z=length_m) — стыки с соседними узлами.
static func build_tube_mesh(length_m: float, width_m: float, height_m: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = width_m * 0.5

	_add_quad(st, Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0),
			Vector3(hw, 0.0, length_m), Vector3(-hw, 0.0, length_m))
	_add_quad(st, Vector3(-hw, height_m, length_m), Vector3(hw, height_m, length_m),
			Vector3(hw, height_m, 0.0), Vector3(-hw, height_m, 0.0))
	_add_quad(st, Vector3(-hw, 0.0, 0.0), Vector3(-hw, height_m, 0.0),
			Vector3(-hw, height_m, length_m), Vector3(-hw, 0.0, length_m))
	_add_quad(st, Vector3(hw, 0.0, length_m), Vector3(hw, height_m, length_m),
			Vector3(hw, height_m, 0.0), Vector3(hw, 0.0, 0.0))

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

## Меш ступицы: цилиндр вдоль локальной оси +Y узла-владельца.
static func build_hub_mesh(radius_m: float, length_m: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_m
	mesh.bottom_radius = radius_m
	mesh.height = length_m
	mesh.radial_segments = 24
	return mesh
