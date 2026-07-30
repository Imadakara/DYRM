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

## Свободный полёт в невесомости (неподвижный ствол гантелеобразной станции —
## ТЗ-000 §17, адаптация ТЗ-100). Тяга по локальным осям взгляда, без "пола" и
## гравитации — принципиально другая модель движения, чем ходьба/бег выше,
## поэтому отдельный блок полей, не переиспользование accel_ground_m_s2 и пр.
@export var zero_g_thrust_m_s2: float = 4.0
@export var zero_g_max_speed_m_s: float = 3.6
@export var zero_g_damping_m_s2: float = 3.0

## Длительность каждой половины экранного затенения при переходе ствол↔плечо
## (документация 0.1.1: "по кнопке действия с затенением экрана"), секунды.
@export var transition_fade_duration_s: float = 0.4
