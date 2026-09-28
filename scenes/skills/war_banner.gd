extends Area2D

## 戰旗：flag_plant.png（橫向 10 格、每格 256x368）
## - plant（0~5）：旗子落下插地、光圈爆開，第 1 格插地瞬間才開始套增益並播音效
## - wave（6~9）：持續飄動循環
## - 範圍：程式繪製的地面光圈（素材的光圈只在插地時短暫出現），有友軍在範圍內時變亮
## - 最後 2 秒閃爍，時間到淡出並移除所有增益
## 增益契約（duck typing，同 take_damage）：範圍內有 add_stat_modifier() 的節點會被套用，
## 離開時呼叫 remove_stat_modifier(self)。

const SHEET = preload("res://assets/effects/skills/knight/flag_plant.png")
const Sfx = preload("res://scenes/support/sfx.gd")
const SFX_PLANT = preload("res://assets/audio/sfx/banner_plant.wav")

const FRAME_SIZE: Vector2i = Vector2i(256, 368)
const SPRITE_SCALE: float = 0.6
## 旗桿底部在每格內約 (127, 287)，offset 讓旗桿底部對齊節點原點（插地點）
const SPRITE_OFFSET: Vector2 = Vector2(1, -103)
const PLANT_FPS: float = 12.0
const WAVE_FPS: float = 8.0
## plant 動畫中旗桿插進地面的那一格
const IMPACT_FRAME: int = 1
const RING_COLOR: Color = Color(0.95, 0.78, 0.3)
const WARN_TIME: float = 2.0
const FADE_DURATION: float = 0.4

var radius: float = 64.0
var duration: float = 10.0
var defense_bonus: float = 0.3

var _t: float = 0.0
var _planted: bool = false
var _sprite: AnimatedSprite2D
var _ring_scale: float = 0.0
var _ending: bool = false
var _affected: Array[Node] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ring: Node2D = $Ring

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	# 落地前不套增益
	monitoring = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ring.draw.connect(_draw_ring)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_sprite.offset = SPRITE_OFFSET
	add_child(_sprite)
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"plant")

	get_tree().create_timer(duration).timeout.connect(_expire)

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_anim(frames, &"plant", range(0, 6), PLANT_FPS, false)
	_add_anim(frames, &"wave", range(6, 10), WAVE_FPS, true)
	return frames

func _add_anim(frames: SpriteFrames, anim: StringName, indices: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(anim, atlas)

func _on_frame_changed() -> void:
	if not _planted and _sprite.animation == &"plant" and _sprite.frame >= IMPACT_FRAME:
		_on_planted()

func _on_animation_finished() -> void:
	if _sprite.animation == &"plant":
		_sprite.play(&"wave")

## 旗桿插進地面：開始套增益、播音效、展開範圍光圈
func _on_planted() -> void:
	_planted = true
	monitoring = true
	Sfx.play(self, SFX_PLANT, -3.0)
	var tween := create_tween()
	tween.tween_property(self, "_ring_scale", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	_t += delta
	if not _ending and _t > duration - WARN_TIME:
		modulate.a = 0.4 if fmod(_t, 0.24) < 0.12 else 1.0
	ring.queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _ending or not body.has_method("add_stat_modifier") or _affected.has(body):
		return
	body.add_stat_modifier(self, &"def", defense_bonus)
	_affected.append(body)

func _on_body_exited(body: Node) -> void:
	if not _affected.has(body):
		return
	_affected.erase(body)
	if is_instance_valid(body):
		body.remove_stat_modifier(self)

func _expire() -> void:
	_ending = true
	_clear_modifiers()
	set_deferred("monitoring", false)
	modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)

## 換地圖等情況旗子被直接移除時，也要把增益拿掉
func _exit_tree() -> void:
	_clear_modifiers()

func _clear_modifiers() -> void:
	for body in _affected:
		if is_instance_valid(body):
			body.remove_stat_modifier(self)
	_affected.clear()

## 地面光圈（畫在 Ring 子節點上，z_index -1 壓在角色下面）；有友軍在範圍內時變亮
func _draw_ring() -> void:
	if _ring_scale <= 0.0:
		return
	var r: float = radius * _ring_scale
	var boost: float = 0.25 if not _affected.is_empty() else 0.0
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var fill := RING_COLOR
	fill.a = 0.08 + 0.05 * pulse + boost * 0.5
	ring.draw_circle(Vector2.ZERO, r, fill)
	var edge := RING_COLOR
	edge.a = 0.5 + 0.3 * pulse + boost
	ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, edge, 2.0, true)
