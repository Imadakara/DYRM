## Каркас рабочей панели рубки (ТЗ-100, раздел 7.1.4): SubViewport с UI,
## рендер на плоский меш, перевод точки попадания луча в пиксель (6.4.4),
## доставка событий мыши как штатных InputEvent (FR-42). Панель — контейнер,
## а не содержимое: что показано, определяют другие ТЗ через set_ui_scene().
class_name WorkPanel
extends Interactable

signal input_capture_changed(captured: bool)

## Идентификатор панели из таблицы 6.3.4 (registrar, decoder, ... star_map).
@export var panel_id: StringName = &""
@export var display_name: String = ""
## Номер ответственного ТЗ для заглушки «НЕТ СИГНАЛА» (пусто для диагностической панели).
@export var responsible_tz: String = ""
@export var config: PanelConfig
## Маркер монтажа (сосед на сцене) — если задан, панель монтируется на него
## автоматически (7.7.2: маркеры задаёт ТЗ-000). Пусто — панель уже размещена
## авторски (диагностическая панель в engineering).
@export var mount_marker_path: NodePath
@export var station_path: NodePath
## Материал рамки — задаётся на уровне сцены (жёлтый у диагностической, ART-03).
@export var frame_material: Material
## Если задано — панель сразу показывает это содержимое, а не заглушку
## (используется диагностической панелью).
@export var initial_content: PackedScene

@onready var _frame: MeshInstance3D = $Frame
@onready var _screen: MeshInstance3D = $Screen
@onready var _viewport: SubViewport = $SubViewport
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visibility_notifier: VisibleOnScreenNotifier3D = $Screen/VisibleOnScreenNotifier3D

var _content_root: Control
var _is_placeholder: bool = true
var _input_captured: bool = false
var _last_pointer_px: Vector2 = Vector2(-1.0, -1.0)

func _ready() -> void:
	# _ready() выполняется снизу вверх: WorkPanel — потомок StationRoot, и на
	# момент его собственного _ready() @onready-поля StationRoot (в т.ч.
	# get_rotating_ring()) ещё не инициализированы. call_deferred откладывает
	# монтаж до конца текущего кадра, когда вся сцена уже готова.
	call_deferred(&"_mount")
	_setup_geometry()
	_setup_collision()
	_setup_viewport()
	_setup_visibility()
	if initial_content != null:
		set_ui_scene(initial_content)
	else:
		set_ui_scene(null)

## Ориентация по маркеру: +Y — «верх» из StationRoot (принцип 7.1.1), +Z —
## наружу от осевой линии прохода кольца (боковые стены рубки, см. отчёт).
func _mount() -> void:
	if mount_marker_path.is_empty():
		return
	var marker: Node3D = get_node_or_null(mount_marker_path) as Node3D
	var station: StationRoot = get_node_or_null(station_path) as StationRoot
	if marker == null or station == null:
		return
	var ring: Node3D = station.get_rotating_ring()
	if ring == null:
		return
	var up: Vector3 = station.get_gravity_up_at(marker.global_position)
	var ring_axis: Vector3 = ring.global_transform.basis.y
	var offset_along_axis: float = (marker.global_position - ring.global_position).dot(ring_axis)
	var axis_sign: float = -1.0 if offset_along_axis >= 0.0 else 1.0
	var forward: Vector3 = ring_axis * axis_sign
	var right: Vector3 = up.cross(forward)
	if right.length() < DEGENERATE_EPS:
		right = Vector3.RIGHT
	right = right.normalized()
	forward = right.cross(up)
	global_transform = Transform3D(Basis(right, up, forward), marker.global_position)

const DEGENERATE_EPS: float = 1e-4

func _setup_geometry() -> void:
	var screen_mesh := QuadMesh.new()
	screen_mesh.size = config.surface_size_m
	_screen.mesh = screen_mesh

	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(
			config.surface_size_m.x + config.frame_thickness_m * 2.0,
			config.surface_size_m.y + config.frame_thickness_m * 2.0,
			config.frame_depth_m)
	_frame.mesh = frame_mesh
	_frame.position = Vector3(0.0, 0.0, -config.frame_depth_m * 0.5)
	if frame_material != null:
		_frame.material_override = frame_material

func _setup_collision() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(config.surface_size_m.x, config.surface_size_m.y, config.frame_depth_m)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 0.0, -config.frame_depth_m * 0.5)

func _setup_viewport() -> void:
	_viewport.size = config.viewport_size_px
	_viewport.transparent_bg = false
	var screen_material := preload("res://materials/mat_panel_screen.tres").duplicate() as StandardMaterial3D
	screen_material.albedo_texture = _viewport.get_texture()
	screen_material.emission_texture = _viewport.get_texture()
	_screen.material_override = screen_material

func _setup_visibility() -> void:
	if _visibility_notifier == null:
		return
	var half_depth: float = config.frame_depth_m * 0.5
	_visibility_notifier.aabb = AABB(
			Vector3(-config.surface_size_m.x * 0.5, -config.surface_size_m.y * 0.5, -half_depth),
			Vector3(config.surface_size_m.x, config.surface_size_m.y, config.frame_depth_m))
	_visibility_notifier.screen_entered.connect(_on_screen_entered)
	_visibility_notifier.screen_exited.connect(_on_screen_exited)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if _visibility_notifier.is_on_screen() else SubViewport.UPDATE_DISABLED

func _on_screen_entered() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

func _on_screen_exited() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

## Замена содержимого целиком (FR-44). scene == null восстанавливает заглушку
## «НЕТ СИГНАЛА» (используется автотестом AC-44 для отката).
func set_ui_scene(scene: PackedScene) -> void:
	if _content_root != null:
		_content_root.queue_free()
		_content_root = null

	var scene_to_load: PackedScene = scene
	var is_placeholder: bool = false
	if scene_to_load == null:
		scene_to_load = load("res://scenes/panels/panel_placeholder.tscn")
		is_placeholder = true

	var instance: Node = scene_to_load.instantiate()
	_content_root = instance as Control
	_viewport.add_child(_content_root)
	# Control заполняет SubViewport через anchors_preset=15 (0,0,1,1) в своей
	# сцене — явная установка .size избыточна и вызывает предупреждение движка.
	if is_placeholder and _content_root != null and _content_root.has_method(&"set_responsible_tz"):
		_content_root.call(&"set_responsible_tz", responsible_tz)
	_is_placeholder = is_placeholder

func get_ui_root() -> Control:
	return _content_root

## Перевод точки попадания луча (мировые координаты) в пиксель SubViewport,
## формула 6.4.4. Vector2(-1, -1), если точка вне поверхности.
func surface_to_viewport(world_point: Vector3) -> Vector2:
	var local: Vector3 = to_local(world_point)
	var w: float = config.surface_size_m.x
	var h: float = config.surface_size_m.y
	var u: float = local.x / w + 0.5
	var v: float = 0.5 - local.y / h
	if u < -DEGENERATE_EPS or u > 1.0 + DEGENERATE_EPS or v < -DEGENERATE_EPS or v > 1.0 + DEGENERATE_EPS:
		return Vector2(-1.0, -1.0)
	return Vector2(clampf(u, 0.0, 1.0) * config.viewport_size_px.x, clampf(v, 0.0, 1.0) * config.viewport_size_px.y)

func request_input_capture(on: bool) -> void:
	if _input_captured == on:
		return
	_input_captured = on
	input_capture_changed.emit(_input_captured)

func is_input_captured() -> bool:
	return _input_captured

func is_capturing_input() -> bool:
	return _input_captured

func has_content() -> bool:
	return not _is_placeholder

## FR-42: перекрестье, наведённое на панель, транслируется в движение мыши
## внутри SubViewport — обычный Control работает без доработок.
func receive_pointer(hit_valid: bool, world_point: Vector3) -> void:
	if not hit_valid:
		return
	var px: Vector2 = surface_to_viewport(world_point)
	if px.x < 0.0:
		return
	_last_pointer_px = px
	var motion := InputEventMouseMotion.new()
	motion.position = px
	motion.global_position = px
	_viewport.push_input(motion, true)

func receive_click(pressed: bool) -> void:
	if _last_pointer_px.x < 0.0:
		return
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = _last_pointer_px
	mb.global_position = _last_pointer_px
	_viewport.push_input(mb, true)
