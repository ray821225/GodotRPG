extends Node2D

const FRAME_COUNT = 16
const FPS = 24.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_play()

func _play() -> void:
	for i in range(FRAME_COUNT):
		if not is_inside_tree():
			return
		sprite.frame = i
		await get_tree().create_timer(1.0 / FPS).timeout
	queue_free()
