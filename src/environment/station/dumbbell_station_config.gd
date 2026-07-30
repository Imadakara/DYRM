## Параметры гантелеобразной станции (см. документацию 0.1.1 «Конфигурация
## станции», раздел «Изменения после ревью» ТЗ-000). Неподвижный ствол —
## антенный модуль → модуль-втулка → модуль передачи, вдоль локальной оси +Y
## StationRoot. На втулке — вращающийся барабан с двумя симметричными плечами
## (коридор + модуль), несущими жилой и рабочий модуль.
class_name DumbbellStationConfig
extends Resource

## Число прямых сегментов на окружность сечения трубы (сглаживание цилиндра).
@export var segment_count: int = 16

## Толщина коллизионных плит стен/торцов, метры (см. WALL_THICKNESS_M в
## station_module.gd — то же соображение: тонкие слои, не сплошной монолит).
@export var wall_thickness_m: float = 0.3

# --- Неподвижный ствол (не вращается) --------------------------------------
@export var antenna_module_radius_m: float = 3.0
@export var antenna_module_length_m: float = 8.0
@export var hub_shell_radius_m: float = 3.0
@export var hub_shell_length_m: float = 6.0
@export var transmission_module_radius_m: float = 3.0
@export var transmission_module_length_m: float = 8.0

# --- Вращающийся барабан и плечи -------------------------------------------
## Радиус барабана — одновременно расстояние от оси вращения до начала
## обоих плеч (коридоров).
@export var drum_radius_m: float = 4.0
@export var drum_length_m: float = 6.0

## Коридор — чисто структурный элемент, без коллизии: игрок телепортируется
## через люк на барабане, а не идёт по коридору пешком (документация 0.1.1,
## «без перемещения по ним, с затенением экрана»).
##
## corridor_length_m напрямую определяет АБСОЛЮТНЫЙ радиус пола жилого/рабочего
## модуля от оси вращения: стыковка по коннекторам (station_docking.gd) кладёт
## Connector_Corridor комнаты ровно на drum_radius_m + corridor_length_m, а пол
## комнаты лежит дальше вдоль той же оси ещё на (arc_room_outer_radius_m -
## arc_room_inner_radius_m) — то есть при неизменном arc_room_outer_radius_m
## радиус пола = drum_radius_m + corridor_length_m + глубина комнаты. Значение
## по умолчанию здесь (10 м) НЕ используется на практике — реальное значение
## живёт в resources/dumbbell_station_default.tres (51.0, подобрано так, чтобы
## 4.0 + 51.0 + 5.0 = 60 = arc_room_outer_radius_m, тот же радиус пола, что и у
## старого доказанно рабочего кольца). Меняя глубину комнаты
## (arc_room_outer/inner_radius_m), нужно синхронно поправить corridor_length_m
## в .tres на ту же дельту, иначе пол сдвинется — проверено эмпирически живым
## запуском, не выводится из докинга "на глаз" (см. историю правки в
## arc_room_station_module.gd, поле inner_radius_m).
@export var corridor_radius_m: float = 1.2
@export var corridor_length_m: float = 10.0

## Жилой и рабочий модуль — симметричные "головы гантели", единственные места
## с гравитацией "на своих ногах". Форма — дуговая четверть-секция
## прямоугольного тора: пол и потолок ИЗОГНУТЫ по окружности вращения
## (радиусы arc_room_inner/outer_radius_m), а не плоские — см. отчёт о
## ревизии конфигурации 0.1.1, второе уточнение ("представь два молота").
## Гранёный (не гладкий) профиль кривизны — arc_room_segment_count хорд.
## arc_room_inner_radius_m — потолок (ближе к оси, здесь коннектор коридора,
## по центру дуги — симметрично), arc_room_outer_radius_m — пол (дальше от
## оси, целевая гравитация target_gravity_g). arc_room_axial_half_width_m —
## половина "приплюснутого" измерения вдоль главной оси станции.
## Радиус пола (60 м) — тот же, что и у старого (доказанно рабочего) кольца
## станции (StationConfig.ring_radius_m), не исходные 24 м первой ревизии
## дуговой комнаты: при 24 м угловая скорость плеча заметно выше (тот же g,
## меньший радиус), и физика ходьбы разваливалась — см. отчёт по адаптации
## ТЗ-100 под ТЗ-000 §17.3. arc_room_inner_radius_m держал ту же глубину
## комнаты (10 м), просто сдвинутую на новый радиус — позже глубина уменьшена
## вдвое (до 5 м) правкой одного только потолка, пол (arc_room_outer_radius_m)
## не тронут, см. комментарий у соответствующего поля в
## arc_room_station_module.gd для деталей и обоснования.
@export var arc_room_inner_radius_m: float = 55.0
@export var arc_room_outer_radius_m: float = 60.0
@export var arc_room_axial_half_width_m: float = 4.0
@export var arc_room_angle_span_deg: float = 30.0
## Число гранёных сегментов дуги пола/потолка/стен — то же самое (16), что и
## StationConfig.arc_segment_count у старого кольца станции, не отдельное
## "6-8 сегментов ради читаемого глазом профиля" первой ревизии. Не
## используется напрямую (ArcRoomStationModule несёт собственное
## arc_segment_count) — держим значение synced ради непротиворечивости
## конфига, а не по необходимости.
@export var arc_room_segment_count: int = 16

## Целевая гравитация на полу жилого/рабочего модуля, в g.
@export var target_gravity_g: float = 0.3

## Внутреннее освещение жилого/рабочего модуля (аналог раздела 9.2 ТЗ-000).
@export var interior_light_count_per_module: int = 4
@export var interior_light_color: Color = Color(1.0, 0.909804, 0.768627)
@export var interior_light_energy: float = 1.2
@export var interior_light_range_m: float = 12.0

## Радиус, на котором достигается target_gravity_g, — совпадает с радиусом
## пола жилого/рабочего модуля (arc_room_outer_radius_m). Используется для
## настройки ω вращателя (см. resources/station_dumbbell_rotator.tres, где
## под это же значение переиспользуется поле StationConfig.ring_radius_m).
func gravity_radius_m() -> float:
	return arc_room_outer_radius_m
