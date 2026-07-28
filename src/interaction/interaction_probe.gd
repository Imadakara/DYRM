## Луч взаимодействия из центра экрана вдоль взгляда камеры (ТЗ-100, FR-30).
## Работает только с базовым классом Interactable — принцип 7.1.3, ни одной
## проверки конкретного наследника.
class_name InteractionProbe
extends Node3D

signal target_changed(target: Interactable)

@export var camera_path: NodePath
@export var config: InteractionConfig

var _camera: Camera3D
var _target: Interactable
var _target_point: Vector3
var _target_distance: float = -1.0

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D

func _physics_process(_delta: float) -> void:
	_update_target()

func _update_target() -> void:
	var new_target: Interactable = null
	var hit_point: Vector3 = Vector3.ZERO
	var hit_distance: float = -1.0

	if _camera != null:
		var origin: Vector3 = _camera.global_position
		var forward: Vector3 = -_camera.global_transform.basis.z
		var to: Vector3 = origin + forward * config.ray_length_m
		var space_state: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(origin, to)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty() and result.get("collider") is Interactable:
			new_target = result["collider"] as Interactable
			hit_point = result["position"]
			hit_distance = origin.distance_to(hit_point)

	if new_target != _target:
		_target = new_target
		target_changed.emit(_target)
	_target_point = hit_point
	_target_distance = hit_distance

	# FR-42: доставка точки наведения текущей цели — обобщённо, без проверки
	# типа (принцип 7.1.3); значимо реализовано только у WorkPanel.
	if _target != null:
		_target.receive_pointer(true, _target_point)

func get_target() -> Interactable:
	return _target

func get_target_point() -> Vector3:
	return _target_point

func get_target_distance() -> float:
	return _target_distance
