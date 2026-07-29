## Стыковка элементов модульной станции по именованным коннекторам
## (station_connector.gd): совмещает moving_connector с target_connector в
## глобальных координатах и разворачивает движущийся элемент так, чтобы их
## +Y стали антипараллельны — как у двух совмещённых фланцев. Пересчитывает
## только global_transform у moving_root; сами коннекторы не создаёт и не меняет.
##
## Это единственное место, где сборка станции вычисляет взаимное положение
## элементов — вместо жёстко прописанных Transform3D в station_dumbbell.tscn,
## что позволяет менять геометрию/размер отдельного элемента, не трогая
## сборку (сместятся только точки стыковки — сборка подстроится сама).
class_name StationDocking
extends RefCounted

static func dock(moving_root: Node3D, moving_connector: Node3D, target_connector: Node3D) -> void:
	var target_global: Transform3D = target_connector.global_transform
	var flipped: Basis = target_global.basis.rotated(target_global.basis.x.normalized(), PI)
	var desired_connector_global := Transform3D(flipped, target_global.origin)
	var connector_local: Transform3D = moving_root.global_transform.affine_inverse() * moving_connector.global_transform
	moving_root.global_transform = desired_connector_global * connector_local.affine_inverse()
