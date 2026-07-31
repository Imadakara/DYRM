## "Код"-сторона тестового моста GDScript <-> Orchestrator
## (scenes/dev/orchestrator_bridge_demo.tscn). Доказательство концепции гибридной
## разработки: эмитит code_ping — событие, которое ловит Orchestrator-сторона
## (OrchestratorBridgeDemo.torch, сосед по сцене), а сама принимает orchestrator_pong
## в ответ. Обе стороны видят друг друга только через сигналы сцены — без прямых
## ссылок на класс друг друга.
##
## trigger_code_event() — программный дубль (см. debugging conventions в CLAUDE.md):
## MCP run_script должен уметь прогнать весь цикл без реального ввода. Физический
## дубль — клавиша interact (E), уже используемая проектом для всех остальных
## взаимодействий, чтобы результат можно было увидеть глазами при живом запуске сцены.
class_name OrchestratorBridgeCodeSide
extends Node

signal code_ping(counter: int)

@onready var _status_label: Label = $StatusLabel

var _counter: int = 0
var _last_value_from_orchestrator: int = -1

func _ready() -> void:
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		trigger_code_event()

func trigger_code_event() -> void:
	_counter += 1
	code_ping.emit(_counter)
	_update_label()

## Вызывается Orchestrator-стороной моста через сигнал orchestrator_pong.
func receive_from_orchestrator(value: int) -> void:
	_last_value_from_orchestrator = value
	_update_label()

func get_counter() -> int:
	return _counter

func get_last_value_from_orchestrator() -> int:
	return _last_value_from_orchestrator

func _update_label() -> void:
	_status_label.text = "code_ping: %d | from Orchestrator: %d" % [_counter, _last_value_from_orchestrator]
