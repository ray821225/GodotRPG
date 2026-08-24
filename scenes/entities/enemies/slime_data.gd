extends "res://scenes/entities/enemies/enemy_data.gd"

## 近戰型敵人的資料：繼承 EnemyData 共用欄位，額外加上「攻擊動畫可以有好幾種、隨機挑一種播放」。
## 史萊姆、未來的近戰哥布林都可以直接沿用這份腳本當 data 的類型，不用另外複製。

@export var attack_animations: Array[StringName] = [&"attack"]
## HitBox 判定放在「面向目標方向 * 這個距離」的位置。近戰（史萊姆/蘑菇/龍蝦）用預設值即可，
## 舌頭/吐口水這種伸長距離攻擊的怪物要調大，不然攻擊動畫看起來打得到，判定卻在很近的地方。
@export var attack_reach: float = 35.0
## 各攻擊動畫「傷害在動畫播放到百分之幾時觸發」，key 是 attack_animations 裡的動畫名稱。
## 沒填的動畫會用 slime.gd 的預設值（0.375，照史萊姆揮擊校準）。
## 動畫本身有明顯攻擊/命中時機的（例如吐口水在後段才噴出）建議填，不然傷害會跟畫面對不上。
@export var attack_hit_ratios: Dictionary = {}
