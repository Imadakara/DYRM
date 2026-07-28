## Дверь на стыке арок: мгновенное переключение створки и коллизии по
## взаимодействию (ТЗ-100, FR-35). Промежуточные состояния не моделируются —
## A-07: коллизия переключается сразу, без анимации в физике.
class_name Door
extends Interactable

signal state_changed(open: bool)

@export var prompt_open_text: String = "Открыть дверь"
@export var prompt_close_text: String = "Закрыть дверь"

@export var leaf_width_m: float = 1.6
@export var leaf_height_m: float = 2.3
@export var leaf_thickness_m: float = 0.1

@onready var _leaf: MeshInstance3D = $Leaf
## AnimatableBody3D, не StaticBody3D: узел лежит под RotatingRing и
## непрерывно вращается вместе с ним — Jolt трактует движущийся StaticBody3D
## как неподвижный для broadphase (см. station_module.gd).
@onready var _leaf_body: AnimatableBody3D = $LeafBody
@onready var _leaf_collision: CollisionShape3D = $LeafBody/LeafCollision
@onready var _probe_collision: CollisionShape3D = $CollisionShape3D

var _open: bool = false

func _ready() -> void:
	var leaf_size := Vector3(leaf_width_m, leaf_height_m, leaf_thickness_m)
	var box := BoxMesh.new()
	box.size = leaf_size
	_leaf.mesh = box
	_leaf.position = Vector3(0.0, leaf_height_m * 0.5, 0.0)
	_leaf_body.position = _leaf.position

	var leaf_shape := BoxShape3D.new()
	leaf_shape.size = leaf_size
	_leaf_collision.shape = leaf_shape

	var probe_shape := BoxShape3D.new()
	probe_shape.size = leaf_size
	_probe_collision.shape = probe_shape
	_probe_collision.position = _leaf.position

	_apply_state()

func interact(from: Node3D) -> void:
	if not can_interact(from):
		return
	toggle()
	activated.emit(from)

func open() -> void:
	if _open:
		return
	_open = true
	_apply_state()
	state_changed.emit(_open)

func close() -> void:
	if not _open:
		return
	_open = false
	_apply_state()
	state_changed.emit(_open)

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func is_open() -> bool:
	return _open

func get_prompt() -> String:
	return prompt_close_text if _open else prompt_open_text

func _apply_state() -> void:
	_leaf.visible = not _open
	_leaf_collision.disabled = _open
