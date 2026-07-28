## Игрок во вращающемся кольце станции (ТЗ-100, подсистемы 1.1/1.2). Дочерний
## узел RotatingRing (A-01): скорость живёт в системе координат кольца
## (local_velocity — источник истины), глобальная velocity собирается
## непосредственно перед move_and_slide() и разбирается сразу после (принцип
## 7.1.2). Базис игрока переориентируется каждый физкадр по формуле 6.4.3,
## сохраняя направление взгляда при изменении «низа» (FR-03). Источник истины
## по гравитации — StationRoot (принцип 7.1.1), собственной формулы здесь нет.
class_name PlayerController
extends CharacterBody3D

## Минимальная длина векторного произведения forward_prev x up, ниже которой
## переориентация базиса считается вырожденной (6.4.3) — берём right с
## прошлого кадра. Практически недостижимо при обычной ходьбе.
const DEGENERATE_CROSS_EPS: float = 1e-4
## Порог около нуля/оси, ниже которого радиальная составляющая позиции
## считается невесомостью (согласовано с StationRoot.get_gravity_up_at()).
const AXIS_EPS: float = 0.01
## Технический запас к step_height_m в тесте на подъём (6.4.6/AC-10 задают
## порог «до 0.35 м включительно»; запас компенсирует зазор коллизии Jolt
## на самой границе, не расширяя фактически преодолимую высоту заметно).
const STEP_UP_MARGIN_M: float = 0.02
## Порог ГОРИЗОНТАЛЬНОЙ скорости, ниже которого считаем, что игрок не пытается
## идти намеренно. Только это, само по себе, НЕ решает, откатывать ли дрейф
## этого кадра — см. was_resting в _physics_process, где это условие сочетается
## с _airborne_streak_frames. Раньше порог проверялся против ПОЛНОЙ скорости
## (горизонталь + радиаль) и его приходилось расширять, чтобы пережить мигание
## опоры на стыках хорд — это сломало реальные прыжки и разгон ходьбы (широкий
## порог считал часть настоящего прыжка/торможения «покоем» и откатывал их).
## Разнесение на два независимых сигнала (эта константа — горизонталь;
## _airborne_streak_frames — радиаль) решает обе задачи, не мешая друг другу.
const REST_VELOCITY_EPS_M_S: float = 0.08
## Сколько кадров подряд без опоры ещё считается миганием is_on_floor() на
## стыке 16-хордовой аппроксимации пола (эмпирически бывает до 3 кадров
## подряд), а не настоящим прыжком/падением. Настоящий прыжок либо вообще не
## попадает в эту ветку (реальный горизонтальный ввод сразу даёт
## REST_VELOCITY_EPS_M_S false), либо остаётся без опоры на порядок дольше
## этого запаса — отличить легко.
const MAX_FLICKER_AIRBORNE_FRAMES: int = 6

signal module_changed(module_id: StringName)
signal footstep(surface_id: StringName, speed: float)
signal grounded_changed(grounded: bool)

@export var config: PlayerConfig
@export var interaction_config: InteractionConfig
@export var station_path: NodePath
@export var camera_pivot_path: NodePath
@export var camera_path: NodePath
@export var interaction_probe_path: NodePath
## Модуль, в котором игрок оказывается при старте сцены (см. teleport_to_module,
## FR-53) — без этого узел остаётся на оси вращения кольца (позиция по
## умолчанию в station.tscn), где нет пола и станция не видна.
@export var initial_module_id: StringName = &"control_deck"

## Скорость в системе координат кольца — источник истины (A-01, принцип 7.1.2).
var local_velocity: Vector3 = Vector3.ZERO

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _camera_pivot: Node3D = get_node_or_null(camera_pivot_path)
@onready var _camera: PlayerCamera = get_node_or_null(camera_path) as PlayerCamera

var _station: StationRoot
var _rotating_ring: Node3D
var _interaction_probe: InteractionProbe
var _modules: Array[StationModule] = []

var _move_input: Vector2 = Vector2.ZERO
var _run_input: bool = false
var _last_physical_move_input: Vector2 = Vector2.ZERO
var _last_physical_run: bool = false
var _pending_jump: bool = false
var _yaw_delta_accum_rad: float = 0.0
var _prev_right: Vector3 = Vector3.RIGHT
var _has_spawned: bool = false

var _up_global: Vector3 = Vector3.UP
var _current_module: StringName = &""
var _stride_accum_m: float = 0.0
var _was_grounded: bool = false
## Кадров подряд без опоры — см. MAX_FLICKER_AIRBORNE_FRAMES. Обновляется в
## конце _physics_process, читается в начале следующего.
var _airborne_streak_frames: int = 0

func _ready() -> void:
	_station = get_node_or_null(station_path) as StationRoot
	if _station != null:
		_rotating_ring = _station.get_rotating_ring()
		_modules = _station.get_modules()
	_interaction_probe = get_node_or_null(interaction_probe_path) as InteractionProbe

	var capsule := CapsuleShape3D.new()
	capsule.height = config.capsule_height_m
	capsule.radius = config.capsule_radius_m
	_collision_shape.shape = capsule
	# Начало координат тела = ступни (не центр капсулы): под этим уже
	# рассчитаны высота глаз (eye_height_m от origin) и радиус пола в AC-06.
	_collision_shape.position = Vector3.UP * (config.capsule_height_m * 0.5)

	if _camera_pivot != null:
		_camera_pivot.position = Vector3.UP * config.eye_height_m

	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(config.max_slope_deg)
	floor_snap_length = config.step_height_m
	set_mouse_captured(true)

func _physics_process(delta: float) -> void:
	_poll_physical_input()

	# _ready() выполняется снизу вверх: Player — потомок StationRoot, поэтому
	# на момент его собственного _ready() @onready-поля StationRoot ещё не
	# инициализированы, и get_rotating_ring() мог вернуть null. Досбор —
	# ленивый, на первом физкадре, когда вся сцена уже готова.
	if _rotating_ring == null and _station != null:
		_rotating_ring = _station.get_rotating_ring()
		_modules = _station.get_modules()

	if _rotating_ring == null or _station == null:
		return

	if not _has_spawned:
		_has_spawned = true
		teleport_to_module(initial_module_id)
		# Не резолвим движение в том же кадре, где телепорт: у Jolt ещё нет
		# контакта с полом по новой позиции (AnimatableBody3D синхронизируется
		# отдельным шагом), и move_and_slide() ниже увидел бы is_on_floor()
		# ложно false — ровно тот же класс ошибки, что и мигание на стыках
		# хорд (см. блок отката дрейфа), но гарантированно на первом кадре.
		return

	var ring_basis: Basis = _rotating_ring.global_transform.basis

	# FR-02: «низ» — только из StationRoot, источник истины (принцип 7.1.1).
	_up_global = _station.get_gravity_up_at(global_position)
	var g_global: Vector3 = _station.get_gravity_at(global_position)
	up_direction = _up_global

	var up_local: Vector3 = (ring_basis.inverse() * _up_global).normalized()
	var g_local: Vector3 = ring_basis.inverse() * g_global

	_reorient_basis(up_local)
	_apply_step_up(ring_basis, delta)

	var v_up: float = local_velocity.dot(up_local)
	var horizontal_velocity: Vector3 = local_velocity - up_local * v_up

	var move_dir_local: Vector3 = (transform.basis.x * _move_input.x - transform.basis.z * _move_input.y)
	move_dir_local = move_dir_local.limit_length(1.0)
	var target_speed: float = config.run_speed_m_s if _run_input else config.walk_speed_m_s
	var target_horizontal: Vector3 = move_dir_local * target_speed

	if is_on_floor():
		var rate: float = config.accel_ground_m_s2 if target_horizontal.length_squared() > horizontal_velocity.length_squared() else config.decel_ground_m_s2
		horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, rate * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(target_horizontal, config.accel_air_m_s2 * delta)

	if _pending_jump and is_on_floor():
		v_up = config.jump_velocity_m_s
	elif is_on_floor():
		v_up = minf(v_up, 0.0)
	else:
		v_up -= g_local.length() * delta
	_pending_jump = false

	local_velocity = horizontal_velocity + up_local * v_up

	# Пол — AnimatableBody3D с sync_to_physics (нужен для верной коллизии под
	# вращающимся родителем, см. station_module.gd) — из-за этого Jolt на
	# КАЖДОМ шаге заново разрешает контакт с движущейся (вращающейся)
	# поверхностью, и это разрешение вносит небольшую систематическую
	# погрешность по касательной, даже при нулевой запрошенной скорости. За
	# много кадров она накапливается в заметный дрейф (обнаружено при отладке
	# AC-07: «стоять 10 с» уезжало на десятки метров). move_and_slide() всё
	# равно вызывается каждый кадр (иначе внутреннее состояние Jolt отстаёт от
	# трансформа и при возобновлении движения даёт рывок/подвисание в воздухе)
	# — но в полном покое результат отбрасывается: сцепление с вращением
	# кольца уже даёт бесплатно родительский Node3D-трансформ (A-01).
	# Два независимых условия, а не одна проверка полной скорости (см. отчёт
	# по ТЗ-100 — единый порог либо пропускал мигание опоры на стыках хорд,
	# либо, расширенный, ломал настоящие прыжки/разгон). Горизонталь: нет
	# намеренного движения (ввод погашен торможением). Радиаль: без опоры не
	# дольше, чем длится мигание на стыке — иначе это уже настоящий
	# прыжок/падение, и откатывать его нельзя.
	var no_intentional_move: bool = horizontal_velocity.length() < REST_VELOCITY_EPS_M_S
	var recent_floor_contact: bool = _airborne_streak_frames <= MAX_FLICKER_AIRBORNE_FRAMES
	var was_resting: bool = not _stepped_up_this_frame and no_intentional_move and recent_floor_contact
	var pos_before_slide: Vector3 = global_position
	velocity = ring_basis * local_velocity - get_platform_velocity()
	move_and_slide()
	local_velocity = ring_basis.inverse() * (velocity - get_platform_velocity())
	if was_resting:
		# Откатываем ТОЛЬКО тангенциальную (не вдоль up) составляющую сдвига —
		# именно она и есть паразитный дрейф от разрешения контакта с
		# вращающейся платформой. Радиальную не трогаем здесь: за неё теперь
		# всегда отвечает безусловная привязка радиуса ниже (не только в покое).
		var drift: Vector3 = global_position - pos_before_slide
		var radial_drift: Vector3 = _up_global * drift.dot(_up_global)
		global_position -= (drift - radial_drift)
		local_velocity = up_local * local_velocity.dot(up_local)
	else:
		_settle_step_up(ring_basis)

	# Радиальная координата — не результат разрешения контакта Jolt, а прямой
	# расчёт положения точки на окружности пола станции (config.ring_radius_m,
	# FR-30): пока игрок на полу и не в процессе подъёма на ступеньку, XZ-часть
	# позиции (в системе координат кольца) масштабируется до точного радиуса
	# каждый кадр. Раньше точность держалась только в полном покое (was_resting)
	# — при ходьбе та же погрешность пересчёта контакта на каждом шаге читалась
	# как дёрганье камеры (см. отчёт по ТЗ-100). Направление (угол) и осевую
	# составляющую (position.y) не трогаем — реальное перемещение идёт как обычно.
	if is_on_floor() and not _stepped_up_this_frame:
		var radial_xz: Vector2 = Vector2(position.x, position.z)
		var current_radius: float = radial_xz.length()
		if current_radius > AXIS_EPS:
			var radial_scale: float = _station.config.ring_radius_m / current_radius
			position.x *= radial_scale
			position.z *= radial_scale
	_airborne_streak_frames = 0 if is_on_floor() else _airborne_streak_frames + 1
	_update_footstep(horizontal_velocity, delta)
	_update_grounded_signal()
	_update_current_module()
	if _camera != null:
		_camera.update_bob(horizontal_velocity.length(), is_on_floor(), delta)

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
	# По изменению, а не каждый кадр: иначе при отсутствии физического ввода
	# (фоновый режим, 7.7.2) опрос каждый кадр перезаписывал бы программный
	# дубль set_move_input() нулём на следующем же физкадре.
	if input_dir != _last_physical_move_input:
		_last_physical_move_input = input_dir
		set_move_input(input_dir)
	var run_pressed: bool = Input.is_action_pressed(&"run")
	if run_pressed != _last_physical_run:
		_last_physical_run = run_pressed
		set_run_input(run_pressed)
	if Input.is_action_just_pressed(&"jump"):
		trigger_jump()
	if Input.is_action_just_pressed(&"interact"):
		trigger_interact()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		# Esc отпускает системный курсор мыши (виден, не заперт окном) — иначе
		# окно нечем закрыть/свернуть, курсор невидим и заперт в клиентской
		# области. Возврат — по клику (ветка ниже), стандартная для жанра пара.
		set_mouse_captured(false)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens: float = config.mouse_sensitivity_deg_px * config.mouse_sensitivity_multiplier
		var y_sign: float = 1.0 if config.invert_y else -1.0
		add_look_input(Vector2(-motion.relative.x * sens, motion.relative.y * sens * y_sign))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if mb.pressed:
				set_mouse_captured(true)
			return
		if _interaction_probe != null:
			var target: Interactable = _interaction_probe.get_target()
			if target != null:
				target.receive_click(mb.pressed)

## Переориентация базиса игрока при смене «низа» (формула 6.4.3, FR-03).
## forward_prev — направление взгляда с прошлого кадра (-basis.z); right
## переносится через минимальное вращение, затем накопленный ввод рыскания
## применяется поворотом вокруг нового «верха» (FR-20).
func _reorient_basis(up_local: Vector3) -> void:
	var forward_prev: Vector3 = -transform.basis.z
	var cross: Vector3 = forward_prev.cross(up_local)
	var right: Vector3
	if cross.length() < DEGENERATE_CROSS_EPS:
		right = _prev_right
	else:
		right = cross.normalized()
	var forward: Vector3 = up_local.cross(right)
	var reoriented := Basis(right, up_local, right.cross(up_local))
	_prev_right = right

	if _yaw_delta_accum_rad != 0.0:
		reoriented = reoriented.rotated(up_local, _yaw_delta_accum_rad)
		_yaw_delta_accum_rad = 0.0
		_prev_right = reoriented.x

	transform.basis = reoriented.orthonormalized()

## Упрощённый подъём на ступеньку до step_height_m (FR-09): если горизонтальное
## движение заблокировано, а прямо над точкой блокировки есть свободное место
## не выше step_height_m — тело поднимается перед move_and_slide(), затем
## _settle_step_up() опускает его обратно на пол после сдвига.
var _stepped_up_this_frame: bool = false

func _apply_step_up(ring_basis: Basis, delta: float) -> void:
	_stepped_up_this_frame = false
	if not is_on_floor():
		return
	var horizontal_local: Vector3 = local_velocity - transform.basis.y * local_velocity.dot(transform.basis.y)
	if horizontal_local.length() < 0.01:
		return
	var motion_global: Vector3 = ring_basis * horizontal_local * delta
	if not test_move(global_transform, motion_global):
		return
	var up_motion: Vector3 = _up_global * (config.step_height_m + STEP_UP_MARGIN_M)
	if not test_move(global_transform, up_motion):
		global_position += up_motion
		_stepped_up_this_frame = true

func _settle_step_up(_ring_basis: Basis) -> void:
	if not _stepped_up_this_frame:
		return
	_stepped_up_this_frame = false
	move_and_collide(-_up_global * (config.step_height_m + STEP_UP_MARGIN_M))

func _update_footstep(horizontal_velocity: Vector3, delta: float) -> void:
	var speed: float = horizontal_velocity.length()
	if is_on_floor() and speed > 0.01:
		_stride_accum_m += speed * delta
		if _stride_accum_m >= config.stride_length_m:
			_stride_accum_m -= config.stride_length_m
			footstep.emit(_current_module, speed)
	else:
		_stride_accum_m = 0.0

func _update_grounded_signal() -> void:
	var grounded: bool = is_on_floor()
	if grounded != _was_grounded:
		_was_grounded = grounded
		grounded_changed.emit(grounded)

func _update_current_module() -> void:
	var angle_deg: float = wrapf(rad_to_deg(atan2(position.z, position.x)), 0.0, 360.0)
	for module in _modules:
		if angle_deg >= module.angle_start_deg and angle_deg < module.angle_end_deg:
			if module.module_id != _current_module:
				_current_module = module.module_id
				module_changed.emit(_current_module)
			return

# ─ Программные дубли ввода (FR-50) ───────────────────────────────────────

func set_move_input(input: Vector2) -> void:
	if _is_input_suppressed():
		return
	_move_input = input.limit_length(1.0)

func set_run_input(running: bool) -> void:
	_run_input = running

func add_look_input(delta_deg: Vector2) -> void:
	if _is_input_suppressed():
		return
	_yaw_delta_accum_rad += deg_to_rad(delta_deg.x)
	if _camera != null:
		_camera.add_pitch_deg(delta_deg.y)

func set_look_direction(yaw_deg: float, pitch_deg: float) -> void:
	var up_local: Vector3 = transform.basis.y
	# Нулевой отсчёт рыскания — тангенциальное направление обхода кольца
	# (forward0), а не up.cross(UP) само по себе: этот вектор лежит в
	# горизонтальной плоскости и годится как ссылка, но это FORWARD, не RIGHT
	# (right = forward×up, иначе «вперёд» указывает вдоль оси кольца — в стену).
	var forward0: Vector3 = up_local.cross(Vector3.UP)
	if forward0.length() < DEGENERATE_CROSS_EPS:
		forward0 = up_local.cross(Vector3.RIGHT)
	forward0 = forward0.normalized()
	var right0: Vector3 = forward0.cross(up_local)
	var base := Basis(right0, up_local, -forward0)
	transform.basis = base.rotated(up_local, deg_to_rad(yaw_deg)).orthonormalized()
	_prev_right = transform.basis.x
	if _camera != null:
		_camera.set_pitch_deg(pitch_deg)

func trigger_jump() -> void:
	if _is_input_suppressed():
		return
	_pending_jump = true

func trigger_interact() -> void:
	if _interaction_probe == null:
		return
	var target: Interactable = _interaction_probe.get_target()
	if target == null:
		return
	var distance: float = _interaction_probe.get_target_distance()
	if distance < 0.0 or distance > interaction_config.interact_range_m:
		return
	target.interact(self)

## Программный дубль Esc/клика по вьюпорту: захват системного курсора мыши
## окном. `false` — курсор виден и свободен (окно можно свернуть/закрыть,
## переключиться на другое приложение); `true` — заперт и невидим, обзор
## управляется мышью как обычно.
func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _is_input_suppressed() -> bool:
	if _interaction_probe == null:
		return false
	var target: Interactable = _interaction_probe.get_target()
	return target != null and target.is_capturing_input()

# ─ Состояние (7.4) ────────────────────────────────────────────────────────

func is_grounded() -> bool:
	return is_on_floor()

func current_module() -> StringName:
	return _current_module

## get_up_direction() не переопределяется: CharacterBody3D уже предоставляет
## его как штатный геттер свойства up_direction, которое этот контроллер
## синхронизирует со StationRoot.get_gravity_up_at() каждый физкадр — тот же
## контракт FR-02, без конфликта с нативным методом движка.

func get_ring_radius() -> float:
	return Vector2(position.x, position.z).length()

func get_eye_transform() -> Transform3D:
	if _camera != null:
		return _camera.global_transform
	return global_transform

func get_look_angles() -> Vector2:
	var up_local: Vector3 = transform.basis.y
	var forward0: Vector3 = up_local.cross(Vector3.UP)
	if forward0.length() < DEGENERATE_CROSS_EPS:
		forward0 = up_local.cross(Vector3.RIGHT)
	forward0 = forward0.normalized()
	var current_forward: Vector3 = -transform.basis.z
	var signed_angle_rad: float = forward0.signed_angle_to(current_forward, up_local)
	var pitch_deg: float = 0.0
	if _camera != null:
		pitch_deg = _camera.get_pitch_deg()
	return Vector2(rad_to_deg(signed_angle_rad), pitch_deg)

# ─ Телепорт (FR-53) ───────────────────────────────────────────────────────

func teleport_to_module(module_id: StringName) -> void:
	if _station == null:
		return
	var spawn: Node3D = _station.get_spawn_point(module_id)
	if spawn == null:
		return
	local_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = spawn.global_position
	if _rotating_ring != null and _station != null:
		var up_local: Vector3 = (_rotating_ring.global_transform.basis.inverse() * _station.get_gravity_up_at(global_position)).normalized()
		# forward — тангенциальное направление обхода кольца; right (вдоль оси
		# кольца) выводится из него, а не наоборот (иначе «вперёд» указывает
		# вдоль оси кольца, в стену — см. отчёт).
		var forward: Vector3 = up_local.cross(Vector3.UP)
		if forward.length() < DEGENERATE_CROSS_EPS:
			forward = up_local.cross(Vector3.RIGHT)
		forward = forward.normalized()
		var right: Vector3 = forward.cross(up_local)
		transform.basis = Basis(right, up_local, -forward)
		_prev_right = right

# ─ Сохранение (ТЗ-073) ────────────────────────────────────────────────────

func get_save_state() -> Dictionary:
	var pitch_deg: float = 0.0
	if _camera != null:
		pitch_deg = _camera.get_pitch_deg()
	return {
		"local_position": position,
		"basis": transform.basis,
		"local_velocity": local_velocity,
		"camera_pitch_deg": pitch_deg,
	}

func apply_save_state(state: Dictionary) -> void:
	if state.has("local_position"):
		position = state["local_position"]
	if state.has("basis"):
		transform.basis = state["basis"]
		_prev_right = transform.basis.x
	if state.has("local_velocity"):
		local_velocity = state["local_velocity"]
	if state.has("camera_pitch_deg") and _camera != null:
		_camera.set_pitch_deg(state["camera_pitch_deg"])
