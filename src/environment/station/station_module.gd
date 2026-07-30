## Один модуль/коридор кольца: строит свою 45°-дугу через StationMeshBuilder
## (пол, потолок, боковые стены + коллизии) по собственным angle_start/end_deg,
## хранит идентификатор и точку спавна. Мешу и коллизии не хранит сам —
## делегирует расчёт StationMeshBuilder (данные отдельно от поведения). FR-30..FR-33, FR-39
##
## @tool: геометрия строится и в редакторе, не только в запущенной игре —
## чтобы station.tscn открывался уже собранным и правки (углы дуги, config)
## были видны сразу, без запуска проекта. _build_geometry() идемпотентна
## (чистит сгенерированные ранее коллайдеры/светильники перед пересборкой),
## поэтому повторные вызовы при перезагрузке скрипта в редакторе не копят
## дубликаты. Сгенерированные узлы НЕ получают owner — это сознательно:
## геометрия пересобирается заново при каждом открытии сцены из актуального
## config, а не сохраняется в .tscn (та же логика, что и раньше при чисто
## рантайм-генерации — просто теперь она срабатывает и в редакторе).
@tool
class_name StationModule
extends Node3D

## Идентификатор модуля из таблицы 6.3.7 (control_deck, corridor_a, habitat, ...).
@export var module_id: StringName = &""
@export var display_name: String = ""

## Угловые границы дуги в системе координат кольца (0° = +X, против часовой
## стрелки при взгляде с +Y), см. таблицу 6.3.7.
@export var angle_start_deg: float = 0.0
@export var angle_end_deg: float = 45.0

@export var config: StationConfig
@export var hull_material: Material

## Толщина коллизии пола/потолка/стен, м. Тонкие слои по всем 4 поверхностям
## тубы вместо одного сплошного блока на весь deck_height_m — см. отчёт
## ТЗ-100 (обходимая, но блокирующая проблема унаследованного ТЗ-000: старая
## коллизия заполняла ВЕСЬ отсек монолитом при полностью полой видимой
## геометрии build_ring_arc_mesh, из-за чего игрок спавнился внутри камня).
const WALL_THICKNESS_M: float = 0.3

@onready var spawn_point: Marker3D = $Spawn
@onready var _hull: MeshInstance3D = $Hull
## AnimatableBody3D, не StaticBody3D: этот узел лежит под RotatingRing и
## непрерывно вращается — движущийся StaticBody3D физика Jolt трактует как
## неподвижный для broadphase и не пересчитывает контакты корректно.
@onready var _collision_root: AnimatableBody3D = $Collision

func _ready() -> void:
	_build_geometry()

## _collision_root (AnimatableBody3D) держит локальный transform строго
## Transform3D.IDENTITY относительно себя же — вся геометрия коллизии,
## построенная _build_collision()/_build_arc_collision() у наследников, уже
## закодирована в собственных локальных трансформах CollisionShape3D-детей
## относительно ЭТОГО узла. У модулей, чей родитель получает трансформ не
## тождеством (арочные плечи гантели, ТЗ-000 §17 — StationDocking.dock()
## поворачивает сам модуль один раз при сборке), Godot стабильно "запоминает"
## для АnimatableBody3D-потомка какой-то трансформ ИЗ МОМЕНТА ДО этого
## поворота предка и с тех пор не пересчитывает его заново (тот же почерк,
## что и паразитный поворот AnimatableBody3D под непрерывно вращающимся
## предком — DrumModule._physics_process(), база знаний Godot, запись 22 —
## только здесь искажение статичное, разовое, а не растущее кадр к кадру).
## Результат без этой защиты — коллизия пола/стен оказывается развёрнута на
## произвольный угол относительно видимой геометрии, и игрок падает мимо
## пола (обнаружено при первой живой проверке ходьбы по плечу гантели).
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Пишем свойство, только если оно реально не тождество — не безусловно
	# каждый кадр: у АnimatableBody3D с sync_to_physics запись transform (даже
	# тем же значением) даёт PhysicsServer3D лишний сигнал "трансформ
	# изменился" ПОВЕРХ обычного пересчёта от вращения предка в этом же кадре,
	# что может путать вычисление скорости синка для контакта (см. is_equal_approx
	# ниже — по факту после первой коррекции это почти всегда true, реальная
	# запись происходит примерно один раз, не каждый кадр).
	if not _collision_root.transform.is_equal_approx(Transform3D.IDENTITY):
		_collision_root.transform = Transform3D.IDENTITY

func _build_geometry() -> void:
	# Устанавливаем тождественный transform ДО первого _physics_process(), не
	# только в нём — иначе Jolt успевает зарегистрировать этот AnimatableBody3D
	# с тем неверным transform, что уже был на узле к моменту его появления в
	# дереве, и первая же коррекция читается как скачок (тот же механизм, что
	# и известный баг "epoch_days на целые сутки одним кадром → аномальная
	# скорость", см. tools/run_tests.gd, physics_containment).
	_collision_root.transform = Transform3D.IDENTITY
	_clear_children(_collision_root)
	_clear_generated_lights()

	var floor_radius_m: float = config.ring_radius_m
	var ceiling_radius_m: float = config.ring_radius_m - config.deck_height_m
	var half_width_m: float = config.tube_width_m * 0.5
	var angle_start_rad: float = deg_to_rad(angle_start_deg)
	var angle_end_rad: float = deg_to_rad(angle_end_deg)

	_hull.mesh = StationMeshBuilder.build_ring_arc_mesh(angle_start_rad, angle_end_rad,
			floor_radius_m, ceiling_radius_m, half_width_m, config.arc_segment_count)
	if hull_material != null:
		_hull.material_override = hull_material

	# Точка спавна — середина дуги, ~1 м над полом в направлении местного "верха"
	# (радиально внутрь, см. get_gravity_up_at). FR-39
	var mid_angle_rad: float = (angle_start_rad + angle_end_rad) * 0.5
	var radial_dir := Vector3(cos(mid_angle_rad), 0.0, sin(mid_angle_rad))
	spawn_point.position = radial_dir * (floor_radius_m - 1.0)

	var mid_radius_m: float = (floor_radius_m + ceiling_radius_m) * 0.5
	_build_collision(angle_start_rad, angle_end_rad, floor_radius_m, ceiling_radius_m, half_width_m)

	_build_interior_lights(angle_start_rad, angle_end_rad, mid_radius_m)

## Четыре тонких коллайдера на хорду (пол/потолок/2 стены) — повторяет полую
## структуру build_ring_arc_mesh. Один сплошной блок на весь deck_height_m
## оставлял бы отсек монолитом без свободного пространства для ходьбы.
func _build_collision(angle_start_rad: float, angle_end_rad: float,
		floor_radius_m: float, ceiling_radius_m: float, half_width_m: float) -> void:
	var mid_radius_m: float = (floor_radius_m + ceiling_radius_m) * 0.5
	var chord_len_m: float = StationMeshBuilder.ring_arc_chord_length(
			angle_start_rad, angle_end_rad, mid_radius_m, config.arc_segment_count)

	# Плиты выступают НАРУЖУ от полой зоны (пол — за r=floor_radius_m в сторону
	# корпуса, потолок — за r=ceiling_radius_m в сторону оси), а не внутрь неё:
	# ходимая поверхность должна остаться ровно на floor_radius_m (AC-06,
	# радиус 60,00 ± 0,05 м), а не на floor_radius_m - WALL_THICKNESS_M/2.
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(chord_len_m, config.tube_width_m, WALL_THICKNESS_M)
	_add_collision_layer(angle_start_rad, angle_end_rad,
			floor_radius_m + WALL_THICKNESS_M * 0.5, floor_shape)

	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(chord_len_m, config.tube_width_m, WALL_THICKNESS_M)
	_add_collision_layer(angle_start_rad, angle_end_rad,
			ceiling_radius_m - WALL_THICKNESS_M * 0.5, ceiling_shape)

	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(chord_len_m, WALL_THICKNESS_M, config.deck_height_m)
	_add_collision_layer(angle_start_rad, angle_end_rad, mid_radius_m, wall_shape, half_width_m)
	_add_collision_layer(angle_start_rad, angle_end_rad, mid_radius_m, wall_shape, -half_width_m)

func _add_collision_layer(angle_start_rad: float, angle_end_rad: float, radius_m: float,
		shape: BoxShape3D, y_offset_m: float = 0.0) -> void:
	var transforms: Array[Transform3D] = StationMeshBuilder.ring_arc_collision_transforms(
			angle_start_rad, angle_end_rad, radius_m, config.arc_segment_count)
	for local_transform in transforms:
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		collision_shape.transform = local_transform.translated(Vector3.UP * y_offset_m)
		_collision_root.add_child(collision_shape)

## Внутреннее освещение отсека: несколько OmniLight3D, равномерно расставленных
## вдоль дуги модуля на середине высоты отсека. Раздел 9.2.
func _build_interior_lights(angle_start_rad: float, angle_end_rad: float, mid_radius_m: float) -> void:
	for i in range(config.interior_light_count_per_module):
		var t: float = (i + 0.5) / float(config.interior_light_count_per_module)
		var angle_rad: float = lerp(angle_start_rad, angle_end_rad, t)
		var light := OmniLight3D.new()
		light.position = Vector3(cos(angle_rad), 0.0, sin(angle_rad)) * mid_radius_m
		light.light_color = config.interior_light_color
		light.omni_range = config.interior_light_range_m
		light.light_energy = config.interior_light_energy
		add_child(light)

## Принадлежит ли точка (глобальные координаты) этому модулю — источник истины
## для PlayerController._update_current_module() (ТЗ-100), полиморфный вместо
## единого углового перебора по всем модулям станции: у гантелеобразной
## станции (см. ТЗ-000 §17) угол осмысленен только для дуговых модулей вроде
## этого — переопределяется в CylindricalStationModule для осевых отсеков
## неподвижного ствола, где углового смысла нет вовсе.
##
## Сравнение по кругу через wrapf(), не прямое "angle >= start and angle < end":
## angle_start_deg/angle_end_deg дуговых модулей плеч гантели заданы
## симметрично вокруг коннектора барабана (например, [-30, 30]) — простое
## сравнение сломалось бы на границе 0°/360°, круговая формула — нет, и при
## этом даёт те же результаты на не-обёрнутых диапазонах прежнего кольца
## (проверено на границах: 45.0 ровно — соседний модуль, не этот).
func contains_point(global_pos: Vector3) -> bool:
	var local: Vector3 = to_local(global_pos)
	var angle_deg: float = rad_to_deg(atan2(local.z, local.x))
	var offset_deg: float = wrapf(angle_deg - angle_start_deg, 0.0, 360.0)
	var span_deg: float = wrapf(angle_end_deg - angle_start_deg, 0.0, 360.0)
	return offset_deg < span_deg

## Чистит сгенерированные _build_geometry() дочерние узлы перед пересборкой
## (сама пересборка происходит и в редакторе — см. класс-комментарий), иначе
## повторный вызов множил бы коллайдеры/светильники, а не заменял их.
func _clear_children(parent: Node) -> void:
	for c in parent.get_children():
		c.free()

func _clear_generated_lights() -> void:
	for c in get_children():
		if c is OmniLight3D:
			c.free()
