## Тонкая GDScript-обёртка над Interactable (ТЗ-100) для реального контракта проекта
## (InteractionProbe делает `result.get("collider") is Interactable` — Orchestration не может
## быть base_type=Interactable напрямую, см. skill godot-orchestrator, раздел "Confirmed
## limitation"). Вся логика переключения света — в соседнем SwitchLogic.torch (Orchestrator),
## эта обёртка только проходит can_interact() и пробрасывает событие сигналом.
class_name OrchestratorLightSwitchWrapper
extends Interactable

signal switch_toggle_requested

func interact(from: Node3D) -> void:
	if not can_interact(from):
		return
	switch_toggle_requested.emit()
	activated.emit(from)
