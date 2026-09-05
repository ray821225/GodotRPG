extends Node2D

## 升級特效：純視覺、播完自動 queue_free。player.gd 升級時在頭頂上方一點生成播放，
## 播放期間往上飄一小段（幅度刻意抓小，避免飄出攝影機範圍），播完淡出消失。

## 44 幀 / 14 fps ≈ 3.1 秒，跟 levelup_frames.tres 的播放速度對齊，改那邊的 speed 記得這裡也要調。
const PLAY_DURATION: float = 1.5
const FADE_DURATION: float = 0.4
const FLOAT_DISTANCE: float = 60.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = 100
	sprite.play(&"levelup")
	sprite.animation_finished.connect(queue_free)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, PLAY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_delay(PLAY_DURATION - FADE_DURATION)
