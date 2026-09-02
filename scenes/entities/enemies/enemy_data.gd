extends Resource

## 所有敵人共用的資料基底：血量/速度/偵測/巡邏/重生等「跟怎麼攻擊無關」的欄位都放這裡。
## 近戰/遠程/法師各自繼承這支，加上自己專屬的欄位就好（不用重複這些共用欄位）：
## - 近戰：MeleeEnemyData（attack_animations）
## - 遠程：RangedEnemyData（projectile_scene 等，待補）
## - 法師：CasterEnemyData（spell_scene 等，待補）

const LootData = preload("res://scenes/items/loot_data.gd")

@export var display_name: String = "Enemy"
@export var sprite_frames: SpriteFrames
## 素材本身「沒翻轉時」預設面向哪邊：大多數素材預設面右，但有些（例如 Mushroom）
## 攻擊動作本身就是往畫面左邊揮，這種要打開此選項，flip_h 的判斷才不會左右相反。
@export var faces_left_by_default: bool = false

@export_category("Stats")
@export var speed: int = 80
@export var chase_speed: int = 140
## 會不會主動索敵：關掉的話不會憑空跑來攻擊玩家，但只要被打中一次還是會反過來追打攻擊者。
@export var use_detection: bool = true
@export var detection_range: float = 250.0
## 追擊時離「出生點」超過這個距離就放棄追擊、回家並補滿血，不會無限跟著玩家跑。
@export var leash_range: float = 350.0
@export var attack_range: float = 36.0
## 攻擊動畫只有左右鏡像、沒有上下/斜角版本時打開：距離夠了但跟玩家垂直落差太大
## （超過 attack_align_tolerance）不會發動攻擊，會先移動到大致同一水平線再攻擊，
## 避免看起來往旁邊打卻打到斜上方的玩家。近戰類怪物攻擊距離短，不太需要開。
@export var attack_needs_horizontal_align: bool = false
@export var attack_align_tolerance: float = 40.0
@export var attack_speed: float = 0.8
@export var max_hp: int = 60
@export var attack_damage: int = 8
## 物理/魔法防禦，套用比例遞減公式（見 damage_math.gd）。玩家近戰打的是物理，
## 火球/冰錐等技能打的是魔法，依 DamageType 選對應這兩個值。
@export var defense: float = 10.0
@export var magic_defense: float = 10.0

@export_category("Wander")
@export var wander_range: float = 100.0
@export var wander_interval: float = 3.0

@export_category("Respawn")
@export var respawn_delay: float = 5.0

@export_category("Loot")
## 死亡時要不要掉落東西的機率（0~1），沒中的話這次死亡不掉落。
@export var loot_drop_chance: float = 0.7
## 死亡掉落的候選清單，依 weight 加權隨機抽一個掉落。預設共用全部種類的金幣（1~6）與肉，
## 個別敵人需要客製掉落表時可以在該敵人的 .tres 裡覆寫這個欄位。
## 金幣先只用單一款（gold_spin 旋轉動畫），6 階不同金額的舊版本（loot_coin_1~6.tres）
## 先不用，之後要恢復分級掉落再換回來即可，資源檔還留著。
@export var loot_table: Array[LootData] = [
	preload("res://resources/items/loot_coin.tres"),
	preload("res://resources/items/loot_meat.tres"),
]
