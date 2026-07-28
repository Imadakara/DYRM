## Минимальный HUD взаимодействия: перекрестье и одна строка подсказки
## (ТЗ-100, раздел 2.1). Только чтение геттеров InteractionProbe — сбором
## данных не занимается (7.3).
class_name InteractionHUD
extends CanvasLayer

@export var probe_path: NodePath
@export var config: InteractionConfig

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_label: Label = %PromptLabel

var _probe: InteractionProbe

func _ready() -> void:
	_probe = get_node_or_null(probe_path) as InteractionProbe
	# Перекрестье сидит ровно в центре экрана — там же, где остаётся курсор
	# сразу после захвата мыши (см. отчёт по debug_overlay.gd) — дефолтный
	# MOUSE_FILTER_STOP съедал бы InputEventMouseMotion до PlayerController.
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
