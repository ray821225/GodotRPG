extends "res://scenes/skills/skill_data.gd"

## 落地 AOE 型技能（sword_nova.tscn / sword_nova_2.tscn）：往滑鼠方向的角色前方一點施放，
## 範圍內敵人一次受到橢圓傷害判定。換素材只要換 scene，數值共用這份定義。

@export var scene: PackedScene
@export var damage: int = 40
@export var damage_per_level: int = 0
## 橢圓判定半軸（水平, 垂直）
@export var radius: Vector2 = Vector2(70.0, 40.0)
@export var radius_per_level: Vector2 = Vector2.ZERO
## 施放點離角色的距離
@export var cast_offset: float = 50.0

func cast(caster: Node2D, level: int) -> void:
	var cast_dir: Vector2 = (caster.get_global_mouse_position() - caster.global_position).normalized()
	if cast_dir.length() < 0.01:
		cast_dir = Vector2.DOWN
	var nova = scene.instantiate()
	nova.global_position = caster.global_position + cast_dir * cast_offset
	nova.damage = scaled(damage, damage_per_level, level)
	nova.radius = scaled(radius, radius_per_level, level)
	nova.attacker = caster
	caster.get_tree().current_scene.add_child(nova)
