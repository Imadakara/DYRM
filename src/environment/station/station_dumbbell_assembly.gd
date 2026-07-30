## Собирает гантелеобразную станцию из независимых элементов-сцен (антенна/
## втулка/передача/барабан/коридор/жилой/рабочий модуль) через их коннекторы
## (station_connector.gd), а не жёстко прописанными Transform3D — см. отчёт о
## ревизии конфигурации 0.1.1, третье уточнение: "станция должна собираться
## как модульный конструктор со взаимозаменяемыми элементами". Меняя
## геометрию/размер одного элемента (например, длину антенного модуля или
## радиус дуговой комнаты), соседние элементы подстраиваются сами при
## следующей пересборке — переставлять числа в station_dumbbell.tscn не нужно.
##
## Единственное место, которое явно знает топологию станции целиком (что к
## чему пристыковано) — читается как сборочный чертёж. Втулка (hub_path) и
## барабан (drum_path) — единственные два "заякоренных" элемента (их
## собственный transform в сцене не трогается); всё остальное стыкуется к
## ним или друг к другу.
##
## Порядок вызова: должен идти ПОСЛЕДНИМ среди детей StationDumbbell (см.
## порядок узлов в station_dumbbell.tscn) — Godot вызывает _ready() у
## потомков раньше родителей и у родных братьев по порядку в дереве, поэтому
## к моменту вызова этого _ready() у всех элементов уже созданы собственные
## коннекторы их же _build_geometry()/_ready().
@tool
class_name StationDumbbellAssembly
extends Node3D

@export var antenna_path: NodePath
@export var hub_path: NodePath
@export var transmission_path: NodePath
@export var drum_path: NodePath
@export var habitat_corridor_path: NodePath
@export var habitat_module_path: NodePath
@export var work_corridor_path: NodePath
@export var work_module_path: NodePath

func _ready() -> void:
	var antenna: StationModule = get_node(antenna_path)
	var hub: Node3D = get_node(hub_path)
	var transmission: StationModule = get_node(transmission_path)
	var drum: Node3D = get_node(drum_path)
	var habitat_corridor: Node3D = get_node(habitat_corridor_path)
	var habitat_module: StationModule = get_node(habitat_module_path)
	var work_corridor: Node3D = get_node(work_corridor_path)
	var work_module: StationModule = get_node(work_module_path)

	# Неподвижный ствол: втулка (hub) остаётся на своём месте в сцене как
	# точка отсчёта, антенна и модуль передачи стыкуются к её торцам.
	StationDocking.dock(antenna, antenna.get_node("Connector_Near"), hub.get_node("Connector_Near"))
	StationDocking.dock(transmission, transmission.get_node("Connector_Near"), hub.get_node("Connector_Far"))

	# Вращающийся барабан (drum) — тоже точка отсчёта; 2 симметричных плеча
	# коридор→модуль стыкуются к его коннекторам.
	StationDocking.dock(habitat_corridor, habitat_corridor.get_node("Connector_Inner"),
			drum.get_node("Connector_ArmHabitat"))
	StationDocking.dock(habitat_module, habitat_module.get_node("Connector_Corridor"),
			habitat_corridor.get_node("Connector_Outer"))

	StationDocking.dock(work_corridor, work_corridor.get_node("Connector_Inner"),
			drum.get_node("Connector_ArmWork"))
	StationDocking.dock(work_module, work_module.get_node("Connector_Corridor"),
			work_corridor.get_node("Connector_Outer"))

	# См. StationModule.rebuild_collision_registration(): каждый из этих 4
	# модулей (не hub/drum — те свой transform не меняют, не при делах;
	# не коридоры — у них нет коллизии) только что переставлен докингом
	# на финальную позицию ОДНИМ кадром, до первого _physics_process().
	# Пересоздаём их AnimatableBody3D в PhysicsServer3D с нуля УЖЕ на этой
	# позиции, а не полагаемся на его "переезд" при первом же кадре.
	antenna.rebuild_collision_registration()
	transmission.rebuild_collision_registration()
	habitat_module.rebuild_collision_registration()
	work_module.rebuild_collision_registration()
