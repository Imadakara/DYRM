## Точка крепления будущего модуля Блока 3 на торце неподвижной ступицы (ГДД
## 000 ревизия 2026-07-28, Core Rule 4/Edge Cases) — заперта, взаимодействие
## всегда отклоняется. Остаётся целью для InteractionProbe (показывает
## подсказку об отказе), но interact() не меняет состояние и не испускает
## activated. Класс сохранил имя SpokeHatch (наследие торовой геометрии, где
## аналогичную роль играли люки в спицы) — поведенческий контракт идентичен,
## переименование не требовалось.
class_name SpokeHatch
extends Interactable

@export var hatch_width_m: float = 1.0
@export var hatch_height_m: float = 1.6
@export var hatch_thickness_m: float = 0.1

@onready var _cover: MeshInstance3D = $Cover
## AnimatableBody3D, не StaticBody3D — узел вращается вместе с RotatingRing
## (см. Door._leaf_body и station_module.gd).
@onready var _cover_body: AnimatableBody3D = $CoverBody
@onready var _cover_collision: CollisionShape3D = $CoverBody/CoverCollision
@onready var _probe_collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	var size := Vector3(hatch_width_m, hatch_height_m, hatch_thickness_m)
	var box := BoxMesh.new()
	box.size = size
	_cover.mesh = box
	_cover.position = Vector3(0.0, hatch_height_m * 0.5, 0.0)
	_cover_body.position = _cover.position

	var cover_shape := BoxShape3D.new()
	cover_shape.size = size
	_cover_collision.shape = cover_shape

	var probe_shape := BoxShape3D.new()
	probe_shape.size = size
	_probe_collision.shape = probe_shape
	_probe_collision.position = _cover.position

func interact(_from: Node3D) -> void:
	pass
