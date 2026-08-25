extends Area2D

## 掉落在地上的道具：由 enemy_base.gd 的 _drop_loot() 生成並呼叫 setup() 帶入對應的 LootData。
## 玩家的 InteractArea 偵測到後按互動鍵呼叫 collect()，duck typing 契約同 take_damage()：
## 任何實作 collect(collector) 的節點都能被互動拾取。

const LootData = preload("res://scenes/items/loot_data.gd")

var item_id: String = ""
var amount: int = 0

@onready var sprite: Sprite2D = $Sprite2D

func setup(loot: LootData) -> void:
	item_id = loot.item_id
	amount = loot.amount
	sprite.texture = loot.texture

func collect(collector: Node) -> void:
	if collector.has_method("collect_item"):
		collector.collect_item(item_id, amount)
	queue_free()
