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
## Контейнер для процедурно генерируемых стеновых сегментов (см.
## _build_hollow_collision()) — не сам коллайдер, коллизию несут его дети.
@onready var _collision_root: Node3D = $Collision

func _ready() -> void:
	var radius_m: float = dumbbell_config.drum_radius_m
	var length_m: float = dumbbell_config.drum_length_m

	# build_tube_wall_mesh()/tube_wall_collision_transforms() кладут трубу с
	# ближним торцом на локальном y=0, до y=length_m — а собственный локальный
	# ноль барабана уже занят серединой (коннекторы Connector_ArmHabitat/
	# Connector_ArmWork стоят на y=0 в _radial_connector_transform()), поэтому
	# и меш, и коллизию центрируем сдвигом на -length_m*0.5.
	_mesh_instance.mesh = DumbbellMeshBuilder.build_tube_wall_mesh(radius_m, length_m, dumbbell_config.segment_count)
	_mesh_instance.position = Vector3(0.0, -length_m * 0.5, 0.0)
	if hull_material != null:
		_mesh_instance.material_override = hull_material

	_build_hollow_collision(radius_m, length_m)

	StationConnector.ensure(self, "Connector_ArmHabitat", _radial_connector_transform(0.0, radius_m))
	StationConnector.ensure(self, "Connector_ArmWork", _radial_connector_transform(PI, radius_m))

## Барабан — ПОЛАЯ труба (кольцо гранёных стеновых сегментов, тот же приём,
## что у CylindricalStationModule/StationModule), а не сплошной CylinderShape3D
## барабана целиком: сквозь его ось проходит невесомый интерьер втулки (hub,
## ТЗ-000 §17.3) — центр hub (радиус 3 м) физически лежит ВНУТРИ радиуса
## барабана (4 м), на той же оси. Сплошной цилиндр полностью перекрывал бы
## пространство, где должен свободно летать игрок. Обнаружено эмпирически при
## адаптации ТЗ-100 под гантелеобразную станцию: капсула игрока, заспавненная
## в центре hub, оказывалась встроена в сплошную коллизию барабана, и Jolt
## депенетрацией выталкивал её вдоль оси на всю полудлину барабана — ровно на
## границу antenna/hub или hub/transmission (T-29 сообщал ложный current_module).
## Оба торца трубы остаются открытыми (без крышек) — hub целиком без коллизии
## на границах, игрок телепортируется через люк, а не идёт пешком (та же
## логика, что и у коридора плеча).
func _build_hollow_collision(radius_m: float, length_m: float) -> void:
	for child in _collision_root.get_children():
		child.free()
	var wall_shape := BoxShape3D.new()
	var chord_len: float = DumbbellMeshBuilder.wall_chord_length(radius_m, dumbbell_config.segment_count)
	wall_shape.size = Vector3(chord_len, length_m, dumbbell_config.wall_thickness_m)
	for local_transform in DumbbellMeshBuilder.tube_wall_collision_transforms(radius_m, length_m, dumbbell_config.segment_count):
		var cs := CollisionShape3D.new()
		cs.shape = wall_shape
		var t: Transform3D = local_transform
		t.origin.y -= length_m * 0.5
		cs.transform = t
		_collision_root.add_child(cs)

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
