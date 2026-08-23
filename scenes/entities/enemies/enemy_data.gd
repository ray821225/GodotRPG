extends Resource

## 所有敵人共用的資料基底：血量/速度/偵測/巡邏/重生等「跟怎麼攻擊無關」的欄位都放這裡。
## 近戰/遠程/法師各自繼承這支，加上自己專屬的欄位就好（不用重複這些共用欄位）：
## - 近戰：MeleeEnemyData（attack_animations）
## - 遠程：RangedEnemyData（projectile_scene 等，待補）
## - 法師：CasterEnemyData（spell_scene 等，待補）

@export var display_name: String = "Enemy"
@export var sprite_frames: SpriteFrames

@export_category("Stats")
@export var speed: int = 80
@export var chase_speed: int = 140
## 會不會主動索敵：關掉的話不會憑空跑來攻擊玩家，但只要被打中一次還是會反過來追打攻擊者。
@export var use_detection: bool = true
@export var detection_range: float = 250.0
@export var attack_range: float = 36.0
@export var attack_speed: float = 0.8
@export var max_hp: int = 60
@export var attack_damage: int = 8

@export_category("Wander")
@export var wander_range: float = 100.0
@export var wander_interval: float = 3.0

@export_category("Respawn")
@export var respawn_delay: float = 5.0
