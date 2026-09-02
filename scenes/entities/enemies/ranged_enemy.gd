extends "res://scenes/entities/enemies/enemy_base.gd"

## 遠程投擲型敵人的攻擊實作：播放丟擲動畫，播到指定時機生成投擲物、沿拋物線飛向玩家當下位置，
## 落地傷害由投擲物自己算（見 dynamite.gd），這裡不像近戰用 HitBox。
## 檔名沿用 ranged_enemy 是因為之後弓箭手等遠程敵人可以直接共用這支腳本；
## 丟炸彈的哥布林用 ranged_enemy_data.gd 當 data 類型、goblin_bomber_data.tres 帶數值即可。

var attack_animation: StringName = &"attack"
var attack_hit_ratio: float = 0.75
var throw_speed: float = 260.0
var throw_min_duration: float = 0.35
var throw_max_duration: float = 0.9
var throw_arc_height: float = 90.0
var throw_offset: float = 20.0
var projectile_scene: PackedScene

func _apply_extra_data() -> void:
	if "attack_animation" in data:
		attack_animation = data.attack_animation
	if "attack_hit_ratio" in data:
		attack_hit_ratio = data.attack_hit_ratio
	if "throw_speed" in data:
		throw_speed = data.throw_speed
	if "throw_min_duration" in data:
		throw_min_duration = data.throw_min_duration
	if "throw_max_duration" in data:
		throw_max_duration = data.throw_max_duration
	if "throw_arc_height" in data:
		throw_arc_height = data.throw_arc_height
	if "throw_offset" in data:
		throw_offset = data.throw_offset
	if "projectile_scene" in data:
		projectile_scene = data.projectile_scene

func _perform_attack(dir: Vector2) -> void:
	sprite.play(attack_animation)

	# 攻擊週期長度跟著實際播放的動畫走，理由同近戰版本：不能寫死用 attack_speed，
	# 不然動畫還沒播完就提早收招、搶跑下一次攻擊。
	var anim_length: float = _get_animation_length(attack_animation)
	var cycle_duration: float = maxf(anim_length, attack_speed)
	var throw_delay: float = anim_length * attack_hit_ratio
	await get_tree().create_timer(throw_delay).timeout
	_throw_projectile(dir)

	await get_tree().create_timer(cycle_duration - throw_delay).timeout

func _throw_projectile(dir: Vector2) -> void:
	if state == State.DEAD or projectile_scene == null or player == null:
		return
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	var start_pos: Vector2 = global_position + dir * throw_offset
	var target_pos: Vector2 = player.global_position
	projectile.launch(start_pos, target_pos, throw_arc_height, throw_speed, throw_min_duration, throw_max_duration, attack_damage, self)

func _get_animation_length(anim_name: StringName) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null or not frames.has_animation(anim_name):
		return 0.5
	var fps: float = frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.5
	return frames.get_frame_count(anim_name) / fps
