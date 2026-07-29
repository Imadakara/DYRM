## Коридор гантелеобразной станции: чисто структурный элемент, БЕЗ коллизии —
## игрок телепортируется через люк на барабане, а не идёт по коридору пешком
## (документация 0.1.1, «без перемещения по ним, с затенением экрана»). Пока
## этот переход не реализован (задел под будущую ревизию ТЗ-100), коридор —
## только видимая труба.
##
## Собственная сцена модульной станции (station_connector.gd/
## station_docking.gd): выставляет 2 коннектора на торцах — Connector_Inner
## (y=0, к барабану) и Connector_Outer (y=corridor_length_m, к жилому/рабочему
## модулю) — станция стыкует коридор к соседям по ним, а не жёстким
## Transform3D в station_dumbbell.tscn.
@tool
class_name DumbbellCorridor
extends Node3D

@export var dumbbell_config: DumbbellStationConfig
@export var hull_material: Material

@onready var _hull: MeshInstance3D = $Hull

func _ready() -> void:
	_hull.mesh = DumbbellMeshBuilder.build_tube_wall_mesh(
			dumbbell_config.corridor_radius_m, dumbbell_config.corridor_length_m,
			dumbbell_config.segment_count)
	if hull_material != null:
		_hull.material_override = hull_material

	StationConnector.ensure(self, "Connector_Inner", Transform3D(StationConnector.flipped_basis(), Vector3.ZERO))
	StationConnector.ensure(self, "Connector_Outer", Transform3D(Basis.IDENTITY,
			Vector3(0.0, dumbbell_config.corridor_length_m, 0.0)))
