## Барабан вращающейся части гантелеобразной станции (см. отчёт о ревизии
## конфигурации 0.1.1): несёт 2 симметричных плеча (коридор → жилой/рабочий
## модуль) через 2 коннектора на своей боковой поверхности — Connector_ArmHabitat
## на угле 0°, Connector_ArmWork на угле 180° — станция стыкует коридоры к
## ним (station_docking.gd), а не через жёсткий Transform3D-перебор в
## station_dumbbell.tscn (как раньше делал dumbbell_arm_layout.gd).
##
## Собственная сцена модульной сборки — раньше барабан был инлайн-узлами
## (MeshInstance3D/CollisionShape3D) прямо в station_dumbbell.tscn.
## AnimatableBody3D, не Node3D+StaticBody3D: как и StationModule._collision_root
## (см. его комментарий) — этот узел лежит под RotatingRing и непрерывно
## вращается, движущийся StaticBody3D физика Jolt трактует как неподвижный
## для broadphase.
@tool
class_name DrumModule
extends AnimatableBody3D

@export var dumbbell_config: DumbbellStationConfig
@export var hull_material: Material

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $Collision

func _ready() -> void:
	var radius_m: float = dumbbell_config.drum_radius_m
	var length_m: float = dumbbell_config.drum_length_m

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_m
	cylinder.bottom_radius = radius_m
	cylinder.height = length_m
	cylinder.radial_segments = dumbbell_config.segment_count
	_mesh_instance.mesh = cylinder
	if hull_material != null:
		_mesh_instance.material_override = hull_material

	var shape := CylinderShape3D.new()
	shape.radius = radius_m
	shape.height = length_m
	_collision.shape = shape

	StationConnector.ensure(self, "Connector_ArmHabitat", _radial_connector_transform(0.0, radius_m))
	StationConnector.ensure(self, "Connector_ArmWork", _radial_connector_transform(PI, radius_m))

## Барабан — неподвижный якорь внутри вращающегося RotatingRing: сам он
## никогда не должен иметь собственного поворота относительно родителя (весь
## поворот несёт RotatingRing.rotation.y, см. ring_rotator.gd), к его
## коннекторам жёстко пристыкованы коридоры/модули (station_dumbbell_assembly.gd)
## один раз при старте — их transform НЕ отслеживает барабан впоследствии.
##
## Воспроизведено эмпирически: пока RotatingRing реально вращается (не
## заморожен на epoch=0), Jolt у этого AnimatableBody3D (sync_to_physics=true,
## ребёнок непрерывно поворачивающегося родителя) через несколько физических
## кадров стабильно сообщает узлу самопроизвольный, далее замороженный
## паразитный поворот (~-10° по Y) — источник не установлен (перебраны и
## отвергнуты: очерёдность стыковки жилого/рабочего модуля через
## call_deferred, самостоятельный запуск сцены без GameClock/RotatingRing);
## похоже на квирк Jolt при процедурно назначенной форме коллизии у
## kinematic-тела с непрерывно вращающимся родителем — см. базу знаний Godot,
## запись 22 (родственно записи 21 — тот же почерк: AnimatableBody3D +
## sync_to_physics даёт аномальную скорость/поворот, но без транспорт-скачка
## как триггера). Раз уже пристыкованные к барабану коридоры
## СВОЙ transform не меняют, любой самостоятельный поворот барабана после
## стыковки — всегда рассинхронизация (видимый шов между барабаном и
## коридором), поэтому проще и надёжнее не искать источник, а держать
## инвариант "поворота относительно RotatingRing нет" явно, каждый кадр.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	transform = Transform3D.IDENTITY

## Коннектор на боковой поверхности барабана на угле angle_rad: локальная +Y —
## радиально наружу (та же ось-конвенция, что и у коридора/дуговой комнаты
## для стыковки — X касательная, Z вдоль главной оси станции). Базис строится
## в коде (Basis(x,y,z) берёт столбцы корректно) — тот же приём, которым
## раньше dumbbell_arm_layout.gd размещал плечи напрямую.
func _radial_connector_transform(angle_rad: float, radius_m: float) -> Transform3D:
	var radial_dir := Vector3(cos(angle_rad), 0.0, sin(angle_rad))
	var tangent_dir := Vector3(-sin(angle_rad), 0.0, cos(angle_rad))
	var basis := Basis(tangent_dir, radial_dir, Vector3.UP)
	return Transform3D(basis, radial_dir * radius_m)
