extends "res://scenes/entities/enemies/enemy_base.gd"

## 近戰型敵人的攻擊實作：貼近後用 HitBox 判定造成傷害，data.attack_animations
## 可以放好幾種動畫名稱、每次攻擊隨機挑一種播放（史萊姆現在有 attack / attack2 兩種）。
## 檔名沿用 slime.gd 是因為目前只有史萊姆在用；之後如果要新增「近戰哥布林」，
## 直接沿用這支腳本 + slime_data.gd 當 data 類型即可，屆時再考慮改成中性檔名。

const ATTACK_HIT_DELAY_RATIO: float = 0.375

var attack_animations: Array[StringName] = [&"attack"]
var attack_reach: float = 35.0
var attack_hit_ratios: Dictionary = {}

@onready var hit_box: Area2D = $HitBox

func _ready() -> void:
	hit_box.monitoring = false
	super._ready()

func _apply_extra_data() -> void:
	if "attack_animations" in data:
		attack_animations = data.attack_animations
	if "attack_reach" in data:
		attack_reach = data.attack_reach
	if "attack_hit_ratios" in data:
		attack_hit_ratios = data.attack_hit_ratios

func _perform_attack(dir: Vector2) -> void:
	var anim_name: StringName = attack_animations.pick_random()
	sprite.play(anim_name)

	hit_box.position = dir * attack_reach
	hit_box.monitoring = true

	# 攻擊週期長度要跟著「實際播放的動畫」走（從 SpriteFrames 直接讀幀數/速度算秒數），
	# 不能寫死用 attack_speed，不然動畫還沒播完就提早收招、搶著開始下一次攻擊，
	# 會變成一次揮擊卻算兩次傷害。
	var anim_length: float = _get_animation_length(anim_name)
	var cycle_duration: float = maxf(anim_length, attack_speed)
	var hit_ratio: float = attack_hit_ratios.get(anim_name, ATTACK_HIT_DELAY_RATIO)
	var hit_delay: float = anim_length * hit_ratio
	await get_tree().create_timer(hit_delay).timeout
	deal_damage()

	await get_tree().create_timer(cycle_duration - hit_delay).timeout
	hit_box.monitoring = false

func _get_animation_length(anim_name: StringName) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	# data 沒設定（例如手動拖新 instance 忘記指定）時 sprite_frames 會是 null，
	# 沒有這個防呆的話，對 null 呼叫方法會直接把遊戲炸掉。
	if frames == null or not frames.has_animation(anim_name):
		return 0.5
	var fps: float = frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.5
	return frames.get_frame_count(anim_name) / fps

func _stop_attacking() -> void:
	hit_box.monitoring = false

func deal_damage() -> void:
	if not hit_box.monitoring:
		return
	var areas = hit_box.get_overlapping_areas()
	for area in areas:
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, self)
