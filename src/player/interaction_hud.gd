## Минимальный HUD взаимодействия: перекрестье, одна строка подсказки
## (ТЗ-100, раздел 2.1) и полноэкранное затемнение для перехода между
## системами отсчёта гантелеобразной станции (ТЗ-000 §17.3, документация
## 0.1.1 — "по кнопке действия с затенением экрана"). Только чтение геттеров
## InteractionProbe — сбором данных не занимается (7.3).
##
## Группа &"interaction_hud": PlayerController.begin_transition() находит HUD
## групповым поиском — у PlayerController никогда не было своего NodePath на
## HUD (раньше и не требовалось, взаимодействие шло в обратную сторону —
## InteractionHUD.probe_path указывает НА игрока, а не наоборот), заводить
## новый экспортируемый путь специально под один этот вызов избыточно.
class_name InteractionHUD
extends CanvasLayer

const GROUP: StringName = &"interaction_hud"

@export var probe_path: NodePath
@export var config: InteractionConfig

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_label: Label = %PromptLabel
@onready var _fade_overlay: ColorRect = %FadeOverlay

var _probe: InteractionProbe
var _fade_tween: Tween

func _ready() -> void:
	add_to_group(GROUP)
	_probe = get_node_or_null(probe_path) as InteractionProbe
	# Перекрестье сидит ровно в центре экрана — там же, где остаётся курсор
	# сразу после захвата мыши (см. отчёт по debug_overlay.gd) — дефолтный
	# MOUSE_FILTER_STOP съедал бы InputEventMouseMotion до PlayerController.
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if _probe == null:
		return
	var target: Interactable = _probe.get_target()
	var size_px: float
	if target != null:
		size_px = config.crosshair_active_size_px
		_prompt_label.text = config.prompt_format % target.get_prompt()
		_prompt_label.visible = true
	else:
		size_px = config.crosshair_idle_size_px
		_prompt_label.text = ""
		_prompt_label.visible = false
	# Anchors 0.5/0.5/0.5/0.5 (точка в центре экрана) — офсеты задают
	# симметричный квадрат вокруг неё независимо от anchors_preset слоя.
	var half: float = size_px * 0.5
	_crosshair.offset_left = -half
	_crosshair.offset_top = -half
	_crosshair.offset_right = half
	_crosshair.offset_bottom = half

## Затемняет экран до непрозрачного чёрного за duration_s — вызывающая
## сторона (PlayerController.begin_transition()) ждёт завершения перед
## телепортом, чтобы сама перестановка позиции/родителя была скрыта.
func fade_out(duration_s: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, ^"color:a", 1.0, duration_s)
	await _fade_tween.finished

## Обратное fade_out() — не ожидается вызывающей стороной (экран уже показывает
## новое состояние, дальше это чисто визуальное появление, не блокирующее геймплей).
func fade_in(duration_s: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, ^"color:a", 0.0, duration_s)
