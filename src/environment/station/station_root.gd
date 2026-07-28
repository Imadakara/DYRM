## Корень станции: орбита вокруг Нептуна (круговая, A-02), контракт гравитации
## для будущего перемещения игрока (ТЗ-100), базис наведения азимут/возвышение,
## реестр модулей, доступ к вращающемуся кольцу для внешних систем. FR-20..FR-42
##
## Узел StationRoot в сцене Local НЕ перемещается на реальное орбитальное
## расстояние (100 000 км не помещаются в радиус слоя Local 2000 м, FR-01) —
## станция всегда остаётся у локального начала координат. position_km()
## хранит истинное гелиоцентрическое положение отдельно, как данные, и
## используется только слоем Deep и вычислениями направлений. Ось вращения
## кольца (global_transform.basis.y узла StationRoot) физически неподвижна
## в инерциальном пространстве — не путать с AimingReference, чей базис
## отслеживает текущий орбитальный зенит и медленно поворачивается за орбитальный
## период (21,1 ч), независимо от быстрого вращения кольца (28,375 с). A-02, A-03
class_name StationRoot
extends Node3D

## Испускается при изменении скорости вращения кольца. В ТЗ-000 скорость
## постоянна — сигнал объявлен как задел под будущие аварийные события. FR-23
signal ring_rotation_changed(rpm: float)

const SECONDS_PER_DAY: float = 86400.0
const NEPTUNE_ID: StringName = &"neptune"
const SUN_ID: StringName = &"sun"

@export var config: StationConfig
@export var solar_system_path: NodePath
@export var game_clock_path: NodePath

@onready var _rotating_ring: RingRotator = $RotatingRing
@onready var _aiming_reference: Node3D = $AimingReference
@onready var _despun_truss: Node3D = $DespunTruss

var _solar_system: SolarSystem
var _modules: Array[StationModule] = []
var _modules_by_id: Dictionary = {}

var _orbit_period_s: float = 1.0
var _orbit_angle_rad: float = 0.0
var _aiming_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	_solar_system = get_node_or_null(solar_system_path) as SolarSystem
	_orbit_period_s = 2.0 * PI * sqrt(pow(config.orbit_radius_km, 3.0) / config.neptune_mu_km3_s2)
	_collect_modules(_rotating_ring)
	_build_hub()
	_update_orbit(0.0)

	var game_clock: GameClock = get_node_or_null(game_clock_path) as GameClock
	if game_clock != null:
		game_clock.time_changed.connect(_update_orbit)
		_update_orbit(game_clock.epoch_days)

## Ступица — простая процедурная геометрия (StationMeshBuilder) и коллизия,
## заполняется в пустую StaticBody3D-заглушку сцены station.tscn. Неподвижна
## относительно инерциальной системы (despun) — её торцы зарезервированы под
## будущие модули Блока 3 (ГДД 000, Core Rule 4, ревизия 2026-07-28).
func _build_hub() -> void:
	_configure_cylinder_body(_despun_truss.get_node_or_null("Hub"),
			StationMeshBuilder.build_hub_mesh(config.hub_radius_m, config.hub_length_m),
			config.hub_radius_m, config.hub_length_m)

func _configure_cylinder_body(body: StaticBody3D, mesh: Mesh, radius_m: float, height_m: float) -> void:
	if body == null:
		return
	var mesh_instance: MeshInstance3D = body.get_node_or_null("Mesh")
	if mesh_instance != null:
		mesh_instance.mesh = mesh
	var collision: CollisionShape3D = body.get_node_or_null("Collision")
	if collision != null:
		var shape := CylinderShape3D.new()
		shape.radius = radius_m
		shape.height = height_m
		collision.shape = shape

func _collect_modules(node: Node) -> void:
	for child in node.get_children():
		if child is StationModule:
			_modules.append(child)
			_modules_by_id[child.module_id] = child
		_collect_modules(child)

## Пересчитывает орбитальный угол станции вокруг Нептуна (формула 6.4.5) и
## базис наведения (местный зенит/скорость). Круговая орбита в экваториальной
## плоскости Нептуна — за отсутствием данных об ориентации полюса Нептуна
## упрощённо принята совпадающей с плоскостью эклиптики (см. отчёт). FR-19, A-02
func _update_orbit(epoch_days: float) -> void:
	var elapsed_s: float = epoch_days * SECONDS_PER_DAY
	_orbit_angle_rad = wrapf(TAU * elapsed_s / _orbit_period_s, 0.0, TAU)

	var zenith: Vector3 = Vector3(cos(_orbit_angle_rad), 0.0, sin(_orbit_angle_rad))
	var velocity_dir: Vector3 = Vector3(-sin(_orbit_angle_rad), 0.0, cos(_orbit_angle_rad))
	var forward: Vector3 = -velocity_dir
	var right: Vector3 = zenith.cross(forward)
	_aiming_basis = Basis(right, zenith, forward)
	_aiming_reference.transform = Transform3D(_aiming_basis, Vector3.ZERO)

func _orbit_offset_km() -> Vector3:
	return Vector3(cos(_orbit_angle_rad), 0.0, sin(_orbit_angle_rad)) * config.orbit_radius_km

## Направление «вверх» (к оси вращения кольца) в глобальных координатах. FR-24
func get_gravity_up_at(global_pos: Vector3) -> Vector3:
	var axis_dir: Vector3 = global_transform.basis.y
	var offset: Vector3 = global_pos - global_position
	var radial: Vector3 = offset - axis_dir * offset.dot(axis_dir)
	if radial.length() < 0.01:
		return axis_dir
	return -radial.normalized()

## Вектор кажущейся (центробежной) гравитации в точке, м/с², направлен наружу
## от оси вращения. На оси — невесомость (Vector3.ZERO). Кориолисова сила
## и градиент тяжести по высоте не моделируются (A-03). FR-24
##
## angular_velocity_rad_s: угловая скорость СИСТЕМЫ ОТСЧЁТА, которой сейчас
## принадлежит точка запроса — не выводится из global_pos автоматически
## (после ревизии станции 2026-07-28 неподвижная ступица и вращающаяся
## сборка сосуществуют на разных радиусах, поэтому единой ω для всей станции
## больше нет). По умолчанию (-1) берётся ω вращающейся сборки — обратная
## совместимость для потребителей, которые всегда находятся в ней (025, 027,
## 031, 034, 039, 045). PlayerController — единственный потребитель, который
## может физически оказаться в ступице или лок-камере — обязан передавать ω
## своего текущего родителя явно (см. player_controller.gd, _current_omega()).
func get_gravity_at(global_pos: Vector3, angular_velocity_rad_s: float = -1.0) -> Vector3:
	var axis_dir: Vector3 = global_transform.basis.y
	var offset: Vector3 = global_pos - global_position
	var radial: Vector3 = offset - axis_dir * offset.dot(axis_dir)
	var radial_len: float = radial.length()
	if radial_len < 0.01:
		return Vector3.ZERO
	var omega: float = angular_velocity_rad_s if angular_velocity_rad_s >= 0.0 else _rotating_ring.angular_velocity_rad_s
	return radial.normalized() * omega * omega * radial_len

## Базис для отсчёта азимута/возвышения (узел AimingReference): +Y — местный
## зенит (от центра Нептуна к станции), -Z — вектор орбитальной скорости,
## +X дополняет до правой тройки. Обновляется в _update_orbit(). FR-27
func get_aiming_basis() -> Basis:
	return _aiming_basis

## Направление (глобальное, единичное) → Vector2(азимут°, возвышение°).
## Азимут — по часовой стрелке от -Z (вид с +Y), [0, 360). Возвышение — от
## плоскости XZ базиса, [-90, 90].
func direction_to_az_el(direction: Vector3) -> Vector2:
	var local: Vector3 = _aiming_basis.inverse() * direction.normalized()
	var azimuth_rad: float = atan2(local.x, -local.z)
	if azimuth_rad < 0.0:
		azimuth_rad += TAU
	var elevation_rad: float = asin(clampf(local.y, -1.0, 1.0))
	return Vector2(rad_to_deg(azimuth_rad), rad_to_deg(elevation_rad))

## Обратное преобразование direction_to_az_el().
func az_el_to_direction(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var az: float = deg_to_rad(azimuth_deg)
	var el: float = deg_to_rad(elevation_deg)
	var local := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	return (_aiming_basis * local).normalized()

func get_modules() -> Array[StationModule]:
	return _modules

func get_module(id: StringName) -> StationModule:
	return _modules_by_id.get(id)

## 3 именованные локации (ГДД 100 Core Rule 3, ревизия 2026-07-28):
## control_room/habitat (StationModule на вращающейся сборке) и hub (маркер
## в неподвижной ступице — не StationModule, не проектируется этим методом).
func get_spawn_point(module_id: StringName) -> Node3D:
	if module_id == &"hub":
		return _despun_truss.get_node_or_null("Spawn")
	var module: StationModule = get_module(module_id)
	if module == null:
		return null
	return module.spawn_point

## Узел вращающейся сборки — родитель для игрока и всего, что должно
## вращаться вместе с ней (ТЗ-100). Имя метода — наследие торовой геометрии,
## сохранено для обратной совместимости; get_rotating_assembly() ниже —
## каноничное имя после ревизии 2026-07-28 (ADR-0002). FR-41
func get_rotating_ring() -> Node3D:
	return _rotating_ring

func get_rotating_assembly() -> Node3D:
	return _rotating_ring

## Неподвижная (despun) ступица — родитель для игрока, когда он физически
## находится в её объёме (ГДД 000 Core Rule 4, ADR-0002 ревизия 2026-07-28).
## Торцы ступицы зарезервированы под будущие модули Блока 3.
func get_despun_hub() -> Node3D:
	return _despun_truss

## Гелиоцентрическое положение станции, км — Нептун + круговое смещение по
## орбите. Не является позицией узла в сцене Local (см. заголовок файла). FR-15
func position_km() -> Vector3:
	var neptune_km: Vector3 = Vector3.ZERO
	if _solar_system != null:
		var neptune: CelestialBody = _solar_system.get_body(NEPTUNE_ID)
		if neptune != null:
			neptune_km = neptune.position_km
	return neptune_km + _orbit_offset_km()

## Текущий угол поворота кольца, радианы — используется отладочным оверлеем.
func get_ring_angle_rad() -> float:
	return _rotating_ring.rotation_angle_rad()

## true, если станция находится в тени Нептуна (формула 6.4.6). FR-25
func is_in_eclipse() -> bool:
	if _solar_system == null:
		return false
	var neptune: CelestialBody = _solar_system.get_body(NEPTUNE_ID)
	var sun: CelestialBody = _solar_system.get_body(SUN_ID)
	if neptune == null or sun == null:
		return false
	var sun_dir: Vector3 = (sun.position_km - neptune.position_km).normalized()
	var station_dir: Vector3 = _orbit_offset_km().normalized()
	var half_angle_rad: float = asin(config.neptune_radius_km / config.orbit_radius_km)
	return sun_dir.dot(station_dir) < -cos(half_angle_rad)
