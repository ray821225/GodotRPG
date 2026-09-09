extends Area2D

## 傳送門：碰到玩家就換地圖。動畫用 sprite sheet 在 _ready() 動態切幀
## （做法跟 player.gd 的蓄力斬特效一樣），這樣同一顆場景換張圖就能重複利用。
@export_category("Visual")
@export var texture: Texture2D
@export var h_frames: int = 1
@export var v_frames: int = 1
@export var frame_count: int = 1
@export var fps: float = 8.0

@export_category("Teleport")
@export var target_map: String = ""
@export var target_spawn_point: StringName = &""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _used: bool = false

func _ready() -> void:
	sprite.sprite_frames = _build_sprite_frames()
	sprite.play(&"idle")

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", fps)
	frames.set_animation_loop(&"idle", true)
	var frame_size: Vector2 = texture.get_size() / Vector2(h_frames, v_frames)
	for i in range(frame_count):
		var col: int = i % h_frames
		@warning_ignore("integer_division")
		var row: int = i / h_frames
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_size.x * col, frame_size.y * row, frame_size.x, frame_size.y)
		frames.add_frame(&"idle", atlas)
	return frames

func _on_body_entered(body: Node2D) -> void:
	if _used or target_map.is_empty():
		return
	if not body.has_method("collect_item"):
		return
	_used = true
	GameManager.teleport(body, target_map, target_spawn_point)
