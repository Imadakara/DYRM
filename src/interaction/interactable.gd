## Базовый контракт взаимодействия (ТЗ-100, FR-31). InteractionProbe работает
## только с этим классом — ни одной проверки конкретного наследника.
class_name Interactable
extends Area3D

signal activated(by: Node3D)

@export var prompt_text: String = ""
@export var enabled: bool = true

## Доступно ли взаимодействие с этой позиции. Базовая реализация проверяет
## только enabled — дистанцию проверяет InteractionProbe (FR-34).
func can_interact(_from: Node3D) -> bool:
	return enabled

## Выполнить взаимодействие. Испускает activated при успехе. Переопределяется
## наследниками; базовая реализация просто испускает сигнал.
func interact(from: Node3D) -> void:
	if not can_interact(from):
		return
	activated.emit(from)

## Текст для HUD с учётом состояния. Базовая реализация возвращает prompt_text.
func get_prompt() -> String:
	return prompt_text

## Точка попадания луча InteractionProbe на этом кадре, если цель — эта
## Interactable; hit_valid=false, когда луч потерял цель. Базовая реализация —
## заглушка; переопределяется WorkPanel для доставки событий в SubViewport
## (FR-42). InteractionProbe вызывает это на любой цели без проверки типа
## (принцип 7.1.3).
func receive_pointer(_hit_valid: bool, _world_point: Vector3) -> void:
	pass

## Физическая кнопка мыши (обычно ЛКМ) нажата/отпущена, пока эта Interactable —
## текущая цель. Базовая реализация — заглушка; переопределяется WorkPanel.
func receive_click(_pressed: bool) -> void:
	pass

## true, пока эта Interactable удерживает захват ввода игрока (FR-46).
## Базовая реализация — false; переопределяется WorkPanel.
func is_capturing_input() -> bool:
	return false
