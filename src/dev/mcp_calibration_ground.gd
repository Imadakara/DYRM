## Плоский пол для сцены калибровки MCP-команд (scenes/dev/mcp_calibration.tscn).
## Строит меш и коллизию в коде, как Door/SpokeHatch — сцена хранит только
## пустые узлы, без ресурсов в .tscn. Не зависит ни от одной игровой системы
## DYRM: годится как образец для любого другого проекта.
class_name McpCalibrationGround
extends StaticBody3D

@export var size_m: Vector2 = Vector2(20.0, 20.0)

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(size_m.x, 0.2, size_m.y)
	_mesh.mesh = box
	_mesh.position = Vector3(0.0, -0.1, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.35, 0.38)
	_mesh.material_override = material

	var shape := BoxShape3D.new()
	shape.size = box.size
	_collision.shape = shape
	_collision.position = _mesh.position
