class_name StatBar
extends HBoxContainer

## A labeled progress bar for one survival stat.

@export var stat_label_text: String = "HP"
@export var bar_color: Color = Color.GREEN

@onready var label: Label = $Label
@onready var bar: ProgressBar = $ProgressBar


func _ready() -> void:
	label.text = stat_label_text
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", style)


func set_value(value: float, max_value: float = 100.0) -> void:
	bar.max_value = max_value
	bar.value = value
