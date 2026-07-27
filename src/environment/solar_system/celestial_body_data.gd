class_name CelestialBodyData
extends Resource

enum BodyType { STAR, PLANET, MOON }

@export var display_name: String = ""
## Уникальный идентификатор тела, используется в SolarSystem.get_body() и в оверлее.
@export var body_id: StringName = &""
@export var body_type: BodyType = BodyType.PLANET
## Идентификатор тела, вокруг которого вычисляется орбита (пусто = Солнце).
@export var parent_body: StringName = &""

@export var radius_km: float = 0.0
@export var orbit: OrbitalElements
## Период вращения вокруг собственной оси, сутки. Отрицательный = ретроградное. FR-13
@export var rotation_period_days: float = 1.0
@export var axial_tilt_deg: float = 0.0
@export var albedo: float = 0.0
@export var base_color: Color = Color.WHITE
## Тело излучает собственный свет (Солнце) — не затемняется терминатором. FR-16
@export var emissive: bool = false
## Множитель яркости в слое Deep для тел ниже порога углового размера. FR-16
@export var brightness: float = 1.0
