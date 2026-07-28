## Содержимое диагностической панели: кнопка со счётчиком, переключатель,
## ползунок, текстовое поле — доказательство работоспособности каркаса
## WorkPanel и мишень автотестов (ТЗ-100, FR-45).
class_name PanelDiagnosticContent
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _counter_button: Button = %CounterButton
@onready var _demo_checkbox: CheckBox = %DemoCheckBox
@onready var _demo_slider: HSlider = %DemoSlider
@onready var _demo_line_edit: LineEdit = %DemoLineEdit

var _press_count: int = 0

func _ready() -> void:
	_title_label.text = "ДИАГНОСТИКА / ТЗ-100"
	_counter_button.pressed.connect(_on_counter_button_pressed)
	_update_button_text()

func _on_counter_button_pressed() -> void:
	_press_count += 1
	_update_button_text()

func _update_button_text() -> void:
	_counter_button.text = "Нажатий: %d" % _press_count

func get_press_count() -> int:
	return _press_count
