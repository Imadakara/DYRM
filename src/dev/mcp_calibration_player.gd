## FPS-контроллер для сцены калибровки MCP-команд
## (scenes/dev/mcp_calibration.tscn, см. skill godot-mcp-testing (глобальный)).
## Обычная земная гравитация ProjectSettings — намеренно НЕ переиспользует
## PlayerController этого репозитория (тот жёстко завязан на вращающееся
## кольцо станции, см. src/player/player_controller.gd). Эта сцена и скрипт
## существуют, чтобы отрабатывать сами MCP-команды (simulate_input,
## take_screenshot, run_script) на минимальном, самодостаточном примере,
## переносимом в любой другой Godot-проект без изменений.
class_name McpCalibrationPlayer
extends CharacterBody3D

@export var move_speed_m_s: float = 3.0
@export var mouse_sensitivity_deg_px: float = 0.15
@export var interact_range_m: float = 2.5
@export var camera_pivot_path: NodePath
@export var ray_path: NodePath

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _camera_pivot: Node3D = get_node_or_null(camera_pivot_path)
@onready var _ray: RayCast3D = get_node_or_null(ray_path)

var _move_input: Vector2 = Vector2.ZERO
var _pitch_deg: float = 0.0
var _last_physical_move_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	_collision.shape = capsule
	# Origin = ступни, не центр капсулы: так CameraPivot.position.y напрямую
	# читается как высота глаз над полом.
	_collision.position = Vector3.UP * (capsule.height * 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_poll_physical_input()

	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	var move_dir: Vector3 = transform.basis.x * _move_input.x - transform.basis.z * _move_input.y
	move_dir = move_dir.limit_length(1.0)
	velocity.x = move_dir.x * move_speed_m_s
	velocity.z = move_dir.z * move_speed_m_s
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		add_look_input(Vector2(-motion.relative.x, -motion.relative.y) * mouse_sensitivity_deg_px)
	elif event.is_action_pressed(&"interact"):
		trigger_interact()

func _poll_physical_input() -> void:
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed(&"move_forward"):
		input_dir.y += 1.0
	if Input.is_action_pressed(&"move_back"):
		input_dir.y -= 1.0
	if Input.is_action_pressed(&"move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed(&"move_left"):
		input_dir.x -= 1.0
	input_dir = input_dir.limit_length(1.0)
	# По изменению, не каждый кадр: иначе в фоновом MCP-режиме (без физического
	# ввода) опрос каждый кадр перезаписывал бы программный дубль set_move_input()
	# нулём на следующем же физкадре.
	if input_dir != _last_physical_move_input:
		_last_physical_move_input = input_dir
		set_move_input(input_dir)

# ─ Программные дубли ввода — обязательны, физический ввод недоступен в ─
# ─ headless/фоновом режиме MCP (см. skill godot-mcp-testing (глобальный)) ─

func set_move_input(input: Vector2) -> void:
	_move_input = input.limit_length(1.0)

func add_look_input(delta_deg: Vector2) -> void:
	rotate_y(deg_to_rad(delta_deg.x))
	_pitch_deg = clampf(_pitch_deg + delta_deg.y, -89.0, 89.0)
	if _camera_pivot != null:
		_camera_pivot.rotation.x = deg_to_rad(_pitch_deg)

## Абсолютная установка обзора — а не относительная дельта. Существует, чтобы
## тест мог принудительно привести камеру в известное состояние: захваченный
## режим мыши в фоновом MCP-запуске склонен копить дрейф рыскания/тангажа от
## посторонних InputEventMouseMotion, не связанных ни с одним отправленным
## simulate_input (см. skill godot-mcp-testing (глобальный)) — полагаться на
## накопленную относительную историю небезопасно.
func set_look_direction(yaw_deg: float, pitch_deg: float) -> void:
	rotation = Vector3.ZERO
	rotate_y(deg_to_rad(yaw_deg))
	_pitch_deg = clampf(pitch_deg, -89.0, 89.0)
	if _camera_pivot != null:
		_camera_pivot.rotation.x = deg_to_rad(_pitch_deg)

func get_look_angles() -> Vector2:
	return Vector2(rotation_degrees.y, _pitch_deg)

func trigger_interact() -> void:
	var target: Node = get_interact_target()
	if target == null:
		return
	target.call(&"interact")

## Текущая цель под перекрестьем в пределах дистанции, или null.
func get_interact_target() -> Node:
	if _ray == null or not _ray.is_colliding():
		return null
	var target: Node = _ray.get_collider()
	if target == null or not target.has_method(&"interact"):
		return null
	var distance: float = _ray.global_position.distance_to(_ray.get_collision_point())
	if distance > interact_range_m:
		return null
	return target
