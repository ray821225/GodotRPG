extends Node2D

## 通用塵土特效：純視覺、播完自動 queue_free。怪物重生時蓋在身上播放，
## 用來遮掉「無中生有」的瞬間，煙塵散開後才看清楚怪物已經站在原地。

const FRAME_COUNT = 8
const FPS = 16.0

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
