extends CanvasLayer

const FADE_DURATION = 1.0  # segundos que o fade demora

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	color_rect.modulate.a = 1.0  # começa totalmente preto
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, FADE_DURATION)
