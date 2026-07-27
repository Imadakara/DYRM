## Автотесты ТЗ-000. Запуск:
##   godot --headless --path . --script res://tools/run_tests.gd
## Одна строка на тест (PASS/FAIL), финальная строка RESULT: N passed, M failed.
## Код возврата 0 только если все тесты прошли.
extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	_test_compress_distance_monotonic()
	_test_compress_distance_reference()
	_test_render_radius_reference()
	_test_planet_positions()
	_test_triton_orbit()
	_test_station_orbit_period()
	_test_ring_rotation_period()
	_test_direction_preservation()
	_test_retrograde_rotation()
	_test_starfield()

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = main_scene.instantiate()
	get_root().add_child(main)
	for i in range(5):
		await process_frame

	var solar_system: SolarSystem = main.get_node("SolarSystem")
	var station: StationRoot = main.get_node("Station")
	var game_clock: GameClock = main.get_node("GameClock")
	var cfg: StationConfig = load("res://resources/station_default.tres")

	_test_bodies_count(solar_system)
	_test_gravity(station, cfg)
	await _test_epoch_roundtrip(solar_system, game_clock)
	_test_station_aabb(station)
	_test_arcs(station)
	_test_laser_coverage(station)
	await _test_rotating_ring(station, game_clock)
	_test_markers(station, cfg)
	# Останавливаем игровое время: кольцо вращается непрерывно (даже с
	# time_scale=1), а T-17 сравнивает финальную позицию тела с AABB модуля,
	# снятым в начале — при вращающемся кольце обе величины «уезжают» друг
	# от друга за секунды симуляции импульса. Сама физика (Jolt) не зависит
	# от GameClock и продолжает считаться нормально.
	game_clock.paused = true
	await _test_physics_containment(station)

	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

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
func _test_gravity(station: StationRoot, cfg: StationConfig) -> void:
	var ok := true
	var details := ""
	var expected_g: float = cfg.target_gravity_g * RingRotator.G_EARTH_M_S2
	var axis: Vector3 = station.global_transform.basis.y
	for module in station.get_modules():
		var mid_angle_rad: float = deg_to_rad(0.0)
		# читаем реальные границы дуги модуля, а не предполагаем их
		mid_angle_rad = _module_mid_angle_rad(module)
		var local_floor: Vector3 = Vector3(cos(mid_angle_rad), 0.0, sin(mid_angle_rad)) * cfg.ring_radius_m
		var floor_point: Vector3 = module.global_transform * local_floor
		var up: Vector3 = station.get_gravity_up_at(floor_point)
		var g: Vector3 = station.get_gravity_at(floor_point)
		if absf(up.length() - 1.0) > 0.01:
			ok = false
			details += "%s |up|=%.4f; " % [module.module_id, up.length()]
		if absf(up.dot(axis)) > 0.01:
			ok = false
			details += "%s up.dot(axis)=%.4f; " % [module.module_id, up.dot(axis)]
		if absf(g.length() - expected_g) > 0.01:
			ok = false
			details += "%s |g|=%.4f expected %.4f; " % [module.module_id, g.length(), expected_g]
	_check("T-09 gravity at 8 floor points", ok, details)

func _module_mid_angle_rad(module: StationModule) -> float:
	# StationModule сам не хранит вычисленный mid_angle — читаем через доступные
	# @export поля напрямую (angle_start_deg/angle_end_deg — публичные свойства).
	return deg_to_rad((module.angle_start_deg + module.angle_end_deg) * 0.5)

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
func _test_arcs(station: StationRoot) -> void:
	var expected_ids: Array = ["control_deck", "corridor_a", "habitat", "corridor_b",
			"engineering", "corridor_c", "docking", "corridor_d"]
	var ok: bool = station.get_modules().size() == 8
	var details := ""
	var total_span: float = 0.0
	for id in expected_ids:
		var m: StationModule = station.get_module(StringName(id))
		if m == null:
			ok = false
			details += "missing %s; " % id
			continue
		total_span += m.angle_end_deg - m.angle_start_deg
		if m.spawn_point == null:
			ok = false
			details += "%s no spawn; " % id
	if absf(total_span - 360.0) > 0.01:
		ok = false
		details += "total_span=%.4f; " % total_span
	_check("T-13 8 arcs, correct ids, 360 deg total, spawns present", ok, details)

# T-14 -----------------------------------------------------------------
func _test_laser_coverage(station: StationRoot) -> void:
	var mounts: Array = []
	for mount_name in ["LaserMount_1", "LaserMount_2", "LaserMount_3"]:
		var mount: LaserMountStub = station.get_node("DespunTruss/%s" % mount_name)
		mounts.append({
			"normal": mount.global_transform.basis.y,
			"elevation_half_range_deg": mount.elevation_half_range_deg,
		})
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var uncovered := 0
	for i in range(1000):
		var dir := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)).normalized()
		var covered := false
		for mount_data in mounts:
			var elevation_deg: float = rad_to_deg(asin(clampf(dir.dot(mount_data["normal"]), -1.0, 1.0)))
			if elevation_deg >= 90.0 - mount_data["elevation_half_range_deg"]:
				covered = true
				break
		if not covered:
			uncovered += 1
	_check("T-14 laser sectors cover full sphere (1000-point grid)", uncovered == 0,
			"uncovered=%d/1000" % uncovered)

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
func _test_markers(station: StationRoot, cfg: StationConfig) -> void:
	var ok := true
	var details := ""
	var control_deck: StationModule = station.get_module(&"control_deck")
	var panel_names: Array = ["Panel_Registrar", "Panel_Decoder", "Panel_TxLog", "Panel_StarMap",
			"Panel_Transmitter", "Panel_TxStatus", "Panel_StationControl"]
	for pname in panel_names:
		var marker: Marker3D = control_deck.get_node_or_null(pname)
		if marker == null:
			ok = false
			details += "missing %s; " % pname
			continue
		var pos: Vector3 = marker.position
		var radial_dist: float = Vector2(pos.x, pos.z).length()
		var height_above_floor: float = cfg.ring_radius_m - radial_dist
		var clearance: float = absf(pos.y)
		if height_above_floor < 0.9 or height_above_floor > 1.9:
			ok = false
			details += "%s height=%.3f; " % [pname, height_above_floor]
		if clearance < 0.8 or clearance > 1.5:
			ok = false
			details += "%s clearance=%.3f; " % [pname, clearance]
	for i in range(1, 5):
		var hatch_name: String = "SpokeHatch_%d" % i
		var marker: Marker3D = station.get_node_or_null("RotatingRing/Arcs/%s" % hatch_name)
		if marker == null:
			ok = false
			details += "missing %s; " % hatch_name
	_check("T-19 panel and spoke-hatch markers", ok, details)

# T-17 -----------------------------------------------------------------------
func _test_physics_containment(station: StationRoot) -> void:
	var ok := true
	var details := ""
	var directions: Array = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for module in station.get_modules():
		var hull: MeshInstance3D = module.get_node("Hull")
		var module_aabb: AABB = (hull.global_transform * hull.mesh.get_aabb()).grow(0.3)
		for dir in directions:
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
	_check("T-17 physics containment (8 modules x 6 directions)", ok, details)
