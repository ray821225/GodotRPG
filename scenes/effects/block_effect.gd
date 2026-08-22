extends Node2D

@export var ring_color: Color = Color(0.55, 0.85, 1.0, 0.95)
@export var radius: float = 38.0

func _ready() -> void:
	scale = Vector2(0.4, 0.4)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.7, 1.7), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, ring_color, 6.0, true)
