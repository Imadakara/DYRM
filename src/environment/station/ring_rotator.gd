## Вращает узел вокруг локальной оси +Y с постоянной угловой скоростью,
## вычисленной из целевой гравитации (формула 6.4.5: ω = sqrt(a_target / R)).
## Угол поворота — чистая функция от epoch_days (NFR-08), а не от реального
## времени кадра: ускорение времени ([ / ]) корректно ускоряет и вращение
## кольца, как и положения небесных тел. Ступица, спицы и неподвижная ферма
## НЕ являются потомками этого узла — они despun (FR-23).
class_name RingRotator
extends Node3D

## g на Земле, м/с² — используется только для перевода target_gravity_g в м/с².
const G_EARTH_M_S2: float = 9.80665
const SECONDS_PER_DAY: float = 86400.0

@export var config: StationConfig
@export var game_clock_path: NodePath

## Угловая скорость вращения кольца, рад/с — вычисляется, не задаётся вручную. FR-22
var angular_velocity_rad_s: float = 0.0

var _game_clock: GameClock

func _ready() -> void:
	var target_accel_m_s2: float = config.target_gravity_g * G_EARTH_M_S2
	angular_velocity_rad_s = sqrt(target_accel_m_s2 / config.ring_radius_m)

	_game_clock = get_node_or_null(game_clock_path) as GameClock
	if _game_clock != null:
		_game_clock.time_changed.connect(_update_rotation)
		_update_rotation(_game_clock.epoch_days)

func _update_rotation(epoch_days: float) -> void:
	var elapsed_s: float = epoch_days * SECONDS_PER_DAY
	rotation.y = wrapf(angular_velocity_rad_s * elapsed_s, 0.0, TAU)

## Текущий угол поворота кольца, радианы, нормирован в [0, TAU).
func rotation_angle_rad() -> float:
	return wrapf(rotation.y, 0.0, TAU)
