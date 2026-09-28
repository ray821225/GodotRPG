extends "res://scenes/skills/skill_data.gd"

## 盾擊：朝滑鼠方向揮盾，打中前方扇形內最近的一隻敵人（小傷害），把牠沿滑鼠方向擊飛。
## 飛行途中撞到地形或另一隻敵人就停下，碰撞雙方受較高傷害並各自判定暈眩
## （擊飛/碰撞/暈眩邏輯在 enemy_base.gd 的 knock_flying()）。沒打到敵人也會揮空並進冷卻。

const BLOCK_EFFECT = preload("res://scenes/effects/block_effect.tscn")
const Sfx = preload("res://scenes/support/sfx.gd")
const SFX_BASH = preload("res://assets/audio/sfx/shield_bash.wav")
const ENEMY_LAYER_MASK: int = 4

## 打得到多遠（從角色腳下算）
@export var reach: float = 80.0
## 扇形半角（度），60 = 前方 120 度
@export var cone_half_angle: float = 60.0
## 命中傷害 = 普攻傷害 × 此倍率
@export var hit_damage_multiplier: float = 0.5
@export var hit_damage_multiplier_per_level: float = 0.0
## 碰撞傷害 = 普攻傷害 × 此倍率（撞牆/撞怪時雙方都吃）
@export var collision_damage_multiplier: float = 1.5
@export var collision_damage_multiplier_per_level: float = 0.0
@export var knockback_distance: float = 220.0
@export var knockback_distance_per_level: float = 0.0
@export var knockback_speed: float = 900.0
## 碰撞時的暈眩機率（0~1）
@export var stun_chance: float = 0.35
@export var stun_chance_per_level: float = 0.0
@export var stun_duration: float = 1.5
@export var stun_duration_per_level: float = 0.0

func cast(caster: Node2D, level: int) -> void:
	var dir: Vector2 = (caster.get_global_mouse_position() - caster.global_position).normalized()
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	caster.play_skill_swing(dir)

	var target: Node2D = _find_target(caster, dir)
	if target == null:
		return
	var atk: int = caster.attack_damage
	# 先擊飛再造成命中傷害，命中那一下才不會又套到受擊小擊退
	target.knock_flying(
		dir,
		scaled(knockback_distance, knockback_distance_per_level, level),
		knockback_speed,
		int(round(atk * scaled(collision_damage_multiplier, collision_damage_multiplier_per_level, level))),
		scaled(stun_chance, stun_chance_per_level, level),
		scaled(stun_duration, stun_duration_per_level, level),
		caster)
	target.take_damage(int(round(atk * scaled(hit_damage_multiplier, hit_damage_multiplier_per_level, level))), DamageNumber.DamageType.PHYSICAL, caster)
	Sfx.play(caster, SFX_BASH, -2.0, 0.06)
	var effect = BLOCK_EFFECT.instantiate()
	caster.get_tree().current_scene.add_child(effect)
	effect.global_position = target.global_position + Vector2(0, -20)

## 前方扇形內離施放者最近的一隻敵人
func _find_target(caster: Node2D, dir: Vector2) -> Node2D:
	var shape := CircleShape2D.new()
	shape.radius = reach
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, caster.global_position)
	query.collision_mask = ENEMY_LAYER_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var best: Node2D = null
	var best_dist: float = INF
	var max_angle: float = deg_to_rad(cone_half_angle)
	for result in caster.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body = result.collider
		if not body.has_method("knock_flying") or body.hp <= 0:
			continue
		var to_body: Vector2 = body.global_position - caster.global_position
		if to_body.length() > 1.0 and absf(dir.angle_to(to_body)) > max_angle:
			continue
		var dist: float = to_body.length()
		if dist < best_dist:
			best = body
			best_dist = dist
	return best
