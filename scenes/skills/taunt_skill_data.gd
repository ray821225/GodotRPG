extends "res://scenes/skills/skill_data.gd"

## 挑釁：施放者頭上跳出罵人對話框，半徑內所有敵人（layer 3，有 taunt() 的節點）
## 頭上跳驚嘆號並立刻鎖定施放者追擊，連不主動索敵的敵人也會被引過來。

const TAUNT_BUBBLE = preload("res://scenes/skills/taunt_bubble.gd")
const Sfx = preload("res://scenes/support/sfx.gd")
const SFX_TAUNT = preload("res://assets/audio/sfx/taunt.wav")
## 對話框尾巴尖端的位置（騎士頭頂上方）
const BUBBLE_OFFSET: Vector2 = Vector2(0, -78)
const ENEMY_LAYER_MASK: int = 4

@export var radius: float = 180.0
@export var radius_per_level: float = 0.0
@export var bubble_text: String = "@#$%&!"
@export var bubble_duration: float = 1.2

func cast(caster: Node2D, level: int) -> void:
	var bubble: TAUNT_BUBBLE = TAUNT_BUBBLE.new()
	bubble.text = bubble_text
	bubble.duration = bubble_duration
	bubble.position = BUBBLE_OFFSET
	caster.add_child(bubble)
	Sfx.play(caster, SFX_TAUNT, -3.0)

	var shape := CircleShape2D.new()
	shape.radius = scaled(radius, radius_per_level, level)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, caster.global_position)
	query.collision_mask = ENEMY_LAYER_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for result in caster.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var enemy = result.collider
		if enemy.has_method("taunt"):
			enemy.taunt(caster)
