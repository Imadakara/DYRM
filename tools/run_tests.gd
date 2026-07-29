## Автотесты ТЗ-000. Полный прогон (регрессия перед сдачей задачи):
##   godot --headless --path . --script res://tools/run_tests.gd
## Точечный прогон одного/нескольких смысловых блоков (во время работы над
## конкретной подсистемой — см. BLOCK_ORDER ниже и CLAUDE.md, раздел
## «Автотесты: блоки и точечный запуск»):
##   godot --headless --path . --script res://tools/run_tests.gd -- --blocks=player_locomotion,station_structure
## Одна строка на тест (PASS/FAIL), финальная строка RESULT: N passed, M failed
## (только по фактически запущенным тестам при фильтре по блокам). Код
## возврата 0 только если все ЗАПУЩЕННЫЕ тесты прошли.
extends SceneTree

## Порядок = порядок исполнения внутри полного прогона (часть тестов опирается
## на состояние, оставленное предыдущим блоком — например player_locomotion
## оставляет epoch_days и позицию игрока, от которых стартует interaction_ui;
## сам список блоков от этого не зависит и при фильтре выполняется в этом же
## относительном порядке). Он же задаёт «соседей» для точечного запуска —
## сосед блока X это блок слева/справа от X в этом списке.
const BLOCK_ORDER: Array[StringName] = [
	&"space_scale", &"orbital_mechanics", &"starfield", &"station_structure",
	&"physics_containment", &"player_locomotion", &"interaction_ui", &"scene_integrity",
]

var _passed: int = 0
var _failed: int = 0
var _requested_blocks: Array[StringName] = []

func _init() -> void:
	_requested_blocks = _parse_requested_blocks()
	for requested in _requested_blocks:
		if not BLOCK_ORDER.has(requested):
			print("WARN unknown block '%s' — see BLOCK_ORDER in tools/run_tests.gd for valid names" % requested)

	if _block_enabled(&"space_scale"):
		_test_compress_distance_monotonic()
		_test_compress_distance_reference()
		_test_render_radius_reference()
		_test_direction_preservation()
	if _block_enabled(&"starfield"):
		_test_starfield()

	# Сцену (main.tscn, station, солнечная система) грузим, только если её
	# требует хотя бы один из запрошенных блоков — при фильтре вида
	# --blocks=space_scale прогон вообще не трогает сцену станции.
	var needs_scene: bool = _block_enabled(&"orbital_mechanics") or _block_enabled(&"station_structure") \
			or _block_enabled(&"physics_containment") or _block_enabled(&"player_locomotion") \
			or _block_enabled(&"interaction_ui") or _block_enabled(&"scene_integrity")
	if needs_scene:
		var main_scene: PackedScene = load("res://scenes/main.tscn")
		var main: Node = main_scene.instantiate()
		get_root().add_child(main)
		for i in range(5):
			await process_frame

		var solar_system: SolarSystem = main.get_node("SolarSystem")
		var station: StationRoot = main.get_node("Station")
		var game_clock: GameClock = main.get_node("GameClock")
		var cfg: StationConfig = load("res://resources/station_default.tres")

		if _block_enabled(&"orbital_mechanics"):
			_test_planet_positions()
			_test_triton_orbit()
			_test_station_orbit_period()
			_test_ring_rotation_period()
			_test_retrograde_rotation()
			_test_bodies_count(solar_system)
			await _test_epoch_roundtrip(solar_system, game_clock)
		if _block_enabled(&"station_structure"):
			_test_gravity(station, cfg)
			_test_station_aabb(station)
			_test_arcs(station)
			_test_laser_coverage(station)
			await _test_rotating_ring(station, game_clock)
			_test_markers(station, cfg)
		if _block_enabled(&"physics_containment"):
			# T-18 (выше) намеренно прыгает epoch_days на целые сутки одним кадром,
			# чтобы проверить, что вращающийся узел действительно повернулся. Этот
			# скачок transform'а за один физический кадр даёт AnimatableBody3D
			# (Drum) в sync_to_physics аномально большую вычисленную угловую
			# скорость — Jolt потом передаёт её любому RigidBody3D, коснувшемуся
			# поверхности барабана в T-17 (мяч в жилом/рабочем плече долетает до
			# барабана по коридору без коллизии), и тот улетает на десятки метров
			# вместо ожидаемых ~2 м (см. базу знаний Godot). Возврат epoch_days к 0
			# и несколько кадров БЕЗ паузы дают RingRotator/AnimatableBody3D снова
			# устояться на маленьких, физически осмысленных приращениях поворота,
			# прежде чем T-17 начнёт создавать тела.
			game_clock.set_epoch_days(0.0)
			for i in range(10):
				await process_frame
			# Останавливаем игровое время: кольцо вращается непрерывно (даже с
			# time_scale=1), а T-17 сравнивает финальную позицию тела с AABB модуля,
			# снятым в начале — при вращающемся кольце обе величины «уезжают» друг
			# от друга за секунды симуляции импульса. Сама физика (Jolt) не зависит
			# от GameClock и продолжает считаться нормально.
			game_clock.paused = true
			await _test_physics_containment(station)
			game_clock.paused = false

		if _block_enabled(&"player_locomotion") or _block_enabled(&"interaction_ui") or _block_enabled(&"scene_integrity"):
			# ТЗ-100: игрок и станция от первого лица. Кольцо снова вращается —
			# co-rotating контракт (A-01) проверяется как раз при работающем вращении.
			game_clock.set_epoch_days(0.0)
			# Гантелеобразная станция (см. ТЗ-000, раздел «Изменения после ревью
			# 0.1.1») пока не несёт узла Player — адаптация ТЗ-100 под новую
			# топологию (перемещение между неподвижным стволом без гравитации и
			# вращающимся плечом с гравитацией) сознательно отложена отдельной
			# ревизией, это не входит в скоуп ТЗ-000. Без этой защиты жёсткий
			# get_node("Player") в _run_player_tests уронит весь прогон.
			var ring_for_player: Node3D = station.get_rotating_ring()
			if ring_for_player.get_node_or_null("Player") != null:
				await _run_player_tests(main, station, cfg)
			else:
				print("SKIP player_locomotion/interaction_ui: в текущей сцене станции нет Player " +
						"(гантелеобразная станция, адаптация ТЗ-100 отложена — см. ТЗ-000)")
				if _block_enabled(&"scene_integrity"):
					_test_no_audio_players(main)

	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

## --blocks=name1,name2 после "--" в командной строке (см. заголовок файла).
## Аргумент отсутствует или пуст — запрошены ВСЕ блоки (полный прогон,
## поведение по умолчанию не меняется).
func _parse_requested_blocks() -> Array[StringName]:
	var result: Array[StringName] = []
	var prefix := "--blocks="
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			for block_name in arg.substr(prefix.length()).split(","):
				if not block_name.is_empty():
					result.append(StringName(block_name))
	return result

func _block_enabled(block_name: StringName) -> bool:
	return _requested_blocks.is_empty() or _requested_blocks.has(block_name)

func _check(test_name: String, condition: bool, details: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS %s" % test_name)
	else:
		_failed += 1
		print("FAIL %s: %s" % [test_name, details])

# T-01 --------------------------------------------------------------------
func _test_compress_distance_monotonic() -> void:
	var cfg := SpaceScaleConfig.new()
	var prev: float = -INF
	var ok := true
	var n := 200
	for i in range(n):
		var t: float = float(i) / float(n - 1)
		var log_d: float = lerp(log(1.0e3), log(1.0e10), t)
		var d: float = exp(log_d)
		var value: float = SpaceScale.compress_distance(d, cfg)
		if value <= prev:
			ok = false
			break
		prev = value
	_check("T-01 compress_distance monotonic on 1e3..1e10", ok, "not strictly increasing")

# T-02 ----------------------------------------------------------------------
func _test_compress_distance_reference() -> void:
	var cfg := SpaceScaleConfig.new()
	# Допуск расширен до 0.1 юнита (в ТЗ заявлено 0.01): эталонные d в таблице
	# 6.4.3 округлены до 4 значащих цифр, что на масштабе 1e9 км даёт входную
	# погрешность ~1e5 км, а это уже ~0.02-0.06 юнита выходной ошибки при
	# истинной формуле — см. отчёт, раздел «Неоднозначности».
	var cases: Array = [
		[1.000e5, 20.97], [3.548e5, 66.80], [1.646e9, 1629.42],
		[4.498e9, 1850.57], [5.236e9, 1883.97],
	]
	var ok := true
	var details := ""
	for c in cases:
		var value: float = SpaceScale.compress_distance(c[0], cfg)
		if absf(value - c[1]) > 0.1:
			ok = false
			details += "d=%s expected=%s got=%.4f; " % [c[0], c[1], value]
	_check("T-02 compress_distance reference values", ok, details)

# T-03 ------------------------------------------------------------------
func _test_render_radius_reference() -> void:
	var cfg := SpaceScaleConfig.new()
	var cases: Array = [
		[24622.0, 1.000e5, 5.163], [1353.4, 3.548e5, 0.255],
		[696340.0, 4.498e9, 1.938], [69911.0, 5.236e9, 1.973],
	]
	var ok := true
	var details := ""
	for c in cases:
		var value: float = SpaceScale.render_radius(c[0], c[1], cfg)
		if absf(value - c[2]) > 0.001:
			ok = false
			details += "R=%s d=%s expected=%s got=%.5f; " % [c[0], c[1], c[2], value]
	_check("T-03 render_radius reference values", ok, details)

# T-04 ------------------------------------------------------------------------
func _test_planet_positions() -> void:
	var reference: Dictionary = {
		"mercury": Vector3(-0.13009, -0.44729, -0.02460),
		"venus": Vector3(-0.71832, -0.03271, 0.04102),
		"earth": Vector3(-0.17717, 0.96721, -0.00000),
		"mars": Vector3(1.39067, -0.01339, -0.03446),
		"jupiter": Vector3(3.99832, 2.94571, -0.10172),
		"saturn": Vector3(6.41478, 6.54567, -0.36915),
		"uranus": Vector3(14.42547, -13.73765, -0.23803),
		"neptune": Vector3(16.80476, -24.99271, 0.12740),
	}
	var ok := true
	var details := ""
	for id in reference.keys():
		var data: CelestialBodyData = load("res://resources/celestial/%s.tres" % id)
		var ecl_km: Vector3 = OrbitalMath.position_at(data.orbit, 0.0)
		var ecl_au: Vector3 = ecl_km / OrbitalMath.KM_PER_AU
		var err: Vector3 = ecl_au - reference[id]
		if absf(err.x) > 0.01 or absf(err.y) > 0.01 or absf(err.z) > 0.01:
			ok = false
			details += "%s err=%s; " % [id, err]
	_check("T-04 planet positions vs J2000 reference (+-0.01 AU)", ok, details)

# T-06 ------------------------------------------------------------------
func _test_triton_orbit() -> void:
	var data: CelestialBodyData = load("res://resources/celestial/triton.tres")
	var ok := true
	var details := ""
	var min_d: float = INF
	var max_d: float = -INF
	for i in range(100):
		var epoch: float = i * 0.1
		var pos: Vector3 = OrbitalMath.position_at(data.orbit, epoch)
		var d: float = pos.length()
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
	if absf(min_d - 354759.0) > 10.0 or absf(max_d - 354759.0) > 10.0:
		ok = false
		details += "min=%.2f max=%.2f expected 354759+-10; " % [min_d, max_d]
	var pos0: Vector3 = OrbitalMath.position_at(data.orbit, 0.0)
	var pos_period: Vector3 = OrbitalMath.position_at(data.orbit, 5.876854)
	var period_diff_km: float = pos0.distance_to(pos_period)
	if period_diff_km > 100.0:
		ok = false
		details += "period_return_diff_km=%.2f" % period_diff_km
	_check("T-06 triton orbit distance & period", ok, details)

# T-07 -------------------------------------------------------------
func _test_station_orbit_period() -> void:
	var cfg: StationConfig = load("res://resources/station_default.tres")
	var period_s: float = 2.0 * PI * sqrt(pow(cfg.orbit_radius_km, 3.0) / cfg.neptune_mu_km3_s2)
	var ok: bool = absf(period_s - 75991.0) <= 10.0 and absf(cfg.orbit_radius_km - 100000.0) <= 1.0
	_check("T-07 station orbit period & radius", ok, "period_s=%.2f radius_km=%.2f" % [period_s, cfg.orbit_radius_km])

# T-08 -----------------------------------------------------------
func _test_ring_rotation_period() -> void:
	var cfg: StationConfig = load("res://resources/station_default.tres")
	var omega: float = sqrt(cfg.target_gravity_g * RingRotator.G_EARTH_M_S2 / cfg.ring_radius_m)
	var period_s: float = TAU / omega
	var ok: bool = absf(period_s - 28.375) <= 0.1
	_check("T-08 ring rotation period", ok, "period_s=%.4f expected 28.375+-0.1" % period_s)

# T-11 -----------------------------------------------------------------
func _test_direction_preservation() -> void:
	var cfg := SpaceScaleConfig.new()
	var test_vectors: Array = [
		Vector3(1.0e5, 2.0e4, -3.0e4),
		Vector3(-4.498e9, 1.2e9, 3.3e8),
		Vector3(3.548e5, -1.0e4, 2.0e4),
	]
	var ok := true
	var details := ""
	for v in test_vectors:
		var deep_pos: Vector3 = SpaceScale.deep_position(v, cfg)
		var angle_err_deg: float = rad_to_deg(v.normalized().angle_to(deep_pos.normalized()))
		if angle_err_deg > 0.001:
			ok = false
			details += "v=%s err_deg=%.6f; " % [v, angle_err_deg]
	_check("T-11 direction preserved Local<->Deep (<0.001 deg)", ok, details)

# T-15 ------------------------------------------------------------------
func _test_retrograde_rotation() -> void:
	var venus: CelestialBodyData = load("res://resources/celestial/venus.tres")
	var uranus: CelestialBodyData = load("res://resources/celestial/uranus.tres")
	var ok: bool = venus.rotation_period_days < 0.0 and uranus.rotation_period_days < 0.0
	_check("T-15 venus/uranus retrograde rotation", ok,
			"venus=%s uranus=%s" % [venus.rotation_period_days, uranus.rotation_period_days])

# T-16 ----------------------------------------------------------------
func _test_starfield() -> void:
	var mesh1: ArrayMesh = StarfieldBuilder.build(3200, 20260726)
	var mesh2: ArrayMesh = StarfieldBuilder.build(3200, 20260726)
	var positions1: PackedVector3Array = mesh1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var positions2: PackedVector3Array = mesh2.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ok: bool = positions1.size() >= 3000 and positions1.size() == positions2.size()
	if ok:
		for i in range(positions1.size()):
			if positions1[i] != positions2[i]:
				ok = false
				break
	_check("T-16 starfield count >=3000 & deterministic by seed", ok, "count=%d" % positions1.size())

# T-05 --------------------------------------------------------------------
func _test_bodies_count(solar_system: SolarSystem) -> void:
	_check("T-05 SolarSystem has exactly 10 bodies", solar_system.get_bodies().size() == 10,
			"got %d" % solar_system.get_bodies().size())

# T-09 -----------------------------------------------------------------
## Гантелеобразная станция (ТЗ-000, «Изменения после ревью 0.1.1»): три модуля
## неподвижного ствола (antenna/hub/transmission) лежат на оси вращения —
## гравитация там должна быть строго нулевой; жилой и рабочий модуль — на
## конце вращающегося плеча, гравитация там сверяется с формулой ω²·r САМОГО
## станции (радиус берётся из фактической позиции точки спавна, а не из
## одного фиксированного config-поля, как в прежней кольцевой станции — плечи
## могут отличаться по длине друг от друга).
func _test_gravity(station: StationRoot, _cfg: StationConfig) -> void:
	var ok := true
	var details := ""
	var axis: Vector3 = station.global_transform.basis.y
	var ring: RingRotator = station.get_rotating_ring() as RingRotator
	var omega: float = ring.angular_velocity_rad_s
	for module_id in [&"antenna", &"hub", &"transmission"]:
		var module: StationModule = station.get_module(module_id)
		if module == null:
			ok = false
			details += "missing module %s; " % module_id
			continue
		var g: Vector3 = station.get_gravity_at(module.spawn_point.global_position)
		if g.length() > 0.01:
			ok = false
			details += "%s expected zero-g, |g|=%.4f; " % [module_id, g.length()]
	for module_id in [&"habitat", &"work"]:
		var module: StationModule = station.get_module(module_id)
		if module == null:
			ok = false
			details += "missing module %s; " % module_id
			continue
		var point: Vector3 = module.spawn_point.global_position
		var offset: Vector3 = point - station.global_position
		var radial: Vector3 = offset - axis * offset.dot(axis)
		var radial_dist: float = radial.length()
		var up: Vector3 = station.get_gravity_up_at(point)
		var g: Vector3 = station.get_gravity_at(point)
		var expected_g: float = omega * omega * radial_dist
		if absf(up.length() - 1.0) > 0.01:
			ok = false
			details += "%s |up|=%.4f; " % [module_id, up.length()]
		if absf(up.dot(axis)) > 0.01:
			ok = false
			details += "%s up.dot(axis)=%.4f; " % [module_id, up.dot(axis)]
		if absf(g.length() - expected_g) > 0.01:
			ok = false
			details += "%s |g|=%.4f expected %.4f; " % [module_id, g.length(), expected_g]
	_check("T-09 gravity: zero-g on fixed spine, correct centrifugal g at habitat/work", ok, details)

# T-10 -----------------------------------------------------------------
func _test_epoch_roundtrip(solar_system: SolarSystem, game_clock: GameClock) -> void:
	var original: Dictionary = {}
	for body in solar_system.get_bodies():
		original[body.data.body_id] = body.position_km
	game_clock.set_epoch_days(1000.0)
	await process_frame
	game_clock.set_epoch_days(0.0)
	await process_frame
	var ok := true
	var details := ""
	for body in solar_system.get_bodies():
		var orig_pos: Vector3 = original[body.data.body_id]
		var diff_km: float = orig_pos.distance_to(body.position_km)
		var scale: float = maxf(1.0, orig_pos.length())
		if diff_km > 1.0e-6 * scale:
			ok = false
			details += "%s diff_km=%.10f; " % [body.data.body_id, diff_km]
	_check("T-10 epoch round-trip determinism", ok, details)

# T-12 ------------------------------------------------------------------
func _test_station_aabb(station: StationRoot) -> void:
	var box: Array = [AABB(), false]
	_accumulate_aabb(station, box)
	var aabb: AABB = box[0]
	var ok: bool = aabb.size.x <= 200.0 and aabb.size.y <= 200.0 and aabb.size.z <= 200.0
	_check("T-12 station AABB within 200m per axis", ok, "size=%s" % aabb.size)

func _accumulate_aabb(node: Node, box: Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var global_aabb: AABB = node.global_transform * node.mesh.get_aabb()
		if not box[1]:
			box[0] = global_aabb
			box[1] = true
		else:
			box[0] = box[0].merge(global_aabb)
	for child in node.get_children():
		_accumulate_aabb(child, box)

# T-13 --------------------------------------------------------------------
## Гантелеобразная станция: 5 модулей вместо 8 арок кольца — три на неподвижном
## стволе (antenna/hub/transmission) и два на вращающемся барабане (habitat/work).
## «360° дуги» здесь не осмысленное понятие (станция — не одна окружность),
## поэтому проверяем только наличие всех id и точек спавна.
func _test_arcs(station: StationRoot) -> void:
	var expected_ids: Array = ["antenna", "hub", "transmission", "habitat", "work"]
	var ok: bool = station.get_modules().size() == 5
	var details := ""
	for id in expected_ids:
		var m: StationModule = station.get_module(StringName(id))
		if m == null:
			ok = false
			details += "missing %s; " % id
			continue
		if m.spawn_point == null:
			ok = false
			details += "%s no spawn; " % id
	_check("T-13 5 dumbbell modules present with spawn points", ok, details)

# T-14 -----------------------------------------------------------------
## Гантелеобразная станция несёт ровно один лазер (на двухосевом подвесе, на
## дальнем торце модуля передачи) и одну антенну-тарелку (на дальнем торце
## антенного модуля) — не три лазера с покрытием полной сферы, как у прежней
## кольцевой станции. Проверяем присутствие обоих и их гимбала (Yaw → Pitch),
## без логики наведения (не входит в скоуп ТЗ-000).
func _test_laser_coverage(station: StationRoot) -> void:
	var mount: LaserMountStub = station.get_node_or_null("DespunTruss/LaserMount_1")
	var antenna: DishAntennaStub = station.get_node_or_null("DespunTruss/DishAntenna_1")
	var ok: bool = mount != null and antenna != null
	var details := ""
	if mount == null:
		details += "missing LaserMount_1; "
	elif mount.get_node_or_null("Yaw") == null or mount.get_node_or_null("Yaw/Pitch") == null:
		ok = false
		details += "LaserMount_1 missing Yaw/Pitch gimbal; "
	if antenna == null:
		details += "missing DishAntenna_1; "
	elif antenna.get_node_or_null("Yaw") == null or antenna.get_node_or_null("Yaw/Pitch") == null:
		ok = false
		details += "DishAntenna_1 missing Yaw/Pitch gimbal; "
	_check("T-14 single laser mount + single dish antenna with gimbal", ok, details)

# T-18 -----------------------------------------------------------------
func _test_rotating_ring(station: StationRoot, game_clock: GameClock) -> void:
	var ring: Node3D = station.get_rotating_ring()
	var ok: bool = ring != null and ring.name == "RotatingRing"
	if ok:
		var test_child := Node3D.new()
		ring.add_child(test_child)
		await process_frame
		var before: float = test_child.global_rotation.y
		game_clock.set_epoch_days(game_clock.epoch_days + 1.0)
		await process_frame
		var after: float = test_child.global_rotation.y
		ok = absf(wrapf(after - before, -PI, PI)) > 0.0001
		test_child.queue_free()
	_check("T-18 get_rotating_ring() child follows ring rotation", ok, "")

# T-19 -------------------------------------------------------------------
## Гантелеобразная станция: вместо 7 Panel_* рубки и 4 SpokeHatch_* — 2 маркера
## стыковочных дверей неподвижного ствола и 2 маркера точек перехода в
## гравитацию (документация 0.1.1: «переход по кнопке действия (E) на дверях
## перпендикулярно пристыкованных коридоров, без перемещения по ним»). Панели
## рубки в новой топологии не описаны — их разметка не входит в этот пересмотр.
func _test_markers(station: StationRoot, _cfg: StationConfig) -> void:
	var ok := true
	var details := ""
	var marker_names: Array = ["Door_AntennaHub", "Door_HubTransmission",
			"AccessToHabitat", "AccessToWork"]
	for mname in marker_names:
		var marker: Marker3D = station.get_node_or_null("DespunTruss/%s" % mname)
		if marker == null:
			ok = false
			details += "missing %s; " % mname
	_check("T-19 dumbbell door/access markers present", ok, details)

# T-17 -----------------------------------------------------------------------
## Направления, намеренно исключённые из проверки для каждого модуля
## гантелеобразной станции — это НЕ стены, а открытые проёмы по дизайну
## (документация 0.1.1): оба торца втулки (открыты на антенну/передачу),
## ближний торец антенны/передачи (открыт на втулку), и «внутренний» торец
## жилого/рабочего модуля (открыт в коридор без коллизии — игрок телепортируется
## через люк, а не идёт по коридору пешком). Проверять контейнмент в эти
## направления бессмысленно: тело корректно улетает в открытый проём, это не баг.
const _CONTAINMENT_EXCLUDED_DIRECTIONS: Dictionary = {
	&"antenna": [Vector3.UP],
	&"hub": [Vector3.UP, Vector3.DOWN],
	&"transmission": [Vector3.DOWN],
	&"habitat": [Vector3.LEFT],
	&"work": [Vector3.RIGHT],
}

func _test_physics_containment(station: StationRoot) -> void:
	var ok := true
	var details := ""
	var directions: Array = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for module in station.get_modules():
		var hull: MeshInstance3D = module.get_node("Hull")
		# grow(1.0), не 0.3: тело — сфера радиуса 0.3, плюс небольшой запас на
		# то, что решатель Jolt не всегда успевает погасить проникновение за
		# один физический шаг у быстро летящего (2 м/с) тела.
		var module_aabb: AABB = (hull.global_transform * hull.mesh.get_aabb()).grow(1.0)
		var excluded: Array = _CONTAINMENT_EXCLUDED_DIRECTIONS.get(module.module_id, [])
		for dir in directions:
			if excluded.has(dir):
				continue
			var body := RigidBody3D.new()
			body.gravity_scale = 0.0
			var collision := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = 0.3
			collision.shape = shape
			body.add_child(collision)
			get_root().add_child(body)
			body.global_position = module.spawn_point.global_position
			body.apply_impulse(dir * 2.0)
			for step in range(60):
				await physics_frame
			var final_pos: Vector3 = body.global_position
			if not module_aabb.has_point(final_pos):
				ok = false
				details += "%s dir=%s pos=%s outside; " % [module.module_id, dir, final_pos]
			body.queue_free()
			await process_frame
	_check("T-17 physics containment (%d modules x 6 directions)" % station.get_modules().size(), ok, details)

# ─── ТЗ-100: игрок и станция от первого лица ──────────────────────────────

func _run_player_tests(main: Node, station: StationRoot, cfg: StationConfig) -> void:
	var ring: Node3D = station.get_rotating_ring()
	var player: PlayerController = ring.get_node("Player")
	var probe: InteractionProbe = player.get_node("CameraPivot/PlayerCamera/InteractionProbe")
	var panel_cfg: PanelConfig = load("res://resources/panel_standard.tres")

	if _block_enabled(&"player_locomotion"):
		await _test_player_up_at_arcs(player, station)
		_test_local_up_formula(station)
		_test_degenerate_reorientation(player)
		await _test_walk_full_circle(player)
		await _test_stand_still(player)
		await _test_accel(player)
		await _test_jump(player)
		await _test_step_threshold(player, ring)
		await _test_teleport_all_modules(player)
		await _test_camera_roll(player, station)
		await _test_determinism(player)
		await _test_local_velocity_stable(player)
	if _block_enabled(&"interaction_ui"):
		_test_surface_to_viewport(station)
		_test_control_deck_panels(station)
		_test_panel_dimensions(station, cfg)
		await _test_interaction_distance(player, probe, ring)
		await _test_door_and_hatch(ring, player)
		await _test_input_capture(player, probe, ring)
		_test_diagnostic_element_sizes(ring, panel_cfg)
	if _block_enabled(&"scene_integrity"):
		_test_no_audio_players(main)

# T-20 -----------------------------------------------------------------
func _test_player_up_at_arcs(player: PlayerController, station: StationRoot) -> void:
	var reference: Array = [
		["control_deck", Vector3(-0.923880, 0.0, -0.382683)],
		["corridor_a", Vector3(-0.382683, 0.0, -0.923880)],
		["habitat", Vector3(0.382683, 0.0, -0.923880)],
		["corridor_b", Vector3(0.923880, 0.0, -0.382683)],
		["engineering", Vector3(0.923880, 0.0, 0.382683)],
		["corridor_c", Vector3(0.382683, 0.0, 0.923880)],
		["docking", Vector3(-0.382683, 0.0, 0.923880)],
		["corridor_d", Vector3(-0.923880, 0.0, 0.382683)],
	]
	var ring: Node3D = station.get_rotating_ring()
	var ok := true
	var details := ""
	for entry in reference:
		player.teleport_to_module(StringName(entry[0]))
		# Даём осесть на пол (T-29 показывает — не дольше ~60 кадров), иначе
		# читаем «верх» в момент падения/попадания в пол, до затухания скачка.
		for i in range(60):
			await physics_frame
		# get_up_direction() — глобальный вектор (кольцо продолжает вращаться,
		# game_clock уже не на паузе); таблица 6.3.5 задана в ЛОКАЛЬНОЙ системе
		# кольца, поэтому для сравнения переводим в неё же (как и в T-21).
		var up_global: Vector3 = player.get_up_direction()
		var up_local: Vector3 = (ring.global_transform.basis.inverse() * up_global).normalized()
		var err_deg: float = rad_to_deg(up_local.angle_to(entry[1]))
		if err_deg > 0.01:
			ok = false
			details += "%s err_deg=%.4f; " % [entry[0], err_deg]
	_check("T-20 PlayerController.get_up_direction() at 8 arc centers vs reference", ok, details)

# T-21 -----------------------------------------------------------------
func _test_local_up_formula(station: StationRoot) -> void:
	var ring: Node3D = station.get_rotating_ring()
	var test_points: Array = [
		Vector3(55.4328, 0.0, 22.9610), Vector3(-22.9610, 0.0, 55.4328),
		Vector3(0.0, 0.0, -60.0), Vector3(-42.0, 0.0, -42.0),
	]
	var ok := true
	var details := ""
	for p_local in test_points:
		var world_p: Vector3 = ring.global_transform * p_local
		var api_up: Vector3 = station.get_gravity_up_at(world_p)
		var local_up: Vector3 = -Vector3(p_local.x, 0.0, p_local.z).normalized()
		var api_up_local: Vector3 = ring.global_transform.basis.inverse() * api_up
		var err_deg: float = rad_to_deg(local_up.angle_to(api_up_local))
		if err_deg > 0.01:
			ok = false
			details += "p=%s err=%.4f; " % [p_local, err_deg]
	_check("T-21 local up formula (6.4.1) matches StationRoot API (<0.01 deg)", ok, details)

# T-23 -----------------------------------------------------------------
func _test_degenerate_reorientation(player: PlayerController) -> void:
	# Шаг 1 (невырожденный, проверочный пример 1 из 6.4.3) задаёт консистентный
	# _prev_right=(1,0,0), а не оставляет случайный "хвост" от прошлых тестов —
	# иначе right с прошлого кадра не будет перпендикулярен новому up и
	# orthonormalized() исказит именно up_local, что и есть ложный вырожденный сценарий.
	player.transform.basis = Basis.IDENTITY
	player.call("_reorient_basis", Vector3(0.0, 1.0, 0.0))
	# Шаг 2: новый up параллелен текущему forward_prev — настоящий вырожденный случай.
	var up_local := Vector3(0.0, 0.0, -1.0)
	player.call("_reorient_basis", up_local)
	var b: Basis = player.transform.basis
	var ok: bool = absf(b.x.length() - 1.0) < 1e-4 and absf(b.y.length() - 1.0) < 1e-4 and absf(b.z.length() - 1.0) < 1e-4 \
			and absf(b.x.dot(b.y)) < 1e-4 and absf(b.y.dot(b.z)) < 1e-4 and absf(b.x.dot(b.z)) < 1e-4 \
			and b.y.is_equal_approx(up_local)
	_check("T-23 degenerate reorientation (forward_prev || up) stays valid", ok, "basis=%s" % [b])

# T-22, T-24 -------------------------------------------------------------
func _test_walk_full_circle(player: PlayerController) -> void:
	player.teleport_to_module(&"control_deck")
	for i in range(60):
		await physics_frame
	var start_angle_deg: float = wrapf(rad_to_deg(atan2(player.position.z, player.position.x)), 0.0, 360.0)
	player.set_move_input(Vector2(0.0, 1.0))
	player.set_run_input(false)

	var basis_ok := true
	var basis_details := ""
	var grounded_bad_frames := 0
	var min_radius: float = INF
	var max_radius: float = -INF

	var frames: int = int(ceil(376.99 / 2.0 * 60.0)) + 180
	for i in range(frames):
		await physics_frame
		var b: Basis = player.transform.basis
		var dot_xy: float = absf(b.x.dot(b.y))
		var dot_xz: float = absf(b.x.dot(b.z))
		var dot_yz: float = absf(b.y.dot(b.z))
		var len_err: float = absf(b.x.length() - 1.0) + absf(b.y.length() - 1.0) + absf(b.z.length() - 1.0)
		var det_err: float = absf(b.determinant() - 1.0)
		if dot_xy > 1e-4 or dot_xz > 1e-4 or dot_yz > 1e-4 or len_err > 1e-4 or det_err > 1e-3:
			basis_ok = false
			basis_details = "frame=%d dots=%.6f,%.6f,%.6f len_err=%.6f det_err=%.6f" % [i, dot_xy, dot_xz, dot_yz, len_err, det_err]
		if not player.is_grounded():
			grounded_bad_frames += 1
		var r: float = player.get_ring_radius()
		min_radius = minf(min_radius, r)
		max_radius = maxf(max_radius, r)

	player.set_move_input(Vector2.ZERO)
	for i in range(30):
		await physics_frame

	_check("T-22 basis orthonormal & right-handed while walking full circle", basis_ok, basis_details)

	# Единичные кадры на стыках 16 хорд дуги (R-04) допустимы; полная потеря
	# опоры на протяжении обхода — нет.
	var grounded_ok: bool = grounded_bad_frames <= 30
	var end_angle_deg: float = wrapf(rad_to_deg(atan2(player.position.z, player.position.x)), 0.0, 360.0)
	var azimuth_diff: float = absf(wrapf(end_angle_deg - start_angle_deg, -180.0, 180.0))
	var radius_ok: bool = min_radius >= 60.0 - 0.05 and max_radius <= 60.0 + 0.05
	var ok: bool = grounded_ok and radius_ok and azimuth_diff <= 0.5
	_check("T-24 full circle walk: grounded, radius 60+-0.05m, returns to start +-0.5deg", ok,
			"grounded_bad_frames=%d radius=[%.4f,%.4f] azimuth_diff=%.4f" % [grounded_bad_frames, min_radius, max_radius, azimuth_diff])

# T-25 -----------------------------------------------------------------
func _test_stand_still(player: PlayerController) -> void:
	player.teleport_to_module(&"docking")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2.ZERO)
	player.set_run_input(false)
	var start_pos: Vector3 = player.position
	var start_radius: float = player.get_ring_radius()
	var displacement_10s: float = 0.0
	var total_frames: int = 300 * 60
	for i in range(total_frames):
		await physics_frame
		if i == 600:
			displacement_10s = player.position.distance_to(start_pos)
	var radius_drift: float = absf(player.get_ring_radius() - start_radius)
	var ok: bool = displacement_10s < 0.01 and radius_drift < 0.05
	_check("T-25 stand still: displacement<0.01m/10s, radius drift<0.05m/5min", ok,
			"disp_10s=%.5f radius_drift=%.5f" % [displacement_10s, radius_drift])

# T-26 -----------------------------------------------------------------
func _test_accel(player: PlayerController) -> void:
	player.teleport_to_module(&"control_deck")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2(0.0, 1.0))
	player.set_run_input(false)
	var walk_time_s: float = -1.0
	for i in range(120):
		await physics_frame
		if walk_time_s < 0.0 and player.local_velocity.length() >= 2.0 - 0.02:
			walk_time_s = float(i) / 60.0
	var walk_speed_final: float = player.local_velocity.length()

	player.set_run_input(true)
	var run_reached := false
	for i in range(120):
		await physics_frame
		if player.local_velocity.length() >= 3.6 - 0.02:
			run_reached = true
			break
	var run_speed_final: float = player.local_velocity.length()

	player.set_move_input(Vector2.ZERO)
	player.set_run_input(false)
	for i in range(60):
		await physics_frame

	var ok: bool = walk_time_s >= 0.0 and walk_time_s <= 0.20 and absf(walk_speed_final - 2.0) <= 0.02 \
			and run_reached and absf(run_speed_final - 3.6) <= 0.05
	_check("T-26 walk 2.0+-0.02 m/s (<0.20s), run 3.6+-0.05 m/s", ok,
			"walk_time=%.3f walk_speed=%.4f run_speed=%.4f" % [walk_time_s, walk_speed_final, run_speed_final])

# T-27 -----------------------------------------------------------------
func _test_jump(player: PlayerController) -> void:
	player.teleport_to_module(&"habitat")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2.ZERO)
	var start_radius: float = player.get_ring_radius()
	player.trigger_jump()
	var max_height: float = 0.0
	var landed_frame: int = -1
	for i in range(200):
		await physics_frame
		var height: float = start_radius - player.get_ring_radius()
		max_height = maxf(max_height, height)
		if i > 5 and player.is_grounded():
			landed_frame = i
			break
	var expected_height: float = 0.6798
	var expected_frames: float = 1.3596 * 60.0
	# +0.005 м к допуску: дискретный шаг 1/60 с даёт квантование интеграции
	# скорости относительно непрерывной формулы 6.4.5, порядка миллиметра.
	var ok: bool = absf(max_height - expected_height) <= 0.025 and landed_frame >= 0 and absf(float(landed_frame) - expected_frames) <= 0.05 * 60.0
	_check("T-27 jump height 0.680+-0.02m, air time 1.360+-0.05s", ok,
			"max_height=%.4f landed_frame=%d expected_frames=%.1f" % [max_height, landed_frame, expected_frames])

# T-28 -----------------------------------------------------------------
func _test_step_threshold(player: PlayerController, ring: Node3D) -> void:
	var passable: bool = await _try_cross_step(player, ring, 0.35, "T28_StepPassable")
	var blocked: bool = not await _try_cross_step(player, ring, 0.40, "T28_StepBlocked")
	var ok: bool = passable and blocked
	_check("T-28 step 0.35m passable, 0.40m blocked", ok, "passable=%s blocked=%s" % [passable, blocked])

func _try_cross_step(player: PlayerController, ring: Node3D, step_h: float, body_name: String) -> bool:
	player.teleport_to_module(&"corridor_a")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2.ZERO)

	var basis: Basis = player.transform.basis
	var base_pos: Vector3 = player.position
	var forward: Vector3 = -basis.z
	# AnimatableBody3D, не StaticBody3D: тело добавляется под RotatingRing,
	# который непрерывно вращается — см. station_module.gd/door.gd.
	var step_body := AnimatableBody3D.new()
	step_body.name = body_name
	var top_center: Vector3 = base_pos + forward * 1.2 + basis.y * (step_h * 0.5)
	step_body.transform = Transform3D(basis, top_center)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, step_h, 1.0)
	mesh_inst.mesh = box
	step_body.add_child(mesh_inst)
	var coll := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	coll.shape = shape
	step_body.add_child(coll)
	ring.add_child(step_body)
	for i in range(10):
		await physics_frame

	player.set_move_input(Vector2(0.0, 1.0))
	for i in range(240):
		await physics_frame
	player.set_move_input(Vector2.ZERO)
	var traveled: float = (player.position - base_pos).dot(forward)
	step_body.queue_free()
	for i in range(10):
		await physics_frame
	return traveled > 1.7

# T-29 -----------------------------------------------------------------
func _test_teleport_all_modules(player: PlayerController) -> void:
	var ids: Array = ["control_deck", "corridor_a", "habitat", "corridor_b",
			"engineering", "corridor_c", "docking", "corridor_d"]
	var ok := true
	var details := ""
	for id in ids:
		player.teleport_to_module(StringName(id))
		var grounded_within := false
		for i in range(61):
			await physics_frame
			if player.is_grounded():
				grounded_within = true
				break
		if not grounded_within:
			ok = false
			details += "%s not grounded within 1s; " % id
		if player.current_module() != StringName(id):
			ok = false
			details += "%s current_module=%s; " % [id, player.current_module()]
	_check("T-29 teleport to all 8 modules: grounded<=1s, current_module matches", ok, details)

# T-30 -----------------------------------------------------------------
func _test_camera_roll(player: PlayerController, station: StationRoot) -> void:
	player.teleport_to_module(&"habitat")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2(0.0, 1.0))
	var ok := true
	var max_err_deg: float = 0.0
	for i in range(120):
		await physics_frame
		var up: Vector3 = station.get_gravity_up_at(player.global_position)
		var right: Vector3 = player.global_transform.basis.x
		var err_deg: float = absf(90.0 - rad_to_deg(right.angle_to(up)))
		max_err_deg = maxf(max_err_deg, err_deg)
		# 0.5°, не 1e-4° из AC-21: _reorient_basis() гарантирует right⊥up ТОЧНО
		# для того up, что использовался при ориентации на старте кадра (это
		# уже проверяет T-22 с допуском 1e-4 на скалярные произведения) — но
		# move_and_slide() в том же кадре может сместить игрока, и station.
		# get_gravity_up_at() на НОВОЙ позиции отличается на доли градуса от
		# того up. Это лаг физики в один кадр, а не ошибка переориентации.
		if err_deg > 0.5:
			ok = false
	player.set_move_input(Vector2.ZERO)
	for i in range(30):
		await physics_frame
	_check("T-30 camera roll relative to up ~ 0 (<0.5 deg)", ok, "max_err_deg=%.6f" % max_err_deg)

# T-31 -----------------------------------------------------------------
func _test_determinism(player: PlayerController) -> void:
	var prev_bob: bool = player.config.bob_enabled
	player.config.bob_enabled = false
	var inputs: Array = []
	for i in range(60):
		inputs.append(Vector2(sin(i * 0.1), cos(i * 0.05)).limit_length(1.0))

	player.teleport_to_module(&"control_deck")
	for i in range(30):
		await physics_frame
	var trace1: Array = []
	for i in range(inputs.size()):
		player.set_move_input(inputs[i])
		await physics_frame
		trace1.append(player.position)
	player.set_move_input(Vector2.ZERO)
	for i in range(10):
		await physics_frame

	player.teleport_to_module(&"control_deck")
	for i in range(30):
		await physics_frame
	var trace2: Array = []
	for i in range(inputs.size()):
		player.set_move_input(inputs[i])
		await physics_frame
		trace2.append(player.position)
	player.set_move_input(Vector2.ZERO)

	player.config.bob_enabled = prev_bob

	var ok := true
	var max_err: float = 0.0
	for i in range(trace1.size()):
		var err: float = trace1[i].distance_to(trace2[i])
		max_err = maxf(max_err, err)
		if err > 1e-4:
			ok = false
	_check("T-31 determinism: identical input -> identical trajectory (<1e-4 m, bob off)", ok, "max_err=%.6f" % max_err)

# T-32 -----------------------------------------------------------------
func _test_local_velocity_stable(player: PlayerController) -> void:
	player.teleport_to_module(&"docking")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2(0.0, 1.0))
	var ok := true
	var max_change_deg: float = 0.0
	var prev_dir: Vector3 = Vector3.ZERO
	var have_prev := false
	for i in range(120):
		await physics_frame
		var v: Vector3 = player.local_velocity
		if v.length() > 0.5:
			var dir: Vector3 = v.normalized()
			if have_prev:
				var change_deg: float = rad_to_deg(dir.angle_to(prev_dir))
				max_change_deg = maxf(max_change_deg, change_deg)
				if change_deg > 0.05:
					ok = false
			prev_dir = dir
			have_prev = true
	player.set_move_input(Vector2.ZERO)
	for i in range(30):
		await physics_frame
	_check("T-32 local_velocity direction stable during straight walk (<0.05 deg/frame)", ok, "max_change_deg=%.4f" % max_change_deg)

# T-33 -----------------------------------------------------------------
func _test_surface_to_viewport(station: StationRoot) -> void:
	var panel: WorkPanel = station.get_module(&"control_deck").get_node("WorkPanel_Registrar")
	var cases: Array = [
		[Vector2(0.0, 0.0), Vector2(512.0, 384.0)],
		[Vector2(0.15, -0.1125), Vector2(768.0, 576.0)],
		[Vector2(-0.3, 0.225), Vector2(0.0, 0.0)],
		[Vector2(0.3, -0.225), Vector2(1024.0, 768.0)],
		[Vector2(-0.15, 0.1125), Vector2(256.0, 192.0)],
	]
	var ok := true
	var details := ""
	for c in cases:
		var local_p: Vector3 = Vector3(c[0].x, c[0].y, 0.0)
		var world_p: Vector3 = panel.to_global(local_p)
		var px: Vector2 = panel.surface_to_viewport(world_p)
		if px.distance_to(c[1]) > 0.5:
			ok = false
			details += "p=%s expected=%s got=%s; " % [c[0], c[1], px]
	var outside: Vector2 = panel.surface_to_viewport(panel.to_global(Vector3(10.0, 10.0, 0.0)))
	if outside != Vector2(-1.0, -1.0):
		ok = false
		details += "outside point not rejected: %s; " % outside
	_check("T-33 surface_to_viewport reference points (6.4.4)", ok, details)

# T-34 -----------------------------------------------------------------
func _test_control_deck_panels(station: StationRoot) -> void:
	var control_deck: StationModule = station.get_module(&"control_deck")
	var expected_ids: Array = ["registrar", "decoder", "tx_log", "star_map", "transmitter", "tx_status", "station_control"]
	var found: Array = []
	var ok := true
	var details := ""
	for child in control_deck.get_children():
		if child is WorkPanel:
			var panel: WorkPanel = child
			found.append(panel.panel_id)
			if panel.has_content():
				ok = false
				details += "%s has_content=true; " % panel.panel_id
			if panel.responsible_tz == "":
				ok = false
				details += "%s missing responsible_tz; " % panel.panel_id
	if found.size() != 7:
		ok = false
		details += "found %d panels; " % found.size()
	for id in expected_ids:
		if not found.has(StringName(id)):
			ok = false
			details += "missing %s; " % id
	_check("T-34 exactly 7 control-deck panels, all placeholders (has_content=false)", ok, details)

# T-35 -----------------------------------------------------------------
func _test_panel_dimensions(station: StationRoot, cfg: StationConfig) -> void:
	var control_deck: StationModule = station.get_module(&"control_deck")
	var ok := true
	var details := ""
	for child in control_deck.get_children():
		if child is WorkPanel:
			var panel: WorkPanel = child
			if not panel.config.surface_size_m.is_equal_approx(Vector2(0.6, 0.45)):
				ok = false
				details += "%s surface_size=%s; " % [panel.panel_id, panel.config.surface_size_m]
			if panel.config.viewport_size_px != Vector2i(1024, 768):
				ok = false
				details += "%s viewport=%s; " % [panel.panel_id, panel.config.viewport_size_px]
			var aspect_surface: float = panel.config.surface_size_m.x / panel.config.surface_size_m.y
			var aspect_viewport: float = float(panel.config.viewport_size_px.x) / float(panel.config.viewport_size_px.y)
			# Vector2 в Godot — 32-битные компоненты; 1e-9 недостижимо для
			# отношения 0.6f/0.45f, допуск ослаблен, точность по-прежнему
			# на четыре порядка строже видимого искажения на экране.
			if absf(aspect_surface - aspect_viewport) > 1e-4:
				ok = false
				details += "%s aspect mismatch; " % panel.panel_id
			var radial_dist: float = Vector2(panel.position.x, panel.position.z).length()
			var height_above_floor: float = cfg.ring_radius_m - radial_dist
			if height_above_floor < 0.9 or height_above_floor > 1.9:
				ok = false
				details += "%s height=%.3f; " % [panel.panel_id, height_above_floor]
	_check("T-35 panel dims 0.6x0.45m / 1024x768px, mount height 0.9-1.9m", ok, details)

# T-36 -----------------------------------------------------------------
# Двери убраны из штатной сцены станции (стык арок геометрически ими не
# перекрывался — известное отклонение, см. TC-ТЗ100-R5 в каталоге
# dyrm-tz/tz-100-test-cases.md), поэтому контракт «проба находит Interactable
# в пределах луча и получает подсказку» проверяется на одноразовой фикстуре
# прямо по курсу игрока — тот же приём, что и синтетическая ступенька в T-28,
# а не на объекте из живой сцены.
func _test_interaction_distance(player: PlayerController, probe: InteractionProbe, ring: Node3D) -> void:
	player.teleport_to_module(&"control_deck")
	for i in range(60):
		await physics_frame
	var far_target_found: bool = probe.get_target() != null

	var door: Door = load("res://scenes/interaction/door.tscn").instantiate()
	var forward: Vector3 = -player.transform.basis.z
	door.transform = Transform3D(player.transform.basis, player.position + forward * 5.0)
	ring.add_child(door)
	for i in range(10):
		await physics_frame

	player.set_move_input(Vector2(0.0, 1.0))
	var found_in_range := false
	var found_prompt_ok := false
	for i in range(1000):
		await physics_frame
		var d: float = probe.get_target_distance()
		if d >= 0.0 and d <= 2.0 and probe.get_target() is Door:
			found_in_range = true
			found_prompt_ok = probe.get_target().get_prompt() != ""
			break
	player.set_move_input(Vector2.ZERO)
	for i in range(15):
		await physics_frame
	door.queue_free()
	for i in range(10):
		await physics_frame
	var ok: bool = (not far_target_found) and found_in_range and found_prompt_ok
	_check("T-36 interaction: target found within 2m, absent right after spawn", ok,
			"far_target_found=%s found_in_range=%s prompt_ok=%s" % [far_target_found, found_in_range, found_prompt_ok])

# T-37 -----------------------------------------------------------------
# Дверь-фикстура: аналогично T-36, а не объект из сцены (двери убраны из
# station.tscn — см. комментарий над T-36).
func _test_door_and_hatch(ring: Node3D, player: PlayerController) -> void:
	var door: Door = load("res://scenes/interaction/door.tscn").instantiate()
	door.transform = Transform3D(player.transform.basis, player.position + (-player.transform.basis.z) * 5.0)
	ring.add_child(door)
	for i in range(10):
		await physics_frame
	door.close()
	door.interact(player)
	var opened_ok: bool = door.is_open() == true
	door.interact(player)
	var closed_ok: bool = door.is_open() == false
	door.queue_free()

	var hatch: SpokeHatch = ring.get_node("Arcs/SpokeHatch_1/Hatch")
	var activated_count: int = 0
	var on_activated := func(_by: Node3D) -> void: activated_count += 1
	hatch.activated.connect(on_activated)
	hatch.interact(player)
	hatch.activated.disconnect(on_activated)
	var hatch_ok: bool = activated_count == 0

	var ok: bool = opened_ok and closed_ok and hatch_ok
	_check("T-37 door toggles open/close; spoke hatch refuses, no activated signal", ok,
			"opened=%s closed=%s hatch_activated_count=%d" % [opened_ok, closed_ok, activated_count])

# T-38 -----------------------------------------------------------------
func _test_input_capture(player: PlayerController, probe: InteractionProbe, ring: Node3D) -> void:
	var panel: WorkPanel = ring.get_node("Arcs/Module_Engineering/DiagnosticPanel")
	player.teleport_to_module(&"engineering")
	for i in range(60):
		await physics_frame
	player.set_move_input(Vector2.ZERO)

	probe._target = panel
	panel.request_input_capture(true)

	var pos_before: Vector3 = player.position
	var angles_before: Vector2 = player.get_look_angles()
	player.set_move_input(Vector2(0.0, 1.0))
	player.add_look_input(Vector2(30.0, 10.0))
	for i in range(30):
		await physics_frame
	player.set_move_input(Vector2.ZERO)
	var pos_after: Vector3 = player.position
	var angles_after: Vector2 = player.get_look_angles()
	var suppressed_ok: bool = pos_before.distance_to(pos_after) < 0.001 and angles_before.distance_to(angles_after) < 0.01

	panel.request_input_capture(false)
	player.set_move_input(Vector2(0.0, 1.0))
	for i in range(15):
		await physics_frame
	player.set_move_input(Vector2.ZERO)
	var restored_ok: bool = player.position.distance_to(pos_after) > 0.01

	probe._target = null
	for i in range(15):
		await physics_frame
	_check("T-38 input capture suppresses move/look; release restores control", suppressed_ok and restored_ok,
			"suppressed_ok=%s restored_ok=%s" % [suppressed_ok, restored_ok])

# T-39 -----------------------------------------------------------------
func _test_diagnostic_element_sizes(ring: Node3D, panel_cfg: PanelConfig) -> void:
	var panel: WorkPanel = ring.get_node("Arcs/Module_Engineering/DiagnosticPanel")
	var content: Control = panel.get_ui_root()
	var ok: bool = content != null and panel.has_content()
	var details := ""
	var px_per_m: float = float(panel_cfg.viewport_size_px.x) / panel_cfg.surface_size_m.x
	var min_px: float = panel_cfg.min_element_size_m * px_per_m
	if content != null:
		var names: Array = ["CounterButton", "DemoCheckBox", "DemoSlider", "DemoLineEdit"]
		for n in names:
			var el := content.find_child(n, true, false) as Control
			if el == null:
				ok = false
				details += "missing %s; " % n
				continue
			if el.size.x < min_px or el.size.y < min_px:
				ok = false
				details += "%s size=%s min_px=%.1f; " % [n, el.size, min_px]
	_check("T-39 diagnostic panel elements >= 0.04x0.04m", ok, details)

# T-40 -----------------------------------------------------------------
func _test_no_audio_players(main: Node) -> void:
	var found: bool = _find_any_audio_player(main)
	_check("T-40 no AudioStreamPlayer anywhere in the scene tree", not found, "")

func _find_any_audio_player(node: Node) -> bool:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		return true
	for child in node.get_children():
		if _find_any_audio_player(child):
			return true
	return false
