## Параметры локомоции и камеры игрока (ТЗ-100, раздел 6.3.2). Плоский Resource
## без вложенности — правка в запущенном проекте немедленно видна (7.7.2).
class_name PlayerConfig
extends Resource

@export var walk_speed_m_s: float = 2.0
@export var run_speed_m_s: float = 3.6
@export var jump_velocity_m_s: float = 2.0
@export var accel_ground_m_s2: float = 12.0
@export var decel_ground_m_s2: float = 16.0
@export var accel_air_m_s2: float = 2.5

@export var capsule_height_m: float = 1.80
@export var capsule_radius_m: float = 0.35
@export var eye_height_m: float = 1.65
@export var step_height_m: float = 0.35
@export var max_slope_deg: float = 46.0

@export var mouse_sensitivity_deg_px: float = 0.15
@export var mouse_sensitivity_multiplier: float = 1.0
@export var invert_y: bool = false
@export var pitch_limit_deg: float = 89.0
@export var fov_deg: float = 75.0

@export var bob_enabled: bool = true
@export var bob_amplitude_v_m: float = 0.030
@export var bob_amplitude_h_m: float = 0.020
@export var stride_length_m: float = 0.75
