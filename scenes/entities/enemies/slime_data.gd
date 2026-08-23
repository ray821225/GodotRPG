extends "res://scenes/entities/enemies/enemy_data.gd"

## 近戰型敵人的資料：繼承 EnemyData 共用欄位，額外加上「攻擊動畫可以有好幾種、隨機挑一種播放」。
## 史萊姆、未來的近戰哥布林都可以直接沿用這份腳本當 data 的類型，不用另外複製。

@export var attack_animations: Array[StringName] = [&"attack"]
