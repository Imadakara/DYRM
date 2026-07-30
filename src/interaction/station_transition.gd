## Точка перехода между стволом и плечом гантелеобразной станции (ТЗ-000 §17.3
## — адаптация ТЗ-100 под новую топологию). По документации 0.1.1 переход
## выполняется "по кнопке действия с затенением экрана, БЕЗ физического
## перемещения по коридору" — у коридора плеча нет коллизии специально по
## этой причине (DumbbellStationConfig.corridor_radius_m). Ставится на
## маркерах Door_AntennaHub/Door_HubTransmission/AccessToHabitat/AccessToWork
## в station_dumbbell.tscn вместо голых Marker3D.
##
## Не строит видимую геометрию (это точка действия, не физический люк с
## воротами) — только зона обнаружения InteractionProbe, тот же контракт, что
## у Door/SpokeHatch (Area3D + CollisionShape3D).
class_name StationTransition
extends Interactable

@export var target_module_id: StringName = &""
@export var probe_radius_m: float = 0.8

@onready var _probe_collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	var shape := SphereShape3D.new()
	shape.radius = probe_radius_m
	_probe_collision.shape = shape

func interact(from: Node3D) -> void:
	if not can_interact(from):
		return
	if from is PlayerController:
		(from as PlayerController).begin_transition(target_module_id)
	activated.emit(from)
