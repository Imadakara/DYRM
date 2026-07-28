## Рукоять-коридор станции-гантели: прямая труба от пола модуля
## (radius=ring_radius_m, module_angle_deg) до наружной стенки лок-камеры
## (radius=hub_radius_m+lock_chamber_length_m, hub_attach_angle_deg).
##
## Проход по рукояти — сценарная перевозка (по аналогии с лок-камерой), а не
## свободная ходьба по Jolt-коллизии: чисто радиальная рукоять (её форвард
## по построению почти всегда близок к радиальному — иначе ширина у дверного
## проёма конфликтует с шириной проёма модуля, см. отчёт по этой ревизии)
## имеет пол, чья нормаль перпендикулярна истинной гравитации на всём своём
## протяжении — Jolt физически не может трактовать такую поверхность как пол
## (получается свободное падение вдоль рукояти, а не ходьба). Игрок
## удерживается на месте (ввод подавлен), позиция интерполируется вдоль
## рукояти в реальном времени; направление «вниз» и ориентация пересчитываются
## каждый кадр как обычно (get_gravity_up_at), так что ощущение непрерывно
## меняющейся тяжести (ГДД 000 Core Rule 4) сохраняется, только без реальной
## физики ходьбы. Коллизия (стены/пол/потолок) остаётся ради визуальной
## твёрдости, но не служит опорой во время перевозки.
class_name ArmCorridor
extends Node3D

@export var module_angle_deg: float = 0.0
@export var hub_attach_angle_deg: float = 0.0
@export var config: StationConfig
@export var hull_material: Material

const WALL_THICKNESS_M: float = 0.3
## Длина триггерной зоны у дверного проёма модуля, метры — как только игрок
## входит в неё, начинается перевозка на всю оставшуюся длину рукояти.
const TRIGGER_ZONE_LENGTH_M: float = 2.0
## Скорость перевозки, м/с — соответствует PlayerConfig.walk_speed_m_s (не
## читается динамически с игрока, чтобы не тянуть его тип сюда).
const TRANSIT_SPEED_M_S: float = 2.0

@onready var spawn_point: Marker3D = $Spawn
@onready var _hull: MeshInstance3D = $Hull
@onready var _collision_root: AnimatableBody3D = $Collision
@onready var _detector: Area3D = $Detector

var _length_m: float = 0.0
var _occupant: CharacterBody3D
var _transit_elapsed_s: float = 0.0
var _transit_duration_s: float = 0.0

var _mount_transform: Transform3D = Transform3D.IDENTITY

## _enter_tree() (не _ready()) — то же обоснование, что в station_module.gd:
## AnimatableBody3D-потомок ($Collision) синхронизируется с физ.сервером на
## своём _ready() (снизу вверх), раньше собственного _ready() рукояти (где
## иначе выставлялся бы transform) — при однократной установке transform
## коллизия навсегда десинхронизируется. _enter_tree() идёт сверху вниз,
## поэтому transform рукояти успевает примениться раньше.
func _enter_tree() -> void:
	_place_self()

func _ready() -> void:
	_build_geometry()
	_detector.body_entered.connect(_on_body_entered)

## См. station_module.gd — тот же приём: sync_to_physics у AnimatableBody3D
## не долетает до физ.сервера от вращения родителя (RotatingAssembly), только
## от изменения СОБСТВЕННОГО transform коллизии — форсируем его каждый кадр
## (нужно и здесь: стены/пол рукояти остаются коллизионно твёрдыми не только
## во время сценарной перевозки, см. заголовок файла).
func _physics_process(delta: float) -> void:
	_collision_root.global_transform = _collision_root.global_transform
	if _occupant == null:
		return
	_transit_elapsed_s += delta
	var t: float = clampf(_transit_elapsed_s / _transit_duration_s, 0.0, 1.0)
	# Позиция — вдоль local +Z рукояти (от триггерной зоны до самого конца,
	# где начинается лок-камера); X/Y фиксированы по центру прохода. Игрок и
	# рукоять — оба потомки RotatingRing (общий родитель), но НЕ друг друга —
	# точку в системе координат рукояти нужно перевести в систему координат
	# ИХ ОБЩЕГО родителя через собственный transform рукояти, иначе позиция
	# трактуется как уже ring-local и оказывается в случайном месте.
	var z: float = lerp(TRIGGER_ZONE_LENGTH_M, _length_m, t)
	var local_in_arm := Vector3(0.0, 1.0, z)
	_occupant.position = _mount_transform * local_in_arm
	_occupant.velocity = Vector3.ZERO
	if _occupant.has_method(&"sync_transit_orientation"):
		_occupant.call(&"sync_transit_orientation")
	if t >= 1.0:
		var finished: CharacterBody3D = _occupant
		_occupant = null
		if finished.has_method(&"end_arm_transit"):
			finished.call(&"end_arm_transit")

func _place_self() -> void:
	var start: Vector3 = StationModule.radial_dir(module_angle_deg) * config.ring_radius_m
	var end: Vector3 = StationModule.radial_dir(hub_attach_angle_deg) * (config.hub_radius_m + config.lock_chamber_length_m)

	# «right» (ширина рукояти) зафиксирован на касательной модуля — совпадает
	# с шириной дверного проёма без излома. «forward» ортогонализован против
	# right по Грам-Шмидту (см. заголовок файла: это и есть причина, по
	# которой рукоять не может быть обычным Jolt-полом).
	var right: Vector3 = StationModule.tangent_dir(module_angle_deg)
	var raw_forward: Vector3 = (end - start).normalized()
	var forward: Vector3 = (raw_forward - right * right.dot(raw_forward)).normalized()
	var up: Vector3 = forward.cross(right)
	var basis := Basis(right, up, forward)
	_length_m = start.distance_to(end)
	_mount_transform = Transform3D(basis, start)
	transform = _mount_transform

func _build_geometry() -> void:
	_hull.mesh = StationMeshBuilder.build_tube_mesh(_length_m, config.arm_cross_section_m, config.arm_cross_section_m)
	if hull_material != null:
		_hull.material_override = hull_material

	spawn_point.position = Vector3(0.0, 1.0, _length_m * 0.5)

	_build_collision()

func _build_collision() -> void:
	var w: float = config.arm_cross_section_m
	var h: float = config.arm_cross_section_m
	var mid_z: float = _length_m * 0.5

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(w, WALL_THICKNESS_M, _length_m)
	_add_box(floor_shape, Vector3(0.0, -WALL_THICKNESS_M * 0.5, mid_z))

	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(w, WALL_THICKNESS_M, _length_m)
	_add_box(ceiling_shape, Vector3(0.0, h + WALL_THICKNESS_M * 0.5, mid_z))

	var side_wall_shape := BoxShape3D.new()
	side_wall_shape.size = Vector3(WALL_THICKNESS_M, h, _length_m)
	_add_box(side_wall_shape, Vector3(-w * 0.5 - WALL_THICKNESS_M * 0.5, h * 0.5, mid_z))
	_add_box(side_wall_shape, Vector3(w * 0.5 + WALL_THICKNESS_M * 0.5, h * 0.5, mid_z))

	var detector_shape := BoxShape3D.new()
	detector_shape.size = Vector3(w, h, TRIGGER_ZONE_LENGTH_M)
	var detector_collision := CollisionShape3D.new()
	detector_collision.shape = detector_shape
	detector_collision.position = Vector3(0.0, h * 0.5, TRIGGER_ZONE_LENGTH_M * 0.5)
	_detector.add_child(detector_collision)

func _add_box(shape: BoxShape3D, local_pos: Vector3) -> void:
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.position = local_pos
	_collision_root.add_child(collision_shape)

func _on_body_entered(body: Node3D) -> void:
	if _occupant != null:
		return
	if not (body is CharacterBody3D and body.has_method(&"begin_arm_transit")):
		return
	var remaining_m: float = _length_m - TRIGGER_ZONE_LENGTH_M
	if remaining_m <= 0.0:
		return
	_occupant = body as CharacterBody3D
	_transit_elapsed_s = 0.0
	_transit_duration_s = remaining_m / TRANSIT_SPEED_M_S
	_occupant.call(&"begin_arm_transit", self)

func length_m() -> float:
	return _length_m
