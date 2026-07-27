## Один модуль/коридор кольца: строит свою 45°-дугу через StationMeshBuilder
## (пол, потолок, боковые стены + коллизии) по собственным angle_start/end_deg,
## хранит идентификатор и точку спавна. Мешу и коллизии не хранит сам —
## делегирует расчёт StationMeshBuilder (данные отдельно от поведения). FR-30..FR-33, FR-39
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

@onready var spawn_point: Marker3D = $Spawn
@onready var _hull: MeshInstance3D = $Hull
## AnimatableBody3D, не StaticBody3D: этот узел лежит под RotatingRing и
## непрерывно вращается — движущийся StaticBody3D физика Jolt трактует как
## неподвижный для broadphase и не пересчитывает контакты корректно.
@onready var _collision_root: AnimatableBody3D = $Collision

func _ready() -> void:
	_build_geometry()

func _build_geometry() -> void:
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
	var chord_len_m: float = StationMeshBuilder.ring_arc_chord_length(
			angle_start_rad, angle_end_rad, mid_radius_m, config.arc_segment_count)
	var shape := BoxShape3D.new()
	shape.size = Vector3(chord_len_m, config.tube_width_m, config.deck_height_m)

	var transforms: Array[Transform3D] = StationMeshBuilder.ring_arc_collision_transforms(
			angle_start_rad, angle_end_rad, mid_radius_m, config.arc_segment_count)
	for local_transform in transforms:
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		collision_shape.transform = local_transform
		_collision_root.add_child(collision_shape)

	_build_interior_lights(angle_start_rad, angle_end_rad, mid_radius_m)

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
