extends Marker2D

## 刷怪點：地圖上放這個代替直接塞完整的怪物節點，執行時才動態生成實際的怪物 instance。
## 場景樹不會被一堆同名怪物節點（SlimeBlue、SlimeBlue2、SlimeBlue3...）塞滿——
## 要新增一隻怪物，複製這個 Marker2D、換 enemy_scene/enemy_data 就好。
##
## 生成出來的怪物會掛在跟這個標記「同一層」（也就是這個標記的 parent 底下），
## 不會掛在標記自己底下，這樣才能正確參與地圖根節點的 Y-sort 深度排序。

const EnemyData = preload("res://scenes/entities/enemies/enemy_data.gd")

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData

func _ready() -> void:
	if enemy_scene == null:
		push_error("SpawnPoint '%s' 沒有指定 enemy_scene" % name)
		return

	var enemy: Node = enemy_scene.instantiate()
	if enemy_data != null and "data" in enemy:
		enemy.data = enemy_data
	enemy.position = position

	# 地圖場景剛載入時，父節點自己還在初始化子節點，這時直接 add_child() 會被拒絕
	# （"Parent node is busy setting up children"），要延到下一幀才能加進樹。
	get_parent().add_child.call_deferred(enemy)
