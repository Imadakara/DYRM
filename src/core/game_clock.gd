## Игровое время: сутки от эпохи J2000.0, множитель скорости, пауза.
## Обычный узел main.tscn — без автозагрузок, ссылки передаются через @export NodePath.
##
## @tool: не для того, чтобы время шло в редакторе (см. защиту в
## _physics_process ниже — там оно НЕ идёт), а чтобы сигнал time_changed
## оставался настоящим сигналом, а не плейсхолдером, для station_root.gd/
## ring_rotator.gd (тоже @tool, см. класс-комментарий StationModule) —
## соединение с плейсхолдером падает с "Invalid access to property or key
## 'time_changed'". Кольцо в редакторе остаётся неподвижным (последний
## сохранённый rotation.y) — самое подходящее состояние для правки геометрии.
@tool
class_name GameClock
extends Node

## Испускается при каждом продвижении времени. FR-19
signal time_changed(epoch_days: float)

## Сутки от эпохи J2000.0 (JD 2451545.0). Положение всех тел — чистая функция
## от этой величины (FR-19, NFR-08). Игровая дата 2426 года по лору сюда не
## транслируется — см. открытый вопрос Q-01.
var epoch_days: float = 0.0

## Множитель скорости течения времени. 1.0 = реальное время. Клавиши [ / ]. FR-53
var time_scale: float = 1.0

## Пауза течения времени. Клавиша P. FR-53
var paused: bool = false

const SECONDS_PER_DAY: float = 86400.0
const MIN_TIME_SCALE: float = 1.0
const MAX_TIME_SCALE: float = 1_000_000.0
const TIME_SCALE_STEP: float = 10.0

## _physics_process, не _process: RotatingRing (см. ring_rotator.gd) — потомок
## этого сигнала, а его поворот несут коллизии игрока и станции (ТЗ-100,
## AnimatableBody3D-полы под ним). Если поворот кольца обновляется на кадрах
## _process (идёт не в такт физике), синхронизация трансформов с физическим
## сервером на границе физкадра расходится с реальным углом поворота —
## визуально незаметно, но даёт систематический дрейф позиции у всего, что
## стоит на вращающемся полу (обнаружено при отладке ТЗ-100, AC-07).
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or paused:
		return
	advance(delta)

## Клавиши [ / ] и P — программные дубли: time_scale и paused уже публичные
## поля, отдельных методов для отладочных пресетов не требуется. FR-53
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("time_scale_up"):
		time_scale = clampf(time_scale * TIME_SCALE_STEP, MIN_TIME_SCALE, MAX_TIME_SCALE)
	elif event.is_action_pressed("time_scale_down"):
		time_scale = clampf(time_scale / TIME_SCALE_STEP, MIN_TIME_SCALE, MAX_TIME_SCALE)
	elif event.is_action_pressed("time_pause"):
		paused = not paused

## Продвигает игровое время на delta секунд реального времени, учитывая time_scale. FR-19
func advance(delta_seconds: float) -> void:
	epoch_days += delta_seconds * time_scale / SECONDS_PER_DAY
	time_changed.emit(epoch_days)

## Устанавливает epoch_days напрямую (тесты, сохранения — ТЗ-073). FR-19
func set_epoch_days(days: float) -> void:
	epoch_days = days
	time_changed.emit(epoch_days)
