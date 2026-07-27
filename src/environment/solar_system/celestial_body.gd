## Небесное тело: собственное гелиоцентрическое (или планетоцентрическое, для лун)
## положение в километрах и вращение вокруг оси. Не отвечает за рендер в слое
## Deep — этим занимается ScaledSpaceLayer, читая position_km извне.
class_name CelestialBody
extends Node3D

@export var data: CelestialBodyData

## Положение тела в километрах, мировые оси Godot (после ecliptic_to_godot).
## Для тела с parent_body — уже сложено с положением родителя (гелиоцентрическое). FR-15
var position_km: Vector3 = Vector3.ZERO

## Ссылка на родительское тело (Солнце для планет, Нептун для Тритона) —
## проставляется SolarSystem при сборке. Пусто для Солнца.
var parent: CelestialBody = null

func update_position(epoch_days: float) -> void:
	if data.orbit == null:
		position_km = Vector3.ZERO
	else:
		var ecl: Vector3 = OrbitalMath.position_at(data.orbit, epoch_days)
		var local_km: Vector3 = OrbitalMath.ecliptic_to_godot(ecl)
		position_km = local_km if parent == null else parent.position_km + local_km

## Вращение вокруг собственной оси на данный игровой момент, радианы.
## Отрицательный rotation_period_days даёт отрицательный (ретроградный) угол. FR-13
func axial_rotation_rad(epoch_days: float) -> float:
	if data.rotation_period_days == 0.0:
		return 0.0
	return TAU * epoch_days / data.rotation_period_days

## Расстояние до наблюдателя, км.
func distance_from(observer_km: Vector3) -> float:
	return position_km.distance_to(observer_km)

## Единичный вектор направления от наблюдателя к телу, мировые оси Godot. FR-15
func direction_from(observer_km: Vector3) -> Vector3:
	var offset: Vector3 = position_km - observer_km
	if offset.length_squared() < 1e-9:
		return Vector3.FORWARD
	return offset.normalized()

## Видимый угловой диаметр тела с точки наблюдателя, градусы (реальный, без
## порога min_angular_diameter — тот применяется только в слое Deep). FR-15
func angular_diameter_deg(observer_km: Vector3) -> float:
	var d: float = distance_from(observer_km)
	if d < 1e-6:
		return 180.0
	return rad_to_deg(2.0 * atan(data.radius_km / d))
