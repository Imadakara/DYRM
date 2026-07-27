## Сборка и обновление всех небесных тел. Добавление нового тела не требует
## изменения кода (NFR-06) — только нового CelestialBodyData.tres в body_resources.
class_name SolarSystem
extends Node3D

## Испускается после пересчёта положений всех тел на новый epoch_days.
signal bodies_updated()

## Ресурсы тел в порядке создания дочерних CelestialBody: Солнце, 8 планет, Тритон
## (таблица 6.3.2). Родство (Тритон → Нептун) определяется полем parent_body. FR-10
@export var body_resources: Array[CelestialBodyData] = []

## Источник игрового времени (см. main.tscn) — SolarSystem не является автозагрузкой,
## ссылка проставляется извне через @export NodePath. FR-19
@export var game_clock_path: NodePath

## Узел станции — точка наблюдения для направлений и расстояний. Устанавливается
## в main.tscn: SolarSystem не обязан знать структуру станции. FR-15
@export var observer_path: NodePath

var _bodies: Array[CelestialBody] = []
var _bodies_by_id: Dictionary = {}
var _game_clock: GameClock
var _observer: StationRoot

func _ready() -> void:
	_game_clock = get_node_or_null(game_clock_path) as GameClock
	_observer = get_node_or_null(observer_path) as StationRoot
	_build_bodies()
	if _game_clock != null:
		_game_clock.time_changed.connect(update_positions)
		update_positions(_game_clock.epoch_days)
	else:
		update_positions(0.0)

func _build_bodies() -> void:
	for data in body_resources:
		var body := CelestialBody.new()
		body.name = String(data.body_id).capitalize()
		body.data = data
		add_child(body)
		_bodies.append(body)
		_bodies_by_id[data.body_id] = body
	for body in _bodies:
		if body.data.parent_body != &"":
			body.parent = _bodies_by_id.get(body.data.parent_body)

## Пересчитывает положения всех тел на заданный игровой момент, км. Родительские
## тела обновляются первыми, чтобы дочерние (Тритон) складывали своё смещение
## с уже актуальным положением родителя (Нептуна). FR-19, NFR-08
func update_positions(epoch_days: float) -> void:
	for body in _bodies:
		if body.parent == null:
			body.update_position(epoch_days)
	for body in _bodies:
		if body.parent != null:
			body.update_position(epoch_days)
	bodies_updated.emit()

func get_bodies() -> Array[CelestialBody]:
	return _bodies

func get_body(id: StringName) -> CelestialBody:
	return _bodies_by_id.get(id)

## Гелиоцентрическое положение станции, км — точка наблюдения для всей системы. FR-15
func observer_position_km() -> Vector3:
	if _observer == null:
		return Vector3.ZERO
	return _observer.position_km()
