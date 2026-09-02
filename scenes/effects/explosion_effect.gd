extends Node2D

## 通用爆炸特效：純視覺、播完自動 queue_free，任何投擲物/範圍傷害要炸開的畫面
## 都可以直接生成這個，不用各自寫一份。

const FRAME_COUNT = 10
const FPS = 20.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	z_index = 100
	_play()

func _play() -> void:
	for i in range(FRAME_COUNT):
		if not is_inside_tree():
			return
		sprite.frame = i
		await get_tree().create_timer(1.0 / FPS).timeout
	queue_free()
