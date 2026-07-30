## Коридор гантелеобразной станции: чисто структурный элемент, БЕЗ коллизии —
## игрок телепортируется через люк на барабане, а не идёт по коридору пешком
## (документация 0.1.1, «без перемещения по ним, с затенением экрана»). Пока
## этот переход не реализован (задел под будущую ревизию ТЗ-100), коридор —
## только видимая труба.
##
## Меш и коннекторы (Connector_Inner/Connector_Outer) — СТАТИЧНЫЕ, запечены
## прямо в corridor.tscn — обычное сохранённое MeshInstance3D-поддерево, как у
## любой другой сцены (в т.ч. экспортируемое в .glb для правки в Blender).
## Раньше строилось в _ready() через DumbbellMeshBuilder из
## dumbbell_config.corridor_radius_m/corridor_length_m/segment_count при
## каждой загрузке сцены — при переходе на статику эти поля стали ни на что
## не влияющими для ЭТОГО модуля (сам dumbbell_config продолжает читаться
## другими модулями станции, не трогать). Чтобы изменить форму —
## перегенерировать геометрию через DumbbellMeshBuilder (см. git-историю этого
## файла до перехода на статику) и заново запечь в corridor.tscn.
@tool
class_name DumbbellCorridor
extends Node3D

@export var hull_material: Material

@onready var _hull: MeshInstance3D = $Hull

func _ready() -> void:
	if hull_material != null:
		_hull.material_override = hull_material
