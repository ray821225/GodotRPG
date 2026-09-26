extends "res://scenes/skills/skill_data.gd"

## 反彈護盾：開啟後 duration 秒內受到的傷害全部吸收（不扣血），依攻擊者分別累計，
## 時間到護盾炸開，對每個攻擊者射出光球反彈「累積量 × multiplier」。
## 吸收/計時/反彈都由 reflect_shield.gd 處理，player.gd 只在 take_damage() 把傷害轉給護盾。

const REFLECT_SHIELD = preload("res://scenes/skills/reflect_shield.gd")
const SHIELD_OFFSET: Vector2 = Vector2(0, -32)

@export var duration: float = 3.0
@export var duration_per_level: float = 0.0
@export var multiplier: float = 1.0
@export var multiplier_per_level: float = 0.0

## 護盾已經開著就不能重複開
func can_cast(caster: Node2D) -> bool:
	return caster.reflect_shield == null

func cast(caster: Node2D, level: int) -> void:
	var shield: REFLECT_SHIELD = REFLECT_SHIELD.new()
	shield.duration = scaled(duration, duration_per_level, level)
	shield.multiplier = scaled(multiplier, multiplier_per_level, level)
	shield.caster = caster
	shield.position = SHIELD_OFFSET
	caster.add_child(shield)
	caster.reflect_shield = shield
