## Соединительная точка ("коннектор") между элементами модульной станции —
## Marker3D с гизмо (видна в редакторе "из коробки", без доп. кода) плюс
## машиночитаемый connector_id. Конвенция стыковки: локальная +Y коннектора
## смотрит НАРУЖУ от своего элемента, в сторону соседнего — у двух состыкованных
## коннекторов +Y всегда антипараллельны (как у совмещённых фланцев), см.
## StationDocking.dock(). Каждый элемент станции (антенна, втулка, барабан,
## коридор, жилой/рабочий модуль) — отдельная сцена, выставляющая такие
## коннекторы вместо жёстко прописанных Transform3D в сцене-сборке.
@tool
class_name StationConnector
extends Marker3D

@export var connector_id: StringName = &""

## Поворот на 180° вокруг локальной +X (X не меняется, Y и Z инвертируются) —
## для торца элемента, откуда сам элемент НЕ продолжается наружу вдоль
## собственной +Y (например, ближний/входной конец трубы). Диагональная
## матрица — безопасна и при ручной записи в текст .tscn (транспонирование
## не имеет значения для чисто диагональных матриц, см. базу знаний Godot,
## пункт 1), но вычисляется в коде для единообразия со всеми остальными
## коннекторами, которые строятся процедурно.
static func flipped_basis() -> Basis:
	return Basis(Vector3.RIGHT, Vector3.DOWN, Vector3(0.0, 0.0, -1.0))

## Создаёт (или переиспользует одноимённый существующий) дочерний коннектор
## с заданным локальным transform. Идемпотентно — безопасно вызывать из
## _build_geometry() при каждой пересборке @tool-скрипта. Принимает готовый
## Transform3D (не просто позицию + флаг разворота), чтобы годиться и для
## коннекторов с осесимметричной ориентацией (torus/цилиндр — identity или
## flipped_basis()), и для радиально ориентированных (барабан — базис зависит
## от угла на окружности, см. drum_module.gd), не размножая варианты сигнатуры.
static func ensure(parent: Node3D, node_name: String, local_transform: Transform3D) -> StationConnector:
	var connector: StationConnector = parent.get_node_or_null(node_name) as StationConnector
	if connector == null:
		connector = StationConnector.new()
		connector.name = node_name
		parent.add_child(connector)
	connector.connector_id = StringName(node_name)
	connector.transform = local_transform
	return connector
