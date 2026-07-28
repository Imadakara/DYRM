## Один обитаемый модуль станции-гантели («боёк молота»): прямоугольная
## комната на радиусе config.ring_radius_m от оси вращения, с дверным проёмом
## в сторону рукояти. Собственный transform вычисляется из mount_angle_deg —
## не задаётся вручную в сцене (см. station_root.gd, где вызывается build()).
## Мешу и коллизии не хранит сам — делегирует расчёт StationMeshBuilder.
class_name StationModule
extends Node3D

## Идентификатор модуля (control_room, habitat — см. ГДД 100 Core Rule 3).
@export var module_id: StringName = &""
@export var display_name: String = ""

## Угол в системе координат вращающейся сборки (0° = +X, против часовой
## стрелки при взгляде с +Y), на котором стоит модуль — см. ГДД 000 Core Rule 4.
@export var mount_angle_deg: float = 0.0

@export var config: StationConfig
@export var hull_material: Material

## Толщина коллизии пола/потолка/стен, метры.
const WALL_THICKNESS_M: float = 0.3

@onready var spawn_point: Marker3D = $Spawn
@onready var _hull: MeshInstance3D = $Hull
## AnimatableBody3D, не StaticBody3D: узел лежит под RotatingAssembly и
## непрерывно вращается — движущийся StaticBody3D физика Jolt трактует как
## неподвижный для broadphase и не пересчитывает контакты корректно.
@onready var _collision_root: AnimatableBody3D = $Collision

## _enter_tree() (не _ready()): порядок вызовов у Godot — _enter_tree() идёт
## СВЕРХУ ВНИЗ (родитель раньше потомка), а _ready() СНИЗУ ВВЕРХ (потомок
## раньше родителя). AnimatableBody3D-потомок ($Collision) регистрирует свой
## global_transform в физическом сервере на СВОЁМ _ready() — если repositioning
## модуля (transform=...) происходит позже, в _ready() модуля, коллизия
## синхронизируется с ФИЗ.сервером по устаревшему (ещё не сдвинутому,
## фактически на оси вращения) transform. Это первая часть бага.
func _enter_tree() -> void:
	_place_self()

func _ready() -> void:
	_build_geometry()

## Вторая, более глубокая часть того же бага (обнаружена диагностикой через
## PhysicsServer3D.body_get_state): sync_to_physics у AnimatableBody3D реально
## переотправляет transform на физ.сервер только когда меняется СОБСТВЕННЫЙ
## (локальный) transform самого тела — вращение РОДИТЕЛЯ (RotatingAssembly),
## два уровня выше ($Collision — потомок StationModule, а не самого
## RotatingAssembly), не долетает до физ.сервера, хотя Node3D.global_transform
## (обычное чтение через сцену) уже показывает верное, повёрнутое значение.
## Итог: физ.сервер держит пол НАВСЕГДА неподвижным в исходной ring-local
## точке, пока станция продолжает вращаться — отсюда провал игрока сквозь пол.
## lock_chamber.gd этой проблемы избегает случайно: он каждый физкадр сам
## переустанавливает СОБСТВЕННЫЙ transform (_apply_transform()), а не только
## меняется трансформом родителя — тем самым каждый раз явно трогая local
## transform, что и запускает пересинхронизацию. Тот же приём применяется
## здесь: пересчитываем global_transform коллизии из актуальной глобальной
## позиции каждый кадр, что вынуждает Godot пересчитать и переприменить
## локальный transform (а не просто прочитать неизменное кэшированное
## значение), и физ.сервер получает свежую позицию.
func _physics_process(_delta: float) -> void:
	_collision_root.global_transform = _collision_root.global_transform

func _place_self() -> void:
	var radial: Vector3 = radial_dir(mount_angle_deg)
	var up: Vector3 = -radial
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	var depth_axis: Vector3 = tangent.cross(up)
	transform = Transform3D(Basis(tangent, up, depth_axis), radial * config.ring_radius_m)

## Радиальное направление (наружу от оси) для заданного угла в системе
## координат вращающейся сборки.
static func radial_dir(angle_deg: float) -> Vector3:
	var angle_rad: float = deg_to_rad(angle_deg)
	return Vector3(cos(angle_rad), 0.0, sin(angle_rad))

## Касательное направление (перпендикулярно радиальному) для того же угла.
static func tangent_dir(angle_deg: float) -> Vector3:
	var r: Vector3 = radial_dir(angle_deg)
	return Vector3(-r.z, 0.0, r.x)

## Ортонормированный базис для прямой трубы (рукоять/лок-камера): forward —
## направление вдоль трубы, up_hint — предпочтительное направление «верха»
## (не обязательно точно перпендикулярно forward). Если forward почти
## параллелен up_hint (чисто радиальный отрезок, вырожденный случай), right
## берётся из касательного направления при заданном угле вместо
## forward x up_hint — иначе получился бы нулевой вектор.
static func orthonormal_tube_basis(forward: Vector3, up_hint: Vector3, fallback_angle_deg: float) -> Basis:
	var right: Vector3 = forward.cross(up_hint)
	if right.length() < 0.01:
		right = forward.cross(tangent_dir(fallback_angle_deg))
		if right.length() < 0.01:
			right = forward.cross(Vector3.UP)
	right = right.normalized()
	var up: Vector3 = right.cross(forward).normalized()
	return Basis(right, up, forward)

func _build_geometry() -> void:
	_hull.mesh = StationMeshBuilder.build_room_mesh(config.module_width_m, config.module_depth_m, config.module_height_m)
	if hull_material != null:
		_hull.material_override = hull_material

	# Точка спавна — центр комнаты, ~1 м от пола в направлении местного «верха».
	spawn_point.position = Vector3(0.0, 1.0, -config.module_depth_m * 0.5)

	_build_collision()
	_build_interior_lights()

## Пол/потолок/3 стены (4-я сторона, Z=0, — дверной проём в рукоять, не
## перекрывается коллизией комнаты).
func _build_collision() -> void:
	var hw: float = config.module_width_m * 0.5
	var d: float = config.module_depth_m
	var h: float = config.module_height_m

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(config.module_width_m, WALL_THICKNESS_M, d)
	_add_box(floor_shape, Vector3(0.0, -WALL_THICKNESS_M * 0.5, -d * 0.5), Basis.IDENTITY)

	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(config.module_width_m, WALL_THICKNESS_M, d)
	_add_box(ceiling_shape, Vector3(0.0, h + WALL_THICKNESS_M * 0.5, -d * 0.5), Basis.IDENTITY)

	var far_wall_shape := BoxShape3D.new()
	far_wall_shape.size = Vector3(config.module_width_m, h, WALL_THICKNESS_M)
	_add_box(far_wall_shape, Vector3(0.0, h * 0.5, -d - WALL_THICKNESS_M * 0.5), Basis.IDENTITY)

	var side_wall_shape := BoxShape3D.new()
	side_wall_shape.size = Vector3(WALL_THICKNESS_M, h, d)
	_add_box(side_wall_shape, Vector3(-hw - WALL_THICKNESS_M * 0.5, h * 0.5, -d * 0.5), Basis.IDENTITY)
	_add_box(side_wall_shape, Vector3(hw + WALL_THICKNESS_M * 0.5, h * 0.5, -d * 0.5), Basis.IDENTITY)

func _add_box(shape: BoxShape3D, local_pos: Vector3, basis: Basis) -> void:
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.transform = Transform3D(basis, local_pos)
	_collision_root.add_child(collision_shape)

func _build_interior_lights() -> void:
	for i in range(config.interior_light_count_per_module):
		var t: float = (i + 0.5) / float(config.interior_light_count_per_module)
		var light := OmniLight3D.new()
		light.position = Vector3(0.0, config.module_height_m * 0.5, lerp(-config.module_depth_m, 0.0, t))
		light.light_color = config.interior_light_color
		light.omni_range = config.interior_light_range_m
		light.light_energy = config.interior_light_energy
		add_child(light)
