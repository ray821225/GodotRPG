extends RefCounted

## 一次性音效：播放器掛在 current_scene 上、播完自己 queue_free。
## 發出聲音的節點（例如命中就消失的光球）先被移除也不會把聲音切掉。

static func play(context: Node, stream: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	if stream == null or not context.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	# 小幅隨機音高，連續觸發同一個音效時比較不會機械重複
	if pitch_jitter > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.finished.connect(player.queue_free)
	context.get_tree().current_scene.add_child(player)
	player.play()
