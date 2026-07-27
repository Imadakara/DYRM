## Чистые функции орбитальной механики: решение уравнения Кеплера, положение тела
## по кеплеровым элементам, перевод эклиптики J2000 в мировые оси Godot.
## Статический класс без состояния — не хранит и не рендерит ничего. FR-11, A-01
class_name OrbitalMath
extends RefCounted

## Километров в одной астрономической единице (IAU 2012).
const KM_PER_AU: float = 149_597_870.7

## Решает уравнение Кеплера E - e*sin(E) = M методом Ньютона (формула 6.4.1). FR-11
static func solve_kepler(mean_anomaly_rad: float, eccentricity: float) -> float:
	var m: float = mean_anomaly_rad
	var e: float = eccentricity
	var ecc_anomaly: float = m + e * sin(m)
	for _i in range(30):
		var delta: float = ecc_anomaly - e * sin(ecc_anomaly) - m
		var derivative: float = 1.0 - e * cos(ecc_anomaly)
		var correction: float = delta / derivative
		ecc_anomaly -= correction
		if absf(correction) < 1e-10:
			break
	return ecc_anomaly

## Положение тела в эклиптических координатах J2000 (км), формулы 6.4.1-6.4.2.
## Вековые рейты не применяются (A-01) — только фазовый сдвиг по среднему движению.
static func position_at(elements: OrbitalElements, epoch_days: float) -> Vector3:
	var a: float = elements.semi_major_axis_km
	var e: float = elements.eccentricity
	var i_rad: float = deg_to_rad(elements.inclination_deg)

	var mean_longitude_deg: float = elements.mean_longitude_deg
	mean_longitude_deg += 360.0 * epoch_days / elements.period_days

	var mean_anomaly_deg: float = mean_longitude_deg - elements.longitude_perihelion_deg
	mean_anomaly_deg = wrapf(mean_anomaly_deg, -180.0, 180.0)
	var mean_anomaly_rad: float = deg_to_rad(mean_anomaly_deg)

	var ecc_anomaly: float = solve_kepler(mean_anomaly_rad, e)

	var x_orb: float = a * (cos(ecc_anomaly) - e)
	var y_orb: float = a * sqrt(1.0 - e * e) * sin(ecc_anomaly)

	var node_rad: float = deg_to_rad(elements.longitude_node_deg)
	var arg_perihelion_rad: float = deg_to_rad(elements.longitude_perihelion_deg) - node_rad

	var cos_w: float = cos(arg_perihelion_rad)
	var sin_w: float = sin(arg_perihelion_rad)
	var cos_o: float = cos(node_rad)
	var sin_o: float = sin(node_rad)
	var cos_i: float = cos(i_rad)
	var sin_i: float = sin(i_rad)

	var x: float = (cos_w * cos_o - sin_w * sin_o * cos_i) * x_orb \
			+ (-sin_w * cos_o - cos_w * sin_o * cos_i) * y_orb
	var y: float = (cos_w * sin_o + sin_w * cos_o * cos_i) * x_orb \
			+ (-sin_w * sin_o + cos_w * cos_o * cos_i) * y_orb
	var z: float = (sin_w * sin_i) * x_orb + (cos_w * sin_i) * y_orb

	return Vector3(x, y, z)

## Единственное место в проекте, где плоскость эклиптики J2000 отображается
## в плоскость XZ Godot. Не дублировать это преобразование больше нигде.
static func ecliptic_to_godot(ecl: Vector3) -> Vector3:
	return Vector3(ecl.x, ecl.z, -ecl.y)
