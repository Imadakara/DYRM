class_name OrbitalElements
extends Resource

## Кеплеровы элементы орбиты на эпоху J2000.0 (см. ТЗ-000, 6.3.1).
## Большая полуось хранится в километрах (для спутников планет — расстояние
## относительно родительского тела, для планет — относительно Солнца).

@export var semi_major_axis_km: float = 0.0
@export var eccentricity: float = 0.0
@export var inclination_deg: float = 0.0
@export var mean_longitude_deg: float = 0.0
@export var longitude_perihelion_deg: float = 0.0
@export var longitude_node_deg: float = 0.0
## Сидерический период обращения, сутки. Знак не несёт смысла (ретроградность
## задаётся наклонением > 90°, см. Тритон в celestial_body_data).
@export var period_days: float = 1.0
