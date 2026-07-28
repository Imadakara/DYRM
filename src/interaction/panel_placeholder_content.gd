## Содержимое заглушки «НЕТ СИГНАЛА» (ТЗ-100, ART-02). Общая сцена для всех
## семи панелей рубки — WorkPanel передаёт номер ответственного ТЗ через
## set_responsible_tz() при загрузке (FR-43).
class_name PanelPlaceholderContent
extends Control

@onready var _tz_label: Label = %TzLabel

func set_responsible_tz(responsible_tz: String) -> void:
	_tz_label.text = "система %s" % responsible_tz
