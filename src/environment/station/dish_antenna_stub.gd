## Геометрия приёмной антенны: гимбал Yaw (вокруг локальной +Y) → Pitch (вокруг
## локальной +X дочернего узла Yaw). БЕЗ логики приёма — та реализуется в ТЗ-034.
## FR-36
class_name DishAntennaStub
extends Node3D

@export var antenna_id: StringName = &""
## Половина сектора обзора по возвышению вокруг Pitch, градусы.
@export var elevation_half_range_deg: float = 80.0

@onready var yaw: Node3D = $Yaw
@onready var pitch: Node3D = $Yaw/Pitch
