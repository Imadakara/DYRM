## Параметры взаимодействия игрока с миром (ТЗ-100, раздел 6.2). Плоский Resource.
class_name InteractionConfig
extends Resource

## Длина луча из центра экрана вдоль взгляда камеры, м. FR-30
@export var ray_length_m: float = 2.0
## Максимальная дистанция, на которой interact() допускается. FR-34
@export var interact_range_m: float = 2.0
## Формат строки подсказки, %s — текст действия. FR-32
@export var prompt_format: String = "[E] %s"
## Размер перекрестья в состоянии покоя, px. ART-06
@export var crosshair_idle_size_px: float = 4.0
## Размер перекрестья (диаметр кольца) при наведении на доступный объект, px. ART-06
@export var crosshair_active_size_px: float = 12.0
