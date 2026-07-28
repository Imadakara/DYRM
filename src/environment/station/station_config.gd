class_name StationConfig
extends Resource

## Радиус пола каждого модуля до оси вращения, метры (r=60). Формула
## [ring-artificial-gravity], ГДД 000.
@export var ring_radius_m: float = 60.0
## Целевая гравитация на полу модуля, в g.
@export var target_gravity_g: float = 0.3

## Радиус неподвижной ступицы — она же радиус, на котором рукоять механически
## стыкуется со ступицей (r_hub). Формула [arm-corridor-length], ГДД 000.
@export var hub_radius_m: float = 7.0
## Длина ступицы вдоль оси вращения, метры — её торцы зарезервированы под
## будущие модули Блока 3.
@export var hub_length_m: float = 20.0

## Угловое смещение (град.) между модулем и точкой стыковки рукояти со
## ступицей — рукоять строится как прямая хорда между этими двумя точками, а
## не вдоль чистого радиуса: чисто радиальная рукоять была бы вертикальной
## шахтой (уклон 90° к «низу»), непроходимой обычной ходьбой при
## PlayerConfig.max_slope_deg. Смещение даёт проходимый уклон, сохраняя
## монотонное убывание радиуса вдоль рукояти.
@export var arm_angular_offset_deg: float = 35.0
## Сечение рукояти-коридора и лок-камеры, метры (квадратное).
@export var arm_cross_section_m: float = 2.5
## Длина лок-камеры вдоль хорды рукояти, метры.
@export var lock_chamber_length_m: float = 3.0
## Длительность цикла синхронизации лок-камеры, секунды. Формула
## [lock-chamber-spin-sync], ГДД 000.
@export var lock_chamber_duration_s: float = 8.0

## Горизонтальные размеры пола модуля, метры: ширина (по касательной) x
## глубина (к рукояти).
@export var module_width_m: float = 8.0
@export var module_depth_m: float = 6.0
## Высота отсека модуля от пола до потолка, метры.
@export var module_height_m: float = 2.6

@export var orbit_radius_km: float = 100000.0
@export var neptune_mu_km3_s2: float = 6.836529e6
@export var neptune_radius_km: float = 24622.0

## Максимальный габарит станции по любой оси, метры.
@export var max_extent_m: float = 140.0

## Внутреннее освещение отсеков, раздел 9.2.
@export var interior_light_count_per_module: int = 4
@export var interior_light_color: Color = Color(1.0, 0.909804, 0.768627)
@export var interior_light_energy: float = 1.2
@export var interior_light_range_m: float = 12.0
