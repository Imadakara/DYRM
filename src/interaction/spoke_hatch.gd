## Люк в спицу: заперт, взаимодействие всегда отклоняется (ТЗ-100, FR-36, A-05).
## Остаётся целью для InteractionProbe (показывает подсказку об отказе), но
## interact() не меняет состояние и не испускает activated.
##
## @tool: створка получает меш/коллизию и в редакторе — станция открывается
## уже собранной, см. класс-комментарий StationModule.
@tool
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

## См. Door._physics_process() — тот же баг синхронизации: CoverBody вложен в
## SpokeHatch (Area3D-предок), собственный transform не меняется скриптом, и
## sync_to_physics без принудительного «касания» никогда не проталкивает
## вращение RotatingRing в PhysicsServer3D.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cover_body.global_transform = _cover_body.global_transform

func interact(_from: Node3D) -> void:
	pass
