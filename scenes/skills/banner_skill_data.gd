extends "res://scenes/skills/skill_data.gd"

## 放置型增益技能（war_banner.tscn）：在滑鼠位置插一支旗子（超出 cast_range 就放在該方向的最遠處），
## 旗子範圍內的友軍（有 add_stat_modifier() 的節點，目前是玩家）防禦提升，離開範圍或旗子消失就移除。

@export var scene: PackedScene
## 最遠施放距離（玩家碰撞寬約 46px，240 ≈ 5 個人）
@export var cast_range: float = 240.0
## 增益範圍半徑（64 = 直徑 128）
@export var radius: float = 64.0
@export var radius_per_level: float = 0.0
@export var duration: float = 10.0
@export var duration_per_level: float = 0.0
## 防禦加成比例，0.3 = +30%
@export var defense_bonus: float = 0.3
@export var defense_bonus_per_level: float = 0.0

func cast(caster: Node2D, level: int) -> void:
	var offset: Vector2 = caster.get_global_mouse_position() - caster.global_position
	var banner = scene.instantiate()
	banner.radius = scaled(radius, radius_per_level, level)
	banner.duration = scaled(duration, duration_per_level, level)
	banner.defense_bonus = scaled(defense_bonus, defense_bonus_per_level, level)
	banner.global_position = caster.global_position + offset.limit_length(cast_range)
	caster.get_tree().current_scene.add_child(banner)
