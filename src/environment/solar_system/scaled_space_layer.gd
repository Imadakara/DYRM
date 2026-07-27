## Слой дальнего космоса: отдельный SubViewport с собственным World3D. Камера
## слоя Deep каждый кадр копирует поворот и FOV основной камеры, но остаётся
## в начале координат СВОЕГО мира (FR-03) — это устраняет параллакс от смещения
## основной камеры в пределах Local (радиус 2000 м), который иначе заметно
## искажал бы направление на объекты, удалённые на миллиарды км.
##
## Композитинг с Local (FR-02): в Godot 2D-канвас всегда рисуется поверх 3D
## в пределах одного Viewport, поэтому "фон позади 3D" сделан не 2D-слоем
## (как буквально названо в ТЗ-000, 7.3, где класс типизирован как Control),
## а полноэкранным квадом внутри самого Local-мира: квад висит перед камерой,
## сэмплит текстуру SubViewport'а по SCREEN_UV, depth-тест и запись глубины
## отключены — реальная геометрия станции, нарисованная после, всегда
## перекрывает его. Отсюда отступление от типа "Control" к Node3D — публичного
## API у класса нет (раздел 7.4 его не перечисляет), другие системы на тип
## не рассчитывают.
class_name ScaledSpaceLayer
extends Node3D

@export var config: SpaceScaleConfig
@export var solar_system_path: NodePath
@export var main_camera_path: NodePath
@export var body_material: ShaderMaterial
@export var background_material: ShaderMaterial

## MeshInstance3D-квад, живущий ПОД MainCamera в main.tscn (не в этой сцене) —
## только так он ригидно следует за камерой независимо от её положения/поворота.
@export var background_quad_path: NodePath

@export var star_count: int = 3200
@export var starfield_seed: int = 20260726
@export var kuiper_point_count: int = 2000
@export var kuiper_min_au: float = 30.0
@export var kuiper_max_au: float = 50.0

@onready var _viewport: SubViewport = $DeepViewport
@onready var _deep_camera: Camera3D = $DeepViewport/DeepCamera
@onready var _starfield: MeshInstance3D = $DeepViewport/Starfield
@onready var _kuiper_belt: MultiMeshInstance3D = $DeepViewport/KuiperBelt
@onready var _bodies_root: Node3D = $DeepViewport/Bodies

var _solar_system: SolarSystem
var _main_camera: Camera3D
var _proxy_by_id: Dictionary = {}
var _unit_sphere: SphereMesh
var _background_material_instance: ShaderMaterial

func _ready() -> void:
	_solar_system = get_node_or_null(solar_system_path) as SolarSystem
	_main_camera = get_node_or_null(main_camera_path) as Camera3D

	_deep_camera.near = config.deep_near
	_deep_camera.far = config.deep_far
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync_viewport_size()
	get_viewport().size_changed.connect(_sync_viewport_size)

	_unit_sphere = SphereMesh.new()
	_unit_sphere.radius = 1.0
	_unit_sphere.height = 2.0
	_unit_sphere.radial_segments = 24
	_unit_sphere.rings = 16

	_starfield.mesh = StarfieldBuilder.build(star_count, starfield_seed)
	_starfield.material_override = _make_point_material(2.0)

	_build_kuiper_belt()

	_background_material_instance = background_material.duplicate()
	_background_material_instance.set_shader_parameter("deep_texture", _viewport.get_texture())
	var background_quad: MeshInstance3D = get_node_or_null(background_quad_path) as MeshInstance3D
	if background_quad != null:
		background_quad.material_override = _background_material_instance

	if _solar_system != null:
		_build_body_proxies()
		_solar_system.bodies_updated.connect(_update_body_proxies)
		_update_body_proxies()

func _process(_delta: float) -> void:
	if _main_camera == null:
		return
	# Позиция Deep-камеры фиксирована в начале координат её мира — переносится
	# только поворот и FOV основной камеры. FR-03
	_deep_camera.global_transform = Transform3D(_main_camera.global_transform.basis, Vector3.ZERO)
	_deep_camera.fov = _main_camera.fov

func _sync_viewport_size() -> void:
	_viewport.size = get_viewport().size

func _build_body_proxies() -> void:
	for body in _solar_system.get_bodies():
		var proxy := MeshInstance3D.new()
		proxy.name = String(body.data.body_id).capitalize()
		proxy.mesh = _unit_sphere
		var mat: ShaderMaterial = body_material.duplicate()
		mat.set_shader_parameter("base_color", body.data.base_color)
		mat.set_shader_parameter("emissive", body.data.emissive)
		proxy.material_override = mat
		_bodies_root.add_child(proxy)
		_proxy_by_id[body.data.body_id] = proxy

func _update_body_proxies() -> void:
	var observer_km: Vector3 = _solar_system.observer_position_km()
	var sun: CelestialBody = _solar_system.get_body(&"sun")
	for body in _solar_system.get_bodies():
		var proxy: MeshInstance3D = _proxy_by_id.get(body.data.body_id)
		if proxy == null:
			continue
		var offset_km: Vector3 = body.position_km - observer_km
		proxy.position = SpaceScale.deep_position(offset_km, config)
		var radius: float = SpaceScale.render_radius(body.data.radius_km, offset_km.length(), config)
		proxy.scale = Vector3.ONE * radius
		if sun != null and body != sun:
			var mat: ShaderMaterial = proxy.material_override
			mat.set_shader_parameter("light_direction", (sun.position_km - body.position_km).normalized())

func _build_kuiper_belt() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = starfield_seed + 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _make_kuiper_point_mesh()
	multimesh.instance_count = kuiper_point_count
	for i in range(kuiper_point_count):
		var au: float = rng.randf_range(kuiper_min_au, kuiper_max_au)
		var distance_km: float = au * OrbitalMath.KM_PER_AU
		var dir := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 0.15), rng.randfn(0.0, 1.0)).normalized()
		var render_distance: float = SpaceScale.compress_distance(distance_km, config)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, dir * render_distance))
	_kuiper_belt.multimesh = multimesh
	_kuiper_belt.material_override = _make_point_material(1.5)

static func _make_kuiper_point_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.4
	m.height = 0.8
	m.radial_segments = 6
	m.rings = 4
	return m

static func _make_point_material(size: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.use_point_size = true
	mat.point_size = size
	return mat
