## Сжатие расстояний слоя Deep. Статический класс без состояния: сжимается
## только радиальная координата, направление на объект остаётся точным. FR-04
class_name SpaceScale
extends RefCounted

## Сжатое расстояние для слоя Deep, юниты Godot. Формула 6.4.3.
static func compress_distance(distance_km: float, cfg: SpaceScaleConfig) -> float:
	return cfg.compression_k * log(1.0 + distance_km / cfg.compression_d0_km)

## Видимый радиус прокси-сферы тела в слое Deep, юниты Godot. Формула 6.4.4.
## Пока реальный угловой размер выше порога — размер физически точен;
## ниже порога — фиксируется на min_angular_diameter_deg. FR-05
static func render_radius(radius_km: float, distance_km: float, cfg: SpaceScaleConfig) -> float:
	var real_angle_rad: float = 2.0 * atan(radius_km / distance_km)
	var min_angle_rad: float = deg_to_rad(cfg.min_angular_diameter_deg)
	var angle_rad: float = maxf(real_angle_rad, min_angle_rad)
	var render_distance: float = compress_distance(distance_km, cfg)
	return render_distance * tan(angle_rad * 0.5)

## Полное положение прокси тела в слое Deep. direction_km — вектор наблюдатель→тело
## в километрах (мировые оси Godot, уже после ecliptic_to_godot). Направление
## сохраняется точно — сжимается только длина вектора. FR-04
static func deep_position(direction_km: Vector3, cfg: SpaceScaleConfig) -> Vector3:
	var distance_km: float = direction_km.length()
	if distance_km < 0.001:
		return Vector3.ZERO
	var dir_unit: Vector3 = direction_km / distance_km
	var render_distance: float = compress_distance(distance_km, cfg)
	return dir_unit * render_distance
