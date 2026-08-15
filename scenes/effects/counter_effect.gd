extends Node2D

@export var burst_color: Color = Color(1.0, 0.85, 0.3, 0.95)
@export var spike_count: int = 8
@export var inner_radius: float = 8.0
@export var outer_radius: float = 34.0

func _ready() -> void:
	scale = Vector2(0.3, 0.3)
	rotation = randf_range(0.0, TAU)
	queue_redraw()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.05)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var points: PackedVector2Array = []
	for i in range(spike_count * 2):
		var angle: float = i * PI / spike_count
		var r: float = outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle), sin(angle)) * r)
	points.append(points[0])
	draw_polyline(points, burst_color, 3.0, true)
