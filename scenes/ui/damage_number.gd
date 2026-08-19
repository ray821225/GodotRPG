extends Node2D
class_name DamageNumber

enum DamageType {
	PHYSICAL,
	FIRE,
	ICE,
	LIGHTNING,
	TAKEN,
}

const COLORS := {
	DamageType.PHYSICAL: Color(0.75, 0.75, 0.78, 1),
	DamageType.FIRE: Color(1, 0.55, 0.15, 1),
	DamageType.ICE: Color(0.55, 0.85, 1, 1),
	DamageType.LIGHTNING: Color(1, 0.9, 0.3, 1),
	DamageType.TAKEN: Color(1, 0.55, 0.55, 1),
}

const BORDER_COLORS := {
	DamageType.PHYSICAL: Color(0.1, 0.1, 0.12, 1),
	DamageType.FIRE: Color(0.4, 0.1, 0.0, 1),
	DamageType.ICE: Color(0.0, 0.2, 0.4, 1),
	DamageType.LIGHTNING: Color(0.4, 0.3, 0.0, 1),
	DamageType.TAKEN: Color(0.4, 0.0, 0.0, 1),
}

func setup(amount: int, spawn_pos: Vector2, type: DamageType = DamageType.PHYSICAL) -> void:
	global_position = spawn_pos
	$Label.text = str(amount)
	$Label.add_theme_color_override("font_color", COLORS[type])
	$Label.add_theme_color_override("font_outline_color", BORDER_COLORS[type])

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - 70.0, 1.5)
	tween.tween_property($Label, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tween.finished.connect(queue_free)
