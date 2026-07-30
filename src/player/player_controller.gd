## Игрок на гантелеобразной станции (ТЗ-100, подсистемы 1.1/1.2; топология
## ствол+барабан — ТЗ-000 §17). GRAVITY_WALK (плечо барабана, гравитация) —
## дочерний узел RotatingRing (A-01): скорость живёт в системе координат
## кольца (local_velocity — источник истины), глобальная velocity собирается
## непосредственно перед move_and_slide() и разбирается сразу после (принцип
## 7.1.2). Опора на пол и высота — ФИЗИКА Jolt (is_on_floor()/move_and_slide()),
## не аналитический расчёт: пол — AnimatableBody3D, вращается вместе с
## плечом, is_on_floor() и есть источник истины «стоит ли игрок». ZERO_G_FLY
## (неподвижный ствол, невесомость) — отдельная ветка без пола вовсе, см.
## _physics_process_zero_g(). Базис игрока переориентируется каждый физкадр по
## формуле 6.4.3, сохраняя направление взгляда при изменении «низа» (FR-03).
## Источник истины по гравитации — StationRoot (принцип 7.1.1), собственной
## формулы здесь нет.
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
## этого кадра — см. was_resting в _physics_process_gravity_walk(), где это
## условие сочетается с _airborne_streak_frames. Раньше порог проверялся
## против ПОЛНОЙ скорости (горизонталь + радиаль) и его приходилось расширять,
## чтобы пережить мигание опоры на стыках хорд — это ломало реальные прыжки и
## разгон ходьбы (широкий порог считал часть настоящего прыжка/торможения
## «покоем» и откатывал их). Разнесение на два независимых сигнала (эта
## константа — горизонталь; _airborne_streak_frames — радиаль) решает обе
## задачи, не мешая друг другу.
const REST_VELOCITY_EPS_M_S: float = 0.08
## Сколько кадров подряд без опоры ещё считается миганием is_on_floor() на
## стыке гранёного профиля пола, а не настоящим прыжком/падением. С переходом
## на сплошную (без внутренних стыков) плиту пола дуговой комнаты (см.
## ArcRoomStationModule._build_arc_collision()) источник мигания, для которого
## это писалось, по идее устранён — запас оставлен как страховка на случай
## остаточной нестабильности Jolt-контакта с непрерывно вращающимся
## AnimatableBody3D, не только стыков. Настоящий прыжок либо вообще не
## попадает в эту ветку (реальный горизонтальный ввод сразу даёт
## REST_VELOCITY_EPS_M_S false), либо остаётся без опоры на порядок дольше
## этого запаса — отличить легко.
const MAX_FLICKER_AIRBORNE_FRAMES: int = 6
## Множитель к config.run_speed_m_s, задающий потолок для local_velocity сразу
## после move_and_slide() (см. применение ниже). move_and_slide() иногда
## выражает однократную коррекцию глубокого проникновения коллизии (например,
## столкновение с закрытой дверью) как «скорость» в десятки м/с, а не как
## разовую подвижку позиции — и без ограничения этот артефакт переносится в
## local_velocity как настоящий импульс и разгоняет игрока в обратном
## направлении на секунду и больше (см. отчёт по ТЗ-100). Множитель 2 даёт
## запас над любой легитимной комбинированной скоростью (бег
## config.run_speed_m_s + вертикальная составляющая прыжка/падения, векторная
## сумма — не более ~4,1 м/с), но далеко отсекает наблюдавшиеся выбросы
## (13-26 м/с при беге 2,0-3,6 м/с).
const MAX_VELOCITY_SPEED_MULTIPLIER: float = 2.0

## Гравитационная ходьба (прежняя механика ТЗ-100, кольцо/плечо) или свободный
## полёт в невесомости (неподвижный ствол гантелеобразной станции, ТЗ-000
## §17.3 — адаптация перемещения под новую топологию). Определяется по
## фактическому родителю узла после teleport_to_module()/begin_transition(),
## не хранится независимо от него.
enum MovementMode { GRAVITY_WALK, ZERO_G_FLY }
var _mode: MovementMode = MovementMode.GRAVITY_WALK

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
## RingRotator, не общий Node3D: gravity-walk-ветке нужен его config.ring_radius_m
## (фактический радиус пола ТЕКУЩЕГО плеча — см. floor-snap ниже), а
## get_rotating_ring() у StationRoot возвращает Node3D только по сигнатуре
## контракта (годится и для старого кольца, и для гантели без её изменения).
var _rotating_ring: RingRotator
var _interaction_probe: InteractionProbe
var _modules: Array[StationModule] = []

var _move_input: Vector2 = Vector2.ZERO
## Вертикальная тяга в невесомости (move_up/move_down, ТЗ-000 §17.3) — [-1, 1].
## Не используется в GRAVITY_WALK (там вертикаль — только jump/гравитация).
var _vertical_input: float = 0.0
var _run_input: bool = false
var _last_physical_move_input: Vector2 = Vector2.ZERO
var _last_physical_vertical: float = 0.0
var _last_physical_run: bool = false
var _pending_jump: bool = false
## Сколько кадров ещё держим _pending_jump после trigger_jump() — тот же
## MAX_FLICKER_AIRBORNE_FRAMES запас, что и у мигания опоры (is_on_floor()
## регулярно ложно false даже на ровной ходьбе, см. отчёт): без буфера прыжок,
## пришедшийся ровно на такой кадр, терялся бы безвозвратно (_pending_jump
## сбрасывался в конце кадра независимо от того, был ли он реально
## использован) — обнаружено эмпирически (прыжок не срабатывал вовсе).
var _jump_buffer_frames_left: int = 0
var _yaw_delta_accum_rad: float = 0.0
var _prev_right: Vector3 = Vector3.RIGHT
var _has_spawned: bool = false

var _up_global: Vector3 = Vector3.UP
var _current_module: StringName = &""
var _stride_accum_m: float = 0.0
var _was_grounded: bool = false
## Кадров подряд без опоры — см. MAX_FLICKER_AIRBORNE_FRAMES. Обновляется в
## конце _physics_process_gravity_walk(), читается в начале следующего.
var _airborne_streak_frames: int = 0

func _ready() -> void:
	_station = get_node_or_null(station_path) as StationRoot
	if _station != null:
		_rotating_ring = _station.get_rotating_ring() as RingRotator
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
	# Не захватывать системный курсор, если рядом работает MCP-мост (сессия
	# отладки/тестирования через godot-runtime, а не игрок за столом) — иначе
	# захват уводит курсор мыши у человека на реальном рабочем столе, даже
	# когда окно самой игры визуально не активно/скрыто (background-режим).
	if get_tree().root.get_node_or_null("McpBridge") == null:
		set_mouse_captured(true)

func _physics_process(delta: float) -> void:
	_poll_physical_input()

	# _ready() выполняется снизу вверх: Player — потомок StationRoot, поэтому
	# на момент его собственного _ready() @onready-поля StationRoot ещё не
	# инициализированы, и get_rotating_ring() мог вернуть null. Досбор —
	# ленивый, на первом физкадре, когда вся сцена уже готова.
	if _rotating_ring == null and _station != null:
		_rotating_ring = _station.get_rotating_ring() as RingRotator
		_modules = _station.get_modules()

	if _rotating_ring == null or _station == null:
		return

	if not _has_spawned:
		_has_spawned = true
		teleport_to_module(initial_module_id)
		# Не резолвим движение в том же кадре, где телепорт: у Jolt ещё нет
		# контакта с полом по новой позиции (AnimatableBody3D синхронизируется
		# отдельным шагом, а StationModule._collision_root вдобавок фиксирует
		# свой identity-transform только в СВОЁМ следующем _physics_process(),
		# см. его класс-комментарий), и move_and_slide() ниже увидел бы
		# is_on_floor() ложно false — ровно тот же класс ошибки, что и мигание
		# на стыках хорд (см. блок отката дрейфа), но гарантированно на первом
		# кадре.
		return

	if _mode == MovementMode.ZERO_G_FLY:
		_physics_process_zero_g(delta)
	else:
		_physics_process_gravity_walk(delta)
	_update_current_module()

## Ходьба/бег/прыжок на полу вращающегося плеча — физика Jolt
## (move_and_slide()/is_on_floor()), не аналитический расчёт радиуса.
##
## Ключевая проблема этой схемы: пол — AnimatableBody3D с sync_to_physics
## (нужен для верной коллизии под вращающимся родителем, см.
## station_module.gd), и из-за этого Jolt на КАЖДОМ шаге заново разрешает
## контакт с движущейся (вращающейся) поверхностью — это разрешение вносит
## небольшую систематическую погрешность по касательной, даже при нулевой
## запрошенной скорости. За много кадров она накапливается в заметный дрейф
## («стоять 10 с» уезжает на десятки метров, если ничего не делать). Игрок при
## этом и так вращается вместе с плечом БЕСПЛАТНО — просто будучи ребёнком
## RotatingRing (A-01) в дереве сцены, без какого-либо участия физики. Фикс —
## ниже, was_resting: пока нет намеренного горизонтального движения (ввод
## погашен торможением) и опора недавняя (не идёт настоящий прыжок/падение),
## тангенциальный сдвиг, который только что дал move_and_slide(), откатывается
## целиком — совпадение с вращением плеча снова полностью на Node3D-иерархии,
## без вклада физики. Радиальная координата вдобавок ВСЕГДА (не только в
## покое) принудительно возвращается на точный радиус пола, пока игрок на полу
## и не в процессе подъёма на ступеньку — той же природы фикс, но для другой
## оси: Jolt-контакт даёт верное НАПРАВЛЕНИЕ, но не идеально точный радиус, и
## без этой коррекции неточность на каждом шаге ходьбы читалась бы как
## дёрганье камеры.
func _physics_process_gravity_walk(delta: float) -> void:
	var ring_basis: Basis = _rotating_ring.global_transform.basis

	# FR-02: «низ» — только из StationRoot, источник истины (принцип 7.1.1).
	_up_global = _station.get_gravity_up_at(global_position)
	var g_global: Vector3 = _station.get_gravity_at(global_position)
	up_direction = _up_global

	var up_local: Vector3 = (ring_basis.inverse() * _up_global).normalized()
	var g_local: Vector3 = ring_basis.inverse() * g_global

	_reorient_basis(up_local)
	_apply_step_up(ring_basis, delta, is_on_floor())

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

	if _pending_jump and _jump_buffer_frames_left > 0:
		_jump_buffer_frames_left -= 1
	if _pending_jump and is_on_floor():
		v_up = config.jump_velocity_m_s
		_pending_jump = false
	elif _pending_jump and _jump_buffer_frames_left <= 0:
		_pending_jump = false
	elif is_on_floor() and v_up <= 0.0:
		# `and v_up <= 0.0`, не голый is_on_floor(): то же мигание опоры, что
		# ломало ходьбу (см. отчёт выше), портило и прыжок — одиночный ложный
		# is_on_floor()=true ПОСРЕДИ подъёма (v_up ещё положительный, игрок
		# явно удаляется от пола) через minf(v_up, 0.0) обнулял высоту прыжка
		# почти сразу после старта (обнаружено эмпирически: прыжок «почти не
		# заметен»). Физически нельзя одновременно покоиться на полу и
		# удаляться от него — контакт, отмеченный при v_up>0, заведомо ложный,
		# и гравитация должна продолжать действовать как обычно (ветка else).
		v_up = 0.0
	else:
		v_up -= g_local.length() * delta

	local_velocity = horizontal_velocity + up_local * v_up

	# Два независимых условия, а не одна проверка полной скорости (единый
	# порог либо пропускал мигание опоры на стыках хорд, либо, расширенный,
	# ломал настоящие прыжки/разгон). Горизонталь — REST_VELOCITY_EPS_M_S;
	# радиаль — _airborne_streak_frames (см. константы).
	var no_intentional_move: bool = horizontal_velocity.length() < REST_VELOCITY_EPS_M_S
	var recent_floor_contact: bool = _airborne_streak_frames <= MAX_FLICKER_AIRBORNE_FRAMES
	var was_resting: bool = not _stepped_up_this_frame and no_intentional_move and recent_floor_contact
	# get_platform_velocity() — штатная схема старого кольца станции (вычесть
	# перед move_and_slide(), прибавить обратно после) — при полностью
	# совпадающей теперь конфигурации пола/радиуса плеча (см. правки
	# dumbbell_station_config.gd/arc_room_station_module.gd) была ПРОВЕРЕНА
	# ЕЩЁ РАЗ и всё равно даёт дрейф в покое (~18 м за 5 с — тот же класс
	# симптома, что документируют TC-ТЗ100-R1/R6 для caмого старого кольца,
	# просто здесь заметнее) и порчу скорости при ходьбе — то есть
	# ненадёжность get_platform_velocity() для CharacterBody3D, стоящего на
	# непрерывно вращающемся AnimatableBody3D, судя по всему присуща самому
	# этому механизму Godot/Jolt в такой конфигурации, а не была замаскирована
	# несовпадением геометрии. Вместо неё — совмещение только через
	# Node3D-иерархию (игрок и так ребёнок RotatingRing, вращается вместе с
	# плечом БЕСПЛАТНО, без физики): `horizontal_velocity`, посчитанный ВЫШЕ
	# через move_toward() к target_horizontal/config.accel_air_m_s2, — то, чего
	# игрок реально хотел этим кадром, не зависит от get_platform_velocity()
	# вовсе; move_and_slide() при этом остаётся полноценно ответственным за
	# столкновение со стенами (реальное перемещение позиции обрабатывается им
	# как обычно) — просто не единственный источник ЗНАЧЕНИЯ скорости,
	# которое переживает кадр.
	var pos_before_slide: Vector3 = global_position
	velocity = ring_basis * local_velocity
	move_and_slide()
	local_velocity = horizontal_velocity + up_local * v_up
	var max_sane_speed_m_s: float = config.run_speed_m_s * MAX_VELOCITY_SPEED_MULTIPLIER
	if local_velocity.length() > max_sane_speed_m_s:
		local_velocity = local_velocity.normalized() * max_sane_speed_m_s
	if was_resting:
		# Откатываем ТОЛЬКО тангенциальную (не вдоль up) составляющую сдвига —
		# именно она и есть паразитный дрейф от разрешения контакта с
		# вращающейся платформой. Радиальную не трогаем здесь: за неё теперь
		# всегда отвечает безусловная привязка радиуса ниже (не только в покое).
		var drift: Vector3 = global_position - pos_before_slide
		var radial_drift: Vector3 = _up_global * drift.dot(_up_global)
		global_position -= (drift - radial_drift)
		local_velocity = up_local * local_velocity.dot(up_local)
	elif not _stepped_up_this_frame:
		# Тот же класс паразитного контакта с вращающимся полом, что и было —
		# при АКТИВНОЙ ходьбе (не в покое) обнаружен эмпирически ЕГО худший
		# случай: move_and_slide() иногда даёт тангенциальную составляющую
		# сдвига, направленную ПРОТИВОПОЛОЖНО намеренному горизонтальному вводу
		# (нажатие "назад" двигало игрока в ту же сторону, что и "вперёд" — не
		# медленнее из-за стены, а буквально в другую сторону). get_platform_velocity()
		# в этот момент нестабилен между 0 и кратными истинной тангенциальной
		# скорости плеча (0, ×1, ×2) — Jolt дублирует/теряет вклад вращения
		# пола при разрешении контакта. Правим ТОЛЬКО явный разворот (скалярное
		# произведение факта и намерения < 0), не любое несовпадение длины —
		# короткий, но в ТУ ЖЕ сторону сдвиг (реальная стена) не трогаем,
		# иначе сломается блокировка стенами (см. регресс-проверку у торцевой
		# стены дуговой комнаты). Более широкая версия (заменять тангенциальный
		# сдвиг на аналитический ВСЕГДА, когда он короче намеренного — не
		# только при развороте) была опробована и ОТКЛОНЕНА: на старом кольце
		# при повторных прогонах с ИДЕНТИЧНЫМ вводом даёт разное, нестабильное
		# направление между попытками (было устойчиво воспроизводимо, стало
		# хаотично) — регрессия хуже устраняемого симптома. Слабая (заметно
		# короче намеренной) дистанция при ходьбе "назад" в дуговой комнате
		# плеча — известное, ещё не устранённое остаточное проявление того же
		# паразитного контакта, не задача этой правки.
		var drift: Vector3 = global_position - pos_before_slide
		var actual_horizontal: Vector3 = drift - _up_global * drift.dot(_up_global)
		var intended_horizontal: Vector3 = ring_basis * horizontal_velocity * delta
		if intended_horizontal.length_squared() > 0.0001 and actual_horizontal.dot(intended_horizontal) < 0.0:
			global_position += intended_horizontal - actual_horizontal
		_settle_step_up(ring_basis)
	else:
		_settle_step_up(ring_basis)

	# Радиальная координата — не результат разрешения контакта Jolt, а прямой
	# расчёт положения точки на окружности пола ТЕКУЩЕГО плеча
	# (_rotating_ring.config.ring_radius_m, FR-30): пока игрок на полу и не в
	# процессе подъёма на ступеньку, XZ-часть позиции (в системе координат
	# кольца) масштабируется до точного радиуса каждый кадр — не только в
	# покое (иначе та же погрешность пересчёта контакта на каждом шаге ходьбы
	# читалась бы как дёрганье камеры). Направление (угол) и осевую
	# составляющую (position.y) не трогаем — реальное перемещение по ним идёт
	# через move_and_slide() выше. _rotating_ring.config, не _station.config:
	# у гантелеобразной станции (ТЗ-000 §17) это разные ресурсы — пол
	# ТЕКУЩЕГО плеча (24 м) лежит в конфиге вращателя
	# (station_dumbbell_rotator.tres), а не в общем конфиге StationRoot
	# (station_default.tres, ring_radius_m=60 — орбитальные параметры станции,
	# доставшиеся от прежнего кольца).
	if is_on_floor() and not _stepped_up_this_frame:
		var radial_xz: Vector2 = Vector2(position.x, position.z)
		var current_radius: float = radial_xz.length()
		if current_radius > AXIS_EPS:
			var radial_scale: float = _rotating_ring.config.ring_radius_m / current_radius
			position.x *= radial_scale
			position.z *= radial_scale

	_airborne_streak_frames = 0 if is_on_floor() else _airborne_streak_frames + 1
	_update_footstep(horizontal_velocity, is_on_floor(), delta)
	_update_grounded_signal(is_on_floor())
	if _camera != null:
		# Не сырой is_on_floor() — он мигает false на несколько кадров подряд
		# даже во время ровной ходьбы (тот же паразитный контакт с вращающимся
		# полом, что и выше), и update_bob() раньше реагировал на это мгновенным
		# сбросом позиции камеры в ноль и обратно каждое мигание — источник
		# заметной дёрганности камеры при ходьбе, отдельный от самого дрейфа
		# позиции. Тот же запас на мигание, что уже используется для was_resting
		# (MAX_FLICKER_AIRBORNE_FRAMES) — камера не должна дёргаться от кадров
		# опоры короче реального прыжка/падения.
		var bob_grounded: bool = _airborne_streak_frames <= MAX_FLICKER_AIRBORNE_FRAMES
		_camera.update_bob(horizontal_velocity.length(), bob_grounded, delta)

## Свободный полёт в невесомости неподвижного ствола (ТЗ-000 §17.3 — этой
## механики не существовало вообще, не адаптация ходьбы). Тяга — по осям
## текущего взгляда игрока (transform.basis), без гравитации/пола/прыжка;
## при отсутствии ввода скорость гасится демпфированием, а не мгновенно.
## Родитель на время этого режима не вращается (DespunTruss/StationDumbbell),
## поэтому, в отличие от gravity-walk, local_velocity переводится в velocity
## через собственный global_transform.basis игрока, а не через ring_basis
## отдельного вращающегося узла — их тут просто нет.
func _physics_process_zero_g(delta: float) -> void:
	if _yaw_delta_accum_rad != 0.0:
		transform.basis = transform.basis.rotated(transform.basis.y, _yaw_delta_accum_rad).orthonormalized()
		_yaw_delta_accum_rad = 0.0
	up_direction = transform.basis.y

	var thrust_dir: Vector3 = transform.basis.x * _move_input.x - transform.basis.z * _move_input.y \
			+ transform.basis.y * _vertical_input
	thrust_dir = thrust_dir.limit_length(1.0)

	if thrust_dir.length_squared() > 0.0:
		local_velocity = local_velocity.move_toward(thrust_dir * config.zero_g_max_speed_m_s, config.zero_g_thrust_m_s2 * delta)
	else:
		local_velocity = local_velocity.move_toward(Vector3.ZERO, config.zero_g_damping_m_s2 * delta)

	velocity = global_transform.basis * local_velocity
	move_and_slide()
	local_velocity = global_transform.basis.inverse() * velocity

	if _camera != null:
		_camera.update_bob(0.0, false, delta)

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
	var vertical: float = 0.0
	if Input.is_action_pressed(&"move_up"):
		vertical += 1.0
	if Input.is_action_pressed(&"move_down"):
		vertical -= 1.0
	if vertical != _last_physical_vertical:
		_last_physical_vertical = vertical
		set_vertical_input(vertical)
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

func _apply_step_up(ring_basis: Basis, delta: float, grounded: bool) -> void:
	_stepped_up_this_frame = false
	if not grounded:
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

func _update_footstep(horizontal_velocity: Vector3, grounded: bool, delta: float) -> void:
	var speed: float = horizontal_velocity.length()
	if grounded and speed > 0.01:
		_stride_accum_m += speed * delta
		if _stride_accum_m >= config.stride_length_m:
			_stride_accum_m -= config.stride_length_m
			footstep.emit(_current_module, speed)
	else:
		_stride_accum_m = 0.0

func _update_grounded_signal(grounded: bool) -> void:
	if grounded != _was_grounded:
		_was_grounded = grounded
		grounded_changed.emit(grounded)

## Через полиморфный StationModule.contains_point(global_pos) вместо единого
## углового перебора — гантелеобразная станция (ТЗ-000 §17) не одна дуга: у
## осевых отсеков неподвижного ствола угол не имеет смысла вовсе, у дуговых
## комнат плеч — своя локальная система координат, не система игрока. Каждый
## модуль сам знает, как проверить принадлежность точки, поэтому эта функция
## больше не зависит от того, чьим ребёнком сейчас является игрок.
func _update_current_module() -> void:
	for module in _modules:
		if module.contains_point(global_position):
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

## Вертикальная тяга в невесомости (move_up/move_down) — программный дубль,
## тот же приём, что и set_move_input(). Не действует в GRAVITY_WALK — там нет
## понятия "вертикаль" в системе игрока, только jump/гравитация.
func set_vertical_input(value: float) -> void:
	if _is_input_suppressed():
		return
	_vertical_input = clampf(value, -1.0, 1.0)

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
	_jump_buffer_frames_left = MAX_FLICKER_AIRBORNE_FRAMES

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

## is_on_floor() только в GRAVITY_WALK — в ZERO_G_FLY "пола" нет вовсе, физика
## его там не резолвит осмысленно.
func is_grounded() -> bool:
	return _mode == MovementMode.GRAVITY_WALK and is_on_floor()

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

## Централизует переход между модулями и, при необходимости, между системами
## отсчёта (ТЗ-000 §17.3: неподвижный ствол — невесомость, вращающееся плечо —
## гравитация). Используется при первом спавне (initial_module_id), тестами
## напрямую и как ядро begin_transition() ниже — сама по себе БЕЗ затемнения
## экрана, это забота вызывающей стороны.
func teleport_to_module(module_id: StringName) -> void:
	if _station == null:
		return
	var module: StationModule = _station.get_module(module_id)
	var spawn: Node3D = _station.get_spawn_point(module_id)
	if module == null or spawn == null:
		return

	local_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	# Сброс streak'а без опоры — иначе телепорт сразу после настоящего прыжка/
	# падения (streak уже большой) на мгновение считал бы новую позицию "не
	# недавним контактом" в was_resting-проверке, хотя игрок только что встал
	# на пол через global_position = spawn.global_position ниже.
	_airborne_streak_frames = 0
	# _was_grounded тоже сбрасываем: иначе переход "в воздухе -> на полу" в
	# _physics_process_gravity_walk() (см. его комментарий про get_platform_velocity())
	# не сработает на ПЕРВОМ приземлении после телепорта, если до него игрок
	# уже стоял на полу где-то ещё (_was_grounded остался бы true с прошлого
	# места) — тот же паразитный тангенциальный импульс от вращения плеча
	# просочился бы необнаруженным именно в этом случае.
	_was_grounded = false
	# Не переносим "хвост" прыжка через телепорт — целевой модуль может быть
	# невесомым (ZERO_G_FLY), где _pending_jump вообще не смотрится, а если
	# он останется true, следующий gravity-walk модуль получит прыжок без
	# нажатия игрока.
	_pending_jump = false
	_jump_buffer_frames_left = 0

	# Игрок реально переезжает между DespunTruss (неподвижный ствол) и
	# RotatingRing (вращающееся плечо) — не только математически, физическим
	# родителем в дереве сцены, иначе вся ходьба (co-rotating design, A-01)
	# перестала бы работать бесплатно через Node3D-иерархию. remove_child/
	# add_child, а не reparent(): последний метод не входит в контракт "API
	# стабильно с 4.2" (см. CLAUDE.md) без дополнительной проверки, а глобальный
	# transform всё равно немедленно переустанавливается ниже.
	var target_parent: Node = module.get_parent()
	var current_parent: Node = get_parent()
	if target_parent != current_parent and current_parent != null:
		current_parent.remove_child(self)
		target_parent.add_child(self)
	_mode = MovementMode.GRAVITY_WALK if target_parent == _rotating_ring else MovementMode.ZERO_G_FLY

	global_position = spawn.global_position
	if _mode == MovementMode.GRAVITY_WALK:
		var up_local: Vector3 = (_rotating_ring.global_transform.basis.inverse() * _station.get_gravity_up_at(global_position)).normalized()
		# forward — тангенциальное направление обхода плеча; right (вдоль оси
		# кольца) выводится из него, а не наоборот (иначе «вперёд» указывает
		# вдоль оси кольца, в стену — см. отчёт).
		var forward: Vector3 = up_local.cross(Vector3.UP)
		if forward.length() < DEGENERATE_CROSS_EPS:
			forward = up_local.cross(Vector3.RIGHT)
		forward = forward.normalized()
		var right: Vector3 = forward.cross(up_local)
		transform.basis = Basis(right, up_local, -forward)
		_prev_right = right
	else:
		# Невесомость: физически осмысленного "верха" нет (get_gravity_up_at()
		# у самой оси вырождается — см. AXIS_EPS), формула 6.4.3 неприменима.
		# Базис просто выравнивается по собственной ориентации модуля (вдоль
		# трубы) — валидный ортонормированный старт для свободного полёта.
		transform.basis = module.global_transform.basis
		_prev_right = transform.basis.x

## Переход между стволом и плечом по кнопке действия, с затенением экрана
## (ТЗ-000 §17.3, документация 0.1.1: "без физического перемещения по
## коридору" — у коридора плеча нет коллизии специально по этой причине).
## Вызывается из StationTransition.interact() (src/interaction/).
func begin_transition(target_module_id: StringName) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"interaction_hud")
	if hud != null and hud.has_method(&"fade_out"):
		await hud.fade_out(config.transition_fade_duration_s)
	teleport_to_module(target_module_id)
	if hud != null and hud.has_method(&"fade_in"):
		hud.fade_in(config.transition_fade_duration_s)

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
