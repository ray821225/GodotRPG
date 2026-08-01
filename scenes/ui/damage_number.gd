extends Node2D

func setup(amount: int, spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	$Label.text = str(amount)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - 45.0, 0.8)
	tween.tween_property($Label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.finished.connect(queue_free)
