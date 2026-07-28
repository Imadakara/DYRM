class_name StationConfig
extends Resource

## Радиус кольца до пола, метры (r=60). Потолок — на ring_radius_m - deck_height_m. FR-30
@export var ring_radius_m: float = 60.0
## Высота отсека от пола до потолка, метры.
@export var deck_height_m: float = 3.5
## Ширина трубы кольца вдоль оси вращения, метры (пол 4.5 м + оборудование по бокам).
@export var tube_width_m: float = 7.0
## Число прямых хорд-сегментов на одну дугу 45° (R-04 — сглаживание торовой геометрии).
@export var arc_segment_count: int = 16

## Целевая гравитация на полу кольца, в g.
@export var target_gravity_g: float = 0.3

@export var hub_radius_m: float = 10.0
@export var hub_length_m: float = 30.0
@export var spoke_count: int = 4
@export var spoke_length_m: float = 46.5
@export var spoke_diameter_m: float = 3.0

@export var orbit_radius_km: float = 100000.0
@export var neptune_mu_km3_s2: float = 6.836529e6
@export var neptune_radius_km: float = 24622.0

## Максимальный габарит станции по любой оси, метры. FR-40
@export var max_extent_m: float = 200.0

## Внутреннее освещение отсеков, раздел 9.2.
@export var interior_light_count_per_module: int = 4
@export var interior_light_color: Color = Color(1.0, 0.909804, 0.768627)
@export var interior_light_energy: float = 1.2
@export var interior_light_range_m: float = 12.0
