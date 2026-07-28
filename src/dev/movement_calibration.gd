## Техническая сцена калибровки движения от первого лица (scenes/dev/movement_calibration.tscn)
## — не привязана к конкретному ТЗ, инструмент отладки того же рода, что и
## tools/run_tests.gd. Даёт дешёвый программный способ прогнать базовые
## движения (вперёд/назад/влево/вправо, покой) и получить численный отчёт по
## устойчивости пола (радиус от оси кольца, дрейф вдоль оси, мигание
## is_on_floor()) одним вызовом run_script вместо серии ручных запросов через
## MCP на каждый кадр. См. skill godot-mcp-testing (глобальный).
class_name MovementCalibration
extends Node3D

@export var player_path: NodePath
@export var frames_per_phase: int = 120

@onready var _player: PlayerController = get_node_or_null(player_path)

## Один прогон: покой -> вперёд -> покой -> назад -> покой -> вправо -> покой
## -> влево -> покой, каждая фаза сэмплируется покадрово. Программный дубль
## того, что раньше делалось вручную через run_script в диагностических
## сессиях (см. отчёты по ТЗ-100).
func run_calibration_sequence() -> Dictionary:
	var phases: Array[Dictionary] = [
		{"name": "idle_1", "input": Vector2.ZERO},
		{"name": "forward", "input": Vector2(0.0, 1.0)},
		{"name": "idle_2", "input": Vector2.ZERO},
		{"name": "back", "input": Vector2(0.0, -1.0)},
		{"name": "idle_3", "input": Vector2.ZERO},
		{"name": "right", "input": Vector2(1.0, 0.0)},
		{"name": "idle_4", "input": Vector2.ZERO},
		{"name": "left", "input": Vector2(-1.0, 0.0)},
		{"name": "idle_5", "input": Vector2.ZERO},
	]
	var report: Dictionary = {}
	for phase in phases:
		_player.set_move_input(phase["input"])
		report[phase["name"]] = await _sample_phase()
	_player.set_move_input(Vector2.ZERO)
	return report

func _sample_phase() -> Dictionary:
	var radii: Array[float] = []
	var pos_y: Array[float] = []
	var grounded_false_frames: int = 0
	for i in range(frames_per_phase):
		radii.append(_player.get_ring_radius())
		pos_y.append(_player.position.y)
		if not _player.is_grounded():
			grounded_false_frames += 1
		await get_tree().physics_frame
	return {
		"radius_min": radii.min(),
		"radius_max": radii.max(),
		"radius_range_m": radii.max() - radii.min(),
		"pos_y_min": pos_y.min(),
		"pos_y_max": pos_y.max(),
		"pos_y_range_m": pos_y.max() - pos_y.min(),
		"grounded_false_frames": grounded_false_frames,
	}
