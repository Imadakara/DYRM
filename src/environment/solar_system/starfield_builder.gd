## Строит звёздный фон: ArrayMesh с примитивом POINTS на сфере единичного радиуса.
## Яркость распределена по степенному закону (мало ярких, много тусклых звёзд),
## ~5% точек получают цветовой сдвиг. Полностью детерминировано по seed. FR-17, NFR-08
class_name StarfieldBuilder
extends RefCounted

const COLOR_SHIFT_PROBABILITY: float = 0.05
const BRIGHTNESS_POWER: float = 3.0
const MIN_VALUE: float = 0.3
const MAX_VALUE: float = 1.0

static func build(star_count: int, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	positions.resize(star_count)
	colors.resize(star_count)

	for i in range(star_count):
		positions[i] = _random_direction(rng)
		colors[i] = _random_star_color(rng)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	return mesh

static func _random_direction(rng: RandomNumberGenerator) -> Vector3:
	var v := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
	if v.length_squared() < 1e-9:
		v = Vector3.UP
	return v.normalized()

static func _random_star_color(rng: RandomNumberGenerator) -> Color:
	var brightness_t: float = pow(rng.randf(), BRIGHTNESS_POWER)
	var value: float = lerp(MIN_VALUE, MAX_VALUE, brightness_t)
	if rng.randf() >= COLOR_SHIFT_PROBABILITY:
		return Color(value, value, value)
	if rng.randf() < 0.5:
		return Color(value, value * 0.85, value * 0.7)
	return Color(value * 0.75, value * 0.85, value)
