## Камера игрока: рыскание передаётся PlayerController (вращает тело), тангаж,
## FOV и покачивание при ходьбе — здесь (ТЗ-100, раздел 7.3). Тело не двигает.
class_name PlayerCamera
extends Camera3D

@export var config: PlayerConfig

var _pitch_deg: float = 0.0
var _bob_phase_rad: float = 0.0

func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = config.fov_deg
	rotation = Vector3.ZERO
	position = Vector3.ZERO

func _process(_delta: float) -> void:
	# FR-25: живая правка FOV в запущенном проекте должна быть видна немедленно (7.7.2).
	fov = config.fov_deg

func add_pitch_deg(delta_deg: float) -> void:
	set_pitch_deg(_pitch_deg + delta_deg)

## FR-21: тангаж ограничен [-89, +89] (config.pitch_limit_deg).
func set_pitch_deg(value_deg: float) -> void:
	_pitch_deg = clampf(value_deg, -config.pitch_limit_deg, config.pitch_limit_deg)
	rotation.x = deg_to_rad(_pitch_deg)

func get_pitch_deg() -> float:
	return _pitch_deg

## Покачивание камеры при ходьбе (FR-23/FR-24). Фаза — функция пройденного
## пути, а не реального времени, поэтому детерминирована при равном
## программном вводе (NFR-09). При bob_enabled=false смещение всегда нулевое.
func update_bob(horizontal_speed_m_s: float, grounded: bool, delta: float) -> void:
	if not config.bob_enabled or not grounded or horizontal_speed_m_s < 0.01:
		position = Vector3.ZERO
		return
	_bob_phase_rad = wrapf(_bob_phase_rad + (horizontal_speed_m_s / config.stride_length_m) * TAU * delta, 0.0, TAU)
	var vertical: float = config.bob_amplitude_v_m * sin(_bob_phase_rad)
	var horizontal: float = config.bob_amplitude_h_m * sin(_bob_phase_rad * 0.5)
	position = Vector3(horizontal, vertical, 0.0)
