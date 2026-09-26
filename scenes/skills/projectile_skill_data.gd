extends "res://scenes/skills/skill_data.gd"

## 直線投射物型技能（fireball.tscn / icespike.tscn）：從角色身上往滑鼠方向發射。
## 投射物場景需提供 damage、speed 屬性與 launch(start_position, dir)。

const MUZZLE_OFFSET: Vector2 = Vector2(0, -32)
const MUZZLE_DISTANCE: float = 30.0

@export var scene: PackedScene
@export var damage: int = 30
@export var damage_per_level: int = 0
@export var speed: float = 500.0

func cast(caster: Node2D, level: int) -> void:
	var muzzle_pos: Vector2 = caster.global_position + MUZZLE_OFFSET
	var cast_dir: Vector2 = (caster.get_global_mouse_position() - muzzle_pos).normalized()
	var projectile = scene.instantiate()
	caster.get_tree().current_scene.add_child(projectile)
	projectile.damage = scaled(damage, damage_per_level, level)
	projectile.speed = speed
	projectile.launch(muzzle_pos + cast_dir * MUZZLE_DISTANCE, cast_dir)
