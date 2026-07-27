## Геометрия лазерной установки: гимбал Yaw (вокруг локальной +Y) → Pitch
## (вокруг локальной +X дочернего узла Yaw), сектор обзора. БЕЗ логики
## наведения — та реализуется в ТЗ-027/028. FR-36, FR-37
class_name LaserMountStub
extends Node3D

@export var mount_id: StringName = &""
## Половина сектора обзора по азимуту вокруг Yaw, градусы.
@export var azimuth_half_range_deg: float = 120.0
## Половина сектора обзора по возвышению вокруг Pitch, градусы.
@export var elevation_half_range_deg: float = 90.0

@onready var yaw: Node3D = $Yaw
@onready var pitch: Node3D = $Yaw/Pitch
