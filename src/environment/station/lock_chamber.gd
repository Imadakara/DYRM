## Стыковочная лок-камера рукоять↔ступица (ГДД 000, Core Rule 5). Физически
## меняет собственную угловую скорость от ω вращающейся сборки до 0 и обратно
## — реалистичный переход через границу вращения вместо мгновенной
## телепортации. Формула [lock-chamber-spin-sync].
##
## В отличие от ArmCorridor/StationModule (transform вычисляется один раз в
## _ready() из фиксированного угла), этот узел пересчитывает свой transform
## КАЖДЫЙ физкадр из текущего угла (который зависит от состояния цикла) —
## сам узел не является потомком ни RotatingAssembly, ни DespunHub, а
## копирует/смешивает их поведение сценарно.
class_name LockChamber
extends Node3D

enum State { IDLE_ARM, CYCLING, IDLE_HUB }

## Идентификатор модуля, к которому ведёт эта лок-камера через свою рукоять
## (для PlayerController.current_module() при выходе в сторону рукояти).
@export var module_id: StringName = &""
@export var hub_attach_angle_deg: float = 0.0
@export var config: StationConfig
@export var ring_rotator_path: NodePath
@export var hull_material: Material

const WALL_THICKNESS_M: float = 0.3

@onready var _ring_rotator: RingRotator = get_node_or_null(ring_rotator_path)
@onready var _hull: MeshInstance3D = $Hull
@onready var _collision_root: AnimatableBody3D = $Collision
@onready var _arm_side_door: Door = $ArmSideDoor
@onready var _hub_side_door: Door = $HubSideDoor
@onready var _detector: Area3D = $Detector

var _state: State = State.IDLE_ARM
var _current_angle_rad: float = 0.0
var _cycle_elapsed_s: float = 0.0
var _cycle_direction: int = 1
var _cycle_omega0: float = 0.0
## Тело внутри камеры, ожидающее завершения цикла (см. player_controller.gd).
## Типизировано как CharacterBody3D, не PlayerController: последнее создало
## бы циклическую зависимость class_name между двумя скриптами (Godot не
## резолвит такой цикл — "Could not resolve external class member"), а
## enter_lock_chamber()/exit_lock_chamber() вызываются через has_method()/
## call() (утиная типизация) вместо статической проверки типа.
var _occupant: CharacterBody3D

func _ready() -> void:
	_current_angle_rad = deg_to_rad(hub_attach_angle_deg)
	_build_geometry()
	_apply_transform()
	_update_door_locks()
	_detector.body_entered.connect(_on_body_entered)
	_detector.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE_ARM:
			_current_angle_rad = _ring_rotator.rotation_angle_rad() + deg_to_rad(hub_attach_angle_deg)
			_apply_transform()
		State.CYCLING:
			_advance_cycle(delta)
			_apply_transform()
		State.IDLE_HUB:
			pass

func _build_geometry() -> void:
	_hull.mesh = StationMeshBuilder.build_tube_mesh(config.lock_chamber_length_m,
			config.arm_cross_section_m, config.arm_cross_section_m)
	if hull_material != null:
		_hull.material_override = hull_material

	var w: float = config.arm_cross_section_m
	var h: float = config.arm_cross_section_m
	var l: float = config.lock_chamber_length_m
	var mid_z: float = l * 0.5

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(w, WALL_THICKNESS_M, l)
	_add_box(floor_shape, Vector3(0.0, -WALL_THICKNESS_M * 0.5, mid_z))

	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(w, WALL_THICKNESS_M, l)
	_add_box(ceiling_shape, Vector3(0.0, h + WALL_THICKNESS_M * 0.5, mid_z))

	var side_wall_shape := BoxShape3D.new()
	side_wall_shape.size = Vector3(WALL_THICKNESS_M, h, l)
	_add_box(side_wall_shape, Vector3(-w * 0.5 - WALL_THICKNESS_M * 0.5, h * 0.5, mid_z))
	_add_box(side_wall_shape, Vector3(w * 0.5 + WALL_THICKNESS_M * 0.5, h * 0.5, mid_z))

	var detector_shape := BoxShape3D.new()
	detector_shape.size = Vector3(w, h, l)
	var detector_collision := CollisionShape3D.new()
	detector_collision.shape = detector_shape
	detector_collision.position = Vector3(0.0, h * 0.5, mid_z)
	_detector.add_child(detector_collision)

func _add_box(shape: BoxShape3D, local_pos: Vector3) -> void:
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.position = local_pos
	_collision_root.add_child(collision_shape)

## Пересобирает transform всего узла из текущего угла — форвард (ось трубы,
## local +Z) направлен строго радиально наружу (см. заголовок файла: короткая
## камера, 3 м, — приемлемое упрощение по сравнению с длинной рукоятью,
## которая специально смещена по углу ради проходимого уклона).
func _apply_transform() -> void:
	var forward: Vector3 = StationModule.radial_dir(rad_to_deg(_current_angle_rad))
	var basis: Basis = StationModule.orthonormal_tube_basis(forward, Vector3.UP, rad_to_deg(_current_angle_rad))
	transform = Transform3D(basis, forward * config.hub_radius_m)

## Текущая угловая скорость камеры, рад/с — формула [lock-chamber-spin-sync].
func get_omega() -> float:
	match _state:
		State.IDLE_ARM:
			return _ring_rotator.angular_velocity_rad_s
		State.IDLE_HUB:
			return 0.0
		State.CYCLING:
			var t: float = _cycle_elapsed_s
			var duration: float = config.lock_chamber_duration_s
			if _cycle_direction == 1:
				return (_cycle_omega0 * 0.5) * (1.0 + cos(PI * t / duration))
			return (_cycle_omega0 * 0.5) * (1.0 - cos(PI * t / duration))
	return 0.0

func is_synced_with_target() -> bool:
	return _state != State.CYCLING

func current_state() -> State:
	return _state

func begin_cycle(direction: int) -> void:
	if _state == State.CYCLING:
		return
	_cycle_direction = direction
	_cycle_elapsed_s = 0.0
	_cycle_omega0 = _ring_rotator.angular_velocity_rad_s
	_state = State.CYCLING
	_update_door_locks()

func _advance_cycle(delta: float) -> void:
	_cycle_elapsed_s += delta
	_current_angle_rad += get_omega() * delta
	if _cycle_elapsed_s >= config.lock_chamber_duration_s:
		_state = State.IDLE_HUB if _cycle_direction == 1 else State.IDLE_ARM
		_update_door_locks()

func _update_door_locks() -> void:
	var locked: bool = _state == State.CYCLING
	_arm_side_door.forced_locked = locked
	_hub_side_door.forced_locked = locked

func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D and body.has_method(&"enter_lock_chamber")):
		return
	if _state == State.CYCLING or _occupant != null:
		return
	_occupant = body as CharacterBody3D
	var direction: int = 1 if _state == State.IDLE_ARM else -1
	_occupant.call(&"enter_lock_chamber", self)
	begin_cycle(direction)

func _on_body_exited(body: Node3D) -> void:
	if body != _occupant:
		return
	_occupant = null
	# Игрок физически вышел (через уже разблокированную дверь — цикл к этому
	# моменту завершён, _state больше не CYCLING): направление выхода
	# определяется текущим состоянием, а не тем, откуда он вошёл.
	if _state == State.IDLE_HUB:
		body.call(&"exit_lock_chamber", true, &"hub")
	else:
		body.call(&"exit_lock_chamber", false, module_id)
