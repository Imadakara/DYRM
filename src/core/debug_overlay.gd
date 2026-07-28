## Отладочный оверлей: показания выводятся именованными дочерними Label-узлами
## (не через _draw()), чтобы их можно было читать без скриншота — через
## get_ui_elements() живого моста. Видимость — публичное свойство `visible`
## (унаследовано от CanvasLayer), программный дубль клавиши F3. FR-52
class_name DebugOverlay
extends CanvasLayer

@export var game_clock_path: NodePath
@export var station_root_path: NodePath
@export var solar_system_path: NodePath
@export var player_path: NodePath
@export var interaction_probe_path: NodePath

@onready var fps_label: Label = %FpsLabel
@onready var epoch_label: Label = %EpochLabel
@onready var time_scale_label: Label = %TimeScaleLabel
@onready var station_pos_label: Label = %StationPosLabel
@onready var ring_angle_label: Label = %RingAngleLabel
@onready var bodies_label: Label = %BodiesLabel

## Блок игрока (ТЗ-100, FR-52) — именованные Label, читаемые обходчиком
## get_ui_elements() живого моста без скриншота.
@onready var player_module_label: Label = %PlayerModuleLabel
@onready var player_pos_label: Label = %PlayerPosLabel
@onready var player_radius_label: Label = %PlayerRadiusLabel
@onready var player_up_label: Label = %PlayerUpLabel
@onready var player_vel_label: Label = %PlayerVelLabel
@onready var player_grounded_label: Label = %PlayerGroundedLabel
@onready var player_target_label: Label = %PlayerTargetLabel

var _game_clock: GameClock
var _station_root: StationRoot
var _solar_system: SolarSystem
var _player: PlayerController
var _interaction_probe: InteractionProbe

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay_toggle"):
		visible = not visible

func _ready() -> void:
	_game_clock = get_node_or_null(game_clock_path) as GameClock
	_station_root = get_node_or_null(station_root_path) as StationRoot
	_solar_system = get_node_or_null(solar_system_path) as SolarSystem
	_player = get_node_or_null(player_path) as PlayerController
	_interaction_probe = get_node_or_null(interaction_probe_path) as InteractionProbe
	_disable_mouse_capture(self)

## Оверлей — чисто информационный слой (F3, FR-52), не должен перехватывать
## мышь у игрока: PanelContainer/Label по умолчанию используют
## MOUSE_FILTER_STOP и иначе съедают InputEventMouseMotion в GUI-слое раньше,
## чем событие доходит до PlayerController._unhandled_input() — камера
## переставала реагировать на мышь всякий раз, когда курсор (в захваченном
## режиме) оказывался над панелью в левом верхнем углу.
func _disable_mouse_capture(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_capture(child)

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_readout()

func _update_readout() -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if _game_clock != null:
		var pause_suffix: String = " [PAUSED]" if _game_clock.paused else ""
		epoch_label.text = "epoch_days: %.4f" % _game_clock.epoch_days
		time_scale_label.text = "time_scale: %.0fx%s" % [_game_clock.time_scale, pause_suffix]

	if _station_root != null:
		var pos_km: Vector3 = _station_root.position_km()
		station_pos_label.text = "station (km): %.0f, %.0f, %.0f" % [pos_km.x, pos_km.y, pos_km.z]
		ring_angle_label.text = "ring angle: %.2f deg" % rad_to_deg(_station_root.get_ring_angle_rad())

	if _solar_system != null and _station_root != null:
		var lines: PackedStringArray = []
		var observer_km: Vector3 = _solar_system.observer_position_km()
		for body in _solar_system.get_bodies():
			var direction: Vector3 = body.direction_from(observer_km)
			var az_el: Vector2 = _station_root.direction_to_az_el(direction)
			var distance_km: float = body.distance_from(observer_km)
			var angular_diameter: float = body.angular_diameter_deg(observer_km)
			lines.append("%s %.0f %.1f %.1f %.3f" % [
					body.data.body_id, distance_km, az_el.x, az_el.y, angular_diameter])
		bodies_label.text = "\n".join(lines)

	if _player != null:
		player_module_label.text = "module: %s" % _player.current_module()
		player_pos_label.text = "pos: %.2f, %.2f, %.2f" % [_player.position.x, _player.position.y, _player.position.z]
		player_radius_label.text = "radius: %.3f m" % _player.get_ring_radius()
		var up: Vector3 = _player.get_up_direction()
		player_up_label.text = "up: %.3f, %.3f, %.3f" % [up.x, up.y, up.z]
		player_vel_label.text = "local_velocity: %.3f, %.3f, %.3f" % [_player.local_velocity.x, _player.local_velocity.y, _player.local_velocity.z]
		player_grounded_label.text = "grounded: %s" % _player.is_grounded()
	if _interaction_probe != null:
		var target: Interactable = _interaction_probe.get_target()
		player_target_label.text = "target: %s" % (target.get_prompt() if target != null else "-")
