## Интерактивная мишень для сцены калибровки MCP-команд
## (scenes/dev/mcp_calibration.tscn, см. skill godot-mcp-testing (глобальный)).
## При interact() переключает белую плашку над собой — сигнал, который
## однозначно читается на скриншоте без разбора мелкого текста, и который
## заодно можно проверить программно через is_plate_visible() без единого
## скриншота. Строит меш/материал в коде (см. mcp_calibration_ground.gd) —
## сцена не хранит ресурсов, только пустые узлы.
##
## Плашка — устойчивый тумблер, НЕ таймер: между двумя вызовами MCP-инструмента
## (screenshot, run_script) проходит реальное время — секунды, а не кадры
## симуляции — и таймер на несколько секунд гарантированно погаснет раньше,
## чем агент успеет сделать следующий запрос на проверку. Обнаружено эмпирически
## при калибровке этой сцены. См. skill godot-mcp-testing (глобальный).
##
## Не наследует Interactable этого репозитория и не зависит ни от одной его
## игровой системы (кольцо, StationRoot и т.д.) — образец для переноса в
## любой другой проект как есть.
class_name McpCalibrationTarget
extends StaticBody3D

## Столбик, а не куб: должен пересекаться горизонтальным лучом на высоте
## глаз игрока (~1,6 м) без необходимости целиться тангажом камеры.
@export var body_size_m: Vector3 = Vector3(0.6, 2.0, 0.6)
@export var body_color: Color = Color(0.2, 0.5, 0.8)

@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _body_collision: CollisionShape3D = $CollisionShape3D
@onready var _plate: MeshInstance3D = $Plate

var _activation_count: int = 0

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = body_size_m
	_body_mesh.mesh = box
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = body_color
	_body_mesh.material_override = body_material

	var shape := BoxShape3D.new()
	shape.size = body_size_m
	_body_collision.shape = shape

	var plate_mesh := PlaneMesh.new()
	plate_mesh.size = Vector2(0.5, 0.3)
	_plate.mesh = plate_mesh
	_plate.position = Vector3(0.0, body_size_m.y * 0.5 + 0.4, 0.0)
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color.WHITE
	plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plate.material_override = plate_material
	_plate.visible = false

## Программный дубль нажатия E на этой мишени (единый контракт, который
## ожидает McpCalibrationPlayer.trigger_interact()).
func interact() -> void:
	_activation_count += 1
	_plate.visible = not _plate.visible

func is_plate_visible() -> bool:
	return _plate.visible

func get_activation_count() -> int:
	return _activation_count
