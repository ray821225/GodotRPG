extends "res://scenes/skills/skill_data.gd"

## 蓄力斬：不放技能欄，由左鍵長按觸發（player.gd 的 _on_left_click_pressed/released）。
## 蓄力特效、揮砍動畫、HitBox 判定跟普攻共用，都留在 player.gd；這裡只管數值與職業/冷卻/MP。
## 流程：長按達門檻時 player.can_use_skill() 通過才開始蓄力（不通過就當普攻），
## 蓄滿放開時 player.use_skill() → cast() → caster.perform_charge_slash(倍率)，此時才扣 MP、進冷卻。

## 傷害 = 普攻傷害 × 此倍率
@export var damage_multiplier: float = 50.0
@export var damage_multiplier_per_level: float = 0.0
@export var charge_time: float = 0.5
## 負數 = 升級後蓄力變快
@export var charge_time_per_level: float = 0.0
## 蓄力中的移動速度倍率
@export var move_speed_multiplier: float = 0.4

func get_charge_time(level: int) -> float:
	return maxf(scaled(charge_time, charge_time_per_level, level), 0.1)

func cast(caster: Node2D, level: int) -> void:
	caster.perform_charge_slash(scaled(damage_multiplier, damage_multiplier_per_level, level))
