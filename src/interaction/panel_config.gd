## Стандарт рабочей панели рубки (ТЗ-100, раздел 6.3.4). Плоский Resource.
class_name PanelConfig
extends Resource

## Физический размер экрана панели, м (ширина, высота).
@export var surface_size_m: Vector2 = Vector2(0.60, 0.45)
## Разрешение SubViewport, px.
@export var viewport_size_px: Vector2i = Vector2i(1024, 768)
## Минимальный размер интерактивного элемента на панели, м. FR-47
@export var min_element_size_m: float = 0.04
## Допустимая высота центра панели над полом, м. FR-48
@export var mount_height_min_m: float = 0.90
@export var mount_height_max_m: float = 1.90
## Допустимая рабочая дистанция оператор-панель, м. FR-48
@export var work_distance_min_m: float = 0.8
@export var work_distance_max_m: float = 1.5
## Толщина рамки-корпуса панели, м (декоративная геометрия ART-01).
@export var frame_thickness_m: float = 0.03
@export var frame_depth_m: float = 0.04
