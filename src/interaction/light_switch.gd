## Настенный выключатель света (тест гибридного GDScript/Orchestrator подхода, см. skill
## godot-orchestrator). Тонкая обёртка: строит геометрию плашки и can_interact()-гейт
## наследует от Interactable как есть, а саму логику переключения пробрасывает сигналом
## в соседний SwitchLogic (Orchestrator, habitat_light_switch_logic.torch) — Orchestration не
## может быть base_type=Interactable напрямую (см. CLAUDE.md, раздел Orchestrator).
class_name LightSwitch
extends Interactable

signal switch_toggle_requested

@export var plate_size_m: Vector3 = Vector3(0.15, 0.2, 0.05)
@export var plate_color: Color = Color(0.8, 0.8, 0.85)

@onready var _plate_mesh: MeshInstance3D = $Plate
@onready var _plate_collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = plate_size_m
	_plate_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = plate_color
	_plate_mesh.material_override = mat

	var shape := BoxShape3D.new()
	shape.size = plate_size_m
	_plate_collision.shape = shape

func interact(from: Node3D) -> void:
	if not can_interact(from):
		return
	switch_toggle_requested.emit()
	activated.emit(from)
