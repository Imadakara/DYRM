## Отладочная камера с двумя режимами: свободный полёт (WASD + мышь, ПКМ —
## захват курсора, Shift — ускорение) и орбита вокруг станции (клавиши 1..5 —
## пять предустановленных ракурсов/"проекций", каждый входит в режим орбиты).
## Пять Marker3D (preset_nodes) задают только НАЧАЛЬНУЮ точку обзора каждого
## ракурса — камера ничего не знает о структуре станции, только вычисляет из
## позиции маркера относительно ORBIT_TARGET начальные дистанцию/азимут/
## возвышение. FR-50, FR-51
##
## В режиме орбиты (после входа по клавише 1..5) ПКМ + движение мыши вращает
## вид вокруг ORBIT_TARGET (азимут/возвышение) вместо свободного взгляда,
## колесо мыши меняет дистанцию; WASD по-прежнему выходит в свободный полёт
## из текущей точки. Станция всегда остаётся в локальном начале координат
## сцены (см. station_root.gd — орбитальное положение не переносится в Local),
## поэтому единой общей точки ORBIT_TARGET достаточно для всех 5 ракурсов, не
## нужен отдельный маркер цели на каждый.
class_name DebugFlyCamera
extends Camera3D

@export var move_speed_m_s: float = 20.0
@export var boost_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.003
@export var orbit_sensitivity: float = 0.006
@export var orbit_zoom_speed_m: float = 4.0
@export var orbit_min_distance_m: float = 4.0
@export var orbit_max_distance_m: float = 400.0

## Marker3D-узлы ракурсов 1..5 (см. ТЗ-000, 4.5 и раздел 17 — обновлены под
## масштаб гантелеобразной станции): изометрия, вид сверху вдоль оси, борт
## неподвижного ствола, крупный план барабана/плеч, широкий контекстный план.
@export var preset_nodes: Array[NodePath] = []

const ORBIT_TARGET: Vector3 = Vector3.ZERO
const _MAX_ELEVATION_RAD: float = 1.5

var _active_preset: int = 0
var _mouse_captured: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0

var _orbit_distance_m: float = 40.0
var _orbit_azimuth_rad: float = 0.0
var _orbit_elevation_rad: float = 0.0

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	if not preset_nodes.is_empty():
		go_to_preset(1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
		elif mb.pressed and _active_preset != 0 and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(-orbit_zoom_speed_m if mb.button_index == MOUSE_BUTTON_WHEEL_UP else orbit_zoom_speed_m)
	elif event is InputEventMouseMotion and _mouse_captured:
		var motion := event as InputEventMouseMotion
		if _active_preset != 0:
			orbit_by(-motion.relative.x * orbit_sensitivity, -motion.relative.y * orbit_sensitivity)
		else:
			_yaw -= motion.relative.x * mouse_sensitivity
			_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -1.5, 1.5)
			rotation = Vector3(_pitch, _yaw, 0.0)

	for i in range(1, 6):
		if event.is_action_pressed("debug_camera_preset_%d" % i):
			go_to_preset(i)

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		var speed: float = move_speed_m_s
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= boost_multiplier
		global_position += input_dir * speed * delta
		_active_preset = 0

## Программный дубль клавиш 1..5 — входит в режим орбиты вокруг ORBIT_TARGET,
## начиная с дистанции/азимута/возвышения, соответствующих позиции маркера
## ракурса (сама позиция маркера — единственное, что из него используется;
## его поворот не читается, направление взгляда всегда пересчитывается на
## ORBIT_TARGET). FR-51
func go_to_preset(preset_id: int) -> void:
	if preset_id < 1 or preset_id > preset_nodes.size():
		return
	var target: Node3D = get_node_or_null(preset_nodes[preset_id - 1])
	if target == null:
		return
	var offset: Vector3 = target.global_position - ORBIT_TARGET
	_orbit_distance_m = clampf(offset.length(), orbit_min_distance_m, orbit_max_distance_m)
	_orbit_elevation_rad = clampf(asin(clampf(offset.y / max(_orbit_distance_m, 0.001), -1.0, 1.0)),
			-_MAX_ELEVATION_RAD, _MAX_ELEVATION_RAD)
	_orbit_azimuth_rad = atan2(offset.x, offset.z)
	_active_preset = preset_id
	_apply_orbit_transform()

## 0 — камера в свободном полёте, иначе номер активного ракурса (1..5). FR-51
func current_preset() -> int:
	return _active_preset

## Программный дубль вращения мышью с зажатой ПКМ (см. класс-комментарий —
## без дубля вращение недоступно в фоновом/безголовом режиме): меняет азимут/
## возвышение вокруг ORBIT_TARGET. Действует только в режиме ракурса —
## в свободном полёте вращать вокруг станции нечего.
func orbit_by(d_azimuth_rad: float, d_elevation_rad: float) -> void:
	if _active_preset == 0:
		return
	_orbit_azimuth_rad = wrapf(_orbit_azimuth_rad + d_azimuth_rad, -PI, PI)
	_orbit_elevation_rad = clampf(_orbit_elevation_rad + d_elevation_rad, -_MAX_ELEVATION_RAD, _MAX_ELEVATION_RAD)
	_apply_orbit_transform()

## Программный дубль колеса мыши — приближает (delta_m < 0) или отдаляет
## (delta_m > 0) камеру от ORBIT_TARGET в пределах orbit_min/max_distance_m.
func zoom_by(delta_m: float) -> void:
	if _active_preset == 0:
		return
	_orbit_distance_m = clampf(_orbit_distance_m + delta_m, orbit_min_distance_m, orbit_max_distance_m)
	_apply_orbit_transform()

func _apply_orbit_transform() -> void:
	var horizontal_m: float = _orbit_distance_m * cos(_orbit_elevation_rad)
	var offset := Vector3(horizontal_m * sin(_orbit_azimuth_rad), _orbit_distance_m * sin(_orbit_elevation_rad),
			horizontal_m * cos(_orbit_azimuth_rad))
	global_position = ORBIT_TARGET + offset
	look_at(ORBIT_TARGET, Vector3.UP)
	_yaw = rotation.y
	_pitch = rotation.x
