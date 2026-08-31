extends Area2D

## 掉落在地上的道具：由 enemy_base.gd 的 _drop_loot() 生成並呼叫 setup() 帶入對應的 LootData。
## 玩家的 InteractArea 偵測到後按互動鍵呼叫 collect()，duck typing 契約同 take_damage()：
## 任何實作 collect(collector) 的節點都能被互動拾取。

const LootData = preload("res://scenes/items/loot_data.gd")

const DROP_DURATION: float = 0.5
const DROP_ARC_HEIGHT: float = 100.0
const COLLECT_POP_DURATION: float = 0.1
const COLLECT_FLY_DURATION: float = 0.25

var item_id: String = ""
var amount: int = 0
var _collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func setup(loot: LootData) -> void:
	item_id = loot.item_id
	amount = loot.amount
	sprite.texture = loot.texture

## 掉落動畫：從怪物身上的 start_pos 為起點，縮放從 0 變大、邊旋轉邊飛到地上的 end_pos，
## 飛行途中先關掉碰撞判定，避免玩家在半空中就撿到。
func play_drop_animation(start_pos: Vector2, end_pos: Vector2) -> void:
	global_position = start_pos
	scale = Vector2.ZERO
	rotation = 0.0
	collision_shape.set_deferred("disabled", true)

	var spins: float = float(randi_range(1, 2)) * TAU

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, DROP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", spins, DROP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_update_drop_position.bind(start_pos, end_pos), 0.0, 1.0, DROP_DURATION)
	tween.chain().tween_callback(collision_shape.set_deferred.bind("disabled", false))

## t 必須用線性時間走（不能套 easing），拋物線本身的 4t(1-t) 公式才會自然呈現
## 「上升減速、下降加速」的重力感；如果連 t 都做緩動，會疊加變成落地前不自然地滑行減速。
func _update_drop_position(t: float, start_pos: Vector2, end_pos: Vector2) -> void:
	var pos: Vector2 = start_pos.lerp(end_pos, t)
	pos.y -= 4.0 * DROP_ARC_HEIGHT * t * (1.0 - t)
	global_position = pos

## 撿取動畫：先關掉碰撞避免同一幀被重複拾取，數值立刻生效（金幣/背包不等動畫），
## 視覺上讓道具先彈跳一下再飛向玩家並縮小淡出，動畫結束才真正移除節點。
func collect(collector: Node) -> void:
	if _collected:
		return
	_collected = true
	collision_shape.set_deferred("disabled", true)

	if collector.has_method("collect_item"):
		collector.collect_item(item_id, amount)

	var target: Node2D = collector as Node2D
	var fly_to: Vector2 = target.global_position if target else global_position

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.3, COLLECT_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", fly_to, COLLECT_FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, COLLECT_FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, COLLECT_FLY_DURATION)
	tween.chain().tween_callback(queue_free)
