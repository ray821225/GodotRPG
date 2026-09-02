extends "res://scenes/entities/enemies/enemy_data.gd"

## 遠程投擲型敵人的資料：繼承 EnemyData 共用欄位，額外加上「丟什麼」「丟多快」「拋物線多高」。
## 目前唯一實作是丟炸彈的哥布林（goblin_bomber_data.tres），之後要加弓箭手等遠程敵人
## 可以直接沿用這份腳本當 data 類型，不用另外複製。

const Dynamite = preload("res://scenes/entities/projectiles/dynamite.tscn")

@export var projectile_scene: PackedScene = Dynamite
@export var attack_animation: StringName = &"attack"
## 攻擊動畫播放到百分之幾時真正放開投擲物，要跟「手真的舉到最高點」的畫面對上，
## 沒填的話用 slime.gd 近戰預設值的同類邏輯，這裡直接給遠程專用預設。
@export var attack_hit_ratio: float = 0.75

@export_category("Throw")
## 投擲物飛行速度（像素/秒），距離越遠飛行時間越長，但夾在 min/max_duration 之間，
## 避免距離太近時瞬間到達、太遠時飛行時間長到不合理。
@export var throw_speed: float = 260.0
@export var throw_min_duration: float = 0.35
@export var throw_max_duration: float = 0.9
@export var throw_arc_height: float = 90.0
## 投擲物生成位置：敵人中心往面向方向偏移這個距離，模擬從手部丟出。
@export var throw_offset: float = 20.0
