extends CanvasLayer

func _ready() -> void:
	get_tree().paused = true

func _on_restart_pressed() -> void:
	GameManager.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
