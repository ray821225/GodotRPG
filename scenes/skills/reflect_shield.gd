extends Node2D

## 反彈護盾外觀：skill_mana_shield.png（橫向 12 格、每格 192x192）切成三段動畫
## - open：展開（0~2）
## - hold：持續期間循環（2~6）
## - release：閃光後炸開成光環（7~11），播完自己 queue_free
## 吸收時縮放彈一下並閃亮，最後 1 秒閃爍提示即將反彈。
## 由 reflect_skill_data.gd 建立並掛在施放者身上；施放者的 take_damage() 在
## reflect_shield 有值時改呼叫 absorb()，時間到自己釋放並清掉施放者的 reflect_shield。

const SHEET = preload("res://assets/effects/skill_mana_shield.png")
const REFLECT_ORB = preload("res://scenes/skills/reflect_orb.gd")
const Sfx = preload("res://scenes/support/sfx.gd")
## 音效由 tools/gen_sfx.py 合成，要換成素材直接覆蓋同名 wav 即可
const SFX_OPEN = preload("res://assets/audio/sfx/reflect_open.wav")
const SFX_ABSORB = preload("res://assets/audio/sfx/reflect_absorb.wav")
const SFX_RELEASE = preload("res://assets/audio/sfx/reflect_release.wav")
const FRAME_SIZE: int = 192
const SPRITE_SCALE: float = 0.84
const WARN_TIME: float = 1.0
const BLINK_INTERVAL: float = 0.12

var duration: float = 3.0
var multiplier: float = 1.0
var caster: Node2D

var _sprite: AnimatedSprite2D
var _t: float = 0.0
var _released: bool = false
## 攻擊者 -> 累積吸收的傷害
var _absorbed: Dictionary = {}

func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"open")
	Sfx.play(self, SFX_OPEN, -4.0)
	get_tree().create_timer(duration).timeout.connect(release)

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_anim(frames, &"open", [0, 1, 2], 12.0, false)
	_add_anim(frames, &"hold", [2, 3, 4, 5, 6], 8.0, true)
	_add_anim(frames, &"release", [7, 8, 9, 10, 11], 14.0, false)
	return frames

func _add_anim(frames: SpriteFrames, anim: StringName, indices: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(anim, atlas)

func _process(delta: float) -> void:
	_t += delta
	if _released:
		return
	if _t > duration - WARN_TIME:
		_sprite.modulate.a = 0.35 if fmod(_t, BLINK_INTERVAL * 2.0) < BLINK_INTERVAL else 1.0

## 記下這筆吸收量；REFLECT 類型的傷害不記帳，避免之後敵人也有反彈時互彈無限循環
func absorb(amount: int, type: DamageNumber.DamageType, attacker: Node2D) -> void:
	if _released:
		return
	if attacker and attacker != caster and type != DamageNumber.DamageType.REFLECT:
		_absorbed[attacker] = _absorbed.get(attacker, 0) + amount
	_play_absorb_feedback()

func _play_absorb_feedback() -> void:
	Sfx.play(self, SFX_ABSORB, -6.0, 0.08)
	_sprite.modulate = Color(1.6, 1.6, 1.6, _sprite.modulate.a)
	var flash := create_tween()
	flash.tween_property(_sprite, "modulate:r", 1.0, 0.2)
	flash.parallel().tween_property(_sprite, "modulate:g", 1.0, 0.2)
	flash.parallel().tween_property(_sprite, "modulate:b", 1.0, 0.2)
	var punch := create_tween()
	punch.tween_property(self, "scale", Vector2.ONE * 1.12, 0.06)
	punch.tween_property(self, "scale", Vector2.ONE, 0.12)

## 釋放：播 release 動畫（播完自己 queue_free），對每個攻擊者射出反彈光球
func release() -> void:
	if _released:
		return
	_released = true
	if is_instance_valid(caster) and caster.reflect_shield == self:
		caster.reflect_shield = null
	_sprite.modulate = Color.WHITE
	scale = Vector2.ONE
	_sprite.play(&"release")
	Sfx.play(self, SFX_RELEASE, -3.0)

	for attacker in _absorbed:
		if not is_instance_valid(attacker):
			continue
		var damage: int = int(round(_absorbed[attacker] * multiplier))
		if damage <= 0:
			continue
		var orb: REFLECT_ORB = REFLECT_ORB.new()
		get_tree().current_scene.add_child(orb)
		orb.launch(global_position, attacker, damage, caster)
	_absorbed.clear()

## 施放者死亡時直接移除，不反彈
func cancel() -> void:
	_released = true
	_absorbed.clear()
	queue_free()

func _on_animation_finished() -> void:
	match _sprite.animation:
		&"open":
			_sprite.play(&"hold")
		&"release":
			queue_free()
