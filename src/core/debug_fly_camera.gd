## Свободная отладочная камера: WASD + мышь (ПКМ — захват курсора), Shift —
## ускорение. Пять предустановленных ракурсов задаются извне как Marker3D
## (preset_nodes) — камера ничего не знает о структуре станции/солнечной
## системы, только копирует transform маркера. FR-50, FR-51
class_name DebugFlyCamera
extends Camera3D

@export var move_speed_m_s: float = 20.0
@export var boost_multiplier: float = 4.0
@export var mouse_sensitivity: float = 0.003

## Marker3D-узлы ракурсов 1..5 (см. ТЗ-000, 4.5): внешний обзор, из рубки,
## на Нептун, на Солнце, крупный план фермы.
@export var preset_nodes: Array[NodePath] = []

var _active_preset: int = 0
var _mouse_captured: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _mouse_captured:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)
		_active_preset = 0

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

## Программный дубль клавиш 1..5 — переключает камеру на именованный ракурс. FR-51
func go_to_preset(preset_id: int) -> void:
	if preset_id < 1 or preset_id > preset_nodes.size():
		return
	var target: Node3D = get_node_or_null(preset_nodes[preset_id - 1])
	if target == null:
		return
	global_transform = target.global_transform
	_yaw = rotation.y
	_pitch = rotation.x
	_active_preset = preset_id

## 0 — камера в свободном полёте, иначе номер активного пресета (1..5). FR-51
func current_preset() -> int:
	return _active_preset
